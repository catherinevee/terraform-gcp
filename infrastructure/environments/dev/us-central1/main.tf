# Regional Resources for us-central1
# This configuration deploys region-specific resources

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.45.2"
    }
  }
}

# Configure the Google Cloud Provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Data source to reference global resources
data "terraform_remote_state" "global" {
  backend = "gcs"
  config = {
    bucket = "acme-ecommerce-platform-dev-terraform-state"
    prefix = "terraform/state/global"
  }
}

# Local values for consistent naming
locals {
  project_id  = var.project_id
  environment = var.environment
  region      = var.region

  # Regional resource naming
  regional_prefix = "acme-ecommerce-platform-${local.environment}-${local.region}"

  # Get global resource references
  vpc_network_name       = data.terraform_remote_state.global.outputs.vpc_network_name
  vpc_network_self_link  = data.terraform_remote_state.global.outputs.vpc_network_self_link
  service_accounts       = data.terraform_remote_state.global.outputs.service_accounts
  kms_key_ring           = data.terraform_remote_state.global.outputs.kms_key_ring
  crypto_keys            = data.terraform_remote_state.global.outputs.crypto_keys
  secrets                = data.terraform_remote_state.global.outputs.secrets
  container_repositories = data.terraform_remote_state.global.outputs.container_repositories
}

# Regional Subnets
module "subnets" {
  source = "../../../modules/networking/subnets"

  project_id   = local.project_id
  network_name = local.vpc_network_name

  subnets = [
    {
      subnet_name           = "acme-ecommerce-web-tier-${local.environment}"
      subnet_ip             = "10.0.1.0/24"
      subnet_region         = local.region
      subnet_private_access = true
    },
    {
      subnet_name           = "acme-ecommerce-app-tier-${local.environment}"
      subnet_ip             = "10.0.10.0/24"
      subnet_region         = local.region
      subnet_private_access = true
    },
    {
      subnet_name           = "acme-ecommerce-database-tier-${local.environment}"
      subnet_ip             = "10.0.20.0/24"
      subnet_region         = local.region
      subnet_private_access = true
    },
    {
      subnet_name           = "acme-ecommerce-kubernetes-tier-${local.environment}"
      subnet_ip             = "10.0.30.0/24"
      subnet_region         = local.region
      subnet_private_access = true
    }
  ]
}

# Regional Firewall Rules
module "firewall" {
  source = "../../../modules/networking/firewall"

  project_id   = local.project_id
  network_name = local.vpc_network_name
}

# Regional Compute Resources
module "compute" {
  source = "../../../modules/compute/instances"

  project_id   = local.project_id
  region       = local.region
  network_name = local.vpc_network_name

  instance_templates = {
    "web-template" = {
      name_prefix            = "web-instance"
      description            = "Web server instance template"
      machine_type           = "e2-micro"
      source_image           = "projects/debian-cloud/global/images/family/debian-11"
      disk_size_gb           = 20
      disk_type              = "pd-standard"
      subnetwork             = module.subnets.subnets[0].subnet_name
      enable_external_ip     = true
      service_account_email  = local.service_accounts["acme-orders-service-sa"]
      service_account_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
      metadata = {
        "startup-script" = <<-EOT
        #!/bin/bash
        apt-get update
        apt-get install -y nginx
        systemctl start nginx
        systemctl enable nginx
        echo '<h1>Hello from Terraform-GCP Multi-Region Phase 1 - US Central!</h1>' > /var/www/html/index.html
        EOT
      }
      startup_script = ""
      tags           = ["http", "web"]
    }
  }

  instance_group_managers = {
    "web-igm" = {
      name                = "acme-ecommerce-web-servers"
      description         = "ACME E-commerce Web Server Instance Group"
      base_instance_name  = "acme-ecommerce-web-server"
      zone                = "${local.region}-a"
      template_key        = "web-template"
      target_size         = 2
      enable_auto_healing = true
      health_check_key    = "web-health-check"
      initial_delay_sec   = 300
      update_policy = {
        type                         = "PROACTIVE"
        instance_redistribution_type = "PROACTIVE"
        minimal_action               = "REPLACE"
        max_surge_fixed              = 1
        max_unavailable_fixed        = 0
      }
    }
  }

  health_checks = {
    "web-health-check" = {
      name                = "acme-ecommerce-web-health-check"
      description         = "Health check for web servers"
      check_interval_sec  = 10
      timeout_sec         = 5
      healthy_threshold   = 2
      unhealthy_threshold = 3
      port                = 80
      request_path        = "/"
    }
  }

  autoscalers = {
    "web-autoscaler" = {
      name                       = "acme-ecommerce-web-autoscaler"
      zone                       = "${local.region}-a"
      instance_group_manager_key = "web-igm"
      max_replicas               = 5
      min_replicas               = 2
      cooldown_period            = 60
      cpu_utilization = {
        target = 70
      }
    }
  }
}

# Regional Storage Resources
module "storage" {
  source = "../../../modules/storage/cloud-storage"

  project_id = local.project_id

  buckets = {
    "app-data" = {
      name          = "acme-ecommerce-customer-data-${local.environment}-${local.region}"
      location      = "US-CENTRAL1"
      storage_class = "STANDARD"
      force_destroy = false

      labels = {
        environment = local.environment
        purpose     = "application-data"
        region      = local.region
      }

      versioning = {
        enabled = true
      }

      lifecycle_rule = [{
        action = {
          type = "Delete"
        }
        condition = {
          age = 365
        }
      }]

      cors = [{
        origin          = ["*"]
        method          = ["GET", "POST", "PUT", "DELETE"]
        response_header = ["*"]
        max_age_seconds = 3600
      }]
    }

    "logs" = {
      name          = "acme-ecommerce-application-logs-${local.environment}-${local.region}"
      location      = "US-CENTRAL1"
      storage_class = "NEARLINE"
      force_destroy = false

      labels = {
        environment = local.environment
        purpose     = "logs"
        region      = local.region
      }

      lifecycle_rule = [{
        action = {
          type = "Delete"
        }
        condition = {
          age = 90
        }
      }]
    }
  }

  bucket_iam_bindings = {
    "app-data-access" = {
      bucket_key = "app-data"
      role       = "roles/storage.objectViewer"
      members = [
        "serviceAccount:${local.service_accounts["acme-orders-service-sa"]}"
      ]
    }
    "logs-access" = {
      bucket_key = "logs"
      role       = "roles/storage.objectCreator"
      members = [
        "serviceAccount:${local.service_accounts["acme-orders-service-sa"]}"
      ]
    }
  }

  bucket_objects = {
    "welcome-file" = {
      bucket_key   = "app-data"
      name         = "welcome.txt"
      content      = "Welcome to ACME E-commerce Platform - Multi-Region Deployment - US Central!"
      content_type = "text/plain"
    }
  }
}

# Outputs for regional resources
output "region" {
  description = "GCP region"
  value       = local.region
}

output "subnets" {
  description = "Regional subnet information"
  value       = module.subnets.subnets
}

output "storage_buckets" {
  description = "Regional storage buckets"
  value       = module.storage.bucket_names
}
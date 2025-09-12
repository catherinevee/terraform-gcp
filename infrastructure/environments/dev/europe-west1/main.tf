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
    bucket = "cataziza-ecommerce-platform-dev-terraform-state"
    prefix = "terraform/state/global"
  }
}

# Data source to access database password from Secret Manager
data "google_secret_manager_secret_version" "database_password" {
  secret = "cataziza-orders-database-password"
}

# Local values for consistent naming
locals {
  project_id  = var.project_id
  environment = var.environment
  region      = var.region

  # Regional resource naming
  regional_prefix = "cataziza-ecommerce-platform-${local.environment}-${local.region}"

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
      subnet_name           = "cataziza-ecommerce-web-tier-${local.environment}"
      subnet_ip             = "10.0.1.0/24"
      subnet_region         = local.region
      subnet_private_access = true
    },
    {
      subnet_name           = "cataziza-ecommerce-app-tier-${local.environment}"
      subnet_ip             = "10.0.10.0/24"
      subnet_region         = local.region
      subnet_private_access = true
    },
    {
      subnet_name           = "cataziza-ecommerce-database-tier-${local.environment}"
      subnet_ip             = "10.0.20.0/24"
      subnet_region         = local.region
      subnet_private_access = true
    },
    {
      subnet_name           = "cataziza-ecommerce-kubernetes-tier-${local.environment}"
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
      disk_size_gb           = var.default_disk_size_gb
      disk_type              = "pd-standard"
      subnetwork             = module.subnets.subnets["cataziza-ecommerce-web-tier-${local.environment}"].name
      enable_external_ip     = true
      service_account_email  = local.service_accounts["cataziza-orders-service-sa"]
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
      name                = "cataziza-ecommerce-web-servers"
      description         = "Cataziza E-commerce Web Server Instance Group"
      base_instance_name  = "cataziza-ecommerce-web-server"
      zone                = "${local.region}-a"
      template_key        = "web-template"
      target_size         = var.instance_group_target_size
      enable_auto_healing = true
      health_check_key    = "web-health-check"
      initial_delay_sec   = var.health_check_initial_delay_sec
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
      name                = "cataziza-ecommerce-web-health-check"
      description         = "Health check for web servers"
      check_interval_sec  = var.health_check_interval_sec
      timeout_sec         = var.health_check_timeout_sec
      healthy_threshold   = 2
      unhealthy_threshold = 3
      port                = var.health_check_port
      request_path        = "/"
    }
  }

  autoscalers = {
    "web-autoscaler" = {
      name                       = "cataziza-ecommerce-web-autoscaler"
      zone                       = "${local.region}-a"
      instance_group_manager_key = "web-igm"
      max_replicas               = 5
      min_replicas               = 2
      cooldown_period            = var.autoscaler_cooldown_period
      cpu_utilization = {
        target = var.autoscaler_cpu_target
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
      name          = "cataziza-ecommerce-customer-data-${local.environment}-${local.region}"
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
          age = var.storage_lifecycle_age_days
        }
      }]

      cors = [{
        origin          = ["*"]
        method          = ["GET", "POST", "PUT", "DELETE"]
        response_header = ["*"]
        max_age_seconds = var.storage_cors_max_age_seconds
      }]
    }

    "logs" = {
      name          = "cataziza-ecommerce-application-logs-${local.environment}-${local.region}"
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
          age = var.storage_short_term_age_days
        }
      }]
    }
  }

  bucket_iam_bindings = {
    "app-data-access" = {
      bucket_key = "app-data"
      role       = "roles/storage.objectViewer"
      members = [
        "serviceAccount:${local.service_accounts["cataziza-orders-service-sa"]}"
      ]
    }
    "logs-access" = {
      bucket_key = "logs"
      role       = "roles/storage.objectCreator"
      members = [
        "serviceAccount:${local.service_accounts["cataziza-orders-service-sa"]}"
      ]
    }
  }

  bucket_objects = {
    "welcome-file" = {
      bucket_key   = "app-data"
      name         = "welcome.txt"
      content      = "Welcome to Cataziza E-commerce Platform - Multi-Region Deployment - US Central!"
      content_type = "text/plain"
    }
  }
}

# Regional Database Resources
module "database" {
  source = "../../../modules/database/cloud-sql"

  project_id = local.project_id

  instances = {
    "orders-database" = {
      name                  = "cataziza-orders-database-${local.environment}"
      database_version      = "POSTGRES_15"
      region                = local.region
      tier                  = "db-f1-micro"
      availability_type     = "ZONAL"
      disk_type             = "PD_SSD"
      disk_size             = var.database_default_disk_size_gb
      disk_autoresize       = true
      disk_autoresize_limit = var.database_autoresize_limit_gb
      deletion_protection   = false

      backup_enabled                 = true
      backup_start_time              = "03:00"
      backup_location                = local.region
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = var.database_transaction_log_retention_days

      ipv4_enabled                                  = false
      private_network                               = local.vpc_network_self_link
      enable_private_path_for_google_cloud_services = true
      require_ssl                                   = true
      authorized_networks                           = []

      database_flags = [
        {
          name  = "log_statement"
          value = "all"
        }
      ]

      insights_config = {
        query_insights_enabled  = true
        query_string_length     = var.database_query_string_length
        record_application_tags = true
        record_client_address   = true
      }

      maintenance_window = {
        day          = 7
        hour         = 3
        update_track = "stable"
      }
    }
  }

  databases = {
    "orders-db" = {
      name         = "orders"
      instance_key = "orders-database"
    }
  }

  users = {
    "orders-user" = {
      name         = "orders_user"
      instance_key = "orders-database"
      password     = data.google_secret_manager_secret_version.database_password.secret_data
    }
  }

  ssl_certs = {
    "orders-ssl-cert" = {
      common_name  = "orders-ssl-cert"
      instance_key = "orders-database"
    }
  }

  private_vpc_connection = null
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

output "database_instances" {
  description = "Database instances"
  value       = module.database.instances
}
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Local variables
locals {
  environment = "dev"
  project_id  = var.project_id
  region      = var.region
  
  common_labels = {
    environment = local.environment
    project     = "terraform-gcp"
    managed_by  = "terraform"
  }
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "redis.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudfunctions.googleapis.com",
    "appengine.googleapis.com",
    "pubsub.googleapis.com",
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "servicenetworking.googleapis.com",
  ])
  
  project = local.project_id
  service = each.value
  
  disable_on_destroy = false
}

# VPC Module
module "vpc" {
  source = "../../modules/networking/vpc"
  
  project_id   = local.project_id
  network_name = "${local.project_id}-${local.environment}-vpc"
  routing_mode = "REGIONAL"
  
  delete_default_routes_on_create = true
  
  depends_on = [google_project_service.required_apis]
}

# Subnets Module
module "subnets" {
  source = "../../modules/networking/subnets"
  
  project_id   = local.project_id
  network_name = module.vpc.network_name
  
  subnets = [
    {
      subnet_name           = "${local.project_id}-${local.environment}-${local.region}-public"
      subnet_ip            = "10.0.1.0/24"
      subnet_region        = local.region
      subnet_private_access = true
    },
    {
      subnet_name           = "${local.project_id}-${local.environment}-${local.region}-private"
      subnet_ip            = "10.0.10.0/24"
      subnet_region        = local.region
      subnet_private_access = true
    },
    {
      subnet_name           = "${local.project_id}-${local.environment}-${local.region}-database"
      subnet_ip            = "10.0.20.0/24"
      subnet_region        = local.region
      subnet_private_access = true
    },
    {
      subnet_name           = "${local.project_id}-${local.environment}-${local.region}-gke"
      subnet_ip            = "10.0.30.0/24"
      subnet_region        = local.region
      subnet_private_access = true
    }
  ]
  
  secondary_ranges = {
    "${local.project_id}-${local.environment}-${local.region}-gke" = [
      {
        range_name    = "gke-pods"
        ip_cidr_range = "10.1.0.0/16"
      },
      {
        range_name    = "gke-services"
        ip_cidr_range = "10.2.0.0/16"
      }
    ]
  }
  
  depends_on = [module.vpc]
}

# Firewall Module
module "firewall" {
  source = "../../modules/networking/firewall"
  
  project_id   = local.project_id
  network_name = module.vpc.network_name
  
  depends_on = [module.vpc]
}

# IAM Module
module "iam" {
  source = "../../modules/security/iam"
  
  project_id = local.project_id
  
  service_accounts = {
    "terraform-sa" = {
      account_id   = "terraform-sa"
      display_name = "Terraform Service Account"
      description  = "Service account for Terraform operations"
    }
    "gke-sa" = {
      account_id   = "gke-sa"
      display_name = "GKE Service Account"
      description  = "Service account for GKE cluster"
    }
    "app-sa" = {
      account_id   = "app-sa"
      display_name = "Application Service Account"
      description  = "Service account for applications"
    }
  }
  
  service_account_roles = {
    "terraform-editor" = {
      service_account_key = "terraform-sa"
      role                = "roles/editor"
    }
    "gke-cluster-admin" = {
      service_account_key = "gke-sa"
      role                = "roles/container.clusterAdmin"
    }
    "app-storage-admin" = {
      service_account_key = "app-sa"
      role                = "roles/storage.admin"
    }
  }
  
  custom_roles = {
    "terraform-custom-role" = {
      role_id     = "terraform_custom_role"
      title       = "Terraform Custom Role"
      description = "Custom role for Terraform operations"
      permissions = [
        "compute.instances.create",
        "compute.instances.delete",
        "compute.networks.create",
        "compute.subnetworks.create"
      ]
    }
  }
  
  enable_workload_identity = true
  workload_identity_pool_id = "github-actions"
  workload_identity_display_name = "GitHub Actions Pool"
  workload_identity_description = "Workload Identity Pool for GitHub Actions"
  
  depends_on = [google_project_service.required_apis]
}

# KMS Module
module "kms" {
  source = "../../modules/security/kms"
  
  project_id    = local.project_id
  key_ring_name = "${local.project_id}-${local.environment}-keyring"
  location      = local.region
  
  crypto_keys = {
    "encryption-key" = {
      name            = "encryption-key"
      purpose         = "ENCRYPT_DECRYPT"
      algorithm       = "GOOGLE_SYMMETRIC_ENCRYPTION"
      rotation_period = "7776000s" # 90 days
    }
    "signing-key" = {
      name            = "signing-key"
      purpose         = "ASYMMETRIC_SIGN"
      algorithm       = "EC_SIGN_P256_SHA256"
      rotation_period = null
    }
  }
  
  crypto_key_iam_bindings = {
    "encryption-key-encrypt-decrypt" = {
      crypto_key_key = "encryption-key"
      role           = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
      members        = [
        "serviceAccount:${module.iam.service_account_emails["terraform-sa"]}",
        "serviceAccount:${module.iam.service_account_emails["app-sa"]}"
      ]
    }
    "signing-key-signer" = {
      crypto_key_key = "signing-key"
      role           = "roles/cloudkms.signer"
      members        = [
        "serviceAccount:${module.iam.service_account_emails["terraform-sa"]}"
      ]
    }
  }
  
  depends_on = [module.iam]
}

# Secret Manager Module
module "secret_manager" {
  source = "../../modules/security/secret-manager"
  
  project_id = local.project_id
  
  secrets = {
    "database-password" = {
      secret_id        = "database-password"
      labels           = { environment = local.environment, type = "database" }
      replication_type = "automatic"
      replicas         = []
    }
    "api-key" = {
      secret_id        = "api-key"
      labels           = { environment = local.environment, type = "api" }
      replication_type = "automatic"
      replicas         = []
    }
  }
  
  secret_versions = {
    "database-password-version" = {
      secret_key  = "database-password"
      secret_data = "initial-password-change-me"
    }
    "api-key-version" = {
      secret_key  = "api-key"
      secret_data = "initial-api-key-change-me"
    }
  }
  
  secret_iam_bindings = {
    "database-password-access" = {
      secret_key = "database-password"
      role       = "roles/secretmanager.secretAccessor"
      members    = [
        "serviceAccount:${module.iam.service_account_emails["app-sa"]}"
      ]
    }
    "api-key-access" = {
      secret_key = "api-key"
      role       = "roles/secretmanager.secretAccessor"
      members    = [
        "serviceAccount:${module.iam.service_account_emails["app-sa"]}"
      ]
    }
  }
  
  depends_on = [module.iam]
}

# Compute Module
module "compute" {
  source = "../../modules/compute/instances"
  
  project_id    = local.project_id
  network_name  = module.vpc.network_name
  region        = local.region
  
  instance_templates = {
    "web-template" = {
      name_prefix              = "web-instance"
      description              = "Web server instance template"
      machine_type             = "e2-micro"
      source_image             = "debian-cloud/debian-11"
      disk_size_gb             = 20
      disk_type                = "pd-standard"
      subnetwork               = module.subnets.subnets["${local.project_id}-${local.environment}-${local.region}-public"].name
      enable_external_ip       = true
      service_account_email    = module.iam.service_account_emails["app-sa"]
      service_account_scopes   = ["cloud-platform"]
      metadata = {
        "startup-script" = <<-EOF
          #!/bin/bash
          apt-get update
          apt-get install -y nginx
          systemctl start nginx
          systemctl enable nginx
          echo '<h1>Hello from Terraform-GCP Phase 3!</h1>' > /var/www/html/index.html
        EOF
      }
      startup_script = ""
      tags = ["web", "http"]
    }
  }
  
  instance_group_managers = {
    "web-igm" = {
      name                    = "web-instance-group"
      description             = "Web server instance group"
      base_instance_name      = "web-instance"
      zone                    = "${local.region}-a"
      template_key            = "web-template"
      target_size             = 2
      enable_auto_healing     = true
      health_check_key        = "web-health-check"
      initial_delay_sec       = 300
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
      name                = "web-health-check"
      description         = "Health check for web servers"
      check_interval_sec  = 5
      timeout_sec         = 5
      healthy_threshold   = 2
      unhealthy_threshold = 2
      port                = 80
      request_path        = "/"
    }
  }
  
  autoscalers = {
    "web-autoscaler" = {
      name                        = "web-autoscaler"
      zone                        = "${local.region}-a"
      instance_group_manager_key  = "web-igm"
      max_replicas                = 5
      min_replicas                = 2
      cooldown_period             = 60
      cpu_utilization = {
        target = 0.7
      }
    }
  }
  
  depends_on = [module.subnets, module.iam]
}

# Load Balancer Module
module "load_balancer" {
  source = "../../modules/compute/load-balancer"
  
  project_id = local.project_id
  
  global_ip_name = "${local.project_id}-${local.environment}-lb-ip"
  health_check_name = "${local.project_id}-${local.environment}-lb-health-check"
  backend_service_name = "${local.project_id}-${local.environment}-lb-backend"
  url_map_name = "${local.project_id}-${local.environment}-lb-url-map"
  forwarding_rule_name = "${local.project_id}-${local.environment}-lb-forwarding-rule"
  
  backend_groups = [
    {
      group           = module.compute.instance_group_managers["web-igm"].instance_group
      balancing_mode  = "UTILIZATION"
      capacity_scaler = 1.0
      max_utilization = 0.8
    }
  ]
  
  depends_on = [module.compute]
}

# Storage Module
module "storage" {
  source = "../../modules/storage/buckets"
  
  project_id = local.project_id
  
  buckets = {
    "app-data" = {
      name                        = "${local.project_id}-${local.environment}-app-data"
      location                    = local.region
      storage_class               = "STANDARD"
      uniform_bucket_level_access = true
      enable_versioning           = true
      kms_key_name                = null
      labels = {
        environment = local.environment
        purpose     = "application-data"
      }
      lifecycle_rules = [
        {
          action_type = "Delete"
          age         = 365
        }
      ]
      cors = {
        origin          = ["*"]
        method          = ["GET", "POST", "PUT", "DELETE"]
        response_header = ["*"]
        max_age_seconds = 3600
      }
    }
    "logs" = {
      name                        = "${local.project_id}-${local.environment}-logs"
      location                    = local.region
      storage_class               = "NEARLINE"
      uniform_bucket_level_access = true
      enable_versioning           = false
      labels = {
        environment = local.environment
        purpose     = "logs"
      }
      lifecycle_rules = [
        {
          action_type = "Delete"
          age         = 90
        }
      ]
    }
  }
  
  bucket_iam_bindings = {
    "app-data-access" = {
      bucket_key = "app-data"
      role       = "roles/storage.objectViewer"
      members    = [
        "serviceAccount:${module.iam.service_account_emails["app-sa"]}"
      ]
    }
    "logs-access" = {
      bucket_key = "logs"
      role       = "roles/storage.objectCreator"
      members    = [
        "serviceAccount:${module.iam.service_account_emails["app-sa"]}"
      ]
    }
  }
  
  bucket_objects = {
    "welcome-file" = {
      name         = "welcome.txt"
      bucket_key   = "app-data"
      content      = "Welcome to Terraform-GCP Phase 3! This file was created by Terraform."
      content_type = "text/plain"
    }
  }
  
  depends_on = [module.kms, module.iam]
}

# Output for Phase 0 validation
output "phase_0_complete" {
  description = "Phase 0: Foundation Setup completed successfully"
  value       = "✅ Foundation setup complete - APIs enabled, project structure ready"
}

output "phase_1_complete" {
  description = "Phase 1: Networking Foundation completed successfully"
  value       = "✅ Networking foundation complete - VPC, subnets, and firewall rules created"
}

output "phase_2_complete" {
  description = "Phase 2: Security & Identity completed successfully"
  value       = "✅ Security & Identity complete - IAM, KMS, Secret Manager configured"
}

output "phase_3_complete" {
  description = "Phase 3: Compute & Storage completed successfully"
  value       = "✅ Compute & Storage complete - VM instances, load balancer, and storage buckets created"
}

output "enabled_apis" {
  description = "List of enabled APIs"
  value       = [for api in google_project_service.required_apis : api.service]
}

output "project_id" {
  description = "GCP Project ID"
  value       = local.project_id
}

output "environment" {
  description = "Environment name"
  value       = local.environment
}

output "region" {
  description = "GCP region"
  value       = local.region
}

output "vpc_name" {
  description = "VPC network name"
  value       = module.vpc.network_name
}

output "vpc_self_link" {
  description = "VPC network self link"
  value       = module.vpc.network_self_link
}

output "subnets" {
  description = "Created subnets"
  value       = module.subnets.subnets
}

output "service_accounts" {
  description = "Created service accounts"
  value       = module.iam.service_account_emails
}

output "kms_key_ring" {
  description = "KMS key ring"
  value       = module.kms.key_ring_id
}

output "crypto_keys" {
  description = "KMS crypto keys"
  value       = module.kms.crypto_key_ids
}

output "secrets" {
  description = "Secret Manager secrets"
  value       = module.secret_manager.secret_ids
}

output "instance_templates" {
  description = "Created instance templates"
  value       = module.compute.instance_templates
}

output "instance_groups" {
  description = "Created instance group managers"
  value       = module.compute.instance_group_managers
}

output "load_balancer_ip" {
  description = "Load balancer global IP address"
  value       = module.load_balancer.global_ip_address
}

output "storage_buckets" {
  description = "Created storage buckets"
  value       = module.storage.bucket_names
}

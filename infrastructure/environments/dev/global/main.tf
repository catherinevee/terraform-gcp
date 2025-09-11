# Global Resources for Multi-Region Deployment
# These resources are shared across all regions

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
  region  = var.primary_region
}

# Local values for consistent naming
locals {
  project_id       = var.project_id
  environment      = var.environment
  primary_region   = var.primary_region
  secondary_region = var.secondary_region

  # Global resource naming
  global_prefix = "cataziza-ecommerce-platform-${local.environment}"
}

# Global VPC Network (shared across regions)
module "vpc" {
  source = "../../../modules/networking/vpc"

  project_id   = local.project_id
  network_name = "${local.global_prefix}-vpc"
  routing_mode = "GLOBAL"
}

# Global Load Balancer
module "load_balancer" {
  source = "../../../modules/networking/load-balancer"

  project_id  = local.project_id
  environment = local.environment

  # Global load balancer configuration
  global_ip_name       = "${local.global_prefix}-lb-ip"
  health_check_name    = "${local.global_prefix}-lb-health-check"
  backend_service_name = "${local.global_prefix}-lb-backend"
  url_map_name         = "${local.global_prefix}-lb-url-map"
  forwarding_rule_name = "${local.global_prefix}-lb-forwarding-rule"

  # Backend regions
  backend_regions = [local.primary_region, local.secondary_region]

  # Health check configuration
  health_check_config = {
    check_interval_sec  = var.load_balancer_health_check_interval
    timeout_sec         = var.load_balancer_health_check_timeout
    healthy_threshold   = 2
    unhealthy_threshold = 3
    port                = var.load_balancer_health_check_port
    request_path        = "/health"
  }
}

# Global IAM Configuration
module "iam" {
  source = "../../../modules/security/iam"

  project_id = local.project_id

  # Service accounts for global resources
  service_accounts = {
    "cataziza-terraform-sa" = {
      account_id   = "cataziza-terraform-sa"
      display_name = "Cataziza E-commerce Terraform Service Account"
      description  = "Service account for Terraform operations"
    }
    "cataziza-orders-service-sa" = {
      account_id   = "cataziza-orders-service-sa"
      display_name = "Cataziza Orders Service Account"
      description  = "Service account for orders service"
    }
    "cataziza-customer-api-gke-sa" = {
      account_id   = "cataziza-customer-api-gke-sa"
      display_name = "Cataziza Customer API GKE Service Account"
      description  = "Service account for customer API in GKE"
    }
  }

  # Custom roles
  custom_roles = {
    "terraform-custom-role" = {
      role_id     = "terraform_custom_role"
      title       = "Terraform Custom Role"
      description = "Custom role for Terraform operations"
      permissions = [
        "compute.instances.create",
        "compute.instances.delete",
        "compute.instances.get",
        "compute.instances.list",
        "compute.instances.setMetadata",
        "compute.instances.setTags",
        "compute.instances.start",
        "compute.instances.stop",
        "compute.instances.update",
        "compute.instances.use",
        "compute.instances.attachDisk",
        "compute.instances.detachDisk",
        "compute.instances.reset",
        "compute.instances.setServiceAccount",
        "compute.instances.setShieldedInstanceIntegrityPolicy",
        "compute.instances.setShieldedVmIntegrityPolicy",
        "compute.instances.setShieldedInstanceIntegrityPolicy",
        "compute.instances.setShieldedVmIntegrityPolicy"
      ]
    }
  }

  # Service account roles
  service_account_roles = {
    "terraform-editor" = {
      role                = "roles/editor"
      service_account_key = "cataziza-terraform-sa"
    }
    "app-storage-admin" = {
      role                = "roles/storage.admin"
      service_account_key = "cataziza-orders-service-sa"
    }
    "gke-cluster-admin" = {
      role                = "roles/container.clusterAdmin"
      service_account_key = "cataziza-customer-api-gke-sa"
    }
  }

  # Project IAM bindings
  project_iam_bindings = {
    "terraform-sa-editor" = {
      role   = "roles/editor"
      member = "serviceAccount:cataziza-terraform-sa@${local.project_id}.iam.gserviceaccount.com"
    }
  }

  # Workload Identity Pool for GitHub Actions
  enable_workload_identity       = true
  workload_identity_pool_id      = "github-actions"
  workload_identity_display_name = "GitHub Actions Workload Identity Pool"
  workload_identity_description  = "Workload Identity Pool for GitHub Actions CI/CD"

  workload_identity_provider_id           = "github-actions-provider"
  workload_identity_provider_display_name = "GitHub Actions Provider"
  workload_identity_provider_description  = "Workload Identity Provider for GitHub Actions"

  workload_identity_issuer_uri = "https://token.actions.githubusercontent.com"
}

# Global KMS Configuration
module "kms" {
  source = "../../../modules/security/kms"

  project_id = local.project_id
  location   = local.primary_region

  key_ring_name = "${local.global_prefix}-keyring"

  crypto_keys = {
    "cataziza-ecommerce-data-encryption-key" = {
      name            = "cataziza-ecommerce-data-encryption-key"
      purpose         = "ENCRYPT_DECRYPT"
      rotation_period = "${var.kms_rotation_period_days * 24 * 60 * 60}s"
      algorithm       = "GOOGLE_SYMMETRIC_ENCRYPTION"
    }
    "cataziza-ecommerce-signing-key" = {
      name      = "cataziza-ecommerce-signing-key"
      purpose   = "ASYMMETRIC_SIGN"
      algorithm = "EC_SIGN_P256_SHA256"
    }
  }

  # IAM bindings for crypto keys
  crypto_key_iam_bindings = {
    "encryption-key-encrypt-decrypt" = {
      role = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
      members = [
        "serviceAccount:cataziza-terraform-sa@${local.project_id}.iam.gserviceaccount.com",
        "serviceAccount:cataziza-orders-service-sa@${local.project_id}.iam.gserviceaccount.com"
      ]
      crypto_key_key = "cataziza-ecommerce-data-encryption-key"
    }
    "signing-key-signer" = {
      role = "roles/cloudkms.signer"
      members = [
        "serviceAccount:cataziza-terraform-sa@${local.project_id}.iam.gserviceaccount.com"
      ]
      crypto_key_key = "cataziza-ecommerce-signing-key"
    }
  }
}

# Global Secret Manager Configuration
module "secret_manager" {
  source = "../../../modules/security/secret-manager"

  project_id = local.project_id

  secrets = {
    "api-key" = {
      secret_id = "api-key"
      labels = {
        environment = local.environment
        purpose     = "api-key"
        managed_by  = "terraform"
      }
      replicas         = []
      replication_type = "AUTOMATIC"
    }
    "database-password" = {
      secret_id = "cataziza-orders-database-password"
      labels = {
        environment = local.environment
        purpose     = "database-password"
        managed_by  = "terraform"
      }
      replicas         = []
      replication_type = "AUTOMATIC"
    }
    "vpn-shared-secret" = {
      secret_id = "cataziza-vpn-shared-secret"
      labels = {
        environment = local.environment
        purpose     = "vpn-shared-secret"
        managed_by  = "terraform"
      }
      replicas         = []
      replication_type = "AUTOMATIC"
    }
  }

  # Secret versions are created manually via gcloud CLI or console
  # Example commands:
  # gcloud secrets versions add api-key --data-file=api-key.txt
  # gcloud secrets versions add cataziza-orders-database-password --data-file=db-password.txt
  # gcloud secrets versions add cataziza-vpn-shared-secret --data-file=vpn-secret.txt

  secret_iam_bindings = {
    "api-key-access" = {
      secret_key = "api-key"
      role       = "roles/secretmanager.secretAccessor"
      members = [
        "serviceAccount:cataziza-orders-service-sa@${local.project_id}.iam.gserviceaccount.com"
      ]
    }
    "database-password-access" = {
      secret_key = "database-password"
      role       = "roles/secretmanager.secretAccessor"
      members = [
        "serviceAccount:cataziza-orders-service-sa@${local.project_id}.iam.gserviceaccount.com"
      ]
    }
    "vpn-shared-secret-access" = {
      secret_key = "vpn-shared-secret"
      role       = "roles/secretmanager.secretAccessor"
      members = [
        "serviceAccount:cataziza-terraform-sa@${local.project_id}.iam.gserviceaccount.com"
      ]
    }
  }
}

# Global Container Registry
module "container_registry" {
  source = "../../../modules/storage/container-registry"

  project_id = local.project_id

  repositories = {
    "app-images" = {
      location       = local.primary_region
      repository_id  = "${local.global_prefix}-application-images"
      description    = "Application container images"
      format         = "DOCKER"
      keep_count     = var.container_registry_retention_count
      retention_days = var.container_registry_retention_days
      labels = {
        environment = local.environment
        purpose     = "application-images"
        managed_by  = "terraform"
      }
    }
    "base-images" = {
      location       = local.primary_region
      repository_id  = "${local.global_prefix}-base-images"
      description    = "Base container images"
      format         = "DOCKER"
      keep_count     = var.container_registry_retention_count
      retention_days = var.container_registry_retention_days
      labels = {
        environment = local.environment
        purpose     = "base-images"
        managed_by  = "terraform"
      }
    }
  }

  # IAM bindings for repositories
  repository_iam_bindings = {
    "app-images-access" = {
      repository_key = "app-images"
      role           = "roles/artifactregistry.reader"
      members = [
        "serviceAccount:cataziza-customer-api-gke-sa@${local.project_id}.iam.gserviceaccount.com",
        "serviceAccount:cataziza-orders-service-sa@${local.project_id}.iam.gserviceaccount.com"
      ]
    }
    "base-images-access" = {
      repository_key = "base-images"
      role           = "roles/artifactregistry.reader"
      members = [
        "serviceAccount:cataziza-customer-api-gke-sa@${local.project_id}.iam.gserviceaccount.com",
        "serviceAccount:cataziza-orders-service-sa@${local.project_id}.iam.gserviceaccount.com"
      ]
    }
  }
}

# Outputs for global resources
output "vpc_network_name" {
  description = "Name of the global VPC network"
  value       = module.vpc.network_name
}

output "vpc_network_self_link" {
  description = "Self-link of the global VPC network"
  value       = module.vpc.network_self_link
}

output "load_balancer_ip" {
  description = "Global load balancer IP address"
  value       = module.load_balancer.global_ip_address
}

output "service_accounts" {
  description = "Global service account emails"
  value       = module.iam.service_account_emails
}

output "kms_key_ring" {
  description = "KMS key ring"
  value       = module.kms.key_ring
}

output "crypto_keys" {
  description = "Crypto keys"
  value       = module.kms.crypto_keys
}

output "secrets" {
  description = "Secret Manager secrets"
  value       = module.secret_manager.secrets
}

output "container_repositories" {
  description = "Container registry repositories"
  value       = module.container_registry.repositories
}
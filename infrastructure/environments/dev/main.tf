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

# Output for Phase 0 validation
output "phase_0_complete" {
  description = "Phase 0: Foundation Setup completed successfully"
  value       = "✅ Foundation setup complete - APIs enabled, project structure ready"
}

output "phase_1_complete" {
  description = "Phase 1: Networking Foundation completed successfully"
  value       = "✅ Networking foundation complete - VPC, subnets, and firewall rules created"
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

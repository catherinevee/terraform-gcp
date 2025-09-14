# Subnets Module
# Creates subnets in a VPC network

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.45.2"
    }
  }
}

# Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "network_name" {
  description = "VPC network name"
  type        = string
}

variable "subnets" {
  description = "List of subnets to create"
  type = list(object({
    subnet_name           = string
    subnet_ip             = string
    subnet_region         = string
    subnet_private_access = bool
  }))
}

# Create subnets
resource "google_compute_subnetwork" "subnets" {
  for_each = { for subnet in var.subnets : subnet.subnet_name => subnet }

  name          = each.value.subnet_name
  ip_cidr_range = each.value.subnet_ip
  region        = each.value.subnet_region
  network       = var.network_name
  project       = var.project_id

  private_ip_google_access = each.value.subnet_private_access
}

# Outputs
output "subnets" {
  description = "Created subnets"
  value = {
    for k, v in google_compute_subnetwork.subnets : k => {
      name    = v.name
      id      = v.id
      self_link = v.self_link
      ip_cidr_range = v.ip_cidr_range
      region  = v.region
    }
  }
}

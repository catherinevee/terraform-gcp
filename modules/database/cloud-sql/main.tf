# Cloud SQL Module
# Creates Cloud SQL instances and databases

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

variable "region" {
  description = "GCP region"
  type        = string
}

variable "databases" {
  description = "Map of databases to create"
  type = map(object({
    name             = string
    database_version = string
    tier             = string
    disk_size        = number
    disk_type        = string
    availability_type = string
    backup_enabled   = bool
    binary_log_enabled = bool
  }))
  default = {}
}

# Cloud SQL instances
resource "google_sql_database_instance" "instances" {
  for_each = var.databases

  name             = each.value.name
  database_version = each.value.database_version
  project          = var.project_id
  region           = var.region

  settings {
    tier              = each.value.tier
    disk_size         = each.value.disk_size
    disk_type         = each.value.disk_type
    availability_type = each.value.availability_type

    backup_configuration {
      enabled                        = each.value.backup_enabled
      binary_log_enabled            = each.value.binary_log_enabled
      start_time                    = "03:00"
      location                      = var.region
      point_in_time_recovery_enabled = true
    }

    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "public"
        value = "0.0.0.0/0"
      }
    }
  }

  deletion_protection = false
}

# Cloud SQL databases
resource "google_sql_database" "databases" {
  for_each = var.databases

  name     = each.value.name
  instance = google_sql_database_instance.instances[each.key].name
  project  = var.project_id
}

# Cloud SQL users
resource "google_sql_user" "users" {
  for_each = var.databases

  name     = "admin"
  instance = google_sql_database_instance.instances[each.key].name
  project  = var.project_id
  password = "admin123"
}

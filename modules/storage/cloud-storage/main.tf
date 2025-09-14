# Cloud Storage Module
# Creates GCS buckets for various purposes

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

variable "buckets" {
  description = "Map of buckets to create"
  type = map(object({
    name          = string
    location      = string
    storage_class = string
    versioning    = bool
    lifecycle_rules = list(object({
      condition = object({
        age = number
      })
      action = object({
        type = string
      })
    }))
  }))
  default = {}
}

# GCS Buckets
resource "google_storage_bucket" "buckets" {
  for_each = var.buckets

  name          = each.value.name
  location      = each.value.location
  project       = var.project_id
  storage_class = each.value.storage_class

  versioning {
    enabled = each.value.versioning
  }

  dynamic "lifecycle_rule" {
    for_each = each.value.lifecycle_rules
    content {
      condition {
        age = lifecycle_rule.value.condition.age
      }
      action {
        type = lifecycle_rule.value.action.type
      }
    }
  }

  uniform_bucket_level_access = true
}

# Bucket IAM bindings
resource "google_storage_bucket_iam_binding" "bindings" {
  for_each = var.buckets

  bucket = google_storage_bucket.buckets[each.key].name
  role   = "roles/storage.objectViewer"

  members = [
    "serviceAccount:terraform-github-actions@${var.project_id}.iam.gserviceaccount.com"
  ]
}

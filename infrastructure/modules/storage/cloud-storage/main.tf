# Cloud Storage Module

# Storage Buckets
resource "google_storage_bucket" "buckets" {
  for_each = var.buckets

  name          = each.value.name
  location      = each.value.location
  storage_class = each.value.storage_class
  force_destroy = each.value.force_destroy

  labels = each.value.labels

  # Versioning
  dynamic "versioning" {
    for_each = each.value.versioning != null ? [each.value.versioning] : []
    content {
      enabled = versioning.value.enabled
    }
  }

  # Lifecycle rules
  dynamic "lifecycle_rule" {
    for_each = each.value.lifecycle_rule != null ? each.value.lifecycle_rule : []
    content {
      action {
        type = lifecycle_rule.value.action.type
      }
      condition {
        age = lifecycle_rule.value.condition.age
      }
    }
  }

  # CORS configuration
  dynamic "cors" {
    for_each = each.value.cors != null ? each.value.cors : []
    content {
      origin          = cors.value.origin
      method          = cors.value.method
      response_header = cors.value.response_header
      max_age_seconds = cors.value.max_age_seconds
    }
  }
}

# Bucket IAM bindings
resource "google_storage_bucket_iam_binding" "bucket_iam_bindings" {
  for_each = var.bucket_iam_bindings

  bucket  = google_storage_bucket.buckets[each.value.bucket_key].name
  role    = each.value.role
  members = each.value.members
}

# Bucket objects
resource "google_storage_bucket_object" "bucket_objects" {
  for_each = var.bucket_objects

  name         = each.value.name
  bucket       = google_storage_bucket.buckets[each.value.bucket_key].name
  content      = each.value.content
  content_type = each.value.content_type
}

# Outputs
output "bucket_names" {
  description = "Names of the created buckets"
  value       = { for k, v in google_storage_bucket.buckets : k => v.name }
}

output "bucket_urls" {
  description = "URLs of the created buckets"
  value       = { for k, v in google_storage_bucket.buckets : k => v.url }
}

output "buckets" {
  description = "Bucket resources"
  value       = google_storage_bucket.buckets
}


# Cloud Storage Buckets
resource "google_storage_bucket" "buckets" {
  for_each = var.buckets
  
  name          = each.value.name
  location      = each.value.location
  project       = var.project_id
  storage_class = each.value.storage_class
  
  uniform_bucket_level_access = each.value.uniform_bucket_level_access
  
  dynamic "versioning" {
    for_each = each.value.enable_versioning ? [1] : []
    content {
      enabled = true
    }
  }
  
  dynamic "lifecycle_rule" {
    for_each = each.value.lifecycle_rules
    content {
      action {
        type = lifecycle_rule.value.action_type
      }
      
      condition {
        age = lifecycle_rule.value.age
      }
    }
  }
  
  dynamic "cors" {
    for_each = each.value.cors != null ? [each.value.cors] : []
    content {
      origin          = cors.value.origin
      method          = cors.value.method
      response_header = cors.value.response_header
      max_age_seconds = cors.value.max_age_seconds
    }
  }
  
  dynamic "encryption" {
    for_each = each.value.kms_key_name != null ? [1] : []
    content {
      default_kms_key_name = each.value.kms_key_name
    }
  }
  
  labels = each.value.labels
}

# Bucket IAM Bindings
resource "google_storage_bucket_iam_binding" "bucket_iam_bindings" {
  for_each = var.bucket_iam_bindings
  
  bucket = google_storage_bucket.buckets[each.value.bucket_key].name
  role   = each.value.role
  members = each.value.members
}

# Bucket Objects
resource "google_storage_bucket_object" "bucket_objects" {
  for_each = var.bucket_objects
  
  name   = each.value.name
  bucket = google_storage_bucket.buckets[each.value.bucket_key].name
  source = each.value.source
  content = each.value.content
  
  content_type = each.value.content_type
}

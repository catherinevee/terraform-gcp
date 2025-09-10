output "buckets" {
  description = "Created storage buckets"
  value       = google_storage_bucket.buckets
}

output "bucket_names" {
  description = "Storage bucket names"
  value       = { for k, v in google_storage_bucket.buckets : k => v.name }
}

output "bucket_objects" {
  description = "Created bucket objects"
  value       = google_storage_bucket_object.bucket_objects
}

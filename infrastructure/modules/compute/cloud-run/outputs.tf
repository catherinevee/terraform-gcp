output "services" {
  description = "Created Cloud Run services"
  value       = google_cloud_run_v2_service.service
}

output "service_names" {
  description = "Cloud Run service names"
  value       = { for k, v in google_cloud_run_v2_service.service : k => v.name }
}

output "service_urls" {
  description = "Cloud Run service URLs"
  value       = { for k, v in google_cloud_run_v2_service.service : k => v.uri }
}

output "service_locations" {
  description = "Cloud Run service locations"
  value       = { for k, v in google_cloud_run_v2_service.service : k => v.location }
}

output "iam_policies" {
  description = "Created IAM policies"
  value       = google_cloud_run_service_iam_policy.policy
}

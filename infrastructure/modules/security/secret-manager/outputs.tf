output "secrets" {
  description = "Secret Manager secrets"
  value       = google_secret_manager_secret.secrets
}

output "secret_versions" {
  description = "Secret Manager secret versions"
  value       = google_secret_manager_secret_version.secret_versions
}

output "secret_ids" {
  description = "Secret Manager secret IDs"
  value       = { for k, v in google_secret_manager_secret.secrets : k => v.id }
}

output "service_accounts" {
  description = "Created service accounts"
  value       = google_service_account.service_accounts
}

output "service_account_emails" {
  description = "Service account emails"
  value       = { for k, v in google_service_account.service_accounts : k => v.email }
}

output "custom_roles" {
  description = "Created custom roles"
  value       = google_project_iam_custom_role.custom_roles
}

output "workload_identity_pool" {
  description = "Workload Identity Pool"
  value       = var.enable_workload_identity ? google_iam_workload_identity_pool.workload_identity_pool[0] : null
}

output "workload_identity_pool_provider" {
  description = "Workload Identity Pool Provider"
  value       = var.enable_workload_identity ? google_iam_workload_identity_pool_provider.workload_identity_pool_provider[0] : null
}

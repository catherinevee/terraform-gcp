# Secret Manager Secrets
resource "google_secret_manager_secret" "secrets" {
  for_each = var.secrets
  
  secret_id = each.value.secret_id
  project   = var.project_id
  
  labels = each.value.labels
  
  replication {
    auto {}
  }
}

# Secret Manager Secret Versions
resource "google_secret_manager_secret_version" "secret_versions" {
  for_each = var.secret_versions
  
  secret      = google_secret_manager_secret.secrets[each.value.secret_key].id
  secret_data = each.value.secret_data
}

# Secret Manager IAM Bindings
resource "google_secret_manager_secret_iam_binding" "secret_iam_bindings" {
  for_each = var.secret_iam_bindings
  
  secret_id = google_secret_manager_secret.secrets[each.value.secret_key].secret_id
  role      = each.value.role
  members   = each.value.members
  project   = var.project_id
}

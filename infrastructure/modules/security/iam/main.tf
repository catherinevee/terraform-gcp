# Service Accounts
resource "google_service_account" "service_accounts" {
  for_each = var.service_accounts
  
  account_id   = each.value.account_id
  display_name = each.value.display_name
  description  = each.value.description
  project      = var.project_id
}

# IAM Bindings for Service Accounts - Commented out to avoid circular dependencies
# resource "google_project_iam_member" "service_account_roles" {
#   for_each = var.service_account_roles
#   
#   project = var.project_id
#   role    = each.value.role
#   member  = "serviceAccount:${google_service_account.service_accounts[each.value.service_account_key].email}"
# }

# Custom IAM Roles
resource "google_project_iam_custom_role" "custom_roles" {
  for_each = var.custom_roles
  
  role_id     = each.value.role_id
  title       = each.value.title
  description = each.value.description
  permissions = each.value.permissions
  project     = var.project_id
}

# IAM Policy Bindings - Commented out to avoid permission issues during initial deployment
# resource "google_project_iam_member" "project_iam_bindings" {
#   for_each = var.project_iam_bindings
#   
#   project = var.project_id
#   role    = each.value.role
#   member  = each.value.member
# }

# Workload Identity Pool (for external identity providers)
resource "google_iam_workload_identity_pool" "workload_identity_pool" {
  count = var.enable_workload_identity ? 1 : 0
  
  workload_identity_pool_id = var.workload_identity_pool_id
  display_name              = var.workload_identity_display_name
  description               = var.workload_identity_description
  project                   = var.project_id
}

# Workload Identity Pool Provider
resource "google_iam_workload_identity_pool_provider" "workload_identity_pool_provider" {
  count = var.enable_workload_identity ? 1 : 0
  
  workload_identity_pool_id          = google_iam_workload_identity_pool.workload_identity_pool[0].workload_identity_pool_id
  workload_identity_pool_provider_id = var.workload_identity_provider_id
  display_name                       = var.workload_identity_provider_display_name
  description                        = var.workload_identity_provider_description
  project                            = var.project_id
  
  attribute_mapping = var.workload_identity_attribute_mapping
  
  attribute_condition = var.workload_identity_attribute_condition
  
  oidc {
    issuer_uri = var.workload_identity_issuer_uri
  }
}

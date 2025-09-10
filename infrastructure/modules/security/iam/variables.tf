variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "service_accounts" {
  description = "Map of service accounts to create"
  type = map(object({
    account_id   = string
    display_name = string
    description  = string
  }))
  default = {}
}

variable "service_account_roles" {
  description = "Map of service account role bindings"
  type = map(object({
    service_account_key = string
    role                = string
  }))
  default = {}
}

variable "custom_roles" {
  description = "Map of custom IAM roles to create"
  type = map(object({
    role_id     = string
    title       = string
    description = string
    permissions = list(string)
  }))
  default = {}
}

variable "project_iam_bindings" {
  description = "Map of project-level IAM bindings"
  type = map(object({
    role   = string
    member = string
  }))
  default = {}
}

variable "enable_workload_identity" {
  description = "Enable Workload Identity Pool"
  type        = bool
  default     = false
}

variable "workload_identity_pool_id" {
  description = "Workload Identity Pool ID"
  type        = string
  default     = "github-actions"
}

variable "workload_identity_display_name" {
  description = "Workload Identity Pool display name"
  type        = string
  default     = "GitHub Actions Pool"
}

variable "workload_identity_description" {
  description = "Workload Identity Pool description"
  type        = string
  default     = "Workload Identity Pool for GitHub Actions"
}

variable "workload_identity_provider_id" {
  description = "Workload Identity Pool Provider ID"
  type        = string
  default     = "github-actions-provider"
}

variable "workload_identity_provider_display_name" {
  description = "Workload Identity Pool Provider display name"
  type        = string
  default     = "GitHub Actions Provider"
}

variable "workload_identity_provider_description" {
  description = "Workload Identity Pool Provider description"
  type        = string
  default     = "Workload Identity Pool Provider for GitHub Actions"
}

variable "workload_identity_attribute_mapping" {
  description = "Workload Identity attribute mapping"
  type        = map(string)
  default = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }
}

variable "workload_identity_issuer_uri" {
  description = "Workload Identity issuer URI"
  type        = string
  default     = "https://token.actions.githubusercontent.com"
}

variable "workload_identity_attribute_condition" {
  description = "Workload Identity attribute condition"
  type        = string
  default     = "assertion.repository=='catherinevee/terraform-gcp'"
}

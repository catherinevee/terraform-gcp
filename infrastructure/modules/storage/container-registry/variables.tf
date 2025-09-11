variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "repositories" {
  description = "Map of Artifact Registry repositories to create"
  type = map(object({
    location       = string
    repository_id  = string
    description    = string
    format         = string
    keep_count     = number
    retention_days = string
    labels         = map(string)
  }))
  default = {}
}

variable "repository_iam_bindings" {
  description = "Map of IAM bindings for repositories"
  type = map(object({
    repository_key = string
    role           = string
    members        = list(string)
  }))
  default = {}
}

variable "enable_legacy_registry" {
  description = "Enable legacy Container Registry"
  type        = bool
  default     = false
}

variable "legacy_registry_location" {
  description = "Location for legacy Container Registry"
  type        = string
  default     = "US"
}

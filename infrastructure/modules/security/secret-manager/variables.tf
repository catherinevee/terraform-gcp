variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "secrets" {
  description = "Map of secrets to create"
  type = map(object({
    secret_id        = string
    labels           = map(string)
    replication_type = string
    replicas = list(object({
      location = string
    }))
  }))
  default = {}
}

variable "secret_versions" {
  description = "Map of secret versions to create"
  type = map(object({
    secret_key  = string
    secret_data = string
  }))
  default = {}
}

variable "secret_iam_bindings" {
  description = "Map of secret IAM bindings"
  type = map(object({
    secret_key = string
    role       = string
    members    = list(string)
  }))
  default = {}
}

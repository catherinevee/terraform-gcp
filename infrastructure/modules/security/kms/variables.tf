variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "key_ring_name" {
  description = "Name of the KMS key ring"
  type        = string
}

variable "location" {
  description = "Location for the KMS key ring"
  type        = string
  default     = "us-central1"
}

variable "enable_iam_bindings" {
  description = "Enable IAM bindings for KMS resources"
  type        = bool
  default     = true
}

variable "crypto_keys" {
  description = "Map of crypto keys to create"
  type = map(object({
    name            = string
    purpose         = string
    algorithm       = string
    rotation_period = optional(string)
  }))
  default = {}
}

variable "crypto_key_iam_bindings" {
  description = "Map of crypto key IAM bindings"
  type = map(object({
    crypto_key_key = string
    role           = string
    members        = list(string)
  }))
  default = {}
}

variable "key_ring_iam_bindings" {
  description = "Map of key ring IAM bindings"
  type = map(object({
    role    = string
    members = list(string)
  }))
  default = {}
}

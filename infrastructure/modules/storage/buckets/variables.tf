variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "buckets" {
  description = "Map of storage buckets to create"
  type = map(object({
    name                        = string
    location                    = string
    storage_class               = string
    uniform_bucket_level_access = bool
    enable_versioning           = bool
    kms_key_name                = optional(string)
    labels                      = map(string)
    lifecycle_rules = list(object({
      action_type = string
      age         = number
    }))
    cors = optional(object({
      origin          = list(string)
      method          = list(string)
      response_header = list(string)
      max_age_seconds = number
    }))
  }))
  default = {}
}

variable "bucket_iam_bindings" {
  description = "Map of bucket IAM bindings"
  type = map(object({
    bucket_key = string
    role       = string
    members    = list(string)
  }))
  default = {}
}

variable "bucket_objects" {
  description = "Map of bucket objects to create"
  type = map(object({
    name         = string
    bucket_key   = string
    source       = optional(string)
    content      = optional(string)
    content_type = string
    kms_key_name = optional(string)
  }))
  default = {}
}

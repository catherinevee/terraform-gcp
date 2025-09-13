# Cloud Storage Module Variables

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "buckets" {
  description = "Map of storage buckets to create"
  type = map(object({
    name          = string
    location      = string
    storage_class = string
    force_destroy = bool
    labels        = map(string)
    versioning = optional(object({
      enabled = bool
    }))
    lifecycle_rule = optional(list(object({
      action = object({
        type = string
      })
      condition = object({
        age = number
      })
    })))
    cors = optional(list(object({
      origin          = list(string)
      method          = list(string)
      response_header = list(string)
      max_age_seconds = number
    })))
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
    bucket_key   = string
    name         = string
    content      = string
    content_type = string
  }))
  default = {}
}



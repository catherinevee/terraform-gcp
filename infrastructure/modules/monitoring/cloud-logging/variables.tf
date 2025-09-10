variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "log_sinks" {
  description = "Map of log sinks to create"
  type = map(object({
    name        = string
    destination = string
    filter      = string
    unique_writer_identity = bool
    bigquery_options = optional(object({
      use_partitioned_tables = bool
    }))
    exclusions = list(object({
      name        = string
      description = string
      filter      = string
      disabled    = bool
    }))
  }))
  default = {}
}

variable "log_metrics" {
  description = "Map of log metrics to create"
  type = map(object({
    name   = string
    filter = string
    description = string
    label_extractors = map(string)
    bucket_options = optional(object({
      linear_buckets = optional(object({
        num_finite_buckets = number
        width              = number
        offset             = number
      }))
      exponential_buckets = optional(object({
        num_finite_buckets = number
        growth_factor      = number
        scale              = number
      }))
      explicit_buckets = optional(object({
        bounds = list(number)
      }))
    }))
    metric_descriptor = optional(object({
      metric_kind = string
      value_type  = string
      labels = list(object({
        key         = string
        value_type  = string
        description = string
      }))
    }))
    value_extractor = optional(string)
  }))
  default = {}
}

variable "log_exclusions" {
  description = "Map of log exclusions to create"
  type = map(object({
    name        = string
    description = string
    filter      = string
    disabled    = bool
  }))
  default = {}
}

variable "log_buckets" {
  description = "Map of log buckets to create"
  type = map(object({
    location      = string
    bucket_id     = string
    description   = string
    retention_days = number
    cmek_settings = optional(object({
      kms_key_name = string
    }))
    index_configs = list(object({
      field_path = string
      type       = string
    }))
  }))
  default = {}
}

variable "folder_sinks" {
  description = "Map of folder sinks to create"
  type = map(object({
    folder     = string
    name       = string
    destination = string
    filter     = string
    unique_writer_identity = bool
    bigquery_options = optional(object({
      use_partitioned_tables = bool
    }))
    exclusions = list(object({
      name        = string
      description = string
      filter      = string
      disabled    = bool
    }))
  }))
  default = {}
}

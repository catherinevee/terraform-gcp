variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "dashboards" {
  description = "Map of monitoring dashboards to create"
  type = map(object({
    display_name = string
    tiles = list(object({
      width  = number
      height = number
      widget = object({
        title = string
        xy_chart = object({
          data_sets = list(object({
            time_series_query = object({
              time_series_filter = object({
                filter = string
                aggregation = object({
                  alignment_period    = string
                  per_series_aligner  = string
                  cross_series_reducer = string
                  group_by_fields     = list(string)
                })
              })
            })
            plot_type = string
            target_axis = string
          }))
          timeshift_duration = string
          y_axis = object({
            label = string
            scale = string
          })
        })
      })
    }))
  }))
  default = {}
}

variable "uptime_checks" {
  description = "Map of uptime checks to create"
  type = map(object({
    display_name = string
    timeout      = string
    period       = string
    host         = string
    path         = string
    port         = number
    request_method = string
    use_ssl      = bool
    validate_ssl = bool
    auth_info = optional(object({
      username = string
      password = string
    }))
    headers = map(string)
    content_matchers = list(object({
      content = string
      matcher = string
    }))
    selected_regions = list(string)
  }))
  default = {}
}

variable "alert_policies" {
  description = "Map of alert policies to create"
  type = map(object({
    display_name = string
    combiner     = string
    enabled      = bool
    condition = object({
      display_name = string
      filter       = string
      duration     = string
      comparison   = string
      threshold_value = number
      aggregation = object({
        alignment_period    = string
        per_series_aligner  = string
        cross_series_reducer = string
        group_by_fields     = list(string)
      })
      trigger = optional(object({
        count = number
      }))
    })
    notification_channels = list(string)
    alert_strategy = optional(object({
      auto_close = string
      notification_rate_limit = optional(object({
        period = string
      }))
    }))
    documentation = optional(object({
      content   = string
      mime_type = string
    }))
  }))
  default = {}
}

variable "notification_channels" {
  description = "Map of notification channels to create"
  type = map(object({
    display_name = string
    type         = string
    labels       = map(string)
    sensitive_labels = optional(object({
      auth_token  = optional(string)
      password    = optional(string)
      service_key = optional(string)
    }))
    enabled = bool
  }))
  default = {}
}

variable "services" {
  description = "Map of services to monitor"
  type = map(object({
    service_id   = string
    display_name = string
    telemetry = optional(object({
      resource_name = string
    }))
    user_labels = map(string)
  }))
  default = {}
}

variable "slos" {
  description = "Map of Service Level Objectives to create"
  type = map(object({
    service_key = string
    slo_id      = string
    display_name = string
    goal        = number
    rolling_period_days = number
    basic_sli = optional(object({
      availability = optional(object({
        enabled = bool
      }))
      latency = optional(object({
        threshold = string
      }))
    }))
    request_based_sli = optional(object({
      total_service_filter = string
      good_service_filter  = string
    }))
  }))
  default = {}
}

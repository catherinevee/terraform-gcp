variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "private_vpc_connection" {
  description = "Private VPC connection for Redis"
  type        = string
}

variable "instances" {
  description = "Map of Redis instances to create"
  type = map(object({
    name                    = string
    tier                    = string
    memory_size_gb          = number
    region                  = string
    location_id             = string
    alternative_location_id = optional(string)
    redis_version           = string
    display_name            = string
    reserved_ip_range       = string
    auth_enabled            = bool
    maintenance_policy = optional(object({
      day          = string
      start_hour   = number
      start_minute = number
      start_second = number
      start_nanos  = number
    }))
    persistence_config = optional(object({
      persistence_mode    = string
      rdb_snapshot_period = string
    }))
    redis_configs = map(string)
  }))
  default = {}
}

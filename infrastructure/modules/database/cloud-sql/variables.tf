variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "private_vpc_connection" {
  description = "Private VPC connection for Cloud SQL"
  type        = string
}

variable "instances" {
  description = "Map of Cloud SQL instances to create"
  type = map(object({
    name                           = string
    database_version               = string
    region                         = string
    tier                           = string
    availability_type              = string
    disk_type                      = string
    disk_size                      = number
    disk_autoresize                = bool
    disk_autoresize_limit          = number
    deletion_protection            = bool
    backup_enabled                 = bool
    backup_start_time              = string
    backup_location                = string
    point_in_time_recovery_enabled = bool
    transaction_log_retention_days = number
    backup_retention_settings = optional(object({
      retained_backups = number
      retention_unit   = string
    }))
    ipv4_enabled                                  = bool
    private_network                               = string
    enable_private_path_for_google_cloud_services = bool
    require_ssl                                   = bool
    authorized_networks = list(object({
      name  = string
      value = string
    }))
    database_flags = list(object({
      name  = string
      value = string
    }))
    insights_config = optional(object({
      query_insights_enabled  = bool
      query_string_length     = number
      record_application_tags = bool
      record_client_address   = bool
    }))
    maintenance_window = optional(object({
      day          = number
      hour         = number
      update_track = string
    }))
  }))
  default = {}
}

variable "databases" {
  description = "Map of databases to create"
  type = map(object({
    name         = string
    instance_key = string
  }))
  default = {}
}

variable "users" {
  description = "Map of database users to create"
  type = map(object({
    name         = string
    instance_key = string
    password     = string
  }))
  default = {}
}

variable "ssl_certs" {
  description = "Map of SSL certificates to create"
  type = map(object({
    common_name  = string
    instance_key = string
  }))
  default = {}
}

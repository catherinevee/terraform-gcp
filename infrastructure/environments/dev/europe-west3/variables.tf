# Regional Variables for us-east1

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west3"
}

# Regional configuration variables
variable "instance_group_target_size" {
  description = "Target size for instance groups"
  type        = number
  default     = 2
  validation {
    condition     = var.instance_group_target_size >= 1 && var.instance_group_target_size <= 10
    error_message = "Instance group target size must be between 1 and 10."
  }
}

variable "health_check_interval_sec" {
  description = "Health check interval in seconds"
  type        = number
  default     = 10
  validation {
    condition     = var.health_check_interval_sec >= 5 && var.health_check_interval_sec <= 60
    error_message = "Health check interval must be between 5 and 60 seconds."
  }
}

variable "health_check_timeout_sec" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
  validation {
    condition     = var.health_check_timeout_sec >= 1 && var.health_check_timeout_sec <= 30
    error_message = "Health check timeout must be between 1 and 30 seconds."
  }
}

variable "health_check_port" {
  description = "Health check port"
  type        = number
  default     = 80
  validation {
    condition     = var.health_check_port >= 1 && var.health_check_port <= 65535
    error_message = "Health check port must be between 1 and 65535."
  }
}

variable "autoscaler_cooldown_period" {
  description = "Autoscaler cooldown period in seconds"
  type        = number
  default     = 60
  validation {
    condition     = var.autoscaler_cooldown_period >= 30 && var.autoscaler_cooldown_period <= 300
    error_message = "Autoscaler cooldown period must be between 30 and 300 seconds."
  }
}

# Compute Configuration
variable "default_disk_size_gb" {
  description = "Default disk size in GB for compute instances"
  type        = number
  default     = 20
  validation {
    condition     = var.default_disk_size_gb >= 10 && var.default_disk_size_gb <= 1000
    error_message = "Disk size must be between 10 and 1000 GB."
  }
}

variable "health_check_initial_delay_sec" {
  description = "Initial delay for health checks in seconds"
  type        = number
  default     = 300
  validation {
    condition     = var.health_check_initial_delay_sec >= 60 && var.health_check_initial_delay_sec <= 600
    error_message = "Initial delay must be between 60 and 600 seconds."
  }
}

variable "autoscaler_cpu_target" {
  description = "CPU utilization target for autoscalers"
  type        = number
  default     = 70
  validation {
    condition     = var.autoscaler_cpu_target >= 50 && var.autoscaler_cpu_target <= 90
    error_message = "CPU target must be between 50 and 90 percent."
  }
}

# Storage Configuration
variable "storage_lifecycle_age_days" {
  description = "Age in days for storage lifecycle policies"
  type        = number
  default     = 365
  validation {
    condition     = var.storage_lifecycle_age_days >= 30 && var.storage_lifecycle_age_days <= 2555
    error_message = "Lifecycle age must be between 30 and 2555 days (7 years)."
  }
}

variable "storage_cors_max_age_seconds" {
  description = "Maximum age for CORS preflight requests"
  type        = number
  default     = 3600
  validation {
    condition     = var.storage_cors_max_age_seconds >= 0 && var.storage_cors_max_age_seconds <= 86400
    error_message = "CORS max age must be between 0 and 86400 seconds (24 hours)."
  }
}

variable "storage_short_term_age_days" {
  description = "Age in days for short-term storage lifecycle policies"
  type        = number
  default     = 90
  validation {
    condition     = var.storage_short_term_age_days >= 7 && var.storage_short_term_age_days <= 365
    error_message = "Short-term storage age must be between 7 and 365 days."
  }
}


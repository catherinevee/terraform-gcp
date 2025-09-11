variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for Cloud Run services"
  type        = string
}

variable "private_vpc_connection" {
  description = "Private VPC connection for Cloud Run"
  type        = string
}

variable "vpc_connector" {
  description = "VPC connector for Cloud Run"
  type        = string
  default     = null
}

variable "services" {
  description = "Map of Cloud Run services to create"
  type = map(object({
    name              = string
    location          = string
    image             = string
    container_port    = number
    environment       = string
    cpu_limit         = string
    memory_limit      = string
    cpu_idle          = bool
    min_instances     = number
    max_instances     = number
    timeout           = string
    health_check_path = string
    env_vars = list(object({
      name  = string
      value = string
    }))
  }))
  default = {}
}

variable "iam_policies" {
  description = "Map of IAM policies for Cloud Run services"
  type = map(object({
    service_key = string
    policy_data = string
  }))
  default = {}
}

# Health Check Configuration
variable "health_check_initial_delay_seconds" {
  description = "Initial delay for health checks in seconds"
  type        = number
  default     = 30
  validation {
    condition     = var.health_check_initial_delay_seconds >= 0 && var.health_check_initial_delay_seconds <= 300
    error_message = "Health check initial delay must be between 0 and 300 seconds."
  }
}

variable "health_check_timeout_seconds" {
  description = "Timeout for health checks in seconds"
  type        = number
  default     = 1
  validation {
    condition     = var.health_check_timeout_seconds >= 1 && var.health_check_timeout_seconds <= 60
    error_message = "Health check timeout must be between 1 and 60 seconds."
  }
}

variable "health_check_period_seconds" {
  description = "Period between health checks in seconds"
  type        = number
  default     = 3
  validation {
    condition     = var.health_check_period_seconds >= 1 && var.health_check_period_seconds <= 60
    error_message = "Health check period must be between 1 and 60 seconds."
  }
}

variable "health_check_failure_threshold" {
  description = "Number of consecutive failures before marking unhealthy"
  type        = number
  default     = 1
  validation {
    condition     = var.health_check_failure_threshold >= 1 && var.health_check_failure_threshold <= 10
    error_message = "Health check failure threshold must be between 1 and 10."
  }
}

# Traffic Configuration
variable "traffic_percent" {
  description = "Percentage of traffic to route to the service"
  type        = number
  default     = 100
  validation {
    condition     = var.traffic_percent >= 0 && var.traffic_percent <= 100
    error_message = "Traffic percent must be between 0 and 100."
  }
}
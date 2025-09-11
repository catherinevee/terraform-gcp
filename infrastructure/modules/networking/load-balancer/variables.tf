# Load Balancer Module Variables

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "global_ip_name" {
  description = "Global IP address name"
  type        = string
}

variable "health_check_name" {
  description = "Health check name"
  type        = string
}

variable "backend_service_name" {
  description = "Backend service name"
  type        = string
}

variable "url_map_name" {
  description = "URL map name"
  type        = string
}

variable "forwarding_rule_name" {
  description = "Forwarding rule name"
  type        = string
}

variable "backend_regions" {
  description = "Backend regions"
  type        = list(string)
  default     = []
}

variable "health_check_config" {
  description = "Health check configuration"
  type = object({
    check_interval_sec  = number
    timeout_sec         = number
    healthy_threshold   = number
    unhealthy_threshold = number
    port                = number
    request_path        = string
  })
  default = {
    check_interval_sec  = 10
    timeout_sec         = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    port                = 80
    request_path        = "/"
  }
}

variable "backend_service_timeout_sec" {
  description = "Backend service timeout in seconds"
  type        = number
  default     = 30
  validation {
    condition     = var.backend_service_timeout_sec >= 1 && var.backend_service_timeout_sec <= 86400
    error_message = "Backend service timeout must be between 1 and 86400 seconds (24 hours)."
  }
}


variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "enable_load_balancer" {
  description = "Enable load balancer"
  type        = bool
  default     = true
}

variable "global_ip_name" {
  description = "Name for the global IP address"
  type        = string
  default     = "lb-global-ip"
}

variable "ip_version" {
  description = "IP version for the global IP address"
  type        = string
  default     = "IPV4"
}

variable "health_check_name" {
  description = "Name for the health check"
  type        = string
  default     = "lb-health-check"
}

variable "health_check_description" {
  description = "Description for the health check"
  type        = string
  default     = "Health check for load balancer"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 5
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive successful health checks"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive failed health checks"
  type        = number
  default     = 2
}

variable "health_check_port" {
  description = "Port for health check"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Path for health check"
  type        = string
  default     = "/"
}

variable "backend_service_name" {
  description = "Name for the backend service"
  type        = string
  default     = "lb-backend-service"
}

variable "backend_service_description" {
  description = "Description for the backend service"
  type        = string
  default     = "Backend service for load balancer"
}

variable "backend_service_protocol" {
  description = "Protocol for the backend service"
  type        = string
  default     = "HTTP"
}

variable "backend_service_port_name" {
  description = "Port name for the backend service"
  type        = string
  default     = "http"
}

variable "backend_groups" {
  description = "List of backend groups"
  type = list(object({
    group           = string
    balancing_mode  = string
    capacity_scaler = number
    max_utilization = number
  }))
  default = []
}

variable "enable_logging" {
  description = "Enable logging for the backend service"
  type        = bool
  default     = true
}

variable "log_sample_rate" {
  description = "Sample rate for logging"
  type        = number
  default     = 1.0
}

variable "url_map_name" {
  description = "Name for the URL map"
  type        = string
  default     = "lb-url-map"
}

variable "url_map_description" {
  description = "Description for the URL map"
  type        = string
  default     = "URL map for load balancer"
}

variable "host_rules" {
  description = "List of host rules"
  type = list(object({
    hosts        = list(string)
    path_matcher = string
  }))
  default = []
}

variable "path_matchers" {
  description = "List of path matchers"
  type = list(object({
    name            = string
    default_service = string
    path_rules = list(object({
      paths   = list(string)
      service = string
    }))
  }))
  default = []
}

variable "enable_https" {
  description = "Enable HTTPS"
  type        = bool
  default     = false
}

variable "https_proxy_name" {
  description = "Name for the HTTPS proxy"
  type        = string
  default     = "lb-https-proxy"
}

variable "http_proxy_name" {
  description = "Name for the HTTP proxy"
  type        = string
  default     = "lb-http-proxy"
}

variable "ssl_certificates" {
  description = "List of SSL certificates"
  type        = list(string)
  default     = []
}

variable "forwarding_rule_name" {
  description = "Name for the forwarding rule"
  type        = string
  default     = "lb-forwarding-rule"
}

variable "port_range" {
  description = "Port range for the forwarding rule"
  type        = string
  default     = "80"
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "routing_mode" {
  description = "The network routing mode (default 'REGIONAL')"
  type        = string
  default     = "REGIONAL"
}

variable "delete_default_routes_on_create" {
  description = "If set to true, default routes (0.0.0.0/0) will be deleted immediately after network creation"
  type        = bool
  default     = false
}

variable "private_ip_google_access_prefix_length" {
  description = "Prefix length for private IP Google access"
  type        = number
  default     = 16
  validation {
    condition     = var.private_ip_google_access_prefix_length >= 8 && var.private_ip_google_access_prefix_length <= 30
    error_message = "Private IP Google access prefix length must be between 8 and 30."
  }
}

variable "enable_service_networking" {
  description = "Enable service networking connection (requires elevated permissions)"
  type        = bool
  default     = false
}
# Cross-Region Networking Variables

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "primary_region" {
  description = "Primary GCP region"
  type        = string
}

variable "secondary_region" {
  description = "Secondary GCP region"
  type        = string
}

variable "primary_network_self_link" {
  description = "Self-link of the primary region VPC network"
  type        = string
}

variable "secondary_network_self_link" {
  description = "Self-link of the secondary region VPC network"
  type        = string
}

variable "vpn_shared_secret" {
  description = "Shared secret for VPN tunnels"
  type        = string
  sensitive   = true
}

variable "vpn_route_priority" {
  description = "Priority for VPN routes"
  type        = number
  default     = 1000
  validation {
    condition     = var.vpn_route_priority >= 0 && var.vpn_route_priority <= 65535
    error_message = "VPN route priority must be between 0 and 65535."
  }
}


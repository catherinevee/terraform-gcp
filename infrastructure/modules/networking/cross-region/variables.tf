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
  default     = "your-vpn-shared-secret-here"
}


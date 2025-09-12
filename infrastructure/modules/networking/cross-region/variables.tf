# Cross-Region Networking Variables
# Simplified for single global VPC architecture

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
  description = "Self-link of the global VPC network"
  type        = string
}

variable "secondary_network_self_link" {
  description = "Self-link of the global VPC network (same as primary for single VPC)"
  type        = string
}


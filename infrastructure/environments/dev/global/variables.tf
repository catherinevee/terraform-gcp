# Global Variables for Multi-Region Deployment

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "primary_region" {
  description = "Primary GCP region"
  type        = string
  default     = "us-central1"
}

variable "secondary_region" {
  description = "Secondary GCP region"
  type        = string
  default     = "us-east1"
}

variable "dns_zone_name" {
  description = "DNS zone name"
  type        = string
  default     = "acme-ecommerce-dev-com"
}

variable "dns_name" {
  description = "DNS name for the zone"
  type        = string
  default     = "dev.acme-ecommerce.com."
}

variable "organization" {
  description = "Organization name"
  type        = string
  default     = "acme-corp"
}

variable "business_unit" {
  description = "Business unit name"
  type        = string
  default     = "ecommerce"
}

variable "application" {
  description = "Application name"
  type        = string
  default     = "ecommerce-platform"
}


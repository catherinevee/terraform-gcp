# DNS Module Variables

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "zone_name" {
  description = "DNS zone name"
  type        = string
}

variable "dns_name" {
  description = "DNS name for the zone"
  type        = string
}

variable "load_balancer_ip" {
  description = "Load balancer IP address"
  type        = string
}

variable "records" {
  description = "DNS records to create"
  type = map(object({
    name = string
    type = string
    ttl  = number
  }))
  default = {}
}



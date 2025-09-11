variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "organization_id" {
  description = "GCP Organization ID"
  type        = string
}

variable "enable_vpc_service_controls" {
  description = "Enable VPC Service Controls"
  type        = bool
  default     = false
}

variable "access_policy_title" {
  description = "Access Policy title"
  type        = string
  default     = "Default Access Policy"
}

variable "service_perimeter_name" {
  description = "Service Perimeter name"
  type        = string
  default     = "default_perimeter"
}

variable "service_perimeter_title" {
  description = "Service Perimeter title"
  type        = string
  default     = "Default Service Perimeter"
}

variable "service_perimeter_resources" {
  description = "Service Perimeter resources"
  type        = list(string)
  default     = []
}

variable "restricted_services" {
  description = "Restricted services"
  type        = list(string)
  default     = ["storage.googleapis.com"]
}

variable "enable_vpc_accessible_services" {
  description = "Enable VPC accessible services"
  type        = bool
  default     = false
}

variable "vpc_accessible_services_enable_restriction" {
  description = "Enable VPC accessible services restriction"
  type        = bool
  default     = true
}

variable "vpc_accessible_services_allowed" {
  description = "VPC accessible services allowed"
  type        = list(string)
  default     = []
}

variable "ingress_policies" {
  description = "Ingress policies"
  type = list(object({
    ingress_from = list(object({
      access_level = string
    }))
    ingress_to = list(object({
      resources    = list(string)
      service_name = string
    }))
  }))
  default = []
}

variable "egress_policies" {
  description = "Egress policies"
  type = list(object({
    egress_from = list(object({
      identities = list(string)
    }))
    egress_to = list(object({
      resources    = list(string)
      service_name = string
    }))
  }))
  default = []
}

variable "enable_access_level" {
  description = "Enable access level"
  type        = bool
  default     = false
}

variable "access_level_name" {
  description = "Access level name"
  type        = string
  default     = "default_access_level"
}

variable "access_level_title" {
  description = "Access level title"
  type        = string
  default     = "Default Access Level"
}

variable "access_level_ip_subnetworks" {
  description = "Access level IP subnetworks"
  type        = list(string)
  default     = []
}

variable "access_level_members" {
  description = "Access level members"
  type        = list(string)
  default     = []
}

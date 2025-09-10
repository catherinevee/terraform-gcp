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
    name                = string
    location            = string
    image               = string
    container_port      = number
    environment         = string
    cpu_limit           = string
    memory_limit        = string
    cpu_idle            = bool
    min_instances       = number
    max_instances       = number
    timeout             = string
    health_check_path   = string
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

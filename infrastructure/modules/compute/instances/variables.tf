variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "network_name" {
  description = "VPC network name"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "instance_templates" {
  description = "Map of instance templates to create"
  type = map(object({
    name_prefix              = string
    description              = string
    machine_type             = string
    source_image             = string
    disk_size_gb             = number
    disk_type                = string
    subnetwork               = string
    enable_external_ip       = bool
    service_account_email    = string
    service_account_scopes   = list(string)
    metadata                 = map(string)
    startup_script           = string
    tags                     = list(string)
  }))
  default = {}
}

variable "instance_group_managers" {
  description = "Map of instance group managers to create"
  type = map(object({
    name                    = string
    description             = string
    base_instance_name      = string
    zone                    = string
    template_key            = string
    target_size             = number
    enable_auto_healing     = bool
    health_check_key        = string
    initial_delay_sec       = number
    update_policy = optional(object({
      type                         = string
      instance_redistribution_type = string
      minimal_action               = string
      max_surge_fixed              = number
      max_unavailable_fixed        = number
    }))
  }))
  default = {}
}

variable "health_checks" {
  description = "Map of health checks to create"
  type = map(object({
    name                = string
    description         = string
    check_interval_sec  = number
    timeout_sec         = number
    healthy_threshold   = number
    unhealthy_threshold = number
    port                = number
    request_path        = string
  }))
  default = {}
}

variable "autoscalers" {
  description = "Map of autoscalers to create"
  type = map(object({
    name                        = string
    zone                        = string
    instance_group_manager_key  = string
    max_replicas                = number
    min_replicas                = number
    cooldown_period             = number
    cpu_utilization = optional(object({
      target = number
    }))
    load_balancing_utilization = optional(object({
      target = number
    }))
  }))
  default = {}
}

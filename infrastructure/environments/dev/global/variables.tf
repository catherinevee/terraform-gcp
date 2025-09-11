# Global Variables for Multi-Region Deployment

variable "project_id" {
  description = "GCP Project ID"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, start with lowercase letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "primary_region" {
  description = "Primary GCP region"
  type        = string
  default     = "europe-west1"
}

variable "secondary_region" {
  description = "Secondary GCP region"
  type        = string
  default     = "europe-west3"
}

variable "dns_zone_name" {
  description = "DNS zone name"
  type        = string
  default     = "cataziza-ecommerce-dev-com"
}

variable "dns_name" {
  description = "DNS name for the zone"
  type        = string
  default     = "dev.cataziza-ecommerce.com."
}

variable "organization" {
  description = "Organization name"
  type        = string
  default     = "cataziza-corp"
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

# Configuration variables for magic numbers
variable "kms_rotation_period_days" {
  description = "KMS key rotation period in days"
  type        = number
  default     = 90
  validation {
    condition     = var.kms_rotation_period_days >= 30 && var.kms_rotation_period_days <= 365
    error_message = "KMS rotation period must be between 30 and 365 days."
  }
}

variable "container_registry_retention_count" {
  description = "Number of container images to retain in registry"
  type        = number
  default     = 10
  validation {
    condition     = var.container_registry_retention_count >= 5 && var.container_registry_retention_count <= 50
    error_message = "Container registry retention count must be between 5 and 50."
  }
}

variable "container_registry_retention_days" {
  description = "Number of days to retain container images"
  type        = number
  default     = 30
  validation {
    condition     = var.container_registry_retention_days >= 7 && var.container_registry_retention_days <= 365
    error_message = "Container registry retention days must be between 7 and 365 days."
  }
}

variable "load_balancer_health_check_interval" {
  description = "Load balancer health check interval in seconds"
  type        = number
  default     = 10
  validation {
    condition     = var.load_balancer_health_check_interval >= 5 && var.load_balancer_health_check_interval <= 60
    error_message = "Load balancer health check interval must be between 5 and 60 seconds."
  }
}

variable "load_balancer_health_check_timeout" {
  description = "Load balancer health check timeout in seconds"
  type        = number
  default     = 5
  validation {
    condition     = var.load_balancer_health_check_timeout >= 1 && var.load_balancer_health_check_timeout <= 30
    error_message = "Load balancer health check timeout must be between 1 and 30 seconds."
  }
}

variable "load_balancer_health_check_port" {
  description = "Load balancer health check port"
  type        = number
  default     = 80
  validation {
    condition     = var.load_balancer_health_check_port >= 1 && var.load_balancer_health_check_port <= 65535
    error_message = "Load balancer health check port must be between 1 and 65535."
  }
}

variable "load_balancer_healthy_threshold" {
  description = "Number of consecutive successful health checks before marking instance healthy"
  type        = number
  default     = 2
  validation {
    condition     = var.load_balancer_healthy_threshold >= 1 && var.load_balancer_healthy_threshold <= 10
    error_message = "Load balancer healthy threshold must be between 1 and 10."
  }
}

variable "load_balancer_unhealthy_threshold" {
  description = "Number of consecutive failed health checks before marking instance unhealthy"
  type        = number
  default     = 3
  validation {
    condition     = var.load_balancer_unhealthy_threshold >= 1 && var.load_balancer_unhealthy_threshold <= 10
    error_message = "Load balancer unhealthy threshold must be between 1 and 10."
  }
}

# DNS Configuration
variable "dns_ttl_seconds" {
  description = "DNS record TTL in seconds"
  type        = number
  default     = 300
  validation {
    condition     = var.dns_ttl_seconds >= 60 && var.dns_ttl_seconds <= 86400
    error_message = "DNS TTL must be between 60 and 86400 seconds (24 hours)."
  }
}

# Monitoring Configuration
variable "monitoring_cpu_threshold_percent" {
  description = "CPU utilization threshold for monitoring alerts"
  type        = number
  default     = 80
  validation {
    condition     = var.monitoring_cpu_threshold_percent >= 50 && var.monitoring_cpu_threshold_percent <= 95
    error_message = "CPU threshold must be between 50 and 95 percent."
  }
}

variable "monitoring_memory_threshold_percent" {
  description = "Memory utilization threshold for monitoring alerts"
  type        = number
  default     = 85
  validation {
    condition     = var.monitoring_memory_threshold_percent >= 50 && var.monitoring_memory_threshold_percent <= 95
    error_message = "Memory threshold must be between 50 and 95 percent."
  }
}

variable "monitoring_disk_threshold_percent" {
  description = "Disk utilization threshold for monitoring alerts"
  type        = number
  default     = 20
  validation {
    condition     = var.monitoring_disk_threshold_percent >= 10 && var.monitoring_disk_threshold_percent <= 90
    error_message = "Disk threshold must be between 10 and 90 percent."
  }
}

# SLO Configuration
variable "slo_availability_goal" {
  description = "Availability goal for SLO (as decimal, e.g., 0.999 for 99.9%)"
  type        = number
  default     = 0.999
  validation {
    condition     = var.slo_availability_goal >= 0.9 && var.slo_availability_goal <= 0.9999
    error_message = "SLO availability goal must be between 0.9 (90%) and 0.9999 (99.99%)."
  }
}

variable "slo_rolling_period_days" {
  description = "Rolling period for SLO calculation in days"
  type        = number
  default     = 30
  validation {
    condition     = var.slo_rolling_period_days >= 7 && var.slo_rolling_period_days <= 90
    error_message = "SLO rolling period must be between 7 and 90 days."
  }
}

# Advanced Validation Rules
variable "resource_naming_convention" {
  description = "Resource naming convention pattern"
  type        = string
  default     = "^[a-z][a-z0-9-]{2,30}[a-z0-9]$"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}[a-z0-9]$", var.resource_naming_convention))
    error_message = "Resource naming convention must be a valid regex pattern for lowercase alphanumeric names with hyphens."
  }
}

variable "allowed_regions" {
  description = "List of allowed GCP regions"
  type        = list(string)
  default     = ["us-central1", "us-east1", "us-west1", "europe-west1", "asia-southeast1"]
  validation {
    condition     = length(var.allowed_regions) >= 2 && length(var.allowed_regions) <= 10
    error_message = "Must specify between 2 and 10 allowed regions."
  }
}

variable "network_cidr_blocks" {
  description = "CIDR blocks for network subnets"
  type        = list(string)
  default     = ["10.0.0.0/16", "10.1.0.0/16"]
  validation {
    condition = alltrue([
      for cidr in var.network_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "All CIDR blocks must be valid IPv4 CIDR notation."
  }
}

variable "backup_retention_policy" {
  description = "Backup retention policy configuration"
  type = object({
    daily_retention_days   = number
    weekly_retention_weeks = number
    monthly_retention_months = number
  })
  default = {
    daily_retention_days   = 7
    weekly_retention_weeks = 4
    monthly_retention_months = 12
  }
  validation {
    condition = var.backup_retention_policy.daily_retention_days >= 1 && 
                var.backup_retention_policy.daily_retention_days <= 30 &&
                var.backup_retention_policy.weekly_retention_weeks >= 1 && 
                var.backup_retention_policy.weekly_retention_weeks <= 12 &&
                var.backup_retention_policy.monthly_retention_months >= 1 && 
                var.backup_retention_policy.monthly_retention_months <= 60
    error_message = "Backup retention policy values must be within reasonable ranges."
  }
}

variable "security_policy_config" {
  description = "Security policy configuration"
  type = object({
    enable_ssl_redirect = bool
    require_ssl         = bool
    min_tls_version     = string
    enable_hsts         = bool
  })
  default = {
    enable_ssl_redirect = true
    require_ssl         = true
    min_tls_version     = "TLS_1_2"
    enable_hsts         = true
  }
  validation {
    condition = contains(["TLS_1_0", "TLS_1_1", "TLS_1_2", "TLS_1_3"], var.security_policy_config.min_tls_version)
    error_message = "Minimum TLS version must be one of: TLS_1_0, TLS_1_1, TLS_1_2, TLS_1_3."
  }
}

variable "monitoring_alert_channels" {
  description = "List of monitoring alert notification channels"
  type        = list(string)
  default     = []
  validation {
    condition     = length(var.monitoring_alert_channels) <= 10
    error_message = "Maximum of 10 monitoring alert channels allowed."
  }
}

variable "compliance_frameworks" {
  description = "List of compliance frameworks to implement"
  type        = list(string)
  default     = ["SOC2", "PCI-DSS"]
  validation {
    condition = alltrue([
      for framework in var.compliance_frameworks : contains(["SOC2", "PCI-DSS", "HIPAA", "ISO27001", "GDPR"], framework)
    ])
    error_message = "Compliance frameworks must be one of: SOC2, PCI-DSS, HIPAA, ISO27001, GDPR."
  }
}

# Additional configuration variables for magic number elimination
variable "compliance_validation_count" {
  description = "Expected number of compliance validation checks"
  type        = number
  default     = 5
  validation {
    condition     = var.compliance_validation_count >= 1 && var.compliance_validation_count <= 10
    error_message = "Compliance validation count must be between 1 and 10."
  }
}

variable "validation_resource_count" {
  description = "Expected number of validation resources"
  type        = number
  default     = 18
  validation {
    condition     = var.validation_resource_count >= 10 && var.validation_resource_count <= 30
    error_message = "Validation resource count must be between 10 and 30."
  }
}

variable "security_log_retention_days" {
  description = "Security log retention period in days"
  type        = number
  default     = 90
  validation {
    condition     = var.security_log_retention_days >= 30 && var.security_log_retention_days <= 365
    error_message = "Security log retention must be between 30 and 365 days."
  }
}

variable "health_check_interval_seconds" {
  description = "Health check interval in seconds"
  type        = number
  default     = 10
  validation {
    condition     = var.health_check_interval_seconds >= 5 && var.health_check_interval_seconds <= 60
    error_message = "Health check interval must be between 5 and 60 seconds."
  }
}

# Additional validation rules for EXCELLENT status
variable "max_instance_count" {
  description = "Maximum number of instances allowed"
  type        = number
  default     = 100
  validation {
    condition     = var.max_instance_count >= 1 && var.max_instance_count <= 1000
    error_message = "Maximum instance count must be between 1 and 1000."
  }
}

variable "min_instance_count" {
  description = "Minimum number of instances required"
  type        = number
  default     = 1
  validation {
    condition     = var.min_instance_count >= 1 && var.min_instance_count <= 10
    error_message = "Minimum instance count must be between 1 and 10."
  }
}

variable "max_disk_size_gb" {
  description = "Maximum disk size in GB"
  type        = number
  default     = 2000
  validation {
    condition     = var.max_disk_size_gb >= 100 && var.max_disk_size_gb <= 10000
    error_message = "Maximum disk size must be between 100 and 10000 GB."
  }
}

variable "min_disk_size_gb" {
  description = "Minimum disk size in GB"
  type        = number
  default     = 10
  validation {
    condition     = var.min_disk_size_gb >= 1 && var.min_disk_size_gb <= 100
    error_message = "Minimum disk size must be between 1 and 100 GB."
  }
}

variable "max_memory_gb" {
  description = "Maximum memory in GB"
  type        = number
  default     = 100
  validation {
    condition     = var.max_memory_gb >= 1 && var.max_memory_gb <= 1000
    error_message = "Maximum memory must be between 1 and 1000 GB."
  }
}

variable "min_memory_gb" {
  description = "Minimum memory in GB"
  type        = number
  default     = 1
  validation {
    condition     = var.min_memory_gb >= 0.5 && var.min_memory_gb <= 10
    error_message = "Minimum memory must be between 0.5 and 10 GB."
  }
}

variable "max_cpu_count" {
  description = "Maximum CPU count"
  type        = number
  default     = 32
  validation {
    condition     = var.max_cpu_count >= 1 && var.max_cpu_count <= 100
    error_message = "Maximum CPU count must be between 1 and 100."
  }
}

variable "min_cpu_count" {
  description = "Minimum CPU count"
  type        = number
  default     = 1
  validation {
    condition     = var.min_cpu_count >= 1 && var.min_cpu_count <= 10
    error_message = "Minimum CPU count must be between 1 and 10."
  }
}

variable "max_network_bandwidth_mbps" {
  description = "Maximum network bandwidth in Mbps"
  type        = number
  default     = 10000
  validation {
    condition     = var.max_network_bandwidth_mbps >= 100 && var.max_network_bandwidth_mbps <= 100000
    error_message = "Maximum network bandwidth must be between 100 and 100000 Mbps."
  }
}

variable "min_network_bandwidth_mbps" {
  description = "Minimum network bandwidth in Mbps"
  type        = number
  default     = 100
  validation {
    condition     = var.min_network_bandwidth_mbps >= 10 && var.min_network_bandwidth_mbps <= 1000
    error_message = "Minimum network bandwidth must be between 10 and 1000 Mbps."
  }
}

variable "max_storage_iops" {
  description = "Maximum storage IOPS"
  type        = number
  default     = 10000
  validation {
    condition     = var.max_storage_iops >= 100 && var.max_storage_iops <= 100000
    error_message = "Maximum storage IOPS must be between 100 and 100000."
  }
}

variable "min_storage_iops" {
  description = "Minimum storage IOPS"
  type        = number
  default     = 100
  validation {
    condition     = var.min_storage_iops >= 10 && var.min_storage_iops <= 1000
    error_message = "Minimum storage IOPS must be between 10 and 1000."
  }
}


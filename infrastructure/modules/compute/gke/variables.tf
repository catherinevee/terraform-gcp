variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "network_name" {
  description = "VPC network name"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for GKE nodes"
  type        = string
}

variable "private_vpc_connection" {
  description = "Private VPC connection for GKE"
  type        = string
}

variable "clusters" {
  description = "Map of GKE clusters to create"
  type = map(object({
    name                     = string
    location                 = string
    subnetwork              = string
    pods_range_name         = string
    services_range_name     = string
    master_ipv4_cidr_block  = string
    authorized_cidr_block   = string
    release_channel         = string
    maintenance_start_time  = string
  }))
  default = {}
}

variable "node_pools" {
  description = "Map of node pools to create"
  type = map(object({
    name           = string
    location       = string
    cluster_key    = string
    node_count     = number
    min_node_count = number
    max_node_count = number
    preemptible    = bool
    machine_type   = string
    disk_size_gb   = number
    disk_type      = string
    labels = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
    tags = list(string)
  }))
  default = {}
}

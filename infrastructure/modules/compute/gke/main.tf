# GKE Cluster
resource "google_container_cluster" "cluster" {
  for_each = var.clusters
  
  name     = each.value.name
  location = each.value.location
  project  = var.project_id
  
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
  
  # Disable deletion protection for development
  deletion_protection = false
  
  network    = var.network_name
  subnetwork = each.value.subnetwork
  
  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  
  # Enable IP aliasing
  ip_allocation_policy {
    cluster_secondary_range_name  = each.value.pods_range_name
    services_secondary_range_name = each.value.services_range_name
  }
  
  # Enable private cluster
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = each.value.master_ipv4_cidr_block
  }
  
  # Enable master authorized networks
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = each.value.authorized_cidr_block
      display_name = "VPC Network"
    }
  }
  
  # Enable network policy
  network_policy {
    enabled = true
  }
  
  # Enable addons
  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
    
    http_load_balancing {
      disabled = false
    }
    
    network_policy_config {
      disabled = false
    }
    
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }
  
  # Enable binary authorization
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }
  
  # Enable cost management
  cost_management_config {
    enabled = true
  }
  
  # Disable cluster autoscaling for now
  cluster_autoscaling {
    enabled = false
  }
  
  # Enable release channel
  release_channel {
    channel = each.value.release_channel
  }
  
  # Enable maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = each.value.maintenance_start_time
    }
  }
  
  # Enable basic monitoring
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }
  
  # Enable logging
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }
  
  depends_on = [var.private_vpc_connection]
}

# GKE Node Pool
resource "google_container_node_pool" "node_pool" {
  for_each = var.node_pools
  
  name       = each.value.name
  location   = each.value.location
  cluster    = google_container_cluster.cluster[each.value.cluster_key].name
  project    = var.project_id
  node_count = each.value.node_count
  
  # Enable autoscaling
  autoscaling {
    min_node_count = each.value.min_node_count
    max_node_count = each.value.max_node_count
  }
  
  # Enable management
  management {
    auto_repair  = true
    auto_upgrade = true
  }
  
  # Node configuration
  node_config {
    preemptible  = each.value.preemptible
    machine_type = each.value.machine_type
    disk_size_gb = each.value.disk_size_gb
    disk_type    = each.value.disk_type
    
    # Enable workload identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
    
    # Service account
    service_account = var.service_account_email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    
    # Enable secure boot
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
    
    # Labels
    labels = each.value.labels
    
    # Taints
    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }
    
    # Tags
    tags = each.value.tags
  }
  
  # Upgrade settings
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

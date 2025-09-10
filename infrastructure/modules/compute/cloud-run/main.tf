# Cloud Run Services
resource "google_cloud_run_v2_service" "service" {
  for_each = var.services
  
  name     = each.value.name
  location = each.value.location
  project  = var.project_id
  
  template {
    containers {
      image = each.value.image
      
      ports {
        container_port = each.value.container_port
      }
      
      env {
        name  = "ENVIRONMENT"
        value = each.value.environment
      }
      
      env {
        name  = "PROJECT_ID"
        value = var.project_id
      }
      
      dynamic "env" {
        for_each = each.value.env_vars
        content {
          name  = env.value.name
          value = env.value.value
        }
      }
      
      resources {
        limits = {
          cpu    = each.value.cpu_limit
          memory = each.value.memory_limit
        }
        
        cpu_idle = each.value.cpu_idle
      }
      
      startup_probe {
        http_get {
          path = each.value.health_check_path
          port = each.value.container_port
        }
        initial_delay_seconds = 30
        timeout_seconds      = 1
        period_seconds       = 3
        failure_threshold    = 1
      }
      
      liveness_probe {
        http_get {
          path = each.value.health_check_path
          port = each.value.container_port
        }
        initial_delay_seconds = 30
        timeout_seconds      = 1
        period_seconds       = 3
        failure_threshold    = 1
      }
    }
    
    scaling {
      min_instance_count = each.value.min_instances
      max_instance_count = each.value.max_instances
    }
    
    # VPC access configuration - only if connector is provided
    dynamic "vpc_access" {
      for_each = var.vpc_connector != null ? [1] : []
      content {
        connector = var.vpc_connector
        egress    = "PRIVATE_RANGES_ONLY"
      }
    }
    
    service_account = var.service_account_email
    
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    
    timeout = each.value.timeout
  }
  
  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }
  
  depends_on = [var.private_vpc_connection]
}

# Cloud Run IAM Policy
resource "google_cloud_run_service_iam_policy" "policy" {
  for_each = var.iam_policies
  
  location = google_cloud_run_v2_service.service[each.value.service_key].location
  project  = var.project_id
  service  = google_cloud_run_v2_service.service[each.value.service_key].name
  
  policy_data = each.value.policy_data
}

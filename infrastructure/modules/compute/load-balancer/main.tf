# Global IP Address
resource "google_compute_global_address" "global_ip" {
  count = var.enable_load_balancer ? 1 : 0
  
  name         = var.global_ip_name
  project      = var.project_id
  ip_version   = var.ip_version
  address_type = "EXTERNAL"
}

# Health Check
resource "google_compute_health_check" "lb_health_check" {
  count = var.enable_load_balancer ? 1 : 0
  
  name               = var.health_check_name
  description        = var.health_check_description
  check_interval_sec = var.health_check_interval
  timeout_sec        = var.health_check_timeout
  healthy_threshold  = var.health_check_healthy_threshold
  unhealthy_threshold = var.health_check_unhealthy_threshold
  project            = var.project_id
  
  http_health_check {
    port         = var.health_check_port
    request_path = var.health_check_path
  }
}

# Backend Service
resource "google_compute_backend_service" "backend_service" {
  count = var.enable_load_balancer ? 1 : 0
  
  name                  = var.backend_service_name
  description           = var.backend_service_description
  protocol              = var.backend_service_protocol
  port_name             = var.backend_service_port_name
  load_balancing_scheme = "EXTERNAL_MANAGED"
  project               = var.project_id
  
  health_checks = [google_compute_health_check.lb_health_check[0].id]
  
  dynamic "backend" {
    for_each = var.backend_groups
    content {
      group           = backend.value.group
      balancing_mode  = backend.value.balancing_mode
      capacity_scaler = backend.value.capacity_scaler
      max_utilization = backend.value.max_utilization
    }
  }
  
  dynamic "log_config" {
    for_each = var.enable_logging ? [1] : []
    content {
      enable      = true
      sample_rate = var.log_sample_rate
    }
  }
}

# URL Map
resource "google_compute_url_map" "url_map" {
  count = var.enable_load_balancer ? 1 : 0
  
  name            = var.url_map_name
  description     = var.url_map_description
  default_service = google_compute_backend_service.backend_service[0].id
  project         = var.project_id
  
  dynamic "host_rule" {
    for_each = var.host_rules
    content {
      hosts        = host_rule.value.hosts
      path_matcher = host_rule.value.path_matcher
    }
  }
  
  dynamic "path_matcher" {
    for_each = var.path_matchers
    content {
      name            = path_matcher.value.name
      default_service = path_matcher.value.default_service
      
      dynamic "path_rule" {
        for_each = path_matcher.value.path_rules
        content {
          paths   = path_rule.value.paths
          service = path_rule.value.service
        }
      }
    }
  }
}

# HTTP(S) Proxy
resource "google_compute_target_https_proxy" "https_proxy" {
  count = var.enable_load_balancer && var.enable_https ? 1 : 0
  
  name             = var.https_proxy_name
  url_map          = google_compute_url_map.url_map[0].id
  ssl_certificates = var.ssl_certificates
  project          = var.project_id
}

resource "google_compute_target_http_proxy" "http_proxy" {
  count = var.enable_load_balancer && !var.enable_https ? 1 : 0
  
  name    = var.http_proxy_name
  url_map = google_compute_url_map.url_map[0].id
  project = var.project_id
}

# Global Forwarding Rule
resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  count = var.enable_load_balancer ? 1 : 0
  
  name       = var.forwarding_rule_name
  target     = var.enable_https ? google_compute_target_https_proxy.https_proxy[0].id : google_compute_target_http_proxy.http_proxy[0].id
  port_range = var.port_range
  ip_address = google_compute_global_address.global_ip[0].address
  project    = var.project_id
}

# Load Balancer Module for Global Load Balancing

# Global IP Address
resource "google_compute_global_address" "global_ip" {
  name = var.global_ip_name
  
  labels = {
    environment = var.environment
    purpose     = "load-balancer"
    managed_by  = "terraform"
  }
}

# Health Check
resource "google_compute_health_check" "health_check" {
  name = var.health_check_name
  
  http_health_check {
    port         = var.health_check_config.port
    request_path = var.health_check_config.request_path
  }
  
  check_interval_sec  = var.health_check_config.check_interval_sec
  timeout_sec         = var.health_check_config.timeout_sec
  healthy_threshold   = var.health_check_config.healthy_threshold
  unhealthy_threshold = var.health_check_config.unhealthy_threshold
}

# Backend Service
resource "google_compute_backend_service" "backend_service" {
  name = var.backend_service_name
  
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = var.backend_service_timeout_sec
  
  health_checks = [google_compute_health_check.health_check.id]
  
  # Backend configuration will be added by regional deployments
}

# URL Map
resource "google_compute_url_map" "url_map" {
  name = var.url_map_name
  
  default_service = google_compute_backend_service.backend_service.id
}

# Forwarding Rule
resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name       = var.forwarding_rule_name
  target     = google_compute_url_map.url_map.id
  port_range = "80"
  ip_address = google_compute_global_address.global_ip.address
}

# Outputs
output "global_ip_address" {
  description = "Global IP address"
  value       = google_compute_global_address.global_ip.address
}

output "health_check_id" {
  description = "Health check ID"
  value       = google_compute_health_check.health_check.id
}

output "backend_service_id" {
  description = "Backend service ID"
  value       = google_compute_backend_service.backend_service.id
}

output "url_map_id" {
  description = "URL map ID"
  value       = google_compute_url_map.url_map.id
}

output "forwarding_rule_id" {
  description = "Forwarding rule ID"
  value       = google_compute_global_forwarding_rule.forwarding_rule.id
}

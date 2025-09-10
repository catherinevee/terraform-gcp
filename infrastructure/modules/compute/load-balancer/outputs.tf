output "global_ip" {
  description = "Global IP address"
  value       = var.enable_load_balancer ? google_compute_global_address.global_ip[0] : null
}

output "global_ip_address" {
  description = "Global IP address value"
  value       = var.enable_load_balancer ? google_compute_global_address.global_ip[0].address : null
}

output "backend_service" {
  description = "Backend service"
  value       = var.enable_load_balancer ? google_compute_backend_service.backend_service[0] : null
}

output "url_map" {
  description = "URL map"
  value       = var.enable_load_balancer ? google_compute_url_map.url_map[0] : null
}

output "forwarding_rule" {
  description = "Forwarding rule"
  value       = var.enable_load_balancer ? google_compute_global_forwarding_rule.forwarding_rule[0] : null
}

output "access_policy" {
  description = "Access Context Manager Access Policy"
  value       = var.enable_vpc_service_controls ? google_access_context_manager_access_policy.access_policy[0] : null
}

output "service_perimeter" {
  description = "Access Context Manager Service Perimeter"
  value       = var.enable_vpc_service_controls ? google_access_context_manager_service_perimeter.service_perimeter[0] : null
}

output "access_level" {
  description = "Access Context Manager Access Level"
  value       = var.enable_vpc_service_controls && var.enable_access_level ? google_access_context_manager_access_level.access_level[0] : null
}

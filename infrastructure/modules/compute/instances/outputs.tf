output "instance_templates" {
  description = "Created instance templates"
  value       = google_compute_instance_template.instance_template
}

output "instance_group_managers" {
  description = "Created instance group managers"
  value       = google_compute_instance_group_manager.instance_group_manager
}

output "health_checks" {
  description = "Created health checks"
  value       = google_compute_health_check.health_check
}

output "autoscalers" {
  description = "Created autoscalers"
  value       = google_compute_autoscaler.autoscaler
}

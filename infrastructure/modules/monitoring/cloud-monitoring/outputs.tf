output "dashboards" {
  description = "Created monitoring dashboards"
  value       = google_monitoring_dashboard.dashboard
}

output "dashboard_names" {
  description = "Dashboard names"
  value       = { for k, v in google_monitoring_dashboard.dashboard : k => v.display_name }
}

output "uptime_checks" {
  description = "Created uptime checks"
  value       = google_monitoring_uptime_check_config.uptime_check
}

output "uptime_check_names" {
  description = "Uptime check names"
  value       = { for k, v in google_monitoring_uptime_check_config.uptime_check : k => v.display_name }
}

output "alert_policies" {
  description = "Created alert policies"
  value       = google_monitoring_alert_policy.alert_policy
}

output "alert_policy_names" {
  description = "Alert policy names"
  value       = { for k, v in google_monitoring_alert_policy.alert_policy : k => v.display_name }
}

output "notification_channels" {
  description = "Created notification channels"
  value       = google_monitoring_notification_channel.notification_channel
}

output "notification_channel_names" {
  description = "Notification channel names"
  value       = { for k, v in google_monitoring_notification_channel.notification_channel : k => v.display_name }
}

output "services" {
  description = "Created monitoring services"
  value       = google_monitoring_service.service
}

output "service_names" {
  description = "Service names"
  value       = { for k, v in google_monitoring_service.service : k => v.display_name }
}

output "slos" {
  description = "Created SLOs"
  value       = google_monitoring_slo.slo
}

output "slo_names" {
  description = "SLO names"
  value       = { for k, v in google_monitoring_slo.slo : k => v.display_name }
}

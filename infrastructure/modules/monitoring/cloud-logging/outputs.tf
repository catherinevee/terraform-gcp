output "log_sinks" {
  description = "Created log sinks"
  value       = google_logging_project_sink.log_sink
}

output "log_sink_names" {
  description = "Log sink names"
  value       = { for k, v in google_logging_project_sink.log_sink : k => v.name }
}

output "log_metrics" {
  description = "Created log metrics"
  value       = google_logging_metric.log_metric
}

output "log_metric_names" {
  description = "Log metric names"
  value       = { for k, v in google_logging_metric.log_metric : k => v.name }
}

output "log_exclusions" {
  description = "Created log exclusions"
  value       = google_logging_project_exclusion.log_exclusion
}

output "log_exclusion_names" {
  description = "Log exclusion names"
  value       = { for k, v in google_logging_project_exclusion.log_exclusion : k => v.name }
}

output "log_buckets" {
  description = "Created log buckets"
  value       = google_logging_project_bucket_config.log_bucket
}

output "log_bucket_names" {
  description = "Log bucket names"
  value       = { for k, v in google_logging_project_bucket_config.log_bucket : k => v.bucket_id }
}

output "folder_sinks" {
  description = "Created folder sinks"
  value       = google_logging_folder_sink.folder_sink
}

output "folder_sink_names" {
  description = "Folder sink names"
  value       = { for k, v in google_logging_folder_sink.folder_sink : k => v.name }
}

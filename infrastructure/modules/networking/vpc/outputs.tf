output "network_name" {
  description = "The name of the VPC being created"
  value       = google_compute_network.vpc.name
}

output "network_self_link" {
  description = "The URI of the VPC being created"
  value       = google_compute_network.vpc.self_link
}

output "network_id" {
  description = "The ID of the VPC being created"
  value       = google_compute_network.vpc.id
}

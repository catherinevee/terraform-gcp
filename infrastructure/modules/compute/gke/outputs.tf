output "clusters" {
  description = "Created GKE clusters"
  value       = google_container_cluster.cluster
}

output "cluster_names" {
  description = "GKE cluster names"
  value       = { for k, v in google_container_cluster.cluster : k => v.name }
}

output "cluster_endpoints" {
  description = "GKE cluster endpoints"
  value       = { for k, v in google_container_cluster.cluster : k => v.endpoint }
}

output "cluster_ca_certificates" {
  description = "GKE cluster CA certificates"
  value       = { for k, v in google_container_cluster.cluster : k => v.master_auth[0].cluster_ca_certificate }
}

output "node_pools" {
  description = "Created node pools"
  value       = google_container_node_pool.node_pool
}

output "node_pool_names" {
  description = "Node pool names"
  value       = { for k, v in google_container_node_pool.node_pool : k => v.name }
}

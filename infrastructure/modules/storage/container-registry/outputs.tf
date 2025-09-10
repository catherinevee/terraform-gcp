output "repositories" {
  description = "Created Artifact Registry repositories"
  value       = google_artifact_registry_repository.repository
}

output "repository_names" {
  description = "Repository names"
  value       = { for k, v in google_artifact_registry_repository.repository : k => v.name }
}

output "repository_urls" {
  description = "Repository URLs"
  value       = { for k, v in google_artifact_registry_repository.repository : k => v.name }
}

output "legacy_registry" {
  description = "Legacy Container Registry"
  value       = var.enable_legacy_registry ? google_container_registry.registry[0] : null
}

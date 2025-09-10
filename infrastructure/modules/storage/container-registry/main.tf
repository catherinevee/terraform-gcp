# Container Registry (Artifact Registry)
resource "google_artifact_registry_repository" "repository" {
  for_each = var.repositories
  
  location      = each.value.location
  repository_id = each.value.repository_id
  description   = each.value.description
  format        = each.value.format
  project       = var.project_id
  
  # Enable vulnerability scanning
  cleanup_policies {
    id     = "delete-prerelease"
    action = "DELETE"
    condition {
      tag_state = "TAGGED"
      tag_prefixes = ["alpha", "beta", "rc"]
      older_than = "604800s" # 7 days
    }
  }
  
  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "KEEP"
    most_recent_versions {
      keep_count = each.value.keep_count
    }
  }
  
  # Enable immutable tags
  cleanup_policies {
    id     = "delete-old-versions"
    action = "DELETE"
    condition {
      tag_state = "TAGGED"
      older_than = each.value.retention_days
    }
  }
  
  # Labels
  labels = each.value.labels
}

# IAM bindings for repositories
resource "google_artifact_registry_repository_iam_binding" "repository_iam" {
  for_each = var.repository_iam_bindings
  
  project    = var.project_id
  location   = google_artifact_registry_repository.repository[each.value.repository_key].location
  repository = google_artifact_registry_repository.repository[each.value.repository_key].name
  role       = each.value.role
  members    = each.value.members
}

# Container Registry (Legacy)
resource "google_container_registry" "registry" {
  count = var.enable_legacy_registry ? 1 : 0
  
  project = var.project_id
  location = var.legacy_registry_location
}

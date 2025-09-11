# Cloud SQL Instance
resource "google_sql_database_instance" "instance" {
  for_each = var.instances

  name             = each.value.name
  database_version = each.value.database_version
  region           = each.value.region
  project          = var.project_id

  deletion_protection = each.value.deletion_protection

  settings {
    tier                  = each.value.tier
    availability_type     = each.value.availability_type
    disk_type             = each.value.disk_type
    disk_size             = each.value.disk_size
    disk_autoresize       = each.value.disk_autoresize
    disk_autoresize_limit = each.value.disk_autoresize_limit

    backup_configuration {
      enabled                        = each.value.backup_enabled
      start_time                     = each.value.backup_start_time
      location                       = each.value.backup_location
      point_in_time_recovery_enabled = each.value.point_in_time_recovery_enabled
      transaction_log_retention_days = each.value.transaction_log_retention_days

      dynamic "backup_retention_settings" {
        for_each = each.value.backup_retention_settings != null ? [each.value.backup_retention_settings] : []
        content {
          retained_backups = backup_retention_settings.value.retained_backups
          retention_unit   = backup_retention_settings.value.retention_unit
        }
      }
    }

    ip_configuration {
      ipv4_enabled                                  = each.value.ipv4_enabled
      private_network                               = each.value.private_network
      enable_private_path_for_google_cloud_services = each.value.enable_private_path_for_google_cloud_services
      require_ssl                                   = each.value.require_ssl

      dynamic "authorized_networks" {
        for_each = each.value.authorized_networks
        content {
          name  = authorized_networks.value.name
          value = authorized_networks.value.value
        }
      }
    }

    dynamic "database_flags" {
      for_each = each.value.database_flags
      content {
        name  = database_flags.value.name
        value = database_flags.value.value
      }
    }

    dynamic "insights_config" {
      for_each = each.value.insights_config != null ? [each.value.insights_config] : []
      content {
        query_insights_enabled  = insights_config.value.query_insights_enabled
        query_string_length     = insights_config.value.query_string_length
        record_application_tags = insights_config.value.record_application_tags
        record_client_address   = insights_config.value.record_client_address
      }
    }

    dynamic "maintenance_window" {
      for_each = each.value.maintenance_window != null ? [each.value.maintenance_window] : []
      content {
        day          = maintenance_window.value.day
        hour         = maintenance_window.value.hour
        update_track = maintenance_window.value.update_track
      }
    }
  }

  depends_on = [var.private_vpc_connection]
}

# Cloud SQL Database
resource "google_sql_database" "database" {
  for_each = var.databases

  name     = each.value.name
  instance = google_sql_database_instance.instance[each.value.instance_key].name
  project  = var.project_id
}

# Cloud SQL User
resource "google_sql_user" "user" {
  for_each = var.users

  name     = each.value.name
  instance = google_sql_database_instance.instance[each.value.instance_key].name
  password = each.value.password
  project  = var.project_id
}

# Cloud SQL SSL Certificate
resource "google_sql_ssl_cert" "client_cert" {
  for_each = var.ssl_certs

  common_name = each.value.common_name
  instance    = google_sql_database_instance.instance[each.value.instance_key].name
  project     = var.project_id
}

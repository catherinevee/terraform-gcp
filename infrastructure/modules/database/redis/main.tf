# Redis Instance
resource "google_redis_instance" "instance" {
  for_each = var.instances
  
  name           = each.value.name
  tier           = each.value.tier
  memory_size_gb = each.value.memory_size_gb
  region         = each.value.region
  project        = var.project_id
  
  location_id             = each.value.location_id
  alternative_location_id = each.value.alternative_location_id
  
  redis_version     = each.value.redis_version
  display_name      = each.value.display_name
  reserved_ip_range = each.value.reserved_ip_range
  
  auth_enabled = each.value.auth_enabled
  
  dynamic "maintenance_policy" {
    for_each = each.value.maintenance_policy != null ? [each.value.maintenance_policy] : []
    content {
      weekly_maintenance_window {
        day = maintenance_policy.value.day
        start_time {
          hours   = maintenance_policy.value.start_hour
          minutes = maintenance_policy.value.start_minute
          seconds = maintenance_policy.value.start_second
          nanos   = maintenance_policy.value.start_nanos
        }
      }
    }
  }
  
  dynamic "persistence_config" {
    for_each = each.value.persistence_config != null ? [each.value.persistence_config] : []
    content {
      persistence_mode    = persistence_config.value.persistence_mode
      rdb_snapshot_period = persistence_config.value.rdb_snapshot_period
    }
  }
  
  redis_configs = each.value.redis_configs
  
  depends_on = [var.private_vpc_connection]
}

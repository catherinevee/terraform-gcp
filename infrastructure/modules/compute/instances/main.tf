# Compute Instance Template
resource "google_compute_instance_template" "instance_template" {
  for_each = var.instance_templates

  name_prefix  = each.value.name_prefix
  description  = each.value.description
  machine_type = each.value.machine_type
  project      = var.project_id
  region       = var.region

  tags = each.value.tags

  disk {
    source_image = each.value.source_image
    auto_delete  = true
    boot         = true
    disk_size_gb = each.value.disk_size_gb
    disk_type    = each.value.disk_type
  }

  network_interface {
    network            = var.network_name
    subnetwork         = each.value.subnetwork
    subnetwork_project = var.project_id

    dynamic "access_config" {
      for_each = each.value.enable_external_ip ? [1] : []
      content {
        // Ephemeral public IP
      }
    }
  }

  service_account {
    email  = each.value.service_account_email
    scopes = each.value.service_account_scopes
  }

  metadata = each.value.metadata

  metadata_startup_script = each.value.startup_script

  lifecycle {
    create_before_destroy = true
  }
}

# Managed Instance Group
resource "google_compute_instance_group_manager" "instance_group_manager" {
  for_each = var.instance_group_managers

  name               = each.value.name
  description        = each.value.description
  base_instance_name = each.value.base_instance_name
  zone               = each.value.zone
  project            = var.project_id

  version {
    instance_template = google_compute_instance_template.instance_template[each.value.template_key].id
  }

  target_size = each.value.target_size

  dynamic "auto_healing_policies" {
    for_each = each.value.enable_auto_healing ? [1] : []
    content {
      health_check      = length(var.health_checks) == 0 ? data.google_compute_health_check.existing_health_check[0].id : google_compute_health_check.health_check[each.value.health_check_key].id
      initial_delay_sec = each.value.initial_delay_sec
    }
  }

  dynamic "update_policy" {
    for_each = each.value.update_policy != null ? [each.value.update_policy] : []
    content {
      type                  = update_policy.value.type
      minimal_action        = update_policy.value.minimal_action
      max_surge_fixed       = update_policy.value.max_surge_fixed
      max_unavailable_fixed = update_policy.value.max_unavailable_fixed
    }
  }
}

# Health Check - Use data source if health_checks is empty, otherwise create resource
data "google_compute_health_check" "existing_health_check" {
  count = length(var.health_checks) == 0 ? 1 : 0
  name  = "cataziza-ecommerce-web-health-check"
}

resource "google_compute_health_check" "health_check" {
  for_each = var.health_checks

  name                = each.value.name
  description         = each.value.description
  check_interval_sec  = each.value.check_interval_sec
  timeout_sec         = each.value.timeout_sec
  healthy_threshold   = each.value.healthy_threshold
  unhealthy_threshold = each.value.unhealthy_threshold
  project             = var.project_id

  http_health_check {
    port         = each.value.port
    request_path = each.value.request_path
  }
}

# Auto Scaling Policy
resource "google_compute_autoscaler" "autoscaler" {
  for_each = var.autoscalers

  name    = each.value.name
  zone    = each.value.zone
  target  = google_compute_instance_group_manager.instance_group_manager[each.value.instance_group_manager_key].id
  project = var.project_id

  autoscaling_policy {
    max_replicas    = each.value.max_replicas
    min_replicas    = each.value.min_replicas
    cooldown_period = each.value.cooldown_period

    dynamic "cpu_utilization" {
      for_each = each.value.cpu_utilization != null ? [each.value.cpu_utilization] : []
      content {
        target = cpu_utilization.value.target
      }
    }

    dynamic "load_balancing_utilization" {
      for_each = each.value.load_balancing_utilization != null ? [each.value.load_balancing_utilization] : []
      content {
        target = load_balancing_utilization.value.target
      }
    }
  }
}

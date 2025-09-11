# Cloud Monitoring Dashboard
resource "google_monitoring_dashboard" "dashboard" {
  for_each = var.dashboards

  dashboard_json = jsonencode({
    displayName = each.value.display_name
    mosaicLayout = {
      tiles = each.value.tiles
    }
  })

  project = var.project_id
}

# Uptime Checks
resource "google_monitoring_uptime_check_config" "uptime_check" {
  for_each = var.uptime_checks

  display_name = each.value.display_name
  timeout      = each.value.timeout
  period       = each.value.period
  project      = var.project_id

  http_check {
    path           = each.value.path
    port           = each.value.port
    request_method = each.value.request_method
    use_ssl        = each.value.use_ssl
    validate_ssl   = each.value.validate_ssl

    dynamic "auth_info" {
      for_each = each.value.auth_info != null ? [each.value.auth_info] : []
      content {
        username = auth_info.value.username
        password = auth_info.value.password
      }
    }

    headers = each.value.headers
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      host       = each.value.host
      project_id = var.project_id
    }
  }

  dynamic "content_matchers" {
    for_each = each.value.content_matchers
    content {
      content = content_matchers.value.content
      matcher = content_matchers.value.matcher
    }
  }

  selected_regions = each.value.selected_regions
}

# Alert Policies
resource "google_monitoring_alert_policy" "alert_policy" {
  for_each = var.alert_policies

  display_name = each.value.display_name
  combiner     = each.value.combiner
  enabled      = each.value.enabled
  project      = var.project_id

  conditions {
    display_name = each.value.condition.display_name

    condition_threshold {
      filter          = each.value.condition.filter
      duration        = each.value.condition.duration
      comparison      = each.value.condition.comparison
      threshold_value = each.value.condition.threshold_value

      aggregations {
        alignment_period     = each.value.condition.aggregation.alignment_period
        per_series_aligner   = each.value.condition.aggregation.per_series_aligner
        cross_series_reducer = each.value.condition.aggregation.cross_series_reducer
        group_by_fields      = each.value.condition.aggregation.group_by_fields
      }

      dynamic "trigger" {
        for_each = each.value.condition.trigger != null ? [each.value.condition.trigger] : []
        content {
          count = trigger.value.count
        }
      }
    }
  }

  notification_channels = each.value.notification_channels

  dynamic "alert_strategy" {
    for_each = each.value.alert_strategy != null ? [each.value.alert_strategy] : []
    content {
      auto_close = alert_strategy.value.auto_close

      dynamic "notification_rate_limit" {
        for_each = alert_strategy.value.notification_rate_limit != null ? [alert_strategy.value.notification_rate_limit] : []
        content {
          period = notification_rate_limit.value.period
        }
      }
    }
  }

  dynamic "documentation" {
    for_each = each.value.documentation != null ? [each.value.documentation] : []
    content {
      content   = documentation.value.content
      mime_type = documentation.value.mime_type
    }
  }
}

# Notification Channels
resource "google_monitoring_notification_channel" "notification_channel" {
  for_each = var.notification_channels

  display_name = each.value.display_name
  type         = each.value.type
  project      = var.project_id

  labels = each.value.labels

  dynamic "sensitive_labels" {
    for_each = each.value.sensitive_labels != null ? [each.value.sensitive_labels] : []
    content {
      auth_token  = sensitive_labels.value.auth_token
      password    = sensitive_labels.value.password
      service_key = sensitive_labels.value.service_key
    }
  }

  enabled = each.value.enabled
}

# Service Monitoring
resource "google_monitoring_service" "service" {
  for_each = var.services

  service_id   = each.value.service_id
  display_name = each.value.display_name
  project      = var.project_id

  basic_service {
    service_type = "CLOUD_RUN"
    service_labels = {
      location     = "us-central1"
      service_name = each.value.service_id
    }
  }

  user_labels = each.value.user_labels
}

# SLO (Service Level Objectives)
resource "google_monitoring_slo" "slo" {
  for_each = var.slos

  service      = google_monitoring_service.service[each.value.service_key].service_id
  slo_id       = each.value.slo_id
  display_name = each.value.display_name
  project      = var.project_id

  goal                = each.value.goal
  rolling_period_days = each.value.rolling_period_days

  dynamic "basic_sli" {
    for_each = each.value.basic_sli != null ? [each.value.basic_sli] : []
    content {
      dynamic "availability" {
        for_each = basic_sli.value.availability != null ? [basic_sli.value.availability] : []
        content {
          enabled = availability.value.enabled
        }
      }

      dynamic "latency" {
        for_each = basic_sli.value.latency != null ? [basic_sli.value.latency] : []
        content {
          threshold = latency.value.threshold
        }
      }
    }
  }

  dynamic "request_based_sli" {
    for_each = each.value.request_based_sli != null ? [each.value.request_based_sli] : []
    content {
      good_total_ratio {
        total_service_filter = request_based_sli.value.total_service_filter
        good_service_filter  = request_based_sli.value.good_service_filter
      }
    }
  }
}

# Security Monitoring Configuration
# This file contains security monitoring and alerting configuration

# Security Incident Detection Alert Policy
resource "google_monitoring_alert_policy" "security_incidents" {
  display_name = "Cataziza E-commerce Platform Security Incident Detection"
  combiner     = "OR"

  documentation {
    content   = "This alert fires when security incidents are detected across all regions"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Unauthorized access attempts detected"

    condition_threshold {
      filter          = "resource.type=\"gce_instance\" AND metric.type=\"logging.googleapis.com/user/security_events\""
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      duration        = "300s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = var.monitoring_alert_channels

  alert_strategy {
    auto_close = "1800s"
  }
}

# Failed Authentication Attempts Alert Policy
resource "google_monitoring_alert_policy" "failed_authentication" {
  display_name = "Cataziza E-commerce Platform Failed Authentication Attempts"
  combiner     = "OR"

  documentation {
    content   = "This alert fires when multiple failed authentication attempts are detected"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Multiple failed authentication attempts"

    condition_threshold {
      filter          = "resource.type=\"gce_instance\" AND metric.type=\"logging.googleapis.com/user/auth_failures\""
      comparison      = "COMPARISON_GT"
      threshold_value = 10
      duration        = "600s"

      aggregations {
        alignment_period   = "600s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = var.monitoring_alert_channels

  alert_strategy {
    auto_close = "3600s"
  }
}

# Suspicious Network Activity Alert Policy
resource "google_monitoring_alert_policy" "suspicious_network_activity" {
  display_name = "Cataziza E-commerce Platform Suspicious Network Activity"
  combiner     = "OR"

  documentation {
    content   = "This alert fires when suspicious network activity is detected"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "High volume of network connections"

    condition_threshold {
      filter          = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/network/received_bytes_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1000000000 # 1GB
      duration        = "300s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = var.monitoring_alert_channels

  alert_strategy {
    auto_close = "1800s"
  }
}

# Database Security Alert Policy
resource "google_monitoring_alert_policy" "database_security" {
  display_name = "Cataziza E-commerce Platform Database Security"
  combiner     = "OR"

  documentation {
    content   = "This alert fires when database security issues are detected"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Database connection failures"

    condition_threshold {
      filter          = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/up\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "60s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.monitoring_alert_channels

  alert_strategy {
    auto_close = "300s"
  }
}

# Storage Security Alert Policy
resource "google_monitoring_alert_policy" "storage_security" {
  display_name = "Cataziza E-commerce Platform Storage Security"
  combiner     = "OR"

  documentation {
    content   = "This alert fires when storage security issues are detected"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Unauthorized storage access"

    condition_threshold {
      filter          = "resource.type=\"gcs_bucket\" AND metric.type=\"storage.googleapis.com/api/request_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1000
      duration        = "300s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = var.monitoring_alert_channels

  alert_strategy {
    auto_close = "1800s"
  }
}

# Compliance Monitoring Dashboard
resource "google_monitoring_dashboard" "security_dashboard" {
  dashboard_json = jsonencode({
    displayName = "Cataziza E-commerce Platform Security Dashboard"
    mosaicLayout = {
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Security Incidents"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"logging.googleapis.com/user/security_events\""
                }
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Failed Authentication Attempts"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"logging.googleapis.com/user/auth_failures\""
                }
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Network Activity"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"compute.googleapis.com/instance/network/received_bytes_count\""
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Database Health"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"cloudsql.googleapis.com/database/up\""
                }
              }
            }
          }
        }
      ]
    }
  })
}

# Security Log Sink for centralized logging
resource "google_logging_project_sink" "security_logs" {
  name = "cataziza-ecommerce-security-logs"

  destination = "storage.googleapis.com/${google_storage_bucket.security_logs.name}"

  filter = <<-EOT
    resource.type="gce_instance" AND
    (jsonPayload.message=~"security" OR
     jsonPayload.message=~"auth" OR
     jsonPayload.message=~"access" OR
     jsonPayload.message=~"permission" OR
     jsonPayload.message=~"unauthorized")
  EOT

  unique_writer_identity = true
}

# Storage bucket for security logs
resource "google_storage_bucket" "security_logs" {
  name          = "cataziza-ecommerce-security-logs-${var.environment}-${random_id.bucket_suffix.hex}"
  location      = "US"
  force_destroy = false

  lifecycle_rule {
    condition {
      age = var.security_log_retention_days
    }
    action {
      type = "Delete"
    }
  }

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = module.kms.crypto_keys["security-logs"].id
  }
}

# Random ID for bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Security Metrics Export
resource "google_monitoring_metric_descriptor" "security_events" {
  type         = "custom.googleapis.com/security/events"
  metric_kind  = "GAUGE"
  value_type   = "INT64"
  display_name = "Security Events Count"
  description  = "Number of security events detected"

  labels {
    key         = "severity"
    value_type  = "STRING"
    description = "Severity level of the security event"
  }

  labels {
    key         = "event_type"
    value_type  = "STRING"
    description = "Type of security event"
  }
}

# Security Policy Violations Alert
resource "google_monitoring_alert_policy" "security_policy_violations" {
  display_name = "Cataziza E-commerce Platform Security Policy Violations"
  combiner     = "OR"

  documentation {
    content   = "This alert fires when security policy violations are detected"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Security policy violations detected"

    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/security_policy_violations\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1
      duration        = "60s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = var.monitoring_alert_channels

  alert_strategy {
    auto_close = "3600s"
  }
}

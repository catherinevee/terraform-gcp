# Log Sinks
resource "google_logging_project_sink" "log_sink" {
  for_each = var.log_sinks
  
  name        = each.value.name
  destination = each.value.destination
  filter      = each.value.filter
  project     = var.project_id
  
  unique_writer_identity = each.value.unique_writer_identity
  
  dynamic "bigquery_options" {
    for_each = each.value.bigquery_options != null ? [each.value.bigquery_options] : []
    content {
      use_partitioned_tables = bigquery_options.value.use_partitioned_tables
    }
  }
  
  dynamic "exclusions" {
    for_each = each.value.exclusions
    content {
      name        = exclusions.value.name
      description = exclusions.value.description
      filter      = exclusions.value.filter
      disabled    = exclusions.value.disabled
    }
  }
}

# Log Metrics
resource "google_logging_metric" "log_metric" {
  for_each = var.log_metrics
  
  name   = each.value.name
  filter = each.value.filter
  project = var.project_id
  
  description = each.value.description
  label_extractors = each.value.label_extractors
  
  dynamic "bucket_options" {
    for_each = each.value.bucket_options != null ? [each.value.bucket_options] : []
    content {
      dynamic "linear_buckets" {
        for_each = bucket_options.value.linear_buckets != null ? [bucket_options.value.linear_buckets] : []
        content {
          num_finite_buckets = linear_buckets.value.num_finite_buckets
          width              = linear_buckets.value.width
          offset             = linear_buckets.value.offset
        }
      }
      
      dynamic "exponential_buckets" {
        for_each = bucket_options.value.exponential_buckets != null ? [bucket_options.value.exponential_buckets] : []
        content {
          num_finite_buckets = exponential_buckets.value.num_finite_buckets
          growth_factor      = exponential_buckets.value.growth_factor
          scale              = exponential_buckets.value.scale
        }
      }
      
      dynamic "explicit_buckets" {
        for_each = bucket_options.value.explicit_buckets != null ? [bucket_options.value.explicit_buckets] : []
        content {
          bounds = explicit_buckets.value.bounds
        }
      }
    }
  }
  
  dynamic "metric_descriptor" {
    for_each = each.value.metric_descriptor != null ? [each.value.metric_descriptor] : []
    content {
      metric_kind = metric_descriptor.value.metric_kind
      value_type  = metric_descriptor.value.value_type
      
      dynamic "labels" {
        for_each = metric_descriptor.value.labels
        content {
          key         = labels.value.key
          value_type  = labels.value.value_type
          description = labels.value.description
        }
      }
    }
  }
  
  value_extractor = each.value.value_extractor
}

# Log Views
resource "google_logging_project_exclusion" "log_exclusion" {
  for_each = var.log_exclusions
  
  name        = each.value.name
  description = each.value.description
  filter      = each.value.filter
  disabled    = each.value.disabled
  project     = var.project_id
}

# Log Router
resource "google_logging_project_bucket_config" "log_bucket" {
  for_each = var.log_buckets
  
  location  = each.value.location
  bucket_id = each.value.bucket_id
  project   = var.project_id
  
  description = each.value.description
  retention_days = each.value.retention_days
  
  dynamic "cmek_settings" {
    for_each = each.value.cmek_settings != null ? [each.value.cmek_settings] : []
    content {
      kms_key_name = cmek_settings.value.kms_key_name
    }
  }
  
  dynamic "index_configs" {
    for_each = each.value.index_configs
    content {
      field_path = index_configs.value.field_path
      type       = index_configs.value.type
    }
  }
}

# Log Analytics
resource "google_logging_folder_sink" "folder_sink" {
  for_each = var.folder_sinks
  
  folder     = each.value.folder
  name       = each.value.name
  destination = each.value.destination
  filter     = each.value.filter
  
  # unique_writer_identity = each.value.unique_writer_identity
  
  dynamic "bigquery_options" {
    for_each = each.value.bigquery_options != null ? [each.value.bigquery_options] : []
    content {
      use_partitioned_tables = bigquery_options.value.use_partitioned_tables
    }
  }
  
  dynamic "exclusions" {
    for_each = each.value.exclusions
    content {
      name        = exclusions.value.name
      description = exclusions.value.description
      filter      = exclusions.value.filter
      disabled    = exclusions.value.disabled
    }
  }
}

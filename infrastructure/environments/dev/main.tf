terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Local variables
locals {
  environment = "dev"
  project_id  = var.project_id
  region      = var.region

  common_labels = {
    environment = local.environment
    project     = "terraform-gcp"
    managed_by  = "terraform"
  }
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "redis.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudfunctions.googleapis.com",
    "appengine.googleapis.com",
    "pubsub.googleapis.com",
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "servicenetworking.googleapis.com",
  ])

  project = local.project_id
  service = each.value

  disable_on_destroy = false
}

# VPC Module
module "vpc" {
  source = "../../modules/networking/vpc"

  project_id   = local.project_id
  network_name = "acme-ecommerce-platform-vpc-${local.environment}"
  routing_mode = "REGIONAL"

  delete_default_routes_on_create = true

  depends_on = [google_project_service.required_apis]
}

# Subnets Module
module "subnets" {
  source = "../../modules/networking/subnets"

  project_id   = local.project_id
  network_name = module.vpc.network_name

  subnets = [
    {
      subnet_name           = "acme-ecommerce-web-tier-${local.environment}"
      subnet_ip             = "10.0.1.0/24"
      subnet_region         = local.region
      subnet_private_access = true
    },
    {
      subnet_name           = "acme-ecommerce-app-tier-${local.environment}"
      subnet_ip             = "10.0.10.0/24"
      subnet_region         = local.region
      subnet_private_access = true
    },
    {
      subnet_name           = "acme-ecommerce-database-tier-${local.environment}"
      subnet_ip             = "10.0.20.0/24"
      subnet_region         = local.region
      subnet_private_access = true
    },
    {
      subnet_name           = "acme-ecommerce-kubernetes-tier-${local.environment}"
      subnet_ip             = "10.0.30.0/24"
      subnet_region         = local.region
      subnet_private_access = true
    }
  ]

  secondary_ranges = {
    "${local.project_id}-${local.environment}-${local.region}-gke" = [
      {
        range_name    = "gke-pods"
        ip_cidr_range = "10.1.0.0/16"
      },
      {
        range_name    = "gke-services"
        ip_cidr_range = "10.2.0.0/16"
      }
    ]
  }

  depends_on = [module.vpc]
}

# Firewall Module
module "firewall" {
  source = "../../modules/networking/firewall"

  project_id   = local.project_id
  network_name = module.vpc.network_name

  depends_on = [module.vpc]
}

# IAM Module
module "iam" {
  source = "../../modules/security/iam"

  project_id = local.project_id

  service_accounts = {
    "acme-ecommerce-terraform-sa" = {
      account_id   = "acme-ecommerce-terraform-sa"
      display_name = "ACME E-commerce Terraform Service Account"
      description  = "Service account for ACME e-commerce platform infrastructure management"
    }
    "acme-customer-api-gke-sa" = {
      account_id   = "acme-customer-api-gke-sa"
      display_name = "ACME Customer API GKE Service Account"
      description  = "Service account for customer API Kubernetes workloads"
    }
    "acme-orders-service-sa" = {
      account_id   = "acme-orders-service-sa"
      display_name = "ACME Orders Service Account"
      description  = "Service account for orders processing service"
    }
  }

  service_account_roles = {
    "terraform-editor" = {
      service_account_key = "acme-ecommerce-terraform-sa"
      role                = "roles/editor"
    }
    "gke-cluster-admin" = {
      service_account_key = "acme-customer-api-gke-sa"
      role                = "roles/container.clusterAdmin"
    }
    "app-storage-admin" = {
      service_account_key = "acme-orders-service-sa"
      role                = "roles/storage.admin"
    }
  }

  custom_roles = {
    "terraform-custom-role" = {
      role_id     = "terraform_custom_role"
      title       = "Terraform Custom Role"
      description = "Custom role for Terraform operations"
      permissions = [
        "compute.instances.create",
        "compute.instances.delete",
        "compute.networks.create",
        "compute.subnetworks.create"
      ]
    }
  }

  enable_workload_identity       = true
  workload_identity_pool_id      = "github-actions"
  workload_identity_display_name = "GitHub Actions Pool"
  workload_identity_description  = "Workload Identity Pool for GitHub Actions"

  depends_on = [google_project_service.required_apis]
}

# KMS Module
module "kms" {
  source = "../../modules/security/kms"

  project_id    = local.project_id
  key_ring_name = "acme-ecommerce-platform-keyring-${local.environment}"
  location      = local.region

  crypto_keys = {
    "acme-ecommerce-data-encryption-key" = {
      name            = "acme-ecommerce-data-encryption-key"
      purpose         = "ENCRYPT_DECRYPT"
      algorithm       = "GOOGLE_SYMMETRIC_ENCRYPTION"
      rotation_period = "7776000s" # 90 days
    }
    "acme-ecommerce-signing-key" = {
      name            = "acme-ecommerce-signing-key"
      purpose         = "ASYMMETRIC_SIGN"
      algorithm       = "EC_SIGN_P256_SHA256"
      rotation_period = null
    }
  }

  crypto_key_iam_bindings = {
    "encryption-key-encrypt-decrypt" = {
      crypto_key_key = "acme-ecommerce-data-encryption-key"
      role           = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
      members = [
        "serviceAccount:${module.iam.service_account_emails["acme-ecommerce-terraform-sa"]}",
        "serviceAccount:${module.iam.service_account_emails["acme-orders-service-sa"]}"
      ]
    }
    "signing-key-signer" = {
      crypto_key_key = "acme-ecommerce-signing-key"
      role           = "roles/cloudkms.signer"
      members = [
        "serviceAccount:${module.iam.service_account_emails["acme-ecommerce-terraform-sa"]}"
      ]
    }
  }

  depends_on = [module.iam]
}

# Secret Manager Module
module "secret_manager" {
  source = "../../modules/security/secret-manager"

  project_id = local.project_id

  secrets = {
    "database-password" = {
      secret_id        = "database-password"
      labels           = { environment = local.environment, type = "database" }
      replication_type = "automatic"
      replicas         = []
    }
    "api-key" = {
      secret_id        = "api-key"
      labels           = { environment = local.environment, type = "api" }
      replication_type = "automatic"
      replicas         = []
    }
  }

  secret_versions = {
    "database-password-version" = {
      secret_key  = "database-password"
      secret_data = "initial-password-change-me"
    }
    "api-key-version" = {
      secret_key  = "api-key"
      secret_data = "initial-api-key-change-me"
    }
  }

  secret_iam_bindings = {
    "database-password-access" = {
      secret_key = "database-password"
      role       = "roles/secretmanager.secretAccessor"
      members = [
        "serviceAccount:${module.iam.service_account_emails["acme-orders-service-sa"]}"
      ]
    }
    "api-key-access" = {
      secret_key = "api-key"
      role       = "roles/secretmanager.secretAccessor"
      members = [
        "serviceAccount:${module.iam.service_account_emails["acme-orders-service-sa"]}"
      ]
    }
  }

  depends_on = [module.iam]
}

# Compute Module
module "compute" {
  source = "../../modules/compute/instances"

  project_id   = local.project_id
  network_name = module.vpc.network_name
  region       = local.region

  instance_templates = {
    "web-template" = {
      name_prefix            = "web-instance"
      description            = "Web server instance template"
      machine_type           = "e2-micro"
      source_image           = "debian-cloud/debian-11"
      disk_size_gb           = 20
      disk_type              = "pd-standard"
      subnetwork             = module.subnets.subnets["acme-ecommerce-web-tier-${local.environment}"].name
      enable_external_ip     = true
      service_account_email  = module.iam.service_account_emails["acme-orders-service-sa"]
      service_account_scopes = ["cloud-platform"]
      metadata = {
        "startup-script" = <<-EOF
          #!/bin/bash
          apt-get update
          apt-get install -y nginx
          systemctl start nginx
          systemctl enable nginx
          echo '<h1>Hello from Terraform-GCP Phase 3!</h1>' > /var/www/html/index.html
        EOF
      }
      startup_script = ""
      tags           = ["web", "http"]
    }
  }

  instance_group_managers = {
    "web-igm" = {
      name                = "acme-ecommerce-web-servers"
      description         = "ACME E-commerce Web Server Instance Group"
      base_instance_name  = "acme-ecommerce-web-server"
      zone                = "${local.region}-a"
      template_key        = "web-template"
      target_size         = 2
      enable_auto_healing = true
      health_check_key    = "web-health-check"
      initial_delay_sec   = 300
      update_policy = {
        type                         = "PROACTIVE"
        instance_redistribution_type = "PROACTIVE"
        minimal_action               = "REPLACE"
        max_surge_fixed              = 1
        max_unavailable_fixed        = 0
      }
    }
  }

  health_checks = {
    "web-health-check" = {
      name                = "acme-ecommerce-web-health-check"
      description         = "Health check for ACME E-commerce web servers"
      check_interval_sec  = 5
      timeout_sec         = 5
      healthy_threshold   = 2
      unhealthy_threshold = 2
      port                = 80
      request_path        = "/"
    }
  }

  autoscalers = {
    "web-autoscaler" = {
      name                       = "acme-ecommerce-web-autoscaler"
      zone                       = "${local.region}-a"
      instance_group_manager_key = "web-igm"
      max_replicas               = 5
      min_replicas               = 2
      cooldown_period            = 60
      cpu_utilization = {
        target = 0.7
      }
    }
  }

  depends_on = [module.subnets, module.iam]
}

# Load Balancer Module
module "load_balancer" {
  source = "../../modules/compute/load-balancer"

  project_id = local.project_id

  global_ip_name       = "acme-ecommerce-platform-lb-ip-${local.environment}"
  health_check_name    = "acme-ecommerce-platform-lb-health-check-${local.environment}"
  backend_service_name = "acme-ecommerce-platform-lb-backend-${local.environment}"
  url_map_name         = "acme-ecommerce-platform-lb-url-map-${local.environment}"
  forwarding_rule_name = "acme-ecommerce-platform-lb-forwarding-rule-${local.environment}"

  backend_groups = [
    {
      group           = module.compute.instance_group_managers["web-igm"].instance_group
      balancing_mode  = "UTILIZATION"
      capacity_scaler = 1.0
      max_utilization = 0.8
    }
  ]

  depends_on = [module.compute]
}

# Storage Module
module "storage" {
  source = "../../modules/storage/buckets"

  project_id = local.project_id

  buckets = {
    "app-data" = {
      name                        = "acme-ecommerce-customer-data-${local.environment}"
      location                    = local.region
      storage_class               = "STANDARD"
      uniform_bucket_level_access = true
      enable_versioning           = true
      kms_key_name                = null
      labels = {
        environment = local.environment
        purpose     = "application-data"
      }
      lifecycle_rules = [
        {
          action_type = "Delete"
          age         = 365
        }
      ]
      cors = {
        origin          = ["*"]
        method          = ["GET", "POST", "PUT", "DELETE"]
        response_header = ["*"]
        max_age_seconds = 3600
      }
    }
    "logs" = {
      name                        = "acme-ecommerce-application-logs-${local.environment}"
      location                    = local.region
      storage_class               = "NEARLINE"
      uniform_bucket_level_access = true
      enable_versioning           = false
      labels = {
        environment = local.environment
        purpose     = "logs"
      }
      lifecycle_rules = [
        {
          action_type = "Delete"
          age         = 90
        }
      ]
    }
  }

  bucket_iam_bindings = {
    "app-data-access" = {
      bucket_key = "app-data"
      role       = "roles/storage.objectViewer"
      members = [
        "serviceAccount:${module.iam.service_account_emails["acme-orders-service-sa"]}"
      ]
    }
    "logs-access" = {
      bucket_key = "logs"
      role       = "roles/storage.objectCreator"
      members = [
        "serviceAccount:${module.iam.service_account_emails["acme-orders-service-sa"]}"
      ]
    }
  }

  bucket_objects = {
    "welcome-file" = {
      name         = "welcome.txt"
      bucket_key   = "app-data"
      content      = "Welcome to Terraform-GCP Phase 3! This file was created by Terraform."
      content_type = "text/plain"
    }
  }

  depends_on = [module.kms, module.iam]
}

# Database Module
module "database" {
  source = "../../modules/database/cloud-sql"

  project_id             = local.project_id
  private_vpc_connection = module.vpc.private_vpc_connection

  instances = {
    "postgres-primary" = {
      name                           = "acme-orders-database-${local.environment}"
      database_version               = "POSTGRES_15"
      region                         = local.region
      tier                           = "db-f1-micro"
      availability_type              = "ZONAL"
      disk_type                      = "PD_SSD"
      disk_size                      = 20
      disk_autoresize                = true
      disk_autoresize_limit          = 100
      deletion_protection            = false
      backup_enabled                 = true
      backup_start_time              = "03:00"
      backup_location                = local.region
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      backup_retention_settings = {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
      ipv4_enabled                                  = false
      private_network                               = module.vpc.network_self_link
      enable_private_path_for_google_cloud_services = true
      require_ssl                                   = true
      authorized_networks                           = []
      database_flags = [
        {
          name  = "log_statement"
          value = "all"
        },
        {
          name  = "log_min_duration_statement"
          value = "1000"
        }
      ]
      insights_config = {
        query_insights_enabled  = true
        query_string_length     = 1024
        record_application_tags = true
        record_client_address   = true
      }
      maintenance_window = {
        day          = 7
        hour         = 3
        update_track = "stable"
      }
    }
  }

  databases = {
    "app-db" = {
      name         = "acme_customer_portal_db"
      instance_key = "postgres-primary"
    }
    "analytics-db" = {
      name         = "acme_analytics_database"
      instance_key = "postgres-primary"
    }
  }

  users = {
    "app-user" = {
      name         = "acme_ecommerce_app_user"
      instance_key = "postgres-primary"
      password     = "initial-password-change-me"
    }
    "readonly-user" = {
      name         = "acme_ecommerce_readonly_user"
      instance_key = "postgres-primary"
      password     = "readonly-password-change-me"
    }
  }

  ssl_certs = {
    "app-ssl-cert" = {
      common_name  = "app-ssl-cert"
      instance_key = "postgres-primary"
    }
  }

  depends_on = [module.vpc, module.iam]
}

# Redis Module
module "redis" {
  source = "../../modules/database/redis"

  project_id             = local.project_id
  private_vpc_connection = module.vpc.private_vpc_connection

  instances = {
    "cache-primary" = {
      name                    = "acme-ecommerce-cache-${local.environment}"
      tier                    = "BASIC"
      memory_size_gb          = 1
      region                  = local.region
      location_id             = "${local.region}-a"
      alternative_location_id = null
      redis_version           = "REDIS_7_0"
      display_name            = "Application Cache"
      reserved_ip_range       = "10.0.40.0/29"
      auth_enabled            = true
      maintenance_policy = {
        day          = "SUNDAY"
        start_hour   = 3
        start_minute = 0
        start_second = 0
        start_nanos  = 0
      }
      persistence_config = {
        persistence_mode    = "RDB"
        rdb_snapshot_period = "TWELVE_HOURS"
      }
      redis_configs = {
        "maxmemory-policy" = "allkeys-lru"
        "timeout"          = "300"
      }
    }
  }

  depends_on = [module.vpc, module.iam]
}

# Cloud Run Module
module "cloud_run" {
  source = "../../modules/compute/cloud-run"

  project_id             = local.project_id
  service_account_email  = module.iam.service_account_emails["acme-orders-service-sa"]
  private_vpc_connection = module.vpc.private_vpc_connection
  vpc_connector          = null # We'll use direct VPC access

  services = {
    "web-service" = {
      name              = "acme-customer-portal-web-${local.environment}"
      location          = local.region
      image             = "gcr.io/cloudrun/hello"
      container_port    = 8080
      environment       = local.environment
      cpu_limit         = "1"
      memory_limit      = "512Mi"
      cpu_idle          = true
      min_instances     = 0
      max_instances     = 10
      timeout           = "300s"
      health_check_path = "/"
      env_vars          = []
    }

    "api-service" = {
      name              = "acme-orders-api-${local.environment}"
      location          = local.region
      image             = "gcr.io/cloudrun/hello"
      container_port    = 8080
      environment       = local.environment
      cpu_limit         = "2"
      memory_limit      = "1Gi"
      cpu_idle          = true
      min_instances     = 0
      max_instances     = 5
      timeout           = "300s"
      health_check_path = "/health"
      env_vars = [
        {
          name  = "API_VERSION"
          value = "v1"
        }
      ]
    }
  }

  depends_on = [module.vpc, module.iam]
}

# Container Registry Module
module "container_registry" {
  source = "../../modules/storage/container-registry"

  project_id = local.project_id

  repositories = {
    "app-images" = {
      location       = local.region
      repository_id  = "acme-ecommerce-application-images-${local.environment}"
      description    = "Application container images"
      format         = "DOCKER"
      keep_count     = 10
      retention_days = "2592000s" # 30 days
      labels = {
        environment = local.environment
        purpose     = "application-images"
      }
    }
    "base-images" = {
      location       = local.region
      repository_id  = "acme-ecommerce-base-images-${local.environment}"
      description    = "Base container images"
      format         = "DOCKER"
      keep_count     = 5
      retention_days = "5184000s" # 60 days
      labels = {
        environment = local.environment
        purpose     = "base-images"
      }
    }
  }

  repository_iam_bindings = {
    "app-images-access" = {
      repository_key = "app-images"
      role           = "roles/artifactregistry.reader"
      members = [
        "serviceAccount:${module.iam.service_account_emails["acme-customer-api-gke-sa"]}",
        "serviceAccount:${module.iam.service_account_emails["acme-orders-service-sa"]}"
      ]
    }
    "base-images-access" = {
      repository_key = "base-images"
      role           = "roles/artifactregistry.reader"
      members = [
        "serviceAccount:${module.iam.service_account_emails["acme-customer-api-gke-sa"]}",
        "serviceAccount:${module.iam.service_account_emails["acme-orders-service-sa"]}"
      ]
    }
  }

  enable_legacy_registry = false

  depends_on = [module.iam]
}

# Cloud Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring/cloud-monitoring"

  project_id = local.project_id

  # Uptime Checks - Simplified for now
  uptime_checks = {}

  # Alert Policies
  alert_policies = {
    "high-cpu-usage" = {
      display_name = "ACME E-commerce Platform High CPU Usage Alert"
      combiner     = "OR"
      enabled      = true
      condition = {
        display_name    = "CPU usage is high"
        filter          = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
        duration        = "300s"
        comparison      = "COMPARISON_GT"
        threshold_value = 80
        aggregation = {
          alignment_period     = "60s"
          per_series_aligner   = "ALIGN_MEAN"
          cross_series_reducer = "REDUCE_MEAN"
          group_by_fields      = ["resource.label.instance_id"]
        }
      }
      notification_channels = []
      documentation = {
        content   = "CPU usage has exceeded 80% for 5 minutes"
        mime_type = "text/markdown"
      }
    }

    "high-memory-usage" = {
      display_name = "ACME E-commerce Platform High Memory Usage Alert"
      combiner     = "OR"
      enabled      = true
      condition = {
        display_name    = "Memory usage is high"
        filter          = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/memory/balloon/ram_size\""
        duration        = "300s"
        comparison      = "COMPARISON_GT"
        threshold_value = 85
        aggregation = {
          alignment_period     = "60s"
          per_series_aligner   = "ALIGN_MEAN"
          cross_series_reducer = "REDUCE_MEAN"
          group_by_fields      = ["resource.label.instance_id"]
        }
      }
      notification_channels = []
      documentation = {
        content   = "Memory usage has exceeded 85% for 5 minutes"
        mime_type = "text/markdown"
      }
    }

    "disk-space-low" = {
      display_name = "ACME E-commerce Platform Low Disk Space Alert"
      combiner     = "OR"
      enabled      = true
      condition = {
        display_name    = "Disk space is low"
        filter          = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/disk/read_bytes_count\""
        duration        = "300s"
        comparison      = "COMPARISON_LT"
        threshold_value = 10
        aggregation = {
          alignment_period     = "60s"
          per_series_aligner   = "ALIGN_MEAN"
          cross_series_reducer = "REDUCE_MEAN"
          group_by_fields      = ["resource.label.instance_id"]
        }
      }
      notification_channels = []
      documentation = {
        content   = "Available disk space is below 10% for 5 minutes"
        mime_type = "text/markdown"
      }
    }
  }

  # Services to Monitor
  services = {
    "cloud-run-web" = {
      service_id   = "terragrunt-471602-dev-web"
      display_name = "ACME Customer Portal Web Service"
      user_labels = {
        environment  = local.environment
        service_type = "web"
      }
    }

    "cloud-run-api" = {
      service_id   = "terragrunt-471602-dev-api"
      display_name = "ACME Orders API Service"
      user_labels = {
        environment  = local.environment
        service_type = "api"
      }
    }
  }

  # SLOs
  slos = {
    "web-service-availability" = {
      service_key         = "cloud-run-web"
      slo_id              = "web-availability-slo"
      display_name        = "ACME Customer Portal Web Service Availability SLO"
      goal                = 0.99
      rolling_period_days = 30
      basic_sli = {
        availability = {
          enabled = true
        }
      }
    }

    "api-service-availability" = {
      service_key         = "cloud-run-api"
      slo_id              = "api-availability-slo"
      display_name        = "ACME Orders API Service Availability SLO"
      goal                = 0.99
      rolling_period_days = 30
      basic_sli = {
        availability = {
          enabled = true
        }
      }
    }
  }

  depends_on = [module.cloud_run, module.compute]
}

# Cloud Logging Module
module "logging" {
  source = "../../modules/monitoring/cloud-logging"

  project_id = local.project_id

  # Log Sinks
  log_sinks = {
    "security-logs" = {
      name                   = "security-logs-sink"
      destination            = "bigquery.googleapis.com/projects/${local.project_id}/datasets/security_logs"
      filter                 = "severity>=ERROR AND resource.type=\"gce_instance\""
      unique_writer_identity = true
      exclusions             = []
    }

    "application-logs" = {
      name                   = "acme-ecommerce-application-logs-sink"
      destination            = "bigquery.googleapis.com/projects/${local.project_id}/datasets/application_logs"
      filter                 = "resource.type=\"cloud_run_revision\""
      unique_writer_identity = true
      exclusions             = []
    }

    "audit-logs" = {
      name                   = "acme-ecommerce-audit-logs-sink"
      destination            = "storage.googleapis.com/terragrunt-471602-dev-logs"
      filter                 = "protoPayload.serviceName=\"cloudsql.googleapis.com\" OR protoPayload.serviceName=\"redis.googleapis.com\""
      unique_writer_identity = true
      exclusions             = []
    }
  }

  # Log Metrics - Simplified for now
  log_metrics = {}

  # Log Exclusions
  log_exclusions = {
    "health-check-logs" = {
      name        = "acme-ecommerce-health-check-exclusion"
      description = "Exclude health check logs"
      filter      = "resource.type=\"cloud_run_revision\" AND httpRequest.requestUrl=\"/health\""
      disabled    = false
    }

    "debug-logs" = {
      name        = "acme-ecommerce-debug-logs-exclusion"
      description = "Exclude debug level logs"
      filter      = "severity=\"DEBUG\""
      disabled    = false
    }
  }

  depends_on = [module.storage]
}

# Output for Phase 0 validation
output "phase_0_complete" {
  description = "Phase 0: Foundation Setup completed successfully"
  value       = "✅ Foundation setup complete - APIs enabled, project structure ready"
}

output "phase_1_complete" {
  description = "Phase 1: Networking Foundation completed successfully"
  value       = "✅ Networking foundation complete - VPC, subnets, and firewall rules created"
}

output "phase_2_complete" {
  description = "Phase 2: Security & Identity completed successfully"
  value       = "✅ Security & Identity complete - IAM, KMS, Secret Manager configured"
}

output "phase_3_complete" {
  description = "Phase 3: Compute & Storage completed successfully"
  value       = "✅ Compute & Storage complete - VM instances, load balancer, and storage buckets created"
}

output "phase_4_complete" {
  description = "Phase 4: Database & Caching completed successfully"
  value       = "✅ Database & Caching complete - Cloud SQL, Redis, and database management configured"
}

output "phase_5_complete" {
  description = "Phase 5: Container Orchestration completed successfully"
  value       = "✅ Container Orchestration complete - Cloud Run services, container registry, and container management configured"
}

output "phase_6_complete" {
  description = "Phase 6: Monitoring & Logging completed successfully"
  value       = "✅ Monitoring & Logging complete - Cloud Monitoring, Logging, Alerting, and observability configured"
}

output "enabled_apis" {
  description = "List of enabled APIs"
  value       = [for api in google_project_service.required_apis : api.service]
}

output "project_id" {
  description = "GCP Project ID"
  value       = local.project_id
}

output "environment" {
  description = "Environment name"
  value       = local.environment
}

output "region" {
  description = "GCP region"
  value       = local.region
}

output "vpc_name" {
  description = "VPC network name"
  value       = module.vpc.network_name
}

output "vpc_self_link" {
  description = "VPC network self link"
  value       = module.vpc.network_self_link
}

output "subnets" {
  description = "Created subnets"
  value       = module.subnets.subnets
}

output "service_accounts" {
  description = "Created service accounts"
  value       = module.iam.service_account_emails
}

output "kms_key_ring" {
  description = "KMS key ring"
  value       = module.kms.key_ring_id
}

output "crypto_keys" {
  description = "KMS crypto keys"
  value       = module.kms.crypto_key_ids
}

output "secrets" {
  description = "Secret Manager secrets"
  value       = module.secret_manager.secret_ids
}

output "instance_templates" {
  description = "Created instance templates"
  value       = module.compute.instance_templates
}

output "instance_groups" {
  description = "Created instance group managers"
  value       = module.compute.instance_group_managers
}

output "load_balancer_ip" {
  description = "Load balancer global IP address"
  value       = module.load_balancer.global_ip_address
}

output "storage_buckets" {
  description = "Created storage buckets"
  value       = module.storage.bucket_names
}

output "database_instances" {
  description = "Created Cloud SQL instances"
  value       = module.database.instance_connection_names
}

output "database_private_ips" {
  description = "Cloud SQL instance private IP addresses"
  value       = module.database.instance_private_ip_addresses
}

output "redis_instances" {
  description = "Created Redis instances"
  value       = module.redis.instance_hosts
}

output "redis_ports" {
  description = "Redis instance ports"
  value       = module.redis.instance_ports
}

output "cloud_run_services" {
  description = "Created Cloud Run services"
  value       = module.cloud_run.service_names
}

output "cloud_run_urls" {
  description = "Cloud Run service URLs"
  value       = module.cloud_run.service_urls
}

output "cloud_run_locations" {
  description = "Cloud Run service locations"
  value       = module.cloud_run.service_locations
}

output "container_repositories" {
  description = "Created container repositories"
  value       = module.container_registry.repository_names
}
output "uptime_checks" {
  description = "Created uptime checks"
  value       = module.monitoring.uptime_check_names
}

output "alert_policies" {
  description = "Created alert policies"
  value       = module.monitoring.alert_policy_names
}

output "monitoring_services" {
  description = "Created monitoring services"
  value       = module.monitoring.service_names
}

output "slos" {
  description = "Created SLOs"
  value       = module.monitoring.slo_names
}

output "log_sinks" {
  description = "Created log sinks"
  value       = module.logging.log_sink_names
}

output "log_metrics" {
  description = "Created log metrics"
  value       = module.logging.log_metric_names
}

output "log_exclusions" {
  description = "Created log exclusions"
  value       = module.logging.log_exclusion_names
}


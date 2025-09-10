# Terraform-GCP Implementation Guide

## 🎯 Quick Start

This guide provides step-by-step instructions for implementing the terraform-gcp infrastructure using the phased rollout plan.

## 📋 Prerequisites

### 1. Required Tools
```bash
# Install required tools
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y terraform gcloud kubectl jq curl

# macOS
brew install terraform google-cloud-sdk kubernetes-cli jq curl

# Windows (using Chocolatey)
choco install terraform gcloudsdk kubernetes-cli jq curl
```

### 2. GCP Setup
```bash
# Authenticate with GCP
gcloud auth login
gcloud auth application-default login

# Create or select project
gcloud projects create your-project-id --name="Your Project Name"
gcloud config set project your-project-id

# Enable required APIs
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable storage.googleapis.com
```

### 3. Environment Variables
```bash
# Set required environment variables
export PROJECT_ID="your-project-id"
export ENVIRONMENT="dev"
export REGION="us-central1"
export ZONE="us-central1-a"
```

## 🚀 Phase 0: Foundation Setup

### Step 1: Initialize Project Structure
```bash
# Clone or create project structure
mkdir -p infrastructure/environments/dev
mkdir -p infrastructure/modules/{networking,compute,data,security,monitoring}
mkdir -p scripts/{phase-testing,automation}
mkdir -p .github/workflows
```

### Step 2: Create Basic Terraform Files
```bash
# Create main.tf
cat > infrastructure/environments/dev/main.tf << 'EOF'
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
EOF

# Create variables.tf
cat > infrastructure/environments/dev/variables.tf << 'EOF'
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
EOF

# Create terraform.tfvars
cat > infrastructure/environments/dev/terraform.tfvars << 'EOF'
project_id  = "your-project-id"
region      = "us-central1"
environment = "dev"
EOF

# Create backend.tf
cat > infrastructure/environments/dev/backend.tf << 'EOF'
terraform {
  backend "gcs" {
    bucket = "your-project-id-terraform-state-dev"
    prefix = "terraform/state"
  }
}
EOF
```

### Step 3: Create GCS Bucket for State
```bash
# Create GCS bucket for Terraform state
gsutil mb gs://your-project-id-terraform-state-dev
gsutil versioning set on gs://your-project-id-terraform-state-dev
```

### Step 4: Deploy Foundation
```bash
# Deploy Phase 0
./scripts/automation/phase-deployment.sh -p your-project-id -e dev 0
```

### Step 5: Validate Foundation
```bash
# Run Phase 0 tests
./scripts/phase-testing/phase-0-tests.sh
```

## 🌐 Phase 1: Networking Foundation

### Step 1: Create Networking Modules
```bash
# Create VPC module
mkdir -p infrastructure/modules/networking/vpc
cat > infrastructure/modules/networking/vpc/main.tf << 'EOF'
resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = var.routing_mode
  
  project = var.project_id
  
  delete_default_routes_on_create = var.delete_default_routes_on_create
}

resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.network_name}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.self_link
  project       = var.project_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}
EOF

# Create subnets module
mkdir -p infrastructure/modules/networking/subnets
cat > infrastructure/modules/networking/subnets/main.tf << 'EOF'
resource "google_compute_subnetwork" "subnets" {
  for_each = { for subnet in var.subnets : subnet.subnet_name => subnet }
  
  name          = each.value.subnet_name
  ip_cidr_range = each.value.subnet_ip
  region        = each.value.subnet_region
  network       = var.network_name
  project       = var.project_id
  
  private_ip_google_access = each.value.subnet_private_access
  enable_flow_logs         = each.value.subnet_flow_logs
  
  dynamic "secondary_ip_range" {
    for_each = var.secondary_ranges[each.value.subnet_name] != null ? var.secondary_ranges[each.value.subnet_name] : []
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }
}
EOF
```

### Step 2: Update Main Configuration
```bash
# Add networking to main.tf
cat >> infrastructure/environments/dev/main.tf << 'EOF'

# VPC Module
module "vpc" {
  source = "../../modules/networking/vpc"
  
  project_id   = local.project_id
  network_name = "${local.project_id}-${local.environment}-vpc"
  routing_mode = "REGIONAL"
  
  shared_vpc_host = false
  delete_default_routes_on_create = true
}

# Subnets Module
module "subnets" {
  source = "../../modules/networking/subnets"
  
  project_id   = local.project_id
  network_name = module.vpc.network_name
  
  subnets = [
    {
      subnet_name           = "${local.project_id}-${local.environment}-${local.region}-public"
      subnet_ip            = "10.0.1.0/24"
      subnet_region        = local.region
      subnet_private_access = true
      subnet_flow_logs     = true
    },
    {
      subnet_name           = "${local.project_id}-${local.environment}-${local.region}-private"
      subnet_ip            = "10.0.10.0/24"
      subnet_region        = local.region
      subnet_private_access = true
      subnet_flow_logs     = true
    },
    {
      subnet_name           = "${local.project_id}-${local.environment}-${local.region}-database"
      subnet_ip            = "10.0.20.0/24"
      subnet_region        = local.region
      subnet_private_access = true
      subnet_flow_logs     = false
    },
    {
      subnet_name           = "${local.project_id}-${local.environment}-${local.region}-gke"
      subnet_ip            = "10.0.30.0/24"
      subnet_region        = local.region
      subnet_private_access = true
      subnet_flow_logs     = true
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
EOF
```

### Step 3: Deploy Networking
```bash
# Deploy Phase 1
./scripts/automation/phase-deployment.sh -p your-project-id -e dev 1
```

### Step 4: Validate Networking
```bash
# Run Phase 1 tests
./scripts/phase-testing/phase-1-tests.sh
```

## 🔐 Phase 2: Security & Identity

### Step 1: Create Security Modules
```bash
# Create IAM module
mkdir -p infrastructure/modules/security/iam
cat > infrastructure/modules/security/iam/main.tf << 'EOF'
resource "google_service_account" "service_accounts" {
  for_each = { for sa in var.service_accounts : sa.account_id => sa }
  
  account_id   = each.value.account_id
  display_name = each.value.display_name
  project      = var.project_id
}

resource "google_project_iam_member" "service_account_roles" {
  for_each = {
    for combo in flatten([
      for sa in var.service_accounts : [
        for role in sa.roles : {
          sa_id = sa.account_id
          role  = role
        }
      ]
    ]) : "${combo.sa_id}-${combo.role}" => combo
  }
  
  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.service_accounts[each.value.sa_id].email}"
}
EOF

# Create KMS module
mkdir -p infrastructure/modules/security/kms
cat > infrastructure/modules/security/kms/main.tf << 'EOF'
resource "google_kms_key_ring" "keyring" {
  name     = var.keyring_name
  location = var.location
  project  = var.project_id
}

resource "google_kms_crypto_key" "keys" {
  for_each = { for key in var.keys : key.name => key }
  
  name     = each.value.name
  key_ring = google_kms_key_ring.keyring.id
  
  rotation_period = each.value.rotation_period
  purpose         = each.value.purpose
  
  version_template {
    algorithm = each.value.algorithm
  }
  
  labels = each.value.labels
}
EOF
```

### Step 2: Update Main Configuration
```bash
# Add security to main.tf
cat >> infrastructure/environments/dev/main.tf << 'EOF'

# IAM Module
module "iam" {
  source = "../../modules/security/iam"
  
  project_id = local.project_id
  
  service_accounts = [
    {
      account_id   = "${local.project_id}-${local.environment}-${local.region}-gke-sa"
      display_name = "GKE Service Account"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
        "roles/monitoring.viewer"
      ]
    },
    {
      account_id   = "${local.project_id}-${local.environment}-${local.region}-cloud-run-sa"
      display_name = "Cloud Run Service Account"
      roles = [
        "roles/cloudsql.client",
        "roles/secretmanager.secretAccessor",
        "roles/datastore.user"
      ]
    }
  ]
}

# KMS Module
module "kms" {
  source = "../../modules/security/kms"
  
  project_id = local.project_id
  location   = local.region
  
  keyring_name = "${local.project_id}-${local.environment}-${local.region}-keyring"
  
  keys = [
    {
      name               = "encryption-key"
      rotation_period    = "7776000s" # 90 days
      algorithm          = "GOOGLE_SYMMETRIC_ENCRYPTION"
      purpose           = "ENCRYPT_DECRYPT"
      labels            = local.common_labels
    }
  ]
}
EOF
```

### Step 3: Deploy Security
```bash
# Deploy Phase 2
./scripts/automation/phase-deployment.sh -p your-project-id -e dev 2
```

### Step 4: Validate Security
```bash
# Run Phase 2 tests
./scripts/phase-testing/phase-2-tests.sh
```

## 💾 Phase 3: Data Layer

### Step 1: Create Data Modules
```bash
# Create Cloud SQL module
mkdir -p infrastructure/modules/data/cloud-sql
cat > infrastructure/modules/data/cloud-sql/main.tf << 'EOF'
resource "google_sql_database_instance" "instance" {
  name             = var.name
  database_version = var.database_version
  region           = var.region
  project          = var.project_id
  
  settings {
    tier              = var.tier
    availability_type = var.availability_type
    disk_size         = var.disk_size
    disk_type         = var.disk_type
    disk_autoresize   = var.disk_autoresize
    
    backup_configuration {
      enabled                        = var.backup_configuration.enabled
      start_time                     = var.backup_configuration.start_time
      point_in_time_recovery_enabled = var.backup_configuration.point_in_time_recovery_enabled
      transaction_log_retention_days = var.backup_configuration.transaction_log_retention_days
      retained_backups              = var.backup_configuration.retained_backups
    }
    
    ip_configuration {
      ipv4_enabled    = var.ip_configuration.ipv4_enabled
      private_network = var.ip_configuration.private_network
      require_ssl     = var.ip_configuration.require_ssl
    }
    
    dynamic "database_flags" {
      for_each = var.database_flags
      content {
        name  = database_flags.value.name
        value = database_flags.value.value
      }
    }
  }
  
  labels = var.user_labels
}

resource "google_sql_database" "database" {
  name     = var.database_name
  instance = google_sql_database_instance.instance.name
  project  = var.project_id
}

resource "google_sql_user" "user" {
  name     = var.user_name
  instance = google_sql_database_instance.instance.name
  password = var.user_password
  project  = var.project_id
}
EOF
```

### Step 2: Update Main Configuration
```bash
# Add data layer to main.tf
cat >> infrastructure/environments/dev/main.tf << 'EOF'

# Cloud SQL Module
module "cloud_sql" {
  source = "../../modules/data/cloud-sql"
  
  project_id = local.project_id
  region     = local.region
  
  name             = "${local.project_id}-${local.environment}-${local.region}-db"
  database_version = "POSTGRES_14"
  tier            = "db-n1-standard-2"
  
  availability_type = "ZONAL"
  
  disk_size         = 100
  disk_type         = "PD_SSD"
  disk_autoresize   = true
  
  backup_configuration = {
    enabled                        = true
    start_time                     = "03:00"
    point_in_time_recovery_enabled = false
    transaction_log_retention_days = 3
    retained_backups              = 7
  }
  
  ip_configuration = {
    ipv4_enabled    = false
    private_network = module.vpc.network_self_link
    require_ssl     = true
  }
  
  database_flags = [
    {
      name  = "max_connections"
      value = "100"
    }
  ]
  
  user_labels = local.common_labels
  
  depends_on = [
    module.vpc,
    google_service_networking_connection.private_vpc_connection
  ]
}
EOF
```

### Step 3: Deploy Data Layer
```bash
# Deploy Phase 3
./scripts/automation/phase-deployment.sh -p your-project-id -e dev 3
```

### Step 4: Validate Data Layer
```bash
# Run Phase 3 tests
./scripts/phase-testing/phase-3-tests.sh
```

## 🖥️ Phase 4: Compute Platform

### Step 1: Create Compute Modules
```bash
# Create GKE module
mkdir -p infrastructure/modules/compute/gke
cat > infrastructure/modules/compute/gke/main.tf << 'EOF'
resource "google_container_cluster" "cluster" {
  name     = var.name
  location = var.location
  project  = var.project_id
  
  network    = var.network
  subnetwork = var.subnetwork
  
  ip_allocation_policy {
    cluster_secondary_range_name  = var.ip_range_pods
    services_secondary_range_name = var.ip_range_services
  }
  
  master_ipv4_cidr_block = var.master_ipv4_cidr_block
  
  enable_private_nodes    = var.enable_private_nodes
  enable_private_endpoint = var.enable_private_endpoint
  
  dynamic "node_pool" {
    for_each = var.node_pools
    content {
      name               = node_pool.value.name
      machine_type       = node_pool.value.machine_type
      min_count          = node_pool.value.min_count
      max_count          = node_pool.value.max_count
      initial_node_count = node_pool.value.initial_node_count
      disk_size_gb       = node_pool.value.disk_size_gb
      disk_type          = node_pool.value.disk_type
      preemptible        = node_pool.value.preemptible
      auto_repair        = node_pool.value.auto_repair
      auto_upgrade       = node_pool.value.auto_upgrade
    }
  }
  
  node_pools_labels = var.node_pools_labels
  node_pools_tags   = var.node_pools_tags
  
  depends_on = [var.depends_on]
}
EOF
```

### Step 2: Update Main Configuration
```bash
# Add compute platform to main.tf
cat >> infrastructure/environments/dev/main.tf << 'EOF'

# GKE Cluster
module "gke" {
  source = "../../modules/compute/gke"
  
  project_id     = local.project_id
  name           = "${local.project_id}-${local.environment}-${local.region}-gke"
  location       = local.region
  
  network    = module.vpc.network_name
  subnetwork = module.subnets.subnets["${local.project_id}-${local.environment}-${local.region}-gke"].name
  
  ip_range_pods     = "gke-pods"
  ip_range_services = "gke-services"
  
  master_ipv4_cidr_block = "172.16.0.0/28"
  
  enable_private_nodes    = true
  enable_private_endpoint = false
  
  node_pools = [
    {
      name               = "default-pool"
      machine_type       = "n2-standard-2"
      min_count          = 1
      max_count          = 3
      initial_node_count = 1
      disk_size_gb       = 100
      disk_type          = "pd-standard"
      preemptible        = true
      auto_repair        = true
      auto_upgrade       = true
    }
  ]
  
  node_pools_labels = {
    all = local.common_labels
    default-pool = {
      pool = "default"
    }
  }
  
  node_pools_tags = {
    all = ["gke-node", "${local.environment}-gke-node"]
    default-pool = []
  }
  
  depends_on = [
    module.vpc,
    module.subnets,
    google_project_service.required_apis
  ]
}
EOF
```

### Step 3: Deploy Compute Platform
```bash
# Deploy Phase 4
./scripts/automation/phase-deployment.sh -p your-project-id -e dev 4
```

### Step 4: Validate Compute Platform
```bash
# Run Phase 4 tests
./scripts/phase-testing/phase-4-tests.sh
```

## 📊 Phase 5: Monitoring & Observability

### Step 1: Create Monitoring Modules
```bash
# Create logging module
mkdir -p infrastructure/modules/monitoring/logging
cat > infrastructure/modules/monitoring/logging/main.tf << 'EOF'
resource "google_logging_project_sink" "log_sinks" {
  for_each = { for sink in var.log_sinks : sink.name => sink }
  
  name        = each.value.name
  destination = each.value.destination
  filter      = each.value.filter
  
  unique_writer_identity = each.value.unique_writer_identity
  
  dynamic "bigquery_options" {
    for_each = each.value.bigquery_options != null ? [each.value.bigquery_options] : []
    content {
      use_partitioned_tables = bigquery_options.value.use_partitioned_tables
    }
  }
}
EOF
```

### Step 2: Update Main Configuration
```bash
# Add monitoring to main.tf
cat >> infrastructure/environments/dev/main.tf << 'EOF'

# Logging Module
module "logging" {
  source = "../../modules/monitoring/logging"
  
  project_id = local.project_id
  
  log_sinks = [
    {
      name        = "${local.project_id}-${local.environment}-${local.region}-critical-logs"
      destination = "storage.googleapis.com/${google_storage_bucket.logs.name}"
      filter      = "severity >= ERROR"
      unique_writer_identity = true
    }
  ]
  
  depends_on = [google_project_service.required_apis]
}

# Log bucket for storage
resource "google_storage_bucket" "logs" {
  name     = "${local.project_id}-${local.environment}-logs"
  location = local.region
  project  = local.project_id
  
  uniform_bucket_level_access = true
  
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
  
  labels = local.common_labels
}
EOF
```

### Step 3: Deploy Monitoring
```bash
# Deploy Phase 5
./scripts/automation/phase-deployment.sh -p your-project-id -e dev 5
```

### Step 4: Validate Monitoring
```bash
# Run Phase 5 tests
./scripts/phase-testing/phase-5-tests.sh
```

## 🏭 Phase 6: Production Hardening

### Step 1: Update for Production
```bash
# Update terraform.tfvars for production
cat > infrastructure/environments/prod/terraform.tfvars << 'EOF'
project_id  = "your-project-id"
region      = "us-central1"
environment = "prod"
EOF
```

### Step 2: Deploy Production Hardening
```bash
# Deploy Phase 6
./scripts/automation/phase-deployment.sh -p your-project-id -e prod 6
```

### Step 3: Validate Production Hardening
```bash
# Run Phase 6 tests
./scripts/phase-testing/phase-6-tests.sh
```

## 🔍 Health Checks and Monitoring

### Run Comprehensive Health Check
```bash
# Run health check
./scripts/automation/health-check.sh -p your-project-id -e dev

# Generate HTML report
./scripts/automation/health-check.sh -p your-project-id -e dev -f html -o health-report.html
```

### Monitor Infrastructure
```bash
# Check GKE cluster status
gcloud container clusters describe your-cluster-name --region=us-central1

# Check Cloud SQL status
gcloud sql instances list

# Check Cloud Run services
gcloud run services list --region=us-central1
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Authentication Errors
```bash
# Re-authenticate
gcloud auth login
gcloud auth application-default login
```

#### 2. Permission Errors
```bash
# Check permissions
gcloud projects get-iam-policy your-project-id
```

#### 3. Resource Not Found
```bash
# Check resource status
gcloud compute instances list --project=your-project-id
gcloud container clusters list --project=your-project-id
```

#### 4. Network Issues
```bash
# Check VPC configuration
gcloud compute networks describe your-vpc-name
gcloud compute firewall-rules list --filter="network:your-vpc-name"
```

### Rollback Procedures
```bash
# Rollback specific phase
./scripts/automation/rollback-phase.sh -p your-project-id -e dev 1

# Force rollback without confirmation
./scripts/automation/rollback-phase.sh -p your-project-id -e dev 1 --force
```

## 📚 Next Steps

### 1. Application Deployment
- Deploy your applications to GKE
- Configure Cloud Run services
- Set up Cloud Functions

### 2. Monitoring Setup
- Configure alerting policies
- Set up dashboards
- Implement log analysis

### 3. Security Hardening
- Review IAM policies
- Enable security monitoring
- Implement compliance checks

### 4. Cost Optimization
- Review resource usage
- Implement cost controls
- Set up budget alerts

## 🎉 Success Criteria

Your infrastructure is ready when:
- ✅ All phases deployed successfully
- ✅ All health checks passing
- ✅ Applications running correctly
- ✅ Monitoring and alerting operational
- ✅ Security controls in place
- ✅ Cost optimization implemented

---

*This implementation guide provides step-by-step instructions for deploying the terraform-gcp infrastructure. Follow each phase carefully and validate with the provided testing scripts.*

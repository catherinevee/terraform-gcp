# Terraform Implementation Structure for GCP

## Directory Structure

```
infrastructure/
├── .gitignore
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml        # PR validation workflow
│       ├── terraform-apply.yml       # Deployment workflow
│       └── terraform-destroy.yml     # Teardown workflow
├── README.md
├── Makefile                           # Common commands
├── environments/
│   ├── dev/
│   │   ├── main.tf                   # Main configuration
│   │   ├── variables.tf              # Variable definitions
│   │   ├── outputs.tf                # Output values
│   │   ├── providers.tf              # Provider configuration
│   │   ├── backend.tf                # Backend configuration
│   │   ├── terraform.tfvars          # Environment-specific values
│   │   ├── networking.tf             # Network resources
│   │   ├── compute.tf                # Compute resources
│   │   ├── data.tf                   # Data resources
│   │   ├── security.tf               # Security resources
│   │   └── monitoring.tf             # Monitoring resources
│   ├── staging/
│   │   └── [similar structure to dev]
│   └── prod/
│       └── [similar structure to dev]
├── modules/                           # Reusable Terraform modules
│   ├── networking/
│   │   ├── vpc/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   ├── versions.tf
│   │   │   └── README.md
│   │   ├── subnets/
│   │   ├── nat/
│   │   ├── firewall/
│   │   ├── load-balancer/
│   │   └── cdn/
│   ├── compute/
│   │   ├── gke/
│   │   ├── cloud-run/
│   │   ├── app-engine/
│   │   └── cloud-functions/
│   ├── data/
│   │   ├── cloud-sql/
│   │   ├── redis/
│   │   ├── gcs/
│   │   ├── bigquery/
│   │   └── pubsub/
│   ├── security/
│   │   ├── iam/
│   │   ├── kms/
│   │   └── secrets/
│   └── monitoring/
│       ├── logging/
│       ├── monitoring/
│       └── alerts/
├── global/                            # Global/shared resources
│   ├── iam/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── dns/
│   └── projects/
└── scripts/
    ├── init-backend.sh                # Initialize GCS backend
    ├── validate.sh                    # Validation script
    └── cost-estimate.sh               # Cost estimation with Infracost
```

## Configuration Files

### Root Makefile
```makefile
# infrastructure/Makefile

.PHONY: help init validate plan apply destroy fmt lint clean

ENVIRONMENT ?= dev
TERRAFORM := terraform
TERRAFORM_DIR := environments/$(ENVIRONMENT)

help: ## Show this help message
	@echo 'Usage: make [target] ENVIRONMENT=[dev|staging|prod]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*##"; printf "\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

init: ## Initialize Terraform
	@echo "Initializing Terraform for $(ENVIRONMENT)..."
	cd $(TERRAFORM_DIR) && $(TERRAFORM) init -reconfigure

validate: fmt ## Validate Terraform configuration
	@echo "Validating Terraform configuration for $(ENVIRONMENT)..."
	cd $(TERRAFORM_DIR) && $(TERRAFORM) validate

plan: validate ## Create Terraform plan
	@echo "Creating Terraform plan for $(ENVIRONMENT)..."
	cd $(TERRAFORM_DIR) && $(TERRAFORM) plan -var-file=terraform.tfvars -out=tfplan

apply: ## Apply Terraform configuration
	@echo "Applying Terraform configuration for $(ENVIRONMENT)..."
	cd $(TERRAFORM_DIR) && $(TERRAFORM) apply tfplan

destroy: ## Destroy Terraform resources
	@echo "Destroying Terraform resources for $(ENVIRONMENT)..."
	cd $(TERRAFORM_DIR) && $(TERRAFORM) destroy -var-file=terraform.tfvars -auto-approve

fmt: ## Format Terraform files
	@echo "Formatting Terraform files..."
	$(TERRAFORM) fmt -recursive .

lint: ## Run tflint
	@echo "Running tflint..."
	tflint --recursive

clean: ## Clean temporary files
	@echo "Cleaning temporary files..."
	find . -type f -name "*.tfplan" -delete
	find . -type f -name "*.tfstate*" -delete
	find . -type d -name ".terraform" -exec rm -rf {} +

cost: ## Estimate costs with Infracost
	@echo "Estimating costs for $(ENVIRONMENT)..."
	cd $(TERRAFORM_DIR) && infracost breakdown --path . --terraform-var-file terraform.tfvars

security: ## Run security scan with tfsec
	@echo "Running security scan..."
	tfsec $(TERRAFORM_DIR)

docs: ## Generate documentation
	@echo "Generating documentation..."
	terraform-docs markdown table --recursive modules/ > MODULES.md

graph: ## Generate dependency graph
	@echo "Generating dependency graph for $(ENVIRONMENT)..."
	cd $(TERRAFORM_DIR) && $(TERRAFORM) graph | dot -Tpng > ../../terraform-graph-$(ENVIRONMENT).png
```

### Environment Configuration (Dev)
```hcl
# infrastructure/environments/dev/main.tf

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Local variables
locals {
  environment = "dev"
  project_id  = var.project_id
  region      = var.region
  zones       = data.google_compute_zones.available.names
  
  # Common labels for all resources
  common_labels = {
    environment  = local.environment
    managed_by   = "terraform"
    project      = local.project_id
    cost_center  = var.cost_center
    team         = var.team
    region       = local.region
  }
  
  # Network configuration
  network_name = "${local.project_id}-${local.environment}-vpc"
  
  # Naming prefix for all resources
  name_prefix = "${local.project_id}-${local.environment}-${local.region}"
}

# Data sources
data "google_compute_zones" "available" {
  project = local.project_id
  region  = local.region
}

data "google_project" "project" {
  project_id = local.project_id
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
```

### Variables Definition
```hcl
# infrastructure/environments/dev/variables.tf

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "engineering"
}

variable "team" {
  description = "Team responsible for resources"
  type        = string
  default     = "platform"
}

# Networking variables
variable "vpc_cidr" {
  description = "CIDR for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidrs" {
  description = "CIDR ranges for subnets"
  type = object({
    public   = string
    private  = string
    database = string
    gke      = string
  })
  default = {
    public   = "10.0.1.0/24"
    private  = "10.0.10.0/24"
    database = "10.0.20.0/24"
    gke      = "10.0.30.0/24"
  }
}

# GKE variables
variable "gke_config" {
  description = "GKE cluster configuration"
  type = object({
    min_nodes     = number
    max_nodes     = number
    machine_type  = string
    disk_size_gb  = number
    preemptible   = bool
  })
  default = {
    min_nodes     = 1
    max_nodes     = 3
    machine_type  = "n2-standard-2"
    disk_size_gb  = 100
    preemptible   = true
  }
}

# Cloud Run variables
variable "cloud_run_config" {
  description = "Cloud Run configuration"
  type = object({
    min_instances = number
    max_instances = number
    cpu           = string
    memory        = string
  })
  default = {
    min_instances = 0
    max_instances = 10
    cpu           = "1"
    memory        = "512Mi"
  }
}

# Database variables
variable "database_config" {
  description = "Cloud SQL configuration"
  type = object({
    database_version = string
    tier            = string
    availability_type = string
    backup_enabled   = bool
    backup_time     = string
  })
  default = {
    database_version  = "POSTGRES_14"
    tier             = "db-n1-standard-2"
    availability_type = "ZONAL"
    backup_enabled    = true
    backup_time      = "03:00"
  }
}

# BigQuery variables
variable "bigquery_config" {
  description = "BigQuery configuration"
  type = object({
    dataset_location              = string
    default_table_expiration_days = number
  })
  default = {
    dataset_location              = "US"
    default_table_expiration_days = 90
  }
}
```

### Environment Variables File
```hcl
# infrastructure/environments/dev/terraform.tfvars

project_id  = "acme-dev-project"
region      = "us-central1"
cost_center = "engineering"
team        = "platform"

# Network configuration
vpc_cidr = "10.0.0.0/16"

subnet_cidrs = {
  public   = "10.0.1.0/24"
  private  = "10.0.10.0/24"
  database = "10.0.20.0/24"
  gke      = "10.0.30.0/24"
}

# GKE configuration for dev
gke_config = {
  min_nodes     = 1
  max_nodes     = 3
  machine_type  = "n2-standard-2"
  disk_size_gb  = 100
  preemptible   = true
}

# Cloud Run configuration
cloud_run_config = {
  min_instances = 0
  max_instances = 10
  cpu           = "1"
  memory        = "512Mi"
}

# Database configuration
database_config = {
  database_version  = "POSTGRES_14"
  tier             = "db-n1-standard-2"
  availability_type = "ZONAL"
  backup_enabled    = true
  backup_time      = "03:00"
}

# BigQuery configuration
bigquery_config = {
  dataset_location              = "US"
  default_table_expiration_days = 90
}
```

### Backend Configuration
```hcl
# infrastructure/environments/dev/backend.tf

terraform {
  backend "gcs" {
    bucket = "acme-terraform-state-dev"
    prefix = "terraform/state"
  }
}
```

### Provider Configuration
```hcl
# infrastructure/environments/dev/providers.tf

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
```

### Networking Resources
```hcl
# infrastructure/environments/dev/networking.tf

# VPC Module
module "vpc" {
  source = "../../modules/networking/vpc"
  
  project_id   = local.project_id
  network_name = local.network_name
  routing_mode = "REGIONAL"
  
  shared_vpc_host = false
  
  delete_default_routes_on_create = true
  
  labels = local.common_labels
}

# Subnets Module
module "subnets" {
  source = "../../modules/networking/subnets"
  
  project_id   = local.project_id
  network_name = module.vpc.network_name
  
  subnets = [
    {
      subnet_name           = "${local.name_prefix}-public"
      subnet_ip            = var.subnet_cidrs.public
      subnet_region        = local.region
      subnet_private_access = true
      subnet_flow_logs     = true
      description          = "Public subnet"
    },
    {
      subnet_name           = "${local.name_prefix}-private"
      subnet_ip            = var.subnet_cidrs.private
      subnet_region        = local.region
      subnet_private_access = true
      subnet_flow_logs     = true
      description          = "Private subnet"
    },
    {
      subnet_name           = "${local.name_prefix}-database"
      subnet_ip            = var.subnet_cidrs.database
      subnet_region        = local.region
      subnet_private_access = true
      subnet_flow_logs     = false
      description          = "Database subnet"
    },
    {
      subnet_name           = "${local.name_prefix}-gke"
      subnet_ip            = var.subnet_cidrs.gke
      subnet_region        = local.region
      subnet_private_access = true
      subnet_flow_logs     = true
      description          = "GKE subnet"
    }
  ]
  
  secondary_ranges = {
    "${local.name_prefix}-gke" = [
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

# NAT Module
module "nat" {
  source = "../../modules/networking/nat"
  
  project_id = local.project_id
  region     = local.region
  
  router_name = "${local.name_prefix}-router"
  network     = module.vpc.network_name
  
  nats = [{
    name                               = "${local.name_prefix}-nat"
    source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
    subnetworks = [
      {
        name                     = module.subnets.subnets["${local.name_prefix}-private"].name
        source_ip_ranges_to_nat  = ["ALL_IP_RANGES"]
      },
      {
        name                     = module.subnets.subnets["${local.name_prefix}-gke"].name
        source_ip_ranges_to_nat  = ["ALL_IP_RANGES"]
      }
    ]
    min_ports_per_vm                    = "64"
    max_ports_per_vm                    = "4096"
    log_config_enable                   = true
    log_config_filter                   = "ERRORS_ONLY"
  }]
  
  depends_on = [module.subnets]
}

# Firewall Module
module "firewall" {
  source = "../../modules/networking/firewall"
  
  project_id   = local.project_id
  network      = module.vpc.network_name
  
  rules = [
    {
      name        = "${local.name_prefix}-allow-iap"
      description = "Allow IAP access"
      direction   = "INGRESS"
      priority    = 1000
      ranges      = ["35.235.240.0/20"]
      allow = [{
        protocol = "tcp"
        ports    = ["22", "3389"]
      }]
    },
    {
      name        = "${local.name_prefix}-allow-health-checks"
      description = "Allow GCP health checks"
      direction   = "INGRESS"
      priority    = 1000
      ranges      = ["35.191.0.0/16", "130.211.0.0/22"]
      allow = [{
        protocol = "tcp"
        ports    = ["80", "443"]
      }]
    },
    {
      name        = "${local.name_prefix}-allow-internal"
      description = "Allow internal traffic"
      direction   = "INGRESS"
      priority    = 1000
      ranges      = [var.vpc_cidr]
      allow = [{
        protocol = "tcp"
        ports    = []
      }]
    },
    {
      name        = "${local.name_prefix}-deny-all-ingress"
      description = "Deny all ingress traffic"
      direction   = "INGRESS"
      priority    = 65534
      ranges      = ["0.0.0.0/0"]
      deny = [{
        protocol = "all"
        ports    = []
      }]
    }
  ]
  
  depends_on = [module.vpc]
}
```

### Compute Resources
```hcl
# infrastructure/environments/dev/compute.tf

# GKE Cluster
module "gke" {
  source = "../../modules/compute/gke"
  
  project_id     = local.project_id
  name           = "${local.name_prefix}-gke"
  location       = local.region
  node_locations = slice(local.zones, 0, 3)
  
  network    = module.vpc.network_name
  subnetwork = module.subnets.subnets["${local.name_prefix}-gke"].name
  
  ip_range_pods     = "gke-pods"
  ip_range_services = "gke-services"
  
  master_ipv4_cidr_block = "172.16.0.0/28"
  
  enable_private_nodes    = true
  enable_private_endpoint = false
  
  node_pools = [
    {
      name               = "default-pool"
      machine_type       = var.gke_config.machine_type
      min_count          = var.gke_config.min_nodes
      max_count          = var.gke_config.max_nodes
      initial_node_count = var.gke_config.min_nodes
      disk_size_gb       = var.gke_config.disk_size_gb
      disk_type          = "pd-standard"
      preemptible        = var.gke_config.preemptible
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

# Cloud Run Services
module "cloud_run" {
  source = "../../modules/compute/cloud-run"
  
  project_id = local.project_id
  location   = local.region
  
  services = {
    "api-service" = {
      name  = "${local.name_prefix}-api"
      image = "gcr.io/${local.project_id}/api-service:latest"
      
      ports = [{
        name           = "http1"
        container_port = 8080
      }]
      
      env_vars = [
        {
          name  = "ENVIRONMENT"
          value = local.environment
        }
      ]
      
      limits = {
        cpu    = var.cloud_run_config.cpu
        memory = var.cloud_run_config.memory
      }
      
      min_scale = var.cloud_run_config.min_instances
      max_scale = var.cloud_run_config.max_instances
      
      allow_unauthenticated = false
    }
    
    "web-service" = {
      name  = "${local.name_prefix}-web"
      image = "gcr.io/${local.project_id}/web-service:latest"
      
      ports = [{
        name           = "http1"
        container_port = 3000
      }]
      
      env_vars = [
        {
          name  = "NODE_ENV"
          value = local.environment == "prod" ? "production" : "development"
        }
      ]
      
      limits = {
        cpu    = var.cloud_run_config.cpu
        memory = var.cloud_run_config.memory
      }
      
      min_scale = var.cloud_run_config.min_instances
      max_scale = var.cloud_run_config.max_instances
      
      allow_unauthenticated = true
    }
  }
  
  vpc_connector_name = "${local.name_prefix}-connector"
  vpc_network        = module.vpc.network_name
  
  labels = local.common_labels
  
  depends_on = [
    module.vpc,
    google_project_service.required_apis
  ]
}

# Cloud Functions
module "cloud_functions" {
  source = "../../modules/compute/cloud-functions"
  
  project_id = local.project_id
  region     = local.region
  
  functions = {
    "process-upload" = {
      name        = "${local.name_prefix}-process-upload"
      description = "Process file uploads"
      runtime     = "python39"
      
      entry_point = "process_upload"
      
      source_archive_bucket = google_storage_bucket.functions_source.name
      source_archive_object = "process-upload.zip"
      
      trigger_type = "storage"
      event_type   = "google.storage.object.finalize"
      resource     = google_storage_bucket.uploads.name
      
      environment_variables = {
        ENVIRONMENT = local.environment
        PROJECT_ID  = local.project_id
      }
      
      available_memory_mb = 256
      timeout            = 60
      max_instances      = 10
    }
    
    "webhook-handler" = {
      name        = "${local.name_prefix}-webhook"
      description = "Handle webhooks"
      runtime     = "nodejs16"
      
      entry_point = "handleWebhook"
      
      source_archive_bucket = google_storage_bucket.functions_source.name
      source_archive_object = "webhook-handler.zip"
      
      trigger_type = "http"
      
      environment_variables = {
        NODE_ENV = local.environment == "prod" ? "production" : "development"
      }
      
      available_memory_mb = 512
      timeout            = 30
      max_instances      = 50
    }
  }
  
  vpc_connector = module.cloud_run.vpc_connector_id
  
  labels = local.common_labels
  
  depends_on = [
    module.cloud_run,
    google_project_service.required_apis
  ]
}
```

### Data Resources
```hcl
# infrastructure/environments/dev/data.tf

# Cloud SQL Instance
module "cloud_sql" {
  source = "../../modules/data/cloud-sql"
  
  project_id = local.project_id
  region     = local.region
  
  name             = "${local.name_prefix}-db"
  database_version = var.database_config.database_version
  tier            = var.database_config.tier
  
  availability_type = var.database_config.availability_type
  
  disk_size         = 100
  disk_type         = "PD_SSD"
  disk_autoresize   = true
  
  backup_configuration = {
    enabled                        = var.database_config.backup_enabled
    start_time                     = var.database_config.backup_time
    point_in_time_recovery_enabled = local.environment == "prod"
    transaction_log_retention_days = local.environment == "prod" ? 7 : 3
    retained_backups              = local.environment == "prod" ? 30 : 7
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

# Private service connection for Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  name          = "${local.name_prefix}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = module.vpc.network_self_link
  project       = local.project_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = module.vpc.network_self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# Redis Instance
module "redis" {
  source = "../../modules/data/redis"
  
  project_id = local.project_id
  region     = local.region
  
  name           = "${local.name_prefix}-redis"
  tier           = "STANDARD_HA"
  memory_size_gb = local.environment == "prod" ? 5 : 2
  
  authorized_network = module.vpc.network_self_link
  
  redis_version = "REDIS_6_X"
  
  display_name = "Redis cache for ${local.environment}"
  
  labels = local.common_labels
  
  depends_on = [
    module.vpc,
    google_project_service.required_apis
  ]
}

# GCS Buckets
resource "google_storage_bucket" "buckets" {
  for_each = {
    static    = { versioning = false, lifecycle_days = 0 }
    media     = { versioning = true, lifecycle_days = 90 }
    uploads   = { versioning = false, lifecycle_days = 7 }
    backups   = { versioning = true, lifecycle_days = 30 }
    functions_source = { versioning = true, lifecycle_days = 0 }
  }
  
  name     = "${local.project_id}-${local.environment}-${each.key}"
  location = local.region
  project  = local.project_id
  
  uniform_bucket_level_access = true
  
  versioning {
    enabled = each.value.versioning
  }
  
  dynamic "lifecycle_rule" {
    for_each = each.value.lifecycle_days > 0 ? [1] : []
    content {
      condition {
        age = each.value.lifecycle_days
      }
      action {
        type = "Delete"
      }
    }
  }
  
  labels = local.common_labels
}

# Create references for specific buckets
resource "google_storage_bucket" "uploads" {
  name     = "${local.project_id}-${local.environment}-uploads"
  location = local.region
  project  = local.project_id
  
  uniform_bucket_level_access = true
  
  labels = local.common_labels
}

resource "google_storage_bucket" "functions_source" {
  name     = "${local.project_id}-${local.environment}-functions"
  location = local.region
  project  = local.project_id
  
  uniform_bucket_level_access = true
  
  labels = local.common_labels
}

# BigQuery Datasets
module "bigquery" {
  source = "../../modules/data/bigquery"
  
  project_id = local.project_id
  
  datasets = [
    {
      dataset_id                  = "${local.environment}_analytics"
      friendly_name               = "Analytics Dataset for ${local.environment}"
      description                 = "Analytics data warehouse"
      location                    = var.bigquery_config.dataset_location
      default_table_expiration_ms = var.bigquery_config.default_table_expiration_days * 24 * 60 * 60 * 1000
      
      labels = local.common_labels
      
      tables = [
        {
          table_id    = "events"
          schema      = file("${path.module}/schemas/events.json")
          time_partitioning = {
            type  = "DAY"
            field = "timestamp"
          }
          clustering = ["event_type", "user_id"]
        }
      ]
    },
    {
      dataset_id    = "${local.environment}_ml_features"
      friendly_name = "ML Feature Store"
      description   = "Feature store for machine learning"
      location      = var.bigquery_config.dataset_location
      
      labels = local.common_labels
    }
  ]
  
  depends_on = [google_project_service.required_apis]
}

# Pub/Sub Topics and Subscriptions
module "pubsub" {
  source = "../../modules/data/pubsub"
  
  project_id = local.project_id
  
  topics = [
    {
      name = "${local.name_prefix}-events"
      labels = local.common_labels
      
      message_retention_duration = "604800s" # 7 days
      
      subscriptions = [
        {
          name = "${local.name_prefix}-events-processor"
          
          ack_deadline_seconds = 60
          
          push_config = {
            push_endpoint = "https://api-${local.environment}.example.com/webhook"
            
            oidc_token = {
              service_account_email = google_service_account.pubsub_sa.email
            }
          }
        }
      ]
    },
    {
      name = "${local.name_prefix}-notifications"
      labels = local.common_labels
      
      subscriptions = [
        {
          name = "${local.name_prefix}-notifications-email"
          ack_deadline_seconds = 30
        }
      ]
    }
  ]
  
  depends_on = [google_project_service.required_apis]
}

# Service account for Pub/Sub
resource "google_service_account" "pubsub_sa" {
  account_id   = "${local.name_prefix}-pubsub-sa"
  display_name = "Pub/Sub Service Account"
  project      = local.project_id
}
```

### Security Resources
```hcl
# infrastructure/environments/dev/security.tf

# KMS Keyring and Keys
module "kms" {
  source = "../../modules/security/kms"
  
  project_id = local.project_id
  location   = local.region
  
  keyring_name = "${local.name_prefix}-keyring"
  
  keys = [
    {
      name               = "encryption-key"
      rotation_period    = "7776000s" # 90 days
      algorithm          = "GOOGLE_SYMMETRIC_ENCRYPTION"
      purpose           = "ENCRYPT_DECRYPT"
      
      labels = local.common_labels
    },
    {
      name               = "signing-key"
      rotation_period    = "7776000s"
      algorithm          = "RSA_SIGN_PSS_2048_SHA256"
      purpose           = "ASYMMETRIC_SIGN"
      
      labels = local.common_labels
    }
  ]
  
  depends_on = [google_project_service.required_apis]
}

# Secret Manager
module "secrets" {
  source = "../../modules/security/secrets"
  
  project_id = local.project_id
  
  secrets = {
    "database-password" = {
      secret_id = "${local.name_prefix}-db-password"
      
      replication_policy = {
        automatic = true
      }
      
      labels = merge(local.common_labels, {
        type = "database"
      })
    }
    
    "api-key" = {
      secret_id = "${local.name_prefix}-api-key"
      
      replication_policy = {
        user_managed = {
          replicas = [
            { location = local.region }
          ]
        }
      }
      
      labels = merge(local.common_labels, {
        type = "api"
      })
    }
  }
  
  depends_on = [google_project_service.required_apis]
}

# IAM Roles and Service Accounts
module "iam" {
  source = "../../modules/security/iam"
  
  project_id = local.project_id
  
  service_accounts = [
    {
      account_id   = "${local.name_prefix}-gke-sa"
      display_name = "GKE Service Account"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
        "roles/monitoring.viewer"
      ]
    },
    {
      account_id   = "${local.name_prefix}-cloud-run-sa"
      display_name = "Cloud Run Service Account"
      roles = [
        "roles/cloudsql.client",
        "roles/secretmanager.secretAccessor",
        "roles/datastore.user"
      ]
    },
    {
      account_id   = "${local.name_prefix}-functions-sa"
      display_name = "Cloud Functions Service Account"
      roles = [
        "roles/storage.objectAdmin",
        "roles/pubsub.publisher",
        "roles/logging.logWriter"
      ]
    }
  ]
  
  custom_roles = [
    {
      role_id     = "customDeveloper"
      title       = "Custom Developer Role"
      description = "Custom role for developers"
      permissions = [
        "compute.instances.get",
        "compute.instances.list",
        "storage.buckets.get",
        "storage.buckets.list"
      ]
    }
  ]
  
  depends_on = [google_project_service.required_apis]
}
```

### Monitoring Resources
```hcl
# infrastructure/environments/dev/monitoring.tf

# Log Sinks
module "logging" {
  source = "../../modules/monitoring/logging"
  
  project_id = local.project_id
  
  log_sinks = [
    {
      name        = "${local.name_prefix}-critical-logs"
      destination = "storage.googleapis.com/${google_storage_bucket.logs.name}"
      filter      = "severity >= ERROR"
      
      unique_writer_identity = true
    },
    {
      name        = "${local.name_prefix}-audit-logs"
      destination = "bigquery.googleapis.com/projects/${local.project_id}/datasets/${local.environment}_audit"
      filter      = "logName:\"cloudaudit.googleapis.com\""
      
      unique_writer_identity = true
      
      bigquery_options = {
        use_partitioned_tables = true
      }
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

# Monitoring Alerts
module "alerts" {
  source = "../../modules/monitoring/alerts"
  
  project_id = local.project_id
  
  notification_channels = [
    {
      type         = "email"
      display_name = "DevOps Team"
      labels = {
        email_address = "devops@example.com"
      }
    },
    {
      type         = "slack"
      display_name = "Slack Alerts"
      labels = {
        channel_name = "#alerts"
        url          = var.slack_webhook_url
      }
      sensitive_labels = {
        auth_token = var.slack_auth_token
      }
    }
  ]
  
  alert_policies = [
    {
      display_name = "High CPU Usage"
      conditions = [{
        display_name = "CPU usage above 80%"
        
        condition_threshold = {
          filter          = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" resource.type=\"gce_instance\""
          duration        = "300s"
          comparison      = "COMPARISON_GT"
          threshold_value = 0.8
          
          aggregations = [{
            alignment_period   = "60s"
            per_series_aligner = "ALIGN_MEAN"
          }]
        }
      }]
      
      notification_channel_ids = ["email", "slack"]
    },
    {
      display_name = "Cloud SQL Down"
      conditions = [{
        display_name = "Database is down"
        
        condition_threshold = {
          filter          = "metric.type=\"cloudsql.googleapis.com/database/up\" resource.type=\"cloudsql_database\""
          duration        = "60s"
          comparison      = "COMPARISON_LT"
          threshold_value = 1
          
          aggregations = [{
            alignment_period   = "60s"
            per_series_aligner = "ALIGN_MEAN"
          }]
        }
      }]
      
      notification_channel_ids = ["email", "slack"]
    }
  ]
  
  depends_on = [google_project_service.required_apis]
}

# Monitoring Dashboard
resource "google_monitoring_dashboard" "main" {
  dashboard_json = jsonencode({
    displayName = "${local.environment} Environment Dashboard"
    
    gridLayout = {
      widgets = [
        {
          title = "CPU Utilization"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" resource.type=\"gce_instance\""
                }
              }
            }]
          }
        },
        {
          title = "Memory Usage"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"kubernetes.io/container/memory/used_bytes\" resource.type=\"k8s_container\""
                }
              }
            }]
          }
        }
      ]
    }
  })
  
  project = local.project_id
}
```

### Outputs
```hcl
# infrastructure/environments/dev/outputs.tf

# Network outputs
output "vpc_id" {
  description = "VPC network ID"
  value       = module.vpc.network_id
}

output "vpc_name" {
  description = "VPC network name"
  value       = module.vpc.network_name
}

output "subnet_ids" {
  description = "Subnet IDs"
  value       = module.subnets.subnet_ids
}

# Compute outputs
output "gke_cluster_name" {
  description = "GKE cluster name"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "cloud_run_urls" {
  description = "Cloud Run service URLs"
  value       = module.cloud_run.service_urls
}

# Data outputs
output "database_connection_name" {
  description = "Cloud SQL connection name"
  value       = module.cloud_sql.connection_name
}

output "redis_host" {
  description = "Redis instance host"
  value       = module.redis.host
}

output "bucket_names" {
  description = "GCS bucket names"
  value       = { for k, v in google_storage_bucket.buckets : k => v.name }
}

# Security outputs
output "kms_keyring_id" {
  description = "KMS keyring ID"
  value       = module.kms.keyring_id
}

output "service_account_emails" {
  description = "Service account emails"
  value       = module.iam.service_account_emails
}
```

## GitHub Actions Workflows

### PR Validation Workflow
```yaml
# .github/workflows/terraform-plan.yml

name: Terraform Plan

on:
  pull_request:
    paths:
      - 'infrastructure/**'
      - '.github/workflows/terraform-*.yml'

env:
  TERRAFORM_VERSION: 1.5.0
  GOOGLE_CREDENTIALS: ${{ secrets.GCP_SA_KEY }}

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      environments: ${{ steps.detect.outputs.environments }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Detect changed environments
        id: detect
        run: |
          CHANGED_FILES=$(git diff --name-only origin/main..HEAD | grep "^infrastructure/environments/" || true)
          if [[ -n "$CHANGED_FILES" ]]; then
            ENVIRONMENTS=$(echo "$CHANGED_FILES" | cut -d'/' -f3 | sort -u | jq -R -s -c 'split("\n")[:-1]')
          else
            ENVIRONMENTS='[]'
          fi
          echo "environments=${ENVIRONMENTS}" >> $GITHUB_OUTPUT

  terraform-plan:
    needs: detect-changes
    if: needs.detect-changes.outputs.environments != '[]'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: ${{ fromJson(needs.detect-changes.outputs.environments) }}
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}
      
      - name: Terraform Init
        run: |
          cd infrastructure/environments/${{ matrix.environment }}
          terraform init
      
      - name: Terraform Format Check
        run: |
          cd infrastructure
          terraform fmt -check -recursive
      
      - name: Terraform Validate
        run: |
          cd infrastructure/environments/${{ matrix.environment }}
          terraform validate
      
      - name: Terraform Plan
        id: plan
        run: |
          cd infrastructure/environments/${{ matrix.environment }}
          terraform plan -var-file=terraform.tfvars -no-color -out=tfplan
      
      - name: Comment PR
        uses: actions/github-script@v7
        if: github.event_name == 'pull_request'
        with:
          script: |
            const output = `#### Terraform Plan for ${{ matrix.environment }} 📋
            
            <details><summary>Show Plan</summary>
            
            \`\`\`terraform
            ${{ steps.plan.outputs.stdout }}
            \`\`\`
            
            </details>
            
            *Environment: ${{ matrix.environment }}*
            *Triggered by: @${{ github.actor }}*`;
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            })
```

### Deployment Workflow
```yaml
# .github/workflows/terraform-apply.yml

name: Terraform Apply

on:
  push:
    branches:
      - main
    paths:
      - 'infrastructure/**'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - dev
          - staging
          - prod

env:
  TERRAFORM_VERSION: 1.5.0

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || 'dev' }}
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}
      
      - name: Terraform Init
        run: |
          cd infrastructure/environments/${{ github.event.inputs.environment || 'dev' }}
          terraform init
      
      - name: Terraform Apply
        run: |
          cd infrastructure/environments/${{ github.event.inputs.environment || 'dev' }}
          terraform apply -var-file=terraform.tfvars -auto-approve
      
      - name: Slack Notification
        if: always()
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: |
            Deployment to ${{ github.event.inputs.environment || 'dev' }} ${{ job.status }}
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## Best Practices Implemented

1. **Module Design**: Reusable, versioned modules with clear interfaces
2. **Environment Separation**: Isolated state and configuration per environment
3. **State Management**: Remote state in GCS with locking
4. **Security**: Least privilege IAM, encrypted secrets, private networks
5. **Cost Optimization**: Environment-specific sizing, preemptible instances
6. **Monitoring**: Comprehensive logging, metrics, and alerting
7. **CI/CD**: Automated validation, planning, and deployment
8. **Documentation**: README files, inline comments, generated docs
9. **Naming Convention**: Consistent resource naming pattern
10. **Dependency Management**: Explicit dependencies between resources

## Usage Commands

```bash
# Initialize environment
make init ENVIRONMENT=dev

# Format code
make fmt

# Validate configuration
make validate ENVIRONMENT=dev

# Plan changes
make plan ENVIRONMENT=dev

# Apply changes
make apply ENVIRONMENT=dev

# Estimate costs
make cost ENVIRONMENT=dev

# Run security scan
make security ENVIRONMENT=dev

# Generate documentation
make docs

# Destroy resources (use with caution)
make destroy ENVIRONMENT=dev
```
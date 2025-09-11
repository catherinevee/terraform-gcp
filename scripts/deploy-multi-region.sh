#!/bin/bash

# Multi-Region Deployment Script
# This script deploys infrastructure across multiple regions

set -e

# Default values
OPERATION=""
REGION="all"
ENVIRONMENT="dev"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--operation)
            OPERATION="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 -o <operation> [-r <region>] [-e <environment>]"
            echo "Operations: plan, apply, destroy"
            echo "Regions: all, global, us-central1, us-east1"
            echo "Environments: dev, staging, prod"
            exit 0
            ;;
        *)
            echo "Unknown option $1"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$OPERATION" ]]; then
    echo "Error: Operation is required"
    echo "Use -h or --help for usage information"
    exit 1
fi

if [[ ! "$OPERATION" =~ ^(plan|apply|destroy)$ ]]; then
    echo "Error: Invalid operation. Must be plan, apply, or destroy"
    exit 1
fi

if [[ ! "$REGION" =~ ^(all|global|us-central1|us-east1)$ ]]; then
    echo "Error: Invalid region. Must be all, global, us-central1, or us-east1"
    exit 1
fi

# Set project ID
PROJECT_ID="cataziza-ecommerce-platform-$ENVIRONMENT"

echo "🚀 Starting Multi-Region Deployment"
echo "Operation: $OPERATION"
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT"
echo "Project ID: $PROJECT_ID"

# Function to run terraform command
run_terraform() {
    local path="$1"
    local command="$2"
    local description="$3"
    
    echo ""
    echo "📁 $description"
    echo "Path: $path"
    echo "Command: terraform $command"
    
    cd "$path"
    
    case "$command" in
        "init")
            terraform init -reconfigure
            ;;
        "plan")
            terraform plan -var-file=terraform.tfvars -out=tfplan
            ;;
        "apply")
            terraform apply -var-file=terraform.tfvars -auto-approve
            ;;
        "destroy")
            echo "⚠️  WARNING: This will destroy infrastructure!"
            terraform plan -destroy -var-file=terraform.tfvars
            terraform destroy -var-file=terraform.tfvars -auto-approve
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo "✅ $description completed successfully"
    else
        echo "❌ $description failed"
        exit 1
    fi
}

# Deploy global resources
if [[ "$REGION" == "all" || "$REGION" == "global" ]]; then
    echo ""
    echo "🌍 Deploying Global Resources"
    
    # Create BigQuery datasets
    echo "Creating BigQuery datasets..."
    bq mk --dataset --location=US --description="Application logs dataset" "$PROJECT_ID:application_logs" 2>/dev/null || true
    bq mk --dataset --location=US --description="Security logs dataset" "$PROJECT_ID:security_logs" 2>/dev/null || true
    
    run_terraform "infrastructure/environments/$ENVIRONMENT/global" "$OPERATION" "Global Resources"
fi

# Deploy US Central1 resources
if [[ "$REGION" == "all" || "$REGION" == "us-central1" ]]; then
    echo ""
    echo "🇺🇸 Deploying US Central1 Resources"
    run_terraform "infrastructure/environments/$ENVIRONMENT/us-central1" "$OPERATION" "US Central1 Resources"
fi

# Deploy US East1 resources
if [[ "$REGION" == "all" || "$REGION" == "us-east1" ]]; then
    echo ""
    echo "🇺🇸 Deploying US East1 Resources"
    run_terraform "infrastructure/environments/$ENVIRONMENT/us-east1" "$OPERATION" "US East1 Resources"
fi

# Deploy cross-region networking (only if both regions are deployed)
if [[ "$REGION" == "all" && "$OPERATION" != "destroy" ]]; then
    echo ""
    echo "🔗 Deploying Cross-Region Networking"
    
    # Create cross-region configuration if it doesn't exist
    CROSS_REGION_PATH="infrastructure/environments/$ENVIRONMENT/cross-region"
    if [ ! -d "$CROSS_REGION_PATH" ]; then
        echo "Creating cross-region configuration..."
        mkdir -p "$CROSS_REGION_PATH"
        
        # Create main.tf
        cat > "$CROSS_REGION_PATH/main.tf" << EOF
# Cross-Region Networking Configuration
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.45.2"
    }
  }
}

provider "google" {
  project = var.project_id
}

# Data sources to reference regional resources
data "terraform_remote_state" "us_central1" {
  backend = "gcs"
  config = {
    bucket = "$PROJECT_ID-terraform-state"
    prefix = "terraform/state/us-central1"
  }
}

data "terraform_remote_state" "us_east1" {
  backend = "gcs"
  config = {
    bucket = "$PROJECT_ID-terraform-state"
    prefix = "terraform/state/us-east1"
  }
}

# Data source to access VPN shared secret from Secret Manager
data "google_secret_manager_secret_version" "vpn_shared_secret" {
  secret = "cataziza-vpn-shared-secret"
}

# Cross-region networking module
module "cross_region_networking" {
  source = "../../../modules/networking/cross-region"

  project_id = var.project_id
  primary_region = "us-central1"
  secondary_region = "us-east1"
  primary_network_self_link = data.terraform_remote_state.us_central1.outputs.vpc_network_self_link
  secondary_network_self_link = data.terraform_remote_state.us_east1.outputs.vpc_network_self_link
  vpn_shared_secret = data.google_secret_manager_secret_version.vpn_shared_secret.secret_data
}
EOF
        
        # Create variables.tf
        cat > "$CROSS_REGION_PATH/variables.tf" << EOF
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "vpn_shared_secret" {
  description = "VPN shared secret"
  type        = string
  sensitive   = true
}
EOF
        
        # Create terraform.tfvars
        cat > "$CROSS_REGION_PATH/terraform.tfvars" << EOF
project_id = "$PROJECT_ID"
vpn_shared_secret = "cataziza-ecommerce-vpn-secret-2024"
EOF
        
        # Create backend.tf
        cat > "$CROSS_REGION_PATH/backend.tf" << EOF
terraform {
  backend "gcs" {
    bucket = "$PROJECT_ID-terraform-state"
    prefix = "terraform/state/cross-region"
  }
}
EOF
    fi
    
    run_terraform "$CROSS_REGION_PATH" "$OPERATION" "Cross-Region Networking"
fi

echo ""
echo "🎉 Multi-Region Deployment Completed!"

if [[ "$OPERATION" == "apply" ]]; then
    echo ""
    echo "📊 Deployment Summary:"
    echo "Global Resources: ✅"
    if [[ "$REGION" == "all" || "$REGION" == "us-central1" ]]; then
        echo "US Central1 Resources: ✅"
    fi
    if [[ "$REGION" == "all" || "$REGION" == "us-east1" ]]; then
        echo "US East1 Resources: ✅"
    fi
    if [[ "$REGION" == "all" ]]; then
        echo "Cross-Region Networking: ✅"
    fi
    
    echo ""
    echo "🔍 Verification Commands:"
    echo "gcloud compute networks list --filter='name:cataziza-ecommerce-platform-vpc-$ENVIRONMENT'"
    echo "gcloud compute instances list --filter='name:cataziza-ecommerce'"
    echo "gcloud run services list --filter='metadata.name:cataziza'"
fi


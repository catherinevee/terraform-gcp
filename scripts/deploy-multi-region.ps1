# Multi-Region Deployment Script
# This script deploys infrastructure across multiple regions

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("plan", "apply", "destroy")]
    [string]$Operation,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("all", "global", "us-central1", "us-east1")]
    [string]$Region = "all",
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev"
)

Write-Host "🚀 Starting Multi-Region Deployment" -ForegroundColor Green
Write-Host "Operation: $Operation" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow

# Set project ID
$ProjectId = "cataziza-platform-$Environment"
Write-Host "Project ID: $ProjectId" -ForegroundColor Cyan

# Function to run terraform command
function Invoke-Terraform {
    param(
        [string]$Path,
        [string]$Command,
        [string]$Description
    )
    
    Write-Host "`n📁 $Description" -ForegroundColor Blue
    Write-Host "Path: $Path" -ForegroundColor Gray
    Write-Host "Command: terraform $Command" -ForegroundColor Gray
    
    Push-Location $Path
    
    try {
        if ($Command -eq "init") {
            terraform init -reconfigure
        } elseif ($Command -eq "plan") {
            terraform plan -var-file=terraform.tfvars -out=tfplan
        } elseif ($Command -eq "apply") {
            terraform apply -var-file=terraform.tfvars -auto-approve
        } elseif ($Command -eq "destroy") {
            Write-Host "⚠️  WARNING: This will destroy infrastructure!" -ForegroundColor Red
            terraform plan -destroy -var-file=terraform.tfvars
            terraform destroy -var-file=terraform.tfvars -auto-approve
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ $Description completed successfully" -ForegroundColor Green
        } else {
            Write-Host "❌ $Description failed" -ForegroundColor Red
            exit 1
        }
    }
    finally {
        Pop-Location
    }
}

# Deploy global resources
if ($Region -eq "all" -or $Region -eq "global") {
    Write-Host "`n🌍 Deploying Global Resources" -ForegroundColor Magenta
    
    # Create BigQuery datasets
    Write-Host "Creating BigQuery datasets..." -ForegroundColor Yellow
    bq mk --dataset --location=US --description="Application logs dataset" "$ProjectId:application_logs" 2>$null
    bq mk --dataset --location=US --description="Security logs dataset" "$ProjectId:security_logs" 2>$null
    
    Invoke-Terraform -Path "infrastructure/environments/$Environment/global" -Command $Operation -Description "Global Resources"
}

# Deploy US Central1 resources
if ($Region -eq "all" -or $Region -eq "us-central1") {
    Write-Host "`n🇺🇸 Deploying US Central1 Resources" -ForegroundColor Magenta
    Invoke-Terraform -Path "infrastructure/environments/$Environment/us-central1" -Command $Operation -Description "US Central1 Resources"
}

# Deploy US East1 resources
if ($Region -eq "all" -or $Region -eq "us-east1") {
    Write-Host "`n🇺🇸 Deploying US East1 Resources" -ForegroundColor Magenta
    Invoke-Terraform -Path "infrastructure/environments/$Environment/us-east1" -Command $Operation -Description "US East1 Resources"
}

# Deploy cross-region networking (only if both regions are deployed)
if ($Region -eq "all" -and $Operation -ne "destroy") {
    Write-Host "`n🔗 Deploying Cross-Region Networking" -ForegroundColor Magenta
    
    # Create cross-region configuration if it doesn't exist
    $CrossRegionPath = "infrastructure/environments/$Environment/cross-region"
    if (-not (Test-Path $CrossRegionPath)) {
        Write-Host "Creating cross-region configuration..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $CrossRegionPath -Force | Out-Null
        
        # Create main.tf
        @"
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
    bucket = "$ProjectId-terraform-state"
    prefix = "terraform/state/us-central1"
  }
}

data "terraform_remote_state" "us_east1" {
  backend = "gcs"
  config = {
    bucket = "$ProjectId-terraform-state"
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
"@ | Out-File -FilePath "$CrossRegionPath/main.tf" -Encoding UTF8
        
        # Create variables.tf
        @"
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "vpn_shared_secret" {
  description = "VPN shared secret"
  type        = string
  sensitive   = true
}
"@ | Out-File -FilePath "$CrossRegionPath/variables.tf" -Encoding UTF8
        
        # Create terraform.tfvars
        @"
project_id = "$ProjectId"
vpn_shared_secret = "cataziza-vpn-secret-2024"
"@ | Out-File -FilePath "$CrossRegionPath/terraform.tfvars" -Encoding UTF8
        
        # Create backend.tf
        @"
terraform {
  backend "gcs" {
    bucket = "$ProjectId-terraform-state"
    prefix = "terraform/state/cross-region"
  }
}
"@ | Out-File -FilePath "$CrossRegionPath/backend.tf" -Encoding UTF8
    }
    
    Invoke-Terraform -Path $CrossRegionPath -Command $Operation -Description "Cross-Region Networking"
}

Write-Host "`n🎉 Multi-Region Deployment Completed!" -ForegroundColor Green

if ($Operation -eq "apply") {
    Write-Host "`n📊 Deployment Summary:" -ForegroundColor Cyan
    Write-Host "Global Resources: ✅" -ForegroundColor Green
    if ($Region -eq "all" -or $Region -eq "us-central1") {
        Write-Host "US Central1 Resources: ✅" -ForegroundColor Green
    }
    if ($Region -eq "all" -or $Region -eq "us-east1") {
        Write-Host "US East1 Resources: ✅" -ForegroundColor Green
    }
    if ($Region -eq "all") {
        Write-Host "Cross-Region Networking: ✅" -ForegroundColor Green
    }
    
    Write-Host "`n🔍 Verification Commands:" -ForegroundColor Yellow
    Write-Host "gcloud compute networks list --filter='name:cataziza-platform-vpc-$Environment'" -ForegroundColor Gray
    Write-Host "gcloud compute instances list --filter='name:cataziza'" -ForegroundColor Gray
    Write-Host "gcloud run services list --filter='metadata.name:cataziza'" -ForegroundColor Gray
}


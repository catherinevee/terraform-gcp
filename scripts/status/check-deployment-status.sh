#!/bin/bash

# Configuration
PROJECT_ID="acme-ecommerce-platform-dev"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LAST_CHECKED=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

# Initialize counters
TOTAL_CHECKS=0
PASSED_CHECKS=0

echo "🔍 Checking deployment status for project: $PROJECT_ID"

# Function to check if a resource exists
check_resource() {
    local resource_type="$1"
    local resource_name="$2"
    local command="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if eval "$command" >/dev/null 2>&1; then
        echo "✅ $resource_type: $resource_name - EXISTS"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo "❌ $resource_type: $resource_name - MISSING"
        return 1
    fi
}

# Check critical infrastructure components
echo "📊 Checking critical infrastructure components..."

# VPC and Networking
check_resource "VPC" "acme-ecommerce-platform-dev-vpc" "gcloud compute networks describe acme-ecommerce-platform-dev-vpc --project=$PROJECT_ID"

# Load Balancer
check_resource "Load Balancer" "acme-ecommerce-platform-lb" "gcloud compute forwarding-rules list --global --filter='name:acme-ecommerce-platform-lb' --project=$PROJECT_ID"

# Service Accounts
check_resource "Service Account" "terraform-github-actions" "gcloud iam service-accounts describe terraform-github-actions@$PROJECT_ID.iam.gserviceaccount.com --project=$PROJECT_ID"

# KMS Keyring
check_resource "KMS Keyring" "acme-ecommerce-platform-dev-keyring" "gcloud kms keyrings describe acme-ecommerce-platform-dev-keyring --location=global --project=$PROJECT_ID"

# Terraform State Bucket
check_resource "State Bucket" "acme-ecommerce-platform-dev-terraform-state" "gsutil ls gs://acme-ecommerce-platform-dev-terraform-state"

# Compute Instances (at least one should exist)
check_resource "Compute Instance" "acme-web-server" "gcloud compute instances list --filter='name:acme-web-server' --project=$PROJECT_ID"

# Cloud SQL (if exists)
check_resource "Cloud SQL" "acme-database-dev" "gcloud sql instances describe acme-database-dev --project=$PROJECT_ID" || echo "⚠️  Cloud SQL not found (optional)"

# Storage Buckets
check_resource "Storage Bucket" "acme-customer-data-dev" "gsutil ls gs://acme-customer-data-dev"
check_resource "Storage Bucket" "acme-application-logs-dev" "gsutil ls gs://acme-application-logs-dev"

# Calculate status
PERCENTAGE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

if [ $PERCENTAGE -ge 80 ]; then
    STATUS="LIVE"
elif [ $PERCENTAGE -ge 50 ]; then
    STATUS="PARTIAL"
else
    STATUS="NOTDEPLOYED"
fi

echo ""
echo "📈 Status Summary:"
echo "   Total Checks: $TOTAL_CHECKS"
echo "   Passed: $PASSED_CHECKS"
echo "   Percentage: $PERCENTAGE%"
echo "   Status: $STATUS"

# Generate status files
echo "$STATUS" > status.txt

cat > deployment-status.json << EOF
{
  "status": "$STATUS",
  "percentage": $PERCENTAGE,
  "timestamp": "$TIMESTAMP",
  "project_id": "$PROJECT_ID",
  "region": "europe-west1",
  "last_checked": "$LAST_CHECKED",
  "checks": {
    "total": $TOTAL_CHECKS,
    "passed": $PASSED_CHECKS,
    "failed": $((TOTAL_CHECKS - PASSED_CHECKS))
  }
}
EOF

echo "Status check completed - $STATUS ($PERCENTAGE%)"

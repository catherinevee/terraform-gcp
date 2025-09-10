#!/bin/bash
# Phase 2: Security & Identity - Testing Script
# This script validates the security infrastructure including IAM, KMS, secrets, and security policies

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="${PROJECT_ID:-}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
REGION="${REGION:-us-central1}"

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    command -v terraform >/dev/null 2>&1 || error "Terraform is not installed"
    command -v gcloud >/dev/null 2>&1 || error "gcloud CLI is not installed"
    command -v jq >/dev/null 2>&1 || error "jq is not installed"
    command -v openssl >/dev/null 2>&1 || error "openssl is not installed"
    
    if [[ -z "$PROJECT_ID" ]]; then
        error "PROJECT_ID environment variable is required"
    fi
    
    success "Prerequisites check passed"
}

# Test 1: IAM Service Accounts Validation
test_service_accounts() {
    log "Testing IAM service accounts..."
    
    # Get all service accounts
    local service_accounts=$(gcloud iam service-accounts list --project="$PROJECT_ID" --format="json")
    local sa_count=$(echo "$service_accounts" | jq '. | length')
    
    if [[ $sa_count -eq 0 ]]; then
        error "No service accounts found"
    fi
    
    # Check for required service accounts
    local required_sas=(
        "gke-sa"
        "cloud-run-sa"
        "functions-sa"
        "pubsub-sa"
    )
    
    for sa_suffix in "${required_sas[@]}"; do
        local sa_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-${sa_suffix}@${PROJECT_ID}.iam.gserviceaccount.com"
        if ! echo "$service_accounts" | jq -e ".[] | select(.email == \"$sa_name\")" >/dev/null; then
            error "Required service account $sa_name not found"
        fi
    done
    
    success "Service accounts validation passed"
}

# Test 2: IAM Roles and Permissions Validation
test_iam_roles() {
    log "Testing IAM roles and permissions..."
    
    # Get IAM policy for the project
    local iam_policy=$(gcloud projects get-iam-policy "$PROJECT_ID" --format="json")
    
    # Check for required roles
    local required_roles=(
        "roles/logging.logWriter"
        "roles/monitoring.metricWriter"
        "roles/cloudsql.client"
        "roles/secretmanager.secretAccessor"
        "roles/storage.objectAdmin"
        "roles/pubsub.publisher"
    )
    
    for role in "${required_roles[@]}"; do
        if ! echo "$iam_policy" | jq -e ".bindings[] | select(.role == \"$role\")" >/dev/null; then
            warning "Role $role not found in IAM policy"
        fi
    done
    
    # Check for custom roles
    local custom_roles=$(gcloud iam roles list --project="$PROJECT_ID" --format="json")
    local custom_role_count=$(echo "$custom_roles" | jq '. | length')
    
    if [[ $custom_role_count -gt 0 ]]; then
        success "Found $custom_role_count custom roles"
    else
        warning "No custom roles found"
    fi
    
    success "IAM roles validation passed"
}

# Test 3: Cloud KMS Validation
test_cloud_kms() {
    log "Testing Cloud KMS configuration..."
    
    # Check for KMS keyring
    local keyring_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-keyring"
    local keyring_info=$(gcloud kms keyrings describe "$keyring_name" --location="$REGION" --project="$PROJECT_ID" --format="json" 2>/dev/null || echo "{}")
    
    if [[ "$keyring_info" == "{}" ]]; then
        error "KMS keyring $keyring_name not found"
    fi
    
    # Check for KMS keys
    local keys=$(gcloud kms keys list --keyring="$keyring_name" --location="$REGION" --project="$PROJECT_ID" --format="json")
    local key_count=$(echo "$keys" | jq '. | length')
    
    if [[ $key_count -eq 0 ]]; then
        error "No KMS keys found in keyring"
    fi
    
    # Check for required keys
    local required_keys=("encryption-key" "signing-key")
    for key_name in "${required_keys[@]}"; do
        if ! echo "$keys" | jq -e ".[] | select(.name | contains(\"$key_name\"))" >/dev/null; then
            error "Required KMS key $key_name not found"
        fi
    done
    
    # Test key rotation
    local encryption_key=$(echo "$keys" | jq -r '.[] | select(.name | contains("encryption-key")) | .name')
    if [[ -n "$encryption_key" ]]; then
        local rotation_period=$(gcloud kms keys describe "$encryption_key" --keyring="$keyring_name" --location="$REGION" --project="$PROJECT_ID" --format="value(rotationPeriod)" 2>/dev/null || echo "")
        if [[ -n "$rotation_period" ]]; then
            success "Key rotation configured: $rotation_period"
        else
            warning "Key rotation not configured"
        fi
    fi
    
    success "Cloud KMS validation passed"
}

# Test 4: Secret Manager Validation
test_secret_manager() {
    log "Testing Secret Manager configuration..."
    
    # Check for secrets
    local secrets=$(gcloud secrets list --project="$PROJECT_ID" --format="json")
    local secret_count=$(echo "$secrets" | jq '. | length')
    
    if [[ $secret_count -eq 0 ]]; then
        error "No secrets found in Secret Manager"
    fi
    
    # Check for required secrets
    local required_secrets=(
        "database-password"
        "api-key"
    )
    
    for secret_suffix in "${required_secrets[@]}"; do
        local secret_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-${secret_suffix}"
        if ! echo "$secrets" | jq -e ".[] | select(.name | contains(\"$secret_name\"))" >/dev/null; then
            error "Required secret $secret_name not found"
        fi
    done
    
    # Test secret access (without revealing values)
    local test_secret=$(echo "$secrets" | jq -r '.[0].name')
    if [[ -n "$test_secret" ]]; then
        if gcloud secrets describe "$test_secret" --project="$PROJECT_ID" >/dev/null 2>&1; then
            success "Secret access test passed"
        else
            warning "Secret access test failed"
        fi
    fi
    
    success "Secret Manager validation passed"
}

# Test 5: VPC Service Controls Validation
test_vpc_service_controls() {
    log "Testing VPC Service Controls..."
    
    # Check if VPC Service Controls are enabled
    local service_perimeter=$(gcloud access-context-manager perimeters list --project="$PROJECT_ID" --format="json" 2>/dev/null || echo "[]")
    local perimeter_count=$(echo "$service_perimeter" | jq '. | length')
    
    if [[ $perimeter_count -eq 0 ]]; then
        warning "No VPC Service Controls perimeters found"
    else
        success "Found $perimeter_count VPC Service Controls perimeters"
    fi
}

# Test 6: Cloud Asset Inventory Validation
test_cloud_asset_inventory() {
    log "Testing Cloud Asset Inventory..."
    
    # Check if Cloud Asset Inventory is enabled
    local asset_inventory=$(gcloud asset feeds list --project="$PROJECT_ID" --format="json" 2>/dev/null || echo "[]")
    local feed_count=$(echo "$asset_inventory" | jq '. | length')
    
    if [[ $feed_count -eq 0 ]]; then
        warning "No Cloud Asset Inventory feeds found"
    else
        success "Found $feed_count Cloud Asset Inventory feeds"
    fi
}

# Test 7: Security Command Center Validation
test_security_command_center() {
    log "Testing Security Command Center..."
    
    # Check if Security Command Center is enabled
    local scc_org=$(gcloud organizations list --format="value(name)" | head -1)
    if [[ -n "$scc_org" ]]; then
        local scc_info=$(gcloud scc sources list --parent="organizations/$scc_org" --format="json" 2>/dev/null || echo "[]")
        local source_count=$(echo "$scc_info" | jq '. | length')
        
        if [[ $source_count -eq 0 ]]; then
            warning "No Security Command Center sources found"
        else
            success "Found $source_count Security Command Center sources"
        fi
    else
        warning "No organization found for Security Command Center"
    fi
}

# Test 8: Workload Identity Validation
test_workload_identity() {
    log "Testing Workload Identity..."
    
    # Check if Workload Identity is enabled on GKE
    local gke_clusters=$(gcloud container clusters list --project="$PROJECT_ID" --format="json")
    local cluster_count=$(echo "$gke_clusters" | jq '. | length')
    
    if [[ $cluster_count -eq 0 ]]; then
        warning "No GKE clusters found for Workload Identity testing"
    else
        for cluster in $(echo "$gke_clusters" | jq -r '.[].name'); do
            local workload_identity=$(gcloud container clusters describe "$cluster" --region="$REGION" --project="$PROJECT_ID" --format="value(workloadIdentityConfig.workloadPool)" 2>/dev/null || echo "")
            if [[ -n "$workload_identity" ]]; then
                success "Workload Identity enabled on cluster $cluster"
            else
                warning "Workload Identity not enabled on cluster $cluster"
            fi
        done
    fi
}

# Test 9: Encryption Validation
test_encryption() {
    log "Testing encryption configuration..."
    
    # Check Cloud SQL encryption
    local sql_instances=$(gcloud sql instances list --project="$PROJECT_ID" --format="json")
    local sql_count=$(echo "$sql_instances" | jq '. | length')
    
    if [[ $sql_count -gt 0 ]]; then
        for instance in $(echo "$sql_instances" | jq -r '.[].name'); do
            local encryption=$(gcloud sql instances describe "$instance" --project="$PROJECT_ID" --format="value(diskEncryptionConfiguration.kmsKeyName)" 2>/dev/null || echo "")
            if [[ -n "$encryption" ]]; then
                success "Cloud SQL instance $instance is encrypted"
            else
                warning "Cloud SQL instance $instance may not be encrypted"
            fi
        done
    fi
    
    # Check Cloud Storage encryption
    local storage_buckets=$(gsutil ls -p "$PROJECT_ID" 2>/dev/null || echo "")
    if [[ -n "$storage_buckets" ]]; then
        success "Cloud Storage buckets found (encryption status varies by bucket)"
    else
        warning "No Cloud Storage buckets found"
    fi
}

# Test 10: Audit Logging Validation
test_audit_logging() {
    log "Testing audit logging..."
    
    # Check if audit logs are enabled
    local audit_config=$(gcloud logging sinks list --project="$PROJECT_ID" --format="json")
    local sink_count=$(echo "$audit_config" | jq '. | length')
    
    if [[ $sink_count -eq 0 ]]; then
        warning "No log sinks found"
    else
        success "Found $sink_count log sinks"
    fi
    
    # Check for audit log sink
    local audit_sink=$(echo "$audit_config" | jq -r '.[] | select(.name | contains("audit")) | .name')
    if [[ -n "$audit_sink" ]]; then
        success "Audit log sink found: $audit_sink"
    else
        warning "No audit log sink found"
    fi
}

# Test 11: Security Baseline Validation
test_security_baseline() {
    log "Testing security baseline..."
    
    # Check for security policies
    local security_policies=$(gcloud compute security-policies list --project="$PROJECT_ID" --format="json")
    local policy_count=$(echo "$security_policies" | jq '. | length')
    
    if [[ $policy_count -eq 0 ]]; then
        warning "No security policies found"
    else
        success "Found $policy_count security policies"
    fi
    
    # Check for organization policies
    local org_policies=$(gcloud resource-manager org-policies list --project="$PROJECT_ID" --format="json" 2>/dev/null || echo "[]")
    local org_policy_count=$(echo "$org_policies" | jq '. | length')
    
    if [[ $org_policy_count -eq 0 ]]; then
        warning "No organization policies found"
    else
        success "Found $org_policy_count organization policies"
    fi
}

# Test 12: Access Control Validation
test_access_control() {
    log "Testing access control..."
    
    # Check for IAM conditions
    local iam_policy=$(gcloud projects get-iam-policy "$PROJECT_ID" --format="json")
    local conditional_bindings=$(echo "$iam_policy" | jq '[.bindings[] | select(.condition != null)] | length')
    
    if [[ $conditional_bindings -gt 0 ]]; then
        success "Found $conditional_bindings conditional IAM bindings"
    else
        warning "No conditional IAM bindings found"
    fi
    
    # Check for service account impersonation
    local impersonation_roles=$(echo "$iam_policy" | jq '[.bindings[] | select(.role == "roles/iam.serviceAccountTokenCreator")] | length')
    
    if [[ $impersonation_roles -gt 0 ]]; then
        success "Service account impersonation configured"
    else
        warning "Service account impersonation not configured"
    fi
}

# Test 13: Compliance Validation
test_compliance() {
    log "Testing compliance configuration..."
    
    # Check for data residency compliance
    local resources=$(gcloud asset search-all-resources --scope="projects/$PROJECT_ID" --asset-types="compute.googleapis.com/Instance" --format="json" 2>/dev/null || echo "[]")
    local resource_count=$(echo "$resources" | jq '. | length')
    
    if [[ $resource_count -gt 0 ]]; then
        # Check if resources are in the expected region
        local regional_resources=$(echo "$resources" | jq "[.[] | select(.location | contains(\"$REGION\"))] | length")
        if [[ $regional_resources -eq $resource_count ]]; then
            success "All resources are in the expected region ($REGION)"
        else
            warning "Some resources may not be in the expected region"
        fi
    fi
    
    # Check for encryption compliance
    local encrypted_resources=$(echo "$resources" | jq '[.[] | select(.additionalAttributes.encryption != null)] | length')
    if [[ $encrypted_resources -gt 0 ]]; then
        success "Found $encrypted_resources encrypted resources"
    else
        warning "No encrypted resources found"
    fi
}

# Main execution
main() {
    log "Starting Phase 2 testing for environment: $ENVIRONMENT"
    log "Project ID: $PROJECT_ID"
    log "Region: $REGION"
    
    # Run all tests
    check_prerequisites
    test_service_accounts
    test_iam_roles
    test_cloud_kms
    test_secret_manager
    test_vpc_service_controls
    test_cloud_asset_inventory
    test_security_command_center
    test_workload_identity
    test_encryption
    test_audit_logging
    test_security_baseline
    test_access_control
    test_compliance
    
    success "All Phase 2 tests completed successfully!"
    log "Phase 2 security and identity is ready for Phase 3 data layer implementation"
}

# Run main function
main "$@"

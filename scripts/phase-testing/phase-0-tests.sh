#!/bin/bash
# Phase 0: Foundation Setup - Testing Script
# This script validates the foundation setup including project structure, CI/CD, and basic modules

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
TERRAFORM_VERSION="1.5.0"

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
    
    # Check if required tools are installed
    command -v terraform >/dev/null 2>&1 || error "Terraform is not installed"
    command -v gcloud >/dev/null 2>&1 || error "gcloud CLI is not installed"
    command -v jq >/dev/null 2>&1 || error "jq is not installed"
    command -v tfsec >/dev/null 2>&1 || error "tfsec is not installed"
    command -v tflint >/dev/null 2>&1 || error "tflint is not installed"
    
    # Check Terraform version
    TF_VERSION=$(terraform version -json | jq -r '.terraform_version')
    if [[ "$TF_VERSION" != "$TERRAFORM_VERSION" ]]; then
        warning "Terraform version $TF_VERSION detected, expected $TERRAFORM_VERSION"
    fi
    
    # Check if PROJECT_ID is set
    if [[ -z "$PROJECT_ID" ]]; then
        error "PROJECT_ID environment variable is required"
    fi
    
    success "Prerequisites check passed"
}

# Test 1: Project Structure Validation
test_project_structure() {
    log "Testing project structure..."
    
    # Check if required directories exist
    local required_dirs=(
        "infrastructure"
        "infrastructure/environments"
        "infrastructure/environments/$ENVIRONMENT"
        "infrastructure/modules"
        "infrastructure/modules/networking"
        "infrastructure/modules/compute"
        "infrastructure/modules/data"
        "infrastructure/modules/security"
        "infrastructure/modules/monitoring"
        ".github/workflows"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            error "Required directory $dir does not exist"
        fi
    done
    
    # Check if required files exist
    local required_files=(
        "infrastructure/Makefile"
        "infrastructure/environments/$ENVIRONMENT/main.tf"
        "infrastructure/environments/$ENVIRONMENT/variables.tf"
        "infrastructure/environments/$ENVIRONMENT/outputs.tf"
        "infrastructure/environments/$ENVIRONMENT/terraform.tfvars"
        ".github/workflows/terraform-plan.yml"
        ".github/workflows/terraform-apply.yml"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            error "Required file $file does not exist"
        fi
    done
    
    success "Project structure validation passed"
}

# Test 2: Terraform Module Validation
test_terraform_modules() {
    log "Testing Terraform modules..."
    
    # Find all Terraform files
    local tf_files=$(find infrastructure/modules -name "*.tf" -type f)
    
    if [[ -z "$tf_files" ]]; then
        error "No Terraform files found in modules directory"
    fi
    
    # Validate each module
    for module_dir in infrastructure/modules/*/; do
        if [[ -d "$module_dir" ]]; then
            log "Validating module: $module_dir"
            
            # Check if module has required files
            local module_name=$(basename "$module_dir")
            local required_module_files=("main.tf" "variables.tf" "outputs.tf")
            
            for file in "${required_module_files[@]}"; do
                if [[ ! -f "$module_dir$file" ]]; then
                    warning "Module $module_name missing $file"
                fi
            done
            
            # Validate Terraform syntax
            cd "$module_dir"
            if ! terraform init -backend=false >/dev/null 2>&1; then
                error "Failed to initialize module $module_name"
            fi
            
            if ! terraform validate >/dev/null 2>&1; then
                error "Module $module_name failed validation"
            fi
            
            cd - >/dev/null
        fi
    done
    
    success "Terraform modules validation passed"
}

# Test 3: Environment Configuration Validation
test_environment_config() {
    log "Testing environment configuration..."
    
    local env_dir="infrastructure/environments/$ENVIRONMENT"
    
    # Initialize Terraform
    cd "$env_dir"
    
    if ! terraform init -backend=false >/dev/null 2>&1; then
        error "Failed to initialize environment $ENVIRONMENT"
    fi
    
    # Validate configuration
    if ! terraform validate >/dev/null 2>&1; then
        error "Environment $ENVIRONMENT configuration is invalid"
    fi
    
    # Check for required variables
    local required_vars=("project_id" "region")
    for var in "${required_vars[@]}"; do
        if ! grep -q "variable \"$var\"" variables.tf; then
            error "Required variable $var not found in variables.tf"
        fi
    done
    
    # Check terraform.tfvars
    if [[ -f "terraform.tfvars" ]]; then
        if ! grep -q "project_id" terraform.tfvars; then
            error "project_id not set in terraform.tfvars"
        fi
    fi
    
    cd - >/dev/null
    
    success "Environment configuration validation passed"
}

# Test 4: Security Scanning
test_security_scanning() {
    log "Running security scans..."
    
    # Run tfsec
    log "Running tfsec security scan..."
    if ! tfsec infrastructure/ --format json > tfsec-results.json 2>/dev/null; then
        warning "tfsec found security issues, check tfsec-results.json"
    else
        success "tfsec security scan passed"
    fi
    
    # Run tflint
    log "Running tflint..."
    if ! tflint --init >/dev/null 2>&1; then
        warning "Failed to initialize tflint"
    fi
    
    if ! tflint infrastructure/ >/dev/null 2>&1; then
        warning "tflint found issues, check output above"
    else
        success "tflint validation passed"
    fi
}

# Test 5: CI/CD Pipeline Validation
test_cicd_pipeline() {
    log "Testing CI/CD pipeline configuration..."
    
    # Check GitHub Actions workflows
    local workflow_files=(
        ".github/workflows/terraform-plan.yml"
        ".github/workflows/terraform-apply.yml"
    )
    
    for workflow in "${workflow_files[@]}"; do
        if [[ ! -f "$workflow" ]]; then
            error "Workflow file $workflow not found"
        fi
        
        # Basic YAML validation
        if ! python3 -c "import yaml; yaml.safe_load(open('$workflow'))" >/dev/null 2>&1; then
            error "Invalid YAML in $workflow"
        fi
    done
    
    # Check if workflows have required steps
    local plan_workflow=".github/workflows/terraform-plan.yml"
    if ! grep -q "terraform validate" "$plan_workflow"; then
        warning "terraform validate step not found in plan workflow"
    fi
    
    if ! grep -q "terraform plan" "$plan_workflow"; then
        warning "terraform plan step not found in plan workflow"
    fi
    
    success "CI/CD pipeline validation passed"
}

# Test 6: GCP Project Validation
test_gcp_project() {
    log "Testing GCP project configuration..."
    
    # Check if project exists and is accessible
    if ! gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
        error "Project $PROJECT_ID not found or not accessible"
    fi
    
    # Check if required APIs are enabled
    local required_apis=(
        "compute.googleapis.com"
        "container.googleapis.com"
        "cloudresourcemanager.googleapis.com"
        "iam.googleapis.com"
        "storage.googleapis.com"
    )
    
    for api in "${required_apis[@]}"; do
        if ! gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
            warning "API $api is not enabled"
        fi
    done
    
    success "GCP project validation passed"
}

# Test 7: State Backend Validation
test_state_backend() {
    log "Testing Terraform state backend..."
    
    local env_dir="infrastructure/environments/$ENVIRONMENT"
    
    # Check if backend configuration exists
    if [[ ! -f "$env_dir/backend.tf" ]]; then
        error "Backend configuration not found"
    fi
    
    # Check if GCS bucket exists (if using GCS backend)
    if grep -q "backend \"gcs\"" "$env_dir/backend.tf"; then
        local bucket_name=$(grep -o 'bucket = "[^"]*"' "$env_dir/backend.tf" | cut -d'"' -f2)
        if [[ -n "$bucket_name" ]]; then
            if ! gsutil ls "gs://$bucket_name" >/dev/null 2>&1; then
                warning "GCS bucket $bucket_name not found or not accessible"
            else
                success "GCS bucket $bucket_name is accessible"
            fi
        fi
    fi
    
    success "State backend validation passed"
}

# Test 8: Cost Estimation
test_cost_estimation() {
    log "Testing cost estimation..."
    
    # Check if infracost is available
    if command -v infracost >/dev/null 2>&1; then
        local env_dir="infrastructure/environments/$ENVIRONMENT"
        
        # Run cost estimation
        if infracost breakdown --path "$env_dir" --terraform-var-file "$env_dir/terraform.tfvars" > cost-estimate.json 2>/dev/null; then
            success "Cost estimation completed, see cost-estimate.json"
        else
            warning "Cost estimation failed"
        fi
    else
        warning "infracost not available, skipping cost estimation"
    fi
}

# Test 9: Documentation Validation
test_documentation() {
    log "Testing documentation..."
    
    # Check if README files exist
    local readme_files=(
        "README.md"
        "infrastructure/README.md"
    )
    
    for readme in "${readme_files[@]}"; do
        if [[ ! -f "$readme" ]]; then
            warning "README file $readme not found"
        fi
    done
    
    # Check if module documentation exists
    for module_dir in infrastructure/modules/*/; do
        if [[ -d "$module_dir" ]]; then
            local module_name=$(basename "$module_dir")
            if [[ ! -f "$module_dir/README.md" ]]; then
                warning "Module $module_name missing README.md"
            fi
        fi
    done
    
    success "Documentation validation completed"
}

# Main execution
main() {
    log "Starting Phase 0 testing for environment: $ENVIRONMENT"
    log "Project ID: $PROJECT_ID"
    log "Region: $REGION"
    
    # Run all tests
    check_prerequisites
    test_project_structure
    test_terraform_modules
    test_environment_config
    test_security_scanning
    test_cicd_pipeline
    test_gcp_project
    test_state_backend
    test_cost_estimation
    test_documentation
    
    success "All Phase 0 tests completed successfully!"
    log "Phase 0 is ready for Phase 1 deployment"
}

# Run main function
main "$@"

#!/bin/bash
# Phase Deployment Automation Script
# This script automates the deployment of each phase with proper validation and rollback capabilities

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="${PROJECT_ID:-}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
REGION="${REGION:-us-central1}"
PHASE="${PHASE:-}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"
DRY_RUN="${DRY_RUN:-false}"

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

info() {
    echo -e "${PURPLE}[INFO]${NC} $1"
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] PHASE

Deploy a specific phase of the terraform-gcp infrastructure.

OPTIONS:
    -p, --project-id PROJECT_ID    GCP Project ID (required)
    -e, --environment ENVIRONMENT  Environment (dev/staging/prod) [default: dev]
    -r, --region REGION           Primary GCP region [default: us-central1]
    -a, --auto-approve            Auto-approve terraform apply
    -d, --dry-run                 Show what would be deployed without applying
    -h, --help                    Show this help message

PHASES:
    0    Foundation Setup
    1    Networking Foundation
    2    Security & Identity
    3    Data Layer
    4    Compute Platform
    5    Monitoring & Observability
    6    Production Hardening

EXAMPLES:
    $0 -p my-project -e dev 0
    $0 -p my-project -e staging 1 --auto-approve
    $0 -p my-project -e prod 6 --dry-run

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--project-id)
                PROJECT_ID="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            -a|--auto-approve)
                AUTO_APPROVE="true"
                shift
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            [0-6])
                PHASE="$1"
                shift
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
}

# Validate prerequisites
validate_prerequisites() {
    log "Validating prerequisites..."
    
    # Check required parameters
    if [[ -z "$PROJECT_ID" ]]; then
        error "PROJECT_ID is required. Use -p or --project-id"
    fi
    
    if [[ -z "$PHASE" ]]; then
        error "PHASE is required. Specify phase number (0-6)"
    fi
    
    if [[ ! "$PHASE" =~ ^[0-6]$ ]]; then
        error "Invalid phase: $PHASE. Must be 0-6"
    fi
    
    # Check required tools
    command -v terraform >/dev/null 2>&1 || error "Terraform is not installed"
    command -v gcloud >/dev/null 2>&1 || error "gcloud CLI is not installed"
    command -v jq >/dev/null 2>&1 || error "jq is not installed"
    
    # Check GCP authentication
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        error "No active GCP authentication found. Run 'gcloud auth login'"
    fi
    
    # Check project access
    if ! gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
        error "Cannot access project $PROJECT_ID. Check permissions and authentication"
    fi
    
    success "Prerequisites validation passed"
}

# Get phase configuration
get_phase_config() {
    case $PHASE in
        0)
            PHASE_NAME="Foundation Setup"
            TERRAFORM_DIR="infrastructure/environments/$ENVIRONMENT"
            TARGETS=()
            TEST_SCRIPT="scripts/phase-testing/phase-0-tests.sh"
            ;;
        1)
            PHASE_NAME="Networking Foundation"
            TERRAFORM_DIR="infrastructure/environments/$ENVIRONMENT"
            TARGETS=("module.vpc" "module.subnets" "module.firewall" "module.nat" "module.load_balancer")
            TEST_SCRIPT="scripts/phase-testing/phase-1-tests.sh"
            ;;
        2)
            PHASE_NAME="Security & Identity"
            TERRAFORM_DIR="infrastructure/environments/$ENVIRONMENT"
            TARGETS=("module.iam" "module.kms" "module.secrets" "module.security_policies")
            TEST_SCRIPT="scripts/phase-testing/phase-2-tests.sh"
            ;;
        3)
            PHASE_NAME="Data Layer"
            TERRAFORM_DIR="infrastructure/environments/$ENVIRONMENT"
            TARGETS=("module.cloud_sql" "module.redis" "module.bigquery" "module.storage" "module.pubsub")
            TEST_SCRIPT="scripts/phase-testing/phase-3-tests.sh"
            ;;
        4)
            PHASE_NAME="Compute Platform"
            TERRAFORM_DIR="infrastructure/environments/$ENVIRONMENT"
            TARGETS=("module.gke" "module.cloud_run" "module.cloud_functions" "module.applications")
            TEST_SCRIPT="scripts/phase-testing/phase-4-tests.sh"
            ;;
        5)
            PHASE_NAME="Monitoring & Observability"
            TERRAFORM_DIR="infrastructure/environments/$ENVIRONMENT"
            TARGETS=("module.logging" "module.monitoring" "module.alerts" "module.dashboards")
            TEST_SCRIPT="scripts/phase-testing/phase-5-tests.sh"
            ;;
        6)
            PHASE_NAME="Production Hardening"
            TERRAFORM_DIR="infrastructure/environments/$ENVIRONMENT"
            TARGETS=("module.ha_config" "module.dr_config" "module.security_hardening" "module.performance_optimization")
            TEST_SCRIPT="scripts/phase-testing/phase-6-tests.sh"
            ;;
    esac
}

# Initialize Terraform
init_terraform() {
    log "Initializing Terraform for $PHASE_NAME..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    if ! terraform init -reconfigure; then
        error "Terraform initialization failed"
    fi
    
    # Validate configuration
    if ! terraform validate; then
        error "Terraform configuration validation failed"
    fi
    
    success "Terraform initialization completed"
}

# Plan Terraform deployment
plan_terraform() {
    log "Planning Terraform deployment for $PHASE_NAME..."
    
    local plan_file="tfplan-phase-$PHASE-$(date +%Y%m%d-%H%M%S)"
    local plan_args=("-var-file=terraform.tfvars" "-out=$plan_file")
    
    # Add targets if specified
    if [[ ${#TARGETS[@]} -gt 0 ]]; then
        for target in "${TARGETS[@]}"; do
            plan_args+=("-target=$target")
        done
    fi
    
    # Run terraform plan
    if ! terraform plan "${plan_args[@]}"; then
        error "Terraform planning failed"
    fi
    
    success "Terraform planning completed"
    echo "$plan_file"
}

# Apply Terraform deployment
apply_terraform() {
    local plan_file="$1"
    
    log "Applying Terraform deployment for $PHASE_NAME..."
    
    local apply_args=("$plan_file")
    
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        apply_args+=("-auto-approve")
    fi
    
    # Run terraform apply
    if ! terraform apply "${apply_args[@]}"; then
        error "Terraform application failed"
    fi
    
    success "Terraform application completed"
}

# Run phase tests
run_phase_tests() {
    log "Running phase tests for $PHASE_NAME..."
    
    # Set environment variables for tests
    export PROJECT_ID="$PROJECT_ID"
    export ENVIRONMENT="$ENVIRONMENT"
    export REGION="$REGION"
    
    # Run the test script
    if ! bash "$TEST_SCRIPT"; then
        error "Phase tests failed"
    fi
    
    success "Phase tests completed successfully"
}

# Create deployment summary
create_deployment_summary() {
    local plan_file="$1"
    local summary_file="deployment-summary-phase-$PHASE-$(date +%Y%m%d-%H%M%S).md"
    
    log "Creating deployment summary..."
    
    cat > "$summary_file" << EOF
# Phase $PHASE Deployment Summary

## Deployment Details
- **Phase**: $PHASE - $PHASE_NAME
- **Project**: $PROJECT_ID
- **Environment**: $ENVIRONMENT
- **Region**: $REGION
- **Deployment Time**: $(date)
- **Plan File**: $plan_file

## Resources Deployed
EOF
    
    # Add resource list if plan file exists
    if [[ -f "$plan_file" ]]; then
        echo "### Terraform Plan Summary" >> "$summary_file"
        echo '```' >> "$summary_file"
        terraform show -no-color "$plan_file" >> "$summary_file"
        echo '```' >> "$summary_file"
    fi
    
    cat >> "$summary_file" << EOF

## Test Results
- **Test Script**: $TEST_SCRIPT
- **Test Status**: PASSED
- **Test Time**: $(date)

## Next Steps
1. Review deployment results
2. Validate all resources are working correctly
3. Proceed to next phase if all tests pass
4. Update documentation as needed

## Rollback Information
If rollback is needed, use the following command:
\`\`\`bash
terraform destroy -var-file=terraform.tfvars -auto-approve
\`\`\`

EOF
    
    success "Deployment summary created: $summary_file"
}

# Rollback deployment
rollback_deployment() {
    log "Rolling back Phase $PHASE deployment..."
    
    cd "$TERRAFORM_DIR"
    
    local destroy_args=("-var-file=terraform.tfvars")
    
    # Add targets if specified
    if [[ ${#TARGETS[@]} -gt 0 ]]; then
        for target in "${TARGETS[@]}"; do
            destroy_args+=("-target=$target")
        done
    fi
    
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        destroy_args+=("-auto-approve")
    fi
    
    # Run terraform destroy
    if ! terraform destroy "${destroy_args[@]}"; then
        error "Terraform rollback failed"
    fi
    
    success "Phase $PHASE rollback completed"
}

# Main deployment function
deploy_phase() {
    log "Starting Phase $PHASE deployment: $PHASE_NAME"
    log "Project: $PROJECT_ID, Environment: $ENVIRONMENT, Region: $REGION"
    
    # Get phase configuration
    get_phase_config
    
    # Initialize Terraform
    init_terraform
    
    # Plan deployment
    local plan_file
    plan_file=$(plan_terraform)
    
    # Check if dry run
    if [[ "$DRY_RUN" == "true" ]]; then
        info "Dry run completed. No changes applied."
        info "Plan file: $plan_file"
        return 0
    fi
    
    # Apply deployment
    apply_terraform "$plan_file"
    
    # Run tests
    run_phase_tests
    
    # Create summary
    create_deployment_summary "$plan_file"
    
    success "Phase $PHASE deployment completed successfully!"
    info "Phase $PHASE_NAME is ready for the next phase"
}

# Error handling
handle_error() {
    local exit_code=$?
    error "Deployment failed with exit code $exit_code"
}

# Set up error handling
trap handle_error ERR

# Main execution
main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Validate prerequisites
    validate_prerequisites
    
    # Deploy phase
    deploy_phase
}

# Run main function
main "$@"

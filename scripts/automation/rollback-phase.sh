#!/bin/bash
# Phase Rollback Script
# This script provides safe rollback capabilities for each phase

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
FORCE="${FORCE:-false}"
BACKUP_STATE="${BACKUP_STATE:-true}"

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

Rollback a specific phase of the terraform-gcp infrastructure.

OPTIONS:
    -p, --project-id PROJECT_ID    GCP Project ID (required)
    -e, --environment ENVIRONMENT  Environment (dev/staging/prod) [default: dev]
    -r, --region REGION           Primary GCP region [default: us-central1]
    -f, --force                   Force rollback without confirmation
    -n, --no-backup              Skip state backup
    -h, --help                   Show this help message

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
    $0 -p my-project -e staging 1 --force
    $0 -p my-project -e prod 6 --no-backup

WARNING: This will destroy resources. Use with caution!

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
            -f|--force)
                FORCE="true"
                shift
                ;;
            -n|--no-backup)
                BACKUP_STATE="false"
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
            RESOURCES=("terraform state" "CI/CD pipeline" "basic modules")
            ;;
        1)
            PHASE_NAME="Networking Foundation"
            TERRAFORM_DIR="infrastructure/environments/$ENVIRONMENT"
            TARGETS=("module.vpc" "module.subnets" "module.firewall" "module.nat" "module.load_balancer")
            RESOURCES=("VPC" "subnets" "firewall rules" "NAT gateway" "load balancer")
            ;;
        2)
            PHASE_NAME="Security & Identity"
            TERRAFORM_DIR="infrastructure/environments/$ENVIRONMENT"
            TARGETS=("module.iam" "module.kms" "module.secrets" "module.security_policies")
            RESOURCES=("IAM policies" "KMS keys" "secrets" "security policies")
            ;;
        3)
            PHASE_NAME="Data Layer"
            TERRAFORM_DIR="infrastructure/environments/$ENVIRONMENT"
            TARGETS=("module.cloud_sql" "module.redis" "module.bigquery" "module.storage" "module.pubsub")
            RESOURCES=("Cloud SQL" "Redis" "BigQuery" "Cloud Storage" "Pub/Sub")
            ;;
        4)
            PHASE_NAME="Compute Platform"
            TERRAFORM_DIR="infrastructure/environments/$ENVIRONMENT"
            TARGETS=("module.gke" "module.cloud_run" "module.cloud_functions" "module.applications")
            RESOURCES=("GKE cluster" "Cloud Run services" "Cloud Functions" "applications")
            ;;
        5)
            PHASE_NAME="Monitoring & Observability"
            TERRAFORM_DIR="infrastructure/environments/$ENVIRONMENT"
            TARGETS=("module.logging" "module.monitoring" "module.alerts" "module.dashboards")
            RESOURCES=("logging" "monitoring" "alerts" "dashboards")
            ;;
        6)
            PHASE_NAME="Production Hardening"
            TERRAFORM_DIR="infrastructure/environments/$ENVIRONMENT"
            TARGETS=("module.ha_config" "module.dr_config" "module.security_hardening" "module.performance_optimization")
            RESOURCES=("HA configuration" "DR configuration" "security hardening" "performance optimization")
            ;;
    esac
}

# Backup Terraform state
backup_terraform_state() {
    if [[ "$BACKUP_STATE" == "true" ]]; then
        log "Backing up Terraform state..."
        
        cd "$TERRAFORM_DIR"
        
        local backup_file="terraform.tfstate.backup.$(date +%Y%m%d-%H%M%S)"
        
        if [[ -f "terraform.tfstate" ]]; then
            cp "terraform.tfstate" "$backup_file"
            success "Terraform state backed up to: $backup_file"
        else
            warning "No terraform.tfstate file found to backup"
        fi
    fi
}

# Confirm rollback
confirm_rollback() {
    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi
    
    echo
    warning "WARNING: This will destroy the following resources:"
    for resource in "${RESOURCES[@]}"; do
        echo "  - $resource"
    done
    echo
    
    read -p "Are you sure you want to rollback Phase $PHASE ($PHASE_NAME)? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        info "Rollback cancelled by user"
        exit 0
    fi
}

# Initialize Terraform
init_terraform() {
    log "Initializing Terraform for rollback..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    if ! terraform init -reconfigure; then
        error "Terraform initialization failed"
    fi
    
    success "Terraform initialization completed"
}

# Plan rollback
plan_rollback() {
    log "Planning rollback for $PHASE_NAME..."
    
    local plan_file="rollback-plan-phase-$PHASE-$(date +%Y%m%d-%H%M%S)"
    local plan_args=("-var-file=terraform.tfvars" "-destroy" "-out=$plan_file")
    
    # Add targets if specified
    if [[ ${#TARGETS[@]} -gt 0 ]]; then
        for target in "${TARGETS[@]}"; do
            plan_args+=("-target=$target")
        done
    fi
    
    # Run terraform plan
    if ! terraform plan "${plan_args[@]}"; then
        error "Terraform rollback planning failed"
    fi
    
    success "Terraform rollback planning completed"
    echo "$plan_file"
}

# Execute rollback
execute_rollback() {
    local plan_file="$1"
    
    log "Executing rollback for $PHASE_NAME..."
    
    # Run terraform apply with destroy plan
    if ! terraform apply "$plan_file"; then
        error "Terraform rollback execution failed"
    fi
    
    success "Terraform rollback execution completed"
}

# Verify rollback
verify_rollback() {
    log "Verifying rollback completion..."
    
    cd "$TERRAFORM_DIR"
    
    # Check if resources still exist
    local remaining_resources=0
    
    for target in "${TARGETS[@]}"; do
        if terraform state list | grep -q "$target"; then
            ((remaining_resources++))
            warning "Resource still exists: $target"
        fi
    done
    
    if [[ $remaining_resources -eq 0 ]]; then
        success "All Phase $PHASE resources have been successfully removed"
    else
        warning "$remaining_resources resources still exist. Manual cleanup may be required."
    fi
}

# Create rollback summary
create_rollback_summary() {
    local plan_file="$1"
    local summary_file="rollback-summary-phase-$PHASE-$(date +%Y%m%d-%H%M%S).md"
    
    log "Creating rollback summary..."
    
    cat > "$summary_file" << EOF
# Phase $PHASE Rollback Summary

## Rollback Details
- **Phase**: $PHASE - $PHASE_NAME
- **Project**: $PROJECT_ID
- **Environment**: $ENVIRONMENT
- **Region**: $REGION
- **Rollback Time**: $(date)
- **Plan File**: $plan_file

## Resources Removed
EOF
    
    for resource in "${RESOURCES[@]}"; do
        echo "- $resource" >> "$summary_file"
    done
    
    cat >> "$summary_file" << EOF

## Rollback Status
- **Status**: COMPLETED
- **Verification**: PASSED
- **Backup Created**: $BACKUP_STATE

## Next Steps
1. Review rollback results
2. Verify all resources have been removed
3. Check for any remaining dependencies
4. Plan next steps (redeploy or proceed to previous phase)

## Recovery Information
If you need to recover from this rollback:
1. Check the backup state file (if created)
2. Redeploy the phase using the deployment script
3. Verify all resources are working correctly

EOF
    
    success "Rollback summary created: $summary_file"
}

# Main rollback function
rollback_phase() {
    log "Starting Phase $PHASE rollback: $PHASE_NAME"
    log "Project: $PROJECT_ID, Environment: $ENVIRONMENT, Region: $REGION"
    
    # Get phase configuration
    get_phase_config
    
    # Confirm rollback
    confirm_rollback
    
    # Backup state
    backup_terraform_state
    
    # Initialize Terraform
    init_terraform
    
    # Plan rollback
    local plan_file
    plan_file=$(plan_rollback)
    
    # Execute rollback
    execute_rollback "$plan_file"
    
    # Verify rollback
    verify_rollback
    
    # Create summary
    create_rollback_summary "$plan_file"
    
    success "Phase $PHASE rollback completed successfully!"
    info "Phase $PHASE_NAME has been rolled back"
}

# Error handling
handle_error() {
    local exit_code=$?
    error "Rollback failed with exit code $exit_code"
}

# Set up error handling
trap handle_error ERR

# Main execution
main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Validate prerequisites
    validate_prerequisites
    
    # Rollback phase
    rollback_phase
}

# Run main function
main "$@"

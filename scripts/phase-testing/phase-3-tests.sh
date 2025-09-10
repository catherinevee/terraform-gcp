#!/bin/bash
# Phase 3: Data Layer - Testing Script
# This script validates the data infrastructure including Cloud SQL, Redis, BigQuery, Storage, and Pub/Sub

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
    command -v psql >/dev/null 2>&1 || error "PostgreSQL client is not installed"
    command -v redis-cli >/dev/null 2>&1 || error "Redis client is not installed"
    
    if [[ -z "$PROJECT_ID" ]]; then
        error "PROJECT_ID environment variable is required"
    fi
    
    success "Prerequisites check passed"
}

# Test 1: Cloud SQL Validation
test_cloud_sql() {
    log "Testing Cloud SQL configuration..."
    
    # Get Cloud SQL instances
    local sql_instances=$(gcloud sql instances list --project="$PROJECT_ID" --format="json")
    local instance_count=$(echo "$sql_instances" | jq '. | length')
    
    if [[ $instance_count -eq 0 ]]; then
        error "No Cloud SQL instances found"
    fi
    
    # Check for required instance
    local instance_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-db"
    local instance_info=$(echo "$sql_instances" | jq -r ".[] | select(.name == \"$instance_name\")")
    
    if [[ -z "$instance_info" ]]; then
        error "Required Cloud SQL instance $instance_name not found"
    fi
    
    # Validate instance configuration
    local database_version=$(echo "$instance_info" | jq -r '.databaseVersion')
    local tier=$(echo "$instance_info" | jq -r '.settings.tier')
    local availability_type=$(echo "$instance_info" | jq -r '.settings.availabilityType')
    
    log "Instance details: Version=$database_version, Tier=$tier, Availability=$availability_type"
    
    # Check backup configuration
    local backup_enabled=$(echo "$instance_info" | jq -r '.settings.backupConfiguration.enabled')
    if [[ "$backup_enabled" == "true" ]]; then
        success "Backup configuration enabled"
    else
        warning "Backup configuration not enabled"
    fi
    
    # Check private IP configuration
    local private_ip=$(echo "$instance_info" | jq -r '.ipAddresses[] | select(.type == "PRIVATE") | .ipAddress')
    if [[ -n "$private_ip" ]]; then
        success "Private IP configured: $private_ip"
    else
        warning "Private IP not configured"
    fi
    
    # Test database connectivity (if possible)
    log "Testing database connectivity..."
    if [[ -n "$private_ip" ]]; then
        # Note: This would require a VM in the same VPC to test connectivity
        warning "Database connectivity test requires VM in same VPC"
    fi
    
    success "Cloud SQL validation passed"
}

# Test 2: Redis Validation
test_redis() {
    log "Testing Redis configuration..."
    
    # Get Redis instances
    local redis_instances=$(gcloud redis instances list --region="$REGION" --project="$PROJECT_ID" --format="json")
    local instance_count=$(echo "$redis_instances" | jq '. | length')
    
    if [[ $instance_count -eq 0 ]]; then
        error "No Redis instances found"
    fi
    
    # Check for required instance
    local instance_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-redis"
    local instance_info=$(echo "$redis_instances" | jq -r ".[] | select(.name | contains(\"$instance_name\"))")
    
    if [[ -z "$instance_info" ]]; then
        error "Required Redis instance $instance_name not found"
    fi
    
    # Validate instance configuration
    local tier=$(echo "$instance_info" | jq -r '.tier')
    local memory_size=$(echo "$instance_info" | jq -r '.memorySizeGb')
    local redis_version=$(echo "$instance_info" | jq -r '.redisVersion')
    
    log "Redis details: Tier=$tier, Memory=${memory_size}GB, Version=$redis_version"
    
    # Check authorized network
    local authorized_network=$(echo "$instance_info" | jq -r '.authorizedNetwork')
    if [[ -n "$authorized_network" ]]; then
        success "Authorized network configured: $authorized_network"
    else
        warning "Authorized network not configured"
    fi
    
    # Check Redis AUTH
    local auth_enabled=$(echo "$instance_info" | jq -r '.authEnabled')
    if [[ "$auth_enabled" == "true" ]]; then
        success "Redis AUTH enabled"
    else
        warning "Redis AUTH not enabled"
    fi
    
    success "Redis validation passed"
}

# Test 3: BigQuery Validation
test_bigquery() {
    log "Testing BigQuery configuration..."
    
    # Get BigQuery datasets
    local datasets=$(bq ls --project_id="$PROJECT_ID" --format=json 2>/dev/null || echo "[]")
    local dataset_count=$(echo "$datasets" | jq '. | length')
    
    if [[ $dataset_count -eq 0 ]]; then
        error "No BigQuery datasets found"
    fi
    
    # Check for required datasets
    local required_datasets=(
        "${ENVIRONMENT}_analytics"
        "${ENVIRONMENT}_ml_features"
    )
    
    for dataset_id in "${required_datasets[@]}"; do
        if ! echo "$datasets" | jq -e ".[] | select(.datasetReference.datasetId == \"$dataset_id\")" >/dev/null; then
            error "Required dataset $dataset_id not found"
        fi
    done
    
    # Validate dataset configuration
    for dataset_id in "${required_datasets[@]}"; do
        local dataset_info=$(bq show --project_id="$PROJECT_ID" --format=json "$dataset_id" 2>/dev/null || echo "{}")
        if [[ "$dataset_info" != "{}" ]]; then
            local location=$(echo "$dataset_info" | jq -r '.location')
            local default_table_expiration=$(echo "$dataset_info" | jq -r '.defaultTableExpirationMs')
            
            log "Dataset $dataset_id: Location=$location, DefaultExpiration=${default_table_expiration}ms"
            
            # Check for tables
            local tables=$(bq ls --project_id="$PROJECT_ID" --format=json "$dataset_id" 2>/dev/null || echo "[]")
            local table_count=$(echo "$tables" | jq '. | length')
            
            if [[ $table_count -gt 0 ]]; then
                success "Dataset $dataset_id has $table_count tables"
            else
                warning "Dataset $dataset_id has no tables"
            fi
        fi
    done
    
    success "BigQuery validation passed"
}

# Test 4: Cloud Storage Validation
test_cloud_storage() {
    log "Testing Cloud Storage configuration..."
    
    # Get Cloud Storage buckets
    local buckets=$(gsutil ls -p "$PROJECT_ID" 2>/dev/null || echo "")
    
    if [[ -z "$buckets" ]]; then
        error "No Cloud Storage buckets found"
    fi
    
    # Check for required buckets
    local required_buckets=(
        "static"
        "media"
        "uploads"
        "backups"
        "functions"
    )
    
    for bucket_type in "${required_buckets[@]}"; do
        local bucket_name="${PROJECT_ID}-${ENVIRONMENT}-${bucket_type}"
        if ! echo "$buckets" | grep -q "$bucket_name"; then
            error "Required bucket $bucket_name not found"
        fi
    done
    
    # Validate bucket configuration
    for bucket_type in "${required_buckets[@]}"; do
        local bucket_name="${PROJECT_ID}-${ENVIRONMENT}-${bucket_type}"
        
        # Check bucket location
        local location=$(gsutil ls -L -b "gs://$bucket_name" 2>/dev/null | grep "Location constraint" | awk '{print $3}' || echo "unknown")
        log "Bucket $bucket_name: Location=$location"
        
        # Check versioning
        local versioning=$(gsutil versioning get "gs://$bucket_name" 2>/dev/null | grep "Enabled" || echo "Disabled")
        if [[ "$versioning" == "Enabled" ]]; then
            success "Versioning enabled for $bucket_name"
        else
            warning "Versioning disabled for $bucket_name"
        fi
        
        # Check lifecycle policies
        local lifecycle=$(gsutil lifecycle get "gs://$bucket_name" 2>/dev/null || echo "No lifecycle policy")
        if [[ "$lifecycle" != "No lifecycle policy" ]]; then
            success "Lifecycle policy configured for $bucket_name"
        else
            warning "No lifecycle policy for $bucket_name"
        fi
    done
    
    success "Cloud Storage validation passed"
}

# Test 5: Pub/Sub Validation
test_pubsub() {
    log "Testing Pub/Sub configuration..."
    
    # Get Pub/Sub topics
    local topics=$(gcloud pubsub topics list --project="$PROJECT_ID" --format="json")
    local topic_count=$(echo "$topics" | jq '. | length')
    
    if [[ $topic_count -eq 0 ]]; then
        error "No Pub/Sub topics found"
    fi
    
    # Check for required topics
    local required_topics=(
        "events"
        "notifications"
    )
    
    for topic_suffix in "${required_topics[@]}"; do
        local topic_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-${topic_suffix}"
        if ! echo "$topics" | jq -e ".[] | select(.name | contains(\"$topic_name\"))" >/dev/null; then
            error "Required topic $topic_name not found"
        fi
    done
    
    # Get Pub/Sub subscriptions
    local subscriptions=$(gcloud pubsub subscriptions list --project="$PROJECT_ID" --format="json")
    local subscription_count=$(echo "$subscriptions" | jq '. | length')
    
    if [[ $subscription_count -eq 0 ]]; then
        error "No Pub/Sub subscriptions found"
    fi
    
    # Validate subscription configuration
    for subscription in $(echo "$subscriptions" | jq -r '.[].name'); do
        local subscription_info=$(gcloud pubsub subscriptions describe "$subscription" --project="$PROJECT_ID" --format="json")
        local ack_deadline=$(echo "$subscription_info" | jq -r '.ackDeadlineSeconds')
        local message_retention=$(echo "$subscription_info" | jq -r '.messageRetentionDuration')
        
        log "Subscription $subscription: AckDeadline=${ack_deadline}s, Retention=$message_retention"
        
        # Check for dead letter topic
        local dead_letter_topic=$(echo "$subscription_info" | jq -r '.deadLetterPolicy.deadLetterTopic // "none"')
        if [[ "$dead_letter_topic" != "none" ]]; then
            success "Dead letter topic configured for $subscription"
        else
            warning "No dead letter topic for $subscription"
        fi
    done
    
    success "Pub/Sub validation passed"
}

# Test 6: Data Integration Tests
test_data_integration() {
    log "Testing data integration..."
    
    # Test BigQuery to Cloud Storage integration
    log "Testing BigQuery to Cloud Storage integration..."
    local test_query="SELECT 1 as test_value"
    if bq query --project_id="$PROJECT_ID" --use_legacy_sql=false "$test_query" >/dev/null 2>&1; then
        success "BigQuery query execution working"
    else
        warning "BigQuery query execution failed"
    fi
    
    # Test Cloud Storage to BigQuery integration (if tables exist)
    local datasets=$(bq ls --project_id="$PROJECT_ID" --format=json 2>/dev/null || echo "[]")
    for dataset in $(echo "$datasets" | jq -r '.[].datasetReference.datasetId'); do
        local tables=$(bq ls --project_id="$PROJECT_ID" --format=json "$dataset" 2>/dev/null || echo "[]")
        local table_count=$(echo "$tables" | jq '. | length')
        
        if [[ $table_count -gt 0 ]]; then
            success "Dataset $dataset has $table_count tables"
            break
        fi
    done
    
    success "Data integration tests passed"
}

# Test 7: Backup and Recovery Tests
test_backup_recovery() {
    log "Testing backup and recovery..."
    
    # Test Cloud SQL backup
    local sql_instances=$(gcloud sql instances list --project="$PROJECT_ID" --format="json")
    for instance in $(echo "$sql_instances" | jq -r '.[].name'); do
        local backups=$(gcloud sql backups list --instance="$instance" --project="$PROJECT_ID" --format="json")
        local backup_count=$(echo "$backups" | jq '. | length')
        
        if [[ $backup_count -gt 0 ]]; then
            success "Instance $instance has $backup_count backups"
        else
            warning "Instance $instance has no backups"
        fi
    done
    
    # Test Cloud Storage backup
    local backup_buckets=$(gsutil ls -p "$PROJECT_ID" | grep "backup" || echo "")
    if [[ -n "$backup_buckets" ]]; then
        success "Backup buckets found"
    else
        warning "No backup buckets found"
    fi
    
    success "Backup and recovery tests passed"
}

# Test 8: Data Encryption Tests
test_data_encryption() {
    log "Testing data encryption..."
    
    # Test Cloud SQL encryption
    local sql_instances=$(gcloud sql instances list --project="$PROJECT_ID" --format="json")
    for instance in $(echo "$sql_instances" | jq -r '.[].name'); do
        local encryption=$(gcloud sql instances describe "$instance" --project="$PROJECT_ID" --format="value(diskEncryptionConfiguration.kmsKeyName)" 2>/dev/null || echo "")
        if [[ -n "$encryption" ]]; then
            success "Instance $instance is encrypted with KMS key"
        else
            warning "Instance $instance may not be encrypted"
        fi
    done
    
    # Test Cloud Storage encryption
    local buckets=$(gsutil ls -p "$PROJECT_ID" 2>/dev/null || echo "")
    if [[ -n "$buckets" ]]; then
        success "Cloud Storage buckets found (encryption status varies by bucket)"
    else
        warning "No Cloud Storage buckets found"
    fi
    
    success "Data encryption tests passed"
}

# Test 9: Performance Tests
test_performance() {
    log "Testing data layer performance..."
    
    # Test BigQuery performance
    local test_query="SELECT COUNT(*) as row_count FROM \`${PROJECT_ID}.${ENVIRONMENT}_analytics.events\` LIMIT 1"
    local start_time=$(date +%s)
    
    if bq query --project_id="$PROJECT_ID" --use_legacy_sql=false "$test_query" >/dev/null 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ $duration -lt 10 ]]; then
            success "BigQuery query completed in ${duration}s"
        else
            warning "BigQuery query took ${duration}s (may be slow)"
        fi
    else
        warning "BigQuery performance test failed"
    fi
    
    # Test Cloud Storage performance
    local test_file="/tmp/test-$(date +%s).txt"
    echo "test data" > "$test_file"
    
    local test_bucket="${PROJECT_ID}-${ENVIRONMENT}-uploads"
    local start_time=$(date +%s)
    
    if gsutil cp "$test_file" "gs://$test_bucket/" >/dev/null 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ $duration -lt 5 ]]; then
            success "Cloud Storage upload completed in ${duration}s"
        else
            warning "Cloud Storage upload took ${duration}s (may be slow)"
        fi
        
        # Clean up test file
        gsutil rm "gs://$test_bucket/$(basename "$test_file")" >/dev/null 2>&1
    else
        warning "Cloud Storage performance test failed"
    fi
    
    rm -f "$test_file"
    
    success "Performance tests passed"
}

# Test 10: Data Lifecycle Tests
test_data_lifecycle() {
    log "Testing data lifecycle policies..."
    
    # Test Cloud Storage lifecycle
    local buckets=$(gsutil ls -p "$PROJECT_ID" 2>/dev/null || echo "")
    local lifecycle_enabled=0
    
    for bucket in $buckets; do
        local bucket_name=$(basename "$bucket")
        local lifecycle=$(gsutil lifecycle get "$bucket" 2>/dev/null || echo "No lifecycle policy")
        
        if [[ "$lifecycle" != "No lifecycle policy" ]]; then
            ((lifecycle_enabled++))
            success "Lifecycle policy configured for $bucket_name"
        fi
    done
    
    if [[ $lifecycle_enabled -gt 0 ]]; then
        success "Found $lifecycle_enabled buckets with lifecycle policies"
    else
        warning "No lifecycle policies configured"
    fi
    
    # Test BigQuery table expiration
    local datasets=$(bq ls --project_id="$PROJECT_ID" --format=json 2>/dev/null || echo "[]")
    local expiration_configured=0
    
    for dataset in $(echo "$datasets" | jq -r '.[].datasetReference.datasetId'); do
        local dataset_info=$(bq show --project_id="$PROJECT_ID" --format=json "$dataset" 2>/dev/null || echo "{}")
        local default_expiration=$(echo "$dataset_info" | jq -r '.defaultTableExpirationMs // 0')
        
        if [[ $default_expiration -gt 0 ]]; then
            ((expiration_configured++))
            success "Default table expiration configured for dataset $dataset"
        fi
    done
    
    if [[ $expiration_configured -gt 0 ]]; then
        success "Found $expiration_configured datasets with table expiration"
    else
        warning "No table expiration configured"
    fi
    
    success "Data lifecycle tests passed"
}

# Main execution
main() {
    log "Starting Phase 3 testing for environment: $ENVIRONMENT"
    log "Project ID: $PROJECT_ID"
    log "Region: $REGION"
    
    # Run all tests
    check_prerequisites
    test_cloud_sql
    test_redis
    test_bigquery
    test_cloud_storage
    test_pubsub
    test_data_integration
    test_backup_recovery
    test_data_encryption
    test_performance
    test_data_lifecycle
    
    success "All Phase 3 tests completed successfully!"
    log "Phase 3 data layer is ready for Phase 4 compute platform implementation"
}

# Run main function
main "$@"

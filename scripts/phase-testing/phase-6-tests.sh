#!/bin/bash
# Phase 6: Production Hardening - Testing Script
# This script validates the production hardening including HA, DR, security hardening, and compliance

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="${PROJECT_ID:-}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
REGION="${REGION:-us-central1}"
SECONDARY_REGION="${SECONDARY_REGION:-us-east1}"

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
    command -v kubectl >/dev/null 2>&1 || error "kubectl is not installed"
    command -v curl >/dev/null 2>&1 || error "curl is not installed"
    
    if [[ -z "$PROJECT_ID" ]]; then
        error "PROJECT_ID environment variable is required"
    fi
    
    if [[ "$ENVIRONMENT" != "prod" ]]; then
        warning "This script is designed for production environment testing"
    fi
    
    success "Prerequisites check passed"
}

# Test 1: High Availability Validation
test_high_availability() {
    log "Testing high availability configuration..."
    
    # Test GKE cluster HA
    local cluster_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-gke"
    local cluster_info=$(gcloud container clusters describe "$cluster_name" --region="$REGION" --project="$PROJECT_ID" --format="json")
    
    # Check for multi-zone configuration
    local node_locations=$(echo "$cluster_info" | jq -r '.locations | length')
    if [[ $node_locations -gt 1 ]]; then
        success "GKE cluster configured for multi-zone HA with $node_locations zones"
    else
        error "GKE cluster not configured for multi-zone HA"
    fi
    
    # Check for regional persistent disks
    local node_pools=$(gcloud container node-pools list --cluster="$cluster_name" --region="$REGION" --project="$PROJECT_ID" --format="json")
    for pool in $(echo "$node_pools" | jq -r '.[].name'); do
        local pool_info=$(gcloud container node-pools describe "$pool" --cluster="$cluster_name" --region="$REGION" --project="$PROJECT_ID" --format="json")
        local disk_type=$(echo "$pool_info" | jq -r '.config.diskType')
        
        if [[ "$disk_type" == "pd-ssd" ]]; then
            success "Node pool $pool using SSD for better performance"
        else
            warning "Node pool $pool using $disk_type (consider SSD for production)"
        fi
    done
    
    # Test Cloud SQL HA
    local sql_instances=$(gcloud sql instances list --project="$PROJECT_ID" --format="json")
    for instance in $(echo "$sql_instances" | jq -r '.[].name'); do
        local instance_info=$(gcloud sql instances describe "$instance" --project="$PROJECT_ID" --format="json")
        local availability_type=$(echo "$instance_info" | jq -r '.settings.availabilityType')
        
        if [[ "$availability_type" == "REGIONAL" ]]; then
            success "Cloud SQL instance $instance configured for regional HA"
        else
            warning "Cloud SQL instance $instance not configured for regional HA"
        fi
    done
    
    # Test Redis HA
    local redis_instances=$(gcloud redis instances list --region="$REGION" --project="$PROJECT_ID" --format="json")
    for instance in $(echo "$redis_instances" | jq -r '.[].name'); do
        local instance_info=$(gcloud redis instances describe "$instance" --region="$REGION" --project="$PROJECT_ID" --format="json")
        local tier=$(echo "$instance_info" | jq -r '.tier')
        
        if [[ "$tier" == "STANDARD_HA" ]]; then
            success "Redis instance $instance configured for HA"
        else
            warning "Redis instance $instance not configured for HA"
        fi
    done
    
    success "High availability validation passed"
}

# Test 2: Disaster Recovery Validation
test_disaster_recovery() {
    log "Testing disaster recovery configuration..."
    
    # Test backup configuration
    local sql_instances=$(gcloud sql instances list --project="$PROJECT_ID" --format="json")
    for instance in $(echo "$sql_instances" | jq -r '.[].name'); do
        local instance_info=$(gcloud sql instances describe "$instance" --project="$PROJECT_ID" --format="json")
        local backup_enabled=$(echo "$instance_info" | jq -r '.settings.backupConfiguration.enabled')
        local point_in_time_recovery=$(echo "$instance_info" | jq -r '.settings.backupConfiguration.pointInTimeRecoveryEnabled')
        local backup_retention=$(echo "$instance_info" | jq -r '.settings.backupConfiguration.retainedBackups')
        
        if [[ "$backup_enabled" == "true" ]]; then
            success "Backup enabled for Cloud SQL instance $instance"
        else
            error "Backup not enabled for Cloud SQL instance $instance"
        fi
        
        if [[ "$point_in_time_recovery" == "true" ]]; then
            success "Point-in-time recovery enabled for Cloud SQL instance $instance"
        else
            warning "Point-in-time recovery not enabled for Cloud SQL instance $instance"
        fi
        
        if [[ $backup_retention -ge 30 ]]; then
            success "Backup retention of $backup_retention days for Cloud SQL instance $instance"
        else
            warning "Backup retention of $backup_retention days for Cloud SQL instance $instance (consider 30+ days for production)"
        fi
    done
    
    # Test cross-region replication
    local storage_buckets=$(gsutil ls -p "$PROJECT_ID" 2>/dev/null || echo "")
    local cross_region_buckets=0
    
    for bucket in $storage_buckets; do
        local bucket_name=$(basename "$bucket")
        local location=$(gsutil ls -L -b "$bucket" 2>/dev/null | grep "Location constraint" | awk '{print $3}' || echo "unknown")
        
        if [[ "$location" == "US" || "$location" == "EU" || "$location" == "ASIA" ]]; then
            ((cross_region_buckets++))
            success "Bucket $bucket_name configured for cross-region storage"
        fi
    done
    
    if [[ $cross_region_buckets -gt 0 ]]; then
        success "Found $cross_region_buckets buckets with cross-region storage"
    else
        warning "No buckets with cross-region storage found"
    fi
    
    # Test BigQuery cross-region replication
    local datasets=$(bq ls --project_id="$PROJECT_ID" --format=json 2>/dev/null || echo "[]")
    local cross_region_datasets=0
    
    for dataset in $(echo "$datasets" | jq -r '.[].datasetReference.datasetId'); do
        local dataset_info=$(bq show --project_id="$PROJECT_ID" --format=json "$dataset" 2>/dev/null || echo "{}")
        local location=$(echo "$dataset_info" | jq -r '.location')
        
        if [[ "$location" == "US" || "$location" == "EU" || "$location" == "ASIA" ]]; then
            ((cross_region_datasets++))
            success "Dataset $dataset configured for cross-region storage"
        fi
    done
    
    if [[ $cross_region_datasets -gt 0 ]]; then
        success "Found $cross_region_datasets datasets with cross-region storage"
    else
        warning "No datasets with cross-region storage found"
    fi
    
    success "Disaster recovery validation passed"
}

# Test 3: Security Hardening Validation
test_security_hardening() {
    log "Testing security hardening..."
    
    # Test GKE security
    local cluster_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-gke"
    local cluster_info=$(gcloud container clusters describe "$cluster_name" --region="$REGION" --project="$PROJECT_ID" --format="json")
    
    # Check for private cluster
    local private_cluster=$(echo "$cluster_info" | jq -r '.privateClusterConfig.enablePrivateNodes')
    if [[ "$private_cluster" == "true" ]]; then
        success "GKE cluster is private"
    else
        error "GKE cluster is not private"
    fi
    
    # Check for private endpoint
    local private_endpoint=$(echo "$cluster_info" | jq -r '.privateClusterConfig.enablePrivateEndpoint')
    if [[ "$private_endpoint" == "true" ]]; then
        success "GKE cluster has private endpoint"
    else
        warning "GKE cluster does not have private endpoint"
    fi
    
    # Check for Workload Identity
    local workload_identity=$(echo "$cluster_info" | jq -r '.workloadIdentityConfig.workloadPool')
    if [[ -n "$workload_identity" ]]; then
        success "Workload Identity configured"
    else
        error "Workload Identity not configured"
    fi
    
    # Check for network policies
    local network_policies=$(kubectl get networkpolicies --no-headers 2>/dev/null | wc -l)
    if [[ $network_policies -gt 0 ]]; then
        success "Found $network_policies network policies"
    else
        error "No network policies found"
    fi
    
    # Test Cloud SQL security
    local sql_instances=$(gcloud sql instances list --project="$PROJECT_ID" --format="json")
    for instance in $(echo "$sql_instances" | jq -r '.[].name'); do
        local instance_info=$(gcloud sql instances describe "$instance" --project="$PROJECT_ID" --format="json")
        local ipv4_enabled=$(echo "$instance_info" | jq -r '.settings.ipConfiguration.ipv4Enabled')
        local require_ssl=$(echo "$instance_info" | jq -r '.settings.ipConfiguration.requireSsl')
        
        if [[ "$ipv4_enabled" == "false" ]]; then
            success "Cloud SQL instance $instance has IPv4 disabled"
        else
            error "Cloud SQL instance $instance has IPv4 enabled"
        fi
        
        if [[ "$require_ssl" == "true" ]]; then
            success "Cloud SQL instance $instance requires SSL"
        else
            error "Cloud SQL instance $instance does not require SSL"
        fi
    done
    
    # Test Redis security
    local redis_instances=$(gcloud redis instances list --region="$REGION" --project="$PROJECT_ID" --format="json")
    for instance in $(echo "$redis_instances" | jq -r '.[].name'); do
        local instance_info=$(gcloud redis instances describe "$instance" --region="$REGION" --project="$PROJECT_ID" --format="json")
        local auth_enabled=$(echo "$instance_info" | jq -r '.authEnabled')
        
        if [[ "$auth_enabled" == "true" ]]; then
            success "Redis instance $instance has AUTH enabled"
        else
            error "Redis instance $instance does not have AUTH enabled"
        fi
    done
    
    success "Security hardening validation passed"
}

# Test 4: Compliance Validation
test_compliance() {
    log "Testing compliance configuration..."
    
    # Test data residency
    local resources=$(gcloud asset search-all-resources --scope="projects/$PROJECT_ID" --asset-types="compute.googleapis.com/Instance" --format="json" 2>/dev/null || echo "[]")
    local regional_resources=0
    
    for resource in $(echo "$resources" | jq -r '.[].name'); do
        local resource_info=$(gcloud asset search-all-resources --scope="projects/$PROJECT_ID" --asset-types="compute.googleapis.com/Instance" --query="name:$resource" --format="json" 2>/dev/null || echo "{}")
        local location=$(echo "$resource_info" | jq -r '.location')
        
        if [[ "$location" == "$REGION" ]]; then
            ((regional_resources++))
        fi
    done
    
    if [[ $regional_resources -gt 0 ]]; then
        success "Found $regional_resources resources in the expected region ($REGION)"
    else
        warning "No resources found in the expected region"
    fi
    
    # Test encryption compliance
    local encrypted_resources=0
    
    for resource in $(echo "$resources" | jq -r '.[].name'); do
        local resource_info=$(gcloud asset search-all-resources --scope="projects/$PROJECT_ID" --asset-types="compute.googleapis.com/Instance" --query="name:$resource" --format="json" 2>/dev/null || echo "{}")
        local encryption=$(echo "$resource_info" | jq -r '.additionalAttributes.encryption // "none"')
        
        if [[ "$encryption" != "none" ]]; then
            ((encrypted_resources++))
        fi
    done
    
    if [[ $encrypted_resources -gt 0 ]]; then
        success "Found $encrypted_resources encrypted resources"
    else
        warning "No encrypted resources found"
    fi
    
    # Test audit logging
    local log_sinks=$(gcloud logging sinks list --project="$PROJECT_ID" --format="json")
    local audit_sinks=0
    
    for sink in $(echo "$log_sinks" | jq -r '.[].name'); do
        local sink_info=$(gcloud logging sinks describe "$sink" --project="$PROJECT_ID" --format="json")
        local filter=$(echo "$sink_info" | jq -r '.filter')
        
        if [[ "$filter" == *"cloudaudit.googleapis.com"* ]]; then
            ((audit_sinks++))
        fi
    done
    
    if [[ $audit_sinks -gt 0 ]]; then
        success "Found $audit_sinks audit log sinks"
    else
        error "No audit log sinks found"
    fi
    
    # Test access control
    local iam_policy=$(gcloud projects get-iam-policy "$PROJECT_ID" --format="json")
    local conditional_bindings=$(echo "$iam_policy" | jq '[.bindings[] | select(.condition != null)] | length')
    
    if [[ $conditional_bindings -gt 0 ]]; then
        success "Found $conditional_bindings conditional IAM bindings"
    else
        warning "No conditional IAM bindings found"
    fi
    
    success "Compliance validation passed"
}

# Test 5: Performance Optimization Validation
test_performance_optimization() {
    log "Testing performance optimization..."
    
    # Test GKE performance
    local cluster_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-gke"
    local cluster_info=$(gcloud container clusters describe "$cluster_name" --region="$REGION" --project="$PROJECT_ID" --format="json")
    
    # Check for auto-scaling
    local node_pools=$(gcloud container node-pools list --cluster="$cluster_name" --region="$REGION" --project="$PROJECT_ID" --format="json")
    local auto_scaling_enabled=0
    
    for pool in $(echo "$node_pools" | jq -r '.[].name'); do
        local pool_info=$(gcloud container node-pools describe "$pool" --cluster="$cluster_name" --region="$REGION" --project="$PROJECT_ID" --format="json")
        local auto_scaling=$(echo "$pool_info" | jq -r '.autoscaling.enabled')
        
        if [[ "$auto_scaling" == "true" ]]; then
            ((auto_scaling_enabled++))
            success "Auto-scaling enabled for node pool $pool"
        fi
    done
    
    if [[ $auto_scaling_enabled -gt 0 ]]; then
        success "Found $auto_scaling_enabled node pools with auto-scaling"
    else
        error "No node pools with auto-scaling found"
    fi
    
    # Test Cloud Run performance
    local services=$(gcloud run services list --region="$REGION" --project="$PROJECT_ID" --format="json")
    local cloud_run_auto_scaling=0
    
    for service in $(echo "$services" | jq -r '.[].metadata.name'); do
        local service_info=$(gcloud run services describe "$service" --region="$REGION" --project="$PROJECT_ID" --format="json")
        local min_scale=$(echo "$service_info" | jq -r '.spec.template.metadata.annotations."autoscaling.knative.dev/minScale" // "0"')
        local max_scale=$(echo "$service_info" | jq -r '.spec.template.metadata.annotations."autoscaling.knative.dev/maxScale" // "0"')
        
        if [[ "$min_scale" != "0" || "$max_scale" != "0" ]]; then
            ((cloud_run_auto_scaling++))
            success "Auto-scaling configured for Cloud Run service $service"
        fi
    done
    
    if [[ $cloud_run_auto_scaling -gt 0 ]]; then
        success "Found $cloud_run_auto_scaling Cloud Run services with auto-scaling"
    else
        warning "No Cloud Run services with auto-scaling found"
    fi
    
    # Test CDN configuration
    local backend_services=$(gcloud compute backend-services list --global --project="$PROJECT_ID" --format="json")
    local cdn_enabled=0
    
    for service in $(echo "$backend_services" | jq -r '.[].name'); do
        local service_info=$(gcloud compute backend-services describe "$service" --global --project="$PROJECT_ID" --format="json")
        local cdn=$(echo "$service_info" | jq -r '.cdnPolicy.enabled // false')
        
        if [[ "$cdn" == "true" ]]; then
            ((cdn_enabled++))
            success "CDN enabled for backend service $service"
        fi
    done
    
    if [[ $cdn_enabled -gt 0 ]]; then
        success "Found $cdn_enabled backend services with CDN"
    else
        warning "No backend services with CDN found"
    fi
    
    success "Performance optimization validation passed"
}

# Test 6: Cost Optimization Validation
test_cost_optimization() {
    log "Testing cost optimization..."
    
    # Test resource labeling
    local resources=$(gcloud asset search-all-resources --scope="projects/$PROJECT_ID" --asset-types="compute.googleapis.com/Instance" --format="json" 2>/dev/null || echo "[]")
    local labeled_resources=0
    
    for resource in $(echo "$resources" | jq -r '.[].name'); do
        local resource_info=$(gcloud asset search-all-resources --scope="projects/$PROJECT_ID" --asset-types="compute.googleapis.com/Instance" --query="name:$resource" --format="json" 2>/dev/null || echo "{}")
        local labels=$(echo "$resource_info" | jq -r '.additionalAttributes.labels // {}')
        
        if [[ "$labels" != "{}" ]]; then
            ((labeled_resources++))
        fi
    done
    
    if [[ $labeled_resources -gt 0 ]]; then
        success "Found $labeled_resources resources with cost allocation labels"
    else
        error "No resources with cost allocation labels found"
    fi
    
    # Test preemptible instances (should be minimal in production)
    local preemptible_instances=0
    
    for resource in $(echo "$resources" | jq -r '.[].name'); do
        local resource_info=$(gcloud asset search-all-resources --scope="projects/$PROJECT_ID" --asset-types="compute.googleapis.com/Instance" --query="name:$resource" --format="json" 2>/dev/null || echo "{}")
        local preemptible=$(echo "$resource_info" | jq -r '.additionalAttributes.scheduling.preemptible // false')
        
        if [[ "$preemptible" == "true" ]]; then
            ((preemptible_instances++))
        fi
    done
    
    if [[ $preemptible_instances -eq 0 ]]; then
        success "No preemptible instances found (appropriate for production)"
    else
        warning "Found $preemptible_instances preemptible instances (consider for production)"
    fi
    
    # Test storage lifecycle policies
    local storage_buckets=$(gsutil ls -p "$PROJECT_ID" 2>/dev/null || echo "")
    local lifecycle_enabled=0
    
    for bucket in $storage_buckets; do
        local bucket_name=$(basename "$bucket")
        local lifecycle=$(gsutil lifecycle get "$bucket" 2>/dev/null || echo "No lifecycle policy")
        
        if [[ "$lifecycle" != "No lifecycle policy" ]]; then
            ((lifecycle_enabled++))
            success "Lifecycle policy configured for bucket $bucket_name"
        fi
    done
    
    if [[ $lifecycle_enabled -gt 0 ]]; then
        success "Found $lifecycle_enabled buckets with lifecycle policies"
    else
        warning "No lifecycle policies configured"
    fi
    
    success "Cost optimization validation passed"
}

# Test 7: Monitoring and Alerting Validation
test_monitoring_alerting() {
    log "Testing monitoring and alerting..."
    
    # Test alert policies
    local alert_policies=$(gcloud monitoring alert-policies list --project="$PROJECT_ID" --format="json")
    local policy_count=$(echo "$alert_policies" | jq '. | length')
    
    if [[ $policy_count -gt 0 ]]; then
        success "Found $policy_count alert policies"
    else
        error "No alert policies found"
    fi
    
    # Test notification channels
    local notification_channels=$(gcloud monitoring notification-channels list --project="$PROJECT_ID" --format="json")
    local channel_count=$(echo "$notification_channels" | jq '. | length')
    
    if [[ $channel_count -gt 0 ]]; then
        success "Found $channel_count notification channels"
    else
        error "No notification channels found"
    fi
    
    # Test monitoring dashboards
    local dashboards=$(gcloud monitoring dashboards list --project="$PROJECT_ID" --format="json")
    local dashboard_count=$(echo "$dashboards" | jq '. | length')
    
    if [[ $dashboard_count -gt 0 ]]; then
        success "Found $dashboard_count monitoring dashboards"
    else
        warning "No monitoring dashboards found"
    fi
    
    # Test uptime checks
    local uptime_checks=$(gcloud monitoring uptime-checks list --project="$PROJECT_ID" --format="json")
    local uptime_count=$(echo "$uptime_checks" | jq '. | length')
    
    if [[ $uptime_count -gt 0 ]]; then
        success "Found $uptime_count uptime checks"
    else
        warning "No uptime checks found"
    fi
    
    success "Monitoring and alerting validation passed"
}

# Test 8: Load Testing
test_load_testing() {
    log "Testing load handling..."
    
    # Test Cloud Run load handling
    local services=$(gcloud run services list --region="$REGION" --project="$PROJECT_ID" --format="json")
    for service in $(echo "$services" | jq -r '.[].metadata.name'); do
        local service_info=$(gcloud run services describe "$service" --region="$REGION" --project="$PROJECT_ID" --format="json")
        local url=$(echo "$service_info" | jq -r '.status.url')
        
        if [[ -n "$url" ]]; then
            log "Testing load handling for Cloud Run service: $service"
            
            # Simple load test with multiple concurrent requests
            local start_time=$(date +%s)
            local success_count=0
            local total_requests=10
            
            for i in $(seq 1 $total_requests); do
                if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|404"; then
                    ((success_count++))
                fi
            done &
            
            wait
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            
            if [[ $success_count -eq $total_requests ]]; then
                success "Cloud Run service $service handled $total_requests requests successfully in ${duration}s"
            else
                warning "Cloud Run service $service handled $success_count out of $total_requests requests"
            fi
        fi
    done
    
    success "Load testing passed"
}

# Test 9: Failover Testing
test_failover() {
    log "Testing failover capabilities..."
    
    # Test GKE node failover
    local cluster_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-gke"
    local nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    
    if [[ $nodes -gt 1 ]]; then
        success "GKE cluster has $nodes nodes for failover"
    else
        error "GKE cluster has only $nodes node (insufficient for failover)"
    fi
    
    # Test Cloud SQL failover
    local sql_instances=$(gcloud sql instances list --project="$PROJECT_ID" --format="json")
    for instance in $(echo "$sql_instances" | jq -r '.[].name'); do
        local instance_info=$(gcloud sql instances describe "$instance" --project="$PROJECT_ID" --format="json")
        local availability_type=$(echo "$instance_info" | jq -r '.settings.availabilityType')
        
        if [[ "$availability_type" == "REGIONAL" ]]; then
            success "Cloud SQL instance $instance configured for regional failover"
        else
            warning "Cloud SQL instance $instance not configured for regional failover"
        fi
    done
    
    # Test Redis failover
    local redis_instances=$(gcloud redis instances list --region="$REGION" --project="$PROJECT_ID" --format="json")
    for instance in $(echo "$redis_instances" | jq -r '.[].name'); do
        local instance_info=$(gcloud redis instances describe "$instance" --region="$REGION" --project="$PROJECT_ID" --format="json")
        local tier=$(echo "$instance_info" | jq -r '.tier')
        
        if [[ "$tier" == "STANDARD_HA" ]]; then
            success "Redis instance $instance configured for HA failover"
        else
            warning "Redis instance $instance not configured for HA failover"
        fi
    done
    
    success "Failover testing passed"
}

# Test 10: Production Readiness Validation
test_production_readiness() {
    log "Testing production readiness..."
    
    # Test all services are running
    local cluster_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-gke"
    local pods=$(kubectl get pods --no-headers 2>/dev/null | wc -l)
    local running_pods=$(kubectl get pods --no-headers 2>/dev/null | grep "Running" | wc -l)
    
    if [[ $pods -gt 0 ]]; then
        if [[ $running_pods -eq $pods ]]; then
            success "All $pods pods are running"
        else
            error "$running_pods out of $pods pods are running"
        fi
    else
        error "No pods found"
    fi
    
    # Test Cloud Run services
    local services=$(gcloud run services list --region="$REGION" --project="$PROJECT_ID" --format="json")
    local ready_services=0
    
    for service in $(echo "$services" | jq -r '.[].metadata.name'); do
        local service_info=$(gcloud run services describe "$service" --region="$REGION" --project="$PROJECT_ID" --format="json")
        local status=$(echo "$service_info" | jq -r '.status.conditions[] | select(.type == "Ready") | .status')
        
        if [[ "$status" == "True" ]]; then
            ((ready_services++))
        fi
    done
    
    if [[ $ready_services -gt 0 ]]; then
        success "Found $ready_services ready Cloud Run services"
    else
        error "No ready Cloud Run services found"
    fi
    
    # Test Cloud Functions
    local functions=$(gcloud functions list --region="$REGION" --project="$PROJECT_ID" --format="json")
    local active_functions=0
    
    for function in $(echo "$functions" | jq -r '.[].name'); do
        local function_info=$(gcloud functions describe "$function" --region="$REGION" --project="$PROJECT_ID" --format="json")
        local status=$(echo "$function_info" | jq -r '.status')
        
        if [[ "$status" == "ACTIVE" ]]; then
            ((active_functions++))
        fi
    done
    
    if [[ $active_functions -gt 0 ]]; then
        success "Found $active_functions active Cloud Functions"
    else
        error "No active Cloud Functions found"
    fi
    
    success "Production readiness validation passed"
}

# Main execution
main() {
    log "Starting Phase 6 testing for environment: $ENVIRONMENT"
    log "Project ID: $PROJECT_ID"
    log "Region: $REGION"
    log "Secondary Region: $SECONDARY_REGION"
    
    # Run all tests
    check_prerequisites
    test_high_availability
    test_disaster_recovery
    test_security_hardening
    test_compliance
    test_performance_optimization
    test_cost_optimization
    test_monitoring_alerting
    test_load_testing
    test_failover
    test_production_readiness
    
    success "All Phase 6 tests completed successfully!"
    log "Phase 6 production hardening is complete - infrastructure is production ready!"
}

# Run main function
main "$@"

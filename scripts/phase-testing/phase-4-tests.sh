#!/bin/bash
# Phase 4: Compute Platform - Testing Script
# This script validates the compute infrastructure including GKE, Cloud Run, Cloud Functions, and applications

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
ZONE="${ZONE:-us-central1-a}"

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
    
    success "Prerequisites check passed"
}

# Test 1: GKE Cluster Validation
test_gke_cluster() {
    log "Testing GKE cluster configuration..."
    
    # Get GKE clusters
    local clusters=$(gcloud container clusters list --project="$PROJECT_ID" --format="json")
    local cluster_count=$(echo "$clusters" | jq '. | length')
    
    if [[ $cluster_count -eq 0 ]]; then
        error "No GKE clusters found"
    fi
    
    # Check for required cluster
    local cluster_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-gke"
    local cluster_info=$(echo "$clusters" | jq -r ".[] | select(.name == \"$cluster_name\")")
    
    if [[ -z "$cluster_info" ]]; then
        error "Required GKE cluster $cluster_name not found"
    fi
    
    # Validate cluster configuration
    local location=$(echo "$cluster_info" | jq -r '.location')
    local node_count=$(echo "$cluster_info" | jq -r '.currentNodeCount')
    local status=$(echo "$cluster_info" | jq -r '.status')
    local version=$(echo "$cluster_info" | jq -r '.currentMasterVersion')
    
    log "Cluster details: Location=$location, Nodes=$node_count, Status=$status, Version=$version"
    
    if [[ "$status" == "RUNNING" ]]; then
        success "GKE cluster is running"
    else
        error "GKE cluster is not running (status: $status)"
    fi
    
    # Check for private cluster configuration
    local private_cluster=$(echo "$cluster_info" | jq -r '.privateClusterConfig.enablePrivateNodes')
    if [[ "$private_cluster" == "true" ]]; then
        success "Private cluster configuration enabled"
    else
        warning "Private cluster configuration not enabled"
    fi
    
    # Check for Workload Identity
    local workload_identity=$(echo "$cluster_info" | jq -r '.workloadIdentityConfig.workloadPool')
    if [[ -n "$workload_identity" ]]; then
        success "Workload Identity enabled: $workload_identity"
    else
        warning "Workload Identity not enabled"
    fi
    
    # Get cluster credentials
    log "Getting cluster credentials..."
    if gcloud container clusters get-credentials "$cluster_name" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
        success "Cluster credentials obtained"
    else
        error "Failed to get cluster credentials"
    fi
    
    # Test kubectl connectivity
    if kubectl cluster-info >/dev/null 2>&1; then
        success "kubectl connectivity verified"
    else
        error "kubectl connectivity failed"
    fi
    
    success "GKE cluster validation passed"
}

# Test 2: GKE Node Pools Validation
test_gke_node_pools() {
    log "Testing GKE node pools..."
    
    local cluster_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-gke"
    
    # Get node pools
    local node_pools=$(gcloud container node-pools list --cluster="$cluster_name" --region="$REGION" --project="$PROJECT_ID" --format="json")
    local pool_count=$(echo "$node_pools" | jq '. | length')
    
    if [[ $pool_count -eq 0 ]]; then
        error "No node pools found"
    fi
    
    # Validate node pool configuration
    for pool in $(echo "$node_pools" | jq -r '.[].name'); do
        local pool_info=$(gcloud container node-pools describe "$pool" --cluster="$cluster_name" --region="$REGION" --project="$PROJECT_ID" --format="json")
        local machine_type=$(echo "$pool_info" | jq -r '.config.machineType')
        local disk_size=$(echo "$pool_info" | jq -r '.config.diskSizeGb')
        local auto_scaling=$(echo "$pool_info" | jq -r '.autoscaling.enabled')
        local min_nodes=$(echo "$pool_info" | jq -r '.autoscaling.minNodeCount // 0')
        local max_nodes=$(echo "$pool_info" | jq -r '.autoscaling.maxNodeCount // 0')
        
        log "Node pool $pool: MachineType=$machine_type, DiskSize=${disk_size}GB, AutoScaling=$auto_scaling, Min=$min_nodes, Max=$max_nodes"
        
        if [[ "$auto_scaling" == "true" ]]; then
            success "Auto-scaling enabled for node pool $pool"
        else
            warning "Auto-scaling not enabled for node pool $pool"
        fi
    done
    
    # Check node status
    local nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    if [[ $nodes -gt 0 ]]; then
        success "Found $nodes nodes in the cluster"
    else
        error "No nodes found in the cluster"
    fi
    
    success "GKE node pools validation passed"
}

# Test 3: Cloud Run Services Validation
test_cloud_run() {
    log "Testing Cloud Run services..."
    
    # Get Cloud Run services
    local services=$(gcloud run services list --region="$REGION" --project="$PROJECT_ID" --format="json")
    local service_count=$(echo "$services" | jq '. | length')
    
    if [[ $service_count -eq 0 ]]; then
        error "No Cloud Run services found"
    fi
    
    # Check for required services
    local required_services=(
        "api-service"
        "web-service"
    )
    
    for service_suffix in "${required_services[@]}"; do
        local service_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-${service_suffix}"
        local service_info=$(echo "$services" | jq -r ".[] | select(.metadata.name == \"$service_name\")")
        
        if [[ -z "$service_info" ]]; then
            error "Required Cloud Run service $service_name not found"
        fi
        
        # Validate service configuration
        local status=$(echo "$service_info" | jq -r '.status.conditions[] | select(.type == "Ready") | .status')
        local url=$(echo "$service_info" | jq -r '.status.url')
        local min_scale=$(echo "$service_info" | jq -r '.spec.template.metadata.annotations."autoscaling.knative.dev/minScale" // "0"')
        local max_scale=$(echo "$service_info" | jq -r '.spec.template.metadata.annotations."autoscaling.knative.dev/maxScale" // "0"')
        
        log "Service $service_name: Status=$status, URL=$url, MinScale=$min_scale, MaxScale=$max_scale"
        
        if [[ "$status" == "True" ]]; then
            success "Cloud Run service $service_name is ready"
        else
            error "Cloud Run service $service_name is not ready"
        fi
        
        # Test service endpoint
        if [[ -n "$url" ]]; then
            log "Testing service endpoint: $url"
            if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|404"; then
                success "Service endpoint responding"
            else
                warning "Service endpoint not responding correctly"
            fi
        fi
    done
    
    success "Cloud Run services validation passed"
}

# Test 4: Cloud Functions Validation
test_cloud_functions() {
    log "Testing Cloud Functions..."
    
    # Get Cloud Functions
    local functions=$(gcloud functions list --region="$REGION" --project="$PROJECT_ID" --format="json")
    local function_count=$(echo "$functions" | jq '. | length')
    
    if [[ $function_count -eq 0 ]]; then
        error "No Cloud Functions found"
    fi
    
    # Check for required functions
    local required_functions=(
        "process-upload"
        "webhook-handler"
    )
    
    for function_suffix in "${required_functions[@]}"; do
        local function_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-${function_suffix}"
        local function_info=$(echo "$functions" | jq -r ".[] | select(.name | contains(\"$function_name\"))")
        
        if [[ -z "$function_info" ]]; then
            error "Required Cloud Function $function_name not found"
        fi
        
        # Validate function configuration
        local status=$(echo "$function_info" | jq -r '.status')
        local runtime=$(echo "$function_info" | jq -r '.runtime')
        local trigger_type=$(echo "$function_info" | jq -r '.eventTrigger.eventType // .httpsTrigger.url // "unknown"')
        
        log "Function $function_name: Status=$status, Runtime=$runtime, Trigger=$trigger_type"
        
        if [[ "$status" == "ACTIVE" ]]; then
            success "Cloud Function $function_name is active"
        else
            error "Cloud Function $function_name is not active (status: $status)"
        fi
        
        # Test HTTP trigger if available
        local https_trigger=$(echo "$function_info" | jq -r '.httpsTrigger.url // empty')
        if [[ -n "$https_trigger" ]]; then
            log "Testing HTTP trigger: $https_trigger"
            if curl -s -o /dev/null -w "%{http_code}" "$https_trigger" | grep -q "200\|404\|405"; then
                success "HTTP trigger responding"
            else
                warning "HTTP trigger not responding correctly"
            fi
        fi
    done
    
    success "Cloud Functions validation passed"
}

# Test 5: VPC Connector Validation
test_vpc_connector() {
    log "Testing VPC connector..."
    
    # Get VPC connectors
    local connectors=$(gcloud compute networks vpc-access connectors list --region="$REGION" --project="$PROJECT_ID" --format="json")
    local connector_count=$(echo "$connectors" | jq '. | length')
    
    if [[ $connector_count -eq 0 ]]; then
        warning "No VPC connectors found"
    else
        # Validate connector configuration
        for connector in $(echo "$connectors" | jq -r '.[].name'); do
            local connector_info=$(gcloud compute networks vpc-access connectors describe "$connector" --region="$REGION" --project="$PROJECT_ID" --format="json")
            local network=$(echo "$connector_info" | jq -r '.network')
            local ip_cidr=$(echo "$connector_info" | jq -r '.ipCidrRange')
            local min_instances=$(echo "$connector_info" | jq -r '.minInstances')
            local max_instances=$(echo "$connector_info" | jq -r '.maxInstances')
            
            log "VPC Connector $connector: Network=$network, CIDR=$ip_cidr, MinInstances=$min_instances, MaxInstances=$max_instances"
            
            success "VPC connector $connector configured"
        done
    fi
    
    success "VPC connector validation passed"
}

# Test 6: Application Deployment Tests
test_application_deployment() {
    log "Testing application deployment..."
    
    # Check for deployed applications in GKE
    local deployments=$(kubectl get deployments --no-headers 2>/dev/null | wc -l)
    local services=$(kubectl get services --no-headers 2>/dev/null | wc -l)
    local pods=$(kubectl get pods --no-headers 2>/dev/null | wc -l)
    
    log "GKE resources: Deployments=$deployments, Services=$services, Pods=$pods"
    
    if [[ $deployments -gt 0 ]]; then
        success "Found $deployments deployments in GKE"
    else
        warning "No deployments found in GKE"
    fi
    
    if [[ $services -gt 0 ]]; then
        success "Found $services services in GKE"
    else
        warning "No services found in GKE"
    fi
    
    if [[ $pods -gt 0 ]]; then
        success "Found $pods pods in GKE"
        
        # Check pod status
        local running_pods=$(kubectl get pods --no-headers 2>/dev/null | grep "Running" | wc -l)
        local total_pods=$(kubectl get pods --no-headers 2>/dev/null | wc -l)
        
        if [[ $running_pods -eq $total_pods ]]; then
            success "All pods are running"
        else
            warning "$running_pods out of $total_pods pods are running"
        fi
    else
        error "No pods found in GKE"
    fi
    
    success "Application deployment tests passed"
}

# Test 7: Load Balancer Integration Tests
test_load_balancer_integration() {
    log "Testing load balancer integration..."
    
    # Check for ingress resources
    local ingress_count=$(kubectl get ingress --no-headers 2>/dev/null | wc -l)
    
    if [[ $ingress_count -gt 0 ]]; then
        success "Found $ingress_count ingress resources"
        
        # Check ingress status
        for ingress in $(kubectl get ingress --no-headers 2>/dev/null | awk '{print $1}'); do
            local ingress_info=$(kubectl get ingress "$ingress" -o json 2>/dev/null || echo "{}")
            local load_balancer_ip=$(echo "$ingress_info" | jq -r '.status.loadBalancer.ingress[0].ip // "pending"')
            
            if [[ "$load_balancer_ip" != "pending" && "$load_balancer_ip" != "null" ]]; then
                success "Ingress $ingress has load balancer IP: $load_balancer_ip"
            else
                warning "Ingress $ingress load balancer IP is pending"
            fi
        done
    else
        warning "No ingress resources found"
    fi
    
    # Check for backend services
    local backend_services=$(gcloud compute backend-services list --global --project="$PROJECT_ID" --format="json")
    local backend_count=$(echo "$backend_services" | jq '. | length')
    
    if [[ $backend_count -gt 0 ]]; then
        success "Found $backend_count backend services"
    else
        warning "No backend services found"
    fi
    
    success "Load balancer integration tests passed"
}

# Test 8: Auto-scaling Tests
test_auto_scaling() {
    log "Testing auto-scaling..."
    
    # Test GKE auto-scaling
    local cluster_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-gke"
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
        warning "No node pools with auto-scaling found"
    fi
    
    # Test Cloud Run auto-scaling
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
    
    success "Auto-scaling tests passed"
}

# Test 9: Performance Tests
test_performance() {
    log "Testing compute platform performance..."
    
    # Test GKE cluster performance
    local cluster_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-gke"
    local cluster_info=$(gcloud container clusters describe "$cluster_name" --region="$REGION" --project="$PROJECT_ID" --format="json")
    local node_count=$(echo "$cluster_info" | jq -r '.currentNodeCount')
    
    if [[ $node_count -gt 0 ]]; then
        success "GKE cluster has $node_count nodes"
    else
        error "GKE cluster has no nodes"
    fi
    
    # Test Cloud Run performance
    local services=$(gcloud run services list --region="$REGION" --project="$PROJECT_ID" --format="json")
    for service in $(echo "$services" | jq -r '.[].metadata.name'); do
        local service_info=$(gcloud run services describe "$service" --region="$REGION" --project="$PROJECT_ID" --format="json")
        local url=$(echo "$service_info" | jq -r '.status.url')
        
        if [[ -n "$url" ]]; then
            log "Testing Cloud Run service performance: $service"
            local start_time=$(date +%s)
            
            if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|404"; then
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                
                if [[ $duration -lt 5 ]]; then
                    success "Cloud Run service $service responded in ${duration}s"
                else
                    warning "Cloud Run service $service took ${duration}s to respond"
                fi
            else
                warning "Cloud Run service $service not responding"
            fi
        fi
    done
    
    success "Performance tests passed"
}

# Test 10: Security Tests
test_security() {
    log "Testing compute platform security..."
    
    # Test GKE security
    local cluster_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-gke"
    local cluster_info=$(gcloud container clusters describe "$cluster_name" --region="$REGION" --project="$PROJECT_ID" --format="json")
    
    # Check for private cluster
    local private_cluster=$(echo "$cluster_info" | jq -r '.privateClusterConfig.enablePrivateNodes')
    if [[ "$private_cluster" == "true" ]]; then
        success "GKE cluster is private"
    else
        warning "GKE cluster is not private"
    fi
    
    # Check for Workload Identity
    local workload_identity=$(echo "$cluster_info" | jq -r '.workloadIdentityConfig.workloadPool')
    if [[ -n "$workload_identity" ]]; then
        success "Workload Identity configured"
    else
        warning "Workload Identity not configured"
    fi
    
    # Check for network policies
    local network_policies=$(kubectl get networkpolicies --no-headers 2>/dev/null | wc -l)
    if [[ $network_policies -gt 0 ]]; then
        success "Found $network_policies network policies"
    else
        warning "No network policies found"
    fi
    
    # Test Cloud Run security
    local services=$(gcloud run services list --region="$REGION" --project="$PROJECT_ID" --format="json")
    for service in $(echo "$services" | jq -r '.[].metadata.name'); do
        local service_info=$(gcloud run services describe "$service" --region="$REGION" --project="$PROJECT_ID" --format="json")
        local allow_unauthenticated=$(echo "$service_info" | jq -r '.spec.template.metadata.annotations."run.googleapis.com/ingress" // "all"')
        
        if [[ "$allow_unauthenticated" == "all" ]]; then
            warning "Cloud Run service $service allows unauthenticated access"
        else
            success "Cloud Run service $service has restricted access"
        fi
    done
    
    success "Security tests passed"
}

# Main execution
main() {
    log "Starting Phase 4 testing for environment: $ENVIRONMENT"
    log "Project ID: $PROJECT_ID"
    log "Region: $REGION"
    
    # Run all tests
    check_prerequisites
    test_gke_cluster
    test_gke_node_pools
    test_cloud_run
    test_cloud_functions
    test_vpc_connector
    test_application_deployment
    test_load_balancer_integration
    test_auto_scaling
    test_performance
    test_security
    
    success "All Phase 4 tests completed successfully!"
    log "Phase 4 compute platform is ready for Phase 5 monitoring implementation"
}

# Run main function
main "$@"

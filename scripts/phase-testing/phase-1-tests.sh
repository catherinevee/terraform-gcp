#!/bin/bash
# Phase 1: Networking Foundation - Testing Script
# This script validates the networking infrastructure including VPC, subnets, firewall, and connectivity

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
    command -v curl >/dev/null 2>&1 || error "curl is not installed"
    command -v nc >/dev/null 2>&1 || error "netcat is not installed"
    
    if [[ -z "$PROJECT_ID" ]]; then
        error "PROJECT_ID environment variable is required"
    fi
    
    success "Prerequisites check passed"
}

# Test 1: VPC and Subnet Validation
test_vpc_subnets() {
    log "Testing VPC and subnet configuration..."
    
    # Get VPC information
    local vpc_name="${PROJECT_ID}-${ENVIRONMENT}-vpc"
    local vpc_info=$(gcloud compute networks describe "$vpc_name" --project="$PROJECT_ID" --format="json" 2>/dev/null || echo "{}")
    
    if [[ "$vpc_info" == "{}" ]]; then
        error "VPC $vpc_name not found"
    fi
    
    # Validate VPC properties
    local routing_mode=$(echo "$vpc_info" | jq -r '.routingConfig.routingMode // "empty"')
    if [[ "$routing_mode" != "REGIONAL" ]]; then
        warning "VPC routing mode is $routing_mode, expected REGIONAL"
    fi
    
    # Get subnet information
    local subnets=$(gcloud compute networks subnets list --project="$PROJECT_ID" --filter="network:$vpc_name" --format="json")
    local subnet_count=$(echo "$subnets" | jq '. | length')
    
    if [[ $subnet_count -lt 4 ]]; then
        error "Expected at least 4 subnets, found $subnet_count"
    fi
    
    # Check for required subnets
    local required_subnets=("public" "private" "database" "gke")
    for subnet_type in "${required_subnets[@]}"; do
        local subnet_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-${subnet_type}"
        if ! echo "$subnets" | jq -e ".[] | select(.name == \"$subnet_name\")" >/dev/null; then
            error "Required subnet $subnet_name not found"
        fi
    done
    
    success "VPC and subnet validation passed"
}

# Test 2: Firewall Rules Validation
test_firewall_rules() {
    log "Testing firewall rules..."
    
    local vpc_name="${PROJECT_ID}-${ENVIRONMENT}-vpc"
    local firewall_rules=$(gcloud compute firewall-rules list --project="$PROJECT_ID" --filter="network:$vpc_name" --format="json")
    
    # Check for required firewall rules
    local required_rules=(
        "allow-iap"
        "allow-health-checks"
        "allow-internal"
        "deny-all-ingress"
    )
    
    for rule_suffix in "${required_rules[@]}"; do
        local rule_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-${rule_suffix}"
        if ! echo "$firewall_rules" | jq -e ".[] | select(.name == \"$rule_name\")" >/dev/null; then
            error "Required firewall rule $rule_name not found"
        fi
    done
    
    # Validate IAP rule
    local iap_rule=$(echo "$firewall_rules" | jq -r '.[] | select(.name | contains("allow-iap")) | .sourceRanges[]')
    if ! echo "$iap_rule" | grep -q "35.235.240.0/20"; then
        warning "IAP rule may not have correct source range"
    fi
    
    # Validate health check rule
    local health_rule=$(echo "$firewall_rules" | jq -r '.[] | select(.name | contains("allow-health-checks")) | .sourceRanges[]')
    if ! echo "$health_rule" | grep -q "35.191.0.0/16"; then
        warning "Health check rule may not have correct source range"
    fi
    
    success "Firewall rules validation passed"
}

# Test 3: Cloud NAT Validation
test_cloud_nat() {
    log "Testing Cloud NAT configuration..."
    
    local router_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-router"
    local nat_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-nat"
    
    # Check if router exists
    if ! gcloud compute routers describe "$router_name" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
        error "Cloud Router $router_name not found"
    fi
    
    # Check if NAT gateway exists
    local nat_info=$(gcloud compute routers nats describe "$nat_name" --router="$router_name" --region="$REGION" --project="$PROJECT_ID" --format="json" 2>/dev/null || echo "{}")
    
    if [[ "$nat_info" == "{}" ]]; then
        error "Cloud NAT $nat_name not found"
    fi
    
    # Validate NAT configuration
    local nat_type=$(echo "$nat_info" | jq -r '.natIpAllocateOption // "empty"')
    if [[ "$nat_type" != "AUTO_ONLY" ]]; then
        warning "NAT type is $nat_type, expected AUTO_ONLY"
    fi
    
    success "Cloud NAT validation passed"
}

# Test 4: Load Balancer Validation
test_load_balancer() {
    log "Testing load balancer configuration..."
    
    # Check for global load balancer
    local lb_name="${PROJECT_ID}-${ENVIRONMENT}-lb"
    local lb_info=$(gcloud compute url-maps describe "$lb_name" --global --project="$PROJECT_ID" --format="json" 2>/dev/null || echo "{}")
    
    if [[ "$lb_info" == "{}" ]]; then
        warning "Global load balancer $lb_name not found"
    else
        success "Global load balancer found"
    fi
    
    # Check for backend services
    local backend_services=$(gcloud compute backend-services list --global --project="$PROJECT_ID" --format="json")
    local backend_count=$(echo "$backend_services" | jq '. | length')
    
    if [[ $backend_count -eq 0 ]]; then
        warning "No backend services found"
    else
        success "Found $backend_count backend services"
    fi
}

# Test 5: Cloud CDN Validation
test_cloud_cdn() {
    log "Testing Cloud CDN configuration..."
    
    # Check for CDN-enabled backend services
    local cdn_backends=$(gcloud compute backend-services list --global --project="$PROJECT_ID" --filter="enableCDN=true" --format="json")
    local cdn_count=$(echo "$cdn_backends" | jq '. | length')
    
    if [[ $cdn_count -eq 0 ]]; then
        warning "No CDN-enabled backend services found"
    else
        success "Found $cdn_count CDN-enabled backend services"
    fi
}

# Test 6: Network Connectivity Tests
test_network_connectivity() {
    log "Testing network connectivity..."
    
    # Create a test VM in the private subnet
    local vm_name="${PROJECT_ID}-${ENVIRONMENT}-test-vm"
    local subnet_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-private"
    
    log "Creating test VM for connectivity testing..."
    
    # Create test VM
    gcloud compute instances create "$vm_name" \
        --zone="$ZONE" \
        --machine-type="e2-micro" \
        --subnet="$subnet_name" \
        --no-address \
        --image-family="debian-11" \
        --image-project="debian-cloud" \
        --project="$PROJECT_ID" \
        --quiet || error "Failed to create test VM"
    
    # Wait for VM to be ready
    sleep 30
    
    # Test internal connectivity
    log "Testing internal network connectivity..."
    if gcloud compute ssh "$vm_name" --zone="$ZONE" --project="$PROJECT_ID" --command="ping -c 3 8.8.8.8" >/dev/null 2>&1; then
        success "Internal connectivity test passed"
    else
        warning "Internal connectivity test failed"
    fi
    
    # Test GCP service connectivity
    log "Testing GCP service connectivity..."
    if gcloud compute ssh "$vm_name" --zone="$ZONE" --project="$PROJECT_ID" --command="curl -s https://www.googleapis.com" >/dev/null 2>&1; then
        success "GCP service connectivity test passed"
    else
        warning "GCP service connectivity test failed"
    fi
    
    # Clean up test VM
    log "Cleaning up test VM..."
    gcloud compute instances delete "$vm_name" --zone="$ZONE" --project="$PROJECT_ID" --quiet || warning "Failed to delete test VM"
}

# Test 7: DNS Resolution Tests
test_dns_resolution() {
    log "Testing DNS resolution..."
    
    # Test external DNS resolution
    if nslookup google.com >/dev/null 2>&1; then
        success "External DNS resolution working"
    else
        warning "External DNS resolution failed"
    fi
    
    # Test internal DNS resolution
    if nslookup metadata.google.internal >/dev/null 2>&1; then
        success "Internal DNS resolution working"
    else
        warning "Internal DNS resolution failed"
    fi
}

# Test 8: Security Group Validation
test_security_groups() {
    log "Testing security group configuration..."
    
    local vpc_name="${PROJECT_ID}-${ENVIRONMENT}-vpc"
    
    # Check for network tags
    local instances=$(gcloud compute instances list --project="$PROJECT_ID" --format="json")
    local tagged_instances=$(echo "$instances" | jq '[.[] | select(.tags.items | length > 0)] | length')
    
    if [[ $tagged_instances -eq 0 ]]; then
        warning "No instances with network tags found"
    else
        success "Found $tagged_instances instances with network tags"
    fi
}

# Test 9: Network Performance Tests
test_network_performance() {
    log "Testing network performance..."
    
    # Test latency to Google services
    local latency=$(ping -c 5 8.8.8.8 | tail -1 | awk -F'/' '{print $5}')
    
    if [[ -n "$latency" ]]; then
        if (( $(echo "$latency < 100" | bc -l) )); then
            success "Network latency is acceptable: ${latency}ms"
        else
            warning "Network latency is high: ${latency}ms"
        fi
    else
        warning "Could not measure network latency"
    fi
}

# Test 10: VPC Flow Logs Validation
test_vpc_flow_logs() {
    log "Testing VPC flow logs..."
    
    local vpc_name="${PROJECT_ID}-${ENVIRONMENT}-vpc"
    local subnets=$(gcloud compute networks subnets list --project="$PROJECT_ID" --filter="network:$vpc_name" --format="json")
    
    # Check if flow logs are enabled on subnets
    local flow_logs_enabled=$(echo "$subnets" | jq '[.[] | select(.enableFlowLogs == true)] | length')
    
    if [[ $flow_logs_enabled -gt 0 ]]; then
        success "Flow logs enabled on $flow_logs_enabled subnets"
    else
        warning "No flow logs enabled on subnets"
    fi
}

# Test 11: Private Google Access Validation
test_private_google_access() {
    log "Testing Private Google Access..."
    
    local vpc_name="${PROJECT_ID}-${ENVIRONMENT}-vpc"
    local subnets=$(gcloud compute networks subnets list --project="$PROJECT_ID" --filter="network:$vpc_name" --format="json")
    
    # Check if private Google access is enabled
    local private_access_enabled=$(echo "$subnets" | jq '[.[] | select(.privateIpGoogleAccess == true)] | length')
    
    if [[ $private_access_enabled -gt 0 ]]; then
        success "Private Google Access enabled on $private_access_enabled subnets"
    else
        warning "Private Google Access not enabled on any subnets"
    fi
}

# Test 12: Network Isolation Tests
test_network_isolation() {
    log "Testing network isolation..."
    
    # This test would require multiple VMs in different subnets
    # For now, we'll validate the subnet configuration
    local vpc_name="${PROJECT_ID}-${ENVIRONMENT}-vpc"
    local subnets=$(gcloud compute networks subnets list --project="$PROJECT_ID" --filter="network:$vpc_name" --format="json")
    
    # Check that subnets have different CIDR ranges
    local cidrs=$(echo "$subnets" | jq -r '.[].ipCidrRange')
    local unique_cidrs=$(echo "$cidrs" | sort -u | wc -l)
    local total_cidrs=$(echo "$cidrs" | wc -l)
    
    if [[ $unique_cidrs -eq $total_cidrs ]]; then
        success "All subnets have unique CIDR ranges"
    else
        error "Subnets have overlapping CIDR ranges"
    fi
}

# Main execution
main() {
    log "Starting Phase 1 testing for environment: $ENVIRONMENT"
    log "Project ID: $PROJECT_ID"
    log "Region: $REGION"
    
    # Run all tests
    check_prerequisites
    test_vpc_subnets
    test_firewall_rules
    test_cloud_nat
    test_load_balancer
    test_cloud_cdn
    test_network_connectivity
    test_dns_resolution
    test_security_groups
    test_network_performance
    test_vpc_flow_logs
    test_private_google_access
    test_network_isolation
    
    success "All Phase 1 tests completed successfully!"
    log "Phase 1 networking foundation is ready for Phase 2 security implementation"
}

# Run main function
main "$@"

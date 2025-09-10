#!/bin/bash
# Infrastructure Health Check Script
# This script performs comprehensive health checks across all infrastructure components

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
OUTPUT_FORMAT="${OUTPUT_FORMAT:-console}" # console, json, html
REPORT_FILE="${REPORT_FILE:-health-check-report-$(date +%Y%m%d-%H%M%S)}"

# Health check results
declare -A HEALTH_RESULTS
declare -A HEALTH_METRICS

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
}

info() {
    echo -e "${PURPLE}[INFO]${NC} $1"
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Perform comprehensive health checks on the terraform-gcp infrastructure.

OPTIONS:
    -p, --project-id PROJECT_ID    GCP Project ID (required)
    -e, --environment ENVIRONMENT  Environment (dev/staging/prod) [default: dev]
    -r, --region REGION           Primary GCP region [default: us-central1]
    -f, --format FORMAT           Output format (console/json/html) [default: console]
    -o, --output FILE             Output file name [default: auto-generated]
    -h, --help                    Show this help message

EXAMPLES:
    $0 -p my-project -e dev
    $0 -p my-project -e staging -f json -o health-report.json
    $0 -p my-project -e prod -f html -o health-report.html

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
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -o|--output)
                REPORT_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
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
    
    # Check required tools
    command -v terraform >/dev/null 2>&1 || error "Terraform is not installed"
    command -v gcloud >/dev/null 2>&1 || error "gcloud CLI is not installed"
    command -v jq >/dev/null 2>&1 || error "jq is not installed"
    command -v kubectl >/dev/null 2>&1 || error "kubectl is not installed"
    command -v curl >/dev/null 2>&1 || error "curl is not installed"
    
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

# Record health check result
record_result() {
    local component="$1"
    local status="$2"
    local message="$3"
    local metric_value="${4:-0}"
    
    HEALTH_RESULTS["$component"]="$status"
    HEALTH_METRICS["$component"]="$metric_value"
    
    case $status in
        "healthy")
            success "$component: $message"
            ;;
        "warning")
            warning "$component: $message"
            ;;
        "error")
            error "$component: $message"
            ;;
        *)
            info "$component: $message"
            ;;
    esac
}

# Check GCP project health
check_project_health() {
    log "Checking GCP project health..."
    
    # Check project status
    local project_info=$(gcloud projects describe "$PROJECT_ID" --format="json")
    local project_state=$(echo "$project_info" | jq -r '.lifecycleState')
    
    if [[ "$project_state" == "ACTIVE" ]]; then
        record_result "project" "healthy" "Project is active"
    else
        record_result "project" "error" "Project is not active (state: $project_state)"
    fi
    
    # Check billing
    local billing_info=$(gcloud billing projects describe "$PROJECT_ID" --format="json" 2>/dev/null || echo "{}")
    if [[ "$billing_info" != "{}" ]]; then
        local billing_enabled=$(echo "$billing_info" | jq -r '.billingEnabled')
        if [[ "$billing_enabled" == "true" ]]; then
            record_result "billing" "healthy" "Billing is enabled"
        else
            record_result "billing" "error" "Billing is not enabled"
        fi
    else
        record_result "billing" "warning" "Cannot check billing status"
    fi
}

# Check networking health
check_networking_health() {
    log "Checking networking health..."
    
    # Check VPC
    local vpc_name="${PROJECT_ID}-${ENVIRONMENT}-vpc"
    local vpc_info=$(gcloud compute networks describe "$vpc_name" --project="$PROJECT_ID" --format="json" 2>/dev/null || echo "{}")
    
    if [[ "$vpc_info" != "{}" ]]; then
        record_result "vpc" "healthy" "VPC is configured"
    else
        record_result "vpc" "error" "VPC not found"
    fi
    
    # Check subnets
    local subnets=$(gcloud compute networks subnets list --project="$PROJECT_ID" --filter="network:$vpc_name" --format="json")
    local subnet_count=$(echo "$subnets" | jq '. | length')
    
    if [[ $subnet_count -ge 4 ]]; then
        record_result "subnets" "healthy" "Found $subnet_count subnets"
    else
        record_result "subnets" "warning" "Found only $subnet_count subnets (expected 4+)"
    fi
    
    # Check firewall rules
    local firewall_rules=$(gcloud compute firewall-rules list --project="$PROJECT_ID" --filter="network:$vpc_name" --format="json")
    local firewall_count=$(echo "$firewall_rules" | jq '. | length')
    
    if [[ $firewall_count -gt 0 ]]; then
        record_result "firewall" "healthy" "Found $firewall_count firewall rules"
    else
        record_result "firewall" "error" "No firewall rules found"
    fi
    
    # Check NAT gateway
    local nat_info=$(gcloud compute routers nats list --project="$PROJECT_ID" --region="$REGION" --format="json")
    local nat_count=$(echo "$nat_info" | jq '. | length')
    
    if [[ $nat_count -gt 0 ]]; then
        record_result "nat" "healthy" "Found $nat_count NAT gateways"
    else
        record_result "nat" "warning" "No NAT gateways found"
    fi
}

# Check compute health
check_compute_health() {
    log "Checking compute health..."
    
    # Check GKE cluster
    local cluster_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-gke"
    local cluster_info=$(gcloud container clusters describe "$cluster_name" --region="$REGION" --project="$PROJECT_ID" --format="json" 2>/dev/null || echo "{}")
    
    if [[ "$cluster_info" != "{}" ]]; then
        local cluster_status=$(echo "$cluster_info" | jq -r '.status')
        local node_count=$(echo "$cluster_info" | jq -r '.currentNodeCount')
        
        if [[ "$cluster_status" == "RUNNING" ]]; then
            record_result "gke_cluster" "healthy" "GKE cluster is running with $node_count nodes"
        else
            record_result "gke_cluster" "error" "GKE cluster is not running (status: $cluster_status)"
        fi
    else
        record_result "gke_cluster" "error" "GKE cluster not found"
    fi
    
    # Check Cloud Run services
    local cloud_run_services=$(gcloud run services list --region="$REGION" --project="$PROJECT_ID" --format="json")
    local service_count=$(echo "$cloud_run_services" | jq '. | length')
    
    if [[ $service_count -gt 0 ]]; then
        local ready_services=0
        for service in $(echo "$cloud_run_services" | jq -r '.[].metadata.name'); do
            local service_info=$(gcloud run services describe "$service" --region="$REGION" --project="$PROJECT_ID" --format="json")
            local status=$(echo "$service_info" | jq -r '.status.conditions[] | select(.type == "Ready") | .status')
            
            if [[ "$status" == "True" ]]; then
                ((ready_services++))
            fi
        done
        
        if [[ $ready_services -eq $service_count ]]; then
            record_result "cloud_run" "healthy" "All $service_count Cloud Run services are ready"
        else
            record_result "cloud_run" "warning" "$ready_services out of $service_count Cloud Run services are ready"
        fi
    else
        record_result "cloud_run" "warning" "No Cloud Run services found"
    fi
    
    # Check Cloud Functions
    local cloud_functions=$(gcloud functions list --region="$REGION" --project="$PROJECT_ID" --format="json")
    local function_count=$(echo "$cloud_functions" | jq '. | length')
    
    if [[ $function_count -gt 0 ]]; then
        local active_functions=0
        for function in $(echo "$cloud_functions" | jq -r '.[].name'); do
            local function_info=$(gcloud functions describe "$function" --region="$REGION" --project="$PROJECT_ID" --format="json")
            local status=$(echo "$function_info" | jq -r '.status')
            
            if [[ "$status" == "ACTIVE" ]]; then
                ((active_functions++))
            fi
        done
        
        if [[ $active_functions -eq $function_count ]]; then
            record_result "cloud_functions" "healthy" "All $function_count Cloud Functions are active"
        else
            record_result "cloud_functions" "warning" "$active_functions out of $function_count Cloud Functions are active"
        fi
    else
        record_result "cloud_functions" "warning" "No Cloud Functions found"
    fi
}

# Check data layer health
check_data_health() {
    log "Checking data layer health..."
    
    # Check Cloud SQL
    local sql_instances=$(gcloud sql instances list --project="$PROJECT_ID" --format="json")
    local sql_count=$(echo "$sql_instances" | jq '. | length')
    
    if [[ $sql_count -gt 0 ]]; then
        local running_instances=0
        for instance in $(echo "$sql_instances" | jq -r '.[].name'); do
            local instance_info=$(gcloud sql instances describe "$instance" --project="$PROJECT_ID" --format="json")
            local state=$(echo "$instance_info" | jq -r '.state')
            
            if [[ "$state" == "RUNNABLE" ]]; then
                ((running_instances++))
            fi
        done
        
        if [[ $running_instances -eq $sql_count ]]; then
            record_result "cloud_sql" "healthy" "All $sql_count Cloud SQL instances are running"
        else
            record_result "cloud_sql" "warning" "$running_instances out of $sql_count Cloud SQL instances are running"
        fi
    else
        record_result "cloud_sql" "warning" "No Cloud SQL instances found"
    fi
    
    # Check Redis
    local redis_instances=$(gcloud redis instances list --region="$REGION" --project="$PROJECT_ID" --format="json")
    local redis_count=$(echo "$redis_instances" | jq '. | length')
    
    if [[ $redis_count -gt 0 ]]; then
        local running_redis=0
        for instance in $(echo "$redis_instances" | jq -r '.[].name'); do
            local instance_info=$(gcloud redis instances describe "$instance" --region="$REGION" --project="$PROJECT_ID" --format="json")
            local state=$(echo "$instance_info" | jq -r '.state')
            
            if [[ "$state" == "READY" ]]; then
                ((running_redis++))
            fi
        done
        
        if [[ $running_redis -eq $redis_count ]]; then
            record_result "redis" "healthy" "All $redis_count Redis instances are ready"
        else
            record_result "redis" "warning" "$running_redis out of $redis_count Redis instances are ready"
        fi
    else
        record_result "redis" "warning" "No Redis instances found"
    fi
    
    # Check BigQuery
    local datasets=$(bq ls --project_id="$PROJECT_ID" --format=json 2>/dev/null || echo "[]")
    local dataset_count=$(echo "$datasets" | jq '. | length')
    
    if [[ $dataset_count -gt 0 ]]; then
        record_result "bigquery" "healthy" "Found $dataset_count BigQuery datasets"
    else
        record_result "bigquery" "warning" "No BigQuery datasets found"
    fi
    
    # Check Cloud Storage
    local storage_buckets=$(gsutil ls -p "$PROJECT_ID" 2>/dev/null || echo "")
    local bucket_count=$(echo "$storage_buckets" | wc -l)
    
    if [[ $bucket_count -gt 0 ]]; then
        record_result "cloud_storage" "healthy" "Found $bucket_count Cloud Storage buckets"
    else
        record_result "cloud_storage" "warning" "No Cloud Storage buckets found"
    fi
}

# Check security health
check_security_health() {
    log "Checking security health..."
    
    # Check IAM
    local service_accounts=$(gcloud iam service-accounts list --project="$PROJECT_ID" --format="json")
    local sa_count=$(echo "$service_accounts" | jq '. | length')
    
    if [[ $sa_count -gt 0 ]]; then
        record_result "iam" "healthy" "Found $sa_count service accounts"
    else
        record_result "iam" "warning" "No service accounts found"
    fi
    
    # Check KMS
    local kms_keyrings=$(gcloud kms keyrings list --location="$REGION" --project="$PROJECT_ID" --format="json")
    local keyring_count=$(echo "$kms_keyrings" | jq '. | length')
    
    if [[ $keyring_count -gt 0 ]]; then
        record_result "kms" "healthy" "Found $keyring_count KMS keyrings"
    else
        record_result "kms" "warning" "No KMS keyrings found"
    fi
    
    # Check Secret Manager
    local secrets=$(gcloud secrets list --project="$PROJECT_ID" --format="json")
    local secret_count=$(echo "$secrets" | jq '. | length')
    
    if [[ $secret_count -gt 0 ]]; then
        record_result "secrets" "healthy" "Found $secret_count secrets"
    else
        record_result "secrets" "warning" "No secrets found"
    fi
}

# Check monitoring health
check_monitoring_health() {
    log "Checking monitoring health..."
    
    # Check log sinks
    local log_sinks=$(gcloud logging sinks list --project="$PROJECT_ID" --format="json")
    local sink_count=$(echo "$log_sinks" | jq '. | length')
    
    if [[ $sink_count -gt 0 ]]; then
        record_result "logging" "healthy" "Found $sink_count log sinks"
    else
        record_result "logging" "warning" "No log sinks found"
    fi
    
    # Check alert policies
    local alert_policies=$(gcloud monitoring alert-policies list --project="$PROJECT_ID" --format="json")
    local alert_count=$(echo "$alert_policies" | jq '. | length')
    
    if [[ $alert_count -gt 0 ]]; then
        record_result "alerts" "healthy" "Found $alert_count alert policies"
    else
        record_result "alerts" "warning" "No alert policies found"
    fi
    
    # Check notification channels
    local notification_channels=$(gcloud monitoring notification-channels list --project="$PROJECT_ID" --format="json")
    local channel_count=$(echo "$notification_channels" | jq '. | length')
    
    if [[ $channel_count -gt 0 ]]; then
        record_result "notifications" "healthy" "Found $channel_count notification channels"
    else
        record_result "notifications" "warning" "No notification channels found"
    fi
}

# Check performance metrics
check_performance_metrics() {
    log "Checking performance metrics..."
    
    # Check resource utilization
    local instances=$(gcloud compute instances list --project="$PROJECT_ID" --format="json")
    local instance_count=$(echo "$instances" | jq '. | length')
    
    if [[ $instance_count -gt 0 ]]; then
        record_result "compute_instances" "healthy" "Found $instance_count compute instances" "$instance_count"
    else
        record_result "compute_instances" "warning" "No compute instances found" "0"
    fi
    
    # Check network performance
    local start_time=$(date +%s)
    if ping -c 3 8.8.8.8 >/dev/null 2>&1; then
        local end_time=$(date +%s)
        local latency=$((end_time - start_time))
        record_result "network_latency" "healthy" "Network latency: ${latency}s" "$latency"
    else
        record_result "network_latency" "error" "Network connectivity failed" "999"
    fi
}

# Generate console report
generate_console_report() {
    log "Generating console report..."
    
    echo
    echo "=========================================="
    echo "INFRASTRUCTURE HEALTH CHECK REPORT"
    echo "=========================================="
    echo "Project: $PROJECT_ID"
    echo "Environment: $ENVIRONMENT"
    echo "Region: $REGION"
    echo "Timestamp: $(date)"
    echo "=========================================="
    echo
    
    local healthy_count=0
    local warning_count=0
    local error_count=0
    
    for component in "${!HEALTH_RESULTS[@]}"; do
        local status="${HEALTH_RESULTS[$component]}"
        local metric="${HEALTH_METRICS[$component]}"
        
        case $status in
            "healthy")
                ((healthy_count++))
                echo "✅ $component: HEALTHY"
                ;;
            "warning")
                ((warning_count++))
                echo "⚠️  $component: WARNING"
                ;;
            "error")
                ((error_count++))
                echo "❌ $component: ERROR"
                ;;
        esac
    done
    
    echo
    echo "=========================================="
    echo "SUMMARY"
    echo "=========================================="
    echo "Healthy: $healthy_count"
    echo "Warnings: $warning_count"
    echo "Errors: $error_count"
    echo "Total: $((healthy_count + warning_count + error_count))"
    echo "=========================================="
    
    if [[ $error_count -gt 0 ]]; then
        echo "❌ Infrastructure has errors that need attention"
        return 1
    elif [[ $warning_count -gt 0 ]]; then
        echo "⚠️  Infrastructure has warnings but is functional"
        return 0
    else
        echo "✅ Infrastructure is healthy"
        return 0
    fi
}

# Generate JSON report
generate_json_report() {
    local json_file="${REPORT_FILE}.json"
    
    log "Generating JSON report: $json_file"
    
    cat > "$json_file" << EOF
{
  "health_check": {
    "project_id": "$PROJECT_ID",
    "environment": "$ENVIRONMENT",
    "region": "$REGION",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "results": {
EOF
    
    local first=true
    for component in "${!HEALTH_RESULTS[@]}"; do
        local status="${HEALTH_RESULTS[$component]}"
        local metric="${HEALTH_METRICS[$component]}"
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo "," >> "$json_file"
        fi
        
        cat >> "$json_file" << EOF
      "$component": {
        "status": "$status",
        "metric": $metric
      }
EOF
    done
    
    cat >> "$json_file" << EOF
    }
  }
}
EOF
    
    success "JSON report generated: $json_file"
}

# Generate HTML report
generate_html_report() {
    local html_file="${REPORT_FILE}.html"
    
    log "Generating HTML report: $html_file"
    
    cat > "$html_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Infrastructure Health Check Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .component { margin: 10px 0; padding: 10px; border-radius: 5px; }
        .healthy { background-color: #d4edda; border-left: 5px solid #28a745; }
        .warning { background-color: #fff3cd; border-left: 5px solid #ffc107; }
        .error { background-color: #f8d7da; border-left: 5px solid #dc3545; }
        .summary { background-color: #e9ecef; padding: 20px; border-radius: 5px; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Infrastructure Health Check Report</h1>
        <p><strong>Project:</strong> $PROJECT_ID</p>
        <p><strong>Environment:</strong> $ENVIRONMENT</p>
        <p><strong>Region:</strong> $REGION</p>
        <p><strong>Timestamp:</strong> $(date)</p>
    </div>
    
    <h2>Component Status</h2>
EOF
    
    for component in "${!HEALTH_RESULTS[@]}"; do
        local status="${HEALTH_RESULTS[$component]}"
        local metric="${HEALTH_METRICS[$component]}"
        
        case $status in
            "healthy")
                echo "    <div class=\"component healthy\">" >> "$html_file"
                echo "        <h3>✅ $component</h3>" >> "$html_file"
                echo "        <p>Status: HEALTHY</p>" >> "$html_file"
                ;;
            "warning")
                echo "    <div class=\"component warning\">" >> "$html_file"
                echo "        <h3>⚠️ $component</h3>" >> "$html_file"
                echo "        <p>Status: WARNING</p>" >> "$html_file"
                ;;
            "error")
                echo "    <div class=\"component error\">" >> "$html_file"
                echo "        <h3>❌ $component</h3>" >> "$html_file"
                echo "        <p>Status: ERROR</p>" >> "$html_file"
                ;;
        esac
        
        if [[ $metric -gt 0 ]]; then
            echo "        <p>Metric: $metric</p>" >> "$html_file"
        fi
        echo "    </div>" >> "$html_file"
    done
    
    # Calculate summary
    local healthy_count=0
    local warning_count=0
    local error_count=0
    
    for component in "${!HEALTH_RESULTS[@]}"; do
        local status="${HEALTH_RESULTS[$component]}"
        case $status in
            "healthy") ((healthy_count++)) ;;
            "warning") ((warning_count++)) ;;
            "error") ((error_count++)) ;;
        esac
    done
    
    cat >> "$html_file" << EOF
    
    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Healthy:</strong> $healthy_count</p>
        <p><strong>Warnings:</strong> $warning_count</p>
        <p><strong>Errors:</strong> $error_count</p>
        <p><strong>Total:</strong> $((healthy_count + warning_count + error_count))</p>
    </div>
</body>
</html>
EOF
    
    success "HTML report generated: $html_file"
}

# Main health check function
run_health_check() {
    log "Starting infrastructure health check..."
    log "Project: $PROJECT_ID, Environment: $ENVIRONMENT, Region: $REGION"
    
    # Run all health checks
    check_project_health
    check_networking_health
    check_compute_health
    check_data_health
    check_security_health
    check_monitoring_health
    check_performance_metrics
    
    # Generate report based on format
    case $OUTPUT_FORMAT in
        "console")
            generate_console_report
            ;;
        "json")
            generate_json_report
            ;;
        "html")
            generate_html_report
            ;;
        *)
            error "Invalid output format: $OUTPUT_FORMAT"
            ;;
    esac
}

# Main execution
main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Validate prerequisites
    validate_prerequisites
    
    # Run health check
    run_health_check
}

# Run main function
main "$@"

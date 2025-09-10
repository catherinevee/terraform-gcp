#!/bin/bash
# Performance Monitoring Script
# This script monitors infrastructure performance and provides optimization recommendations

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
REPORT_FILE="${REPORT_FILE:-performance-monitor-$(date +%Y%m%d-%H%M%S)}"
MONITORING_DURATION="${MONITORING_DURATION:-300}" # 5 minutes in seconds

# Performance monitoring results
declare -A PERFORMANCE_METRICS
declare -A PERFORMANCE_RECOMMENDATIONS
declare -A ALERT_THRESHOLDS

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

Monitor infrastructure performance and provide optimization recommendations.

OPTIONS:
    -p, --project-id PROJECT_ID    GCP Project ID (required)
    -e, --environment ENVIRONMENT  Environment (dev/staging/prod) [default: dev]
    -r, --region REGION           Primary GCP region [default: us-central1]
    -f, --format FORMAT           Output format (console/json/html) [default: console]
    -o, --output FILE             Output file name [default: auto-generated]
    -d, --duration SECONDS        Monitoring duration in seconds [default: 300]
    -h, --help                    Show this help message

EXAMPLES:
    $0 -p my-project -e dev
    $0 -p my-project -e staging -f json -o performance-report.json
    $0 -p my-project -e prod -d 600 -f html -o performance-report.html

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
            -d|--duration)
                MONITORING_DURATION="$2"
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
    command -v gcloud >/dev/null 2>&1 || error "gcloud CLI is not installed"
    command -v jq >/dev/null 2>&1 || error "jq is not installed"
    command -v kubectl >/dev/null 2>&1 || error "kubectl is not installed"
    command -v curl >/dev/null 2>&1 || error "curl is not installed"
    command -v bc >/dev/null 2>&1 || error "bc calculator is not installed"
    
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

# Set up alert thresholds
setup_alert_thresholds() {
    ALERT_THRESHOLDS["cpu_usage"]="80"
    ALERT_THRESHOLDS["memory_usage"]="85"
    ALERT_THRESHOLDS["disk_usage"]="90"
    ALERT_THRESHOLDS["network_latency"]="100"
    ALERT_THRESHOLDS["response_time"]="2000"
    ALERT_THRESHOLDS["error_rate"]="5"
}

# Monitor GKE cluster performance
monitor_gke_performance() {
    log "Monitoring GKE cluster performance..."
    
    # Get cluster information
    local clusters=$(gcloud container clusters list --project="$PROJECT_ID" --format="json")
    local cluster_count=$(echo "$clusters" | jq '. | length')
    
    if [[ $cluster_count -gt 0 ]]; then
        PERFORMANCE_METRICS["gke_clusters"]="$cluster_count"
        
        for cluster in $(echo "$clusters" | jq -r '.[].name'); do
            local cluster_info=$(gcloud container clusters describe "$cluster" --region="$REGION" --project="$PROJECT_ID" --format="json")
            local node_count=$(echo "$cluster_info" | jq -r '.currentNodeCount')
            local node_pools=$(echo "$cluster_info" | jq -r '.nodePools | length')
            
            PERFORMANCE_METRICS["gke_nodes_$cluster"]="$node_count"
            PERFORMANCE_METRICS["gke_node_pools_$cluster"]="$node_pools"
            
            # Get cluster credentials for kubectl
            gcloud container clusters get-credentials "$cluster" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1
            
            # Monitor node resources
            if kubectl get nodes >/dev/null 2>&1; then
                local total_cpu=0
                local total_memory=0
                local used_cpu=0
                local used_memory=0
                
                # Get node resource usage
                local node_metrics=$(kubectl top nodes --no-headers 2>/dev/null || echo "")
                if [[ -n "$node_metrics" ]]; then
                    while IFS= read -r line; do
                        local node_name=$(echo "$line" | awk '{print $1}')
                        local cpu_usage=$(echo "$line" | awk '{print $2}' | sed 's/m//')
                        local memory_usage=$(echo "$line" | awk '{print $4}' | sed 's/Mi//')
                        
                        # Get node capacity
                        local node_info=$(kubectl get node "$node_name" -o json)
                        local cpu_capacity=$(echo "$node_info" | jq -r '.status.capacity.cpu' | sed 's/m//')
                        local memory_capacity=$(echo "$node_info" | jq -r '.status.capacity.memory' | sed 's/Mi//')
                        
                        total_cpu=$((total_cpu + cpu_capacity))
                        total_memory=$((total_memory + memory_capacity))
                        used_cpu=$((used_cpu + cpu_usage))
                        used_memory=$((used_memory + memory_usage))
                    done <<< "$node_metrics"
                    
                    # Calculate percentages
                    local cpu_percentage=$(echo "scale=2; $used_cpu * 100 / $total_cpu" | bc 2>/dev/null || echo "0")
                    local memory_percentage=$(echo "scale=2; $used_memory * 100 / $total_memory" | bc 2>/dev/null || echo "0")
                    
                    PERFORMANCE_METRICS["gke_cpu_usage_$cluster"]="$cpu_percentage"
                    PERFORMANCE_METRICS["gke_memory_usage_$cluster"]="$memory_percentage"
                    
                    # Check for alerts
                    if (( $(echo "$cpu_percentage > ${ALERT_THRESHOLDS["cpu_usage"]}" | bc -l) )); then
                        PERFORMANCE_RECOMMENDATIONS["gke_cpu_$cluster"]="High CPU usage ($cpu_percentage%). Consider scaling up nodes or optimizing workloads."
                    fi
                    
                    if (( $(echo "$memory_percentage > ${ALERT_THRESHOLDS["memory_usage"]}" | bc -l) )); then
                        PERFORMANCE_RECOMMENDATIONS["gke_memory_$cluster"]="High memory usage ($memory_percentage%). Consider scaling up nodes or optimizing memory usage."
                    fi
                fi
            fi
        done
    else
        PERFORMANCE_METRICS["gke_clusters"]="0"
    fi
}

# Monitor Cloud Run performance
monitor_cloud_run_performance() {
    log "Monitoring Cloud Run performance..."
    
    local services=$(gcloud run services list --region="$REGION" --project="$PROJECT_ID" --format="json")
    local service_count=$(echo "$services" | jq '. | length')
    
    PERFORMANCE_METRICS["cloud_run_services"]="$service_count"
    
    if [[ $service_count -gt 0 ]]; then
        for service in $(echo "$services" | jq -r '.[].metadata.name'); do
            local service_info=$(gcloud run services describe "$service" --region="$REGION" --project="$PROJECT_ID" --format="json")
            local status=$(echo "$service_info" | jq -r '.status.conditions[] | select(.type == "Ready") | .status')
            local url=$(echo "$service_info" | jq -r '.status.url')
            
            if [[ "$status" == "True" && -n "$url" ]]; then
                # Test response time
                local start_time=$(date +%s%3N)
                local response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
                local end_time=$(date +%s%3N)
                local response_time=$((end_time - start_time))
                
                PERFORMANCE_METRICS["cloud_run_response_time_$service"]="$response_time"
                
                if [[ $response_time -gt ${ALERT_THRESHOLDS["response_time"]} ]]; then
                    PERFORMANCE_RECOMMENDATIONS["cloud_run_response_$service"]="Slow response time (${response_time}ms). Consider optimizing the service or increasing resources."
                fi
                
                if [[ "$response" != "200" ]]; then
                    PERFORMANCE_RECOMMENDATIONS["cloud_run_health_$service"]="Service returned HTTP $response. Check service health and logs."
                fi
            fi
        done
    fi
}

# Monitor Cloud SQL performance
monitor_cloud_sql_performance() {
    log "Monitoring Cloud SQL performance..."
    
    local instances=$(gcloud sql instances list --project="$PROJECT_ID" --format="json")
    local instance_count=$(echo "$instances" | jq '. | length')
    
    PERFORMANCE_METRICS["cloud_sql_instances"]="$instance_count"
    
    if [[ $instance_count -gt 0 ]]; then
        for instance in $(echo "$instances" | jq -r '.[].name'); do
            local instance_info=$(gcloud sql instances describe "$instance" --project="$PROJECT_ID" --format="json")
            local state=$(echo "$instance_info" | jq -r '.state')
            local tier=$(echo "$instance_info" | jq -r '.settings.tier')
            local disk_size=$(echo "$instance_info" | jq -r '.settings.dataDiskSizeGb')
            
            PERFORMANCE_METRICS["cloud_sql_state_$instance"]="$state"
            PERFORMANCE_METRICS["cloud_sql_tier_$instance"]="$tier"
            PERFORMANCE_METRICS["cloud_sql_disk_size_$instance"]="$disk_size"
            
            if [[ "$state" != "RUNNABLE" ]]; then
                PERFORMANCE_RECOMMENDATIONS["cloud_sql_state_$instance"]="Instance is not in RUNNABLE state ($state). Check instance health."
            fi
        done
    fi
}

# Monitor network performance
monitor_network_performance() {
    log "Monitoring network performance..."
    
    # Test network latency
    local start_time=$(date +%s%3N)
    if ping -c 3 8.8.8.8 >/dev/null 2>&1; then
        local end_time=$(date +%s%3N)
        local latency=$((end_time - start_time))
        PERFORMANCE_METRICS["network_latency"]="$latency"
        
        if [[ $latency -gt ${ALERT_THRESHOLDS["network_latency"]} ]]; then
            PERFORMANCE_RECOMMENDATIONS["network_latency"]="High network latency (${latency}ms). Check network configuration and connectivity."
        fi
    else
        PERFORMANCE_METRICS["network_latency"]="999"
        PERFORMANCE_RECOMMENDATIONS["network_latency"]="Network connectivity failed. Check network configuration."
    fi
    
    # Check load balancer health
    local load_balancers=$(gcloud compute url-maps list --project="$PROJECT_ID" --format="json")
    local lb_count=$(echo "$load_balancers" | jq '. | length')
    PERFORMANCE_METRICS["load_balancers"]="$lb_count"
    
    # Check NAT gateway usage
    local nat_gateways=$(gcloud compute routers nats list --project="$PROJECT_ID" --region="$REGION" --format="json")
    local nat_count=$(echo "$nat_gateways" | jq '. | length')
    PERFORMANCE_METRICS["nat_gateways"]="$nat_count"
}

# Monitor storage performance
monitor_storage_performance() {
    log "Monitoring storage performance..."
    
    # Check Cloud Storage buckets
    local buckets=$(gsutil ls -p "$PROJECT_ID" 2>/dev/null || echo "")
    local bucket_count=$(echo "$buckets" | wc -l)
    PERFORMANCE_METRICS["storage_buckets"]="$bucket_count"
    
    # Check BigQuery performance
    local datasets=$(bq ls --project_id="$PROJECT_ID" --format=json 2>/dev/null || echo "[]")
    local dataset_count=$(echo "$datasets" | jq '. | length')
    PERFORMANCE_METRICS["bigquery_datasets"]="$dataset_count"
    
    # Check Redis instances
    local redis_instances=$(gcloud redis instances list --region="$REGION" --project="$PROJECT_ID" --format="json")
    local redis_count=$(echo "$redis_instances" | jq '. | length')
    PERFORMANCE_METRICS["redis_instances"]="$redis_count"
    
    if [[ $redis_count -gt 0 ]]; then
        for instance in $(echo "$redis_instances" | jq -r '.[].name'); do
            local instance_info=$(gcloud redis instances describe "$instance" --region="$REGION" --project="$PROJECT_ID" --format="json")
            local state=$(echo "$instance_info" | jq -r '.state')
            local memory_size=$(echo "$instance_info" | jq -r '.memorySizeGb')
            
            PERFORMANCE_METRICS["redis_state_$instance"]="$state"
            PERFORMANCE_METRICS["redis_memory_$instance"]="$memory_size"
            
            if [[ "$state" != "READY" ]]; then
                PERFORMANCE_RECOMMENDATIONS["redis_state_$instance"]="Redis instance is not ready ($state). Check instance health."
            fi
        done
    fi
}

# Monitor monitoring and logging
monitor_monitoring_performance() {
    log "Monitoring monitoring and logging performance..."
    
    # Check log sinks
    local log_sinks=$(gcloud logging sinks list --project="$PROJECT_ID" --format="json")
    local sink_count=$(echo "$log_sinks" | jq '. | length')
    PERFORMANCE_METRICS["log_sinks"]="$sink_count"
    
    # Check alert policies
    local alert_policies=$(gcloud monitoring alert-policies list --project="$PROJECT_ID" --format="json")
    local alert_count=$(echo "$alert_policies" | jq '. | length')
    PERFORMANCE_METRICS["alert_policies"]="$alert_count"
    
    # Check uptime checks
    local uptime_checks=$(gcloud monitoring uptime-checks list --project="$PROJECT_ID" --format="json")
    local uptime_count=$(echo "$uptime_checks" | jq '. | length')
    PERFORMANCE_METRICS["uptime_checks"]="$uptime_count"
    
    # Check notification channels
    local notification_channels=$(gcloud monitoring notification-channels list --project="$PROJECT_ID" --format="json")
    local channel_count=$(echo "$notification_channels" | jq '. | length')
    PERFORMANCE_METRICS["notification_channels"]="$channel_count"
}

# Generate performance recommendations
generate_performance_recommendations() {
    log "Generating performance recommendations..."
    
    # GKE recommendations
    local gke_clusters=${PERFORMANCE_METRICS["gke_clusters"]:-0}
    if [[ $gke_clusters -gt 0 ]]; then
        for cluster in $(gcloud container clusters list --project="$PROJECT_ID" --format="value(name)"); do
            local cpu_usage=${PERFORMANCE_METRICS["gke_cpu_usage_$cluster"]:-0}
            local memory_usage=${PERFORMANCE_METRICS["gke_memory_usage_$cluster"]:-0}
            
            if (( $(echo "$cpu_usage < 30" | bc -l) )); then
                PERFORMANCE_RECOMMENDATIONS["gke_optimization_$cluster"]="Low CPU usage ($cpu_usage%). Consider downsizing nodes or enabling cluster autoscaler."
            fi
            
            if (( $(echo "$memory_usage < 40" | bc -l) )); then
                PERFORMANCE_RECOMMENDATIONS["gke_memory_optimization_$cluster"]="Low memory usage ($memory_usage%). Consider optimizing memory allocation."
            fi
        done
    fi
    
    # Storage recommendations
    local storage_buckets=${PERFORMANCE_METRICS["storage_buckets"]:-0}
    if [[ $storage_buckets -gt 10 ]]; then
        PERFORMANCE_RECOMMENDATIONS["storage_optimization"]="High number of storage buckets ($storage_buckets). Consider consolidating or archiving unused buckets."
    fi
    
    # Monitoring recommendations
    local alert_policies=${PERFORMANCE_METRICS["alert_policies"]:-0}
    if [[ $alert_policies -lt 5 ]]; then
        PERFORMANCE_RECOMMENDATIONS["monitoring_coverage"]="Low number of alert policies ($alert_policies). Consider adding more comprehensive monitoring."
    fi
}

# Generate console report
generate_console_report() {
    log "Generating console report..."
    
    echo
    echo "=========================================="
    echo "PERFORMANCE MONITORING REPORT"
    echo "=========================================="
    echo "Project: $PROJECT_ID"
    echo "Environment: $ENVIRONMENT"
    echo "Region: $REGION"
    echo "Timestamp: $(date)"
    echo "Monitoring Duration: ${MONITORING_DURATION}s"
    echo "=========================================="
    echo
    
    # Performance metrics
    echo "PERFORMANCE METRICS"
    echo "-------------------"
    echo "GKE Clusters: ${PERFORMANCE_METRICS["gke_clusters"]:-0}"
    echo "Cloud Run Services: ${PERFORMANCE_METRICS["cloud_run_services"]:-0}"
    echo "Cloud SQL Instances: ${PERFORMANCE_METRICS["cloud_sql_instances"]:-0}"
    echo "Storage Buckets: ${PERFORMANCE_METRICS["storage_buckets"]:-0}"
    echo "BigQuery Datasets: ${PERFORMANCE_METRICS["bigquery_datasets"]:-0}"
    echo "Redis Instances: ${PERFORMANCE_METRICS["redis_instances"]:-0}"
    echo "Load Balancers: ${PERFORMANCE_METRICS["load_balancers"]:-0}"
    echo "NAT Gateways: ${PERFORMANCE_METRICS["nat_gateways"]:-0}"
    echo "Network Latency: ${PERFORMANCE_METRICS["network_latency"]:-0}ms"
    echo "Log Sinks: ${PERFORMANCE_METRICS["log_sinks"]:-0}"
    echo "Alert Policies: ${PERFORMANCE_METRICS["alert_policies"]:-0}"
    echo "Uptime Checks: ${PERFORMANCE_METRICS["uptime_checks"]:-0}"
    echo "Notification Channels: ${PERFORMANCE_METRICS["notification_channels"]:-0}"
    echo
    
    # Performance recommendations
    if [[ ${#PERFORMANCE_RECOMMENDATIONS[@]} -gt 0 ]]; then
        echo "PERFORMANCE RECOMMENDATIONS"
        echo "---------------------------"
        for recommendation in "${!PERFORMANCE_RECOMMENDATIONS[@]}"; do
            echo "• ${PERFORMANCE_RECOMMENDATIONS[$recommendation]}"
        done
        echo
    fi
    
    echo "=========================================="
}

# Generate JSON report
generate_json_report() {
    local json_file="${REPORT_FILE}.json"
    
    log "Generating JSON report: $json_file"
    
    cat > "$json_file" << EOF
{
  "performance_monitoring": {
    "project_id": "$PROJECT_ID",
    "environment": "$ENVIRONMENT",
    "region": "$REGION",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "monitoring_duration": $MONITORING_DURATION,
    "metrics": {
EOF
    
    local first=true
    for metric in "${!PERFORMANCE_METRICS[@]}"; do
        local value="${PERFORMANCE_METRICS[$metric]}"
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo "," >> "$json_file"
        fi
        
        cat >> "$json_file" << EOF
      "$metric": $value
EOF
    done
    
    cat >> "$json_file" << EOF
    },
    "recommendations": {
EOF
    
    first=true
    for recommendation in "${!PERFORMANCE_RECOMMENDATIONS[@]}"; do
        local value="${PERFORMANCE_RECOMMENDATIONS[$recommendation]}"
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo "," >> "$json_file"
        fi
        
        cat >> "$json_file" << EOF
      "$recommendation": "$value"
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
    <title>Performance Monitoring Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .metric { margin: 10px 0; padding: 10px; border-radius: 5px; background-color: #e9ecef; }
        .recommendation { margin: 10px 0; padding: 10px; border-radius: 5px; background-color: #d1ecf1; }
        .summary { background-color: #e9ecef; padding: 20px; border-radius: 5px; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Performance Monitoring Report</h1>
        <p><strong>Project:</strong> $PROJECT_ID</p>
        <p><strong>Environment:</strong> $ENVIRONMENT</p>
        <p><strong>Region:</strong> $REGION</p>
        <p><strong>Timestamp:</strong> $(date)</p>
        <p><strong>Monitoring Duration:</strong> ${MONITORING_DURATION}s</p>
    </div>
    
    <h2>Performance Metrics</h2>
EOF
    
    for metric in "${!PERFORMANCE_METRICS[@]}"; do
        local value="${PERFORMANCE_METRICS[$metric]}"
        echo "    <div class=\"metric\">" >> "$html_file"
        echo "        <strong>$metric:</strong> $value" >> "$html_file"
        echo "    </div>" >> "$html_file"
    done
    
    cat >> "$html_file" << EOF
    
    <h2>Performance Recommendations</h2>
EOF
    
    for recommendation in "${!PERFORMANCE_RECOMMENDATIONS[@]}"; do
        local value="${PERFORMANCE_RECOMMENDATIONS[$recommendation]}"
        echo "    <div class=\"recommendation\">" >> "$html_file"
        echo "        <strong>$recommendation:</strong> $value" >> "$html_file"
        echo "    </div>" >> "$html_file"
    done
    
    cat >> "$html_file" << EOF
    
    <div class="summary">
        <h2>Summary</h2>
        <p>This report provides a comprehensive overview of your infrastructure performance.</p>
        <p>Review the recommendations above to optimize your infrastructure performance and costs.</p>
    </div>
</body>
</html>
EOF
    
    success "HTML report generated: $html_file"
}

# Main performance monitoring function
run_performance_monitoring() {
    log "Starting performance monitoring..."
    log "Project: $PROJECT_ID, Environment: $ENVIRONMENT, Region: $REGION"
    log "Monitoring duration: ${MONITORING_DURATION}s"
    
    # Set up alert thresholds
    setup_alert_thresholds
    
    # Run all performance monitoring
    monitor_gke_performance
    monitor_cloud_run_performance
    monitor_cloud_sql_performance
    monitor_network_performance
    monitor_storage_performance
    monitor_monitoring_performance
    generate_performance_recommendations
    
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
    
    # Run performance monitoring
    run_performance_monitoring
}

# Run main function
main "$@"

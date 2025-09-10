#!/bin/bash
# Cost Analysis and Optimization Script
# This script analyzes infrastructure costs and provides optimization recommendations

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
OUTPUT_FORMAT="${OUTPUT_FORMAT:-console}" # console, json, csv
REPORT_FILE="${REPORT_FILE:-cost-analysis-$(date +%Y%m%d-%H%M%S)}"

# Cost analysis results
declare -A COST_DATA
declare -A OPTIMIZATION_RECOMMENDATIONS

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
Usage: $0 [OPTIONS]

Analyze infrastructure costs and provide optimization recommendations.

OPTIONS:
    -p, --project-id PROJECT_ID    GCP Project ID (required)
    -e, --environment ENVIRONMENT  Environment (dev/staging/prod) [default: dev]
    -r, --region REGION           Primary GCP region [default: us-central1]
    -f, --format FORMAT           Output format (console/json/csv) [default: console]
    -o, --output FILE             Output file name [default: auto-generated]
    -h, --help                    Show this help message

EXAMPLES:
    $0 -p my-project -e dev
    $0 -p my-project -e staging -f json -o cost-report.json
    $0 -p my-project -e prod -f csv -o cost-report.csv

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
    command -v gcloud >/dev/null 2>&1 || error "gcloud CLI is not installed"
    command -v jq >/dev/null 2>&1 || error "jq is not installed"
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

# Get billing information
get_billing_info() {
    log "Retrieving billing information..."
    
    # Get billing account
    local billing_account=$(gcloud billing projects describe "$PROJECT_ID" --format="value(billingAccountName)" 2>/dev/null || echo "")
    
    if [[ -n "$billing_account" ]]; then
        COST_DATA["billing_account"]="$billing_account"
        success "Billing account: $billing_account"
    else
        warning "No billing account found"
        COST_DATA["billing_account"]="Not configured"
    fi
}

# Analyze compute costs
analyze_compute_costs() {
    log "Analyzing compute costs..."
    
    # Get GKE cluster costs
    local clusters=$(gcloud container clusters list --project="$PROJECT_ID" --format="json")
    local cluster_count=$(echo "$clusters" | jq '. | length')
    
    if [[ $cluster_count -gt 0 ]]; then
        local total_nodes=0
        local preemptible_nodes=0
        
        for cluster in $(echo "$clusters" | jq -r '.[].name'); do
            local cluster_info=$(gcloud container clusters describe "$cluster" --region="$REGION" --project="$PROJECT_ID" --format="json")
            local node_count=$(echo "$cluster_info" | jq -r '.currentNodeCount')
            total_nodes=$((total_nodes + node_count))
            
            # Check for preemptible nodes
            local node_pools=$(gcloud container node-pools list --cluster="$cluster" --region="$REGION" --project="$PROJECT_ID" --format="json")
            for pool in $(echo "$node_pools" | jq -r '.[].name'); do
                local pool_info=$(gcloud container node-pools describe "$pool" --cluster="$cluster" --region="$REGION" --project="$PROJECT_ID" --format="json")
                local preemptible=$(echo "$pool_info" | jq -r '.config.preemptible')
                if [[ "$preemptible" == "true" ]]; then
                    preemptible_nodes=$((preemptible_nodes + 1))
                fi
            done
        done
        
        COST_DATA["gke_clusters"]="$cluster_count"
        COST_DATA["total_nodes"]="$total_nodes"
        COST_DATA["preemptible_nodes"]="$preemptible_nodes"
        
        # Calculate potential savings
        local preemptible_percentage=$(echo "scale=2; $preemptible_nodes * 100 / $total_nodes" | bc 2>/dev/null || echo "0")
        COST_DATA["preemptible_percentage"]="$preemptible_percentage"
        
        if (( $(echo "$preemptible_percentage < 50" | bc -l) )); then
            OPTIMIZATION_RECOMMENDATIONS["gke_preemptible"]="Consider using more preemptible nodes (currently $preemptible_percentage%). Preemptible nodes can save up to 80% on compute costs."
        fi
    else
        COST_DATA["gke_clusters"]="0"
        COST_DATA["total_nodes"]="0"
        COST_DATA["preemptible_nodes"]="0"
    fi
    
    # Get Cloud Run costs
    local cloud_run_services=$(gcloud run services list --region="$REGION" --project="$PROJECT_ID" --format="json")
    local service_count=$(echo "$cloud_run_services" | jq '. | length')
    COST_DATA["cloud_run_services"]="$service_count"
    
    # Get Cloud Functions costs
    local cloud_functions=$(gcloud functions list --region="$REGION" --project="$PROJECT_ID" --format="json")
    local function_count=$(echo "$cloud_functions" | jq '. | length')
    COST_DATA["cloud_functions"]="$function_count"
    
    # Get Compute Engine instances
    local instances=$(gcloud compute instances list --project="$PROJECT_ID" --format="json")
    local instance_count=$(echo "$instances" | jq '. | length')
    local preemptible_instances=0
    
    for instance in $(echo "$instances" | jq -r '.[].name'); do
        local instance_info=$(gcloud compute instances describe "$instance" --zone="$REGION-a" --project="$PROJECT_ID" --format="json" 2>/dev/null || echo "{}")
        local scheduling=$(echo "$instance_info" | jq -r '.scheduling.preemptible // false')
        if [[ "$scheduling" == "true" ]]; then
            ((preemptible_instances++))
        fi
    done
    
    COST_DATA["compute_instances"]="$instance_count"
    COST_DATA["preemptible_instances"]="$preemptible_instances"
}

# Analyze storage costs
analyze_storage_costs() {
    log "Analyzing storage costs..."
    
    # Get Cloud Storage buckets
    local buckets=$(gsutil ls -p "$PROJECT_ID" 2>/dev/null || echo "")
    local bucket_count=$(echo "$buckets" | wc -l)
    COST_DATA["storage_buckets"]="$bucket_count"
    
    # Analyze bucket storage classes and lifecycle policies
    local standard_buckets=0
    local nearline_buckets=0
    local coldline_buckets=0
    local archive_buckets=0
    local lifecycle_enabled=0
    
    for bucket in $buckets; do
        local bucket_name=$(basename "$bucket")
        local storage_class=$(gsutil ls -L -b "$bucket" 2>/dev/null | grep "Storage class" | awk '{print $3}' || echo "STANDARD")
        
        case $storage_class in
            "STANDARD") ((standard_buckets++)) ;;
            "NEARLINE") ((nearline_buckets++)) ;;
            "COLDLINE") ((coldline_buckets++)) ;;
            "ARCHIVE") ((archive_buckets++)) ;;
        esac
        
        # Check lifecycle policies
        local lifecycle=$(gsutil lifecycle get "$bucket" 2>/dev/null || echo "No lifecycle policy")
        if [[ "$lifecycle" != "No lifecycle policy" ]]; then
            ((lifecycle_enabled++))
        fi
    done
    
    COST_DATA["standard_buckets"]="$standard_buckets"
    COST_DATA["nearline_buckets"]="$nearline_buckets"
    COST_DATA["coldline_buckets"]="$coldline_buckets"
    COST_DATA["archive_buckets"]="$archive_buckets"
    COST_DATA["lifecycle_enabled"]="$lifecycle_enabled"
    
    # Optimization recommendations
    if [[ $standard_buckets -gt 0 ]]; then
        OPTIMIZATION_RECOMMENDATIONS["storage_class"]="Consider using Nearline, Coldline, or Archive storage classes for infrequently accessed data to reduce costs."
    fi
    
    if [[ $lifecycle_enabled -lt $bucket_count ]]; then
        OPTIMIZATION_RECOMMENDATIONS["lifecycle_policies"]="Enable lifecycle policies on all buckets to automatically transition or delete old data."
    fi
}

# Analyze database costs
analyze_database_costs() {
    log "Analyzing database costs..."
    
    # Get Cloud SQL instances
    local sql_instances=$(gcloud sql instances list --project="$PROJECT_ID" --format="json")
    local sql_count=$(echo "$sql_instances" | jq '. | length')
    COST_DATA["cloud_sql_instances"]="$sql_count"
    
    # Analyze SQL instance tiers
    local standard_tiers=0
    local high_memory_tiers=0
    local shared_core_tiers=0
    
    for instance in $(echo "$sql_instances" | jq -r '.[].name'); do
        local instance_info=$(gcloud sql instances describe "$instance" --project="$PROJECT_ID" --format="json")
        local tier=$(echo "$instance_info" | jq -r '.settings.tier')
        
        if [[ "$tier" == *"db-n1-standard"* ]]; then
            ((standard_tiers++))
        elif [[ "$tier" == *"db-n1-highmem"* ]]; then
            ((high_memory_tiers++))
        elif [[ "$tier" == *"db-f1-micro"* ]] || [[ "$tier" == *"db-g1-small"* ]]; then
            ((shared_core_tiers++))
        fi
    done
    
    COST_DATA["standard_sql_tiers"]="$standard_tiers"
    COST_DATA["high_memory_sql_tiers"]="$high_memory_tiers"
    COST_DATA["shared_core_sql_tiers"]="$shared_core_sql_tiers"
    
    # Get Redis instances
    local redis_instances=$(gcloud redis instances list --region="$REGION" --project="$PROJECT_ID" --format="json")
    local redis_count=$(echo "$redis_instances" | jq '. | length')
    COST_DATA["redis_instances"]="$redis_count"
    
    # Get BigQuery datasets
    local datasets=$(bq ls --project_id="$PROJECT_ID" --format=json 2>/dev/null || echo "[]")
    local dataset_count=$(echo "$datasets" | jq '. | length')
    COST_DATA["bigquery_datasets"]="$dataset_count"
}

# Analyze network costs
analyze_network_costs() {
    log "Analyzing network costs..."
    
    # Get VPC networks
    local vpcs=$(gcloud compute networks list --project="$PROJECT_ID" --format="json")
    local vpc_count=$(echo "$vpcs" | jq '. | length')
    COST_DATA["vpc_networks"]="$vpc_count"
    
    # Get Cloud NAT gateways
    local nat_gateways=$(gcloud compute routers nats list --project="$PROJECT_ID" --region="$REGION" --format="json")
    local nat_count=$(echo "$nat_gateways" | jq '. | length')
    COST_DATA["nat_gateways"]="$nat_count"
    
    # Get Cloud Load Balancers
    local load_balancers=$(gcloud compute url-maps list --project="$PROJECT_ID" --format="json")
    local lb_count=$(echo "$load_balancers" | jq '. | length')
    COST_DATA["load_balancers"]="$lb_count"
    
    # Get Cloud CDN
    local cdn_backends=$(gcloud compute backend-services list --project="$PROJECT_ID" --format="json")
    local cdn_enabled=0
    
    for backend in $(echo "$cdn_backends" | jq -r '.[].name'); do
        local backend_info=$(gcloud compute backend-services describe "$backend" --global --project="$PROJECT_ID" --format="json")
        local cdn=$(echo "$backend_info" | jq -r '.cdnPolicy.enabled // false')
        if [[ "$cdn" == "true" ]]; then
            ((cdn_enabled++))
        fi
    done
    
    COST_DATA["cdn_enabled"]="$cdn_enabled"
    
    # Optimization recommendations
    if [[ $nat_count -gt 1 ]]; then
        OPTIMIZATION_RECOMMENDATIONS["nat_gateways"]="Consider consolidating NAT gateways. Each NAT gateway incurs costs regardless of usage."
    fi
}

# Analyze monitoring costs
analyze_monitoring_costs() {
    log "Analyzing monitoring costs..."
    
    # Get log sinks
    local log_sinks=$(gcloud logging sinks list --project="$PROJECT_ID" --format="json")
    local sink_count=$(echo "$log_sinks" | jq '. | length')
    COST_DATA["log_sinks"]="$sink_count"
    
    # Get alert policies
    local alert_policies=$(gcloud monitoring alert-policies list --project="$PROJECT_ID" --format="json")
    local alert_count=$(echo "$alert_policies" | jq '. | length')
    COST_DATA["alert_policies"]="$alert_count"
    
    # Get uptime checks
    local uptime_checks=$(gcloud monitoring uptime-checks list --project="$PROJECT_ID" --format="json")
    local uptime_count=$(echo "$uptime_checks" | jq '. | length')
    COST_DATA["uptime_checks"]="$uptime_count"
}

# Calculate cost estimates
calculate_cost_estimates() {
    log "Calculating cost estimates..."
    
    # GKE costs (rough estimates)
    local gke_nodes=${COST_DATA["total_nodes"]:-0}
    local gke_preemptible=${COST_DATA["preemptible_nodes"]:-0}
    local gke_standard=$((gke_nodes - gke_preemptible))
    
    # Estimated monthly costs (USD)
    local gke_standard_cost=$(echo "scale=2; $gke_standard * 73.00" | bc 2>/dev/null || echo "0")
    local gke_preemptible_cost=$(echo "scale=2; $gke_preemptible * 14.60" | bc 2>/dev/null || echo "0")
    local gke_total_cost=$(echo "scale=2; $gke_standard_cost + $gke_preemptible_cost" | bc 2>/dev/null || echo "0")
    
    COST_DATA["gke_standard_cost"]="$gke_standard_cost"
    COST_DATA["gke_preemptible_cost"]="$gke_preemptible_cost"
    COST_DATA["gke_total_cost"]="$gke_total_cost"
    
    # Cloud SQL costs (rough estimates)
    local sql_instances=${COST_DATA["cloud_sql_instances"]:-0}
    local sql_standard=${COST_DATA["standard_sql_tiers"]:-0}
    local sql_shared_core=${COST_DATA["shared_core_sql_tiers"]:-0}
    
    local sql_standard_cost=$(echo "scale=2; $sql_standard * 50.00" | bc 2>/dev/null || echo "0")
    local sql_shared_core_cost=$(echo "scale=2; $sql_shared_core * 10.00" | bc 2>/dev/null || echo "0")
    local sql_total_cost=$(echo "scale=2; $sql_standard_cost + $sql_shared_core_cost" | bc 2>/dev/null || echo "0")
    
    COST_DATA["sql_standard_cost"]="$sql_standard_cost"
    COST_DATA["sql_shared_core_cost"]="$sql_shared_core_cost"
    COST_DATA["sql_total_cost"]="$sql_total_cost"
    
    # Storage costs (rough estimates)
    local storage_buckets=${COST_DATA["storage_buckets"]:-0}
    local storage_cost=$(echo "scale=2; $storage_buckets * 5.00" | bc 2>/dev/null || echo "0")
    COST_DATA["storage_cost"]="$storage_cost"
    
    # Network costs (rough estimates)
    local nat_gateways=${COST_DATA["nat_gateways"]:-0}
    local load_balancers=${COST_DATA["load_balancers"]:-0}
    local nat_cost=$(echo "scale=2; $nat_gateways * 45.00" | bc 2>/dev/null || echo "0")
    local lb_cost=$(echo "scale=2; $load_balancers * 18.00" | bc 2>/dev/null || echo "0")
    local network_total_cost=$(echo "scale=2; $nat_cost + $lb_cost" | bc 2>/dev/null || echo "0")
    
    COST_DATA["nat_cost"]="$nat_cost"
    COST_DATA["lb_cost"]="$lb_cost"
    COST_DATA["network_total_cost"]="$network_total_cost"
    
    # Total estimated cost
    local total_cost=$(echo "scale=2; $gke_total_cost + $sql_total_cost + $storage_cost + $network_total_cost" | bc 2>/dev/null || echo "0")
    COST_DATA["total_estimated_cost"]="$total_cost"
}

# Generate console report
generate_console_report() {
    log "Generating console report..."
    
    echo
    echo "=========================================="
    echo "COST ANALYSIS REPORT"
    echo "=========================================="
    echo "Project: $PROJECT_ID"
    echo "Environment: $ENVIRONMENT"
    echo "Region: $REGION"
    echo "Timestamp: $(date)"
    echo "=========================================="
    echo
    
    # Resource summary
    echo "RESOURCE SUMMARY"
    echo "----------------"
    echo "GKE Clusters: ${COST_DATA["gke_clusters"]:-0}"
    echo "Total Nodes: ${COST_DATA["total_nodes"]:-0} (${COST_DATA["preemptible_nodes"]:-0} preemptible)"
    echo "Cloud Run Services: ${COST_DATA["cloud_run_services"]:-0}"
    echo "Cloud Functions: ${COST_DATA["cloud_functions"]:-0}"
    echo "Compute Instances: ${COST_DATA["compute_instances"]:-0}"
    echo "Cloud SQL Instances: ${COST_DATA["cloud_sql_instances"]:-0}"
    echo "Redis Instances: ${COST_DATA["redis_instances"]:-0}"
    echo "BigQuery Datasets: ${COST_DATA["bigquery_datasets"]:-0}"
    echo "Storage Buckets: ${COST_DATA["storage_buckets"]:-0}"
    echo "VPC Networks: ${COST_DATA["vpc_networks"]:-0}"
    echo "NAT Gateways: ${COST_DATA["nat_gateways"]:-0}"
    echo "Load Balancers: ${COST_DATA["load_balancers"]:-0}"
    echo
    
    # Cost estimates
    echo "COST ESTIMATES (Monthly USD)"
    echo "----------------------------"
    echo "GKE Standard Nodes: \$${COST_DATA["gke_standard_cost"]:-0}"
    echo "GKE Preemptible Nodes: \$${COST_DATA["gke_preemptible_cost"]:-0}"
    echo "GKE Total: \$${COST_DATA["gke_total_cost"]:-0}"
    echo "Cloud SQL Standard: \$${COST_DATA["sql_standard_cost"]:-0}"
    echo "Cloud SQL Shared Core: \$${COST_DATA["sql_shared_core_cost"]:-0}"
    echo "Cloud SQL Total: \$${COST_DATA["sql_total_cost"]:-0}"
    echo "Storage: \$${COST_DATA["storage_cost"]:-0}"
    echo "NAT Gateways: \$${COST_DATA["nat_cost"]:-0}"
    echo "Load Balancers: \$${COST_DATA["lb_cost"]:-0}"
    echo "Network Total: \$${COST_DATA["network_total_cost"]:-0}"
    echo "----------------------------------------"
    echo "TOTAL ESTIMATED: \$${COST_DATA["total_estimated_cost"]:-0}"
    echo
    
    # Optimization recommendations
    if [[ ${#OPTIMIZATION_RECOMMENDATIONS[@]} -gt 0 ]]; then
        echo "OPTIMIZATION RECOMMENDATIONS"
        echo "----------------------------"
        for recommendation in "${!OPTIMIZATION_RECOMMENDATIONS[@]}"; do
            echo "• ${OPTIMIZATION_RECOMMENDATIONS[$recommendation]}"
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
  "cost_analysis": {
    "project_id": "$PROJECT_ID",
    "environment": "$ENVIRONMENT",
    "region": "$REGION",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "billing_account": "${COST_DATA["billing_account"]:-"Not configured"}",
    "resources": {
      "gke_clusters": ${COST_DATA["gke_clusters"]:-0},
      "total_nodes": ${COST_DATA["total_nodes"]:-0},
      "preemptible_nodes": ${COST_DATA["preemptible_nodes"]:-0},
      "cloud_run_services": ${COST_DATA["cloud_run_services"]:-0},
      "cloud_functions": ${COST_DATA["cloud_functions"]:-0},
      "compute_instances": ${COST_DATA["compute_instances"]:-0},
      "cloud_sql_instances": ${COST_DATA["cloud_sql_instances"]:-0},
      "redis_instances": ${COST_DATA["redis_instances"]:-0},
      "bigquery_datasets": ${COST_DATA["bigquery_datasets"]:-0},
      "storage_buckets": ${COST_DATA["storage_buckets"]:-0},
      "vpc_networks": ${COST_DATA["vpc_networks"]:-0},
      "nat_gateways": ${COST_DATA["nat_gateways"]:-0},
      "load_balancers": ${COST_DATA["load_balancers"]:-0}
    },
    "cost_estimates": {
      "gke_standard_cost": ${COST_DATA["gke_standard_cost"]:-0},
      "gke_preemptible_cost": ${COST_DATA["gke_preemptible_cost"]:-0},
      "gke_total_cost": ${COST_DATA["gke_total_cost"]:-0},
      "sql_standard_cost": ${COST_DATA["sql_standard_cost"]:-0},
      "sql_shared_core_cost": ${COST_DATA["sql_shared_core_cost"]:-0},
      "sql_total_cost": ${COST_DATA["sql_total_cost"]:-0},
      "storage_cost": ${COST_DATA["storage_cost"]:-0},
      "nat_cost": ${COST_DATA["nat_cost"]:-0},
      "lb_cost": ${COST_DATA["lb_cost"]:-0},
      "network_total_cost": ${COST_DATA["network_total_cost"]:-0},
      "total_estimated_cost": ${COST_DATA["total_estimated_cost"]:-0}
    },
    "optimization_recommendations": {
EOF
    
    local first=true
    for recommendation in "${!OPTIMIZATION_RECOMMENDATIONS[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo "," >> "$json_file"
        fi
        
        cat >> "$json_file" << EOF
      "$recommendation": "${OPTIMIZATION_RECOMMENDATIONS[$recommendation]}"
EOF
    done
    
    cat >> "$json_file" << EOF
    }
  }
}
EOF
    
    success "JSON report generated: $json_file"
}

# Generate CSV report
generate_csv_report() {
    local csv_file="${REPORT_FILE}.csv"
    
    log "Generating CSV report: $csv_file"
    
    cat > "$csv_file" << EOF
Resource,Count,Monthly Cost (USD)
GKE Standard Nodes,${COST_DATA["gke_standard"]:-0},${COST_DATA["gke_standard_cost"]:-0}
GKE Preemptible Nodes,${COST_DATA["preemptible_nodes"]:-0},${COST_DATA["gke_preemptible_cost"]:-0}
Cloud SQL Standard,${COST_DATA["standard_sql_tiers"]:-0},${COST_DATA["sql_standard_cost"]:-0}
Cloud SQL Shared Core,${COST_DATA["shared_core_sql_tiers"]:-0},${COST_DATA["sql_shared_core_cost"]:-0}
Storage Buckets,${COST_DATA["storage_buckets"]:-0},${COST_DATA["storage_cost"]:-0}
NAT Gateways,${COST_DATA["nat_gateways"]:-0},${COST_DATA["nat_cost"]:-0}
Load Balancers,${COST_DATA["load_balancers"]:-0},${COST_DATA["lb_cost"]:-0}
Total,,${COST_DATA["total_estimated_cost"]:-0}
EOF
    
    success "CSV report generated: $csv_file"
}

# Main cost analysis function
run_cost_analysis() {
    log "Starting cost analysis..."
    log "Project: $PROJECT_ID, Environment: $ENVIRONMENT, Region: $REGION"
    
    # Run all cost analyses
    get_billing_info
    analyze_compute_costs
    analyze_storage_costs
    analyze_database_costs
    analyze_network_costs
    analyze_monitoring_costs
    calculate_cost_estimates
    
    # Generate report based on format
    case $OUTPUT_FORMAT in
        "console")
            generate_console_report
            ;;
        "json")
            generate_json_report
            ;;
        "csv")
            generate_csv_report
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
    
    # Run cost analysis
    run_cost_analysis
}

# Run main function
main "$@"

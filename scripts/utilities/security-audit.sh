#!/bin/bash
# Security Audit Script
# This script performs comprehensive security audits of the terraform-gcp infrastructure

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
REPORT_FILE="${REPORT_FILE:-security-audit-$(date +%Y%m%d-%H%M%S)}"

# Security audit results
declare -A SECURITY_RESULTS
declare -A SECURITY_RECOMMENDATIONS
declare -A COMPLIANCE_SCORES

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

Perform comprehensive security audit of the terraform-gcp infrastructure.

OPTIONS:
    -p, --project-id PROJECT_ID    GCP Project ID (required)
    -e, --environment ENVIRONMENT  Environment (dev/staging/prod) [default: dev]
    -r, --region REGION           Primary GCP region [default: us-central1]
    -f, --format FORMAT           Output format (console/json/html) [default: console]
    -o, --output FILE             Output file name [default: auto-generated]
    -h, --help                    Show this help message

EXAMPLES:
    $0 -p my-project -e dev
    $0 -p my-project -e staging -f json -o security-audit.json
    $0 -p my-project -e prod -f html -o security-audit.html

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
    command -v kubectl >/dev/null 2>&1 || error "kubectl is not installed"
    
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

# Record security audit result
record_result() {
    local category="$1"
    local check_name="$2"
    local status="$3"
    local message="$4"
    local recommendation="${5:-}"
    
    local key="${category}_${check_name}"
    SECURITY_RESULTS["$key"]="$status"
    
    if [[ -n "$recommendation" ]]; then
        SECURITY_RECOMMENDATIONS["$key"]="$recommendation"
    fi
    
    case $status in
        "pass")
            success "$category - $check_name: $message"
            ;;
        "warn")
            warning "$category - $check_name: $message"
            ;;
        "fail")
            error "$category - $check_name: $message"
            ;;
        *)
            info "$category - $check_name: $message"
            ;;
    esac
}

# Audit IAM security
audit_iam_security() {
    log "Auditing IAM security..."
    
    # Check for overly permissive roles
    local iam_policy=$(gcloud projects get-iam-policy "$PROJECT_ID" --format="json")
    local editor_roles=$(echo "$iam_policy" | jq '[.bindings[] | select(.role == "roles/editor")] | length')
    local owner_roles=$(echo "$iam_policy" | jq '[.bindings[] | select(.role == "roles/owner")] | length')
    
    if [[ $editor_roles -gt 0 ]]; then
        record_result "iam" "editor_roles" "warn" "Found $editor_roles editor role bindings" "Consider using more specific roles instead of editor role"
    else
        record_result "iam" "editor_roles" "pass" "No editor role bindings found"
    fi
    
    if [[ $owner_roles -gt 1 ]]; then
        record_result "iam" "owner_roles" "warn" "Found $owner_roles owner role bindings" "Limit owner role to essential accounts only"
    else
        record_result "iam" "owner_roles" "pass" "Owner role appropriately limited"
    fi
    
    # Check for service accounts
    local service_accounts=$(gcloud iam service-accounts list --project="$PROJECT_ID" --format="json")
    local sa_count=$(echo "$service_accounts" | jq '. | length')
    
    if [[ $sa_count -gt 0 ]]; then
        record_result "iam" "service_accounts" "pass" "Found $sa_count service accounts"
        
        # Check for service account keys
        local sa_with_keys=0
        for sa in $(echo "$service_accounts" | jq -r '.[].email'); do
            local keys=$(gcloud iam service-accounts keys list --iam-account="$sa" --project="$PROJECT_ID" --format="json")
            local key_count=$(echo "$keys" | jq '. | length')
            if [[ $key_count -gt 0 ]]; then
                ((sa_with_keys++))
            fi
        done
        
        if [[ $sa_with_keys -gt 0 ]]; then
            record_result "iam" "service_account_keys" "warn" "Found $sa_with_keys service accounts with keys" "Consider using Workload Identity instead of service account keys"
        else
            record_result "iam" "service_account_keys" "pass" "No service account keys found"
        fi
    else
        record_result "iam" "service_accounts" "warn" "No service accounts found"
    fi
    
    # Check for conditional IAM bindings
    local conditional_bindings=$(echo "$iam_policy" | jq '[.bindings[] | select(.condition != null)] | length')
    if [[ $conditional_bindings -gt 0 ]]; then
        record_result "iam" "conditional_bindings" "pass" "Found $conditional_bindings conditional IAM bindings"
    else
        record_result "iam" "conditional_bindings" "warn" "No conditional IAM bindings found" "Consider using conditional access for enhanced security"
    fi
}

# Audit network security
audit_network_security() {
    log "Auditing network security..."
    
    # Check VPC configuration
    local vpcs=$(gcloud compute networks list --project="$PROJECT_ID" --format="json")
    local vpc_count=$(echo "$vpcs" | jq '. | length')
    
    if [[ $vpc_count -gt 0 ]]; then
        record_result "network" "vpc_count" "pass" "Found $vpc_count VPC networks"
        
        # Check for private clusters
        local clusters=$(gcloud container clusters list --project="$PROJECT_ID" --format="json")
        local private_clusters=0
        local total_clusters=$(echo "$clusters" | jq '. | length')
        
        for cluster in $(echo "$clusters" | jq -r '.[].name'); do
            local cluster_info=$(gcloud container clusters describe "$cluster" --region="$REGION" --project="$PROJECT_ID" --format="json")
            local private_cluster=$(echo "$cluster_info" | jq -r '.privateClusterConfig.enablePrivateNodes')
            if [[ "$private_cluster" == "true" ]]; then
                ((private_clusters++))
            fi
        done
        
        if [[ $total_clusters -gt 0 ]]; then
            local private_percentage=$(echo "scale=2; $private_clusters * 100 / $total_clusters" | bc 2>/dev/null || echo "0")
            if (( $(echo "$private_percentage == 100" | bc -l) )); then
                record_result "network" "private_clusters" "pass" "All $total_clusters clusters are private"
            else
                record_result "network" "private_clusters" "warn" "$private_clusters out of $total_clusters clusters are private" "Consider making all clusters private for enhanced security"
            fi
        fi
    else
        record_result "network" "vpc_count" "fail" "No VPC networks found"
    fi
    
    # Check firewall rules
    local firewall_rules=$(gcloud compute firewall-rules list --project="$PROJECT_ID" --format="json")
    local firewall_count=$(echo "$firewall_rules" | jq '. | length')
    
    if [[ $firewall_count -gt 0 ]]; then
        record_result "network" "firewall_rules" "pass" "Found $firewall_count firewall rules"
        
        # Check for overly permissive rules
        local permissive_rules=0
        for rule in $(echo "$firewall_rules" | jq -r '.[].name'); do
            local rule_info=$(gcloud compute firewall-rules describe "$rule" --project="$PROJECT_ID" --format="json")
            local source_ranges=$(echo "$rule_info" | jq -r '.sourceRanges[]? // empty')
            local allowed_ports=$(echo "$rule_info" | jq -r '.allowed[].ports[]? // empty')
            
            if echo "$source_ranges" | grep -q "0.0.0.0/0"; then
                if echo "$allowed_ports" | grep -q "22\|3389"; then
                    ((permissive_rules++))
                fi
            fi
        done
        
        if [[ $permissive_rules -gt 0 ]]; then
            record_result "network" "permissive_rules" "warn" "Found $permissive_rules potentially permissive firewall rules" "Review rules allowing SSH/RDP from 0.0.0.0/0"
        else
            record_result "network" "permissive_rules" "pass" "No overly permissive firewall rules found"
        fi
    else
        record_result "network" "firewall_rules" "fail" "No firewall rules found"
    fi
}

# Audit data security
audit_data_security() {
    log "Auditing data security..."
    
    # Check Cloud SQL encryption
    local sql_instances=$(gcloud sql instances list --project="$PROJECT_ID" --format="json")
    local sql_count=$(echo "$sql_instances" | jq '. | length')
    
    if [[ $sql_count -gt 0 ]]; then
        local encrypted_instances=0
        local private_instances=0
        
        for instance in $(echo "$sql_instances" | jq -r '.[].name'); do
            local instance_info=$(gcloud sql instances describe "$instance" --project="$PROJECT_ID" --format="json")
            local encryption=$(echo "$instance_info" | jq -r '.diskEncryptionConfiguration.kmsKeyName // empty')
            local ipv4_enabled=$(echo "$instance_info" | jq -r '.settings.ipConfiguration.ipv4Enabled')
            
            if [[ -n "$encryption" ]]; then
                ((encrypted_instances++))
            fi
            
            if [[ "$ipv4_enabled" == "false" ]]; then
                ((private_instances++))
            fi
        done
        
        if [[ $encrypted_instances -eq $sql_count ]]; then
            record_result "data" "sql_encryption" "pass" "All $sql_count Cloud SQL instances are encrypted"
        else
            record_result "data" "sql_encryption" "fail" "$encrypted_instances out of $sql_count Cloud SQL instances are encrypted" "Enable encryption for all Cloud SQL instances"
        fi
        
        if [[ $private_instances -eq $sql_count ]]; then
            record_result "data" "sql_private" "pass" "All $sql_count Cloud SQL instances are private"
        else
            record_result "data" "sql_private" "warn" "$private_instances out of $sql_count Cloud SQL instances are private" "Consider making all Cloud SQL instances private"
        fi
    else
        record_result "data" "sql_instances" "warn" "No Cloud SQL instances found"
    fi
    
    # Check Cloud Storage encryption
    local storage_buckets=$(gsutil ls -p "$PROJECT_ID" 2>/dev/null || echo "")
    local bucket_count=$(echo "$storage_buckets" | wc -l)
    
    if [[ $bucket_count -gt 0 ]]; then
        record_result "data" "storage_buckets" "pass" "Found $bucket_count Cloud Storage buckets"
        
        # Check for uniform bucket-level access
        local uniform_access=0
        for bucket in $storage_buckets; do
            local bucket_name=$(basename "$bucket")
            local uniform_access_enabled=$(gsutil iam get "$bucket" 2>/dev/null | grep -q "uniform" && echo "true" || echo "false")
            if [[ "$uniform_access_enabled" == "true" ]]; then
                ((uniform_access++))
            fi
        done
        
        if [[ $uniform_access -eq $bucket_count ]]; then
            record_result "data" "uniform_access" "pass" "All $bucket_count buckets have uniform bucket-level access"
        else
            record_result "data" "uniform_access" "warn" "$uniform_access out of $bucket_count buckets have uniform bucket-level access" "Enable uniform bucket-level access for all buckets"
        fi
    else
        record_result "data" "storage_buckets" "warn" "No Cloud Storage buckets found"
    fi
}

# Audit encryption security
audit_encryption_security() {
    log "Auditing encryption security..."
    
    # Check KMS configuration
    local kms_keyrings=$(gcloud kms keyrings list --location="$REGION" --project="$PROJECT_ID" --format="json")
    local keyring_count=$(echo "$kms_keyrings" | jq '. | length')
    
    if [[ $keyring_count -gt 0 ]]; then
        record_result "encryption" "kms_keyrings" "pass" "Found $keyring_count KMS keyrings"
        
        # Check for key rotation
        local rotating_keys=0
        local total_keys=0
        
        for keyring in $(echo "$kms_keyrings" | jq -r '.[].name'); do
            local keys=$(gcloud kms keys list --keyring="$keyring" --location="$REGION" --project="$PROJECT_ID" --format="json")
            local key_count=$(echo "$keys" | jq '. | length')
            total_keys=$((total_keys + key_count))
            
            for key in $(echo "$keys" | jq -r '.[].name'); do
                local key_info=$(gcloud kms keys describe "$key" --keyring="$keyring" --location="$REGION" --project="$PROJECT_ID" --format="json")
                local rotation_period=$(echo "$key_info" | jq -r '.rotationPeriod // empty')
                if [[ -n "$rotation_period" ]]; then
                    ((rotating_keys++))
                fi
            done
        done
        
        if [[ $total_keys -gt 0 ]]; then
            local rotation_percentage=$(echo "scale=2; $rotating_keys * 100 / $total_keys" | bc 2>/dev/null || echo "0")
            if (( $(echo "$rotation_percentage == 100" | bc -l) )); then
                record_result "encryption" "key_rotation" "pass" "All $total_keys KMS keys have rotation enabled"
            else
                record_result "encryption" "key_rotation" "warn" "$rotating_keys out of $total_keys KMS keys have rotation enabled" "Enable key rotation for all KMS keys"
            fi
        fi
    else
        record_result "encryption" "kms_keyrings" "warn" "No KMS keyrings found"
    fi
    
    # Check Secret Manager
    local secrets=$(gcloud secrets list --project="$PROJECT_ID" --format="json")
    local secret_count=$(echo "$secrets" | jq '. | length')
    
    if [[ $secret_count -gt 0 ]]; then
        record_result "encryption" "secrets" "pass" "Found $secret_count secrets in Secret Manager"
    else
        record_result "encryption" "secrets" "warn" "No secrets found in Secret Manager"
    fi
}

# Audit monitoring security
audit_monitoring_security() {
    log "Auditing monitoring security..."
    
    # Check log sinks
    local log_sinks=$(gcloud logging sinks list --project="$PROJECT_ID" --format="json")
    local sink_count=$(echo "$log_sinks" | jq '. | length')
    
    if [[ $sink_count -gt 0 ]]; then
        record_result "monitoring" "log_sinks" "pass" "Found $sink_count log sinks"
        
        # Check for audit log sinks
        local audit_sinks=0
        for sink in $(echo "$log_sinks" | jq -r '.[].name'); do
            local sink_info=$(gcloud logging sinks describe "$sink" --project="$PROJECT_ID" --format="json")
            local filter=$(echo "$sink_info" | jq -r '.filter')
            if echo "$filter" | grep -q "cloudaudit.googleapis.com"; then
                ((audit_sinks++))
            fi
        done
        
        if [[ $audit_sinks -gt 0 ]]; then
            record_result "monitoring" "audit_sinks" "pass" "Found $audit_sinks audit log sinks"
        else
            record_result "monitoring" "audit_sinks" "warn" "No audit log sinks found" "Enable audit log sinks for compliance"
        fi
    else
        record_result "monitoring" "log_sinks" "warn" "No log sinks found"
    fi
    
    # Check alert policies
    local alert_policies=$(gcloud monitoring alert-policies list --project="$PROJECT_ID" --format="json")
    local alert_count=$(echo "$alert_policies" | jq '. | length')
    
    if [[ $alert_count -gt 0 ]]; then
        record_result "monitoring" "alert_policies" "pass" "Found $alert_count alert policies"
    else
        record_result "monitoring" "alert_policies" "warn" "No alert policies found" "Set up alert policies for security monitoring"
    fi
}

# Calculate compliance scores
calculate_compliance_scores() {
    log "Calculating compliance scores..."
    
    local total_checks=0
    local passed_checks=0
    local warned_checks=0
    local failed_checks=0
    
    for result in "${!SECURITY_RESULTS[@]}"; do
        local status="${SECURITY_RESULTS[$result]}"
        ((total_checks++))
        
        case $status in
            "pass") ((passed_checks++)) ;;
            "warn") ((warned_checks++)) ;;
            "fail") ((failed_checks++)) ;;
        esac
    done
    
    local pass_percentage=$(echo "scale=2; $passed_checks * 100 / $total_checks" | bc 2>/dev/null || echo "0")
    local warn_percentage=$(echo "scale=2; $warned_checks * 100 / $total_checks" | bc 2>/dev/null || echo "0")
    local fail_percentage=$(echo "scale=2; $failed_checks * 100 / $total_checks" | bc 2>/dev/null || echo "0")
    
    COMPLIANCE_SCORES["total_checks"]="$total_checks"
    COMPLIANCE_SCORES["passed_checks"]="$passed_checks"
    COMPLIANCE_SCORES["warned_checks"]="$warned_checks"
    COMPLIANCE_SCORES["failed_checks"]="$failed_checks"
    COMPLIANCE_SCORES["pass_percentage"]="$pass_percentage"
    COMPLIANCE_SCORES["warn_percentage"]="$warn_percentage"
    COMPLIANCE_SCORES["fail_percentage"]="$fail_percentage"
}

# Generate console report
generate_console_report() {
    log "Generating console report..."
    
    echo
    echo "=========================================="
    echo "SECURITY AUDIT REPORT"
    echo "=========================================="
    echo "Project: $PROJECT_ID"
    echo "Environment: $ENVIRONMENT"
    echo "Region: $REGION"
    echo "Timestamp: $(date)"
    echo "=========================================="
    echo
    
    # Compliance summary
    echo "COMPLIANCE SUMMARY"
    echo "------------------"
    echo "Total Checks: ${COMPLIANCE_SCORES["total_checks"]:-0}"
    echo "Passed: ${COMPLIANCE_SCORES["passed_checks"]:-0} (${COMPLIANCE_SCORES["pass_percentage"]:-0}%)"
    echo "Warnings: ${COMPLIANCE_SCORES["warned_checks"]:-0} (${COMPLIANCE_SCORES["warn_percentage"]:-0}%)"
    echo "Failed: ${COMPLIANCE_SCORES["failed_checks"]:-0} (${COMPLIANCE_SCORES["fail_percentage"]:-0}%)"
    echo
    
    # Security recommendations
    if [[ ${#SECURITY_RECOMMENDATIONS[@]} -gt 0 ]]; then
        echo "SECURITY RECOMMENDATIONS"
        echo "------------------------"
        for recommendation in "${!SECURITY_RECOMMENDATIONS[@]}"; do
            echo "• ${SECURITY_RECOMMENDATIONS[$recommendation]}"
        done
        echo
    fi
    
    echo "=========================================="
    
    # Overall security rating
    local fail_percentage=${COMPLIANCE_SCORES["fail_percentage"]:-0}
    if (( $(echo "$fail_percentage == 0" | bc -l) )); then
        echo "✅ SECURITY RATING: EXCELLENT"
    elif (( $(echo "$fail_percentage < 10" | bc -l) )); then
        echo "⚠️  SECURITY RATING: GOOD"
    elif (( $(echo "$fail_percentage < 25" | bc -l) )); then
        echo "⚠️  SECURITY RATING: FAIR"
    else
        echo "❌ SECURITY RATING: POOR"
    fi
    echo "=========================================="
}

# Generate JSON report
generate_json_report() {
    local json_file="${REPORT_FILE}.json"
    
    log "Generating JSON report: $json_file"
    
    cat > "$json_file" << EOF
{
  "security_audit": {
    "project_id": "$PROJECT_ID",
    "environment": "$ENVIRONMENT",
    "region": "$REGION",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "compliance_scores": {
      "total_checks": ${COMPLIANCE_SCORES["total_checks"]:-0},
      "passed_checks": ${COMPLIANCE_SCORES["passed_checks"]:-0},
      "warned_checks": ${COMPLIANCE_SCORES["warned_checks"]:-0},
      "failed_checks": ${COMPLIANCE_SCORES["failed_checks"]:-0},
      "pass_percentage": ${COMPLIANCE_SCORES["pass_percentage"]:-0},
      "warn_percentage": ${COMPLIANCE_SCORES["warn_percentage"]:-0},
      "fail_percentage": ${COMPLIANCE_SCORES["fail_percentage"]:-0}
    },
    "results": {
EOF
    
    local first=true
    for result in "${!SECURITY_RESULTS[@]}"; do
        local status="${SECURITY_RESULTS[$result]}"
        local recommendation="${SECURITY_RECOMMENDATIONS[$result]:-}"
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo "," >> "$json_file"
        fi
        
        cat >> "$json_file" << EOF
      "$result": {
        "status": "$status",
        "recommendation": "$recommendation"
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
    <title>Security Audit Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .check { margin: 10px 0; padding: 10px; border-radius: 5px; }
        .pass { background-color: #d4edda; border-left: 5px solid #28a745; }
        .warn { background-color: #fff3cd; border-left: 5px solid #ffc107; }
        .fail { background-color: #f8d7da; border-left: 5px solid #dc3545; }
        .summary { background-color: #e9ecef; padding: 20px; border-radius: 5px; margin-top: 20px; }
        .recommendations { background-color: #d1ecf1; padding: 20px; border-radius: 5px; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Security Audit Report</h1>
        <p><strong>Project:</strong> $PROJECT_ID</p>
        <p><strong>Environment:</strong> $ENVIRONMENT</p>
        <p><strong>Region:</strong> $REGION</p>
        <p><strong>Timestamp:</strong> $(date)</p>
    </div>
    
    <div class="summary">
        <h2>Compliance Summary</h2>
        <p><strong>Total Checks:</strong> ${COMPLIANCE_SCORES["total_checks"]:-0}</p>
        <p><strong>Passed:</strong> ${COMPLIANCE_SCORES["passed_checks"]:-0} (${COMPLIANCE_SCORES["pass_percentage"]:-0}%)</p>
        <p><strong>Warnings:</strong> ${COMPLIANCE_SCORES["warned_checks"]:-0} (${COMPLIANCE_SCORES["warn_percentage"]:-0}%)</p>
        <p><strong>Failed:</strong> ${COMPLIANCE_SCORES["failed_checks"]:-0} (${COMPLIANCE_SCORES["fail_percentage"]:-0}%)</p>
    </div>
    
    <h2>Security Checks</h2>
EOF
    
    for result in "${!SECURITY_RESULTS[@]}"; do
        local status="${SECURITY_RESULTS[$result]}"
        local recommendation="${SECURITY_RECOMMENDATIONS[$result]:-}"
        
        case $status in
            "pass")
                echo "    <div class=\"check pass\">" >> "$html_file"
                echo "        <h3>✅ $result</h3>" >> "$html_file"
                echo "        <p>Status: PASSED</p>" >> "$html_file"
                ;;
            "warn")
                echo "    <div class=\"check warn\">" >> "$html_file"
                echo "        <h3>⚠️ $result</h3>" >> "$html_file"
                echo "        <p>Status: WARNING</p>" >> "$html_file"
                ;;
            "fail")
                echo "    <div class=\"check fail\">" >> "$html_file"
                echo "        <h3>❌ $result</h3>" >> "$html_file"
                echo "        <p>Status: FAILED</p>" >> "$html_file"
                ;;
        esac
        
        if [[ -n "$recommendation" ]]; then
            echo "        <p><strong>Recommendation:</strong> $recommendation</p>" >> "$html_file"
        fi
        echo "    </div>" >> "$html_file"
    done
    
    cat >> "$html_file" << EOF
    
    <div class="recommendations">
        <h2>Security Recommendations</h2>
        <ul>
EOF
    
    for recommendation in "${!SECURITY_RECOMMENDATIONS[@]}"; do
        echo "            <li>${SECURITY_RECOMMENDATIONS[$recommendation]}</li>" >> "$html_file"
    done
    
    cat >> "$html_file" << EOF
        </ul>
    </div>
</body>
</html>
EOF
    
    success "HTML report generated: $html_file"
}

# Main security audit function
run_security_audit() {
    log "Starting security audit..."
    log "Project: $PROJECT_ID, Environment: $ENVIRONMENT, Region: $REGION"
    
    # Run all security audits
    audit_iam_security
    audit_network_security
    audit_data_security
    audit_encryption_security
    audit_monitoring_security
    calculate_compliance_scores
    
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
    
    # Run security audit
    run_security_audit
}

# Run main function
main "$@"

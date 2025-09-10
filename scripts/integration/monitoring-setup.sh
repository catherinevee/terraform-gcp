#!/bin/bash
# Monitoring Setup Script
# This script sets up comprehensive monitoring and alerting for the terraform-gcp infrastructure

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
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"

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

Set up comprehensive monitoring and alerting for the terraform-gcp infrastructure.

OPTIONS:
    -p, --project-id PROJECT_ID    GCP Project ID (required)
    -e, --environment ENVIRONMENT  Environment (dev/staging/prod) [default: dev]
    -r, --region REGION           Primary GCP region [default: us-central1]
    -m, --email EMAIL             Notification email address
    -s, --slack-webhook URL       Slack webhook URL for notifications
    -h, --help                    Show this help message

EXAMPLES:
    $0 -p my-project -e dev -m admin@company.com
    $0 -p my-project -e prod -m admin@company.com -s https://hooks.slack.com/...

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
            -m|--email)
                NOTIFICATION_EMAIL="$2"
                shift 2
                ;;
            -s|--slack-webhook)
                SLACK_WEBHOOK_URL="$2"
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

# Create notification channels
create_notification_channels() {
    log "Creating notification channels..."
    
    # Create email notification channel
    if [[ -n "$NOTIFICATION_EMAIL" ]]; then
        local email_channel=$(gcloud monitoring notification-channels list \
            --project="$PROJECT_ID" \
            --filter="displayName:Email-$ENVIRONMENT" \
            --format="value(name)" 2>/dev/null || echo "")
        
        if [[ -z "$email_channel" ]]; then
            gcloud monitoring notification-channels create \
                --display-name="Email-$ENVIRONMENT" \
                --type=email \
                --channel-labels=email_address="$NOTIFICATION_EMAIL" \
                --project="$PROJECT_ID" >/dev/null 2>&1
            
            success "Email notification channel created"
        else
            info "Email notification channel already exists"
        fi
    fi
    
    # Create Slack notification channel
    if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
        local slack_channel=$(gcloud monitoring notification-channels list \
            --project="$PROJECT_ID" \
            --filter="displayName:Slack-$ENVIRONMENT" \
            --format="value(name)" 2>/dev/null || echo "")
        
        if [[ -z "$slack_channel" ]]; then
            gcloud monitoring notification-channels create \
                --display-name="Slack-$ENVIRONMENT" \
                --type=slack \
                --channel-labels=channel_name="#alerts" \
                --channel-labels=webhook_url="$SLACK_WEBHOOK_URL" \
                --project="$PROJECT_ID" >/dev/null 2>&1
            
            success "Slack notification channel created"
        else
            info "Slack notification channel already exists"
        fi
    fi
}

# Create uptime checks
create_uptime_checks() {
    log "Creating uptime checks..."
    
    # Get load balancer IP
    local lb_ip=$(gcloud compute forwarding-rules list \
        --project="$PROJECT_ID" \
        --filter="region:$REGION" \
        --format="value(IPAddress)" 2>/dev/null | head -1 || echo "")
    
    if [[ -n "$lb_ip" ]]; then
        # Create HTTP uptime check
        local http_check=$(gcloud monitoring uptime-checks list \
            --project="$PROJECT_ID" \
            --filter="displayName:HTTP-$ENVIRONMENT" \
            --format="value(name)" 2>/dev/null || echo "")
        
        if [[ -z "$http_check" ]]; then
            gcloud monitoring uptime-checks create http \
                --display-name="HTTP-$ENVIRONMENT" \
                --host="$lb_ip" \
                --path="/health" \
                --port=80 \
                --check-interval=60s \
                --timeout=10s \
                --project="$PROJECT_ID" >/dev/null 2>&1
            
            success "HTTP uptime check created"
        else
            info "HTTP uptime check already exists"
        fi
        
        # Create HTTPS uptime check
        local https_check=$(gcloud monitoring uptime-checks list \
            --project="$PROJECT_ID" \
            --filter="displayName:HTTPS-$ENVIRONMENT" \
            --format="value(name)" 2>/dev/null || echo "")
        
        if [[ -z "$https_check" ]]; then
            gcloud monitoring uptime-checks create http \
                --display-name="HTTPS-$ENVIRONMENT" \
                --host="$lb_ip" \
                --path="/health" \
                --port=443 \
                --use-ssl \
                --check-interval=60s \
                --timeout=10s \
                --project="$PROJECT_ID" >/dev/null 2>&1
            
            success "HTTPS uptime check created"
        else
            info "HTTPS uptime check already exists"
        fi
    else
        warning "No load balancer IP found, skipping uptime checks"
    fi
}

# Create alert policies
create_alert_policies() {
    log "Creating alert policies..."
    
    # Get notification channels
    local email_channel=$(gcloud monitoring notification-channels list \
        --project="$PROJECT_ID" \
        --filter="displayName:Email-$ENVIRONMENT" \
        --format="value(name)" 2>/dev/null || echo "")
    
    local slack_channel=$(gcloud monitoring notification-channels list \
        --project="$PROJECT_ID" \
        --filter="displayName:Slack-$ENVIRONMENT" \
        --format="value(name)" 2>/dev/null || echo "")
    
    local notification_channels=""
    if [[ -n "$email_channel" && -n "$slack_channel" ]]; then
        notification_channels="$email_channel,$slack_channel"
    elif [[ -n "$email_channel" ]]; then
        notification_channels="$email_channel"
    elif [[ -n "$slack_channel" ]]; then
        notification_channels="$slack_channel"
    fi
    
    if [[ -z "$notification_channels" ]]; then
        warning "No notification channels found, skipping alert policies"
        return
    fi
    
    # Create GKE cluster alert policies
    create_gke_alerts "$notification_channels"
    
    # Create Cloud SQL alert policies
    create_cloud_sql_alerts "$notification_channels"
    
    # Create Cloud Run alert policies
    create_cloud_run_alerts "$notification_channels"
    
    # Create network alert policies
    create_network_alerts "$notification_channels"
    
    # Create storage alert policies
    create_storage_alerts "$notification_channels"
    
    # Create cost alert policies
    create_cost_alerts "$notification_channels"
}

# Create GKE cluster alert policies
create_gke_alerts() {
    local notification_channels="$1"
    
    # GKE cluster CPU usage alert
    local cpu_alert=$(gcloud monitoring alert-policies list \
        --project="$PROJECT_ID" \
        --filter="displayName:GKE CPU Usage-$ENVIRONMENT" \
        --format="value(name)" 2>/dev/null || echo "")
    
    if [[ -z "$cpu_alert" ]]; then
        gcloud monitoring alert-policies create \
            --display-name="GKE CPU Usage-$ENVIRONMENT" \
            --condition-display-name="GKE CPU Usage" \
            --condition-filter="resource.type=\"k8s_cluster\" AND resource.labels.cluster_name=~\".*$ENVIRONMENT.*\"" \
            --condition-aggregation-alignment-period=300s \
            --condition-aggregation-per-series-aligner=ALIGN_MEAN \
            --condition-aggregation-cross-series-reducer=REDUCE_MEAN \
            --condition-comparison-comparison=COMPARISON_GREATER_THAN \
            --condition-comparison-threshold-value=80 \
            --condition-comparison-threshold-duration=300s \
            --notification-channels="$notification_channels" \
            --project="$PROJECT_ID" >/dev/null 2>&1
        
        success "GKE CPU usage alert created"
    else
        info "GKE CPU usage alert already exists"
    fi
    
    # GKE cluster memory usage alert
    local memory_alert=$(gcloud monitoring alert-policies list \
        --project="$PROJECT_ID" \
        --filter="displayName:GKE Memory Usage-$ENVIRONMENT" \
        --format="value(name)" 2>/dev/null || echo "")
    
    if [[ -z "$memory_alert" ]]; then
        gcloud monitoring alert-policies create \
            --display-name="GKE Memory Usage-$ENVIRONMENT" \
            --condition-display-name="GKE Memory Usage" \
            --condition-filter="resource.type=\"k8s_cluster\" AND resource.labels.cluster_name=~\".*$ENVIRONMENT.*\"" \
            --condition-aggregation-alignment-period=300s \
            --condition-aggregation-per-series-aligner=ALIGN_MEAN \
            --condition-aggregation-cross-series-reducer=REDUCE_MEAN \
            --condition-comparison-comparison=COMPARISON_GREATER_THAN \
            --condition-comparison-threshold-value=85 \
            --condition-comparison-threshold-duration=300s \
            --notification-channels="$notification_channels" \
            --project="$PROJECT_ID" >/dev/null 2>&1
        
        success "GKE memory usage alert created"
    else
        info "GKE memory usage alert already exists"
    fi
}

# Create Cloud SQL alert policies
create_cloud_sql_alerts() {
    local notification_channels="$1"
    
    # Cloud SQL CPU usage alert
    local sql_cpu_alert=$(gcloud monitoring alert-policies list \
        --project="$PROJECT_ID" \
        --filter="displayName:Cloud SQL CPU Usage-$ENVIRONMENT" \
        --format="value(name)" 2>/dev/null || echo "")
    
    if [[ -z "$sql_cpu_alert" ]]; then
        gcloud monitoring alert-policies create \
            --display-name="Cloud SQL CPU Usage-$ENVIRONMENT" \
            --condition-display-name="Cloud SQL CPU Usage" \
            --condition-filter="resource.type=\"cloudsql_database\" AND resource.labels.database_id=~\".*$ENVIRONMENT.*\"" \
            --condition-aggregation-alignment-period=300s \
            --condition-aggregation-per-series-aligner=ALIGN_MEAN \
            --condition-aggregation-cross-series-reducer=REDUCE_MEAN \
            --condition-comparison-comparison=COMPARISON_GREATER_THAN \
            --condition-comparison-threshold-value=80 \
            --condition-comparison-threshold-duration=300s \
            --notification-channels="$notification_channels" \
            --project="$PROJECT_ID" >/dev/null 2>&1
        
        success "Cloud SQL CPU usage alert created"
    else
        info "Cloud SQL CPU usage alert already exists"
    fi
    
    # Cloud SQL disk usage alert
    local sql_disk_alert=$(gcloud monitoring alert-policies list \
        --project="$PROJECT_ID" \
        --filter="displayName:Cloud SQL Disk Usage-$ENVIRONMENT" \
        --format="value(name)" 2>/dev/null || echo "")
    
    if [[ -z "$sql_disk_alert" ]]; then
        gcloud monitoring alert-policies create \
            --display-name="Cloud SQL Disk Usage-$ENVIRONMENT" \
            --condition-display-name="Cloud SQL Disk Usage" \
            --condition-filter="resource.type=\"cloudsql_database\" AND resource.labels.database_id=~\".*$ENVIRONMENT.*\"" \
            --condition-aggregation-alignment-period=300s \
            --condition-aggregation-per-series-aligner=ALIGN_MEAN \
            --condition-aggregation-cross-series-reducer=REDUCE_MEAN \
            --condition-comparison-comparison=COMPARISON_GREATER_THAN \
            --condition-comparison-threshold-value=90 \
            --condition-comparison-threshold-duration=300s \
            --notification-channels="$notification_channels" \
            --project="$PROJECT_ID" >/dev/null 2>&1
        
        success "Cloud SQL disk usage alert created"
    else
        info "Cloud SQL disk usage alert already exists"
    fi
}

# Create Cloud Run alert policies
create_cloud_run_alerts() {
    local notification_channels="$1"
    
    # Cloud Run error rate alert
    local run_error_alert=$(gcloud monitoring alert-policies list \
        --project="$PROJECT_ID" \
        --filter="displayName:Cloud Run Error Rate-$ENVIRONMENT" \
        --format="value(name)" 2>/dev/null || echo "")
    
    if [[ -z "$run_error_alert" ]]; then
        gcloud monitoring alert-policies create \
            --display-name="Cloud Run Error Rate-$ENVIRONMENT" \
            --condition-display-name="Cloud Run Error Rate" \
            --condition-filter="resource.type=\"cloud_run_revision\" AND resource.labels.service_name=~\".*$ENVIRONMENT.*\"" \
            --condition-aggregation-alignment-period=300s \
            --condition-aggregation-per-series-aligner=ALIGN_RATE \
            --condition-aggregation-cross-series-reducer=REDUCE_MEAN \
            --condition-comparison-comparison=COMPARISON_GREATER_THAN \
            --condition-comparison-threshold-value=0.05 \
            --condition-comparison-threshold-duration=300s \
            --notification-channels="$notification_channels" \
            --project="$PROJECT_ID" >/dev/null 2>&1
        
        success "Cloud Run error rate alert created"
    else
        info "Cloud Run error rate alert already exists"
    fi
}

# Create network alert policies
create_network_alerts() {
    local notification_channels="$1"
    
    # Network latency alert
    local latency_alert=$(gcloud monitoring alert-policies list \
        --project="$PROJECT_ID" \
        --filter="displayName:Network Latency-$ENVIRONMENT" \
        --format="value(name)" 2>/dev/null || echo "")
    
    if [[ -z "$latency_alert" ]]; then
        gcloud monitoring alert-policies create \
            --display-name="Network Latency-$ENVIRONMENT" \
            --condition-display-name="Network Latency" \
            --condition-filter="resource.type=\"gce_instance\" AND resource.labels.instance_name=~\".*$ENVIRONMENT.*\"" \
            --condition-aggregation-alignment-period=300s \
            --condition-aggregation-per-series-aligner=ALIGN_MEAN \
            --condition-aggregation-cross-series-reducer=REDUCE_MEAN \
            --condition-comparison-comparison=COMPARISON_GREATER_THAN \
            --condition-comparison-threshold-value=100 \
            --condition-comparison-threshold-duration=300s \
            --notification-channels="$notification_channels" \
            --project="$PROJECT_ID" >/dev/null 2>&1
        
        success "Network latency alert created"
    else
        info "Network latency alert already exists"
    fi
}

# Create storage alert policies
create_storage_alerts() {
    local notification_channels="$1"
    
    # Storage usage alert
    local storage_alert=$(gcloud monitoring alert-policies list \
        --project="$PROJECT_ID" \
        --filter="displayName:Storage Usage-$ENVIRONMENT" \
        --format="value(name)" 2>/dev/null || echo "")
    
    if [[ -z "$storage_alert" ]]; then
        gcloud monitoring alert-policies create \
            --display-name="Storage Usage-$ENVIRONMENT" \
            --condition-display-name="Storage Usage" \
            --condition-filter="resource.type=\"gcs_bucket\" AND resource.labels.bucket_name=~\".*$ENVIRONMENT.*\"" \
            --condition-aggregation-alignment-period=300s \
            --condition-aggregation-per-series-aligner=ALIGN_MEAN \
            --condition-aggregation-cross-series-reducer=REDUCE_MEAN \
            --condition-comparison-comparison=COMPARISON_GREATER_THAN \
            --condition-comparison-threshold-value=90 \
            --condition-comparison-threshold-duration=300s \
            --notification-channels="$notification_channels" \
            --project="$PROJECT_ID" >/dev/null 2>&1
        
        success "Storage usage alert created"
    else
        info "Storage usage alert already exists"
    fi
}

# Create cost alert policies
create_cost_alerts() {
    local notification_channels="$1"
    
    # Daily cost alert
    local cost_alert=$(gcloud monitoring alert-policies list \
        --project="$PROJECT_ID" \
        --filter="displayName:Daily Cost-$ENVIRONMENT" \
        --format="value(name)" 2>/dev/null || echo "")
    
    if [[ -z "$cost_alert" ]]; then
        # Set cost threshold based on environment
        local cost_threshold
        case "$ENVIRONMENT" in
            "dev") cost_threshold=100 ;;
            "staging") cost_threshold=200 ;;
            "prod") cost_threshold=500 ;;
            *) cost_threshold=100 ;;
        esac
        
        gcloud monitoring alert-policies create \
            --display-name="Daily Cost-$ENVIRONMENT" \
            --condition-display-name="Daily Cost" \
            --condition-filter="resource.type=\"billing_account\"" \
            --condition-aggregation-alignment-period=86400s \
            --condition-aggregation-per-series-aligner=ALIGN_SUM \
            --condition-aggregation-cross-series-reducer=REDUCE_SUM \
            --condition-comparison-comparison=COMPARISON_GREATER_THAN \
            --condition-comparison-threshold-value="$cost_threshold" \
            --condition-comparison-threshold-duration=86400s \
            --notification-channels="$notification_channels" \
            --project="$PROJECT_ID" >/dev/null 2>&1
        
        success "Daily cost alert created (threshold: \$$cost_threshold)"
    else
        info "Daily cost alert already exists"
    fi
}

# Create log sinks
create_log_sinks() {
    log "Creating log sinks..."
    
    # Create log sink for audit logs
    local audit_sink=$(gcloud logging sinks list \
        --project="$PROJECT_ID" \
        --filter="name:audit-logs-$ENVIRONMENT" \
        --format="value(name)" 2>/dev/null || echo "")
    
    if [[ -z "$audit_sink" ]]; then
        gcloud logging sinks create "audit-logs-$ENVIRONMENT" \
            "storage.googleapis.com/$PROJECT_ID-$ENVIRONMENT-audit-logs" \
            --log-filter="protoPayload.serviceName=\"cloudresourcemanager.googleapis.com\" OR protoPayload.serviceName=\"iam.googleapis.com\"" \
            --project="$PROJECT_ID" >/dev/null 2>&1
        
        success "Audit log sink created"
    else
        info "Audit log sink already exists"
    fi
    
    # Create log sink for application logs
    local app_sink=$(gcloud logging sinks list \
        --project="$PROJECT_ID" \
        --filter="name:app-logs-$ENVIRONMENT" \
        --format="value(name)" 2>/dev/null || echo "")
    
    if [[ -z "$app_sink" ]]; then
        gcloud logging sinks create "app-logs-$ENVIRONMENT" \
            "storage.googleapis.com/$PROJECT_ID-$ENVIRONMENT-app-logs" \
            --log-filter="resource.type=\"k8s_container\" OR resource.type=\"cloud_run_revision\"" \
            --project="$PROJECT_ID" >/dev/null 2>&1
        
        success "Application log sink created"
    else
        info "Application log sink already exists"
    fi
}

# Create dashboards
create_dashboards() {
    log "Creating monitoring dashboards..."
    
    # Create infrastructure dashboard
    local infra_dashboard=$(gcloud monitoring dashboards list \
        --project="$PROJECT_ID" \
        --filter="displayName:Infrastructure-$ENVIRONMENT" \
        --format="value(name)" 2>/dev/null || echo "")
    
    if [[ -z "$infra_dashboard" ]]; then
        cat > "/tmp/infrastructure-dashboard-$ENVIRONMENT.json" << EOF
{
  "displayName": "Infrastructure-$ENVIRONMENT",
  "mosaicLayout": {
    "tiles": [
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "GKE Cluster CPU Usage",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"k8s_cluster\" AND resource.labels.cluster_name=~\".*$ENVIRONMENT.*\"",
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "perSeriesAligner": "ALIGN_MEAN",
                      "crossSeriesReducer": "REDUCE_MEAN"
                    }
                  }
                }
              }
            ]
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "GKE Cluster Memory Usage",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"k8s_cluster\" AND resource.labels.cluster_name=~\".*$ENVIRONMENT.*\"",
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "perSeriesAligner": "ALIGN_MEAN",
                      "crossSeriesReducer": "REDUCE_MEAN"
                    }
                  }
                }
              }
            ]
          }
        }
      }
    ]
  }
}
EOF
        
        gcloud monitoring dashboards create \
            --config-from-file="/tmp/infrastructure-dashboard-$ENVIRONMENT.json" \
            --project="$PROJECT_ID" >/dev/null 2>&1
        
        rm -f "/tmp/infrastructure-dashboard-$ENVIRONMENT.json"
        
        success "Infrastructure dashboard created"
    else
        info "Infrastructure dashboard already exists"
    fi
}

# Main setup function
setup_monitoring() {
    log "Setting up monitoring and alerting for terraform-gcp infrastructure..."
    log "Project: $PROJECT_ID, Environment: $ENVIRONMENT, Region: $REGION"
    
    # Create monitoring components
    create_notification_channels
    create_uptime_checks
    create_alert_policies
    create_log_sinks
    create_dashboards
    
    success "Monitoring setup completed successfully!"
    
    echo
    echo "=========================================="
    echo "MONITORING SETUP COMPLETE"
    echo "=========================================="
    echo "Project ID: $PROJECT_ID"
    echo "Environment: $ENVIRONMENT"
    echo "Region: $REGION"
    echo
    echo "Components created:"
    echo "• Notification channels (Email, Slack)"
    echo "• Uptime checks (HTTP, HTTPS)"
    echo "• Alert policies (GKE, Cloud SQL, Cloud Run, Network, Storage, Cost)"
    echo "• Log sinks (Audit logs, Application logs)"
    echo "• Monitoring dashboards"
    echo
    echo "Next steps:"
    echo "1. Verify alert policies in Cloud Console"
    echo "2. Test notification channels"
    echo "3. Review and customize alert thresholds"
    echo "4. Set up additional dashboards as needed"
    echo "=========================================="
}

# Main execution
main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Validate prerequisites
    validate_prerequisites
    
    # Setup monitoring
    setup_monitoring
}

# Run main function
main "$@"

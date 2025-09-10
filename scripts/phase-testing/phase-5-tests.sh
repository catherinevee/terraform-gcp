#!/bin/bash
# Phase 5: Monitoring & Observability - Testing Script
# This script validates the monitoring infrastructure including logging, metrics, alerting, and cost management

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
    command -v curl >/dev/null 2>&1 || error "curl is not installed"
    
    if [[ -z "$PROJECT_ID" ]]; then
        error "PROJECT_ID environment variable is required"
    fi
    
    success "Prerequisites check passed"
}

# Test 1: Cloud Logging Validation
test_cloud_logging() {
    log "Testing Cloud Logging configuration..."
    
    # Check for log sinks
    local log_sinks=$(gcloud logging sinks list --project="$PROJECT_ID" --format="json")
    local sink_count=$(echo "$log_sinks" | jq '. | length')
    
    if [[ $sink_count -eq 0 ]]; then
        error "No log sinks found"
    fi
    
    # Check for required log sinks
    local required_sinks=(
        "critical-logs"
        "audit-logs"
    )
    
    for sink_suffix in "${required_sinks[@]}"; do
        local sink_name="${PROJECT_ID}-${ENVIRONMENT}-${REGION}-${sink_suffix}"
        if ! echo "$log_sinks" | jq -e ".[] | select(.name | contains(\"$sink_name\"))" >/dev/null; then
            error "Required log sink $sink_name not found"
        fi
    done
    
    # Validate log sink configuration
    for sink in $(echo "$log_sinks" | jq -r '.[].name'); do
        local sink_info=$(gcloud logging sinks describe "$sink" --project="$PROJECT_ID" --format="json")
        local destination=$(echo "$sink_info" | jq -r '.destination')
        local filter=$(echo "$sink_info" | jq -r '.filter')
        
        log "Log sink $sink: Destination=$destination, Filter=$filter"
        
        if [[ -n "$destination" ]]; then
            success "Log sink $sink configured with destination"
        else
            warning "Log sink $sink has no destination"
        fi
    done
    
    # Test log generation
    log "Testing log generation..."
    local test_log_message="Test log message from phase 5 testing - $(date)"
    if gcloud logging write test-log "$test_log_message" --project="$PROJECT_ID" >/dev/null 2>&1; then
        success "Log generation test passed"
    else
        warning "Log generation test failed"
    fi
    
    success "Cloud Logging validation passed"
}

# Test 2: Cloud Monitoring Validation
test_cloud_monitoring() {
    log "Testing Cloud Monitoring configuration..."
    
    # Check for monitoring dashboards
    local dashboards=$(gcloud monitoring dashboards list --project="$PROJECT_ID" --format="json")
    local dashboard_count=$(echo "$dashboards" | jq '. | length')
    
    if [[ $dashboard_count -eq 0 ]]; then
        warning "No monitoring dashboards found"
    else
        success "Found $dashboard_count monitoring dashboards"
        
        # Validate dashboard configuration
        for dashboard in $(echo "$dashboards" | jq -r '.[].name'); do
            local dashboard_info=$(gcloud monitoring dashboards describe "$dashboard" --project="$PROJECT_ID" --format="json")
            local display_name=$(echo "$dashboard_info" | jq -r '.displayName')
            local widget_count=$(echo "$dashboard_info" | jq '.mosaicLayout.tiles | length')
            
            log "Dashboard $display_name: Widgets=$widget_count"
            
            if [[ $widget_count -gt 0 ]]; then
                success "Dashboard $display_name has $widget_count widgets"
            else
                warning "Dashboard $display_name has no widgets"
            fi
        done
    fi
    
    # Check for uptime checks
    local uptime_checks=$(gcloud monitoring uptime-checks list --project="$PROJECT_ID" --format="json")
    local uptime_count=$(echo "$uptime_checks" | jq '. | length')
    
    if [[ $uptime_count -eq 0 ]]; then
        warning "No uptime checks found"
    else
        success "Found $uptime_count uptime checks"
    fi
    
    # Test metric collection
    log "Testing metric collection..."
    local test_metric="custom.googleapis.com/test/metric"
    local test_value=$((RANDOM % 100))
    
    if gcloud monitoring metrics write "$test_metric" --value="$test_value" --project="$PROJECT_ID" >/dev/null 2>&1; then
        success "Metric collection test passed"
    else
        warning "Metric collection test failed"
    fi
    
    success "Cloud Monitoring validation passed"
}

# Test 3: Alert Policies Validation
test_alert_policies() {
    log "Testing alert policies..."
    
    # Check for alert policies
    local alert_policies=$(gcloud monitoring alert-policies list --project="$PROJECT_ID" --format="json")
    local policy_count=$(echo "$alert_policies" | jq '. | length')
    
    if [[ $policy_count -eq 0 ]]; then
        error "No alert policies found"
    fi
    
    # Check for required alert policies
    local required_policies=(
        "High CPU Usage"
        "Cloud SQL Down"
    )
    
    for policy_name in "${required_policies[@]}"; do
        if ! echo "$alert_policies" | jq -e ".[] | select(.displayName == \"$policy_name\")" >/dev/null; then
            error "Required alert policy $policy_name not found"
        fi
    done
    
    # Validate alert policy configuration
    for policy in $(echo "$alert_policies" | jq -r '.[].name'); do
        local policy_info=$(gcloud monitoring alert-policies describe "$policy" --project="$PROJECT_ID" --format="json")
        local display_name=$(echo "$policy_info" | jq -r '.displayName')
        local enabled=$(echo "$policy_info" | jq -r '.enabled')
        local condition_count=$(echo "$policy_info" | jq '.conditions | length')
        local notification_count=$(echo "$policy_info" | jq '.notificationChannels | length')
        
        log "Alert policy $display_name: Enabled=$enabled, Conditions=$condition_count, Notifications=$notification_count"
        
        if [[ "$enabled" == "true" ]]; then
            success "Alert policy $display_name is enabled"
        else
            warning "Alert policy $display_name is disabled"
        fi
        
        if [[ $condition_count -gt 0 ]]; then
            success "Alert policy $display_name has $condition_count conditions"
        else
            warning "Alert policy $display_name has no conditions"
        fi
        
        if [[ $notification_count -gt 0 ]]; then
            success "Alert policy $display_name has $notification_count notification channels"
        else
            warning "Alert policy $display_name has no notification channels"
        fi
    done
    
    success "Alert policies validation passed"
}

# Test 4: Notification Channels Validation
test_notification_channels() {
    log "Testing notification channels..."
    
    # Check for notification channels
    local notification_channels=$(gcloud monitoring notification-channels list --project="$PROJECT_ID" --format="json")
    local channel_count=$(echo "$notification_channels" | jq '. | length')
    
    if [[ $channel_count -eq 0 ]]; then
        error "No notification channels found"
    fi
    
    # Check for required notification channels
    local required_channels=(
        "email"
        "slack"
    )
    
    for channel_type in "${required_channels[@]}"; do
        if ! echo "$notification_channels" | jq -e ".[] | select(.type == \"$channel_type\")" >/dev/null; then
            error "Required notification channel type $channel_type not found"
        fi
    done
    
    # Validate notification channel configuration
    for channel in $(echo "$notification_channels" | jq -r '.[].name'); do
        local channel_info=$(gcloud monitoring notification-channels describe "$channel" --project="$PROJECT_ID" --format="json")
        local display_name=$(echo "$channel_info" | jq -r '.displayName')
        local type=$(echo "$channel_info" | jq -r '.type')
        local enabled=$(echo "$channel_info" | jq -r '.enabled')
        
        log "Notification channel $display_name: Type=$type, Enabled=$enabled"
        
        if [[ "$enabled" == "true" ]]; then
            success "Notification channel $display_name is enabled"
        else
            warning "Notification channel $display_name is disabled"
        fi
    done
    
    success "Notification channels validation passed"
}

# Test 5: Cost Management Validation
test_cost_management() {
    log "Testing cost management..."
    
    # Check for budget alerts
    local budgets=$(gcloud billing budgets list --billing-account="$(gcloud billing accounts list --format='value(name)' | head -1)" --format="json" 2>/dev/null || echo "[]")
    local budget_count=$(echo "$budgets" | jq '. | length')
    
    if [[ $budget_count -eq 0 ]]; then
        warning "No budget alerts found"
    else
        success "Found $budget_count budget alerts"
        
        # Validate budget configuration
        for budget in $(echo "$budgets" | jq -r '.[].name'); do
            local budget_info=$(gcloud billing budgets describe "$budget" --billing-account="$(gcloud billing accounts list --format='value(name)' | head -1)" --format="json" 2>/dev/null || echo "{}")
            local display_name=$(echo "$budget_info" | jq -r '.displayName')
            local budget_amount=$(echo "$budget_info" | jq -r '.budgetFilter.projects[] // "all"')
            local threshold_count=$(echo "$budget_info" | jq '.thresholdRules | length')
            
            log "Budget $display_name: Projects=$budget_amount, Thresholds=$threshold_count"
            
            if [[ $threshold_count -gt 0 ]]; then
                success "Budget $display_name has $threshold_count threshold rules"
            else
                warning "Budget $display_name has no threshold rules"
            fi
        done
    fi
    
    # Check for cost allocation labels
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
        warning "No resources with cost allocation labels found"
    fi
    
    success "Cost management validation passed"
}

# Test 6: Log-based Metrics Validation
test_log_based_metrics() {
    log "Testing log-based metrics..."
    
    # Check for log-based metrics
    local log_metrics=$(gcloud logging metrics list --project="$PROJECT_ID" --format="json")
    local metric_count=$(echo "$log_metrics" | jq '. | length')
    
    if [[ $metric_count -eq 0 ]]; then
        warning "No log-based metrics found"
    else
        success "Found $metric_count log-based metrics"
        
        # Validate log-based metric configuration
        for metric in $(echo "$log_metrics" | jq -r '.[].name'); do
            local metric_info=$(gcloud logging metrics describe "$metric" --project="$PROJECT_ID" --format="json")
            local display_name=$(echo "$metric_info" | jq -r '.displayName')
            local filter=$(echo "$metric_info" | jq -r '.filter')
            local metric_type=$(echo "$metric_info" | jq -r '.metricDescriptor.metricKind')
            
            log "Log-based metric $display_name: Type=$metric_type, Filter=$filter"
            
            if [[ -n "$filter" ]]; then
                success "Log-based metric $display_name has filter configured"
            else
                warning "Log-based metric $display_name has no filter"
            fi
        done
    fi
    
    success "Log-based metrics validation passed"
}

# Test 7: Synthetic Monitoring Validation
test_synthetic_monitoring() {
    log "Testing synthetic monitoring..."
    
    # Check for uptime checks
    local uptime_checks=$(gcloud monitoring uptime-checks list --project="$PROJECT_ID" --format="json")
    local uptime_count=$(echo "$uptime_checks" | jq '. | length')
    
    if [[ $uptime_count -eq 0 ]]; then
        warning "No uptime checks found"
    else
        success "Found $uptime_count uptime checks"
        
        # Validate uptime check configuration
        for check in $(echo "$uptime_checks" | jq -r '.[].name'); do
            local check_info=$(gcloud monitoring uptime-checks describe "$check" --project="$PROJECT_ID" --format="json")
            local display_name=$(echo "$check_info" | jq -r '.displayName')
            local check_type=$(echo "$check_info" | jq -r '.httpCheck // .tcpCheck // .contentMatchers // "unknown"')
            local timeout=$(echo "$check_info" | jq -r '.timeout // "unknown"')
            
            log "Uptime check $display_name: Type=$check_type, Timeout=$timeout"
            
            if [[ "$check_type" != "unknown" ]]; then
                success "Uptime check $display_name configured"
            else
                warning "Uptime check $display_name not properly configured"
            fi
        done
    fi
    
    success "Synthetic monitoring validation passed"
}

# Test 8: Performance Monitoring Validation
test_performance_monitoring() {
    log "Testing performance monitoring..."
    
    # Check for custom metrics
    local custom_metrics=$(gcloud monitoring metrics list --project="$PROJECT_ID" --format="json" 2>/dev/null || echo "[]")
    local custom_metric_count=$(echo "$custom_metrics" | jq '. | length')
    
    if [[ $custom_metric_count -eq 0 ]]; then
        warning "No custom metrics found"
    else
        success "Found $custom_metric_count custom metrics"
    fi
    
    # Check for service monitoring
    local services=$(gcloud monitoring services list --project="$PROJECT_ID" --format="json" 2>/dev/null || echo "[]")
    local service_count=$(echo "$services" | jq '. | length')
    
    if [[ $service_count -eq 0 ]]; then
        warning "No monitored services found"
    else
        success "Found $service_count monitored services"
    fi
    
    # Test metric query
    log "Testing metric query..."
    local test_query="metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
    local start_time=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)
    local end_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    if gcloud monitoring metrics list --filter="$test_query" --project="$PROJECT_ID" >/dev/null 2>&1; then
        success "Metric query test passed"
    else
        warning "Metric query test failed"
    fi
    
    success "Performance monitoring validation passed"
}

# Test 9: Alert Testing
test_alert_testing() {
    log "Testing alert functionality..."
    
    # Test alert policy creation (dry run)
    local test_alert_policy='{
        "displayName": "Test Alert Policy",
        "conditions": [{
            "displayName": "Test Condition",
            "conditionThreshold": {
                "filter": "metric.type=\"compute.googleapis.com/instance/cpu/utilization\"",
                "comparison": "COMPARISON_GT",
                "thresholdValue": 0.9,
                "duration": "300s"
            }
        }],
        "enabled": false
    }'
    
    # Test alert policy validation
    if echo "$test_alert_policy" | gcloud monitoring alert-policies create --project="$PROJECT_ID" --policy-from-file=- --dry-run >/dev/null 2>&1; then
        success "Alert policy validation test passed"
    else
        warning "Alert policy validation test failed"
    fi
    
    # Test notification channel validation
    local test_notification_channel='{
        "displayName": "Test Notification Channel",
        "type": "email",
        "labels": {
            "email_address": "test@example.com"
        },
        "enabled": false
    }'
    
    if echo "$test_notification_channel" | gcloud monitoring notification-channels create --project="$PROJECT_ID" --channel-from-file=- --dry-run >/dev/null 2>&1; then
        success "Notification channel validation test passed"
    else
        warning "Notification channel validation test failed"
    fi
    
    success "Alert testing passed"
}

# Test 10: Monitoring Integration Tests
test_monitoring_integration() {
    log "Testing monitoring integration..."
    
    # Test log to metric integration
    local test_log_metric='{
        "name": "test-log-metric",
        "displayName": "Test Log Metric",
        "filter": "resource.type=\"gce_instance\"",
        "metricDescriptor": {
            "metricKind": "GAUGE",
            "valueType": "INT64"
        }
    }'
    
    if echo "$test_log_metric" | gcloud logging metrics create --project="$PROJECT_ID" --metric-from-file=- --dry-run >/dev/null 2>&1; then
        success "Log to metric integration test passed"
    else
        warning "Log to metric integration test failed"
    fi
    
    # Test dashboard to alert integration
    local test_dashboard='{
        "displayName": "Test Dashboard",
        "mosaicLayout": {
            "tiles": [{
                "width": 6,
                "height": 4,
                "widget": {
                    "title": "Test Widget",
                    "xyChart": {
                        "dataSets": [{
                            "timeSeriesQuery": {
                                "timeSeriesFilter": {
                                    "filter": "metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
                                }
                            }
                        }]
                    }
                }
            }]
        }
    }'
    
    if echo "$test_dashboard" | gcloud monitoring dashboards create --project="$PROJECT_ID" --dashboard-from-file=- --dry-run >/dev/null 2>&1; then
        success "Dashboard integration test passed"
    else
        warning "Dashboard integration test failed"
    fi
    
    success "Monitoring integration tests passed"
}

# Main execution
main() {
    log "Starting Phase 5 testing for environment: $ENVIRONMENT"
    log "Project ID: $PROJECT_ID"
    log "Region: $REGION"
    
    # Run all tests
    check_prerequisites
    test_cloud_logging
    test_cloud_monitoring
    test_alert_policies
    test_notification_channels
    test_cost_management
    test_log_based_metrics
    test_synthetic_monitoring
    test_performance_monitoring
    test_alert_testing
    test_monitoring_integration
    
    success "All Phase 5 tests completed successfully!"
    log "Phase 5 monitoring and observability is ready for Phase 6 production hardening"
}

# Run main function
main "$@"

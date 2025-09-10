#!/bin/bash
# Comprehensive Phase Testing Script
# This script runs all phase tests in sequence and generates a comprehensive report

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
REPORT_DIR="${REPORT_DIR:-./test-reports}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

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

# Initialize test environment
init_test_environment() {
    log "Initializing test environment..."
    
    # Create report directory
    mkdir -p "$REPORT_DIR"
    
    # Set up environment variables
    export PROJECT_ID="$PROJECT_ID"
    export ENVIRONMENT="$ENVIRONMENT"
    export REGION="$REGION"
    
    # Create test report file
    local report_file="$REPORT_DIR/phase-test-report-$TIMESTAMP.md"
    echo "# Phase Testing Report" > "$report_file"
    echo "Generated: $(date)" >> "$report_file"
    echo "Project: $PROJECT_ID" >> "$report_file"
    echo "Environment: $ENVIRONMENT" >> "$report_file"
    echo "Region: $REGION" >> "$report_file"
    echo "" >> "$report_file"
    
    success "Test environment initialized"
}

# Run phase tests
run_phase_tests() {
    local phase="$1"
    local test_script="scripts/phase-testing/phase-${phase}-tests.sh"
    local report_file="$REPORT_DIR/phase-test-report-$TIMESTAMP.md"
    local phase_report="$REPORT_DIR/phase-${phase}-report-$TIMESTAMP.log"
    
    log "Running Phase $phase tests..."
    
    # Add phase header to report
    echo "## Phase $phase Test Results" >> "$report_file"
    echo "Started: $(date)" >> "$report_file"
    echo "" >> "$report_file"
    
    # Run the test script
    if [[ -f "$test_script" ]]; then
        if bash "$test_script" 2>&1 | tee "$phase_report"; then
            success "Phase $phase tests completed successfully"
            echo "✅ **PASSED** - All Phase $phase tests completed successfully" >> "$report_file"
        else
            error "Phase $phase tests failed"
            echo "❌ **FAILED** - Phase $phase tests failed" >> "$report_file"
            echo "See detailed log: $phase_report" >> "$report_file"
            return 1
        fi
    else
        error "Test script $test_script not found"
        echo "❌ **ERROR** - Test script not found: $test_script" >> "$report_file"
        return 1
    fi
    
    echo "Completed: $(date)" >> "$report_file"
    echo "" >> "$report_file"
}

# Generate comprehensive report
generate_report() {
    local report_file="$REPORT_DIR/phase-test-report-$TIMESTAMP.md"
    
    log "Generating comprehensive test report..."
    
    # Add summary section
    echo "## Test Summary" >> "$report_file"
    echo "Total Phases Tested: 6" >> "$report_file"
    echo "Test Duration: $(date)" >> "$report_file"
    echo "" >> "$report_file"
    
    # Add test artifacts section
    echo "## Test Artifacts" >> "$report_file"
    echo "All test logs and reports are available in: $REPORT_DIR" >> "$report_file"
    echo "" >> "$report_file"
    
    # Add next steps section
    echo "## Next Steps" >> "$report_file"
    echo "1. Review any failed tests and address issues" >> "$report_file"
    echo "2. Proceed to next phase if all tests pass" >> "$report_file"
    echo "3. Update documentation based on test results" >> "$report_file"
    echo "" >> "$report_file"
    
    success "Test report generated: $report_file"
}

# Cleanup function
cleanup() {
    log "Cleaning up test environment..."
    
    # Remove temporary files if any
    rm -f /tmp/terraform-test-*
    
    success "Cleanup completed"
}

# Main execution
main() {
    log "Starting comprehensive phase testing..."
    log "Project ID: $PROJECT_ID"
    log "Environment: $ENVIRONMENT"
    log "Region: $REGION"
    
    # Check prerequisites
    if [[ -z "$PROJECT_ID" ]]; then
        error "PROJECT_ID environment variable is required"
        exit 1
    fi
    
    # Initialize test environment
    init_test_environment
    
    # Track overall success
    local overall_success=true
    
    # Run all phase tests
    local phases=("0" "1" "2" "3" "4" "5" "6")
    
    for phase in "${phases[@]}"; do
        info "=== Starting Phase $phase Tests ==="
        
        if ! run_phase_tests "$phase"; then
            overall_success=false
            warning "Phase $phase tests failed, but continuing with remaining phases"
        fi
        
        info "=== Phase $phase Tests Complete ==="
        echo ""
    done
    
    # Generate final report
    generate_report
    
    # Cleanup
    cleanup
    
    # Final status
    if [[ "$overall_success" == "true" ]]; then
        success "All phase tests completed successfully!"
        info "Check the test report for detailed results: $REPORT_DIR/phase-test-report-$TIMESTAMP.md"
    else
        warning "Some phase tests failed. Check the test report for details: $REPORT_DIR/phase-test-report-$TIMESTAMP.md"
        exit 1
    fi
}

# Trap for cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"

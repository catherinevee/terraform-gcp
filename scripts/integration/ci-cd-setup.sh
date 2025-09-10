#!/bin/bash
# CI/CD Setup Script
# This script sets up GitHub Actions workflows for the terraform-gcp infrastructure

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
GITHUB_REPO="${GITHUB_REPO:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

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

Set up CI/CD workflows for the terraform-gcp infrastructure.

OPTIONS:
    -p, --project-id PROJECT_ID    GCP Project ID (required)
    -e, --environment ENVIRONMENT  Environment (dev/staging/prod) [default: dev]
    -r, --region REGION           Primary GCP region [default: us-central1]
    -g, --github-repo REPO        GitHub repository (owner/repo) [required]
    -t, --github-token TOKEN      GitHub token for API access [required]
    -h, --help                    Show this help message

EXAMPLES:
    $0 -p my-project -g owner/repo -t ghp_xxxxx
    $0 -p my-project -e staging -g owner/repo -t ghp_xxxxx

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
            -g|--github-repo)
                GITHUB_REPO="$2"
                shift 2
                ;;
            -t|--github-token)
                GITHUB_TOKEN="$2"
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
    
    if [[ -z "$GITHUB_REPO" ]]; then
        error "GITHUB_REPO is required. Use -g or --github-repo"
    fi
    
    if [[ -z "$GITHUB_TOKEN" ]]; then
        error "GITHUB_TOKEN is required. Use -t or --github-token"
    fi
    
    # Check required tools
    command -v gh >/dev/null 2>&1 || error "GitHub CLI (gh) is not installed"
    command -v jq >/dev/null 2>&1 || error "jq is not installed"
    command -v gcloud >/dev/null 2>&1 || error "gcloud CLI is not installed"
    
    # Check GitHub authentication
    if ! gh auth status >/dev/null 2>&1; then
        error "GitHub CLI not authenticated. Run 'gh auth login'"
    fi
    
    # Check GCP authentication
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        error "No active GCP authentication found. Run 'gcloud auth login'"
    fi
    
    success "Prerequisites validation passed"
}

# Create GitHub Actions workflows directory
create_workflows_directory() {
    log "Creating GitHub Actions workflows directory..."
    
    mkdir -p .github/workflows
    
    success "Workflows directory created"
}

# Create terraform plan workflow
create_terraform_plan_workflow() {
    log "Creating Terraform plan workflow..."
    
    cat > .github/workflows/terraform-plan.yml << EOF
name: Terraform Plan

on:
  pull_request:
    branches: [ main, develop ]
    paths:
      - 'infrastructure/**'
      - '.github/workflows/terraform-plan.yml'
  workflow_dispatch:

env:
  TF_VERSION: '1.5.0'
  TF_VAR_project_id: \${{ secrets.GCP_PROJECT_ID }}
  TF_VAR_region: '$REGION'

jobs:
  terraform-plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        environment: [dev, staging, prod]
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: \${{ env.TF_VERSION }}
    
    - name: Setup Google Cloud CLI
      uses: google-github-actions/setup-gcloud@v2
      with:
        service_account_key: \${{ secrets.GCP_SA_KEY }}
        project_id: \${{ env.TF_VAR_project_id }}
    
    - name: Authenticate to Google Cloud
      uses: google-github-actions/auth@v2
      with:
        credentials_json: \${{ secrets.GCP_SA_KEY }}
    
    - name: Configure gcloud
      run: |
        gcloud config set project \${{ env.TF_VAR_project_id }}
        gcloud config set compute/region $REGION
    
    - name: Terraform Format Check
      run: |
        cd infrastructure/environments/\${{ matrix.environment }}
        terraform fmt -check -recursive
    
    - name: Terraform Init
      run: |
        cd infrastructure/environments/\${{ matrix.environment }}
        terraform init -backend=false
    
    - name: Terraform Validate
      run: |
        cd infrastructure/environments/\${{ matrix.environment }}
        terraform validate
    
    - name: Terraform Plan
      run: |
        cd infrastructure/environments/\${{ matrix.environment }}
        terraform plan -var-file=terraform.tfvars -out=tfplan-\${{ matrix.environment }}
      env:
        TF_VAR_environment: \${{ matrix.environment }}
    
    - name: Upload Terraform Plan
      uses: actions/upload-artifact@v4
      with:
        name: terraform-plan-\${{ matrix.environment }}
        path: infrastructure/environments/\${{ matrix.environment }}/tfplan-\${{ matrix.environment }}
        retention-days: 1
    
    - name: Comment PR with Plan
      if: github.event_name == 'pull_request'
      uses: actions/github-script@v7
      with:
        script: |
          const fs = require('fs');
          const path = require('path');
          
          try {
            const planPath = path.join('infrastructure/environments/\${{ matrix.environment }}', 'tfplan-\${{ matrix.environment }}');
            if (fs.existsSync(planPath)) {
              const plan = fs.readFileSync(planPath, 'utf8');
              const output = \`## Terraform Plan - \${{ matrix.environment }}
              
              \`\`\`hcl
              \${plan}
              \`\`\`
              \`;
              
              github.rest.issues.createComment({
                issue_number: context.issue.number,
                owner: context.repo.owner,
                repo: context.repo.repo,
                body: output
              });
            }
          } catch (error) {
            console.error('Error commenting PR:', error);
          }
EOF
    
    success "Terraform plan workflow created"
}

# Create terraform apply workflow
create_terraform_apply_workflow() {
    log "Creating Terraform apply workflow..."
    
    cat > .github/workflows/terraform-apply.yml << EOF
name: Terraform Apply

on:
  push:
    branches: [ main ]
    paths:
      - 'infrastructure/**'
      - '.github/workflows/terraform-apply.yml'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        default: 'dev'
        type: choice
        options:
        - dev
        - staging
        - prod
      phase:
        description: 'Phase to deploy (0-6)'
        required: true
        default: '0'
        type: choice
        options:
        - '0'
        - '1'
        - '2'
        - '3'
        - '4'
        - '5'
        - '6'

env:
  TF_VERSION: '1.5.0'
  TF_VAR_project_id: \${{ secrets.GCP_PROJECT_ID }}
  TF_VAR_region: '$REGION'

jobs:
  terraform-apply:
    name: Terraform Apply
    runs-on: ubuntu-latest
    environment: \${{ github.event.inputs.environment || 'dev' }}
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: \${{ env.TF_VERSION }}
    
    - name: Setup Google Cloud CLI
      uses: google-github-actions/setup-gcloud@v2
      with:
        service_account_key: \${{ secrets.GCP_SA_KEY }}
        project_id: \${{ env.TF_VAR_project_id }}
    
    - name: Authenticate to Google Cloud
      uses: google-github-actions/auth@v2
      with:
        credentials_json: \${{ secrets.GCP_SA_KEY }}
    
    - name: Configure gcloud
      run: |
        gcloud config set project \${{ env.TF_VAR_project_id }}
        gcloud config set compute/region $REGION
    
    - name: Download Terraform Plan
      uses: actions/download-artifact@v4
      with:
        name: terraform-plan-\${{ github.event.inputs.environment || 'dev' }}
        path: infrastructure/environments/\${{ github.event.inputs.environment || 'dev' }}/
    
    - name: Terraform Init
      run: |
        cd infrastructure/environments/\${{ github.event.inputs.environment || 'dev' }}
        terraform init
    
    - name: Terraform Apply
      run: |
        cd infrastructure/environments/\${{ github.event.inputs.environment || 'dev' }}
        terraform apply -auto-approve tfplan-\${{ github.event.inputs.environment || 'dev' }}
      env:
        TF_VAR_environment: \${{ github.event.inputs.environment || 'dev' }}
    
    - name: Run Phase Tests
      run: |
        chmod +x scripts/phase-testing/*.sh
        ./scripts/phase-testing/phase-\${{ github.event.inputs.phase || '0' }}-tests.sh
      env:
        PROJECT_ID: \${{ env.TF_VAR_project_id }}
        ENVIRONMENT: \${{ github.event.inputs.environment || 'dev' }}
        REGION: $REGION
    
    - name: Run Health Check
      run: |
        chmod +x scripts/automation/health-check.sh
        ./scripts/automation/health-check.sh -p \${{ env.TF_VAR_project_id }} -e \${{ github.event.inputs.environment || 'dev' }} -f json -o health-check-\${{ github.event.inputs.environment || 'dev' }}.json
      env:
        PROJECT_ID: \${{ env.TF_VAR_project_id }}
        ENVIRONMENT: \${{ github.event.inputs.environment || 'dev' }}
        REGION: $REGION
    
    - name: Upload Health Check Report
      uses: actions/upload-artifact@v4
      with:
        name: health-check-\${{ github.event.inputs.environment || 'dev' }}
        path: health-check-\${{ github.event.inputs.environment || 'dev' }}.json
        retention-days: 30
    
    - name: Notify Deployment Success
      if: success()
      uses: actions/github-script@v7
      with:
        script: |
          github.rest.repos.createCommitStatus({
            owner: context.repo.owner,
            repo: context.repo.repo,
            sha: context.sha,
            state: 'success',
            description: 'Terraform apply completed successfully',
            context: 'terraform-apply-\${{ github.event.inputs.environment || 'dev' }}'
          });
    
    - name: Notify Deployment Failure
      if: failure()
      uses: actions/github-script@v7
      with:
        script: |
          github.rest.repos.createCommitStatus({
            owner: context.repo.owner,
            repo: context.repo.repo,
            sha: context.sha,
            state: 'failure',
            description: 'Terraform apply failed',
            context: 'terraform-apply-\${{ github.event.inputs.environment || 'dev' }}'
          });
EOF
    
    success "Terraform apply workflow created"
}

# Create security scan workflow
create_security_scan_workflow() {
    log "Creating security scan workflow..."
    
    cat > .github/workflows/security-scan.yml << EOF
name: Security Scan

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]
  schedule:
    - cron: '0 2 * * 1' # Weekly on Monday at 2 AM
  workflow_dispatch:

env:
  TF_VERSION: '1.5.0'
  TF_VAR_project_id: \${{ secrets.GCP_PROJECT_ID }}
  TF_VAR_region: '$REGION'

jobs:
  security-scan:
    name: Security Scan
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        environment: [dev, staging, prod]
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: \${{ env.TF_VERSION }}
    
    - name: Setup Google Cloud CLI
      uses: google-github-actions/setup-gcloud@v2
      with:
        service_account_key: \${{ secrets.GCP_SA_KEY }}
        project_id: \${{ env.TF_VAR_project_id }}
    
    - name: Authenticate to Google Cloud
      uses: google-github-actions/auth@v2
      with:
        credentials_json: \${{ secrets.GCP_SA_KEY }}
    
    - name: Configure gcloud
      run: |
        gcloud config set project \${{ env.TF_VAR_project_id }}
        gcloud config set compute/region $REGION
    
    - name: Run Security Audit
      run: |
        chmod +x scripts/utilities/security-audit.sh
        ./scripts/utilities/security-audit.sh -p \${{ env.TF_VAR_project_id }} -e \${{ matrix.environment }} -f json -o security-audit-\${{ matrix.environment }}.json
      env:
        PROJECT_ID: \${{ env.TF_VAR_project_id }}
        ENVIRONMENT: \${{ matrix.environment }}
        REGION: $REGION
    
    - name: Upload Security Audit Report
      uses: actions/upload-artifact@v4
      with:
        name: security-audit-\${{ matrix.environment }}
        path: security-audit-\${{ matrix.environment }}.json
        retention-days: 90
    
    - name: Check Security Score
      run: |
        SECURITY_SCORE=\$(jq -r '.security_audit.compliance_scores.pass_percentage' security-audit-\${{ matrix.environment }}.json)
        echo "Security score for \${{ matrix.environment }}: \$SECURITY_SCORE%"
        
        if (( \$(echo "\$SECURITY_SCORE < 90" | bc -l) )); then
          echo "Security score below threshold (90%)"
          exit 1
        fi
    
    - name: Comment PR with Security Results
      if: github.event_name == 'pull_request'
      uses: actions/github-script@v7
      with:
        script: |
          const fs = require('fs');
          
          try {
            const reportPath = 'security-audit-\${{ matrix.environment }}.json';
            if (fs.existsSync(reportPath)) {
              const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
              const scores = report.security_audit.compliance_scores;
              
              const output = \`## Security Scan Results - \${{ matrix.environment }}
              
              **Compliance Score:** \${scores.pass_percentage}%
              
              - **Passed:** \${scores.passed_checks}
              - **Warnings:** \${scores.warned_checks}
              - **Failed:** \${scores.failed_checks}
              - **Total Checks:** \${scores.total_checks}
              
              \${scores.pass_percentage < 90 ? '⚠️ **Security score below threshold (90%)**' : '✅ **Security score meets requirements**'}
              \`;
              
              github.rest.issues.createComment({
                issue_number: context.issue.number,
                owner: context.repo.owner,
                repo: context.repo.repo,
                body: output
              });
            }
          } catch (error) {
            console.error('Error commenting PR:', error);
          }
EOF
    
    success "Security scan workflow created"
}

# Create cost analysis workflow
create_cost_analysis_workflow() {
    log "Creating cost analysis workflow..."
    
    cat > .github/workflows/cost-analysis.yml << EOF
name: Cost Analysis

on:
  schedule:
    - cron: '0 9 1 * *' # Monthly on the 1st at 9 AM
  workflow_dispatch:

env:
  TF_VERSION: '1.5.0'
  TF_VAR_project_id: \${{ secrets.GCP_PROJECT_ID }}
  TF_VAR_region: '$REGION'

jobs:
  cost-analysis:
    name: Cost Analysis
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        environment: [dev, staging, prod]
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Setup Google Cloud CLI
      uses: google-github-actions/setup-gcloud@v2
      with:
        service_account_key: \${{ secrets.GCP_SA_KEY }}
        project_id: \${{ env.TF_VAR_project_id }}
    
    - name: Authenticate to Google Cloud
      uses: google-github-actions/auth@v2
      with:
        credentials_json: \${{ secrets.GCP_SA_KEY }}
    
    - name: Configure gcloud
      run: |
        gcloud config set project \${{ env.TF_VAR_project_id }}
        gcloud config set compute/region $REGION
    
    - name: Run Cost Analysis
      run: |
        chmod +x scripts/utilities/cost-analyzer.sh
        ./scripts/utilities/cost-analyzer.sh -p \${{ env.TF_VAR_project_id }} -e \${{ matrix.environment }} -f json -o cost-analysis-\${{ matrix.environment }}.json
      env:
        PROJECT_ID: \${{ env.TF_VAR_project_id }}
        ENVIRONMENT: \${{ matrix.environment }}
        REGION: $REGION
    
    - name: Upload Cost Analysis Report
      uses: actions/upload-artifact@v4
      with:
        name: cost-analysis-\${{ matrix.environment }}
        path: cost-analysis-\${{ matrix.environment }}.json
        retention-days: 365
    
    - name: Check Cost Threshold
      run: |
        TOTAL_COST=\$(jq -r '.cost_analysis.cost_estimates.total_estimated_cost' cost-analysis-\${{ matrix.environment }}.json)
        echo "Total estimated cost for \${{ matrix.environment }}: \$$TOTAL_COST"
        
        # Set cost threshold based on environment
        case "\${{ matrix.environment }}" in
          "dev") THRESHOLD=500 ;;
          "staging") THRESHOLD=1000 ;;
          "prod") THRESHOLD=5000 ;;
        esac
        
        if (( \$(echo "\$TOTAL_COST > \$THRESHOLD" | bc -l) )); then
          echo "Cost exceeds threshold (\$$THRESHOLD)"
          exit 1
        fi
    
    - name: Create Cost Report Issue
      if: github.event_name == 'schedule'
      uses: actions/github-script@v7
      with:
        script: |
          const fs = require('fs');
          
          try {
            const reportPath = 'cost-analysis-\${{ matrix.environment }}.json';
            if (fs.existsSync(reportPath)) {
              const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
              const costs = report.cost_analysis.cost_estimates;
              
              const output = \`## Monthly Cost Analysis - \${{ matrix.environment }}
              
              **Total Estimated Cost:** \$${costs.total_estimated_cost}
              
              ### Cost Breakdown:
              - **GKE:** \$${costs.gke_total_cost}
              - **Cloud SQL:** \$${costs.sql_total_cost}
              - **Storage:** \$${costs.storage_cost}
              - **Network:** \$${costs.network_total_cost}
              
              ### Resources:
              - **GKE Clusters:** \${report.cost_analysis.resources.gke_clusters}
              - **Cloud SQL Instances:** \${report.cost_analysis.resources.cloud_sql_instances}
              - **Storage Buckets:** \${report.cost_analysis.resources.storage_buckets}
              - **Load Balancers:** \${report.cost_analysis.resources.load_balancers}
              
              Generated on: \${new Date().toISOString()}
              \`;
              
              github.rest.issues.create({
                owner: context.repo.owner,
                repo: context.repo.repo,
                title: \`Monthly Cost Analysis - \${{ matrix.environment }} - \${new Date().toLocaleDateString()}\`,
                body: output,
                labels: ['cost-analysis', 'monthly-report']
              });
            }
          } catch (error) {
            console.error('Error creating cost report issue:', error);
          }
EOF
    
    success "Cost analysis workflow created"
}

# Create performance monitoring workflow
create_performance_monitoring_workflow() {
    log "Creating performance monitoring workflow..."
    
    cat > .github/workflows/performance-monitoring.yml << EOF
name: Performance Monitoring

on:
  schedule:
    - cron: '0 */6 * * *' # Every 6 hours
  workflow_dispatch:

env:
  TF_VERSION: '1.5.0'
  TF_VAR_project_id: \${{ secrets.GCP_PROJECT_ID }}
  TF_VAR_region: '$REGION'

jobs:
  performance-monitoring:
    name: Performance Monitoring
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        environment: [dev, staging, prod]
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Setup Google Cloud CLI
      uses: google-github-actions/setup-gcloud@v2
      with:
        service_account_key: \${{ secrets.GCP_SA_KEY }}
        project_id: \${{ env.TF_VAR_project_id }}
    
    - name: Authenticate to Google Cloud
      uses: google-github-actions/auth@v2
      with:
        credentials_json: \${{ secrets.GCP_SA_KEY }}
    
    - name: Configure gcloud
      run: |
        gcloud config set project \${{ env.TF_VAR_project_id }}
        gcloud config set compute/region $REGION
    
    - name: Run Performance Monitoring
      run: |
        chmod +x scripts/utilities/performance-monitor.sh
        ./scripts/utilities/performance-monitor.sh -p \${{ env.TF_VAR_project_id }} -e \${{ matrix.environment }} -f json -o performance-monitor-\${{ matrix.environment }}.json
      env:
        PROJECT_ID: \${{ env.TF_VAR_project_id }}
        ENVIRONMENT: \${{ matrix.environment }}
        REGION: $REGION
    
    - name: Upload Performance Report
      uses: actions/upload-artifact@v4
      with:
        name: performance-monitor-\${{ matrix.environment }}
        path: performance-monitor-\${{ matrix.environment }}.json
        retention-days: 30
    
    - name: Check Performance Thresholds
      run: |
        # Check for performance issues
        if jq -e '.performance_monitoring.recommendations | length > 0' performance-monitor-\${{ matrix.environment }}.json > /dev/null; then
          echo "Performance issues detected"
          jq -r '.performance_monitoring.recommendations | to_entries[] | "• " + .value' performance-monitor-\${{ matrix.environment }}.json
        else
          echo "No performance issues detected"
        fi
EOF
    
    success "Performance monitoring workflow created"
}

# Create GitHub repository secrets
create_github_secrets() {
    log "Creating GitHub repository secrets..."
    
    # Check if secrets already exist
    local existing_secrets=$(gh secret list --repo "$GITHUB_REPO" --json name --jq '.[].name' 2>/dev/null || echo "")
    
    # Create GCP service account key
    local sa_name="terraform-github-actions"
    local sa_email="${sa_name}@${PROJECT_ID}.iam.gserviceaccount.com"
    
    # Check if service account exists
    if ! gcloud iam service-accounts describe "$sa_email" --project="$PROJECT_ID" >/dev/null 2>&1; then
        log "Creating service account: $sa_name"
        gcloud iam service-accounts create "$sa_name" \
            --display-name="Terraform GitHub Actions" \
            --description="Service account for Terraform GitHub Actions workflows" \
            --project="$PROJECT_ID"
    fi
    
    # Grant necessary roles
    local roles=(
        "roles/editor"
        "roles/iam.serviceAccountAdmin"
        "roles/container.admin"
        "roles/cloudsql.admin"
        "roles/storage.admin"
        "roles/secretmanager.admin"
        "roles/cloudkms.admin"
        "roles/monitoring.admin"
        "roles/logging.admin"
        "roles/bigquery.admin"
        "roles/pubsub.admin"
        "roles/run.admin"
        "roles/cloudfunctions.admin"
        "roles/appengine.appAdmin"
    )
    
    for role in "${roles[@]}"; do
        gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="serviceAccount:$sa_email" \
            --role="$role" >/dev/null 2>&1
    done
    
    # Create and download service account key
    local key_file="terraform-github-actions-key.json"
    gcloud iam service-accounts keys create "$key_file" \
        --iam-account="$sa_email" \
        --project="$PROJECT_ID"
    
    # Set GitHub secrets
    if [[ "$existing_secrets" != *"GCP_SA_KEY"* ]]; then
        gh secret set GCP_SA_KEY --repo "$GITHUB_REPO" --body-file "$key_file"
        success "GCP_SA_KEY secret created"
    else
        info "GCP_SA_KEY secret already exists"
    fi
    
    if [[ "$existing_secrets" != *"GCP_PROJECT_ID"* ]]; then
        gh secret set GCP_PROJECT_ID --repo "$GITHUB_REPO" --body "$PROJECT_ID"
        success "GCP_PROJECT_ID secret created"
    else
        info "GCP_PROJECT_ID secret already exists"
    fi
    
    # Clean up key file
    rm -f "$key_file"
    
    success "GitHub repository secrets configured"
}

# Create GitHub environments
create_github_environments() {
    log "Creating GitHub environments..."
    
    local environments=("dev" "staging" "prod")
    
    for env in "${environments[@]}"; do
        # Check if environment exists
        if gh api "repos/$GITHUB_REPO/environments/$env" >/dev/null 2>&1; then
            info "Environment $env already exists"
        else
            # Create environment
            gh api "repos/$GITHUB_REPO/environments" \
                --method POST \
                --field name="$env" \
                --field protection_rules='[{"type":"required_reviewers","required_reviewers":1}]' >/dev/null 2>&1
            
            success "Environment $env created"
        fi
    done
}

# Create GitHub branch protection rules
create_branch_protection() {
    log "Creating GitHub branch protection rules..."
    
    local branches=("main" "develop")
    
    for branch in "${branches[@]}"; do
        # Check if branch exists
        if gh api "repos/$GITHUB_REPO/branches/$branch" >/dev/null 2>&1; then
            # Create branch protection rule
            gh api "repos/$GITHUB_REPO/branches/$branch/protection" \
                --method PUT \
                --field required_status_checks='{"strict":true,"contexts":["terraform-plan-dev","terraform-plan-staging","terraform-plan-prod"]}' \
                --field enforce_admins=true \
                --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true}' \
                --field restrictions='{"users":[],"teams":[]}' >/dev/null 2>&1
            
            success "Branch protection rule created for $branch"
        else
            warning "Branch $branch does not exist"
        fi
    done
}

# Main setup function
setup_cicd() {
    log "Setting up CI/CD for terraform-gcp infrastructure..."
    log "Project: $PROJECT_ID, Environment: $ENVIRONMENT, Region: $REGION"
    log "GitHub Repository: $GITHUB_REPO"
    
    # Create workflows
    create_workflows_directory
    create_terraform_plan_workflow
    create_terraform_apply_workflow
    create_security_scan_workflow
    create_cost_analysis_workflow
    create_performance_monitoring_workflow
    
    # Configure GitHub
    create_github_secrets
    create_github_environments
    create_branch_protection
    
    success "CI/CD setup completed successfully!"
    
    echo
    echo "=========================================="
    echo "CI/CD SETUP COMPLETE"
    echo "=========================================="
    echo "GitHub Repository: $GITHUB_REPO"
    echo "Project ID: $PROJECT_ID"
    echo "Region: $REGION"
    echo
    echo "Workflows created:"
    echo "• terraform-plan.yml - Terraform planning on PRs"
    echo "• terraform-apply.yml - Terraform deployment on main"
    echo "• security-scan.yml - Security auditing"
    echo "• cost-analysis.yml - Monthly cost analysis"
    echo "• performance-monitoring.yml - Performance monitoring"
    echo
    echo "Next steps:"
    echo "1. Commit and push the .github/workflows/ directory"
    echo "2. Create a pull request to test the workflows"
    echo "3. Review and approve the pull request"
    echo "4. Merge to main to trigger deployment"
    echo "=========================================="
}

# Main execution
main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Validate prerequisites
    validate_prerequisites
    
    # Setup CI/CD
    setup_cicd
}

# Run main function
main "$@"

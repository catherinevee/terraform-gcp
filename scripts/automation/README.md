# Automation Scripts

This directory contains automation scripts for deploying, managing, and monitoring the terraform-gcp infrastructure.

## 📋 Scripts Overview

| Script | Purpose | Usage |
|--------|---------|-------|
| `phase-deployment.sh` | Deploy specific phases | `./phase-deployment.sh -p project-id -e dev 0` |
| `rollback-phase.sh` | Rollback specific phases | `./rollback-phase.sh -p project-id -e dev 1` |
| `health-check.sh` | Comprehensive health checks | `./health-check.sh -p project-id -e dev` |

## 🚀 Phase Deployment Script

### Purpose
Automates the deployment of specific phases with proper validation and rollback capabilities.

### Usage
```bash
# Deploy Phase 0 (Foundation Setup)
./phase-deployment.sh -p my-project -e dev 0

# Deploy Phase 1 (Networking) with auto-approve
./phase-deployment.sh -p my-project -e staging 1 --auto-approve

# Dry run Phase 6 (Production Hardening)
./phase-deployment.sh -p my-project -e prod 6 --dry-run
```

### Options
- `-p, --project-id PROJECT_ID` - GCP Project ID (required)
- `-e, --environment ENVIRONMENT` - Environment (dev/staging/prod) [default: dev]
- `-r, --region REGION` - Primary GCP region [default: us-central1]
- `-a, --auto-approve` - Auto-approve terraform apply
- `-d, --dry-run` - Show what would be deployed without applying
- `-h, --help` - Show help message

### Features
- **Automated Validation**: Runs phase-specific tests after deployment
- **Rollback Capability**: Can rollback if deployment fails
- **State Management**: Handles Terraform state properly
- **Progress Tracking**: Detailed logging and progress updates
- **Summary Reports**: Generates deployment summaries

## 🔄 Rollback Script

### Purpose
Provides safe rollback capabilities for each phase with proper cleanup and verification.

### Usage
```bash
# Rollback Phase 1 (Networking)
./rollback-phase.sh -p my-project -e dev 1

# Force rollback without confirmation
./rollback-phase.sh -p my-project -e staging 2 --force

# Rollback without state backup
./rollback-phase.sh -p my-project -e prod 3 --no-backup
```

### Options
- `-p, --project-id PROJECT_ID` - GCP Project ID (required)
- `-e, --environment ENVIRONMENT` - Environment (dev/staging/prod) [default: dev]
- `-r, --region REGION` - Primary GCP region [default: us-central1]
- `-f, --force` - Force rollback without confirmation
- `-n, --no-backup` - Skip state backup
- `-h, --help` - Show help message

### Features
- **Safe Rollback**: Confirms before destroying resources
- **State Backup**: Automatically backs up Terraform state
- **Verification**: Verifies rollback completion
- **Cleanup**: Removes all phase-specific resources
- **Summary Reports**: Generates rollback summaries

## 🏥 Health Check Script

### Purpose
Performs comprehensive health checks across all infrastructure components.

### Usage
```bash
# Console health check
./health-check.sh -p my-project -e dev

# JSON health check report
./health-check.sh -p my-project -e staging -f json -o health-report.json

# HTML health check report
./health-check.sh -p my-project -e prod -f html -o health-report.html
```

### Options
- `-p, --project-id PROJECT_ID` - GCP Project ID (required)
- `-e, --environment ENVIRONMENT` - Environment (dev/staging/prod) [default: dev]
- `-r, --region REGION` - Primary GCP region [default: us-central1]
- `-f, --format FORMAT` - Output format (console/json/html) [default: console]
- `-o, --output FILE` - Output file name [default: auto-generated]
- `-h, --help` - Show help message

### Features
- **Comprehensive Checks**: Covers all infrastructure components
- **Multiple Formats**: Console, JSON, and HTML output
- **Performance Metrics**: Includes performance and utilization data
- **Health Scoring**: Provides overall health status
- **Detailed Reports**: Comprehensive health analysis

## 🔧 Prerequisites

### Required Tools
```bash
# Install required tools
sudo apt-get update
sudo apt-get install -y terraform gcloud kubectl jq curl

# Or on macOS
brew install terraform google-cloud-sdk kubernetes-cli jq curl
```

### GCP Authentication
```bash
# Authenticate with GCP
gcloud auth login
gcloud auth application-default login

# Set project
gcloud config set project YOUR_PROJECT_ID
```

### Permissions
Ensure your account has the following roles:
- `roles/editor` - For resource creation and management
- `roles/iam.serviceAccountAdmin` - For service account management
- `roles/container.admin` - For GKE management
- `roles/cloudsql.admin` - For Cloud SQL management
- `roles/storage.admin` - For Cloud Storage management

## 📊 Health Check Components

### Infrastructure Components
- **Project Health**: Project status, billing, permissions
- **Networking**: VPC, subnets, firewall rules, NAT gateway
- **Compute**: GKE cluster, Cloud Run services, Cloud Functions
- **Data Layer**: Cloud SQL, Redis, BigQuery, Cloud Storage
- **Security**: IAM, KMS, Secret Manager
- **Monitoring**: Logging, alerting, notification channels

### Health Status Levels
- **Healthy** ✅: Component is working correctly
- **Warning** ⚠️: Component has issues but is functional
- **Error** ❌: Component has critical issues

### Performance Metrics
- **Resource Utilization**: CPU, memory, storage usage
- **Network Performance**: Latency, connectivity
- **Service Availability**: Uptime, response times
- **Cost Metrics**: Resource costs, optimization opportunities

## 🚨 Error Handling

### Common Issues
1. **Authentication Errors**: Re-authenticate with GCP
2. **Permission Errors**: Check IAM roles and permissions
3. **Resource Not Found**: Verify resource names and regions
4. **Network Issues**: Check VPC and firewall configurations

### Troubleshooting
```bash
# Check authentication
gcloud auth list
gcloud config list

# Check project access
gcloud projects describe YOUR_PROJECT_ID

# Check resource status
gcloud compute instances list --project=YOUR_PROJECT_ID
gcloud container clusters list --project=YOUR_PROJECT_ID
```

## 📈 Best Practices

### Deployment
1. **Test First**: Always run dry-run before actual deployment
2. **Validate**: Run health checks after each deployment
3. **Monitor**: Watch for errors and warnings during deployment
4. **Document**: Keep track of deployment history and changes

### Rollback
1. **Backup State**: Always backup Terraform state before rollback
2. **Verify Dependencies**: Check for dependent resources
3. **Test Rollback**: Verify rollback completion
4. **Update Documentation**: Document rollback reasons and results

### Health Checks
1. **Regular Monitoring**: Run health checks regularly
2. **Trend Analysis**: Track health metrics over time
3. **Alert Integration**: Integrate with monitoring systems
4. **Automated Checks**: Schedule automated health checks

## 🔄 Integration

### CI/CD Integration
```yaml
# Example GitHub Actions workflow
- name: Deploy Phase
  run: |
    ./scripts/automation/phase-deployment.sh \
      -p ${{ secrets.GCP_PROJECT_ID }} \
      -e ${{ github.ref_name }} \
      ${{ matrix.phase }}

- name: Health Check
  run: |
    ./scripts/automation/health-check.sh \
      -p ${{ secrets.GCP_PROJECT_ID }} \
      -e ${{ github.ref_name }} \
      -f json \
      -o health-report.json
```

### Monitoring Integration
```bash
# Schedule health checks
crontab -e

# Add entry for hourly health checks
0 * * * * /path/to/scripts/automation/health-check.sh -p my-project -e prod -f json -o /var/log/health-check.json
```

## 📚 Examples

### Complete Phase Deployment
```bash
#!/bin/bash
# Deploy all phases in sequence

PROJECT_ID="my-project"
ENVIRONMENT="dev"

for phase in {0..6}; do
    echo "Deploying Phase $phase..."
    ./phase-deployment.sh -p "$PROJECT_ID" -e "$ENVIRONMENT" "$phase"
    
    if [[ $? -ne 0 ]]; then
        echo "Phase $phase deployment failed. Rolling back..."
        ./rollback-phase.sh -p "$PROJECT_ID" -e "$ENVIRONMENT" "$phase"
        exit 1
    fi
    
    echo "Phase $phase deployed successfully."
done

echo "All phases deployed successfully!"
```

### Health Check with Alerting
```bash
#!/bin/bash
# Health check with alerting

PROJECT_ID="my-project"
ENVIRONMENT="prod"

# Run health check
./health-check.sh -p "$PROJECT_ID" -e "$ENVIRONMENT" -f json -o health-report.json

# Check for errors
if jq -e '.health_check.results | to_entries[] | select(.value.status == "error")' health-report.json > /dev/null; then
    echo "Health check found errors. Sending alert..."
    # Send alert (email, Slack, etc.)
fi
```

## 🆘 Support

### Getting Help
1. **Check Logs**: Review script output and error messages
2. **Documentation**: Consult this README and phase-specific docs
3. **Community**: Post issues in project repository
4. **Team**: Contact platform engineering team

### Reporting Issues
When reporting script issues, include:
- Script name and version
- Environment details (project, region, etc.)
- Complete error output
- Steps to reproduce
- Expected vs actual behavior

---

*These automation scripts provide comprehensive deployment, rollback, and monitoring capabilities for the terraform-gcp infrastructure.*

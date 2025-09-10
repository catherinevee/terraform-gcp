# Integration Scripts

This directory contains integration scripts for setting up CI/CD, monitoring, and other infrastructure components.

## 📋 Scripts Overview

| Script | Purpose | Usage |
|--------|---------|-------|
| `ci-cd-setup.sh` | Set up GitHub Actions workflows | `./ci-cd-setup.sh -p project-id -g owner/repo -t ghp_xxxxx` |
| `monitoring-setup.sh` | Set up monitoring and alerting | `./monitoring-setup.sh -p project-id -e dev -m admin@company.com` |

## 🚀 CI/CD Setup Script

### Purpose
Sets up GitHub Actions workflows for automated Terraform deployment, testing, and monitoring.

### Usage
```bash
# Set up CI/CD for a repository
./ci-cd-setup.sh -p my-project -g owner/repo -t ghp_xxxxx

# Set up CI/CD for staging environment
./ci-cd-setup.sh -p my-project -e staging -g owner/repo -t ghp_xxxxx
```

### Options
- `-p, --project-id PROJECT_ID` - GCP Project ID (required)
- `-e, --environment ENVIRONMENT` - Environment (dev/staging/prod) [default: dev]
- `-r, --region REGION` - Primary GCP region [default: us-central1]
- `-g, --github-repo REPO` - GitHub repository (owner/repo) [required]
- `-t, --github-token TOKEN` - GitHub token for API access [required]
- `-h, --help` - Show help message

### Features
- **Automated Workflows**: Creates GitHub Actions workflows for Terraform operations
- **Environment Management**: Sets up GitHub environments with protection rules
- **Branch Protection**: Configures branch protection rules for main and develop
- **Service Account**: Creates and configures GCP service account for GitHub Actions
- **Secrets Management**: Automatically sets up GitHub repository secrets
- **Notification Integration**: Integrates with GitHub for deployment notifications

### Workflows Created
1. **terraform-plan.yml** - Terraform planning on pull requests
2. **terraform-apply.yml** - Terraform deployment on main branch
3. **security-scan.yml** - Security auditing and compliance checks
4. **cost-analysis.yml** - Monthly cost analysis and reporting
5. **performance-monitoring.yml** - Performance monitoring and optimization

### Prerequisites
- GitHub CLI (gh) installed and authenticated
- GCP CLI (gcloud) installed and authenticated
- GitHub repository with appropriate permissions
- GitHub token with repository and organization access

## 📊 Monitoring Setup Script

### Purpose
Sets up comprehensive monitoring and alerting for the terraform-gcp infrastructure.

### Usage
```bash
# Set up monitoring with email notifications
./monitoring-setup.sh -p my-project -e dev -m admin@company.com

# Set up monitoring with email and Slack notifications
./monitoring-setup.sh -p my-project -e prod -m admin@company.com -s https://hooks.slack.com/...
```

### Options
- `-p, --project-id PROJECT_ID` - GCP Project ID (required)
- `-e, --environment ENVIRONMENT` - Environment (dev/staging/prod) [default: dev]
- `-r, --region REGION` - Primary GCP region [default: us-central1]
- `-m, --email EMAIL` - Notification email address
- `-s, --slack-webhook URL` - Slack webhook URL for notifications
- `-h, --help` - Show help message

### Features
- **Notification Channels**: Sets up email and Slack notification channels
- **Uptime Checks**: Creates HTTP and HTTPS uptime checks for load balancers
- **Alert Policies**: Configures comprehensive alerting for all infrastructure components
- **Log Sinks**: Sets up log sinks for audit and application logs
- **Dashboards**: Creates monitoring dashboards for infrastructure visibility
- **Cost Monitoring**: Includes cost alerts and budget monitoring

### Monitoring Components
1. **Notification Channels**
   - Email notifications
   - Slack webhook notifications
   - Custom notification channels

2. **Uptime Checks**
   - HTTP health checks
   - HTTPS health checks
   - Custom endpoint monitoring

3. **Alert Policies**
   - GKE cluster monitoring (CPU, memory)
   - Cloud SQL monitoring (CPU, disk)
   - Cloud Run monitoring (error rate, response time)
   - Network monitoring (latency, connectivity)
   - Storage monitoring (usage, performance)
   - Cost monitoring (daily, monthly thresholds)

4. **Log Sinks**
   - Audit log collection
   - Application log collection
   - Security log collection

5. **Dashboards**
   - Infrastructure overview
   - Performance metrics
   - Cost analysis
   - Security monitoring

## 🔧 Prerequisites

### Required Tools
```bash
# Install required tools
sudo apt-get update
sudo apt-get install -y gcloud gh jq

# Or on macOS
brew install google-cloud-sdk gh jq
```

### Authentication
```bash
# Authenticate with GCP
gcloud auth login
gcloud auth application-default login

# Authenticate with GitHub
gh auth login

# Set project
gcloud config set project YOUR_PROJECT_ID
```

### Permissions
Ensure your account has the following permissions:

#### GCP Permissions
- `roles/editor` - For resource creation and management
- `roles/iam.serviceAccountAdmin` - For service account management
- `roles/container.admin` - For GKE management
- `roles/cloudsql.admin` - For Cloud SQL management
- `roles/storage.admin` - For Cloud Storage management
- `roles/monitoring.admin` - For monitoring setup
- `roles/logging.admin` - For log sink creation

#### GitHub Permissions
- Repository admin access
- Organization admin access (for branch protection)
- Ability to create secrets and environments
- Ability to create and modify workflows

## 📈 Usage Examples

### Complete CI/CD Setup
```bash
#!/bin/bash
# Set up CI/CD for all environments

PROJECT_ID="my-project"
GITHUB_REPO="owner/repo"
GITHUB_TOKEN="ghp_xxxxx"

for environment in dev staging prod; do
    echo "Setting up CI/CD for $environment..."
    ./ci-cd-setup.sh \
        -p "$PROJECT_ID" \
        -e "$environment" \
        -g "$GITHUB_REPO" \
        -t "$GITHUB_TOKEN"
done
```

### Complete Monitoring Setup
```bash
#!/bin/bash
# Set up monitoring for all environments

PROJECT_ID="my-project"
NOTIFICATION_EMAIL="admin@company.com"
SLACK_WEBHOOK="https://hooks.slack.com/..."

for environment in dev staging prod; do
    echo "Setting up monitoring for $environment..."
    ./monitoring-setup.sh \
        -p "$PROJECT_ID" \
        -e "$environment" \
        -m "$NOTIFICATION_EMAIL" \
        -s "$SLACK_WEBHOOK"
done
```

### Automated Setup Workflow
```bash
#!/bin/bash
# Complete infrastructure setup

PROJECT_ID="my-project"
GITHUB_REPO="owner/repo"
GITHUB_TOKEN="ghp_xxxxx"
NOTIFICATION_EMAIL="admin@company.com"
SLACK_WEBHOOK="https://hooks.slack.com/..."

# Set up CI/CD
echo "Setting up CI/CD..."
./ci-cd-setup.sh \
    -p "$PROJECT_ID" \
    -g "$GITHUB_REPO" \
    -t "$GITHUB_TOKEN"

# Set up monitoring
echo "Setting up monitoring..."
./monitoring-setup.sh \
    -p "$PROJECT_ID" \
    -m "$NOTIFICATION_EMAIL" \
    -s "$SLACK_WEBHOOK"

echo "Setup complete!"
```

## 🔄 Integration with Existing Workflows

### GitHub Actions Integration
The CI/CD setup script creates workflows that integrate with:
- Existing Terraform configurations
- Phase testing scripts
- Health check scripts
- Security audit scripts
- Cost analysis scripts
- Performance monitoring scripts

### Monitoring Integration
The monitoring setup script integrates with:
- Existing infrastructure components
- Application health endpoints
- Cost management tools
- Security monitoring systems
- Performance monitoring tools

## 🚨 Troubleshooting

### Common Issues

#### 1. Authentication Errors
```bash
# Re-authenticate with GCP
gcloud auth login
gcloud auth application-default login

# Re-authenticate with GitHub
gh auth login
```

#### 2. Permission Errors
```bash
# Check GCP permissions
gcloud projects get-iam-policy YOUR_PROJECT_ID

# Check GitHub permissions
gh api user
gh api repos/owner/repo
```

#### 3. Service Account Issues
```bash
# Check service account
gcloud iam service-accounts list --project=YOUR_PROJECT_ID

# Check service account keys
gcloud iam service-accounts keys list --iam-account=terraform-github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

#### 4. Workflow Issues
```bash
# Check workflow status
gh run list --repo owner/repo

# Check workflow logs
gh run view RUN_ID --repo owner/repo
```

### Debug Mode
```bash
# Enable debug mode for detailed output
set -x
./ci-cd-setup.sh -p my-project -g owner/repo -t ghp_xxxxx
set +x
```

## 📚 Best Practices

### CI/CD Best Practices
1. **Environment Separation**: Use separate environments for dev, staging, and prod
2. **Branch Protection**: Enable branch protection rules for main branches
3. **Review Process**: Require pull request reviews before merging
4. **Testing**: Run comprehensive tests before deployment
5. **Rollback**: Have rollback procedures in place

### Monitoring Best Practices
1. **Alert Thresholds**: Set appropriate alert thresholds for each environment
2. **Notification Channels**: Use multiple notification channels for redundancy
3. **Log Retention**: Configure appropriate log retention periods
4. **Dashboard Design**: Create focused dashboards for different teams
5. **Cost Monitoring**: Set up cost alerts to prevent budget overruns

### Security Best Practices
1. **Least Privilege**: Use least privilege access for service accounts
2. **Secret Management**: Store secrets securely in GitHub Secrets
3. **Audit Logging**: Enable comprehensive audit logging
4. **Access Control**: Implement proper access controls for all resources
5. **Regular Reviews**: Regularly review and update permissions

## 🆘 Support

### Getting Help
1. **Check Logs**: Review script output and error messages
2. **Documentation**: Consult this README and related documentation
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

*These integration scripts provide comprehensive setup for CI/CD and monitoring, enabling automated deployment and ongoing infrastructure management.*

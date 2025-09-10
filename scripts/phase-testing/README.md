# Phase Testing Framework

This directory contains comprehensive testing scripts for validating each phase of the terraform-gcp infrastructure rollout. Each script provides automated validation of infrastructure components, security configurations, and operational readiness.

## 📋 Overview

The testing framework consists of 6 phase-specific test scripts plus supporting utilities:

| Script | Purpose | Duration | Tests |
|--------|---------|----------|-------|
| `phase-0-tests.sh` | Foundation Setup | ~15 min | Project structure, CI/CD, modules |
| `phase-1-tests.sh` | Networking Foundation | ~20 min | VPC, subnets, firewall, connectivity |
| `phase-2-tests.sh` | Security & Identity | ~25 min | IAM, KMS, secrets, access controls |
| `phase-3-tests.sh` | Data Layer | ~30 min | Cloud SQL, Redis, BigQuery, Storage |
| `phase-4-tests.sh` | Compute Platform | ~35 min | GKE, Cloud Run, Functions, apps |
| `phase-5-tests.sh` | Monitoring & Observability | ~20 min | Logging, metrics, alerting, cost |
| `phase-6-tests.sh` | Production Hardening | ~40 min | HA, DR, security, compliance |
| `run-all-phase-tests.sh` | Complete Test Suite | ~3 hours | All phases in sequence |

## 🚀 Quick Start

### Prerequisites

Ensure you have the following tools installed and configured:

```bash
# Required tools
terraform >= 1.5.0
gcloud CLI
kubectl
jq
curl
psql (PostgreSQL client)
redis-cli
openssl
bc (calculator)

# Optional but recommended
tfsec
tflint
infracost
```

### Environment Setup

```bash
# Set required environment variables
export PROJECT_ID="your-gcp-project-id"
export ENVIRONMENT="dev"  # or staging, prod
export REGION="us-central1"

# Authenticate with GCP
gcloud auth login
gcloud config set project $PROJECT_ID

# Get GKE credentials (for Phase 4+)
gcloud container clusters get-credentials your-cluster-name --region=$REGION
```

### Running Tests

#### Single Phase Testing
```bash
# Test a specific phase
./scripts/phase-testing/phase-0-tests.sh
./scripts/phase-testing/phase-1-tests.sh
# ... etc
```

#### Complete Test Suite
```bash
# Run all phases in sequence
./scripts/phase-testing/run-all-phase-tests.sh
```

#### Custom Test Execution
```bash
# Set custom environment
export PROJECT_ID="my-project"
export ENVIRONMENT="staging"
export REGION="us-east1"

# Run specific phase
./scripts/phase-testing/phase-2-tests.sh
```

## 📊 Test Categories

### 1. Infrastructure Validation
- **Resource Existence**: Verify all required resources are created
- **Configuration Validation**: Check resource settings and parameters
- **Dependency Verification**: Ensure proper resource dependencies
- **State Consistency**: Validate Terraform state alignment

### 2. Security Testing
- **Access Controls**: Verify IAM policies and permissions
- **Encryption**: Check encryption at rest and in transit
- **Network Security**: Validate firewall rules and network policies
- **Secret Management**: Test secret access and rotation

### 3. Connectivity Testing
- **Internal Communication**: Test inter-service connectivity
- **External Access**: Verify internet and GCP service access
- **Load Balancing**: Test traffic distribution and health checks
- **DNS Resolution**: Validate name resolution

### 4. Performance Testing
- **Response Times**: Measure service response times
- **Auto-scaling**: Test scaling behavior under load
- **Resource Utilization**: Check resource efficiency
- **Capacity Planning**: Validate resource sizing

### 5. Operational Testing
- **Monitoring**: Verify metrics collection and dashboards
- **Alerting**: Test alert policies and notifications
- **Logging**: Check log aggregation and retention
- **Backup/Recovery**: Test backup and restore procedures

## 🔧 Test Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `PROJECT_ID` | GCP Project ID | - | Yes |
| `ENVIRONMENT` | Environment name (dev/staging/prod) | dev | No |
| `REGION` | Primary GCP region | us-central1 | No |
| `ZONE` | Primary GCP zone | us-central1-a | No |
| `SECONDARY_REGION` | Secondary region for DR | us-east1 | No |
| `REPORT_DIR` | Test report directory | ./test-reports | No |

### Test Output

Each test script generates:
- **Console Output**: Real-time test progress and results
- **Log Files**: Detailed test logs in `test-reports/`
- **JSON Reports**: Machine-readable test results
- **Markdown Reports**: Human-readable test summaries

## 📈 Test Results

### Success Criteria

Each phase test passes when:
- ✅ All required resources exist and are configured correctly
- ✅ Security controls are properly implemented
- ✅ Connectivity tests pass
- ✅ Performance meets requirements
- ✅ Monitoring and alerting are operational

### Failure Handling

When tests fail:
1. **Detailed Error Messages**: Specific failure reasons and locations
2. **Rollback Guidance**: Instructions for reverting changes
3. **Troubleshooting Tips**: Common issues and solutions
4. **Support Information**: Where to get additional help

### Test Reports

Test reports include:
- **Executive Summary**: High-level test results
- **Detailed Results**: Per-test outcomes and metrics
- **Recommendations**: Suggested improvements
- **Next Steps**: Actions required before proceeding

## 🛠️ Customization

### Adding Custom Tests

To add custom tests to a phase:

```bash
# Edit the appropriate phase test script
vim scripts/phase-testing/phase-X-tests.sh

# Add your test function
test_custom_feature() {
    log "Testing custom feature..."
    
    # Your test logic here
    if [[ condition ]]; then
        success "Custom feature test passed"
    else
        error "Custom feature test failed"
    fi
}

# Add to main() function
main() {
    # ... existing tests ...
    test_custom_feature
    # ... rest of tests ...
}
```

### Modifying Test Parameters

Adjust test parameters by editing the configuration section:

```bash
# In each test script
# Configuration
PROJECT_ID="${PROJECT_ID:-}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
REGION="${REGION:-us-central1}"

# Add custom parameters
CUSTOM_PARAM="${CUSTOM_PARAM:-default-value}"
```

## 🔍 Troubleshooting

### Common Issues

#### Authentication Errors
```bash
# Re-authenticate with GCP
gcloud auth login
gcloud auth application-default login
gcloud config set project $PROJECT_ID
```

#### Permission Errors
```bash
# Check required permissions
gcloud projects get-iam-policy $PROJECT_ID
gcloud auth list
```

#### Resource Not Found
```bash
# Verify resource names and regions
gcloud compute instances list --project=$PROJECT_ID
gcloud container clusters list --project=$PROJECT_ID
```

#### Network Connectivity Issues
```bash
# Test basic connectivity
ping 8.8.8.8
nslookup google.com
curl -I https://www.google.com
```

### Debug Mode

Enable debug mode for detailed output:

```bash
# Set debug environment variable
export DEBUG=true

# Run tests with verbose output
./scripts/phase-testing/phase-0-tests.sh
```

### Test Isolation

Run tests in isolation to avoid conflicts:

```bash
# Create isolated test environment
export PROJECT_ID="test-project-$(date +%s)"
export ENVIRONMENT="test"

# Run tests
./scripts/phase-testing/phase-0-tests.sh
```

## 📚 Best Practices

### Test Execution

1. **Run tests in order**: Execute phases sequentially
2. **Validate prerequisites**: Ensure all dependencies are met
3. **Review results**: Check all test outputs before proceeding
4. **Document issues**: Record any failures or warnings
5. **Clean up**: Remove test resources when done

### Test Maintenance

1. **Regular updates**: Keep tests current with infrastructure changes
2. **Version control**: Track test script changes
3. **Documentation**: Update test documentation as needed
4. **Performance monitoring**: Track test execution times
5. **Feedback loop**: Incorporate lessons learned

### Security Considerations

1. **Credential management**: Use service accounts for automation
2. **Access controls**: Limit test permissions to minimum required
3. **Data protection**: Avoid sensitive data in test outputs
4. **Audit logging**: Enable audit logs for test activities
5. **Cleanup**: Remove test data and temporary resources

## 🆘 Support

### Getting Help

1. **Check logs**: Review test output and error messages
2. **Documentation**: Consult this README and phase-specific docs
3. **Community**: Post issues in project repository
4. **Team**: Contact platform engineering team

### Reporting Issues

When reporting test failures, include:
- Test script name and version
- Environment details (project, region, etc.)
- Complete error output
- Steps to reproduce
- Expected vs actual behavior

### Contributing

To contribute to the testing framework:
1. Fork the repository
2. Create a feature branch
3. Add your tests or improvements
4. Run the full test suite
5. Submit a pull request

---

*This testing framework ensures comprehensive validation of the terraform-gcp infrastructure at each phase, providing confidence in the deployment process and infrastructure quality.*

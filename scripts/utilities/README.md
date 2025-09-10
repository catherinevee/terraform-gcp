# Utility Scripts

This directory contains utility scripts for monitoring, analyzing, and optimizing the terraform-gcp infrastructure.

## 📋 Scripts Overview

| Script | Purpose | Usage |
|--------|---------|-------|
| `cost-analyzer.sh` | Analyze infrastructure costs | `./cost-analyzer.sh -p project-id -e dev` |
| `security-audit.sh` | Perform security audits | `./security-audit.sh -p project-id -e dev` |
| `performance-monitor.sh` | Monitor performance metrics | `./performance-monitor.sh -p project-id -e dev` |

## 💰 Cost Analyzer Script

### Purpose
Analyzes infrastructure costs and provides optimization recommendations to help reduce spending.

### Usage
```bash
# Console cost analysis
./cost-analyzer.sh -p my-project -e dev

# JSON cost report
./cost-analyzer.sh -p my-project -e staging -f json -o cost-report.json

# CSV cost report
./cost-analyzer.sh -p my-project -e prod -f csv -o cost-report.csv
```

### Features
- **Resource Analysis**: Analyzes all GCP resources and their costs
- **Cost Estimation**: Provides monthly cost estimates for each service
- **Optimization Recommendations**: Suggests ways to reduce costs
- **Multiple Output Formats**: Console, JSON, and CSV reports
- **Preemptible Analysis**: Identifies opportunities for preemptible instances
- **Storage Class Analysis**: Recommends appropriate storage classes

### Cost Categories
- **Compute**: GKE clusters, Cloud Run, Cloud Functions, Compute Engine
- **Storage**: Cloud Storage buckets, BigQuery datasets
- **Database**: Cloud SQL instances, Redis instances
- **Network**: NAT gateways, load balancers, CDN
- **Monitoring**: Logging, alerting, uptime checks

### Optimization Recommendations
- Use preemptible instances for non-critical workloads
- Implement lifecycle policies for storage
- Consolidate NAT gateways
- Use appropriate storage classes
- Enable autoscaling for GKE clusters

## 🔒 Security Audit Script

### Purpose
Performs comprehensive security audits of the infrastructure to ensure compliance and identify vulnerabilities.

### Usage
```bash
# Console security audit
./security-audit.sh -p my-project -e dev

# JSON security report
./security-audit.sh -p my-project -e staging -f json -o security-audit.json

# HTML security report
./security-audit.sh -p my-project -e prod -f html -o security-audit.html
```

### Features
- **IAM Security**: Audits IAM policies and service accounts
- **Network Security**: Checks VPC configuration and firewall rules
- **Data Security**: Validates encryption and access controls
- **Encryption Security**: Reviews KMS and Secret Manager usage
- **Monitoring Security**: Ensures proper logging and alerting
- **Compliance Scoring**: Provides overall security rating

### Security Categories
- **IAM**: Role bindings, service accounts, conditional access
- **Network**: VPC configuration, firewall rules, private clusters
- **Data**: Cloud SQL encryption, storage access, BigQuery security
- **Encryption**: KMS keys, key rotation, Secret Manager
- **Monitoring**: Audit logs, alert policies, security monitoring

### Security Recommendations
- Use least privilege IAM roles
- Enable private clusters for GKE
- Implement encryption at rest and in transit
- Enable key rotation for KMS keys
- Set up comprehensive audit logging
- Use conditional IAM bindings

## 📊 Performance Monitor Script

### Purpose
Monitors infrastructure performance and provides optimization recommendations for better efficiency.

### Usage
```bash
# Console performance monitoring
./performance-monitor.sh -p my-project -e dev

# JSON performance report
./performance-monitor.sh -p my-project -e staging -f json -o performance-report.json

# HTML performance report
./performance-monitor.sh -p my-project -e prod -f html -o performance-report.html

# Extended monitoring (10 minutes)
./performance-monitor.sh -p my-project -e prod -d 600
```

### Features
- **Real-time Monitoring**: Monitors performance metrics in real-time
- **Resource Utilization**: Tracks CPU, memory, and disk usage
- **Response Time Analysis**: Measures service response times
- **Network Performance**: Tests latency and connectivity
- **Optimization Recommendations**: Suggests performance improvements
- **Alert Thresholds**: Configurable alerting for performance issues

### Performance Metrics
- **GKE**: Node utilization, pod performance, cluster health
- **Cloud Run**: Response times, service health, scaling
- **Cloud SQL**: Instance state, performance, optimization
- **Network**: Latency, connectivity, load balancer health
- **Storage**: Bucket performance, BigQuery efficiency
- **Monitoring**: Alert coverage, uptime checks

### Performance Recommendations
- Scale resources based on utilization
- Optimize memory and CPU allocation
- Implement caching strategies
- Use CDN for static content
- Enable autoscaling
- Monitor and optimize database queries

## 🔧 Prerequisites

### Required Tools
```bash
# Install required tools
sudo apt-get update
sudo apt-get install -y gcloud kubectl jq curl bc

# Or on macOS
brew install google-cloud-sdk kubernetes-cli jq curl bc
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
- `roles/viewer` - For reading resource information
- `roles/monitoring.viewer` - For monitoring metrics
- `roles/logging.viewer` - For log analysis
- `roles/cloudsql.viewer` - For database monitoring
- `roles/container.viewer` - For GKE monitoring

## 📈 Usage Examples

### Complete Infrastructure Analysis
```bash
#!/bin/bash
# Run all utility scripts

PROJECT_ID="my-project"
ENVIRONMENT="dev"

echo "Running cost analysis..."
./cost-analyzer.sh -p "$PROJECT_ID" -e "$ENVIRONMENT" -f json -o cost-analysis.json

echo "Running security audit..."
./security-audit.sh -p "$PROJECT_ID" -e "$ENVIRONMENT" -f json -o security-audit.json

echo "Running performance monitoring..."
./performance-monitor.sh -p "$PROJECT_ID" -e "$ENVIRONMENT" -f json -o performance-monitor.json

echo "Analysis complete!"
```

### Automated Monitoring
```bash
#!/bin/bash
# Schedule regular monitoring

PROJECT_ID="my-project"
ENVIRONMENT="prod"

# Run performance monitoring every hour
while true; do
    ./performance-monitor.sh -p "$PROJECT_ID" -e "$ENVIRONMENT" -f json -o "performance-$(date +%Y%m%d-%H%M%S).json"
    sleep 3600
done
```

### Cost Optimization Workflow
```bash
#!/bin/bash
# Cost optimization workflow

PROJECT_ID="my-project"
ENVIRONMENT="prod"

# Run cost analysis
./cost-analyzer.sh -p "$PROJECT_ID" -e "$ENVIRONMENT" -f json -o cost-analysis.json

# Check for high costs
if jq -e '.cost_analysis.cost_estimates.total_estimated_cost > 1000' cost-analysis.json > /dev/null; then
    echo "High costs detected. Sending alert..."
    # Send alert (email, Slack, etc.)
fi

# Run security audit
./security-audit.sh -p "$PROJECT_ID" -e "$ENVIRONMENT" -f json -o security-audit.json

# Check security score
SECURITY_SCORE=$(jq -r '.security_audit.compliance_scores.pass_percentage' security-audit.json)
if (( $(echo "$SECURITY_SCORE < 90" | bc -l) )); then
    echo "Security score below threshold: $SECURITY_SCORE%"
    # Send security alert
fi
```

## 📊 Report Formats

### Console Output
- Real-time monitoring results
- Color-coded status indicators
- Summary statistics
- Recommendations list

### JSON Output
- Structured data for programmatic use
- Complete metrics and recommendations
- Easy integration with other tools
- Machine-readable format

### HTML Output
- Visual reports with styling
- Interactive elements
- Professional presentation
- Easy sharing and documentation

## 🚨 Alerting and Thresholds

### Cost Alerts
- High monthly costs
- Unused resources
- Inefficient resource allocation
- Storage class optimization opportunities

### Security Alerts
- Failed security checks
- Overly permissive IAM roles
- Unencrypted resources
- Missing security controls

### Performance Alerts
- High resource utilization
- Slow response times
- Network connectivity issues
- Service health problems

## 🔄 Integration

### CI/CD Integration
```yaml
# Example GitHub Actions workflow
- name: Run Security Audit
  run: |
    ./scripts/utilities/security-audit.sh \
      -p ${{ secrets.GCP_PROJECT_ID }} \
      -e ${{ github.ref_name }} \
      -f json \
      -o security-audit.json

- name: Run Cost Analysis
  run: |
    ./scripts/utilities/cost-analyzer.sh \
      -p ${{ secrets.GCP_PROJECT_ID }} \
      -e ${{ github.ref_name }} \
      -f json \
      -o cost-analysis.json
```

### Monitoring Integration
```bash
# Schedule regular monitoring
crontab -e

# Add entries for regular monitoring
0 0 * * * /path/to/scripts/utilities/cost-analyzer.sh -p my-project -e prod -f json -o /var/log/cost-analysis.json
0 */6 * * * /path/to/scripts/utilities/performance-monitor.sh -p my-project -e prod -f json -o /var/log/performance-monitor.json
0 0 * * 0 /path/to/scripts/utilities/security-audit.sh -p my-project -e prod -f json -o /var/log/security-audit.json
```

## 🆘 Troubleshooting

### Common Issues
1. **Authentication Errors**: Re-authenticate with GCP
2. **Permission Errors**: Check IAM roles and permissions
3. **Resource Not Found**: Verify resource names and regions
4. **Network Issues**: Check connectivity and firewall rules

### Debug Mode
```bash
# Enable debug mode for detailed output
set -x
./cost-analyzer.sh -p my-project -e dev
set +x
```

### Log Analysis
```bash
# Check script logs
tail -f /var/log/utility-scripts.log

# Analyze JSON reports
jq '.cost_analysis.cost_estimates' cost-analysis.json
jq '.security_audit.compliance_scores' security-audit.json
jq '.performance_monitoring.metrics' performance-monitor.json
```

## 📚 Best Practices

### Regular Monitoring
1. **Daily**: Performance monitoring
2. **Weekly**: Security audits
3. **Monthly**: Cost analysis
4. **Quarterly**: Comprehensive review

### Report Management
1. **Store Reports**: Keep historical reports for trend analysis
2. **Version Control**: Track changes in reports over time
3. **Share Results**: Distribute reports to stakeholders
4. **Action Items**: Follow up on recommendations

### Optimization
1. **Cost Optimization**: Implement cost-saving recommendations
2. **Security Hardening**: Address security findings
3. **Performance Tuning**: Optimize based on performance data
4. **Continuous Improvement**: Regular review and updates

---

*These utility scripts provide comprehensive monitoring, analysis, and optimization capabilities for your terraform-gcp infrastructure.*

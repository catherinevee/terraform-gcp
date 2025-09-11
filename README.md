# Terraform GCP Infrastructure

![Development Pipeline](https://github.com/catherinevee/terraform-gcp/actions/workflows/dev-pipeline.yml/badge.svg)
![Trivy Security Scan](https://github.com/catherinevee/terraform-gcp/actions/workflows/trivy-scan.yml/badge.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg?style=for-the-badge)
![Terraform](https://img.shields.io/badge/terraform-1.5.0+-blue.svg?style=for-the-badge)

A comprehensive, production-ready infrastructure-as-code solution for Google Cloud Platform, built with Terraform and designed for ACME Corporation's e-commerce platform.

## Overview

This repository provides a complete infrastructure foundation for deploying and managing cloud resources on Google Cloud Platform. The infrastructure is organized into modular, reusable components that support multiple environments and follow industry best practices for security, scalability, and maintainability.

### Key Features

- **Multi-Region Support**: Deploy across multiple GCP regions (us-central1, us-east1)
- **Multi-Environment Support**: Development, staging, and production environments
- **Modular Architecture**: Reusable Terraform modules for common GCP services
- **Security First**: IAM, KMS, Secret Manager, and VPC Service Controls
- **Automated Security Scanning**: Trivy vulnerability, secret, and IaC scanning with GitHub integration
- **CI/CD Integration**: GitHub Actions workflows for automated deployment and security
- **Cross-Region Networking**: VPC peering and VPN tunnels for region connectivity
- **Monitoring & Logging**: Comprehensive observability with Cloud Monitoring and Logging
- **Cost Optimization**: Resource sizing and scheduling for different environments
- **Disaster Recovery**: Backup strategies and cross-region replication

## Architecture

### Multi-Region Design

This infrastructure supports deployment across multiple GCP regions for high availability and disaster recovery:

- **Global Resources**: Shared across all regions (VPC, Load Balancer, DNS, IAM, KMS, Secret Manager)
- **Regional Resources**: Deployed per region (Compute, Storage, Databases, Monitoring)
- **Cross-Region Networking**: VPC peering and VPN tunnels for secure inter-region communication
- **Data Replication**: Automatic cross-region data replication for critical services

#### Region Distribution
- **Primary Region**: us-central1 (Iowa)
- **Secondary Region**: us-east1 (South Carolina)
- **Global Resources**: Deployed once, accessible from all regions

### Architecture Diagrams

#### Comprehensive Architecture
![GCP Architecture](gcp_architecture_diagram.png)

#### Simplified Overview
![GCP Simplified](gcp_simplified_diagram.png)

*These diagrams are automatically generated from the Terraform infrastructure code. See [docs/architecture-diagrams.md](docs/architecture-diagrams.md) for more details.*

### Infrastructure Components

#### **Networking Foundation**
- **VPC**: Custom Virtual Private Cloud with regional routing
- **Subnets**: Tiered network architecture (web, app, database, kubernetes)
- **Firewall Rules**: Security groups with least-privilege access
- **Load Balancer**: Global HTTP(S) load balancer with health checks

#### **Security & Identity**
- **Service Accounts**: Purpose-specific service accounts with minimal permissions
- **IAM Roles**: Custom roles and policies for fine-grained access control
- **KMS**: Customer-managed encryption keys for data protection
- **Secret Manager**: Secure storage and rotation of sensitive credentials

#### **Compute & Storage**
- **Cloud Run**: Serverless container platform for microservices
- **Compute Engine**: Virtual machines with auto-scaling groups
- **Cloud Storage**: Multi-class storage buckets with lifecycle policies
- **Container Registry**: Private container image repositories

#### **Database & Caching**
- **Cloud SQL**: Managed PostgreSQL with high availability
- **Redis**: Memorystore for caching and session storage
- **Database Users**: Application-specific database access controls

#### **Monitoring & Observability**
- **Cloud Monitoring**: Custom dashboards and alerting policies
- **Cloud Logging**: Centralized log aggregation and analysis
- **Service Level Objectives**: SLOs for critical business metrics
- **Uptime Checks**: Automated availability monitoring

## Project Structure

```
terraform-gcp/
├── infrastructure/
│   └── environments/
│       ├── dev/                    # Development environment
│       │   ├── global/            # Global resources (VPC, IAM, etc.)
│       │   ├── us-central1/       # Primary region resources
│       │   └── us-east1/          # Secondary region resources
│       ├── staging/               # Staging environment (future)
│       └── prod/                  # Production environment (future)
├── infrastructure/modules/         # Reusable Terraform modules
│   ├── compute/                   # Compute resources
│   │   ├── cloud-run/            # Cloud Run services
│   │   ├── gke/                  # Google Kubernetes Engine
│   │   ├── instances/            # Compute Engine instances
│   │   └── load-balancer/        # Load balancer configuration
│   ├── database/                 # Database services
│   │   ├── cloud-sql/           # Cloud SQL instances
│   │   └── redis/               # Memorystore Redis
│   ├── monitoring/              # Observability
│   │   ├── cloud-monitoring/    # Monitoring dashboards
│   │   └── cloud-logging/       # Log management
│   ├── networking/              # Network infrastructure
│   │   ├── vpc/                # Virtual Private Cloud
│   │   ├── subnets/            # Subnet configuration
│   │   ├── firewall/           # Firewall rules
│   │   ├── cross-region/       # Cross-region networking
│   │   ├── dns/                # DNS configuration
│   │   └── load-balancer/      # Load balancer networking
│   ├── security/               # Security services
│   │   ├── iam/               # Identity and Access Management
│   │   ├── kms/               # Key Management Service
│   │   ├── secret-manager/    # Secret storage
│   │   └── vpc-service-controls/ # VPC Service Controls
│   └── storage/               # Storage services
│       ├── buckets/          # Cloud Storage buckets
│       ├── cloud-storage/    # Cloud Storage configuration
│       └── container-registry/ # Artifact Registry
├── .github/workflows/         # CI/CD pipelines
│   ├── dev-pipeline.yml      # Development deployment pipeline
│   └── trivy-scan.yml        # Security scanning pipeline
├── scripts/                  # Automation scripts
│   ├── automation/          # Deployment automation
│   ├── integration/         # Integration testing
│   ├── phase-testing/       # Phased deployment testing
│   └── utilities/           # Utility scripts
└── docs/                    # Documentation
```

## Prerequisites

### Required Tools

| Tool | Version | Installation |
|------|---------|-------------|
| Terraform | 1.5.0+ | [Download](https://releases.hashicorp.com/terraform/) |
| Google Cloud SDK | Latest | [Install Guide](https://cloud.google.com/sdk/docs/install) |
| Git | 2.30+ | [Download](https://git-scm.com/downloads) |

### GCP Requirements

- Google Cloud Platform account with billing enabled
- Project with appropriate APIs enabled
- Service account with required permissions
- Following APIs will be automatically enabled:
  - Compute Engine API
  - Cloud Run API
  - Cloud SQL Admin API
  - Cloud Storage API
  - Cloud Monitoring API
  - Cloud Logging API
  - Secret Manager API
  - Cloud KMS API
  - IAM API

## Quick Start

### 1. Clone and Setup

```bash
# Clone the repository
git clone <repository-url>
cd terraform-gcp

# Verify tool versions
terraform version   # Should show 1.5.0+
gcloud version      # Should show latest
```

### 2. Configure GCP Authentication

```bash
# Authenticate with Google Cloud
gcloud auth login
gcloud auth application-default login

# Set your project ID
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID
```

### 3. Configure Environment Variables

```bash
# Set environment variables
export TF_VAR_project_id="your-project-id"
export TF_VAR_region="us-central1"
export TF_VAR_environment="dev"
```

### 4. Deploy Infrastructure

```bash
# Navigate to environment directory
cd infrastructure/environments/dev

# Initialize Terraform
terraform init

# Review the plan
terraform plan -var-file=terraform.tfvars

# Apply the infrastructure
terraform apply -var-file=terraform.tfvars
```

### 5. Verify Deployment

```bash
# Check deployed resources
gcloud compute instances list --project=$PROJECT_ID
gcloud run services list --project=$PROJECT_ID
gcloud sql instances list --project=$PROJECT_ID
```

## Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `project_id` | GCP Project ID | - | Yes |
| `region` | GCP Region | `us-central1` | No |
| `environment` | Environment name | `dev` | No |

### Customizing Resources

Edit the `terraform.tfvars` file to customize your deployment:

```hcl
project_id  = "your-project-id"
region      = "us-central1"
environment = "dev"
```

## CI/CD Pipeline

### Available Pipelines

The project includes two active CI/CD workflows:

#### **1. Development Pipeline** ✅ **Active & Working**
- **File**: `dev-pipeline.yml`
- **Status**: Fully functional and actively running
- **Features**:
  - Terraform format and validation checks
  - Full Terraform planning and deployment
  - Development environment deployment
  - Resource verification
  - Automated workflow dispatch

#### **2. Trivy Security Scan** ✅ **Active & Working**
- **File**: `trivy-scan.yml`
- **Status**: Fully functional with passing security scans
- **Features**:
  - Vulnerability scanning (CRITICAL/HIGH severity)
  - Secret detection (API keys, credentials)
  - Infrastructure as Code scanning (Terraform security)
  - GitHub Security tab integration
  - Daily automated scans
  - PR comments with scan results

### Pipeline Status

| Pipeline | Status | Description |
|----------|--------|-------------|
| Development Pipeline | ✅ Working | Terraform validation and deployment |
| Trivy Security Scan | ✅ Working | Comprehensive security scanning |

### Manual Deployment

#### Multi-Region Deployment

**Using GitHub CLI (Recommended)**:
```bash
# Deploy all regions
gh workflow run dev-pipeline.yml -f operation=apply -f region=all

# Deploy specific region
gh workflow run dev-pipeline.yml -f operation=apply -f region=us-central1

# Plan all regions
gh workflow run dev-pipeline.yml -f operation=plan -f region=all

# Destroy all regions (⚠️ REMOVES ALL RESOURCES)
gh workflow run dev-pipeline.yml -f operation=destroy -f region=all

# Run security scan manually
gh workflow run trivy-scan.yml
```

**Using Deployment Scripts**:

**PowerShell (Windows)**:
```powershell
# Deploy all regions
.\scripts\deploy-multi-region.ps1 -Operation apply -Region all

# Deploy specific region
.\scripts\deploy-multi-region.ps1 -Operation apply -Region us-central1

# Plan deployment
.\scripts\deploy-multi-region.ps1 -Operation plan -Region all
```

**Bash (Linux/Mac)**:
```bash
# Deploy all regions
./scripts/deploy-multi-region.sh -o apply -r all

# Deploy specific region
./scripts/deploy-multi-region.sh -o apply -r us-central1

# Plan deployment
./scripts/deploy-multi-region.sh -o plan -r all
```

#### Single Region Deployment (Legacy)

For backward compatibility, you can still deploy to a single region:

```bash
# Plan infrastructure changes (safe, no changes made)
gh workflow run dev-pipeline.yml -f operation=plan -f region=us-central1

# Deploy infrastructure (creates/updates resources)
gh workflow run dev-pipeline.yml -f operation=apply -f region=us-central1

# Destroy infrastructure (⚠️ REMOVES ALL RESOURCES)
gh workflow run dev-pipeline.yml -f operation=destroy -f region=us-central1

# Run security scan
gh workflow run trivy-scan.yml
```

### ⚠️ Destroy Operation Warning

The `destroy` operation will **permanently delete ALL infrastructure resources** in the development environment, including:

- **Compute Resources**: VM instances, instance groups, load balancers
- **Storage**: Application data buckets, logs buckets (terraform state bucket preserved)
- **Databases**: Cloud SQL instances, Redis cache
- **Networking**: VPC, subnets, firewall rules
- **Security**: Service accounts, IAM bindings, KMS keys
- **Monitoring**: Alert policies, SLOs, logging configurations

**This action cannot be undone!** Only use destroy when you need to completely tear down the environment.

### GCP Setup Requirements

To use the deployment pipelines, you need:

1. **GCP Project**: Create a project with billing enabled
2. **Service Account**: Create a service account with required permissions
3. **GitHub Secrets**: Configure the following secrets:
   - `GCP_SA_KEY`: Service account JSON key
   - `GCP_PROJECT_ID`: Target GCP project ID
   - `GCP_REGION`: Default GCP region

**Note**: The Trivy security scanning workflow runs independently and doesn't require GCP setup - it scans your Terraform code for security issues without needing cloud credentials.

## Modules

### Available Modules

| Module | Purpose | Resources |
|--------|---------|-----------|
| `compute/cloud-run` | Serverless containers | Cloud Run services, IAM |
| `compute/gke` | Kubernetes clusters | GKE cluster, node pools |
| `compute/instances` | Virtual machines | Compute Engine, MIGs |
| `compute/load-balancer` | Load balancing | Global load balancer |
| `database/cloud-sql` | Managed databases | Cloud SQL, databases, users |
| `database/redis` | Caching layer | Memorystore Redis |
| `monitoring/cloud-monitoring` | Observability | Dashboards, alerts, SLOs |
| `monitoring/cloud-logging` | Log management | Log sinks, metrics |
| `networking/vpc` | Network foundation | VPC, subnets, routes |
| `networking/firewall` | Security rules | Firewall rules, policies |
| `security/iam` | Access control | Service accounts, roles |
| `security/kms` | Encryption | Key rings, crypto keys |
| `security/secret-manager` | Secret storage | Secrets, versions |
| `storage/buckets` | Object storage | Cloud Storage buckets |
| `storage/container-registry` | Container images | Artifact Registry |

## Security

### Security Features

- **Identity & Access Management**: Least-privilege service accounts
- **Network Security**: Private subnets, firewall rules, VPC Service Controls
- **Data Protection**: Customer-managed encryption keys, secret rotation
- **Compliance**: SOC 2, PCI DSS, HIPAA ready configurations
- **Audit Logging**: Comprehensive activity tracking

### Automated Security Scanning

This repository includes comprehensive security scanning with **Trivy**:

- **✅ Vulnerability Scanning**: Scans for CRITICAL and HIGH severity vulnerabilities
- **✅ Secret Detection**: Identifies exposed API keys, passwords, and credentials
- **✅ Infrastructure as Code Scanning**: Validates Terraform configurations for security best practices
- **✅ GitHub Security Integration**: Results automatically uploaded to GitHub Security tab
- **✅ Daily Automated Scans**: Continuous security monitoring
- **✅ PR Security Reviews**: Automatic security comments on pull requests

### Current Security Status

- **Critical Vulnerabilities**: 0 found ✅
- **Exposed Secrets**: 0 found ✅
- **Security Badge**: Passing ✅
- **IaC Misconfigurations**: 7 minor warnings (non-critical)

The security scanning runs automatically on every push and pull request, ensuring continuous security monitoring of your infrastructure code.

## Monitoring & Observability

### Key Metrics

- **Infrastructure**: Resource utilization, availability, performance
- **Application**: Response times, error rates, throughput
- **Business**: User activity, transaction volumes, revenue metrics

### Alerting

- **Critical**: Service downtime, security incidents
- **Warning**: Resource utilization, performance degradation
- **Info**: Deployment notifications, maintenance windows

## Troubleshooting

### Common Issues

#### **Authentication Errors**
```bash
# Re-authenticate with Google Cloud
gcloud auth application-default login
```

#### **API Not Enabled**
```bash
# Enable required APIs
gcloud services enable compute.googleapis.com
gcloud services enable run.googleapis.com
```

#### **Insufficient Quota**
```bash
# Check current quotas
gcloud compute project-info describe --project=$PROJECT_ID
```

## Contributing

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and validation
5. Submit a pull request

### Code Standards

- Follow Terraform best practices
- Use consistent naming conventions
- Document all non-obvious configurations
- Maintain test coverage
- Update documentation for changes

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues and questions:

- **Documentation**: [docs/](docs/)
- **Issues**: [GitHub Issues](https://github.com/your-org/terraform-gcp/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/terraform-gcp/discussions)
- **Email**: platform-engineering@your-company.com

---

**Last Updated**: September 2025  
**Version**: 1.1.0  
**Maintainer**: Platform Engineering Team  
**Security Status**: ✅ Passing (0 critical vulnerabilities, 0 exposed secrets)
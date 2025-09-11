# Architecture Diagrams

This document contains the visual representations of the GCP infrastructure architecture defined in this Terraform project.

## Generated Diagrams

### 1. Comprehensive Architecture Diagram
![Comprehensive GCP Architecture](gcp_architecture_diagram.png)

This diagram shows the complete multi-region GCP infrastructure including:
- **Global Resources**: DNS, Load Balancer, IAM, KMS, Monitoring, Container Registry
- **Primary Region (us-central1)**: VPC, Subnets, GKE, Cloud Run, Compute Engine, Cloud SQL, Redis, Storage
- **Secondary Region (us-east1)**: Mirror infrastructure for high availability
- **Cross-Region Connectivity**: VPC Peering and VPN Tunnels
- **Security & Compliance**: VPC Service Controls, Binary Authorization, Workload Identity

### 2. Simplified Architecture Overview
![Simplified GCP Architecture](gcp_simplified_diagram.png)

This high-level diagram provides an overview of the key components:
- **Global Services**: DNS, Load Balancer, IAM, Monitoring
- **Multi-Region Deployment**: Primary and Secondary regions with GKE, Cloud SQL, and Storage
- **Cross-Region Connectivity**: VPC Peering for inter-region communication

## How to Regenerate Diagrams

The diagrams are generated using the [Diagrams](https://diagrams.mingrammer.com/) Python library.

### Prerequisites
- Python 3.6+
- diagrams library

### Installation
```bash
pip install diagrams
```

### Generation
```bash
python generate_architecture_diagram.py
```

This will create two PNG files:
- `gcp_architecture_diagram.png` - Comprehensive view
- `gcp_simplified_diagram.png` - High-level overview

## Architecture Components

### Global Resources
- **Cloud DNS**: Domain name resolution
- **Global Load Balancer**: Traffic distribution across regions
- **IAM & Service Accounts**: Identity and access management
- **Cloud KMS**: Key management and encryption
- **Cloud Monitoring**: Infrastructure monitoring and alerting
- **Artifact Registry**: Container image storage

### Regional Resources

#### Primary Region (us-central1)
- **VPC Network**: Custom virtual private cloud
- **Subnets**: Web, App, Database, and GKE subnets
- **Firewall Rules**: Network security policies
- **GKE Cluster**: Kubernetes container orchestration
- **Cloud Run**: Serverless container platform
- **Compute Engine**: Virtual machines
- **Cloud SQL**: Managed PostgreSQL database
- **Redis Cache**: Memorystore for caching
- **Cloud Storage**: Object storage buckets
- **Filestore**: Managed file storage

#### Secondary Region (us-east1)
- Mirror infrastructure for disaster recovery and high availability

### Security Features
- **VPC Service Controls**: Network perimeter security
- **Binary Authorization**: Container image security
- **Workload Identity**: Secure service-to-service authentication
- **Private Clusters**: GKE clusters with private endpoints
- **Encryption**: Customer-managed encryption keys

### Cross-Region Connectivity
- **VPC Peering**: Direct network connectivity between regions
- **VPN Tunnels**: Secure inter-region communication
- **Database Replication**: Cross-region data replication

## Usage in Documentation

These diagrams can be included in:
- Project README files
- Architecture documentation
- Presentation materials
- Team onboarding materials

The diagrams are automatically generated from the Terraform infrastructure code, ensuring they stay up-to-date with the actual deployed resources.

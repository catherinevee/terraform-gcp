#!/usr/bin/env python3
"""
GCP Terraform Infrastructure Architecture Diagram Generator

This script generates a comprehensive architecture diagram for the terraform-gcp project
using the diagrams Python library. It visualizes the multi-region GCP infrastructure
including networking, compute, database, security, and monitoring components.

Author: Generated for terraform-gcp project
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.gcp.compute import ComputeEngine, GKE, Run
from diagrams.gcp.database import SQL, Memorystore
from diagrams.gcp.network import VPC, LoadBalancing, DNS, FirewallRules
from diagrams.gcp.storage import GCS, Filestore
from diagrams.gcp.security import Iam, KMS
from diagrams.gcp.analytics import BigQuery
from diagrams.gcp.devtools import ContainerRegistry
from diagrams.onprem.client import Users
from diagrams.onprem.network import Internet

def create_gcp_architecture_diagram():
    """Create a comprehensive GCP architecture diagram"""
    
    with Diagram("Terraform GCP Multi-Region Infrastructure", 
                 filename="gcp_architecture_diagram", 
                 show=False, 
                 direction="TB"):
        
        # External users and internet
        users = Users("Users")
        internet = Internet("Internet")
        
        # Global resources
        with Cluster("Global Resources"):
            dns = DNS("Cloud DNS")
            lb_global = LoadBalancing("Global Load Balancer")
            iam = Iam("IAM & Service Accounts")
            kms = KMS("Cloud KMS")
            monitoring = BigQuery("Cloud Monitoring")
            registry = ContainerRegistry("Artifact Registry")
        
        # Primary Region (us-central1)
        with Cluster("Primary Region (us-central1)"):
            with Cluster("VPC Network"):
                vpc_primary = VPC("VPC")
                
                with Cluster("Subnets"):
                    web_subnet = VPC("Web Subnet")
                    app_subnet = VPC("App Subnet")
                    db_subnet = VPC("DB Subnet")
                    gke_subnet = VPC("GKE Subnet")
                
                firewall = FirewallRules("Firewall Rules")
                
                with Cluster("Compute Layer"):
                    gke_primary = GKE("GKE Cluster")
                    cloud_run_primary = Run("Cloud Run")
                    compute_primary = ComputeEngine("Compute Engine")
                
                with Cluster("Database Layer"):
                    sql_primary = SQL("Cloud SQL\n(PostgreSQL)")
                    redis_primary = Memorystore("Redis Cache")
                
                with Cluster("Storage Layer"):
                    storage_primary = GCS("Cloud Storage")
                    filestore_primary = Filestore("Filestore")
        
        # Secondary Region (us-east1)
        with Cluster("Secondary Region (us-east1)"):
            with Cluster("VPC Network"):
                vpc_secondary = VPC("VPC")
                
                with Cluster("Subnets"):
                    web_subnet_2 = VPC("Web Subnet")
                    app_subnet_2 = VPC("App Subnet")
                    db_subnet_2 = VPC("DB Subnet")
                    gke_subnet_2 = VPC("GKE Subnet")
                
                firewall_2 = FirewallRules("Firewall Rules")
                
                with Cluster("Compute Layer"):
                    gke_secondary = GKE("GKE Cluster")
                    cloud_run_secondary = Run("Cloud Run")
                    compute_secondary = ComputeEngine("Compute Engine")
                
                with Cluster("Database Layer"):
                    sql_secondary = SQL("Cloud SQL\n(PostgreSQL)")
                    redis_secondary = Memorystore("Redis Cache")
                
                with Cluster("Storage Layer"):
                    storage_secondary = GCS("Cloud Storage")
                    filestore_secondary = Filestore("Filestore")
        
        # Cross-region connectivity
        with Cluster("Cross-Region Connectivity"):
            vpc_peering = VPC("VPC Peering")
            vpn_tunnel = VPC("VPN Tunnel")
        
        # Security and compliance
        with Cluster("Security & Compliance"):
            vpc_sc = VPC("VPC Service Controls")
            binary_auth = Iam("Binary Authorization")
            workload_identity = Iam("Workload Identity")
        
        # Data flow connections
        users >> internet
        internet >> dns
        dns >> lb_global
        
        # Global load balancer to regions
        lb_global >> gke_primary
        lb_global >> gke_secondary
        lb_global >> cloud_run_primary
        lb_global >> cloud_run_secondary
        
        # Primary region internal connections
        gke_primary >> sql_primary
        gke_primary >> redis_primary
        gke_primary >> storage_primary
        cloud_run_primary >> sql_primary
        cloud_run_primary >> redis_primary
        compute_primary >> sql_primary
        compute_primary >> storage_primary
        
        # Secondary region internal connections
        gke_secondary >> sql_secondary
        gke_secondary >> redis_secondary
        gke_secondary >> storage_secondary
        cloud_run_secondary >> sql_secondary
        cloud_run_secondary >> redis_secondary
        compute_secondary >> sql_secondary
        compute_secondary >> storage_secondary
        
        # Cross-region connections
        vpc_primary >> vpc_peering
        vpc_secondary >> vpc_peering
        vpc_primary >> vpn_tunnel
        vpc_secondary >> vpn_tunnel
        
        # Database replication
        sql_primary >> sql_secondary
        
        # Security connections
        iam >> gke_primary
        iam >> gke_secondary
        iam >> cloud_run_primary
        iam >> cloud_run_secondary
        kms >> sql_primary
        kms >> sql_secondary
        kms >> storage_primary
        kms >> storage_secondary
        
        # Monitoring connections
        monitoring >> gke_primary
        monitoring >> gke_secondary
        monitoring >> sql_primary
        monitoring >> sql_secondary
        
        # Container registry
        registry >> gke_primary
        registry >> gke_secondary
        registry >> cloud_run_primary
        registry >> cloud_run_secondary
        
        # Security controls
        vpc_sc >> vpc_primary
        vpc_sc >> vpc_secondary
        binary_auth >> gke_primary
        binary_auth >> gke_secondary
        workload_identity >> gke_primary
        workload_identity >> gke_secondary

def create_simplified_architecture_diagram():
    """Create a simplified high-level architecture diagram"""
    
    with Diagram("GCP Infrastructure Overview", 
                 filename="gcp_simplified_diagram", 
                 show=False, 
                 direction="TB"):
        
        # External access
        users = Users("Users")
        internet = Internet("Internet")
        
        # Global services
        with Cluster("Global Services"):
            dns = DNS("Cloud DNS")
            lb = LoadBalancing("Global Load Balancer")
            iam = Iam("IAM & Security")
            monitoring = BigQuery("Monitoring & Logging")
        
        # Multi-region deployment
        with Cluster("Multi-Region Deployment"):
            with Cluster("Primary Region\n(us-central1)"):
                gke_primary = GKE("GKE Cluster")
                sql_primary = SQL("Cloud SQL")
                storage_primary = GCS("Cloud Storage")
            
            with Cluster("Secondary Region\n(us-east1)"):
                gke_secondary = GKE("GKE Cluster")
                sql_secondary = SQL("Cloud SQL")
                storage_secondary = GCS("Cloud Storage")
        
        # Cross-region connectivity
        vpc_peering = VPC("VPC Peering")
        
        # Connections
        users >> internet
        internet >> dns
        dns >> lb
        lb >> gke_primary
        lb >> gke_secondary
        gke_primary >> sql_primary
        gke_primary >> storage_primary
        gke_secondary >> sql_secondary
        gke_secondary >> storage_secondary
        sql_primary >> sql_secondary  # Replication
        gke_primary >> vpc_peering
        gke_secondary >> vpc_peering
        iam >> gke_primary
        iam >> gke_secondary
        monitoring >> gke_primary
        monitoring >> gke_secondary

if __name__ == "__main__":
    print("Generating GCP architecture diagrams...")
    
    # Generate comprehensive diagram
    print("Creating comprehensive architecture diagram...")
    create_gcp_architecture_diagram()
    print("✅ Comprehensive diagram saved as 'gcp_architecture_diagram.png'")
    
    # Generate simplified diagram
    print("Creating simplified architecture diagram...")
    create_simplified_architecture_diagram()
    print("✅ Simplified diagram saved as 'gcp_simplified_diagram.png'")
    
    print("\n🎉 Architecture diagrams generated successfully!")
    print("📁 Files created:")
    print("   - gcp_architecture_diagram.png (comprehensive view)")
    print("   - gcp_simplified_diagram.png (high-level overview)")
    print("\n💡 You can now include these diagrams in your documentation!")

# Backend configuration for regional resources
terraform {
  backend "gcs" {
    bucket = "acme-ecommerce-platform-dev-terraform-state"
    prefix = "terraform/state/us-central1"
  }
}
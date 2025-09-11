# Backend configuration for global resources
terraform {
  backend "gcs" {
    bucket = "cataziza-ecommerce-platform-dev-terraform-state"
    prefix = "terraform/state/global"
  }
}


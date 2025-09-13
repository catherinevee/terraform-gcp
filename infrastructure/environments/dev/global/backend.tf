# Backend configuration for global resources
terraform {
  backend "gcs" {
    bucket = "cataziza-platform-dev-terraform-state"
    prefix = "terraform/state/global"
  }
}


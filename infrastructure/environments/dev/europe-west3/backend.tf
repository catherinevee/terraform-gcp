# Backend configuration for regional resources
terraform {
  backend "gcs" {
    bucket = "cataziza-platform-dev-terraform-state"
    prefix = "terraform/state/europe-west3"
  }
}


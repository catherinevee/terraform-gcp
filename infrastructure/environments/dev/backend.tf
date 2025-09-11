terraform {
  backend "gcs" {
    bucket = "acme-ecommerce-platform-dev-terraform-state"
    prefix = "terraform/state"
  }
}

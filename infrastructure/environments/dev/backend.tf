terraform {
  backend "gcs" {
    bucket = "terragrunt-471602-terraform-state-dev"
    prefix = "terraform/state"
  }
}

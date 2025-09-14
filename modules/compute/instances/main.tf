# Compute Instances Module
# Creates compute instances and instance groups

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.45.2"
    }
  }
}

# Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "zone" {
  description = "GCP zone"
  type        = string
}

variable "instance_group_managers" {
  description = "Map of instance group managers to create"
  type = map(object({
    name                = string
    description         = string
    base_instance_name  = string
    zone                = string
    template_key        = string
    target_size         = number
    enable_auto_healing = bool
    update_policy = object({
      type                         = string
      instance_redistribution_type = string
      minimal_action               = string
      max_surge_fixed              = number
      max_unavailable_fixed        = number
    })
  }))
  default = {}
}

# Instance templates
resource "google_compute_instance_template" "templates" {
  for_each = var.instance_group_managers

  name_prefix  = "${each.value.base_instance_name}-template-"
  description  = each.value.description
  project      = var.project_id
  machine_type = "e2-micro"

  tags = ["http", "https", "ssh"]

  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    startup-script = <<-EOF
      #!/bin/bash
      apt-get update
      apt-get install -y nginx
      systemctl start nginx
      systemctl enable nginx
    EOF
  }

  service_account {
    email  = "terraform-github-actions@${var.project_id}.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }
}

# Instance group managers
resource "google_compute_instance_group_manager" "groups" {
  for_each = var.instance_group_managers

  name               = each.value.name
  description        = each.value.description
  base_instance_name = each.value.base_instance_name
  zone               = each.value.zone
  project            = var.project_id
  target_size        = each.value.target_size

  version {
    instance_template = google_compute_instance_template.templates[each.key].id
  }

  update_policy {
    type                         = each.value.update_policy.type
    instance_redistribution_type = each.value.update_policy.instance_redistribution_type
    minimal_action               = each.value.update_policy.minimal_action
    max_surge_fixed              = each.value.update_policy.max_surge_fixed
    max_unavailable_fixed        = each.value.update_policy.max_unavailable_fixed
  }

}

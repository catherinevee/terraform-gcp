# Cross-Region Networking Module
# Creates VPN tunnels and cross-region connectivity

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

variable "vpn_shared_secret" {
  description = "VPN shared secret"
  type        = string
}

variable "regions" {
  description = "List of regions to connect"
  type        = list(string)
  default     = ["europe-west1", "europe-west3"]
}

# VPN gateways
resource "google_compute_vpn_gateway" "gateways" {
  for_each = toset(var.regions)

  name    = "vpn-gateway-${each.key}"
  network = "default"
  region  = each.key
  project = var.project_id
}

# VPN tunnels
resource "google_compute_vpn_tunnel" "tunnels" {
  for_each = toset(var.regions)

  name          = "vpn-tunnel-${each.key}"
  region        = each.key
  project       = var.project_id
  peer_ip       = google_compute_vpn_gateway.gateways[each.key].self_link
  shared_secret = var.vpn_shared_secret

  target_vpn_gateway = google_compute_vpn_gateway.gateways[each.key].id

  depends_on = [google_compute_forwarding_rule.esp, google_compute_forwarding_rule.udp500, google_compute_forwarding_rule.udp4500]
}

# Forwarding rules for VPN
resource "google_compute_forwarding_rule" "esp" {
  for_each = toset(var.regions)

  name        = "fr-esp-${each.key}"
  ip_protocol = "ESP"
  ip_address  = google_compute_vpn_gateway.gateways[each.key].self_link
  target      = google_compute_vpn_gateway.gateways[each.key].id
  region      = each.key
  project     = var.project_id
}

resource "google_compute_forwarding_rule" "udp500" {
  for_each = toset(var.regions)

  name        = "fr-udp500-${each.key}"
  ip_protocol = "UDP"
  port_range  = "500"
  ip_address  = google_compute_vpn_gateway.gateways[each.key].self_link
  target      = google_compute_vpn_gateway.gateways[each.key].id
  region      = each.key
  project     = var.project_id
}

resource "google_compute_forwarding_rule" "udp4500" {
  for_each = toset(var.regions)

  name        = "fr-udp4500-${each.key}"
  ip_protocol = "UDP"
  port_range  = "4500"
  ip_address  = google_compute_vpn_gateway.gateways[each.key].self_link
  target      = google_compute_vpn_gateway.gateways[each.key].id
  region      = each.key
  project     = var.project_id
}

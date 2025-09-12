# Cross-Region Networking Module
# Handles cross-region connectivity for a single global VPC
# Note: VPC peering is not needed since we use a single global VPC

# Note: VPN gateways and tunnels are not needed for a single global VPC
# Cross-region connectivity is handled automatically by GCP's global network

# Cloud NAT for primary region
resource "google_compute_router" "primary_router" {
  name    = "${var.project_id}-${var.primary_region}-router"
  region  = var.primary_region
  network = var.primary_network_self_link
}

resource "google_compute_router_nat" "primary_nat" {
  name                               = "${var.project_id}-${var.primary_region}-nat"
  router                             = google_compute_router.primary_router.name
  region                             = var.primary_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Cloud NAT for secondary region
resource "google_compute_router" "secondary_router" {
  name    = "${var.project_id}-${var.secondary_region}-router"
  region  = var.secondary_region
  network = var.secondary_network_self_link
}

resource "google_compute_router_nat" "secondary_nat" {
  name                               = "${var.project_id}-${var.secondary_region}-nat"
  router                             = google_compute_router.secondary_router.name
  region                             = var.secondary_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}


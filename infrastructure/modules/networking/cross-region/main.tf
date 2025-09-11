# Cross-Region Networking Module
# Handles VPC peering, VPN tunnels, and cross-region connectivity

# VPC Peering for cross-region connectivity
resource "google_compute_network_peering" "primary_to_secondary" {
  name         = "${var.project_id}-${var.primary_region}-to-${var.secondary_region}"
  network      = var.primary_network_self_link
  peer_network = var.secondary_network_self_link

  depends_on = [google_compute_network_peering.secondary_to_primary]
}

resource "google_compute_network_peering" "secondary_to_primary" {
  name         = "${var.project_id}-${var.secondary_region}-to-${var.primary_region}"
  network      = var.secondary_network_self_link
  peer_network = var.primary_network_self_link

  depends_on = [google_compute_network_peering.primary_to_secondary]
}

# VPN Gateway for primary region
resource "google_compute_vpn_gateway" "primary_vpn_gateway" {
  name    = "${var.project_id}-${var.primary_region}-vpn-gateway"
  network = var.primary_network_self_link
  region  = var.primary_region
}

# VPN Gateway for secondary region
resource "google_compute_vpn_gateway" "secondary_vpn_gateway" {
  name    = "${var.project_id}-${var.secondary_region}-vpn-gateway"
  network = var.secondary_network_self_link
  region  = var.secondary_region
}

# External IP for primary VPN gateway
resource "google_compute_address" "primary_vpn_ip" {
  name   = "${var.project_id}-${var.primary_region}-vpn-ip"
  region = var.primary_region
}

# External IP for secondary VPN gateway
resource "google_compute_address" "secondary_vpn_ip" {
  name   = "${var.project_id}-${var.secondary_region}-vpn-ip"
  region = var.secondary_region
}

# Forwarding rule for primary VPN gateway
resource "google_compute_forwarding_rule" "primary_vpn_forwarding_rule" {
  name   = "${var.project_id}-${var.primary_region}-vpn-forwarding-rule"
  region = var.primary_region

  ip_protocol = "ESP"
  ip_address  = google_compute_address.primary_vpn_ip.address
  target      = google_compute_vpn_gateway.primary_vpn_gateway.id
}

# Forwarding rule for secondary VPN gateway
resource "google_compute_forwarding_rule" "secondary_vpn_forwarding_rule" {
  name   = "${var.project_id}-${var.secondary_region}-vpn-forwarding-rule"
  region = var.secondary_region

  ip_protocol = "ESP"
  ip_address  = google_compute_address.secondary_vpn_ip.address
  target      = google_compute_vpn_gateway.secondary_vpn_gateway.id
}

# VPN tunnel from primary to secondary
resource "google_compute_vpn_tunnel" "primary_to_secondary_tunnel" {
  name          = "${var.project_id}-${var.primary_region}-to-${var.secondary_region}-tunnel"
  region        = var.primary_region
  peer_ip       = google_compute_address.secondary_vpn_ip.address
  shared_secret = var.vpn_shared_secret

  target_vpn_gateway = google_compute_vpn_gateway.primary_vpn_gateway.id

  local_traffic_selector  = ["10.0.0.0/8"]
  remote_traffic_selector = ["10.1.0.0/8"]

  depends_on = [google_compute_forwarding_rule.primary_vpn_forwarding_rule]
}

# VPN tunnel from secondary to primary
resource "google_compute_vpn_tunnel" "secondary_to_primary_tunnel" {
  name          = "${var.project_id}-${var.secondary_region}-to-${var.primary_region}-tunnel"
  region        = var.secondary_region
  peer_ip       = google_compute_address.primary_vpn_ip.address
  shared_secret = var.vpn_shared_secret

  target_vpn_gateway = google_compute_vpn_gateway.secondary_vpn_gateway.id

  local_traffic_selector  = ["10.1.0.0/8"]
  remote_traffic_selector = ["10.0.0.0/8"]

  depends_on = [google_compute_forwarding_rule.secondary_vpn_forwarding_rule]
}

# Routes for cross-region traffic
resource "google_compute_route" "primary_to_secondary_route" {
  name                = "${var.project_id}-${var.primary_region}-to-${var.secondary_region}-route"
  dest_range          = "10.1.0.0/8"
  network             = var.primary_network_self_link
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.primary_to_secondary_tunnel.id
  priority            = var.vpn_route_priority
}

resource "google_compute_route" "secondary_to_primary_route" {
  name                = "${var.project_id}-${var.secondary_region}-to-${var.primary_region}-route"
  dest_range          = "10.0.0.0/8"
  network             = var.secondary_network_self_link
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.secondary_to_primary_tunnel.id
  priority            = var.vpn_route_priority
}

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


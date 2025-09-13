# Cross-Region Networking Outputs

output "vpc_peerings" {
  description = "VPC peering connections"
  value = {
    primary_to_secondary = google_compute_network_peering.primary_to_secondary.name
    secondary_to_primary = google_compute_network_peering.secondary_to_primary.name
  }
}

output "vpn_gateways" {
  description = "VPN gateway information"
  value = {
    primary = {
      name = google_compute_vpn_gateway.primary_vpn_gateway.name
      ip   = google_compute_address.primary_vpn_ip.address
    }
    secondary = {
      name = google_compute_vpn_gateway.secondary_vpn_gateway.name
      ip   = google_compute_address.secondary_vpn_ip.address
    }
  }
}

output "vpn_tunnels" {
  description = "VPN tunnel information"
  value = {
    primary_to_secondary = google_compute_vpn_tunnel.primary_to_secondary_tunnel.name
    secondary_to_primary = google_compute_vpn_tunnel.secondary_to_primary_tunnel.name
  }
}

output "routes" {
  description = "Cross-region routes"
  value = {
    primary_to_secondary = google_compute_route.primary_to_secondary_route.name
    secondary_to_primary = google_compute_route.secondary_to_primary_route.name
  }
}

output "nat_gateways" {
  description = "Cloud NAT gateways"
  value = {
    primary   = google_compute_router_nat.primary_nat.name
    secondary = google_compute_router_nat.secondary_nat.name
  }
}



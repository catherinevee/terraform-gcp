resource "google_compute_subnetwork" "subnets" {
  for_each = { for subnet in var.subnets : subnet.subnet_name => subnet }
  
  name          = each.value.subnet_name
  ip_cidr_range = each.value.subnet_ip
  region        = each.value.subnet_region
  network       = var.network_name
  project       = var.project_id
  
  private_ip_google_access = each.value.subnet_private_access
  enable_flow_logs         = each.value.subnet_flow_logs
  
  dynamic "secondary_ip_range" {
    for_each = var.secondary_ranges[each.value.subnet_name] != null ? var.secondary_ranges[each.value.subnet_name] : []
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }
}

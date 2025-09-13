# DNS Module for Global DNS Management

# DNS Zone
resource "google_dns_managed_zone" "zone" {
  name        = var.zone_name
  dns_name    = var.dns_name
  description = "DNS zone for ${var.environment} environment"

  labels = {
    environment = var.environment
    purpose     = "dns-management"
    managed_by  = "terraform"
  }
}

# DNS Records
resource "google_dns_record_set" "records" {
  for_each = var.records

  name = "${each.value.name}.${google_dns_managed_zone.zone.dns_name}"
  type = each.value.type
  ttl  = each.value.ttl

  managed_zone = google_dns_managed_zone.zone.name

  rrdatas = [var.load_balancer_ip]
}

# Outputs
output "zone_name" {
  description = "DNS zone name"
  value       = google_dns_managed_zone.zone.name
}

output "zone_dns_name" {
  description = "DNS zone DNS name"
  value       = google_dns_managed_zone.zone.dns_name
}

output "zone_id" {
  description = "DNS zone ID"
  value       = google_dns_managed_zone.zone.id
}



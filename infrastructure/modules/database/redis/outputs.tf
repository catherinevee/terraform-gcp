output "instances" {
  description = "Created Redis instances"
  value       = google_redis_instance.instance
}

output "instance_hosts" {
  description = "Redis instance host addresses"
  value       = { for k, v in google_redis_instance.instance : k => v.host }
}

output "instance_ports" {
  description = "Redis instance ports"
  value       = { for k, v in google_redis_instance.instance : k => v.port }
}

output "instance_current_location_ids" {
  description = "Redis instance current location IDs"
  value       = { for k, v in google_redis_instance.instance : k => v.current_location_id }
}

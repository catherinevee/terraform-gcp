output "instances" {
  description = "Created Cloud SQL instances"
  value       = google_sql_database_instance.instance
}

output "instance_connection_names" {
  description = "Cloud SQL instance connection names"
  value       = { for k, v in google_sql_database_instance.instance : k => v.connection_name }
}

output "instance_private_ip_addresses" {
  description = "Cloud SQL instance private IP addresses"
  value       = { for k, v in google_sql_database_instance.instance : k => v.private_ip_address }
}

output "databases" {
  description = "Created databases"
  value       = google_sql_database.database
}

output "users" {
  description = "Created database users"
  value       = google_sql_user.user
}

output "ssl_certs" {
  description = "Created SSL certificates"
  value       = google_sql_ssl_cert.client_cert
}

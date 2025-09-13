# PowerShell script to import existing GCP resources into Terraform state

Write-Host "Starting resource import process for Europe West1..."

# Import health check
Write-Host "Importing health check..."
terraform import 'module.compute.google_compute_health_check.health_check["web-health-check"]' 'projects/cataziza-platform-dev/global/healthChecks/cataziza-web-health-check'

# Import firewall rules
Write-Host "Importing firewall rules..."
terraform import 'module.firewall.google_compute_firewall.allow_internal' 'projects/cataziza-platform-dev/global/firewalls/cataziza-platform-dev-vpc-allow-internal'
terraform import 'module.firewall.google_compute_firewall.allow_ssh' 'projects/cataziza-platform-dev/global/firewalls/cataziza-platform-dev-vpc-allow-ssh'
terraform import 'module.firewall.google_compute_firewall.allow_http' 'projects/cataziza-platform-dev/global/firewalls/cataziza-platform-dev-vpc-allow-http'
terraform import 'module.firewall.google_compute_firewall.allow_https' 'projects/cataziza-platform-dev/global/firewalls/cataziza-platform-dev-vpc-allow-https'

Write-Host "Resource import process completed!"

# Data source to reference existing health check
data "google_compute_health_check" "existing_health_check" {
  name = "cataziza-ecommerce-web-health-check"
}

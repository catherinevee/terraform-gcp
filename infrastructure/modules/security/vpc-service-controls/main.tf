# VPC Service Controls Access Policy
resource "google_access_context_manager_access_policy" "access_policy" {
  count = var.enable_vpc_service_controls ? 1 : 0

  parent = "organizations/${var.organization_id}"
  title  = var.access_policy_title
}

# VPC Service Controls Service Perimeter
resource "google_access_context_manager_service_perimeter" "service_perimeter" {
  count = var.enable_vpc_service_controls ? 1 : 0

  parent = "accessPolicies/${google_access_context_manager_access_policy.access_policy[0].name}"
  name   = "accessPolicies/${google_access_context_manager_access_policy.access_policy[0].name}/servicePerimeters/${var.service_perimeter_name}"
  title  = var.service_perimeter_title

  status {
    resources = var.service_perimeter_resources

    restricted_services = var.restricted_services

    dynamic "vpc_accessible_services" {
      for_each = var.enable_vpc_accessible_services ? [1] : []
      content {
        enable_restriction = var.vpc_accessible_services_enable_restriction
        allowed_services   = var.vpc_accessible_services_allowed
      }
    }

    dynamic "ingress_policies" {
      for_each = var.ingress_policies
      content {
        dynamic "ingress_from" {
          for_each = ingress_policies.value.ingress_from
          content {
            sources {
              dynamic "access_level" {
                for_each = ingress_from.value.access_level != null ? [ingress_from.value.access_level] : []
                content {
                  access_level = access_level.value
                }
              }
            }
          }
        }

        dynamic "ingress_to" {
          for_each = ingress_policies.value.ingress_to
          content {
            resources = ingress_to.value.resources
            operations {
              dynamic "service_name" {
                for_each = ingress_to.value.service_name != null ? [ingress_to.value.service_name] : []
                content {
                  service_name = service_name.value
                }
              }
            }
          }
        }
      }
    }

    dynamic "egress_policies" {
      for_each = var.egress_policies
      content {
        dynamic "egress_from" {
          for_each = egress_policies.value.egress_from
          content {
            identities = egress_from.value.identities
          }
        }

        dynamic "egress_to" {
          for_each = egress_policies.value.egress_to
          content {
            resources = egress_to.value.resources
            operations {
              dynamic "service_name" {
                for_each = egress_to.value.service_name != null ? [egress_to.value.service_name] : []
                content {
                  service_name = service_name.value
                }
              }
            }
          }
        }
      }
    }
  }
}

# VPC Service Controls Access Level
resource "google_access_context_manager_access_level" "access_level" {
  count = var.enable_vpc_service_controls && var.enable_access_level ? 1 : 0

  parent = "accessPolicies/${google_access_context_manager_access_policy.access_policy[0].name}"
  name   = "accessPolicies/${google_access_context_manager_access_policy.access_policy[0].name}/accessLevels/${var.access_level_name}"
  title  = var.access_level_title

  basic {
    conditions {
      dynamic "ip_subnetworks" {
        for_each = var.access_level_ip_subnetworks
        content {
          ip_subnetworks = ip_subnetworks.value
        }
      }

      dynamic "members" {
        for_each = var.access_level_members
        content {
          members = members.value
        }
      }
    }
  }
}

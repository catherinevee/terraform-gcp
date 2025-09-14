# KMS Key Ring
resource "google_kms_key_ring" "key_ring" {
  name     = var.key_ring_name
  location = var.location
  project  = var.project_id
}

# KMS Crypto Keys
resource "google_kms_crypto_key" "crypto_keys" {
  for_each = var.crypto_keys

  name     = each.value.name
  key_ring = google_kms_key_ring.key_ring.id

  purpose = each.value.purpose

  version_template {
    algorithm = each.value.algorithm
  }


  rotation_period = each.value.rotation_period != null ? each.value.rotation_period : null
}

# KMS Key IAM Bindings
resource "google_kms_crypto_key_iam_binding" "crypto_key_iam_bindings" {
  for_each = var.enable_iam_bindings ? var.crypto_key_iam_bindings : {}

  crypto_key_id = google_kms_crypto_key.crypto_keys[each.value.crypto_key_key].id
  role          = each.value.role
  members       = each.value.members
}

# KMS Key Ring IAM Bindings
resource "google_kms_key_ring_iam_binding" "key_ring_iam_bindings" {
  for_each = var.enable_iam_bindings ? var.key_ring_iam_bindings : {}

  key_ring_id = google_kms_key_ring.key_ring.id
  role        = each.value.role
  members     = each.value.members
}

output "key_ring" {
  description = "KMS key ring"
  value       = google_kms_key_ring.key_ring
}

output "key_ring_name" {
  description = "KMS key ring name"
  value       = google_kms_key_ring.key_ring.name
}

output "crypto_keys" {
  description = "KMS crypto keys"
  value       = google_kms_crypto_key.crypto_keys
}

output "crypto_key_names" {
  description = "KMS crypto key names and purposes"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => {
      name    = v.name
      purpose = v.purpose
    }
  }
}

output "key_ring_id" {
  description = "KMS key ring ID"
  value       = google_kms_key_ring.key_ring.id
}

output "crypto_key_ids" {
  description = "KMS crypto key IDs"
  value       = { for k, v in google_kms_crypto_key.crypto_keys : k => v.id }
}

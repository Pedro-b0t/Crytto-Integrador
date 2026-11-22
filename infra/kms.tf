# S6: criptografia em repouso declarada explicitamente com chave gerenciada pelo cliente (CMEK).
# Discos de boot (e os snapshots derivados deles) usam esta chave. O bucket de backup pode reutilizá-la.

# Key rings não podem ser apagados na GCP: o destroy só os remove do state.
# O sufixo aleatório permite recriar o ambiente sem conflito de nome.
resource "random_id" "kms_suffix" {
  byte_length = 3
}

resource "google_kms_key_ring" "this" {
  name     = "kr-${var.project_label}-${random_id.kms_suffix.hex}"
  location = var.region

  depends_on = [google_project_service.apis]
}

resource "google_kms_crypto_key" "cmek" {
  name            = "cmek-${var.project_label}"
  key_ring        = google_kms_key_ring.this.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s" # 90 dias

  # Menor prazo permitido entre o destroy e a destruição definitiva das versões da chave.
  destroy_scheduled_duration = "86400s"
}

# O agente de serviço do Compute Engine cifra e decifra os discos com a chave.
resource "google_kms_crypto_key_iam_member" "compute_agent" {
  crypto_key_id = google_kms_crypto_key.cmek.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.this.number}@compute-system.iam.gserviceaccount.com"

  depends_on = [google_project_service.apis]
}

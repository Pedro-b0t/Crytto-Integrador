
# B6 / S5 / S6 - Backup mínimo do PostgreSQL

resource "random_id" "backup_suffix" {
  byte_length = 3
}

# Identidade gerenciada pelo próprio Cloud Storage.
data "google_storage_project_service_account" "gcs" {
  project = var.project_id

  depends_on = [google_project_service.apis]
}

# Permissão para o Cloud Storage utilizar a chave CMEK.
resource "google_kms_crypto_key_iam_member" "storage_agent" {
  crypto_key_id = google_kms_crypto_key.cmek.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = data.google_storage_project_service_account.gcs.member
}

# Bucket privado para os backups diários.
resource "google_storage_bucket" "backup" {
  name = "${var.project_id}-crytto-backup-${random_id.backup_suffix.hex}"

  location      = var.region
  storage_class = "STANDARD"
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Política mínima: arquivos independentes, sem versões adicionais.
  versioning {
    enabled = false
  }

  # Desabilita a retenção adicional de objetos excluídos.
  soft_delete_policy {
    retention_duration_seconds = 0
  }

  # Expiração dos backups no prefixo diario/.
  lifecycle_rule {
    condition {
      age            = 5
      matches_prefix = ["diario/"]
    }

    action {
      type = "Delete"
    }
  }

  # Criptografia CMEK já existente no projeto.
  encryption {
    default_kms_key_name = google_kms_crypto_key.cmek.id
  }

  depends_on = [
    google_kms_crypto_key_iam_member.storage_agent
  ]
}

# A VM pode criar objetos, mas não listar, ler ou apagar backups.
resource "google_storage_bucket_iam_member" "db_backup_writer" {
  bucket = google_storage_bucket.backup.name
  role   = "roles/storage.objectCreator"
  member = google_service_account.db.member
}

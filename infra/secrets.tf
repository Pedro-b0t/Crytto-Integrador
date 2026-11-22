# S4: a senha do banco fica no Secret Manager. O valor chega por TF_VAR_db_password (variável
# efêmera) e é gravado por argumento write-only, portanto não aparece no plan nem no state.
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.project_label}-db-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "db_password" {
  secret                 = google_secret_manager_secret.db_password.id
  secret_data_wo         = var.db_password
  secret_data_wo_version = var.db_password_version
}

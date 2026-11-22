# S5: cada VM que acessa serviços do provedor tem identidade própria, com permissão apenas
# sobre o recurso necessário. Nenhuma chave de acesso é gravada nas instâncias.
# O bastion não recebe service account: ele só repassa SSH.

resource "google_service_account" "app" {
  account_id   = "sa-vm-app"
  display_name = "Identidade da vm-app (leitura da senha do banco)"

  depends_on = [google_project_service.apis]
}

resource "google_service_account" "db" {
  account_id   = "sa-vm-db"
  display_name = "Identidade da vm-db (senha do banco e gravação de backup)"

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_iam_member" "app_db_password" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.app.member
}

resource "google_secret_manager_secret_iam_member" "db_db_password" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.db.member
}

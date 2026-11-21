# Credenciais não ficam no código: o provider usa o Application Default Credentials
# (gcloud auth application-default login) ou GOOGLE_APPLICATION_CREDENTIALS.
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone

  # R10: labels aplicadas automaticamente a todo recurso que as suporta.
  default_labels = local.labels
}

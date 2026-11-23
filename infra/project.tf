data "google_project" "this" {}

# APIs usadas pela infraestrutura. Não são desativadas no destroy para não afetar outros recursos do projeto.
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "cloudkms.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "storage.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

locals {
  labels = {
    projeto        = var.project_label
    grupo          = var.group_label
    ambiente       = var.environment
    gerenciado-por = "terraform"
  }

  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))

  # Metadados comuns às VMs: só a chave do grupo é aceita (chaves de projeto bloqueadas),
  # sem OS Login e sem console serial interativo.
  common_metadata = {
    ssh-keys               = "${var.ssh_user}:${local.ssh_public_key}"
    block-project-ssh-keys = "true"
    enable-oslogin         = "FALSE"
    serial-port-enable     = "FALSE"
  }

  common_script = file("${path.module}/templates/common.sh")

  # replace() remove CR caso o checkout no Windows tenha convertido os scripts para CRLF.
  bastion_startup_script = replace(join("\n", [
    local.common_script,
    templatefile("${path.module}/templates/bastion.sh.tftpl", {}),
  ]), "\r", "")

  db_startup_script = replace(join("\n", [
    local.common_script,
    templatefile("${path.module}/templates/db.sh.tftpl", {
      project_id      = var.project_id
      db_secret_id    = google_secret_manager_secret.db_password.secret_id
      db_name         = var.db_name
      db_user         = var.db_user
      backup_bucket   = google_storage_bucket.backup.name
      backup_schedule = var.backup_schedule
      backup_script   = file("${path.module}/templates/backup.sh")
    }),
  ]), "\r", "")

  app_startup_script = replace(join("\n", [
    local.common_script,
    templatefile("${path.module}/templates/app.sh.tftpl", {
      project_id   = var.project_id
      db_secret_id = google_secret_manager_secret.db_password.secret_id
      db_name      = var.db_name
      db_user      = var.db_user
      db_host      = var.db_private_ip
      public_ip    = google_compute_address.app.address
      repo_url     = var.app_repo_url
      repo_ref     = var.app_repo_ref
    }),
  ]), "\r", "")
}

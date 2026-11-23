# R5, R6, R8, R9, S5, S6. Sub-redes e tags de firewall vêm de network.tf e security.tf.

# R6: IPs externos estáticos do recurso de acesso (bastion) e da aplicação.
resource "google_compute_address" "bastion" {
  name         = "ip-bastion"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"

  depends_on = [google_project_service.apis]
}

resource "google_compute_address" "app" {
  name         = "ip-app"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"

  depends_on = [google_project_service.apis]
}

resource "google_compute_instance" "bastion" {
  name                      = "vm-bastion"
  machine_type              = var.bastion_machine_type
  zone                      = var.zone
  tags                      = ["bastion"]
  labels                    = { papel = "bastion" }
  allow_stopping_for_update = true

  boot_disk {
    auto_delete       = true
    kms_key_self_link = google_kms_crypto_key.cmek.id

    initialize_params {
      image  = var.image
      size   = var.bastion_disk_size_gb
      type   = var.disk_type
      labels = local.labels
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.pub_a.id
    network_ip = var.bastion_private_ip

    access_config {
      nat_ip       = google_compute_address.bastion.address
      network_tier = "PREMIUM"
    }
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = merge(local.common_metadata, {
    startup-script = local.bastion_startup_script
  })

  depends_on = [google_kms_crypto_key_iam_member.compute_agent]
}

resource "google_compute_instance" "db" {
  name                      = "vm-db"
  machine_type              = var.db_machine_type
  zone                      = var.zone
  tags                      = ["db"]
  labels                    = { papel = "db" }
  allow_stopping_for_update = true

  boot_disk {
    auto_delete       = true
    kms_key_self_link = google_kms_crypto_key.cmek.id

    initialize_params {
      image  = var.image
      size   = var.db_disk_size_gb
      type   = var.disk_type
      labels = local.labels
    }
  }

  # R5: sem access_config, portanto sem IP público. A saída para a internet é pelo Cloud NAT.
  network_interface {
    subnetwork = google_compute_subnetwork.priv_a.id
    network_ip = var.db_private_ip
  }

  service_account {
    email  = google_service_account.db.email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = merge(local.common_metadata, {
    startup-script = local.db_startup_script
  })

  depends_on = [
    google_kms_crypto_key_iam_member.compute_agent,
    google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_iam_member.db_db_password,
    google_storage_bucket_iam_member.db_backup_writer,
  ]
}

resource "google_compute_instance" "app" {
  name                      = "vm-app"
  machine_type              = var.app_machine_type
  zone                      = var.zone
  tags                      = ["app"]
  labels                    = { papel = "app" }
  allow_stopping_for_update = true

  boot_disk {
    auto_delete       = true
    kms_key_self_link = google_kms_crypto_key.cmek.id

    initialize_params {
      image  = var.image
      size   = var.app_disk_size_gb
      type   = var.disk_type
      labels = local.labels
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.pub_a.id
    network_ip = var.app_private_ip

    access_config {
      nat_ip       = google_compute_address.app.address
      network_tier = "PREMIUM"
    }
  }

  service_account {
    email  = google_service_account.app.email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = merge(local.common_metadata, {
    startup-script = local.app_startup_script
  })

  depends_on = [
    google_kms_crypto_key_iam_member.compute_agent,
    google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_iam_member.app_db_password,
    google_compute_instance.db,
  ]
}

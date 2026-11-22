resource "google_compute_instance" "vm_db" {
  name         = "vm-db"
  machine_type = var.vm_db_machine_type
  zone         = var.zone

  tags = ["db"]

  labels = local.resource_labels

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      size  = var.vm_db_boot_disk_size
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork   = google_compute_subnetwork.priv_a.id
    network_ip   = "10.20.10.10"
  }

  metadata = var.ssh_public_key != "" ? {
    ssh-keys       = "${var.ssh_admin_user}:${var.ssh_public_key}"
    startup-script = file("${path.module}/ssh-hardening.sh")
  } : {
    startup-script = file("${path.module}/ssh-hardening.sh")
  }

  allow_stopping_for_update = true
  can_ip_forward            = false

  service_account {
    scopes = ["cloud-platform"]
  }

  lifecycle {
    ignore_changes = [metadata["ssh-keys"]]
  }
}

output "vm_db_private_ip" {
  value       = google_compute_instance.vm_db.network_interface[0].network_ip
  description = "IP privado da VM do banco, sem IP publico."
}

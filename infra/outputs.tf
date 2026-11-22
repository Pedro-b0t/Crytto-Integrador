# R11
output "bastion_public_ip" {
  description = "IP público estático do bastion (recurso de acesso administrativo)."
  value       = google_compute_address.bastion.address
}

output "app_public_ip" {
  description = "IP público estático da vm-app."
  value       = google_compute_address.app.address
}

output "nat_public_ip" {
  description = "IP público do Cloud NAT. Deve ser igual ao retorno de 'curl -s https://ifconfig.me' na vm-db."
  value       = google_compute_address.nat.address
}

output "private_ips" {
  description = "IPs privados das instâncias."
  value = {
    vm-bastion = google_compute_instance.bastion.network_interface[0].network_ip
    vm-app     = google_compute_instance.app.network_interface[0].network_ip
    vm-db      = google_compute_instance.db.network_interface[0].network_ip
  }
}

output "app_url" {
  description = "URL HTTPS da aplicação (certificado autoassinado)."
  value       = "https://${google_compute_address.app.address}"
}

output "ssh_bastion" {
  description = "Comando para acessar o bastion."
  value       = "ssh ${var.ssh_user}@${google_compute_address.bastion.address}"
}

output "ssh_app" {
  description = "Comando para acessar a vm-app pelo bastion."
  value       = "ssh -J ${var.ssh_user}@${google_compute_address.bastion.address} ${var.ssh_user}@${var.app_private_ip}"
}

output "ssh_db" {
  description = "Comando para acessar a vm-db pelo bastion."
  value       = "ssh -J ${var.ssh_user}@${google_compute_address.bastion.address} ${var.ssh_user}@${var.db_private_ip}"
}

output "db_password_secret" {
  description = "Nome do segredo da senha do banco no Secret Manager (o valor não é exibido)."
  value       = google_secret_manager_secret.db_password.secret_id
}

output "db_service_account_email" {
  description = "Service account da vm-db (usada para conceder a gravação no bucket de backup)."
  value       = google_service_account.db.email
}

output "kms_key_id" {
  description = "Chave CMEK usada nos discos (reutilizável no bucket de backup)."
  value       = google_kms_crypto_key.cmek.id
}

resource "google_compute_firewall" "allow_ssh_from_admin" {
  name        = "sg-bastion-ssh"
  network     = google_compute_network.vpc.name
  description = "Permite SSH apenas do CIDR do administrador autorizado."

  direction = "INGRESS"
  priority  = 1000

  source_ranges = [var.ssh_allowed_cidr]
  target_tags   = ["bastion"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow_http_https_public" {
  name        = "sg-app-http-https"
  network     = google_compute_network.vpc.name
  description = "Permite tráfego público em HTTP e HTTPS para a VM de aplicação."

  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["app"]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

resource "google_compute_firewall" "allow_ssh_bastion_to_app" {
  name        = "sg-app-ssh-bastion"
  network     = google_compute_network.vpc.name
  description = "Permite SSH da VM bastion para a VM de aplicação."

  direction = "INGRESS"
  priority  = 1000

  source_tags = ["bastion"]
  target_tags = ["app"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow_postgres_from_app" {
  name        = "sg-db-postgres"
  network     = google_compute_network.vpc.name
  description = "Permite apenas a aplicação acessar o PostgreSQL na sub-rede privada."

  direction = "INGRESS"
  priority  = 1000

  source_tags = ["app"]
  target_tags = ["db"]

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }
}

resource "google_compute_firewall" "allow_ssh_bastion_to_db" {
  name        = "sg-db-ssh-bastion"
  network     = google_compute_network.vpc.name
  description = "Permite administração do banco via bastion."

  direction = "INGRESS"
  priority  = 1000

  source_tags = ["bastion"]
  target_tags = ["db"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "egress_app_allowed" {
  name        = "sg-app-egress-allowed"
  network     = google_compute_network.vpc.name
  description = "Permite saida HTTP/HTTPS/DNS da aplicacao e PostgreSQL para o banco."

  direction          = "EGRESS"
  priority           = 1000
  target_tags        = ["app"]
  destination_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "53"]
  }

  allow {
    protocol = "udp"
    ports    = ["53"]
  }
}

resource "google_compute_firewall" "egress_dns" {
  name        = "sg-db-egress-dns"
  network     = google_compute_network.vpc.name
  description = "Restringe a saída da VM privada apenas para DNS."

  direction = "EGRESS"
  priority  = 1000

  target_tags        = ["db"]
  destination_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  allow {
    protocol = "tcp"
    ports    = ["53"]
  }
}

resource "google_compute_firewall" "egress_http_https" {
  name        = "sg-db-egress-http-https"
  network     = google_compute_network.vpc.name
  description = "Permite apenas acesso externo HTTP/HTTPS para atualizações e pacotes na VM privada."

  direction = "EGRESS"
  priority  = 1000

  target_tags        = ["db"]
  destination_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

resource "google_compute_firewall" "egress_postgres_app_to_db" {
  name        = "sg-app-egress-postgres"
  network     = google_compute_network.vpc.name
  description = "Permite apenas a aplicação acessar o PostgreSQL na sub-rede privada."

  direction = "EGRESS"
  priority  = 1000

  target_tags        = ["app"]
  destination_ranges = [var.private_subnet_cidr]

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }
}

resource "google_compute_firewall" "deny_db_egress_except_allowed" {
  name        = "sg-db-egress-deny-all"
  network     = google_compute_network.vpc.name
  description = "Bloqueia toda saida da VM privada nao explicitamente permitida."

  direction          = "EGRESS"
  priority           = 65534
  target_tags        = ["db"]
  destination_ranges = ["0.0.0.0/0"]

  deny {
    protocol = "all"
  }
}

resource "google_compute_firewall" "deny_app_egress_except_allowed" {
  name        = "sg-app-egress-deny-all"
  network     = google_compute_network.vpc.name
  description = "Bloqueia saida da aplicacao que nao esteja explicitamente permitida."

  direction          = "EGRESS"
  priority           = 65534
  target_tags        = ["app"]
  destination_ranges = ["0.0.0.0/0"]

  deny {
    protocol = "all"
  }
}

# S2: o bastion só abre SSH para dentro da VPC (salto para vm-app e vm-db) e sai para a
# internet apenas por DNS e HTTP/HTTPS (atualizações de pacotes). Todo o resto é bloqueado.
resource "google_compute_firewall" "egress_bastion_ssh_vpc" {
  name        = "sg-bastion-egress-ssh"
  network     = google_compute_network.vpc.name
  description = "Permite SSH do bastion apenas para as VMs da VPC."

  direction = "EGRESS"
  priority  = 1000

  target_tags        = ["bastion"]
  destination_ranges = [var.vpc_cidr]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "egress_bastion_updates" {
  name        = "sg-bastion-egress-updates"
  network     = google_compute_network.vpc.name
  description = "Permite DNS e HTTP/HTTPS do bastion para atualizacao de pacotes."

  direction = "EGRESS"
  priority  = 1000

  target_tags        = ["bastion"]
  destination_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["53", "80", "443"]
  }

  allow {
    protocol = "udp"
    ports    = ["53"]
  }
}

resource "google_compute_firewall" "deny_bastion_egress_except_allowed" {
  name        = "sg-bastion-egress-deny-all"
  network     = google_compute_network.vpc.name
  description = "Bloqueia saida do bastion que nao esteja explicitamente permitida."

  direction = "EGRESS"
  priority  = 65534

  target_tags        = ["bastion"]
  destination_ranges = ["0.0.0.0/0"]

  deny {
    protocol = "all"
  }
}
resource "google_compute_network" "vpc" {
  name                    = "vpc-grupo-x"
  auto_create_subnetworks = false
  mtu                     = 1460
  routing_mode            = "REGIONAL"
  description             = "VPC do projeto Crytto com segmentação pública e privada."
}

resource "google_compute_subnetwork" "pub_a" {
  name                     = "pub-a"
  ip_cidr_range            = var.pub_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  description              = "Sub-rede pública para bastion e VM de aplicação."
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "priv_a" {
  name                     = "priv-a"
  ip_cidr_range            = var.priv_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  description              = "Sub-rede privada para a VM de banco e serviços internos."
  private_ip_google_access = true
}

resource "google_compute_route" "internet_egress" {
  name             = "route-internet-default"
  network          = google_compute_network.vpc.name
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
  description      = "Rota padrão para saída para a internet."
}

resource "google_compute_address" "nat_ip" {
  name         = "nat-ip-grupo-x"
  region       = var.region
  address_type = "EXTERNAL"
  description  = "IP externo reservado para o Cloud NAT."
  labels       = local.resource_labels
}

resource "google_compute_router" "nat_router" {
  name        = "nat-router-grupo-x"
  region      = var.region
  network     = google_compute_network.vpc.id
  description = "Router usado para o Cloud NAT da sub-rede privada."

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "nat" {
  name                               = "nat-grupo-x"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  nat_ips                            = [google_compute_address.nat_ip.self_link]

  subnetwork {
    name                    = google_compute_subnetwork.priv_a.self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

output "vpc_name" {
  value       = google_compute_network.vpc.name
  description = "Nome da VPC criada para o projeto."
}

output "public_subnet_name" {
  value       = google_compute_subnetwork.pub_a.name
  description = "Nome da sub-rede pública."
}

output "private_subnet_name" {
  value       = google_compute_subnetwork.priv_a.name
  description = "Nome da sub-rede privada."
}

output "nat_ip" {
  value       = google_compute_address.nat_ip.address
  description = "IP externo reservado pelo Cloud NAT."
}

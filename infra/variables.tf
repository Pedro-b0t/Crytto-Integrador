# ---------------------------------------------------------------------------
# Projeto e identificação
# ---------------------------------------------------------------------------

variable "project_id" {
  type        = string
  description = "ID do projeto GCP onde a infraestrutura será criada."
}

variable "region" {
  type        = string
  description = "Região GCP dos recursos regionais (sub-redes, NAT, IPs, chave KMS)."
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "Zona GCP das VMs. A arquitetura implantada usa uma única zona (ver docs/arquitetura.md, 5.10)."
  default     = "us-central1-a"
}

variable "project_label" {
  type        = string
  description = "Valor da label 'projeto' aplicada a todos os recursos (R10). Também usado como prefixo de nomes."
  default     = "crytto"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project_label))
    error_message = "Use apenas letras minúsculas, números e hífen (2 a 21 caracteres), começando por letra."
  }
}

variable "group_label" {
  type        = string
  description = "Valor da label 'grupo' aplicada a todos os recursos (R10)."
  default     = "grupo-x"

  validation {
    condition     = can(regex("^[a-z0-9_-]{1,63}$", var.group_label))
    error_message = "Labels GCP aceitam apenas letras minúsculas, números, '_' e '-'."
  }
}

variable "environment" {
  type        = string
  description = "Valor da label 'ambiente' (por exemplo, entrega2)."
  default     = "entrega2"
}

# ---------------------------------------------------------------------------
# Rede (usadas em network.tf e security.tf)
# ---------------------------------------------------------------------------

variable "network_name" {
  type        = string
  description = "Nome da VPC."
  default     = "vpc-grupo-x"
}

variable "vpc_cidr" {
  type        = string
  description = "Bloco de endereçamento reservado para a VPC (Entrega 1, 5.3). Na GCP a VPC não tem CIDR próprio; o bloco agrupa as sub-redes e é usado nas regras internas."
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Informe um CIDR IPv4 válido."
  }
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR da sub-rede pública pub-a (bastion e aplicação)."
  default     = "10.20.1.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "Informe um CIDR IPv4 válido."
  }
}

variable "private_subnet_cidr" {
  type        = string
  description = "CIDR da sub-rede privada priv-a (banco de dados)."
  default     = "10.20.10.0/24"

  validation {
    condition     = can(cidrhost(var.private_subnet_cidr, 0))
    error_message = "Informe um CIDR IPv4 válido."
  }
}

variable "ssh_allowed_cidr" {
  type        = string
  description = "Único CIDR autorizado a acessar o SSH do bastion, normalmente o IP público do administrador em /32 (R7)."

  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0)) && !endswith(var.ssh_allowed_cidr, "/0")
    error_message = "Informe um CIDR IPv4 válido e específico (ex.: 203.0.113.10/32). SSH aberto para 0.0.0.0/0 não é aceito."
  }
}

variable "bastion_private_ip" {
  type        = string
  description = "IP interno fixo da vm-bastion, dentro de public_subnet_cidr."
  default     = "10.20.1.10"
}

variable "app_private_ip" {
  type        = string
  description = "IP interno fixo da vm-app, dentro de public_subnet_cidr."
  default     = "10.20.1.20"
}

variable "db_private_ip" {
  type        = string
  description = "IP interno fixo da vm-db, dentro de private_subnet_cidr."
  default     = "10.20.10.10"
}

# ---------------------------------------------------------------------------
# Instâncias (R9)
# ---------------------------------------------------------------------------

variable "bastion_machine_type" {
  type        = string
  description = "Tipo de máquina da vm-bastion (família E2, Entrega 1, 5.7)."
  default     = "e2-micro"
}

variable "app_machine_type" {
  type        = string
  description = "Tipo de máquina da vm-app."
  default     = "e2-small"
}

variable "db_machine_type" {
  type        = string
  description = "Tipo de máquina da vm-db."
  default     = "e2-small"
}

variable "bastion_disk_size_gb" {
  type        = number
  description = "Tamanho do disco de boot da vm-bastion, em GB."
  default     = 10
}

variable "app_disk_size_gb" {
  type        = number
  description = "Tamanho do disco de boot da vm-app, em GB."
  default     = 20
}

variable "db_disk_size_gb" {
  type        = number
  description = "Tamanho do disco de boot da vm-db, em GB (os dados do PostgreSQL ficam nele)."
  default     = 20
}

variable "disk_type" {
  type        = string
  description = "Tipo de disco persistente das VMs."
  default     = "pd-balanced"
}

variable "image" {
  type        = string
  description = "Imagem (ou família) do sistema operacional das VMs."
  default     = "ubuntu-os-cloud/ubuntu-2204-lts"
}

# ---------------------------------------------------------------------------
# Acesso SSH (R8)
# ---------------------------------------------------------------------------

variable "ssh_user" {
  type        = string
  description = "Usuário Linux criado nas VMs para a chave SSH do grupo."
  default     = "crytto"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Caminho da chave pública SSH do grupo. A chave privada nunca entra no repositório."
  default     = "~/.ssh/chave-grupo.pub"
}

# ---------------------------------------------------------------------------
# Aplicação e segredos (R12, S4)
# ---------------------------------------------------------------------------

variable "app_repo_url" {
  type        = string
  description = "URL HTTPS do repositório Git clonado pela vm-app."
  default     = "https://github.com/Pedro-b0t/Crytto-Integrador.git"
}

variable "app_repo_ref" {
  type        = string
  description = "Branch ou tag do repositório implantada na vm-app (na apresentação: entrega-2)."
  default     = "main"
}

variable "db_name" {
  type        = string
  description = "Nome do banco PostgreSQL da aplicação."
  default     = "crytto"
}

variable "db_user" {
  type        = string
  description = "Usuário do PostgreSQL da aplicação."
  default     = "crytto"
}

variable "db_password" {
  type        = string
  description = "Senha do PostgreSQL. Fornecer apenas por variável de ambiente (TF_VAR_db_password). É gravada no Secret Manager por argumento write-only e não fica no state."
  sensitive   = true
  ephemeral   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{16,}$", var.db_password))
    error_message = "A senha deve ter ao menos 16 caracteres, usando letras, números, '_' ou '-' (ex.: openssl rand -hex 24)."
  }
}

variable "db_password_version" {
  type        = number
  description = "Incrementar para gravar uma nova versão da senha no Secret Manager (rotação)."
  default     = 1
}

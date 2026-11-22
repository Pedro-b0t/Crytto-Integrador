variable "project_id" {
  description = "ID do projeto na Google Cloud Platform."
  type        = string
  default     = "grupo-x-projeto"
}

variable "region" {
  description = "Região do provedor onde a infraestrutura será implantada."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zona da região usada pelos recursos de computação."
  type        = string
  default     = "us-central1-a"
}

variable "project_name" {
  description = "Nome do projeto usado nos labels dos recursos."
  type        = string
  default     = "crytto"
}

variable "group_name" {
  description = "Identificador do grupo para os labels dos recursos."
  type        = string
  default     = "grupo-x"
}

variable "vpc_cidr" {
  description = "CIDR da VPC principal do projeto."
  type        = string
  default     = "10.20.0.0/16"
}

variable "pub_subnet_cidr" {
  description = "CIDR da sub-rede pública para bastion e aplicação."
  type        = string
  default     = "10.20.1.0/24"
}

variable "priv_subnet_cidr" {
  description = "CIDR da sub-rede privada para o banco e demais serviços internos."
  type        = string
  default     = "10.20.10.0/24"
}

variable "admin_source_cidr" {
  description = "CIDR autorizado para acesso administrativo via SSH no bastion. Deve ser estritamente restrito e nunca 0.0.0.0/0."
  type        = string
  default     = "203.0.113.10/32"
}

locals {
  resource_labels = {
    projeto = var.project_name
    grupo   = var.group_name
  }
}

variable "vm_db_machine_type" {
  description = "Tipo da VM de banco de dados."
  type        = string
  default     = "e2-small"
}

variable "vm_db_boot_disk_size" {
  description = "Tamanho do disco de boot da VM de banco, em GB."
  type        = number
  default     = 20
}

variable "ssh_admin_user" {
  description = "Usuario local usado para autenticacao SSH por chave publica."
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "Chave publica SSH autorizada. Nao informe nem commite a chave privada."
  type        = string
  default     = ""
  sensitive   = true
}

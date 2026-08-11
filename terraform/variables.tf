# ============================================================
# ObservaTI - Terraform Variables
# ============================================================

# --- General ---
variable "project_name" {
  description = "Nombre del proyecto (usado para naming de recursos)"
  type        = string
  default     = "observati"
}

variable "environment" {
  description = "Ambiente (production, staging, development)"
  type        = string
  default     = "production"
}

variable "aws_region" {
  description = "Región AWS principal"
  type        = string
  default     = "us-east-1"
}

# --- Networking ---
variable "vpc_id" {
  description = "ID de la VPC donde se desplegará el servidor"
  type        = string
}

variable "subnet_id" {
  description = "ID de la subnet donde se desplegará la instancia EC2"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDRs permitidos para acceso a Grafana y Uptime Kuma (ej: IP de oficina, VPN)"
  type        = list(string)
  default     = []
}

variable "allowed_ssh_cidr_blocks" {
  description = "CIDRs permitidos para SSH (dejar vacío si no se necesita SSH directo)"
  type        = list(string)
  default     = []
}

# --- EC2 ---
variable "instance_type" {
  description = "Tipo de instancia EC2 (t3.small para lab, t3.medium para producción)"
  type        = string
  default     = "t3.small"
}

variable "volume_size" {
  description = "Tamaño del volumen EBS raíz en GB"
  type        = number
  default     = 30
}

variable "volume_type" {
  description = "Tipo de volumen EBS"
  type        = string
  default     = "gp3"
}

variable "key_pair_name" {
  description = "Nombre del key pair para SSH (dejar vacío para no asignar key)"
  type        = string
  default     = ""
}

# --- Acceso ---
variable "associate_public_ip" {
  description = "Asignar IP pública a la instancia (true si no hay NAT/VPN configurado)"
  type        = bool
  default     = false
}

# --- Monitoreo CloudWatch cross-account (opcional) ---
variable "monitored_account_ids" {
  description = "IDs de cuentas AWS adicionales a monitorear (cross-account). Dejar vacío si es una sola cuenta."
  type        = list(string)
  default     = []
}

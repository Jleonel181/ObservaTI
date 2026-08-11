# ============================================================
# ObservaTI - Security Group
# ============================================================
# Reglas de acceso para el servidor de observabilidad.
# Solo se permite acceso desde CIDRs explícitamente autorizados.
# ============================================================

resource "aws_security_group" "observati" {
  name        = "${var.project_name}-server-sg"
  description = "Security Group para servidor ObservaTI (Grafana + Uptime Kuma)"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-server-sg"
  }
}

# --- Reglas Ingress ---

# Grafana (:3000) - Solo desde CIDRs autorizados
resource "aws_security_group_rule" "grafana_ingress" {
  count = length(var.allowed_cidr_blocks) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.observati.id
  description       = "Grafana UI"
}

# Uptime Kuma (:3001) - Solo desde CIDRs autorizados
resource "aws_security_group_rule" "uptime_kuma_ingress" {
  count = length(var.allowed_cidr_blocks) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 3001
  to_port           = 3001
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.observati.id
  description       = "Uptime Kuma UI"
}

# SSH (:22) - Solo si se especifican CIDRs para SSH
resource "aws_security_group_rule" "ssh_ingress" {
  count = length(var.allowed_ssh_cidr_blocks) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ssh_cidr_blocks
  security_group_id = aws_security_group.observati.id
  description       = "SSH access"
}

# --- Reglas Egress ---

# HTTPS saliente (CloudWatch API, Discord Webhooks, Docker Hub, apt)
resource "aws_security_group_rule" "https_egress" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.observati.id
  description       = "HTTPS outbound (CloudWatch API, Discord, Docker Hub)"
}

# HTTP saliente (apt updates, Uptime Kuma checks a apps sin HTTPS)
resource "aws_security_group_rule" "http_egress" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.observati.id
  description       = "HTTP outbound (apt, Uptime Kuma checks)"
}

# SMTP saliente - Zoho Mail (puerto 587 STARTTLS)
resource "aws_security_group_rule" "smtp_egress" {
  type              = "egress"
  from_port         = 587
  to_port           = 587
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.observati.id
  description       = "SMTP outbound (Zoho Mail STARTTLS)"
}

# DNS saliente
resource "aws_security_group_rule" "dns_egress_tcp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.observati.id
  description       = "DNS TCP outbound"
}

resource "aws_security_group_rule" "dns_egress_udp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.observati.id
  description       = "DNS UDP outbound"
}

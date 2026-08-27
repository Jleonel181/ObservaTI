# ============================================================
# ObservaTI - EC2 Instance
# ============================================================
# Servidor de observabilidad con Docker preinstalado.
# user_data instala Docker, Docker Compose, y clona el repo.
# ============================================================

# --- AMI: Ubuntu 24.04 LTS (última versión disponible) ---
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# --- EC2 Instance ---
resource "aws_instance" "observati" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.observati.id]
  iam_instance_profile   = aws_iam_instance_profile.observati.name
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null

  associate_public_ip_address = var.associate_public_ip

  root_block_device {
    volume_size           = var.volume_size
    volume_type           = var.volume_type
    encrypted             = true
    delete_on_termination = false

    tags = {
      Name = "${var.project_name}-root-volume"
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    project_name = var.project_name
    aws_region   = var.aws_region
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 obligatorio (seguridad)
    http_put_response_hop_limit = 2
  }

  tags = {
    Name   = "${var.project_name}-server"
    Team   = var.team
    Service = "observability"
    CentroCosto = "CC-420099"
    Prioridad = "Baja"
    Area = "TI"
    Ambiente = "Produccion"
    Propietario = "Leonel Lopez"
    Cliente = "Interno"
  }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

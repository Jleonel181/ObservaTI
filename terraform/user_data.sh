#!/bin/bash
# ============================================================
# ObservaTI - EC2 Bootstrap Script
# ============================================================
# Instala Docker, Docker Compose, y prepara el servidor.
# Se ejecuta UNA VEZ al crear la instancia.
# ============================================================

set -euo pipefail

# --- Logging ---
exec > >(tee /var/log/observati-bootstrap.log) 2>&1
echo "[$(date)] Iniciando bootstrap ObservaTI..."

# --- Variables ---
PROJECT_NAME="${project_name}"
AWS_REGION="${aws_region}"
INSTALL_DIR="/opt/$PROJECT_NAME"

# --- Actualizar sistema ---
echo "[$(date)] Actualizando paquetes..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# --- Instalar dependencias ---
echo "[$(date)] Instalando dependencias..."
apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  git \
  jq \
  unzip \
  htop \
  ncdu \
  tree

# --- Instalar Docker ---
echo "[$(date)] Instalando Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# --- Habilitar Docker ---
systemctl enable docker
systemctl start docker

# --- Crear usuario para el proyecto ---
echo "[$(date)] Configurando usuario..."
useradd -m -s /bin/bash -G docker observati || true

# --- Crear directorio del proyecto ---
echo "[$(date)] Preparando directorio del proyecto..."
mkdir -p "$INSTALL_DIR"
chown observati:observati "$INSTALL_DIR"

# --- Crear archivo de referencia para el equipo ---
cat > "$INSTALL_DIR/README.txt" << 'EOF'
# ObservaTI - Servidor de Observabilidad
#
# Este servidor fue provisionado por Terraform.
#
# Para desplegar la plataforma:
#   1. Clonar el repositorio en /opt/observati/
#   2. Copiar .env.example a .env y configurar
#   3. Ejecutar: make up
#
# Logs del bootstrap: /var/log/observati-bootstrap.log
# Usuario del servicio: observati
# Docker: instalado y habilitado
EOF

# --- Configurar timezone ---
timedatectl set-timezone America/Guatemala

# --- Configurar log rotation para Docker ---
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF
systemctl restart docker

# --- Instalar AWS CLI v2 (útil para debugging) ---
echo "[$(date)] Instalando AWS CLI..."
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

# --- Verificar instalación ---
echo "[$(date)] Verificando instalación..."
docker --version
docker compose version
aws --version

echo "[$(date)] Bootstrap completado exitosamente."
echo "[$(date)] Próximo paso: clonar el repositorio en $INSTALL_DIR y ejecutar 'make up'"

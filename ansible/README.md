# ObservaTI - Ansible Deployment

Automatiza el despliegue de la plataforma ObservaTI en el servidor EC2.

## ¿Qué hace?

1. Espera que el servidor termine el bootstrap (cloud-init).
2. Verifica que Docker y Docker Compose estén instalados.
3. Clona/actualiza el repositorio desde GitHub.
4. Genera el archivo `.env` con los secretos.
5. Descarga las imágenes Docker.
6. Levanta Grafana + Uptime Kuma.
7. Verifica que ambos servicios estén healthy.

## Requisitos

| Requisito | Instalación |
|-----------|-------------|
| Ansible | `brew install ansible` |
| SSH access | Key pair `.pem` configurado |
| EC2 creada | Via `terraform apply` |

## Uso

### 1. Crear inventario

```bash
cd ansible/
cp inventory.ini.example inventory.ini
```

Editar `inventory.ini` con la IP pública de la EC2 (la que devolvió Terraform):

```ini
[observati]
observati-server ansible_host=54.x.x.x ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/observati-key.pem
```

### 2. Ejecutar playbook

```bash
ansible-playbook playbook.yml
```

Te preguntará:
- Grafana admin password
- Discord Webhook URL (Enter para omitir)
- SMTP user (Enter para omitir)
- SMTP password (Enter para omitir)

### 3. Alternativa: pasar secretos sin prompt

```bash
ansible-playbook playbook.yml \
  -e "grafana_admin_password=MiPassword123" \
  -e "discord_webhook_url=https://discord.com/api/webhooks/..." \
  -e "smtp_user=alertas@tudominio.com" \
  -e "smtp_password=app_password_zoho"
```

### 4. Solo redesplegar (sin prompts de configuración inicial)

```bash
ansible-playbook playbook.yml --tags deploy \
  -e "grafana_admin_password=MiPassword123"
```

## Tags disponibles

| Tag | Qué ejecuta |
|-----|-------------|
| `setup` | Verificaciones iniciales (Docker, directorios) |
| `deploy` | Clone repo, generar .env, pull images, start services |
| `config` | Solo regenerar .env |
| `verify` | Solo verificar que servicios estén UP |

## Variables

Definidas en `group_vars/observati.yml`:

| Variable | Default | Descripción |
|----------|---------|-------------|
| `project_repo` | GitHub URL | Repositorio a clonar |
| `project_branch` | `main` | Branch a desplegar |
| `project_dir` | `/opt/observati` | Directorio en el servidor |
| `grafana_admin_user` | `admin` | Usuario admin de Grafana |
| `aws_default_region` | `us-east-1` | Región AWS para CloudWatch |
| `smtp_host` | `smtp.zoho.com:587` | Servidor SMTP |
| `timezone` | `America/Guatemala` | Zona horaria |

## Secretos (no se guardan en el repo)

Se pasan vía:
- `--extra-vars` en la línea de comando
- Prompts interactivos del playbook
- Ansible Vault (para automatización)

## Flujo completo

```
terraform apply  →  crea EC2 + IAM + SG
                          │
                          ▼ (output: IP pública)
ansible-playbook  →  clona repo, genera .env, docker compose up
                          │
                          ▼
              Grafana :3000 + Uptime Kuma :3001 UP
```

## Redespliegue tras cambios

Si cambias dashboards, alertas, o configuración:

```bash
ansible-playbook playbook.yml --tags deploy \
  -e "grafana_admin_password=MiPassword123"
```

Esto hace git pull + docker compose up --force-recreate.

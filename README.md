# ObservaTI

Plataforma centralizada de observabilidad para múltiples aplicaciones y servicios en AWS.

## Arquitectura (Fase 1 - MVP)

```
┌─────────────────────────────┐
│     AWS CloudWatch          │
│  (EC2, Lambda, RDS, APIGW)  │
└─────────────┬───────────────┘
              │ IAM Role / Access Keys
              ▼
┌─────────────────────────────┐      ┌─────────────────────┐
│       Grafana OSS           │      │    Uptime Kuma      │
│  • Dashboards               │      │  • HTTP/HTTPS       │
│  • CloudWatch DataSource    │      │  • TCP/DNS/Ping     │
│  • Alerting → Discord/Mail  │      │  • SSL Expiry       │
└─────────────────────────────┘      └─────────────────────┘
              │                                │
              ▼                                ▼
┌─────────────────────────────────────────────────────────┐
│              Discord + Zoho Mail (alertas)               │
└─────────────────────────────────────────────────────────┘
```

## Aplicaciones monitoreadas

| Aplicación | Ambientes |
|------------|-----------|
| RedApp | Producción, Test |
| WebApp | Producción, Test |
| Sitio Corporativo | Producción, Test |
| Intranet | Producción |

## Inicio rápido

```bash
# 1. Configurar variables de entorno
cp .env.example .env
# Editar .env con valores reales

# 2. Iniciar servicios
make up

# 3. Verificar
make health

# 4. Configurar monitores de Uptime Kuma (requiere yq: brew install yq)
#    Editar uptime-kuma/monitors.yml con las URLs reales
make setup-monitors
```

## Acceso

| Servicio | Puerto | URL |
|----------|--------|-----|
| Grafana | 3000 | http://localhost:3000 |
| Uptime Kuma | 3001 | http://localhost:3001 |

## Requisitos

- Docker 24.0+
- Docker Compose v2
- yq (`brew install yq`) — para gestionar monitores como código
- Credenciales AWS con permisos CloudWatch (lectura)
- Webhook de Discord (opcional para alertas)
- Cuenta Zoho Mail con App Password (opcional para alertas por correo)

## Estructura del proyecto

```
observati/
├── docker-compose.yml
├── .env.example
├── Makefile
├── grafana/
│   ├── grafana.ini
│   └── provisioning/
│       ├── dashboards/
│       │   ├── overview/         → Application Health
│       │   ├── aws/              → EC2, RDS, Lambda, API Gateway
│       │   └── applications/     → Dashboards por aplicación
│       ├── datasources/          → CloudWatch
│       └── alerting/             → Contact points, policies, rules
├── uptime-kuma/
│   └── monitors.yml              → Monitores como código
├── scripts/
│   └── setup-monitors.sh         → Provisiona monitores vía Socket.IO
├── ansible/                      → Despliegue automatizado (IaC)
│   ├── playbook.yml              → Playbook principal
│   ├── inventory.ini.example     → Template de inventario
│   ├── ansible.cfg               → Configuración Ansible
│   ├── group_vars/               → Variables por grupo
│   └── roles/observati/          → Role de despliegue
├── terraform/                    → Infraestructura AWS (IaC)
│   ├── ec2.tf, iam.tf, etc.     → Recursos AWS
│   └── terraform.tfvars.example  → Template de variables
└── docs/
    ├── architecture.md           → Diseño detallado y decisiones
    └── installation.md           → Guía paso a paso
```

## Comandos útiles

```bash
make help              # Ver todos los comandos disponibles
make up                # Iniciar servicios
make down              # Detener servicios
make status            # Ver estado de contenedores
make health            # Verificar salud de servicios
make logs              # Ver logs recientes
make setup-monitors    # Crear monitores en Uptime Kuma desde monitors.yml
make reset-monitors    # Eliminar monitores existentes y recrear desde código
make backup            # Crear backup de configuración
make rebuild           # Recrear servicios (tras cambios de config)
make validate          # Validar docker-compose.yml
make env-check         # Verificar variables de entorno
```

## Gestión de monitores como código

Los monitores de Uptime Kuma se definen en `uptime-kuma/monitors.yml`:

```yaml
defaults:
  interval: 60
  headers:
    User-Agent: "Mozilla/5.0 (Macintosh; ...) Chrome/120.0.0.0 Safari/537.36"

monitors:
  - name: "Mi App - Producción"
    type: http
    url: "https://miapp.com"
    interval: 60
```

Para agregar una nueva aplicación, agrega una entrada al YAML y ejecuta:

```bash
make setup-monitors    # Crea solo los nuevos (no duplica existentes)
make reset-monitors    # Borra todos y recrea desde cero
```

> **Nota:** Sitios con WAF/CDN (Cloudflare, AWS WAF) pueden bloquear requests sin User-Agent de navegador. El header por defecto en `defaults.headers` soluciona esto.

## Roadmap

| Fase | Componentes | Estado |
|------|------------|--------|
| 1 - MVP | Grafana, CloudWatch, Uptime Kuma, Discord, Email | ✅ Actual |
| 2 - Métricas | Prometheus, OTel Collector, Alertmanager | Pendiente |
| 3 - Logs | Loki, OTel logs pipeline | Pendiente |
| 4 - Trazas | Tempo, OTel tracing | Pendiente |
| 5 - Avanzada | SLIs/SLOs, correlación, dashboards ejecutivos | Pendiente |

## Despliegue a AWS

El flujo completo de despliegue es:

```bash
# 1. Crear infraestructura (EC2, IAM, Security Group)
cd terraform
terraform apply

# 2. Desplegar la plataforma (clone repo, docker compose up)
cd ../ansible
cp inventory.ini.example inventory.ini
# Editar inventory.ini con la IP del output de Terraform
ansible-playbook playbook.yml
```

## Documentación

- [Arquitectura detallada](docs/architecture.md)
- [Guía de instalación](docs/installation.md)
- [Despliegue con Ansible](ansible/README.md)
- [Infraestructura con Terraform](terraform/README.md)

## CI/CD Pipeline

El repositorio incluye un pipeline de GitHub Actions (`.github/workflows/validate.yml`) que se ejecuta automáticamente en cada push y PR.

### En push a develop/main:

| Validación | Qué verifica |
|------------|-------------|
| Docker Compose | Sintaxis correcta, archivos referenciados existen |
| Grafana Provisioning | YAMLs de alerting y JSONs de dashboards válidos |
| Monitors Config | Cada monitor tiene name, url y type |
| Terraform | Formato HCL, init, validate |
| Integration Test | Levanta el stack, verifica Grafana + Uptime Kuma + dashboards + alertas |

### En PR a main (requiere GitHub Secrets de AWS):

| Validación | Qué verifica |
|------------|-------------|
| Terraform Plan | Muestra qué recursos se crearían en AWS (sin crear nada) |

### Configurar GitHub Secrets (opcional, para terraform plan):

Settings → Secrets and variables → Actions:

| Secret | Valor |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | Access Key con permisos de lectura |
| `AWS_SECRET_ACCESS_KEY` | Secret Key correspondiente |

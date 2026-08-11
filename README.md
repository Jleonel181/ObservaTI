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
```

## Acceso

| Servicio | Puerto | URL |
|----------|--------|-----|
| Grafana | 3000 | http://localhost:3000 |
| Uptime Kuma | 3001 | http://localhost:3001 |

## Requisitos

- Docker 24.0+
- Docker Compose v2
- Credenciales AWS con permisos CloudWatch (lectura)
- Webhook de Discord
- Cuenta Zoho Mail con App Password

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
├── scripts/
└── docs/
    ├── architecture.md           → Diseño detallado y decisiones
    └── installation.md           → Guía paso a paso
```

## Comandos útiles

```bash
make help          # Ver todos los comandos disponibles
make up            # Iniciar servicios
make down          # Detener servicios
make status        # Ver estado de contenedores
make health        # Verificar salud de servicios
make logs          # Ver logs recientes
make backup        # Crear backup de configuración
make rebuild       # Recrear servicios (tras cambios de config)
make validate      # Validar docker-compose.yml
make env-check     # Verificar variables de entorno
```

## Roadmap

| Fase | Componentes | Estado |
|------|------------|--------|
| 1 - MVP | Grafana, CloudWatch, Uptime Kuma, Discord, Email | ✅ Actual |
| 2 - Métricas | Prometheus, OTel Collector, Alertmanager | Pendiente |
| 3 - Logs | Loki, OTel logs pipeline | Pendiente |
| 4 - Trazas | Tempo, OTel tracing | Pendiente |
| 5 - Avanzada | SLIs/SLOs, correlación, dashboards ejecutivos | Pendiente |

## Documentación

- [Arquitectura detallada](docs/architecture.md)
- [Guía de instalación](docs/installation.md)

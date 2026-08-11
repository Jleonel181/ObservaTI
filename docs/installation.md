# Guía de Instalación - ObservaTI (Fase 1)

## Requisitos previos

| Requisito | Versión mínima | Verificar con |
|-----------|---------------|---------------|
| Docker | 24.0+ | `docker --version` |
| Docker Compose | 2.20+ (plugin) | `docker compose version` |
| Acceso a AWS | IAM con permisos CloudWatch | Ver sección IAM |
| Conectividad | Puerto 443 saliente (CloudWatch API, Discord) | - |

## 1. Clonar el repositorio

```bash
git clone <URL_DEL_REPOSITORIO> observati
cd observati
```

## 2. Configurar variables de entorno

```bash
cp .env.example .env
```

Editar `.env` con los valores reales:

### Grafana (obligatorio)

```env
GF_ADMIN_USER=admin
GF_ADMIN_PASSWORD=<contraseña segura>
```

### AWS CloudWatch (obligatorio)

**Opción A - EC2 Instance Profile (recomendado):**

Si el servidor de observabilidad es una instancia EC2 con un IAM Role adjunto,
dejar vacías las variables AWS. Grafana usará las credenciales del Instance Profile automáticamente.

```env
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=us-east-1
```

**Opción B - Access Keys (si no hay Instance Profile):**

```env
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_DEFAULT_REGION=us-east-1
```

### SMTP - Zoho Mail (obligatorio para alertas por correo)

```env
GF_SMTP_HOST=smtp.zoho.com:587
GF_SMTP_USER=alertas@tudominio.com
GF_SMTP_PASSWORD=<contraseña de aplicación Zoho>
GF_SMTP_FROM_ADDRESS=alertas@tudominio.com
GF_SMTP_FROM_NAME=ObservaTI
```

> **Nota Zoho Mail:** Usa una "App Password" en lugar de tu contraseña principal.
> Generarla en: Zoho Mail → Settings → Security → App Passwords.

### Discord (obligatorio para alertas)

```env
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/ID/TOKEN
```

Para crear un Webhook en Discord:
1. Ir al canal donde se quieren recibir alertas.
2. Editar Canal → Integraciones → Webhooks → Nuevo Webhook.
3. Copiar la URL del Webhook.

### Zona horaria

```env
TZ=America/Guatemala
```

## 3. Iniciar servicios

```bash
make up
```

O directamente:

```bash
docker compose up -d
```

## 4. Verificar que los servicios estén corriendo

```bash
make status
make health
```

Resultado esperado:

```
  Grafana:     ✓ UP
  Uptime Kuma: ✓ UP
```

## 5. Acceder a los servicios

| Servicio | URL | Credenciales |
|----------|-----|-------------|
| Grafana | http://<IP_SERVIDOR>:3000 | Las configuradas en .env |
| Uptime Kuma | http://<IP_SERVIDOR>:3001 | Se crean en el primer acceso |

## 6. Configurar Uptime Kuma

Uptime Kuma se configura vía UI en el primer acceso:

1. Abrir http://<IP_SERVIDOR>:3001
2. Crear usuario administrador.
3. Agregar monitores para cada aplicación:

### Ejemplo: Agregar RedApp Producción

| Campo | Valor |
|-------|-------|
| Monitor Type | HTTP(s) |
| Friendly Name | RedApp - Producción |
| URL | https://redapp.tudominio.com |
| Heartbeat Interval | 60 seconds |
| Retries | 3 |
| Accepted Status Codes | 200-299 |

### Ejemplo: Agregar WebApp Test

| Campo | Valor |
|-------|-------|
| Monitor Type | HTTP(s) |
| Friendly Name | WebApp - Test |
| URL | https://test.webapp.tudominio.com |
| Heartbeat Interval | 120 seconds |
| Retries | 3 |
| Accepted Status Codes | 200-299 |

### Configurar notificaciones en Uptime Kuma

1. Settings → Notifications → Setup Notification.
2. **Discord:**
   - Notification Type: Discord
   - Webhook URL: (misma URL del .env)
   - Habilitar para Up & Down.
3. **Email (Zoho):**
   - Notification Type: SMTP
   - Host: smtp.zoho.com
   - Port: 587
   - Security: STARTTLS
   - Username: alertas@tudominio.com
   - Password: <app password>
   - From: alertas@tudominio.com
   - To: equipo@tudominio.com

### Monitores sugeridos iniciales

| Aplicación | Tipo | URL/Host | Intervalo |
|------------|------|----------|-----------|
| RedApp Prod | HTTP(s) | https://redapp.tudominio.com | 60s |
| RedApp Test | HTTP(s) | https://test.redapp.tudominio.com | 120s |
| WebApp Prod | HTTP(s) | https://webapp.tudominio.com | 60s |
| WebApp Test | HTTP(s) | https://test.webapp.tudominio.com | 120s |
| Sitio Corporativo Prod | HTTP(s) | https://www.tudominio.com | 60s |
| Sitio Corporativo Test | HTTP(s) | https://test.tudominio.com | 120s |
| Intranet | HTTP(s) | https://intranet.tudominio.com | 60s |
| SSL RedApp | HTTP(s) - Certificate | https://redapp.tudominio.com | 86400s (diario) |
| SSL WebApp | HTTP(s) - Certificate | https://webapp.tudominio.com | 86400s (diario) |
| SSL Sitio Corporativo | HTTP(s) - Certificate | https://www.tudominio.com | 86400s (diario) |

## 7. Verificar CloudWatch en Grafana

1. Ir a Grafana → Connections → Data sources.
2. Seleccionar "CloudWatch".
3. Click en "Test" → debe mostrar "Data source is working".
4. Si falla, verificar:
   - Las credenciales AWS en `.env`.
   - Que el IAM user/role tenga los permisos correctos.
   - Que el servidor tenga conectividad a internet (puerto 443).

## 8. Verificar dashboards

1. Ir a Grafana → Dashboards.
2. Deberían existir los folders:
   - Overview → Application Health
   - AWS Infrastructure → EC2, RDS, Lambda, API Gateway
3. Si los dashboards muestran "No data", verificar:
   - Que existan recursos en la región configurada.
   - Que el datasource CloudWatch esté funcionando (paso 7).
   - Que los servicios AWS estén generando métricas.

## 9. Verificar alertas

1. Ir a Grafana → Alerting → Contact points.
2. Verificar que existan: discord-alerts, email-alerts.
3. Click "Test" en discord-alerts → debe llegar mensaje a Discord.
4. Click "Test" en email-alerts → debe llegar correo.

---

## Troubleshooting

### Grafana no inicia

```bash
make logs-grafana
```

Causas comunes:
- Puerto 3000 ya en uso: cambiar en docker-compose.yml.
- Permisos en volúmenes: `docker compose down && docker compose up -d`.

### CloudWatch "Access Denied"

Verificar que el IAM user/role tenga esta política adjunta:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:DescribeAlarmsForMetric",
        "cloudwatch:DescribeAlarmHistory",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricData",
        "cloudwatch:GetInsightRuleReport",
        "logs:DescribeLogGroups",
        "logs:GetLogGroupFields",
        "logs:StartQuery",
        "logs:StopQuery",
        "logs:GetQueryResults",
        "logs:GetLogEvents",
        "ec2:DescribeRegions",
        "tag:GetResources"
      ],
      "Resource": "*"
    }
  ]
}
```

### Discord no recibe alertas

1. Verificar que el Webhook URL sea correcto en `.env`.
2. Verificar que el canal de Discord no tenga restricciones.
3. Reiniciar Grafana después de cambiar el `.env`: `make rebuild`.

### SMTP falla (Zoho Mail)

1. Verificar que se usa una App Password (no contraseña principal).
2. Puerto correcto: 587 con STARTTLS.
3. Verificar que la cuenta Zoho tenga SMTP habilitado.
4. Probar: `make logs-grafana` y buscar errores SMTP.

---

## Operaciones comunes

| Acción | Comando |
|--------|---------|
| Iniciar | `make up` |
| Detener | `make down` |
| Ver estado | `make status` |
| Ver logs | `make logs` |
| Backup | `make backup` |
| Reiniciar tras cambio de config | `make rebuild` |
| Validar compose | `make validate` |
| Verificar .env | `make env-check` |

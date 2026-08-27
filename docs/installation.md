# Guía de Instalación - ObservaTI (Fase 1)

## Requisitos previos

| Requisito | Versión mínima | Verificar con |
|-----------|---------------|---------------|
| Docker | 24.0+ | `docker --version` |
| Docker Compose | 2.20+ (plugin) | `docker compose version` |
| yq | 4.0+ | `yq --version` (instalar: `brew install yq`) |
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

### Primer acceso (solo una vez)

1. Abrir http://<IP_SERVIDOR>:3001
2. Crear usuario administrador (recordar estas credenciales).

### Configurar monitores como código

Los monitores se definen en `uptime-kuma/monitors.yml`:

```yaml
defaults:
  interval: 60
  retryInterval: 30
  maxretries: 3
  timeout: 10
  headers:
    # User-Agent de navegador real (necesario para sitios con WAF/CDN)
    User-Agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ..."

monitors:
  - name: "RedApp - Producción"
    type: http
    url: "https://redapp.tudominio.com"
    interval: 60

  - name: "Sitio Corporativo - Producción"
    type: http
    url: "https://www.tudominio.com"
    interval: 60
```

Editar las URLs con los valores reales y ejecutar:

```bash
make setup-monitors
```

El script solicita las credenciales de Uptime Kuma y crea todos los monitores automáticamente.

**Nota importante sobre User-Agent:**
Sitios protegidos por WAF (AWS WAF, Cloudflare, etc.) devuelven HTTP 403 si el request no incluye un User-Agent de navegador real. El campo `defaults.headers.User-Agent` resuelve esto enviando un User-Agent de Chrome en cada check.

### Agregar una nueva aplicación

1. Agregar entrada en `uptime-kuma/monitors.yml`
2. Ejecutar `make setup-monitors` (solo crea los nuevos, no duplica)

### Recrear todos los monitores

Si cambias URLs o headers y necesitas aplicar los cambios:

```bash
make reset-monitors
```

Esto elimina todos los monitores existentes y los recrea desde el YAML.

### Configurar notificaciones en Uptime Kuma

Esto se configura vía UI (Settings → Notifications):

1. **Discord:**
   - Notification Type: Discord
   - Webhook URL: (misma URL del .env)
   - Habilitar para Up & Down.
2. **Email (Zoho):**
   - Notification Type: SMTP
   - Host: smtp.zoho.com
   - Port: 587
   - Security: STARTTLS
   - Username: alertas@tudominio.com
   - Password: <app password>
   - From: alertas@tudominio.com
   - To: equipo@tudominio.com

### Monitores sugeridos iniciales

Los monitores se definen en `uptime-kuma/monitors.yml`. La configuración inicial incluye:

| Aplicación | Tipo | Intervalo |
|------------|------|-----------|
| RedApp Prod | HTTP(s) | 60s |
| RedApp Test | HTTP(s) | 120s |
| WebApp Prod | HTTP(s) | 60s |
| WebApp Test | HTTP(s) | 120s |
| Sitio Corporativo Prod | HTTP(s) | 60s |
| Sitio Corporativo Test | HTTP(s) | 120s |
| Intranet | HTTP(s) | 60s |
| SSL RedApp | HTTP(s) - Certificate | 86400s (diario) |
| SSL WebApp | HTTP(s) - Certificate | 86400s (diario) |
| SSL Sitio Corporativo | HTTP(s) - Certificate | 86400s (diario) |

Editar las URLs en el archivo y ejecutar `make setup-monitors`.

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

### Uptime Kuma marca sitio como DOWN (HTTP 403)

Sitios con WAF/CDN (Cloudflare, AWS WAF, Akamai) bloquean requests sin User-Agent de navegador real.

**Solución:** Verificar que `uptime-kuma/monitors.yml` tenga en defaults:

```yaml
defaults:
  headers:
    User-Agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
```

Luego recrear monitores: `make reset-monitors`

### setup-monitors falla con "Login fallido"

Las credenciales de Uptime Kuma son las que creaste en la UI (http://localhost:3001) al primer acceso. No son las de Grafana ni las del `.env`.

Puedes pasarlas como variables de entorno para evitar el prompt:

```bash
KUMA_USER=admin KUMA_PASS=tu_password make setup-monitors
```

---

## Operaciones comunes

| Acción | Comando |
|--------|---------|
| Iniciar | `make up` |
| Detener | `make down` |
| Ver estado | `make status` |
| Ver logs | `make logs` |
| Configurar monitores | `make setup-monitors` |
| Resetear monitores | `make reset-monitors` |
| Backup | `make backup` |
| Reiniciar tras cambio de config | `make rebuild` |
| Validar compose | `make validate` |
| Verificar .env | `make env-check` |

---

## CI/CD Pipeline

El repositorio incluye un pipeline de GitHub Actions que valida automáticamente cada cambio.

### ¿Qué se ejecuta?

En cada **push a develop/main**:
- Valida `docker-compose.yml`
- Valida JSONs de dashboards y YAMLs de alerting
- Valida `monitors.yml` (campos requeridos)
- Valida Terraform (`fmt`, `init`, `validate`)
- Levanta el stack completo y verifica que Grafana arranque con dashboards y alertas

En cada **PR a main** (si se configuran secrets AWS):
- Ejecuta `terraform plan` y postea el resultado como comentario en el PR

### Configurar secrets para terraform plan (opcional)

En GitHub: Settings → Secrets and variables → Actions → New repository secret:

| Secret | Valor |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | Access Key del operador de Terraform |
| `AWS_SECRET_ACCESS_KEY` | Secret Key correspondiente |

Sin estos secrets, el pipeline pasa igualmente — solo omite el paso de `terraform plan`.

### Validar localmente antes de push

```bash
# Validar compose
make validate

# Validar Terraform
cd terraform && terraform fmt -check && terraform init -backend=false && terraform validate

# Verificar que el stack arranca
make up && make health
```

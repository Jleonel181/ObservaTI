# ============================================================
# ObservaTI - Makefile
# ============================================================
# Comandos operacionales para la plataforma de observabilidad.
# Uso: make <comando>
# ============================================================

.PHONY: help up down restart status logs logs-grafana logs-uptime health backup clean

# --- Variables ---
COMPOSE = docker compose
BACKUP_DIR = ./backups
TIMESTAMP = $(shell date +%Y%m%d_%H%M%S)

# --- Default ---
help: ## Muestra esta ayuda
	@echo ""
	@echo "  ObservaTI - Comandos disponibles"
	@echo "  ================================"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

# --- Lifecycle ---
up: ## Inicia todos los servicios
	$(COMPOSE) up -d
	@echo ""
	@echo "  ✓ ObservaTI iniciado"
	@echo "  → Grafana:     http://localhost:3000"
	@echo "  → Uptime Kuma: http://localhost:3001"
	@echo ""

down: ## Detiene todos los servicios (datos persistentes se mantienen)
	$(COMPOSE) down
	@echo "  ✓ Servicios detenidos. Los datos persisten en volúmenes Docker."

restart: ## Reinicia todos los servicios
	$(COMPOSE) restart
	@echo "  ✓ Servicios reiniciados."

pull: ## Descarga las últimas versiones de las imágenes configuradas
	$(COMPOSE) pull

rebuild: ## Reconstruye y reinicia (útil tras cambios de configuración)
	$(COMPOSE) down
	$(COMPOSE) up -d --force-recreate
	@echo "  ✓ Servicios recreados con nueva configuración."

# --- Observación ---
status: ## Muestra el estado de los contenedores
	$(COMPOSE) ps

health: ## Verifica la salud de los servicios
	@echo "  Verificando servicios..."
	@echo ""
	@printf "  Grafana:     "; curl -sf http://localhost:3000/api/health > /dev/null && echo "✓ UP" || echo "✗ DOWN"
	@printf "  Uptime Kuma: "; curl -sf http://localhost:3001 > /dev/null && echo "✓ UP" || echo "✗ DOWN"
	@echo ""

logs: ## Muestra logs de todos los servicios (últimas 50 líneas)
	$(COMPOSE) logs --tail=50

logs-grafana: ## Muestra logs de Grafana (follow)
	$(COMPOSE) logs -f grafana

logs-uptime: ## Muestra logs de Uptime Kuma (follow)
	$(COMPOSE) logs -f uptime-kuma

# --- Backup ---
# --- Setup ---
setup-monitors: ## Configura monitores de Uptime Kuma desde uptime-kuma/monitors.yml
	@./scripts/setup-monitors.sh

reset-monitors: ## Elimina TODOS los monitores de Uptime Kuma y los recrea desde código
	@RESET_MONITORS=1 ./scripts/setup-monitors.sh

sync-ec2-names: ## Sincroniza nombres (tag Name) de instancias EC2 en los dashboards
	@./scripts/sync-ec2-names.sh

# --- Backup ---
backup: ## Crea backup de configuración y volúmenes
	@mkdir -p $(BACKUP_DIR)
	@echo "  Creando backup..."
	@tar -czf $(BACKUP_DIR)/observati-config-$(TIMESTAMP).tar.gz \
		docker-compose.yml \
		.env \
		grafana/ \
		--exclude='*.tar.gz' 2>/dev/null || true
	@docker run --rm \
		-v observati_grafana_data:/data/grafana:ro \
		-v observati_uptime_kuma_data:/data/uptime-kuma:ro \
		-v $(PWD)/$(BACKUP_DIR):/backup \
		alpine tar -czf /backup/observati-volumes-$(TIMESTAMP).tar.gz /data 2>/dev/null || \
		echo "  ⚠ No se pudieron respaldar volúmenes (¿servicios corriendo?)"
	@echo "  ✓ Backup creado en $(BACKUP_DIR)/"
	@ls -la $(BACKUP_DIR)/*$(TIMESTAMP)* 2>/dev/null

# --- Mantenimiento ---
clean: ## Elimina contenedores, redes (NO elimina volúmenes de datos)
	$(COMPOSE) down --remove-orphans
	@echo "  ✓ Limpieza completada. Volúmenes de datos intactos."

clean-all: ## ⚠️  PELIGROSO: Elimina todo incluyendo datos persistentes
	@echo "  ⚠️  ADVERTENCIA: Esto eliminará TODOS los datos (dashboards, configuración Uptime Kuma)."
	@echo "  Presiona Ctrl+C para cancelar, o Enter para continuar..."
	@read _
	$(COMPOSE) down -v --remove-orphans
	@echo "  ✓ Todo eliminado incluyendo volúmenes."

# --- Validación ---
validate: ## Valida la configuración de Docker Compose
	$(COMPOSE) config --quiet && echo "  ✓ docker-compose.yml válido" || echo "  ✗ Error en configuración"

env-check: ## Verifica que las variables de entorno estén configuradas
	@echo "  Verificando variables de entorno..."
	@echo ""
	@test -f .env && echo "  ✓ Archivo .env existe" || echo "  ✗ Archivo .env NO existe (copia .env.example)"
	@echo ""
	@if [ -f .env ]; then \
		grep -q "CHANGE_ME" .env && echo "  ⚠ Hay valores por cambiar (CHANGE_ME) en .env" || echo "  ✓ No hay placeholders pendientes"; \
		grep -q "^DISCORD_WEBHOOK_URL=https://discord" .env && echo "  ✓ Discord Webhook configurado" || echo "  ⚠ Discord Webhook no configurado"; \
		grep -q "^GF_SMTP_USER=." .env && echo "  ✓ SMTP user configurado" || echo "  ⚠ SMTP user no configurado"; \
	fi

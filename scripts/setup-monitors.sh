#!/bin/bash
# ============================================================
# ObservaTI - Setup Uptime Kuma Monitors
# ============================================================
# Crea monitores en Uptime Kuma desde uptime-kuma/monitors.yml
# Se ejecuta dentro de un contenedor Docker (sin instalar nada local).
#
# Requisitos:
#   - Docker corriendo con Uptime Kuma (make up)
#   - Usuario admin ya creado en Uptime Kuma (primer acceso web)
#   - yq instalado localmente (brew install yq)
#
# Uso:
#   make setup-monitors
#   KUMA_USER=admin KUMA_PASS=password make setup-monitors
# ============================================================

set -euo pipefail

MONITORS_FILE="${MONITORS_FILE:-uptime-kuma/monitors.yml}"

# --- Colores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Validaciones ---
if ! command -v yq &> /dev/null; then
  echo -e "${RED}Error: yq no está instalado. Ejecuta: brew install yq${NC}"
  exit 1
fi

if [ ! -f "$MONITORS_FILE" ]; then
  echo -e "${RED}Error: No se encuentra $MONITORS_FILE${NC}"
  exit 1
fi

if ! docker compose ps uptime-kuma 2>/dev/null | grep -qi "up\|running"; then
  echo -e "${RED}Error: Uptime Kuma no está corriendo. Ejecuta: make up${NC}"
  exit 1
fi

# --- Solicitar credenciales ---
KUMA_USER="${KUMA_USER:-}"
KUMA_PASS="${KUMA_PASS:-}"

if [ -z "$KUMA_USER" ]; then
  read -p "Uptime Kuma usuario: " KUMA_USER
fi
if [ -z "$KUMA_PASS" ]; then
  read -sp "Uptime Kuma contraseña: " KUMA_PASS
  echo ""
fi

# --- Leer monitores del YAML y convertir a JSON ---
MONITORS_JSON=$(yq -o=json '.monitors' "$MONITORS_FILE")
DEFAULTS_JSON=$(yq -o=json '.defaults // {}' "$MONITORS_FILE")

echo ""
echo -e "${YELLOW}Configurando monitores en Uptime Kuma...${NC}"
echo ""

# --- Ejecutar dentro de un contenedor Python efímero ---
docker run --rm --network observati-network \
  -e KUMA_USER="$KUMA_USER" \
  -e KUMA_PASS="$KUMA_PASS" \
  -e MONITORS_JSON="$MONITORS_JSON" \
  -e DEFAULTS_JSON="$DEFAULTS_JSON" \
  -e RESET_MONITORS="${RESET_MONITORS:-0}" \
  python:3.12-slim sh -c '
    pip install -q "python-socketio[client]" "websocket-client" 2>/dev/null
    python3 << "EOF"
import os
import sys
import json
import time
import socketio

KUMA_URL = "http://observati-uptime-kuma:3001"
USERNAME = os.environ["KUMA_USER"]
PASSWORD = os.environ["KUMA_PASS"]
MONITORS = json.loads(os.environ["MONITORS_JSON"])
DEFAULTS = json.loads(os.environ.get("DEFAULTS_JSON", "{}"))
DEFAULT_HEADERS = DEFAULTS.get("headers", {})

sio = socketio.Client()
login_ok = {}
monitor_list = {}
add_results = []

@sio.on("monitorList")
def on_monitor_list(data):
    monitor_list.update(data)

sio.connect(KUMA_URL, transports=["websocket"])

# Login con callback
def on_login(data):
    login_ok.update(data if isinstance(data, dict) else {"ok": False})

sio.emit("login", {"username": USERNAME, "password": PASSWORD, "token": ""}, callback=on_login)
time.sleep(2)

if not login_ok.get("ok"):
    msg = login_ok.get("msg", "credenciales incorrectas")
    print(f"✗ Login fallido: {msg}")
    sio.disconnect()
    sys.exit(1)

print("✓ Login exitoso")
print()

# Esperar a recibir lista de monitores
time.sleep(1)

existing_names = set()
existing_ids = []
for mid, mon in monitor_list.items():
    existing_names.add(mon.get("name", ""))
    existing_ids.append(int(mid))


# ---- Gestion de tags ----
# Uptime Kuma maneja tags en dos pasos: crear el tag global y luego
# asociarlo a cada monitor. Aqui garantizamos que cada tag del YAML
# exista y guardamos su id para reutilizarlo.
def emit_sync(event, data=None, timeout=5):
    box = {}
    def cb(*a):
        box["r"] = a
    if data is None:
        sio.emit(event, callback=cb)
    else:
        sio.emit(event, data, callback=cb)
    waited = 0.0
    while "r" not in box and waited < timeout:
        time.sleep(0.1)
        waited += 0.1
    return box.get("r")


# Cargar tags ya existentes en Kuma: {nombre: id}
tag_ids = {}
resp = emit_sync("getTags")
if resp and isinstance(resp[0], dict) and resp[0].get("ok"):
    for t in resp[0].get("tags", []):
        tag_ids[t["name"]] = t["id"]


def ensure_tag(name, color):
    """Devuelve el id del tag, creandolo si no existe."""
    if name in tag_ids:
        return tag_ids[name]
    resp = emit_sync("addTag", {"name": name, "color": color})
    if resp and isinstance(resp[0], dict) and resp[0].get("ok"):
        tid = resp[0]["tag"]["id"]
        tag_ids[name] = tid
        print(f"  + Tag creado: {name}")
        return tid
    return None

# Si RESET, eliminar todos los monitores existentes
if os.environ.get("RESET_MONITORS") == "1" and existing_ids:
    print(f"Eliminando {len(existing_ids)} monitores existentes...")
    for mid in existing_ids:
        result = {}
        def on_delete(data, _r=result):
            _r.update(data if isinstance(data, dict) else {})
        sio.emit("deleteMonitor", mid, callback=on_delete)
        time.sleep(0.3)
    existing_names = set()
    print("✓ Monitores eliminados")
    print()

# Crear monitores
created = 0
skipped = 0

for monitor in MONITORS:
    name = monitor.get("name", "")
    url = monitor.get("url", "")
    interval = monitor.get("interval", 60)
    max_retries = monitor.get("maxretries", 3)
    mon_type = monitor.get("type", "http")

    if name in existing_names:
        print(f"  ⊘ Skip: {name} (ya existe)")
        skipped += 1
        continue

    type_map = {"http": "http", "https": "http", "tcp": "port", "ping": "ping", "dns": "dns"}
    kuma_type = type_map.get(mon_type, "http")

    monitor_data = {
        "type": kuma_type,
        "name": name,
        "url": url,
        "interval": interval,
        "maxretries": max_retries,
        "retryInterval": 30,
        "active": True,
        "accepted_statuscodes": ["200-299"],
        "notificationIDList": {},
    }

    # Headers: merge defaults + per-monitor overrides
    headers = dict(DEFAULT_HEADERS)
    monitor_headers = monitor.get("headers", {})
    if monitor_headers:
        headers.update(monitor_headers)
    if headers:
        monitor_data["headers"] = json.dumps(headers)

    result = {}

    def on_add(data, _result=result):
        _result.update(data if isinstance(data, dict) else {"ok": False})

    sio.emit("add", monitor_data, callback=on_add)
    time.sleep(1)

    if result.get("ok"):
        monitor_id = result.get("monitorID", "?")
        print(f"  ✓ Creado: {name} (ID: {monitor_id})")
        created += 1

        # Asociar tags al monitor recien creado
        for tag in monitor.get("tags", []):
            tname = tag.get("name")
            tcolor = tag.get("color", "#4b5563")
            if not tname:
                continue
            tid = ensure_tag(tname, tcolor)
            if tid is not None:
                emit_sync("addMonitorTag", (tid, monitor_id, ""))
    else:
        msg = result.get("msg", "error desconocido")
        print(f"  ✗ Error: {name} - {msg}")

sio.disconnect()

print()
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print(f"  Creados:  {created}")
print(f"  Saltados: {skipped}")
print(f"  Total:    {len(MONITORS)}")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
EOF
'

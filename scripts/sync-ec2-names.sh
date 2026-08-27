#!/bin/bash
# ============================================================
# ObservaTI - Sincroniza nombres de instancias EC2
# ============================================================
# CloudWatch solo expone InstanceId en las metricas, nunca el tag Name.
# Este script consulta EC2 y genera field overrides (displayName) en los
# paneles marcados, para que muestren nombres legibles en vez de i-xxxx.
#
# Ejecutar cuando se creen o eliminen instancias EC2.
#
# Uso:
#   make sync-ec2-names
#   AWS_REGION=us-west-2 ./scripts/sync-ec2-names.sh
# ============================================================

set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
DASHBOARD="${DASHBOARD:-grafana/provisioning/dashboards/overview/application-health.json}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if ! command -v aws &> /dev/null; then
  echo -e "${RED}Error: aws CLI no esta instalado.${NC}"
  exit 1
fi

if [ ! -f "$DASHBOARD" ]; then
  echo -e "${RED}Error: no se encuentra $DASHBOARD${NC}"
  exit 1
fi

echo -e "${YELLOW}Consultando instancias EC2 en $AWS_REGION...${NC}"

MAPPING_JSON=$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --query 'Reservations[].Instances[].{id:InstanceId,name:Tags[?Key==`Name`]|[0].Value}' \
  --output json)

export MAPPING_JSON DASHBOARD

python3 << 'PYEOF'
import json
import os

mapping_raw = json.loads(os.environ["MAPPING_JSON"])
dashboard_path = os.environ["DASHBOARD"]

# InstanceId -> Name (solo instancias con tag Name)
names = {
    i["id"]: i["name"]
    for i in mapping_raw
    if i.get("id") and i.get("name")
}

if not names:
    print("  No se encontraron instancias con tag Name. Sin cambios.")
    raise SystemExit(0)

# Field overrides: renombran la serie cuyo nombre es el InstanceId.
# Los value mappings NO sirven aqui: mapean valores, no nombres de serie.
overrides = [
    {
        "matcher": {"id": "byName", "options": instance_id},
        "properties": [{"id": "displayName", "value": name}],
    }
    for instance_id, name in sorted(names.items(), key=lambda kv: kv[1])
]

with open(dashboard_path) as f:
    dashboard = json.load(f)

updated = []
for panel in dashboard.get("panels", []):
    if "ec2-name-mapping" not in (panel.get("description") or ""):
        continue

    field_config = panel.setdefault("fieldConfig", {})

    # Conservar overrides manuales que no sean del mapeo de nombres EC2
    manual = [
        o for o in field_config.get("overrides", [])
        if not (
            o.get("matcher", {}).get("id") == "byName"
            and str(o.get("matcher", {}).get("options", "")).startswith("i-")
        )
    ]
    field_config["overrides"] = manual + overrides

    # Limpiar value mappings de instancias (enfoque anterior, no funcionaba)
    defaults = field_config.setdefault("defaults", {})
    if "mappings" in defaults:
        cleaned = []
        for m in defaults["mappings"]:
            if m.get("type") == "value":
                opts = {
                    k: v for k, v in m.get("options", {}).items()
                    if not k.startswith("i-")
                }
                if opts:
                    cleaned.append({"type": "value", "options": opts})
            else:
                cleaned.append(m)
        defaults["mappings"] = cleaned

    updated.append(panel.get("title"))

with open(dashboard_path, "w") as f:
    json.dump(dashboard, f, indent=2)
    f.write("\n")

print(f"  Instancias con nombre: {len(names)}")
for title in updated:
    print(f"  Panel actualizado: {title} ({len(overrides)} overrides)")
if not updated:
    print("  Ningun panel marcado con 'ec2-name-mapping' en su description.")
PYEOF

echo -e "${GREEN}Listo.${NC} Reinicia Grafana para aplicar: make rebuild"

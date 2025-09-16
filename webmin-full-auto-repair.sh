#!/bin/bash

# Reparación completa (one-shot) del servidor y servidores virtuales
# Usa las rutinas del auto-repair continuo y fuerza una pasada completa

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN="/opt/webmin-self-healing/auto-repair.sh"

if [[ -x "$MAIN" ]]; then
  echo "[INFO] Ejecutando reparación completa..."
  # Exportar flags para que el script continuo ejecute validación inmediata
  export FORCE_VALIDATE_NOW=1
  bash "$MAIN" --oneshot || true
else
  echo "[ERROR] No existe $MAIN. Reinstala el stack de auto-reparación."
  exit 1
fi


#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

expected_modules=(
  "openvm-core"
  "openvm-admin"
  "openvm-suite"
  "openvm-dns"
  "openvm-backup"
)

expected_entrypoints=(
  "openvm-core/index.cgi"
  "openvm-core/edit_html.cgi"
  "openvm-core/connectivity.cgi"
  "openvm-core/maillog.cgi"
  "openvm-core/list_bkeys.cgi"
  "openvm-core/remotedns.cgi"
  "openvm-admin/index.cgi"
  "openvm-admin/admins.cgi"
  "openvm-admin/resellers.cgi"
  "openvm-admin/audit.cgi"
  "openvm-suite/index.cgi"
  "openvm-dns/index.cgi"
  "openvm-backup/index.cgi"
  "openvm-backup/schedules.cgi"
  "openvm-backup/keys.cgi"
  "openvm-backup/restore.cgi"
)

INSTALLER_FILE="${ROOT_DIR}/install_openvm_suite.sh"
PRODUCTION_INSTALLER_FILE="${ROOT_DIR}/install_openvm_production.sh"

echo "[openvm-stack-test] Verificando módulos declarados en instalador principal"
for module in "${expected_modules[@]}"; do
  grep -q "\"${module}\"" "$INSTALLER_FILE" || {
    echo "Módulo no registrado en instalador principal: ${module}" >&2
    exit 1
  }
done

echo "[openvm-stack-test] Verificando entrypoints declarados"
for entrypoint in "${expected_entrypoints[@]}"; do
  grep -q "\"${entrypoint}\"" "$INSTALLER_FILE" || {
    echo "Entrypoint no registrado en instalador principal: ${entrypoint}" >&2
    exit 1
  }
done

echo "[openvm-stack-test] Verificando instalador de producción"
[[ -f "$PRODUCTION_INSTALLER_FILE" ]] || {
  echo "No existe instalador de producción" >&2
  exit 1
}
bash -n "$PRODUCTION_INSTALLER_FILE"

echo "[openvm-stack-test] Verificando README de producción"
[[ -f "${ROOT_DIR}/docs/OPENVM_PRODUCTION_README.md" ]] || {
  echo "No existe documentación de producción" >&2
  exit 1
}

echo "[openvm-stack-test] OK"

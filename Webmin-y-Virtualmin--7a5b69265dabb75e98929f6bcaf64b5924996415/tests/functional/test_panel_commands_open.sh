#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SETUP_FILE="${ROOT_DIR}/setup_pro_production.sh"
VALIDATOR_FILE="${ROOT_DIR}/validate_installation.sh"
OPENVM_INSTALLER_FILE="${ROOT_DIR}/install_openvm_suite.sh"

expected_native_commands=(
  "vmin-install-app"
  "vmin-ssh-keys"
  "vmin-backup-keys"
  "vmin-mail-search"
  "vmin-cloud-dns"
  "vmin-resource-limits"
  "vmin-mailbox-cleanup"
  "vmin-secondary-mx"
  "vmin-check-connectivity"
  "vmin-graphs"
  "vmin-batch-create"
  "vmin-add-link"
  "vmin-ssl-cert"
  "vmin-edit-file"
  "vmin-email-owners"
)

expected_openvm_modules=(
  "openvm-core"
  "openvm-admin"
  "openvm-suite"
  "openvm-dns"
  "openvm-backup"
)

license_blockers='virtualmin_license_file|LicenseKey|SerialNumber|upgrade-licence|downgrade-licence|update_licence_from_site|check_licence_expired'

echo "[panel-open-test] Verificando comandos nativos abiertos del panel"
for command_name in "${expected_native_commands[@]}"; do
  grep -q "/usr/local/bin/${command_name}" "$SETUP_FILE" || {
    echo "No se genera el comando nativo esperado: ${command_name}" >&2
    exit 1
  }

  grep -q "\"${command_name}\"" "$VALIDATOR_FILE" || {
    echo "El validador no cubre el comando nativo esperado: ${command_name}" >&2
    exit 1
  }
done

echo "[panel-open-test] Verificando módulos OpenVM declarados como runtime abierto"
for module_name in "${expected_openvm_modules[@]}"; do
  grep -q "\"${module_name}\"" "$OPENVM_INSTALLER_FILE" || {
    echo "El instalador OpenVM no declara el módulo esperado: ${module_name}" >&2
    exit 1
  }
done

echo "[panel-open-test] Verificando ausencia de bloqueos de licencia en la capa abierta"
if grep -E -n "$license_blockers" \
  "$SETUP_FILE" \
  "$VALIDATOR_FILE" \
  "$OPENVM_INSTALLER_FILE"; then
  echo "Se detectó lógica de licencia en la capa abierta del panel" >&2
  exit 1
fi

echo "[panel-open-test] OK"

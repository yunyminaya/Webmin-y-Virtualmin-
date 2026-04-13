#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATION_SCRIPTS=(
  "./tests/functional/test_openvm_core.sh"
  "./tests/functional/test_openvm_admin.sh"
  "./tests/functional/test_openvm_suite.sh"
  "./tests/functional/test_openvm_dns.sh"
  "./tests/functional/test_openvm_backup.sh"
  "./tests/functional/test_virtualmin_pro_compat.sh"
  "./tests/integration/test_openvm_stack.sh"
)

log() {
  printf '[openvm-production] %s\n' "$1"
}

ensure_executable() {
  local file="$1"
  [[ -f "$file" ]] || {
    log "No existe el archivo requerido: $file"
    return 1
  }
  chmod 755 "$file"
}

run_validations() {
  local script
  for script in "${VALIDATION_SCRIPTS[@]}"; do
    ensure_executable "$script"
    log "Ejecutando validación: $script"
    "$script"
  done
}

main() {
  log "Iniciando despliegue OpenVM para producción"
  ensure_executable "${SCRIPT_DIR}/install_openvm_suite.sh"
  "${SCRIPT_DIR}/install_openvm_suite.sh"
  run_validations
  log "Despliegue y validación OpenVM completados"
}

main "$@"

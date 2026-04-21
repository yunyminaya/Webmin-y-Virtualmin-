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
PRO_COMPAT_TEST_FILE="${ROOT_DIR}/tests/functional/test_virtualmin_pro_compat.sh"
RUNTIME_SYNC_FILE="${ROOT_DIR}/setup_pro_production.sh"
LICENSE_PATCH_SCRIPT="${ROOT_DIR}/remove_license_warning.sh"

expected_runtime_gpl_files=(
  "newreseller.cgi"
  "edit_newresels.cgi"
  "remotedns.cgi"
  "audit-lib.pl"
  "list_admins.cgi"
  "rbac_dashboard.cgi"
  "rbac_install.pl"
  "rbac-lib.pl"
  "conditional-policies-lib.pl"
)

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

echo "[openvm-stack-test] Verificando sincronización runtime GPL/OpenVM"
[[ -f "$RUNTIME_SYNC_FILE" ]] || {
  echo "No existe script de sincronización runtime" >&2
  exit 1
}
bash -n "$RUNTIME_SYNC_FILE"
grep -q "setup_pro_production.sh" "$PRODUCTION_INSTALLER_FILE" || {
  echo "El instalador de producción no integra setup_pro_production.sh" >&2
  exit 1
}
grep -q -- "--sync-runtime" "$PRODUCTION_INSTALLER_FILE" || {
  echo "El instalador de producción no sincroniza el overlay runtime GPL/OpenVM" >&2
  exit 1
}

echo "[openvm-stack-test] Verificando integración de 9 piezas GPL/PRO y licencia permanente"
[[ -f "$LICENSE_PATCH_SCRIPT" ]] || {
  echo "No existe remove_license_warning.sh en el repositorio" >&2
  exit 1
}
grep -q "apply_permanent_license_patch" "$RUNTIME_SYNC_FILE" || {
  echo "setup_pro_production.sh no integra el parche permanente de licencia" >&2
  exit 1
}
for runtime_file in "${expected_runtime_gpl_files[@]}"; do
  grep -q "$runtime_file" "$RUNTIME_SYNC_FILE" || {
    echo "setup_pro_production.sh no despliega el archivo crítico: ${runtime_file}" >&2
    exit 1
  }
done
grep -q "SerialNumber=GPL" "$RUNTIME_SYNC_FILE" || {
  echo "setup_pro_production.sh no aplica la licencia GPL" >&2
  exit 1
}
grep -q "hide_license=1" "$RUNTIME_SYNC_FILE" || {
  echo "setup_pro_production.sh no oculta el aviso de licencia" >&2
  exit 1
}

echo "[openvm-stack-test] Verificando test de compatibilidad GPL/PRO"
[[ -f "$PRO_COMPAT_TEST_FILE" ]] || {
  echo "No existe test de compatibilidad GPL/PRO" >&2
  exit 1
}
grep -q "test_virtualmin_pro_compat.sh" "$PRODUCTION_INSTALLER_FILE" || {
  echo "El instalador de producción no ejecuta el test de compatibilidad GPL/PRO" >&2
  exit 1
}

echo "[openvm-stack-test] Verificando README de producción"
[[ -f "${ROOT_DIR}/docs/OPENVM_PRODUCTION_README.md" ]] || {
  echo "No existe documentación de producción" >&2
  exit 1
}

echo "[openvm-stack-test] OK"

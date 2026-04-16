#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

required_files=(
  "openvm-admin/module.info"
  "openvm-admin/config"
  "openvm-admin/openvm-admin-lib.pl"
  "openvm-admin/index.cgi"
  "openvm-admin/admins.cgi"
  "openvm-admin/resellers.cgi"
  "openvm-admin/audit.cgi"
  "install_openvm_suite.sh"
)

code_files=(
  "openvm-admin/openvm-admin-lib.pl"
  "openvm-admin/index.cgi"
  "openvm-admin/admins.cgi"
  "openvm-admin/resellers.cgi"
  "openvm-admin/audit.cgi"
)

echo "[openvm-admin-test] Verificando archivos requeridos"
for file in "${required_files[@]}"; do
  [[ -f "${ROOT_DIR}/${file}" ]] || {
    echo "Falta archivo: ${file}" >&2
    exit 1
  }
done

echo "[openvm-admin-test] Ejecutando validación sintáctica Perl"
for file in "${code_files[@]}"; do
  perl -c "${ROOT_DIR}/${file}" >/dev/null
done

echo "[openvm-admin-test] Verificando ausencia de escrituras a licencia oficial"
if grep -E -n "virtualmin_license_file|LicenseKey|SerialNumber|upgrade-licence|downgrade-licence" \
  "${ROOT_DIR}/openvm-admin/openvm-admin-lib.pl" \
  "${ROOT_DIR}/openvm-admin/index.cgi" \
  "${ROOT_DIR}/openvm-admin/admins.cgi" \
  "${ROOT_DIR}/openvm-admin/resellers.cgi" \
  "${ROOT_DIR}/openvm-admin/audit.cgi" \
  "${ROOT_DIR}/install_openvm_suite.sh"; then
  echo "Se detectó una referencia prohibida a flujos de licencia oficiales" >&2
  exit 1
fi

echo "[openvm-admin-test] OK"

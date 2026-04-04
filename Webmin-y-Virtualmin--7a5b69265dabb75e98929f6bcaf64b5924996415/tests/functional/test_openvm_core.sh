#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

required_files=(
  "openvm-core/module.info"
  "openvm-core/config"
  "openvm-core/openvm-lib.pl"
  "openvm-core/index.cgi"
  "openvm-core/edit_html.cgi"
  "openvm-core/connectivity.cgi"
  "openvm-core/maillog.cgi"
  "openvm-core/list_bkeys.cgi"
  "openvm-core/remotedns.cgi"
  "install_openvm_suite.sh"
)

code_files=(
  "openvm-core/openvm-lib.pl"
  "openvm-core/index.cgi"
  "openvm-core/edit_html.cgi"
  "openvm-core/connectivity.cgi"
  "openvm-core/maillog.cgi"
  "openvm-core/list_bkeys.cgi"
  "openvm-core/remotedns.cgi"
)

echo "[openvm-test] Verificando archivos requeridos"
for file in "${required_files[@]}"; do
  [[ -f "${ROOT_DIR}/${file}" ]] || {
    echo "Falta archivo: ${file}" >&2
    exit 1
  }
done

echo "[openvm-test] Ejecutando validación sintáctica Perl"
for file in "${code_files[@]}"; do
  perl -c "${ROOT_DIR}/${file}" >/dev/null
done

echo "[openvm-test] Verificando ausencia de escrituras a licencia oficial"
if grep -E -n "virtualmin_license_file|LicenseKey|SerialNumber|upgrade-licence|downgrade-licence" \
  "${ROOT_DIR}/openvm-core/openvm-lib.pl" \
  "${ROOT_DIR}/openvm-core/index.cgi" \
  "${ROOT_DIR}/openvm-core/edit_html.cgi" \
  "${ROOT_DIR}/openvm-core/connectivity.cgi" \
  "${ROOT_DIR}/openvm-core/maillog.cgi" \
  "${ROOT_DIR}/openvm-core/list_bkeys.cgi" \
  "${ROOT_DIR}/openvm-core/remotedns.cgi" \
  "${ROOT_DIR}/install_openvm_suite.sh"; then
  echo "Se detectó una referencia prohibida a flujos de licencia oficiales" >&2
  exit 1
fi

echo "[openvm-test] OK"

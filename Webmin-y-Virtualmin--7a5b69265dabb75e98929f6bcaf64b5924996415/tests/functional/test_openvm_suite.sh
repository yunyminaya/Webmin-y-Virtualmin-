#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

required_files=(
  "openvm-suite/module.info"
  "openvm-suite/config"
  "openvm-suite/openvm-suite-lib.pl"
  "openvm-suite/index.cgi"
  "install_openvm_suite.sh"
)

code_files=(
  "openvm-suite/openvm-suite-lib.pl"
  "openvm-suite/index.cgi"
)

echo "[openvm-suite-test] Verificando archivos requeridos"
for file in "${required_files[@]}"; do
  [[ -f "${ROOT_DIR}/${file}" ]] || {
    echo "Falta archivo: ${file}" >&2
    exit 1
  }
done

echo "[openvm-suite-test] Ejecutando validación sintáctica Perl"
for file in "${code_files[@]}"; do
  perl -c "${ROOT_DIR}/${file}" >/dev/null
done

echo "[openvm-suite-test] Verificando ausencia de escrituras a licencia oficial"
if grep -E -n "virtualmin_license_file|LicenseKey|SerialNumber|upgrade-licence|downgrade-licence" \
  "${ROOT_DIR}/openvm-suite/openvm-suite-lib.pl" \
  "${ROOT_DIR}/openvm-suite/index.cgi" \
  "${ROOT_DIR}/install_openvm_suite.sh"; then
  echo "Se detectó una referencia prohibida a flujos de licencia oficiales" >&2
  exit 1
fi

echo "[openvm-suite-test] OK"

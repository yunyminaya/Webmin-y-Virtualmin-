#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

required_files=(
  "openvm-dns/module.info"
  "openvm-dns/config"
  "openvm-dns/openvm-dns-lib.pl"
  "openvm-dns/index.cgi"
  "install_openvm_suite.sh"
)

code_files=(
  "openvm-dns/openvm-dns-lib.pl"
  "openvm-dns/index.cgi"
)

echo "[openvm-dns-test] Verificando archivos requeridos"
for file in "${required_files[@]}"; do
  [[ -f "${ROOT_DIR}/${file}" ]] || {
    echo "Falta archivo: ${file}" >&2
    exit 1
  }
done

echo "[openvm-dns-test] Ejecutando validación sintáctica Perl"
for file in "${code_files[@]}"; do
  perl -c "${ROOT_DIR}/${file}" >/dev/null
done

echo "[openvm-dns-test] Verificando ausencia de escrituras a licencia oficial"
if grep -E -n "virtualmin_license_file|LicenseKey|SerialNumber|upgrade-licence|downgrade-licence" \
  "${ROOT_DIR}/openvm-dns/openvm-dns-lib.pl" \
  "${ROOT_DIR}/openvm-dns/index.cgi" \
  "${ROOT_DIR}/install_openvm_suite.sh"; then
  echo "Se detectó una referencia prohibida a flujos de licencia oficiales" >&2
  exit 1
fi

echo "[openvm-dns-test] OK"

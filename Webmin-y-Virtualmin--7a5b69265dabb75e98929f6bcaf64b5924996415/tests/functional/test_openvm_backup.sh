#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

required_files=(
  "openvm-backup/module.info"
  "openvm-backup/config"
  "openvm-backup/openvm-backup-lib.pl"
  "openvm-backup/index.cgi"
  "openvm-backup/schedules.cgi"
  "openvm-backup/keys.cgi"
  "openvm-backup/restore.cgi"
  "install_openvm_suite.sh"
)

code_files=(
  "openvm-backup/openvm-backup-lib.pl"
  "openvm-backup/index.cgi"
  "openvm-backup/schedules.cgi"
  "openvm-backup/keys.cgi"
  "openvm-backup/restore.cgi"
)

echo "[openvm-backup-test] Verificando archivos requeridos"
for file in "${required_files[@]}"; do
  [[ -f "${ROOT_DIR}/${file}" ]] || {
    echo "Falta archivo: ${file}" >&2
    exit 1
  }
done

echo "[openvm-backup-test] Ejecutando validación sintáctica Perl"
for file in "${code_files[@]}"; do
  perl -c "${ROOT_DIR}/${file}" >/dev/null
done

echo "[openvm-backup-test] Verificando ausencia de escrituras a licencia oficial"
if grep -E -n "virtualmin_license_file|LicenseKey|SerialNumber|upgrade-licence|downgrade-licence" \
  "${ROOT_DIR}/openvm-backup/openvm-backup-lib.pl" \
  "${ROOT_DIR}/openvm-backup/index.cgi" \
  "${ROOT_DIR}/openvm-backup/schedules.cgi" \
  "${ROOT_DIR}/openvm-backup/keys.cgi" \
  "${ROOT_DIR}/openvm-backup/restore.cgi" \
  "${ROOT_DIR}/install_openvm_suite.sh"; then
  echo "Se detectó una referencia prohibida a flujos de licencia oficiales" >&2
  exit 1
fi

echo "[openvm-backup-test] OK"

#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PRO_DIR="${ROOT_DIR}/virtualmin-gpl-master/pro"

required_files=(
  "virtualmin-gpl-master/pro/openvm-compat-lib.pl"
  "virtualmin-gpl-master/pro/edit_html.cgi"
  "virtualmin-gpl-master/pro/connectivity.cgi"
  "virtualmin-gpl-master/pro/maillog.cgi"
  "virtualmin-gpl-master/pro/list_bkeys.cgi"
  "virtualmin-gpl-master/pro/history.cgi"
  "virtualmin-gpl-master/pro/edit_newacmes.cgi"
  "virtualmin-gpl-master/pro/edit_res.cgi"
  "virtualmin-gpl-master/pro/licence.cgi"
  "virtualmin-gpl-master/pro/mass_domains_form.cgi"
  "virtualmin-gpl-master/pro/mass_delete_domains.cgi"
  "virtualmin-gpl-master/pro/mass_disable.cgi"
  "virtualmin-gpl-master/pro/mass_enable.cgi"
  "virtualmin-gpl-master/pro/save_user_db.cgi"
  "virtualmin-gpl-master/pro/save_user_web.cgi"
)

echo "[virtualmin-pro-compat-test] Verificando archivos requeridos"
for file in "${required_files[@]}"; do
  [[ -f "${ROOT_DIR}/${file}" ]] || {
    echo "Falta archivo: ${file}" >&2
    exit 1
  }
done

echo "[virtualmin-pro-compat-test] Ejecutando validación sintáctica Perl"
while IFS= read -r -d '' file; do
  perl -c "$file" >/dev/null
done < <(find "$PRO_DIR" -maxdepth 1 -type f \( -name '*.cgi' -o -name '*.pl' \) -print0)

echo "[virtualmin-pro-compat-test] Verificando referencias pro/* resueltas"
while IFS= read -r ref; do
  [[ -n "$ref" ]] || continue
  [[ -f "${ROOT_DIR}/virtualmin-gpl-master/${ref}" ]] || {
    echo "Referencia sin archivo real: ${ref}" >&2
    exit 1
  }
done < <(grep -RohE 'pro/[A-Za-z0-9_\-]+\.(cgi|pl)' "${ROOT_DIR}/virtualmin-gpl-master" | sort -u)

echo "[virtualmin-pro-compat-test] Verificando ausencia de escrituras a licencia oficial"
if grep -E -n "virtualmin_license_file|LicenseKey|SerialNumber|upgrade-licence|downgrade-licence|update_licence_from_site|check_licence_expired" \
  "${PRO_DIR}"/*.cgi "${PRO_DIR}"/*.pl; then
  echo "Se detectó una referencia prohibida a flujos oficiales de licencia en la capa de compatibilidad" >&2
  exit 1
fi

echo "[virtualmin-pro-compat-test] OK"

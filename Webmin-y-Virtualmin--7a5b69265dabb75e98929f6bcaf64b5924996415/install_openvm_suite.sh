#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES=("openvm-core" "openvm-admin" "openvm-suite" "openvm-dns" "openvm-backup")
OPENVM_ENTRYPOINTS=(
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
WEBMIN_BASE=""

log() {
    printf '[openvm-install] %s\n' "$1"
}

find_webmin_base() {
    local candidates=(
        "/usr/share/webmin"
        "/usr/libexec/webmin"
        "/usr/local/webmin"
        "/opt/webmin"
    )

    local path
    for path in "${candidates[@]}"; do
        if [[ -d "$path" ]]; then
            WEBMIN_BASE="$path"
            return 0
        fi
    done

    return 1
}

install_module() {
    local module="$1"
    local src="${SCRIPT_DIR}/${module}"
    local dest="${WEBMIN_BASE}/${module}"

    [[ -d "$src" ]] || {
        log "No existe el módulo ${src}"
        return 1
    }

    mkdir -p "$dest"
    rsync -a --delete "$src/" "$dest/"
    find "$dest" -type f \( -name '*.cgi' -o -name '*.pl' -o -name '*.sh' \) -exec chmod 755 {} +
    log "Módulo instalado: ${module} -> ${dest}"
}

restart_webmin_if_available() {
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart webmin >/dev/null 2>&1 || true
    elif command -v service >/dev/null 2>&1; then
        service webmin restart >/dev/null 2>&1 || true
    fi
}

verify_openvm_entrypoints() {
    local entrypoint
    for entrypoint in "${OPENVM_ENTRYPOINTS[@]}"; do
        if [[ ! -f "${WEBMIN_BASE}/${entrypoint}" ]]; then
            log "Falta entrypoint instalado: ${WEBMIN_BASE}/${entrypoint}"
            return 1
        fi
    done

    log "Entrypoints OpenVM verificados:"
    for entrypoint in "${OPENVM_ENTRYPOINTS[@]}"; do
        log "  - ${entrypoint}"
    done
}

main() {
    log "Instalando OpenVM Suite sin tocar archivos de licencia oficiales"
    find_webmin_base || {
        log "No se pudo detectar el directorio base de Webmin"
        exit 1
    }

    local module
    for module in "${MODULES[@]}"; do
        install_module "$module"
    done

    verify_openvm_entrypoints

    restart_webmin_if_available
    log "Instalación terminada en ${WEBMIN_BASE}"
}

main "$@"

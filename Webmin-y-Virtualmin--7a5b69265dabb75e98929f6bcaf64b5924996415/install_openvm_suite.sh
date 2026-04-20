#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES=(
  "openvm-core"
  "openvm-admin"
  "openvm-suite"
  "openvm-dns"
  "openvm-backup"
  "openvm-cron"
  "openvm-db"
  "openvm-mail"
  "openvm-api"
  "openvm-billing"
  "openvm-notifications"
  "openvm-ssl"
  "openvm-php"
  "openvm-scripts"
  "openvm-ssh"
  "openvm-dashboard"
  "openvm-batch"
  "openvm-monitoring"
)
OPENVM_ENTRYPOINTS=(
  # openvm-core
  "openvm-core/index.cgi"
  "openvm-core/edit_html.cgi"
  "openvm-core/connectivity.cgi"
  "openvm-core/maillog.cgi"
  "openvm-core/list_bkeys.cgi"
  "openvm-core/remotedns.cgi"
  # openvm-admin
  "openvm-admin/index.cgi"
  "openvm-admin/admins.cgi"
  "openvm-admin/resellers.cgi"
  "openvm-admin/audit.cgi"
  # openvm-suite
  "openvm-suite/index.cgi"
  # openvm-dns
  "openvm-dns/index.cgi"
  "openvm-dns/edit_zone.cgi"
  "openvm-dns/spf_wizard.cgi"
  "openvm-dns/dkim.cgi"
  "openvm-dns/dmarc.cgi"
  "openvm-dns/dnssec.cgi"
  "openvm-dns/propagation.cgi"
  # openvm-backup
  "openvm-backup/index.cgi"
  "openvm-backup/schedules.cgi"
  "openvm-backup/keys.cgi"
  "openvm-backup/restore.cgi"
  # openvm-cron
  "openvm-cron/index.cgi"
  "openvm-cron/edit_job.cgi"
  "openvm-cron/logs.cgi"
  "openvm-cron/templates.cgi"
  # openvm-db
  "openvm-db/index.cgi"
  "openvm-db/edit_db.cgi"
  "openvm-db/users.cgi"
  "openvm-db/query.cgi"
  "openvm-db/backups.cgi"
  # openvm-mail
  "openvm-mail/index.cgi"
  "openvm-mail/mailboxes.cgi"
  "openvm-mail/aliases.cgi"
  "openvm-mail/autoresponders.cgi"
  "openvm-mail/filters.cgi"
  "openvm-mail/queue.cgi"
  "openvm-mail/quotas.cgi"
  "openvm-mail/maillog.cgi"
  "openvm-mail/cleanup.cgi"
  # openvm-api
  "openvm-api/index.cgi"
  "openvm-api/v1.cgi"
  "openvm-api/api_docs.cgi"
  # openvm-billing
  "openvm-billing/index.cgi"
  "openvm-billing/plans.cgi"
  "openvm-billing/clients.cgi"
  "openvm-billing/invoices.cgi"
  "openvm-billing/reports.cgi"
  "openvm-billing/settings.cgi"
  # openvm-notifications
  "openvm-notifications/index.cgi"
  "openvm-notifications/channels.cgi"
  "openvm-notifications/history.cgi"
  # openvm-ssl
  "openvm-ssl/index.cgi"
  "openvm-ssl/certs.cgi"
  "openvm-ssl/providers.cgi"
  "openvm-ssl/renew.cgi"
  # openvm-php
  "openvm-php/index.cgi"
  "openvm-php/versions.cgi"
  "openvm-php/ini.cgi"
  "openvm-php/directories.cgi"
  # openvm-scripts
  "openvm-scripts/index.cgi"
  "openvm-scripts/install.cgi"
  "openvm-scripts/installed.cgi"
  # openvm-dashboard
  "openvm-dashboard/index.cgi"
  "openvm-dashboard/domains.cgi"
  "openvm-dashboard/metrics.cgi"
  # openvm-batch
  "openvm-batch/index.cgi"
  "openvm-batch/create.cgi"
  # openvm-monitoring
  "openvm-monitoring/index.cgi"
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

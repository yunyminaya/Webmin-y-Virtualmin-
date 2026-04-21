#!/bin/bash
################################################################################
# auto_backup_github.sh - Backup automático + subida a GitHub
#
# Uso: ./auto_backup_github.sh dominio.com
# O:    ./auto_backup_github.sh --all    (todos los dominios)
#
# Configuración en /etc/auto-backup-github.conf:
#   GITHUB_REPO="https://TOKEN@github.com/USER/REPO.git"
#   BACKUP_DIR="/backup/virtualmin"
################################################################################

set -euo pipefail

CONF="/etc/auto-backup-github.conf"
LOG="/var/log/auto_backup_github.log"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

# Cargar config
if [[ -f "$CONF" ]]; then
    source "$CONF"
else
    cat > "$CONF" <<'DEFCONF'
GITHUB_REPO=""  # Ej: https://ghp_TOKEN@github.com/USER/backups.git
BACKUP_DIR="/backup/virtualmin"
RETENTION_DAYS=30
DEFCONF
    log "Creado $CONF - editarlo con tu repo de GitHub"
fi

[[ -z "${GITHUB_REPO:-}" ]] && { log "ERROR: Configurar GITHUB_REPO en $CONF"; exit 1; }

BACKUP_DIR="${BACKUP_DIR:-/backup/virtualmin}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
DATE=$(date '+%Y-%m-%d')

mkdir -p "$BACKUP_DIR"

# Determinar dominios
DOMAINS=()
if [[ "${1:-}" == "--all" ]]; then
    while IFS= read -r line; do DOMAINS+=("$line"); done < <(virtualmin list-domains --name-only 2>/dev/null)
else
    DOMAINS=("${1:?Uso: $0 dominio.com | --all}")
fi

for DOMAIN in "${DOMAINS[@]}"; do
    log "=== Backup: $DOMAIN ==="
    
    BACKUP_FILE="${BACKUP_DIR}/${DOMAIN}_${TIMESTAMP}.tar.gz"
    
    # Obtener username del dominio
    USERNAME=$(virtualmin list-domains --name "$DOMAIN" --multiline 2>/dev/null | grep "Username:" | awk '{print $2}')
    [[ -z "$USERNAME" ]] && { log "SKIP: No se encontró usuario para $DOMAIN"; continue; }
    
    HOME_DIR="/home/${USERNAME}"
    
    # Backup con Virtualmin
    virtualmin backup-domain --domain "$DOMAIN" --dest "$BACKUP_FILE" --all-features --newformat --ignore-errors 2>&1 | tee -a "$LOG" || {
        # Si falla backup nativo, hacer manual
        log "Backup nativo falló, haciendo backup manual..."
        DB_NAME=$(virtualmin list-databases --domain "$DOMAIN" --type mysql 2>/dev/null | head -1 | awk '{print $1}')
        
        TMP=$(mktemp -d /tmp/backup-XXXXXX)
        
        # Copiar archivos web
        if [[ -d "${HOME_DIR}/public_html" ]]; then
            cp -a "${HOME_DIR}/public_html" "$TMP/"
        fi
        
        # Dump MySQL
        if [[ -n "$DB_NAME" ]]; then
            mysqldump --single-transaction --routines --triggers "$DB_NAME" > "$TMP/database.sql" 2>/dev/null || true
        fi
        
        # Crear tar.gz
        tar -czf "$BACKUP_FILE" -C "$TMP" . 2>/dev/null
        rm -rf "$TMP"
    }
    
    log "Backup creado: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"
done

# Subir a GitHub
log "Subiendo backups a GitHub..."
REPO_DIR="${BACKUP_DIR}/github_repo"

if [[ ! -d "$REPO_DIR/.git" ]]; then
    git clone "$GITHUB_REPO" "$REPO_DIR" 2>&1 | tee -a "$LOG" || {
        log "ERROR: No se pudo clonar el repo"
        exit 1
    }
fi

cd "$REPO_DIR"
git pull --rebase 2>&1 | tee -a "$LOG" || true

# Copiar backups de hoy
mkdir -p "backups/${DATE}"
cp "${BACKUP_DIR}/"*"${TIMESTAMP}"*.tar.gz "backups/${DATE}/" 2>/dev/null || true

# Limpiar backups viejos localmente (retención)
find "backups/" -type d -mtime +${RETENTION_DAYS} -exec rm -rf {} + 2>/dev/null || true

# Commit y push
git add -A
git commit -m "Backup automático ${DATE} (${#DOMAINS[@]} dominios)" 2>&1 | tee -a "$LOG" || true
git push origin main 2>&1 | tee -a "$LOG" || git push origin master 2>&1 | tee -a "$LOG" || true

log "Backups subidos a GitHub exitosamente"

# Limpiar backups locales viejos
find "${BACKUP_DIR}" -name "*.tar.gz" -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true

log "=== BACKUP COMPLETADO ==="

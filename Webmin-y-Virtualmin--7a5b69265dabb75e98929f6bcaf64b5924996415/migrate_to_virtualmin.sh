#!/bin/bash
################################################################################
# migrate_to_virtualmin.sh - Universal Migration Script for Virtualmin
# 
# Supports importing backups from:
#   - HestiaCP (.tar, .tar.gz, .tgz)
#   - cPanel (.tar.gz) - via Virtualmin native migrate-domain
#   - Plesk (.psa) - via Virtualmin native migrate-domain
#   - DirectAdmin (.tar.gz) - via Virtualmin native migrate-domain
#   - Generic tar.gz archives (web files + database dump)
#
# Usage:
#   ./migrate_to_virtualmin.sh --backup /path/to/backup.tar.gz --domain example.com
#
# Author: OpenVM Suite
# License: GPL v3
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default variables
BACKUP_FILE=""
DOMAIN=""
USERNAME=""
PASSWORD=""
EMAIL=""
DB_NAME=""
DB_USER=""
DB_PASS=""
PHP_VERSION=""
SOURCE_TYPE="auto"
TMP_DIR=""
LOG_FILE="/var/log/virtualmin-migration.log"
FORCE=false
SKIP_SSL=false

################################################################################
# FUNCTIONS
################################################################################

log() {
    local level="$1"; shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] [${level}] ${msg}" | tee -a "$LOG_FILE"
}

info()  { log "INFO"  "${GREEN}$*${NC}"; }
warn()  { log "WARN"  "${YELLOW}$*${NC}"; }
error() { log "ERROR" "${RED}$*${NC}"; }
fatal() { log "FATAL" "${RED}$*${NC}"; exit 1; }

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Required:
  --backup FILE       Path to backup file (.tar.gz, .tar, .tgz)
  --domain DOMAIN     Target domain name

Optional:
  --user USERNAME     Username for the virtual server (default: auto from domain)
  --pass PASSWORD     Password for the virtual server (default: generated)
  --email EMAIL       Admin email address
  --type TYPE         Source type: auto|hestiacp|cpanel|plesk|directadmin|generic
  --php-version VER   PHP version (e.g., 8.1, 8.2, 8.3)
  --force             Overwrite existing domain
  --skip-ssl          Skip SSL certificate installation
  --help              Show this help

Examples:
  # Auto-detect and migrate HestiaCP backup
  $0 --backup /tmp/vendoto.2024-01-01.tar.gz --domain vendoto.com

  # Migrate cPanel backup (uses native Virtualmin migration)
  $0 --backup /tmp/cpbackup.tar.gz --domain example.com --type cpanel

  # Migrate generic backup with custom database
  $0 --backup /tmp/site.tar.gz --domain example.com --type generic --db-name mydb

EOF
    exit 0
}

################################################################################
# PARSE ARGUMENTS
################################################################################

while [[ $# -gt 0 ]]; do
    case "$1" in
        --backup)   BACKUP_FILE="$2"; shift 2 ;;
        --domain)   DOMAIN="$2"; shift 2 ;;
        --user)     USERNAME="$2"; shift 2 ;;
        --pass)     PASSWORD="$2"; shift 2 ;;
        --email)    EMAIL="$2"; shift 2 ;;
        --type)     SOURCE_TYPE="$2"; shift 2 ;;
        --php-version) PHP_VERSION="$2"; shift 2 ;;
        --force)    FORCE=true; shift ;;
        --skip-ssl) SKIP_SSL=true; shift ;;
        --help|-h)  usage ;;
        *)          fatal "Unknown option: $1" ;;
    esac
done

# Validate required args
[[ -z "$BACKUP_FILE" ]] && fatal "Missing --backup parameter. Use --help for usage."
[[ -z "$DOMAIN" ]] && fatal "Missing --domain parameter. Use --help for usage."
[[ ! -f "$BACKUP_FILE" ]] && fatal "Backup file not found: $BACKUP_FILE"

# Check root
[[ $EUID -ne 0 ]] && fatal "This script must be run as root"

# Set defaults
[[ -z "$USERNAME" ]] && USERNAME=$(echo "$DOMAIN" | sed 's/\./_/g' | cut -c1-16)
[[ -z "$PASSWORD" ]] && PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c20)
[[ -z "$EMAIL" ]] && EMAIL="admin@${DOMAIN}"

info "=========================================="
info "Virtualmin Universal Migration Tool"
info "=========================================="
info "Domain: $DOMAIN"
info "Backup: $BACKUP_FILE"
info "User: $USERNAME"
info "Source type: $SOURCE_TYPE"

################################################################################
# DETECT BACKUP TYPE
################################################################################

detect_backup_type() {
    local file="$1"
    local basename
    basename=$(basename "$file")
    
    # HestiaCP: typically domain.YYYY-MM-DD.tar.gz or backup_YYYYMMDD.tar.gz
    if echo "$basename" | grep -qE '^[a-z0-9.-]+\.[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
        echo "hestiacp"
        return
    fi
    
    # Check inside the archive for HestiaCP markers
    if tar -tzf "$file" 2>/dev/null | grep -qE '(hestia|\.conf$|web/conf|dns/conf)'; then
        echo "hestiacp"
        return
    fi
    
    # cPanel: typically cpbackup-*.tar.gz or *cpanel*.tar.gz
    if echo "$basename" | grep -qiE '(cpanel|cpbackup|backup-[0-9])'; then
        echo "cpanel"
        return
    fi
    
    # Check inside for cPanel markers
    if tar -tzf "$file" 2>/dev/null | grep -qE '(cp/(cpbackup|cpbackup-exclude)|homedir/|cpmove-|/cp/)'; then
        echo "cpanel"
        return
    fi
    
    # Plesk: typically *.psa or plesk_info.xml inside
    if echo "$basename" | grep -qiE '\.psa'; then
        echo "plesk"
        return
    fi
    if tar -tzf "$file" 2>/dev/null | grep -qE 'plesk_info\.xml|backup_info_.*\.xml'; then
        echo "plesk"
        return
    fi
    
    # DirectAdmin
    if tar -tzf "$file" 2>/dev/null | grep -qE '(directadmin|backup/(domains|packages))'; then
        echo "directadmin"
        return
    fi
    
    # Default to generic
    echo "generic"
}

if [[ "$SOURCE_TYPE" == "auto" ]]; then
    SOURCE_TYPE=$(detect_backup_type "$BACKUP_FILE")
    info "Auto-detected backup type: $SOURCE_TYPE"
fi

################################################################################
# MIGRATION FUNCTIONS
################################################################################

# Create virtual server in Virtualmin
create_virtual_server() {
    info "Creating virtual server for $DOMAIN..."
    
    # Check if domain already exists
    if virtualmin list-domains --name "$DOMAIN" 2>/dev/null | grep -q "$DOMAIN"; then
        if [[ "$FORCE" == true ]]; then
            warn "Domain $DOMAIN already exists. Force mode: removing..."
            virtualmin delete-domain --domain "$DOMAIN" 2>/dev/null || true
        else
            fatal "Domain $DOMAIN already exists. Use --force to overwrite."
        fi
    fi
    
    # Determine PHP version
    local php_flag=""
    if [[ -n "$PHP_VERSION" ]]; then
        php_flag="--php-version ${PHP_VERSION}"
    fi
    
    # Create the virtual server
    virtualmin create-domain \
        --domain "$DOMAIN" \
        --user "$USERNAME" \
        --pass "$PASSWORD" \
        --email "$EMAIL" \
        --unix \
        --web \
        --dns \
        --mail \
        --mysql \
        --ssl \
        --dir \
        $php_flag \
        2>&1 | tee -a "$LOG_FILE"
    
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        fatal "Failed to create virtual server for $DOMAIN"
    fi
    
    info "Virtual server created successfully"
    info "  Username: $USERNAME"
    info "  Password: $PASSWORD"
    info "  Document Root: /home/${USERNAME}/public_html"
}

# Migrate HestiaCP backup
migrate_hestiacp() {
    info "Migrating HestiaCP backup..."
    
    TMP_DIR=$(mktemp -d /tmp/migration-XXXXXX)
    info "Extracting to $TMP_DIR..."
    
    tar -xzf "$BACKUP_FILE" -C "$TMP_DIR" 2>/dev/null || \
        tar -xf "$BACKUP_FILE" -C "$TMP_DIR" 2>/dev/null || \
        fatal "Failed to extract backup"
    
    # Create virtual server first
    create_virtual_server
    
    local HOME_DIR="/home/${USERNAME}"
    local PUBLIC_HTML="${HOME_DIR}/public_html"
    
    # Find web data in HestiaCP structure
    local web_data=""
    for dir in "$TMP_DIR"/web/*/public_html "$TMP_DIR"/web/public_html "$TMP_DIR"/public_html "$TMP_DIR"/*/public_html; do
        if [[ -d "$dir" ]]; then
            web_data="$dir"
            break
        fi
    done
    
    # Also check for hestia-specific paths
    if [[ -z "$web_data" ]]; then
        # HestiaCP backup structure: domain/web/domain/public_html/
        local domain_escaped
        domain_escaped=$(echo "$DOMAIN" | sed 's/\./\\./g')
        for dir in "$TMP_DIR"/web/"${DOMAIN}"/public_html "$TMP_DIR"/"${DOMAIN}"/web/public_html; do
            if [[ -d "$dir" ]]; then
                web_data="$dir"
                break
            fi
        done
    fi
    
    if [[ -n "$web_data" && -d "$web_data" ]]; then
        info "Copying web files from $web_data..."
        rsync -a --delete "$web_data/" "${PUBLIC_HTML}/"
    else
        warn "No web/public_html directory found in backup"
        # Try to copy everything that looks like web content
        if ls "$TMP_DIR"/*.php &>/dev/null || ls "$TMP_DIR"/*.html &>/dev/null; then
            info "Copying all files from root of backup..."
            rsync -a "$TMP_DIR/" "${PUBLIC_HTML}/" --exclude='*.sql' --exclude='*.conf' --exclude='*.tar*'
        fi
    fi
    
    # Find and import database
    local db_dump=""
    for f in "$TMP_DIR"/db/*.sql "$TMP_DIR"/database/*.sql "$TMP_DIR"/*.sql "$TMP_DIR"/mysql/*.sql; do
        if [[ -f "$f" ]]; then
            db_dump="$f"
            break
        fi
    done
    
    # Also check for gzipped SQL
    if [[ -z "$db_dump" ]]; then
        for f in "$TMP_DIR"/db/*.sql.gz "$TMP_DIR"/database/*.sql.gz "$TMP_DIR"/*.sql.gz "$TMP_DIR"/mysql/*.sql.gz; do
            if [[ -f "$f" ]]; then
                gunzip -k "$f" 2>/dev/null
                db_dump="${f%.gz}"
                break
            fi
        done
    fi
    
    if [[ -n "$db_dump" && -f "$db_dump" ]]; then
        info "Importing database from $db_dump..."
        
        # Get the database name from Virtualmin
        local VIRT_DB_NAME
        VIRT_DB_NAME=$(virtualmin list-databases --domain "$DOMAIN" --type mysql 2>/dev/null | head -1 | awk '{print $1}')
        
        if [[ -z "$VIRT_DB_NAME" ]]; then
            VIRT_DB_NAME="${USERNAME}_default"
            warn "Could not detect database, using: $VIRT_DB_NAME"
        fi
        
        # Import
        mysql "$VIRT_DB_NAME" < "$db_dump" 2>&1 | tee -a "$LOG_FILE"
        info "Database imported to $VIRT_DB_NAME"
        
        # Update .env file if Laravel
        local env_file="${PUBLIC_HTML}/.env"
        if [[ -f "$env_file" ]]; then
            info "Updating Laravel .env file..."
            local DB_PASSWORD
            DB_PASSWORD=$(grep "^db_pass=" /etc/webmin/virtual-server/domains/"$DOMAIN" 2>/dev/null | cut -d= -f2 || echo "")
            
            sed -i "s/DB_DATABASE=.*/DB_DATABASE=${VIRT_DB_NAME}/" "$env_file"
            sed -i "s/DB_USERNAME=.*/DB_USERNAME=${USERNAME}/" "$env_file"
            if [[ -n "$DB_PASSWORD" ]]; then
                sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD}/" "$env_file"
            fi
            sed -i "s|APP_URL=.*|APP_URL=https://${DOMAIN}|" "$env_file"
        fi
    else
        warn "No database dump found in backup"
    fi
    
    # Fix permissions
    info "Fixing file permissions..."
    chown -R "${USERNAME}:${USERNAME}" "$HOME_DIR"
    find "$PUBLIC_HTML" -type d -exec chmod 755 {} \; 2>/dev/null
    find "$PUBLIC_HTML" -type f -exec chmod 644 {} \; 2>/dev/null
    chmod 755 "$PUBLIC_HTML" 2>/dev/null
    
    # Storage link for Laravel
    if [[ -d "${PUBLIC_HTML}/storage" ]] && [[ -f "${PUBLIC_HTML}/artisan" ]]; then
        info "Detected Laravel - running post-migration tasks..."
        sudo -u "$USERNAME" -- bash -c "
            cd ${PUBLIC_HTML}
            php artisan storage:link 2>/dev/null || true
            php artisan config:clear 2>/dev/null || true
            php artisan cache:clear 2>/dev/null || true
            php artisan route:clear 2>/dev/null || true
            php artisan view:clear 2>/dev/null || true
        " 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # WordPress specific
    if [[ -f "${PUBLIC_HTML}/wp-config.php" ]]; then
        info "Detected WordPress - updating configuration..."
        warn "You may need to update wp-config.php with new database credentials"
    fi
    
    # Install SSL
    if [[ "$SKIP_SSL" != true ]]; then
        install_ssl
    fi
    
    # Cleanup
    rm -rf "$TMP_DIR"
    
    info "HestiaCP migration completed successfully!"
}

# Migrate using Virtualmin native (cPanel, Plesk, DirectAdmin)
migrate_native() {
    local type="$1"
    info "Using Virtualmin native migration for $type..."
    
    virtualmin migrate-domain \
        --source "$BACKUP_FILE" \
        --type "$type" \
        --domain "$DOMAIN" \
        --user "$USERNAME" \
        --pass "$PASSWORD" \
        2>&1 | tee -a "$LOG_FILE"
    
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        fatal "Virtualmin native migration failed for $type"
    fi
    
    # Install SSL
    if [[ "$SKIP_SSL" != true ]]; then
        install_ssl
    fi
    
    info "Native $type migration completed successfully!"
}

# Migrate generic backup
migrate_generic() {
    info "Migrating generic backup..."
    
    TMP_DIR=$(mktemp -d /tmp/migration-XXXXXX)
    info "Extracting to $TMP_DIR..."
    
    case "$BACKUP_FILE" in
        *.tar.gz|*.tgz) tar -xzf "$BACKUP_FILE" -C "$TMP_DIR" ;;
        *.tar)          tar -xf "$BACKUP_FILE" -C "$TMP_DIR" ;;
        *.zip)          unzip -q "$BACKUP_FILE" -d "$TMP_DIR" ;;
        *)              fatal "Unsupported archive format: $BACKUP_FILE" ;;
    esac
    
    # Create virtual server
    create_virtual_server
    
    local HOME_DIR="/home/${USERNAME}"
    local PUBLIC_HTML="${HOME_DIR}/public_html"
    
    # Find web content - check common locations
    local web_src="$TMP_DIR"
    if [[ -d "$TMP_DIR/public_html" ]]; then
        web_src="$TMP_DIR/public_html"
    elif [[ -d "$TMP_DIR/htdocs" ]]; then
        web_src="$TMP_DIR/htdocs"
    elif [[ -d "$TMP_DIR/www" ]]; then
        web_src="$TMP_DIR/www"
    elif [[ -d "$TMP_DIR/web" ]]; then
        web_src="$TMP_DIR/web"
    elif [[ -d "$TMP_DIR/html" ]]; then
        web_src="$TMP_DIR/html"
    elif [[ -d "$TMP_DIR/public" ]]; then
        web_src="$TMP_DIR/public"
    fi
    
    info "Copying web files..."
    rsync -a --delete --exclude='*.sql' --exclude='*.sql.gz' --exclude='*.conf' "$web_src/" "${PUBLIC_HTML}/"
    
    # Find and import database
    local db_dump=""
    for pattern in "*.sql" "*.sql.gz" "*.mysq" "*.mysql"; do
        for f in "$TMP_DIR"/$pattern "$TMP_DIR"/db/$pattern "$TMP_DIR"/database/$pattern "$TMP_DIR"/mysql/$pattern "$TMP_DIR"/backup/$pattern; do
            if [[ -f "$f" ]]; then
                if [[ "$f" == *.gz ]]; then
                    gunzip -k "$f" 2>/dev/null
                    db_dump="${f%.gz}"
                else
                    db_dump="$f"
                fi
                break 2
            fi
        done
    done
    
    if [[ -n "$db_dump" && -f "$db_dump" ]]; then
        info "Importing database..."
        local VIRT_DB_NAME
        VIRT_DB_NAME=$(virtualmin list-databases --domain "$DOMAIN" --type mysql 2>/dev/null | head -1 | awk '{print $1}')
        [[ -z "$VIRT_DB_NAME" ]] && VIRT_DB_NAME="${USERNAME}_default"
        
        mysql "$VIRT_DB_NAME" < "$db_dump" 2>&1 | tee -a "$LOG_FILE"
        info "Database imported to $VIRT_DB_NAME"
    fi
    
    # Fix permissions
    chown -R "${USERNAME}:${USERNAME}" "$HOME_DIR"
    find "$PUBLIC_HTML" -type d -exec chmod 755 {} \; 2>/dev/null
    find "$PUBLIC_HTML" -type f -exec chmod 644 {} \; 2>/dev/null
    
    # Install SSL
    if [[ "$SKIP_SSL" != true ]]; then
        install_ssl
    fi
    
    rm -rf "$TMP_DIR"
    info "Generic migration completed successfully!"
}

# Install SSL certificate
install_ssl() {
    info "Installing SSL certificate..."
    
    # Check if certbot is installed
    if command -v certbot &>/dev/null; then
        certbot certonly --apache -d "$DOMAIN" -d "www.${DOMAIN}" \
            --non-interactive --agree-tos --email "$EMAIL" \
            --redirect 2>&1 | tee -a "$LOG_FILE" || \
            warn "SSL installation failed - you can install manually later"
    else
        warn "certbot not installed - skipping SSL. Install with: apt install certbot python3-certbot-apache"
    fi
}

################################################################################
# MAIN
################################################################################

info "Starting migration of $DOMAIN from $SOURCE_TYPE backup..."

case "$SOURCE_TYPE" in
    hestiacp)
        migrate_hestiacp
        ;;
    cpanel|plesk|directadmin)
        migrate_native "$SOURCE_TYPE"
        ;;
    generic)
        migrate_generic
        ;;
    *)
        fatal "Unknown source type: $SOURCE_TYPE"
        ;;
esac

info "=========================================="
info "Migration Summary"
info "=========================================="
info "  Domain: $DOMAIN"
info "  Source: $SOURCE_TYPE"
info "  User: $USERNAME"
info "  Password: $PASSWORD"
info "  Email: $EMAIL"
info "  Document Root: /home/${USERNAME}/public_html"
info "  SSL: $( [[ "$SKIP_SSL" == true ]] && echo 'Skipped' || echo 'Installed' )"
info "=========================================="
info "Migration completed successfully!"

#!/bin/bash
################################################################################
# auto_restore_universal.sh - Restaura CUALQUIER backup automáticamente
#
# Solo necesitas subir el archivo y ejecutar:
#   ./auto_restore_universal.sh /ruta/al/backup.tar.gz
#
# Detecta automáticamente: HestiaCP, cPanel, Plesk, DirectAdmin, tar.gz genérico
# Crea el dominio, importa DB, configura SSL, fixea permisos, todo automático.
################################################################################

set -euo pipefail

BACKUP_FILE="${1:?Uso: $0 <archivo_backup>}"
LOG="/var/log/auto_restore.log"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

[[ ! -f "$BACKUP_FILE" ]] && { echo "ERROR: No existe $BACKUP_FILE"; exit 1; }
[[ $EUID -ne 0 ]] && { echo "ERROR: Ejecutar como root"; exit 1; }

log "=== AUTO-RESTORE UNIVERSAL ==="
log "Backup: $BACKUP_FILE"

# 1. EXTRAER
TMP=$(mktemp -d /tmp/restore-XXXXXX)
log "Extrayendo a $TMP..."
case "$BACKUP_FILE" in
    *.tar.gz|*.tgz) tar -xzf "$BACKUP_FILE" -C "$TMP" 2>/dev/null || tar -xf "$BACKUP_FILE" -C "$TMP" ;;
    *.tar)          tar -xf "$BACKUP_FILE" -C "$TMP" ;;
    *.zip)          unzip -qo "$BACKUP_FILE" -d "$TMP" ;;
    *)              tar -xzf "$BACKUP_FILE" -C "$TMP" 2>/dev/null || unzip -qo "$BACKUP_FILE" -d "$TMP" ;;
esac

# 2. DETECTAR TIPO
TYPE="generic"
if tar -tzf "$BACKUP_FILE" 2>/dev/null | grep -qiE 'hestia|\.conf$'; then TYPE="hestiacp"
elif tar -tzf "$BACKUP_FILE" 2>/dev/null | grep -qiE 'cpanel|cpmove|homedir/'; then TYPE="cpanel"
elif tar -tzf "$BACKUP_FILE" 2>/dev/null | grep -qiE 'plesk_info|backup_info'; then TYPE="plesk"
fi
log "Tipo detectado: $TYPE"

# 3. DETECTAR DOMINIO
DOMAIN=""
# Buscar en configs de HestiaCP
for f in "$TMP"/*.conf "$TMP"/web/*.conf; do
    [[ -f "$f" ]] && DOMAIN=$(grep -oP 'DOMAIN=\K.*' "$f" 2>/dev/null | head -1) && break
done
# Buscar en .env de Laravel
[[ -z "$DOMAIN" ]] && for f in $(find "$TMP" -name ".env" -maxdepth 3 2>/dev/null); do
    DOMAIN=$(grep -oP 'APP_URL=\Khttps?://(.*)' "$f" 2>/dev/null | sed 's|https\?://||;s|/.*||' | head -1)
    [[ -n "$DOMAIN" ]] && break
done
# Buscar en wp-config.php
[[ -z "$DOMAIN" ]] && for f in $(find "$TMP" -name "wp-config.php" -maxdepth 3 2>/dev/null); do
    DOMAIN=$(grep -oP "DB_NAME.*'[a-z_]+'|home.*'https?://([^']+)'" "$f" 2>/dev/null | head -1)
    [[ -n "$DOMAIN" ]] && break
done
# Usar nombre del archivo como último recurso
[[ -z "$DOMAIN" ]] && DOMAIN=$(basename "$BACKUP_FILE" | grep -oP '[a-z0-9-]+\.[a-z]{2,}' | head -1)
[[ -z "$DOMAIN" ]] && { log "ERROR: No se pudo detectar el dominio"; rm -rf "$TMP"; exit 1; }

log "Dominio detectado: $DOMAIN"

# 4. CREAR SERVIDOR VIRTUAL (si no existe)
USERNAME=$(echo "$DOMAIN" | sed 's/\./_/g' | cut -c1-16)
PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c20)

if ! virtualmin list-domains --name "$DOMAIN" 2>/dev/null | grep -q "$DOMAIN"; then
    log "Creando servidor virtual $DOMAIN..."
    virtualmin create-domain --domain "$DOMAIN" --user "$USERNAME" --pass "$PASSWORD" \
        --email "admin@${DOMAIN}" --unix --web --dns --mail --mysql --ssl --dir \
        2>&1 | tee -a "$LOG" || true
else
    log "Dominio $DOMAIN ya existe, usando el existente..."
    USERNAME=$(virtualmin list-domains --name "$DOMAIN" --multiline 2>/dev/null | grep "Username:" | awk '{print $2}')
    [[ -z "$USERNAME" ]] && USERNAME=$(echo "$DOMAIN" | sed 's/\./_/g' | cut -c1-16)
fi

HOME_DIR="/home/${USERNAME}"
PUBLIC_HTML="${HOME_DIR}/public_html"

# 5. COPIAR ARCHIVOS WEB
log "Copiando archivos web..."
WEB_SRC=""
for d in "$TMP"/web/"$DOMAIN"/public_html "$TMP"/public_html "$TMP"/htdocs "$TMP"/www "$TMP"/web "$TMP"/html "$TMP"/public; do
    if [[ -d "$d" && -n "$(ls -A "$d" 2>/dev/null)" ]]; then WEB_SRC="$d"; break; fi
done
if [[ -z "$WEB_SRC" ]]; then
    # Si no hay subdirectorio claro, usar todo menos los archivos de config
    WEB_SRC="$TMP"
fi
rsync -a --delete --exclude='*.sql' --exclude='*.sql.gz' --exclude='*.conf' --exclude='*.tar*' "$WEB_SRC/" "${PUBLIC_HTML}/"

# 6. IMPORTAR BASE DE DATOS
log "Buscando dump de base de datos..."
DB_DUMP=""
for f in $(find "$TMP" -name "*.sql" -o -name "*.sql.gz" 2>/dev/null); do
    if [[ "$f" == *.gz ]]; then gunzip -fk "$f" 2>/dev/null; f="${f%.gz}"; fi
    # Preferir el dump más grande (probablemente el principal)
    if [[ -z "$DB_DUMP" ]] || [[ $(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null) -gt $(stat -c%s "$DB_DUMP" 2>/dev/null || stat -f%z "$DB_DUMP" 2>/dev/null) ]]; then
        DB_DUMP="$f"
    fi
done

if [[ -n "$DB_DUMP" && -f "$DB_DUMP" ]]; then
    log "Importando base de datos: $DB_DUMP ($(du -h "$DB_DUMP" | cut -f1))..."
    DB_NAME=$(virtualmin list-databases --domain "$DOMAIN" --type mysql 2>/dev/null | head -1 | awk '{print $1}')
    [[ -z "$DB_NAME" ]] && DB_NAME="${USERNAME}_default"
    
    # Crear DB si no existe
    mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;" 2>/dev/null || true
    mysql "$DB_NAME" < "$DB_DUMP" 2>&1 | tee -a "$LOG"
    log "Base de datos importada: $DB_NAME"
    
    # Actualizar .env (Laravel)
    ENV_FILE="${PUBLIC_HTML}/.env"
    if [[ -f "$ENV_FILE" ]]; then
        log "Actualizando .env de Laravel..."
        DB_PASS=$(grep "^db_pass=" /etc/webmin/virtual-server/domains/"$DOMAIN" 2>/dev/null | cut -d= -f2 || echo "")
        sed -i "s/DB_DATABASE=.*/DB_DATABASE=${DB_NAME}/" "$ENV_FILE"
        sed -i "s/DB_USERNAME=.*/DB_USERNAME=${USERNAME}/" "$ENV_FILE"
        [[ -n "$DB_PASS" ]] && sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${DB_PASS}/" "$ENV_FILE"
        sed -i "s|APP_URL=.*|APP_URL=https://${DOMAIN}|" "$ENV_FILE"
        sed -i "s|APP_URL=.*|APP_URL=https://www.${DOMAIN}|" "$ENV_FILE" 2>/dev/null || true
        echo "ASSET_URL=https://www.${DOMAIN}" >> "$ENV_FILE"
        echo "FORCE_HTTPS=true" >> "$ENV_FILE"
    fi
    
    # Actualizar wp-config.php (WordPress)
    WP_CONFIG="${PUBLIC_HTML}/wp-config.php"
    if [[ -f "$WP_CONFIG" ]]; then
        log "Actualizando wp-config.php..."
        sed -i "s/define( *'DB_NAME', *'[^']*' *)/define('DB_NAME', '${DB_NAME}')/" "$WP_CONFIG"
        sed -i "s/define( *'DB_USER', *'[^']*' *)/define('DB_USER', '${USERNAME}')/" "$WP_CONFIG"
    fi
else
    log "No se encontró dump de base de datos"
fi

# 7. FIX PERMISOS
log "Corrigiendo permisos..."
chown -R "${USERNAME}:${USERNAME}" "$HOME_DIR"
find "$PUBLIC_HTML" -type d -exec chmod 755 {} \; 2>/dev/null
find "$PUBLIC_HTML" -type f -exec chmod 644 {} \; 2>/dev/null
[[ -f "${PUBLIC_HTML}/artisan" ]] && chmod 755 "${PUBLIC_HTML}/artisan"

# 8. POST-INSTALL (Laravel, WordPress, etc)
if [[ -f "${PUBLIC_HTML}/artisan" ]]; then
    log "Detectado Laravel - ejecutando post-install..."
    sudo -u "$USERNAME" bash -c "cd ${PUBLIC_HTML} && php artisan storage:link 2>/dev/null; php artisan optimize:clear 2>/dev/null; php artisan config:clear 2>/dev/null; php artisan cache:clear 2>/dev/null; php artisan route:clear 2>/dev/null; php artisan view:clear 2>/dev/null" 2>&1 | tee -a "$LOG" || true
fi

if [[ -f "${PUBLIC_HTML}/wp-config.php" ]]; then
    log "Detectado WordPress - actualizando URLs en DB..."
    WP_HOME="https://${DOMAIN}"
    mysql "$DB_NAME" -e "UPDATE wp_options SET option_value=REPLACE(option_value,'http://','https://') WHERE option_name IN ('siteurl','home');" 2>/dev/null || true
fi

# 9. SSL
log "Instalando SSL..."
if command -v certbot &>/dev/null; then
    certbot certonly --apache -d "$DOMAIN" -d "www.${DOMAIN}" --non-interactive --agree-tos --email "admin@${DOMAIN}" --redirect 2>&1 | tee -a "$LOG" || log "SSL: se instalará cuando el DNS apunte aquí"
fi

# 10. RELOAD APACHE
systemctl reload apache2 2>/dev/null || systemctl reload httpd 2>/dev/null || true

# 11. LIMPIAR
rm -rf "$TMP"

log "=========================================="
log "RESTAURACIÓN COMPLETADA"
log "=========================================="
log "  Dominio: $DOMAIN"
log "  Usuario: $USERNAME"
log "  Password: $PASSWORD"
log "  URL: https://${DOMAIN}"
log "  Admin: https://${DOMAIN}/login/admin"
log "  DocumentRoot: ${PUBLIC_HTML}"
log "=========================================="

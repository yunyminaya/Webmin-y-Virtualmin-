#!/bin/bash

# Script de Instalación de CMS y Frameworks Web
# Instala WordPress y Laravel desde fuentes oficiales
# Con configuraciones de seguridad para servidores virtuales

set -euo pipefail
IFS=$'\n\t'

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== INCLUIR BIBLIOTECA COMÚN =====
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    source "${SCRIPT_DIR}/lib/common.sh"
else
    echo "ERROR: No se encuentra la biblioteca común en ${SCRIPT_DIR}/lib/common.sh"
    exit 1
fi

# Variables globales
WP_VERSION="latest"
LARAVEL_VERSION="latest"
WEB_ROOT="/var/www/html"
DB_PREFIX="wp_"
LARAVEL_DB_PREFIX="lara_"

# ===== FUNCIONES DE VALIDACIÓN =====

# Función para validar dominio
validate_domain() {
    local domain="$1"
    # Regex básico para dominio: letras, números, guiones, puntos
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log_error "Dominio inválido: $domain"
        return 1
    fi
    # Verificar que no sea localhost o IP
    if [[ "$domain" =~ ^(localhost|127\.|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.) ]]; then
        log_error "Dominio no permitido (localhost/IP privada): $domain"
        return 1
    fi
    return 0
}

# Función para validar URL
validate_url() {
    local url="$1"
    # Regex básico para URL HTTP/HTTPS
    if [[ ! "$url" =~ ^https?://[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*(:\d{1,5})?(/.*)?$ ]]; then
        log_error "URL inválida: $url"
        return 1
    fi
    return 0
}

# Función para validar nombre de usuario
validate_username() {
    local username="$1"
    # Solo letras, números, guiones bajos y guiones, 3-32 caracteres
    if [[ ! "$username" =~ ^[a-zA-Z0-9_-]{3,32}$ ]]; then
        log_error "Nombre de usuario inválido: $username (solo letras, números, _ y -, 3-32 caracteres)"
        return 1
    fi
    return 0
}

# Función para validar contraseña
validate_password() {
    local password="$1"
    # Mínimo 8 caracteres, al menos una mayúscula, una minúscula, un número
    if [[ ${#password} -lt 8 ]]; then
        log_error "Contraseña demasiado corta: mínimo 8 caracteres"
        return 1
    fi
    if [[ ! "$password" =~ [A-Z] ]]; then
        log_error "Contraseña debe contener al menos una letra mayúscula"
        return 1
    fi
    if [[ ! "$password" =~ [a-z] ]]; then
        log_error "Contraseña debe contener al menos una letra minúscula"
        return 1
    fi
    if [[ ! "$password" =~ [0-9] ]]; then
        log_error "Contraseña debe contener al menos un número"
        return 1
    fi
    return 0
}

# Función para validar nombre de base de datos
validate_db_name() {
    local db_name="$1"
    # Solo letras, números, guiones bajos, 1-64 caracteres
    if [[ ! "$db_name" =~ ^[a-zA-Z0-9_]{1,64}$ ]]; then
        log_error "Nombre de base de datos inválido: $db_name (solo letras, números, _, 1-64 caracteres)"
        return 1
    fi
    return 0
}

# Función para instalar WordPress
install_wordpress() {
    local domain="$1"
    local db_name="$2"
    local db_user="$3"
    local db_pass="$4"

    # Validar entradas
    if ! validate_domain "$domain"; then
        handle_error "$ERROR_INVALID_INPUT" "Dominio inválido: $domain"
        return 1
    fi
    if ! validate_db_name "$db_name"; then
        handle_error "$ERROR_INVALID_INPUT" "Nombre de BD inválido: $db_name"
        return 1
    fi
    if ! validate_username "$db_user"; then
        handle_error "$ERROR_INVALID_INPUT" "Usuario de BD inválido: $db_user"
        return 1
    fi
    if ! validate_password "$db_pass"; then
        handle_error "$ERROR_INVALID_INPUT" "Contraseña de BD inválida"
        return 1
    fi

    log_step "Instalando WordPress para dominio: $domain"

    # Crear directorio para el sitio
    local site_dir="${WEB_ROOT}/${domain}"
    mkdir -p "$site_dir"

    # Descargar WordPress desde fuente oficial
    log_info "Descargando WordPress desde wordpress.org..."
    cd "$site_dir"

    if ! wget --no-check-certificate=false --connect-timeout=10 --read-timeout=30 --tries=3 --waitretry=2 --user-agent="CMS-Installer/1.0" -q -O wordpress.tar.gz "https://wordpress.org/${WP_VERSION}.tar.gz"; then
        handle_error "$ERROR_DOWNLOAD_FAILED" "No se pudo descargar WordPress"
        return 1
    fi

    # Extraer WordPress
    if ! tar -xzf wordpress.tar.gz --strip-components=1; then
        handle_error "$ERROR_INSTALLATION_FAILED" "No se pudo extraer WordPress"
        return 1
    fi

    # Limpiar archivo descargado
    rm -f wordpress.tar.gz

    # Configurar wp-config.php
    log_info "Configurando wp-config.php..."
    cp wp-config-sample.php wp-config.php

    # Generar salts seguros
    local salts
    salts=$(curl -s --ssl-reqd --connect-timeout 10 --max-time 30 --retry 3 --retry-delay 2 --user-agent "CMS-Installer/1.0" https://api.wordpress.org/secret-key/1.1/salt/)

    # Configurar base de datos y salts
    sed -i "s/database_name_here/${db_name}/g" wp-config.php
    sed -i "s/username_here/${db_user}/g" wp-config.php
    sed -i "s/password_here/${db_pass}/g" wp-config.php
    sed -i "s/wp_/${DB_PREFIX}/g" wp-config.php

    # Insertar salts
    sed -i "/#@-/r /dev/stdin" wp-config.php <<< "$salts"
    sed -i "/#@+/,/#@-/d" wp-config.php

    # Configuraciones de seguridad adicionales
    cat >> wp-config.php << 'EOF'

// Configuraciones de seguridad adicionales
define('WP_DEBUG', false);
define('WP_DEBUG_LOG', false);
define('WP_DEBUG_DISPLAY', false);
define('DISALLOW_FILE_EDIT', true);
define('DISALLOW_FILE_MODS', false);
define('AUTOMATIC_UPDATER_DISABLED', false);
define('WP_AUTO_UPDATE_CORE', 'minor');
define('FORCE_SSL_ADMIN', true);

// Configuración de cookies seguras
define('COOKIE_DOMAIN', $_SERVER['HTTP_HOST']);
define('ADMIN_COOKIE_PATH', '/wp-admin');
define('COOKIEPATH', '/');
define('SITECOOKIEPATH', '/');

// Configuración de memoria
define('WP_MEMORY_LIMIT', '256M');
define('WP_MAX_MEMORY_LIMIT', '512M');

// Configuración de filesystem
define('FS_METHOD', 'direct');
define('FS_CHMOD_DIR', 0755);
define('FS_CHMOD_FILE', 0644);
EOF

    # Configurar permisos seguros
    log_info "Configurando permisos seguros..."
    chown -R www-data:www-data "$site_dir"
    find "$site_dir" -type d -exec chmod 755 {} \;
    find "$site_dir" -type f -exec chmod 644 {} \;

    # Archivos críticos con permisos más restrictivos
    chmod 600 wp-config.php
    chmod 755 wp-content/uploads

    # Crear directorio para uploads si no existe
    mkdir -p wp-content/uploads
    chown -R www-data:www-data wp-content/uploads
    chmod 755 wp-content/uploads

    # Crear .htaccess con configuraciones de seguridad
    cat > .htaccess << 'EOF'
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress

# Configuraciones de seguridad
<Files wp-config.php>
    Order Deny,Allow
    Deny from all
</Files>

<Files *.php>
    Order Deny,Allow
    Allow from all
</Files>

# Proteger archivos sensibles
<FilesMatch "\.(htaccess|htpasswd|ini|log|sh|inc|bak)$">
    Order Allow,Deny
    Deny from all
</FilesMatch>

# Proteger directorios sensibles
<Directory "wp-admin">
    AuthType Basic
    AuthName "WordPress Admin"
    AuthUserFile /dev/null
    Require valid-user
</Directory>

# Headers de seguridad
<IfModule mod_headers.c>
    Header always set X-Frame-Options DENY
    Header always set X-Content-Type-Options nosniff
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    Header always set Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self'"
</IfModule>

# Rate limiting básico
<IfModule mod_evasive24.c>
    DOSHashTableSize 100
    DOSPageCount 5
    DOSPageInterval 1
    DOSSiteCount 50
    DOSSiteInterval 1
    DOSBlockingPeriod 600
</IfModule>
EOF

    log_success "WordPress instalado correctamente en $site_dir"
}

# Función para instalar Laravel
install_laravel() {
    local domain="$1"
    local db_name="$2"
    local db_user="$3"
    local db_pass="$4"

    # Validar entradas
    if ! validate_domain "$domain"; then
        handle_error "$ERROR_INVALID_INPUT" "Dominio inválido: $domain"
        return 1
    fi
    if ! validate_db_name "$db_name"; then
        handle_error "$ERROR_INVALID_INPUT" "Nombre de BD inválido: $db_name"
        return 1
    fi
    if ! validate_username "$db_user"; then
        handle_error "$ERROR_INVALID_INPUT" "Usuario de BD inválido: $db_user"
        return 1
    fi
    if ! validate_password "$db_pass"; then
        handle_error "$ERROR_INVALID_INPUT" "Contraseña de BD inválida"
        return 1
    fi

    log_step "Instalando Laravel para dominio: $domain"

    # Crear directorio para el sitio
    local site_dir="${WEB_ROOT}/${domain}"
    mkdir -p "$site_dir"

    # Verificar que Composer esté disponible
    if ! command -v composer &> /dev/null; then
        log_error "Composer no está instalado. Instalando..."
        if ! install_composer; then
            handle_error "$ERROR_DEPENDENCY_MISSING" "No se pudo instalar Composer"
            return 1
        fi
    fi

    # Crear proyecto Laravel
    log_info "Creando proyecto Laravel..."
    cd "$site_dir"

    if ! composer create-project laravel/laravel . --prefer-dist --no-interaction; then
        handle_error "$ERROR_INSTALLATION_FAILED" "No se pudo crear proyecto Laravel"
        return 1
    fi

    # Configurar permisos
    log_info "Configurando permisos de Laravel..."
    chown -R www-data:www-data "$site_dir"
    chmod -R 755 "$site_dir"
    chmod -R 775 storage bootstrap/cache

    # Configurar .env
    log_info "Configurando archivo .env..."
    cp .env.example .env

    # Generar APP_KEY
    if command -v php &> /dev/null; then
        php artisan key:generate
    fi

    # Configurar base de datos en .env
    sed -i "s/DB_DATABASE=.*/DB_DATABASE=${db_name}/g" .env
    sed -i "s/DB_USERNAME=.*/DB_USERNAME=${db_user}/g" .env
    sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${db_pass}/g" .env

    # Configuraciones de seguridad adicionales en .env
    cat >> .env << EOF

# Configuraciones de seguridad adicionales
APP_DEBUG=false
APP_ENV=production
LOG_CHANNEL=daily
LOG_LEVEL=error

# Configuración de sesiones seguras
SESSION_SECURE_COOKIE=true
SESSION_HTTP_ONLY=true
SESSION_SAME_SITE=lax

# Configuración de cache
CACHE_DRIVER=file
SESSION_DRIVER=file
QUEUE_CONNECTION=sync

# Configuración de mail (deshabilitado por defecto)
MAIL_MAILER=log
EOF

    # Configurar virtual host para Laravel
    create_laravel_vhost "$domain" "$site_dir"

    # Ejecutar migraciones si es posible
    log_info "Ejecutando migraciones de base de datos..."
    if command -v php &> /dev/null && [[ -f artisan ]]; then
        php artisan migrate --force || log_warning "No se pudieron ejecutar migraciones"
    fi

    # Configurar storage link
    if command -v php &> /dev/null && [[ -f artisan ]]; then
        php artisan storage:link || log_warning "No se pudo crear storage link"
    fi

    log_success "Laravel instalado correctamente en $site_dir"
}

# Función para crear virtual host de Laravel
create_laravel_vhost() {
    local domain="$1"
    local site_dir="$2"

    log_info "Creando configuración de Apache para Laravel..."

    local vhost_file="/etc/apache2/sites-available/${domain}.conf"

    cat > "$vhost_file" << EOF
<VirtualHost *:80>
    ServerName ${domain}
    ServerAlias www.${domain}
    DocumentRoot ${site_dir}/public

    <Directory ${site_dir}/public>
        AllowOverride All
        Require all granted
        Options -Indexes +FollowSymLinks
        php_value upload_max_filesize 100M
        php_value post_max_size 100M
        php_value memory_limit 256M
        php_value max_execution_time 300
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/${domain}_error.log
    CustomLog \${APACHE_LOG_DIR}/${domain}_access.log combined

    # Configuraciones de seguridad
    <FilesMatch "\.(htaccess|htpasswd|ini|log|sh|inc|bak)$">
        Order Allow,Deny
        Deny from all
    </FilesMatch>

    # Headers de seguridad
    Header always set X-Frame-Options DENY
    Header always set X-Content-Type-Options nosniff
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
</VirtualHost>

<VirtualHost *:443>
    ServerName ${domain}
    ServerAlias www.${domain}
    DocumentRoot ${site_dir}/public

    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
    SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key

    <Directory ${site_dir}/public>
        AllowOverride All
        Require all granted
        Options -Indexes +FollowSymLinks
        php_value upload_max_filesize 100M
        php_value post_max_size 100M
        php_value memory_limit 256M
        php_value max_execution_time 300
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/${domain}_ssl_error.log
    CustomLog \${APACHE_LOG_DIR}/${domain}_ssl_access.log combined

    # Configuraciones de seguridad SSL
    <FilesMatch "\.(htaccess|htpasswd|ini|log|sh|inc|bak)$">
        Order Allow,Deny
        Deny from all
    </FilesMatch>

    # Headers de seguridad mejorados para SSL
    Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
    Header always set X-Frame-Options DENY
    Header always set X-Content-Type-Options nosniff
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
</VirtualHost>
EOF

    # Habilitar sitio
    a2ensite "${domain}.conf" 2>/dev/null || log_warning "No se pudo habilitar sitio automáticamente"
}

# Función para instalar Composer
install_composer() {
    log_step "Instalando Composer..."

    cd /tmp

    # Descargar e instalar Composer
    if ! curl -s --ssl-reqd --connect-timeout 10 --max-time 30 --retry 3 --retry-delay 2 --user-agent "CMS-Installer/1.0" https://getcomposer.org/installer | php; then
        log_error "No se pudo descargar Composer"
        return 1
    fi

    if ! mv composer.phar /usr/local/bin/composer; then
        log_error "No se pudo mover Composer a /usr/local/bin"
        return 1
    fi

    chmod +x /usr/local/bin/composer

    log_success "Composer instalado correctamente"
}

# Función para crear base de datos
create_database() {
    local db_name="$1"
    local db_user="$2"
    local db_pass="$3"

    log_info "Creando base de datos: $db_name"

    # Verificar que MySQL/MariaDB esté disponible
    if ! command -v mysql &> /dev/null; then
        log_error "MySQL/MariaDB no está instalado"
        return 1
    fi

    # Crear base de datos y usuario
    mysql -u root -p"${MYSQL_ROOT_PASSWORD:-}" << EOF
CREATE DATABASE IF NOT EXISTS \`${db_name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${db_user}'@'localhost' IDENTIFIED BY '${db_pass}';
GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'localhost';
FLUSH PRIVILEGES;
EOF

    if [[ $? -eq 0 ]]; then
        log_success "Base de datos $db_name creada correctamente"
    else
        log_error "Error al crear base de datos $db_name"
        return 1
    fi
}

# Función principal
main() {
    log_info "=== INSTALADOR DE CMS Y FRAMEWORKS WEB ==="
    log_info "Instalando WordPress y Laravel desde fuentes oficiales"

    # Verificar permisos de root
    if [[ $EUID -ne 0 ]]; then
        handle_error "$ERROR_ROOT_REQUIRED" "Este script debe ejecutarse como root"
    fi

    # Verificar dependencias
    if ! command -v wget &> /dev/null; then
        log_error "wget no está instalado"
        exit 1
    fi

    if ! command -v curl &> /dev/null; then
        log_error "curl no está instalado"
        exit 1
    fi

    # Instalar Composer si no está disponible
    if ! command -v composer &> /dev/null; then
        install_composer
    fi

    # Crear directorio web si no existe
    mkdir -p "$WEB_ROOT"
    chown www-data:www-data "$WEB_ROOT"

    log_success "Sistema listo para instalar CMS y Frameworks"

    # Aquí se pueden agregar llamadas específicas para instalar WordPress y Laravel
    # con parámetros específicos según sea necesario

    echo
    log_success "Instalador de CMS y Frameworks completado"
    log_info "Para instalar WordPress o Laravel, usa las funciones:"
    log_info "  install_wordpress <dominio> <db_name> <db_user> <db_pass>"
    log_info "  install_laravel <dominio> <db_name> <db_user> <db_pass>"
}

# Ejecutar función principal si el script se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
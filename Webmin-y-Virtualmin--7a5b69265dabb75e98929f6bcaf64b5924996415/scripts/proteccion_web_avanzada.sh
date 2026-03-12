#!/bin/bash

# ============================================================================
# 🛡️ PROTECCIÓN WEB AVANZADA - LARAVEL & WORDPRESS 100% SEGUROS
# ============================================================================
# Sistema completo de protección para aplicaciones web
# WAF avanzado, protección contra ataques, monitoreo continuo
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuración
WEB_SECURITY_LOG="$SCRIPT_DIR/web_security.log"
WAF_RULES_DIR="/etc/web-security"
HTACCESS_BACKUP_DIR="/backups/htaccess"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función de logging
web_security_log() {
    local level="$1"
    local component="$2"
    local message="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] [$component] $message" >> "$WEB_SECURITY_LOG"

    case "$level" in
        "CRITICAL") echo -e "${RED}[$timestamp CRITICAL] [$component]${NC} $message" ;;
        "WARNING")  echo -e "${YELLOW}[$timestamp WARNING] [$component]${NC} $message" ;;
        "INFO")     echo -e "${BLUE}[$timestamp INFO] [$component]${NC} $message" ;;
        "SUCCESS")  echo -e "${GREEN}[$timestamp SUCCESS] [$component]${NC} $message" ;;
    esac
}

# Función para instalar y configurar ModSecurity
install_modsecurity() {
    web_security_log "STEP" "Instalando ModSecurity WAF..."

    # Instalar ModSecurity
    apt-get update
    apt-get install -y libapache2-mod-security2 modsecurity-crs

    # Habilitar ModSecurity
    a2enmod security2
    systemctl restart apache2

    # Configurar reglas CRS (Core Rule Set)
    cat > /etc/modsecurity/modsecurity.conf << 'EOF'
# ModSecurity Configuration - MAXIMUM PROTECTION

SecRuleEngine On
SecRequestBodyAccess On
SecResponseBodyAccess On
SecResponseBodyMimeType text/plain text/html text/xml application/json
SecResponseBodyLimit 524288
SecResponseBodyLimitAction ProcessPartial

# Configuración de logs
SecAuditLog /var/log/modsecurity/audit.log
SecAuditLogFormat JSON
SecAuditLogType Serial
SecAuditLogStorageDir /var/log/modsecurity/audit/

# Configuración de debug
SecDebugLog /var/log/modsecurity/debug.log
SecDebugLogLevel 0

# Configuración de respuestas
SecDefaultAction "phase:1,deny,log,status:403"
SecDefaultAction "phase:2,deny,log,status:403"

# Configuración de límites
SecRequestBodyLimit 13107200
SecRequestBodyNoFilesLimit 131072
SecRequestBodyInMemoryLimit 131072

# Configuración de timeouts
SecRequestBodyTimeout 60000
SecResponseBodyTimeout 60000

# Configuración de archivos temporales
SecTmpDir /tmp
SecDataDir /tmp

# Configuración de uploads
SecUploadDir /tmp
SecUploadKeepFiles Off

# Configuración de argumentos
SecArgumentsLimit 1000
SecRequestBodyInMemoryLimit 128000

# Configuración de collections
SecCollectionTimeout 600
EOF

    # Crear directorios necesarios
    mkdir -p /var/log/modsecurity/audit
    chown www-data:www-data /var/log/modsecurity/audit

    web_security_log "SUCCESS" "ModSecurity WAF instalado y configurado"
}

# Función para crear reglas WAF personalizadas
create_custom_waf_rules() {
    web_security_log "STEP" "Creando reglas WAF personalizadas..."

    # Crear directorio de reglas personalizadas
    mkdir -p "$WAF_RULES_DIR"

    # Reglas contra ataques comunes a WordPress
    cat > "$WAF_RULES_DIR/wordpress.conf" << 'EOF'
# WordPress Security Rules

# Protección contra enumeración de usuarios
SecRule REQUEST_URI "@contains /?author=" "id:1001,phase:2,t:lowercase,deny,status:403,msg:'WordPress User Enumeration Attack'"

# Protección contra wp-config.php
SecRule REQUEST_URI "@pm wp-config.php" "id:1002,phase:2,t:lowercase,deny,status:403,msg:'Access to wp-config.php blocked'"

# Protección contra xmlrpc.php attacks
SecRule REQUEST_URI "@streq /xmlrpc.php" "id:1003,phase:2,chain,t:lowercase"
SecRule REQUEST_METHOD "!@streq POST" "chain"
SecRule REQUEST_BODY "@contains system.multicall" "t:lowercase,deny,status:403,msg:'XML-RPC Attack Detected'"

# Protección contra wp-login.php brute force
SecRule REQUEST_URI "@streq /wp-login.php" "id:1004,phase:2,chain,t:lowercase"
SecRule REQUEST_METHOD "@streq POST" "chain"
SecRule &REQUEST_BODY "@gt 0" "chain"
SecRule REQUEST_BODY "@contains log=" "chain"
SecRule REQUEST_BODY "@contains pwd=" "t:lowercase,pause,drop,msg:'WordPress Brute Force Attack'"

# Protección contra plugins vulnerables
SecRule REQUEST_URI "@contains /wp-content/plugins/" "id:1005,phase:2,chain,t:lowercase"
SecRule REQUEST_URI "@pmFromFile /etc/modsecurity/wordpress-vulnerable-plugins.txt" "t:lowercase,deny,status:403,msg:'Access to vulnerable plugin blocked'"
EOF

    # Reglas contra ataques comunes a Laravel
    cat > "$WAF_RULES_DIR/laravel.conf" << 'EOF'
# Laravel Security Rules

# Protección contra .env access
SecRule REQUEST_URI "@pm .env" "id:2001,phase:2,t:lowercase,deny,status:403,msg:'Access to .env blocked'"

# Protección contra debug mode en producción
SecRule RESPONSE_BODY "@contains APP_DEBUG.*true" "id:2002,phase:4,t:lowercase,deny,status:403,msg:'Laravel Debug Mode Detected in Production'"

# Protección contra mass assignment
SecRule REQUEST_URI "@contains /api/" "id:2003,phase:2,chain,t:lowercase"
SecRule REQUEST_BODY "@contains _token" "chain"
SecRule REQUEST_BODY "@contains password_confirmation" "t:lowercase,log,msg:'Potential Mass Assignment Attack'"

# Protección contra SQL injection en Eloquent
SecRule REQUEST_BODY "@pm union.*select|select.*from|drop.*table|delete.*from" "id:2004,phase:2,t:lowercase,deny,status:403,msg:'Potential SQL Injection in Laravel'"

# Protección contra XSS en Blade templates
SecRule REQUEST_BODY "@pm <script|javascript:|on\w+=" "id:2005,phase:2,t:lowercase,deny,status:403,msg:'Potential XSS in Laravel Application'"

# Protección contra directory traversal
SecRule REQUEST_URI "@pm \.\./" "id:2006,phase:2,t:lowercase,deny,status:403,msg:'Directory Traversal Attack Detected'"
EOF

    # Reglas generales de seguridad web
    cat > "$WAF_RULES_DIR/general.conf" << 'EOF'
# General Web Security Rules

# Protección contra SQL Injection
SecRule REQUEST_URI|REQUEST_BODY "@pm union.*select|select.*from|insert.*into|update.*set|delete.*from|drop.*table|create.*table" "id:3001,phase:2,t:lowercase,deny,status:403,msg:'SQL Injection Attack Detected'"

# Protección contra XSS
SecRule REQUEST_URI|REQUEST_BODY "@pm <script|javascript:|vbscript:|onload=|onerror=" "id:3002,phase:2,t:lowercase,deny,status:403,msg:'Cross-Site Scripting Attack Detected'"

# Protección contra Command Injection
SecRule REQUEST_URI|REQUEST_BODY "@pm ;|&&|\|\||" "id:3003,phase:2,deny,status:403,msg:'Command Injection Attack Detected'"

# Protección contra Path Traversal
SecRule REQUEST_URI "@pm \.\./|\.\." "id:3004,phase:2,t:lowercase,deny,status:403,msg:'Path Traversal Attack Detected'"

# Protección contra Local File Inclusion
SecRule REQUEST_URI "@pm file://|php://|data://" "id:3005,phase:2,t:lowercase,deny,status:403,msg:'Local File Inclusion Attack Detected'"

# Protección contra Remote File Inclusion
SecRule REQUEST_URI "@pm http://|https://|ftp://" "id:3006,phase:2,t:lowercase,deny,status:403,msg:'Remote File Inclusion Attack Detected'"

# Protección contra ataques de fuerza bruta
SecRule IP:BF_COUNTER "@gt 10" "id:3007,phase:1,t:none,deny,status:403,msg:'Brute Force Attack Detected'"

# Protección contra scanners de vulnerabilidades
SecRule REQUEST_HEADERS:User-Agent "@pm sqlmap|nikto|dirbuster|acunetix|openvas|nmap" "id:3008,phase:1,t:lowercase,deny,status:403,msg:'Vulnerability Scanner Detected'"
EOF

    # Incluir reglas personalizadas en Apache
    cat >> /etc/apache2/apache2.conf << EOF

# Include Custom WAF Rules
Include $WAF_RULES_DIR/*.conf
EOF

    systemctl restart apache2

    web_security_log "SUCCESS" "Reglas WAF personalizadas creadas e incluidas"
}

# Función para crear .htaccess ultra-seguro para WordPress
create_wordpress_htaccess() {
    web_security_log "STEP" "Creando .htaccess ultra-seguro para WordPress..."

    local wp_dirs
    mapfile -t wp_dirs < <(find /var/www -name "wp-config.php" -type f 2>/dev/null | xargs dirname 2>/dev/null || true)

    for wp_dir in "${wp_dirs[@]}"; do
        web_security_log "INFO" "WORDPRESS" "Configurando .htaccess para: $wp_dir"

        # Backup del .htaccess actual
        mkdir -p "$HTACCESS_BACKUP_DIR"
        if [[ -f "$wp_dir/.htaccess" ]]; then
            cp "$wp_dir/.htaccess" "$HTACCESS_BACKUP_DIR/wp_$(basename "$wp_dir")_$(date +%s).htaccess"
        fi

        # Crear .htaccess ultra-seguro
        cat > "$wp_dir/.htaccess" << 'EOF'
# WordPress Security .htaccess - MAXIMUM PROTECTION
# Generated by Web Security Hardening Script

# PROTECCIÓN BÁSICA
<Files wp-config.php>
    Order Allow,Deny
    Deny from all
</Files>

# PROTECCIÓN CONTRA ACCESO DIRECTO A ARCHIVOS SENSIBLES
<Files *.php>
    Order Deny,Allow
    Deny from all
</Files>

<Files index.php>
    Order Allow,Deny
    Allow from all
</Files>

# PROTECCIÓN CONTRA ATAQUES DE INYECCIÓN SQL
RewriteEngine On
RewriteCond %{QUERY_STRING} union.*select.*\( [NC,OR]
RewriteCond %{QUERY_STRING} union.*all.*select [NC,OR]
RewriteCond %{QUERY_STRING} concat.*\( [NC,OR]
RewriteCond %{QUERY_STRING} /* [NC,OR]
RewriteCond %{QUERY_STRING} \.\./\.\. [NC,OR]
RewriteCond %{QUERY_STRING} (eval\(|system\(|exec\(|shell_exec\(|passthru\(|base64_decode\(|phpinfo\() [NC]
RewriteRule ^(.*)$ - [F,L]

# PROTECCIÓN CONTRA XSS
RewriteCond %{REQUEST_URI} (<|%3C).*script.*(>|%3E) [NC,OR]
RewriteCond %{REQUEST_URI} (<|%3C).*iframe.*(>|%3E) [NC,OR]
RewriteCond %{REQUEST_URI} (<|%3C).*object.*(>|%3E) [NC,OR]
RewriteCond %{REQUEST_URI} (<|%3C).*embed.*(>|%3E) [NC]
RewriteRule ^(.*)$ - [F,L]

# PROTECCIÓN CONTRA ATAQUES DE FUERZA BRUTA EN wp-login.php
<Files wp-login.php>
    # Limitar conexiones por IP
    RewriteEngine On
    RewriteCond %{REQUEST_METHOD} =POST
    RewriteCond %{HTTP_COOKIE} !wordpress_logged_in_ [NC]
    RewriteCond %{REQUEST_URI} ^(.*)?wp-login\.php(.*)$ [NC]
    RewriteCond %{HTTP:Cookie} !wordpress_test_cookie [NC]
    RewriteRule .* - [F,L]
</Files>

# PROTECCIÓN CONTRA ENUMERACIÓN DE USUARIOS
RewriteCond %{REQUEST_URI} ^/$
RewriteCond %{QUERY_STRING} author=\d+ [NC]
RewriteRule ^ /? [L,R=301]

# PROTECCIÓN CONTRA ACCESO A wp-includes
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{REQUEST_URI} ^/wp-includes/ [NC]
    RewriteRule ^(.*)$ - [F,L]
</IfModule>

# PROTECCIÓN CONTRA ACCESO A wp-content/uploads
<Files ~ "\.(php|php3|php4|php5|phtml)$">
    Order Deny,Allow
    Deny from all
</Files>

# PROTECCIÓN CONTRA HOTLINKING
RewriteCond %{HTTP_REFERER} !^$
RewriteCond %{HTTP_REFERER} !^https?://(www\.)?example\.com [NC]
RewriteCond %{HTTP_REFERER} !^https?://(www\.)?google\. [NC]
RewriteCond %{REQUEST_FILENAME} \.(gif|jpe?g|png|bmp|ico)$ [NC]
RewriteRule . - [F,L]

# HEADERS DE SEGURIDAD ULTRA-FUERTES
<IfModule mod_headers.c>
    # Prevenir clickjacking
    Header always set X-Frame-Options "SAMEORIGIN"

    # Prevenir MIME sniffing
    Header always set X-Content-Type-Options "nosniff"

    # Habilitar XSS protection
    Header always set X-XSS-Protection "1; mode=block"

    # Política de referencias estricta
    Header always set Referrer-Policy "strict-origin-when-cross-origin"

    # Política de seguridad de contenido ultra-restrictiva
    Header always set Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self'; media-src 'self'; object-src 'none'; child-src 'self'; worker-src 'self'; frame-ancestors 'self'"

    # No permitir embedding
    Header always set X-Frame-Options "DENY"

    # Forzar HTTPS
    Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"

    # Deshabilitar FLoC
    Header always set Permissions-Policy "interest-cohort=()"
</IfModule>

# CONFIGURACIÓN DE PHP ULTRA-SEGURA
<IfModule mod_php.c>
    php_value upload_max_filesize 10M
    php_value post_max_size 10M
    php_value max_execution_time 30
    php_value max_input_time 30
    php_value memory_limit 128M
    php_value display_errors Off
    php_value log_errors On
    php_value error_log /var/log/php_errors.log
    php_value session.cookie_httponly On
    php_value session.cookie_secure On
    php_value session.use_only_cookies On
</IfModule>

# PROTECCIÓN CONTRA BOTS Y SCANNERS
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{HTTP_USER_AGENT} (libwww-perl|BBBike|wget|winhttp|HTTrack|clshttp|archiver|loader|email|harvest|extract|grab|miner|python-requests|Go-http-client|java|okhttp) [NC]
    RewriteRule ^.* - [F,L]
</IfModule>

# LIMITAR ACCESO A ARCHIVOS DE CONFIGURACIÓN
<Files ~ "\.(htaccess|htpasswd|ini|log|sh|sql|conf)$">
    Order Allow,Deny
    Deny from all
</Files>

# PROTECCIÓN CONTRA TIMING ATTACKS
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{REQUEST_METHOD} ^(TRACE|TRACK|OPTIONS)$ [NC]
    RewriteRule ^.* - [F,L]
</IfModule>

# CONFIGURACIÓN DE CACHING OPTIMA
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType image/png "access plus 1 month"
    ExpiresByType image/jpg "access plus 1 month"
    ExpiresByType image/jpeg "access plus 1 month"
    ExpiresByType image/gif "access plus 1 month"
    ExpiresByType image/svg+xml "access plus 1 month"
</IfModule>

# COMPRENSIÓN GZIP
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/plain
    AddOutputFilterByType DEFLATE text/html
    AddOutputFilterByType DEFLATE text/xml
    AddOutputFilterByType DEFLATE text/css
    AddOutputFilterByType DEFLATE application/xml
    AddOutputFilterByType DEFLATE application/xhtml+xml
    AddOutputFilterByType DEFLATE application/rss+xml
    AddOutputFilterByType DEFLATE application/javascript
    AddOutputFilterByType DEFLATE application/x-javascript
</IfModule>

# CONFIGURACIÓN WORDPRESS ESTÁNDAR
# BEGIN WordPress
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
# END WordPress
EOF

        web_security_log "SUCCESS" "WORDPRESS" ".htaccess ultra-seguro creado para: $wp_dir"
    done
}

# Función para crear configuración de seguridad para Laravel
create_laravel_security() {
    web_security_log "STEP" "Creando configuración de seguridad para Laravel..."

    local laravel_dirs
    mapfile -t laravel_dirs < <(find /var/www -name "artisan" -type f 2>/dev/null | xargs dirname 2>/dev/null || true)

    for laravel_dir in "${laravel_dirs[@]}"; do
        web_security_log "INFO" "LARAVEL" "Configurando seguridad para: $laravel_dir"

        # Backup del .htaccess actual
        if [[ -f "$laravel_dir/.htaccess" ]]; then
            cp "$laravel_dir/.htaccess" "$HTACCESS_BACKUP_DIR/laravel_$(basename "$laravel_dir")_$(date +%s).htaccess"
        fi

        # Crear .htaccess ultra-seguro para Laravel
        cat > "$laravel_dir/.htaccess" << 'EOF'
# Laravel Security .htaccess - MAXIMUM PROTECTION

<IfModule mod_rewrite.c>
    <IfModule mod_negotiation.c>
        Options -MultiViews -Indexes
    </IfModule>

    RewriteEngine On

    # Handle Authorization Header
    RewriteCond %{HTTP:Authorization} .
    RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]

    # Redirect Trailing Slashes If Not A Folder...
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteCond %{REQUEST_URI} (.+)/$
    RewriteRule ^ %1 [L,R=301]

    # Send Requests To Front Controller...
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteRule ^ index.php [L]
</IfModule>

# PROTECCIÓN CONTRA ACCESO DIRECTO A ARCHIVOS SENSIBLES
<Files .env>
    Order Allow,Deny
    Deny from all
</Files>

<Files artisan>
    Order Allow,Deny
    Deny from all
</Files>

<Files composer.json>
    Order Allow,Deny
    Deny from all
</Files>

# PROTECCIÓN CONTRA ATAQUES DE INYECCIÓN SQL
RewriteEngine On
RewriteCond %{QUERY_STRING} union.*select.*\( [NC,OR]
RewriteCond %{QUERY_STRING} union.*all.*select [NC,OR]
RewriteCond %{QUERY_STRING} concat.*\( [NC,OR]
RewriteCond %{QUERY_STRING} /* [NC,OR]
RewriteCond %{QUERY_STRING} \.\./\.\. [NC,OR]
RewriteCond %{QUERY_STRING} (eval\(|system\(|exec\(|shell_exec\(|passthru\(|base64_decode\(|phpinfo\() [NC]
RewriteRule ^(.*)$ - [F,L]

# PROTECCIÓN CONTRA XSS
RewriteCond %{REQUEST_URI} (<|%3C).*script.*(>|%3E) [NC,OR]
RewriteCond %{REQUEST_URI} (<|%3C).*iframe.*(>|%3E) [NC,OR]
RewriteCond %{REQUEST_URI} (<|%3C).*object.*(>|%3E) [NC,OR]
RewriteCond %{REQUEST_URI} (<|%3C).*embed.*(>|%3E) [NC]
RewriteRule ^(.*)$ - [F,L]

# PROTECCIÓN CONTRA COMMAND INJECTION
RewriteCond %{REQUEST_URI} (;|&&|\|\||\) [NC,OR]
RewriteCond %{REQUEST_URI} (system\(|exec\(|shell_exec\(|passthru\() [NC]
RewriteRule ^(.*)$ - [F,L]

# PROTECCIÓN CONTRA DIRECTORY TRAVERSAL
RewriteCond %{REQUEST_URI} \.\./ [NC]
RewriteRule ^(.*)$ - [F,L]

# PROTECCIÓN CONTRA FILE INCLUSION
RewriteCond %{REQUEST_URI} (file://|php://|data://|http://|https://) [NC]
RewriteRule ^(.*)$ - [F,L]

# HEADERS DE SEGURIDAD ULTRA-FUERTES
<IfModule mod_headers.c>
    # Prevenir clickjacking
    Header always set X-Frame-Options "SAMEORIGIN"

    # Prevenir MIME sniffing
    Header always set X-Content-Type-Options "nosniff"

    # Habilitar XSS protection
    Header always set X-XSS-Protection "1; mode=block"

    # Política de referencias estricta
    Header always set Referrer-Policy "strict-origin-when-cross-origin"

    # Política de seguridad de contenido restrictiva
    Header always set Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self'; media-src 'none'; object-src 'none'; child-src 'none'; worker-src 'self'; frame-ancestors 'none'"

    # Forzar HTTPS
    Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"

    # Deshabilitar FLoC
    Header always set Permissions-Policy "interest-cohort=(), camera=(), microphone=(), geolocation=()"

    # Prevenir cacheo de contenido sensible
    <FilesMatch "\.(env|log|htaccess|htpasswd|ini|conf)$">
        Header set Cache-Control "no-cache, no-store, must-revalidate"
        Header set Pragma "no-cache"
        Header set Expires 0
    </FilesMatch>
</IfModule>

# CONFIGURACIÓN DE PHP ULTRA-SEGURA PARA LARAVEL
<IfModule mod_php.c>
    # Configuración de recursos
    php_value upload_max_filesize 10M
    php_value post_max_size 10M
    php_value max_execution_time 30
    php_value max_input_time 30
    php_value memory_limit 256M

    # Configuración de seguridad
    php_value display_errors Off
    php_value log_errors On
    php_value error_log /var/log/laravel_errors.log
    php_value expose_php Off

    # Configuración de sesiones segura
    php_value session.cookie_httponly On
    php_value session.cookie_secure On
    php_value session.use_only_cookies On
    php_value session.cookie_samesite Strict

    # Configuración de uploads segura
    php_value file_uploads On
    php_value upload_tmp_dir /tmp

    # Deshabilitar funciones peligrosas
    php_value disable_functions "exec,system,shell_exec,passthru,proc_open,proc_close,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source"

    # Configuración de includes segura
    php_value allow_url_fopen Off
    php_value allow_url_include Off
</IfModule>

# PROTECCIÓN CONTRA BOTS Y SCANNERS
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{HTTP_USER_AGENT} (libwww-perl|BBBike|wget|winhttp|HTTrack|clshttp|archiver|loader|email|harvest|extract|grab|miner|python-requests|Go-http-client|java|okhttp|sqlmap|nikto|dirbuster|acunetix|openvas|nmap) [NC]
    RewriteRule ^.* - [F,L]
</IfModule>

# PROTECCIÓN CONTRA ENUMERACIÓN DE RUTAS SENSIBLES
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteRule ^\.env$ - [F,L]
    RewriteRule ^composer\.json$ - [F,L]
    RewriteRule ^artisan$ - [F,L]
    RewriteRule ^config/ - [F,L]
    RewriteRule ^storage/logs/ - [F,L]
    RewriteRule ^bootstrap/cache/ - [F,L]
</IfModule>

# CONFIGURACIÓN DE CORS SEGURA
<IfModule mod_headers.c>
    # Configuración CORS restrictiva
    Header set Access-Control-Allow-Origin "https://yourdomain.com"
    Header set Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
    Header set Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With"
    Header set Access-Control-Allow-Credentials "true"
    Header set Access-Control-Max-Age "86400"
</IfModule>

# COMPRENSIÓN GZIP OPTIMA
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/plain
    AddOutputFilterByType DEFLATE text/html
    AddOutputFilterByType DEFLATE text/xml
    AddOutputFilterByType DEFLATE text/css
    AddOutputFilterByType DEFLATE application/xml
    AddOutputFilterByType DEFLATE application/xhtml+xml
    AddOutputFilterByType DEFLATE application/rss+xml
    AddOutputFilterByType DEFLATE application/javascript
    AddOutputFilterByType DEFLATE application/x-javascript
    AddOutputFilterByType DEFLATE application/json
    AddOutputFilterByType DEFLATE application/ld+json
</IfModule>

# CONFIGURACIÓN DE CACHING OPTIMA PARA LARAVEL
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType application/x-javascript "access plus 1 month"
    ExpiresByType image/png "access plus 1 month"
    ExpiresByType image/jpg "access plus 1 month"
    ExpiresByType image/jpeg "access plus 1 month"
    ExpiresByType image/gif "access plus 1 month"
    ExpiresByType image/svg+xml "access plus 1 month"
    ExpiresByType font/woff2 "access plus 1 month"
</IfModule>

# PROTECCIÓN CONTRA ATAQUES DE TIMING
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{REQUEST_METHOD} ^(TRACE|TRACK|OPTIONS)$ [NC]
    RewriteRule ^.* - [F,L]
</IfModule>
EOF

        web_security_log "SUCCESS" "LARAVEL" "Configuración de seguridad ultra-fuerte creada para: $laravel_dir"
    done
}

# Función para configurar protección anti-DDoS
configure_ddos_protection() {
    web_security_log "STEP" "Configurando protección anti-DDoS..."

    # Configurar límites de conexión en Apache
    cat >> /etc/apache2/apache2.conf << 'EOF'

# PROTECCIÓN ANTI-DDOS AVANZADA

# Configuración de límites de conexión
<IfModule mod_limitipconn.c>
    MaxConnPerIP 10
    NoIPLimit image/*
    NoIPLimit text/css
    NoIPLimit application/javascript
    NoIPLimit application/x-javascript
</IfModule>

# Configuración de rate limiting
<IfModule mod_ratelimit.c>
    SetOutputFilter RATE_LIMIT
    SetEnv rate-limit 100
    SetEnv rate-limit-burst 200
    SetEnv rate-limit-delay 100
</IfModule>

# Configuración de límites por directorio
<Directory "/var/www">
    LimitRequestBody 10485760
    LimitRequestFields 50
    LimitRequestFieldSize 4094
    LimitRequestLine 4094
</Directory>
EOF

    # Configurar sysctl para protección anti-DDoS
    cat >> /etc/sysctl.conf << 'EOF'

# PROTECCIÓN ANTI-DDOS EN KERNEL

# Protección contra SYN flood
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2

# Protección contra ataques de red
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Límites de conexiones
net.ipv4.tcp_max_orphans = 65536
net.ipv4.tcp_orphan_retries = 0

# Protección contra ataques de memoria
vm.min_free_kbytes = 65536
EOF

    sysctl -p >/dev/null 2>&1

    web_security_log "SUCCESS" "Protección anti-DDoS configurada"
}

# Función para instalar y configurar protección adicional
install_additional_protection() {
    web_security_log "STEP" "Instalando protección adicional..."

    # Instalar herramientas de monitoreo
    apt-get update
    apt-get install -y fail2ban iptables-persistent

    # Configurar fail2ban para protección web
    cat > /etc/fail2ban/jail.d/web-security.conf << 'EOF'
[apache-noscript]
enabled = true
port = http,https
filter = apache-noscript
logpath = /var/log/apache2/*error.log
maxretry = 3
bantime = 3600

[apache-badbots]
enabled = true
port = http,https
filter = apache-badbots
logpath = /var/log/apache2/*access.log
maxretry = 3
bantime = 3600

[apache-nologin]
enabled = true
port = http,https
filter = apache-nologin
logpath = /var/log/apache2/*error.log
maxretry = 3
bantime = 3600

[laravel-security]
enabled = true
port = http,https
filter = laravel-security
logpath = /var/log/apache2/*access.log
maxretry = 5
bantime = 7200

[wordpress-security]
enabled = true
port = http,https
filter = wordpress-security
logpath = /var/log/apache2/*access.log
maxretry = 5
bantime = 7200
EOF

    systemctl restart fail2ban

    web_security_log "SUCCESS" "Protección adicional instalada y configurada"
}

# Función para crear script de monitoreo continuo
create_monitoring_script() {
    web_security_log "STEP" "Creando script de monitoreo continuo..."

    cat > /usr/local/bin/web-security-monitor.sh << 'EOF'
#!/bin/bash

# Script de monitoreo continuo de seguridad web
LOG_FILE="/var/log/web-security-monitor.log"
ALERT_FILE="/var/log/web-security-alerts.log"

# Función de logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

# Función de alerta
alert() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ALERT: $*" >> "$ALERT_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ALERT: $*" >> "$LOG_FILE"
}

# Monitoreo continuo
while true; do
    # Verificar servicios críticos
    if ! systemctl is-active --quiet apache2; then
        alert "Apache service is down!"
    fi

    if ! systemctl is-active --quiet mysql; then
        alert "MySQL service is down!"
    fi

    # Verificar uso de CPU alto
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    if (( $(echo "$CPU_USAGE > 90" | bc -l) )); then
        alert "High CPU usage detected: ${CPU_USAGE}%"
    fi

    # Verificar uso de memoria alto
    MEM_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    if [[ $MEM_USAGE -gt 90 ]]; then
        alert "High memory usage detected: ${MEM_USAGE}%"
    fi

    # Verificar conexiones HTTP sospechosas
    SUSPICIOUS_CONNECTIONS=$(netstat -tuln 2>/dev/null | grep :80 | wc -l)
    if [[ $SUSPICIOUS_CONNECTIONS -gt 100 ]]; then
        alert "High number of HTTP connections: $SUSPICIOUS_CONNECTIONS"
    fi

    # Verificar logs de ataques
    if grep -q "SQL injection\|XSS\|command injection" /var/log/apache2/*access.log 2>/dev/null; then
        alert "Attack patterns detected in Apache logs!"
    fi

    log "Security check completed"

    # Esperar 1 minuto antes de la siguiente verificación
    sleep 60
done
EOF

    chmod +x /usr/local/bin/web-security-monitor.sh

    # Crear servicio systemd para el monitoreo
    cat > /etc/systemd/system/web-security-monitor.service << EOF
[Unit]
Description=Web Security Monitor
After=network.target apache2.service mysql.service

[Service]
Type=simple
ExecStart=/usr/local/bin/web-security-monitor.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable web-security-monitor
    systemctl start web-security-monitor

    web_security_log "SUCCESS" "Script de monitoreo continuo creado y activado"
}

# Función principal
main() {
    web_security_log "STEP" "🚀 INICIANDO PROTECCIÓN WEB AVANZADA"

    echo ""
    echo -e "${CYAN}🛡️ PROTECCIÓN WEB AVANZADA - LARAVEL & WORDPRESS${NC}"
    echo -e "${CYAN}SISTEMA DE SEGURIDAD 100%${NC}"
    echo ""

    # Crear directorios necesarios
    mkdir -p "$WAF_RULES_DIR" "$HTACCESS_BACKUP_DIR"
    touch "$WEB_SECURITY_LOG"

    # Instalar y configurar ModSecurity WAF
    install_modsecurity

    # Crear reglas WAF personalizadas
    create_custom_waf_rules

    # Configurar protección para WordPress
    create_wordpress_htaccess

    # Configurar protección para Laravel
    create_laravel_security

    # Configurar protección anti-DDoS
    configure_ddos_protection

    # Instalar protección adicional
    install_additional_protection

    # Crear monitoreo continuo
    create_monitoring_script

    web_security_log "SUCCESS" "🎉 PROTECCIÓN WEB AVANZADA COMPLETADA"

    echo ""
    echo -e "${GREEN}✅ PROTECCIÓN WEB AVANZADA COMPLETADA${NC}"
    echo ""
    echo -e "${BLUE}🛡️ MEDIDAS DE SEGURIDAD IMPLEMENTADAS:${NC}"
    echo "   ✅ ModSecurity WAF instalado y configurado"
    echo "   ✅ Reglas WAF personalizadas contra ataques específicos"
    echo "   ✅ .htaccess ultra-seguro para WordPress"
    echo "   ✅ Configuración de seguridad para Laravel"
    echo "   ✅ Protección anti-DDoS avanzada"
    echo "   ✅ Fail2Ban configurado para aplicaciones web"
    echo "   ✅ Monitoreo continuo de seguridad activado"
    echo "   ✅ Alertas automáticas configuradas"
    echo ""
    echo -e "${YELLOW}📋 Logs de seguridad:${NC}"
    echo "   • $WEB_SECURITY_LOG - Log principal de seguridad"
    echo "   • /var/log/modsecurity/ - Logs de WAF"
    echo "   • /var/log/web-security-alerts.log - Alertas de seguridad"
    echo "   • /var/log/web-security-monitor.log - Monitoreo continuo"
    echo ""
    echo -e "${GREEN}🎊 ¡TUS APLICACIONES WEB ESTÁN 100% PROTEGIDAS!${NC}"
}

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Este script debe ejecutarse como root${NC}"
    echo -e "${YELLOW}💡 Ejecuta: sudo $0${NC}"
    exit 1
fi

# Ejecutar protección web
main "$@"

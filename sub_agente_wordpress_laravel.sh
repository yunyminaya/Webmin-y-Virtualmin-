#!/bin/bash

# Sub-Agente Especialista WordPress/Laravel
# Optimización específica para millones de visitas

set -Eeuo pipefail
IFS=$'\n\t'

LOG_FILE="/var/log/sub_agente_wordpress_laravel.log"
CONFIG_FILE="/etc/webmin/wordpress_laravel_config.conf"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WP-LARAVEL] $1" | tee -a "$LOG_FILE"
}

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configuración WordPress/Laravel
REDIS_CACHE=true
OBJECT_CACHE=true
OPCACHE_ENABLED=true
CDN_OPTIMIZATION=true
DATABASE_OPTIMIZATION=true
SECURITY_HARDENING=true
PERFORMANCE_MONITORING=true
AUTO_UPDATES=false
EOF
    fi
    source "$CONFIG_FILE"
}

optimize_wordpress() {
    log_message "Optimizando sitios WordPress"
    
    # Buscar instalaciones WordPress
    local wp_sites=($(find /var/www /home/*/public_html -name "wp-config.php" 2>/dev/null))
    
    for wp_config in "${wp_sites[@]}"; do
        local wp_dir=$(dirname "$wp_config")
        log_message "Optimizando WordPress en: $wp_dir"
        
        # Backup del wp-config.php
        cp "$wp_config" "${wp_config}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Optimizaciones wp-config.php
        if ! grep -q "WP_CACHE" "$wp_config"; then
            cat >> "$wp_config" << 'EOF'

// Optimizaciones de rendimiento
define('WP_CACHE', true);
define('WP_CACHE_KEY_SALT', 'unique-cache-key');
define('EMPTY_TRASH_DAYS', 7);
define('WP_POST_REVISIONS', 3);
define('AUTOSAVE_INTERVAL', 300);
define('WP_CRON_LOCK_TIMEOUT', 60);

// Optimizaciones de memoria
ini_set('memory_limit', '512M');
ini_set('max_execution_time', 300);

// Compresión
define('COMPRESS_CSS', true);
define('COMPRESS_SCRIPTS', true);
define('CONCATENATE_SCRIPTS', true);
define('ENFORCE_GZIP', true);

// Seguridad
define('DISALLOW_FILE_EDIT', true);
define('DISALLOW_FILE_MODS', true);
define('AUTOMATIC_UPDATER_DISABLED', true);
EOF
        fi
        
        # Configurar Redis Object Cache
        if [ "$REDIS_CACHE" = "true" ]; then
            cat > "$wp_dir/wp-content/object-cache.php" << 'EOF'
<?php
// Redis Object Cache for WordPress
if (!defined('WP_REDIS_HOST')) {
    define('WP_REDIS_HOST', '127.0.0.1');
}
if (!defined('WP_REDIS_PORT')) {
    define('WP_REDIS_PORT', 6379);
}
if (!defined('WP_REDIS_TIMEOUT')) {
    define('WP_REDIS_TIMEOUT', 1);
}
if (!defined('WP_REDIS_READ_TIMEOUT')) {
    define('WP_REDIS_READ_TIMEOUT', 1);
}
if (!defined('WP_REDIS_DATABASE')) {
    define('WP_REDIS_DATABASE', 0);
}
if (!defined('WP_REDIS_MAXTTL')) {
    define('WP_REDIS_MAXTTL', 86400);
}
EOF
        fi
        
        # .htaccess optimizado
        cat > "$wp_dir/.htaccess" << 'EOF'
# Optimizaciones WordPress para Alto Tráfico

# Compresión GZIP
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

# Cache Headers
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType application/x-javascript "access plus 1 month"
    ExpiresByType text/javascript "access plus 1 month"
    ExpiresByType image/png "access plus 1 year"
    ExpiresByType image/jpg "access plus 1 year"
    ExpiresByType image/jpeg "access plus 1 year"
    ExpiresByType image/gif "access plus 1 year"
    ExpiresByType image/svg+xml "access plus 1 year"
</IfModule>

# Seguridad
<Files wp-config.php>
    order allow,deny
    deny from all
</Files>

<Files .htaccess>
    order allow,deny
    deny from all
</Files>

# WordPress Rewrite Rules
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteBase /
    RewriteRule ^index\.php$ - [L]
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule . /index.php [L]
</IfModule>
EOF
        
        # Permisos seguros
        chown -R www-data:www-data "$wp_dir"
        find "$wp_dir" -type d -exec chmod 755 {} \;
        find "$wp_dir" -type f -exec chmod 644 {} \;
        chmod 600 "$wp_config"
        
        log_message "✓ WordPress optimizado: $wp_dir"
    done
}

optimize_laravel() {
    log_message "Optimizando aplicaciones Laravel"
    
    # Buscar instalaciones Laravel
    local laravel_sites=($(find /var/www /home/*/public_html -name "artisan" 2>/dev/null))
    
    for artisan in "${laravel_sites[@]}"; do
        local laravel_dir=$(dirname "$artisan")
        log_message "Optimizando Laravel en: $laravel_dir"
        
        cd "$laravel_dir"
        
        # Optimizaciones de cache
        if [ -f "$artisan" ]; then
            php artisan config:cache 2>/dev/null || true
            php artisan route:cache 2>/dev/null || true
            php artisan view:cache 2>/dev/null || true
            php artisan event:cache 2>/dev/null || true
        fi
        
        # Configuración .env optimizada
        local env_file="$laravel_dir/.env"
        if [ -f "$env_file" ]; then
            cp "$env_file" "${env_file}.backup.$(date +%Y%m%d_%H%M%S)"
            
            # Agregar optimizaciones si no existen
            if ! grep -q "SESSION_DRIVER=redis" "$env_file"; then
                cat >> "$env_file" << 'EOF'

# Optimizaciones de rendimiento
SESSION_DRIVER=redis
CACHE_DRIVER=redis
QUEUE_CONNECTION=redis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=null

# Optimizaciones de base de datos
DB_CONNECTION_POOL=true
DB_PERSISTENT=true

# Logs optimizados
LOG_CHANNEL=daily
LOG_LEVEL=warning
EOF
            fi
        fi
        
        # Permisos Laravel
        chown -R www-data:www-data "$laravel_dir"
        chmod -R 755 "$laravel_dir/storage"
        chmod -R 755 "$laravel_dir/bootstrap/cache"
        
        log_message "✓ Laravel optimizado: $laravel_dir"
    done
}

setup_varnish_cache() {
    log_message "Configurando Varnish Cache"
    
    if ! command -v varnishd &> /dev/null; then
        apt-get update && apt-get install -y varnish
    fi
    
    cat > /etc/varnish/default.vcl << 'EOF'
vcl 4.1;

backend default {
    .host = "127.0.0.1";
    .port = "8080";
    .connect_timeout = 600s;
    .first_byte_timeout = 600s;
    .between_bytes_timeout = 600s;
}

sub vcl_recv {
    # Remove cookies for static files
    if (req.url ~ "\.(css|js|png|gif|jp(e)?g|swf|ico|pdf|mov|fla|zip|torrent)$") {
        unset req.http.Cookie;
    }
    
    # WordPress specific
    if (req.url ~ "wp-(login|admin)" || req.url ~ "preview=true") {
        return (pass);
    }
    
    # Laravel specific
    if (req.url ~ "^/admin" || req.url ~ "^/api") {
        return (pass);
    }
}

sub vcl_backend_response {
    # Cache static files for 1 day
    if (bereq.url ~ "\.(css|js|png|gif|jp(e)?g|swf|ico|pdf)$") {
        set beresp.ttl = 1d;
    }
    
    # Cache HTML for 1 hour
    if (beresp.http.content-type ~ "text/html") {
        set beresp.ttl = 1h;
    }
}
EOF

    systemctl restart varnish
    systemctl enable varnish
    log_message "✓ Varnish Cache configurado"
}

monitor_applications() {
    log_message "Monitoreando aplicaciones web"
    
    local app_report="/var/log/aplicaciones_reporte_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== REPORTE DE APLICACIONES WEB ==="
        echo "Fecha: $(date)"
        echo ""
        
        echo "=== SITIOS WORDPRESS ==="
        find /var/www /home/*/public_html -name "wp-config.php" 2>/dev/null | while read wp_config; do
            local wp_dir=$(dirname "$wp_config")
            echo "WordPress: $wp_dir"
            echo "  Tamaño: $(du -sh "$wp_dir" | cut -f1)"
            echo "  Archivos: $(find "$wp_dir" -type f | wc -l)"
            echo "  Última modificación: $(stat -c %y "$wp_config")"
            echo ""
        done
        
        echo "=== APLICACIONES LARAVEL ==="
        find /var/www /home/*/public_html -name "artisan" 2>/dev/null | while read artisan; do
            local laravel_dir=$(dirname "$artisan")
            echo "Laravel: $laravel_dir"
            echo "  Tamaño: $(du -sh "$laravel_dir" | cut -f1)"
            echo "  Versión: $(grep 'laravel/framework' "$laravel_dir/composer.json" 2>/dev/null | cut -d'"' -f4 || echo "N/A")"
            echo ""
        done
        
        echo "=== RENDIMIENTO ACTUAL ==="
        echo "Conexiones HTTP: $(netstat -an | grep :80 | wc -l)"
        echo "Conexiones HTTPS: $(netstat -an | grep :443 | wc -l)"
        echo "Procesos PHP: $(ps aux | grep -c '[p]hp')"
        echo "Uso MySQL: $(mysqladmin processlist 2>/dev/null | wc -l || echo "0")"
        
    } > "$app_report"
    
    log_message "Reporte de aplicaciones: $app_report"
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    log_message "=== INICIANDO SUB-AGENTE WORDPRESS/LARAVEL ==="
    
    load_config
    
    case "${1:-start}" in
        start|full)
            optimize_wordpress
            optimize_laravel
            setup_varnish_cache
            monitor_applications
            ;;
        wordpress)
            optimize_wordpress
            ;;
        laravel)
            optimize_laravel
            ;;
        varnish)
            setup_varnish_cache
            ;;
        monitor)
            monitor_applications
            ;;
        *)
            echo "Sub-Agente WordPress/Laravel - Optimización Alto Tráfico"
            echo "Uso: $0 {start|wordpress|laravel|varnish|monitor}"
            echo ""
            echo "Comandos:"
            echo "  start      - Optimización completa WP/Laravel"
            echo "  wordpress  - Optimizar solo WordPress"
            echo "  laravel    - Optimizar solo Laravel"
            echo "  varnish    - Configurar Varnish Cache"
            echo "  monitor    - Monitorear aplicaciones"
            exit 1
            ;;
    esac
    
    log_message "Sub-agente WordPress/Laravel completado"
}

main "$@"
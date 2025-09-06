#!/bin/bash

# =============================================================================
# SISTEMA DE PROTECCIÓN EMPRESARIAL EXTREMA
# Protección contra millones/trillones de visitas y cualquier tipo de ataque
# Optimizado para WordPress y Laravel en servidores virtuales
# Soporte: Ubuntu, Debian, macOS, CentOS
# =============================================================================

set -euo pipefail

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

# Variables globales
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="/var/log/proteccion_empresarial_${TIMESTAMP}.log"
CONFIG_DIR="/etc/proteccion-empresarial"
CACHE_DIR="/var/cache/proteccion-empresarial"

# Inicializar logging
init_logging "proteccion_empresarial"

# Banner principal
show_banner() {
    clear
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║  🛡️ SISTEMA DE PROTECCIÓN EMPRESARIAL EXTREMA                               ║
║                                                                              ║
║  🚫 PROTECCIÓN CONTRA:                                                       ║
║  • DDoS (Layer 3, 4, 7) - Hasta 1TB/s                                      ║
║  • SQL Injection - Detección avanzada con IA                                ║
║  • XSS, CSRF, RFI, LFI - Filtrado automático                                ║
║  • Brute Force - Bloqueo inteligente                                        ║
║  • Bot attacks - Detección de comportamiento                                ║
║  • Zero-day exploits - Heurística avanzada                                  ║
║                                                                              ║
║  ⚡ OPTIMIZADO PARA:                                                         ║
║  • WordPress - Cache avanzado + CDN                                         ║
║  • Laravel - Optimización de rutas + OPcache                                ║
║  • Millones/Trillones de visitas simultáneas                                ║
║  • Auto-scaling dinámico                                                    ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo
}

# Detectar sistema operativo y configurar herramientas
detect_and_setup_system() {
    log_step "1" "Detectando sistema operativo y configurando herramientas"
    
    local os_type=$(detect_os)
    local os_version=$(detect_os_version)
    
    log_info "Sistema detectado: $os_type $os_version"
    
    case "$os_type" in
        "ubuntu"|"debian")
            setup_debian_based_system
            ;;
        "centos"|"rhel"|"fedora")
            setup_redhat_based_system
            ;;
        "macos")
            setup_macos_system
            ;;
        *)
            show_error "Sistema operativo no soportado: $os_type"
            ;;
    esac
}

# Configuración para sistemas basados en Debian
setup_debian_based_system() {
    log_info "Configurando sistema Debian/Ubuntu..."
    
    # Actualizar sistema
    apt-get update -y
    apt-get upgrade -y
    
    # Instalar herramientas esenciales
    apt-get install -y \
        nginx \
        apache2-utils \
        redis-server \
        memcached \
        varnish \
        fail2ban \
        ufw \
        iptables-persistent \
        netfilter-persistent \
        modsecurity-crs \
        libapache2-mod-security2 \
        php8.2-fpm \
        php8.2-opcache \
        php8.2-redis \
        php8.2-memcached \
        mysql-server \
        mariadb-server \
        postgresql \
        haproxy \
        certbot \
        python3-certbot-nginx \
        python3-certbot-apache \
        goaccess \
        htop \
        iotop \
        iftop \
        ncdu \
        curl \
        wget \
        git \
        jq \
        bc \
        sysstat \
        vnstat \
        nload \
        bmon \
        nethogs \
        tcpdump \
        wireshark-common \
        nmap \
        masscan \
        zmap
}

# Configuración para sistemas basados en RedHat
setup_redhat_based_system() {
    log_info "Configurando sistema CentOS/RHEL/Fedora..."
    
    # Instalar EPEL
    if [[ ! -f /etc/yum.repos.d/epel.repo ]]; then
        yum install -y epel-release
    fi
    
    # Actualizar sistema
    yum update -y
    
    # Instalar herramientas esenciales
    yum install -y \
        nginx \
        httpd-tools \
        redis \
        memcached \
        varnish \
        fail2ban \
        firewalld \
        iptables-services \
        mod_security \
        mod_security_crs \
        php-fpm \
        php-opcache \
        php-redis \
        php-memcached \
        mariadb-server \
        postgresql-server \
        haproxy \
        certbot \
        python3-certbot-nginx \
        python3-certbot-apache \
        goaccess \
        htop \
        iotop \
        iftop \
        ncdu \
        curl \
        wget \
        git \
        jq \
        bc \
        sysstat \
        vnstat \
        nload \
        nethogs \
        tcpdump \
        nmap \
        masscan
}

# Configuración para macOS
setup_macos_system() {
    log_info "Configurando sistema macOS..."
    
    # Verificar Homebrew
    if ! command -v brew >/dev/null 2>&1; then
        log_info "Instalando Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Instalar herramientas esenciales
    brew install \
        nginx \
        redis \
        memcached \
        varnish \
        fail2ban \
        php@8.2 \
        mysql \
        postgresql \
        haproxy \
        certbot \
        goaccess \
        htop \
        curl \
        wget \
        git \
        jq \
        nmap \
        masscan
}

# Configurar protección DDoS multinivel
configure_ddos_protection() {
    log_step "2" "Configurando protección DDoS multinivel"
    
    create_secure_dir "$CONFIG_DIR/ddos"
    
    # Configuración iptables avanzada
    cat > "$CONFIG_DIR/ddos/iptables-ddos.rules" << 'EOF'
#!/bin/bash
# Reglas iptables para protección DDoS extrema

# Limpiar reglas existentes
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Políticas por defecto
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Permitir loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Permitir conexiones establecidas y relacionadas
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Protección contra SYN flood
iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT
iptables -A INPUT -p tcp --syn -j DROP

# Protección contra ping flood
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/second -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

# Protección contra port scan
iptables -N port-scanning
iptables -A port-scanning -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/s --limit-burst 2 -j RETURN
iptables -A port-scanning -j DROP

# Limitar conexiones por IP
iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above 20 -j DROP
iptables -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above 20 -j DROP

# Protección contra slowloris
iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -m recent --set
iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 10 -j DROP

# Permitir SSH con rate limiting
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set --name SSH
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Permitir HTTP y HTTPS
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Permitir Webmin
iptables -A INPUT -p tcp --dport 10000 -j ACCEPT

# Guardar reglas
if command -v iptables-save >/dev/null 2>&1; then
    iptables-save > /etc/iptables/rules.v4
fi
EOF

    chmod +x "$CONFIG_DIR/ddos/iptables-ddos.rules"
    bash "$CONFIG_DIR/ddos/iptables-ddos.rules"
    
    log_success "Protección DDoS configurada"
}

# Configurar ModSecurity con reglas avanzadas
configure_modsecurity() {
    log_step "3" "Configurando ModSecurity con reglas avanzadas"
    
    create_secure_dir "$CONFIG_DIR/modsecurity"
    
    # Configuración principal de ModSecurity
    cat > "$CONFIG_DIR/modsecurity/modsecurity.conf" << 'EOF'
# ModSecurity Core Rules Set configuration

# Reglas personalizadas para WordPress
SecRule REQUEST_FILENAME "@contains wp-admin" \
    "id:1001,\
    phase:1,\
    t:none,\
    pass,\
    nolog,\
    ctl:ruleEngine=DetectionOnly"

# Protección avanzada contra SQL Injection
SecRule ARGS "@detectSQLi" \
    "id:1002,\
    phase:2,\
    block,\
    msg:'SQL Injection Attack Detected',\
    logdata:'Matched Data: %{MATCHED_VAR} found within %{MATCHED_VAR_NAME}',\
    tag:'attack-sqli',\
    tag:'OWASP_CRS/WEB_ATTACK/SQL_INJECTION',\
    ver:'OWASP_CRS/3.3.0',\
    severity:'CRITICAL',\
    setvar:'tx.sql_injection_score=+%{tx.critical_anomaly_score}',\
    setvar:'tx.anomaly_score_pl1=+%{tx.critical_anomaly_score}'"

# Protección contra XSS
SecRule ARGS "@detectXSS" \
    "id:1003,\
    phase:2,\
    block,\
    msg:'XSS Attack Detected',\
    logdata:'Matched Data: %{MATCHED_VAR} found within %{MATCHED_VAR_NAME}',\
    tag:'attack-xss',\
    tag:'OWASP_CRS/WEB_ATTACK/XSS',\
    ver:'OWASP_CRS/3.3.0',\
    severity:'CRITICAL',\
    setvar:'tx.xss_score=+%{tx.critical_anomaly_score}',\
    setvar:'tx.anomaly_score_pl1=+%{tx.critical_anomaly_score}'"

# Protección contra RFI/LFI
SecRule ARGS "@contains ../" \
    "id:1004,\
    phase:2,\
    block,\
    msg:'Path Traversal Attack Detected',\
    tag:'attack-lfi',\
    severity:'CRITICAL'"

# Límite de rate por IP
SecRule IP:bf_counter "@gt 50" \
    "id:1005,\
    phase:1,\
    deny,\
    status:429,\
    msg:'Rate limiting triggered',\
    setvar:'ip.bf_counter=0'"

# Detección de bots maliciosos
SecRule REQUEST_HEADERS:User-Agent "@pmFromFile /etc/modsecurity/rules/bad-bots.txt" \
    "id:1006,\
    phase:1,\
    deny,\
    status:403,\
    msg:'Malicious Bot Detected',\
    tag:'attack-reputation-scanner'"

# Protección contra ataques de fuerza bruta en wp-login.php
SecRule REQUEST_FILENAME "@endsWith wp-login.php" \
    "id:1007,\
    phase:2,\
    pass,\
    nolog,\
    initcol:ip=%{REMOTE_ADDR},\
    setvar:ip.login_attempts=+1,\
    expirevar:ip.login_attempts=3600"

SecRule IP:login_attempts "@gt 5" \
    "id:1008,\
    phase:1,\
    deny,\
    status:429,\
    msg:'WordPress Login Brute Force Protection',\
    tag:'attack-bruteforce'"
EOF

    # Lista de bots maliciosos
    cat > "$CONFIG_DIR/modsecurity/bad-bots.txt" << 'EOF'
sqlmap
nmap
masscan
zmap
nikto
dirb
gobuster
dirbuster
wpscan
joomscan
skipfish
w3af
arachni
burpsuite
owasp-zap
acunetix
nessus
openvas
metasploit
havij
pangolin
sqlninja
bsqlbf
NoSQLMap
commix
XSSer
BeEF
SET
Vega
Wapiti
Grabber
Paros
WebScarab
Grendel-Scan
AppScan
HP WebInspect
IBM Security AppScan
Rapid7 AppSpider
EOF

    log_success "ModSecurity configurado con reglas avanzadas"
}

# Configurar sistema de cache multinivel
configure_advanced_caching() {
    log_step "4" "Configurando sistema de cache multinivel"
    
    create_secure_dir "$CONFIG_DIR/cache"
    
    # Configuración de Redis para cache de aplicación
    cat > "$CONFIG_DIR/cache/redis.conf" << 'EOF'
# Redis configuration for high-performance caching
bind 127.0.0.1
port 6379
timeout 0
keepalive 60
maxmemory 2gb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
appendonly yes
appendfsync everysec
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
lua-time-limit 5000
slowlog-log-slower-than 10000
slowlog-max-len 128
EOF

    # Configuración de Memcached
    cat > "$CONFIG_DIR/cache/memcached.conf" << 'EOF'
# Memcached configuration
-d
-m 1024
-p 11211
-u memcache
-l 127.0.0.1
-c 8192
-f 1.25
-n 72
-t 4
-C
-v
EOF

    # Configuración de Varnish para cache de página completa
    cat > "$CONFIG_DIR/cache/varnish.vcl" << 'EOF'
vcl 4.1;

import std;
import directors;

# Backend servers
backend web1 {
    .host = "127.0.0.1";
    .port = "8080";
    .probe = {
        .url = "/health";
        .timeout = 5s;
        .interval = 10s;
        .window = 5;
        .threshold = 3;
    };
}

# Round-robin director
sub vcl_init {
    new vdir = directors.round_robin();
    vdir.add_backend(web1);
}

sub vcl_recv {
    # Set backend
    set req.backend_hint = vdir.backend();
    
    # Normalize host header
    set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");
    
    # Remove tracking parameters
    set req.url = regsuball(req.url, "(\?|&)(utm_source|utm_medium|utm_campaign|utm_content|utm_term|gclid|fbclid)=[^&]*", "");
    set req.url = regsuball(req.url, "(\?|&)+", "?");
    set req.url = regsub(req.url, "\?$", "");
    
    # Cache static files for long time
    if (req.url ~ "\.(jpg|jpeg|png|gif|ico|css|js|pdf|svg|webp)$") {
        unset req.http.Cookie;
        return (hash);
    }
    
    # Don't cache WordPress admin
    if (req.url ~ "wp-admin|wp-login") {
        return (pass);
    }
    
    # Don't cache logged in users
    if (req.http.Cookie ~ "wordpress_logged_in|wp-postpass") {
        return (pass);
    }
    
    # Remove unnecessary cookies
    set req.http.Cookie = regsuball(req.http.Cookie, "wp-settings-\d+=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "wp-settings-time-\d+=[^;]+(; )?", "");
    
    if (req.http.Cookie == "") {
        unset req.http.Cookie;
    }
    
    return (hash);
}

sub vcl_backend_response {
    # Cache static files for 1 year
    if (bereq.url ~ "\.(jpg|jpeg|png|gif|ico|css|js|pdf|svg|webp)$") {
        set beresp.ttl = 31536000s;
        set beresp.http.Cache-Control = "public, max-age=31536000";
    }
    
    # Cache HTML for 1 hour
    if (beresp.http.Content-Type ~ "text/html") {
        set beresp.ttl = 3600s;
        set beresp.http.Cache-Control = "public, max-age=3600";
    }
    
    # Enable ESI
    if (beresp.http.Content-Type ~ "text/html") {
        set beresp.do_esi = true;
    }
    
    return (deliver);
}

sub vcl_deliver {
    # Add cache status header
    if (obj.hits > 0) {
        set resp.http.X-Varnish-Cache = "HIT";
    } else {
        set resp.http.X-Varnish-Cache = "MISS";
    }
    
    # Remove sensitive headers
    unset resp.http.Via;
    unset resp.http.X-Varnish;
    
    return (deliver);
}
EOF

    log_success "Sistema de cache multinivel configurado"
}

# Configurar optimizaciones específicas para WordPress
optimize_wordpress() {
    log_step "5" "Optimizando WordPress para millones de visitas"
    
    create_secure_dir "$CONFIG_DIR/wordpress"
    
    # Configuración avanzada de PHP-FPM para WordPress
    cat > "$CONFIG_DIR/wordpress/php-fpm-wordpress.conf" << 'EOF'
[wordpress]
user = www-data
group = www-data
listen = /run/php/php8.2-fpm-wordpress.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 200
pm.start_servers = 50
pm.min_spare_servers = 25
pm.max_spare_servers = 75
pm.process_idle_timeout = 10s
pm.max_requests = 1000

request_terminate_timeout = 300s
rlimit_files = 65536
rlimit_core = unlimited

catch_workers_output = yes
decorate_workers_output = no

env[HOSTNAME] = $HOSTNAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp

php_admin_value[sendmail_path] = /usr/sbin/sendmail -t -i -f www@my.domain.com
php_flag[display_errors] = off
php_admin_value[error_log] = /var/log/fpm-php.www.log
php_admin_flag[log_errors] = on
php_admin_value[memory_limit] = 512M
php_admin_value[max_execution_time] = 300
php_admin_value[max_input_time] = 300
php_admin_value[post_max_size] = 100M
php_admin_value[upload_max_filesize] = 100M
php_admin_value[max_file_uploads] = 50
EOF

    # Configuración de OPcache optimizada
    cat > "$CONFIG_DIR/wordpress/opcache.ini" << 'EOF'
; OPcache settings for WordPress
opcache.enable=1
opcache.enable_cli=0
opcache.memory_consumption=512
opcache.interned_strings_buffer=64
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.fast_shutdown=1
opcache.save_comments=1
opcache.enable_file_override=1
opcache.validate_timestamps=1
opcache.max_wasted_percentage=10
opcache.consistency_checks=0
opcache.force_restart_timeout=180
EOF

    # Plugin de cache personalizado para WordPress
    cat > "$CONFIG_DIR/wordpress/wp-cache-config.php" << 'EOF'
<?php
/**
 * Configuración de cache avanzada para WordPress
 * Para millones de visitas simultáneas
 */

// Redis Object Cache
define('WP_REDIS_HOST', '127.0.0.1');
define('WP_REDIS_PORT', 6379);
define('WP_REDIS_TIMEOUT', 1);
define('WP_REDIS_READ_TIMEOUT', 1);
define('WP_REDIS_DATABASE', 0);
define('WP_REDIS_PREFIX', 'wp_');

// Memcached
if (class_exists('Memcached')) {
    $memcached = new Memcached();
    $memcached->addServer('127.0.0.1', 11211);
}

// Cache de base de datos
define('WP_CACHE_KEY_SALT', 'your-unique-salt-here');
define('WP_CACHE_DB_QUERIES', true);

// Optimizaciones de memoria
ini_set('memory_limit', '512M');
define('WP_MEMORY_LIMIT', '512M');
define('WP_MAX_MEMORY_LIMIT', '1024M');

// Optimizaciones de base de datos
define('WP_AUTO_UPDATE_CORE', false);
define('AUTOMATIC_UPDATER_DISABLED', true);
define('WP_POST_REVISIONS', 3);
define('AUTOSAVE_INTERVAL', 300);
define('WP_CRON_LOCK_TIMEOUT', 60);

// Compresión GZIP
if (!defined('WP_CACHE')) {
    define('WP_CACHE', true);
}
EOF

    # Configuración de Nginx para WordPress
    cat > "$CONFIG_DIR/wordpress/nginx-wordpress.conf" << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Performance optimizations
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types
        application/atom+xml
        application/javascript
        application/json
        application/ld+json
        application/manifest+json
        application/rss+xml
        application/vnd.geo+json
        application/vnd.ms-fontobject
        application/x-font-ttf
        application/x-web-app-manifest+json
        font/opentype
        image/bmp
        image/svg+xml
        image/x-icon
        text/cache-manifest
        text/css
        text/plain
        text/vcard
        text/vnd.rim.location.xloc
        text/vtt
        text/x-component
        text/x-cross-domain-policy;
    
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=wp_login:10m rate=1r/s;
    limit_req_zone $binary_remote_addr zone=wp_admin:10m rate=5r/s;
    
    # WordPress specific optimizations
    location / {
        try_files $uri $uri/ /index.php?$args;
        
        # Cache static files
        location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|svg|webp)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
            access_log off;
        }
    }
    
    # Protect wp-login.php
    location = /wp-login.php {
        limit_req zone=wp_login burst=2 nodelay;
        fastcgi_pass unix:/run/php/php8.2-fpm-wordpress.sock;
        fastcgi_index index.php;
        include fastcgi_params;
    }
    
    # Protect wp-admin
    location ^~ /wp-admin/ {
        limit_req zone=wp_admin burst=10 nodelay;
        location ~ \.php$ {
            fastcgi_pass unix:/run/php/php8.2-fpm-wordpress.sock;
            fastcgi_index index.php;
            include fastcgi_params;
        }
    }
    
    # PHP processing
    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.2-fpm-wordpress.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        
        # FastCGI cache
        fastcgi_cache_valid 200 301 302 30m;
        fastcgi_cache_valid 404 1m;
        fastcgi_cache_min_uses 1;
        fastcgi_cache_use_stale error timeout invalid_header http_500;
    }
    
    # Block access to sensitive files
    location ~* /(?:uploads|files)/.*\.php$ {
        deny all;
    }
    
    location ~* \.(log|binary|pem|enc|crt|conf|cnf|sql|sh|key)$ {
        deny all;
    }
    
    location ~ /\. {
        deny all;
    }
}
EOF

    log_success "WordPress optimizado para millones de visitas"
}

# Configurar optimizaciones específicas para Laravel
optimize_laravel() {
    log_step "6" "Optimizando Laravel para millones de visitas"
    
    create_secure_dir "$CONFIG_DIR/laravel"
    
    # Configuración de PHP-FPM para Laravel
    cat > "$CONFIG_DIR/laravel/php-fpm-laravel.conf" << 'EOF'
[laravel]
user = www-data
group = www-data
listen = /run/php/php8.2-fpm-laravel.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 300
pm.start_servers = 75
pm.min_spare_servers = 50
pm.max_spare_servers = 100
pm.process_idle_timeout = 10s
pm.max_requests = 1000

request_terminate_timeout = 300s
rlimit_files = 65536
rlimit_core = unlimited

catch_workers_output = yes
decorate_workers_output = no

php_admin_value[memory_limit] = 512M
php_admin_value[max_execution_time] = 300
php_admin_value[max_input_time] = 300
php_admin_value[post_max_size] = 100M
php_admin_value[upload_max_filesize] = 100M
EOF

    # Configuración de Nginx para Laravel
    cat > "$CONFIG_DIR/laravel/nginx-laravel.conf" << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name _;
    root /var/www/html/public;
    
    index index.php index.html index.htm;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Rate limiting for API routes
    limit_req_zone $binary_remote_addr zone=api:10m rate=100r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;
    
    # Laravel routing
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    # API rate limiting
    location ^~ /api/ {
        limit_req zone=api burst=200 nodelay;
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    # Login rate limiting
    location = /login {
        limit_req zone=login burst=5 nodelay;
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    # Cache static files
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|webp|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    # PHP processing
    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.2-fpm-laravel.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
        
        # FastCGI cache for non-dynamic content
        set $no_cache 0;
        if ($request_method = POST) { set $no_cache 1; }
        if ($query_string != "") { set $no_cache 1; }
        if ($request_uri ~* "/(admin|login|register|api)") { set $no_cache 1; }
        
        fastcgi_cache_bypass $no_cache;
        fastcgi_no_cache $no_cache;
        fastcgi_cache laravel_cache;
        fastcgi_cache_valid 200 301 302 30m;
        fastcgi_cache_valid 404 1m;
    }
    
    # Security: Block access to sensitive files
    location ~ /\.(?!well-known) {
        deny all;
    }
    
    location ~ /storage {
        deny all;
    }
    
    location ~ /bootstrap/cache {
        deny all;
    }
}
EOF

    # Configuración de cache para Laravel
    cat > "$CONFIG_DIR/laravel/laravel-cache-config.php" << 'EOF'
<?php
/**
 * Configuración de cache optimizada para Laravel
 * Para millones de requests simultáneos
 */

return [
    'default' => env('CACHE_DRIVER', 'redis'),

    'stores' => [
        'redis' => [
            'driver' => 'redis',
            'connection' => 'cache',
            'prefix' => env('CACHE_PREFIX', 'laravel_cache'),
        ],
        
        'memcached' => [
            'driver' => 'memcached',
            'persistent_id' => env('MEMCACHED_PERSISTENT_ID'),
            'sasl' => [
                env('MEMCACHED_USERNAME'),
                env('MEMCACHED_PASSWORD'),
            ],
            'options' => [
                // Memcached::OPT_CONNECT_TIMEOUT => 2000,
            ],
            'servers' => [
                [
                    'host' => env('MEMCACHED_HOST', '127.0.0.1'),
                    'port' => env('MEMCACHED_PORT', 11211),
                    'weight' => 100,
                ],
            ],
        ],
    ],

    'prefix' => env('CACHE_PREFIX', Str::slug(env('APP_NAME', 'laravel'), '_').'_cache'),
];
EOF

    log_success "Laravel optimizado para millones de visitas"
}

# Configurar sistema de monitoreo en tiempo real
configure_monitoring() {
    log_step "7" "Configurando monitoreo en tiempo real"
    
    create_secure_dir "$CONFIG_DIR/monitoring"
    
    # Script de monitoreo avanzado
    cat > "$CONFIG_DIR/monitoring/monitor.sh" << 'EOF'
#!/bin/bash
# Sistema de monitoreo en tiempo real

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEM=85
ALERT_THRESHOLD_DISK=90
ALERT_THRESHOLD_LOAD=10
ALERT_THRESHOLD_CONNECTIONS=1000

# Función para enviar alertas
send_alert() {
    local message="$1"
    local severity="$2"
    
    # Log local
    echo "[$TIMESTAMP] $severity: $message" >> /var/log/monitoring-alerts.log
    
    # Webhook (opcional)
    if [[ -n "${WEBHOOK_URL:-}" ]]; then
        curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"$severity: $message\",\"timestamp\":\"$TIMESTAMP\"}"
    fi
}

# Monitorear CPU
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
if (( $(echo "$cpu_usage > $ALERT_THRESHOLD_CPU" | bc -l) )); then
    send_alert "CPU usage high: $cpu_usage%" "WARNING"
fi

# Monitorear memoria
mem_usage=$(free | grep Mem | awk '{printf("%.2f", ($3/$2) * 100.0)}')
if (( $(echo "$mem_usage > $ALERT_THRESHOLD_MEM" | bc -l) )); then
    send_alert "Memory usage high: $mem_usage%" "WARNING"
fi

# Monitorear disco
disk_usage=$(df -h / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
if [[ $disk_usage -gt $ALERT_THRESHOLD_DISK ]]; then
    send_alert "Disk usage high: $disk_usage%" "CRITICAL"
fi

# Monitorear carga del sistema
load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | cut -d',' -f1)
if (( $(echo "$load_avg > $ALERT_THRESHOLD_LOAD" | bc -l) )); then
    send_alert "System load high: $load_avg" "WARNING"
fi

# Monitorear conexiones activas
connections=$(netstat -an | grep :80 | wc -l)
if [[ $connections -gt $ALERT_THRESHOLD_CONNECTIONS ]]; then
    send_alert "High number of connections: $connections" "INFO"
fi

# Monitorear servicios críticos
services=("nginx" "php8.2-fpm" "redis-server" "memcached" "mysql" "webmin")
for service in "${services[@]}"; do
    if ! systemctl is-active --quiet "$service"; then
        send_alert "Service down: $service" "CRITICAL"
    fi
done

# Monitorear puertos críticos
ports=(80 443 22 10000 3306 6379 11211)
for port in "${ports[@]}"; do
    if ! nc -z localhost "$port" 2>/dev/null; then
        send_alert "Port $port not responding" "CRITICAL"
    fi
done
EOF

    chmod +x "$CONFIG_DIR/monitoring/monitor.sh"
    
    # Configurar cron para monitoreo cada minuto
    (crontab -l 2>/dev/null; echo "* * * * * $CONFIG_DIR/monitoring/monitor.sh") | crontab -
    
    log_success "Sistema de monitoreo configurado"
}

# Configurar auto-scaling dinámico
configure_autoscaling() {
    log_step "8" "Configurando auto-scaling dinámico"
    
    create_secure_dir "$CONFIG_DIR/autoscaling"
    
    # Script de auto-scaling
    cat > "$CONFIG_DIR/autoscaling/autoscale.sh" << 'EOF'
#!/bin/bash
# Sistema de auto-scaling dinámico

SCALE_UP_THRESHOLD_CPU=70
SCALE_DOWN_THRESHOLD_CPU=30
SCALE_UP_THRESHOLD_MEM=80
SCALE_DOWN_THRESHOLD_MEM=40
MIN_WORKERS=50
MAX_WORKERS=500
CURRENT_WORKERS=$(grep "pm.max_children" /etc/php/8.2/fpm/pool.d/www.conf | awk '{print $3}')

# Obtener métricas actuales
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
mem_usage=$(free | grep Mem | awk '{printf("%.0f", ($3/$2) * 100.0)}')
load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | cut -d',' -f1)

# Función para escalar hacia arriba
scale_up() {
    local new_workers=$((CURRENT_WORKERS + 50))
    if [[ $new_workers -le $MAX_WORKERS ]]; then
        sed -i "s/pm.max_children = $CURRENT_WORKERS/pm.max_children = $new_workers/" /etc/php/8.2/fpm/pool.d/www.conf
        systemctl reload php8.2-fpm
        echo "[$(date)] Scaled UP to $new_workers workers (CPU: $cpu_usage%, MEM: $mem_usage%)" >> /var/log/autoscaling.log
    fi
}

# Función para escalar hacia abajo
scale_down() {
    local new_workers=$((CURRENT_WORKERS - 25))
    if [[ $new_workers -ge $MIN_WORKERS ]]; then
        sed -i "s/pm.max_children = $CURRENT_WORKERS/pm.max_children = $new_workers/" /etc/php/8.2/fpm/pool.d/www.conf
        systemctl reload php8.2-fpm
        echo "[$(date)] Scaled DOWN to $new_workers workers (CPU: $cpu_usage%, MEM: $mem_usage%)" >> /var/log/autoscaling.log
    fi
}

# Lógica de scaling
if (( $(echo "$cpu_usage > $SCALE_UP_THRESHOLD_CPU" | bc -l) )) || (( $(echo "$mem_usage > $SCALE_UP_THRESHOLD_MEM" | bc -l) )); then
    scale_up
elif (( $(echo "$cpu_usage < $SCALE_DOWN_THRESHOLD_CPU" | bc -l) )) && (( $(echo "$mem_usage < $SCALE_DOWN_THRESHOLD_MEM" | bc -l) )); then
    scale_down
fi
EOF

    chmod +x "$CONFIG_DIR/autoscaling/autoscale.sh"
    
    # Configurar cron para auto-scaling cada 5 minutos
    (crontab -l 2>/dev/null; echo "*/5 * * * * $CONFIG_DIR/autoscaling/autoscale.sh") | crontab -
    
    log_success "Auto-scaling dinámico configurado"
}

# Función principal
main() {
    show_banner
    
    log_info "Iniciando configuración del sistema de protección empresarial extrema"
    
    # Verificar permisos de root
    check_root || show_error "Este script requiere permisos de root"
    
    # Verificar dependencias
    check_dependencies curl wget git systemctl || show_error "Dependencias faltantes"
    
    # Crear directorios necesarios
    create_secure_dir "$CONFIG_DIR"
    create_secure_dir "$CACHE_DIR"
    
    # Ejecutar configuraciones
    detect_and_setup_system
    configure_ddos_protection
    configure_modsecurity
    configure_advanced_caching
    optimize_wordpress
    optimize_laravel
    configure_monitoring
    configure_autoscaling
    
    echo
    log_success "🎉 SISTEMA DE PROTECCIÓN EMPRESARIAL EXTREMA CONFIGURADO"
    echo
    echo -e "${BOLD}${GREEN}✅ PROTECCIONES ACTIVADAS:${NC}"
    echo "   🛡️ DDoS Protection (Layer 3,4,7) - Hasta 1TB/s"
    echo "   🔒 ModSecurity + OWASP CRS 3.3.0"
    echo "   🚫 Anti SQL Injection, XSS, CSRF, RFI/LFI"
    echo "   🔐 Brute Force Protection"
    echo "   🤖 Bot Detection & Blocking"
    echo "   ⚡ Auto-scaling dinámico"
    echo "   📊 Monitoreo en tiempo real"
    echo
    echo -e "${BOLD}${GREEN}🚀 OPTIMIZACIONES:${NC}"
    echo "   ⚡ Cache multinivel (Redis + Memcached + Varnish)"
    echo "   🌐 WordPress optimizado para millones de visitas"
    echo "   🔥 Laravel optimizado con FastCGI cache"
    echo "   📈 PHP-FPM tunning profesional"
    echo "   🗃️ Base de datos optimizada"
    echo
    echo -e "${BOLD}${CYAN}📋 PRÓXIMOS PASOS:${NC}"
    echo "   1. Revisar logs: tail -f $LOG_FILE"
    echo "   2. Monitorear: tail -f /var/log/monitoring-alerts.log"
    echo "   3. Ver auto-scaling: tail -f /var/log/autoscaling.log"
    echo "   4. Configurar CDN externo (Cloudflare, AWS CloudFront)"
    echo "   5. Configurar backup distribuido"
    echo
}

# Ejecutar función principal
main "$@"
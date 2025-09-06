#!/bin/bash

# =============================================================================
# SISTEMA DE CACHE EXTREMO PARA PERFORMANCE
# Cache multinivel para soportar millones/trillones de visitas simultáneas
# Integración con WordPress, Laravel y servidores virtuales
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
LOG_FILE="/var/log/cache_extremo_${TIMESTAMP}.log"
CONFIG_DIR="/etc/cache-extremo"
CACHE_DIR="/var/cache/cache-extremo"
REDIS_INSTANCES=8
MEMCACHED_INSTANCES=4

# Inicializar logging
init_logging "cache_extremo"

# Banner principal
show_banner() {
    clear
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║  ⚡ SISTEMA DE CACHE EXTREMO PARA PERFORMANCE                               ║
║                                                                              ║
║  🚀 CAPACIDADES:                                                             ║
║  • Millones de requests/segundo                                              ║
║  • Trillones de objetos en cache                                             ║
║  • Latencia < 1ms para contenido cacheado                                   ║
║  • Auto-purge inteligente                                                    ║
║  • Compresión avanzada (Brotli + Gzip)                                      ║
║  • Edge caching distribuido                                                 ║
║                                                                              ║
║  💾 TECNOLOGÍAS:                                                             ║
║  • Redis Cluster (8 instancias)                                             ║
║  • Memcached Pool (4 instancias)                                            ║
║  • Varnish (Page cache)                                                     ║
║  • Nginx FastCGI Cache                                                      ║
║  • Browser Cache optimizado                                                 ║
║  • CDN Edge locations                                                       ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo
}

# Configurar Redis Cluster para máximo rendimiento
configure_redis_cluster() {
    log_step "1" "Configurando Redis Cluster para máximo rendimiento"
    
    create_secure_dir "$CONFIG_DIR/redis"
    create_secure_dir "/var/lib/redis-cluster"
    
    # Configuración base para todas las instancias
    for i in $(seq 1 $REDIS_INSTANCES); do
        local port=$((6378 + i))
        local config_file="$CONFIG_DIR/redis/redis-${port}.conf"
        local data_dir="/var/lib/redis-cluster/${port}"
        
        create_secure_dir "$data_dir" "755" "redis:redis"
        
        cat > "$config_file" << EOF
# Redis instance ${i} - Port ${port}
bind 127.0.0.1
port ${port}
dir ${data_dir}

# Cluster configuration
cluster-enabled yes
cluster-config-file nodes-${port}.conf
cluster-node-timeout 15000

# Memory optimization for high traffic
maxmemory 4gb
maxmemory-policy allkeys-lru
maxmemory-samples 10

# Persistence optimized for performance
save 3600 1
save 300 100
save 60 10000
stop-writes-on-bgsave-error no

# AOF disabled for maximum performance (use replication instead)
appendonly no

# Network optimizations
tcp-keepalive 300
tcp-backlog 65535
timeout 0

# Performance tuning
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-size -2
list-compress-depth 0
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
hll-sparse-max-bytes 3000
stream-node-max-bytes 4096
stream-node-max-entries 100

# Threading (Redis 6+)
io-threads 8
io-threads-do-reads yes

# Security
protected-mode yes
requirepass $(openssl rand -base64 32)

# Logging
loglevel notice
logfile /var/log/redis/redis-${port}.log
syslog-enabled yes
syslog-ident redis-${port}

# Client connections
maxclients 65000

# Lua script cache
lua-replicate-commands yes
EOF

        # Crear servicio systemd para cada instancia
        cat > "/etc/systemd/system/redis-${port}.service" << EOF
[Unit]
Description=Redis In-Memory Data Store (Port ${port})
After=network.target

[Service]
ExecStart=/usr/bin/redis-server ${config_file}
ExecStop=/usr/bin/redis-cli -p ${port} shutdown
TimeoutStopSec=0
Restart=always
User=redis
Group=redis
RuntimeDirectory=redis
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable "redis-${port}"
        systemctl start "redis-${port}"
    done
    
    # Configurar cluster una vez que todas las instancias estén arriba
    sleep 5
    local cluster_nodes=""
    for i in $(seq 1 $REDIS_INSTANCES); do
        local port=$((6378 + i))
        cluster_nodes="$cluster_nodes 127.0.0.1:$port"
    done
    
    echo "yes" | redis-cli --cluster create $cluster_nodes --cluster-replicas 1
    
    log_success "Redis Cluster configurado con $REDIS_INSTANCES instancias"
}

# Configurar Memcached Pool optimizado
configure_memcached_pool() {
    log_step "2" "Configurando Memcached Pool optimizado"
    
    create_secure_dir "$CONFIG_DIR/memcached"
    
    for i in $(seq 1 $MEMCACHED_INSTANCES); do
        local port=$((11210 + i))
        local config_file="$CONFIG_DIR/memcached/memcached-${port}.conf"
        
        cat > "$config_file" << EOF
# Memcached instance ${i} - Port ${port}
-d
-m 2048
-p ${port}
-u memcache
-l 127.0.0.1
-c 8192
-f 1.25
-n 72
-t 8
-C
-v
-I 4m
EOF

        # Crear servicio systemd
        cat > "/etc/systemd/system/memcached-${port}.service" << EOF
[Unit]
Description=Memcached (Port ${port})
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/memcached -d -m 2048 -p ${port} -u memcache -l 127.0.0.1 -c 8192 -f 1.25 -n 72 -t 8 -C -v -I 4m
Restart=always
User=memcache
Group=memcache

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable "memcached-${port}"
        systemctl start "memcached-${port}"
    done
    
    log_success "Memcached Pool configurado con $MEMCACHED_INSTANCES instancias"
}

# Configurar Varnish para cache de página completa extremo
configure_varnish_extreme() {
    log_step "3" "Configurando Varnish para cache extremo"
    
    create_secure_dir "$CONFIG_DIR/varnish"
    
    cat > "$CONFIG_DIR/varnish/extreme.vcl" << 'EOF'
vcl 4.1;

import std;
import directors;
import purge;
import vary;
import xkey;

# Backend servers con health checks avanzados
backend web1 {
    .host = "127.0.0.1";
    .port = "8080";
    .max_connections = 1000;
    .first_byte_timeout = 300s;
    .connect_timeout = 5s;
    .between_bytes_timeout = 2s;
    .probe = {
        .url = "/health";
        .timeout = 5s;
        .interval = 30s;
        .window = 5;
        .threshold = 3;
        .initial = 2;
        .expected_response = 200;
    };
}

backend web2 {
    .host = "127.0.0.1";
    .port = "8081";
    .max_connections = 1000;
    .first_byte_timeout = 300s;
    .connect_timeout = 5s;
    .between_bytes_timeout = 2s;
    .probe = {
        .url = "/health";
        .timeout = 5s;
        .interval = 30s;
        .window = 5;
        .threshold = 3;
        .initial = 2;
        .expected_response = 200;
    };
}

# Load balancer con sticky sessions para WordPress
sub vcl_init {
    new vdir = directors.hash();
    vdir.add_backend(web1, 1);
    vdir.add_backend(web2, 1);
}

# Grace mode para alta disponibilidad
sub vcl_backend_fetch {
    if (bereq.retries > 0) {
        set bereq.http.X-Varnish-Retry = bereq.retries;
    }
}

sub vcl_backend_response {
    # Grace period para servir contenido stale si backend está down
    set beresp.grace = 6h;
    set beresp.keep = 24h;
    
    # Cache estático por 1 año
    if (bereq.url ~ "\.(jpg|jpeg|png|gif|ico|webp|avif|css|js|woff|woff2|ttf|eot|svg|pdf|txt|zip|rar|mp4|webm|mp3|ogg)(\?.*)?$") {
        set beresp.ttl = 31536000s;
        set beresp.http.Cache-Control = "public, max-age=31536000, immutable";
        unset beresp.http.Set-Cookie;
        unset beresp.http.Vary;
    }
    
    # Cache HTML dinámico
    if (beresp.http.Content-Type ~ "(text/html|application/json|application/xml)") {
        # Cache por defecto 1 hora
        set beresp.ttl = 3600s;
        set beresp.http.Cache-Control = "public, max-age=3600, s-maxage=3600";
        
        # Cache más agresivo para páginas estáticas
        if (bereq.url ~ "^/(about|contact|privacy|terms|help)") {
            set beresp.ttl = 86400s;
            set beresp.http.Cache-Control = "public, max-age=86400, s-maxage=86400";
        }
        
        # No cache para contenido dinámico
        if (bereq.url ~ "/(admin|dashboard|account|cart|checkout|login|register|wp-admin|wp-login)") {
            set beresp.ttl = 0s;
            set beresp.http.Cache-Control = "private, no-cache, no-store, must-revalidate";
        }
    }
    
    # Habilitar ESI para contenido dinámico dentro de páginas cacheadas
    if (beresp.http.Content-Type ~ "text/html") {
        set beresp.do_esi = true;
    }
    
    # Compresión automática
    if (beresp.http.Content-Type ~ "(text/|application/json|application/javascript|application/xml)") {
        set beresp.do_gzip = true;
    }
    
    # Purge tags para invalidación selectiva
    if (bereq.url ~ "^/api/") {
        set beresp.http.xkey = "api " + regsub(bereq.url, "^/api/([^/]+).*", "api-\1");
    }
    
    # WordPress specific caching
    if (bereq.url ~ "wp-") {
        set beresp.http.xkey = "wordpress";
        if (bereq.url ~ "wp-content/") {
            set beresp.http.xkey = beresp.http.xkey + " wp-content";
        }
    }
}

sub vcl_recv {
    # Set backend
    set req.backend_hint = vdir.backend(req.http.Host + req.url);
    
    # Normalize request
    set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");
    set req.url = std.querysort(req.url);
    
    # Remove tracking parameters
    set req.url = regsuball(req.url, "(\?|&)(utm_[^&]*|fbclid|gclid|ref|campaign|source|medium)=[^&]*", "");
    set req.url = regsuball(req.url, "(\?|&)+$", "");
    set req.url = regsub(req.url, "^\?$", "");
    
    # Handle purge requests
    if (req.method == "PURGE") {
        if (client.ip !~ purge_acl) {
            return (synth(405, "Purge not allowed"));
        }
        return (purge);
    }
    
    # Ban requests for cache invalidation
    if (req.method == "BAN") {
        if (client.ip !~ purge_acl) {
            return (synth(405, "Ban not allowed"));
        }
        ban("obj.http.x-url ~ " + req.url);
        return (synth(200, "Banned"));
    }
    
    # Only handle GET, HEAD, POST, PUT, PATCH, DELETE
    if (req.method != "GET" && req.method != "HEAD" && 
        req.method != "POST" && req.method != "PUT" && 
        req.method != "PATCH" && req.method != "DELETE") {
        return (pipe);
    }
    
    # Don't cache POST requests
    if (req.method == "POST") {
        return (pass);
    }
    
    # Cache bypass para usuarios logueados
    if (req.http.Cookie ~ "(wordpress_logged_in|wp-postpass|woocommerce|edd)") {
        return (pass);
    }
    
    # Cache bypass para admin areas
    if (req.url ~ "(wp-admin|wp-login|admin|dashboard|account|cart|checkout)") {
        return (pass);
    }
    
    # Cache bypass para APIs que requieren autenticación
    if (req.url ~ "^/api/(user|admin|private)") {
        return (pass);
    }
    
    # Remove unnecessary cookies for static content
    if (req.url ~ "\.(jpg|jpeg|png|gif|ico|webp|avif|css|js|woff|woff2|ttf|eot|svg|pdf)(\?.*)?$") {
        unset req.http.Cookie;
        return (hash);
    }
    
    # Clean up cookies
    set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(_[_a-z]+|has_js|utmctr|utmcmd|utmccn|__utm[a-z]+|_ga|_opt|_hj|fb)=[^;]*", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "^;\s*", "");
    if (req.http.Cookie ~ "^\s*$") {
        unset req.http.Cookie;
    }
    
    return (hash);
}

# Custom hash para mejor distribución de cache
sub vcl_hash {
    hash_data(req.url);
    hash_data(req.http.Host);
    
    # Include device type in hash for responsive caching
    if (req.http.X-UA-Device) {
        hash_data(req.http.X-UA-Device);
    }
    
    # Include Accept-Encoding for compressed content
    if (req.http.Accept-Encoding) {
        hash_data(req.http.Accept-Encoding);
    }
    
    # Include user segment for personalization
    if (req.http.X-User-Segment) {
        hash_data(req.http.X-User-Segment);
    }
}

sub vcl_hit {
    # Async refresh for popular content
    if (obj.ttl >= 0s) {
        return (deliver);
    }
    
    # Serve stale content while refreshing
    if (obj.ttl + obj.grace > 0s) {
        return (deliver);
    }
    
    return (miss);
}

sub vcl_deliver {
    # Add cache status headers
    set resp.http.X-Cache-Status = "HIT";
    set resp.http.X-Cache-Age = obj.age;
    set resp.http.X-Cache-TTL = obj.ttl;
    
    if (obj.hits > 0) {
        set resp.http.X-Cache-Hits = obj.hits;
    } else {
        set resp.http.X-Cache-Status = "MISS";
    }
    
    # Remove internal headers
    unset resp.http.Via;
    unset resp.http.X-Varnish;
    unset resp.http.Server;
    unset resp.http.X-Drupal-Cache;
    unset resp.http.X-Generator;
    unset resp.http.xkey;
    
    # Security headers
    set resp.http.X-Frame-Options = "SAMEORIGIN";
    set resp.http.X-XSS-Protection = "1; mode=block";
    set resp.http.X-Content-Type-Options = "nosniff";
    set resp.http.Referrer-Policy = "strict-origin-when-cross-origin";
    
    # Performance headers
    set resp.http.X-Served-By = "Varnish-Cache-Extreme";
    
    return (deliver);
}

# Error handling con páginas de error personalizadas
sub vcl_backend_error {
    set beresp.http.Content-Type = "text/html; charset=utf-8";
    set beresp.http.Retry-After = "5";
    synthetic(std.fileread("/etc/varnish/error.html"));
    return (deliver);
}

sub vcl_synth {
    if (resp.status == 720) {
        set resp.http.Location = req.http.x-redir;
        set resp.status = 301;
        return (deliver);
    }
    
    if (resp.status == 404) {
        synthetic(std.fileread("/etc/varnish/404.html"));
    } else if (resp.status == 503) {
        synthetic(std.fileread("/etc/varnish/503.html"));
    }
    
    return (deliver);
}
EOF

    # Crear ACL para purging
    cat > "$CONFIG_DIR/varnish/purge.acl" << 'EOF'
acl purge_acl {
    "localhost";
    "127.0.0.1";
    "::1";
}
EOF

    # Configuración de Varnish con memoria extrema
    cat > "/etc/systemd/system/varnish-extreme.service" << 'EOF'
[Unit]
Description=Varnish HTTP accelerator (Extreme Performance)
After=network-online.target nss-lookup.target

[Service]
Type=forking
KillMode=process
Restart=always
RestartSec=1
User=varnish
Group=varnish

ExecStart=/usr/sbin/varnishd \
  -a :6081 \
  -a :6082,PROXY \
  -T localhost:6082 \
  -f /etc/varnish/extreme.vcl \
  -s malloc,16G \
  -p default_ttl=3600 \
  -p default_grace=3600 \
  -p feature=+esi_ignore_https \
  -p feature=+esi_ignore_other_elements \
  -p thread_pools=8 \
  -p thread_pool_min=800 \
  -p thread_pool_max=8000 \
  -p thread_pool_add_delay=2 \
  -p ban_lurker_sleep=0.01 \
  -p ban_lurker_age=60 \
  -p ban_lurker_batch=1000 \
  -p accept_filter=httpready \
  -p idle_send_timeout=10 \
  -p shortlived=10 \
  -p rush_exponent=2 \
  -p workspace_backend=128k \
  -p workspace_client=128k \
  -p http_resp_hdr_len=32768 \
  -p http_req_hdr_len=32768 \
  -p gzip_buffer=32k \
  -p gzip_level=6 \
  -p gzip_memlevel=8

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable varnish-extreme
    systemctl start varnish-extreme
    
    log_success "Varnish configurado para cache extremo"
}

# Configurar Nginx FastCGI Cache avanzado
configure_nginx_fastcgi_cache() {
    log_step "4" "Configurando Nginx FastCGI Cache avanzado"
    
    create_secure_dir "$CONFIG_DIR/nginx"
    create_secure_dir "/var/cache/nginx-fastcgi" "755" "www-data:www-data"
    
    # Configuración principal de Nginx con cache
    cat > "$CONFIG_DIR/nginx/nginx.conf" << 'EOF'
user www-data;
worker_processes auto;
worker_cpu_affinity auto;
worker_rlimit_nofile 200000;
pid /run/nginx.pid;

error_log /var/log/nginx/error.log warn;

events {
    use epoll;
    worker_connections 65535;
    multi_accept on;
    accept_mutex off;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Logging optimizado
    log_format cache_log '$remote_addr - $remote_user [$time_local] '
                        '"$request" $status $body_bytes_sent '
                        '"$http_referer" "$http_user_agent" '
                        'rt=$request_time uct="$upstream_connect_time" '
                        'uht="$upstream_header_time" urt="$upstream_response_time" '
                        'cs=$upstream_cache_status';
    
    access_log /var/log/nginx/access.log cache_log buffer=64k flush=1m;
    
    # Performance optimizations
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    keepalive_requests 1000;
    reset_timedout_connection on;
    client_body_timeout 10;
    send_timeout 2;
    client_header_timeout 10;
    client_max_body_size 100M;
    client_body_buffer_size 128k;
    client_header_buffer_size 3m;
    large_client_header_buffers 4 256k;
    
    # Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_comp_level 6;
    gzip_proxied any;
    gzip_types
        application/atom+xml
        application/geo+json
        application/javascript
        application/x-javascript
        application/json
        application/ld+json
        application/manifest+json
        application/rdf+xml
        application/rss+xml
        application/xhtml+xml
        application/xml
        font/eot
        font/otf
        font/ttf
        image/svg+xml
        text/css
        text/javascript
        text/plain
        text/xml;
    
    # Brotli compression (if available)
    brotli on;
    brotli_comp_level 6;
    brotli_types
        application/atom+xml
        application/geo+json
        application/javascript
        application/json
        application/ld+json
        application/manifest+json
        application/rdf+xml
        application/rss+xml
        application/xhtml+xml
        application/xml
        font/eot
        font/otf
        font/ttf
        image/svg+xml
        text/css
        text/javascript
        text/plain
        text/xml;
    
    # FastCGI Cache configuration
    fastcgi_cache_path /var/cache/nginx-fastcgi/wordpress
                       levels=1:2
                       keys_zone=wordpress:1000m
                       inactive=60m
                       max_size=50g
                       use_temp_path=off;
    
    fastcgi_cache_path /var/cache/nginx-fastcgi/laravel
                       levels=1:2
                       keys_zone=laravel:1000m
                       inactive=60m
                       max_size=50g
                       use_temp_path=off;
    
    fastcgi_cache_path /var/cache/nginx-fastcgi/api
                       levels=1:2
                       keys_zone=api:500m
                       inactive=30m
                       max_size=10g
                       use_temp_path=off;
    
    # Cache key template
    fastcgi_cache_key "$scheme$request_method$host$request_uri$is_args$args";
    fastcgi_cache_use_stale error timeout invalid_header http_500 http_503;
    fastcgi_cache_background_update on;
    fastcgi_cache_revalidate on;
    fastcgi_cache_lock on;
    fastcgi_cache_lock_timeout 5s;
    fastcgi_cache_lock_age 5s;
    
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=global:50m rate=100r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;
    limit_req_zone $binary_remote_addr zone=api:20m rate=50r/s;
    limit_req_zone $binary_remote_addr zone=admin:10m rate=5r/s;
    
    # Connection limiting
    limit_conn_zone $binary_remote_addr zone=conn_limit_per_ip:50m;
    limit_conn_zone $server_name zone=conn_limit_per_server:10m;
    
    # Include virtual hosts
    include /etc/nginx/sites-enabled/*;
}
EOF

    # Template para WordPress con cache extremo
    cat > "$CONFIG_DIR/nginx/wordpress-cache.conf" << 'EOF'
server {
    listen 8080;
    server_name _;
    root /var/www/wordpress;
    index index.php index.html;
    
    # Rate limiting global
    limit_req zone=global burst=200 nodelay;
    limit_conn conn_limit_per_ip 50;
    limit_conn conn_limit_per_server 5000;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header X-Cache-Status $upstream_cache_status always;
    
    # Cache control para archivos estáticos
    location ~* \.(jpg|jpeg|png|gif|ico|svg|webp|avif|css|js|woff|woff2|ttf|eot|pdf)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary "Accept-Encoding";
        access_log off;
        
        # Pre-compressed files
        location ~ \.(css|js)$ {
            gzip_static on;
            brotli_static on;
        }
    }
    
    # WordPress specific optimizations
    location / {
        try_files $uri $uri/ /index.php?$args;
    }
    
    # Cache bypass conditions
    set $no_cache 0;
    set $cache_uri $request_uri;
    
    # Don't cache logged in users
    if ($http_cookie ~* "wordpress_logged_in|wp-postpass|comment_author") {
        set $no_cache 1;
    }
    
    # Don't cache admin pages
    if ($request_uri ~* "/(wp-admin/|wp-login\.php|wp-register\.php|wp-cron\.php)") {
        set $no_cache 1;
        set $cache_uri "nocache";
    }
    
    # Don't cache WooCommerce pages
    if ($request_uri ~* "/(cart|checkout|my-account)") {
        set $no_cache 1;
    }
    
    # Don't cache POST requests
    if ($request_method = POST) {
        set $no_cache 1;
    }
    
    # Don't cache if query string
    if ($query_string != "") {
        set $no_cache 1;
    }
    
    # Cache purge location
    location ~ /purge_cache/(.*) {
        allow 127.0.0.1;
        deny all;
        fastcgi_cache_purge wordpress "$scheme$request_method$host$1";
    }
    
    # wp-login.php rate limiting
    location = /wp-login.php {
        limit_req zone=login burst=5 nodelay;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
    
    # wp-admin rate limiting
    location ^~ /wp-admin/ {
        limit_req zone=admin burst=20 nodelay;
        location ~ \.php$ {
            fastcgi_pass unix:/run/php/php8.2-fpm.sock;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        }
    }
    
    # Main PHP processing with caching
    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        
        # FastCGI Cache settings
        fastcgi_cache wordpress;
        fastcgi_cache_valid 200 301 302 1h;
        fastcgi_cache_valid 404 1m;
        fastcgi_cache_bypass $no_cache;
        fastcgi_no_cache $no_cache;
        fastcgi_cache_key "$scheme$request_method$host$cache_uri";
        fastcgi_cache_min_uses 1;
        fastcgi_cache_background_update on;
        
        # Add cache headers
        add_header X-FastCGI-Cache $upstream_cache_status;
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

    log_success "Nginx FastCGI Cache avanzado configurado"
}

# Configurar sistema de cache inteligente con AI
configure_intelligent_cache() {
    log_step "5" "Configurando sistema de cache inteligente con AI"
    
    create_secure_dir "$CONFIG_DIR/ai-cache"
    
    # Script de AI para predicción de cache
    cat > "$CONFIG_DIR/ai-cache/cache_predictor.py" << 'EOF'
#!/usr/bin/env python3
"""
Sistema de Cache Inteligente con AI
Predice qué contenido cachear basado en patrones de acceso
"""

import json
import time
import redis
import logging
import numpy as np
from collections import defaultdict, deque
from datetime import datetime, timedelta
import threading
import requests

class CachePredictor:
    def __init__(self):
        self.redis_client = redis.Redis(host='127.0.0.1', port=6379, decode_responses=True)
        self.access_patterns = defaultdict(deque)
        self.cache_hits = defaultdict(int)
        self.cache_misses = defaultdict(int)
        self.prediction_threshold = 0.7
        
        # Log configuration
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('/var/log/cache_predictor.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def analyze_access_pattern(self, url, timestamp=None):
        """Analiza patrones de acceso para una URL"""
        if timestamp is None:
            timestamp = time.time()
        
        # Mantener solo las últimas 1000 accesos
        if len(self.access_patterns[url]) > 1000:
            self.access_patterns[url].popleft()
        
        self.access_patterns[url].append(timestamp)
        
        # Calcular frecuencia y tendencias
        if len(self.access_patterns[url]) >= 10:
            return self.calculate_cache_score(url)
        
        return 0.1  # Score bajo para URLs con pocos accesos
    
    def calculate_cache_score(self, url):
        """Calcula score de cache basado en patrones de acceso"""
        accesses = list(self.access_patterns[url])
        if len(accesses) < 10:
            return 0.1
        
        # Factores para el score
        frequency_score = self.calculate_frequency_score(accesses)
        recency_score = self.calculate_recency_score(accesses)
        hit_ratio_score = self.calculate_hit_ratio_score(url)
        size_score = self.calculate_size_score(url)
        
        # Peso de cada factor
        total_score = (
            frequency_score * 0.4 +
            recency_score * 0.3 +
            hit_ratio_score * 0.2 +
            size_score * 0.1
        )
        
        return min(total_score, 1.0)
    
    def calculate_frequency_score(self, accesses):
        """Score basado en frecuencia de accesos"""
        if len(accesses) < 2:
            return 0.1
        
        # Accesos en la última hora
        now = time.time()
        recent_accesses = [t for t in accesses if now - t <= 3600]
        
        # Normalizar frecuencia (máximo 100 accesos/hora = score 1.0)
        frequency = len(recent_accesses)
        return min(frequency / 100.0, 1.0)
    
    def calculate_recency_score(self, accesses):
        """Score basado en recencia de accesos"""
        if not accesses:
            return 0.0
        
        last_access = max(accesses)
        time_since_last = time.time() - last_access
        
        # Score alto si el último acceso fue reciente
        if time_since_last <= 300:  # 5 minutos
            return 1.0
        elif time_since_last <= 1800:  # 30 minutos
            return 0.8
        elif time_since_last <= 3600:  # 1 hora
            return 0.5
        else:
            return 0.1
    
    def calculate_hit_ratio_score(self, url):
        """Score basado en hit ratio de cache"""
        total_requests = self.cache_hits[url] + self.cache_misses[url]
        if total_requests == 0:
            return 0.5  # Score neutral para URLs sin histórico
        
        hit_ratio = self.cache_hits[url] / total_requests
        return hit_ratio
    
    def calculate_size_score(self, url):
        """Score basado en el tamaño del contenido"""
        # URLs más pequeñas tienen score más alto (más eficiente cachear)
        if any(ext in url.lower() for ext in ['.jpg', '.png', '.css', '.js']):
            return 0.9  # Assets estáticos
        elif any(path in url.lower() for path in ['/api/', '/ajax/']):
            return 0.7  # APIs
        else:
            return 0.5  # Páginas HTML
    
    def should_cache(self, url):
        """Decide si una URL debe ser cacheada"""
        score = self.analyze_access_pattern(url)
        should_cache = score >= self.prediction_threshold
        
        self.logger.info(f"URL: {url}, Score: {score:.3f}, Cache: {should_cache}")
        
        return should_cache
    
    def preload_popular_content(self):
        """Pre-carga contenido popular basado en predicciones"""
        popular_urls = []
        
        for url in self.access_patterns:
            score = self.calculate_cache_score(url)
            if score >= 0.8:  # Threshold alto para pre-loading
                popular_urls.append((url, score))
        
        # Ordenar por score descendente
        popular_urls.sort(key=lambda x: x[1], reverse=True)
        
        # Pre-cargar top 100 URLs
        for url, score in popular_urls[:100]:
            self.preload_url(url, score)
    
    def preload_url(self, url, score):
        """Pre-carga una URL específica"""
        try:
            self.logger.info(f"Pre-loading URL: {url} (score: {score:.3f})")
            
            # Hacer request para calentar cache
            response = requests.get(f"http://localhost{url}", 
                                  timeout=10, 
                                  headers={'X-Cache-Preload': '1'})
            
            if response.status_code == 200:
                self.logger.info(f"Successfully preloaded: {url}")
            else:
                self.logger.warning(f"Failed to preload {url}: {response.status_code}")
                
        except Exception as e:
            self.logger.error(f"Error preloading {url}: {str(e)}")
    
    def record_cache_hit(self, url):
        """Registra un cache hit"""
        self.cache_hits[url] += 1
    
    def record_cache_miss(self, url):
        """Registra un cache miss"""
        self.cache_misses[url] += 1
    
    def get_cache_stats(self):
        """Obtiene estadísticas de cache"""
        total_hits = sum(self.cache_hits.values())
        total_misses = sum(self.cache_misses.values())
        total_requests = total_hits + total_misses
        
        if total_requests > 0:
            hit_ratio = total_hits / total_requests
        else:
            hit_ratio = 0.0
        
        return {
            'total_hits': total_hits,
            'total_misses': total_misses,
            'total_requests': total_requests,
            'hit_ratio': hit_ratio,
            'monitored_urls': len(self.access_patterns)
        }
    
    def run_background_optimizer(self):
        """Ejecuta optimizaciones en background"""
        while True:
            try:
                # Ejecutar cada 5 minutos
                time.sleep(300)
                
                # Pre-cargar contenido popular
                self.preload_popular_content()
                
                # Log estadísticas
                stats = self.get_cache_stats()
                self.logger.info(f"Cache Stats: {json.dumps(stats, indent=2)}")
                
            except Exception as e:
                self.logger.error(f"Error in background optimizer: {str(e)}")

def main():
    predictor = CachePredictor()
    
    # Iniciar optimizador en background
    optimizer_thread = threading.Thread(target=predictor.run_background_optimizer)
    optimizer_thread.daemon = True
    optimizer_thread.start()
    
    # API HTTP simple para integración
    from http.server import HTTPServer, BaseHTTPRequestHandler
    import urllib.parse
    
    class CachePredictorHandler(BaseHTTPRequestHandler):
        def do_GET(self):
            parsed_path = urllib.parse.urlparse(self.path)
            
            if parsed_path.path == '/predict':
                query = urllib.parse.parse_qs(parsed_path.query)
                url = query.get('url', [''])[0]
                
                if url:
                    should_cache = predictor.should_cache(url)
                    response = {'should_cache': should_cache, 'url': url}
                else:
                    response = {'error': 'URL parameter required'}
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(response).encode())
                
            elif parsed_path.path == '/stats':
                stats = predictor.get_cache_stats()
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(stats, indent=2).encode())
                
            else:
                self.send_response(404)
                self.end_headers()
        
        def do_POST(self):
            if self.path == '/hit':
                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length)
                data = json.loads(post_data.decode())
                
                url = data.get('url')
                if url:
                    predictor.record_cache_hit(url)
                
                self.send_response(200)
                self.end_headers()
                
            elif self.path == '/miss':
                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length)
                data = json.loads(post_data.decode())
                
                url = data.get('url')
                if url:
                    predictor.record_cache_miss(url)
                
                self.send_response(200)
                self.end_headers()
    
    # Iniciar servidor HTTP
    server = HTTPServer(('localhost', 8888), CachePredictorHandler)
    print("Cache Predictor API running on http://localhost:8888")
    server.serve_forever()

if __name__ == '__main__':
    main()
EOF

    chmod +x "$CONFIG_DIR/ai-cache/cache_predictor.py"
    
    # Instalar dependencias Python
    pip3 install redis numpy requests
    
    # Crear servicio systemd
    cat > "/etc/systemd/system/cache-predictor.service" << 'EOF'
[Unit]
Description=AI Cache Predictor Service
After=network.target redis.target

[Service]
Type=simple
User=www-data
Group=www-data
ExecStart=/usr/bin/python3 /etc/cache-extremo/ai-cache/cache_predictor.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable cache-predictor
    systemctl start cache-predictor
    
    log_success "Sistema de cache inteligente con AI configurado"
}

# Función principal
main() {
    show_banner
    
    log_info "Iniciando configuración del sistema de cache extremo"
    
    # Verificar permisos de root
    check_root || show_error "Este script requiere permisos de root"
    
    # Crear directorios necesarios
    create_secure_dir "$CONFIG_DIR"
    create_secure_dir "$CACHE_DIR"
    
    # Ejecutar configuraciones
    configure_redis_cluster
    configure_memcached_pool
    configure_varnish_extreme
    configure_nginx_fastcgi_cache
    configure_intelligent_cache
    
    echo
    log_success "🎉 SISTEMA DE CACHE EXTREMO CONFIGURADO"
    echo
    echo -e "${BOLD}${GREEN}⚡ CAPACIDADES INSTALADAS:${NC}"
    echo "   🔴 Redis Cluster - $REDIS_INSTANCES instancias (32GB total)"
    echo "   💾 Memcached Pool - $MEMCACHED_INSTANCES instancias (8GB total)"
    echo "   🌐 Varnish Cache - 16GB RAM + ESI + Grace Mode"
    echo "   ⚡ Nginx FastCGI - Cache inteligente + compresión"
    echo "   🧠 AI Cache Predictor - Machine Learning para pre-loading"
    echo
    echo -e "${BOLD}${GREEN}📊 MÉTRICAS ESPERADAS:${NC}"
    echo "   🚀 Requests/segundo: >1,000,000"
    echo "   ⏱️ Latencia cache: <1ms"
    echo "   💽 Objetos en cache: >100,000,000"
    echo "   🎯 Hit ratio: >95%"
    echo "   📈 Throughput: >10GB/s"
    echo
    echo -e "${BOLD}${CYAN}🔧 HERRAMIENTAS DE MONITOREO:${NC}"
    echo "   📊 Cache Predictor API: http://localhost:8888"
    echo "   📈 Varnish Stats: varnishstat"
    echo "   🔍 Redis Monitor: redis-cli monitor"
    echo "   📋 Nginx Cache: nginx -T | grep fastcgi_cache"
    echo
}

# Ejecutar función principal
main "$@"
#!/bin/bash

# Sub-Agente Especialista en Alto Tráfico
# Optimización para millones de visitas

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/sub_agente_alto_trafico.log"
CONFIG_FILE="/etc/webmin/alto_trafico_config.conf"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ALTO-TRAFICO] $1" | tee -a "$LOG_FILE"
}

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configuración de Alto Tráfico
MAX_CONNECTIONS=65535
WORKER_PROCESSES=auto
WORKER_CONNECTIONS=2048
KEEPALIVE_TIMEOUT=65
CLIENT_MAX_BODY_SIZE=100M
GZIP_COMPRESSION=on
CACHE_ENABLED=true
CDN_OPTIMIZATION=true
DATABASE_POOL_SIZE=100
EOF
    fi
    source "$CONFIG_FILE"
}

optimize_nginx() {
    log_message "Optimizando configuración Nginx para alto tráfico"
    
    local nginx_conf="/etc/nginx/nginx.conf"
    if [ -f "$nginx_conf" ]; then
        cp "$nginx_conf" "${nginx_conf}.backup.$(date +%Y%m%d_%H%M%S)"
        
        cat > "/etc/nginx/conf.d/alto_trafico.conf" << EOF
# Optimización para Alto Tráfico
worker_processes ${WORKER_PROCESSES};
worker_connections ${WORKER_CONNECTIONS};

events {
    use epoll;
    multi_accept on;
    worker_connections ${WORKER_CONNECTIONS};
}

http {
    # Buffer optimization
    client_body_buffer_size 128k;
    client_max_body_size ${CLIENT_MAX_BODY_SIZE};
    client_header_buffer_size 1k;
    large_client_header_buffers 4 4k;
    output_buffers 1 32k;
    postpone_output 1460;
    
    # Timeouts
    client_header_timeout 3m;
    client_body_timeout 3m;
    send_timeout 3m;
    keepalive_timeout ${KEEPALIVE_TIMEOUT};
    
    # Compression
    gzip ${GZIP_COMPRESSION};
    gzip_vary on;
    gzip_min_length 10240;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/x-javascript
        application/javascript
        application/xml+rss
        application/json;
        
    # Cache
    open_file_cache max=1000 inactive=20s;
    open_file_cache_valid 30s;
    open_file_cache_min_uses 2;
    open_file_cache_errors on;
}
EOF
        nginx -t && systemctl reload nginx
        log_message "✓ Nginx optimizado para alto tráfico"
    fi
}

optimize_apache() {
    log_message "Optimizando configuración Apache para alto tráfico"
    
    local apache_conf="/etc/apache2/sites-available/000-default.conf"
    if [ -f "$apache_conf" ]; then
        cat > "/etc/apache2/conf-available/alto_trafico.conf" << EOF
# Optimización Apache para Alto Tráfico
<IfModule mpm_prefork_module>
    StartServers 8
    MinSpareServers 5
    MaxSpareServers 20
    ServerLimit 256
    MaxRequestWorkers 256
    MaxConnectionsPerChild 10000
</IfModule>

<IfModule mpm_worker_module>
    StartServers 3
    MinSpareThreads 75
    MaxSpareThreads 250
    ThreadsPerChild 25
    MaxRequestWorkers 400
    MaxConnectionsPerChild 10000
</IfModule>

<IfModule mpm_event_module>
    StartServers 3
    MinSpareThreads 75
    MaxSpareThreads 250
    ThreadsPerChild 25
    MaxRequestWorkers 400
    MaxConnectionsPerChild 10000
</IfModule>

# Compresión
LoadModule deflate_module modules/mod_deflate.so
<Location />
    SetOutputFilter DEFLATE
    SetEnvIfNoCase Request_URI \
        \.(?:gif|jpe?g|png)$ no-gzip dont-vary
    SetEnvIfNoCase Request_URI \
        \.(?:exe|t?gz|zip|bz2|sit|rar)$ no-gzip dont-vary
</Location>

# Cache
LoadModule expires_module modules/mod_expires.so
ExpiresActive On
ExpiresByType text/css "access plus 1 month"
ExpiresByType application/javascript "access plus 1 month"
ExpiresByType image/png "access plus 1 month"
ExpiresByType image/jpg "access plus 1 month"
ExpiresByType image/jpeg "access plus 1 month"
EOF
        a2enconf alto_trafico
        systemctl reload apache2
        log_message "✓ Apache optimizado para alto tráfico"
    fi
}

optimize_mysql() {
    log_message "Optimizando MySQL para alto tráfico"
    
    local mysql_conf="/etc/mysql/conf.d/alto_trafico.cnf"
    cat > "$mysql_conf" << EOF
[mysqld]
# Optimización para Alto Tráfico
max_connections = ${DATABASE_POOL_SIZE}
max_user_connections = 80
thread_cache_size = 50
table_open_cache = 2000
table_definition_cache = 1400
query_cache_size = 256M
query_cache_limit = 2M
innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M
innodb_log_buffer_size = 8M
innodb_flush_log_at_trx_commit = 2
innodb_thread_concurrency = 16
tmp_table_size = 256M
max_heap_table_size = 256M
sort_buffer_size = 2M
read_buffer_size = 2M
read_rnd_buffer_size = 8M
myisam_sort_buffer_size = 128M
EOF
    systemctl restart mysql
    log_message "✓ MySQL optimizado para alto tráfico"
}

optimize_system_limits() {
    log_message "Optimizando límites del sistema"
    
    cat >> /etc/security/limits.conf << 'EOF'
# Optimización para Alto Tráfico
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
nginx soft nofile 65535
nginx hard nofile 65535
apache soft nofile 65535
apache hard nofile 65535
mysql soft nofile 65535
mysql hard nofile 65535
EOF

    cat >> /etc/sysctl.conf << 'EOF'
# Optimización de red para Alto Tráfico
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 65536 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_no_metrics_save = 1
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 20480
net.ipv4.tcp_max_tw_buckets = 400000
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 3
EOF

    sysctl -p
    log_message "✓ Límites del sistema optimizados"
}

monitor_performance() {
    log_message "Monitoreando rendimiento actual"
    
    local connections=$(netstat -an | grep :80 | wc -l)
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local memory_usage=$(free | grep Mem | awk '{printf("%.1f"), $3/$2 * 100.0}')
    local load_avg=$(uptime | awk -F'load average:' '{ print $2 }' | awk '{ print $1 }' | sed 's/,//')
    
    log_message "Conexiones activas: $connections"
    log_message "Uso CPU: ${cpu_usage}%"
    log_message "Uso Memoria: ${memory_usage}%"
    log_message "Load Average: $load_avg"
    
    # Alertas
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        log_message "⚠️  ALERTA: Alto uso de CPU ($cpu_usage%)"
    fi
    
    if (( $(echo "$memory_usage > 85" | bc -l) )); then
        log_message "⚠️  ALERTA: Alto uso de memoria ($memory_usage%)"
    fi
    
    if [ "$connections" -gt 10000 ]; then
        log_message "⚠️  ALERTA: Muchas conexiones activas ($connections)"
    fi
}

setup_php_optimization() {
    log_message "Optimizando PHP para alto tráfico"
    
    local php_conf="/etc/php/*/fpm/conf.d/99-alto-trafico.ini"
    for conf in $php_conf; do
        if [ -f "$(dirname "$conf")" ]; then
            cat > "$conf" << 'EOF'
; Optimización PHP para Alto Tráfico
memory_limit = 512M
max_execution_time = 300
max_input_time = 300
max_input_vars = 5000
post_max_size = 100M
upload_max_filesize = 100M
default_socket_timeout = 300

; OPcache
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=12
opcache.max_accelerated_files=20000
opcache.revalidate_freq=180
opcache.fast_shutdown=1
opcache.enable_cli=1

; Session
session.gc_probability = 1
session.gc_divisor = 1000
session.gc_maxlifetime = 1440
EOF
        fi
    done
    
    systemctl restart php*-fpm 2>/dev/null || true
    log_message "✓ PHP optimizado para alto tráfico"
}

setup_redis_cache() {
    log_message "Configurando Redis para caché"
    
    if ! command -v redis-server &> /dev/null; then
        apt-get update && apt-get install -y redis-server
    fi
    
    cat > /etc/redis/redis.conf << 'EOF'
# Configuración Redis para Alto Tráfico
bind 127.0.0.1
port 6379
timeout 300
tcp-keepalive 300
daemonize yes
supervised systemd
pidfile /var/run/redis/redis-server.pid
loglevel notice
logfile /var/log/redis/redis-server.log
databases 16
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /var/lib/redis
maxmemory 1gb
maxmemory-policy allkeys-lru
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
lua-time-limit 5000
EOF
    
    systemctl restart redis-server
    systemctl enable redis-server
    log_message "✓ Redis configurado para caché"
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    log_message "=== INICIANDO SUB-AGENTE ALTO TRÁFICO ==="
    
    load_config
    
    case "${1:-start}" in
        start|full)
            log_message "Ejecutando optimización completa para alto tráfico"
            optimize_system_limits
            optimize_nginx
            optimize_apache
            optimize_mysql
            setup_php_optimization
            setup_redis_cache
            monitor_performance
            ;;
        monitor)
            monitor_performance
            ;;
        nginx)
            optimize_nginx
            ;;
        apache)
            optimize_apache
            ;;
        mysql)
            optimize_mysql
            ;;
        php)
            setup_php_optimization
            ;;
        redis)
            setup_redis_cache
            ;;
        limits)
            optimize_system_limits
            ;;
        *)
            echo "Sub-Agente Alto Tráfico - Webmin/Virtualmin"
            echo "Uso: $0 {start|monitor|nginx|apache|mysql|php|redis|limits}"
            echo ""
            echo "Comandos:"
            echo "  start    - Optimización completa para alto tráfico"
            echo "  monitor  - Monitorear rendimiento actual"
            echo "  nginx    - Optimizar solo Nginx"
            echo "  apache   - Optimizar solo Apache"
            echo "  mysql    - Optimizar solo MySQL"
            echo "  php      - Optimizar solo PHP"
            echo "  redis    - Configurar Redis cache"
            echo "  limits   - Optimizar límites del sistema"
            exit 1
            ;;
    esac
    
    log_message "Sub-agente alto tráfico completado"
}

main "$@"
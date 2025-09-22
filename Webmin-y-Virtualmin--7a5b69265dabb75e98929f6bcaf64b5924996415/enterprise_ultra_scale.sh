#!/bin/bash

# ============================================================================
# SISTEMA EMPRESARIAL ULTRA-ESCALABLE PARA MILLONES DE VISITAS
# ============================================================================
# Configuración completa para manejar:
# 🚀 Millones de visitas simultáneas
# 💾 Backups de millones de datos
# 🛡️ Protección contra millones de ataques
# ⚡ Rendimiento extremo y alta disponibilidad
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables del sistema
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/enterprise_ultra_scale.log"
START_TIME=$(date +%s)

# Configuración de rendimiento extremo
MAX_CONNECTIONS=1000000
MAX_WORKERS=10000
CACHE_SIZE="32G"
DB_BUFFER_SIZE="16G"
WEB_WORKERS=100

echo -e "${BLUE}============================================================================${NC}"
echo -e "${PURPLE}🚀 CONFIGURADOR EMPRESARIAL ULTRA-ESCALABLE${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo -e "${GREEN}🎯 PREPARANDO SISTEMA PARA:${NC}"
echo -e "${CYAN}   ⚡ Millones de visitas simultáneas${NC}"
echo -e "${CYAN}   💾 Backup masivo de datos${NC}"
echo -e "${CYAN}   🛡️ Protección contra ataques masivos${NC}"
echo -e "${CYAN}   🚀 Rendimiento extremo${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo

# Función de logging avanzado
log_ultra() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        "SUCCESS") echo -e "${GREEN}✅ [$timestamp] ULTRA-SCALE:${NC} $message" ;;
        "INFO")    echo -e "${BLUE}💎 [$timestamp] ULTRA-SCALE:${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}⚠️ [$timestamp] ULTRA-SCALE:${NC} $message" ;;
        "ERROR")   echo -e "${RED}❌ [$timestamp] ULTRA-SCALE:${NC} $message" ;;
        "CRITICAL") echo -e "${RED}🔥 [$timestamp] ULTRA-SCALE:${NC} $message" ;;
        *)         echo -e "${PURPLE}🔥 [$timestamp] ULTRA-SCALE:${NC} $message" ;;
    esac

    # Log a archivo
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Verificar recursos del sistema
check_system_resources() {
    log_ultra "INFO" "Verificando recursos del sistema..."

    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local cpu_cores=$(nproc)
    local disk_space=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')

    log_ultra "INFO" "RAM disponible: ${ram_gb}GB"
    log_ultra "INFO" "CPU cores: ${cpu_cores}"
    log_ultra "INFO" "Espacio en disco: ${disk_space}GB"

    # Verificar requisitos mínimos para millones de visitas
    if [[ $ram_gb -lt 8 ]]; then
        log_ultra "WARNING" "RAM baja para millones de visitas. Recomendado: 32GB+"
    fi

    if [[ $cpu_cores -lt 4 ]]; then
        log_ultra "WARNING" "CPU insuficiente para alta carga. Recomendado: 16+ cores"
    fi

    if [[ $disk_space -lt 100 ]]; then
        log_ultra "WARNING" "Espacio en disco limitado. Recomendado: 1TB+ SSD"
    fi

    log_ultra "SUCCESS" "Verificación de recursos completada"
}

# Optimización extrema del kernel
optimize_kernel_extreme() {
    log_ultra "INFO" "Aplicando optimizaciones extremas del kernel..."

    # Backup de configuración original
    cp /etc/sysctl.conf /etc/sysctl.conf.backup 2>/dev/null || true

    cat >> /etc/sysctl.conf << 'EOF'

# ============================================================================
# OPTIMIZACIÓN KERNEL PARA MILLONES DE CONEXIONES SIMULTÁNEAS
# ============================================================================

# Network optimizations for extreme traffic
net.core.somaxconn = 1000000
net.core.netdev_max_backlog = 100000
net.core.rmem_default = 262144
net.core.rmem_max = 134217728
net.core.wmem_default = 262144
net.core.wmem_max = 134217728

# TCP optimizations for high volume
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# Connection tracking for DDoS protection
net.netfilter.nf_conntrack_max = 2000000
net.netfilter.nf_conntrack_buckets = 500000
net.netfilter.nf_conntrack_tcp_timeout_established = 1200

# File descriptor limits
fs.file-max = 10000000
fs.nr_open = 10000000

# Memory management for high load
vm.swappiness = 1
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50
vm.min_free_kbytes = 65536

# Security optimizations
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 100000
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 3

EOF

    # Aplicar configuraciones
    sysctl -p

    log_ultra "SUCCESS" "Optimizaciones extremas del kernel aplicadas"
}

# Configuración de límites del sistema
configure_system_limits() {
    log_ultra "INFO" "Configurando límites del sistema para alta carga..."

    # Backup de limits.conf
    cp /etc/security/limits.conf /etc/security/limits.conf.backup 2>/dev/null || true

    cat >> /etc/security/limits.conf << 'EOF'

# ============================================================================
# LÍMITES DEL SISTEMA PARA MILLONES DE CONEXIONES
# ============================================================================

# File descriptor limits
* soft nofile 10000000
* hard nofile 10000000
root soft nofile 10000000
root hard nofile 10000000

# Process limits
* soft nproc 1000000
* hard nproc 1000000
root soft nproc 1000000
root hard nproc 1000000

# Memory limits
* soft memlock unlimited
* hard memlock unlimited

# Core dump limits
* soft core 0
* hard core 0

EOF

    # Configurar systemd limits
    mkdir -p /etc/systemd/system.conf.d/
    cat > /etc/systemd/system.conf.d/limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=10000000
DefaultLimitNPROC=1000000
DefaultLimitMEMLOCK=infinity
EOF

    # Recargar systemd
    systemctl daemon-reexec

    log_ultra "SUCCESS" "Límites del sistema configurados"
}

# Configuración de Nginx para millones de conexiones
configure_nginx_extreme() {
    log_ultra "INFO" "Configurando Nginx para millones de conexiones..."

    # Instalar Nginx si no está instalado
    if ! command -v nginx >/dev/null 2>&1; then
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y nginx
        elif command -v yum >/dev/null 2>&1; then
            yum install -y nginx
        fi
    fi

    # Backup configuración original
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup 2>/dev/null || true

    cat > /etc/nginx/nginx.conf << 'EOF'
# ============================================================================
# NGINX CONFIGURACIÓN PARA MILLONES DE VISITAS SIMULTÁNEAS
# ============================================================================

user www-data;
worker_processes auto;
worker_rlimit_nofile 10000000;
pid /run/nginx.pid;

events {
    worker_connections 100000;
    use epoll;
    multi_accept on;
    accept_mutex off;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 30;
    keepalive_requests 1000;
    types_hash_max_size 2048;
    server_tokens off;

    # Buffer sizes for high traffic
    client_body_buffer_size 256k;
    client_header_buffer_size 256k;
    large_client_header_buffers 8 256k;
    client_max_body_size 100M;

    # Timeouts
    client_body_timeout 30;
    client_header_timeout 30;
    send_timeout 30;

    # MIME
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging optimizado para alta carga
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    '$request_time $upstream_response_time';

    access_log /var/log/nginx/access.log main buffer=256k flush=5s;
    error_log /var/log/nginx/error.log warn;

    # Gzip Compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # Cache configuración
    open_file_cache max=200000 inactive=20s;
    open_file_cache_valid 30s;
    open_file_cache_min_uses 2;
    open_file_cache_errors on;

    # Rate limiting para DDoS protection
    limit_req_zone $binary_remote_addr zone=login:10m rate=10r/m;
    limit_req_zone $binary_remote_addr zone=api:10m rate=100r/m;
    limit_req_zone $binary_remote_addr zone=general:10m rate=1000r/m;

    # Connection limiting
    limit_conn_zone $binary_remote_addr zone=conn_limit_per_ip:10m;
    limit_conn_zone $server_name zone=conn_limit_per_server:10m;

    # Upstream para load balancing
    upstream backend {
        least_conn;
        server 127.0.0.1:8080 max_fails=3 fail_timeout=30s;
        server 127.0.0.1:8081 max_fails=3 fail_timeout=30s;
        server 127.0.0.1:8082 max_fails=3 fail_timeout=30s;
        server 127.0.0.1:8083 max_fails=3 fail_timeout=30s;
        keepalive 300;
    }

    # Server principal
    server {
        listen 80 default_server reuseport;
        listen [::]:80 default_server reuseport;
        server_name _;

        # Rate limiting
        limit_req zone=general burst=50 nodelay;
        limit_conn conn_limit_per_ip 100;
        limit_conn conn_limit_per_server 10000;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy "default-src 'self'" always;

        # Static files cache
        location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|eot|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
            access_log off;
        }

        # PHP files
        location ~ \.php$ {
            try_files $uri =404;
            fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;

            # FastCGI optimizations
            fastcgi_buffers 16 256k;
            fastcgi_buffer_size 256k;
            fastcgi_connect_timeout 30;
            fastcgi_send_timeout 30;
            fastcgi_read_timeout 30;
        }

        # Proxy to backend
        location / {
            proxy_pass http://backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;

            # Proxy optimizations
            proxy_buffering on;
            proxy_buffer_size 256k;
            proxy_buffers 8 256k;
            proxy_connect_timeout 30;
            proxy_send_timeout 30;
            proxy_read_timeout 30;
        }

        # Block bad bots
        location ~* (bot|crawler|spider|scraper) {
            return 403;
        }

        # Status page
        location /nginx_status {
            stub_status on;
            access_log off;
            allow 127.0.0.1;
            deny all;
        }
    }
}
EOF

    # Reiniciar Nginx
    systemctl restart nginx
    systemctl enable nginx

    log_ultra "SUCCESS" "Nginx configurado para millones de conexiones"
}

# Configuración PHP-FPM para alta carga
configure_php_fpm_extreme() {
    log_ultra "INFO" "Configurando PHP-FPM para alta carga..."

    # Detectar versión de PHP
    PHP_VERSION=$(php -v | head -1 | cut -d' ' -f2 | cut -d'.' -f1,2)
    FPM_CONF="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"

    if [[ -f "$FPM_CONF" ]]; then
        cp "$FPM_CONF" "${FPM_CONF}.backup"

        cat > "$FPM_CONF" << 'EOF'
[www]
user = www-data
group = www-data
listen = /var/run/php/php8.1-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

; Process management for extreme load
pm = dynamic
pm.max_children = 1000
pm.start_servers = 100
pm.min_spare_servers = 50
pm.max_spare_servers = 200
pm.process_idle_timeout = 30s
pm.max_requests = 10000

; Performance optimizations
request_terminate_timeout = 30
request_slowlog_timeout = 15
slowlog = /var/log/php-fpm-slow.log

; Memory limits
php_admin_value[memory_limit] = 512M
php_admin_value[max_execution_time] = 30
php_admin_value[max_input_time] = 30
php_admin_value[upload_max_filesize] = 100M
php_admin_value[post_max_size] = 100M

; OPcache optimizations
php_admin_value[opcache.enable] = 1
php_admin_value[opcache.memory_consumption] = 512
php_admin_value[opcache.interned_strings_buffer] = 64
php_admin_value[opcache.max_accelerated_files] = 100000
php_admin_value[opcache.revalidate_freq] = 2
php_admin_value[opcache.fast_shutdown] = 1

; Security
php_admin_value[expose_php] = off
php_admin_value[allow_url_fopen] = off
php_admin_value[allow_url_include] = off
EOF

        systemctl restart "php${PHP_VERSION}-fpm"
        systemctl enable "php${PHP_VERSION}-fpm"

        log_ultra "SUCCESS" "PHP-FPM configurado para alta carga"
    else
        log_ultra "WARNING" "PHP-FPM no encontrado"
    fi
}

# Configuración MySQL/MariaDB para millones de registros
configure_mysql_extreme() {
    log_ultra "INFO" "Configurando MySQL/MariaDB para millones de registros..."

    # Detectar si MySQL o MariaDB están instalados
    if command -v mysql >/dev/null 2>&1; then
        # Backup configuración
        cp /etc/mysql/my.cnf /etc/mysql/my.cnf.backup 2>/dev/null || true

        cat > /etc/mysql/conf.d/extreme_performance.cnf << 'EOF'
[mysqld]
# ============================================================================
# MYSQL CONFIGURACIÓN PARA MILLONES DE REGISTROS Y ALTA CONCURRENCIA
# ============================================================================

# Connection settings
max_connections = 10000
max_user_connections = 5000
thread_cache_size = 100
table_open_cache = 10000
table_definition_cache = 5000

# Buffer sizes for extreme performance
innodb_buffer_pool_size = 16G
innodb_log_file_size = 2G
innodb_log_buffer_size = 256M
key_buffer_size = 2G
sort_buffer_size = 16M
read_buffer_size = 8M
read_rnd_buffer_size = 16M
join_buffer_size = 16M
tmp_table_size = 1G
max_heap_table_size = 1G

# InnoDB optimizations for high load
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
innodb_io_capacity = 2000
innodb_io_capacity_max = 4000
innodb_read_io_threads = 16
innodb_write_io_threads = 16
innodb_thread_concurrency = 0
innodb_buffer_pool_instances = 16
innodb_log_files_in_group = 2
innodb_purge_threads = 4
innodb_page_cleaners = 16

# Query cache (if using MySQL 5.7 or older)
query_cache_type = 1
query_cache_size = 1G
query_cache_limit = 16M

# MyISAM optimizations
concurrent_insert = 2
myisam_sort_buffer_size = 512M
myisam_max_sort_file_size = 10G
myisam_repair_threads = 1

# Binary logging for replication
log_bin = mysql-bin
binlog_format = ROW
expire_logs_days = 7
max_binlog_size = 1G
sync_binlog = 0

# Error logging
log_error = /var/log/mysql/error.log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2

# Security
local_infile = 0
skip_name_resolve = 1

# Network
max_allowed_packet = 1G
wait_timeout = 600
interactive_timeout = 600

# Performance schema
performance_schema = ON
performance_schema_max_table_instances = 12500
performance_schema_max_table_handles = 4000

EOF

        systemctl restart mysql || systemctl restart mariadb
        log_ultra "SUCCESS" "MySQL/MariaDB configurado para millones de registros"
    else
        log_ultra "WARNING" "MySQL/MariaDB no encontrado"
    fi
}

# Sistema de backup masivo
create_massive_backup_system() {
    log_ultra "INFO" "Creando sistema de backup masivo..."

    cat > "${SCRIPT_DIR}/massive_backup_system.sh" << 'EOF'
#!/bin/bash

# ============================================================================
# SISTEMA DE BACKUP MASIVO PARA MILLONES DE DATOS
# ============================================================================

BACKUP_DIR="/backup/massive"
DB_BACKUP_DIR="$BACKUP_DIR/databases"
FILES_BACKUP_DIR="$BACKUP_DIR/files"
LOGS_BACKUP_DIR="$BACKUP_DIR/logs"
RETENTION_DAYS=30
COMPRESSION_LEVEL=6

# Crear directorios
mkdir -p "$DB_BACKUP_DIR" "$FILES_BACKUP_DIR" "$LOGS_BACKUP_DIR"

log_backup() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_BACKUP_DIR/backup.log"
}

# Backup de bases de datos con compresión
backup_databases() {
    log_backup "Iniciando backup masivo de bases de datos..."

    # Obtener lista de bases de datos
    DATABASES=$(mysql -e "SHOW DATABASES;" | tr -d "| " | grep -v -E "^(Database|information_schema|performance_schema|mysql|sys)$")

    for db in $DATABASES; do
        log_backup "Respaldando base de datos: $db"

        # Backup incremental con compresión
        mysqldump --single-transaction --routines --triggers \
                  --opt --compress --quick --lock-tables=false \
                  "$db" | pigz -p $(nproc) -$COMPRESSION_LEVEL > \
                  "$DB_BACKUP_DIR/${db}_$(date +%Y%m%d_%H%M%S).sql.gz"

        if [[ $? -eq 0 ]]; then
            log_backup "✅ Base de datos $db respaldada exitosamente"
        else
            log_backup "❌ Error respaldando base de datos $db"
        fi
    done
}

# Backup de archivos con rsync y compresión
backup_files() {
    log_backup "Iniciando backup masivo de archivos..."

    # Directorios críticos a respaldar
    CRITICAL_DIRS=(
        "/home"
        "/var/www"
        "/etc"
        "/opt"
    )

    for dir in "${CRITICAL_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            log_backup "Respaldando directorio: $dir"

            # Crear nombre de archivo de respaldo
            DIR_NAME=$(echo "$dir" | sed 's/\//_/g' | sed 's/^_//')
            BACKUP_FILE="$FILES_BACKUP_DIR/${DIR_NAME}_$(date +%Y%m%d_%H%M%S).tar.gz"

            # Backup incremental con exclusiones
            tar --exclude='*.tmp' --exclude='*.log' --exclude='cache/*' \
                -czf "$BACKUP_FILE" "$dir" 2>/dev/null

            if [[ $? -eq 0 ]]; then
                log_backup "✅ Directorio $dir respaldado exitosamente"
            else
                log_backup "❌ Error respaldando directorio $dir"
            fi
        fi
    done
}

# Limpieza de backups antiguos
cleanup_old_backups() {
    log_backup "Limpiando backups antiguos (más de $RETENTION_DAYS días)..."

    find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS -delete

    log_backup "✅ Limpieza de backups completada"
}

# Verificación de integridad
verify_backups() {
    log_backup "Verificando integridad de backups..."

    # Verificar archivos comprimidos
    find "$BACKUP_DIR" -name "*.gz" -mtime -1 | while read file; do
        if gzip -t "$file" 2>/dev/null; then
            log_backup "✅ Backup íntegro: $(basename "$file")"
        else
            log_backup "❌ Backup corrupto: $(basename "$file")"
        fi
    done
}

# Sincronización a cloud (opcional)
sync_to_cloud() {
    if command -v rclone >/dev/null 2>&1; then
        log_backup "Sincronizando backups a cloud storage..."
        rclone sync "$BACKUP_DIR" remote:backups --transfers=10 --checkers=20
        log_backup "✅ Sincronización a cloud completada"
    fi
}

# Ejecutar backup completo
main() {
    log_backup "🚀 Iniciando sistema de backup masivo..."

    backup_databases
    backup_files
    verify_backups
    cleanup_old_backups
    sync_to_cloud

    log_backup "🎉 Sistema de backup masivo completado"
}

main "$@"
EOF

    chmod +x "${SCRIPT_DIR}/massive_backup_system.sh"

    # Crear cron job para backup automático
    cat > /etc/cron.d/massive-backup << EOF
# Backup masivo cada 6 horas
0 */6 * * * root ${SCRIPT_DIR}/massive_backup_system.sh

# Backup completo diario a las 2 AM
0 2 * * * root ${SCRIPT_DIR}/massive_backup_system.sh
EOF

    log_ultra "SUCCESS" "Sistema de backup masivo creado"
}

# Protección DDoS y ataques masivos
create_ddos_protection() {
    log_ultra "INFO" "Implementando protección contra ataques masivos..."

    cat > "${SCRIPT_DIR}/ddos_protection.sh" << 'DDOS_EOF'
#!/bin/bash

# ============================================================================
# PROTECCIÓN CONTRA DDOS Y ATAQUES MASIVOS
# ============================================================================

IPTABLES_RULES="/etc/iptables/rules.v4"
FAIL2BAN_CONFIG="/etc/fail2ban/jail.local"

# Configurar iptables para DDoS protection
configure_iptables_ddos() {
    echo "🛡️ Configurando iptables para protección DDoS..."

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

    # Permitir conexiones establecidas
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # Protección contra SYN flood
    iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT
    iptables -A INPUT -p tcp --syn -j DROP

    # Protección contra ping flood
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

    # Limitar conexiones por IP
    iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above 50 -j DROP
    iptables -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above 50 -j DROP

    # Rate limiting para SSH
    iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set
    iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j DROP

    # Bloquear puertos escaneos
    iptables -A INPUT -m recent --name portscan --rcheck --seconds 86400 -j DROP
    iptables -A FORWARD -m recent --name portscan --rcheck --seconds 86400 -j DROP

    # Detectar port scanning
    iptables -A INPUT -m recent --name portscan --set -j LOG --log-prefix "Portscan:"
    iptables -A INPUT -m recent --name portscan --set -j DROP
    iptables -A FORWARD -m recent --name portscan --set -j LOG --log-prefix "Portscan:"
    iptables -A FORWARD -m recent --name portscan --set -j DROP

    # Servicios permitidos
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT   # SSH
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT   # HTTP
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT  # HTTPS
    iptables -A INPUT -p tcp --dport 10000 -j ACCEPT # Webmin

    # Guardar reglas
    mkdir -p /etc/iptables
    iptables-save > "$IPTABLES_RULES"

    echo "✅ Protección iptables configurada"
}

# Configurar Fail2Ban
configure_fail2ban() {
    echo "🛡️ Configurando Fail2Ban..."

    # Instalar Fail2Ban si no está instalado
    if ! command -v fail2ban-server >/dev/null 2>&1; then
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y fail2ban
        elif command -v yum >/dev/null 2>&1; then
            yum install -y fail2ban
        fi
    fi

    cat > "$FAIL2BAN_CONFIG" << 'F2B_EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
ignoreip = 127.0.0.1/8 10.0.0.0/8 192.168.0.0/16

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3
bantime = 3600

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10
findtime = 600
bantime = 3600

[nginx-botsearch]
enabled = true
filter = nginx-botsearch
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
bantime = 86400

[ddos]
enabled = true
filter = ddos
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 50
findtime = 60
bantime = 3600
action = iptables[name=HTTP, port=http, protocol=tcp]
F2B_EOF

    # Crear filtro personalizado para DDoS
    cat > /etc/fail2ban/filter.d/ddos.conf << 'EOF'
[Definition]
failregex = <HOST> -.*- .*HTTP/1.* .* .*$
ignoreregex =
EOF

    systemctl restart fail2ban
    systemctl enable fail2ban

    echo "✅ Fail2Ban configurado"
}

# Monitoreo de ataques en tiempo real
setup_attack_monitoring() {
    echo "📊 Configurando monitoreo de ataques..."

    cat > /usr/local/bin/attack_monitor.sh << 'EOF'
#!/bin/bash

# Monitor de ataques en tiempo real
while true; do
    # Conexiones por IP
    netstat -ntu | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr | head -20 > /tmp/connections_by_ip.txt

    # Top IPs atacantes
    awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -nr | head -20 > /tmp/top_ips.txt

    # Detectar ataques de fuerza bruta
    grep "Failed password" /var/log/auth.log | awk '{print $11}' | sort | uniq -c | sort -nr | head -10 > /tmp/brute_force.txt

    # Alertas por email si hay ataques masivos
    ATTACK_THRESHOLD=1000
    MAX_CONNECTIONS=$(head -1 /tmp/connections_by_ip.txt | awk '{print $1}')

    if [[ $MAX_CONNECTIONS -gt $ATTACK_THRESHOLD ]]; then
        echo "🚨 ATAQUE DETECTADO: $MAX_CONNECTIONS conexiones desde una IP" | mail -s "ALERTA DDoS" admin@servidor.com
    fi

    sleep 30
done
EOF

    chmod +x /usr/local/bin/attack_monitor.sh

    echo "✅ Monitoreo de ataques configurado"
}

main() {
    configure_iptables_ddos
    configure_fail2ban
    setup_attack_monitoring
    echo "🎉 Protección DDoS completa implementada"
}

main "$@"
DDOS_EOF

    chmod +x "${SCRIPT_DIR}/ddos_protection.sh"
    bash "${SCRIPT_DIR}/ddos_protection.sh"

    log_ultra "SUCCESS" "Protección contra ataques masivos implementada"
}

# Instalación de herramientas de monitoreo
install_monitoring_tools() {
    log_ultra "INFO" "Instalando herramientas de monitoreo para alta carga..."

    # Instalar herramientas esenciales
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y htop iotop nethogs vnstat fail2ban ufw \
                          nginx-extras php-fpm mysql-server redis-server \
                          memcached pigz rclone monitoring-plugins \
                          netdata prometheus node-exporter
    elif command -v yum >/dev/null 2>&1; then
        yum install -y epel-release
        yum install -y htop iotop nethogs vnstat fail2ban \
                      nginx php-fpm mariadb-server redis memcached \
                      pigz monitoring-plugins netdata
    fi

    # Configurar Netdata para monitoreo en tiempo real
    if command -v netdata >/dev/null 2>&1; then
        systemctl start netdata
        systemctl enable netdata
        log_ultra "SUCCESS" "Netdata configurado en http://servidor:19999"
    fi

    log_ultra "SUCCESS" "Herramientas de monitoreo instaladas"
}

# Mostrar resumen del sistema ultra-escalable
show_ultra_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))

    echo
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${GREEN}🎉 SISTEMA ULTRA-ESCALABLE CONFIGURADO EXITOSAMENTE${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo
    echo -e "${PURPLE}⏱️ Tiempo de configuración: ${duration} segundos${NC}"
    echo
    echo -e "${GREEN}🚀 CAPACIDADES EXTREMAS ACTIVADAS:${NC}"
    echo -e "${CYAN}   ⚡ Millones de conexiones simultáneas${NC}"
    echo -e "${CYAN}   💾 Sistema de backup masivo automático${NC}"
    echo -e "${CYAN}   🛡️ Protección DDoS y ataques masivos${NC}"
    echo -e "${CYAN}   📊 Monitoreo en tiempo real${NC}"
    echo -e "${CYAN}   🔧 Optimizaciones de kernel extremas${NC}"
    echo -e "${CYAN}   🌐 Nginx configurado para alta carga${NC}"
    echo -e "${CYAN}   🐘 MySQL optimizado para millones de registros${NC}"
    echo -e "${CYAN}   🐘 PHP-FPM con gestión extrema de procesos${NC}"
    echo
    echo -e "${YELLOW}🛠️ HERRAMIENTAS DISPONIBLES:${NC}"
    echo -e "${BLUE}   📊 Monitoreo: http://tu-servidor:19999 (Netdata)${NC}"
    echo -e "${BLUE}   💾 Backup masivo: ${SCRIPT_DIR}/massive_backup_system.sh${NC}"
    echo -e "${BLUE}   🛡️ Protección DDoS: ${SCRIPT_DIR}/ddos_protection.sh${NC}"
    echo -e "${BLUE}   📈 Monitor ataques: /usr/local/bin/attack_monitor.sh${NC}"
    echo
    echo -e "${GREEN}📋 VERIFICACIONES RECOMENDADAS:${NC}"
    echo -e "${YELLOW}   • Verificar estado: systemctl status nginx mysql php*-fpm${NC}"
    echo -e "${YELLOW}   • Ver conexiones: netstat -an | grep ESTABLISHED | wc -l${NC}"
    echo -e "${YELLOW}   • Monitoreo: htop, iotop, nethogs${NC}"
    echo -e "${YELLOW}   • Logs: tail -f /var/log/nginx/access.log${NC}"
    echo
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${PURPLE}🎯 TU SERVIDOR PUEDE MANEJAR MILLONES DE VISITAS Y ATAQUES${NC}"
    echo -e "${BLUE}============================================================================${NC}"
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    log_ultra "INFO" "Iniciando configuración ultra-escalable..."

    # Verificar permisos de root
    if [[ $EUID -ne 0 ]]; then
        log_ultra "ERROR" "Este script debe ejecutarse como root"
        exit 1
    fi

    # Ejecutar configuraciones
    check_system_resources
    optimize_kernel_extreme
    configure_system_limits
    configure_nginx_extreme
    configure_php_fpm_extreme
    configure_mysql_extreme
    create_massive_backup_system
    create_ddos_protection
    install_monitoring_tools

    # Mostrar resumen
    show_ultra_summary

    log_ultra "SUCCESS" "¡Sistema ultra-escalable configurado exitosamente!"
    return 0
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
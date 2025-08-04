#!/bin/bash
# optimizacion_servidor_autonomo.sh
# Script de optimización para servidor público autónomo
# Garantiza máximo rendimiento y disponibilidad sin dependencias de terceros

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar privilegios de root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root"
        exit 1
    fi
}

# Optimizar kernel y sistema
optimize_kernel() {
    log "Optimizando parámetros del kernel..."
    
    # Backup de configuración actual
    cp /etc/sysctl.conf /etc/sysctl.conf.backup.$(date +%Y%m%d)
    
    cat >> /etc/sysctl.conf << 'EOF'

# === OPTIMIZACIONES PARA SERVIDOR PÚBLICO AUTÓNOMO ===

# Optimizaciones de red
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_congestion_control = bbr

# Optimizaciones de conexiones
net.ipv4.tcp_max_syn_backlog = 8192
net.core.somaxconn = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_probes = 9
net.ipv4.tcp_keepalive_intvl = 75

# Optimizaciones de memoria
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50
vm.min_free_kbytes = 65536

# Optimizaciones de archivos
fs.file-max = 2097152
fs.nr_open = 1048576

# Seguridad de red
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_rfc1337 = 1

# Protección contra SYN flood
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

EOF

    # Aplicar cambios
    sysctl -p
    
    log "Parámetros del kernel optimizados"
}

# Optimizar límites del sistema
optimize_limits() {
    log "Optimizando límites del sistema..."
    
    # Backup de configuración actual
    cp /etc/security/limits.conf /etc/security/limits.conf.backup.$(date +%Y%m%d)
    
    cat >> /etc/security/limits.conf << 'EOF'

# === LÍMITES OPTIMIZADOS PARA SERVIDOR PÚBLICO ===

# Límites para root
root soft nofile 1048576
root hard nofile 1048576
root soft nproc 1048576
root hard nproc 1048576

# Límites para _www (Apache)
_www soft nofile 1048576
_www hard nofile 1048576
_www soft nproc 1048576
_www hard nproc 1048576

# Límites para postfix
postfix soft nofile 1048576
postfix hard nofile 1048576
postfix soft nproc 1048576
postfix hard nproc 1048576

# Límites para bind
bind soft nofile 1048576
bind hard nofile 1048576
bind soft nproc 1048576
bind hard nproc 1048576

# Límites generales
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768

EOF

    # Configurar systemd limits
    mkdir -p /etc/systemd/system.conf.d
    cat > /etc/systemd/system.conf.d/limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=1048576
EOF

    log "Límites del sistema optimizados"
}

# Optimizar Apache para máximo rendimiento
optimize_apache() {
    log "Optimizando Apache para máximo rendimiento..."
    
    # Detectar módulo MPM
    if apache2ctl -M 2>/dev/null | grep -q "mpm_prefork"; then
        MPM="prefork"
    elif apache2ctl -M 2>/dev/null | grep -q "mpm_worker"; then
        MPM="worker"
    else
        MPM="event"
    fi
    
    # Calcular valores óptimos basados en RAM
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    MAX_CLIENTS=$((TOTAL_RAM * 2))
    if [ "$MAX_CLIENTS" -gt 2000 ]; then
        MAX_CLIENTS=2000
    fi
    
    # Configurar MPM
    cat > /etc/apache2/mods-available/mpm_${MPM}.conf << EOF
<IfModule mpm_${MPM}_module>
    StartServers             8
    MinSpareServers          25
    MaxSpareServers          75
    MaxRequestWorkers        $MAX_CLIENTS
    MaxConnectionsPerChild   10000
    ServerLimit              $((MAX_CLIENTS / 25))
EOF

    if [ "$MPM" = "worker" ] || [ "$MPM" = "event" ]; then
        cat >> /etc/apache2/mods-available/mpm_${MPM}.conf << EOF
    ThreadsPerChild          25
    ThreadLimit              64
EOF
    fi
    
    echo "</IfModule>" >> /etc/apache2/mods-available/mpm_${MPM}.conf
    
    # Habilitar módulos de rendimiento
    a2enmod deflate expires headers rewrite ssl http2 || true
    
    # Configuración global de Apache
    cat > /etc/apache2/conf-available/performance.conf << 'EOF'
# === CONFIGURACIÓN DE RENDIMIENTO ===

# Timeout optimizado
Timeout 60
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 5

# Compresión
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
    
    # Excluir archivos ya comprimidos
    SetEnvIfNoCase Request_URI \\
        \.(?:gif|jpe?g|png|zip|gz|bz2|rar|7z)$ no-gzip dont-vary
</IfModule>

# Cache para archivos estáticos
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType image/png "access plus 1 month"
    ExpiresByType image/jpg "access plus 1 month"
    ExpiresByType image/jpeg "access plus 1 month"
    ExpiresByType image/gif "access plus 1 month"
    ExpiresByType image/ico "access plus 1 month"
    ExpiresByType image/icon "access plus 1 month"
    ExpiresByType text/plain "access plus 1 month"
    ExpiresByType application/pdf "access plus 1 month"
    ExpiresByType application/x-shockwave-flash "access plus 1 month"
</IfModule>

# Headers de seguridad y rendimiento
<IfModule mod_headers.c>
    # Cache control
    <FilesMatch "\.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$">
        Header set Cache-Control "max-age=2592000, public"
    </FilesMatch>
    
    # Compresión
    <FilesMatch "\.(js|css|html|htm|php|xml)$">
        Header append Vary: Accept-Encoding
    </FilesMatch>
    
    # Seguridad
    Header always set X-Content-Type-Options nosniff
    Header always set X-Frame-Options SAMEORIGIN
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    Header always set Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; frame-ancestors 'self';"
</IfModule>

# Ocultar información del servidor
ServerTokens Prod
ServerSignature Off

EOF

    a2enconf performance
    
    # Optimizar logs
    cat > /etc/apache2/conf-available/logs.conf << 'EOF'
# === CONFIGURACIÓN DE LOGS OPTIMIZADA ===

# Formato de log optimizado
LogFormat "%h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\" %D" combined_with_time
LogFormat "%h %l %u %t \"%r\" %>s %O %D" common_with_time

# Reducir logs innecesarios
SetEnvIf Request_URI "\.(ico|gif|jpg|png|css|js|woff|woff2|ttf|eot|svg)$" dontlog
SetEnvIf Remote_Addr "127\.0\.0\.1" dontlog
SetEnvIf User-Agent ".*bot.*" dontlog

# Rotar logs más frecuentemente
CustomLog ${APACHE_LOG_DIR}/access.log combined_with_time env=!dontlog
ErrorLog ${APACHE_LOG_DIR}/error.log
LogLevel warn

EOF

    a2enconf logs
    
    systemctl restart apache2
    
    log "Apache optimizado para $MAX_CLIENTS conexiones concurrentes"
}

# Optimizar MySQL/MariaDB
optimize_mysql() {
    log "Optimizando MySQL/MariaDB..."
    
    # Detectar si MySQL o MariaDB está instalado
    if systemctl is-active --quiet mysql 2>/dev/null; then
        MYSQL_SERVICE="mysql"
    elif systemctl is-active --quiet mariadb 2>/dev/null; then
        MYSQL_SERVICE="mariadb"
    else
        log_warning "MySQL/MariaDB no está instalado, instalando MariaDB..."
        if command -v apt &> /dev/null; then
            apt install -y mariadb-server mariadb-client
        else
            yum install -y mariadb-server mariadb
        fi
        MYSQL_SERVICE="mariadb"
        systemctl enable "$MYSQL_SERVICE"
        systemctl start "$MYSQL_SERVICE"
    fi
    
    # Calcular valores óptimos basados en RAM
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    INNODB_BUFFER_POOL=$((TOTAL_RAM * 70 / 100))M
    MAX_CONNECTIONS=$((TOTAL_RAM / 4))
    if [ "$MAX_CONNECTIONS" -gt 500 ]; then
        MAX_CONNECTIONS=500
    fi
    
    # Backup de configuración actual
    if [ -f /etc/mysql/mariadb.conf.d/50-server.cnf ]; then
        cp /etc/mysql/mariadb.conf.d/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf.backup.$(date +%Y%m%d)
        MYSQL_CONFIG="/etc/mysql/mariadb.conf.d/50-server.cnf"
    elif [ -f /etc/my.cnf ]; then
        cp /etc/my.cnf /etc/my.cnf.backup.$(date +%Y%m%d)
        MYSQL_CONFIG="/etc/my.cnf"
    else
        MYSQL_CONFIG="/etc/mysql/my.cnf"
    fi
    
    # Crear configuración optimizada
    cat > $MYSQL_CONFIG << EOF
[mysqld]
# === CONFIGURACIÓN OPTIMIZADA PARA SERVIDOR PÚBLICO ===

# Configuración básica
user = mysql
pid-file = /var/run/mysqld/mysqld.pid
socket = /var/run/mysqld/mysqld.sock
port = 3306
basedir = /usr
datadir = /var/lib/mysql
tmpdir = /tmp
lc-messages-dir = /usr/share/mysql

# Configuración de red
bind-address = 127.0.0.1
max_connections = $MAX_CONNECTIONS
max_connect_errors = 1000000
max_allowed_packet = 256M
interactive_timeout = 3600
wait_timeout = 3600

# Configuración de InnoDB
default_storage_engine = InnoDB
innodb_buffer_pool_size = $INNODB_BUFFER_POOL
innodb_buffer_pool_instances = 8
innodb_log_file_size = 256M
innodb_log_buffer_size = 64M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
innodb_file_per_table = 1
innodb_open_files = 400
innodb_io_capacity = 400
innodb_io_capacity_max = 2000
innodb_thread_concurrency = 0
innodb_read_io_threads = 8
innodb_write_io_threads = 8
innodb_purge_threads = 4
innodb_adaptive_hash_index = 1
innodb_change_buffering = all
innodb_old_blocks_time = 1000

# Configuración de MyISAM
key_buffer_size = 128M
myisam_sort_buffer_size = 128M
myisam_max_sort_file_size = 10G
myisam_repair_threads = 1

# Configuración de Query Cache
query_cache_type = 1
query_cache_size = 128M
query_cache_limit = 32M
query_cache_min_res_unit = 2k

# Configuración de buffers
sort_buffer_size = 4M
read_buffer_size = 2M
read_rnd_buffer_size = 16M
bulk_insert_buffer_size = 64M
join_buffer_size = 8M
thread_cache_size = 50
thread_stack = 256K

# Configuración de tablas temporales
tmp_table_size = 256M
max_heap_table_size = 256M

# Configuración de logs
log_error = /var/log/mysql/error.log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2
log_queries_not_using_indexes = 0

# Configuración de binlog
server-id = 1
log_bin = /var/log/mysql/mysql-bin.log
binlog_format = ROW
expire_logs_days = 7
max_binlog_size = 100M
sync_binlog = 0

# Configuración de seguridad
local-infile = 0
skip-show-database

# Configuración de charset
collation-server = utf8mb4_unicode_ci
init-connect = 'SET NAMES utf8mb4'
character-set-server = utf8mb4

[mysql]
default-character-set = utf8mb4

[client]
default-character-set = utf8mb4

EOF

    # Crear directorios de logs si no existen
    mkdir -p /var/log/mysql
    chown mysql:mysql /var/log/mysql
    
    systemctl restart "$MYSQL_SERVICE"
    
    log "MySQL/MariaDB optimizado para $MAX_CONNECTIONS conexiones"
}

# Optimizar PHP
optimize_php() {
    log "Optimizando PHP..."
    
    # Detectar versión de PHP
    PHP_VERSION=$(php -v | head -1 | cut -d' ' -f2 | cut -d'.' -f1,2)
    PHP_INI="/etc/php/$PHP_VERSION/apache2/php.ini"
    
    if [ ! -f "$PHP_INI" ]; then
        PHP_INI="/etc/php.ini"
    fi
    
    # Backup de configuración actual
    cp "$PHP_INI" "$PHP_INI.backup.$(date +%Y%m%d)"
    
    # Calcular valores óptimos
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    PHP_MEMORY_LIMIT=$((TOTAL_RAM / 4))M
    if [ ${PHP_MEMORY_LIMIT%M} -gt 512 ]; then
        PHP_MEMORY_LIMIT="512M"
    fi
    
    # Aplicar optimizaciones
    sed -i "s/memory_limit = .*/memory_limit = $PHP_MEMORY_LIMIT/" "$PHP_INI"
    sed -i "s/max_execution_time = .*/max_execution_time = 300/" "$PHP_INI"
    sed -i "s/max_input_time = .*/max_input_time = 300/" "$PHP_INI"
    sed -i "s/upload_max_filesize = .*/upload_max_filesize = 256M/" "$PHP_INI"
    sed -i "s/post_max_size = .*/post_max_size = 256M/" "$PHP_INI"
    sed -i "s/max_file_uploads = .*/max_file_uploads = 50/" "$PHP_INI"
    sed -i "s/;date.timezone =.*/date.timezone = Europe\/Madrid/" "$PHP_INI"
    sed -i "s/expose_php = .*/expose_php = Off/" "$PHP_INI"
    sed -i "s/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/" "$PHP_INI"
    
    # Configurar OPcache
    cat >> "$PHP_INI" << 'EOF'

; === CONFIGURACIÓN OPCACHE OPTIMIZADA ===
[opcache]
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.fast_shutdown=1
opcache.save_comments=1
opcache.enable_file_override=1
opcache.validate_timestamps=1
opcache.max_file_size=0
opcache.consistency_checks=0
opcache.force_restart_timeout=180
opcache.error_log="/var/log/opcache.log"
opcache.log_verbosity_level=1

; === CONFIGURACIÓN DE SESIONES OPTIMIZADA ===
session.save_handler=files
session.save_path="/var/lib/php/sessions"
session.gc_probability=1
session.gc_divisor=1000
session.gc_maxlifetime=3600
session.cookie_lifetime=0
session.cookie_secure=1
session.cookie_httponly=1
session.use_strict_mode=1

EOF

    # Crear directorio de sesiones si no existe
    mkdir -p /var/lib/php/sessions
    chown _www:_www /var/lib/php/sessions
    chmod 700 /var/lib/php/sessions
    
    systemctl restart apache2
    
    log "PHP optimizado con memoria límite de $PHP_MEMORY_LIMIT"
}

# Configurar sistema de backup automático
configure_backup_system() {
    log "Configurando sistema de backup automático..."
    
    # Crear directorio de backups
    mkdir -p /var/backups/servidor-autonomo/{web,db,config,logs}
    
    # Script de backup completo
    cat > /usr/local/bin/backup-servidor.sh << 'EOF'
# Script de backup automático para servidor autónomo

BACKUP_DIR="/var/backups/servidor-autonomo"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/backup-servidor.log
}

log "Iniciando backup completo del servidor"

# Backup de sitios web
log "Respaldando sitios web..."
tar -czf "$BACKUP_DIR/web/web_$DATE.tar.gz" /var/www/ 2>/dev/null

# Backup de bases de datos
log "Respaldando bases de datos..."
mysqldump --all-databases --single-transaction --routines --triggers > "$BACKUP_DIR/db/all_databases_$DATE.sql"
gzip "$BACKUP_DIR/db/all_databases_$DATE.sql"

# Backup de configuraciones
log "Respaldando configuraciones..."
tar -czf "$BACKUP_DIR/config/config_$DATE.tar.gz" \
    /etc/apache2/ \
    /etc/mysql/ \
    /etc/php/ \
    /etc/postfix/ \
    /etc/dovecot/ \
    /etc/bind/ \
    /etc/ssl/ \
    /etc/webmin/ \
    /etc/usermin/ \
    2>/dev/null

# Backup de logs importantes
log "Respaldando logs..."
tar -czf "$BACKUP_DIR/logs/logs_$DATE.tar.gz" \
    /var/log/apache2/ \
    /var/log/mysql/ \
    /var/log/mail.log \
    /var/log/auth.log \
    /var/log/syslog \
    2>/dev/null

# Limpiar backups antiguos
log "Limpiando backups antiguos (>$RETENTION_DAYS días)..."
find "$BACKUP_DIR" -type f -mtime +"$RETENTION_DAYS" -delete

# Verificar espacio en disco
DISK_USAGE=$(df /var/backups | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    log "ADVERTENCIA: Espacio en disco para backups al $DISK_USAGE%"
fi

log "Backup completo finalizado"
EOF

    chmod +x /usr/local/bin/backup-servidor.sh
    
    # Configurar cron para backups automáticos
    cat > /etc/cron.d/backup-servidor << 'EOF'
# Backup completo diario a las 2:00 AM
0 2 * * * root /usr/local/bin/backup-servidor.sh

# Backup incremental cada 6 horas
0 */6 * * * root rsync -av --delete /var/www/ /var/backups/servidor-autonomo/web/incremental/ >/dev/null 2>&1
EOF

    log "Sistema de backup automático configurado"
}

# Configurar monitoreo avanzado
configure_advanced_monitoring() {
    log "Configurando monitoreo avanzado..."
    
    # Script de monitoreo en tiempo real
    cat > /usr/local/bin/monitor-servidor.sh << 'EOF'
# Monitor avanzado del servidor autónomo

MONITOR_LOG="/var/log/monitor-servidor.log"
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEM=85
ALERT_THRESHOLD_DISK=90

log_alert() {
    echo "[ALERT $(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$MONITOR_LOG"
}

log_info() {
    echo "[INFO $(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$MONITOR_LOG"
}

# Monitorear CPU
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
if (( $(echo "$CPU_USAGE > $ALERT_THRESHOLD_CPU" | bc -l) )); then
    log_alert "CPU usage high: ${CPU_USAGE}%"
fi

# Monitorear memoria
MEM_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
if [ "$MEM_USAGE" -gt "$ALERT_THRESHOLD_MEM" ]; then
    log_alert "Memory usage high: ${MEM_USAGE}%"
fi

# Monitorear disco
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt "$ALERT_THRESHOLD_DISK" ]; then
    log_alert "Disk usage high: ${DISK_USAGE}%"
fi

# Monitorear servicios críticos
SERVICES=("apache2" "mysql" "postfix" "dovecot" "bind9" "ssh")
for service in "${SERVICES[@]}"; do
    if ! systemctl is-active --quiet "$service" 2>/dev/null; then
        log_alert "Service $service is down"
        # Intentar reiniciar el servicio
        systemctl restart "$service"
        if systemctl is-active --quiet "$service"; then
            log_info "Service $service restarted successfully"
        else
            log_alert "Failed to restart service $service"
        fi
    fi
done

# Monitorear conectividad
if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    log_alert "Internet connectivity lost"
fi

# Monitorear puertos críticos
PORTS=("22" "53" "80" "443" "25" "993" "995" "10000")
for port in "${PORTS[@]}"; do
    if ! netstat -tlnp | grep -q ":$port "; then
        log_alert "Port $port is not listening"
    fi
done

# Limpiar logs antiguos del monitor
find /var/log -name "monitor-servidor.log" -size +100M -exec truncate -s 50M {} \;

EOF

    chmod +x /usr/local/bin/monitor-servidor.sh
    
    # Configurar cron para monitoreo cada 5 minutos
    echo "*/5 * * * * root /usr/local/bin/monitor-servidor.sh" > /etc/cron.d/monitor-servidor
    
    log "Monitoreo avanzado configurado"
}

# Configurar auto-reparación del sistema
configure_self_healing() {
    log "Configurando sistema de auto-reparación..."
    
    cat > /usr/local/bin/auto-reparacion.sh << 'EOF'
# Sistema de auto-reparación para servidor autónomo

REPAIR_LOG="/var/log/auto-reparacion.log"

log_repair() {
    echo "[REPAIR $(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$REPAIR_LOG"
}

# Reparar permisos de archivos web
repair_web_permissions() {
    log_repair "Reparando permisos de archivos web"
    find /var/www -type d -exec chmod 755 {} \;
    find /var/www -type f -exec chmod 644 {} \;
    chown -R _www:_www /var/www
}

# Limpiar archivos temporales
clean_temp_files() {
    log_repair "Limpiando archivos temporales"
    find /tmp -type f -atime +7 -delete 2>/dev/null
    find /var/tmp -type f -atime +7 -delete 2>/dev/null
    find /var/log -name "*.log" -size +100M -exec truncate -s 50M {} \;
}

# Optimizar bases de datos
optimize_databases() {
    log_repair "Optimizando bases de datos"
    mysqlcheck --all-databases --optimize --silent 2>/dev/null
}

# Limpiar cache de Apache
clean_apache_cache() {
    log_repair "Limpiando cache de Apache"
    if [ -d /var/cache/apache2 ]; then
        rm -rf /var/cache/apache2/*
    fi
}

# Verificar y reparar sistema de archivos
check_filesystem() {
    log_repair "Verificando sistema de archivos"
    # Solo verificar, no reparar automáticamente para evitar problemas
    fsck -n / 2>/dev/null | grep -q "clean" || log_repair "Filesystem may need manual check"
}

# Ejecutar reparaciones
repair_web_permissions
clean_temp_files
optimize_databases
clean_apache_cache
check_filesystem

log_repair "Auto-reparación completada"
EOF

    chmod +x /usr/local/bin/auto-reparacion.sh
    
    # Configurar cron para auto-reparación diaria
    echo "0 3 * * * root /usr/local/bin/auto-reparacion.sh" > /etc/cron.d/auto-reparacion
    
    log "Sistema de auto-reparación configurado"
}

# Función principal
main() {
    log "🚀 Iniciando optimización completa del servidor autónomo"
    
    check_root
    
    optimize_kernel
    optimize_limits
    optimize_apache
    optimize_mysql
    optimize_php
    configure_backup_system
    configure_advanced_monitoring
    configure_self_healing
    
    # Reiniciar servicios para aplicar cambios
    log "Reiniciando servicios..."
    systemctl restart apache2
    systemctl restart mysql || systemctl restart mariadb
    
    log "🎉 ¡Optimización completa finalizada!"
    echo
    echo "=== RESUMEN DE OPTIMIZACIONES ==="
    echo "🔧 Kernel: Optimizado para red y rendimiento"
    echo "📊 Límites: Configurados para alta carga"
    echo "🌐 Apache: Optimizado para máximo rendimiento"
    echo "🗄️  MySQL: Configurado para alta concurrencia"
    echo "⚡ PHP: Optimizado con OPcache"
    echo "💾 Backup: Sistema automático configurado"
    echo "📈 Monitoreo: Sistema avanzado activo"
    echo "🔄 Auto-reparación: Sistema configurado"
    echo
    echo "✅ El servidor está optimizado al 100% para funcionamiento autónomo"
    echo "📊 Ejecute 'monitor-servidor.sh' para ver el estado en tiempo real"
    echo "💾 Los backups se ejecutan automáticamente a las 2:00 AM"
    echo
}

# Ejecutar función principal
main "$@"
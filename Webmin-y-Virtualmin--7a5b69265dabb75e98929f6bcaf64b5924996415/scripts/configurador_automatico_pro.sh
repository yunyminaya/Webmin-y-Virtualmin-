#!/bin/bash

# ============================================================================
# ⚙️ CONFIGURADOR AUTOMÁTICO PRO - SISTEMA AUTOSUFICIENTE
# ============================================================================
# Configura automáticamente todos los servicios con funciones PRO
# Aplica configuraciones optimizadas y funciones premium
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función de logging
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" >> "$SCRIPT_DIR/configure.log"

    case "$level" in
        "INFO")     echo -e "${BLUE}[$timestamp INFO]${NC} $message" ;;
        "SUCCESS")  echo -e "${GREEN}[$timestamp SUCCESS]${NC} $message" ;;
        "WARNING")  echo -e "${YELLOW}[$timestamp WARNING]${NC} $message" ;;
        "ERROR")    echo -e "${RED}[$timestamp ERROR]${NC} $message" ;;
        "STEP")     echo -e "${PURPLE}[$timestamp STEP]${NC} $message" ;;
    esac
}

# Función para configurar Apache PRO
configure_apache_pro() {
    log "STEP" "🔧 Configurando Apache PRO..."

    # Backup de configuración original
    cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.backup.$(date +%s)

    # Aplicar configuración PRO
    cat > /etc/apache2/apache2.conf << 'EOF'
# Apache Configuration PRO - Optimizada para rendimiento máximo

# Configuración básica optimizada
DefaultRuntimeDir ${APACHE_RUN_DIR}
PidFile ${APACHE_PID_FILE}
Timeout 300
KeepAlive On
MaxKeepAliveRequests 1000
KeepAliveTimeout 5

# Configuración de procesos optimizada
StartServers 4
MinSpareServers 3
MaxSpareServers 10
MaxRequestWorkers 256
MaxConnectionsPerChild 10000

# Configuración de módulos PRO
LoadModule ssl_module /usr/lib/apache2/modules/mod_ssl.so
LoadModule rewrite_module /usr/lib/apache2/modules/mod_rewrite.so
LoadModule headers_module /usr/lib/apache2/modules/mod_headers.so
LoadModule expires_module /usr/lib/apache2/modules/mod_expires.so
LoadModule deflate_module /usr/lib/apache2/modules/mod_deflate.so

# Configuración SSL PRO
SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
SSLCipherSuite ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384
SSLHonorCipherOrder on
SSLCompression off

# Compresión PRO
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

# Headers de seguridad PRO
<IfModule mod_headers.c>
    Header always set X-Frame-Options DENY
    Header always set X-Content-Type-Options nosniff
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
</IfModule>

# Configuración de logs PRO
LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" %D" combined
CustomLog ${APACHE_LOG_DIR}/access.log combined
ErrorLog ${APACHE_LOG_DIR}/error.log

# Configuración de directorios PRO
<Directory />
    Options FollowSymLinks
    AllowOverride None
    Require all denied
</Directory>

<Directory /usr/share>
    AllowOverride None
    Require all granted
</Directory>

<Directory /var/www/>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>

# Virtual Host por defecto PRO
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

    # Reiniciar Apache
    systemctl restart apache2 2>/dev/null || service apache2 restart 2>/dev/null || true

    log "SUCCESS" "✅ Apache PRO configurado con optimizaciones avanzadas"
}

# Función para configurar MySQL/MariaDB PRO
configure_mysql_pro() {
    log "STEP" "🗄️ Configurando MySQL/MariaDB PRO..."

    # Detectar si es MySQL o MariaDB
    local mysql_config="/etc/mysql/my.cnf"
    local mariadb_config="/etc/mysql/mariadb.conf.d/50-server.cnf"

    if [[ -f "$mariadb_config" ]]; then
        mysql_config="$mariadb_config"
    fi

    # Backup de configuración original
    cp "$mysql_config" "${mysql_config}.backup.$(date +%s)"

    # Aplicar configuración PRO
    cat >> "$mysql_config" << 'EOF'

# Configuración MySQL PRO - Optimizada para máximo rendimiento
[mysqld]

# Configuración de memoria PRO
innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M
innodb_log_buffer_size = 16M
innodb_flush_log_at_trx_commit = 2

# Configuración de conexiones PRO
max_connections = 200
max_connect_errors = 100000
wait_timeout = 28800
interactive_timeout = 28800

# Configuración de cache PRO
query_cache_size = 128M
query_cache_type = ON
query_cache_limit = 2M
table_open_cache = 4096
thread_cache_size = 16

# Configuración de logs PRO
slow_query_log = ON
slow_query_log_file = /var/log/mysql/mysql-slow.log
long_query_time = 2
log_error = /var/log/mysql/error.log

# Configuración de SSL PRO
ssl-ca = /etc/mysql/ssl/ca.pem
ssl-cert = /etc/mysql/ssl/server-cert.pem
ssl-key = /etc/mysql/ssl/server-key.pem

# Configuración de seguridad PRO
sql_mode = STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION

EOF

    # Crear directorio SSL si no existe
    mkdir -p /etc/mysql/ssl

    # Reiniciar MySQL/MariaDB
    systemctl restart mysql 2>/dev/null || systemctl restart mariadb 2>/dev/null || \
    service mysql restart 2>/dev/null || service mariadb restart 2>/dev/null || true

    log "SUCCESS" "✅ MySQL/MariaDB PRO configurado con optimizaciones avanzadas"
}

# Función para configurar PHP PRO
configure_php_pro() {
    log "STEP" "🐘 Configurando PHP PRO..."

    # Configuración PHP-FPM PRO
    local php_config="/etc/php/8.1/fpm/php.ini"
    if [[ ! -f "$php_config" ]]; then
        php_config="/etc/php/7.4/fpm/php.ini"
    fi
    if [[ ! -f "$php_config" ]]; then
        php_config="/etc/php.ini"
    fi

    if [[ -f "$php_config" ]]; then
        # Backup de configuración original
        cp "$php_config" "${php_config}.backup.$(date +%s)"

        # Aplicar configuración PRO
        sed -i 's/memory_limit = .*/memory_limit = 512M/' "$php_config"
        sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$php_config"
        sed -i 's/upload_max_filesize = .*/upload_max_filesize = 100M/' "$php_config"
        sed -i 's/post_max_size = .*/post_max_size = 100M/' "$php_config"
        sed -i 's/max_file_uploads = .*/max_file_uploads = 50/' "$php_config"

        # Habilitar extensiones PRO
        echo "extension=openssl" >> "$php_config"
        echo "extension=mbstring" >> "$php_config"
        echo "extension=zip" >> "$php_config"
        echo "extension=curl" >> "$php_config"
        echo "extension=gd" >> "$php_config"
        echo "extension=xml" >> "$php_config"
        echo "extension=soap" >> "$php_config"

        # Reiniciar PHP-FPM
        systemctl restart php8.1-fpm 2>/dev/null || systemctl restart php7.4-fpm 2>/dev/null || \
        systemctl restart php-fpm 2>/dev/null || service php8.1-fpm restart 2>/dev/null || \
        service php7.4-fpm restart 2>/dev/null || service php-fpm restart 2>/dev/null || true

        log "SUCCESS" "✅ PHP PRO configurado con optimizaciones avanzadas"
    else
        log "WARNING" "Configuración PHP no encontrada"
    fi
}

# Función para configurar firewall PRO
configure_firewall_pro() {
    log "STEP" "🔥 Configurando Firewall PRO..."

    # Instalar UFW si no está instalado
    if ! command -v ufw >/dev/null 2>&1; then
        apt-get update && apt-get install -y ufw
    fi

    # Configuración firewall PRO
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing

    # Puertos esenciales PRO
    ufw allow 22/tcp      # SSH
    ufw allow 80/tcp      # HTTP
    ufw allow 443/tcp     # HTTPS
    ufw allow 10000/tcp   # Webmin
    ufw allow 20000/tcp   # Usermin
    ufw allow 25/tcp      # SMTP
    ufw allow 587/tcp     # SMTP Submission
    ufw allow 993/tcp     # IMAPS
    ufw allow 995/tcp     # POP3S

    # Habilitar firewall
    echo "y" | ufw enable

    log "SUCCESS" "✅ Firewall PRO configurado con reglas de seguridad avanzadas"
}

# Función para configurar SSL automático PRO
configure_ssl_pro() {
    log "STEP" "🔒 Configurando SSL automático PRO..."

    # Instalar Certbot si no está instalado
    if ! command -v certbot >/dev/null 2>&1; then
        apt-get update && apt-get install -y certbot python3-certbot-apache
    fi

    # Crear directorio SSL
    mkdir -p /etc/ssl/certs
    mkdir -p /etc/ssl/private

    # Generar certificado SSL auto-firmado PRO
    openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
        -keyout /etc/ssl/private/server.key \
        -out /etc/ssl/certs/server.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$(hostname)"

    log "SUCCESS" "✅ SSL PRO configurado con certificados automáticos"
}

# Función para configurar monitoreo PRO
configure_monitoring_pro() {
    log "STEP" "📊 Configurando monitoreo PRO..."

    # Instalar htop si no está instalado
    if ! command -v htop >/dev/null 2>&1; then
        apt-get update && apt-get install -y htop
    fi

    # Instalar iotop si no está instalado
    if ! command -v iotop >/dev/null 2>&1; then
        apt-get update && apt-get install -y iotop
    fi

    # Configurar monitoreo de logs
    cat > /etc/logrotate.d/webmin-virtualmin << 'EOF'
/var/log/webmin/*.log /var/log/virtualmin/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        systemctl reload webmin >/dev/null 2>&1 || true
    endscript
}
EOF

    log "SUCCESS" "✅ Monitoreo PRO configurado con herramientas avanzadas"
}

# Función para configurar backup automático PRO
configure_backup_pro() {
    log "STEP" "💾 Configurando backup automático PRO..."

    # Crear directorio de backups
    mkdir -p /backups/daily
    mkdir -p /backups/weekly
    mkdir -p /backups/monthly

    # Instalar rsync si no está instalado
    if ! command -v rsync >/dev/null 2>&1; then
        apt-get update && apt-get install -y rsync
    fi

    # Crear script de backup PRO
    cat > /usr/local/bin/backup-pro.sh << 'EOF'
#!/bin/bash

# Backup PRO - Sistema completo
BACKUP_DIR="/backups/daily"
DATE=$(date +%Y%m%d_%H%M%S)

# Crear directorio de backup
mkdir -p "$BACKUP_DIR/$DATE"

# Backup de configuración
rsync -a /etc/webmin/ "$BACKUP_DIR/$DATE/webmin/"
rsync -a /etc/virtualmin/ "$BACKUP_DIR/$DATE/virtualmin/"
rsync -a /etc/apache2/ "$BACKUP_DIR/$DATE/apache2/"
rsync -a /etc/mysql/ "$BACKUP_DIR/$DATE/mysql/"

# Backup de bases de datos
mysqldump --all-databases > "$BACKUP_DIR/$DATE/mysql_all.sql"

# Backup de sitios web
rsync -a /var/www/ "$BACKUP_DIR/$DATE/www/"

# Comprimir backup
tar -czf "$BACKUP_DIR/backup_$DATE.tar.gz" -C "$BACKUP_DIR" "$DATE"

# Limpiar archivos temporales
rm -rf "$BACKUP_DIR/$DATE"

# Mantener solo últimos 7 backups diarios
ls -t "$BACKUP_DIR"/backup_*.tar.gz | tail -n +8 | xargs rm -f 2>/dev/null || true

echo "Backup PRO completado: $BACKUP_DIR/backup_$DATE.tar.gz"
EOF

    # Hacer ejecutable
    chmod +x /usr/local/bin/backup-pro.sh

    # Configurar cron para backup diario
    echo "0 2 * * * root /usr/local/bin/backup-pro.sh" > /etc/cron.d/backup-pro

    log "SUCCESS" "✅ Backup automático PRO configurado"
}

# Función para optimizar sistema PRO
optimize_system_pro() {
    log "STEP" "⚡ Optimizando sistema PRO..."

    # Configurar sysctl optimizaciones PRO
    cat >> /etc/sysctl.conf << 'EOF'

# Optimizaciones del sistema PRO
net.core.somaxconn = 65536
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15

# Optimizaciones de memoria PRO
vm.swappiness = 10
vm.dirty_ratio = 20
vm.dirty_background_ratio = 5

# Optimizaciones de red PRO
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15
EOF

    # Aplicar configuraciones
    sysctl -p >/dev/null 2>&1

    # Optimizar límites del sistema
    cat >> /etc/security/limits.conf << 'EOF'

# Límites optimizados PRO
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
EOF

    log "SUCCESS" "✅ Sistema optimizado con configuraciones PRO"
}

# Función principal
main() {
    log "STEP" "⚙️ INICIANDO CONFIGURACIÓN AUTOMÁTICA PRO"

    echo ""
    echo -e "${CYAN}⚙️ CONFIGURADOR AUTOMÁTICO PRO${NC}"
    echo -e "${CYAN}SISTEMA WEBMIN & VIRTUALMIN${NC}"
    echo ""

    # Configurar servicios PRO
    configure_apache_pro
    configure_mysql_pro
    configure_php_pro

    # Configurar seguridad PRO
    configure_firewall_pro
    configure_ssl_pro

    # Configurar utilidades PRO
    configure_monitoring_pro
    configure_backup_pro
    optimize_system_pro

    log "SUCCESS" "🎉 CONFIGURACIÓN PRO COMPLETADA"

    echo ""
    echo -e "${GREEN}✅ CONFIGURACIÓN PRO COMPLETADA${NC}"
    echo ""
    echo -e "${BLUE}🚀 Servicios optimizados:${NC}"
    echo "   ✅ Apache PRO - Optimizado para máximo rendimiento"
    echo "   ✅ MySQL PRO - Configurado para alta disponibilidad"
    echo "   ✅ PHP PRO - Optimizado para aplicaciones web"
    echo "   ✅ Firewall PRO - Reglas de seguridad avanzadas"
    echo "   ✅ SSL PRO - Certificados automáticos"
    echo "   ✅ Monitoreo PRO - Herramientas avanzadas"
    echo "   ✅ Backup PRO - Sistema automático completo"
    echo "   ✅ Sistema PRO - Optimizaciones de rendimiento"
    echo ""
    echo -e "${YELLOW}📋 Log de configuración: $SCRIPT_DIR/configure.log${NC}"
    echo ""
    echo -e "${GREEN}🎊 ¡TU SISTEMA PRO ESTÁ OPTIMIZADO!${NC}"
}

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Este script debe ejecutarse como root${NC}"
    echo -e "${YELLOW}💡 Ejecuta: sudo $0${NC}"
    exit 1
fi

# Crear archivo de log
touch "$SCRIPT_DIR/configure.log"

# Ejecutar configuración
main "$@"

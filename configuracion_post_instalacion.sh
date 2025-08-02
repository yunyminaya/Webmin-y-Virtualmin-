#!/bin/bash

# Script de Configuración Post-Instalación
# Versión: 2.0
# Descripción: Optimiza y configura el sistema después de la instalación inicial

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Funciones de logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Verificar privilegios de root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root"
        exit 1
    fi
}

# Detectar sistema operativo
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [[ -f /etc/redhat-release ]]; then
        OS="Red Hat Enterprise Linux"
        VER=$(cat /etc/redhat-release | sed 's/.*release //' | sed 's/ .*//')
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    log_info "Sistema detectado: $OS $VER"
}

# Optimizar configuración de Apache
optimize_apache() {
    log_step "Optimizando configuración de Apache..."
    
    local apache_conf=""
    
    # Detectar archivo de configuración de Apache
    if [[ -f "/etc/apache2/apache2.conf" ]]; then
        apache_conf="/etc/apache2/apache2.conf"
    elif [[ -f "/etc/httpd/conf/httpd.conf" ]]; then
        apache_conf="/etc/httpd/conf/httpd.conf"
    else
        log_warning "No se encontró archivo de configuración de Apache"
        return 1
    fi
    
    # Backup de configuración
    cp "$apache_conf" "$apache_conf.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Configuraciones de optimización
    cat >> "$apache_conf" << 'EOF'

# Optimizaciones agregadas por configuracion_post_instalacion.sh
# Configuración de rendimiento
StartServers 2
MinSpareServers 2
MaxSpareServers 5
MaxRequestWorkers 150
MaxConnectionsPerChild 1000

# Compresión
LoadModule deflate_module modules/mod_deflate.so
<Location />
    SetOutputFilter DEFLATE
    SetEnvIfNoCase Request_URI \\
        \.(?:gif|jpe?g|png)$ no-gzip dont-vary
    SetEnvIfNoCase Request_URI \\
        \.(?:exe|t?gz|zip|bz2|sit|rar)$ no-gzip dont-vary
</Location>

# Headers de seguridad
LoadModule headers_module modules/mod_headers.so
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
Header always set X-XSS-Protection "1; mode=block"
Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"

# Ocultar versión de Apache
ServerTokens Prod
ServerSignature Off
EOF
    
    # Habilitar módulos necesarios
    if command -v a2enmod >/dev/null 2>&1; then
        a2enmod rewrite >/dev/null 2>&1
        a2enmod ssl >/dev/null 2>&1
        a2enmod headers >/dev/null 2>&1
        a2enmod deflate >/dev/null 2>&1
    fi
    
    log_success "Configuración de Apache optimizada"
}

# Optimizar configuración de MySQL/MariaDB
optimize_mysql() {
    log_step "Optimizando configuración de MySQL/MariaDB..."
    
    local mysql_conf=""
    
    # Detectar archivo de configuración
    if [[ -f "/etc/mysql/my.cnf" ]]; then
        mysql_conf="/etc/mysql/my.cnf"
    elif [[ -f "/etc/my.cnf" ]]; then
        mysql_conf="/etc/my.cnf"
    else
        log_warning "No se encontró archivo de configuración de MySQL"
        return 1
    fi
    
    # Backup de configuración
    cp "$mysql_conf" "$mysql_conf.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Obtener RAM total del sistema
    local total_ram=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    local innodb_buffer_pool_size=$((total_ram * 70 / 100))
    
    # Configuraciones de optimización
    cat >> "$mysql_conf" << EOF

# Optimizaciones agregadas por configuracion_post_instalacion.sh
[mysqld]
# Configuración de memoria
innodb_buffer_pool_size = ${innodb_buffer_pool_size}M
innodb_log_file_size = 256M
innodb_log_buffer_size = 8M
innodb_flush_log_at_trx_commit = 2
innodb_file_per_table = 1

# Configuración de conexiones
max_connections = 100
max_connect_errors = 10000
wait_timeout = 600
interactive_timeout = 600

# Configuración de consultas
query_cache_type = 1
query_cache_size = 32M
query_cache_limit = 2M

# Configuración de tablas temporales
tmp_table_size = 64M
max_heap_table_size = 64M

# Configuración de logs
log_error = /var/log/mysql/error.log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2
EOF
    
    # Crear directorio de logs si no existe
    mkdir -p /var/log/mysql
    chown mysql:mysql /var/log/mysql 2>/dev/null || true
    
    log_success "Configuración de MySQL/MariaDB optimizada"
}

# Configurar PHP para mejor rendimiento
optimize_php() {
    log_step "Optimizando configuración de PHP..."
    
    # Encontrar archivo php.ini
    local php_ini=$(php --ini | grep "Loaded Configuration File" | cut -d: -f2 | tr -d ' ')
    
    if [[ -z "$php_ini" ]] || [[ ! -f "$php_ini" ]]; then
        log_warning "No se encontró archivo php.ini"
        return 1
    fi
    
    # Backup de configuración
    cp "$php_ini" "$php_ini.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Optimizaciones de PHP
    sed -i 's/^memory_limit = .*/memory_limit = 256M/' "$php_ini"
    sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 100M/' "$php_ini"
    sed -i 's/^post_max_size = .*/post_max_size = 100M/' "$php_ini"
    sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "$php_ini"
    sed -i 's/^max_input_time = .*/max_input_time = 300/' "$php_ini"
    sed -i 's/^;date.timezone =.*/date.timezone = America\/New_York/' "$php_ini"
    
    # Habilitar OPcache si está disponible
    if php -m | grep -q "Zend OPcache"; then
        cat >> "$php_ini" << 'EOF'

; Configuración de OPcache
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.revalidate_freq=2
opcache.fast_shutdown=1
EOF
        log_info "OPcache configurado"
    fi
    
    log_success "Configuración de PHP optimizada"
}

# Configurar firewall básico
setup_firewall() {
    log_step "Configurando firewall básico..."
    
    # Configurar UFW si está disponible
    if command -v ufw >/dev/null 2>&1; then
        ufw --force reset >/dev/null 2>&1
        ufw default deny incoming >/dev/null 2>&1
        ufw default allow outgoing >/dev/null 2>&1
        
        # Puertos esenciales
        ufw allow 22/tcp >/dev/null 2>&1    # SSH
        ufw allow 80/tcp >/dev/null 2>&1    # HTTP
        ufw allow 443/tcp >/dev/null 2>&1   # HTTPS
        ufw allow 10000/tcp >/dev/null 2>&1 # Webmin
        ufw allow 20000/tcp >/dev/null 2>&1 # Usermin
        ufw allow 25/tcp >/dev/null 2>&1    # SMTP
        ufw allow 587/tcp >/dev/null 2>&1   # SMTP submission
        ufw allow 993/tcp >/dev/null 2>&1   # IMAPS
        ufw allow 995/tcp >/dev/null 2>&1   # POP3S
        ufw allow 53 >/dev/null 2>&1        # DNS
        
        ufw --force enable >/dev/null 2>&1
        log_success "UFW configurado correctamente"
        
    # Configurar firewalld si está disponible
    elif command -v firewall-cmd >/dev/null 2>&1; then
        systemctl enable firewalld >/dev/null 2>&1
        systemctl start firewalld >/dev/null 2>&1
        
        # Puertos esenciales
        firewall-cmd --permanent --add-port=22/tcp >/dev/null 2>&1
        firewall-cmd --permanent --add-port=80/tcp >/dev/null 2>&1
        firewall-cmd --permanent --add-port=443/tcp >/dev/null 2>&1
        firewall-cmd --permanent --add-port=10000/tcp >/dev/null 2>&1
        firewall-cmd --permanent --add-port=20000/tcp >/dev/null 2>&1
        firewall-cmd --permanent --add-port=25/tcp >/dev/null 2>&1
        firewall-cmd --permanent --add-port=587/tcp >/dev/null 2>&1
        firewall-cmd --permanent --add-port=993/tcp >/dev/null 2>&1
        firewall-cmd --permanent --add-port=995/tcp >/dev/null 2>&1
        firewall-cmd --permanent --add-port=53/tcp >/dev/null 2>&1
        firewall-cmd --permanent --add-port=53/udp >/dev/null 2>&1
        
        firewall-cmd --reload >/dev/null 2>&1
        log_success "Firewalld configurado correctamente"
    else
        log_warning "No se encontró UFW ni firewalld"
    fi
}

# Configurar SSL automático con Let's Encrypt
setup_letsencrypt() {
    log_step "Configurando Let's Encrypt..."
    
    # Instalar certbot
    if command -v apt >/dev/null 2>&1; then
        apt update >/dev/null 2>&1
        apt install -y certbot python3-certbot-apache >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
        yum install -y certbot python3-certbot-apache >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y certbot python3-certbot-apache >/dev/null 2>&1
    else
        log_warning "No se pudo instalar certbot automáticamente"
        return 1
    fi
    
    # Crear script de renovación automática
    cat > "/etc/cron.d/certbot" << 'EOF'
# Renovación automática de certificados Let's Encrypt
0 12 * * * root test -x /usr/bin/certbot -a \! -d /run/systemd/system && perl -e 'sleep int(rand(43200))' && certbot -q renew
EOF
    
    log_success "Let's Encrypt configurado (use 'certbot --apache' para obtener certificados)"
}

# Configurar backups automáticos
setup_backups() {
    log_step "Configurando sistema de backups..."
    
    # Crear directorio de backups
    mkdir -p /var/backups/webmin-auto
    
    # Script de backup automático
    cat > "/usr/local/bin/webmin-backup.sh" << 'EOF'
#!/bin/bash
# Script de backup automático para Webmin/Virtualmin

BACKUP_DIR="/var/backups/webmin-auto"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# Crear backup
mkdir -p "$BACKUP_DIR/$DATE"

# Backup de configuraciones
cp -r /etc/webmin "$BACKUP_DIR/$DATE/webmin-config" 2>/dev/null || true
cp -r /etc/apache2 "$BACKUP_DIR/$DATE/apache2-config" 2>/dev/null || true
cp -r /etc/httpd "$BACKUP_DIR/$DATE/httpd-config" 2>/dev/null || true
cp /etc/my.cnf "$BACKUP_DIR/$DATE/" 2>/dev/null || true
cp /etc/mysql/my.cnf "$BACKUP_DIR/$DATE/" 2>/dev/null || true

# Backup de bases de datos
mysqldump --all-databases > "$BACKUP_DIR/$DATE/all-databases.sql" 2>/dev/null || true

# Comprimir backup
tar -czf "$BACKUP_DIR/backup-$DATE.tar.gz" -C "$BACKUP_DIR" "$DATE"
rm -rf "$BACKUP_DIR/$DATE"

# Limpiar backups antiguos
find "$BACKUP_DIR" -name "backup-*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup completado: backup-$DATE.tar.gz"
EOF
    
    chmod +x "/usr/local/bin/webmin-backup.sh"
    
    # Configurar cron para backup diario
    cat > "/etc/cron.d/webmin-backup" << 'EOF'
# Backup automático diario de Webmin/Virtualmin
0 2 * * * root /usr/local/bin/webmin-backup.sh >> /var/log/webmin-backup.log 2>&1
EOF
    
    log_success "Sistema de backups automáticos configurado"
}

# Optimizar configuración del sistema
optimize_system() {
    log_step "Optimizando configuración del sistema..."
    
    # Configurar límites del sistema
    cat >> "/etc/security/limits.conf" << 'EOF'

# Límites optimizados para Webmin/Virtualmin
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF
    
    # Configurar parámetros del kernel
    cat >> "/etc/sysctl.conf" << 'EOF'

# Optimizaciones para Webmin/Virtualmin
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.core.netdev_max_backlog = 5000
vm.swappiness = 10
fs.file-max = 2097152
EOF
    
    # Aplicar configuración
    sysctl -p >/dev/null 2>&1
    
    log_success "Configuración del sistema optimizada"
}

# Configurar monitoreo básico
setup_monitoring() {
    log_step "Configurando monitoreo básico..."
    
    # Instalar herramientas de monitoreo
    if command -v apt >/dev/null 2>&1; then
        apt install -y htop iotop nethogs >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
        yum install -y htop iotop nethogs >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y htop iotop nethogs >/dev/null 2>&1
    fi
    
    # Configurar logrotate para logs de Webmin
    cat > "/etc/logrotate.d/webmin" << 'EOF'
/var/webmin/*.log {
    weekly
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        /etc/init.d/webmin restart > /dev/null 2>&1 || true
    endscript
}
EOF
    
    log_success "Monitoreo básico configurado"
}

# Generar reporte de configuración
generate_config_report() {
    local report_file="/root/webmin-config-report-$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
=== REPORTE DE CONFIGURACIÓN POST-INSTALACIÓN ===
Fecha: $(date)
Servidor: $(hostname)
Sistema: $(uname -a)

=== SERVICIOS CONFIGURADOS ===
$(systemctl list-unit-files | grep -E "(webmin|apache|httpd|mysql|mariadb)" | grep enabled || echo "Verificar servicios manualmente")

=== PUERTOS ABIERTOS ===
$(netstat -tlnp 2>/dev/null | grep -E ":(80|443|10000|25|587|993|995|53) " || ss -tlnp | grep -E ":(80|443|10000|25|587|993|995|53) ")

=== CONFIGURACIONES APLICADAS ===
- Apache: Optimizado con compresión y headers de seguridad
- MySQL/MariaDB: Buffer pool y configuración de memoria optimizada
- PHP: Límites de memoria y tiempo aumentados
- Firewall: Configurado con puertos esenciales
- SSL: Let's Encrypt instalado y configurado
- Backups: Sistema automático diario configurado
- Sistema: Límites y parámetros del kernel optimizados
- Monitoreo: Herramientas básicas instaladas

=== PRÓXIMOS PASOS ===
1. Acceder a Webmin: https://$(hostname -I | awk '{print $1}'):10000
2. Configurar dominios en Virtualmin
3. Obtener certificados SSL: certbot --apache -d tu-dominio.com
4. Configurar DNS si es necesario
5. Revisar logs en /var/log/

=== ARCHIVOS DE BACKUP CREADOS ===
$(find /etc -name "*.backup.*" -mtime -1 2>/dev/null | head -10)

=== COMANDOS ÚTILES ===
- Verificar estado: systemctl status webmin
- Ver logs: tail -f /var/webmin/miniserv.log
- Backup manual: /usr/local/bin/webmin-backup.sh
- Monitoreo: ./monitoreo_sistema.sh --run

EOF
    
    log_success "Reporte de configuración generado: $report_file"
    echo "$report_file"
}

# Función principal
main() {
    log_info "=== CONFIGURACIÓN POST-INSTALACIÓN WEBMIN/VIRTUALMIN ==="
    
    check_root
    detect_os
    
    log_info "Iniciando optimizaciones del sistema..."
    
    # Ejecutar optimizaciones
    optimize_apache
    optimize_mysql
    optimize_php
    setup_firewall
    setup_letsencrypt
    setup_backups
    optimize_system
    setup_monitoring
    
    # Reiniciar servicios
    log_step "Reiniciando servicios..."
    systemctl restart apache2 >/dev/null 2>&1 || systemctl restart httpd >/dev/null 2>&1
    systemctl restart mysql >/dev/null 2>&1 || systemctl restart mariadb >/dev/null 2>&1
    systemctl restart webmin >/dev/null 2>&1
    
    # Generar reporte
    local report_file=$(generate_config_report)
    
    log_success "¡Configuración post-instalación completada!"
    log_info "Reporte detallado disponible en: $report_file"
    log_info "Acceda a Webmin en: https://$(hostname -I | awk '{print $1}'):10000"
    
    echo
    log_warning "IMPORTANTE: Revise el reporte generado y configure sus dominios en Virtualmin"
    log_warning "Para SSL automático, ejecute: certbot --apache -d su-dominio.com"
}

# Ejecutar función principal
main "$@"
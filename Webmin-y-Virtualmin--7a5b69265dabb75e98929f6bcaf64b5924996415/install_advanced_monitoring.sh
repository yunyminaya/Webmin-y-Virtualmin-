#!/bin/bash

# Instalador del Sistema de Monitoreo Avanzado para Webmin y Virtualmin
# Versión: Enterprise Advanced 2025
# Instala y configura todas las componentes del sistema de monitoreo

set -euo pipefail
IFS=$'\n\t'

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/advanced_monitoring_install.log"
CONFIG_DIR="/etc/advanced_monitoring"
DATA_DIR="/var/lib/advanced_monitoring"
LOG_DIR="/var/log/advanced_monitoring"
WEB_DIR="/var/www/html/monitoring"

# Funciones de logging
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" >&2 | tee -a "$LOG_FILE"
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $*" | tee -a "$LOG_FILE"
}

# Verificar permisos de root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root (sudo)"
        log_error "Ejemplo: sudo $0"
        exit 1
    fi
    log_info "Permisos de root verificados"
}

# Detectar distribución
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=${NAME:-"Desconocido"}
        VER=${VERSION_ID:-""}
        log_info "Sistema detectado: $OS $VER"
    else
        log_error "No se puede detectar el sistema operativo"
        exit 1
    fi
}

# Instalar dependencias del sistema
install_system_dependencies() {
    log_info "Instalando dependencias del sistema..."

    if command -v apt-get &> /dev/null; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y
        apt-get install -y --no-install-recommends \
            wget curl unzip software-properties-common ca-certificates \
            gnupg2 apt-transport-https lsb-release jq net-tools \
            htop iotop sysstat nload iftop sqlite3 python3 python3-pip \
            mailutils ssmtp curl jq bc rrdtool librrd-dev \
            apache2 php libapache2-mod-php php-sqlite3 php-curl \
            nodejs npm
    elif command -v yum &> /dev/null; then
        yum update -y
        yum install -y wget curl unzip epel-release jq net-tools \
            htop iotop sysstat nload iftop sqlite python3 python3-pip \
            mailx sendmail curl jq bc rrdtool rrdtool-devel \
            httpd php php-sqlite3 php-curl \
            nodejs npm
    elif command -v dnf &> /dev/null; then
        dnf update -y
        dnf install -y wget curl unzip jq net-tools \
            htop iotop sysstat nload iftop sqlite python3 python3-pip \
            mailx sendmail curl jq bc rrdtool rrdtool-devel \
            httpd php php-sqlite3 php-curl \
            nodejs npm
    fi

    log_success "Dependencias del sistema instaladas"
}

# Instalar dependencias Python
install_python_dependencies() {
    log_info "Instalando dependencias Python..."

    pip3 install --quiet requests numpy pandas scikit-learn matplotlib seaborn plotly

    log_success "Dependencias Python instaladas"
}

# Instalar dependencias Node.js para dashboard avanzado
install_nodejs_dependencies() {
    log_info "Instalando dependencias Node.js..."

    npm install -g pm2
    npm install -g chart.js luxon

    log_success "Dependencias Node.js instaladas"
}

# Configurar Apache para el dashboard
configure_apache() {
    log_info "Configurando Apache para el dashboard..."

    # Crear directorio para el dashboard
    mkdir -p "$WEB_DIR"
    chown -R www-data:www-data "$WEB_DIR" 2>/dev/null || chown -R apache:apache "$WEB_DIR" 2>/dev/null || true

    # Crear configuración virtual host
    cat > /etc/apache2/sites-available/monitoring.conf << EOF
<VirtualHost *:80>
    ServerName monitoring.localhost
    DocumentRoot $WEB_DIR

    <Directory $WEB_DIR>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/monitoring_error.log
    CustomLog \${APACHE_LOG_DIR}/monitoring_access.log combined
</VirtualHost>
EOF

    # Habilitar sitio
    a2ensite monitoring.conf 2>/dev/null || true
    systemctl reload apache2 2>/dev/null || systemctl reload httpd 2>/dev/null || true

    log_success "Apache configurado para dashboard"
}

# Configurar email para alertas
configure_email_alerts() {
    log_info "Configurando sistema de email para alertas..."

    # Configurar ssmtp o sendmail básico
    if command -v ssmtp &> /dev/null; then
        cat > /etc/ssmtp/ssmtp.conf << EOF
root=postmaster
mailhub=smtp.gmail.com:587
AuthUser=tu-email@gmail.com
AuthPass=tu-password-app
UseSTARTTLS=YES
EOF
        log_info "ssmtp configurado. Edita /etc/ssmtp/ssmtp.conf con tus credenciales"
    fi

    log_success "Sistema de email configurado"
}

# Configurar Telegram para alertas
configure_telegram_alerts() {
    log_info "Configurando alertas por Telegram..."

    echo
    echo "=========================================="
    echo "  CONFIGURACIÓN DE TELEGRAM BOT"
    echo "=========================================="
    echo
    echo "Para configurar alertas por Telegram:"
    echo "1. Crea un bot con @BotFather en Telegram"
    echo "2. Obtén el token del bot"
    echo "3. Crea un canal privado o grupo"
    echo "4. Agrega el bot como administrador"
    echo "5. Obtén el Chat ID enviando un mensaje al bot"
    echo "6. Edita el archivo de configuración con estos valores"
    echo
    log_info "Telegram configurado (requiere configuración manual)"
}

# Crear directorios necesarios
create_directories() {
    log_info "Creando directorios necesarios..."

    mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$LOG_DIR" "$WEB_DIR"
    chmod 755 "$CONFIG_DIR" "$DATA_DIR" "$LOG_DIR" "$WEB_DIR"

    log_success "Directorios creados"
}

# Crear archivo de configuración
create_config_file() {
    log_info "Creando archivo de configuración..."

    cat > "$CONFIG_DIR/config.sh" << 'EOF'
# Configuración del Sistema de Monitoreo Avanzado
# Modificar estas variables según sea necesario

# Intervalo de monitoreo (segundos)
MONITOR_INTERVAL=30

# Alertas por email
ENABLE_EMAIL_ALERTS=true
EMAIL_RECIPIENT="admin@localhost"

# Alertas por Telegram (requiere configuración)
ENABLE_TELEGRAM_ALERTS=false
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# Umbrales de alerta
CPU_WARNING=80
CPU_CRITICAL=95
MEM_WARNING=85
MEM_CRITICAL=95
DISK_WARNING=85
DISK_CRITICAL=95

# Características avanzadas
ANOMALY_DETECTION=true
HISTORICAL_DATA=true

# Umbrales para detección de anomalías (desviación estándar)
ANOMALY_THRESHOLD=2.0

# Configuración de base de datos
DB_FILE="/var/lib/advanced_monitoring/metrics.db"

# Configuración web
WEB_DIR="/var/www/html/monitoring"
DASHBOARD_REFRESH_INTERVAL=30000
EOF

    log_success "Archivo de configuración creado: $CONFIG_DIR/config.sh"
}

# Crear servicio systemd
create_systemd_service() {
    log_info "Creando servicio systemd..."

    cat > /etc/systemd/system/advanced-monitoring.service << EOF
[Unit]
Description=Advanced Monitoring Service for Webmin/Virtualmin
After=network.target mysql.service postgresql.service

[Service]
Type=simple
User=root
ExecStart=$SCRIPT_DIR/advanced_monitoring.sh --continuous
Restart=always
RestartSec=10

# Configuración de límites
LimitNOFILE=65536
LimitNPROC=4096

# Variables de entorno
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=PYTHONPATH=/usr/local/lib/python3/dist-packages

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    log_success "Servicio systemd creado"
}

# Crear script de backup de métricas
create_backup_script() {
    log_info "Creando script de backup de métricas..."

    cat > "$SCRIPT_DIR/backup_monitoring_data.sh" << 'EOF'
#!/bin/bash
# Script de backup para datos de monitoreo

BACKUP_DIR="/var/backups/monitoring"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/monitoring_backup_$DATE.tar.gz"

mkdir -p "$BACKUP_DIR"

# Backup de base de datos y configuración
tar -czf "$BACKUP_FILE" \
    /etc/advanced_monitoring/ \
    /var/lib/advanced_monitoring/ \
    /var/log/advanced_monitoring/

# Mantener solo los últimos 7 backups
find "$BACKUP_DIR" -name "monitoring_backup_*.tar.gz" -mtime +7 -delete

echo "Backup creado: $BACKUP_FILE"
EOF

    chmod +x "$SCRIPT_DIR/backup_monitoring_data.sh"

    # Agregar a cron para backup diario
    echo "0 2 * * * root $SCRIPT_DIR/backup_monitoring_data.sh" > /etc/cron.d/monitoring-backup

    log_success "Script de backup creado"
}

# Crear script de mantenimiento
create_maintenance_script() {
    log_info "Creando script de mantenimiento..."

    cat > "$SCRIPT_DIR/maintenance_monitoring.sh" << 'EOF'
#!/bin/bash
# Script de mantenimiento para el sistema de monitoreo

LOG_DIR="/var/log/advanced_monitoring"
DATA_DIR="/var/lib/advanced_monitoring"
CONFIG_DIR="/etc/advanced_monitoring"

echo "=== Mantenimiento del Sistema de Monitoreo ==="

# Limpiar logs antiguos (mantener 30 días)
find "$LOG_DIR" -name "*.log" -mtime +30 -delete

# Optimizar base de datos
if [[ -f "$DATA_DIR/metrics.db" ]]; then
    sqlite3 "$DATA_DIR/metrics.db" "VACUUM;"
    sqlite3 "$DATA_DIR/metrics.db" "REINDEX;"
fi

# Limpiar métricas antiguas (mantener 90 días)
sqlite3 "$DATA_DIR/metrics.db" "DELETE FROM metrics WHERE timestamp < datetime('now', '-90 days');"
sqlite3 "$DATA_DIR/metrics.db" "DELETE FROM alerts WHERE timestamp < datetime('now', '-90 days') AND resolved = 1;"

echo "Mantenimiento completado"
EOF

    chmod +x "$SCRIPT_DIR/maintenance_monitoring.sh"

    # Agregar a cron para mantenimiento semanal
    echo "0 3 * * 0 root $SCRIPT_DIR/maintenance_monitoring.sh" > /etc/cron.d/monitoring-maintenance

    log_success "Script de mantenimiento creado"
}

# Probar la instalación
test_installation() {
    log_info "Probando instalación..."

    # Verificar que los scripts existen y son ejecutables
    if [[ ! -x "$SCRIPT_DIR/advanced_monitoring.sh" ]]; then
        log_error "Script principal no encontrado o no ejecutable"
        return 1
    fi

    # Verificar dependencias
    if ! command -v sqlite3 &> /dev/null; then
        log_error "SQLite3 no está instalado"
        return 1
    fi

    if ! command -v python3 &> /dev/null; then
        log_error "Python3 no está instalado"
        return 1
    fi

    # Probar ejecución básica
    if "$SCRIPT_DIR/advanced_monitoring.sh" --help &>/dev/null; then
        log_success "Script principal funciona correctamente"
    else
        log_error "Error en script principal"
        return 1
    fi

    log_success "Instalación probada exitosamente"
}

# Mostrar información post-instalación
show_post_install_info() {
    echo
    echo "=========================================="
    echo "  ✅ INSTALACIÓN COMPLETADA"
    echo "=========================================="
    echo
    echo "Sistema de Monitoreo Avanzado instalado exitosamente"
    echo
    echo "SERVICIOS CONFIGURADOS:"
    echo "✅ Servicio systemd: advanced-monitoring"
    echo "✅ Dashboard web: http://tu-servidor/monitoring/"
    echo "✅ Backup automático: diario a las 2:00 AM"
    echo "✅ Mantenimiento: semanal los domingos a las 3:00 AM"
    echo
    echo "ARCHIVOS IMPORTANTES:"
    echo "📁 Configuración: $CONFIG_DIR/config.sh"
    echo "📁 Datos: $DATA_DIR/"
    echo "📁 Logs: $LOG_DIR/"
    echo "📁 Web: $WEB_DIR/"
    echo
    echo "COMANDOS ÚTILES:"
    echo "🚀 Iniciar monitoreo: systemctl start advanced-monitoring"
    echo "🔄 Estado del servicio: systemctl status advanced-monitoring"
    echo "📊 Ver dashboard: http://tu-servidor/monitoring/"
    echo "⚙️  Configurar: editar $CONFIG_DIR/config.sh"
    echo
    echo "CONFIGURACIÓN PENDIENTE:"
    echo "📧 Email: configurar credenciales en ssmtp.conf"
    echo "📱 Telegram: configurar bot token y chat ID"
    echo
    echo "Para más información, consulta la documentación completa."
    echo
}

# Función principal
main() {
    echo "=========================================="
    echo "  INSTALADOR DEL SISTEMA DE MONITOREO"
    echo "  Webmin & Virtualmin Enterprise"
    echo "=========================================="
    echo

    log_info "Iniciando instalación del sistema de monitoreo avanzado..."

    check_root
    detect_os
    create_directories
    install_system_dependencies
    install_python_dependencies
    install_nodejs_dependencies
    configure_apache
    configure_email_alerts
    configure_telegram_alerts
    create_config_file
    create_systemd_service
    create_backup_script
    create_maintenance_script

    # Ejecutar configuración inicial del script principal
    if [[ -x "$SCRIPT_DIR/advanced_monitoring.sh" ]]; then
        "$SCRIPT_DIR/advanced_monitoring.sh" --setup
    fi

    test_installation
    show_post_install_info

    log_success "Instalación del sistema de monitoreo avanzado completada"
}

# Ejecutar instalación
main "$@"
#!/bin/bash

# INSTALADOR DEL SISTEMA DE RECUPERACIÓN DE DESASTRES (DR)
# Instala y configura el sistema DR completo para Webmin/Virtualmin

set -euo pipefail
IFS=$'\n\t'

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/dr_config.conf"
LOG_FILE="$SCRIPT_DIR/install_dr.log"

# Funciones de logging
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INSTALL] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INSTALL-ERROR] $*" >&2 | tee -a "$LOG_FILE"
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INSTALL-SUCCESS] $*" | tee -a "$LOG_FILE"
}

# Función para verificar permisos de root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este instalador debe ejecutarse como root"
        exit 1
    fi
}

# Función para detectar distribución Linux
detect_distro() {
    if [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "redhat"
    elif [[ -f /etc/SuSE-release ]]; then
        echo "suse"
    else
        echo "unknown"
    fi
}

# Función para instalar dependencias
install_dependencies() {
    local distro
    distro=$(detect_distro)

    log_info "Instalando dependencias para $distro..."

    case "$distro" in
        "debian")
            apt-get update
            apt-get install -y \
                rsync \
                inotify-tools \
                jq \
                curl \
                wget \
                openssh-client \
                openssh-server \
                apache2 \
                mysql-server \
                bind9 \
                systemd \
                cron \
                bc \
                mailutils \
                unzip
            ;;

        "redhat")
            yum update -y
            yum install -y \
                rsync \
                inotify-tools \
                jq \
                curl \
                wget \
                openssh-clients \
                openssh-server \
                httpd \
                mysql-server \
                bind \
                systemd \
                cronie \
                bc \
                mailx \
                unzip
            ;;

        "suse")
            zypper refresh
            zypper install -y \
                rsync \
                inotify-tools \
                jq \
                curl \
                wget \
                openssh \
                apache2 \
                mysql \
                bind \
                systemd \
                cron \
                bc \
                mailx \
                unzip
            ;;

        *)
            log_error "Distribución no soportada: $distro"
            exit 1
            ;;
    esac

    log_success "Dependencias instaladas"
}

# Función para configurar directorios
setup_directories() {
    log_info "Configurando directorios del sistema DR..."

    # Crear directorios principales
    mkdir -p "$DR_ROOT_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$TEMP_DIR"
    mkdir -p "$REPORTS_DIR"/{html,pdf,json,daily,weekly,monthly}

    # Configurar permisos
    chown root:root "$DR_ROOT_DIR"
    chmod 700 "$DR_ROOT_DIR"
    chmod 755 "$LOG_DIR"
    chmod 755 "$CONFIG_DIR"
    chmod 755 "$TEMP_DIR"

    log_success "Directorios configurados"
}

# Función para configurar servicios systemd
setup_systemd_services() {
    log_info "Configurando servicios systemd..."

    # Servicio principal del sistema DR
    cat > "/etc/systemd/system/dr-core.service" << EOF
[Unit]
Description=Sistema de Recuperación de Desastres Core
After=network.target

[Service]
Type=simple
User=root
ExecStart=$SCRIPT_DIR/dr_core.sh monitor
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Servicio de replicación
    cat > "/etc/systemd/system/dr-replication.service" << EOF
[Unit]
Description=Servicio de Replicación DR
After=network.target dr-core.service

[Service]
Type=simple
User=root
ExecStart=$SCRIPT_DIR/replication_manager.sh start
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Timer para reportes diarios
    cat > "/etc/systemd/system/dr-daily-reports.timer" << EOF
[Unit]
Description=Timer para reportes diarios DR
Requires=dr-daily-reports.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

    cat > "/etc/systemd/system/dr-daily-reports.service" << EOF
[Unit]
Description=Generar reportes diarios DR

[Service]
Type=oneshot
User=root
ExecStart=$SCRIPT_DIR/compliance_reporting.sh generate
EOF

    # Recargar systemd
    systemctl daemon-reload

    log_success "Servicios systemd configurados"
}

# Función para configurar cron jobs
setup_cron_jobs() {
    log_info "Configurando trabajos programados..."

    # Backup del sistema DR
    echo "0 3 * * * root $SCRIPT_DIR/dr_core.sh backup" > "/etc/cron.d/dr_backup"

    # Verificación semanal de integridad
    echo "0 4 * * 0 root $SCRIPT_DIR/replication_manager.sh verify" > "/etc/cron.d/dr_verification"

    # Tests DR semanales
    echo "0 5 * * 0 root $SCRIPT_DIR/dr_testing.sh test all" > "/etc/cron.d/dr_testing"

    chmod 644 "/etc/cron.d/dr_backup"
    chmod 644 "/etc/cron.d/dr_verification"
    chmod 644 "/etc/cron.d/dr_testing"

    log_success "Trabajos programados configurados"
}

# Función para configurar firewall
setup_firewall() {
    log_info "Configurando firewall para sistema DR..."

    # Detectar herramienta de firewall
    if command -v ufw &>/dev/null; then
        # UFW (Ubuntu/Debian)
        ufw allow 873/tcp  # rsync
        ufw allow 22/tcp   # SSH
        ufw --force reload
    elif command -v firewall-cmd &>/dev/null; then
        # firewalld (RHEL/CentOS)
        firewall-cmd --permanent --add-port=873/tcp
        firewall-cmd --permanent --add-port=22/tcp
        firewall-cmd --reload
    elif command -v iptables &>/dev/null; then
        # iptables directo
        iptables -A INPUT -p tcp --dport 873 -j ACCEPT
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT
        # Guardar reglas (depende de la distro)
        if command -v netfilter-persistent &>/dev/null; then
            netfilter-persistent save
        fi
    fi

    log_success "Firewall configurado"
}

# Función para configurar logrotate
setup_logrotate() {
    log_info "Configurando rotación de logs..."

    cat > "/etc/logrotate.d/dr_system" << EOF
$LOG_DIR/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        systemctl reload dr-core.service || true
    endscript
}

$REPORTS_DIR/daily/*.json {
    weekly
    rotate 52
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}

$REPORTS_DIR/weekly/*.json {
    monthly
    rotate 24
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}

$REPORTS_DIR/monthly/*.json {
    yearly
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

    log_success "Rotación de logs configurada"
}

# Función para configurar monitoreo básico
setup_basic_monitoring() {
    log_info "Configurando monitoreo básico..."

    # Instalar htop si no está disponible
    if ! command -v htop &>/dev/null; then
        case "$(detect_distro)" in
            "debian") apt-get install -y htop ;;
            "redhat") yum install -y htop ;;
            "suse") zypper install -y htop ;;
        esac
    fi

    # Configurar límites de recursos
    cat > "/etc/security/limits.d/dr_limits.conf" << EOF
# Límites para procesos del sistema DR
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
EOF

    log_success "Monitoreo básico configurado"
}

# Función para crear scripts de automatización
create_automation_scripts() {
    log_info "Creando scripts de automatización..."

    # Script de backup del sistema DR
    cat > "$SCRIPT_DIR/dr_backup.sh" << 'EOF'
#!/bin/bash
# Script de backup del sistema DR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/dr_config.conf"

BACKUP_NAME="dr_system_backup_$(date +%Y%m%d_%H%M%S)"
BACKUP_PATH="$BACKUP_DIR/dr_backups/$BACKUP_NAME"

mkdir -p "$BACKUP_PATH"

# Backup de configuración
cp -r "$DR_ROOT_DIR" "$BACKUP_PATH/"
cp "$SCRIPT_DIR"/*.sh "$BACKUP_PATH/"
cp "$SCRIPT_DIR"/*.conf "$BACKUP_PATH/"

# Backup de logs
cp -r "$LOG_DIR" "$BACKUP_PATH/"

# Crear archivo tar
cd "$BACKUP_DIR/dr_backups"
tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_NAME"

echo "Backup del sistema DR creado: ${BACKUP_NAME}.tar.gz"
EOF

    chmod +x "$SCRIPT_DIR/dr_backup.sh"

    # Script de restauración
    cat > "$SCRIPT_DIR/dr_restore.sh" << 'EOF'
#!/bin/bash
# Script de restauración del sistema DR

if [[ $# -ne 1 ]]; then
    echo "Uso: $0 <archivo_backup.tar.gz>"
    exit 1
fi

BACKUP_FILE="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "Archivo de backup no encontrado: $BACKUP_FILE"
    exit 1
fi

echo "Restaurando sistema DR desde: $BACKUP_FILE"

# Detener servicios
systemctl stop dr-core.service dr-replication.service 2>/dev/null || true

# Restaurar archivos
tar -xzf "$BACKUP_FILE" -C /

# Reiniciar servicios
systemctl start dr-core.service dr-replication.service 2>/dev/null || true

echo "Sistema DR restaurado exitosamente"
EOF

    chmod +x "$SCRIPT_DIR/dr_restore.sh"

    log_success "Scripts de automatización creados"
}

# Función para configurar integración con Webmin
setup_webmin_integration() {
    log_info "Configurando integración con Webmin..."

    # Crear módulo Webmin básico (si Webmin está instalado)
    if [[ -d "/usr/libexec/webmin" ]]; then
        WEBMIN_MODULE_DIR="/usr/libexec/webmin/dr_system"

        mkdir -p "$WEBMIN_MODULE_DIR"

        # Archivo de configuración del módulo
        cat > "$WEBMIN_MODULE_DIR/module.info" << EOF
name=Disaster Recovery System
desc=Sistema de Recuperación de Desastres para Webmin/Virtualmin
version=$DR_SYSTEM_VERSION
category=system
depends=system
EOF

        # Script CGI para el módulo
        cat > "$WEBMIN_MODULE_DIR/index.cgi" << EOF
#!/usr/bin/perl
# Interfaz Webmin para el sistema DR

require './dr_system-lib.pl';

ui_print_header(undef, \$text{'index_title'}, "");

print "<h1>Sistema de Recuperación de Desastres</h1>\n";

# Mostrar estado del sistema
print "<h2>Estado del Sistema</h2>\n";
print "<p>Estado: " . get_dr_status() . "</p>\n";

# Enlaces a acciones
print "<h2>Acciones</h2>\n";
print "<a href='status.cgi'>Ver Estado Detallado</a><br>\n";
print "<a href='test.cgi'>Ejecutar Tests</a><br>\n";
print "<a href='reports.cgi'>Ver Reportes</a><br>\n";

ui_print_footer("/", \$text{'index'});
EOF

        chmod +x "$WEBMIN_MODULE_DIR/index.cgi"

        log_success "Integración con Webmin configurada"
    else
        log_info "Webmin no detectado, omitiendo integración"
    fi
}

# Función para ejecutar pruebas post-instalación
run_post_install_tests() {
    log_info "Ejecutando pruebas post-instalación..."

    # Verificar que los scripts sean ejecutables
    local scripts=("$SCRIPT_DIR/dr_core.sh" "$SCRIPT_DIR/replication_manager.sh" "$SCRIPT_DIR/failover_orchestrator.sh" "$SCRIPT_DIR/recovery_procedures.sh" "$SCRIPT_DIR/dr_testing.sh" "$SCRIPT_DIR/compliance_reporting.sh")

    for script in "${scripts[@]}"; do
        if [[ ! -x "$script" ]]; then
            chmod +x "$script"
            log_info "Permisos corregidos: $script"
        fi
    done

    # Verificar configuración
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Archivo de configuración faltante: $CONFIG_FILE"
        return 1
    fi

    # Verificar servicios
    if ! systemctl is-enabled dr-core.service 2>/dev/null; then
        log_warning "Servicio dr-core.service no está habilitado"
    fi

    log_success "Pruebas post-instalación completadas"
}

# Función para mostrar resumen de instalación
show_installation_summary() {
    echo
    echo "=========================================="
    echo "  INSTALACIÓN COMPLETADA"
    echo "=========================================="
    echo
    echo "✅ Sistema de Recuperación de Desastres instalado"
    echo
    echo "📁 Directorios creados:"
    echo "   - $DR_ROOT_DIR (directorio raíz)"
    echo "   - $LOG_DIR (logs del sistema)"
    echo "   - $REPORTS_DIR (reportes y auditoría)"
    echo
    echo "🔧 Servicios configurados:"
    echo "   - dr-core.service (núcleo del sistema DR)"
    echo "   - dr-replication.service (replicación de datos)"
    echo "   - dr-daily-reports.timer (reportes automáticos)"
    echo
    echo "📋 Scripts disponibles:"
    echo "   - $SCRIPT_DIR/dr_core.sh (control principal)"
    echo "   - $SCRIPT_DIR/replication_manager.sh (gestión de replicación)"
    echo "   - $SCRIPT_DIR/failover_orchestrator.sh (orquestador de failover)"
    echo "   - $SCRIPT_DIR/recovery_procedures.sh (procedimientos de recuperación)"
    echo "   - $SCRIPT_DIR/dr_testing.sh (sistema de testing)"
    echo "   - $SCRIPT_DIR/compliance_reporting.sh (reportes y auditoría)"
    echo
    echo "🌐 Dashboard web:"
    echo "   - $SCRIPT_DIR/dr_dashboard.html"
    echo
    echo "🚀 Para iniciar el sistema:"
    echo "   sudo $SCRIPT_DIR/dr_core.sh init"
    echo "   sudo $SCRIPT_DIR/dr_core.sh start"
    echo
    echo "📖 Para más información:"
    echo "   sudo $SCRIPT_DIR/dr_core.sh --help"
    echo
}

# Función principal
main() {
    echo "=========================================="
    echo "  INSTALADOR SISTEMA DE RECUPERACIÓN DR"
    echo "  Webmin/Virtualmin Enterprise"
    echo "=========================================="
    echo

    log_info "Iniciando instalación del sistema DR..."

    # Verificar root
    check_root

    # Instalar dependencias
    install_dependencies

    # Configurar directorios
    setup_directories

    # Configurar servicios systemd
    setup_systemd_services

    # Configurar cron jobs
    setup_cron_jobs

    # Configurar firewall
    setup_firewall

    # Configurar logrotate
    setup_logrotate

    # Configurar monitoreo básico
    setup_basic_monitoring

    # Crear scripts de automatización
    create_automation_scripts

    # Configurar integración con Webmin
    setup_webmin_integration

    # Ejecutar pruebas post-instalación
    run_post_install_tests

    # Mostrar resumen
    show_installation_summary

    log_success "Instalación del sistema DR completada exitosamente"
}

# Ejecutar función principal
main "$@"
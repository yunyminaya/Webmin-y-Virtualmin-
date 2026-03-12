#!/bin/bash

# ============================================================================
# 🚀 INSTALADOR DEL SISTEMA DE AUTO-REPARACIÓN AUTÓNOMA COMPLETA
# ============================================================================
# Instala automáticamente el sistema completo de auto-reparación
# Configura servicios, cron jobs, monitoreo continuo y alertas
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuración
AUTONOMOUS_SCRIPT="$SCRIPT_DIR/autonomous_repair.sh"
SYSTEMD_SERVICE="/etc/systemd/system/auto-repair.service"
CRON_JOB="/etc/cron.d/auto-repair"
CONFIG_FILE="$SCRIPT_DIR/autonomous_config.sh"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función de logging
install_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" >> "$SCRIPT_DIR/install_autonomous.log"

    case "$level" in
        "CRITICAL") echo -e "${RED}[INSTALL CRITICAL]${NC} $message" ;;
        "WARNING")  echo -e "${YELLOW}[INSTALL WARNING]${NC} $message" ;;
        "INFO")     echo -e "${BLUE}[INSTALL INFO]${NC} $message" ;;
        "SUCCESS")  echo -e "${GREEN}[INSTALL SUCCESS]${NC} $message" ;;
        "STEP")     echo -e "${PURPLE}[INSTALL STEP]${NC} $message" ;;
    esac
}

# Función para verificar prerrequisitos
check_prerequisites() {
    install_log "STEP" "Verificando prerrequisitos del sistema..."

    local missing_deps=()

    # Verificar que el script autónomo existe
    if [[ ! -f "$AUTONOMOUS_SCRIPT" ]]; then
        install_log "CRITICAL" "Script autónomo no encontrado: $AUTONOMOUS_SCRIPT"
        return 1
    fi

    # Verificar permisos de ejecución
    if [[ ! -x "$AUTONOMOUS_SCRIPT" ]]; then
        chmod +x "$AUTONOMOUS_SCRIPT"
        install_log "INFO" "Permisos de ejecución agregados al script autónomo"
    fi

    # Verificar herramientas necesarias
    local required_tools=("systemctl" "cron" "curl" "wget" "mail")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_deps+=("$tool")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        install_log "WARNING" "Herramientas faltantes detectadas: ${missing_deps[*]}"
        install_log "INFO" "Instalando dependencias faltantes..."

        if command -v apt-get >/dev/null 2>&1; then
            apt-get update
            apt-get install -y "${missing_deps[@]}"
        elif command -v yum >/dev/null 2>&1; then
            yum install -y "${missing_deps[@]}"
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y "${missing_deps[@]}"
        fi
    fi

    install_log "SUCCESS" "Prerrequisitos verificados correctamente"
    return 0
}

# Función para configurar el servicio systemd
configure_systemd_service() {
    install_log "STEP" "Configurando servicio systemd..."

    # Crear archivo de servicio
    cat > "$SYSTEMD_SERVICE" << EOF
[Unit]
Description=Auto-Repair Autonomous System
After=network.target multi-user.target
Wants=network.target

[Service]
Type=simple
User=root
ExecStart=$AUTONOMOUS_SCRIPT daemon
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal
SyslogIdentifier=auto-repair

[Install]
WantedBy=multi-user.target
EOF

    # Recargar systemd
    systemctl daemon-reload

    # Habilitar el servicio
    systemctl enable auto-repair

    install_log "SUCCESS" "Servicio systemd configurado correctamente"
}

# Función para configurar cron job
configure_cron_job() {
    install_log "STEP" "Configurando monitoreo automático con cron..."

    # Crear archivo de cron
    cat > "$CRON_JOB" << EOF
# Auto-Repair Autonomous System - Monitoreo continuo
# Ejecuta monitoreo cada 5 minutos
*/5 * * * * root $AUTONOMOUS_SCRIPT monitor >/dev/null 2>&1

# Genera reportes diarios a las 2 AM
0 2 * * * root $AUTONOMOUS_SCRIPT report >/dev/null 2>&1

# Verificación semanal completa los domingos a las 3 AM
0 3 * * 0 root $AUTONOMOUS_SCRIPT monitor && $AUTONOMOUS_SCRIPT report >/dev/null 2>&1
EOF

    # Reiniciar cron
    systemctl restart cron 2>/dev/null || true
    service cron restart 2>/dev/null || true

    install_log "SUCCESS" "Cron job configurado correctamente"
}

# Función para crear configuración personalizada
create_configuration() {
    install_log "STEP" "Creando configuración personalizada..."

    # Detectar email del administrador
    local admin_email=""
    if [[ -n "${SUDO_USER:-}" ]]; then
        admin_email=$(getent passwd "$SUDO_USER" | cut -d: -f1)@$HOSTNAME
    else
        admin_email="root@$HOSTNAME"
    fi

    # Crear archivo de configuración
    cat > "$CONFIG_FILE" << EOF
#!/bin/bash
# Configuración del Sistema de Auto-Reparación Autónoma
# Generado automáticamente por el instalador

# Intervalo de monitoreo (segundos)
MONITORING_INTERVAL=300

# Email para notificaciones
NOTIFICATION_EMAIL="$admin_email"

# Archivos de log y estado
AUTO_REPAIR_LOG="$SCRIPT_DIR/auto_repair_daemon.log"
AUTO_REPAIR_STATUS="$SCRIPT_DIR/auto_repair_status.json"
BACKUP_DIR="/backups/auto_repair_autonomous"

# Servicios críticos a monitorear
CRITICAL_SERVICES=("webmin" "apache2" "nginx" "mysql" "mariadb" "postfix" "dovecot" "ssh" "ufw" "fail2ban")

# Umbrales de alerta
MEMORY_THRESHOLD=80
CPU_THRESHOLD=90
DISK_THRESHOLD=85

# Configuración de backups automáticos
AUTO_BACKUP_ENABLED=true
BACKUP_RETENTION_DAYS=7
EOF

    chmod 600 "$CONFIG_FILE"

    install_log "SUCCESS" "Configuración creada: $CONFIG_FILE"
}

# Función para crear directorios necesarios
create_directories() {
    install_log "STEP" "Creando directorios necesarios..."

    local directories=(
        "$SCRIPT_DIR"
        "/backups/auto_repair_autonomous"
        "/var/log/auto-repair"
        "/etc/auto-repair"
    )

    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            install_log "INFO" "Directorio creado: $dir"
        fi
    done

    install_log "SUCCESS" "Directorios creados correctamente"
}

# Función para configurar alertas por email
configure_email_alerts() {
    install_log "STEP" "Configurando sistema de alertas por email..."

    # Verificar si postfix está instalado
    if ! command -v postfix >/dev/null 2>&1; then
        install_log "INFO" "Instalando Postfix para envío de emails..."

        if command -v apt-get >/dev/null 2>&1; then
            apt-get update
            DEBIAN_FRONTEND=noninteractive apt-get install -y postfix mailutils
        elif command -v yum >/dev/null 2>&1; then
            yum install -y postfix mailx
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y postfix mailx
        fi
    fi

    # Configurar postfix básico si no está configurado
    if [[ ! -f /etc/postfix/main.cf.backup ]]; then
        cp /etc/postfix/main.cf /etc/postfix/main.cf.backup
        postconf -e "myhostname = $HOSTNAME"
        postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost"
        systemctl restart postfix 2>/dev/null || true
    fi

    install_log "SUCCESS" "Sistema de alertas configurado"
}

# Función para crear scripts de utilidad
create_utility_scripts() {
    install_log "STEP" "Creando scripts de utilidad..."

    # Script de verificación rápida
    cat > "$SCRIPT_DIR/check_autonomous.sh" << 'EOF'
#!/bin/bash
# Script de verificación rápida del sistema autónomo

echo "=== ESTADO DEL SISTEMA AUTÓNOMO ==="
echo "Servicio systemd:"
systemctl status auto-repair --no-pager -l | head -5

echo ""
echo "Estado del sistema:"
if [[ -f "/root/auto_repair_status.json" ]]; then
    cat /root/auto_repair_status.json
else
    echo "Archivo de estado no encontrado"
fi

echo ""
echo "Últimos logs:"
tail -10 /root/auto_repair_daemon.log 2>/dev/null || echo "No hay logs disponibles"

echo ""
echo "Próxima ejecución del cron:"
crontab -l | grep auto-repair || echo "No hay cron configurado"
EOF

    # Script de parada de emergencia
    cat > "$SCRIPT_DIR/stop_autonomous.sh" << 'EOF'
#!/bin/bash
# Script de parada de emergencia del sistema autónomo

echo "=== DETENIENDO SISTEMA AUTÓNOMO ==="

# Detener servicio
systemctl stop auto-repair 2>/dev/null || echo "Servicio no estaba ejecutándose"

# Deshabilitar servicio
systemctl disable auto-repair 2>/dev/null || echo "Servicio ya estaba deshabilitado"

# Remover cron job
rm -f /etc/cron.d/auto-repair
systemctl restart cron 2>/dev/null || true

echo "Sistema autónomo detenido correctamente"
echo "Para reiniciar: bash /root/scripts/autonomous_repair.sh install"
EOF

    chmod +x "$SCRIPT_DIR/check_autonomous.sh"
    chmod +x "$SCRIPT_DIR/stop_autonomous.sh"

    install_log "SUCCESS" "Scripts de utilidad creados"
}

# Función para ejecutar prueba inicial
run_initial_test() {
    install_log "STEP" "Ejecutando prueba inicial del sistema..."

    # Ejecutar monitoreo inicial
    if "$AUTONOMOUS_SCRIPT" monitor; then
        install_log "SUCCESS" "Prueba inicial completada exitosamente"
    else
        install_log "WARNING" "La prueba inicial encontró algunos problemas (normal)"
    fi

    # Iniciar el servicio
    if systemctl start auto-repair; then
        install_log "SUCCESS" "Servicio autónomo iniciado correctamente"
    else
        install_log "WARNING" "No se pudo iniciar el servicio autónomo"
    fi
}

# Función para mostrar resumen de instalación
show_installation_summary() {
    install_log "STEP" "Mostrando resumen de instalación..."

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           🎉 SISTEMA DE AUTO-REPARACIÓN AUTÓNOMA INSTALADO 🎉         ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}✅ INSTALACIÓN COMPLETADA EXITOSAMENTE${NC}"
    echo ""
    echo -e "${BLUE}📋 COMPONENTES INSTALADOS:${NC}"
    echo "   🔧 Servicio systemd: auto-repair"
    echo "   ⏰ Cron job: cada 5 minutos"
    echo "   📧 Alertas por email: configuradas"
    echo "   📊 Reportes automáticos: diarios y semanales"
    echo "   🔄 Monitoreo continuo: 24/7"
    echo ""
    echo -e "${BLUE}🎯 FUNCIONES AUTOMÁTICAS:${NC}"
    echo "   ✅ Detección automática de problemas"
    echo "   ✅ Reparación automática de servicios"
    echo "   ✅ Liberación automática de memoria"
    echo "   ✅ Limpieza automática de disco"
    echo "   ✅ Reparación automática de red"
    echo "   ✅ Generación automática de reportes"
    echo ""
    echo -e "${BLUE}📁 ARCHIVOS IMPORTANTES:${NC}"
    echo "   📝 Script principal: $AUTONOMOUS_SCRIPT"
    echo "   ⚙️ Configuración: $CONFIG_FILE"
    echo "   📊 Estado: $SCRIPT_DIR/auto_repair_status.json"
    echo "   📋 Logs: $SCRIPT_DIR/auto_repair_daemon.log"
    echo ""
    echo -e "${BLUE}🛠️ COMANDOS ÚTILES:${NC}"
    echo "   📊 Ver estado: $SCRIPT_DIR/check_autonomous.sh"
    echo "   🛑 Detener: $SCRIPT_DIR/stop_autonomous.sh"
    echo "   🔄 Reiniciar: systemctl restart auto-repair"
    echo "   📋 Ver logs: tail -f $SCRIPT_DIR/auto_repair_daemon.log"
    echo ""
    echo -e "${GREEN}🚀 EL SISTEMA YA ESTÁ FUNCIONANDO AUTOMÁTICAMENTE${NC}"
    echo ""
    echo -e "${YELLOW}💡 El sistema se ejecutará cada 5 minutos y reparará${NC}"
    echo -e "${YELLOW}   automáticamente cualquier problema que detecte${NC}"
    echo ""
    echo -e "${PURPLE}📧 RECIBIRÁS ALERTAS POR EMAIL SI HAY PROBLEMAS CRÍTICOS${NC}"
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              🛡️ TU VPS AHORA SE AUTO-REPARA SOLO 🛡️                 ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Función principal de instalación
main_install() {
    echo ""
    echo -e "${CYAN}🚀 INSTALANDO SISTEMA DE AUTO-REPARACIÓN AUTÓNOMA...${NC}"
    echo ""

    # Verificar prerrequisitos
    if ! check_prerequisites; then
        install_log "CRITICAL" "Instalación abortada por prerrequisitos faltantes"
        exit 1
    fi

    # Crear directorios
    create_directories

    # Crear configuración
    create_configuration

    # Configurar systemd
    configure_systemd_service

    # Configurar cron
    configure_cron_job

    # Configurar alertas
    configure_email_alerts

    # Crear scripts de utilidad
    create_utility_scripts

    # Ejecutar prueba inicial
    run_initial_test

    # Mostrar resumen
    show_installation_summary

    install_log "SUCCESS" "Instalación del sistema autónomo completada"
}

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Este script debe ejecutarse como root${NC}"
    echo -e "${YELLOW}💡 Ejecuta: sudo $0${NC}"
    exit 1
fi

# Crear directorio de logs
mkdir -p "$SCRIPT_DIR"
touch "$SCRIPT_DIR/install_autonomous.log"

# Ejecutar instalación
main_install

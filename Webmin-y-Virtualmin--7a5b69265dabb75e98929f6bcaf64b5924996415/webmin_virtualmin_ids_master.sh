#!/bin/bash

# ============================================================================
# SISTEMA COMPLETO IDS/IPS PARA WEBMIN/VIRTUALMIN - MAESTRO
# ============================================================================
# Instalador y gestor unificado del sistema de detección y prevención
# de intrusiones para Webmin y Virtualmin
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
SYSTEM_NAME="Webmin/Virtualmin IDS/IPS"
SYSTEM_VERSION="1.0.0"
INSTALL_DIR="/etc/webmin-virtualmin-ids"
CONFIG_DIR="$INSTALL_DIR/config"
SERVICES_DIR="$INSTALL_DIR/services"
LOGS_DIR="$INSTALL_DIR/logs"
BACKUP_DIR="$INSTALL_DIR/backups"

# Componentes del sistema
COMPONENTS=(
    "fail2ban:install_webmin_virtualmin_ids.sh"
    "monitor:webmin_virtualmin_monitor.sh"
    "alerts:alert_system.sh"
    "rules:custom_rules_manager.sh"
    "dashboard:ids_dashboard.html"
)

# Función de logging del sistema maestro
log_master() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    mkdir -p "$LOGS_DIR"

    case "$level" in
        "SUCCESS") echo -e "${GREEN}✅ [$timestamp] MASTER:${NC} $message" ;;
        "INFO")    echo -e "${BLUE}💎 [$timestamp] MASTER:${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}⚠️ [$timestamp] MASTER:${NC} $message" ;;
        "ERROR")   echo -e "${RED}❌ [$timestamp] MASTER:${NC} $message" ;;
        *)         echo -e "${PURPLE}🔥 [$timestamp] MASTER:${NC} $message" ;;
    esac

    echo "[$timestamp] [$level] $message" >> "$LOGS_DIR/master.log"
}

# Verificar permisos de root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_master "ERROR" "Este script debe ejecutarse como root"
        echo -e "${RED}❌ ERROR: Debe ejecutar este script como root (sudo)${NC}"
        exit 1
    fi
}

# Verificar dependencias del sistema
check_dependencies() {
    log_master "INFO" "Verificando dependencias del sistema..."

    local missing_deps=()

    # Comandos esenciales
    local essential_cmds=("curl" "wget" "grep" "awk" "sed" "netstat" "ss")
    for cmd in "${essential_cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_master "WARNING" "Dependencias faltantes: ${missing_deps[*]}"
        install_missing_dependencies "${missing_deps[@]}"
    fi

    log_master "SUCCESS" "Dependencias verificadas"
}

# Instalar dependencias faltantes
install_missing_dependencies() {
    local deps=("$@")

    log_master "INFO" "Instalando dependencias faltantes..."

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y "${deps[@]}"
    elif command -v yum >/dev/null 2>&1; then
        yum install -y "${deps[@]}"
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y "${deps[@]}"
    else
        log_master "ERROR" "No se pudo instalar dependencias - gestor de paquetes no reconocido"
        return 1
    fi

    log_master "SUCCESS" "Dependencias instaladas"
}

# Crear estructura de directorios
create_directory_structure() {
    log_master "INFO" "Creando estructura de directorios..."

    local dirs=(
        "$INSTALL_DIR"
        "$CONFIG_DIR"
        "$SERVICES_DIR"
        "$LOGS_DIR"
        "$BACKUP_DIR"
        "$INSTALL_DIR/rules"
        "$INSTALL_DIR/scripts"
        "$INSTALL_DIR/data"
        "$INSTALL_DIR/reports"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        chmod 755 "$dir"
    done

    log_master "SUCCESS" "Estructura de directorios creada"
}

# Verificar componentes
verify_components() {
    log_master "INFO" "Verificando componentes del sistema..."

    local missing_components=()

    for component in "${COMPONENTS[@]}"; do
        local name="${component%%:*}"
        local file="${component##*:}"

        if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
            missing_components+=("$file")
        fi
    done

    if [[ ${#missing_components[@]} -gt 0 ]]; then
        log_master "ERROR" "Componentes faltantes: ${missing_components[*]}"
        echo -e "${RED}❌ ERROR: Faltan componentes del sistema. Asegúrese de que todos los archivos estén en el mismo directorio.${NC}"
        exit 1
    fi

    log_master "SUCCESS" "Todos los componentes verificados"
}

# Instalar componentes
install_components() {
    log_master "INFO" "Instalando componentes del sistema..."

    # Instalar fail2ban y reglas específicas
    if [[ -f "$SCRIPT_DIR/install_webmin_virtualmin_ids.sh" ]]; then
        log_master "INFO" "Instalando configuración de fail2ban..."
        bash "$SCRIPT_DIR/install_webmin_virtualmin_ids.sh"
    fi

    # Instalar sistema de alertas
    if [[ -f "$SCRIPT_DIR/alert_system.sh" ]]; then
        log_master "INFO" "Configurando sistema de alertas..."
        bash "$SCRIPT_DIR/alert_system.sh" init
    fi

    # Instalar gestor de reglas
    if [[ -f "$SCRIPT_DIR/custom_rules_manager.sh" ]]; then
        log_master "INFO" "Inicializando gestor de reglas..."
        bash "$SCRIPT_DIR/custom_rules_manager.sh" init
    fi

    # Copiar dashboard
    if [[ -f "$SCRIPT_DIR/ids_dashboard.html" ]]; then
        cp "$SCRIPT_DIR/ids_dashboard.html" "$INSTALL_DIR/"
        log_master "INFO" "Dashboard copiado a $INSTALL_DIR/"
    fi

    log_master "SUCCESS" "Componentes instalados"
}

# Crear servicios systemd
create_systemd_services() {
    log_master "INFO" "Creando servicios systemd..."

    # Servicio principal del monitor
    cat > /etc/systemd/system/webmin-ids-monitor.service << EOF
[Unit]
Description=Webmin/Virtualmin IDS Monitor Service
After=network.target fail2ban.service
Wants=fail2ban.service

[Service]
Type=simple
User=root
ExecStart=$SCRIPT_DIR/webmin_virtualmin_monitor.sh start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Servicio de alertas
    cat > /etc/systemd/system/webmin-ids-alerts.service << EOF
[Unit]
Description=Webmin/Virtualmin IDS Alerts Service
After=network.target

[Service]
Type=oneshot
User=root
ExecStart=$SCRIPT_DIR/alert_system.sh test
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # Recargar systemd
    systemctl daemon-reload

    log_master "SUCCESS" "Servicios systemd creados"
}

# Crear scripts de gestión
create_management_scripts() {
    log_master "INFO" "Creando scripts de gestión..."

    # Script de inicio del sistema
    cat > "$INSTALL_DIR/start_ids.sh" << 'EOF'
#!/bin/bash
# Script de inicio del sistema IDS/IPS

echo "🚀 Iniciando sistema IDS/IPS completo..."

# Iniciar servicios
systemctl start webmin-ids-monitor
systemctl start fail2ban

# Verificar estado
sleep 2
systemctl status webmin-ids-monitor --no-pager -l
systemctl status fail2ban --no-pager -l

echo "✅ Sistema IDS/IPS iniciado"
EOF

    # Script de parada del sistema
    cat > "$INSTALL_DIR/stop_ids.sh" << 'EOF'
#!/bin/bash
# Script de parada del sistema IDS/IPS

echo "🛑 Deteniendo sistema IDS/IPS..."

# Detener servicios
systemctl stop webmin-ids-monitor
systemctl stop fail2ban

echo "✅ Sistema IDS/IPS detenido"
EOF

    # Script de estado del sistema
    cat > "$INSTALL_DIR/status_ids.sh" << 'EOF'
#!/bin/bash
# Script de estado del sistema IDS/IPS

echo "=== ESTADO DEL SISTEMA IDS/IPS ==="
echo ""

echo "🔍 Servicios:"
systemctl status webmin-ids-monitor fail2ban --no-pager -l | head -20

echo ""
echo "📊 Estadísticas de fail2ban:"
fail2ban-client status 2>/dev/null || echo "fail2ban no disponible"

echo ""
echo "📁 Archivos de log:"
ls -la /etc/webmin-virtualmin-ids/logs/ 2>/dev/null || echo "Directorio de logs no encontrado"

echo ""
echo "🛡️ Dashboard disponible en:"
echo "file:///etc/webmin-virtualmin-ids/ids_dashboard.html"
EOF

    # Hacer ejecutables los scripts
    chmod +x "$INSTALL_DIR"/*.sh

    log_master "SUCCESS" "Scripts de gestión creados"
}

# Configurar firewall básico
configure_basic_firewall() {
    log_master "INFO" "Configurando firewall básico..."

    # Backup de reglas existentes
    iptables-save > "$BACKUP_DIR/iptables_backup_$(date +%Y%m%d_%H%M%S).rules" 2>/dev/null || true

    # Reglas básicas de protección
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT

    # Permitir loopback
    iptables -A INPUT -i lo -j ACCEPT

    # Permitir conexiones establecidas
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # Permitir SSH (puerto 22)
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT

    # Permitir Webmin (puerto 10000)
    iptables -A INPUT -p tcp --dport 10000 -j ACCEPT

    # Permitir HTTP/HTTPS
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT

    # Guardar reglas
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4

    log_master "SUCCESS" "Firewall básico configurado"
}

# Crear configuración inicial
create_initial_config() {
    log_master "INFO" "Creando configuración inicial..."

    cat > "$CONFIG_DIR/system.conf" << EOF
# Configuración del Sistema IDS/IPS - Webmin/Virtualmin
# Generado automáticamente el $(date)

[SYSTEM]
name=$SYSTEM_NAME
version=$SYSTEM_VERSION
install_dir=$INSTALL_DIR
install_date=$(date +%Y-%m-%d)
status=installed

[COMPONENTS]
fail2ban=enabled
monitor=enabled
alerts=enabled
rules=enabled
dashboard=enabled

[PATHS]
config_dir=$CONFIG_DIR
logs_dir=$LOGS_DIR
backup_dir=$BACKUP_DIR
services_dir=$SERVICES_DIR

[MONITORING]
enabled=true
interval=60
log_level=INFO

[ALERTS]
enabled=true
channels=email
min_level=MEDIUM

[FIREWALL]
enabled=true
backend=iptables
policy=DROP
EOF

    log_master "SUCCESS" "Configuración inicial creada"
}

# Mostrar banner de instalación
show_installation_banner() {
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${PURPLE}🛡️ INSTALANDO SISTEMA COMPLETO IDS/IPS PARA WEBMIN/VIRTUALMIN${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${GREEN}🎯 FUNCIONALIDADES:${NC}"
    echo -e "${CYAN}   🔐 Detección de autenticación Webmin/Virtualmin${NC}"
    echo -e "${CYAN}   💉 Prevención de SQL Injection${NC}"
    echo -e "${CYAN}   🕷️ Protección contra XSS${NC}"
    echo -e "${CYAN}   🔨 Bloqueo de ataques de fuerza bruta${NC}"
    echo -e "${CYAN}   📡 Monitoreo de APIs${NC}"
    echo -e "${CYAN}   🚫 Prevención DDoS${NC}"
    echo -e "${CYAN}   📊 Dashboard web en tiempo real${NC}"
    echo -e "${CYAN}   🔔 Alertas multi-canal${NC}"
    echo -e "${CYAN}   ⚙️ Reglas personalizables${NC}"
    echo -e "${CYAN}   🤖 Monitoreo inteligente${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo ""
}

# Mostrar resumen de instalación
show_installation_summary() {
    echo ""
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${GREEN}✅ INSTALACIÓN COMPLETADA - SISTEMA IDS/IPS OPERATIVO${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo ""
    echo -e "${YELLOW}📍 UBICACIÓN DE ARCHIVOS:${NC}"
    echo -e "${BLUE}   Directorio principal: $INSTALL_DIR${NC}"
    echo -e "${BLUE}   Configuración: $CONFIG_DIR${NC}"
    echo -e "${BLUE}   Logs: $LOGS_DIR${NC}"
    echo ""
    echo -e "${YELLOW}🚀 COMANDOS DE GESTIÓN:${NC}"
    echo -e "${BLUE}   Iniciar sistema: $INSTALL_DIR/start_ids.sh${NC}"
    echo -e "${BLUE}   Detener sistema: $INSTALL_DIR/stop_ids.sh${NC}"
    echo -e "${BLUE}   Ver estado: $INSTALL_DIR/status_ids.sh${NC}"
    echo ""
    echo -e "${YELLOW}📊 DASHBOARD:${NC}"
    echo -e "${BLUE}   URL: file://$INSTALL_DIR/ids_dashboard.html${NC}"
    echo ""
    echo -e "${YELLOW}🛠️ HERRAMIENTAS ADICIONALES:${NC}"
    echo -e "${BLUE}   Monitor: $SCRIPT_DIR/webmin_virtualmin_monitor.sh${NC}"
    echo -e "${BLUE}   Alertas: $SCRIPT_DIR/alert_system.sh${NC}"
    echo -e "${BLUE}   Reglas: $SCRIPT_DIR/custom_rules_manager.sh${NC}"
    echo ""
    echo -e "${GREEN}🎯 PRÓXIMOS PASOS:${NC}"
    echo -e "${CYAN}   1. Configure las alertas: $SCRIPT_DIR/alert_system.sh config${NC}"
    echo -e "${CYAN}   2. Personalice las reglas: $SCRIPT_DIR/custom_rules_manager.sh list${NC}"
    echo -e "${CYAN}   3. Inicie el sistema: $INSTALL_DIR/start_ids.sh${NC}"
    echo -e "${CYAN}   4. Abra el dashboard para monitorear${NC}"
    echo ""
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${PURPLE}🛡️ SU SERVIDOR ESTÁ PROTEGIDO CONTRA AMENAZAS AVANZADAS${NC}"
    echo -e "${BLUE}============================================================================${NC}"
}

# Función de desinstalación
uninstall_system() {
    log_master "WARNING" "Iniciando desinstalación del sistema..."

    echo -e "${YELLOW}⚠️ ATENCIÓN: Esta acción eliminará completamente el sistema IDS/IPS${NC}"
    read -p "¿Está seguro de que desea continuar? (sí/no): " -r
    if [[ ! $REPLY =~ ^[Ss][Ii]$ ]]; then
        log_master "INFO" "Desinstalación cancelada por el usuario"
        exit 0
    fi

    # Detener servicios
    systemctl stop webmin-ids-monitor 2>/dev/null || true
    systemctl stop fail2ban 2>/dev/null || true

    # Eliminar servicios
    systemctl disable webmin-ids-monitor 2>/dev/null || true
    systemctl disable fail2ban 2>/dev/null || true

    rm -f /etc/systemd/system/webmin-ids-*.service
    systemctl daemon-reload

    # Eliminar directorios
    rm -rf "$INSTALL_DIR"

    # Limpiar crontab
    crontab -l 2>/dev/null | grep -v "webmin_virtualmin_ids\|webmin-ids" | crontab - 2>/dev/null || true

    log_master "SUCCESS" "Sistema desinstalado completamente"
    echo -e "${GREEN}✅ Sistema IDS/IPS desinstalado${NC}"
}

# Función principal
main() {
    local action="${1:-install}"

    case "$action" in
        "install")
            show_installation_banner
            check_root
            check_dependencies
            verify_components
            create_directory_structure
            install_components
            create_systemd_services
            create_management_scripts
            configure_basic_firewall
            create_initial_config
            show_installation_summary
            ;;
        "uninstall")
            check_root
            uninstall_system
            ;;
        "status")
            echo "=== ESTADO DEL SISTEMA IDS/IPS ==="
            echo "Directorio: $INSTALL_DIR"
            echo "Configuración: $CONFIG_DIR/system.conf"
            echo ""

            if [[ -f "$CONFIG_DIR/system.conf" ]]; then
                echo "Estado: INSTALADO"
                source "$CONFIG_DIR/system.conf"
                echo "Versión: $version"
                echo "Fecha instalación: $install_date"
            else
                echo "Estado: NO INSTALADO"
            fi
            ;;
        "start")
            if [[ -f "$INSTALL_DIR/start_ids.sh" ]]; then
                bash "$INSTALL_DIR/start_ids.sh"
            else
                echo "Sistema no instalado. Ejecute: $0 install"
            fi
            ;;
        "stop")
            if [[ -f "$INSTALL_DIR/stop_ids.sh" ]]; then
                bash "$INSTALL_DIR/stop_ids.sh"
            else
                echo "Sistema no instalado."
            fi
            ;;
        *)
            echo "Sistema Maestro IDS/IPS - Webmin/Virtualmin"
            echo ""
            echo "Uso: $0 [acción]"
            echo ""
            echo "Acciones:"
            echo "  install     - Instalar sistema completo"
            echo "  uninstall   - Desinstalar sistema completo"
            echo "  start       - Iniciar servicios"
            echo "  stop        - Detener servicios"
            echo "  status      - Mostrar estado del sistema"
            ;;
    esac
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
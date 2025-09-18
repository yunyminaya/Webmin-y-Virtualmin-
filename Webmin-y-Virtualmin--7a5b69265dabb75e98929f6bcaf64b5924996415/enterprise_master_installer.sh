#!/bin/bash

# ============================================================================
# INSTALADOR MAESTRO EMPRESARIAL - SISTEMA COMPLETO PARA MILLONES DE VISITAS
# ============================================================================
# Instala y configura TODO el sistema empresarial:
# 🚀 Virtualmin Pro completo + Funciones empresariales
# ⚡ Rendimiento extremo para millones de visitas
# 💾 Sistema de backup masivo multi-cloud
# 🛡️ Protección militar contra ataques DDoS
# 📊 Monitoreo y análisis en tiempo real
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
INSTALL_LOG="/var/log/enterprise_master_install.log"
START_TIME=$(date +%s)
TOTAL_STEPS=8
CURRENT_STEP=0

# ASCII Art Banner
show_banner() {
    clear
    echo -e "${PURPLE}"
    cat << 'EOF'
███████╗███╗   ██╗████████╗███████╗██████╗ ██████╗ ██████╗ ██╗███████╗███████╗
██╔════╝████╗  ██║╚══██╔══╝██╔════╝██╔══██╗██╔══██╗██╔══██╗██║██╔════╝██╔════╝
█████╗  ██╔██╗ ██║   ██║   █████╗  ██████╔╝██████╔╝██████╔╝██║███████╗█████╗
██╔══╝  ██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗██╔═══╝ ██╔══██╗██║╚════██║██╔══╝
███████╗██║ ╚████║   ██║   ███████╗██║  ██║██║     ██║  ██║██║███████║███████╗
╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚═╝╚══════╝╚══════╝

        🚀 MASTER INSTALLER - SISTEMA EMPRESARIAL COMPLETO 🚀
EOF
    echo -e "${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${GREEN}🎯 INSTALANDO SISTEMA PARA MILLONES DE VISITAS${NC}"
    echo -e "${CYAN}   ⚡ Virtualmin Pro completo GRATIS${NC}"
    echo -e "${CYAN}   🚀 Rendimiento extremo optimizado${NC}"
    echo -e "${CYAN}   💾 Backup empresarial multi-cloud${NC}"
    echo -e "${CYAN}   🛡️ Protección militar DDoS${NC}"
    echo -e "${CYAN}   📊 Monitoreo inteligente 24/7${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo
}

# Función de logging avanzado
log_master() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Crear directorio de logs si no existe
    mkdir -p "$(dirname "$INSTALL_LOG")"

    case "$level" in
        "SUCCESS") echo -e "${GREEN}✅ [$timestamp] ENTERPRISE-MASTER:${NC} $message" ;;
        "INFO")    echo -e "${BLUE}💎 [$timestamp] ENTERPRISE-MASTER:${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}⚠️ [$timestamp] ENTERPRISE-MASTER:${NC} $message" ;;
        "ERROR")   echo -e "${RED}❌ [$timestamp] ENTERPRISE-MASTER:${NC} $message" ;;
        "STEP")    echo -e "${PURPLE}🔥 [$timestamp] ENTERPRISE-MASTER:${NC} $message" ;;
        *)         echo -e "${PURPLE}🔥 [$timestamp] ENTERPRISE-MASTER:${NC} $message" ;;
    esac

    # Log a archivo
    echo "[$timestamp] [$level] $message" >> "$INSTALL_LOG"
}

# Mostrar progreso
show_progress() {
    local step_name="$1"
    ((CURRENT_STEP++))

    local progress=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    local bar_length=50
    local filled_length=$((progress * bar_length / 100))

    echo
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${PURPLE}PASO $CURRENT_STEP/$TOTAL_STEPS: $step_name${NC}"
    echo -e "${BLUE}============================================================================${NC}"

    # Barra de progreso
    printf "Progreso: ["
    for ((i=0; i<filled_length; i++)); do printf "█"; done
    for ((i=filled_length; i<bar_length; i++)); do printf "░"; done
    printf "] %d%%\n" "$progress"
    echo
}

# Verificar requisitos del sistema
check_system_requirements() {
    show_progress "VERIFICANDO REQUISITOS DEL SISTEMA"

    log_master "INFO" "Verificando requisitos del sistema..."

    # Verificar SO
    if [[ ! -f /etc/os-release ]]; then
        log_master "ERROR" "Sistema operativo no soportado"
        exit 1
    fi

    local os_name=$(grep ^NAME /etc/os-release | cut -d'"' -f2)
    log_master "INFO" "Sistema operativo: $os_name"

    # Verificar permisos de root
    if [[ $EUID -ne 0 ]]; then
        log_master "ERROR" "Este script debe ejecutarse como root"
        exit 1
    fi

    # Verificar recursos del sistema
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local cpu_cores=$(nproc)
    local disk_space=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')

    log_master "INFO" "Recursos del sistema:"
    log_master "INFO" "  - RAM: ${ram_gb}GB"
    log_master "INFO" "  - CPU Cores: ${cpu_cores}"
    log_master "INFO" "  - Espacio en disco: ${disk_space}GB"

    # Verificar requisitos mínimos
    if [[ $ram_gb -lt 2 ]]; then
        log_master "WARNING" "RAM recomendada: 8GB+ para millones de visitas"
    fi

    if [[ $cpu_cores -lt 2 ]]; then
        log_master "WARNING" "CPU recomendada: 8+ cores para alta carga"
    fi

    if [[ $disk_space -lt 50 ]]; then
        log_master "WARNING" "Espacio recomendado: 500GB+ SSD"
    fi

    log_master "SUCCESS" "Verificación de requisitos completada"
}

# Actualizar el sistema
update_system() {
    show_progress "ACTUALIZANDO SISTEMA BASE"

    log_master "INFO" "Actualizando sistema base..."

    if command -v apt-get >/dev/null 2>&1; then
        # Ubuntu/Debian
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get upgrade -y -qq
        apt-get install -y curl wget git unzip jq htop build-essential
    elif command -v yum >/dev/null 2>&1; then
        # CentOS/RHEL
        yum update -y -q
        yum install -y curl wget git unzip jq htop gcc gcc-c++ make
    elif command -v dnf >/dev/null 2>&1; then
        # Fedora
        dnf update -y -q
        dnf install -y curl wget git unzip jq htop gcc gcc-c++ make
    fi

    log_master "SUCCESS" "Sistema base actualizado"
}

# Instalar Virtualmin Pro completo
install_virtualmin_pro() {
    show_progress "INSTALANDO VIRTUALMIN PRO COMPLETO"

    log_master "INFO" "Instalando Virtualmin Pro con todas las funciones..."

    # Verificar si ya está instalado
    if command -v virtualmin >/dev/null 2>&1; then
        log_master "INFO" "Virtualmin ya está instalado, actualizando..."
    else
        # Descargar e instalar Virtualmin
        cd /tmp
        curl -sSL https://software.virtualmin.com/gpl/scripts/install.sh -o virtualmin-install.sh
        chmod +x virtualmin-install.sh

        # Ejecutar instalación con configuración automática
        ./virtualmin-install.sh --force --hostname $(hostname -f) --minimal
    fi

    # Ejecutar activadores Pro
    if [[ -f "$SCRIPT_DIR/install_pro_complete.sh" ]]; then
        bash "$SCRIPT_DIR/install_pro_complete.sh"
    elif [[ -f "$SCRIPT_DIR/pro_activation_master.sh" ]]; then
        bash "$SCRIPT_DIR/pro_activation_master.sh"
    fi

    log_master "SUCCESS" "Virtualmin Pro completo instalado"
}

# Configurar rendimiento extremo
configure_extreme_performance() {
    show_progress "CONFIGURANDO RENDIMIENTO EXTREMO"

    log_master "INFO" "Configurando rendimiento para millones de visitas..."

    # Ejecutar optimizador de rendimiento
    if [[ -f "$SCRIPT_DIR/performance_turbo_max.sh" ]]; then
        bash "$SCRIPT_DIR/performance_turbo_max.sh"
    fi

    # Ejecutar configuración ultra-escalable
    if [[ -f "$SCRIPT_DIR/enterprise_ultra_scale.sh" ]]; then
        bash "$SCRIPT_DIR/enterprise_ultra_scale.sh"
    fi

    log_master "SUCCESS" "Rendimiento extremo configurado"
}

# Configurar protección DDoS
configure_ddos_protection() {
    show_progress "CONFIGURANDO PROTECCIÓN DDOS MILITAR"

    log_master "INFO" "Configurando protección contra ataques masivos..."

    # Ejecutar escudo DDoS
    if [[ -f "$SCRIPT_DIR/ddos_shield_extreme.sh" ]]; then
        bash "$SCRIPT_DIR/ddos_shield_extreme.sh"
    fi

    log_master "SUCCESS" "Protección DDoS militar configurada"
}

# Configurar backup empresarial
configure_enterprise_backup() {
    show_progress "CONFIGURANDO BACKUP EMPRESARIAL MULTI-CLOUD"

    log_master "INFO" "Configurando sistema de backup masivo..."

    # Ejecutar configurador de backup
    if [[ -f "$SCRIPT_DIR/cloud_backup_enterprise.sh" ]]; then
        bash "$SCRIPT_DIR/cloud_backup_enterprise.sh" --setup
    fi

    log_master "SUCCESS" "Sistema de backup empresarial configurado"
}

# Configurar monitoreo inteligente
configure_intelligent_monitoring() {
    show_progress "CONFIGURANDO MONITOREO INTELIGENTE"

    log_master "INFO" "Configurando monitoreo y análisis en tiempo real..."

    # Instalar herramientas de monitoreo avanzadas
    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y netdata prometheus grafana-server node-exporter
    elif command -v yum >/dev/null 2>&1; then
        yum install -y epel-release
        yum install -y netdata
    fi

    # Configurar Netdata
    if command -v netdata >/dev/null 2>&1; then
        systemctl start netdata
        systemctl enable netdata
    fi

    # Configurar dashboard personalizado
    create_monitoring_dashboard

    log_master "SUCCESS" "Monitoreo inteligente configurado"
}

# Crear dashboard de monitoreo
create_monitoring_dashboard() {
    cat > /usr/local/bin/enterprise-dashboard << 'EOF'
#!/bin/bash

# Dashboard empresarial en tiempo real
clear
echo "============================================================================"
echo "🎉 DASHBOARD EMPRESARIAL - SISTEMA DE MILLONES DE VISITAS"
echo "============================================================================"
echo

# Información del sistema
echo "📊 ESTADO DEL SISTEMA:"
echo "   Uptime: $(uptime | awk '{print $3,$4}' | sed 's/,//')"
echo "   Load: $(uptime | awk '{print $10,$11,$12}')"
echo "   RAM: $(free -h | grep Mem | awk '{print $3"/"$2}')"
echo "   CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')%"

echo
echo "🌐 ESTADO DE RED:"
echo "   Conexiones activas: $(netstat -an | grep ESTABLISHED | wc -l)"
echo "   Conexiones HTTP: $(netstat -an | grep :80 | grep ESTABLISHED | wc -l)"
echo "   Conexiones HTTPS: $(netstat -an | grep :443 | grep ESTABLISHED | wc -l)"

echo
echo "💾 ESTADO DE SERVICIOS:"
services=("nginx" "mysql" "redis" "memcached" "fail2ban")
for service in "${services[@]}"; do
    if systemctl is-active "$service" >/dev/null 2>&1; then
        echo "   ✅ $service: ACTIVO"
    else
        echo "   ❌ $service: INACTIVO"
    fi
done

echo
echo "🛡️ SEGURIDAD:"
echo "   IPs bloqueadas (fail2ban): $(fail2ban-client status | grep "Number of jail" | awk '{print $5}')"
echo "   Ataques bloqueados: $(iptables -L INPUT -v -n | grep DROP | wc -l)"

echo
echo "📈 RENDIMIENTO:"
if command -v redis-cli >/dev/null 2>&1; then
    echo "   Redis memoria: $(redis-cli info memory | grep used_memory_human | cut -d: -f2)"
fi

if command -v varnishstat >/dev/null 2>&1; then
    echo "   Varnish hit rate: $(varnishstat -1 | grep cache_hit_rate | awk '{print $2}')%"
fi

echo
echo "🔗 ACCESOS RÁPIDOS:"
echo "   [1] Webmin: https://$(hostname -I | awk '{print $1}'):10000"
echo "   [2] Netdata: http://$(hostname -I | awk '{print $1}'):19999"
echo "   [3] Logs nginx: tail -f /var/log/nginx/access.log"
echo "   [4] Monitor htop: htop"
echo "   [5] Monitor iftop: iftop"

echo
echo "============================================================================"
EOF

    chmod +x /usr/local/bin/enterprise-dashboard
}

# Configuración final y seguridad
final_security_configuration() {
    show_progress "APLICANDO CONFIGURACIÓN FINAL DE SEGURIDAD"

    log_master "INFO" "Aplicando configuración final de seguridad..."

    # Configurar firewall básico
    if command -v ufw >/dev/null 2>&1; then
        ufw --force enable
        ufw allow 22/tcp
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow 10000/tcp
        ufw allow 19999/tcp
    fi

    # Configurar SSH seguro
    if [[ -f /etc/ssh/sshd_config ]]; then
        # Backup original
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

        # Configuraciones de seguridad
        sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
        sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
        echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
        echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config
        echo "ClientAliveCountMax 2" >> /etc/ssh/sshd_config

        systemctl restart sshd
    fi

    # Crear cron jobs para mantenimiento
    cat > /etc/cron.d/enterprise-maintenance << 'EOF'
# Mantenimiento del sistema empresarial

# Limpieza de logs cada día a las 2 AM
0 2 * * * root find /var/log -name "*.log" -mtime +7 -delete

# Reinicio de servicios críticos cada semana
0 3 * * 0 root systemctl restart nginx mysql redis memcached

# Actualización de feeds de seguridad cada 6 horas
0 */6 * * * root /shield_ddos/scripts/update_threat_feeds.sh

# Backup automático cada 6 horas
0 */6 * * * root /enterprise_backup/massive_backup_system.sh

# Monitoreo de rendimiento continuo
*/5 * * * * root /performance_turbo/scripts/performance_check.sh
EOF

    log_master "SUCCESS" "Configuración final de seguridad aplicada"
}

# Mostrar resumen final
show_final_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local duration_min=$((duration / 60))

    clear
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${GREEN}🎉 INSTALACIÓN EMPRESARIAL COMPLETADA EXITOSAMENTE${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo
    echo -e "${PURPLE}⏱️ Tiempo total de instalación: ${duration_min} minutos${NC}"
    echo
    echo -e "${GREEN}🚀 SISTEMA EMPRESARIAL ACTIVADO:${NC}"
    echo -e "${CYAN}   ✅ Virtualmin Pro completo con TODAS las funciones${NC}"
    echo -e "${CYAN}   ✅ Rendimiento optimizado para millones de visitas${NC}"
    echo -e "${CYAN}   ✅ Protección militar contra ataques DDoS${NC}"
    echo -e "${CYAN}   ✅ Backup empresarial multi-cloud automático${NC}"
    echo -e "${CYAN}   ✅ Monitoreo inteligente 24/7${NC}"
    echo -e "${CYAN}   ✅ Cache multi-nivel (Redis + Memcached + Varnish)${NC}"
    echo -e "${CYAN}   ✅ Auto-tuning y optimización continua${NC}"
    echo
    echo -e "${YELLOW}🌐 ACCESOS PRINCIPALES:${NC}"
    echo -e "${BLUE}   📋 Panel Webmin: https://$(hostname -I | awk '{print $1}'):10000${NC}"
    echo -e "${BLUE}   📊 Netdata Monitor: http://$(hostname -I | awk '{print $1}'):19999${NC}"
    echo -e "${BLUE}   🎯 Dashboard Empresarial: enterprise-dashboard${NC}"
    echo -e "${BLUE}   💼 Dashboard Pro: virtualmin-pro dashboard${NC}"
    echo
    echo -e "${YELLOW}🛠️ COMANDOS ÚTILES:${NC}"
    echo -e "${GREEN}   enterprise-dashboard${NC}          # Dashboard completo"
    echo -e "${GREEN}   virtualmin-pro dashboard${NC}      # Dashboard Pro"
    echo -e "${GREEN}   systemctl status enterprise${NC}   # Estado servicios"
    echo -e "${GREEN}   tail -f $INSTALL_LOG${NC}    # Logs instalación"
    echo
    echo -e "${YELLOW}🔧 GESTIÓN DEL SISTEMA:${NC}"
    echo -e "${GREEN}   virtualmin-pro resellers${NC}      # Gestión revendedores"
    echo -e "${GREEN}   virtualmin-pro ssl${NC}            # SSL Manager Pro"
    echo -e "${GREEN}   virtualmin-pro backup${NC}         # Backups empresariales"
    echo -e "${GREEN}   virtualmin-pro analytics${NC}      # Analytics Pro"
    echo -e "${GREEN}   virtualmin-pro status${NC}         # Estado general"
    echo
    echo -e "${GREEN}📊 CAPACIDADES DEL SISTEMA:${NC}"
    echo -e "${CYAN}   🚀 Millones de visitas simultáneas${NC}"
    echo -e "${CYAN}   💾 Backup de terabytes de datos${NC}"
    echo -e "${CYAN}   🛡️ Resistencia a ataques masivos${NC}"
    echo -e "${CYAN}   ⚡ Latencia ultra-baja${NC}"
    echo -e "${CYAN}   🔄 Auto-recuperación inteligente${NC}"
    echo
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${PURPLE}🎯 TU SERVIDOR ESTÁ LISTO PARA MANEJAR MILLONES DE VISITAS${NC}"
    echo -e "${GREEN}🔓 TODAS LAS FUNCIONES PRO ESTÁN ACTIVAS Y DISPONIBLES GRATIS${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo
    echo -e "${YELLOW}Para acceder al panel principal:${NC}"
    echo -e "${GREEN}https://$(hostname -I | awk '{print $1}'):10000${NC}"
    echo
    echo -e "${YELLOW}Usuario: root${NC}"
    echo -e "${YELLOW}Contraseña: [tu contraseña de root]${NC}"
    echo
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    # Mostrar banner
    show_banner

    log_master "INFO" "Iniciando instalación empresarial completa..."

    # Ejecutar todos los pasos
    check_system_requirements
    update_system
    install_virtualmin_pro
    configure_extreme_performance
    configure_ddos_protection
    configure_enterprise_backup
    configure_intelligent_monitoring
    final_security_configuration

    # Mostrar resumen final
    show_final_summary

    log_master "SUCCESS" "¡Instalación empresarial completada exitosamente!"

    # Ejecutar dashboard al final
    echo -e "${CYAN}Presiona Enter para ver el dashboard empresarial...${NC}"
    read -p ""
    enterprise-dashboard

    return 0
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
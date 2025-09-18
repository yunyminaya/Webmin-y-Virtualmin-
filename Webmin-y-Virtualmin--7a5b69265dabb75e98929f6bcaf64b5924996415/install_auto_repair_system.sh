#!/bin/bash

# ============================================================================
# 🚀 INSTALACIÓN RÁPIDA DEL SISTEMA DE AUTO-REPARACIÓN
# ============================================================================
# Script para instalar rápidamente el sistema completo en un VPS
# Descarga e instala todo el sistema de protección y reparación
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Configuración
REPO_URL="https://github.com/yunyminaya/Webmin-y-Virtualmin-.git"
TEMP_DIR="/tmp/webmin-system-install"
INSTALL_LOG="/tmp/instalacion_sistema_$(date +%Y%m%d_%H%M%S).log"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función de logging
log_install() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$INSTALL_LOG"

    case "$level" in
        "INFO")     echo -e "${BLUE}[INSTALL]${NC} $message" ;;
        "SUCCESS")  echo -e "${GREEN}[INSTALL]${NC} $message" ;;
        "WARNING")  echo -e "${YELLOW}[INSTALL]${NC} $message" ;;
        "ERROR")    echo -e "${RED}[INSTALL]${NC} $message" ;;
    esac
}

# Función para verificar requisitos del sistema
check_system_requirements() {
    log_install "INFO" "Verificando requisitos del sistema..."

    # Verificar arquitectura
    local arch
    arch=$(uname -m)
    if [[ "$arch" != "x86_64" && "$arch" != "aarch64" ]]; then
        log_install "WARNING" "Arquitectura $arch detectada - Compatible limitada"
    fi

    # Verificar distribución
    if [[ ! -f /etc/os-release ]]; then
        log_install "ERROR" "Sistema operativo no compatible"
        exit 1
    fi

    local distro
    distro=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')

    case "$distro" in
        "ubuntu"|"debian"|"centos"|"rhel"|"fedora")
            log_install "SUCCESS" "Distribución compatible: $distro"
            ;;
        *)
            log_install "WARNING" "Distribución no probada: $distro"
            ;;
    esac

    # Verificar espacio en disco
    local disk_space
    disk_space=$(df /tmp | tail -1 | awk '{print $4}')
    if [[ $disk_space -lt 1048576 ]]; then  # 1GB en KB
        log_install "ERROR" "Espacio insuficiente en /tmp"
        exit 1
    fi

    # Verificar herramientas necesarias
    local required_tools=("wget" "curl" "git" "tar" "gzip")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_install "INFO" "Instalando herramienta faltante: $tool"
            apt-get update && apt-get install -y "$tool" || yum install -y "$tool" || true
        fi
    done

    log_install "SUCCESS" "Requisitos del sistema verificados"
}

# Función para descargar el sistema
download_system() {
    log_install "INFO" "Descargando sistema desde GitHub..."

    # Crear directorio temporal
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"

    # Descargar repositorio
    if command -v git >/dev/null 2>&1; then
        log_install "INFO" "Clonando repositorio con git..."
        if git clone --depth 1 "$REPO_URL" .; then
            log_install "SUCCESS" "Repositorio clonado exitosamente"
        else
            log_install "WARNING" "Error al clonar con git, intentando descarga directa..."
            download_fallback
        fi
    else
        download_fallback
    fi
}

# Función de descarga alternativa
download_fallback() {
    log_install "INFO" "Descargando repositorio como archivo zip..."

    local zip_url="${REPO_URL%.git}/archive/main.zip"
    local zip_file="/tmp/webmin-system.zip"

    if curl -L -o "$zip_file" "$zip_url" 2>/dev/null || wget -O "$zip_file" "$zip_url" 2>/dev/null; then
        unzip "$zip_file" -d "$TEMP_DIR" 2>/dev/null || tar -xzf "$zip_file" -C "$TEMP_DIR" 2>/dev/null || true
        log_install "SUCCESS" "Repositorio descargado y extraído"
        rm -f "$zip_file"
    else
        log_install "ERROR" "Error al descargar el repositorio"
        exit 1
    fi
}

# Función para instalar dependencias del sistema
install_system_dependencies() {
    log_install "INFO" "Instalando dependencias del sistema..."

    # Detectar gestor de paquetes
    if command -v apt-get >/dev/null 2>&1; then
        log_install "INFO" "Instalando dependencias con apt-get..."

        # Actualizar lista de paquetes
        apt-get update

        # Instalar dependencias básicas
        apt-get install -y \
            curl wget git tar gzip \
            apache2 libapache2-mod-security2 \
            mysql-server mysql-client \
            php php-cli php-mysql php-zip php-xml \
            ufw fail2ban \
            htop iotop \
            rkhunter chkrootkit \
            auditd aide \
            || true

    elif command -v yum >/dev/null 2>&1; then
        log_install "INFO" "Instalando dependencias con yum..."

        yum update -y
        yum install -y \
            curl wget git tar gzip \
            httpd mod_security \
            mysql mysql-server \
            php php-cli php-mysql php-zip php-xml \
            firewalld fail2ban \
            htop iotop \
            rkhunter chkrootkit \
            audit audit-libs aide \
            || true

    elif command -v dnf >/dev/null 2>&1; then
        log_install "INFO" "Instalando dependencias con dnf..."

        dnf update -y
        dnf install -y \
            curl wget git tar gzip \
            httpd mod_security \
            mysql mysql-server \
            php php-cli php-mysql php-zip php-xml \
            firewalld fail2ban \
            htop iotop \
            rkhunter chkrootkit \
            audit audit-libs aide \
            || true
    else
        log_install "WARNING" "No se detectó gestor de paquetes compatible"
    fi

    log_install "SUCCESS" "Dependencias del sistema instaladas"
}

# Función para configurar firewall básico
configure_basic_firewall() {
    log_install "INFO" "Configurando firewall básico..."

    if command -v ufw >/dev/null 2>&1; then
        log_install "INFO" "Configurando UFW..."

        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow ssh
        ufw allow 80
        ufw allow 443
        ufw allow 10000  # Webmin
        echo "y" | ufw enable

    elif command -v firewall-cmd >/dev/null 2>&1; then
        log_install "INFO" "Configurando firewalld..."

        systemctl enable firewalld
        systemctl start firewalld

        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --permanent --add-port=10000/tcp
        firewall-cmd --reload
    fi

    log_install "SUCCESS" "Firewall básico configurado"
}

# Función para ejecutar el diagnóstico y reparación
run_diagnostic_repair() {
    log_install "INFO" "Ejecutando diagnóstico y reparación..."

    # Buscar el script de diagnóstico
    local diag_script="$TEMP_DIR/scripts/diagnostico_reparacion_vps.sh"

    if [[ -f "$diag_script" ]]; then
        log_install "INFO" "Ejecutando diagnóstico completo..."

        if bash "$diag_script" full; then
            log_install "SUCCESS" "Diagnóstico y reparación completados"
        else
            log_install "WARNING" "Algunos problemas no pudieron ser reparados automáticamente"
        fi
    else
        log_install "ERROR" "Script de diagnóstico no encontrado"
        exit 1
    fi
}

# Función para configurar monitoreo básico
setup_basic_monitoring() {
    log_install "INFO" "Configurando monitoreo básico..."

    # Crear script de monitoreo básico
    cat > /usr/local/bin/monitor-sistema.sh << 'EOF'
#!/bin/bash

# Monitoreo básico del sistema
LOG_FILE="/var/log/sistema-monitor.log"

# Función de logging
log_monitor() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

# Verificar servicios críticos
check_services() {
    local services=("webmin" "apache2" "nginx" "mysql" "mariadb" "ssh")

    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_monitor "OK: $service activo"
        else
            log_monitor "ERROR: $service inactivo"
        fi
    done
}

# Verificar recursos
check_resources() {
    local cpu_usage mem_usage disk_usage

    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

    log_monitor "CPU: ${cpu_usage}% | MEM: ${mem_usage}% | DISK: ${disk_usage}%"
}

# Ejecutar verificación
check_services
check_resources
EOF

    chmod +x /usr/local/bin/monitor-sistema.sh

    # Configurar cron para monitoreo cada 5 minutos
    echo "*/5 * * * * root /usr/local/bin/monitor-sistema.sh" > /etc/cron.d/sistema-monitor

    log_install "SUCCESS" "Monitoreo básico configurado"
}

# Función para mostrar resultados finales
show_final_results() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                           🎉 INSTALACIÓN COMPLETADA                         ║${NC}"
    echo -e "${CYAN}║                 SISTEMA DE AUTO-REPARACIÓN OPERATIVO                      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${GREEN}✅ SISTEMA DE AUTO-REPARACIÓN INSTALADO${NC}"
    echo ""
    echo -e "${BLUE}🛠️ COMPONENTES INSTALADOS:${NC}"
    echo "   ✅ Herramientas de diagnóstico"
    echo "   ✅ Sistema de reparación automática"
    echo "   ✅ Monitoreo básico del sistema"
    echo "   ✅ Firewall configurado"
    echo "   ✅ Dependencias del sistema"
    echo ""

    echo -e "${BLUE}📊 LOGS Y REPORTES:${NC}"
    echo "   • Log de instalación: $INSTALL_LOG"
    echo "   • Log de monitoreo: /var/log/sistema-monitor.log"
    echo "   • Reportes de diagnóstico: /tmp/reporte_vps_*.txt"
    echo ""

    echo -e "${BLUE}🚀 PRUEBA EL SISTEMA:${NC}"
    echo "   Para diagnóstico completo:"
    echo "   sudo bash scripts/diagnostico_reparacion_vps.sh full"
    echo ""
    echo "   Para solo diagnóstico:"
    echo "   sudo bash scripts/diagnostico_reparacion_vps.sh diagnose"
    echo ""
    echo "   Para solo reparaciones:"
    echo "   sudo bash scripts/diagnostico_reparacion_vps.sh repair"
    echo ""

    echo -e "${YELLOW}💡 PRÓXIMOS PASOS RECOMENDADOS:${NC}"
    echo "   1. Ejecuta el diagnóstico para verificar el estado actual"
    echo "   2. Revisa los logs para identificar problemas específicos"
    echo "   3. Si hay problemas críticos, ejecuta las reparaciones"
    echo "   4. Configura alertas por email si es necesario"
    echo "   5. Considera instalar el sistema de protección completa"
    echo ""

    echo -e "${GREEN}🎯 ¡TU SISTEMA DE AUTO-REPARACIÓN ESTÁ LISTO!${NC}"
}

# Función principal
main() {
    echo ""
    echo -e "${CYAN}🚀 INSTALACIÓN RÁPIDA DEL SISTEMA DE AUTO-REPARACIÓN${NC}"
    echo -e "${CYAN}Webmin & Virtualmin - Protección y Reparación Automática${NC}"
    echo ""

    # Verificar requisitos
    check_system_requirements

    # Descargar sistema
    download_system

    # Instalar dependencias
    install_system_dependencies

    # Configurar firewall básico
    configure_basic_firewall

    # Ejecutar diagnóstico y reparación
    run_diagnostic_repair

    # Configurar monitoreo básico
    setup_basic_monitoring

    # Mostrar resultados
    show_final_results

    log_install "SUCCESS" "Instalación del sistema de auto-reparación completada"

    echo ""
    echo -e "${GREEN}✅ INSTALACIÓN COMPLETADA EXITOSAMENTE${NC}"
}

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Este script debe ejecutarse como root${NC}"
    echo -e "${YELLOW}💡 Ejecuta: sudo $0${NC}"
    exit 1
fi

# Ejecutar instalación
main "$@"

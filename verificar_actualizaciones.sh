#!/bin/bash

# Script de Verificación de Actualizaciones
# Verifica si hay actualizaciones disponibles sin instalarlas

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -e

# Colores para output
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Variables

# Función para detectar sistema operativo
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        DISTRO="macos"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS="linux"
        DISTRO="$ID"
    elif [[ -f /etc/redhat-release ]]; then
        OS="linux"
        if grep -q "CentOS" /etc/redhat-release; then
            DISTRO="centos"
        elif grep -q "Red Hat" /etc/redhat-release; then
            DISTRO="rhel"
        elif grep -q "Fedora" /etc/redhat-release; then
            DISTRO="fedora"
        fi
    elif [[ -f /etc/debian_version ]]; then
        OS="linux"
        DISTRO="debian"
    else
        OS="unknown"
        DISTRO="unknown"
    fi
    
    export OS DISTRO
}

THEME_DIR="/usr/share/webmin/authentic-theme"
VIRTUALMIN_DIR="/usr/share/webmin/virtual-server"
UPDATE_CHECK_FILE="/var/cache/webmin-virtualmin-updates.cache"

# Funciones de logging
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Obtener versión actual de Authentic Theme
get_current_theme_version() {
    if [[ -f "$THEME_DIR/theme.info" ]]; then
        grep "version=" "$THEME_DIR/theme.info" | cut -d= -f2 | tr -d '"' || echo "unknown"
    else
        echo "not_installed"
    fi
}

# Obtener versión actual de Virtualmin
get_current_virtualmin_version() {
    if [[ -f "$VIRTUALMIN_DIR/module.info" ]]; then
        grep "version=" "$VIRTUALMIN_DIR/module.info" | cut -d= -f2 | tr -d '"' || echo "unknown"
    else
        echo "not_installed"
    fi
}

# Verificar última versión de Authentic Theme en GitHub
check_latest_theme_version() {
    log_step "Verificando última versión de Authentic Theme..."
    
    # Usar API de GitHub para obtener la última release
    if command -v curl >/dev/null 2>&1; then
        LATEST_THEME_VERSION=$(curl -s https://api.github.com/repos/authentic-theme/authentic-theme/releases/latest | grep '"tag_name":' | cut -d'"' -f4 2>/dev/null || echo "unknown")
    elif command -v wget >/dev/null 2>&1; then
        LATEST_THEME_VERSION=$(wget -qO- https://api.github.com/repos/authentic-theme/authentic-theme/releases/latest | grep '"tag_name":' | cut -d'"' -f4 2>/dev/null || echo "unknown")
    else
        log_warning "No se puede verificar la versión remota (curl/wget no disponible)"
        LATEST_THEME_VERSION="unknown"
    fi
    
    echo "$LATEST_THEME_VERSION"
}

# Verificar actualizaciones del sistema
check_system_updates() {
    log_step "Verificando actualizaciones del sistema operativo..."
    
    if command -v apt >/dev/null 2>&1; then
        # Ubuntu/Debian
        apt update >/dev/null 2>&1
        SYSTEM_UPDATES=$(apt list --upgradable 2>/dev/null | grep -c upgradable || echo "0")
        SYSTEM_SECURITY_UPDATES=$(apt list --upgradable 2>/dev/null | grep -c security || echo "0")
    elif command -v yum >/dev/null 2>&1; then
        # CentOS/RHEL
        SYSTEM_UPDATES=$(yum check-update --quiet | wc -l || echo "0")
        SYSTEM_SECURITY_UPDATES=$(yum --security check-update --quiet | wc -l || echo "0")
    elif command -v dnf >/dev/null 2>&1; then
        # Fedora
        SYSTEM_UPDATES=$(dnf check-update --quiet | wc -l || echo "0")
        SYSTEM_SECURITY_UPDATES=$(dnf --security check-update --quiet | wc -l || echo "0")
    else
        SYSTEM_UPDATES="unknown"
        SYSTEM_SECURITY_UPDATES="unknown"
    fi
}

# Verificar estado de servicios
check_services_status() {
    log_step "Verificando estado de servicios..."
    
    # Webmin
    if systemctl is-active --quiet webmin 2>/dev/null; then
        WEBMIN_STATUS="running"
    elif service webmin status >/dev/null 2>&1; then
        WEBMIN_STATUS="running"
    else
        WEBMIN_STATUS="stopped"
    fi
    
    # Apache
    if systemctl is-active --quiet apache2 2>/dev/null; then
        APACHE_STATUS="running"
    elif systemctl is-active --quiet httpd 2>/dev/null; then
        APACHE_STATUS="running"
    else
        APACHE_STATUS="stopped"
    fi
    
    # MySQL/MariaDB
    if systemctl is-active --quiet mysql 2>/dev/null; then
        MYSQL_STATUS="running"
    elif systemctl is-active --quiet mariadb 2>/dev/null; then
        MYSQL_STATUS="running"
    else
        MYSQL_STATUS="stopped"
    fi
}

# Verificar espacio en disco
check_disk_space() {
    log_step "Verificando espacio en disco..."
    
    DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    DISK_AVAILABLE=$(df -h / | awk 'NR==2 {print $4}')
    
    if [[ $DISK_USAGE -gt 90 ]]; then
        DISK_STATUS="critical"
    elif [[ $DISK_USAGE -gt 80 ]]; then
        DISK_STATUS="warning"
    else
        DISK_STATUS="ok"
    fi
}

# Verificar memoria RAM
check_memory_usage() {
    log_step "Verificando uso de memoria..."
    
    if command -v free >/dev/null 2>&1; then
        MEMORY_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2 }')
        MEMORY_AVAILABLE=$(free -h | awk 'NR==2{print $7}')
        
        if [[ $MEMORY_USAGE -gt 90 ]]; then
            MEMORY_STATUS="critical"
        elif [[ $MEMORY_USAGE -gt 80 ]]; then
            MEMORY_STATUS="warning"
        else
            MEMORY_STATUS="ok"
        fi
    else
        MEMORY_USAGE="unknown"
        MEMORY_STATUS="unknown"
    fi
}

# Generar reporte de estado
generate_status_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    cat > "$UPDATE_CHECK_FILE" << EOF
# Reporte de Estado del Sistema - $timestamp

## Versiones Instaladas
Authentic Theme: $CURRENT_THEME_VERSION
Virtualmin: $CURRENT_VIRTUALMIN_VERSION
Webmin: $(webmin --version 2>/dev/null || echo "unknown")

## Actualizaciones Disponibles
Authentic Theme Latest: $LATEST_THEME_VERSION
Sistema: $SYSTEM_UPDATES actualizaciones disponibles
Seguridad: $SYSTEM_SECURITY_UPDATES actualizaciones de seguridad

## Estado de Servicios
Webmin: $WEBMIN_STATUS
Apache: $APACHE_STATUS
MySQL/MariaDB: $MYSQL_STATUS

## Recursos del Sistema
Uso de Disco: $DISK_USAGE% (Estado: $DISK_STATUS)
Espacio Disponible: $DISK_AVAILABLE
Uso de Memoria: $MEMORY_USAGE% (Estado: $MEMORY_STATUS)
Memoria Disponible: $MEMORY_AVAILABLE

## Última Verificación
$timestamp
EOF
}

# Mostrar reporte en pantalla
show_status_report() {
    echo
    echo "========================================"
    echo -e "${BLUE}  REPORTE DE ESTADO DEL SISTEMA${NC}"
    echo "========================================"
    echo
    
    # Versiones
    echo -e "${PURPLE}📦 VERSIONES INSTALADAS:${NC}"
    echo -e "   🎨 Authentic Theme: ${YELLOW}$CURRENT_THEME_VERSION${NC}"
    echo -e "   🌐 Virtualmin: ${YELLOW}$CURRENT_VIRTUALMIN_VERSION${NC}"
    echo -e "   ⚙️  Webmin: ${YELLOW}$(webmin --version 2>/dev/null || echo "unknown")${NC}"
    echo
    
    # Actualizaciones
    echo -e "${PURPLE}🔄 ACTUALIZACIONES DISPONIBLES:${NC}"
    if [[ "$LATEST_THEME_VERSION" != "$CURRENT_THEME_VERSION" && "$LATEST_THEME_VERSION" != "unknown" ]]; then
        echo -e "   🎨 Authentic Theme: ${GREEN}$LATEST_THEME_VERSION disponible${NC}"
    else
        echo -e "   🎨 Authentic Theme: ${GREEN}Actualizado${NC}"
    fi
    
    if [[ $SYSTEM_UPDATES -gt 0 ]]; then
        echo -e "   🖥️  Sistema: ${YELLOW}$SYSTEM_UPDATES actualizaciones${NC}"
    else
        echo -e "   🖥️  Sistema: ${GREEN}Actualizado${NC}"
    fi
    
    if [[ $SYSTEM_SECURITY_UPDATES -gt 0 ]]; then
        echo -e "   🔒 Seguridad: ${RED}$SYSTEM_SECURITY_UPDATES actualizaciones críticas${NC}"
    else
        echo -e "   🔒 Seguridad: ${GREEN}Actualizado${NC}"
    fi
    echo
    
    # Estado de servicios
    echo -e "${PURPLE}🔧 ESTADO DE SERVICIOS:${NC}"
    if [[ "$WEBMIN_STATUS" == "running" ]]; then
        echo -e "   ⚙️  Webmin: ${GREEN}Ejecutándose${NC}"
    else
        echo -e "   ⚙️  Webmin: ${RED}Detenido${NC}"
    fi
    
    if [[ "$APACHE_STATUS" == "running" ]]; then
        echo -e "   🌐 Apache: ${GREEN}Ejecutándose${NC}"
    else
        echo -e "   🌐 Apache: ${RED}Detenido${NC}"
    fi
    
    if [[ "$MYSQL_STATUS" == "running" ]]; then
        echo -e "   🗄️  MySQL/MariaDB: ${GREEN}Ejecutándose${NC}"
    else
        echo -e "   🗄️  MySQL/MariaDB: ${RED}Detenido${NC}"
    fi
    echo
    
    # Recursos del sistema
    echo -e "${PURPLE}💻 RECURSOS DEL SISTEMA:${NC}"
    
    case $DISK_STATUS in
        "ok")
            echo -e "   💾 Disco: ${GREEN}$DISK_USAGE% usado${NC} ($DISK_AVAILABLE disponible)"
            ;;
        "warning")
            echo -e "   💾 Disco: ${YELLOW}$DISK_USAGE% usado${NC} ($DISK_AVAILABLE disponible)"
            ;;
        "critical")
            echo -e "   💾 Disco: ${RED}$DISK_USAGE% usado${NC} ($DISK_AVAILABLE disponible)"
            ;;
    esac
    
    case $MEMORY_STATUS in
        "ok")
            echo -e "   🧠 Memoria: ${GREEN}$MEMORY_USAGE% usado${NC} ($MEMORY_AVAILABLE disponible)"
            ;;
        "warning")
            echo -e "   🧠 Memoria: ${YELLOW}$MEMORY_USAGE% usado${NC} ($MEMORY_AVAILABLE disponible)"
            ;;
        "critical")
            echo -e "   🧠 Memoria: ${RED}$MEMORY_USAGE% usado${NC} ($MEMORY_AVAILABLE disponible)"
            ;;
        "unknown")
            echo -e "   🧠 Memoria: ${YELLOW}No disponible${NC}"
            ;;
    esac
    echo
    
    # Recomendaciones
    echo -e "${PURPLE}💡 RECOMENDACIONES:${NC}"
    
    local recommendations=0
    
    if [[ "$LATEST_THEME_VERSION" != "$CURRENT_THEME_VERSION" && "$LATEST_THEME_VERSION" != "unknown" ]]; then
        echo -e "   🔄 Ejecuta ${BLUE}sudo ./actualizar_sistema.sh${NC} para actualizar Authentic Theme"
        ((recommendations++))
    fi
    
    if [[ $SYSTEM_SECURITY_UPDATES -gt 0 ]]; then
        echo -e "   🔒 Instala las actualizaciones de seguridad del sistema"
        ((recommendations++))
    fi
    
    if [[ "$WEBMIN_STATUS" != "running" ]]; then
        echo -e "   ⚙️  Inicia el servicio Webmin: ${BLUE}sudo systemctl start webmin${NC}"
        ((recommendations++))
    fi
    
    if [[ "$DISK_STATUS" == "critical" ]]; then
        echo -e "   💾 Libera espacio en disco urgentemente"
        ((recommendations++))
    elif [[ "$DISK_STATUS" == "warning" ]]; then
        echo -e "   💾 Considera liberar espacio en disco"
        ((recommendations++))
    fi
    
    if [[ "$MEMORY_STATUS" == "critical" ]]; then
        echo -e "   🧠 Considera aumentar la memoria RAM o cerrar procesos"
        ((recommendations++))
    fi
    
    if [[ $recommendations -eq 0 ]]; then
        echo -e "   ${GREEN}✅ Todo está funcionando correctamente${NC}"
    fi
    
    echo
    echo -e "${BLUE}📝 Reporte guardado en: $UPDATE_CHECK_FILE${NC}"
    echo -e "${BLUE}🕒 Última verificación: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo
}

# Función principal
main() {
    echo -e "${BLUE}Verificando estado del sistema...${NC}"
    echo
    
    # Crear directorio cache si no existe
    mkdir -p "$(dirname "$UPDATE_CHECK_FILE")"
    
    # Obtener información actual
    CURRENT_THEME_VERSION=$(get_current_theme_version)
    CURRENT_VIRTUALMIN_VERSION=$(get_current_virtualmin_version)
    LATEST_THEME_VERSION=$(check_latest_theme_version)
    
    # Verificar actualizaciones y estado
    check_system_updates
    check_services_status
    check_disk_space
    check_memory_usage
    
    # Generar y mostrar reporte
    generate_status_report
    show_status_report
}

# Ejecutar función principal
main

echo -e "${GREEN}Verificación completada.${NC}"

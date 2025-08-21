#!/bin/bash

# =============================================================================
# DESINSTALADOR DE WEBMIN Y VIRTUALMIN
# Script para desinstalar completamente Webmin, Virtualmin y dependencias
# =============================================================================

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -e

# Colores
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Variables
LOG_FILE="/tmp/desinstalacion_webmin_$(date +%Y%m%d_%H%M%S).log"
WEBMIN_DIR="/opt/webmin"
WEBMIN_CONFIG="/etc/webmin"
WEBMIN_VAR="/var/webmin"
WEBMIN_LOG="/var/log/webmin"

# Función para logging
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

# Detectar sistema operativo
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
        DISTRO="centos"
    else
        log_error "Sistema operativo no soportado"
        exit 1
    fi
    
    log_info "Sistema detectado: $OS - $DISTRO"
}

# Verificar permisos
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        SUDO=""
    elif command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        log_error "Se requieren permisos de administrador"
        exit 1
    fi
}

# Detener servicios de Webmin
stop_webmin() {
    log "Deteniendo servicios de Webmin..."
    
    case "$DISTRO" in
        "macos")
            # Detener LaunchDaemon en macOS
            if [[ -f /Library/LaunchDaemons/com.webmin.webmin.plist ]]; then
                $SUDO launchctl unload /Library/LaunchDaemons/com.webmin.webmin.plist 2>/dev/null || true
            fi
            
            # Matar procesos de Webmin
            pkill -f "miniserv.pl" 2>/dev/null || true
            pkill -f "webmin" 2>/dev/null || true
            ;;
        *)
            # Detener systemd service en Linux
            if systemctl is-active --quiet webmin 2>/dev/null; then
                $SUDO systemctl stop webmin
            fi
            
            if systemctl is-enabled --quiet webmin 2>/dev/null; then
                $SUDO systemctl disable webmin
            fi
            
            # Matar procesos restantes
            $SUDO pkill -f "miniserv.pl" 2>/dev/null || true
            $SUDO pkill -f "webmin" 2>/dev/null || true
            ;;
    esac
    
    log "Servicios de Webmin detenidos"
}

# Eliminar archivos de Webmin
remove_webmin_files() {
    log "Eliminando archivos de Webmin..."
    
    # Directorios principales
    for dir in "$WEBMIN_DIR" "$WEBMIN_CONFIG" "$WEBMIN_VAR" "$WEBMIN_LOG"; do
        if [[ -d "$dir" ]]; then
            log_info "Eliminando directorio: $dir"
            $SUDO rm -rf "$dir"
        fi
    done
    
    # Archivos de configuración adicionales
    case "$DISTRO" in
        "macos")
            # Eliminar LaunchDaemon
            if [[ -f /Library/LaunchDaemons/com.webmin.webmin.plist ]]; then
                $SUDO rm -f /Library/LaunchDaemons/com.webmin.webmin.plist
            fi
            ;;
        *)
            # Eliminar archivos de systemd
            if [[ -f /etc/systemd/system/webmin.service ]]; then
                $SUDO rm -f /etc/systemd/system/webmin.service
                $SUDO systemctl daemon-reload
            fi
            
            # Eliminar archivos de init.d
            if [[ -f /etc/init.d/webmin ]]; then
                $SUDO rm -f /etc/init.d/webmin
            fi
            ;;
    esac
    
    log "Archivos de Webmin eliminados"
}

# Eliminar usuarios y grupos de Webmin
remove_webmin_users() {
    log "Eliminando usuarios y grupos de Webmin..."
    
    case "$DISTRO" in
        "macos")
            # En macOS, Webmin no crea usuarios del sistema típicamente
            log_info "No hay usuarios específicos de Webmin en macOS"
            ;;
        *)
            # Eliminar usuario webmin si existe
            if id "webmin" >/dev/null 2>&1; then
                $SUDO userdel webmin 2>/dev/null || true
                log_info "Usuario webmin eliminado"
            fi
            
            # Eliminar grupo webmin si existe
            if getent group webmin >/dev/null 2>&1; then
                $SUDO groupdel webmin 2>/dev/null || true
                log_info "Grupo webmin eliminado"
            fi
            ;;
    esac
    
    log "Usuarios y grupos procesados"
}

# Limpiar configuración de firewall
clean_firewall() {
    log "Limpiando configuración de firewall..."
    
    case "$DISTRO" in
        "macos")
            log_info "Configuración de firewall en macOS debe limpiarse manualmente"
            ;;
        "ubuntu"|"debian")
            if command -v ufw >/dev/null 2>&1; then
                $SUDO ufw delete allow 10000/tcp 2>/dev/null || true
                log_info "Regla de firewall UFW eliminada"
            fi
            ;;
        "centos"|"rhel"|"fedora")
            if command -v firewall-cmd >/dev/null 2>&1; then
                $SUDO firewall-cmd --permanent --remove-port=10000/tcp 2>/dev/null || true
                $SUDO firewall-cmd --reload 2>/dev/null || true
                log_info "Regla de firewall eliminada"
            fi
            ;;
    esac
    
    log "Configuración de firewall limpiada"
}

# Preguntar sobre servicios adicionales
ask_remove_services() {
    echo
    log_warning "¿Desea también desinstalar los servicios adicionales?"
    echo "   • MySQL/MariaDB"
    echo "   • Apache HTTP Server"
    echo "   • PHP"
    echo
    read -p "¿Eliminar servicios adicionales? (s/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[SsYy]$ ]]; then
        remove_additional_services
    else
        log_info "Manteniendo servicios adicionales"
    fi
}

# Eliminar servicios adicionales
remove_additional_services() {
    log "Eliminando servicios adicionales..."
    
    case "$DISTRO" in
        "macos")
            # Detener servicios con Homebrew
            brew services stop mysql 2>/dev/null || true
            brew services stop httpd 2>/dev/null || true
            
            # Desinstalar con Homebrew
            brew uninstall mysql apache2 php 2>/dev/null || true
            ;;
        "ubuntu"|"debian")
            # Detener servicios
            $SUDO systemctl stop mysql apache2 2>/dev/null || true
            $SUDO systemctl disable mysql apache2 2>/dev/null || true
            
            # Desinstalar paquetes
            $SUDO apt-get remove --purge -y mysql-server apache2 php libapache2-mod-php php-mysql 2>/dev/null || true
            $SUDO apt-get autoremove -y 2>/dev/null || true
            ;;
        "centos"|"rhel"|"fedora")
            # Detener servicios
            $SUDO systemctl stop mysqld httpd 2>/dev/null || true
            $SUDO systemctl disable mysqld httpd 2>/dev/null || true
            
            # Desinstalar paquetes
            if command -v dnf >/dev/null 2>&1; then
                $SUDO dnf remove -y mysql-server httpd php php-mysql 2>/dev/null || true
            else
                $SUDO yum remove -y mysql-server httpd php php-mysql 2>/dev/null || true
            fi
            ;;
    esac
    
    log "Servicios adicionales eliminados"
}

# Limpiar archivos temporales
cleanup_temp_files() {
    log "Limpiando archivos temporales..."
    
    # Eliminar archivos de instalación temporales
    rm -rf /tmp/webmin_install 2>/dev/null || true
    rm -rf /tmp/webmin_virtualmin_install 2>/dev/null || true
    
    # Eliminar logs de instalación antiguos
    find /tmp -name "instalacion_webmin_*.log" -mtime +7 -delete 2>/dev/null || true
    
    log "Archivos temporales limpiados"
}

# Verificar desinstalación
verify_removal() {
    log "Verificando desinstalación..."
    
    local issues=0
    
    # Verificar que Webmin no esté ejecutándose
    if pgrep -f "miniserv.pl" >/dev/null 2>&1; then
        log_warning "⚠️  Webmin aún está ejecutándose"
        issues=$((issues + 1))
    else
        log "✅ Webmin no está ejecutándose"
    fi
    
    # Verificar que los directorios fueron eliminados
    for dir in "$WEBMIN_DIR" "$WEBMIN_CONFIG" "$WEBMIN_VAR"; do
        if [[ -d "$dir" ]]; then
            log_warning "⚠️  Directorio aún existe: $dir"
            issues=$((issues + 1))
        fi
    done
    
    if [[ $issues -eq 0 ]]; then
        log "✅ Desinstalación verificada correctamente"
    else
        log_warning "⚠️  Se encontraron $issues problemas durante la verificación"
    fi
    
    return $issues
}

# Mostrar información final
show_final_info() {
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${GREEN}🗑️  DESINSTALACIÓN COMPLETADA${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    echo -e "${BLUE}📋 RESUMEN:${NC}"
    echo "   • Webmin ha sido desinstalado completamente"
    echo "   • Virtualmin ha sido eliminado"
    echo "   • Servicios del sistema detenidos"
    echo "   • Archivos de configuración eliminados"
    echo "   • Usuarios y grupos limpiados"
    echo
    echo -e "${BLUE}📁 ARCHIVOS ELIMINADOS:${NC}"
    echo "   • $WEBMIN_DIR"
    echo "   • $WEBMIN_CONFIG"
    echo "   • $WEBMIN_VAR"
    echo "   • $WEBMIN_LOG"
    echo
    echo -e "${BLUE}📄 LOG DE DESINSTALACIÓN:${NC}"
    echo "   • $LOG_FILE"
    echo
    echo -e "${YELLOW}⚠️  NOTAS IMPORTANTES:${NC}"
    echo "   • Los datos de bases de datos pueden haberse conservado"
    echo "   • Revise manualmente archivos de configuración personalizados"
    echo "   • Algunos archivos de log pueden permanecer en el sistema"
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
}

# Función principal
main() {
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${RED}🗑️  DESINSTALADOR DE WEBMIN Y VIRTUALMIN${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    
    # Advertencia
    echo -e "${YELLOW}⚠️  ADVERTENCIA:${NC}"
    echo "   Este script eliminará completamente Webmin y Virtualmin de su sistema."
    echo "   Esta acción NO se puede deshacer."
    echo
    echo -e "${RED}📋 SE ELIMINARÁN:${NC}"
    echo "   • Todos los archivos de Webmin y Virtualmin"
    echo "   • Configuraciones y datos del panel"
    echo "   • Usuarios y grupos del sistema"
    echo "   • Servicios y procesos relacionados"
    echo
    
    # Confirmación
    read -p "¿Está seguro de que desea continuar? (escriba 'SI' para confirmar): " -r
    if [[ ! $REPLY == "SI" ]]; then
        log "Desinstalación cancelada por el usuario"
        exit 0
    fi
    
    echo
    
    # Detectar sistema
    detect_os
    
    # Verificar permisos
    check_permissions
    
    # Crear log
    mkdir -p "$(dirname "$LOG_FILE")"
    log "Iniciando desinstalación de Webmin y Virtualmin..."
    
    # Ejecutar pasos de desinstalación
    stop_webmin
    remove_webmin_files
    remove_webmin_users
    clean_firewall
    ask_remove_services
    cleanup_temp_files
    
    # Verificar y mostrar resultado
    if verify_removal; then
        show_final_info
        log "🎉 Desinstalación completada exitosamente"
    else
        log_error "❌ La desinstalación se completó con advertencias"
        echo
        echo -e "${YELLOW}🔧 LIMPIEZA MANUAL REQUERIDA:${NC}"
        echo "   • Revise los archivos que no pudieron eliminarse"
        echo "   • Verifique procesos en ejecución manualmente"
        echo "   • Consulte el log para más detalles: $LOG_FILE"
        echo
    fi
}

# Manejo de errores
trap 'log_error "Error en línea $LINENO. Código de salida: $?"; exit 1' ERR

# Ejecutar función principal
main "$@"

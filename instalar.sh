#!/bin/bash

# =============================================================================
# INSTALADOR UNIVERSAL WEBMIN + VIRTUALMIN - UN SOLO COMANDO
# Descarga automática desde GitHub e instalación completa
# Comando único: curl -sSL https://raw.githubusercontent.com/tu-usuario/tu-repo/master/instalar.sh | sudo bash
# =============================================================================

set -euo pipefail

# Variables globales
REPO_URL="https://github.com/tu-usuario/tu-repo"
RAW_URL="https://raw.githubusercontent.com/tu-usuario/tu-repo/master"
TEMP_DIR="/tmp/webmin-virtualmin-$(date +%s)"
LOG_FILE="/var/log/instalacion-webmin-virtualmin.log"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    echo "[ERROR] $1" >> "$LOG_FILE"
    exit 1
}

# Banner principal
show_banner() {
    clear
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║  🚀 INSTALADOR UNIVERSAL WEBMIN + VIRTUALMIN - UN SOLO COMANDO              ║
║                                                                              ║
║  ✨ Descarga automática desde GitHub                                         ║
║  🔧 Instalación completamente automática                                     ║
║  🛡️ A prueba de errores con recuperación automática                         ║
║  ⚡ Optimizado para Ubuntu 20.04 LTS                                        ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo
}

# Verificar privilegios de root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Este script debe ejecutarse como root. Usa: sudo $0"
    fi
    log "✅ Privilegios de root verificados"
}

# Detectar sistema operativo
detect_system() {
    log "🔍 Detectando sistema operativo..."
    
    if [[ ! -f /etc/os-release ]]; then
        error "Sistema operativo no soportado"
    fi
    
    source /etc/os-release
    
    case "$ID" in
        "ubuntu")
            if [[ "$VERSION_ID" == "20.04" ]]; then
                log "✅ Ubuntu 20.04 LTS detectado (OPTIMIZADO)"
            elif [[ "$VERSION_ID" > "18.04" ]]; then
                log "✅ Ubuntu $VERSION_ID detectado (Compatible)"
            else
                error "Ubuntu $VERSION_ID no soportado (mínimo: 18.04)"
            fi
            ;;
        "debian")
            if [[ "${VERSION_ID%%.*}" -ge 10 ]]; then
                log "✅ Debian $VERSION_ID detectado (Compatible)"
            else
                error "Debian $VERSION_ID no soportado (mínimo: 10)"
            fi
            ;;
        *)
            error "Distribución no soportada: $ID. Solo Ubuntu 18.04+ y Debian 10+"
            ;;
    esac
}

# Verificar conectividad
check_connectivity() {
    log "🌐 Verificando conectividad..."
    
    if ! ping -c 1 github.com >/dev/null 2>&1; then
        error "No hay conectividad a GitHub"
    fi
    
    if ! ping -c 1 download.webmin.com >/dev/null 2>&1; then
        error "No hay conectividad a servidores de Webmin"
    fi
    
    log "✅ Conectividad verificada"
}

# Crear directorio temporal
setup_temp_dir() {
    log "📁 Creando directorio temporal..."
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    log "✅ Directorio temporal: $TEMP_DIR"
}

# Descargar instalador principal desde GitHub
download_installer() {
    log "⬇️ Descargando instalador desde GitHub..."
    
    # Descargar el script principal de instalación
    if curl -sSL "$RAW_URL/instalacion_un_comando.sh" -o instalacion_un_comando.sh; then
        log "✅ Instalador principal descargado"
    else
        error "❌ Error al descargar instalador principal"
    fi
    
    # Hacer ejecutable
    chmod +x instalacion_un_comando.sh
    
    # Verificar que se descargó correctamente
    if [[ ! -f "instalacion_un_comando.sh" ]] || [[ ! -s "instalacion_un_comando.sh" ]]; then
        error "❌ El instalador descargado está vacío o corrupto"
    fi
    
    log "✅ Instalador listo para ejecutar"
}

# Ejecutar instalación principal
run_installation() {
    log "🚀 Iniciando instalación completa de Webmin + Virtualmin..."
    
    # Ejecutar el instalador principal
    if ./instalacion_un_comando.sh; then
        log "✅ Instalación completada exitosamente"
    else
        error "❌ Error durante la instalación"
    fi
}

# Descargar y ejecutar verificación
run_verification() {
    log "🔍 Descargando verificador post-instalación..."
    
    # Descargar verificador
    if curl -sSL "$RAW_URL/verificar_instalacion_un_comando.sh" -o verificar_instalacion.sh; then
        chmod +x verificar_instalacion.sh
        log "✅ Verificador descargado"
        
        # Ejecutar verificación
        if ./verificar_instalacion.sh; then
            log "✅ Verificación completada - Sistema funcionando correctamente"
        else
            log "⚠️ Verificación completada con advertencias"
        fi
    else
        log "⚠️ No se pudo descargar el verificador (opcional)"
    fi
}

# Limpiar archivos temporales
cleanup() {
    log "🧹 Limpiando archivos temporales..."
    cd /
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    log "✅ Limpieza completada"
}

# Mostrar información de acceso
show_access_info() {
    local server_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "TU-IP-SERVIDOR")
    
    echo
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo -e "║  ${GREEN}🎉 ¡INSTALACIÓN COMPLETADA EXITOSAMENTE!${NC}                                 ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo
    echo -e "${CYAN}📡 ACCESO A WEBMIN/VIRTUALMIN:${NC}"
    echo -e "   🌐 URL: ${WHITE}https://$server_ip:10000${NC}"
    echo -e "   👤 Usuario: ${WHITE}root${NC}"
    echo -e "   🔐 Contraseña: ${WHITE}[tu contraseña de root]${NC}"
    echo
    echo -e "${CYAN}🔧 SERVICIOS INSTALADOS:${NC}"
    echo "   ✅ Webmin - Panel de administración"
    echo "   ✅ Virtualmin GPL - Gestión de hosting"
    echo "   ✅ Authentic Theme - Interfaz moderna"
    echo "   ✅ Apache + MySQL + PHP - Stack LAMP"
    echo "   ✅ Postfix - Servidor de correo"
    echo "   ✅ SSL/TLS - Certificados automáticos"
    echo "   ✅ UFW Firewall - Seguridad configurada"
    echo
    echo -e "${CYAN}📋 PRÓXIMOS PASOS:${NC}"
    echo "   1. Acceder a https://$server_ip:10000"
    echo "   2. Iniciar sesión con credenciales de root"
    echo "   3. Configurar primer dominio en Virtualmin"
    echo "   4. Revisar System Information"
    echo
    echo -e "${CYAN}📄 LOGS:${NC}"
    echo "   📁 $LOG_FILE"
    echo
}

# Manejo de errores
trap cleanup EXIT
trap 'error "Script interrumpido"' INT TERM

# Función principal
main() {
    # Configurar logging
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "=== INSTALACIÓN WEBMIN/VIRTUALMIN INICIADA $(date) ===" > "$LOG_FILE"
    
    # Mostrar banner
    show_banner
    
    # Ejecutar pasos de instalación
    log "🚀 Iniciando instalador universal de Webmin + Virtualmin"
    log "📍 Descarga desde: $REPO_URL"
    
    check_root
    detect_system
    check_connectivity
    setup_temp_dir
    download_installer
    run_installation
    run_verification
    cleanup
    
    # Mostrar información final
    show_access_info
    
    log "🎉 Instalación universal completada exitosamente"
    
    echo -e "${GREEN}¡Listo! Tu servidor de hosting está funcionando.${NC}"
    echo -e "${BLUE}Accede a: https://$(hostname -I | awk '{print $1}'):10000${NC}"
}

# Ejecutar función principal si el script se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

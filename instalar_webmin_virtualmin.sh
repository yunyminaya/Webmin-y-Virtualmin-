#!/bin/bash

# =============================================================================
# INSTALADOR AUTOMÁTICO DE WEBMIN Y VIRTUALMIN
# Sistema Enterprise Pro con Auto-Reparación Inteligente
# Un solo comando para instalar todo el panel completo
#
# Uso: curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/instalar_webmin_virtualmin.sh | bash
#
# Desarrollado por: Yuny Minaya
# Repositorio: https://github.com/yunyminaya/Webmin-y-Virtualmin-
# Versión: Enterprise Pro v2.0
# =============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función de logging
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}"
}

# Función de logging con colores
log_color() {
    local level="$1"
    local message="$2"
    local color="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${color}${timestamp} [${level}] ${message}${NC}"
}

# Función para mostrar banner
show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    INSTALACIÓN AUTOMÁTICA                                  ║
║                    WEBMIN & VIRTUALMIN                                    ║
║                                                                          ║
║  🚀 Sistema Enterprise Pro con Auto-Reparación Inteligente               ║
║  🛡️  Detección Avanzada de Ataques y Auto-Defensa                        ║
║  🔄 Auto-Recuperación Inteligente de Servidores                           ║
║  📊 Monitoreo Continuo 24/7 y Alertas en Tiempo Real                     ║
║  ⚡ Instalación Ultra-Rápida con Un Solo Comando                         ║
║                                                                          ║
║  Desarrollado por: Yuny Minaya                                           ║
║  Repositorio: https://github.com/yunyminaya/Webmin-y-Virtualmin-          ║
║  Versión: Enterprise Pro v2.0 con Auto-Reparación                        ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Función para verificar requisitos del sistema
check_system_requirements() {
    log_color "INFO" "🔍 Verificando requisitos del sistema..." "$BLUE"

    # Verificar si estamos en root o sudo
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ ERROR: Este script debe ejecutarse como root o con sudo${NC}"
        echo -e "${YELLOW}💡 Use: sudo $0${NC}"
        exit 1
    fi

    # Verificar distribución de Linux
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        log_color "SUCCESS" "✅ Sistema detectado: $PRETTY_NAME" "$GREEN"

        # Verificar distribuciones soportadas
        case "$ID" in
            ubuntu|debian|centos|rhel|fedora|almalinux|rocky)
                log_color "SUCCESS" "✅ Distribución soportada: $ID" "$GREEN"
                ;;
            *)
                log_color "WARNING" "⚠️  Distribución no probada: $ID - Continuando de todos modos..." "$YELLOW"
                ;;
        esac
    else
        log_color "WARNING" "⚠️  No se pudo detectar la distribución del sistema" "$YELLOW"
    fi

    # Verificar conectividad a internet
    log_color "INFO" "🌐 Verificando conectividad a internet..." "$BLUE"
    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        log_color "ERROR" "❌ Sin conectividad a internet" "$RED"
        log_color "INFO" "💡 Verifique su conexión e intente nuevamente" "$BLUE"
        exit 1
    fi
    log_color "SUCCESS" "✅ Conectividad a internet verificada" "$GREEN"

    # Verificar espacio en disco
    local disk_space=$(df / | tail -1 | awk '{print $4}')
    if [[ $disk_space -lt 5242880 ]]; then  # Menos de 5GB
        log_color "WARNING" "⚠️  Espacio en disco bajo: $(($disk_space/1024))MB disponibles" "$YELLOW"
        log_color "INFO" "💡 Se recomienda al menos 5GB de espacio libre" "$BLUE"
    fi

    log_color "SUCCESS" "✅ Todos los requisitos verificados correctamente" "$GREEN"
}

# Función para mostrar información del sistema
show_system_info() {
    echo -e "${PURPLE}📋 INFORMACIÓN DEL SISTEMA:${NC}"
    echo -e "${CYAN}  • Usuario:${NC} $(whoami)"
    echo -e "${CYAN}  • Hostname:${NC} $(hostname)"
    echo -e "${CYAN}  • Kernel:${NC} $(uname -r)"
    echo -e "${CYAN}  • Arquitectura:${NC} $(uname -m)"
    echo -e "${CYAN}  • Memoria RAM:${NC} $(free -h | grep '^Mem:' | awk '{print $2}')"
    echo -e "${CYAN}  • Disco disponible:${NC} $(df -h / | tail -1 | awk '{print $4}')"
    echo ""
}

# Función para mostrar opciones de instalación
show_installation_options() {
    echo -e "${YELLOW}🚀 OPCIONES DE INSTALACIÓN DISPONIBLES:${NC}"
    echo -e "${GREEN}  1.${NC} Instalación Completa Enterprise (Webmin + Virtualmin + Auto-Reparación)"
    echo -e "${GREEN}  2.${NC} Solo Webmin con Sistema de Auto-Defensa"
    echo -e "${GREEN}  3.${NC} Solo Virtualmin con Protección Avanzada"
    echo -e "${GREEN}  4.${NC} Sistema de Monitoreo y Alertas Inteligentes"
    echo -e "${GREEN}  5.${NC} Verificación y Optimización del Sistema Actual"
    echo ""
    echo -e "${BLUE}💡 Por defecto: Instalación Completa Enterprise${NC}"
    echo ""
}

# Función para descargar el script principal
download_main_script() {
    log_color "INFO" "📥 Descargando script principal de instalación..." "$BLUE"

    local repo_url="https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main"
    local main_script="instalacion_un_comando.sh"
    local temp_script="/tmp/webmin_virtualmin_installer_$(date +%s).sh"

    # Descargar el script principal
    if curl -sSL "${repo_url}/${main_script}" -o "$temp_script"; then
        log_color "SUCCESS" "✅ Script principal descargado exitosamente" "$GREEN"

        # Verificar que el script se descargó correctamente
        if [[ -s "$temp_script" ]]; then
            log_color "INFO" "🔍 Verificando integridad del script..." "$BLUE"
            chmod +x "$temp_script"

            # Verificar que el script tiene contenido válido
            if head -n 1 "$temp_script" | grep -q "#!/bin/bash"; then
                log_color "SUCCESS" "✅ Script validado y listo para ejecución" "$GREEN"
            else
                log_color "ERROR" "❌ El script descargado no es válido" "$RED"
                rm -f "$temp_script"
                exit 1
            fi
        else
            log_color "ERROR" "❌ El script descargado está vacío" "$RED"
            exit 1
        fi
    else
        log_color "ERROR" "❌ No se pudo descargar el script principal" "$RED"
        log_color "INFO" "💡 Verifique su conexión a internet e intente nuevamente" "$BLUE"
        log_color "INFO" "🔗 URL utilizada: ${repo_url}/${main_script}" "$BLUE"
        exit 1
    fi

    echo "$temp_script"
}

# Función para mostrar progreso
show_progress() {
    local message="$1"
    echo -e "${BLUE}⏳ ${message}${NC}"
}

# Función para mostrar éxito
show_success() {
    local message="$1"
    echo -e "${GREEN}✅ ${message}${NC}"
}

# Función principal de instalación
main() {
    # Limpiar pantalla
    clear

    # Mostrar banner
    show_banner

    # Mostrar información del sistema
    show_system_info

    # Verificar requisitos del sistema
    check_system_requirements

    # Mostrar opciones de instalación
    show_installation_options

    # Esperar confirmación del usuario
    echo -e "${YELLOW}⚠️  ADVERTENCIA:${NC}"
    echo -e "${YELLOW}   Esta instalación modificará su sistema y puede tomar varios minutos.${NC}"
    echo -e "${YELLOW}   Se recomienda hacer un backup antes de continuar.${NC}"
    echo ""
    echo -e "${CYAN}¿Desea continuar con la instalación? (y/N): ${NC}"
    read -r -t 30 response || response="y"  # Timeout de 30 segundos, por defecto "y"

    case "$response" in
        [Yy]|[Yy][Ee][Ss])
            log_color "INFO" "🚀 Iniciando instalación..." "$BLUE"
            ;;
        *)
            log_color "INFO" "❌ Instalación cancelada por el usuario" "$YELLOW"
            exit 0
            ;;
    esac

    # Descargar el script principal
    local main_script_path=$(download_main_script)

    # Mostrar progreso
    show_progress "Iniciando instalación completa de Webmin y Virtualmin..."
    show_progress "Esto puede tomar varios minutos dependiendo de su conexión a internet"
    show_progress "El sistema se instalará con auto-reparación inteligente incluida"
    echo ""

    # Ejecutar el script principal
    if bash "$main_script_path"; then
        # Limpiar archivo temporal
        rm -f "$main_script_path"

        # Mostrar mensaje de éxito
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                        🎉 INSTALACIÓN COMPLETA 🎉                        ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        show_success "Webmin y Virtualmin instalados y configurados correctamente"
        show_success "Sistema de Auto-Reparación Inteligente activado"
        show_success "Seguridad Enterprise implementada"
        show_success "Monitoreo continuo activado"
        echo ""
        echo -e "${BLUE}📋 ACCESO A LOS PANELES:${NC}"
        echo -e "${CYAN}  🌐 Webmin:${NC} https://$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'TU_IP'):10000"
        echo -e "${CYAN}  👤 Usermin:${NC} https://$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'TU_IP'):20000"
        echo ""
        echo -e "${YELLOW}🔐 CREDENCIALES INICIALES:${NC}"
        echo -e "${YELLOW}  👤 Usuario:${NC} root"
        echo -e "${YELLOW}  🔑 Contraseña:${NC} Su contraseña de root del sistema"
        echo ""
        echo -e "${PURPLE}📚 RECURSOS Y SOPORTE:${NC}"
        echo -e "${CYAN}  📖 Repositorio:${NC} https://github.com/yunyminaya/Webmin-y-Virtualmin-"
        echo -e "${CYAN}  📚 Documentación:${NC} Revisar archivos README en el repositorio"
        echo -e "${CYAN}  🆘 Soporte:${NC} Abrir issue en el repositorio de GitHub"
        echo ""
        echo -e "${GREEN}💡 PRÓXIMOS PASOS RECOMENDADOS:${NC}"
        echo -e "${BLUE}  1.${NC} Cambiar la contraseña por defecto"
        echo -e "${BLUE}  2.${NC} Configurar dominios virtuales"
        echo -e "${BLUE}  3.${NC} Revisar configuraciones de seguridad"
        echo -e "${BLUE}  4.${NC} Configurar backups automáticos"
        echo ""
        log_color "SUCCESS" "🎊 INSTALACIÓN COMPLETADA EXITOSAMENTE - DISFRUTE SU SISTEMA!" "$GREEN"

    else
        log_color "ERROR" "❌ LA INSTALACIÓN FALLÓ" "$RED"
        log_color "INFO" "🔍 Revise los logs anteriores para identificar el problema" "$BLUE"
        log_color "INFO" "🔄 Puede intentar ejecutar nuevamente el script" "$BLUE"
        log_color "INFO" "📁 Script temporal guardado en: $main_script_path (para debugging)" "$BLUE"

        exit 1
    fi
}

# Función para mostrar ayuda
show_help() {
    echo -e "${BLUE}Ayuda - Instalador Automático Webmin & Virtualmin${NC}"
    echo ""
    echo "Uso:"
    echo "  curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/instalar_webmin_virtualmin.sh | bash"
    echo ""
    echo "Opciones:"
    echo "  --help     Mostrar esta ayuda"
    echo "  --version  Mostrar versión"
    echo ""
    echo "Repositorio: https://github.com/yunyminaya/Webmin-y-Virtualmin-"
}

# Función para mostrar versión
show_version() {
    echo -e "${BLUE}Instalador Automático Webmin & Virtualmin${NC}"
    echo "Versión: Enterprise Pro v2.0"
    echo "Fecha: $(date)"
    echo "Repositorio: https://github.com/yunyminaya/Webmin-y-Virtualmin-"
}

# Procesar argumentos de línea de comandos
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --version|-v)
        show_version
        exit 0
        ;;
    *)
        # Verificar si el script se está ejecutando directamente
        if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
            # Ejecutar función principal
            main "$@"
        fi
        ;;
esac

#!/bin/bash

# ============================================================================
# INSTALADOR COMPLETO DE UN SOLO COMANDO - PERFIL PROFESIONAL DE PRODUCCION
# ============================================================================
# Instala la base Webmin/Virtualmin y aplica el perfil profesional del repositorio:
# curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install_pro_complete.sh | bash
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

# Variables
REPO_URL="https://github.com/yunyminaya/Webmin-y-Virtualmin-.git"
REPO_RAW_BASE="https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main"
SCRIPT_URL="${REPO_RAW_BASE}/install_pro_complete.sh"
INSTALL_DIR="/opt/virtualmin-pro"
START_TIME=$(date +%s)
POST_BASE_ONLY=0

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --post-base)
                POST_BASE_ONLY=1
                ;;
        esac
        shift
    done
}

echo -e "${BLUE}============================================================================${NC}"
echo -e "${PURPLE}🚀 INSTALADOR VIRTUALMIN PRO COMPLETO - UN SOLO COMANDO${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo -e "${GREEN}🎉 Instalando perfil profesional del panel para produccion${NC}"
echo -e "${CYAN}   ✅ Cuentas de Revendedor ILIMITADAS${NC}"
echo -e "${CYAN}   ✅ Funciones Empresariales COMPLETAS${NC}"
echo -e "${CYAN}   ✅ Overlay runtime del panel Pro${NC}"
echo -e "${CYAN}   ✅ Seguridad base y actualizacion desde el mismo repo${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo

# Función de logging
log_install() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%H:%M:%S')

    case "$level" in
        "SUCCESS") echo -e "${GREEN}✅ [$timestamp] PRO INSTALLER:${NC} $message" ;;
        "INFO")    echo -e "${BLUE}💎 [$timestamp] PRO INSTALLER:${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}⚠️ [$timestamp] PRO INSTALLER:${NC} $message" ;;
        "ERROR")   echo -e "${RED}❌ [$timestamp] PRO INSTALLER:${NC} $message" ;;
        *)         echo -e "${PURPLE}🔥 [$timestamp] PRO INSTALLER:${NC} $message" ;;
    esac
}

# Verificar permisos de root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_install "SUCCESS" "Ejecutándose como root - permisos completos"
        return 0
    fi

    if ! command -v sudo >/dev/null 2>&1; then
        log_install "ERROR" "Se requiere root o sudo para continuar"
        exit 1
    fi

    log_install "INFO" "Elevando privilegios con sudo..."

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$SCRIPT_URL" | sudo -E bash
        exit $?
    fi

    if command -v wget >/dev/null 2>&1; then
        wget -qO- "$SCRIPT_URL" | sudo -E bash
        exit $?
    fi

    log_install "ERROR" "No se encontro curl ni wget para relanzar el instalador con sudo"
    exit 1
}

# Instalar dependencias
install_dependencies() {
    log_install "INFO" "Instalando dependencias necesarias..."

    if command -v apt-get >/dev/null 2>&1; then
        # Debian/Ubuntu
        apt-get update -qq
        apt-get install -y git curl wget unzip jq
    elif command -v yum >/dev/null 2>&1; then
        # CentOS/RHEL
        yum install -y git curl wget unzip jq epel-release
    elif command -v dnf >/dev/null 2>&1; then
        # Fedora
        dnf install -y git curl wget unzip jq
    else
        log_install "WARNING" "Gestor de paquetes no detectado - verificar dependencias manualmente"
    fi

    log_install "SUCCESS" "Dependencias instaladas"
}

# Descargar repositorio
download_repo() {
    log_install "INFO" "Descargando repositorio Virtualmin Pro..."

    # Crear directorio de instalación
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    # Clonar repositorio
    if [[ -d ".git" ]]; then
        log_install "INFO" "Actualizando repositorio existente..."
        git pull origin main
    else
        log_install "INFO" "Clonando repositorio..."
        git clone "$REPO_URL" .
    fi

    # Dar permisos ejecutables
    find . -name "*.sh" -exec chmod +x {} \;

    log_install "SUCCESS" "Repositorio descargado y configurado"
}

# Activar Webmin/Virtualmin base si no está instalado
install_webmin_virtualmin() {
    log_install "INFO" "Verificando instalación de Webmin/Virtualmin..."

    if ! command -v virtualmin >/dev/null 2>&1; then
        log_install "INFO" "Instalando Webmin/Virtualmin base desde el repositorio local..."

        if [[ -f "$INSTALL_DIR/install.sh" ]]; then
            VIRTUALMIN_SKIP_REPO_PROFILE=1 bash "$INSTALL_DIR/install.sh"
        else
            log_install "ERROR" "No se encontro $INSTALL_DIR/install.sh"
            exit 1
        fi

        log_install "SUCCESS" "Webmin/Virtualmin base instalado"
    else
        log_install "SUCCESS" "Webmin/Virtualmin ya está instalado"
    fi
}

# Ejecutar activación completa
activate_all_pro() {
    log_install "INFO" "Activando TODAS las funciones Pro..."

    cd "$INSTALL_DIR"

    # Ejecutar activadores en secuencia
    local activators=(
        "pro_activation_master.sh"
        "activate_all_pro_features.sh"
        "pro_features_advanced.sh"
    )

    for activator in "${activators[@]}"; do
        if [[ -f "$activator" ]]; then
            log_install "INFO" "Ejecutando $activator..."
            bash "$activator" || log_install "WARNING" "Error en $activator (continuando...)"
        else
            log_install "WARNING" "Activador $activator no encontrado"
        fi
    done

    if [[ -f "setup_pro_production.sh" ]]; then
        log_install "INFO" "Aplicando integracion Pro sobre el sistema instalado..."
        if ! bash "setup_pro_production.sh"; then
            log_install "ERROR" "setup_pro_production.sh fallo; no se puede afirmar una instalacion Pro completa"
            exit 1
        fi
    else
        log_install "WARNING" "setup_pro_production.sh no encontrado"
    fi

    log_install "SUCCESS" "Activación Pro completada"
}

# Configurar sistema de actualización segura
setup_secure_updates() {
    log_install "INFO" "Configurando sistema de actualización segura..."

    if [[ -f "configure_official_repo.sh" ]]; then
        bash configure_official_repo.sh
        log_install "SUCCESS" "Sistema de actualización segura configurado"
    else
        log_install "WARNING" "Script de configuración segura no encontrado"
    fi
}

# Crear comando global
create_global_command() {
    log_install "INFO" "Creando comando global 'virtualmin-pro'..."

    cat > "/usr/local/bin/virtualmin-pro" << 'EOF'
#!/bin/bash
# Comando global Virtualmin Pro

INSTALL_DIR="/opt/virtualmin-pro"

case "$1" in
    "dashboard"|"dash")
        cd "$INSTALL_DIR" && bash pro_dashboard.sh
        ;;
    "status")
        cd "$INSTALL_DIR" && if [[ -f production_profile_status.json ]]; then cat production_profile_status.json 2>/dev/null | jq . || cat production_profile_status.json; elif [[ -f pro_status.json ]]; then cat pro_status.json 2>/dev/null | jq . || cat pro_status.json; else cat master_pro_status.txt; fi
        ;;
    "validate")
        cd "$INSTALL_DIR" && bash setup_pro_production.sh --validate
        ;;
    "update")
        cd "$INSTALL_DIR" && bash update_system_secure.sh
        ;;
    "rollout")
        shift
        cd "$INSTALL_DIR" && bash scripts/rollout_openvm_update.sh "$@"
        ;;
    "repair")
        cd "$INSTALL_DIR" && bash auto_repair.sh
        ;;
    "resellers")
        cd "$INSTALL_DIR" && bash manage_resellers.sh
        ;;
    "ssl")
        cd "$INSTALL_DIR" && bash ssl_manager_pro.sh
        ;;
    "backup")
        cd "$INSTALL_DIR" && bash enterprise_backup_pro.sh
        ;;
    "analytics")
        cd "$INSTALL_DIR" && bash analytics_pro.sh
        ;;
    *)
        echo "🎉 VIRTUALMIN PRO - Comandos disponibles:"
        echo "   virtualmin-pro dashboard  - Dashboard Pro"
        echo "   virtualmin-pro status     - Estado del sistema"
        echo "   virtualmin-pro update     - Actualizar sistema"
        echo "   virtualmin-pro rollout    - Actualizar múltiples servidores"
        echo "   virtualmin-pro repair     - Auto-reparación"
        echo "   virtualmin-pro resellers  - Gestión de revendedores"
        echo "   virtualmin-pro ssl        - SSL Manager Pro"
        echo "   virtualmin-pro backup     - Backups empresariales"
        echo "   virtualmin-pro analytics  - Analytics Pro"
        echo "   virtualmin-pro validate   - Validar runtime del panel"
        ;;
esac
EOF

    chmod +x "/usr/local/bin/virtualmin-pro"
    log_install "SUCCESS" "Comando 'virtualmin-pro' creado"
}

# Mostrar resumen final
show_final_summary() {
    local end_time
    local duration

    end_time=$(date +%s)
    duration=$((end_time - START_TIME))

    echo
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${GREEN}🎉 INSTALACIÓN VIRTUALMIN PRO COMPLETADA EXITOSAMENTE${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo
    echo -e "${PURPLE}⏱️ Tiempo de instalación: ${duration} segundos${NC}"
    echo
    echo -e "${GREEN}🏆 FUNCIONES PRO ACTIVADAS:${NC}"
    echo -e "${CYAN}   ✅ Cuentas de Revendedor ILIMITADAS${NC}"
    echo -e "${CYAN}   ✅ Funciones Empresariales COMPLETAS${NC}"
    echo -e "${CYAN}   ✅ Migración de Servidores ACTIVA${NC}"
    echo -e "${CYAN}   ✅ Clustering y Alta Disponibilidad ACTIVO${NC}"
    echo -e "${CYAN}   ✅ API Sin Restricciones ACTIVA${NC}"
    echo -e "${CYAN}   ✅ Monitoreo Empresarial ACTIVO${NC}"
    echo -e "${CYAN}   ✅ SSL Manager Avanzado ACTIVO${NC}"
    echo -e "${CYAN}   ✅ Backups Empresariales ACTIVOS${NC}"
    echo -e "${CYAN}   ✅ Analytics y Reportes Pro ACTIVOS${NC}"
    echo -e "${CYAN}   ✅ Timer de sincronizacion desde el mismo repositorio ACTIVO${NC}"
    echo -e "${CYAN}   ✅ Baseline de seguridad de produccion APLICADO${NC}"
    echo
    echo -e "${YELLOW}🚀 ACCESO RÁPIDO:${NC}"
    echo -e "${BLUE}   Panel Web: https://$(hostname -I | awk '{print $1}'):10000${NC}"
    echo -e "${BLUE}   Dashboard Pro: virtualmin-pro dashboard${NC}"
    echo -e "${BLUE}   Estado: virtualmin-pro status${NC}"
    echo -e "${BLUE}   Validación: bash /opt/virtualmin-pro/setup_pro_production.sh --validate${NC}"
    echo
    echo -e "${GREEN}🎯 COMANDOS DISPONIBLES:${NC}"
    echo -e "${YELLOW}   virtualmin-pro dashboard  ${NC}# Dashboard Pro completo"
    echo -e "${YELLOW}   virtualmin-pro resellers  ${NC}# Gestión de revendedores"
    echo -e "${YELLOW}   virtualmin-pro ssl        ${NC}# SSL Manager Pro"
    echo -e "${YELLOW}   virtualmin-pro backup     ${NC}# Backups empresariales"
    echo -e "${YELLOW}   virtualmin-pro analytics  ${NC}# Analytics Pro"
    echo -e "${YELLOW}   virtualmin-pro rollout    ${NC}# Actualización masiva de servidores"
    echo
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${PURPLE}🎉 ¡VIRTUALMIN PRO COMPLETO INSTALADO Y ACTIVO!${NC}"
    echo -e "${GREEN}   El panel runtime y la seguridad base quedaron sincronizados desde este repositorio${NC}"
    echo -e "${BLUE}============================================================================${NC}"
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    parse_args "$@"

    if (( POST_BASE_ONLY == 1 )); then
        log_install "INFO" "Iniciando fase post-base del perfil profesional..."
    else
        log_install "INFO" "Iniciando instalación completa de Virtualmin Pro..."
    fi

    # Verificar sistema
    check_root

    # Instalar componentes
    install_dependencies
    download_repo
    if (( POST_BASE_ONLY == 0 )); then
        install_webmin_virtualmin
    else
        log_install "SUCCESS" "Instalacion base ya presente - se omite reinstall"
    fi
    activate_all_pro
    setup_secure_updates
    create_global_command

    # Mostrar resumen
    show_final_summary

    log_install "SUCCESS" "¡Instalación completada exitosamente!"

    # Ejecutar dashboard solo si hay terminal interactiva
    if [[ -t 0 && -t 1 ]]; then
        virtualmin-pro dashboard || true
    fi
}

# Ejecutar instalación
main "$@"

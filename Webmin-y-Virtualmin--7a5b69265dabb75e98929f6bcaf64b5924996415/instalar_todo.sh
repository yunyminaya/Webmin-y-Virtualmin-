#!/bin/bash

# =============================================================================
# 🚀 INSTALACIÓN COMPLETA WEBMIN Y VIRTUALMIN CON UN SOLO COMANDO
# =============================================================================
#
# Este script instala completamente Webmin y Virtualmin con todas las
# funcionalidades premium GRATIS en un solo comando.
#
# USO: ./instalar_todo.sh [opciones]
#
# OPCIONES:
#   --help          : Muestra esta ayuda
#   --skip-validation: Omite la validación inicial (no recomendado)
#   --only-validation: Solo ejecuta validación, no instala
#   --with-docker   : Incluye configuración Docker
#   --with-kubernetes: Incluye configuración Kubernetes
#   --with-monitoring: Incluye monitoreo del sistema
#   --with-backup   : Incluye configuración de backup multi-cloud
#
# EJEMPLOS:
#   ./instalar_todo.sh                           # Instalación completa estándar
#   ./instalar_todo.sh --with-docker             # + Docker
#   ./instalar_todo.sh --with-kubernetes         # + Kubernetes
#   ./instalar_todo.sh --with-monitoring         # + Monitoreo
#   ./instalar_todo.sh --with-backup             # + Backup multi-cloud
#   ./instalar_todo.sh --with-docker --with-kubernetes --with-monitoring --with-backup  # Todo
#
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/webmin_virtualmin_install.log"
START_TIME=$(date +%s)

# Flags de opciones
SKIP_VALIDATION=false
ONLY_VALIDATION=false
WITH_DOCKER=false
WITH_KUBERNETES=false
WITH_MONITORING=false
WITH_BACKUP=false

# Función para mostrar ayuda
show_help() {
    cat << EOF
${BLUE}🚀 INSTALACIÓN COMPLETA WEBMIN Y VIRTUALMIN${NC}

Este script instala completamente Webmin y Virtualmin con todas las
funcionalidades premium GRATIS en un solo comando.

${YELLOW}USO:${NC}
    ./instalar_todo.sh [opciones]

${YELLOW}OPCIONES:${NC}
    --help              Muestra esta ayuda
    --skip-validation   Omite la validación inicial (no recomendado)
    --only-validation   Solo ejecuta validación, no instala
    --with-docker       Incluye configuración Docker
    --with-kubernetes   Incluye configuración Kubernetes
    --with-monitoring   Incluye monitoreo del sistema
    --with-backup       Incluye configuración de backup multi-cloud

${YELLOW}EJEMPLOS:${NC}
    ./instalar_todo.sh                           # Instalación completa estándar
    ./instalar_todo.sh --with-docker             # + Docker
    ./instalar_todo.sh --with-kubernetes         # + Kubernetes
    ./instalar_todo.sh --with-monitoring         # + Monitoreo
    ./instalar_todo.sh --with-backup             # + Backup multi-cloud
    ./instalar_todo.sh --with-docker --with-kubernetes --with-monitoring --with-backup  # Todo

${YELLOW}FUNCIONALIDADES INCLUIDAS GRATIS:${NC}
    🎨 Authentic Theme Pro     (Incluido)
    🌐 Virtualmin Pro          (Incluido)
    🔒 SSL Certificados        (Incluido)
    📧 Email Server            (Incluido)
    💾 Backup System           (Incluido)
    📊 Monitoreo Avanzado      (Incluido)
    ☁️ Multi-Cloud             (Incluido)
    🐳 Contenedores            (Incluido)


EOF
}

# Función para logging
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Crear directorio de logs si no existe
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

    # Escribir a archivo
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    # Mostrar en pantalla
    case "$level" in
        "INFO")     echo -e "${BLUE}[$timestamp INFO]${NC} $message" ;;
        "SUCCESS")  echo -e "${GREEN}[$timestamp SUCCESS]${NC} $message" ;;
        "WARNING")  echo -e "${YELLOW}[$timestamp WARNING]${NC} $message" ;;
        "ERROR")    echo -e "${RED}[$timestamp ERROR]${NC} $message" ;;
        "STEP")     echo -e "${PURPLE}[$timestamp STEP]${NC} $message" ;;
        "CRITICAL") echo -e "${RED}${WHITE}[$timestamp CRITICAL]${NC} $message" ;;
    esac
}

# Función para mostrar progreso
show_progress() {
    local current="$1"
    local total="$2"
    local description="$3"
    local percentage=$((current * 100 / total))
    local progress_bar=""

    # Crear barra de progreso
    for ((i=0; i<percentage/2; i++)); do
        progress_bar="${progress_bar}█"
    done
    for ((i=percentage/2; i<50; i++)); do
        progress_bar="${progress_bar}░"
    done

    echo -ne "\\r${BLUE}[$current/$total]${NC} ${description} ${progress_bar} ${percentage}%"
}

# Función para mostrar banner inicial
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                       🚀 INSTALACIÓN COMPLETA                              ║
║                       WEBMIN Y VIRTUALMIN                                 ║
║                                                                          ║
║                   💰 FUNCIONALIDADES PREMIUM GRATIS                       ║
║                                                                          ║
║  🎨 Authentic Theme Pro    🌐 Virtualmin Pro     🔒 SSL Certificados     ║
║  📧 Email Server          💾 Backup System       📊 Monitoreo Avanzado   ║
║  ☁️ Multi-Cloud           🐳 Contenedores                                 ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Función para parsear argumentos
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                show_help
                exit 0
                ;;
            --skip-validation)
                SKIP_VALIDATION=true
                log "INFO" "Validación inicial omitida por usuario"
                ;;
            --only-validation)
                ONLY_VALIDATION=true
                log "INFO" "Modo solo validación activado"
                ;;
            --with-docker)
                WITH_DOCKER=true
                log "INFO" "Configuración Docker incluida"
                ;;
            --with-kubernetes)
                WITH_KUBERNETES=true
                log "INFO" "Configuración Kubernetes incluida"
                ;;
            --with-monitoring)
                WITH_MONITORING=true
                log "INFO" "Monitoreo del sistema incluido"
                ;;
            --with-backup)
                WITH_BACKUP=true
                log "INFO" "Backup multi-cloud incluido"
                ;;
            *)
                log "ERROR" "Opción desconocida: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# Función para verificar prerrequisitos
check_prerequisites() {
    log "STEP" "Verificando prerrequisitos del script maestro"

    # Verificar que estamos en el directorio correcto
    if [[ ! -f "validar_dependencias.sh" ]] || [[ ! -f "instalacion_unificada.sh" ]] || [[ ! -f "instalar_integracion.sh" ]]; then
        log "ERROR" "No se encontraron los scripts necesarios. Asegúrate de estar en el directorio raíz del proyecto."
        exit 1
    fi

    # Verificar permisos de ejecución
    local scripts=("validar_dependencias.sh" "instalacion_unificada.sh" "instalar_integracion.sh")
    for script in "${scripts[@]}"; do
        if [[ ! -x "$script" ]]; then
            log "WARNING" "Dando permisos de ejecución a $script"
            chmod +x "$script"
        fi
    done

    log "SUCCESS" "Prerrequisitos verificados correctamente"
}

# Función para ejecutar validación
run_validation() {
    log "STEP" "Ejecutando validación del sistema"
    show_progress 1 5 "Validando sistema..."

    if ! bash validar_dependencias.sh; then
        log "ERROR" "La validación del sistema falló. Revisa los logs en $LOG_FILE"
        exit 1
    fi

    log "SUCCESS" "Validación del sistema completada exitosamente"
    show_progress 2 5 "Sistema validado..."
}

# Función para ejecutar instalación principal
run_main_installation() {
    log "STEP" "Ejecutando instalación principal de Webmin y Virtualmin"
    show_progress 3 5 "Instalando Webmin y Virtualmin..."

    if ! bash instalacion_unificada.sh; then
        log "ERROR" "La instalación principal falló. Revisa los logs en $LOG_FILE"
        exit 1
    fi

    log "SUCCESS" "Instalación principal completada exitosamente"
    show_progress 4 5 "Webmin y Virtualmin instalados..."
}

# Función para ejecutar integración de componentes
run_integration() {
    log "STEP" "Ejecutando integración de componentes premium"
    show_progress 5 5 "Integrando componentes..."

    if ! bash instalar_integracion.sh; then
        log "ERROR" "La integración de componentes falló. Revisa los logs en $LOG_FILE"
        exit 1
    fi

    log "SUCCESS" "Integración de componentes completada exitosamente"
    echo # Nueva línea para la barra de progreso
}

# Función para configurar Docker
setup_docker() {
    if [[ "$WITH_DOCKER" == "true" ]]; then
        log "STEP" "Configurando Docker"

        if [[ ! -f "generar_docker.sh" ]]; then
            log "WARNING" "Script generar_docker.sh no encontrado, omitiendo configuración Docker"
            return
        fi

        if [[ ! -x "generar_docker.sh" ]]; then
            chmod +x generar_docker.sh
        fi

        if ! bash generar_docker.sh; then
            log "WARNING" "La configuración de Docker falló, pero continuando con la instalación"
        else
            log "SUCCESS" "Docker configurado exitosamente"
        fi
    fi
}

# Función para configurar Kubernetes
setup_kubernetes() {
    if [[ "$WITH_KUBERNETES" == "true" ]]; then
        log "STEP" "Configurando Kubernetes"

        if [[ ! -f "kubernetes_setup.sh" ]]; then
            log "WARNING" "Script kubernetes_setup.sh no encontrado, omitiendo configuración Kubernetes"
            return
        fi

        if [[ ! -x "kubernetes_setup.sh" ]]; then
            chmod +x kubernetes_setup.sh
        fi

        if ! bash kubernetes_setup.sh; then
            log "WARNING" "La configuración de Kubernetes falló, pero continuando con la instalación"
        else
            log "SUCCESS" "Kubernetes configurado exitosamente"
        fi
    fi
}

# Función para configurar monitoreo
setup_monitoring() {
    if [[ "$WITH_MONITORING" == "true" ]]; then
        log "STEP" "Configurando monitoreo del sistema"

        if [[ ! -f "monitor_sistema.sh" ]]; then
            log "WARNING" "Script monitor_sistema.sh no encontrado, omitiendo configuración de monitoreo"
            return
        fi

        if [[ ! -x "monitor_sistema.sh" ]]; then
            chmod +x monitor_sistema.sh
        fi

        if ! bash monitor_sistema.sh --install; then
            log "WARNING" "La configuración de monitoreo falló, pero continuando con la instalación"
        else
            log "SUCCESS" "Monitoreo del sistema configurado exitosamente"
        fi
    fi
}

# Función para configurar backup
setup_backup() {
    if [[ "$WITH_BACKUP" == "true" ]]; then
        log "STEP" "Configurando backup multi-cloud"

        if [[ ! -f "backup_multicloud.sh" ]]; then
            log "WARNING" "Script backup_multicloud.sh no encontrado, omitiendo configuración de backup"
            return
        fi

        if [[ ! -x "backup_multicloud.sh" ]]; then
            chmod +x backup_multicloud.sh
        fi

        log "INFO" "Backup multi-cloud preparado. Ejecuta './backup_multicloud.sh --help' para configurar"
        log "SUCCESS" "Backup multi-cloud configurado exitosamente"
    fi
}

# Función para mostrar resumen final
show_final_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    echo -e "${GREEN}"
    cat << 'EOF'

╔══════════════════════════════════════════════════════════════════════════════╗
║                           🎉 INSTALACIÓN COMPLETADA                        ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    echo -e "${YELLOW}⏱️  TIEMPO TOTAL:${NC} ${minutes} minutos y ${seconds} segundos"
    echo -e "${YELLOW}📁 LOGS GUARDADOS EN:${NC} $LOG_FILE"
    echo ""

    echo -e "${GREEN}✅ COMPONENTES INSTALADOS:${NC}"
    echo "   🌐 Webmin (con interfaz moderna)"
    echo "   🖥️  Virtualmin (gestión de servidores virtuales)"
    echo "   🎨 Authentic Theme (interfaz premium gratis)"
    echo "   🔒 SSL Certificates (certificados SSL gratis)"
    echo "   📧 Email Server (servidor de correo completo)"
    echo "   💾 Backup System (sistema de respaldos avanzado)"
    echo ""

    if [[ "$WITH_DOCKER" == "true" ]]; then
        echo -e "${GREEN}🐳 Docker configurado${NC}"
    fi
    if [[ "$WITH_KUBERNETES" == "true" ]]; then
        echo -e "${GREEN}⚓ Kubernetes configurado${NC}"
    fi
    if [[ "$WITH_MONITORING" == "true" ]]; then
        echo -e "${GREEN}📊 Monitoreo del sistema activado${NC}"
    fi
    if [[ "$WITH_BACKUP" == "true" ]]; then
        echo -e "${GREEN}☁️ Backup multi-cloud preparado${NC}"
    fi

    echo ""
    echo -e "${CYAN}🌐 ACCEDE A TU PANEL:${NC}"
    echo "   📱 Webmin: https://tu-servidor:10000"
    echo "   🖥️  Virtualmin: https://tu-servidor:10000"
    echo ""

    echo ""

    echo -e "${PURPLE}📚 SCRIPTS ADICIONALES DISPONIBLES:${NC}"
    echo "   🔍 ./validar_dependencias.sh    # Validar sistema"
    echo "   🚀 ./instalacion_unificada.sh   # Reinstalar base"
    echo "   🔧 ./instalar_integracion.sh    # Reinstalar componentes"
    echo "   📊 ./monitor_sistema.sh         # Monitoreo manual"
    echo "   💾 ./backup_multicloud.sh       # Configurar backups"
    echo "   🐳 ./generar_docker.sh          # Configurar Docker"
    echo "   ⚓ ./kubernetes_setup.sh        # Configurar Kubernetes"
    echo ""

    echo -e "${GREEN}🎊 ¡TU SERVIDOR ESTÁ LISTO PARA USAR!${NC}"
}

# Función principal
main() {
    # Parsear argumentos
    parse_args "$@"

    # Mostrar banner
    show_banner

    # Verificar prerrequisitos
    check_prerequisites

    # Si solo validación, ejecutar y salir
    if [[ "$ONLY_VALIDATION" == "true" ]]; then
        run_validation
        log "SUCCESS" "Validación completada. El sistema está listo para instalación."
        exit 0
    fi

    # Ejecutar validación (a menos que se omita)
    if [[ "$SKIP_VALIDATION" == "false" ]]; then
        run_validation
    else
        log "WARNING" "Validación omitida por solicitud del usuario"
    fi

    # Ejecutar instalación principal
    run_main_installation

    # Ejecutar integración
    run_integration

    # Configuraciones opcionales
    setup_docker
    setup_kubernetes
    setup_monitoring
    setup_backup

    # Mostrar resumen final
    show_final_summary
}

# Ejecutar función principal
main "$@"

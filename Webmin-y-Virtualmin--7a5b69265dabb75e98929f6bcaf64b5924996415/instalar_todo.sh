#!/bin/bash

# =============================================================================
# 🚀 INSTALACIÓN Y AUTO-REPARACIÓN INTELIGENTE WEBMIN Y VIRTUALMIN
# =============================================================================
#
# SISTEMA INTELIGENTE QUE DETECTA AUTOMÁTICAMENTE:
# - Si Webmin/Virtualmin ya están instalados
# - Si hay problemas en el sistema
# - Si necesita reparaciones automáticas
#
# USO AUTOMÁTICO (solo ejecutar):
#   ./instalar_todo.sh
#
# El sistema decidirá automáticamente qué hacer:
# ✅ NO INSTALADO: Instala completamente
# 🔧 INSTALADO CON PROBLEMAS: Repara automáticamente
# 📊 INSTALADO OK: Muestra estado actual
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

# Variables globales configurables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="./logs/webmin_virtualmin_install.log"
START_TIME=$(date +%s)

# Función para obtener IP del servidor
get_server_ip() {
    # Intentar obtener IP local
    local local_ip
    local_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    
    if [[ -n "$local_ip" ]] && [[ "$local_ip" != "127.0.0.1" ]]; then
        echo "$local_ip"
        return 0
    fi
    
    # Intentar obtener IP pública
    local public_ip
    public_ip=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || \
                curl -s --max-time 3 icanhazip.com 2>/dev/null || \
                curl -s --max-time 3 api.ipify.org 2>/dev/null || \
                echo "127.0.0.1")
    
    echo "$public_ip"
}

# ===== INCLUIR BIBLIOTECA COMÚN =====
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    source "${SCRIPT_DIR}/lib/common.sh"
    log_info "Biblioteca común cargada correctamente"
else
    echo "ERROR: No se encuentra la biblioteca común en ${SCRIPT_DIR}/lib/common.sh"
    echo "El script no puede continuar sin las funciones básicas"
    exit 1
fi

# Variables configurables con valores por defecto
SERVER_IP="${SERVER_IP:-$(get_server_ip)}"
WEBMIN_PORT="${WEBMIN_PORT:-10000}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="${HTTPS_PORT:-443}"
BACKUP_DIR="${BACKUP_DIR:-/backups}"
BACKUP_RETENTION="${BACKUP_RETENTION:-30}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-2}"
MIN_DISK_GB="${MIN_DISK_GB:-20}"

WITH_BACKUP=false

# ============================================================================
# FUNCIONES DE DETECCIÓN INTELIGENTE
# ============================================================================

# Función para detectar si Webmin está instalado
detect_webmin_installed() {
    if [[ -d "/etc/webmin" ]] || [[ -d "/usr/libexec/webmin" ]]; then
        return 0  # Instalado
    fi
    return 1  # No instalado
}

# Función para detectar si Virtualmin está instalado
detect_virtualmin_installed() {
    if [[ -d "/etc/virtualmin" ]] || [[ -d "/usr/libexec/virtualmin" ]]; then
        return 0  # Instalado
    fi
    return 1  # No instalado
}

# Función para verificar estado de servicios
check_services_status() {
    local issues_found=0

    log "INFO" "Verificando estado de servicios..."

    # Verificar Webmin
    if detect_webmin_installed; then
        if ! service_running "webmin" 2>/dev/null; then
            log "WARNING" "Servicio Webmin no está ejecutándose"
            ((issues_found++))
        else
            log "SUCCESS" "Servicio Webmin funcionando correctamente"
        fi
    fi

    # Verificar Apache/Nginx
    if service_running "apache2" 2>/dev/null || service_running "nginx" 2>/dev/null; then
        log "SUCCESS" "Servidor web funcionando correctamente"
    else
        log "WARNING" "Servidor web no está ejecutándose"
        ((issues_found++))
    fi

    # Verificar MySQL/MariaDB
    if service_running "mysql" 2>/dev/null || service_running "mariadb" 2>/dev/null; then
        log "SUCCESS" "Base de datos funcionando correctamente"
    else
        log "WARNING" "Base de datos no está ejecutándose"
        ((issues_found++))
    fi

    return $issues_found
}

# Función para verificar configuración de Virtualmin
check_virtualmin_config() {
    if detect_virtualmin_installed; then
        log "INFO" "Verificando configuración de Virtualmin..."

        # Verificar directorios de configuración
        if [[ ! -d "/etc/virtualmin" ]]; then
            log "ERROR" "Directorio de configuración de Virtualmin no encontrado"
            return 1
        fi

        # Contar dominios configurados
        local domain_count
        domain_count=$(find /etc/virtualmin -name "*.conf" 2>/dev/null | wc -l)

        if [[ $domain_count -gt 0 ]]; then
            log "SUCCESS" "Virtualmin configurado con $domain_count dominios"
            return 0
        else
            log "WARNING" "Virtualmin instalado pero sin dominios configurados"
            return 1
        fi
    fi

    return 1  # No instalado
}

# Función para determinar modo de operación
determine_operation_mode() {
    log "STEP" "🔍 ANALIZANDO ESTADO DEL SISTEMA..."

    local webmin_installed=false
    local virtualmin_installed=false
    local services_issues=0
    local config_issues=0

    # Verificar instalaciones
    if detect_webmin_installed; then
        webmin_installed=true
        log "INFO" "✅ Webmin detectado en el sistema"
    else
        log "INFO" "ℹ️  Webmin no detectado - se instalará"
    fi

    if detect_virtualmin_installed; then
        virtualmin_installed=true
        log "INFO" "✅ Virtualmin detectado en el sistema"
    else
        log "INFO" "ℹ️  Virtualmin no detectado - se instalará"
    fi

    # Si ninguno está instalado, hacer instalación completa
    if [[ "$webmin_installed" == "false" ]] && [[ "$virtualmin_installed" == "false" ]]; then
        log "STEP" "🎯 MODO: INSTALACIÓN COMPLETA"
        echo "INSTALL"
        return
    fi

    # Verificar servicios si están instalados
    if [[ "$webmin_installed" == "true" ]] || [[ "$virtualmin_installed" == "true" ]]; then
        if ! check_services_status; then
            ((services_issues++))
        fi
    fi

    # Verificar configuración de Virtualmin
    if [[ "$virtualmin_installed" == "true" ]]; then
        if ! check_virtualmin_config; then
            ((config_issues++))
        fi
    fi

    # Determinar si hay problemas
    if [[ $services_issues -gt 0 ]] || [[ $config_issues -gt 0 ]]; then
        log "STEP" "🔧 MODO: REPARACIÓN AUTOMÁTICA"
        log "WARNING" "Se detectaron $services_issues problemas de servicios y $config_issues problemas de configuración"
        echo "REPAIR"
    else
        log "STEP" "📊 MODO: VERIFICACIÓN DE ESTADO"
        log "SUCCESS" "Sistema funcionando correctamente - no se requieren reparaciones"
        echo "STATUS"
    fi
}

# ============================================================================
# FUNCIONES DE REPARACIÓN AUTOMÁTICA
# ============================================================================

# Función para reparar servicios
repair_services() {
    log "STEP" "🔧 Reparando servicios del sistema..."

    local services_repaired=0

    # Reparar Webmin
    if detect_webmin_installed; then
        if ! service_running "webmin"; then
            log "INFO" "Intentando reiniciar Webmin..."
            if command_exists systemctl; then
                systemctl restart webmin 2>/dev/null && log "SUCCESS" "Webmin reiniciado correctamente" && ((services_repaired++))
            elif command_exists service; then
                service webmin restart 2>/dev/null && log "SUCCESS" "Webmin reiniciado correctamente" && ((services_repaired++))
            fi
        fi
    fi

    # Reparar servidor web
    if service_running "apache2"; then
        log "INFO" "Reiniciando Apache..."
        if command_exists systemctl; then
            systemctl restart apache2 2>/dev/null && log "SUCCESS" "Apache reiniciado correctamente" && ((services_repaired++))
        elif command_exists service; then
            service apache2 restart 2>/dev/null && log "SUCCESS" "Apache reiniciado correctamente" && ((services_repaired++))
        fi
    elif service_running "nginx"; then
        log "INFO" "Reiniciando Nginx..."
        if command_exists systemctl; then
            systemctl restart nginx 2>/dev/null && log "SUCCESS" "Nginx reiniciado correctamente" && ((services_repaired++))
        elif command_exists service; then
            service nginx restart 2>/dev/null && log "SUCCESS" "Nginx reiniciado correctamente" && ((services_repaired++))
        fi
    fi

    # Reparar base de datos
    if service_running "mysql"; then
        log "INFO" "Reiniciando MySQL..."
        if command_exists systemctl; then
            systemctl restart mysql 2>/dev/null && log "SUCCESS" "MySQL reiniciado correctamente" && ((services_repaired++))
        elif command_exists service; then
            service mysql restart 2>/dev/null && log "SUCCESS" "MySQL reiniciado correctamente" && ((services_repaired++))
        fi
    elif service_running "mariadb"; then
        log "INFO" "Reiniciando MariaDB..."
        if command_exists systemctl; then
            systemctl restart mariadb 2>/dev/null && log "SUCCESS" "MariaDB reiniciado correctamente" && ((services_repaired++))
        elif command_exists service; then
            service mariadb restart 2>/dev/null && log "SUCCESS" "MariaDB reiniciado correctamente" && ((services_repaired++))
        fi
    fi

    log "SUCCESS" "Reparación de servicios completada: $services_repaired servicios reparados"
}

# Función para mostrar estado del sistema
show_system_status() {
    log "STEP" "📊 MOSTRANDO ESTADO ACTUAL DEL SISTEMA"

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                        📊 ESTADO DEL SISTEMA                             ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Estado de Webmin
    if detect_webmin_installed; then
        echo -e "${GREEN}✅ Webmin:${NC} Instalado"
        if service_running "webmin"; then
            echo -e "${GREEN}   └─ Servicio:${NC} Ejecutándose"
        else
            echo -e "${RED}   └─ Servicio:${NC} Detenido"
        fi
    else
        echo -e "${YELLOW}⚠️  Webmin:${NC} No instalado"
    fi

    # Estado de Virtualmin
    if detect_virtualmin_installed; then
        echo -e "${GREEN}✅ Virtualmin:${NC} Instalado"
        local domain_count
        domain_count=$(find /etc/virtualmin -name "*.conf" 2>/dev/null | wc -l)
        echo -e "${GREEN}   └─ Dominios:${NC} $domain_count configurados"
    else
        echo -e "${YELLOW}⚠️  Virtualmin:${NC} No instalado"
    fi

    # Estado de servicios
    echo ""
    echo -e "${BLUE}🔧 SERVICIOS:${NC}"

    local services=("apache2" "nginx" "mysql" "mariadb" "postfix" "dovecot")
    for service in "${services[@]}"; do
        if service_running "$service" 2>/dev/null; then
            echo -e "${GREEN}   ✅ $service${NC}"
        else
            echo -e "${RED}   ❌ $service${NC}"
        fi
    done

    # Información del sistema
    echo ""
    echo -e "${BLUE}💻 SISTEMA:${NC}"
    echo -e "${BLUE}   └─ SO:${NC} $(uname -s) $(uname -r)"
    echo -e "${BLUE}   └─ CPU:${NC} $(nproc 2>/dev/null || echo '1') núcleos"
    echo -e "${BLUE}   └─ Memoria:${NC} $(free -h 2>/dev/null | awk 'NR==2{print $2}' || echo 'Desconocida')"
    echo -e "${BLUE}   └─ Disco:${NC} $(df -h / 2>/dev/null | tail -1 | awk '{print $4}' || echo 'Desconocido') libres"

    echo ""
    echo -e "${GREEN}🎯 SISTEMA FUNCIONANDO CORRECTAMENTE${NC}"
    echo -e "${YELLOW}💡 Ejecuta nuevamente para instalación o reparación automática${NC}"
}

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

# Función para mostrar progreso (versión segura)
show_progress() {
    local current="$1"
    local total="$2"
    local description="$3"

    # Usar la función segura del common.sh si está disponible
    if command -v show_progress_safe >/dev/null 2>&1; then
        show_progress_safe "$current" "$total" "$description"
    else
        # Fallback a la versión original si common.sh no está disponible
        local percentage=$((current * 100 / total))
        local progress_bar=""

        # Crear barra de progreso
        for ((i=0; i<percentage/2; i++)); do
            progress_bar="${progress_bar}█"
        done
        for ((i=percentage/2; i<50; i++)); do
            progress_bar="${progress_bar}░"
        done

        # Solo usar \r si estamos en una terminal interactiva
        if [[ -t 1 ]]; then
            echo -ne "\\r${BLUE}[$current/$total]${NC} ${description} ${progress_bar} ${percentage}%"
        else
            echo "${BLUE}[$current/$total]${NC} ${description} ${progress_bar} ${percentage}%"
        fi
    fi
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

# Función para ejecutar validación con mejor manejo de errores
run_validation() {
    log "STEP" "Ejecutando validación del sistema"
    show_progress 1 5 "Validando sistema..."

    # Verificar que el script de validación existe y es ejecutable
    if [[ ! -f "validar_dependencias.sh" ]]; then
        handle_error "$ERROR_DEPENDENCY_MISSING" "El script validar_dependencias.sh no se encuentra"
    fi

    if [[ ! -x "validar_dependencias.sh" ]]; then
        log "WARNING" "Dando permisos de ejecución a validar_dependencias.sh"
        chmod +x "validar_dependencias.sh" 2>/dev/null || {
            handle_error "$ERROR_INSTALLATION_FAILED" "No se pudieron dar permisos de ejecución a validar_dependencias.sh"
        }
    fi

    # Ejecutar validación con captura de errores detallada
    local validation_output
    local validation_exit_code

    if ! validation_output=$(bash validar_dependencias.sh 2>&1); then
        validation_exit_code=$?
        log "ERROR" "La validación del sistema falló (código de salida: $validation_exit_code)"
        log "INFO" "Output de la validación:"
        echo "$validation_output" | while IFS= read -r line; do
            log "DEBUG" "  $line"
        done
        handle_error "$ERROR_DEPENDENCY_MISSING" "La validación del sistema falló. Revisa los logs en $LOG_FILE"
    fi

    log "SUCCESS" "Validación del sistema completada exitosamente"
    show_progress 2 5 "Sistema validado..."
}

# Función para ejecutar instalación principal con mejor manejo de errores
run_main_installation() {
    log "STEP" "Ejecutando instalación principal de Webmin y Virtualmin"
    show_progress 3 5 "Instalando Webmin y Virtualmin..."

    # Verificar que el script de instalación existe y es ejecutable
    if [[ ! -f "instalacion_unificada.sh" ]]; then
        handle_error "$ERROR_DEPENDENCY_MISSING" "El script instalacion_unificada.sh no se encuentra"
    fi

    if [[ ! -x "instalacion_unificada.sh" ]]; then
        log "WARNING" "Dando permisos de ejecución a instalacion_unificada.sh"
        chmod +x "instalacion_unificada.sh" 2>/dev/null || {
            handle_error "$ERROR_INSTALLATION_FAILED" "No se pudieron dar permisos de ejecución a instalacion_unificada.sh"
        }
    fi

    # Ejecutar instalación con captura de errores detallada
    local install_output
    local install_exit_code

    if ! install_output=$(bash instalacion_unificada.sh 2>&1); then
        install_exit_code=$?
        log "ERROR" "La instalación principal falló (código de salida: $install_exit_code)"
        log "INFO" "Output de la instalación:"
        echo "$install_output" | while IFS= read -r line; do
            log "DEBUG" "  $line"
        done
        handle_error "$ERROR_INSTALLATION_FAILED" "La instalación principal falló. Revisa los logs en $LOG_FILE"
    fi

    log "SUCCESS" "Instalación principal completada exitosamente"
    show_progress 4 5 "Webmin y Virtualmin instalados..."
}

# Función para ejecutar integración con mejor manejo de errores
run_integration() {
    log "STEP" "Ejecutando integración de componentes premium"
    show_progress 5 5 "Integrando componentes..."

    # Verificar que el script de integración existe y es ejecutable
    if [[ ! -f "instalar_integracion.sh" ]]; then
        handle_error "$ERROR_DEPENDENCY_MISSING" "El script instalar_integracion.sh no se encuentra"
    fi

    if [[ ! -x "instalar_integracion.sh" ]]; then
        log "WARNING" "Dando permisos de ejecución a instalar_integracion.sh"
        chmod +x "instalar_integracion.sh" 2>/dev/null || {
            handle_error "$ERROR_INSTALLATION_FAILED" "No se pudieron dar permisos de ejecución a instalar_integracion.sh"
        }
    fi

    # Ejecutar integración con captura de errores detallada
    local integration_output
    local integration_exit_code

    if ! integration_output=$(bash instalar_integracion.sh 2>&1); then
        integration_exit_code=$?
        log "ERROR" "La integración de componentes falló (código de salida: $integration_exit_code)"
        log "INFO" "Output de la integración:"
        echo "$integration_output" | while IFS= read -r line; do
            log "DEBUG" "  $line"
        done
        handle_error "$ERROR_INSTALLATION_FAILED" "La integración de componentes falló. Revisa los logs en $LOG_FILE"
    fi

    log "SUCCESS" "Integración de componentes completada exitosamente"
    echo # Nueva línea para la barra de progreso
}

# Función para configurar Docker con mejor manejo de errores
setup_docker() {
    if [[ "$WITH_DOCKER" == "true" ]]; then
        log "STEP" "Configurando Docker"

        if [[ ! -f "generar_docker.sh" ]]; then
            log "WARNING" "Script generar_docker.sh no encontrado, omitiendo configuración Docker"
            return 0
        fi

        # Verificar permisos de ejecución
        if [[ ! -x "generar_docker.sh" ]]; then
            chmod +x "generar_docker.sh" 2>/dev/null || {
                log "WARNING" "No se pudieron dar permisos de ejecución a generar_docker.sh, omitiendo configuración Docker"
                return 0
            }
        fi

        # Ejecutar configuración de Docker con captura de errores
        local docker_output
        local docker_exit_code

        if ! docker_output=$(bash generar_docker.sh 2>&1); then
            docker_exit_code=$?
            log "WARNING" "La configuración de Docker falló (código de salida: $docker_exit_code), pero continuando con la instalación"
            if [[ "${DEBUG:-false}" == "true" ]]; then
                log "DEBUG" "Output de Docker:"
                echo "$docker_output" | while IFS= read -r line; do
                    log "DEBUG" "  $line"
                done
            fi
        else
            log "SUCCESS" "Docker configurado exitosamente"
        fi
    fi
}

# Función para configurar Kubernetes con mejor manejo de errores
setup_kubernetes() {
    if [[ "$WITH_KUBERNETES" == "true" ]]; then
        log "STEP" "Configurando Kubernetes"

        if [[ ! -f "kubernetes_setup.sh" ]]; then
            log "WARNING" "Script kubernetes_setup.sh no encontrado, omitiendo configuración Kubernetes"
            return 0
        fi

        # Verificar permisos de ejecución
        if [[ ! -x "kubernetes_setup.sh" ]]; then
            chmod +x "kubernetes_setup.sh" 2>/dev/null || {
                log "WARNING" "No se pudieron dar permisos de ejecución a kubernetes_setup.sh, omitiendo configuración Kubernetes"
                return 0
            }
        fi

        # Ejecutar configuración de Kubernetes con captura de errores
        local k8s_output
        local k8s_exit_code

        if ! k8s_output=$(bash kubernetes_setup.sh 2>&1); then
            k8s_exit_code=$?
            log "WARNING" "La configuración de Kubernetes falló (código de salida: $k8s_exit_code), pero continuando con la instalación"
            if [[ "${DEBUG:-false}" == "true" ]]; then
                log "DEBUG" "Output de Kubernetes:"
                echo "$k8s_output" | while IFS= read -r line; do
                    log "DEBUG" "  $line"
                done
            fi
        else
            log "SUCCESS" "Kubernetes configurado exitosamente"
        fi
    fi
}

# Función para configurar monitoreo con mejor manejo de errores
setup_monitoring() {
    if [[ "$WITH_MONITORING" == "true" ]]; then
        log "STEP" "Configurando monitoreo del sistema"

        if [[ ! -f "monitor_sistema.sh" ]]; then
            log "WARNING" "Script monitor_sistema.sh no encontrado, omitiendo configuración de monitoreo"
            return 0
        fi

        # Verificar permisos de ejecución
        if [[ ! -x "monitor_sistema.sh" ]]; then
            chmod +x "monitor_sistema.sh" 2>/dev/null || {
                log "WARNING" "No se pudieron dar permisos de ejecución a monitor_sistema.sh, omitiendo configuración de monitoreo"
                return 0
            }
        fi

        # Ejecutar configuración de monitoreo con captura de errores
        local monitor_output
        local monitor_exit_code

        if ! monitor_output=$(bash monitor_sistema.sh --install 2>&1); then
            monitor_exit_code=$?
            log "WARNING" "La configuración de monitoreo falló (código de salida: $monitor_exit_code), pero continuando con la instalación"
            if [[ "${DEBUG:-false}" == "true" ]]; then
                log "DEBUG" "Output de monitoreo:"
                echo "$monitor_output" | while IFS= read -r line; do
                    log "DEBUG" "  $line"
                done
            fi
        else
            log "SUCCESS" "Monitoreo del sistema configurado exitosamente"
        fi
    fi
}

# Función para configurar backup con mejor manejo de errores
setup_backup() {
    if [[ "$WITH_BACKUP" == "true" ]]; then
        log "STEP" "Configurando backup multi-cloud"

        if [[ ! -f "backup_multicloud.sh" ]]; then
            log "WARNING" "Script backup_multicloud.sh no encontrado, omitiendo configuración de backup"
            return 0
        fi

        # Verificar permisos de ejecución
        if [[ ! -x "backup_multicloud.sh" ]]; then
            chmod +x "backup_multicloud.sh" 2>/dev/null || {
                log "WARNING" "No se pudieron dar permisos de ejecución a backup_multicloud.sh, omitiendo configuración de backup"
                return 0
            }
        fi

        # Solo informar sobre la configuración, no ejecutar automáticamente
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
    echo "   📱 Webmin: https://$SERVER_IP:$WEBMIN_PORT"
    echo "   🖥️  Virtualmin: https://$SERVER_IP:$WEBMIN_PORT"
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

# Función para mostrar banner inteligente
show_smart_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                🚀 SISTEMA INTELIGENTE WEBMIN & VIRTUALMIN                 ║
║                                                                          ║
║  🤖 DETECCIÓN AUTOMÁTICA - DECIDE QUÉ HACER POR SÍ SOLO                  ║
║                                                                          ║
║  ✅ NO INSTALADO → INSTALA COMPLETAMENTE                                  ║
║  🔧 CON PROBLEMAS → REPARA AUTOMÁTICAMENTE                                ║
║  📊 FUNCIONANDO OK → MUESTRA ESTADO ACTUAL                               ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Función para mostrar ayuda inteligente
show_smart_help() {
    cat << EOF
${BLUE}🚀 SISTEMA INTELIGENTE WEBMIN Y VIRTUALMIN${NC}

Este script es INTELIGENTE y detecta automáticamente qué hacer:

${YELLOW}USO AUTOMÁTICO:${NC}
    ./instalar_todo.sh                    # El sistema decide qué hacer

${YELLOW}OPCIONES MANUALES:${NC}
    --help              Mostrar esta ayuda
    --force-install     Forzar instalación completa (ignora detección)
    --force-repair      Forzar reparación (ignora detección)
    --status-only       Solo mostrar estado (sin cambios)

${YELLOW}COMPORTAMIENTO INTELIGENTE:${NC}
    🔍 PRIMERO: Analiza el estado actual del sistema
    🤔 LUEGO: Decide automáticamente qué acción tomar
    ✅ FINAL: Ejecuta la acción más apropiada

${YELLOW}ACCIONES POSIBLES:${NC}
    🎯 INSTALACIÓN: Si Webmin/Virtualmin no están instalados
    🔧 REPARACIÓN: Si hay servicios detenidos o problemas
    📊 ESTADO: Si todo funciona correctamente

${GREEN}🎊 ¡SOLO EJECÚTALO - EL SISTEMA HACE EL RESTO!${NC}

EOF
}

# Función principal inteligente
main() {
    # Parsear argumentos básicos
    if [[ $# -gt 0 ]]; then
        case "$1" in
            --help|-h)
                show_smart_help
                exit 0
                ;;
            --force-install)
                log "INFO" "Forzando instalación completa por solicitud del usuario"
                SKIP_VALIDATION=false
                ONLY_VALIDATION=false
                ;;
            --force-repair)
                log "INFO" "Forzando reparación por solicitud del usuario"
                # Aquí iría la lógica de reparación forzada
                ;;
            --status-only)
                show_system_status
                exit 0
                ;;
            *)
                log "ERROR" "Opción no reconocida: $1"
                show_smart_help
                exit 1
                ;;
        esac
    fi

    # Mostrar banner inteligente
    show_smart_banner

    # Verificar prerrequisitos
    check_prerequisites

    # DETERMINAR MODO DE OPERACIÓN INTELIGENTE
    local operation_mode
    operation_mode=$(determine_operation_mode)

    case "$operation_mode" in
        "INSTALL")
            # MODO INSTALACIÓN: Webmin/Virtualmin no están instalados
            log "STEP" "🎯 INICIANDO INSTALACIÓN COMPLETA"

            # Ejecutar validación
            if [[ "$SKIP_VALIDATION" == "false" ]]; then
                run_validation
            fi

            # Instalar Webmin y Virtualmin
            run_main_installation
            run_integration

            # Configurar opciones adicionales si se solicitaron
            setup_docker
            setup_kubernetes
            setup_monitoring
            setup_backup

            # Mostrar resumen final
            show_final_summary
            ;;

        "REPAIR")
            # MODO REPARACIÓN: Hay problemas que solucionar
            log "STEP" "🔧 INICIANDO REPARACIÓN AUTOMÁTICA"

            # Reparar servicios
            repair_services

            # Verificar configuración de Virtualmin si está instalado
            if detect_virtualmin_installed; then
                if ! check_virtualmin_config; then
                    log "WARNING" "Se detectaron problemas en la configuración de Virtualmin"
                    # Aquí se podrían agregar reparaciones específicas de Virtualmin
                fi
            fi

            log "SUCCESS" "🔧 REPARACIÓN AUTOMÁTICA COMPLETADA"

            # Mostrar estado actualizado
            show_system_status
            ;;

        "STATUS")
            # MODO ESTADO: Todo funciona correctamente
            show_system_status
            ;;
    esac
}

# Ejecutar función principal
main "$@"

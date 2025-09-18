#!/bin/bash

# Script de Validación de Dependencias
# Verifica todos los requisitos antes de la instalación

set -euo pipefail
IFS=$'\n\t'

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Códigos de error
declare -r ERROR_ROOT_REQUIRED=100
declare -r ERROR_INTERNET_CONNECTION=101
declare -r ERROR_OS_NOT_SUPPORTED=102
declare -r ERROR_ARCHITECTURE_NOT_SUPPORTED=103
declare -r ERROR_MEMORY_INSUFFICIENT=104
declare -r ERROR_DISK_INSUFFICIENT=105
declare -r ERROR_DEPENDENCY_MISSING=106
declare -r ERROR_PACKAGE_MANAGER_NOT_FOUND=107
declare -r ERROR_PERL_NOT_FOUND=108
declare -r ERROR_PYTHON_NOT_FOUND=109

# Función de logging con timestamp
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        "INFO")     echo -e "${BLUE}[$timestamp INFO]${NC} $message" ;;
        "SUCCESS")  echo -e "${GREEN}[$timestamp SUCCESS]${NC} $message" ;;
        "WARNING")  echo -e "${YELLOW}[$timestamp WARNING]${NC} $message" ;;
        "ERROR")    echo -e "${RED}[$timestamp ERROR]${NC} $message" ;;
        "STEP")     echo -e "${PURPLE}[$timestamp STEP]${NC} $message" ;;
        "DEBUG")    echo -e "${CYAN}[$timestamp DEBUG]${NC} $message" ;;
    esac
}

# Función para mostrar progreso
show_progress() {
    local current="$1"
    local total="$2"
    local description="$3"
    local percentage=$((current * 100 / total))
    local progress_bar=""

    for ((i=0; i<percentage/2; i++)); do
        progress_bar="${progress_bar}█"
    done
    for ((i=percentage/2; i<50; i++)); do
        progress_bar="${progress_bar}░"
    done

    echo -ne "\r${BLUE}[$current/$total]${NC} ${description} ${progress_bar} ${percentage}%"
}

# Función para verificar privilegios de root
check_root_privileges() {
    log "STEP" "Verificando privilegios de administrador..."

    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Este script debe ejecutarse como root (usa sudo)"
        log "INFO" "Ejemplo: sudo $0"
        exit $ERROR_ROOT_REQUIRED
    fi

    log "SUCCESS" "Privilegios de root verificados"
}

# Función para verificar conectividad a internet
check_internet_connection() {
    log "STEP" "Verificando conectividad a internet..."

    local timeout=10
    local test_urls=("https://google.com" "https://github.com" "https://software.virtualmin.com")

    for url in "${test_urls[@]}"; do
        if curl -s --max-time "$timeout" "$url" > /dev/null 2>&1; then
            log "SUCCESS" "Conectividad a internet OK (probado con $url)"
            return 0
        fi
    done

    log "ERROR" "No hay conectividad a internet. Verifica tu conexión y vuelve a intentar."
    exit $ERROR_INTERNET_CONNECTION
}

# Función para detectar y validar sistema operativo
detect_and_validate_os() {
    log "STEP" "Detectando sistema operativo..."

    if [[ ! -f /etc/os-release ]]; then
        log "ERROR" "No se puede detectar el sistema operativo. Archivo /etc/os-release no encontrado."
        exit $ERROR_OS_NOT_SUPPORTED
    fi

    # shellcheck source=/dev/null
    . /etc/os-release

    local os_name="${NAME:-Unknown}"
    local os_version="${VERSION_ID:-Unknown}"
    local os_id="${ID:-unknown}"

    log "INFO" "Sistema detectado: $os_name $os_version ($os_id)"

    # Lista de sistemas operativos soportados
    local supported_os=("ubuntu" "debian" "centos" "rocky" "almalinux" "ol" "rhel")

    if [[ ! " ${supported_os[*]} " =~ ${os_id} ]]; then
        log "ERROR" "Sistema operativo no soportado: $os_name"
        log "INFO" "Sistemas soportados: Ubuntu, Debian, CentOS, Rocky Linux, AlmaLinux, Oracle Linux, RHEL"
        exit $ERROR_OS_NOT_SUPPORTED
    fi

    # Validar versiones mínimas
    case "$os_id" in
        ubuntu)
            if [[ "${os_version%%.*}" -lt 20 ]]; then
                log "WARNING" "Ubuntu $os_version detectado. Recomendado: Ubuntu 20.04+"
            fi
            ;;
        debian)
            if [[ "${os_version%%.*}" -lt 11 ]]; then
                log "WARNING" "Debian $os_version detectado. Recomendado: Debian 11+"
            fi
            ;;
        centos|rhel|rocky|almalinux|ol)
            if [[ "${os_version%%.*}" -lt 8 ]]; then
                log "WARNING" "Versión $os_version de $os_name detectada. Recomendado: versión 8+"
            fi
            ;;
    esac

    log "SUCCESS" "Sistema operativo validado: $os_name $os_version"
}

# Función para verificar arquitectura
check_architecture() {
    log "STEP" "Verificando arquitectura del sistema..."

    local arch
    arch=$(uname -m)

    case "$arch" in
        x86_64|amd64)
            log "SUCCESS" "Arquitectura soportada: $arch"
            ;;
        *)
            log "ERROR" "Arquitectura no soportada: $arch"
            log "INFO" "Arquitecturas soportadas: x86_64, amd64"
            exit $ERROR_ARCHITECTURE_NOT_SUPPORTED
            ;;
    esac
}

# Función para verificar recursos del sistema
check_system_resources() {
    log "STEP" "Verificando recursos del sistema..."

    # Verificar memoria RAM
    if [[ -r /proc/meminfo ]]; then
        local mem_kb
        mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        local mem_gb=$((mem_kb / 1024 / 1024))

        if [[ $mem_gb -lt 2 ]]; then
            log "ERROR" "Memoria RAM insuficiente: ${mem_gb}GB"
            log "INFO" "Mínimo requerido: 2GB RAM"
            log "INFO" "Recomendado: 4GB+ RAM"
            exit $ERROR_MEMORY_INSUFFICIENT
        elif [[ $mem_gb -lt 4 ]]; then
            log "WARNING" "Memoria RAM limitada: ${mem_gb}GB (recomendado: 4GB+)"
        else
            log "SUCCESS" "Memoria RAM: ${mem_gb}GB"
        fi
    fi

    # Verificar espacio en disco
    local disk_kb
    disk_kb=$(df --output=avail / | tail -n 1)
    local disk_gb=$((disk_kb / 1024 / 1024))

    if [[ $disk_gb -lt 20 ]]; then
        log "ERROR" "Espacio en disco insuficiente: ${disk_gb}GB libres en /"
        log "INFO" "Mínimo requerido: 20GB libres"
        log "INFO" "Recomendado: 50GB+ libres"
        exit $ERROR_DISK_INSUFFICIENT
    elif [[ $disk_gb -lt 50 ]]; then
        log "WARNING" "Espacio en disco limitado: ${disk_gb}GB (recomendado: 50GB+)"
    else
        log "SUCCESS" "Espacio en disco: ${disk_gb}GB libres"
    fi

    # Verificar núcleos de CPU
    local cpu_cores
    cpu_cores=$(nproc 2>/dev/null || echo "1")
    if [[ $cpu_cores -lt 2 ]]; then
        log "WARNING" "Pocos núcleos de CPU: $cpu_cores (recomendado: 2+)"
    else
        log "SUCCESS" "Núcleos de CPU: $cpu_cores"
    fi
}

# Función para verificar gestor de paquetes
check_package_manager() {
    log "STEP" "Verificando gestor de paquetes..."

    local package_managers=("apt-get" "yum" "dnf" "zypper")
    local found_manager=""

    for manager in "${package_managers[@]}"; do
        if command -v "$manager" &> /dev/null; then
            found_manager="$manager"
            break
        fi
    done

    if [[ -z "$found_manager" ]]; then
        log "ERROR" "No se encontró un gestor de paquetes soportado"
        log "INFO" "Gestores soportados: apt-get, yum, dnf, zypper"
        exit $ERROR_PACKAGE_MANAGER_NOT_FOUND
    fi

    log "SUCCESS" "Gestor de paquetes encontrado: $found_manager"
}

# Función para verificar dependencias críticas
check_critical_dependencies() {
    log "STEP" "Verificando dependencias críticas..."

    local critical_deps=("curl" "wget" "tar" "gzip" "bash")
    local missing_deps=()

    for dep in "${critical_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "Dependencias críticas faltantes: ${missing_deps[*]}"
        log "INFO" "Instala las dependencias faltantes y vuelve a ejecutar el script"
        exit $ERROR_DEPENDENCY_MISSING
    fi

    log "SUCCESS" "Dependencias críticas verificadas"
}

# Función para verificar Perl
check_perl() {
    log "STEP" "Verificando instalación de Perl..."

    if ! command -v perl &> /dev/null; then
        log "ERROR" "Perl no está instalado"
        exit $ERROR_PERL_NOT_FOUND
    fi

    local perl_version
    perl_version=$(perl -v | grep -oP 'v\d+\.\d+\.\d+' | head -1)

    if [[ -z "$perl_version" ]]; then
        log "WARNING" "No se pudo determinar la versión de Perl"
    else
        log "INFO" "Versión de Perl: $perl_version"
    fi

    # Verificar módulos Perl críticos
    local perl_modules=("Digest::MD5" "MIME::Base64" "Time::Local")
    local missing_modules=()

    for module in "${perl_modules[@]}"; do
        if ! perl -M"$module" -e 'print "OK"' &> /dev/null; then
            missing_modules+=("$module")
        fi
    done

    if [[ ${#missing_modules[@]} -gt 0 ]]; then
        log "WARNING" "Módulos Perl faltantes: ${missing_modules[*]}"
        log "INFO" "Algunos módulos se instalarán automáticamente durante la instalación"
    else
        log "SUCCESS" "Módulos Perl críticos verificados"
    fi
}

# Función para verificar Python (opcional)
check_python() {
    log "STEP" "Verificando instalación de Python..."

    local python_cmd=""
    if command -v python3 &> /dev/null; then
        python_cmd="python3"
    elif command -v python &> /dev/null; then
        python_cmd="python"
    else
        log "WARNING" "Python no está instalado (opcional para algunas funcionalidades)"
        return 0
    fi

    local python_version
    python_version=$("$python_cmd" --version 2>&1 | grep -oP '\d+\.\d+\.\d+')

    if [[ -n "$python_version" ]]; then
        log "INFO" "Versión de Python: $python_version"
        log "SUCCESS" "Python disponible"
    else
        log "WARNING" "No se pudo determinar la versión de Python"
    fi
}

# Función para verificar conectividad a repositorios
check_repository_connectivity() {
    log "STEP" "Verificando conectividad a repositorios..."

    local repos=("https://software.virtualmin.com" "https://github.com" "https://deb.debian.org" "https://archive.ubuntu.com")

    for repo in "${repos[@]}"; do
        if curl -s --max-time 5 "$repo" > /dev/null 2>&1; then
            log "DEBUG" "Repositorio accesible: $repo"
        else
            log "WARNING" "Repositorio no accesible: $repo"
        fi
    done

    log "SUCCESS" "Verificación de repositorios completada"
}

# Función principal
main() {
    echo
    echo "========================================"
    echo "  VALIDACIÓN DE DEPENDENCIAS"
    echo "  Authentic Theme + Virtualmin"
    echo "========================================"
    echo

    local total_steps=10
    local current_step=0

    # Ejecutar validaciones paso a paso
    ((current_step++))
    show_progress "$current_step" "$total_steps" "Verificando privilegios..."
    check_root_privileges

    ((current_step++))
    show_progress "$current_step" "$total_steps" "Verificando internet..."
    check_internet_connection

    ((current_step++))
    show_progress "$current_step" "$total_steps" "Detectando SO..."
    detect_and_validate_os

    ((current_step++))
    show_progress "$current_step" "$total_steps" "Verificando arquitectura..."
    check_architecture

    ((current_step++))
    show_progress "$current_step" "$total_steps" "Verificando recursos..."
    check_system_resources

    ((current_step++))
    show_progress "$current_step" "$total_steps" "Verificando gestor de paquetes..."
    check_package_manager

    ((current_step++))
    show_progress "$current_step" "$total_steps" "Verificando dependencias críticas..."
    check_critical_dependencies

    ((current_step++))
    show_progress "$current_step" "$total_steps" "Verificando Perl..."
    check_perl

    ((current_step++))
    show_progress "$current_step" "$total_steps" "Verificando Python..."
    check_python

    ((current_step++))
    show_progress "$current_step" "$total_steps" "Verificando repositorios..."
    check_repository_connectivity

    echo # Nueva línea después del progreso
    log "SUCCESS" "¡Todas las validaciones pasaron exitosamente!"
    echo
    log "INFO" "El sistema está listo para la instalación de Virtualmin + Authentic Theme"
    echo
    log "INFO" "Ejecuta el script de instalación principal:"
    log "INFO" "  sudo ./instalacion_unificada.sh"
}

# Función de limpieza
cleanup() {
    # Limpiar archivos temporales si existen
    rm -f /tmp/validation_check_*.tmp 2>/dev/null || true
}

# Configurar cleanup al salir
trap cleanup EXIT

# Verificar si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

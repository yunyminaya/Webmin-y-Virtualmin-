#!/bin/bash

# Script de Validación de Dependencias
# Verifica todos los requisitos antes de la instalación

set -euo pipefail
IFS=$'\n\t'

# ===== INCLUIR BIBLIOTECA COMÚN =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    source "${SCRIPT_DIR}/lib/common.sh"
else
    echo "ERROR: No se encuentra la biblioteca común en ${SCRIPT_DIR}/lib/common.sh"
    exit 1
fi

# Variables configurables
MIN_MEMORY_GB="${MIN_MEMORY_GB:-2}"
MIN_DISK_GB="${MIN_DISK_GB:-20}"

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
    log_step "Verificando privilegios de administrador..."

    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root (usa sudo)"
        log_info "Ejemplo: sudo $0"
        exit $ERROR_ROOT_REQUIRED
    fi

    log_success "Privilegios de root verificados"
}

# Función para verificar conectividad a internet
check_internet_connection() {
    log_step "Verificando conectividad a internet..."

    local timeout=10
    local test_urls=("https://google.com" "https://github.com" "https://software.virtualmin.com")

    for url in "${test_urls[@]}"; do
        if curl -s --max-time "$timeout" "$url" > /dev/null 2>&1; then
            log_success "Conectividad a internet OK (probado con $url)"
            return 0
        fi
    done

    log_error "No hay conectividad a internet. Verifica tu conexión y vuelve a intentar."
    exit $ERROR_INTERNET_CONNECTION
}

# Función para detectar y validar sistema operativo
detect_and_validate_os() {
    log_step "Detectando sistema operativo..."

    if [[ ! -f /etc/os-release ]]; then
        log_error "No se puede detectar el sistema operativo. Archivo /etc/os-release no encontrado."
        exit $ERROR_OS_NOT_SUPPORTED
    fi

    # shellcheck source=/dev/null
    . /etc/os-release

    local os_name="${NAME:-Unknown}"
    local os_version="${VERSION_ID:-Unknown}"
    local os_id="${ID:-unknown}"

    log_info "Sistema detectado: $os_name $os_version ($os_id)"

    # Lista de sistemas operativos soportados
    local supported_os=("ubuntu" "debian" "centos" "rocky" "almalinux" "ol" "rhel")

    if [[ ! " ${supported_os[*]} " =~ ${os_id} ]]; then
        log_error "Sistema operativo no soportado: $os_name"
        log_info "Sistemas soportados: Ubuntu, Debian, CentOS, Rocky Linux, AlmaLinux, Oracle Linux, RHEL"
        exit $ERROR_OS_NOT_SUPPORTED
    fi

    # Validar versiones mínimas
    case "$os_id" in
        ubuntu)
            if [[ "${os_version%%.*}" -lt 20 ]]; then
                log_warning "Ubuntu $os_version detectado. Recomendado: Ubuntu 20.04+"
            fi
            ;;
        debian)
            if [[ "${os_version%%.*}" -lt 11 ]]; then
                log_warning "Debian $os_version detectado. Recomendado: Debian 11+"
            fi
            ;;
        centos|rhel|rocky|almalinux|ol)
            if [[ "${os_version%%.*}" -lt 8 ]]; then
                log_warning "Versión $os_version de $os_name detectada. Recomendado: versión 8+"
            fi
            ;;
    esac

    log_success "Sistema operativo validado: $os_name $os_version"
}

# Función para verificar arquitectura
check_architecture() {
    log_step "Verificando arquitectura del sistema..."

    local arch
    arch=$(uname -m)

    case "$arch" in
        x86_64|amd64)
            log_success "Arquitectura soportada: $arch"
            ;;
        *)
            log_error "Arquitectura no soportada: $arch"
            log_info "Arquitecturas soportadas: x86_64, amd64"
            exit $ERROR_ARCHITECTURE_NOT_SUPPORTED
            ;;
    esac
}

# Función para verificar recursos del sistema
check_system_resources() {
    log_step "Verificando recursos del sistema..."

    # Verificar memoria RAM
    if [[ -r /proc/meminfo ]]; then
        local mem_kb
        mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        local mem_gb=$((mem_kb / 1024 / 1024))

        if [[ $mem_gb -lt $MIN_MEMORY_GB ]]; then
            log_error "Memoria RAM insuficiente: ${mem_gb}GB"
            log_info "Mínimo requerido: ${MIN_MEMORY_GB}GB RAM"
            log_info "Recomendado: 4GB+ RAM"
            exit $ERROR_MEMORY_INSUFFICIENT
        elif [[ $mem_gb -lt 4 ]]; then
            log_warning "Memoria RAM limitada: ${mem_gb}GB (recomendado: 4GB+)"
        else
            log_success "Memoria RAM: ${mem_gb}GB"
        fi
    fi

    # Verificar espacio en disco
    local disk_kb
    disk_kb=$(df --output=avail / | tail -n 1)
    local disk_gb=$((disk_kb / 1024 / 1024))

    if [[ $disk_gb -lt $MIN_DISK_GB ]]; then
        log_error "Espacio en disco insuficiente: ${disk_gb}GB libres en /"
        log_info "Mínimo requerido: ${MIN_DISK_GB}GB libres"
        log_info "Recomendado: 50GB+ libres"
        exit $ERROR_DISK_INSUFFICIENT
    elif [[ $disk_gb -lt 50 ]]; then
        log_warning "Espacio en disco limitado: ${disk_gb}GB (recomendado: 50GB+)"
    else
        log_success "Espacio en disco: ${disk_gb}GB libres"
    fi

    # Verificar núcleos de CPU
    local cpu_cores
    cpu_cores=$(nproc 2>/dev/null || echo "1")
    if [[ $cpu_cores -lt 2 ]]; then
        log_warning "Pocos núcleos de CPU: $cpu_cores (recomendado: 2+)"
    else
        log_success "Núcleos de CPU: $cpu_cores"
    fi
}

# Función para verificar gestor de paquetes
check_package_manager() {
    log_step "Verificando gestor de paquetes..."

    local package_managers=("apt-get" "yum" "dnf" "zypper")
    local found_manager=""

    for manager in "${package_managers[@]}"; do
        if command -v "$manager" &> /dev/null; then
            found_manager="$manager"
            break
        fi
    done

    if [[ -z "$found_manager" ]]; then
        log_error "No se encontró un gestor de paquetes soportado"
        log_info "Gestores soportados: apt-get, yum, dnf, zypper"
        exit $ERROR_PACKAGE_MANAGER_NOT_FOUND
    fi

    log_success "Gestor de paquetes encontrado: $found_manager"
}

# Función para verificar dependencias críticas
check_critical_dependencies() {
    log_step "Verificando dependencias críticas..."

    local critical_deps=("curl" "wget" "tar" "gzip" "bash")
    local missing_deps=()

    for dep in "${critical_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Dependencias críticas faltantes: ${missing_deps[*]}"
        log_info "Instala las dependencias faltantes y vuelve a ejecutar el script"
        exit $ERROR_DEPENDENCY_MISSING
    fi

    log_success "Dependencias críticas verificadas"
}

# Función para verificar Perl
check_perl() {
    log_step "Verificando instalación de Perl..."

    if ! command -v perl &> /dev/null; then
        log_error "Perl no está instalado"
        exit $ERROR_PERL_NOT_FOUND
    fi

    local perl_version
    perl_version=$(perl -v | grep -oP 'v\d+\.\d+\.\d+' | head -1)

    if [[ -z "$perl_version" ]]; then
        log_warning "No se pudo determinar la versión de Perl"
    else
        log_info "Versión de Perl: $perl_version"
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
        log_warning "Módulos Perl faltantes: ${missing_modules[*]}"
        log_info "Algunos módulos se instalarán automáticamente durante la instalación"
    else
        log_success "Módulos Perl críticos verificados"
    fi
}

# Función para verificar Python (opcional)
check_python() {
    log_step "Verificando instalación de Python..."

    local python_cmd=""
    if command -v python3 &> /dev/null; then
        python_cmd="python3"
    elif command -v python &> /dev/null; then
        python_cmd="python"
    else
        log_warning "Python no está instalado (opcional para algunas funcionalidades)"
        return 0
    fi

    local python_version
    python_version=$("$python_cmd" --version 2>&1 | grep -oP '\d+\.\d+\.\d+')

    if [[ -n "$python_version" ]]; then
        log_info "Versión de Python: $python_version"
        log_success "Python disponible"
    else
        log_warning "No se pudo determinar la versión de Python"
    fi
}

# Función para verificar conectividad a repositorios
check_repository_connectivity() {
    log_step "Verificando conectividad a repositorios..."

    local repos=("https://software.virtualmin.com" "https://github.com" "https://deb.debian.org" "https://archive.ubuntu.com")

    for repo in "${repos[@]}"; do
        if curl -s --max-time 5 "$repo" > /dev/null 2>&1; then
            log_debug "Repositorio accesible: $repo"
        else
            log_warning "Repositorio no accesible: $repo"
        fi
    done

    log_success "Verificación de repositorios completada"
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
    log_success "¡Todas las validaciones pasaron exitosamente!"
    echo
    log_info "El sistema está listo para la instalación de Virtualmin + Authentic Theme"
    echo
    log_info "Ejecuta el script de instalación principal:"
    log_info "  sudo ./instalacion_unificada.sh"
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

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
        if curl -s --ssl-reqd --connect-timeout 10 --max-time "$timeout" --retry 3 --retry-delay 2 --user-agent "Dependency-Validator/1.0" "$url" > /dev/null 2>&1; then
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
        local mem_gb=$(bc -l <<< "scale=2; $mem_kb / (1024 * 1024)")  # Convertir KB a GB con precisión

        if (( $(echo "$mem_gb < $MIN_MEMORY_GB" | bc -l) )); then
            log_error "Memoria RAM insuficiente: ${mem_gb}GB"
            log_info "Mínimo requerido: ${MIN_MEMORY_GB}GB RAM"
            log_info "Recomendado: 4GB+ RAM"
            exit $ERROR_MEMORY_INSUFFICIENT
        elif (( $(echo "$mem_gb < 4" | bc -l) )); then
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

    local critical_deps=("curl" "wget" "tar" "gzip" "bash" "bc")
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

# Función para verificar versiones mínimas de dependencias clave
check_minimum_versions() {
    log_step "Verificando versiones mínimas de dependencias clave..."

    # Verificar PHP
    if command -v php &> /dev/null; then
        local php_version
        php_version=$(php --version | head -1 | grep -oP '\d+\.\d+\.\d+')
        if [[ -n "$php_version" ]]; then
            log_info "Versión de PHP detectada: $php_version"
            if [[ "$(printf '%s\n' "$php_version" "7.4.0" | sort -V | head -n1)" != "7.4.0" ]]; then
                log_error "Versión de PHP demasiado antigua: $php_version. Mínimo requerido: 7.4.0"
                exit 1
            fi
        else
            log_warning "No se pudo determinar la versión de PHP"
        fi
    else
        log_warning "PHP no está instalado"
    fi

    # Verificar MySQL/MariaDB
    local mysql_cmd=""
    if command -v mysql &> /dev/null; then
        mysql_cmd="mysql"
    elif command -v mariadb &> /dev/null; then
        mysql_cmd="mariadb"
    fi

    if [[ -n "$mysql_cmd" ]]; then
        local mysql_version
        mysql_version=$("$mysql_cmd" --version | grep -oP '\d+\.\d+\.\d+' | head -1)
        if [[ -n "$mysql_version" ]]; then
            log_info "Versión de MySQL/MariaDB detectada: $mysql_version"
            if [[ "$(printf '%s\n' "$mysql_version" "5.7.0" | sort -V | head -n1)" != "5.7.0" ]]; then
                log_error "Versión de MySQL/MariaDB demasiado antigua: $mysql_version. Mínimo requerido: 5.7.0"
                exit 1
            fi
        else
            log_warning "No se pudo determinar la versión de MySQL/MariaDB"
        fi
    else
        log_warning "MySQL/MariaDB no está instalado"
    fi

    # Verificar Apache
    local apache_cmd=""
    if command -v apache2 &> /dev/null; then
        apache_cmd="apache2"
    elif command -v httpd &> /dev/null; then
        apache_cmd="httpd"
    fi

    if [[ -n "$apache_cmd" ]]; then
        local apache_version
        apache_version=$("$apache_cmd" -v | grep -oP 'Apache/\d+\.\d+\.\d+' | cut -d'/' -f2)
        if [[ -n "$apache_version" ]]; then
            log_info "Versión de Apache detectada: $apache_version"
            if [[ "$(printf '%s\n' "$apache_version" "2.4.0" | sort -V | head -n1)" != "2.4.0" ]]; then
                log_error "Versión de Apache demasiado antigua: $apache_version. Mínimo requerido: 2.4.0"
                exit 1
            fi
        else
            log_warning "No se pudo determinar la versión de Apache"
        fi
    else
        log_warning "Apache no está instalado"
    fi

    log_success "Versiones mínimas verificadas"
}

# Función para verificar existencia de archivos críticos
check_critical_files() {
    log_step "Verificando existencia de archivos críticos..."

    local critical_files=(
        "/etc/passwd"
        "/etc/group"
        "/etc/shadow"
        "/etc/sudoers"
        "/etc/hosts"
        "/etc/resolv.conf"
    )

    local missing_files=()

    for file in "${critical_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done

    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "Archivos críticos faltantes: ${missing_files[*]}"
        exit 1
    fi

    # Verificar archivos de configuración específicos
    if command -v php &> /dev/null; then
        if [[ ! -f /etc/php.ini ]] && [[ ! -f /etc/php/*/php.ini ]]; then
            log_warning "Archivo de configuración de PHP no encontrado (/etc/php.ini)"
        fi
    fi

    if command -v mysql &> /dev/null || command -v mariadb &> /dev/null; then
        if [[ ! -f /etc/mysql/my.cnf ]] && [[ ! -f /etc/my.cnf ]]; then
            log_warning "Archivo de configuración de MySQL/MariaDB no encontrado"
        fi
    fi

    if command -v apache2 &> /dev/null || command -v httpd &> /dev/null; then
        if [[ ! -f /etc/apache2/apache2.conf ]] && [[ ! -f /etc/httpd/conf/httpd.conf ]]; then
            log_warning "Archivo de configuración de Apache no encontrado"
        fi
    fi

    log_success "Archivos críticos verificados"
}

# Función para verificar existencia de bibliotecas comunes
check_common_libraries() {
    log_step "Verificando existencia de bibliotecas comunes..."

    # Verificar extensiones PHP comunes
    if command -v php &> /dev/null; then
        local php_extensions=("mysqli" "pdo" "pdo_mysql" "mbstring" "curl" "gd" "json" "openssl")
        local missing_extensions=()

        for ext in "${php_extensions[@]}"; do
            if ! php -m | grep -q "^$ext$"; then
                missing_extensions+=("$ext")
            fi
        done

        if [[ ${#missing_extensions[@]} -gt 0 ]]; then
            log_warning "Extensiones PHP faltantes: ${missing_extensions[*]}"
            log_info "Estas extensiones se pueden instalar con el gestor de paquetes"
        else
            log_success "Extensiones PHP comunes verificadas"
        fi
    fi

    # Verificar bibliotecas del sistema comunes
    local system_libs=("libssl.so" "libcrypto.so" "libz.so" "libxml2.so")
    local missing_libs=()

    for lib in "${system_libs[@]}"; do
        if ! ldconfig -p | grep -q "$lib"; then
            missing_libs+=("$lib")
        fi
    done

    if [[ ${#missing_libs[@]} -gt 0 ]]; then
        log_warning "Bibliotecas del sistema faltantes: ${missing_libs[*]}"
    else
        log_success "Bibliotecas del sistema comunes verificadas"
    fi

    log_success "Verificación de bibliotecas completada"
}

# Función para detectar versiones vulnerables y CVEs conocidas
check_vulnerable_versions() {
    log_step "Detectando versiones vulnerables y CVEs conocidas..."

    # Verificar PHP vulnerabilidades conocidas
    if command -v php &> /dev/null; then
        local php_version
        php_version=$(php --version | head -1 | grep -oP '\d+\.\d+\.\d+')
        if [[ -n "$php_version" ]]; then
            # PHP < 7.4 tiene múltiples CVEs críticas
            if [[ "$(printf '%s\n' "$php_version" "7.4.0" | sort -V | head -n1)" != "7.4.0" ]]; then
                log_error "Versión de PHP vulnerable detectada: $php_version"
                log_info "CVEs conocidas: Múltiples vulnerabilidades en versiones < 7.4.0"
                log_info "Recomendado: Actualizar a PHP 8.0+ para mayor seguridad"
                exit 1
            elif [[ "$(printf '%s\n' "$php_version" "8.0.0" | sort -V | head -n1)" != "8.0.0" ]]; then
                log_warning "Versión de PHP potencialmente vulnerable: $php_version"
                log_info "Recomendado: Actualizar a PHP 8.0+ para parches de seguridad recientes"
            fi
        fi
    fi

    # Verificar MySQL/MariaDB vulnerabilidades
    local mysql_cmd=""
    if command -v mysql &> /dev/null; then
        mysql_cmd="mysql"
    elif command -v mariadb &> /dev/null; then
        mysql_cmd="mariadb"
    fi

    if [[ -n "$mysql_cmd" ]]; then
        local mysql_version
        mysql_version=$("$mysql_cmd" --version | grep -oP '\d+\.\d+\.\d+' | head -1)
        if [[ -n "$mysql_version" ]]; then
            # MySQL < 5.7 tiene vulnerabilidades conocidas
            if [[ "$(printf '%s\n' "$mysql_version" "5.7.0" | sort -V | head -n1)" != "5.7.0" ]]; then
                log_error "Versión de MySQL/MariaDB vulnerable: $mysql_version"
                log_info "CVEs conocidas: Múltiples vulnerabilidades en versiones < 5.7.0"
                exit 1
            fi
        fi
    fi

    # Verificar Apache vulnerabilidades
    local apache_cmd=""
    if command -v apache2 &> /dev/null; then
        apache_cmd="apache2"
    elif command -v httpd &> /dev/null; then
        apache_cmd="httpd"
    fi

    if [[ -n "$apache_cmd" ]]; then
        local apache_version
        apache_version=$("$apache_cmd" -v | grep -oP 'Apache/\d+\.\d+\.\d+' | cut -d'/' -f2)
        if [[ -n "$apache_version" ]]; then
            # Apache < 2.4.41 tiene vulnerabilidades como CVE-2019-0211, etc.
            if [[ "$(printf '%s\n' "$apache_version" "2.4.41" | sort -V | head -n1)" != "2.4.41" ]]; then
                log_warning "Versión de Apache potencialmente vulnerable: $apache_version"
                log_info "Recomendado: Actualizar a Apache 2.4.41+ para parches de seguridad"
            fi
        fi
    fi

    log_success "Verificación de vulnerabilidades completada"
}

# Función para verificar conectividad a repositorios
check_repository_connectivity() {
    log_step "Verificando conectividad a repositorios..."

    local repos=("https://software.virtualmin.com" "https://github.com" "https://deb.debian.org" "https://archive.ubuntu.com")

    for repo in "${repos[@]}"; do
        if curl -s --ssl-reqd --connect-timeout 10 --max-time 5 --retry 3 --retry-delay 2 --user-agent "Dependency-Validator/1.0" "$repo" > /dev/null 2>&1; then
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

    local total_steps=14
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

    ((current_step++))
    show_progress "$current_step" "$total_steps" "Verificando versiones mínimas..."
    check_minimum_versions

    ((current_step++))
    show_progress "$current_step" "$total_steps" "Verificando archivos críticos..."
    check_critical_files

    ((current_step++))
    show_progress "$current_step" "$total_steps" "Verificando bibliotecas comunes..."
    check_common_libraries

    ((current_step++))
    show_progress "$current_step" "$total_steps" "Detectando vulnerabilidades..."
    check_vulnerable_versions

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

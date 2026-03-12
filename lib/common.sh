#!/bin/bash

# ============================================================================
# BIBLIOTECA COMÚN PARA SCRIPTS
# ============================================================================
# Funciones de logging, constantes y utilidades comunes
# ============================================================================

# Colores ANSI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Constantes de error
ERROR_ROOT_REQUIRED=1
ERROR_INTERNET_CONNECTION=2
ERROR_OS_NOT_SUPPORTED=3
ERROR_ARCHITECTURE_NOT_SUPPORTED=4
ERROR_MEMORY_INSUFFICIENT=5
ERROR_DISK_INSUFFICIENT=6
ERROR_PACKAGE_MANAGER_NOT_FOUND=7
ERROR_DEPENDENCY_MISSING=8
ERROR_PERL_NOT_FOUND=9
ERROR_PYTHON_NOT_FOUND=10
ERROR_PHP_NOT_FOUND=11
ERROR_MYSQL_NOT_FOUND=12
ERROR_APACHE_NOT_FOUND=13
ERROR_FILE_NOT_FOUND=14
ERROR_PERMISSION_DENIED=15
ERROR_INVALID_ARGUMENT=16
ERROR_NETWORK_ERROR=17
ERROR_TIMEOUT=18
ERROR_CHECKSUM_MISMATCH=19
ERROR_BACKUP_FAILED=20
ERROR_RESTORE_FAILED=21
ERROR_CONFIGURATION_ERROR=22
ERROR_SERVICE_FAILED=23
ERROR_SSL_ERROR=24
ERROR_DATABASE_ERROR=25
ERROR_API_ERROR=26
ERROR_AUTHENTICATION_FAILED=27
ERROR_AUTHORIZATION_FAILED=28
ERROR_VALIDATION_FAILED=29
ERROR_DOWNLOAD_FAILED=30
ERROR_INSTALLATION_FAILED=31
ERROR_PHP_VERSION_TOO_OLD=32
ERROR_MYSQL_VERSION_TOO_OLD=33
ERROR_APACHE_VERSION_TOO_OLD=34
ERROR_SECURITY_VULNERABILITY=35
ERROR_UNKNOWN=99

# Archivo de log global (opcional)
LOG_FILE="${LOG_FILE:-}"

# Función para logging con timestamp
_log() {
    local level="$1"
    local color="$2"
    local message="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Mostrar en pantalla con color
    echo -e "${color}[$timestamp] [$level]${NC} $message"

    # Guardar en archivo si está definido
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
}

# Funciones de logging específicas
log_error() {
    _log "ERROR" "$RED" "$*"
}

log_success() {
    _log "SUCCESS" "$GREEN" "$*"
}

log_info() {
    _log "INFO" "$BLUE" "$*"
}

log_warning() {
    _log "WARNING" "$YELLOW" "$*"
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        _log "DEBUG" "$PURPLE" "$*"
    fi
}

log_step() {
    _log "STEP" "$CYAN" "$*"
}

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para mostrar barra de progreso
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

# Función para verificar conectividad a URL
check_url_connectivity() {
    local url="$1"
    local timeout="${2:-10}"

    if curl -s --ssl-reqd --connect-timeout "$timeout" --max-time "$((timeout * 2))" --retry 3 --retry-delay 2 --user-agent "Script-Checker/1.0" "$url" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Función para obtener tamaño de archivo en MB
get_file_size_mb() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local size_bytes
        size_bytes=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
        echo $((size_bytes / 1024 / 1024))
    else
        echo "0"
    fi
}

# Función para crear backup de archivo
backup_file() {
    local file="$1"
    local backup_suffix="${2:-.bak}"

    if [[ -f "$file" ]]; then
        cp "$file" "${file}${backup_suffix}"
        log_debug "Backup creado: ${file}${backup_suffix}"
        return 0
    else
        log_warning "Archivo no existe para backup: $file"
        return 1
    fi
}

# Función para restaurar desde backup
restore_file() {
    local file="$1"
    local backup_suffix="${2:-.bak}"

    if [[ -f "${file}${backup_suffix}" ]]; then
        cp "${file}${backup_suffix}" "$file"
        log_debug "Archivo restaurado desde backup: $file"
        return 0
    else
        log_warning "Backup no encontrado: ${file}${backup_suffix}"
        return 1
    fi
}

# Función para verificar suma de verificación
verify_checksum() {
    local file="$1"
    local expected_checksum="$2"
    local algorithm="${3:-sha256}"

    if [[ ! -f "$file" ]]; then
        log_error "Archivo no encontrado para verificación: $file"
        return 1
    fi

    local actual_checksum
    case "$algorithm" in
        md5)
            actual_checksum=$(md5sum "$file" 2>/dev/null | cut -d' ' -f1 || md5 "$file" 2>/dev/null | cut -d' ' -f4)
            ;;
        sha1)
            actual_checksum=$(sha1sum "$file" 2>/dev/null | cut -d' ' -f1 || shasum -a 1 "$file" 2>/dev/null | cut -d' ' -f1)
            ;;
        sha256)
            actual_checksum=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$file" 2>/dev/null | cut -d' ' -f1)
            ;;
        *)
            log_error "Algoritmo de checksum no soportado: $algorithm"
            return 1
            ;;
    esac

    if [[ "$actual_checksum" == "$expected_checksum" ]]; then
        log_debug "Checksum verificado correctamente: $file"
        return 0
    else
        log_error "Checksum no coincide para $file"
        log_debug "Esperado: $expected_checksum"
        log_debug "Actual: $actual_checksum"
        return 1
    fi
}

# Función para manejar errores
handle_error() {
    local error_code="$1"
    local message="$2"

    log_error "$message"
    log_error "Código de error: $error_code"

    # Cleanup si existe función cleanup
    if declare -f cleanup >/dev/null 2>&1; then
        log_debug "Ejecutando cleanup..."
        cleanup
    fi

    exit "$error_code"
}

# Función para validar argumentos
validate_args() {
    local expected="$1"
    local actual="$2"
    local usage_message="$3"

    if [[ $actual -lt $expected ]]; then
        log_error "Argumentos insuficientes. Esperados: $expected, Recibidos: $actual"
        if [[ -n "$usage_message" ]]; then
            log_info "$usage_message"
        fi
        exit $ERROR_INVALID_ARGUMENT
    fi
}

# Función para verificar permisos de root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        handle_error $ERROR_ROOT_REQUIRED "Este script debe ejecutarse como root (usa sudo)"
    fi
}

# Función para verificar conectividad a internet
check_internet() {
    local test_urls=("https://google.com" "https://github.com" "https://software.virtualmin.com")

    for url in "${test_urls[@]}"; do
        if check_url_connectivity "$url" 10; then
            log_debug "Conectividad OK (probado con $url)"
            return 0
        fi
    done

    handle_error $ERROR_INTERNET_CONNECTION "No hay conectividad a internet"
}

# Función para mostrar ayuda
show_help() {
    local script_name
    script_name=$(basename "$0")

    echo "Uso: $script_name [opciones]"
    echo
    echo "Opciones:"
    echo "  -h, --help     Mostrar esta ayuda"
    echo "  -v, --verbose  Modo verbose"
    echo "  -d, --debug    Modo debug"
    echo "  --log-file     Archivo de log personalizado"
    echo
}

# Parsear argumentos comunes
parse_common_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--debug)
                DEBUG=true
                shift
                ;;
            --log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            *)
                # Argumento no reconocido, dejar que el script lo maneje
                break
                ;;
        esac
    done
}

# Función para obtener timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Función para obtener información del sistema
get_system_info() {
    local info_type="${1:-all}"
    
    case "$info_type" in
        os)
            if [[ -f /etc/os-release ]]; then
                . /etc/os-release
                echo "${NAME:-Unknown} ${VERSION_ID:-Unknown}"
            else
                echo "Unknown"
            fi
            ;;
        arch)
            uname -m
            ;;
        memory)
            local mem_kb
            mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")
            local mem_gb=$(awk "BEGIN {printf \"%.2f\", $mem_kb / 1024 / 1024}")
            echo "${mem_gb}GB"
            ;;
        disk)
            local disk_kb
            disk_kb=$(df --output=avail / | tail -n 1 2>/dev/null || echo "0")
            local disk_gb=$(awk "BEGIN {printf \"%.2f\", $disk_kb / 1024 / 1024}")
            echo "${disk_gb}GB libres"
            ;;
        cpu)
            nproc 2>/dev/null || echo "1"
            ;;
        *)
            # Devolver toda la información
            echo "OS: $(get_system_info os)"
            echo "Arquitectura: $(get_system_info arch)"
            echo "Memoria: $(get_system_info memory)"
            echo "Disco: $(get_system_info disk)"
            echo "CPU: $(get_system_info cpu)"
            ;;
    esac
}

# Función para verificar si un servicio está corriendo
service_running() {
    local service="$1"
    
    if command -v systemctl >/dev/null 2>&1; then
        systemctl is-active --quiet "$service"
    elif command -v service >/dev/null 2>&1; then
        service "$service" status >/dev/null 2>&1
    else
        # Fallback: verificar si el proceso existe
        pgrep -x "$service" >/dev/null 2>&1
    fi
}

# Función para verificar conectividad de red
check_network_connectivity() {
    local test_urls=("https://google.com" "https://github.com" "https://software.virtualmin.com")
    
    for url in "${test_urls[@]}"; do
        if check_url_connectivity "$url" 10; then
            return 0
        fi
    done
    
    return 1
}

# Función para verificar si un puerto está disponible
check_port_available() {
    local port="$1"
    
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        return 1  # Puerto en uso
    fi
    
    return 0  # Puerto disponible
}

# Función para verificar conexión a MySQL
check_mysql_connection() {
    local mysql_cmd=""
    
    if command -v mysql >/dev/null 2>&1; then
        mysql_cmd="mysql"
    elif command -v mariadb >/dev/null 2>&1; then
        mysql_cmd="mariadb"
    else
        return 1
    fi
    
    # Intentar conexión sin contraseña (solo verificar si el servicio responde)
    if "$mysql_cmd" -e "SELECT 1" >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

# Función para detectar gestor de paquetes
detect_package_manager() {
    local package_managers=("apt-get" "yum" "dnf" "zypper")
    
    for manager in "${package_managers[@]}"; do
        if command -v "$manager" >/dev/null 2>&1; then
            echo "$manager"
            return 0
        fi
    done
    
    return 1
}

# Función para verificar permisos de escritura
check_write_permissions() {
    local path="$1"
    
    if [[ -w "$path" ]]; then
        return 0
    fi
    
    return 1
}

# Función para instalar paquetes
install_packages() {
    local packages=("$@")
    
    if [[ -z "${packages[*]}" ]]; then
        return 0
    fi
    
    local package_manager
    package_manager=$(detect_package_manager)
    
    if [[ -z "$package_manager" ]]; then
        log_error "No se encontró un gestor de paquetes soportado"
        return 1
    fi
    
    case "$package_manager" in
        apt-get)
            DEBIAN_FRONTEND=noninteractive apt-get install -y -q "${packages[@]}"
            ;;
        yum)
            yum install -y "${packages[@]}"
            ;;
        dnf)
            dnf install -y "${packages[@]}"
            ;;
        zypper)
            zypper install -y "${packages[@]}"
            ;;
        *)
            log_error "Gestor de paquetes no soportado: $package_manager"
            return 1
            ;;
    esac
}

# Función para mostrar información del sistema
show_system_info() {
    echo ""
    echo "=== Información del Sistema ==="
    echo "Sistema Operativo: $(get_system_info os)"
    echo "Arquitectura: $(get_system_info arch)"
    echo "Memoria: $(get_system_info memory)"
    echo "Disco: $(get_system_info disk)"
    echo "CPU: $(get_system_info cpu)"
    echo "============================"
    echo ""
}

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

# Función para asegurar directorio existe
ensure_directory() {
    local dir="$1"
    
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" 2>/dev/null || {
            log_error "No se pudo crear directorio: $dir"
            return 1
        }
    fi
    
    return 0
}

# Función para mostrar progreso completo
show_progress_complete() {
    echo -ne "\r${GREEN}[100%]${NC} Completado${BLUE}████████████████████████████████████████████████████${NC} 100%\n"
}

# Función para detectar y validar sistema operativo
# Args: Ninguno
# Returns:
#   0 - Sistema operativo soportado
#   1 - Sistema operativo no soportado o no detectable
detect_and_validate_os() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "No se puede detectar el sistema operativo"
        return 1
    fi
    
    # Cargar variables del archivo os-release
    . /etc/os-release
    
    # Lista de distribuciones soportadas
    local supported_distros=("ubuntu" "debian" "centos" "rhel" "fedora" "rocky" "almalinux")
    local distro_id="${ID,,}"
    
    # Verificar si la distribución está soportada
    for supported in "${supported_distros[@]}"; do
        if [[ "$distro_id" == "$supported" ]]; then
            log_debug "Sistema operativo detectado: $PRETTY_NAME"
            return 0
        fi
    done
    
    log_error "Sistema operativo no soportado: $PRETTY_NAME"
    log_info "Distribuciones soportadas: ${supported_distros[*]}"
    return 1
}

# Exportar funciones para que estén disponibles en scripts que sourcean este archivo
export -f _log log_error log_success log_info log_warning log_debug log_step
export -f command_exists show_progress check_url_connectivity get_file_size_mb
export -f backup_file restore_file verify_checksum handle_error validate_args
export -f check_root check_internet show_help parse_common_args
export -f get_timestamp get_system_info service_running check_network_connectivity
export -f check_port_available check_mysql_connection detect_package_manager
export -f check_write_permissions install_packages show_system_info get_server_ip
export -f ensure_directory show_progress_complete detect_and_validate_os
#!/bin/bash
##############################################################################
# SECURE INPUT SANITIZER - PRODUCTION SECURE
# Sanitizador de entradas para prevenir inyección de comandos
# Cumple con estándares de seguridad P0 críticos
##############################################################################

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="/var/log/webmin/input_sanitizer.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$@"
}

log_warn() {
    log "WARN" "$@"
}

log_error() {
    log "ERROR" "$@"
}

log_success() {
    log "SUCCESS" "$@"
}

# Función quotemeta - Escapa caracteres especiales para shell
# Similar a Perl's quotemeta, escapa todos los caracteres que tienen
# significado especial en el shell
quotemeta() {
    local input="$1"
    local output=""
    local i=0
    local len=${#input}
    
    while [ $i -lt $len ]; do
        local char="${input:$i:1}"
        case "$char" in
            '\'|'|'|'&'|';'|'$'|'('|')'|'<'|'>'|'*'|'?'|'['|']'|'{'|'}'|'^'|'!'|'#'|'~'|'`'|'"')
                output+="\\$char"
                ;;
            *)
                output+="$char"
                ;;
        esac
        ((i++))
    done
    
    echo "$output"
}

# Validar y sanitizar nombre de archivo
sanitize_filename() {
    local filename="$1"
    
    # Verificar que no está vacío
    if [ -z "$filename" ]; then
        log_error "Nombre de archivo vacío"
        return 1
    fi
    
    # Verificar longitud máxima (255 caracteres)
    if [ ${#filename} -gt 255 ]; then
        log_error "Nombre de archivo demasiado largo: ${#filename} caracteres"
        return 1
    fi
    
    # Verificar que no contiene caracteres peligrosos
    local dangerous_chars='../..|/etc/|/proc/|/sys/|/dev/|/root/|~|`|$|;|&|>|<|*|?|[|]|{|}|(|)|!|\\|\'|"'
    
    for pattern in $(echo "$dangerous_chars" | tr '|' '\n'); do
        if [[ "$filename" == *"$pattern"* ]]; then
            log_error "Nombre de archivo contiene patrón peligroso: $pattern"
            return 1
        fi
    done
    
    # Verificar que no comienza con guión (podría ser interpretado como opción)
    if [[ "$filename" == -* ]]; then
        log_error "Nombre de archivo comienza con guión: $filename"
        return 1
    fi
    
    # Verificar que no contiene espacios (para evitar problemas de shell)
    if [[ "$filename" == *" "* ]]; then
        log_error "Nombre de archivo contiene espacios: $filename"
        return 1
    fi
    
    # Verificar que solo contiene caracteres alfanuméricos, guiones, guiones bajos y puntos
    if ! [[ "$filename" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        log_error "Nombre de archivo contiene caracteres no permitidos: $filename"
        return 1
    fi
    
    # Escapar caracteres especiales
    quotemeta "$filename"
}

# Validar y sanitizar ruta de archivo
sanitize_filepath() {
    local filepath="$1"
    
    # Verificar que no está vacío
    if [ -z "$filepath" ]; then
        log_error "Ruta de archivo vacía"
        return 1
    fi
    
    # Verificar longitud máxima (4096 caracteres)
    if [ ${#filepath} -gt 4096 ]; then
        log_error "Ruta de archivo demasiado larga: ${#filepath} caracteres"
        return 1
    fi
    
    # Verificar que no contiene path traversal
    if [[ "$filepath" == *"../"* ]] || [[ "$filepath" == *"/../"* ]]; then
        log_error "Ruta de archivo contiene path traversal: $filepath"
        return 1
    fi
    
    # Verificar que no comienza con /../
    if [[ "$filepath" == "/../"* ]]; then
        log_error "Ruta de archivo comienza con path traversal: $filepath"
        return 1
    fi
    
    # Verificar que no contiene rutas peligrosas
    local dangerous_paths='/etc/passwd|/etc/shadow|/etc/sudoers|/etc/hosts|/root/.ssh|~/.ssh|/proc/|/sys/|/dev/'
    
    for pattern in $(echo "$dangerous_paths" | tr '|' '\n'); do
        if [[ "$filepath" == *"$pattern"* ]]; then
            log_error "Ruta de archivo contiene ruta peligrosa: $pattern"
            return 1
        fi
    done
    
    # Normalizar la ruta (eliminar . y ..)
    local normalized_path=$(realpath -m "$filepath" 2>/dev/null || echo "$filepath")
    
    # Verificar que la ruta normalizada no contiene .. al final
    if [[ "$normalized_path" == *".." ]]; then
        log_error "Ruta normalizada contiene .. al final: $normalized_path"
        return 1
    fi
    
    # Escapar caracteres especiales
    quotemeta "$normalized_path"
}

# Validar y sanitizar nombre de usuario
sanitize_username() {
    local username="$1"
    
    # Verificar que no está vacío
    if [ -z "$username" ]; then
        log_error "Nombre de usuario vacío"
        return 1
    fi
    
    # Verificar longitud máxima (32 caracteres)
    if [ ${#username} -gt 32 ]; then
        log_error "Nombre de usuario demasiado largo: ${#username} caracteres"
        return 1
    fi
    
    # Verificar que solo contiene caracteres alfanuméricos y guiones bajos
    if ! [[ "$username" =~ ^[a-zA-Z0-9_]+$ ]]; then
        log_error "Nombre de usuario contiene caracteres no permitidos: $username"
        return 1
    fi
    
    # Verificar que no comienza con número o guión bajo
    if [[ "$username" =~ ^[0-9_] ]]; then
        log_error "Nombre de usuario comienza con número o guión bajo: $username"
        return 1
    fi
    
    # Verificar que no es un nombre de usuario reservado
    local reserved_users='root|daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|irc|gnats|nobody'
    
    for reserved in $(echo "$reserved_users" | tr '|' '\n'); do
        if [ "$username" = "$reserved" ]; then
            log_error "Nombre de usuario reservado: $username"
            return 1
        fi
    done
    
    # Escapar caracteres especiales
    quotemeta "$username"
}

# Validar y sanitizar dirección IP
sanitize_ip_address() {
    local ip="$1"
    
    # Verificar que no está vacío
    if [ -z "$ip" ]; then
        log_error "Dirección IP vacía"
        return 1
    fi
    
    # Validar formato IPv4
    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        # Verificar que cada octeto está en el rango 0-255
        local IFS='.'
        read -ra octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [ "$octet" -gt 255 ] || [ "$octet" -lt 0 ]; then
                log_error "Octeto fuera de rango en dirección IP: $octet"
                return 1
            fi
        done
        echo "$ip"
        return 0
    fi
    
    # Validar formato IPv6
    if [[ "$ip" =~ ^([0-9a-fA-F]{0,4}:){7}[0-9a-fA-F]{0,4}$ ]]; then
        echo "$ip"
        return 0
    fi
    
    log_error "Formato de dirección IP inválido: $ip"
    return 1
}

# Validar y sanitizar número de puerto
sanitize_port() {
    local port="$1"
    
    # Verificar que no está vacío
    if [ -z "$port" ]; then
        log_error "Número de puerto vacío"
        return 1
    fi
    
    # Verificar que es un número
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        log_error "Número de puerto no es numérico: $port"
        return 1
    fi
    
    # Verificar rango válido (1-65535)
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "Número de puerto fuera de rango: $port (debe ser 1-65535)"
        return 1
    fi
    
    # Verificar que no es un puerto reservado del sistema (1-1024)
    if [ "$port" -le 1024 ]; then
        log_warn "Número de puerto reservado del sistema: $port"
    fi
    
    echo "$port"
}

# Validar y sanitizar nombre de dominio
sanitize_domain() {
    local domain="$1"
    
    # Verificar que no está vacío
    if [ -z "$domain" ]; then
        log_error "Nombre de dominio vacío"
        return 1
    fi
    
    # Verificar longitud máxima (253 caracteres)
    if [ ${#domain} -gt 253 ]; then
        log_error "Nombre de dominio demasiado largo: ${#domain} caracteres"
        return 1
    fi
    
    # Verificar que solo contiene caracteres permitidos
    if ! [[ "$domain" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        log_error "Nombre de dominio contiene caracteres no permitidos: $domain"
        return 1
    fi
    
    # Verificar que no comienza o termina con guión o punto
    if [[ "$domain" == -* ]] || [[ "$domain" == *- ]] || [[ "$domain" == .* ]] || [[ "$domain" == *. ]]; then
        log_error "Nombre de dominio comienza o termina con guión o punto: $domain"
        return 1
    fi
    
    # Verificar que no contiene dos puntos consecutivos
    if [[ "$domain" == *..* ]]; then
        log_error "Nombre de dominio contiene dos puntos consecutivos: $domain"
        return 1
    fi
    
    # Verificar que tiene al menos un punto
    if ! [[ "$domain" == *.* ]]; then
        log_error "Nombre de dominio no contiene punto: $domain"
        return 1
    fi
    
    # Verificar que el TLD tiene al menos 2 caracteres
    local tld="${domain##*.}"
    if [ ${#tld} -lt 2 ]; then
        log_error "TLD demasiado corto: $tld"
        return 1
    fi
    
    # Escapar caracteres especiales
    quotemeta "$domain"
}

# Validar y sanitizar URL
sanitize_url() {
    local url="$1"
    
    # Verificar que no está vacío
    if [ -z "$url" ]; then
        log_error "URL vacía"
        return 1
    fi
    
    # Verificar longitud máxima (2048 caracteres)
    if [ ${#url} -gt 2048 ]; then
        log_error "URL demasiado larga: ${#url} caracteres"
        return 1
    fi
    
    # Verificar que comienza con protocolo válido
    if ! [[ "$url" =~ ^https?:// ]] && ! [[ "$url" =~ ^ftp:// ]]; then
        log_error "URL no comienza con protocolo válido: $url"
        return 1
    fi
    
    # Verificar que no contiene caracteres peligrosos
    if [[ "$url" == *"<script"* ]] || [[ "$url" == *"javascript:"* ]] || [[ "$url" == *"data:"* ]]; then
        log_error "URL contiene patrón peligroso: $url"
        return 1
    fi
    
    # Escapar caracteres especiales
    quotemeta "$url"
}

# Validar y sanitizar entrada de comando
sanitize_command_input() {
    local input="$1"
    local allowed_pattern="${2:-}"
    
    # Verificar que no está vacío
    if [ -z "$input" ]; then
        log_error "Entrada de comando vacía"
        return 1
    fi
    
    # Verificar longitud máxima (1024 caracteres)
    if [ ${#input} -gt 1024 ]; then
        log_error "Entrada de comando demasiado larga: ${#input} caracteres"
        return 1
    fi
    
    # Verificar que no contiene caracteres peligrosos de inyección
    local injection_patterns=';|&|\||\$|\(|\)|`|<|>|\\|\n|\r|\t'
    
    for pattern in $(echo "$injection_patterns" | tr '|' '\n'); do
        if [[ "$input" == *"$pattern"* ]]; then
            log_error "Entrada de comando contiene patrón de inyección: $pattern"
            return 1
        fi
    done
    
    # Si se proporciona un patrón permitido, verificar que la entrada coincide
    if [ -n "$allowed_pattern" ]; then
        if ! [[ "$input" =~ ^$allowed_pattern$ ]]; then
            log_error "Entrada de comando no coincide con patrón permitido: $allowed_pattern"
            return 1
        fi
    fi
    
    # Escapar caracteres especiales
    quotemeta "$input"
}

# Ejecutar comando de forma segura con argumentos en array
safe_execute() {
    local command="$1"
    shift
    local args=("$@")
    
    log_info "Ejecutando comando seguro: $command"
    
    # Verificar que el comando existe y es ejecutable
    if [ ! -x "$command" ]; then
        log_error "Comando no existe o no es ejecutable: $command"
        return 1
    fi
    
    # Verificar que el comando está en una ruta permitida
    local allowed_paths='/bin|/sbin|/usr/bin|/usr/sbin|/usr/local/bin|/usr/local/sbin'
    local command_path=$(dirname "$command")
    local is_allowed=0
    
    for path in $(echo "$allowed_paths" | tr '|' '\n'); do
        if [[ "$command_path" == "$path" ]]; then
            is_allowed=1
            break
        fi
    done
    
    if [ "$is_allowed" -eq 0 ]; then
        log_error "Comando no está en ruta permitida: $command_path"
        return 1
    fi
    
    # Ejecutar comando con argumentos en array (seguro contra inyección)
    "$command" "${args[@]}"
    return $?
}

# Ejecutar comando con sanitización de argumentos
safe_execute_with_args() {
    local command="$1"
    shift
    local args=("$@")
    
    log_info "Ejecutando comando con argumentos sanitizados: $command"
    
    # Verificar que el comando existe y es ejecutable
    if [ ! -x "$command" ]; then
        log_error "Comando no existe o no es ejecutable: $command"
        return 1
    fi
    
    # Construir array de argumentos sanitizados
    local sanitized_args=()
    for arg in "${args[@]}"; do
        sanitized_args+=("$(quotemeta "$arg")")
    done
    
    # Ejecutar comando con argumentos sanitizados
    "$command" "${sanitized_args[@]}"
    return $?
}

# Validar y sanitizar entrada de usuario general
sanitize_user_input() {
    local input="$1"
    local max_length="${2:-1024}"
    
    # Verificar que no está vacío
    if [ -z "$input" ]; then
        log_error "Entrada de usuario vacía"
        return 1
    fi
    
    # Verificar longitud máxima
    if [ ${#input} -gt "$max_length" ]; then
        log_error "Entrada de usuario demasiado larga: ${#input} caracteres (máximo: $max_length)"
        return 1
    fi
    
    # Verificar que no contiene caracteres de control (excepto newline y tab)
    if [[ "$input" == $'\x00' ]]; then
        log_error "Entrada de usuario contiene carácter nulo"
        return 1
    fi
    
    # Escapar caracteres especiales
    quotemeta "$input"
}

# Función principal
main() {
    case "${1:-help}" in
        filename)
            if [ -z "${2:-}" ]; then
                log_error "Uso: $0 filename <nombre_archivo>"
                exit 1
            fi
            sanitize_filename "$2"
            ;;
        filepath)
            if [ -z "${2:-}" ]; then
                log_error "Uso: $0 filepath <ruta_archivo>"
                exit 1
            fi
            sanitize_filepath "$2"
            ;;
        username)
            if [ -z "${2:-}" ]; then
                log_error "Uso: $0 username <nombre_usuario>"
                exit 1
            fi
            sanitize_username "$2"
            ;;
        ip)
            if [ -z "${2:-}" ]; then
                log_error "Uso: $0 ip <direccion_ip>"
                exit 1
            fi
            sanitize_ip_address "$2"
            ;;
        port)
            if [ -z "${2:-}" ]; then
                log_error "Uso: $0 port <numero_puerto>"
                exit 1
            fi
            sanitize_port "$2"
            ;;
        domain)
            if [ -z "${2:-}" ]; then
                log_error "Uso: $0 domain <nombre_dominio>"
                exit 1
            fi
            sanitize_domain "$2"
            ;;
        url)
            if [ -z "${2:-}" ]; then
                log_error "Uso: $0 url <url>"
                exit 1
            fi
            sanitize_url "$2"
            ;;
        command)
            if [ -z "${2:-}" ]; then
                log_error "Uso: $0 command <entrada> [patrón_permitido]"
                exit 1
            fi
            sanitize_command_input "$2" "${3:-}"
            ;;
        quotemeta)
            if [ -z "${2:-}" ]; then
                log_error "Uso: $0 quotemeta <texto>"
                exit 1
            fi
            quotemeta "$2"
            ;;
        help|--help|-h)
            cat << EOF
Sanitizador de Entradas Seguras para Producción

Uso:
  $0 filename <nombre_archivo>          Sanitizar nombre de archivo
  $0 filepath <ruta_archivo>           Sanitizar ruta de archivo
  $0 username <nombre_usuario>         Sanitizar nombre de usuario
  $0 ip <direccion_ip>                Sanitizar dirección IP
  $0 port <numero_puerto>             Sanitizar número de puerto
  $0 domain <nombre_dominio>          Sanitizar nombre de dominio
  $0 url <url>                        Sanitizar URL
  $0 command <entrada> [patrón]       Sanitizar entrada de comando
  $0 quotemeta <texto>                Escapar caracteres especiales
  $0 help                             Mostrar esta ayuda

Ejemplos:
  $0 filename "documento.txt"
  $0 filepath "/var/log/system.log"
  $0 username "usuario_ejemplo"
  $0 ip "192.168.1.1"
  $0 port "8080"
  $0 domain "example.com"
  $0 url "https://example.com"
  $0 command "start" "^(start|stop|restart)$"

Seguridad:
  - Prevención de inyección de comandos
  - Validación de formatos
  - Escapado de caracteres especiales
  - Verificación de longitudes máximas
  - Detección de patrones peligrosos

EOF
            ;;
        *)
            log_error "Comando no reconocido: $1"
            echo "Use '$0 help' para ver la ayuda"
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"

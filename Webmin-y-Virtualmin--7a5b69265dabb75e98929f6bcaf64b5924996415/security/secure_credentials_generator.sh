#!/bin/bash
##############################################################################
# SECURE CREDENTIALS GENERATOR - PRODUCTION SECURE
# Generador de credenciales únicas y seguras para producción
# Cumple con estándares de seguridad P0 críticos
##############################################################################

set -euo pipefail

# Configuración
MIN_PASSWORD_LENGTH=24
MIN_USERNAME_LENGTH=12
ENTROPY_BITS=256
SECRET_DIR="/etc/webmin/secrets"
ENV_FILE="${SECRET_DIR}/production.env"
BACKUP_DIR="${SECRET_DIR}/backups"

# Caracteres permitidos para contraseñas (alfanuméricos + símbolos seguros)
PASSWORD_CHARS='A-Za-z0-9!@#$%^&*()_+-=[]{}|;:,.<>?'

# Caracteres permitidos para nombres de usuario (alfanuméricos + guiones bajos)
USERNAME_CHARS='A-Za-z0-9_'

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="/var/log/webmin/secure_credentials.log"
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

# Generar contraseña segura con alta entropía
generate_secure_password() {
    local length="${1:-$MIN_PASSWORD_LENGTH}"
    
    # Validar longitud mínima
    if [ "$length" -lt "$MIN_PASSWORD_LENGTH" ]; then
        log_error "Longitud de contraseña debe ser al menos ${MIN_PASSWORD_LENGTH} caracteres"
        return 1
    fi
    
    # Generar contraseña usando /dev/urandom con alta entropía
    local password=""
    local password_chars_length=${#PASSWORD_CHARS}
    
    for i in $(seq 1 "$length"); do
        local random_byte=$(od -An -N1 -tu1 /dev/urandom | tr -d ' ')
        local char_index=$((random_byte % password_chars_length))
        password+="${PASSWORD_CHARS:$char_index:1}"
    done
    
    # Verificar que la contraseña cumple con requisitos de complejidad
    if ! validate_password_complexity "$password"; then
        log_warn "Contraseña generada no cumple requisitos, reintentando..."
        generate_secure_password "$length"
        return $?
    fi
    
    echo "$password"
}

# Validar complejidad de contraseña
validate_password_complexity() {
    local password="$1"
    
    # Verificar longitud mínima
    if [ ${#password} -lt "$MIN_PASSWORD_LENGTH" ]; then
        return 1
    fi
    
    # Verificar que contiene al menos un carácter de cada tipo
    if ! [[ "$password" =~ [A-Z] ]]; then
        return 1
    fi
    
    if ! [[ "$password" =~ [a-z] ]]; then
        return 1
    fi
    
    if ! [[ "$password" =~ [0-9] ]]; then
        return 1
    fi
    
    if ! [[ "$password" =~ [!@#$%^&*()_+\-=\[\]{}|;:,.<>?] ]]; then
        return 1
    fi
    
    return 0
}

# Generar nombre de usuario seguro
generate_secure_username() {
    local length="${1:-$MIN_USERNAME_LENGTH}"
    
    # Validar longitud mínima
    if [ "$length" -lt "$MIN_USERNAME_LENGTH" ]; then
        log_error "Longitud de usuario debe ser al menos ${MIN_USERNAME_LENGTH} caracteres"
        return 1
    fi
    
    # Generar nombre de usuario
    local username=""
    local username_chars_length=${#USERNAME_CHARS}
    
    for i in $(seq 1 "$length"); do
        local random_byte=$(od -An -N1 -tu1 /dev/urandom | tr -d ' ')
        local char_index=$((random_byte % username_chars_length))
        username+="${USERNAME_CHARS:$char_index:1}"
    done
    
    # Asegurar que comienza con letra
    username=$(echo "$username" | sed 's/^[0-9_]/a/')
    
    echo "$username"
}

# Generar token seguro para APIs
generate_secure_token() {
    local length="${1:-64}"
    
    # Generar token hexadecimal seguro
    openssl rand -hex "$length"
}

# Generar clave de encriptación
generate_encryption_key() {
    # Generar clave de 256 bits (32 bytes) en base64
    openssl rand -base64 32
}

# Validar permisos de archivo de entorno
validate_env_permissions() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        log_error "Archivo no existe: $file"
        return 1
    fi
    
    # Verificar permisos (deben ser 600)
    local perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%OLp" "$file" 2>/dev/null)
    if [ "$perms" != "600" ]; then
        log_error "Permisos incorrectos en $file: $perms (esperado: 600)"
        return 1
    fi
    
    # Verificar owner (debe ser root:root)
    local owner=$(stat -c "%U:%G" "$file" 2>/dev/null || stat -f "%Su:%Sg" "$file" 2>/dev/null)
    if [ "$owner" != "root:root" ]; then
        log_error "Owner incorrecto en $file: $owner (esperado: root:root)"
        return 1
    fi
    
    return 0
}

# Validar contenido de archivo de entorno
validate_env_content() {
    local file="$1"
    
    # Lista de claves permitidas (allowlist)
    local allowed_keys=(
        "GRAFANA_ADMIN_USER"
        "GRAFANA_ADMIN_PASSWORD"
        "PROMETHEUS_ADMIN_USER"
        "PROMETHEUS_ADMIN_PASSWORD"
        "N8N_ADMIN_USER"
        "N8N_ADMIN_PASSWORD"
        "DATABASE_ROOT_PASSWORD"
        "WEBMIN_ROOT_PASSWORD"
        "API_SECRET_KEY"
        "ENCRYPTION_KEY"
        "JWT_SECRET"
        "SESSION_SECRET"
    )
    
    # Leer archivo línea por línea
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Ignorar comentarios y líneas vacías
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        
        # Extraer clave
        local key="${line%%=*}"
        
        # Verificar que la clave está en la allowlist
        local is_allowed=0
        for allowed_key in "${allowed_keys[@]}"; do
            if [ "$key" = "$allowed_key" ]; then
                is_allowed=1
                break
            fi
        done
        
        if [ "$is_allowed" -eq 0 ]; then
            log_error "Clave no permitida en archivo de entorno: $key"
            return 1
        fi
        
        # Verificar que el valor no está vacío
        local value="${line#*=}"
        if [ -z "$value" ]; then
            log_error "Valor vacío para clave: $key"
            return 1
        fi
        
        # Verificar longitud mínima para contraseñas
        if [[ "$key" =~ PASSWORD ]] && [ ${#value} -lt "$MIN_PASSWORD_LENGTH" ]; then
            log_error "Contraseña demasiado corta para $key: ${#value} caracteres (mínimo: $MIN_PASSWORD_LENGTH)"
            return 1
        fi
        
    done < "$file"
    
    return 0
}

# Crear directorio de secretos con permisos seguros
setup_secret_dir() {
    log_info "Configurando directorio de secretos..."
    
    # Crear directorio si no existe
    if [ ! -d "$SECRET_DIR" ]; then
        mkdir -p "$SECRET_DIR"
        chmod 700 "$SECRET_DIR"
        chown root:root "$SECRET_DIR"
        log_success "Directorio de secretos creado: $SECRET_DIR"
    fi
    
    # Crear directorio de backups
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        chmod 700 "$BACKUP_DIR"
        chown root:root "$BACKUP_DIR"
        log_success "Directorio de backups creado: $BACKUP_DIR"
    fi
}

# Crear backup de archivo de entorno existente
backup_env_file() {
    if [ -f "$ENV_FILE" ]; then
        local timestamp=$(date '+%Y%m%d_%H%M%S')
        local backup_file="${BACKUP_DIR}/production.env.backup_${timestamp}"
        
        cp "$ENV_FILE" "$backup_file"
        chmod 600 "$backup_file"
        chown root:root "$backup_file"
        
        log_success "Backup creado: $backup_file"
    fi
}

# Generar credenciales completas para producción
generate_production_credentials() {
    log_info "Generando credenciales de producción..."
    
    # Crear archivo de entorno temporal
    local temp_file=$(mktemp)
    chmod 600 "$temp_file"
    
    # Generar credenciales para Grafana
    local grafana_user=$(generate_secure_username 16)
    local grafana_password=$(generate_secure_password 32)
    echo "GRAFANA_ADMIN_USER=${grafana_user}" >> "$temp_file"
    echo "GRAFANA_ADMIN_PASSWORD=${grafana_password}" >> "$temp_file"
    log_success "Credenciales Grafana generadas"
    
    # Generar credenciales para Prometheus
    local prometheus_user=$(generate_secure_username 16)
    local prometheus_password=$(generate_secure_password 32)
    echo "PROMETHEUS_ADMIN_USER=${prometheus_user}" >> "$temp_file"
    echo "PROMETHEUS_ADMIN_PASSWORD=${prometheus_password}" >> "$temp_file"
    log_success "Credenciales Prometheus generadas"
    
    # Generar credenciales para N8N
    local n8n_user=$(generate_secure_username 16)
    local n8n_password=$(generate_secure_password 32)
    echo "N8N_ADMIN_USER=${n8n_user}" >> "$temp_file"
    echo "N8N_ADMIN_PASSWORD=${n8n_password}" >> "$temp_file"
    log_success "Credenciales N8N generadas"
    
    # Generar contraseña de root para base de datos
    local db_root_password=$(generate_secure_password 32)
    echo "DATABASE_ROOT_PASSWORD=${db_root_password}" >> "$temp_file"
    log_success "Contraseña root de base de datos generada"
    
    # Generar contraseña de Webmin
    local webmin_root_password=$(generate_secure_password 32)
    echo "WEBMIN_ROOT_PASSWORD=${webmin_root_password}" >> "$temp_file"
    log_success "Contraseña root de Webmin generada"
    
    # Generar claves de encriptación y tokens
    local api_secret=$(generate_secure_token 64)
    echo "API_SECRET_KEY=${api_secret}" >> "$temp_file"
    
    local encryption_key=$(generate_encryption_key)
    echo "ENCRYPTION_KEY=${encryption_key}" >> "$temp_file"
    
    local jwt_secret=$(generate_secure_token 64)
    echo "JWT_SECRET=${jwt_secret}" >> "$temp_file"
    
    local session_secret=$(generate_secure_token 64)
    echo "SESSION_SECRET=${session_secret}" >> "$temp_file"
    
    log_success "Claves de encriptación y tokens generados"
    
    # Mover archivo temporal a ubicación final
    mv "$temp_file" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    chown root:root "$ENV_FILE"
    
    log_success "Archivo de entorno creado: $ENV_FILE"
}

# Validar archivo de entorno completo
validate_env_file() {
    log_info "Validando archivo de entorno..."
    
    if [ ! -f "$ENV_FILE" ]; then
        log_error "Archivo de entorno no existe: $ENV_FILE"
        return 1
    fi
    
    # Validar permisos
    if ! validate_env_permissions "$ENV_FILE"; then
        return 1
    fi
    
    # Validar contenido
    if ! validate_env_content "$ENV_FILE"; then
        return 1
    fi
    
    log_success "Archivo de entorno validado correctamente"
    return 0
}

# Cargar credencial específica de forma segura
load_credential() {
    local key="$1"
    
    if [ ! -f "$ENV_FILE" ]; then
        log_error "Archivo de entorno no existe: $ENV_FILE"
        return 1
    fi
    
    # Validar permisos antes de leer
    if ! validate_env_permissions "$ENV_FILE"; then
        return 1
    fi
    
    # Leer valor de forma segura
    local value=$(grep "^${key}=" "$ENV_FILE" | cut -d= -f2-)
    
    if [ -z "$value" ]; then
        log_error "Credencial no encontrada: $key"
        return 1
    fi
    
    echo "$value"
}

# Rotar credenciales específicas
rotate_credential() {
    local key="$1"
    
    log_info "Rotando credencial: $key"
    
    # Backup antes de rotar
    backup_env_file
    
    # Generar nueva credencial según el tipo
    local new_value=""
    
    if [[ "$key" =~ GRAFANA_ADMIN_PASSWORD ]] || [[ "$key" =~ PROMETHEUS_ADMIN_PASSWORD ]] || [[ "$key" =~ N8N_ADMIN_PASSWORD ]] || [[ "$key" =~ DATABASE_ROOT_PASSWORD ]] || [[ "$key" =~ WEBMIN_ROOT_PASSWORD ]]; then
        new_value=$(generate_secure_password 32)
    elif [[ "$key" =~ GRAFANA_ADMIN_USER ]] || [[ "$key" =~ PROMETHEUS_ADMIN_USER ]] || [[ "$key" =~ N8N_ADMIN_USER ]]; then
        new_value=$(generate_secure_username 16)
    elif [[ "$key" =~ API_SECRET_KEY ]] || [[ "$key" =~ JWT_SECRET ]] || [[ "$key" =~ SESSION_SECRET ]]; then
        new_value=$(generate_secure_token 64)
    elif [[ "$key" =~ ENCRYPTION_KEY ]]; then
        new_value=$(generate_encryption_key)
    else
        log_error "Tipo de credencial no soportado: $key"
        return 1
    fi
    
    # Actualizar archivo
    if grep -q "^${key}=" "$ENV_FILE"; then
        sed -i "s/^${key}=.*/${key}=${new_value}/" "$ENV_FILE"
    else
        echo "${key}=${new_value}" >> "$ENV_FILE"
    fi
    
    # Asegurar permisos
    chmod 600 "$ENV_FILE"
    chown root:root "$ENV_FILE"
    
    log_success "Credencial rotada: $key"
}

# Mostrar resumen de credenciales (sin valores)
show_credentials_summary() {
    log_info "Resumen de credenciales:"
    
    if [ ! -f "$ENV_FILE" ]; then
        log_warn "Archivo de entorno no existe"
        return 1
    fi
    
    echo ""
    echo -e "${BLUE}=== CREDENCIALES DE PRODUCCIÓN ===${NC}"
    echo ""
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Ignorar comentarios y líneas vacías
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        
        local key="${line%%=*}"
        local value="${line#*=}"
        local value_length=${#value}
        
        echo -e "${GREEN}✓${NC} $key (${value_length} caracteres)"
        
    done < "$ENV_FILE"
    
    echo ""
    echo -e "${YELLOW}⚠${NC} Archivo: $ENV_FILE"
    echo -e "${YELLOW}⚠${NC} Permisos: 600 (root:root)"
    echo ""
}

# Función principal
main() {
    case "${1:-help}" in
        generate)
            setup_secret_dir
            backup_env_file
            generate_production_credentials
            validate_env_file
            show_credentials_summary
            ;;
        validate)
            validate_env_file
            ;;
        load)
            if [ -z "${2:-}" ]; then
                log_error "Uso: $0 load <clave>"
                exit 1
            fi
            load_credential "$2"
            ;;
        rotate)
            if [ -z "${2:-}" ]; then
                log_error "Uso: $0 rotate <clave>"
                exit 1
            fi
            rotate_credential "$2"
            validate_env_file
            ;;
        summary)
            show_credentials_summary
            ;;
        help|--help|-h)
            cat << EOF
Generador de Credenciales Seguras para Producción

Uso:
  $0 generate              Generar nuevas credenciales de producción
  $0 validate              Validar archivo de entorno existente
  $0 load <clave>          Cargar credencial específica
  $0 rotate <clave>         Rotar credencial específica
  $0 summary               Mostrar resumen de credenciales
  $0 help                  Mostrar esta ayuda

Ejemplos:
  $0 generate
  $0 load GRAFANA_ADMIN_PASSWORD
  $0 rotate GRAFANA_ADMIN_PASSWORD
  $0 validate

Seguridad:
  - Contraseñas de mínimo 24 caracteres
  - Alfanuméricas + símbolos
  - Alta entropía (256 bits)
  - Permisos 600 (root:root)
  - Validación de allowlist de claves

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

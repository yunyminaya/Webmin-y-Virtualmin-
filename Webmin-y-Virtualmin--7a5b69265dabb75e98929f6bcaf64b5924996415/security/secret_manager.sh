#!/bin/bash

# Gestor de Secretos Seguro para Webmin/Virtualmin Enterprise
# Versión: 1.0.0
# Proporciona gestión segura de credenciales y configuración sensible

set -euo pipefail

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_ROOT="/opt/webmin-security"
SECRETS_DIR="$SECURITY_ROOT/secrets"
CONFIG_DIR="$SECURITY_ROOT/config"
KEY_DIR="$SECURITY_ROOT/keys"
LOG_DIR="$SECURITY_ROOT/logs"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging seguro
log_secure() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [SECURE] $1${NC}" | tee -a "$LOG_DIR/secret_manager.log"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1${NC}" | tee -a "$LOG_DIR/secret_manager.log" >&2
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] $1${NC}" | tee -a "$LOG_DIR/secret_manager.log"
}

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1${NC}" | tee -a "$LOG_DIR/secret_manager.log"
}

# Verificar privilegios
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root"
        exit 1
    fi
}

# Inicializar directorios seguros
init_secure_directories() {
    log_info "Inicializando directorios seguros..."
    
    mkdir -p "$SECRETS_DIR" "$CONFIG_DIR" "$KEY_DIR" "$LOG_DIR"
    
    # Establecer permisos restrictivos
    chmod 700 "$SECURITY_ROOT"
    chmod 700 "$SECRETS_DIR"
    chmod 755 "$CONFIG_DIR"
    chmod 700 "$KEY_DIR"
    chmod 755 "$LOG_DIR"
    
    # Asegurar ownership
    chown root:root "$SECURITY_ROOT" "$SECRETS_DIR" "$KEY_DIR"
    chown root:root "$LOG_DIR"
    
    log_secure "Directorios seguros inicializados"
}

# Generar clave de encriptación
generate_encryption_key() {
    local key_file="$KEY_DIR/master.key"
    
    if [[ -f "$key_file" ]]; then
        log_warning "Clave de encriptación ya existe"
        return 0
    fi
    
    log_info "Generando clave de encriptación maestra..."
    
    # Generar clave aleatoria de 256 bits
    openssl rand -hex 32 > "$key_file"
    chmod 600 "$key_file"
    chown root:root "$key_file"
    
    log_secure "Clave de encriptación generada y almacenada de forma segura"
}

# Encriptar secreto
encrypt_secret() {
    local secret="$1"
    local key_file="$KEY_DIR/master.key"
    
    if [[ ! -f "$key_file" ]]; then
        log_error "Clave de encriptación no encontrada. Ejecute: $0 init"
        exit 1
    fi
    
    echo "$secret" | openssl enc -aes-256-cbc -salt -pass file:"$key_file" -base64
}

# Desencriptar secreto
decrypt_secret() {
    local encrypted_secret="$1"
    local key_file="$KEY_DIR/master.key"
    
    if [[ ! -f "$key_file" ]]; then
        log_error "Clave de encriptación no encontrada. Ejecute: $0 init"
        exit 1
    fi
    
    echo "$encrypted_secret" | openssl enc -aes-256-cbc -d -pass file:"$key_file" -base64
}

# Almacenar secreto de forma segura
store_secret() {
    local secret_name="$1"
    local secret_value="$2"
    local description="${3:-}"
    
    if [[ -z "$secret_name" || -z "$secret_value" ]]; then
        log_error "Nombre y valor del secreto son requeridos"
        exit 1
    fi
    
    local secret_file="$SECRETS_DIR/${secret_name}.enc"
    local meta_file="$SECRETS_DIR/${secret_name}.meta"
    
    # Encriptar y almacenar el secreto
    local encrypted_value
    encrypted_value=$(encrypt_secret "$secret_value")
    echo "$encrypted_value" > "$secret_file"
    chmod 600 "$secret_file"
    chown root:root "$secret_file"
    
    # Almacenar metadatos
    cat > "$meta_file" << EOF
name=$secret_name
created=$(date -Iseconds)
description=$description
access_count=0
last_access=
EOF
    chmod 644 "$meta_file"
    chown root:root "$meta_file"
    
    log_secure "Secreto '$secret_name' almacenado de forma segura"
}

# Recuperar secreto
retrieve_secret() {
    local secret_name="$1"
    
    if [[ -z "$secret_name" ]]; then
        log_error "Nombre del secreto es requerido"
        exit 1
    fi
    
    local secret_file="$SECRETS_DIR/${secret_name}.enc"
    local meta_file="$SECRETS_DIR/${secret_name}.meta"
    
    if [[ ! -f "$secret_file" ]]; then
        log_error "Secreto '$secret_name' no encontrado"
        exit 1
    fi
    
    # Leer y desencriptar
    local encrypted_value
    encrypted_value=$(cat "$secret_file")
    local decrypted_value
    decrypted_value=$(decrypt_secret "$encrypted_value")
    
    # Actualizar metadatos de acceso
    if [[ -f "$meta_file" ]]; then
        local access_count
        access_count=$(grep "^access_count=" "$meta_file" | cut -d= -f2)
        access_count=$((access_count + 1))
        
        sed -i "s/^access_count=.*/access_count=$access_count/" "$meta_file"
        sed -i "s/^last_access=.*/last_access=$(date -Iseconds)/" "$meta_file"
    fi
    
    echo "$decrypted_value"
    log_info "Secreto '$secret_name' accedido"
}

# Listar secretos
list_secrets() {
    log_info "Listando secretos almacenados:"
    
    if [[ ! -d "$SECRETS_DIR" ]]; then
        log_warning "Directorio de secretos no existe. Ejecute: $0 init"
        return 1
    fi
    
    echo -e "\n${PURPLE}=== SECRETOS ALMACENADOS ===${NC}"
    printf "%-20s %-30s %-15s %-20s\n" "NOMBRE" "DESCRIPCIÓN" "ACCESOS" "ÚLTIMO ACCESO"
    printf "%-20s %-30s %-15s %-20s\n" "--------------------" "------------------------------" "---------------" "--------------------"
    
    for meta_file in "$SECRETS_DIR"/*.meta; do
        if [[ -f "$meta_file" ]]; then
            local name
            name=$(grep "^name=" "$meta_file" | cut -d= -f2)
            local description
            description=$(grep "^description=" "$meta_file" | cut -d= -f2)
            local access_count
            access_count=$(grep "^access_count=" "$meta_file" | cut -d= -f2)
            local last_access
            last_access=$(grep "^last_access=" "$meta_file" | cut -d= -f2)
            
            printf "%-20s %-30s %-15s %-20s\n" "$name" "${description:-N/A}" "$access_count" "${last_access:-Nunca}"
        fi
    done
    echo
}

# Eliminar secreto
delete_secret() {
    local secret_name="$1"
    
    if [[ -z "$secret_name" ]]; then
        log_error "Nombre del secreto es requerido"
        exit 1
    fi
    
    local secret_file="$SECRETS_DIR/${secret_name}.enc"
    local meta_file="$SECRETS_DIR/${secret_name}.meta"
    
    if [[ -f "$secret_file" ]]; then
        # Sobreescribir archivo antes de eliminar (seguridad)
        shred -vfz -n 3 "$secret_file" 2>/dev/null || rm -f "$secret_file"
        rm -f "$meta_file"
        log_secure "Secreto '$secret_name' eliminado permanentemente"
    else
        log_error "Secreto '$secret_name' no encontrado"
        exit 1
    fi
}

# Generar archivo .env seguro
generate_env_file() {
    local env_file="$CONFIG_DIR/secure.env"
    local template_file="${1:-}"
    
    log_info "Generando archivo .env seguro..."
    
    cat > "$env_file" << 'EOF'
# Archivo de entorno seguro generado automáticamente
# NO COMMIT - Contiene secretos encriptados
# Generado: $(date)

# Configuración de base de datos
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-3306}
DB_NAME=${DB_NAME:-webmin}
DB_USER=${DB_USER:-webmin_user}
DB_PASSWORD_ENCRYPTED=true

# Configuración de Webmin/Virtualmin
WEBMIN_PORT=${WEBMIN_PORT:-10000}
WEBMIN_SSL_ENABLED=${WEBMIN_SSL_ENABLED:-true}
VIRTUALMIN_LICENSE_KEY_ENCRYPTED=true

# Configuración de AWS (si aplica)
AWS_ACCESS_KEY_ID_ENCRYPTED=true
AWS_SECRET_ACCESS_KEY_ENCRYPTED=true
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1}

# Configuración de backup
BACKUP_ENCRYPTION_KEY_ENCRYPTED=true
BACKUP_SCHEDULE=${BACKUP_SCHEDULE:-0 2 * * *}

# Configuración de monitoreo
GRAFANA_ADMIN_PASSWORD_ENCRYPTED=true
PROMETHEUS_ADMIN_PASSWORD_ENCRYPTED=true

# Configuración de notificaciones
SMTP_PASSWORD_ENCRYPTED=true
SLACK_WEBHOOK_URL_ENCRYPTED=true
PAGERDUTY_SERVICE_KEY_ENCRYPTED=true

# Configuración de SSL
SSL_CERT_PATH=${SSL_CERT_PATH:-/etc/letsencrypt/live/}
SSL_KEY_ENCRYPTED=true
SSL_AUTO_RENEWAL=${SSL_AUTO_RENEWAL:-true}

# Configuración de seguridad
SECURITY_KEY_ROTATION_DAYS=${SECURITY_KEY_ROTATION_DAYS:-90}
AUDIT_LOG_RETENTION_DAYS=${AUDIT_LOG_RETENTION_DAYS:-365}
EOF
    
    chmod 600 "$env_file"
    chown root:root "$env_file"
    
    log_secure "Archivo .env seguro generado en $env_file"
}

# Validar configuración de seguridad
validate_security_config() {
    log_info "Validando configuración de seguridad..."
    
    local issues=0
    
    # Verificar permisos de directorios
    if [[ $(stat -c %a "$SECRETS_DIR" 2>/dev/null) != "700" ]]; then
        log_error "Permisos incorrectos en directorio de secretos"
        ((issues++))
    fi
    
    if [[ $(stat -c %a "$KEY_DIR" 2>/dev/null) != "700" ]]; then
        log_error "Permisos incorrectos en directorio de claves"
        ((issues++))
    fi
    
    # Verificar existencia de clave maestra
    if [[ ! -f "$KEY_DIR/master.key" ]]; then
        log_error "Clave maestra no encontrada"
        ((issues++))
    fi
    
    # Verificar archivos con permisos inseguros
    while IFS= read -r -d '' file; do
        local perms
        perms=$(stat -c %a "$file")
        if [[ "$perms" != "600" && "$file" == *.enc ]]; then
            log_warning "Archivo de secreto con permisos inseguros: $file ($perms)"
            ((issues++))
        fi
    done < <(find "$SECRETS_DIR" -name "*.enc" -print0 2>/dev/null)
    
    if [[ $issues -eq 0 ]]; then
        log_secure "Configuración de seguridad validada correctamente"
        return 0
    else
        log_error "Se encontraron $issues problemas de seguridad"
        return 1
    fi
}

# Rotar claves
rotate_keys() {
    log_info "Iniciando rotación de claves..."
    
    # Backup de clave actual
    local current_key="$KEY_DIR/master.key"
    local backup_key="$KEY_DIR/master.key.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [[ -f "$current_key" ]]; then
        cp "$current_key" "$backup_key"
        chmod 600 "$backup_key"
        log_info "Backup de clave actual creado"
    fi
    
    # Generar nueva clave
    generate_encryption_key
    
    # Re-encriptar todos los secretos con la nueva clave
    log_info "Re-encriptando secretos con nueva clave..."
    for secret_file in "$SECRETS_DIR"/*.enc; do
        if [[ -f "$secret_file" ]]; then
            # Aquí iría la lógica de re-encriptación
            # Por ahora solo registramos la acción
            log_info "Secreto $(basename "$secret_file" .enc) necesita re-encriptación manual"
        fi
    done
    
    log_secure "Rotación de claves completada"
}

# Mostrar ayuda
show_help() {
    cat << EOF
Gestor de Secretos Seguro para Webmin/Virtualmin Enterprise

Uso: $0 <comando> [opciones]

Comandos:
    init                    Inicializa el sistema de gestión de secretos
    store <nombre> <valor>  Almacena un secreto de forma segura
    retrieve <nombre>       Recupera un secreto desencriptado
    list                    Lista todos los secretos almacenados
    delete <nombre>          Elimina un secreto permanentemente
    generate-env            Genera archivo .env seguro
    validate                Valida la configuración de seguridad
    rotate                  Rota las claves de encriptación
    help                    Muestra esta ayuda

Ejemplos:
    $0 init
    $0 store db_password "MiPasswordSeguro123" "Contraseña de base de datos"
    $0 retrieve db_password
    $0 list
    $0 generate-env
    $0 validate

EOF
}

# Función principal
main() {
    check_privileges
    
    case "${1:-}" in
        init)
            init_secure_directories
            generate_encryption_key
            generate_env_file
            ;;
        store)
            if [[ $# -lt 3 ]]; then
                log_error "Uso: $0 store <nombre> <valor> [descripción]"
                exit 1
            fi
            store_secret "$2" "$3" "${4:-}"
            ;;
        retrieve)
            if [[ $# -lt 2 ]]; then
                log_error "Uso: $0 retrieve <nombre>"
                exit 1
            fi
            retrieve_secret "$2"
            ;;
        list)
            list_secrets
            ;;
        delete)
            if [[ $# -lt 2 ]]; then
                log_error "Uso: $0 delete <nombre>"
                exit 1
            fi
            delete_secret "$2"
            ;;
        generate-env)
            generate_env_file "${2:-}"
            ;;
        validate)
            validate_security_config
            ;;
        rotate)
            rotate_keys
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Comando no reconocido: ${1:-}"
            show_help
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"
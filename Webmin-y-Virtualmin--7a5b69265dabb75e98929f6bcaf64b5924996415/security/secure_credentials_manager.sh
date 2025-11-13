#!/bin/bash

# ============================================================================
# 🔐 GESTOR SEGURO DE CREDENCIALES - WEBMIN/VIRTUALMIN
# ============================================================================
# Sistema centralizado de gestión de secretos con cifrado AES-256
# Rotación automática de credenciales y auditoría completa
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_DIR="${SCRIPT_DIR}"
SECRETS_DIR="${SECURITY_DIR}/secrets"
KEYSTORE_DIR="${SECURITY_DIR}/keystore"
AUDIT_LOG="${SECURITY_DIR}/credentials_audit.log"
CONFIG_FILE="${SECURITY_DIR}/credentials_config.conf"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función de logging seguro
log_secure() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # No registrar información sensible en los logs
    local safe_message="$message"
    safe_message=$(echo "$safe_message" | sed -E 's/(password|secret|key|token)[=:][^[:space:]]*/\1=***REDACTED***/gi')
    
    echo "[$timestamp] [$level] $safe_message" >> "$AUDIT_LOG"
    
    case "$level" in
        "INFO")     echo -e "${BLUE}[$timestamp INFO]${NC} $safe_message" ;;
        "SUCCESS")  echo -e "${GREEN}[$timestamp SUCCESS]${NC} $safe_message" ;;
        "WARNING")  echo -e "${YELLOW}[$timestamp WARNING]${NC} $safe_message" ;;
        "ERROR")    echo -e "${RED}[$timestamp ERROR]${NC} $safe_message" ;;
        "CRITICAL") echo -e "${RED}[$timestamp CRITICAL]${NC} $safe_message" ;;
    esac
}

# Inicializar directorios seguros
init_secure_directories() {
    log_secure "INFO" "Inicializando directorios seguros..."
    
    # Crear directorios con permisos restringidos
    mkdir -p "$SECRETS_DIR" "$KEYSTORE_DIR"
    chmod 700 "$SECRETS_DIR" "$KEYSTORE_DIR"
    
    # Verificar que no sean accesibles por otros usuarios
    if [ "$(stat -c %a "$SECRETS_DIR")" != "700" ]; then
        log_secure "ERROR" "Permisos incorrectos en directorio de secretos"
        return 1
    fi
    
    log_secure "SUCCESS" "Directorios seguros inicializados"
}

# Generar clave maestra
generate_master_key() {
    local key_file="$KEYSTORE_DIR/master.key"
    
    if [ -f "$key_file" ]; then
        log_secure "INFO" "Clave maestra ya existe"
        return 0
    fi
    
    log_secure "INFO" "Generando clave maestra AES-256..."
    
    # Generar clave aleatoria de 256 bits
    openssl rand -hex 32 > "$key_file"
    chmod 600 "$key_file"
    
    log_secure "SUCCESS" "Clave maestra generada y protegida"
    log_secure "WARNING" "⚠️  HAZ BACKUP DE LA CLAVE MAESTRA: $key_file"
}

# Cifrar secreto
encrypt_secret() {
    local secret_name="$1"
    local secret_value="$2"
    local encrypted_file="$SECRETS_DIR/${secret_name}.enc"
    
    log_secure "INFO" "Cifrando secreto: $secret_name"
    
    # Cifrar con AES-256 usando la clave maestra
    echo "$secret_value" | openssl enc -aes-256-cbc -salt -pbkdf2 \
        -in - -out "$encrypted_file" \
        -pass file:"$KEYSTORE_DIR/master.key" 2>/dev/null
    
    chmod 600 "$encrypted_file"
    
    # Registrar auditoría (sin el valor del secreto)
    log_secure "INFO" "Secreto cifrado: $secret_name -> $encrypted_file"
    
    echo "$encrypted_file"
}

# Descifrar secreto
decrypt_secret() {
    local secret_name="$1"
    local encrypted_file="$SECRETS_DIR/${secret_name}.enc"
    
    if [ ! -f "$encrypted_file" ]; then
        log_secure "ERROR" "Secreto no encontrado: $secret_name"
        return 1
    fi
    
    log_secure "INFO" "Descifrando secreto: $secret_name"
    
    # Descifrar con AES-256
    openssl enc -aes-256-cbc -d -pbkdf2 \
        -in "$encrypted_file" \
        -pass file:"$KEYSTORE_DIR/master.key" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_secure "INFO" "Secreto descifrado exitosamente: $secret_name"
    else
        log_secure "ERROR" "Error al descifrar secreto: $secret_name"
        return 1
    fi
}

# Almacenar secreto de forma segura
store_secret() {
    local secret_name="$1"
    local secret_value="$2"
    local description="${3:-""}"
    local rotation_days="${4:-90}"
    
    log_secure "INFO" "Almacenando secreto: $secret_name"
    
    # Validar nombre del secreto
    if [[ ! "$secret_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_secure "ERROR" "Nombre de secreto inválido: $secret_name"
        return 1
    fi
    
    # Cifrar y almacenar
    local encrypted_file
    encrypted_file=$(encrypt_secret "$secret_name" "$secret_value")
    
    # Crear metadatos
    local metadata_file="$SECRETS_DIR/${secret_name}.meta"
    cat > "$metadata_file" << EOF
name=$secret_name
description=$description
created=$(date +%s)
rotation_days=$rotation_days
last_rotation=$(date +%s)
access_count=0
EOF
    chmod 600 "$metadata_file"
    
    log_secure "SUCCESS" "Secreto almacenado: $secret_name"
}

# Recuperar secreto
get_secret() {
    local secret_name="$1"
    local metadata_file="$SECRETS_DIR/${secret_name}.meta"
    
    log_secure "INFO" "Recuperando secreto: $secret_name"
    
    if [ ! -f "$metadata_file" ]; then
        log_secure "ERROR" "Metadatos no encontrados para: $secret_name"
        return 1
    fi
    
    # Actualizar contador de acceso
    local access_count
    access_count=$(grep "^access_count=" "$metadata_file" | cut -d'=' -f2)
    access_count=$((access_count + 1))
    sed -i "s/^access_count=.*/access_count=$access_count/" "$metadata_file"
    
    # Descifrar y retornar
    decrypt_secret "$secret_name"
}

# Rotar secreto
rotate_secret() {
    local secret_name="$1"
    local new_value="$2"
    local metadata_file="$SECRETS_DIR/${secret_name}.meta"
    
    log_secure "INFO" "Rotando secreto: $secret_name"
    
    if [ ! -f "$metadata_file" ]; then
        log_secure "ERROR" "Secreto no encontrado para rotación: $secret_name"
        return 1
    fi
    
    # Backup del secreto anterior
    local backup_file="$SECRETS_DIR/${secret_name}.backup.$(date +%s)"
    cp "$SECRETS_DIR/${secret_name}.enc" "$backup_file"
    
    # Actualizar con nuevo valor
    encrypt_secret "$secret_name" "$new_value"
    
    # Actualizar metadatos
    sed -i "s/^last_rotation=.*/last_rotation=$(date +%s)/" "$metadata_file"
    
    log_secure "SUCCESS" "Secreto rotado: $secret_name"
    log_secure "INFO" "Backup guardado: $backup_file"
}

# Verificar rotación automática
check_rotation_needed() {
    local metadata_file="$1"
    local current_time
    current_time=$(date +%s)
    
    if [ ! -f "$metadata_file" ]; then
        return 1
    fi
    
    local rotation_days
    local last_rotation
    
    rotation_days=$(grep "^rotation_days=" "$metadata_file" | cut -d'=' -f2)
    last_rotation=$(grep "^last_rotation=" "$metadata_file" | cut -d'=' -f2)
    
    local rotation_seconds=$((rotation_days * 86400))
    local time_since_rotation=$((current_time - last_rotation))
    
    if [ $time_since_rotation -gt $rotation_seconds ]; then
        return 0  # Necesita rotación
    fi
    
    return 1  # No necesita rotación
}

# Rotación automática de secretos
auto_rotate_secrets() {
    log_secure "INFO" "Verificando rotación automática de secretos..."
    
    local secrets_needing_rotation=()
    
    # Encontrar secretos que necesitan rotación
    for meta_file in "$SECRETS_DIR"/*.meta; do
        if [ -f "$meta_file" ]; then
            if check_rotation_needed "$meta_file"; then
                local secret_name
                secret_name=$(basename "$meta_file" .meta)
                secrets_needing_rotation+=("$secret_name")
            fi
        fi
    done
    
    if [ ${#secrets_needing_rotation[@]} -eq 0 ]; then
        log_secure "INFO" "No hay secretos que necesiten rotación"
        return 0
    fi
    
    log_secure "WARNING" "Secretos que necesitan rotación: ${secrets_needing_rotation[*]}"
    
    # Generar nuevos valores y rotar
    for secret_name in "${secrets_needing_rotation[@]}"; do
        local new_value
        new_value=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        
        rotate_secret "$secret_name" "$new_value"
        
        # Enviar notificación (opcional)
        log_secure "WARNING" "🔄 SECRETO ROTADO: $secret_name (actualizar configuraciones)"
    done
}

# Listar secretos
list_secrets() {
    log_secure "INFO" "Listando secretos almacenados..."
    
    echo ""
    echo -e "${CYAN}📋 SECRETOS ALMACENADOS${NC}"
    echo "================================"
    
    for meta_file in "$SECRETS_DIR"/*.meta; do
        if [ -f "$meta_file" ]; then
            local secret_name
            local description
            local created
            local rotation_days
            local last_rotation
            local access_count
            
            secret_name=$(grep "^name=" "$meta_file" | cut -d'=' -f2)
            description=$(grep "^description=" "$meta_file" | cut -d'=' -f2)
            created=$(grep "^created=" "$meta_file" | cut -d'=' -f2)
            rotation_days=$(grep "^rotation_days=" "$meta_file" | cut -d'=' -f2)
            last_rotation=$(grep "^last_rotation=" "$meta_file" | cut -d'=' -f2)
            access_count=$(grep "^access_count=" "$meta_file" | cut -d'=' -f2)
            
            # Formatear fechas
            created_date=$(date -d "@$created" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$created" '+%Y-%m-%d %H:%M:%S')
            last_rotation_date=$(date -d "@$last_rotation" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$last_rotation" '+%Y-%m-%d %H:%M:%S')
            
            echo -e "${GREEN}🔐 $secret_name${NC}"
            echo "   📝 $description"
            echo "   📅 Creado: $created_date"
            echo "   🔄 Última rotación: $last_rotation_date"
            echo "   ⏰ Rotación cada: $rotation_days días"
            echo "   👁️  Accesos: $access_count"
            
            # Verificar si necesita rotación
            if check_rotation_needed "$meta_file"; then
                echo -e "   ${YELLOW}⚠️  NECESITA ROTACIÓN${NC}"
            fi
            
            echo ""
        fi
    done
}

# Eliminar secreto
delete_secret() {
    local secret_name="$1"
    
    log_secure "WARNING" "Eliminando secreto: $secret_name"
    
    # Eliminar archivos
    rm -f "$SECRETS_DIR/${secret_name}.enc"
    rm -f "$SECRETS_DIR/${secret_name}.meta"
    
    log_secure "SUCCESS" "Secreto eliminado: $secret_name"
}

# Validar integridad del sistema
validate_system() {
    log_secure "INFO" "Validando integridad del sistema de credenciales..."
    
    local issues=0
    
    # Verificar permisos de directorios
    if [ "$(stat -c %a "$SECRETS_DIR")" != "700" ]; then
        log_secure "ERROR" "Permisos incorrectos en SECRETS_DIR"
        ((issues++))
    fi
    
    if [ "$(stat -c %a "$KEYSTORE_DIR")" != "700" ]; then
        log_secure "ERROR" "Permisos incorrectos en KEYSTORE_DIR"
        ((issues++))
    fi
    
    # Verificar clave maestra
    if [ ! -f "$KEYSTORE_DIR/master.key" ]; then
        log_secure "ERROR" "Clave maestra no encontrada"
        ((issues++))
    elif [ "$(stat -c %a "$KEYSTORE_DIR/master.key")" != "600" ]; then
        log_secure "ERROR" "Permisos incorrectos en clave maestra"
        ((issues++))
    fi
    
    # Verificar integridad de secretos
    for enc_file in "$SECRETS_DIR"/*.enc; do
        if [ -f "$enc_file" ]; then
            local secret_name
            secret_name=$(basename "$enc_file" .enc)
            local meta_file="$SECRETS_DIR/${secret_name}.meta"
            
            if [ ! -f "$meta_file" ]; then
                log_secure "WARNING" "Faltan metadatos para: $secret_name"
                ((issues++))
            fi
        fi
    done
    
    if [ $issues -eq 0 ]; then
        log_secure "SUCCESS" "✅ Sistema de credenciales válido"
        return 0
    else
        log_secure "ERROR" "❌ Se encontraron $issues problemas"
        return 1
    fi
}

# Función principal
main() {
    local command="${1:-help}"
    
    case "$command" in
        "init")
            init_secure_directories
            generate_master_key
            ;;
        "store")
            if [ $# -lt 3 ]; then
                echo "Uso: $0 store <nombre> <valor> [descripción] [días_rotación]"
                exit 1
            fi
            init_secure_directories
            generate_master_key
            store_secret "$2" "$3" "${4:-""}" "${5:-90}"
            ;;
        "get")
            if [ $# -lt 2 ]; then
                echo "Uso: $0 get <nombre>"
                exit 1
            fi
            init_secure_directories
            get_secret "$2"
            ;;
        "rotate")
            if [ $# -lt 3 ]; then
                echo "Uso: $0 rotate <nombre> <nuevo_valor>"
                exit 1
            fi
            init_secure_directories
            rotate_secret "$2" "$3"
            ;;
        "list")
            init_secure_directories
            list_secrets
            ;;
        "delete")
            if [ $# -lt 2 ]; then
                echo "Uso: $0 delete <nombre>"
                exit 1
            fi
            init_secure_directories
            delete_secret "$2"
            ;;
        "auto-rotate")
            init_secure_directories
            auto_rotate_secrets
            ;;
        "validate")
            init_secure_directories
            validate_system
            ;;
        "help"|*)
            echo ""
            echo -e "${CYAN}🔐 GESTOR SEGURO DE CREDENCIALES${NC}"
            echo "================================"
            echo ""
            echo "Comandos disponibles:"
            echo ""
            echo "  init                    - Inicializar el sistema"
            echo "  store <nombre> <valor>   - Almacenar un secreto"
            echo "  get <nombre>            - Recuperar un secreto"
            echo "  rotate <nombre> <valor>  - Rotar un secreto"
            echo "  list                    - Listar todos los secretos"
            echo "  delete <nombre>         - Eliminar un secreto"
            echo "  auto-rotate             - Rotación automática"
            echo "  validate                - Validar integridad"
            echo "  help                    - Mostrar esta ayuda"
            echo ""
            echo "Ejemplos:"
            echo "  $0 store db_password 'MiPassword123' 'Base de datos principal' 30"
            echo "  $0 get db_password"
            echo "  $0 rotate db_password 'NuevoPassword456'"
            echo "  $0 auto-rotate"
            echo ""
            ;;
    esac
}

# Verificar dependencias
if ! command -v openssl >/dev/null 2>&1; then
    echo "❌ OpenSSL es requerido pero no está instalado"
    exit 1
fi

# Ejecutar comando principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
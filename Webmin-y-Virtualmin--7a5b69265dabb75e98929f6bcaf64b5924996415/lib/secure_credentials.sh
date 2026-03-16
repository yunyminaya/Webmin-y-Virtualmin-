#!/bin/bash

# Sistema de Gestion Segura de Credenciales para Webmin/Virtualmin

CREDENTIALS_DIR="/etc/webmin/credentials"
CREDENTIALS_FILE="$CREDENTIALS_DIR/secure_credentials.enc"
SALT_FILE="$CREDENTIALS_DIR/salt.bin"
LOG_FILE="/var/log/webmin/credentials.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_credentials() {
    local level=$1
    local message=$2
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    if [ -n "$LOG_FILE" ]; then
        mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

check_dependencies() {
    local missing_deps=()

    if ! command -v openssl >/dev/null 2>&1; then
        missing_deps+=("openssl")
    fi

    if ! command -v hexdump >/dev/null 2>&1; then
        missing_deps+=("hexdump")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}Error: Dependencias faltantes: ${missing_deps[*]}${NC}"
        return 1
    fi

    return 0
}

init_credentials_system() {
    log_credentials "INFO" "Inicializando sistema de credenciales"

    if ! check_dependencies; then
        return 1
    fi

    mkdir -p "$CREDENTIALS_DIR"
    chmod 700 "$CREDENTIALS_DIR"

    if [ ! -f "$SALT_FILE" ]; then
        openssl rand -hex 32 > "$SALT_FILE"
        chmod 600 "$SALT_FILE"
        log_credentials "INFO" "Salt generado para el sistema de credenciales"
    fi

    if [ ! -f "$CREDENTIALS_FILE" ]; then
        : > "$CREDENTIALS_FILE"
        chmod 600 "$CREDENTIALS_FILE"
        log_credentials "INFO" "Archivo de credenciales creado: $CREDENTIALS_FILE"
    fi

    echo -e "${GREEN}Sistema de credenciales inicializado correctamente${NC}"
    return 0
}

derive_key() {
    local password=$1
    local salt
    salt=$(cat "$SALT_FILE")
    echo -n "$password$salt" | openssl dgst -sha256 -hex | cut -d' ' -f2
}

sign_entry() {
    local payload=$1
    local key=$2
    echo -n "$payload" | openssl dgst -sha256 -hmac "$key" | cut -d' ' -f2
}

encrypt_data() {
    local data=$1
    local key=$2
    printf '%s' "$data" | openssl enc -aes-256-cbc -pbkdf2 -salt -pass pass:"$key" -base64 -A 2>/dev/null
}

decrypt_data() {
    local encrypted_data=$1
    local key=$2
    printf '%s' "$encrypted_data" | openssl enc -aes-256-cbc -pbkdf2 -d -pass pass:"$key" -base64 -A 2>/dev/null
}

encode_credential_entry() {
    local service=$1
    local username=$2
    local password=$3
    local key=$4
    local payload
    local signature

    payload="$service:$username:$password"
    signature=$(sign_entry "$payload" "$key")
    printf 'CREDv1|%s|%s' "$payload" "$signature"
}

decode_credential_entry() {
    local encrypted_entry=$1
    local key=$2
    local decrypted_entry
    local body
    local payload
    local signature
    local expected_signature

    decrypted_entry=$(decrypt_data "$encrypted_entry" "$key") || return 1
    [ -n "$decrypted_entry" ] || return 1

    [[ "$decrypted_entry" == CREDv1\|* ]] || return 1

    body=${decrypted_entry#CREDv1|}
    signature=${body##*|}
    payload=${body%|$signature}
    expected_signature=$(sign_entry "$payload" "$key")

    [ "$signature" = "$expected_signature" ] || return 1
    printf '%s' "$payload"
}

store_credential() {
    local service=$1
    local username=$2
    local password=$3
    local master_password=$4
    local key
    local entry
    local encrypted_entry

    if [ -z "$service" ] || [ -z "$username" ] || [ -z "$password" ] || [ -z "$master_password" ]; then
        echo -e "${RED}Error: Todos los parametros son requeridos${NC}"
        return 1
    fi

    if [ ! -f "$SALT_FILE" ] || [ ! -f "$CREDENTIALS_FILE" ]; then
        init_credentials_system || return 1
    fi

    key=$(derive_key "$master_password")
    [ -n "$key" ] || {
        echo -e "${RED}Error: No se pudo derivar la clave${NC}"
        return 1
    }

    entry=$(encode_credential_entry "$service" "$username" "$password" "$key")
    encrypted_entry=$(encrypt_data "$entry" "$key")
    [ -n "$encrypted_entry" ] || {
        echo -e "${RED}Error: No se pudo cifrar la credencial${NC}"
        return 1
    }

    echo "$encrypted_entry" >> "$CREDENTIALS_FILE"

    log_credentials "INFO" "Credencial almacenada para servicio: $service"
    echo -e "${GREEN}Credencial almacenada correctamente para $service${NC}"
    return 0
}

retrieve_credential() {
    local service=$1
    local master_password=$2
    local key

    if [ -z "$service" ] || [ -z "$master_password" ]; then
        echo -e "${RED}Error: Todos los parametros son requeridos${NC}"
        return 1
    fi

    if [ ! -f "$SALT_FILE" ] || [ ! -f "$CREDENTIALS_FILE" ]; then
        echo -e "${RED}Error: Sistema de credenciales no inicializado${NC}"
        return 1
    fi

    key=$(derive_key "$master_password")
    [ -n "$key" ] || {
        echo -e "${RED}Error: No se pudo derivar la clave${NC}"
        return 1
    }

    while IFS= read -r encrypted_entry; do
        local payload
        local entry_service
        local entry_username
        local entry_password

        [ -n "$encrypted_entry" ] || continue
        payload=$(decode_credential_entry "$encrypted_entry" "$key") || continue

        entry_service=$(echo "$payload" | cut -d: -f1)
        if [ "$entry_service" = "$service" ]; then
            entry_username=$(echo "$payload" | cut -d: -f2)
            entry_password=$(echo "$payload" | cut -d: -f3-)

            echo "USERNAME:$entry_username"
            echo "PASSWORD:$entry_password"
            log_credentials "INFO" "Credencial recuperada para servicio: $service"
            return 0
        fi
    done < "$CREDENTIALS_FILE"

    echo -e "${YELLOW}No se encontro credencial para el servicio: $service${NC}"
    return 1
}

list_services() {
    local master_password=$1
    local key
    local found=false

    if [ -z "$master_password" ]; then
        echo -e "${RED}Error: Se requiere la contrasena maestra${NC}"
        return 1
    fi

    if [ ! -f "$SALT_FILE" ] || [ ! -f "$CREDENTIALS_FILE" ]; then
        echo -e "${RED}Error: Sistema de credenciales no inicializado${NC}"
        return 1
    fi

    key=$(derive_key "$master_password")
    [ -n "$key" ] || {
        echo -e "${RED}Error: No se pudo derivar la clave${NC}"
        return 1
    }

    echo "Servicios almacenados:"
    echo "===================="

    while IFS= read -r encrypted_entry; do
        local payload
        local entry_service
        local entry_username

        [ -n "$encrypted_entry" ] || continue
        payload=$(decode_credential_entry "$encrypted_entry" "$key") || continue
        entry_service=$(echo "$payload" | cut -d: -f1)
        entry_username=$(echo "$payload" | cut -d: -f2)
        echo "- $entry_service ($entry_username)"
        found=true
    done < "$CREDENTIALS_FILE"

    if [ "$found" = false ]; then
        echo "No hay credenciales almacenadas"
    fi

    log_credentials "INFO" "Lista de servicios solicitada"
    return 0
}

delete_credential() {
    local service=$1
    local master_password=$2
    local key
    local temp_file
    local found=false

    if [ -z "$service" ] || [ -z "$master_password" ]; then
        echo -e "${RED}Error: Todos los parametros son requeridos${NC}"
        return 1
    fi

    if [ ! -f "$SALT_FILE" ] || [ ! -f "$CREDENTIALS_FILE" ]; then
        echo -e "${RED}Error: Sistema de credenciales no inicializado${NC}"
        return 1
    fi

    key=$(derive_key "$master_password")
    [ -n "$key" ] || {
        echo -e "${RED}Error: No se pudo derivar la clave${NC}"
        return 1
    }

    temp_file=$(mktemp)

    while IFS= read -r encrypted_entry; do
        local payload
        local entry_service

        [ -n "$encrypted_entry" ] || continue
        payload=$(decode_credential_entry "$encrypted_entry" "$key")
        if [ $? -ne 0 ]; then
            echo "$encrypted_entry" >> "$temp_file"
            continue
        fi

        entry_service=$(echo "$payload" | cut -d: -f1)
        if [ "$entry_service" != "$service" ]; then
            echo "$encrypted_entry" >> "$temp_file"
        else
            found=true
        fi
    done < "$CREDENTIALS_FILE"

    mv "$temp_file" "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE"

    if [ "$found" = true ]; then
        log_credentials "INFO" "Credencial eliminada para servicio: $service"
        echo -e "${GREEN}Credencial eliminada correctamente para $service${NC}"
        return 0
    fi

    echo -e "${YELLOW}No se encontro credencial para el servicio: $service${NC}"
    return 1
}

verify_security() {
    local issues=0
    local dir_perms
    local file_perms
    local salt_perms

    echo "Verificación de seguridad del sistema de credenciales:"
    echo "======================================================"

    if [ -d "$CREDENTIALS_DIR" ]; then
        dir_perms=$(stat -c "%a" "$CREDENTIALS_DIR" 2>/dev/null || stat -f "%A" "$CREDENTIALS_DIR" 2>/dev/null)
        if [ "$dir_perms" != "700" ]; then
            echo -e "${RED}✗ Permisos incorrectos en directorio: $dir_perms (deberia ser 700)${NC}"
            issues=$((issues + 1))
        else
            echo -e "${GREEN}✓ Permisos correctos en directorio${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Directorio de credenciales no existe${NC}"
        issues=$((issues + 1))
    fi

    if [ -f "$CREDENTIALS_FILE" ]; then
        file_perms=$(stat -c "%a" "$CREDENTIALS_FILE" 2>/dev/null || stat -f "%A" "$CREDENTIALS_FILE" 2>/dev/null)
        if [ "$file_perms" != "600" ]; then
            echo -e "${RED}✗ Permisos incorrectos en archivo de credenciales: $file_perms (deberia ser 600)${NC}"
            issues=$((issues + 1))
        else
            echo -e "${GREEN}✓ Permisos correctos en archivo de credenciales${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Archivo de credenciales no existe${NC}"
        issues=$((issues + 1))
    fi

    if [ -f "$SALT_FILE" ]; then
        salt_perms=$(stat -c "%a" "$SALT_FILE" 2>/dev/null || stat -f "%A" "$SALT_FILE" 2>/dev/null)
        if [ "$salt_perms" != "600" ]; then
            echo -e "${RED}✗ Permisos incorrectos en archivo salt: $salt_perms (deberia ser 600)${NC}"
            issues=$((issues + 1))
        else
            echo -e "${GREEN}✓ Permisos correctos en archivo salt${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Archivo salt no existe${NC}"
        issues=$((issues + 1))
    fi

    if check_dependencies; then
        echo -e "${GREEN}✓ Dependencias verificadas${NC}"
    else
        echo -e "${RED}✗ Faltan dependencias${NC}"
        issues=$((issues + 1))
    fi

    if [ $issues -eq 0 ]; then
        echo "Configuración de seguridad: OK"
        echo -e "${GREEN}Sistema de credenciales seguro${NC}"
        return 0
    fi

    echo -e "${RED}Se encontraron $issues problemas de seguridad${NC}"
    return 1
}

show_help() {
    echo "Sistema de Gestion Segura de Credenciales"
    echo "Uso:"
    echo "  source lib/secure_credentials.sh"
    echo ""
    echo "Funciones disponibles:"
    echo "  init_credentials_system"
    echo "  store_credential <service> <user> <pass> <master>"
    echo "  retrieve_credential <service> <master>"
    echo "  list_services <master>"
    echo "  delete_credential <service> <master>"
    echo "  verify_security"
    echo "  show_help"
}

if [ "${1:-}" = "--export" ]; then
    export -f init_credentials_system
    export -f store_credential
    export -f retrieve_credential
    export -f list_services
    export -f delete_credential
    export -f verify_security
    export -f show_help
fi

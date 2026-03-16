#!/bin/bash

# Sistema de gestion segura de credenciales - version de prueba

CREDENTIALS_DIR="./test_credentials"
LOG_FILE="./test_credentials.log"
MASTER_PASSWORD="test_master_password_123"

log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

file_mode() {
    stat -c "%a" "$1" 2>/dev/null || stat -f "%A" "$1" 2>/dev/null || echo ""
}

init_credentials_system() {
    mkdir -p "$CREDENTIALS_DIR"
    chmod 700 "$CREDENTIALS_DIR" 2>/dev/null || true
    touch "$LOG_FILE"

    if [ ! -f "$CREDENTIALS_DIR/.salt" ]; then
        openssl rand -hex 16 > "$CREDENTIALS_DIR/.salt"
        chmod 600 "$CREDENTIALS_DIR/.salt"
    fi

    if [ -f "$CREDENTIALS_DIR/.salt" ]; then
        log_message "INFO" "Sistema de credenciales inicializado correctamente"
        return 0
    fi

    log_message "ERROR" "No se pudo inicializar el sistema de credenciales"
    return 1
}

derive_key() {
    local salt
    salt=$(cat "$CREDENTIALS_DIR/.salt")
    echo -n "$MASTER_PASSWORD" | openssl dgst -sha256 -hmac "$salt" | cut -d' ' -f2
}

sign_payload() {
    local payload="$1"
    local key
    key=$(derive_key)
    echo -n "$payload" | openssl dgst -sha256 -hmac "$key" | cut -d' ' -f2
}

encrypt_data() {
    local data="$1"
    local key
    key=$(derive_key)
    printf '%s' "$data" | openssl enc -aes-256-cbc -pbkdf2 -e -a -A -salt -pass pass:"$key" 2>/dev/null
}

decrypt_data() {
    local encrypted_data="$1"
    local key
    key=$(derive_key)
    printf '%s' "$encrypted_data" | openssl enc -aes-256-cbc -pbkdf2 -d -a -A -pass pass:"$key" 2>/dev/null
}

store_credential() {
    local service="$1"
    local username="$2"
    local password="$3"
    local payload
    local signature
    local sealed
    local encrypted_data

    if [ -z "$service" ] || [ -z "$username" ] || [ -z "$password" ]; then
        log_message "ERROR" "Parametros incompletos para store_credential"
        echo "Error: Todos los parametros son requeridos"
        return 1
    fi

    if [ ! -f "$CREDENTIALS_DIR/.salt" ]; then
        init_credentials_system >/dev/null || return 1
    fi

    payload="${username}:${password}"
    signature=$(sign_payload "$payload")
    sealed="CREDv1|${payload}|${signature}"
    encrypted_data=$(encrypt_data "$sealed")

    if [ -z "$encrypted_data" ]; then
        log_message "ERROR" "Error al cifrar datos para servicio: $service"
        echo "Error: No se pudo cifrar la credencial"
        return 1
    fi

    echo "$encrypted_data" > "$CREDENTIALS_DIR/${service}.enc"
    chmod 600 "$CREDENTIALS_DIR/${service}.enc"
    log_message "INFO" "Credencial almacenada para servicio: $service"
    echo "Credencial almacenada correctamente para $service"
    return 0
}

retrieve_credential() {
    local service="$1"
    local encrypted_data
    local decrypted_data
    local body
    local payload
    local signature
    local expected_signature

    if [ -z "$service" ]; then
        log_message "ERROR" "Parametro de servicio requerido para retrieve_credential"
        echo "Error: Se requiere el nombre del servicio"
        return 1
    fi

    if [ ! -f "$CREDENTIALS_DIR/${service}.enc" ]; then
        log_message "ERROR" "No existe credencial para servicio: $service"
        echo "Error: No existe credencial para el servicio $service"
        return 1
    fi

    encrypted_data=$(cat "$CREDENTIALS_DIR/${service}.enc")
    decrypted_data=$(decrypt_data "$encrypted_data")
    if [ $? -ne 0 ] || [ -z "$decrypted_data" ]; then
        log_message "ERROR" "Error al descifrar datos para servicio: $service"
        echo "Error: No se pudo descifrar la credencial (contrasena incorrecta)"
        return 1
    fi

    [[ "$decrypted_data" == CREDv1\|* ]] || {
        log_message "ERROR" "Formato de datos invalido para servicio: $service"
        echo "Error: No se pudo descifrar la credencial (contrasena incorrecta)"
        return 1
    }

    body=${decrypted_data#CREDv1|}
    signature=${body##*|}
    payload=${body%|$signature}
    expected_signature=$(sign_payload "$payload")

    if [ "$signature" != "$expected_signature" ] || [[ "$payload" != *:* ]]; then
        log_message "ERROR" "Firma invalida para servicio: $service"
        echo "Error: No se pudo descifrar la credencial (contrasena incorrecta)"
        return 1
    fi

    log_message "INFO" "Credencial recuperada para servicio: $service"
    echo "$payload"
    return 0
}

list_services() {
    local files=()

    if [ ! -d "$CREDENTIALS_DIR" ]; then
        echo "Error: El sistema no esta inicializado"
        return 1
    fi

    shopt -s nullglob
    files=("$CREDENTIALS_DIR"/*.enc)
    shopt -u nullglob

    if [ ${#files[@]} -eq 0 ]; then
        echo "No hay credenciales almacenadas"
        return 1
    fi

    for file in "${files[@]}"; do
        basename "$file" .enc
    done

    return 0
}

delete_credential() {
    local service="$1"

    if [ -z "$service" ]; then
        echo "Error: Se requiere el nombre del servicio"
        return 1
    fi

    if [ -f "$CREDENTIALS_DIR/${service}.enc" ]; then
        rm "$CREDENTIALS_DIR/${service}.enc"
        log_message "INFO" "Credencial eliminada para servicio: $service"
        echo "Credencial eliminada correctamente para $service"
        return 0
    fi

    echo "Error: No existe credencial para el servicio $service"
    return 1
}

verify_security() {
    local issues=0
    local dir_perms=""

    if [ -d "$CREDENTIALS_DIR" ]; then
        dir_perms=$(file_mode "$CREDENTIALS_DIR")
        if [ "$dir_perms" != "700" ]; then
            echo "ADVERTENCIA: Permisos incorrectos en directorio: $dir_perms (deberia ser 700)"
            issues=$((issues + 1))
        fi
    fi

    for file in "$CREDENTIALS_DIR"/*.enc; do
        if [ -f "$file" ]; then
            local file_perms
            file_perms=$(file_mode "$file")
            if [ "$file_perms" != "600" ]; then
                echo "ADVERTENCIA: Permisos incorrectos en archivo $(basename "$file"): $file_perms (deberia ser 600)"
                issues=$((issues + 1))
            fi
        fi
    done

    if [ $issues -eq 0 ]; then
        echo "Configuración de seguridad: OK"
        return 0
    fi

    echo "Se encontraron $issues problemas de seguridad"
    return 1
}

cleanup_test_system() {
    if [ -d "$CREDENTIALS_DIR" ]; then
        rm -rf "$CREDENTIALS_DIR"
        log_message "INFO" "Sistema de pruebas limpiado"
    fi
    if [ -f "$LOG_FILE" ]; then
        rm -f "$LOG_FILE"
    fi
}

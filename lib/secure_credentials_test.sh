#!/bin/bash

# Sistema de gestión segura de credenciales - Versión de prueba
# Modificado para funcionar sin permisos de root

# Variables de configuración para pruebas
CREDENTIALS_DIR="./test_credentials"
LOG_FILE="./test_credentials.log"
MASTER_PASSWORD="test_master_password_123"

# Función para registrar logs
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# Inicializar el sistema de credenciales
init_credentials_system() {
    # Crear directorios para pruebas
    mkdir -p "$CREDENTIALS_DIR"
    chmod 700 "$CREDENTIALS_DIR" 2>/dev/null || true
    
    # Crear archivo de log
    touch "$LOG_FILE"
    
    # Generar salt si no existe
    if [ ! -f "$CREDENTIALS_DIR/.salt" ]; then
        openssl rand -hex 16 > "$CREDENTIALS_DIR/.salt"
        chmod 600 "$CREDENTIALS_DIR/.salt"
    fi
    
    # Verificamos que el sistema esté inicializado
    if [ -f "$CREDENTIALS_DIR/.salt" ]; then
        log_message "INFO" "Sistema de credenciales inicializado correctamente"
        return 0
    else
        log_message "ERROR" "No se pudo inicializar el sistema de credenciales"
        return 1
    fi
}

# Función para cifrar datos
encrypt_data() {
    local data="$1"
    local salt=$(cat "$CREDENTIALS_DIR/.salt")
    local key=$(echo -n "$MASTER_PASSWORD" | openssl dgst -sha256 -hmac "$salt" | cut -d' ' -f2)
    
    echo "$data" | openssl enc -aes-256-cbc -e -a -k "$key" 2>/dev/null
}

# Función para descifrar datos
decrypt_data() {
    local encrypted_data="$1"
    local salt=$(cat "$CREDENTIALS_DIR/.salt")
    local key=$(echo -n "$MASTER_PASSWORD" | openssl dgst -sha256 -hmac "$salt" | cut -d' ' -f2)
    
    echo "$encrypted_data" | openssl enc -aes-256-cbc -d -a -k "$key" 2>/dev/null
}

# Almacenar credencial
store_credential() {
    local service="$1"
    local username="$2"
    local password="$3"
    
    # Verificar parámetros
    if [ -z "$service" ] || [ -z "$username" ] || [ -z "$password" ]; then
        log_message "ERROR" "Parámetros incompletos para store_credential"
        echo "Error: Todos los parámetros son requeridos"
        return 1
    fi
    
    # Cifrar y almacenar
    local credential_data="${username}:${password}"
    local encrypted_data=$(encrypt_data "$credential_data")
    
    if [ $? -eq 0 ] && [ -n "$encrypted_data" ]; then
        echo "$encrypted_data" > "$CREDENTIALS_DIR/${service}.enc"
        chmod 600 "$CREDENTIALS_DIR/${service}.enc"
        log_message "INFO" "Credencial almacenada para servicio: $service"
        echo "Credencial almacenada correctamente para $service"
        return 0
    else
        log_message "ERROR" "Error al cifrar datos para servicio: $service"
        echo "Error: No se pudo cifrar la credencial"
        return 1
    fi
}

# Recuperar credencial
retrieve_credential() {
    local service="$1"
    
    # Verificar parámetro
    if [ -z "$service" ]; then
        log_message "ERROR" "Parámetro de servicio requerido para retrieve_credential"
        echo "Error: Se requiere el nombre del servicio"
        return 1
    fi
    
    # Verificar que exista el archivo
    if [ ! -f "$CREDENTIALS_DIR/${service}.enc" ]; then
        log_message "ERROR" "No existe credencial para servicio: $service"
        echo "Error: No existe credencial para el servicio $service"
        return 1
    fi
    
    # Descifrar y retornar
        local encrypted_data=$(cat "$CREDENTIALS_DIR/${service}.enc")
        local decrypted_data=$(decrypt_data "$encrypted_data")
        
        if [ $? -eq 0 ] && [ -n "$decrypted_data" ]; then
            # Validar formato de datos descifrados (debe contener ":")
            if echo "$decrypted_data" | grep -q ":"; then
                log_message "INFO" "Credencial recuperada para servicio: $service"
                echo "$decrypted_data"
                return 0
            else
                log_message "ERROR" "Datos descifrados inválidos para servicio: $service"
                echo "Error: No se pudo descifrar la credencial (contraseña incorrecta)"
                return 1
            fi
        else
            log_message "ERROR" "Error al descifrar datos para servicio: $service"
            echo "Error: No se pudo descifrar la credencial (contraseña incorrecta)"
            return 1
        fi
}

# Listar servicios
list_services() {
    if [ ! -d "$CREDENTIALS_DIR" ]; then
        echo "Error: El sistema no está inicializado"
        return 1
    fi
    
    local services=$(ls "$CREDENTIALS_DIR"/*.enc 2>/dev/null | xargs -n 1 basename | sed 's/.enc$//')
    if [ -n "$services" ]; then
        echo "$services"
        return 0
    else
        echo "No hay credenciales almacenadas"
        return 1
    fi
}

# Eliminar credencial
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
    else
        echo "Error: No existe credencial para el servicio $service"
        return 1
    fi
}

# Verificar seguridad del sistema
verify_security() {
    local issues=0
    
    # Verificar permisos del directorio
    if [ -d "$CREDENTIALS_DIR" ]; then
        local dir_perms=$(stat -c "%a" "$CREDENTIALS_DIR" 2>/dev/null || stat -f "%A" "$CREDENTIALS_DIR" 2>/dev/null)
        if [ "$dir_perms" != "700" ]; then
            echo "ADVERTENCIA: Permisos incorrectos en directorio: $dir_perms (debería ser 700)"
            issues=$((issues + 1))
        fi
    fi
    
    # Verificar archivos cifrados
    for file in "$CREDENTIALS_DIR"/*.enc; do
        if [ -f "$file" ]; then
            local file_perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%A" "$file" 2>/dev/null)
            if [ "$file_perms" != "600" ]; then
                echo "ADVERTENCIA: Permisos incorrectos en archivo $(basename $file): $file_perms (debería ser 600)"
                issues=$((issues + 1))
            fi
        fi
    done
    
    if [ $issues -eq 0 ]; then
        echo "Configuración de seguridad: OK"
        return 0
    else
        echo "Se encontraron $issues problemas de seguridad"
        return 1
    fi
}

# Limpiar sistema de pruebas
cleanup_test_system() {
    if [ -d "$CREDENTIALS_DIR" ]; then
        rm -rf "$CREDENTIALS_DIR"
        log_message "INFO" "Sistema de pruebas limpiado"
    fi
    if [ -f "$LOG_FILE" ]; then
        rm -f "$LOG_FILE"
    fi
}
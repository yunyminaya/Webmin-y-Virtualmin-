#!/bin/bash

# Sistema de Gestión Segura de Credenciales para Webmin/Virtualmin
# Este módulo proporciona funciones para almacenar y recuperar credenciales de forma segura

# Configuración
CREDENTIALS_DIR="/etc/webmin/credentials"
CREDENTIALS_FILE="$CREDENTIALS_DIR/secure_credentials.enc"
SALT_FILE="$CREDENTIALS_DIR/salt.bin"
LOG_FILE="/var/log/webmin/credentials.log"

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función de logging
log_credentials() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Función para verificar dependencias
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

# Función para inicializar el sistema de credenciales
init_credentials_system() {
    log_credentials "INFO" "Inicializando sistema de credenciales"
    
    # Verificar dependencias
    if ! check_dependencies; then
        return 1
    fi
    
    # Crear directorio de credenciales si no existe
    if [ ! -d "$CREDENTIALS_DIR" ]; then
        mkdir -p "$CREDENTIALS_DIR"
        chmod 700 "$CREDENTIALS_DIR"
        log_credentials "INFO" "Directorio de credenciales creado: $CREDENTIALS_DIR"
    fi
    
    # Generar salt si no existe
    if [ ! -f "$SALT_FILE" ]; then
        openssl rand -hex 32 > "$SALT_FILE"
        chmod 600 "$SALT_FILE"
        log_credentials "INFO" "Salt generado para el sistema de credenciales"
    fi
    
    # Crear archivo de credenciales vacío si no existe
    if [ ! -f "$CREDENTIALS_FILE" ]; then
        touch "$CREDENTIALS_FILE"
        chmod 600 "$CREDENTIALS_FILE"
        log_credentials "INFO" "Archivo de credenciales creado: $CREDENTIALS_FILE"
    fi
    
    echo -e "${GREEN}Sistema de credenciales inicializado correctamente${NC}"
    return 0
}

# Función para derivar clave a partir de contraseña
derive_key() {
    local password=$1
    local salt=$(cat "$SALT_FILE")
    
    # Usar SHA-256 para derivar clave (más compatible)
    echo -n "$password$salt" | openssl dgst -sha256 -hex | cut -d' ' -f2
}

# Función para cifrar datos
encrypt_data() {
    local data=$1
    local key=$2
    
    echo "$data" | openssl enc -aes-256-cbc -salt -pass pass:"$key" -base64 2>/dev/null
}

# Función para descifrar datos
decrypt_data() {
    local encrypted_data=$1
    local key=$2
    
    echo "$encrypted_data" | openssl enc -aes-256-cbc -d -pass pass:"$key" -base64 2>/dev/null
}

# Función para almacenar credencial
store_credential() {
    local service=$1
    local username=$2
    local password=$3
    local master_password=$4
    
    if [ -z "$service" ] || [ -z "$username" ] || [ -z "$password" ] || [ -z "$master_password" ]; then
        echo -e "${RED}Error: Todos los parámetros son requeridos${NC}"
        return 1
    fi
    
    # Inicializar sistema si es necesario
    if [ ! -f "$SALT_FILE" ] || [ ! -f "$CREDENTIALS_FILE" ]; then
        if ! init_credentials_system; then
            return 1
        fi
    fi
    
    # Derivar clave
    local key=$(derive_key "$master_password")
    if [ -z "$key" ]; then
        echo -e "${RED}Error: No se pudo derivar la clave${NC}"
        return 1
    fi
    
    # Crear entrada de credencial
    local credential_entry="$service:$username:$password"
    local encrypted_entry=$(encrypt_data "$credential_entry" "$key")
    
    if [ -z "$encrypted_entry" ]; then
        echo -e "${RED}Error: No se pudo cifrar la credencial${NC}"
        return 1
    fi
    
    # Almacenar en archivo
    echo "$encrypted_entry" >> "$CREDENTIALS_FILE"
    
    log_credentials "INFO" "Credencial almacenada para servicio: $service"
    echo -e "${GREEN}Credencial almacenada correctamente para $service${NC}"
    return 0
}

# Función para recuperar credencial
retrieve_credential() {
    local service=$1
    local master_password=$2
    
    if [ -z "$service" ] || [ -z "$master_password" ]; then
        echo -e "${RED}Error: Todos los parámetros son requeridos${NC}"
        return 1
    fi
    
    # Verificar que exista el sistema
    if [ ! -f "$SALT_FILE" ] || [ ! -f "$CREDENTIALS_FILE" ]; then
        echo -e "${RED}Error: Sistema de credenciales no inicializado${NC}"
        return 1
    fi
    
    # Derivar clave
    local key=$(derive_key "$master_password")
    if [ -z "$key" ]; then
        echo -e "${RED}Error: No se pudo derivar la clave${NC}"
        return 1
    fi
    
    # Buscar credencial
    while IFS= read -r encrypted_entry; do
        if [ -n "$encrypted_entry" ]; then
            local decrypted_entry=$(decrypt_data "$encrypted_entry" "$key")
            if [ -n "$decrypted_entry" ]; then
                # Eliminar caracteres de control y espacios en blanco
                decrypted_entry=$(echo "$decrypted_entry" | tr -d '\r\n\t ')
                local entry_service=$(echo "$decrypted_entry" | cut -d: -f1)
                if [ "$entry_service" = "$service" ]; then
                    local entry_username=$(echo "$decrypted_entry" | cut -d: -f2)
                    local entry_password=$(echo "$decrypted_entry" | cut -d: -f3)
                    
                    echo "USERNAME:$entry_username"
                    echo "PASSWORD:$entry_password"
                    
                    log_credentials "INFO" "Credencial recuperada para servicio: $service"
                    return 0
                fi
            fi
        fi
    done < "$CREDENTIALS_FILE"
    
    echo -e "${YELLOW}No se encontró credencial para el servicio: $service${NC}"
    return 1
}

# Función para listar servicios
list_services() {
    local master_password=$1
    
    if [ -z "$master_password" ]; then
        echo -e "${RED}Error: Se requiere la contraseña maestra${NC}"
        return 1
    fi
    
    # Verificar que exista el sistema
    if [ ! -f "$SALT_FILE" ] || [ ! -f "$CREDENTIALS_FILE" ]; then
        echo -e "${RED}Error: Sistema de credenciales no inicializado${NC}"
        return 1
    fi
    
    # Derivar clave
    local key=$(derive_key "$master_password")
    if [ -z "$key" ]; then
        echo -e "${RED}Error: No se pudo derivar la clave${NC}"
        return 1
    fi
    
    echo "Servicios almacenados:"
    echo "===================="
    
    local found=false
    while IFS= read -r encrypted_entry; do
        if [ -n "$encrypted_entry" ]; then
            local decrypted_entry=$(decrypt_data "$encrypted_entry" "$key")
            if [ -n "$decrypted_entry" ]; then
                # Eliminar caracteres de control y espacios en blanco
                decrypted_entry=$(echo "$decrypted_entry" | tr -d '\r\n\t ')
                local entry_service=$(echo "$decrypted_entry" | cut -d: -f1)
                local entry_username=$(echo "$decrypted_entry" | cut -d: -f2)
                echo "- $entry_service ($entry_username)"
                found=true
            fi
        fi
    done < "$CREDENTIALS_FILE"
    
    if [ "$found" = false ]; then
        echo "No hay credenciales almacenadas"
    fi
    
    log_credentials "INFO" "Lista de servicios solicitada"
    return 0
}

# Función para eliminar credencial
delete_credential() {
    local service=$1
    local master_password=$2
    
    if [ -z "$service" ] || [ -z "$master_password" ]; then
        echo -e "${RED}Error: Todos los parámetros son requeridos${NC}"
        return 1
    fi
    
    # Verificar que exista el sistema
    if [ ! -f "$SALT_FILE" ] || [ ! -f "$CREDENTIALS_FILE" ]; then
        echo -e "${RED}Error: Sistema de credenciales no inicializado${NC}"
        return 1
    fi
    
    # Derivar clave
    local key=$(derive_key "$master_password")
    if [ -z "$key" ]; then
        echo -e "${RED}Error: No se pudo derivar la clave${NC}"
        return 1
    fi
    
    # Crear archivo temporal
    local temp_file=$(mktemp)
    local found=false
    
    # Filtrar credenciales, eliminando la que coincide
    while IFS= read -r encrypted_entry; do
        if [ -n "$encrypted_entry" ]; then
            local decrypted_entry=$(decrypt_data "$encrypted_entry" "$key")
            if [ -n "$decrypted_entry" ]; then
                # Eliminar caracteres de control y espacios en blanco
                decrypted_entry=$(echo "$decrypted_entry" | tr -d '\r\n\t ')
                local entry_service=$(echo "$decrypted_entry" | cut -d: -f1)
                if [ "$entry_service" != "$service" ]; then
                    echo "$encrypted_entry" >> "$temp_file"
                else
                    found=true
                fi
            else
                # Mantener entradas que no se pueden descifrar (podrían ser de otra contraseña)
                echo "$encrypted_entry" >> "$temp_file"
            fi
        fi
    done < "$CREDENTIALS_FILE"
    
    # Reemplazar archivo original
    mv "$temp_file" "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE"
    
    if [ "$found" = true ]; then
        log_credentials "INFO" "Credencial eliminada para servicio: $service"
        echo -e "${GREEN}Credencial eliminada correctamente para $service${NC}"
        return 0
    else
        echo -e "${YELLOW}No se encontró credencial para el servicio: $service${NC}"
        return 1
    fi
}

# Función para verificar seguridad del sistema
verify_security() {
    echo "Verificación de seguridad del sistema de credenciales:"
    echo "======================================================"
    
    local issues=0
    
    # Verificar permisos del directorio
    if [ -d "$CREDENTIALS_DIR" ]; then
        local dir_perms=$(stat -c "%a" "$CREDENTIALS_DIR" 2>/dev/null || stat -f "%A" "$CREDENTIALS_DIR" 2>/dev/null)
        if [ "$dir_perms" != "700" ]; then
            echo -e "${RED}✗ Permisos incorrectos en directorio: $dir_perms (debería ser 700)${NC}"
            issues=$((issues + 1))
        else
            echo -e "${GREEN}✓ Permisos correctos en directorio${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Directorio de credenciales no existe${NC}"
        issues=$((issues + 1))
    fi
    
    # Verificar permisos del archivo de credenciales
    if [ -f "$CREDENTIALS_FILE" ]; then
        local file_perms=$(stat -c "%a" "$CREDENTIALS_FILE" 2>/dev/null || stat -f "%A" "$CREDENTIALS_FILE" 2>/dev/null)
        if [ "$file_perms" != "600" ]; then
            echo -e "${RED}✗ Permisos incorrectos en archivo de credenciales: $file_perms (debería ser 600)${NC}"
            issues=$((issues + 1))
        else
            echo -e "${GREEN}✓ Permisos correctos en archivo de credenciales${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Archivo de credenciales no existe${NC}"
        issues=$((issues + 1))
    fi
    
    # Verificar permisos del archivo salt
    if [ -f "$SALT_FILE" ]; then
        local salt_perms=$(stat -c "%a" "$SALT_FILE" 2>/dev/null || stat -f "%A" "$SALT_FILE" 2>/dev/null)
        if [ "$salt_perms" != "600" ]; then
            echo -e "${RED}✗ Permisos incorrectos en archivo salt: $salt_perms (debería ser 600)${NC}"
            issues=$((issues + 1))
        else
            echo -e "${GREEN}✓ Permisos correctos en archivo salt${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Archivo salt no existe${NC}"
        issues=$((issues + 1))
    fi
    
    # Verificar dependencias
    if check_dependencies; then
        echo -e "${GREEN}✓ Dependencias verificadas${NC}"
    else
        echo -e "${RED}✗ Faltan dependencias${NC}"
        issues=$((issues + 1))
    fi
    
    if [ $issues -eq 0 ]; then
        echo -e "${GREEN}Sistema de credenciales seguro${NC}"
        return 0
    else
        echo -e "${RED}Se encontraron $issues problemas de seguridad${NC}"
        return 1
    fi
}

# Función para mostrar ayuda
show_help() {
    echo "Sistema de Gestión Segura de Credenciales"
    echo "Uso:"
    echo "  source lib/secure_credentials.sh"
    echo ""
    echo "Funciones disponibles:"
    echo "  init_credentials_system                    - Inicializa el sistema de credenciales"
    echo "  store_credential <service> <user> <pass> <master> - Almacena una credencial"
    echo "  retrieve_credential <service> <master>     - Recupera una credencial"
    echo "  list_services <master>                     - Lista todos los servicios"
    echo "  delete_credential <service> <master>       - Elimina una credencial"
    echo "  verify_security                            - Verifica la seguridad del sistema"
    echo "  show_help                                  - Muestra esta ayuda"
}

# Exportar funciones si se solicita
if [ "$1" = "--export" ]; then
    export -f init_credentials_system
    export -f store_credential
    export -f retrieve_credential
    export -f list_services
    export -f delete_credential
    export -f verify_security
    export -f show_help
fi
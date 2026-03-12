#!/bin/bash

# Pruebas unitarias para el sistema de gestión segura de credenciales
# Este archivo prueba las funcionalidades del módulo lib/secure_credentials.sh

# Importar el módulo de credenciales
source "$(dirname "$0")/../../lib/secure_credentials.sh"

# Configuración de pruebas
TEST_DIR="/tmp/test_credentials_$$"
TEST_CREDENTIALS_DIR="$TEST_DIR/credentials"
TEST_LOG_FILE="$TEST_DIR/test.log"

# Variables globales para pruebas
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para configurar entorno de prueba
setup_test_environment() {
    echo -e "${BLUE}Configurando entorno de prueba...${NC}"
    
    # Crear directorio de prueba
    mkdir -p "$TEST_DIR"
    mkdir -p "$TEST_CREDENTIALS_DIR"
    chmod 700 "$TEST_CREDENTIALS_DIR"
    
    # Sobrescribir variables del módulo para usar directorios de prueba
    CREDENTIALS_DIR="$TEST_CREDENTIALS_DIR"
    CREDENTIALS_FILE="$TEST_CREDENTIALS_DIR/secure_credentials.enc"
    SALT_FILE="$TEST_CREDENTIALS_DIR/salt.bin"
    LOG_FILE="$TEST_LOG_FILE"
    
    # Limpiar archivos anteriores si existen
    rm -f "$CREDENTIALS_FILE" "$SALT_FILE" "$LOG_FILE"
    
    echo -e "${GREEN}Entorno de prueba configurado${NC}"
}

# Función para limpiar entorno de prueba
cleanup_test_environment() {
    echo -e "${BLUE}Limpiando entorno de prueba...${NC}"
    rm -rf "$TEST_DIR"
    echo -e "${GREEN}Entorno de prueba limpiado${NC}"
}

# Función para ejecutar una prueba
run_test() {
    local test_name=$1
    local test_function=$2
    
    echo -e "${BLUE}Ejecutando prueba: $test_name${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if $test_function; then
        echo -e "${GREEN}✓ $test_name - PASÓ${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ $test_name - FALLÓ${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Prueba 1: Inicialización del sistema
test_initialization() {
    # Verificar que el sistema no esté inicializado
    if [ -f "$SALT_FILE" ] || [ -f "$CREDENTIALS_FILE" ]; then
        echo "Error: El sistema ya está inicializado"
        return 1
    fi
    
    # Inicializar el sistema
    if ! init_credentials_system; then
        echo "Error: No se pudo inicializar el sistema"
        return 1
    fi
    
    # Verificar que los archivos fueron creados
    if [ ! -f "$SALT_FILE" ]; then
        echo "Error: No se creó el archivo salt"
        return 1
    fi
    
    if [ ! -f "$CREDENTIALS_FILE" ]; then
        echo "Error: No se creó el archivo de credenciales"
        return 1
    fi
    
    # Verificar permisos
    local dir_perms=$(stat -c "%a" "$CREDENTIALS_DIR" 2>/dev/null || stat -f "%A" "$CREDENTIALS_DIR" 2>/dev/null)
    if [ "$dir_perms" != "700" ]; then
        echo "Error: Permisos incorrectos en directorio: $dir_perms"
        return 1
    fi
    
    local salt_perms=$(stat -c "%a" "$SALT_FILE" 2>/dev/null || stat -f "%A" "$SALT_FILE" 2>/dev/null)
    if [ "$salt_perms" != "600" ]; then
        echo "Error: Permisos incorrectos en archivo salt: $salt_perms"
        return 1
    fi
    
    local file_perms=$(stat -c "%a" "$CREDENTIALS_FILE" 2>/dev/null || stat -f "%A" "$CREDENTIALS_FILE" 2>/dev/null)
    if [ "$file_perms" != "600" ]; then
        echo "Error: Permisos incorrectos en archivo de credenciales: $file_perms"
        return 1
    fi
    
    return 0
}

# Prueba 2: Almacenamiento y recuperación de credenciales
test_store_and_retrieve() {
    local test_service="test_service"
    local test_username="test_user"
    local test_password="test_password"
    local master_password="master_password"
    
    # Almacenar credencial
    if ! store_credential "$test_service" "$test_username" "$test_password" "$master_password"; then
        echo "Error: No se pudo almacenar la credencial"
        return 1
    fi
    
    # Recuperar credencial
    local result=$(retrieve_credential "$test_service" "$master_password")
    if [ $? -ne 0 ]; then
        echo "Error: No se pudo recuperar la credencial"
        return 1
    fi
    
    # Verificar contenido
    local retrieved_username=$(echo "$result" | grep "USERNAME:" | cut -d: -f2)
    local retrieved_password=$(echo "$result" | grep "PASSWORD:" | cut -d: -f2)
    
    if [ "$retrieved_username" != "$test_username" ]; then
        echo "Error: Username incorrecto. Esperado: $test_username, Obtenido: $retrieved_username"
        return 1
    fi
    
    if [ "$retrieved_password" != "$test_password" ]; then
        echo "Error: Password incorrecto. Esperado: $test_password, Obtenido: $retrieved_password"
        return 1
    fi
    
    return 0
}

# Prueba 3: Recuperación con contraseña maestra incorrecta
test_retrieve_wrong_password() {
    local test_service="test_service2"
    local test_username="test_user2"
    local test_password="test_password2"
    local master_password="master_password"
    local wrong_password="wrong_password"
    
    # Almacenar credencial
    if ! store_credential "$test_service" "$test_username" "$test_password" "$master_password"; then
        echo "Error: No se pudo almacenar la credencial"
        return 1
    fi
    
    # Intentar recuperar con contraseña incorrecta
    local result=$(retrieve_credential "$test_service" "$wrong_password" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "Error: Se recuperó credencial con contraseña incorrecta"
        return 1
    fi
    
    return 0
}

# Prueba 4: Listado de servicios
test_list_services() {
    local master_password="master_password"
    
    # Agregar algunas credenciales
    store_credential "service1" "user1" "pass1" "$master_password"
    store_credential "service2" "user2" "pass2" "$master_password"
    store_credential "service3" "user3" "pass3" "$master_password"
    
    # Listar servicios
    local result=$(list_services "$master_password")
    if [ $? -ne 0 ]; then
        echo "Error: No se pudo listar los servicios"
        return 1
    fi
    
    # Verificar que los servicios estén en la lista
    if ! echo "$result" | grep -q "service1"; then
        echo "Error: service1 no encontrado en la lista"
        return 1
    fi
    
    if ! echo "$result" | grep -q "service2"; then
        echo "Error: service2 no encontrado en la lista"
        return 1
    fi
    
    if ! echo "$result" | grep -q "service3"; then
        echo "Error: service3 no encontrado en la lista"
        return 1
    fi
    
    return 0
}

# Prueba 5: Eliminación de credenciales
test_delete_credential() {
    local master_password="master_password"
    
    # Agregar una credencial
    store_credential "delete_service" "delete_user" "delete_pass" "$master_password"
    
    # Verificar que existe
    local result=$(retrieve_credential "delete_service" "$master_password")
    if [ $? -ne 0 ]; then
        echo "Error: No se pudo recuperar la credencial antes de eliminar"
        return 1
    fi
    
    # Eliminar la credencial
    if ! delete_credential "delete_service" "$master_password"; then
        echo "Error: No se pudo eliminar la credencial"
        return 1
    fi
    
    # Verificar que ya no existe
    result=$(retrieve_credential "delete_service" "$master_password" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "Error: La credencial aún existe después de eliminar"
        return 1
    fi
    
    return 0
}

# Prueba 6: Verificación de seguridad
test_security_verification() {
    # Verificar seguridad del sistema
    local result=$(verify_security)
    if [ $? -ne 0 ]; then
        echo "Error: La verificación de seguridad falló"
        return 1
    fi
    
    # Verificar que no hay problemas de seguridad
    if echo "$result" | grep -q "✗"; then
        echo "Error: Se encontraron problemas de seguridad"
        return 1
    fi
    
    return 0
}

# Prueba 7: Cifrado y descifrado
test_encryption_decryption() {
    local test_data="test_data_for_encryption"
    local test_password="encryption_password"
    
    # Generar salt para la prueba
    openssl rand -hex 32 > "$SALT_FILE"
    
    # Derivar clave
    local key=$(derive_key "$test_password")
    if [ -z "$key" ]; then
        echo "Error: No se pudo derivar la clave"
        return 1
    fi
    
    # Cifrar datos
    local encrypted=$(encrypt_data "$test_data" "$key")
    if [ -z "$encrypted" ]; then
        echo "Error: No se pudieron cifrar los datos"
        return 1
    fi
    
    # Descifrar datos
    local decrypted=$(decrypt_data "$encrypted" "$key")
    if [ "$decrypted" != "$test_data" ]; then
        echo "Error: Los datos descifrados no coinciden. Esperado: $test_data, Obtenido: $decrypted"
        return 1
    fi
    
    return 0
}

# Función principal de pruebas
main() {
    echo -e "${BLUE}Iniciando pruebas unitarias del sistema de gestión segura de credenciales${NC}"
    echo "=================================================================="
    
    # Configurar entorno
    setup_test_environment
    
    # Ejecutar pruebas
    run_test "Inicialización del sistema" test_initialization
    run_test "Almacenamiento y recuperación de credenciales" test_store_and_retrieve
    run_test "Recuperación con contraseña incorrecta" test_retrieve_wrong_password
    run_test "Listado de servicios" test_list_services
    run_test "Eliminación de credenciales" test_delete_credential
    run_test "Verificación de seguridad" test_security_verification
    run_test "Cifrado y descifrado" test_encryption_decryption
    
    # Mostrar resultados
    echo "=================================================================="
    echo -e "${BLUE}Resultados de las pruebas:${NC}"
    echo -e "Total de pruebas: $TOTAL_TESTS"
    echo -e "${GREEN}Pruebas pasadas: $TESTS_PASSED${NC}"
    echo -e "${RED}Pruebas fallidas: $TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}¡Todas las pruebas pasaron!${NC}"
        local exit_code=0
    else
        echo -e "${RED}Algunas pruebas fallaron${NC}"
        local exit_code=1
    fi
    
    # Limpiar entorno
    cleanup_test_environment
    
    exit $exit_code
}

# Ejutar pruebas si se llama directamente al script
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
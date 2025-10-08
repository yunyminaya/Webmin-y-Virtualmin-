#!/bin/bash

# Pruebas unitarias para el sistema de gestión segura de credenciales - Versión corregida

# Importar el sistema de credenciales de prueba
source ../lib/secure_credentials_test.sh

# Contador de pruebas
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Función para ejecutar una prueba
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo "Ejecutando prueba: $test_name"
    
    if $test_function; then
        echo "✓ $test_name - PASÓ"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo "✗ $test_name - FALLÓ"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo ""
}

# Función para configurar entorno de prueba
setup_test_env() {
    echo "Configurando entorno de prueba..."
    # Limpiar cualquier prueba anterior
    cleanup_test_system >/dev/null 2>&1
    # Inicializar sistema
    init_credentials_system >/dev/null 2>&1
    echo "Entorno de prueba configurado"
}

# Función para limpiar entorno de prueba
cleanup_test_env() {
    echo "Limpiando entorno de prueba..."
    cleanup_test_system >/dev/null 2>&1
    echo "Entorno de prueba limpiado"
}

# Test 1: Inicialización del sistema
test_initialization() {
    setup_test_env
    
    if [ -f "$CREDENTIALS_DIR/.salt" ] && [ -f "$LOG_FILE" ]; then
        return 0
    else
        return 1
    fi
}

# Test 2: Almacenamiento y recuperación de credenciales
test_storage_retrieval() {
    setup_test_env
    
    # Almacenar credencial
    local result=$(store_credential "test_service" "test_user" "test_password")
    if [ $? -ne 0 ]; then
        echo "Error al almacenar credencial: $result"
        return 1
    fi
    
    # Recuperar credencial
    local retrieved=$(retrieve_credential "test_service")
    if [ $? -ne 0 ]; then
        echo "Error al recuperar credencial: $retrieved"
        return 1
    fi
    
    # Parsear resultado
    local username=$(echo "$retrieved" | awk -F: '{print $1}')
    local password=$(echo "$retrieved" | awk -F: '{print $2}')
    
    # Verificar
    if [ "$username" = "test_user" ] && [ "$password" = "test_password" ]; then
        return 0
    else
        echo "Username incorrecto. Esperado: test_user, Obtenido: $username"
        return 1
    fi
}

# Test 3: Recuperación con contraseña incorrecta
test_wrong_password() {
    setup_test_env
    
    # Almacenar credencial
    store_credential "test_service2" "test_user2" "test_password2" >/dev/null
    
    # Cambiar contraseña temporalmente
    local original_password="$MASTER_PASSWORD"
    MASTER_PASSWORD="wrong_password"
    
    # Intentar recuperar
    local result=$(retrieve_credential "test_service2")
    local exit_code=$?
    
    # Restaurar contraseña
    MASTER_PASSWORD="$original_password"
    
    # Verificar que falle
    if [ $exit_code -ne 0 ]; then
        return 0
    else
        echo "Error: Se recuperó credencial con contraseña incorrecta"
        return 1
    fi
}

# Test 4: Listado de servicios
test_list_services() {
    setup_test_env
    
    # Almacenar varias credenciales
    store_credential "service1" "user1" "pass1" >/dev/null
    store_credential "service2" "user2" "pass2" >/dev/null
    store_credential "service3" "user3" "pass3" >/dev/null
    
    # Listar servicios
    local services=$(list_services)
    local service_count=$(echo "$services" | wc -l)
    
    if [ "$service_count" -eq 3 ]; then
        return 0
    else
        echo "Se esperaban 3 servicios, se encontraron $service_count"
        return 1
    fi
}

# Test 5: Eliminación de credenciales
test_delete_credential() {
    setup_test_env
    
    # Almacenar credencial
    store_credential "delete_service" "delete_user" "delete_pass" >/dev/null
    
    # Verificar que existe
    if [ ! -f "$CREDENTIALS_DIR/delete_service.enc" ]; then
        echo "Error: La credencial no se almacenó correctamente"
        return 1
    fi
    
    # Eliminar credencial
    local result=$(delete_credential "delete_service")
    if [ $? -ne 0 ]; then
        echo "Error al eliminar credencial: $result"
        return 1
    fi
    
    # Verificar que ya no existe
    if [ ! -f "$CREDENTIALS_DIR/delete_service.enc" ]; then
        return 0
    else
        echo "Error: La credencial no se eliminó correctamente"
        return 1
    fi
}

# Test 6: Verificación de seguridad
test_security_verification() {
    setup_test_env
    
    # Almacenar una credencial para tener archivos que verificar
    store_credential "security_test" "sec_user" "sec_pass" >/dev/null
    
    # Verificar seguridad
    local result=$(verify_security)
    
    if echo "$result" | grep -q "Configuración de seguridad: OK"; then
        return 0
    else
        echo "Error en verificación de seguridad: $result"
        return 1
    fi
}

# Test 7: Cifrado y descifrado
test_encryption_decryption() {
    setup_test_env
    
    local test_data="user_test:password_test"
    
    # Cifrar datos
    local encrypted=$(encrypt_data "$test_data")
    if [ $? -ne 0 ] || [ -z "$encrypted" ]; then
        echo "Error al cifrar datos"
        return 1
    fi
    
    # Descifrar datos
    local decrypted=$(decrypt_data "$encrypted")
    if [ $? -ne 0 ] || [ -z "$decrypted" ]; then
        echo "Error al descifrar datos"
        return 1
    fi
    
    # Verificar que los datos coincidan
    if [ "$decrypted" = "$test_data" ]; then
        return 0
    else
        echo "Datos descifrados no coinciden. Original: $test_data, Descifrado: $decrypted"
        return 1
    fi
}

# Ejecutar todas las pruebas
echo "Iniciando pruebas unitarias del sistema de gestión segura de credenciales"
echo "=================================================================="

setup_test_env
echo ""

run_test "Inicialización del sistema" test_initialization
run_test "Almacenamiento y recuperación de credenciales" test_storage_retrieval
run_test "Recuperación con contraseña incorrecta" test_wrong_password
run_test "Listado de servicios" test_list_services
run_test "Eliminación de credenciales" test_delete_credential
run_test "Verificación de seguridad" test_security_verification
run_test "Cifrado y descifrado" test_encryption_decryption

cleanup_test_env

echo "=================================================================="
echo "Resultados de las pruebas:"
echo "Total de pruebas: $TOTAL_TESTS"
echo "Pruebas pasadas: $PASSED_TESTS"
echo "Pruebas fallidas: $FAILED_TESTS"

if [ $FAILED_TESTS -eq 0 ]; then
    echo "Todas las pruebas pasaron"
    exit 0
else
    echo "Algunas pruebas fallaron"
    exit 1
fi
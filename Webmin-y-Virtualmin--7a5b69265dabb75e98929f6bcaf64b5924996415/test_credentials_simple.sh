#!/bin/bash

# Prueba simple del sistema de gestión segura de credenciales

# Importar el sistema de credenciales de prueba
source ./lib/secure_credentials_test.sh

echo "=== INICIO DE PRUEBA SIMPLE DE CREDENCIALES ==="

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

# Test 1: Inicialización del sistema
test_initialization() {
    cleanup_test_system >/dev/null 2>&1
    init_credentials_system >/dev/null 2>&1
    
    if [ -f "$CREDENTIALS_DIR/.salt" ] && [ -f "$LOG_FILE" ]; then
        echo "   Sistema inicializado correctamente"
        return 0
    else
        echo "   Error: No se pudo inicializar el sistema"
        return 1
    fi
}

# Test 2: Almacenamiento y recuperación de credenciales
test_storage_retrieval() {
    cleanup_test_system >/dev/null 2>&1
    init_credentials_system >/dev/null 2>&1
    
    # Almacenar credencial
    local result=$(store_credential "test_service" "test_user" "test_password")
    if [ $? -ne 0 ]; then
        echo "   Error al almacenar credencial: $result"
        return 1
    fi
    
    # Recuperar credencial
    local retrieved=$(retrieve_credential "test_service")
    if [ $? -ne 0 ]; then
        echo "   Error al recuperar credencial: $retrieved"
        return 1
    fi
    
    # Parsear resultado
    local username=$(echo "$retrieved" | awk -F: '{print $1}')
    local password=$(echo "$retrieved" | awk -F: '{print $2}')
    
    # Verificar
    if [ "$username" = "test_user" ] && [ "$password" = "test_password" ]; then
        echo "   Credencial almacenada y recuperada correctamente"
        return 0
    else
        echo "   Username incorrecto. Esperado: test_user, Obtenido: $username"
        return 1
    fi
}

# Test 3: Recuperación con contraseña incorrecta
test_wrong_password() {
    cleanup_test_system >/dev/null 2>&1
    init_credentials_system >/dev/null 2>&1
    
    # Almacenar credencial
    store_credential "test_service2" "test_user2" "test_password2" >/dev/null
    
    # Cambiar contraseña temporalmente
    local original_password="$MASTER_PASSWORD"
    MASTER_PASSWORD="wrong_password"
    
    # Intentar recuperar
    retrieve_credential "test_service2" >/dev/null
    local exit_code=$?
    
    # Restaurar contraseña
    MASTER_PASSWORD="$original_password"
    
    # Verificar que falle
    if [ $exit_code -ne 0 ]; then
        echo "   Correctamente rechazada contraseña incorrecta"
        return 0
    else
        echo "   Error: Se recuperó credencial con contraseña incorrecta"
        return 1
    fi
}

# Test 4: Listado de servicios
test_list_services() {
    cleanup_test_system >/dev/null 2>&1
    init_credentials_system >/dev/null 2>&1
    
    # Almacenar varias credenciales
    store_credential "service1" "user1" "pass1" >/dev/null
    store_credential "service2" "user2" "pass2" >/dev/null
    store_credential "service3" "user3" "pass3" >/dev/null
    
    # Listar servicios
    local services=$(list_services)
    local service_count=$(echo "$services" | wc -l)
    
    if [ "$service_count" -eq 3 ]; then
        echo "   Listado de servicios funciona correctamente"
        return 0
    else
        echo "   Se esperaban 3 servicios, se encontraron $service_count"
        return 1
    fi
}

# Test 5: Eliminación de credenciales
test_delete_credential() {
    cleanup_test_system >/dev/null 2>&1
    init_credentials_system >/dev/null 2>&1
    
    # Almacenar credencial
    store_credential "delete_service" "delete_user" "delete_pass" >/dev/null
    
    # Verificar que existe
    if [ ! -f "$CREDENTIALS_DIR/delete_service.enc" ]; then
        echo "   Error: La credencial no se almacenó correctamente"
        return 1
    fi
    
    # Eliminar credencial
    local result=$(delete_credential "delete_service")
    if [ $? -ne 0 ]; then
        echo "   Error al eliminar credencial: $result"
        return 1
    fi
    
    # Verificar que ya no existe
    if [ ! -f "$CREDENTIALS_DIR/delete_service.enc" ]; then
        echo "   Credencial eliminada correctamente"
        return 0
    else
        echo "   Error: La credencial no se eliminó correctamente"
        return 1
    fi
}

# Test 6: Verificación de seguridad
test_security_verification() {
    cleanup_test_system >/dev/null 2>&1
    init_credentials_system >/dev/null 2>&1
    
    # Almacenar una credencial para tener archivos que verificar
    store_credential "security_test" "sec_user" "sec_pass" >/dev/null
    
    # Verificar seguridad
    local result=$(verify_security)
    
    if echo "$result" | grep -q "Configuración de seguridad: OK"; then
        echo "   Verificación de seguridad correcta"
        return 0
    else
        echo "   Error en verificación de seguridad: $result"
        return 1
    fi
}

# Test 7: Cifrado y descifrado
test_encryption_decryption() {
    cleanup_test_system >/dev/null 2>&1
    init_credentials_system >/dev/null 2>&1
    
    local test_data="user_test:password_test"
    
    # Cifrar datos
    local encrypted=$(encrypt_data "$test_data")
    if [ $? -ne 0 ] || [ -z "$encrypted" ]; then
        echo "   Error al cifrar datos"
        return 1
    fi
    
    # Descifrar datos
    local decrypted=$(decrypt_data "$encrypted")
    if [ $? -ne 0 ] || [ -z "$decrypted" ]; then
        echo "   Error al descifrar datos"
        return 1
    fi
    
    # Verificar que los datos coincidan
    if [ "$decrypted" = "$test_data" ]; then
        echo "   Cifrado y descifrado funcionan correctamente"
        return 0
    else
        echo "   Datos descifrados no coinciden. Original: $test_data, Descifrado: $decrypted"
        return 1
    fi
}

# Ejecutar todas las pruebas
echo "Iniciando pruebas unitarias del sistema de gestión segura de credenciales"
echo "=================================================================="

run_test "Inicialización del sistema" test_initialization
run_test "Almacenamiento y recuperación de credenciales" test_storage_retrieval
run_test "Recuperación con contraseña incorrecta" test_wrong_password
run_test "Listado de servicios" test_list_services
run_test "Eliminación de credenciales" test_delete_credential
run_test "Verificación de seguridad" test_security_verification
run_test "Cifrado y descifrado" test_encryption_decryption

cleanup_test_system >/dev/null 2>&1

echo "=================================================================="
echo "Resultados de las pruebas:"
echo "Total de pruebas: $TOTAL_TESTS"
echo "Pruebas pasadas: $PASSED_TESTS"
echo "Pruebas fallidas: $FAILED_TESTS"

if [ $FAILED_TESTS -eq 0 ]; then
    echo "✓ Todas las pruebas pasaron"
    exit 0
else
    echo "✗ Algunas pruebas fallaron"
    exit 1
fi
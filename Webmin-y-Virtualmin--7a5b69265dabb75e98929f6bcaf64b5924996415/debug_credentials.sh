#!/bin/bash

# Script de depuración para el sistema de credenciales

# Importar el módulo
source lib/secure_credentials.sh

# Configurar entorno de prueba
TEST_DIR="/tmp/debug_credentials_$$"
TEST_CREDENTIALS_DIR="$TEST_DIR/credentials"
TEST_CREDENTIALS_FILE="$TEST_CREDENTIALS_DIR/secure_credentials.enc"
TEST_SALT_FILE="$TEST_CREDENTIALS_DIR/salt.bin"

# Sobrescribir variables
CREDENTIALS_DIR="$TEST_CREDENTIALS_DIR"
CREDENTIALS_FILE="$TEST_CREDENTIALS_FILE"
SALT_FILE="$TEST_SALT_FILE"

# Crear entorno
mkdir -p "$TEST_CREDENTIALS_DIR"
chmod 700 "$TEST_CREDENTIALS_DIR"

echo "=== Depuración del sistema de credenciales ==="
echo "Directorio: $CREDENTIALS_DIR"
echo "Archivo: $CREDENTIALS_FILE"
echo "Salt: $SALT_FILE"

# Inicializar sistema
echo "1. Inicializando sistema..."
init_credentials_system

# Verificar salt
echo "2. Salt generado:"
cat "$SALT_FILE"
echo ""

# Probar derivación de clave
echo "3. Probando derivación de clave..."
test_password="test_password"
derived_key=$(derive_key "$test_password")
echo "Contraseña: $test_password"
echo "Clave derivada: $derived_key"
echo "Longitud de clave: ${#derived_key}"
echo ""

# Probar cifrado/descifrado
echo "4. Probando cifrado/descifrado..."
test_data="test_service:test_user:test_password"
echo "Datos originales: $test_data"

encrypted=$(encrypt_data "$test_data" "$derived_key")
echo "Datos cifrados: $encrypted"

decrypted=$(decrypt_data "$encrypted" "$derived_key")
echo "Datos descifrados: $decrypted"

if [ "$test_data" = "$decrypted" ]; then
    echo "✓ Cifrado/descifrado funciona correctamente"
else
    echo "✗ Error en cifrado/descifrado"
fi

# Probar almacenamiento y recuperación
echo ""
echo "5. Probando almacenamiento y recuperación..."
master_password="master_password"
service="debug_service"
username="debug_user"
password="debug_pass"

echo "Almacenando credencial..."
store_credential "$service" "$username" "$password" "$master_password"

echo "Recuperando credencial..."
result=$(retrieve_credential "$service" "$master_password")
echo "Resultado: $result"

# Probar con contraseña incorrecta
echo ""
echo "6. Probando con contraseña incorrecta..."
wrong_password="wrong_password"
result_wrong=$(retrieve_credential "$service" "$wrong_password" 2>/dev/null)
echo "Resultado con contraseña incorrecta: $result_wrong"

if [ -n "$result_wrong" ]; then
    echo "✗ ERROR: Se recuperó credencial con contraseña incorrecta"
else
    echo "✓ Correcto: No se recuperó credencial con contraseña incorrecta"
fi

# Limpiar
rm -rf "$TEST_DIR"
echo ""
echo "=== Fin de la depuración ==="
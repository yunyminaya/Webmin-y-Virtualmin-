#!/bin/bash

# Script de depuración simple para el sistema de gestión de credenciales

source ./lib/secure_credentials.sh

echo "=== INICIO DE DEPURACIÓN SIMPLE ==="

# Probar solo las funciones básicas
echo "1. Inicializando sistema..."
init_credentials_system

echo "2. Almacenando credencial de prueba..."
store_credential "test_service" "test_user" "test_pass"

echo "3. Recuperando credencial..."
result=$(retrieve_credential "test_service")
echo "   Resultado: '$result'"

echo "4. Analizando resultado con awk..."
username=$(echo "$result" | awk -F: '{print $1}')
password=$(echo "$result" | awk -F: '{print $2}')
echo "   Username: '$username'"
echo "   Password: '$password'"

echo "5. Verificando archivo cifrado..."
if [ -f "$CREDENTIALS_DIR/test_service.enc" ]; then
    echo "   Archivo cifrado existe"
    file_size=$(stat -f%z "$CREDENTIALS_DIR/test_service.enc" 2>/dev/null || stat -c%s "$CREDENTIALS_DIR/test_service.enc" 2>/dev/null || echo "desconocido")
    echo "   Tamaño: $file_size bytes"
else
    echo "   Archivo cifrado NO existe"
fi

echo "6. Limpiando..."
delete_credential "test_service" >/dev/null 2>&1

echo "=== FIN DE DEPURACIÓN SIMPLE ==="
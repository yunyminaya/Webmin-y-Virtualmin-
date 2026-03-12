#!/bin/bash

# Depuración específica para el problema de contraseña incorrecta

source ./lib/secure_credentials_test.sh

echo "=== DEPURACIÓN DE PRUEBA DE CONTRASEÑA INCORRECTA ==="

# Limpiar y configurar
cleanup_test_system >/dev/null 2>&1
init_credentials_system >/dev/null 2>&1

# Almacenar credencial con contraseña correcta
echo "1. Almacenando credencial con contraseña correcta..."
store_credential "test_service2" "test_user2" "test_password2" >/dev/null

# Verificar que se almacene correctamente
echo "2. Verificando almacenamiento..."
if [ -f "$CREDENTIALS_DIR/test_service2.enc" ]; then
    echo "   ✓ Credencial almacenada correctamente"
else
    echo "   ✗ Error: No se almacenó la credencial"
    exit 1
fi

# Recuperar con contraseña correcta para verificar que funciona
echo "3. Verificando recuperación con contraseña correcta..."
correct_result=$(retrieve_credential "test_service2")
if [ $? -eq 0 ]; then
    echo "   ✓ Recuperación con contraseña correcta funciona"
    username=$(echo "$correct_result" | awk -F: '{print $1}')
    echo "   Username recuperado: '$username'"
else
    echo "   ✗ Error: No se puede recuperar con contraseña correcta"
fi

# Cambiar contraseña temporalmente
echo "4. Cambiando contraseña temporalmente..."
original_password="$MASTER_PASSWORD"
echo "   Contraseña original: '$original_password'"
MASTER_PASSWORD="wrong_password"
echo "   Contraseña cambiada a: '$MASTER_PASSWORD'"

# Verificar el salt
echo "5. Verificando salt..."
if [ -f "$CREDENTIALS_DIR/.salt" ]; then
    salt=$(cat "$CREDENTIALS_DIR/.salt")
    echo "   Salt: '$salt'"
else
    echo "   ✗ Error: No existe el archivo salt"
fi

# Intentar recuperar con contraseña incorrecta
echo "6. Intentando recuperar con contraseña incorrecta..."
result=$(retrieve_credential "test_service2")
exit_code=$?
echo "   Exit code: $exit_code"
echo "   Resultado: '$result'"

# Analizar el resultado
if [ $exit_code -eq 0 ]; then
    echo "   ✗ PROBLEMA: Se recuperó credencial con contraseña incorrecta"
    if [ -n "$result" ]; then
        username=$(echo "$result" | awk -F: '{print $1}')
        password=$(echo "$result" | awk -F: '{print $2}')
        echo "   Username recuperado: '$username'"
        echo "   Password recuperado: '$password'"
        
        # Verificar si son los datos correctos
        if [ "$username" = "test_user2" ] && [ "$password" = "test_password2" ]; then
            echo "   ✗ GRAVE: Se recuperaron los datos correctos con contraseña incorrecta"
        else
            echo "   ⚠ Datos recuperados no coinciden con los originales"
        fi
    fi
else
    echo "   ✓ Correctamente rechazada contraseña incorrecta"
fi

# Restaurar contraseña
echo "7. Restaurando contraseña original..."
MASTER_PASSWORD="$original_password"

# Verificar que funcione con contraseña original
echo "8. Verificando recuperación con contraseña restaurada..."
final_result=$(retrieve_credential "test_service2")
if [ $? -eq 0 ]; then
    echo "   ✓ Recuperación con contraseña restaurada funciona"
else
    echo "   ✗ Error: No se puede recuperar con contraseña restaurada"
fi

# Limpiar
cleanup_test_system >/dev/null 2>&1

echo ""
echo "=== FIN DE DEPURACIÓN ==="
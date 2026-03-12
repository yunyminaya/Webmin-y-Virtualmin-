#!/bin/bash

# Script para ejecutar pruebas unitarias

echo "🧪 Ejecutando pruebas unitarias para Webmin/Virtualmin DevOps"
echo "==========================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/../tests"
UNIT_TESTS_DIR="$TEST_DIR/unit"

# Verificar que existe el directorio de pruebas
if [ ! -d "$UNIT_TESTS_DIR" ]; then
    echo "❌ Error: Directorio de pruebas unitarias no encontrado: $UNIT_TESTS_DIR"
    exit 1
fi

# Cambiar al directorio de pruebas
cd "$TEST_DIR"

# Contadores
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Función para ejecutar una prueba
run_test() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .sh)

    echo ""
    echo "▶️  Ejecutando $test_name..."

    if [ -x "$test_file" ]; then
        # Ejecutar la prueba y capturar salida
        output=$("$test_file" 2>&1)
        exit_code=$?

        # Mostrar salida de la prueba
        echo "$output"

        if [ $exit_code -eq 0 ]; then
            echo "✅ $test_name PASSED"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo "❌ $test_name FAILED"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        echo "❌ $test_name no es ejecutable"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# Encontrar y ejecutar todas las pruebas unitarias
echo "🔍 Buscando pruebas unitarias..."
UNIT_TEST_FILES=()
while IFS= read -r -d '' test_file; do
    UNIT_TEST_FILES+=("$test_file")
done < <(find "$UNIT_TESTS_DIR" -name "test_*.sh" -type f -print0)

if [ ${#UNIT_TEST_FILES[@]} -eq 0 ]; then
    echo "⚠️  No se encontraron pruebas unitarias"
    exit 1
fi

for test_file in "${UNIT_TEST_FILES[@]}"; do
    run_test "$test_file"
done

# Mostrar resumen final
echo ""
echo "📊 Resumen de pruebas unitarias:"
echo "   Total ejecutadas: $TOTAL_TESTS"
echo "   ✅ Pasadas: $PASSED_TESTS"
echo "   ❌ Fallidas: $FAILED_TESTS"

if [ $FAILED_TESTS -eq 0 ]; then
    echo "🎉 Todas las pruebas unitarias pasaron exitosamente"
    exit 0
else
    echo "⚠️  $FAILED_TESTS pruebas unitarias fallaron"
    exit 1
fi
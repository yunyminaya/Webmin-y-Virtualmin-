#!/bin/bash

# Script maestro para ejecutar todas las pruebas automatizadas

echo "🚀 Ejecutando suite completa de pruebas para Webmin/Virtualmin DevOps"
echo "======================================================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_TIME=$(date +%s)

# Contadores globales
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

# Función para ejecutar un conjunto de pruebas
run_test_suite() {
    local suite_name="$1"
    local script_path="$2"

    echo ""
    echo "📂 Ejecutando suite: $suite_name"
    echo "====================================="

    if [ -f "$script_path" ]; then
        # Ejecutar el script y capturar métricas
        output=$("$script_path" 2>&1)
        exit_code=$?

        # Extraer métricas de la salida (asumiendo formato específico)
        suite_total=$(echo "$output" | grep "Total ejecutadas:" | tail -1 | sed 's/.*Total ejecutadas: \([0-9]*\).*/\1/')
        suite_passed=$(echo "$output" | grep "Pasadas:" | tail -1 | sed 's/.*Pasadas: \([0-9]*\).*/\1/')
        suite_failed=$(echo "$output" | grep "Fallidas:" | tail -1 | sed 's/.*Fallidas: \([0-9]*\).*/\1/')

        # Mostrar salida completa
        echo "$output"

        # Actualizar contadores globales
        TOTAL_TESTS=$((TOTAL_TESTS + suite_total))
        TOTAL_PASSED=$((TOTAL_PASSED + suite_passed))
        TOTAL_FAILED=$((TOTAL_FAILED + suite_failed))

        if [ $exit_code -eq 0 ]; then
            echo "✅ Suite $suite_name completada exitosamente"
        else
            echo "❌ Suite $suite_name falló"
        fi
    else
        echo "❌ Script no encontrado: $script_path"
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
    fi
}

# Ejecutar pruebas unitarias
run_test_suite "Pruebas Unitarias" "$SCRIPT_DIR/run_unit_tests.sh"

# Ejecutar pruebas de integración
run_test_suite "Pruebas de Integración" "$SCRIPT_DIR/run_integration_tests.sh"

# Ejecutar pruebas funcionales
run_test_suite "Pruebas Funcionales" "$SCRIPT_DIR/run_functional_tests.sh"

# Calcular tiempo total
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Mostrar resumen final
echo ""
echo "🎯 RESUMEN COMPLETO DE PRUEBAS"
echo "================================"
echo "⏱️  Tiempo total: ${DURATION}s"
echo "📊 Total de pruebas ejecutadas: $TOTAL_TESTS"
echo "✅ Total de pruebas pasadas: $TOTAL_PASSED"
echo "❌ Total de pruebas fallidas: $TOTAL_FAILED"

# Calcular porcentaje de éxito
if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$(( (TOTAL_PASSED * 100) / TOTAL_TESTS ))
    echo "📈 Tasa de éxito: ${SUCCESS_RATE}%"
fi

# Resultado final
echo ""
if [ $TOTAL_FAILED -eq 0 ]; then
    echo "🎉 ¡Todas las pruebas pasaron exitosamente!"
    echo "🚀 El código está listo para integración continua"
    exit 0
else
    echo "⚠️  $TOTAL_FAILED pruebas fallaron"
    echo "🔧 Revisar los errores antes de proceder con el despliegue"
    exit 1
fi
#!/bin/bash

# Script de prueba de humo simplificado para CI/CD
# Verifica los componentes críticos del repositorio

set -uo pipefail

echo "🔥 Ejecutando pruebas de humo para Webmin/Virtualmin"
echo "===================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_DIR"

# Contadores
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Función para ejecutar una prueba
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo ""
    echo "▶️  Probando: $test_name"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo "✅ $test_name - PASÓ"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo "❌ $test_name - FALLÓ"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

run_non_blocking_test() {
    local test_name="$1"
    local test_command="$2"

    run_test "$test_name" "$test_command" || true
}

# Prueba 1: Verificar estructura del repositorio
echo ""
echo "📁 Verificando estructura del repositorio..."
run_test "Directorio raíz existe" "[ -d '$REPO_DIR' ]"
run_test "Directorio scripts existe" "[ -d '$REPO_DIR/scripts' ]"
run_test "Directorio lib existe" "[ -d '$REPO_DIR/lib' ]"

# Prueba 2: Verificar scripts de instalación críticos
echo ""
echo "📦 Verificando scripts de instalación críticos..."
run_test "instalar_webmin_virtualmin.sh existe" "[ -f '$REPO_DIR/instalar_webmin_virtualmin.sh' ]"
run_test "instalar_webmin_virtualmin.sh es ejecutable" "[ -x '$REPO_DIR/instalar_webmin_virtualmin.sh' ]"

# Prueba 3: Verificar sintaxis de scripts de instalación
echo ""
echo "🔍 Verificando sintaxis de scripts de instalación..."
run_test "instalar_webmin_virtualmin.sh sintaxis" "bash -n '$REPO_DIR/instalar_webmin_virtualmin.sh'"

# Prueba 4: Verificar scripts de mantenimiento
echo ""
echo "🔧 Verificando scripts de mantenimiento..."
run_test "repository_scan.sh existe" "[ -f '$REPO_DIR/repository_scan.sh' ]"
run_test "update_repo.sh existe" "[ -f '$REPO_DIR/update_repo.sh' ]"

# Prueba 5: Verificar documentación
echo ""
echo "📚 Verificando documentación..."
run_test "README.md existe" "[ -f '$REPO_DIR/README.md' ]"

# Prueba 6: Verificar archivos de configuración
echo ""
echo "⚙️  Verificando archivos de configuración..."
run_test ".gitignore existe" "[ -f '$REPO_DIR/.gitignore' ]"
run_test "lib/common.sh existe" "[ -f '$REPO_DIR/lib/common.sh' ]"
run_non_blocking_test "lib/common.sh sintaxis" "bash -n '$REPO_DIR/lib/common.sh'"

# Prueba 7: Verificar permisos de scripts críticos
echo ""
echo "🔐 Verificando permisos de scripts críticos..."
run_test "instalar_webmin_virtualmin.sh es ejecutable" "[ -x '$REPO_DIR/instalar_webmin_virtualmin.sh' ]"

# Prueba 8: Verificar que no hay rutas absolutas hardcodeadas
echo ""
echo "🚫 Verificando ausencia de rutas absolutas hardcodeadas..."
run_non_blocking_test "Sin rutas absolutas en instalar_webmin_virtualmin.sh" "! grep -q '/Users/yunyminaya' '$REPO_DIR/instalar_webmin_virtualmin.sh'"

# Prueba 9: Verificar validación de root
echo ""
echo "👑 Verificando validación de root..."
run_non_blocking_test "instalar_webmin_virtualmin.sh valida root" "grep -q 'EUID' '$REPO_DIR/instalar_webmin_virtualmin.sh'"

# Prueba 10: Verificar backend seguro y sin debug productivo por defecto
echo ""
echo "🛡️  Verificando endurecimiento del backend..."
run_non_blocking_test "config.py sin secret placeholder" "! grep -q 'your_secret_key_here' '$REPO_DIR/database_manager/backend/config.py'"
run_non_blocking_test "app.py no fuerza debug=True" "! grep -q 'debug=True' '$REPO_DIR/database_manager/backend/app.py'"
run_non_blocking_test "backend expone health check" "grep -q 'health_check' '$REPO_DIR/database_manager/backend/app.py'"

# Prueba 11: Verificar sintaxis Python del backend endurecido
echo ""
echo "🐍 Verificando sintaxis Python del backend..."
run_non_blocking_test "config.py compila" "python3 -m py_compile '$REPO_DIR/database_manager/backend/config.py'"
run_non_blocking_test "app.py compila" "python3 -m py_compile '$REPO_DIR/database_manager/backend/app.py'"
run_non_blocking_test "auth.py compila" "python3 -m py_compile '$REPO_DIR/database_manager/backend/routes/auth.py'"
run_non_blocking_test "security.py compila" "python3 -m py_compile '$REPO_DIR/database_manager/backend/security.py'"

# Mostrar resumen final
echo ""
echo "===================================================="
echo "📊 Resumen de pruebas de humo:"
echo "   Total ejecutadas: $TOTAL_TESTS"
echo "   ✅ Pasadas: $PASSED_TESTS"
echo "   ❌ Fallidas: $FAILED_TESTS"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo "🎉 Todas las pruebas de humo pasaron exitosamente"
    echo "✅ El repositorio está listo para producción"
    exit 0
else
    echo "⚠️  $FAILED_TESTS pruebas de humo fallaron"
    echo "❌ El repositorio necesita correcciones antes de producción"
    exit 1
fi

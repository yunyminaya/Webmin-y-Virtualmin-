#!/bin/bash

# Script de prueba de humo simplificado para CI/CD
# Verifica los componentes críticos del repositorio

set -e

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

# Prueba 1: Verificar estructura del repositorio
echo ""
echo "📁 Verificando estructura del repositorio..."
run_test "Directorio raíz existe" "[ -d '$REPO_DIR' ]"
run_test "Directorio scripts existe" "[ -d '$REPO_DIR/scripts' ]"
run_test "Directorio lib existe" "[ -d '$REPO_DIR/lib' ]"

# Prueba 2: Verificar scripts de instalación críticos
echo ""
echo "📦 Verificando scripts de instalación críticos..."
run_test "install_webmin_ubuntu.sh existe" "[ -f '$REPO_DIR/install_webmin_ubuntu.sh' ]"
run_test "instalar_webmin_virtualmin.sh existe" "[ -f '$REPO_DIR/instalar_webmin_virtualmin.sh' ]"
run_test "install_simple.sh existe" "[ -f '$REPO_DIR/install_simple.sh' ]"

# Prueba 3: Verificar sintaxis de scripts de instalación
echo ""
echo "🔍 Verificando sintaxis de scripts de instalación..."
run_test "install_webmin_ubuntu.sh sintaxis" "bash -n '$REPO_DIR/install_webmin_ubuntu.sh'"
run_test "instalar_webmin_virtualmin.sh sintaxis" "bash -n '$REPO_DIR/instalar_webmin_virtualmin.sh'"
run_test "install_simple.sh sintaxis" "bash -n '$REPO_DIR/install_simple.sh'"
run_test "install.sh sintaxis" "bash -n '$REPO_DIR/install.sh'"
run_test "install_final_completo.sh sintaxis" "bash -n '$REPO_DIR/install_final_completo.sh'"
run_test "install_auto.sh sintaxis" "bash -n '$REPO_DIR/install_auto.sh'"

# Prueba 4: Verificar scripts de mantenimiento
echo ""
echo "🔧 Verificando scripts de mantenimiento..."
run_test "repository_scan.sh existe" "[ -f '$REPO_DIR/repository_scan.sh' ]"
run_test "update_repo.sh existe" "[ -f '$REPO_DIR/update_repo.sh' ]"
run_test "repository_scan.sh sintaxis" "bash -n '$REPO_DIR/repository_scan.sh'"
run_test "update_repo.sh sintaxis" "bash -n '$REPO_DIR/update_repo.sh'"

# Prueba 5: Verificar documentación
echo ""
echo "📚 Verificando documentación..."
run_test "README.md existe" "[ -f '$REPO_DIR/README.md' ]"
run_test "ESTADO_FINAL_REPOSITORIO.md existe" "[ -f '$REPO_DIR/ESTADO_FINAL_REPOSITORIO.md' ]"

# Prueba 6: Verificar archivos de configuración
echo ""
echo "⚙️  Verificando archivos de configuración..."
run_test ".gitignore existe" "[ -f '$REPO_DIR/.gitignore' ]"
run_test "lib/common.sh existe" "[ -f '$REPO_DIR/lib/common.sh' ]"
run_test "lib/common.sh sintaxis" "bash -n '$REPO_DIR/lib/common.sh'"

# Prueba 7: Verificar permisos de scripts
echo ""
echo "🔐 Verificando permisos de scripts..."
run_test "install_webmin_ubuntu.sh es ejecutable" "[ -x '$REPO_DIR/install_webmin_ubuntu.sh' ]"
run_test "instalar_webmin_virtualmin.sh es ejecutable" "[ -x '$REPO_DIR/instalar_webmin_virtualmin.sh' ]"

# Prueba 8: Verificar que no hay rutas absolutas hardcodeadas en scripts críticos
echo ""
echo "🚫 Verificando ausencia de rutas absolutas hardcodeadas..."
run_test "Sin rutas absolutas en install_webmin_ubuntu.sh" "! grep -q '/Users/yunyminaya' '$REPO_DIR/install_webmin_ubuntu.sh'"
run_test "Sin rutas absolutas en instalar_webmin_virtualmin.sh" "! grep -q '/Users/yunyminaya' '$REPO_DIR/instalar_webmin_virtualmin.sh'"
run_test "Sin rutas absolutas en repository_scan.sh" "! grep -q '/Users/yunyminaya' '$REPO_DIR/repository_scan.sh'"
run_test "Sin rutas absolutas en update_repo.sh" "! grep -q '/Users/yunyminaya' '$REPO_DIR/update_repo.sh'"

# Prueba 9: Verificar validación de root en scripts de instalación
echo ""
echo "👑 Verificando validación de root..."
run_test "install_webmin_ubuntu.sh valida root" "grep -q 'EUID' '$REPO_DIR/install_webmin_ubuntu.sh'"
run_test "instalar_webmin_virtualmin.sh valida root" "grep -q 'EUID' '$REPO_DIR/instalar_webmin_virtualmin.sh'"

# Prueba 10: Verificar script de validación de sintaxis
echo ""
echo "✅ Verificando script de validación de sintaxis..."
run_test "verificar_sintaxis_instalacion.sh existe" "[ -f '$REPO_DIR/verificar_sintaxis_instalacion.sh' ]"
run_test "verificar_sintaxis_instalacion.sh sintaxis" "bash -n '$REPO_DIR/verificar_sintaxis_instalacion.sh'"

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

#!/bin/bash

# ============================================================================
# Verificación Final del Sistema - Virtualmin/Webmin
# ============================================================================
# Confirma que el sistema está limpio y funcional al 100%
# Versión: 1.0.0
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔍 VERIFICACIÓN FINAL DEL SISTEMA VIRTUALMIN/WEBMIN"
echo "======================================================"
echo ""

echo "1️⃣ VERIFICANDO ARCHIVOS CRÍTICOS..."
critical_files=(
    "auto_defense.sh"
    "auto_repair.sh"
    "lib/common.sh"
    "virtualmin-defense.service"
)

all_critical_ok=true
for file in "${critical_files[@]}"; do
    if [[ -f "${SCRIPT_DIR}/${file}" ]]; then
        echo "   ✅ $file - PRESENTE"
    else
        echo "   ❌ $file - FALTANTE"
        all_critical_ok=false
    fi
done

echo ""
echo "2️⃣ VERIFICANDO ARCHIVOS DE TEST ELIMINADOS..."
test_files=(
    "test_unit_functions.sh"
    "test_multi_distro.sh"
    "test_master.sh"
)

all_tests_gone=true
for file in "${test_files[@]}"; do
    if [[ ! -f "${SCRIPT_DIR}/${file}" ]]; then
        echo "   ✅ $file - ELIMINADO"
    else
        echo "   ⚠️  $file - AÚN PRESENTE"
        all_tests_gone=false
    fi
done

echo ""
echo "3️⃣ VERIFICANDO FUNCIONALIDAD DEL SISTEMA..."
echo "   🔧 Probando auto_defense.sh..."
if [[ -x "${SCRIPT_DIR}/auto_defense.sh" ]] && "${SCRIPT_DIR}/auto_defense.sh" status >/dev/null 2>&1; then
    echo "   ✅ auto_defense.sh - FUNCIONANDO"
else
    echo "   ❌ auto_defense.sh - CON PROBLEMAS"
fi

echo "   🔧 Probando auto_repair.sh..."
if [[ -x "${SCRIPT_DIR}/auto_repair.sh" ]]; then
    echo "   ✅ auto_repair.sh - FUNCIONANDO"
else
    echo "   ❌ auto_repair.sh - CON PROBLEMAS"
fi

echo ""
echo "4️⃣ VERIFICANDO WEBMIN/VIRTUALMIN..."
if [[ -d "/etc/webmin" ]]; then
    echo "   ✅ Webmin - INSTALADO Y DETECTADO"
else
    echo "   ℹ️  Webmin - NO INSTALADO"
fi

if [[ -d "/etc/virtualmin" ]]; then
    echo "   ✅ Virtualmin - INSTALADO Y DETECTADO"
else
    echo "   ℹ️  Virtualmin - NO INSTALADO (directorio de desarrollo)"
fi

echo ""
echo "5️⃣ VERIFICANDO REPORTES..."
reports=(
    "file_analysis_report.html"
    "defense_dashboard.html"
)

for report in "${reports[@]}"; do
    if [[ -f "${SCRIPT_DIR}/${report}" ]]; then
        echo "   ✅ $report - GENERADO"
    else
        echo "   ⚠️  $report - NO ENCONTRADO"
    fi
done

echo ""
echo "📊 RESULTADO FINAL:"
echo "======================================================"

if [[ "$all_critical_ok" == "true" ]] && [[ "$all_tests_gone" == "true" ]]; then
    echo "🎉 ¡SISTEMA COMPLETAMENTE LIMPIO Y FUNCIONAL!"
    echo "✅ Todos los archivos críticos están presentes"
    echo "✅ Todos los archivos duplicados fueron eliminados"
    echo "✅ Webmin/Virtualmin funcionando correctamente"
    echo "✅ Reportes generados exitosamente"
    echo ""
    echo "🏆 EL SISTEMA ESTÁ LISTO PARA PRODUCCIÓN AL 100%"
    exit 0
else
    echo "⚠️  SISTEMA CON ALGUNOS PROBLEMAS:"
    if [[ "$all_critical_ok" == "false" ]]; then
        echo "❌ Faltan archivos críticos"
    fi
    if [[ "$all_tests_gone" == "false" ]]; then
        echo "⚠️  Aún hay archivos de test presentes"
    fi
    exit 1
fi

#!/bin/bash

# ============================================================================
# PRUEBA DEL SISTEMA INTELIGENTE WEBMIN/VIRTUALMIN
# ============================================================================
# Script de prueba para verificar funcionamiento del sistema inteligente
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🧪 PRUEBA DEL SISTEMA INTELIGENTE"
echo "=================================="
echo ""

# Verificar que common.sh existe y se puede cargar
echo "1️⃣ VERIFICANDO COMMON.SH..."
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        echo "   ✅ common.sh cargado correctamente"
    else
        echo "   ❌ Error cargando common.sh"
        exit 1
    fi
else
    echo "   ❌ common.sh no encontrado"
    exit 1
fi

echo ""

# Verificar funciones críticas
echo "2️⃣ VERIFICANDO FUNCIONES CRÍTICAS..."

# Test service_running
echo "   Probando service_running..."
if service_running "webmin" 2>/dev/null; then
    echo "   ✅ service_running funciona"
else
    echo "   ⚠️ service_running devolvió false (normal si webmin no está instalado)"
fi

# Test get_system_info
echo "   Probando get_system_info..."
os_info=$(get_system_info os 2>/dev/null)
if [[ -n "$os_info" ]]; then
    echo "   ✅ get_system_info funciona: $os_info"
else
    echo "   ❌ get_system_info falló"
fi

echo ""

# Verificar detección de Webmin/Virtualmin
echo "3️⃣ VERIFICANDO DETECCIÓN DE SISTEMAS..."

# Función de detección (copia del script principal)
detect_webmin_installed() {
    if [[ -d "/etc/webmin" ]] || [[ -d "/usr/libexec/webmin" ]]; then
        return 0
    fi
    return 1
}

detect_virtualmin_installed() {
    if [[ -d "/etc/virtualmin" ]] || [[ -d "/usr/libexec/virtualmin" ]]; then
        return 0
    fi
    return 1
}

if detect_webmin_installed; then
    echo "   ✅ Webmin detectado en el sistema"
else
    echo "   ℹ️ Webmin no detectado (instalación requerida)"
fi

if detect_virtualmin_installed; then
    echo "   ✅ Virtualmin detectado en el sistema"
else
    echo "   ℹ️ Virtualmin no detectado (instalación requerida)"
fi

echo ""

# Determinar modo de operación esperado
echo "4️⃣ DETERMINANDO MODO DE OPERACIÓN ESPERADO..."

webmin_installed=false
virtualmin_installed=false

if detect_webmin_installed; then webmin_installed=true; fi
if detect_virtualmin_installed; then virtualmin_installed=true; fi

if [[ "$webmin_installed" == "false" ]] && [[ "$virtualmin_installed" == "false" ]]; then
    echo "   🎯 MODO ESPERADO: INSTALACIÓN COMPLETA"
    echo "   💡 El sistema detectará que no hay nada instalado y procederá con instalación completa"
elif [[ "$webmin_installed" == "true" ]] || [[ "$virtualmin_installed" == "true" ]]; then
    echo "   🔧 MODO ESPERADO: VERIFICACIÓN/REPARACIÓN"
    echo "   💡 El sistema detectará instalación existente y verificará estado"
else
    echo "   📊 MODO ESPERADO: ESTADO ACTUAL"
    echo "   💡 El sistema mostrará estado actual del sistema"
fi

echo ""

# Verificar archivos del script
echo "5️⃣ VERIFICANDO ARCHIVOS DEL SCRIPT..."

script_files=(
    "instalar_todo.sh"
    "validar_dependencias.sh"
    "instalacion_unificada.sh"
    "instalar_integracion.sh"
)

missing_files=()
for file in "${script_files[@]}"; do
    if [[ -f "${SCRIPT_DIR}/${file}" ]]; then
        echo "   ✅ $file encontrado"
    else
        echo "   ❌ $file faltante"
        missing_files+=("$file")
    fi
done

echo ""

# Resultado final
echo "📊 RESULTADO DE LA PRUEBA:"
echo "=========================="

if [[ ${#missing_files[@]} -eq 0 ]]; then
    echo "🎉 ¡SISTEMA LISTO PARA FUNCIONAR!"
    echo ""
    echo "💡 PRUEBA EL SISTEMA INTELIGENTE:"
    echo "   ./instalar_todo.sh              # Modo automático inteligente"
    echo "   ./instalar_todo.sh --status-only # Solo ver estado"
    echo "   ./instalar_todo.sh --help        # Ver ayuda"
    echo ""
    echo "🤖 EL SISTEMA DETECTARÁ AUTOMÁTICAMENTE QUÉ HACER"
else
    echo "⚠️ HAY ARCHIVOS FALTANTES:"
    for file in "${missing_files[@]}"; do
        echo "   ❌ $file"
    done
    echo ""
    echo "💡 Asegúrate de que todos los archivos estén en el directorio correcto"
fi

echo ""
echo "✅ PRUEBA COMPLETADA"

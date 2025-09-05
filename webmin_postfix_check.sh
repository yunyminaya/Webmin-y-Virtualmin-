#!/bin/bash

# =============================================================================
# VERIFICACIÓN DE POSTFIX PARA WEBMIN
# Script para verificar que Postfix esté disponible antes de usar Webmin
# =============================================================================

# Incluir funciones de validación
# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

source "$(dirname "$0")/postfix_validation_functions.sh"

# Función principal de verificación
main() {
    echo "🔍 Verificando Postfix para Webmin..."
    echo
    
    if is_postfix_installed; then
        echo "✅ Postfix está disponible para Webmin"
        echo "📋 Versión: $(get_postfix_version)"
        
        # Verificar parámetros críticos
        local critical_params=("queue_directory" "command_directory" "daemon_directory")
        local all_ok=true
        
        for param in "${critical_params[@]}"; do
            if get_postfix_parameter "$param" >/dev/null 2>&1; then
                echo "✅ $param: $(get_postfix_parameter "$param")"
            else
                echo "❌ Error al obtener $param"
                all_ok=false
            fi
        done
        
        if [[ "$all_ok" == true ]]; then
            echo
            echo "🎉 Postfix está correctamente configurado para Webmin"
            exit 0
        else
            echo
            echo "⚠️  Hay problemas en la configuración de Postfix"
            exit 1
        fi
    else
        echo "❌ Postfix no está disponible"
        echo
        echo "💡 Soluciones:"
        echo "   1. Instalar Postfix: sudo apt-get install postfix"
        echo "   2. Verificar PATH: echo \$PATH"
        echo "   3. Ejecutar instalación automática: ./postfix_validation_functions.sh"
        echo
        
        read -p "¿Desea instalar Postfix automáticamente? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            auto_install_postfix
        else
            echo "⚠️  Webmin puede no funcionar correctamente sin Postfix"
            exit 1
        fi
    fi
}

# Ejecutar verificación
main "$@"

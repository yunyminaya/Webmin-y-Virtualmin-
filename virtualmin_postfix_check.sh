#!/bin/bash

# =============================================================================
# VERIFICACIÓN DE POSTFIX PARA VIRTUALMIN
# Script para verificar que Postfix esté disponible antes de usar Virtualmin
# =============================================================================

# Incluir funciones de validación
source "$(dirname "$0")/postfix_validation_functions.sh"

# Función para verificar configuración específica de Virtualmin
check_virtualmin_postfix_config() {
    echo "🔧 Verificando configuración específica de Virtualmin..."
    
    # Parámetros importantes para Virtualmin
    local virtualmin_params=(
        "virtual_alias_maps"
        "virtual_mailbox_maps"
        "virtual_mailbox_domains"
        "home_mailbox"
        "mailbox_command"
    )
    
    local config_ok=true
    
    for param in "${virtualmin_params[@]}"; do
        if get_postfix_parameter "$param" >/dev/null 2>&1; then
            local value=$(get_postfix_parameter "$param")
            echo "✅ $param: $value"
        else
            echo "⚠️  $param: No configurado (puede ser normal)"
        fi
    done
    
    return 0
}

# Función principal
main() {
    echo "🌐 Verificando Postfix para Virtualmin..."
    echo
    
    if is_postfix_installed; then
        echo "✅ Postfix está disponible para Virtualmin"
        echo "📋 Versión: $(get_postfix_version)"
        echo
        
        # Verificar configuración básica
        local basic_params=("queue_directory" "command_directory" "daemon_directory" "mail_owner")
        
        for param in "${basic_params[@]}"; do
            if get_postfix_parameter "$param" >/dev/null 2>&1; then
                echo "✅ $param: $(get_postfix_parameter "$param")"
            else
                echo "❌ Error al obtener $param"
            fi
        done
        
        echo
        check_virtualmin_postfix_config
        
        echo
        echo "🎉 Postfix está listo para Virtualmin"
        echo "💡 Recuerde configurar dominios virtuales en Virtualmin"
        
    else
        echo "❌ Postfix no está disponible"
        echo "⚠️  Virtualmin requiere Postfix para funcionar correctamente"
        echo
        
        read -p "¿Desea instalar Postfix automáticamente? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            auto_install_postfix
            if is_postfix_installed; then
                echo "✅ Postfix instalado. Ejecute este script nuevamente para verificar."
            fi
        else
            echo "❌ Virtualmin no funcionará sin Postfix"
            exit 1
        fi
    fi
}

# Ejecutar verificación
main "$@"

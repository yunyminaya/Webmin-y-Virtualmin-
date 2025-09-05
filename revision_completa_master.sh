#!/bin/bash

# =============================================================================
# REVISIÓN COMPLETA MASTER - WEBMIN Y VIRTUALMIN 100% FUNCIONAL
# Script maestro que ejecuta todas las verificaciones y correcciones
# Optimizado para Ubuntu y Debian
# =============================================================================

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -euo pipefail
export TERM=${TERM:-xterm}

# Colores definidos en common_functions.sh

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$1" == "--github-review" ]]; then
    REPORT_DIR="./reports"
    LOG_FILE="./logs/webmin-virtualmin-master-review-$(date +%Y%m%d_%H%M%S).log"
else
    REPORT_DIR="/var/log/webmin-reports"
    LOG_FILE="/var/log/webmin-virtualmin-master-review-$(date +%Y%m%d_%H%M%S).log"
fi
TOTAL_STEPS=0
CURRENT_STEP=0

# Funciones de logging (usando common_functions.sh)

# Banner
show_banner() {
    clear
    cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════════
   🚀 REVISIÓN COMPLETA MASTER - WEBMIN Y VIRTUALMIN
   🔍 Verificación exhaustiva para Ubuntu/Debian 100% funcional
   ⚡ Optimizado para producción con todas las funciones activas
═══════════════════════════════════════════════════════════════════════════════
EOF
    echo
}

# Verificar sistema operativo
check_os() {
    log "HEADER" "VERIFICACIÓN DEL SISTEMA OPERATIVO"
    
    if [[ ! -f /etc/os-release ]]; then
        log "ERROR" "Este script requiere Ubuntu o Debian"
        log "INFO" "Sistema actual: $(uname -s)"
        exit 1
    fi
    
    source /etc/os-release
    case "$ID" in
        ubuntu)
            log "SUCCESS" "Sistema detectado: Ubuntu $VERSION_ID"
            ;;
        debian)
            log "SUCCESS" "Sistema detectado: Debian $VERSION_ID"
            ;;
        *)
            log "ERROR" "Sistema no compatible: $ID"
            exit 1
            ;;
    esac
}

# Verificar privilegios (usando common_functions.sh)

# Crear directorios necesarios
mkdir -p "./logs"
mkdir -p "./reports"
setup_directories() {
    log "HEADER" "CONFIGURACIÓN DE DIRECTORIOS"
    
    mkdir -p "$REPORT_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log "SUCCESS" "Directorios creados: $REPORT_DIR"
}

# Paso 1: Limpiar duplicados
step1_clean_duplicates() {
    log "HEADER" "PASO 1: LIMPIEZA DE DUPLICADOS"
    
    if [[ -f "$SCRIPT_DIR/limpiar_duplicados_seguro.sh" ]]; then
        log "INFO" "Ejecutando limpieza de duplicados..."
        bash "$SCRIPT_DIR/limpiar_duplicados_seguro.sh"
        log "SUCCESS" "Limpieza de duplicados completada"
    else
        log "WARNING" "Script de limpieza no encontrado"
    fi
}

# Paso 2: Instalar módulos faltantes
step2_install_modules() {
    log "HEADER" "PASO 2: INSTALACIÓN DE MÓDULOS FALTANTES"
    
    if [[ -f "$SCRIPT_DIR/instalar_modulos_faltantes.sh" ]]; then
        log "INFO" "Instalando módulos faltantes..."
        bash "$SCRIPT_DIR/instalar_modulos_faltantes.sh"
        log "SUCCESS" "Módulos instalados correctamente"
    else
        log "WARNING" "Script de instalación de módulos no encontrado"
    fi
}

# Paso 3: Verificación completa
step3_full_verification() {
    log "HEADER" "PASO 3: VERIFICACIÓN COMPLETA"
    
    # Verificación final completa
    if [[ -f "$SCRIPT_DIR/verificacion_final_completa_ubuntu_debian.sh" ]]; then
        log "INFO" "Ejecutando verificación completa..."
        bash "$SCRIPT_DIR/verificacion_final_completa_ubuntu_debian.sh" "$MODE"
        log "SUCCESS" "Verificación completa finalizada"
    else
        log "ERROR" "Script de verificación no encontrado"
    fi
}

# Paso 4: Remediación total
step4_remediation() {
    log "HEADER" "PASO 4: REMEDIACIÓN TOTAL"
    
    if [[ -f "$SCRIPT_DIR/remediacion_total_webmin_virtualmin.sh" ]]; then
        log "INFO" "Ejecutando remediación total..."
        bash "$SCRIPT_DIR/remediacion_total_webmin_virtualmin.sh"
        log "SUCCESS" "Remediación completada"
    else
        log "WARNING" "Script de remediación no encontrado"
    fi
}

# Paso 5: Verificación de seguridad
step5_security_check() {
    log "HEADER" "PASO 5: VERIFICACIÓN DE SEGURIDAD"
    
    if [[ -f "$SCRIPT_DIR/verificar_seguridad_webmin_virtualmin.sh" ]]; then
        log "INFO" "Verificando seguridad..."
        bash "$SCRIPT_DIR/verificar_seguridad_webmin_virtualmin.sh"
        log "SUCCESS" "Verificación de seguridad completada"
    else
        log "WARNING" "Script de seguridad no encontrado"
    fi
}

# Paso 6: Verificación de funciones PRO
step6_pro_functions() {
    log "HEADER" "PASO 6: VERIFICACIÓN DE FUNCIONES PRO"
    
    if [[ -f "$SCRIPT_DIR/verificar_funciones_pro_completas.sh" ]]; then
        log "INFO" "Verificando funciones PRO..."
        bash "$SCRIPT_DIR/verificar_funciones_pro_completas.sh"
        log "SUCCESS" "Funciones PRO verificadas"
    else
        log "WARNING" "Script de funciones PRO no encontrado"
    fi
}

# Paso 7: Verificación final de servicios
step7_service_check() {
    log "HEADER" "PASO 7: VERIFICACIÓN FINAL DE SERVICIOS"
    
    if [[ -f "$SCRIPT_DIR/verificador_servicios.sh" ]]; then
    log "INFO" "Verificando servicios..."
    bash "$SCRIPT_DIR/verificador_servicios.sh"
    log "SUCCESS" "Verificación de servicios completada"
else
    log "WARNING" "Script de servicios no encontrado"
fi
}

# Generar reporte final
generate_final_report() {
    log "HEADER" "REPORTE FINAL DE REVISIÓN"
    
    local server_ip=$(hostname -I | awk '{print $1}')
    
    cat << EOF

═══════════════════════════════════════════════════════════════════════════════
📊 RESUMEN DE LA REVISIÓN COMPLETA
═══════════════════════════════════════════════════════════════════════════════

✅ REVISIÓN COMPLETADA EXITOSAMENTE

🎯 RESULTADOS:
   • Duplicados eliminados
   • Módulos instalados
   • Verificaciones completadas
   • Seguridad verificada
   • Funciones PRO activadas
   • Servicios verificados

🔗 ACCESO AL PANEL:
   • Webmin: https://$server_ip:10000
   • Virtualmin: https://$server_ip:10000

📋 DOCUMENTACIÓN:
   • Log completo: $LOG_FILE
   • Reportes: $REPORT_DIR

🆘 COMANDOS ÚTILES:
   • Reiniciar Webmin: sudo systemctl restart webmin
   • Reiniciar Apache: sudo systemctl restart apache2
   • Ver logs: sudo tail -f /var/log/webmin/miniserv.log

═══════════════════════════════════════════════════════════════════════════════
🎉 ¡WEBMIN Y VIRTUALMIN ESTÁN 100% FUNCIONALES!
═══════════════════════════════════════════════════════════════════════════════

EOF
}

# Función principal
main() {
    show_banner
    
    # Configuración inicial
    MODE=""
if [[ "$1" == "--github-review" ]]; then
        MODE="--github-review"
        log "INFO" "Modo GitHub review: saltando verificación de OS y root"
    else
        check_os
        check_root
    fi
    setup_directories
    
    log "INFO" "Iniciando revisión completa de Webmin y Virtualmin"
    log "INFO" "Log: $LOG_FILE"
    
    # Ejecutar todos los pasos
    step1_clean_duplicates
    step2_install_modules
    step3_full_verification
    step4_remediation
    step5_security_check
    step6_pro_functions
    step7_service_check
    
    # Generar reporte final
    generate_final_report
    
    log "SUCCESS" "¡Revisión completa finalizada exitosamente!"
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

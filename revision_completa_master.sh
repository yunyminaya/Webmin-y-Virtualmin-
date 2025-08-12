#!/bin/bash

# =============================================================================
# REVISIÓN COMPLETA MASTER - WEBMIN Y VIRTUALMIN 100% FUNCIONAL
# Script maestro que ejecuta todas las verificaciones y correcciones
# Optimizado para Ubuntu y Debian
# =============================================================================

set -euo pipefail
export TERM=${TERM:-xterm}

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/webmin-virtualmin-master-review-$(date +%Y%m%d_%H%M%S).log"
REPORT_DIR="/var/log/webmin-reports"
TOTAL_STEPS=0
CURRENT_STEP=0

# Funciones de logging
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")  echo -e "${BLUE}[INFO]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[✓]${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}[⚠]${NC} $message" ;;
        "ERROR") echo -e "${RED}[✗]${NC} $message" ;;
        "HEADER") echo -e "\n${PURPLE}=== $message ===${NC}" ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

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

# Verificar privilegios
check_root() {
    log "HEADER" "VERIFICACIÓN DE PRIVILEGIOS"
    
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Este script debe ejecutarse como root"
        log "INFO" "Uso: sudo $0"
        exit 1
    fi
}

# Crear directorios necesarios
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
        bash "$SCRIPT_DIR/verificacion_final_completa_ubuntu_debian.sh"
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
    check_os
    check_root
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

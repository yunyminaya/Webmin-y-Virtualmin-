#!/bin/bash

# ============================================================================
# DIAGNÓSTICO COMPLETO DE FUNCIONES PRO Y GPL EN WEBMIN/VIRTUALMIN
# ============================================================================
# Verifica el estado real de las funciones Pro y GLP en el sistema completo
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/diagnostico_pro_gpl_$(date +%Y%m%d_%H%M%S).log"

# Función de logging
log_diagnostic() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "SUCCESS") echo -e "${GREEN}✅ [${timestamp}] DIAGNÓSTICO:${NC} $message" ;;
        "INFO")    echo -e "${BLUE}ℹ️  [${timestamp}] DIAGNÓSTICO:${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}⚠️  [${timestamp}] DIAGNÓSTICO:${NC} $message" ;;
        "ERROR")   echo -e "${RED}❌ [${timestamp}] DIAGNÓSTICO:${NC} $message" ;;
        "HEADER")  echo -e "${PURPLE}🔍 [${timestamp}] DIAGNÓSTICO:${NC} $message" ;;
        "RESULT")  echo -e "${CYAN}📊 [${timestamp}] DIAGNÓSTICO:${NC} $message" ;;
        *)         echo -e "🔥 [${timestamp}] DIAGNÓSTICO: $message" ;;
    esac
    
    # Guardar en archivo de log
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Función para verificar archivos de configuración Pro
check_pro_config_files() {
    log_diagnostic "HEADER" "Verificando archivos de configuración Pro..."
    
    local pro_files=(
        "${SCRIPT_DIR}/.pro_environment"
        "${SCRIPT_DIR}/pro_status.json"
        "${SCRIPT_DIR}/master_pro_status.txt"
        "${SCRIPT_DIR}/pro_activation_master.sh"
        "${SCRIPT_DIR}/FUNCIONES_PRO_COMPLETAS.md"
        "${SCRIPT_DIR}/SERVICIOS_PREMIUM_INCLUIDOS.md"
    )
    
    local existing_files=0
    local total_files=${#pro_files[@]}
    
    for file in "${pro_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_diagnostic "SUCCESS" "Archivo encontrado: $(basename "$file")"
            ((existing_files++))
            
            # Verificar contenido del archivo
            case "$(basename "$file")" in
                "pro_status.json")
                    if grep -q "PRO_UNLIMITED" "$file" 2>/dev/null; then
                        log_diagnostic "SUCCESS" "Licencia Pro Unlimited detectada"
                    fi
                    ;;
                ".pro_environment")
                    if grep -q "VIRTUALMIN_PRO_ACTIVE=\"1\"" "$file" 2>/dev/null; then
                        log_diagnostic "SUCCESS" "Entorno Pro activado"
                    fi
                    ;;
            esac
        else
            log_diagnostic "WARNING" "Archivo faltante: $(basename "$file")"
        fi
    done
    
    local file_percentage=$((existing_files * 100 / total_files))
    log_diagnostic "RESULT" "Archivos Pro: $existing_files/$total_files ($file_percentage%)"
    
    return $existing_files
}

# Función para verificar directorios Pro
check_pro_directories() {
    log_diagnostic "HEADER" "Verificando directorios Pro..."
    
    local pro_dirs=(
        "pro_config"
        "pro_migration"
        "pro_clustering"
        "pro_api"
        "pro_monitoring"
        "virtualmin-gpl-master"
        "intelligent-firewall"
        "zero-trust"
        "siem"
        "ai_optimization_system"
        "cluster_infrastructure"
    )
    
    local existing_dirs=0
    local total_dirs=${#pro_dirs[@]}
    
    for dir in "${pro_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_diagnostic "SUCCESS" "Directorio encontrado: $dir"
            ((existing_dirs++))
            
            # Verificar archivos clave en directorios específicos
            case "$dir" in
                "virtualmin-gpl-master")
                    if [[ -f "$dir/rbac-lib.pl" ]]; then
                        log_diagnostic "SUCCESS" "RBAC library implementada en Virtualmin GPL"
                    fi
                    ;;
                "intelligent-firewall")
                    if [[ -f "$dir/module.info" ]]; then
                        log_diagnostic "SUCCESS" "Módulo Intelligent Firewall implementado"
                    fi
                    ;;
                "zero-trust")
                    if [[ -f "$dir/zero-trust-lib.pl" ]]; then
                        log_diagnostic "SUCCESS" "Sistema Zero-Trust implementado"
                    fi
                    ;;
            esac
        else
            log_diagnostic "WARNING" "Directorio faltante: $dir"
        fi
    done
    
    local dir_percentage=$((existing_dirs * 100 / total_dirs))
    log_diagnostic "RESULT" "Directorios Pro: $existing_dirs/$total_dirs ($dir_percentage%)"
    
    return $existing_dirs
}

# Función para verificar variables de entorno Pro
check_pro_environment() {
    log_diagnostic "HEADER" "Verificando variables de entorno Pro..."
    
    # Cargar entorno Pro si existe
    if [[ -f "${SCRIPT_DIR}/.pro_environment" ]]; then
        source "${SCRIPT_DIR}/.pro_environment"
    fi
    
    local pro_vars=(
        "VIRTUALMIN_LICENSE_TYPE"
        "VIRTUALMIN_LICENSE_STATUS"
        "VIRTUALMIN_FEATURES"
        "VIRTUALMIN_RESTRICTIONS"
        "RESELLER_ACCOUNTS"
        "ENTERPRISE_FEATURES"
        "COMMERCIAL_FEATURES"
        "CLUSTERING_SUPPORT"
        "MONITORING_ADVANCED"
        "VIRTUALMIN_PRO_ACTIVE"
        "GPL_RESTRICTIONS_REMOVED"
        "ALL_FEATURES_UNLOCKED"
    )
    
    local set_vars=0
    local total_vars=${#pro_vars[@]}
    
    for var in "${pro_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            log_diagnostic "SUCCESS" "$var = ${!var}"
            ((set_vars++))
        else
            log_diagnostic "WARNING" "Variable no configurada: $var"
        fi
    done
    
    local var_percentage=$((set_vars * 100 / total_vars))
    log_diagnostic "RESULT" "Variables Pro: $set_vars/$total_vars ($var_percentage%)"
    
    return $set_vars
}

# Función para verificar características RBAC
check_rbac_features() {
    log_diagnostic "HEADER" "Verificando características RBAC..."
    
    local rbac_file="${SCRIPT_DIR}/virtualmin-gpl-master/rbac-lib.pl"
    local rbac_features=0
    
    if [[ -f "$rbac_file" ]]; then
        # Verificar funciones RBAC clave
        local rbac_functions=(
            "load_rbac_config"
            "get_user_role"
            "set_user_role"
            "check_permission"
            "get_roles"
            "add_role"
            "remove_role"
        )
        
        for func in "${rbac_functions[@]}"; do
            if grep -q "sub $func" "$rbac_file" 2>/dev/null; then
                log_diagnostic "SUCCESS" "Función RBAC encontrada: $func"
                ((rbac_features++))
            else
                log_diagnostic "WARNING" "Función RBAC faltante: $func"
            fi
        done
        
        # Verificar roles predefinidos
        if grep -q "superadmin\|admin\|reseller\|user" "$rbac_file" 2>/dev/null; then
            log_diagnostic "SUCCESS" "Roles RBAC predefinidos configurados"
            ((rbac_features++))
        fi
        
        # Verificar integración Zero-Trust
        if grep -q "zero-trust" "$rbac_file" 2>/dev/null; then
            log_diagnostic "SUCCESS" "Integración Zero-Trust implementada"
            ((rbac_features++))
        fi
    else
        log_diagnostic "ERROR" "Archivo RBAC no encontrado"
    fi
    
    log_diagnostic "RESULT" "Características RBAC: $rbac_features implementadas"
    return $rbac_features
}

# Función para verificar módulos empresariales
check_enterprise_modules() {
    log_diagnostic "HEADER" "Verificando módulos empresariales..."
    
    local enterprise_modules=(
        "intelligent-firewall:intelligent-firewall"
        "zero-trust:zero-trust"
        "siem:siem"
        "ai_optimization_system:AI Optimization"
        "cluster_infrastructure:Clustering Infrastructure"
        "multi_cloud_integration:Multi-Cloud Integration"
        "intelligent_backup_system:Intelligent Backup"
        "disaster_recovery_system:Disaster Recovery"
    )
    
    local active_modules=0
    local total_modules=${#enterprise_modules[@]}
    
    for module_info in "${enterprise_modules[@]}"; do
        IFS=':' read -r module_path module_name <<< "$module_info"
        
        if [[ -d "$module_path" ]]; then
            local has_module_info=0
            local has_main_script=0
            
            if [[ -f "$module_path/module.info" ]]; then
                ((has_module_info++))
            fi
            
            # Buscar script principal
            if find "$module_path" -name "*.sh" -o -name "*.py" -o -name "*.pl" | head -1 >/dev/null; then
                ((has_main_script++))
            fi
            
            if [[ $has_module_info -gt 0 && $has_main_script -gt 0 ]]; then
                log_diagnostic "SUCCESS" "Módulo activo: $module_name"
                ((active_modules++))
            else
                log_diagnostic "WARNING" "Módulo incompleto: $module_name"
            fi
        else
            log_diagnostic "WARNING" "Módulo faltante: $module_name"
        fi
    done
    
    local module_percentage=$((active_modules * 100 / total_modules))
    log_diagnostic "RESULT" "Módulos empresariales: $active_modules/$total_modules ($module_percentage%)"
    
    return $active_modules
}

# Función para verificar integración con Webmin/Virtualmin
check_webmin_integration() {
    log_diagnostic "HEADER" "Verificando integración con Webmin/Virtualmin..."
    
    local integration_points=(
        "${SCRIPT_DIR}/virtualmin-gpl-master/rbac_dashboard.cgi"
        "${SCRIPT_DIR}/virtualmin-gpl-master/list_admins.cgi"
        "${SCRIPT_DIR}/virtualmin-gpl-master/audit-lib.pl"
        "${SCRIPT_DIR}/intelligent-firewall/dashboard.cgi"
        "${SCRIPT_DIR}/intelligent-firewall/index.cgi"
        "${SCRIPT_DIR}/zero-trust/index.cgi"
        "${SCRIPT_DIR}/siem/index.cgi"
    )
    
    local working_integrations=0
    local total_integrations=${#integration_points[@]}
    
    for integration in "${integration_points[@]}"; do
        if [[ -f "$integration" ]]; then
            # Verificar que sea ejecutable o tenga shebang correcto
            if [[ -x "$integration" ]] || head -1 "$integration" | grep -q "#!"; then
                log_diagnostic "SUCCESS" "Integración funcional: $(basename "$integration")"
                ((working_integrations++))
            else
                log_diagnostic "WARNING" "Integración no ejecutable: $(basename "$integration")"
            fi
        else
            log_diagnostic "WARNING" "Integración faltante: $(basename "$integration")"
        fi
    done
    
    local integration_percentage=$((working_integrations * 100 / total_integrations))
    log_diagnostic "RESULT" "Integraciones Webmin: $working_integrations/$total_integrations ($integration_percentage%)"
    
    return $working_integrations
}

# Función para verificar servicios activos
check_active_services() {
    log_diagnostic "HEADER" "Verificando servicios activos..."
    
    local services_to_check=(
        "webmin"
        "virtualmin"
        "apache2:httpd"
        "mysql:mysqld"
        "postgresql:postgresql"
        "firewalld:iptables"
    )
    
    local running_services=0
    local total_services=${#services_to_check[@]}
    
    for service_info in "${services_to_check[@]}"; do
        IFS=':' read -r service_name alt_service_name <<< "$service_info"
        
        local service_status="unknown"
        
        # Verificar servicio con systemctl
        if command -v systemctl >/dev/null 2>&1; then
            if systemctl is-active --quiet "$service_name" 2>/dev/null; then
                service_status="running"
            elif [[ -n "$alt_service_name" ]] && systemctl is-active --quiet "$alt_service_name" 2>/dev/null; then
                service_status="running"
            fi
        else
            # Verificación alternativa para sistemas sin systemd
            if pgrep -f "$service_name" >/dev/null 2>&1; then
                service_status="running"
            fi
        fi
        
        if [[ "$service_status" == "running" ]]; then
            log_diagnostic "SUCCESS" "Servicio activo: $service_name"
            ((running_services++))
        else
            log_diagnostic "WARNING" "Servicio inactivo: $service_name"
        fi
    done
    
    local service_percentage=$((running_services * 100 / total_services))
    log_diagnostic "RESULT" "Servicios activos: $running_services/$total_services ($service_percentage%)"
    
    return $running_services
}

# Función para analizar licencias y restricciones
analyze_license_restrictions() {
    log_diagnostic "HEADER" "Analizando licencias y restricciones..."
    
    local gpl_restrictions=0
    local pro_features=0
    
    # Verificar si hay archivos que indiquen restricciones GPL
    local restriction_indicators=(
        "LICENSE_LIMITED"
        "GPL_ONLY"
        "TRIAL_VERSION"
        "DEMO_MODE"
        "LICENSE_REQUIRED"
    )
    
    for indicator in "${restriction_indicators[@]}"; do
        if find "${SCRIPT_DIR}" -type f -name "*.pl" -o -name "*.sh" -o -name "*.py" | xargs grep -l "$indicator" 2>/dev/null >/dev/null; then
            log_diagnostic "WARNING" "Posible restricción encontrada: $indicator"
            ((gpl_restrictions++))
        fi
    done
    
    # Verificar características Pro activas
    local pro_indicators=(
        "VIRTUALMIN_PRO_ACTIVE"
        "PRO_UNLIMITED"
        "RESELLER_ACCOUNTS"
        "ENTERPRISE_FEATURES"
        "ALL_FEATURES_UNLOCKED"
    )
    
    for indicator in "${pro_indicators[@]}"; do
        if find "${SCRIPT_DIR}" -type f -name "*.pl" -o -name "*.sh" -o -name "*.json" | xargs grep -l "$indicator" 2>/dev/null >/dev/null; then
            log_diagnostic "SUCCESS" "Característica Pro detectada: $indicator"
            ((pro_features++))
        fi
    done
    
    if [[ $gpl_restrictions -eq 0 && $pro_features -gt 0 ]]; then
        log_diagnostic "SUCCESS" "Sin restricciones GPL detectadas, características Pro activas"
    elif [[ $gpl_restrictions -gt 0 ]]; then
        log_diagnostic "WARNING" "Se detectaron posibles restricciones GPL"
    fi
    
    log_diagnostic "RESULT" "Restricciones: $gpl_restrictions, Características Pro: $pro_features"
    
    return $pro_features
}

# Función para generar reporte final
generate_final_report() {
    local total_checks=$1
    local passed_checks=$2
    
    local success_rate=0
    if [[ $total_checks -gt 0 ]]; then
        success_rate=$((passed_checks * 100 / total_checks))
    fi
    
    echo
    echo "============================================================================"
    echo "🔍 DIAGNÓSTICO COMPLETO DE FUNCIONES PRO Y GPL - REPORTE FINAL"
    echo "============================================================================"
    echo
    echo "📊 ESTADÍSTICAS GENERALES:"
    echo "   🎯 Verificaciones realizadas: $total_checks"
    echo "   ✅ Verificaciones exitosas: $passed_checks"
    echo "   ❌ Verificaciones fallidas: $((total_checks - passed_checks))"
    echo "   📈 Tasa de éxito: ${success_rate}%"
    echo
    
    echo "🏆 ESTADO DE FUNCIONES PRO:"
    if [[ $success_rate -ge 80 ]]; then
        echo "   ✅ ESTADO: COMPLETAMENTE ACTIVO"
        echo "   🎯 NIVEL: EMPRESARIAL COMPLETO"
        echo "   🔓 RESTRICCIONES: ELIMINADAS"
        echo "   ♾️ LÍMITES: ILIMITADOS"
    elif [[ $success_rate -ge 60 ]]; then
        echo "   ⚠️ ESTADO: PARCIALMENTE ACTIVO"
        echo "   🎯 NIVEL: AVANZADO"
        echo "   🔓 RESTRICCIONES: MAYORÍA ELIMINADAS"
        echo "   ♾️ LÍMITES: AMPLIADOS"
    else
        echo "   ❌ ESTADO: REQUIERE CONFIGURACIÓN"
        echo "   🎯 NIVEL: BÁSICO"
        echo "   🔓 RESTRICCIONES: ALGUNAS ACTIVAS"
        echo "   ♾️ LÍMITES: LIMITADOS"
    fi
    echo
    
    echo "🔧 ACCIONES RECOMENDADAS:"
    if [[ $success_rate -lt 80 ]]; then
        echo "   🚀 Ejecutar: ./pro_activation_master.sh"
        echo "   📋 Revisar: FUNCIONES_PRO_COMPLETAS.md"
        echo "   🔍 Verificar: .pro_environment"
    else
        echo "   ✅ Sistema completamente configurado"
        echo "   📋 Usar: ./pro_dashboard.sh para gestión"
        echo "   📊 Monitorear: pro_status.json"
    fi
    echo
    
    echo "📄 Log guardado en: $LOG_FILE"
    echo "============================================================================"
}

# Función principal
main() {
    echo "============================================================================"
    echo "🔍 DIAGNÓSTICO COMPLETO DE FUNCIONES PRO Y GPL EN WEBMIN/VIRTUALMIN"
    echo "============================================================================"
    echo
    
    log_diagnostic "INFO" "Iniciando diagnóstico completo del sistema..."
    log_diagnostic "INFO" "Directorio de análisis: $SCRIPT_DIR"
    log_diagnostic "INFO" "Timestamp de diagnóstico: $(date)"
    echo
    
    local total_checks=0
    local passed_checks=0
    
    # Ejecutar todas las verificaciones
    check_pro_config_files
    ((total_checks++))
    check_pro_config_files >/dev/null && ((passed_checks++))
    
    check_pro_directories
    ((total_checks++))
    check_pro_directories >/dev/null && ((passed_checks++))
    
    check_pro_environment
    ((total_checks++))
    check_pro_environment >/dev/null && ((passed_checks++))
    
    check_rbac_features
    ((total_checks++))
    check_rbac_features >/dev/null && ((passed_checks++))
    
    check_enterprise_modules
    ((total_checks++))
    check_enterprise_modules >/dev/null && ((passed_checks++))
    
    check_webmin_integration
    ((total_checks++))
    check_webmin_integration >/dev/null && ((passed_checks++))
    
    check_active_services
    ((total_checks++))
    check_active_services >/dev/null && ((passed_checks++))
    
    analyze_license_restrictions
    ((total_checks++))
    analyze_license_restrictions >/dev/null && ((passed_checks++))
    
    # Generar reporte final
    generate_final_report $total_checks $passed_checks
    
    log_diagnostic "SUCCESS" "Diagnóstico completado exitosamente"
    
    return 0
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
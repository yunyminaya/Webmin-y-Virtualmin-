#!/bin/bash

# Sistema de Auditoría de Seguridad Simplificado
# Compatible con macOS y Linux

set -euo pipefail

# Configuración de auditoría
AUDIT_LOG="security_audit_$(date +%Y%m%d_%H%M%S).log"
AUDIT_REPORT="security_audit_report_$(date +%Y%m%d_%H%M%S).txt"

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Contadores
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Función de logging
log_audit() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$AUDIT_LOG"
}

# Función para registrar resultados
check_result() {
    local check_name="$1"
    local status="$2"
    local details="$3"
    local severity="$4" # CRITICAL, HIGH, MEDIUM, LOW
    
    ((TOTAL_CHECKS++))
    
    case $status in
        "PASS")
            ((PASSED_CHECKS++))
            echo -e "${GREEN}✅ PASS${NC}: $check_name"
            log_audit "INFO" "PASS: $check_name - $details"
            echo "PASS: $check_name - $details [$severity]" >> "$AUDIT_REPORT"
            ;;
        "FAIL")
            ((FAILED_CHECKS++))
            echo -e "${RED}❌ FAIL${NC}: $check_name ($severity)"
            log_audit "CRITICAL" "FAIL: $check_name - $details [$severity]"
            echo "FAIL: $check_name - $details [$severity]" >> "$AUDIT_REPORT"
            ;;
        "WARN")
            ((WARNING_CHECKS++))
            echo -e "${YELLOW}⚠️  WARN${NC}: $check_name ($severity)"
            log_audit "WARNING" "WARN: $check_name - $details [$severity]"
            echo "WARN: $check_name - $details [$severity]" >> "$AUDIT_REPORT"
            ;;
    esac
}

# Función para inicializar auditoría
init_audit() {
    echo "=== Iniciando Auditoría de Seguridad Completa ==="
    echo "Fecha: $(date)"
    echo "Sistema: $(uname -a)"
    echo "Usuario: $(whoami)"
    echo ""
    
    log_audit "INFO" "Iniciando auditoría de seguridad completa"
    
    # Inicializar reporte
    echo "AUDITORÍA DE SEGURIDAD - WEBMIN/VIRTUALMIN" > "$AUDIT_REPORT"
    echo "Fecha: $(date)" >> "$AUDIT_REPORT"
    echo "Sistema: $(uname -a)" >> "$AUDIT_REPORT"
    echo "Usuario: $(whoami)" >> "$AUDIT_REPORT"
    echo "========================================" >> "$AUDIT_REPORT"
    echo "" >> "$AUDIT_REPORT"
}

# 1. Auditoría de Sistema de Credenciales
audit_credentials_system() {
    echo -e "\n${BLUE}🔐 Auditoría de Sistema de Credenciales${NC}"
    log_audit "INFO" "Iniciando auditoría de sistema de credenciales"
    
    # Verificar existencia del sistema
    if [ -f "lib/secure_credentials_test.sh" ]; then
        check_result "Sistema de Credenciales Presente" "PASS" "Archivo lib/secure_credentials_test.sh encontrado" "LOW"
    else
        check_result "Sistema de Credenciales Presente" "FAIL" "Archivo lib/secure_credentials_test.sh no encontrado" "CRITICAL"
        return
    fi
    
    # Verificar permisos del script
    if [ -f "lib/secure_credentials_test.sh" ]; then
        local script_perms=$(stat -f "%A" "lib/secure_credentials_test.sh" 2>/dev/null || stat -c "%a" "lib/secure_credentials_test.sh" 2>/dev/null || echo "000")
        if [ "$script_perms" = "755" ] || [ "$script_perms" = "700" ]; then
            check_result "Permisos de Script de Credenciales" "PASS" "Permisos correctos: $script_perms" "LOW"
        else
            check_result "Permisos de Script de Credenciales" "WARN" "Permisos inseguros: $script_perms" "MEDIUM"
        fi
    fi
    
    # Verificar dependencias
    if command -v openssl >/dev/null 2>&1; then
        check_result "OpenSSL Disponible" "PASS" "OpenSSL está instalado y disponible" "LOW"
    else
        check_result "OpenSSL Disponible" "FAIL" "OpenSSL no está instalado" "CRITICAL"
    fi
    
    # Ejecutar pruebas automatizadas
    if [ -f "test_credentials_simple.sh" ]; then
        log_audit "INFO" "Ejecutando pruebas automatizadas del sistema de credenciales"
        
        # Ejecutar pruebas en modo silencioso
        if bash test_credentials_simple.sh >/dev/null 2>&1; then
            check_result "Pruebas Automatizadas de Credenciales" "PASS" "Todas las pruebas pasaron exitosamente" "LOW"
        else
            check_result "Pruebas Automatizadas de Credenciales" "FAIL" "Algunas pruebas fallaron" "HIGH"
        fi
    else
        check_result "Pruebas Automatizadas de Credenciales" "WARN" "Archivo de pruebas no encontrado" "MEDIUM"
    fi
}

# 2. Auditoría de Seguridad de Scripts
audit_scripts_security() {
    echo -e "\n${BLUE}📜 Auditoría de Seguridad de Scripts${NC}"
    log_audit "INFO" "Iniciando auditoría de seguridad de scripts"
    
    # Buscar scripts con permisos inseguros
    local insecure_scripts=()
    while IFS= read -r script; do
        if [ -f "$script" ]; then
            local perms=$(stat -f "%A" "$script" 2>/dev/null || stat -c "%a" "$script" 2>/dev/null || echo "000")
            if [[ "$perms" =~ [2367][4567][4567] ]]; then
                insecure_scripts+=("$script ($perms)")
            fi
        fi
    done < <(find . -name "*.sh" -type f 2>/dev/null)
    
    if [ ${#insecure_scripts[@]} -eq 0 ]; then
        check_result "Permisos de Scripts" "PASS" "No se encontraron scripts con permisos inseguros" "LOW"
    else
        check_result "Permisos de Scripts" "WARN" "Se encontraron ${#insecure_scripts[@]} scripts con permisos inseguros" "MEDIUM"
    fi
    
    # Buscar contraseñas en texto plano
    local plaintext_passwords=()
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            if grep -qi "password\|passwd\|secret" "$file" 2>/dev/null; then
                if grep -qE "(password|passwd|secret)\s*=\s*['\"][^'\"]+['\"]" "$file" 2>/dev/null; then
                    plaintext_passwords+=("$file")
                fi
            fi
        fi
    done < <(find . -name "*.sh" -o -name "*.conf" -o -name "*.cfg" -type f 2>/dev/null)
    
    if [ ${#plaintext_passwords[@]} -eq 0 ]; then
        check_result "Contraseñas en Texto Plano" "PASS" "No se encontraron contraseñas en texto plano" "LOW"
    else
        check_result "Contraseñas en Texto Plano" "FAIL" "Se encontraron ${#plaintext_passwords[@]} archivos con posibles contraseñas en texto plano" "CRITICAL"
    fi
}

# 3. Auditoría de Configuración de Firewall
audit_firewall_security() {
    echo -e "\n${BLUE}🛡️ Auditoría de Configuración de Firewall${NC}"
    log_audit "INFO" "Iniciando auditoría de configuración de firewall"
    
    # Verificar sistema de firewall inteligente
    if [ -f "intelligent-firewall/init_firewall.pl" ]; then
        check_result "Sistema de Firewall Inteligente" "PASS" "Módulo de firewall inteligente encontrado" "LOW"
        
        # Verificar permisos del script
        local fw_perms=$(stat -f "%A" "intelligent-firewall/init_firewall.pl" 2>/dev/null || stat -c "%a" "intelligent-firewall/init_firewall.pl" 2>/dev/null || echo "000")
        if [ "$fw_perms" = "755" ] || [ "$fw_perms" = "700" ]; then
            check_result "Permisos de Script de Firewall" "PASS" "Permisos correctos: $fw_perms" "LOW"
        else
            check_result "Permisos de Script de Firewall" "WARN" "Permisos potencialmente inseguros: $fw_perms" "MEDIUM"
        fi
    else
        check_result "Sistema de Firewall Inteligente" "WARN" "Módulo de firewall inteligente no encontrado" "MEDIUM"
    fi
    
    # Verificar reglas de firewall
    if [ -f "intelligent-firewall/smart_lists.pl" ]; then
        check_result "Reglas de Firewall Inteligente" "PASS" "Sistema de reglas inteligentes encontrado" "LOW"
    else
        check_result "Reglas de Firewall Inteligente" "WARN" "Sistema de reglas inteligentes no encontrado" "MEDIUM"
    fi
}

# 4. Auditoría de Sistema SSL/TLS
audit_ssl_security() {
    echo -e "\n${BLUE}🔒 Auditoría de Sistema SSL/TLS${NC}"
    log_audit "INFO" "Iniciando auditoría de sistema SSL/TLS"
    
    # Verificar configuración SSL
    if [ -f "advanced_ssl_manager.sh" ]; then
        check_result "Gestor SSL Avanzado" "PASS" "Sistema de gestión SSL encontrado" "LOW"
        
        # Verificar permisos
        local ssl_perms=$(stat -f "%A" "advanced_ssl_manager.sh" 2>/dev/null || stat -c "%a" "advanced_ssl_manager.sh" 2>/dev/null || echo "000")
        if [ "$ssl_perms" = "755" ] || [ "$ssl_perms" = "700" ]; then
            check_result "Permisos de Gestor SSL" "PASS" "Permisos correctos: $ssl_perms" "LOW"
        else
            check_result "Permisos de Gestor SSL" "WARN" "Permisos potencialmente inseguros: $ssl_perms" "MEDIUM"
        fi
    else
        check_result "Gestor SSL Avanzado" "WARN" "Sistema de gestión SSL no encontrado" "MEDIUM"
    fi
    
    # Verificar configuraciones SSL
    local ssl_configs=("configs/apache/httpd.conf" "nginx_ssl.conf" "postfix_ssl.conf" "dovecot_ssl.conf")
    local found_configs=0
    
    for config in "${ssl_configs[@]}"; do
        if [ -f "$config" ]; then
            ((found_configs++))
        fi
    done
    
    if [ $found_configs -gt 0 ]; then
        check_result "Configuraciones SSL" "PASS" "Se encontraron $found_configs configuraciones SSL" "LOW"
    else
        check_result "Configuraciones SSL" "WARN" "No se encontraron configuraciones SSL" "MEDIUM"
    fi
}

# 5. Auditoría de Sistema de Monitoreo
audit_monitoring_security() {
    echo -e "\n${BLUE}📊 Auditoría de Sistema de Monitoreo${NC}"
    log_audit "INFO" "Iniciando auditoría de sistema de monitoreo"
    
    # Verificar sistema de monitoreo avanzado
    if [ -f "advanced_monitoring.sh" ]; then
        check_result "Sistema de Monitoreo Avanzado" "PASS" "Sistema de monitoreo avanzado encontrado" "LOW"
        
        # Verificar permisos
        local mon_perms=$(stat -f "%A" "advanced_monitoring.sh" 2>/dev/null || stat -c "%a" "advanced_monitoring.sh" 2>/dev/null || echo "000")
        if [ "$mon_perms" = "755" ] || [ "$mon_perms" = "700" ]; then
            check_result "Permisos de Monitoreo" "PASS" "Permisos correctos: $mon_perms" "LOW"
        else
            check_result "Permisos de Monitoreo" "WARN" "Permisos potencialmente inseguros: $mon_perms" "MEDIUM"
        fi
    else
        check_result "Sistema de Monitoreo Avanzado" "WARN" "Sistema de monitoreo avanzado no encontrado" "MEDIUM"
    fi
    
    # Verificar dashboards
    if [ -f "devops-dashboard.html" ] || [ -f "devops-dashboard.cgi" ]; then
        check_result "Dashboards de Monitoreo" "PASS" "Dashboards de monitoreo encontrados" "LOW"
    else
        check_result "Dashboards de Monitoreo" "WARN" "Dashboards de monitoreo no encontrados" "MEDIUM"
    fi
}

# 6. Auditoría de Sistema de Respaldos
audit_backup_security() {
    echo -e "\n${BLUE}💾 Auditoría de Sistema de Respaldos${NC}"
    log_audit "INFO" "Iniciando auditoría de sistema de respaldos"
    
    # Verificar sistema de respaldos inteligente
    if [ -f "intelligent_backup_system/core/backup_engine.py" ]; then
        check_result "Sistema de Respaldos Inteligente" "PASS" "Sistema de respaldos inteligente encontrado" "LOW"
        
        # Verificar permisos
        local backup_perms=$(stat -f "%A" "intelligent_backup_system/core/backup_engine.py" 2>/dev/null || stat -c "%a" "intelligent_backup_system/core/backup_engine.py" 2>/dev/null || echo "000")
        if [ "$backup_perms" = "755" ] || [ "$backup_perms" = "644" ]; then
            check_result "Permisos de Sistema de Respaldos" "PASS" "Permisos correctos: $backup_perms" "LOW"
        else
            check_result "Permisos de Sistema de Respaldos" "WARN" "Permisos potencialmente inseguros: $backup_perms" "MEDIUM"
        fi
    else
        check_result "Sistema de Respaldos Inteligente" "WARN" "Sistema de respaldos inteligente no encontrado" "MEDIUM"
    fi
    
    # Verificar scripts de respaldo
    local backup_scripts=("auto_backup_system.sh" "enterprise_backup_pro.sh")
    local found_backup_scripts=0
    
    for script in "${backup_scripts[@]}"; do
        if [ -f "$script" ]; then
            ((found_backup_scripts++))
        fi
    done
    
    if [ $found_backup_scripts -gt 0 ]; then
        check_result "Scripts de Respaldo" "PASS" "Se encontraron $found_backup_scripts scripts de respaldo" "LOW"
    else
        check_result "Scripts de Respaldo" "WARN" "No se encontraron scripts de respaldo" "MEDIUM"
    fi
}

# 7. Auditoría de Sistema SIEM
audit_siem_security() {
    echo -e "\n${BLUE}🔍 Auditoría de Sistema SIEM${NC}"
    log_audit "INFO" "Iniciando auditoría de sistema SIEM"
    
    # Verificar sistema SIEM
    if [ -f "siem/correlation_engine.sh" ]; then
        check_result "Sistema SIEM" "PASS" "Sistema SIEM encontrado" "LOW"
        
        # Verificar permisos
        local siem_perms=$(stat -f "%A" "siem/correlation_engine.sh" 2>/dev/null || stat -c "%a" "siem/correlation_engine.sh" 2>/dev/null || echo "000")
        if [ "$siem_perms" = "755" ] || [ "$siem_perms" = "700" ]; then
            check_result "Permisos de Sistema SIEM" "PASS" "Permisos correctos: $siem_perms" "LOW"
        else
            check_result "Permisos de Sistema SIEM" "WARN" "Permisos potencialmente inseguros: $siem_perms" "MEDIUM"
        fi
    else
        check_result "Sistema SIEM" "WARN" "Sistema SIEM no encontrado" "MEDIUM"
    fi
    
    # Verificar componentes SIEM
    local siem_components=("siem/alert_manager.sh" "siem/forensic_analyzer.sh" "siem/report_generator.sh")
    local found_siem_components=0
    
    for component in "${siem_components[@]}"; do
        if [ -f "$component" ]; then
            ((found_siem_components++))
        fi
    done
    
    if [ $found_siem_components -gt 0 ]; then
        check_result "Componentes SIEM" "PASS" "Se encontraron $found_siem_components componentes SIEM" "LOW"
    else
        check_result "Componentes SIEM" "WARN" "No se encontraron componentes SIEM" "MEDIUM"
    fi
}

# 8. Auditoría de AI Defense
audit_ai_defense_security() {
    echo -e "\n${BLUE}🤖 Auditoría de Sistema AI Defense${NC}"
    log_audit "INFO" "Iniciando auditoría de sistema AI Defense"
    
    # Verificar sistema AI Defense
    if [ -f "ai_defense_system.sh" ]; then
        check_result "Sistema AI Defense" "PASS" "Sistema AI Defense encontrado" "LOW"
        
        # Verificar permisos
        local ai_perms=$(stat -f "%A" "ai_defense_system.sh" 2>/dev/null || stat -c "%a" "ai_defense_system.sh" 2>/dev/null || echo "000")
        if [ "$ai_perms" = "755" ] || [ "$ai_perms" = "700" ]; then
            check_result "Permisos de Sistema AI Defense" "PASS" "Permisos correctos: $ai_perms" "LOW"
        else
            check_result "Permisos de Sistema AI Defense" "WARN" "Permisos potencialmente inseguros: $ai_perms" "MEDIUM"
        fi
        
        # Verificar funciones implementadas
        if grep -q "analyze_traffic_patterns" "ai_defense_system.sh"; then
            check_result "Funciones AI Defense Implementadas" "PASS" "Funciones de análisis implementadas" "LOW"
        else
            check_result "Funciones AI Defense Implementadas" "WARN" "Funciones de análisis no encontradas" "MEDIUM"
        fi
    else
        check_result "Sistema AI Defense" "WARN" "Sistema AI Defense no encontrado" "MEDIUM"
    fi
}

# Función principal de auditoría
main_audit() {
    init_audit
    
    echo -e "${BLUE}🔍 Iniciando Auditoría de Seguridad Completa del Sistema Webmin/Virtualmin${NC}"
    echo "Log de auditoría: $AUDIT_LOG"
    echo "Reporte: $AUDIT_REPORT"
    echo ""
    
    # Ejecutar todas las auditorías
    audit_credentials_system
    audit_scripts_security
    audit_firewall_security
    audit_ssl_security
    audit_monitoring_security
    audit_backup_security
    audit_siem_security
    audit_ai_defense_security
    
    # Mostrar resumen final
    echo -e "\n${BLUE}📊 Resumen Final de Auditoría${NC}"
    echo "=================================="
    echo "Total de verificaciones: $TOTAL_CHECKS"
    echo -e "Pruebas pasadas: ${GREEN}$PASSED_CHECKS${NC}"
    echo -e "Advertencias: ${YELLOW}$WARNING_CHECKS${NC}"
    echo -e "Pruebas fallidas: ${RED}$FAILED_CHECKS${NC}"
    
    # Calcular puntuación de seguridad
    local security_score=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
    echo "Puntuación de seguridad: $security_score/100"
    
    if [ $security_score -ge 90 ]; then
        echo -e "${GREEN}🎉 Nivel de Seguridad: EXCELENTE${NC}"
    elif [ $security_score -ge 75 ]; then
        echo -e "${GREEN}✅ Nivel de Seguridad: BUENO${NC}"
    elif [ $security_score -ge 60 ]; then
        echo -e "${YELLOW}⚠️  Nivel de Seguridad: REGULAR${NC}"
    else
        echo -e "${RED}❌ Nivel de Seguridad: CRÍTICO${NC}"
    fi
    
    echo ""
    echo "Reporte detallado generado: $AUDIT_REPORT"
    echo "Log de auditoría: $AUDIT_LOG"
    
    # Agregar resumen al reporte
    echo "" >> "$AUDIT_REPORT"
    echo "RESUMEN DE AUDITORÍA" >> "$AUDIT_REPORT"
    echo "===================" >> "$AUDIT_REPORT"
    echo "Total de verificaciones: $TOTAL_CHECKS" >> "$AUDIT_REPORT"
    echo "Pruebas pasadas: $PASSED_CHECKS" >> "$AUDIT_REPORT"
    echo "Advertencias: $WARNING_CHECKS" >> "$AUDIT_REPORT"
    echo "Pruebas fallidas: $FAILED_CHECKS" >> "$AUDIT_REPORT"
    echo "Puntuación de seguridad: $security_score/100" >> "$AUDIT_REPORT"
    
    log_audit "INFO" "Auditoría de seguridad completada. Puntuación: $security_score/100"
    
    # Retornar código de salida basado en resultados
    if [ $FAILED_CHECKS -gt 0 ]; then
        return 2  # CRITICAL
    elif [ $WARNING_CHECKS -gt 0 ]; then
        return 1  # WARNING
    else
        return 0  # OK
    fi
}

# Ejecutar auditoría principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_audit "$@"
fi
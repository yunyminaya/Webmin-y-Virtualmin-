#!/bin/bash

# Sistema de Auditoría de Seguridad Completa
# Para el proyecto Webmin/Virtualmin mejorado

set -euo pipefail

# Configuración de auditoría
AUDIT_LOG="security_audit_$(date +%Y%m%d_%H%M%S).log"
AUDIT_REPORT="security_audit_report_$(date +%Y%m%d_%H%M%S).html"
TEMP_DIR="/tmp/security_audit_$$"

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
            ;;
        "FAIL")
            ((FAILED_CHECKS++))
            echo -e "${RED}❌ FAIL${NC}: $check_name ($severity)"
            log_audit "CRITICAL" "FAIL: $check_name - $details [$severity]"
            ;;
        "WARN")
            ((WARNING_CHECKS++))
            echo -e "${YELLOW}⚠️  WARN${NC}: $check_name ($severity)"
            log_audit "WARNING" "WARN: $check_name - $details [$severity]"
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
    
    # Crear directorio temporal
    mkdir -p "$TEMP_DIR"
    
    # Inicializar reporte HTML
    cat > "$AUDIT_REPORT" << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Auditoría de Seguridad - Webmin/Virtualmin</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; border-bottom: 2px solid #007bff; padding-bottom: 20px; margin-bottom: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .summary-card { background: #f8f9fa; padding: 20px; border-radius: 8px; text-align: center; border-left: 4px solid #007bff; }
        .pass { border-left-color: #28a745; color: #28a745; }
        .fail { border-left-color: #dc3545; color: #dc3545; }
        .warn { border-left-color: #ffc107; color: #ffc107; }
        .check-item { margin-bottom: 15px; padding: 15px; border-radius: 5px; border-left: 4px solid #ddd; }
        .check-pass { background: #d4edda; border-left-color: #28a745; }
        .check-fail { background: #f8d7da; border-left-color: #dc3545; }
        .check-warn { background: #fff3cd; border-left-color: #ffc107; }
        .severity { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 12px; font-weight: bold; color: white; }
        .critical { background: #dc3545; }
        .high { background: #fd7e14; }
        .medium { background: #ffc107; color: #212529; }
        .low { background: #28a745; }
        .details { margin-top: 10px; font-size: 14px; color: #666; }
        .recommendations { background: #e9ecef; padding: 20px; border-radius: 8px; margin-top: 30px; }
        h1, h2, h3 { color: #333; }
        .timestamp { color: #666; font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔒 Auditoría de Seguridad Completa</h1>
            <p class="timestamp">Generado: $(date)</p>
            <p>Sistema: Webmin/Virtualmin Mejorado</p>
        </div>
        
        <div class="summary" id="summary">
            <!-- Se actualizará dinámicamente -->
        </div>
        
        <h2>📋 Resultados Detallados</h2>
        <div id="results">
            <!-- Se actualizará dinámicamente -->
        </div>
        
        <div class="recommendations">
            <h2>💡 Recomendaciones de Seguridad</h2>
            <div id="recommendations">
                <!-- Se actualizará dinámicamente -->
            </div>
        </div>
    </div>
</body>
</html>
EOF
}

# Función para actualizar reporte HTML
update_html_report() {
    local check_name="$1"
    local status="$2"
    local details="$3"
    local severity="$4"
    local recommendation="$5"
    
    local status_class="check-$(echo "$status" | tr '[:upper:]' '[:lower:]')"
    local severity_class="$(echo "$severity" | tr '[:upper:]' '[:lower:]')"
    
    # Escapar HTML
    local escaped_name=$(echo "$check_name" | sed 's/&/\&/g; s/</\</g; s/>/\>/g')
    local escaped_details=$(echo "$details" | sed 's/&/\&/g; s/</\</g; s/>/\>/g')
    local escaped_recommendation=$(echo "$recommendation" | sed 's/&/\&/g; s/</\</g; s/>/\>/g')
    
    # Insertar en el reporte
    sed -i "/<div id=\"results\">/a\\
            <div class=\"check-item $status_class\">\\
                <h3>$escaped_name</h3>\\
                <span class=\"severity $severity_class\">$severity</span>\\
                <div class=\"details\">$escaped_details</div>\\
                $([ -n \"$recommendation\" ] && echo \"<div class=\"details\"><strong>Recomendación:</strong> $escaped_recommendation</div>\")\\
            </div>" "$AUDIT_REPORT"
}

# Función para finalizar reporte HTML
finalize_html_report() {
    # Actualizar resumen
    local summary_html="
        <div class=\"summary-card pass\">
            <h3>$PASSED_CHECKS</h3>
            <p>Pruebas Pasadas</p>
        </div>
        <div class=\"summary-card fail\">
            <h3>$FAILED_CHECKS</h3>
            <p>Pruebas Fallidas</p>
        </div>
        <div class=\"summary-card warn\">
            <h3>$WARNING_CHECKS</h3>
            <p>Advertencias</p>
        </div>
        <div class=\"summary-card\">
            <h3>$TOTAL_CHECKS</h3>
            <p>Total de Pruebas</p>
        </div>"
    
    sed -i "s|<div id=\"summary\">.*</div>|$summary_html|" "$AUDIT_REPORT"
    
    # Cerrar HTML
    sed -i '/<div id="recommendations">/a\\
            <p>Auditoría completada. Revisar los resultados detallados arriba.</p>' "$AUDIT_REPORT"
}

# 1. Auditoría de Sistema de Credenciales
audit_credentials_system() {
    echo -e "\n${BLUE}🔐 Auditoría de Sistema de Credenciales${NC}"
    log_audit "INFO" "Iniciando auditoría de sistema de credenciales"
    
    # Verificar existencia del sistema
    if [ -f "lib/secure_credentials_test.sh" ]; then
        check_result "Sistema de Credenciales Presente" "PASS" "Archivo lib/secure_credentials_test.sh encontrado" "LOW"
        update_html_report "Sistema de Credenciales Presente" "PASS" "El sistema de gestión de credenciales está presente en el proyecto" "LOW" ""
    else
        check_result "Sistema de Credenciales Presente" "FAIL" "Archivo lib/secure_credentials_test.sh no encontrado" "CRITICAL"
        update_html_report "Sistema de Credenciales Presente" "FAIL" "El sistema de gestión de credenciales no está presente" "CRITICAL" "Implementar el sistema de gestión segura de credenciales"
        return
    fi
    
    # Verificar permisos del script
    local script_perms=$(stat -c "%a" "lib/secure_credentials_test.sh" 2>/dev/null || echo "000")
    if [ "$script_perms" = "755" ] || [ "$script_perms" = "700" ]; then
        check_result "Permisos de Script de Credenciales" "PASS" "Permisos correctos: $script_perms" "LOW"
        update_html_report "Permisos de Script de Credenciales" "PASS" "El script tiene permisos seguros: $script_perms" "LOW" ""
    else
        check_result "Permisos de Script de Credenciales" "WARN" "Permisos inseguros: $script_perms" "MEDIUM"
        update_html_report "Permisos de Script de Credenciales" "WARN" "El script tiene permisos potencialmente inseguros: $script_perms" "MEDIUM" "Ejecutar: chmod 755 lib/secure_credentials_test.sh"
    fi
    
    # Verificar dependencias
    if command -v openssl >/dev/null 2>&1; then
        check_result "OpenSSL Disponible" "PASS" "OpenSSL está instalado y disponible" "LOW"
        update_html_report "OpenSSL Disponible" "PASS" "OpenSSL está disponible para operaciones criptográficas" "LOW" ""
    else
        check_result "OpenSSL Disponible" "FAIL" "OpenSSL no está instalado" "CRITICAL"
        update_html_report "OpenSSL Disponible" "FAIL" "OpenSSL no está disponible, afectando el cifrado" "CRITICAL" "Instalar OpenSSL: apt-get install openssl o yum install openssl"
    fi
    
    # Ejecutar pruebas automatizadas
    if [ -f "test_credentials_simple.sh" ]; then
        log_audit "INFO" "Ejecutando pruebas automatizadas del sistema de credenciales"
        
        # Ejecutar pruebas en modo silencioso
        if bash test_credentials_simple.sh >/dev/null 2>&1; then
            check_result "Pruebas Automatizadas de Credenciales" "PASS" "Todas las pruebas pasaron exitosamente" "LOW"
            update_html_report "Pruebas Automatizadas de Credenciales" "PASS" "El sistema de credenciales pasó todas las pruebas automatizadas" "LOW" ""
        else
            check_result "Pruebas Automatizadas de Credenciales" "FAIL" "Algunas pruebas fallaron" "HIGH"
            update_html_report "Pruebas Automatizadas de Credenciales" "FAIL" "El sistema de credenciales tiene pruebas fallidas" "HIGH" "Revisar y corregir las pruebas fallidas del sistema de credenciales"
        fi
    else
        check_result "Pruebas Automatizadas de Credenciales" "WARN" "Archivo de pruebas no encontrado" "MEDIUM"
        update_html_report "Pruebas Automatizadas de Credenciales" "WARN" "No se encontró el archivo de pruebas automatizadas" "MEDIUM" "Implementar pruebas automatizadas para el sistema de credenciales"
    fi
}

# 2. Auditoría de Seguridad de Scripts
audit_scripts_security() {
    echo -e "\n${BLUE}📜 Auditoría de Seguridad de Scripts${NC}"
    log_audit "INFO" "Iniciando auditoría de seguridad de scripts"
    
    # Buscar scripts con permisos inseguros
    local insecure_scripts=()
    while IFS= read -r -d '' script; do
        local perms=$(stat -c "%a" "$script")
        if [[ "$perms" =~ [2367][4567][4567] ]]; then
            insecure_scripts+=("$script ($perms)")
        fi
    done < <(find . -name "*.sh" -type f -print0 2>/dev/null)
    
    if [ ${#insecure_scripts[@]} -eq 0 ]; then
        check_result "Permisos de Scripts" "PASS" "No se encontraron scripts con permisos inseguros" "LOW"
        update_html_report "Permisos de Scripts" "PASS" "Todos los scripts tienen permisos seguros" "LOW" ""
    else
        check_result "Permisos de Scripts" "WARN" "Se encontraron ${#insecure_scripts[@]} scripts con permisos inseguros" "MEDIUM"
        local details="Scripts con permisos inseguros: $(IFS=', '; echo "${insecure_scripts[*]}")"
        update_html_report "Permisos de Scripts" "WARN" "$details" "MEDIUM" "Corregir permisos de scripts: chmod 755 script.sh"
    fi
    
    # Buscar contraseñas en texto plano
    local plaintext_passwords=()
    while IFS= read -r -d '' file; do
        if grep -qi "password\|passwd\|secret" "$file" 2>/dev/null; then
            if grep -qE "(password|passwd|secret)\s*=\s*['\"][^'\"]+['\"]" "$file" 2>/dev/null; then
                plaintext_passwords+=("$file")
            fi
        fi
    done < <(find . -name "*.sh" -o -name "*.conf" -o -name "*.cfg" -type f -print0 2>/dev/null)
    
    if [ ${#plaintext_passwords[@]} -eq 0 ]; then
        check_result "Contraseñas en Texto Plano" "PASS" "No se encontraron contraseñas en texto plano" "LOW"
        update_html_report "Contraseñas en Texto Plano" "PASS" "No se detectaron contraseñas almacenadas en texto plano" "LOW" ""
    else
        check_result "Contraseñas en Texto Plano" "FAIL" "Se encontraron ${#plaintext_passwords[@]} archivos con posibles contraseñas en texto plano" "CRITICAL"
        local details="Archivos con posibles contraseñas: $(IFS=', '; echo "${plaintext_passwords[*]}")"
        update_html_report "Contraseñas en Texto Plano" "FAIL" "$details" "CRITICAL" "Mover contraseñas al sistema de gestión segura de credenciales"
    fi
    
    # Verificar uso de variables sin comillas
    local unquoted_vars=()
    while IFS= read -r -d '' script; do
        if grep -qE '\$[A-Za-z_][A-Za-z0-9_]*\s' "$script" 2>/dev/null; then
            if grep -qvE '#.*\$[A-Za-z_][A-Za-z0-9_]*\s' "$script" 2>/dev/null; then
                unquoted_vars+=("$script")
            fi
        fi
    done < <(find . -name "*.sh" -type f -print0 2>/dev/null)
    
    if [ ${#unquoted_vars[@]} -eq 0 ]; then
        check_result "Variables Sin Comillas" "PASS" "No se encontraron variables potencialmente inseguras sin comillas" "LOW"
        update_html_report "Variables Sin Comillas" "PASS" "Las variables están correctamente citadas" "LOW" ""
    else
        check_result "Variables Sin Comillas" "WARN" "Se encontraron ${#unquoted_vars[@]} scripts con posibles variables sin comillas" "MEDIUM"
        local details="Scripts con posibles variables sin comillas: $(IFS=', '; echo "${unquoted_vars[*]}")"
        update_html_report "Variables Sin Comillas" "WARN" "$details" "MEDIUM" "Revisar y citar correctamente las variables en los scripts"
    fi
}

# 3. Auditoría de Configuración de Firewall
audit_firewall_security() {
    echo -e "\n${BLUE}🛡️ Auditoría de Configuración de Firewall${NC}"
    log_audit "INFO" "Iniciando auditoría de configuración de firewall"
    
    # Verificar sistema de firewall inteligente
    if [ -f "intelligent-firewall/init_firewall.pl" ]; then
        check_result "Sistema de Firewall Inteligente" "PASS" "Módulo de firewall inteligente encontrado" "LOW"
        update_html_report "Sistema de Firewall Inteligente" "PASS" "El sistema incluye un módulo de firewall inteligente" "LOW" ""
        
        # Verificar permisos del script
        local fw_perms=$(stat -c "%a" "intelligent-firewall/init_firewall.pl" 2>/dev/null || echo "000")
        if [ "$fw_perms" = "755" ] || [ "$fw_perms" = "700" ]; then
            check_result "Permisos de Script de Firewall" "PASS" "Permisos correctos: $fw_perms" "LOW"
            update_html_report "Permisos de Script de Firewall" "PASS" "El script de firewall tiene permisos seguros" "LOW" ""
        else
            check_result "Permisos de Script de Firewall" "WARN" "Permisos potencialmente inseguros: $fw_perms" "MEDIUM"
            update_html_report "Permisos de Script de Firewall" "WARN" "El script de firewall tiene permisos inseguros" "MEDIUM" "Corregir permisos: chmod 755 intelligent-firewall/init_firewall.pl"
        fi
    else
        check_result "Sistema de Firewall Inteligente" "WARN" "Módulo de firewall inteligente no encontrado" "MEDIUM"
        update_html_report "Sistema de Firewall Inteligente" "WARN" "No se encontró el módulo de firewall inteligente" "MEDIUM" "Implementar el sistema de firewall inteligente"
    fi
    
    # Verificar reglas de firewall
    if [ -f "intelligent-firewall/smart_lists.pl" ]; then
        check_result "Reglas de Firewall Inteligente" "PASS" "Sistema de reglas inteligentes encontrado" "LOW"
        update_html_report "Reglas de Firewall Inteligente" "PASS" "El sistema incluye reglas de firewall dinámicas" "LOW" ""
    else
        check_result "Reglas de Firewall Inteligente" "WARN" "Sistema de reglas inteligentes no encontrado" "MEDIUM"
        update_html_report "Reglas de Firewall Inteligente" "WARN" "No se encontró el sistema de reglas inteligentes" "MEDIUM" "Implementar reglas de firewall dinámicas"
    fi
}

# 4. Auditoría de Sistema SSL/TLS
audit_ssl_security() {
    echo -e "\n${BLUE}🔒 Auditoría de Sistema SSL/TLS${NC}"
    log_audit "INFO" "Iniciando auditoría de sistema SSL/TLS"
    
    # Verificar configuración SSL
    if [ -f "advanced_ssl_manager.sh" ]; then
        check_result "Gestor SSL Avanzado" "PASS" "Sistema de gestión SSL encontrado" "LOW"
        update_html_report "Gestor SSL Avanzado" "PASS" "El sistema incluye un gestor SSL avanzado" "LOW" ""
        
        # Verificar permisos
        local ssl_perms=$(stat -c "%a" "advanced_ssl_manager.sh" 2>/dev/null || echo "000")
        if [ "$ssl_perms" = "755" ] || [ "$ssl_perms" = "700" ]; then
            check_result "Permisos de Gestor SSL" "PASS" "Permisos correctos: $ssl_perms" "LOW"
            update_html_report "Permisos de Gestor SSL" "PASS" "El gestor SSL tiene permisos seguros" "LOW" ""
        else
            check_result "Permisos de Gestor SSL" "WARN" "Permisos potencialmente inseguros: $ssl_perms" "MEDIUM"
            update_html_report "Permisos de Gestor SSL" "WARN" "El gestor SSL tiene permisos inseguros" "MEDIUM" "Corregir permisos: chmod 755 advanced_ssl_manager.sh"
        fi
    else
        check_result "Gestor SSL Avanzado" "WARN" "Sistema de gestión SSL no encontrado" "MEDIUM"
        update_html_report "Gestor SSL Avanzado" "WARN" "No se encontró el sistema de gestión SSL" "MEDIUM" "Implementar el gestor SSL avanzado"
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
        update_html_report "Configuraciones SSL" "PASS" "Se encontraron $found_configs archivos de configuración SSL" "LOW" ""
    else
        check_result "Configuraciones SSL" "WARN" "No se encontraron configuraciones SSL" "MEDIUM"
        update_html_report "Configuraciones SSL" "WARN" "No se encontraron archivos de configuración SSL" "MEDIUM" "Implementar configuraciones SSL para los servicios"
    fi
}

# 5. Auditoría de Sistema de Monitoreo
audit_monitoring_security() {
    echo -e "\n${BLUE}📊 Auditoría de Sistema de Monitoreo${NC}"
    log_audit "INFO" "Iniciando auditoría de sistema de monitoreo"
    
    # Verificar sistema de monitoreo avanzado
    if [ -f "advanced_monitoring.sh" ]; then
        check_result "Sistema de Monitoreo Avanzado" "PASS" "Sistema de monitoreo avanzado encontrado" "LOW"
        update_html_report "Sistema de Monitoreo Avanzado" "PASS" "El sistema incluye monitoreo avanzado" "LOW" ""
        
        # Verificar permisos
        local mon_perms=$(stat -c "%a" "advanced_monitoring.sh" 2>/dev/null || echo "000")
        if [ "$mon_perms" = "755" ] || [ "$mon_perms" = "700" ]; then
            check_result "Permisos de Monitoreo" "PASS" "Permisos correctos: $mon_perms" "LOW"
            update_html_report "Permisos de Monitoreo" "PASS" "El script de monitoreo tiene permisos seguros" "LOW" ""
        else
            check_result "Permisos de Monitoreo" "WARN" "Permisos potencialmente inseguros: $mon_perms" "MEDIUM"
            update_html_report "Permisos de Monitoreo" "WARN" "El script de monitoreo tiene permisos inseguros" "MEDIUM" "Corregir permisos: chmod 755 advanced_monitoring.sh"
        fi
    else
        check_result "Sistema de Monitoreo Avanzado" "WARN" "Sistema de monitoreo avanzado no encontrado" "MEDIUM"
        update_html_report "Sistema de Monitoreo Avanzado" "WARN" "No se encontró el sistema de monitoreo avanzado" "MEDIUM" "Implementar el sistema de monitoreo avanzado"
    fi
    
    # Verificar dashboards
    if [ -f "devops-dashboard.html" ] || [ -f "devops-dashboard.cgi" ]; then
        check_result "Dashboards de Monitoreo" "PASS" "Dashboards de monitoreo encontrados" "LOW"
        update_html_report "Dashboards de Monitoreo" "PASS" "El sistema incluye dashboards de monitoreo" "LOW" ""
    else
        check_result "Dashboards de Monitoreo" "WARN" "Dashboards de monitoreo no encontrados" "MEDIUM"
        update_html_report "Dashboards de Monitoreo" "WARN" "No se encontraron dashboards de monitoreo" "MEDIUM" "Implementar dashboards de monitoreo"
    fi
}

# 6. Auditoría de Sistema de Respaldos
audit_backup_security() {
    echo -e "\n${BLUE}💾 Auditoría de Sistema de Respaldos${NC}"
    log_audit "INFO" "Iniciando auditoría de sistema de respaldos"
    
    # Verificar sistema de respaldos inteligente
    if [ -f "intelligent_backup_system/core/backup_engine.py" ]; then
        check_result "Sistema de Respaldos Inteligente" "PASS" "Sistema de respaldos inteligente encontrado" "LOW"
        update_html_report "Sistema de Respaldos Inteligente" "PASS" "El sistema incluye respaldos inteligentes" "LOW" ""
        
        # Verificar permisos
        local backup_perms=$(stat -c "%a" "intelligent_backup_system/core/backup_engine.py" 2>/dev/null || echo "000")
        if [ "$backup_perms" = "755" ] || [ "$backup_perms" = "644" ]; then
            check_result "Permisos de Sistema de Respaldos" "PASS" "Permisos correctos: $backup_perms" "LOW"
            update_html_report "Permisos de Sistema de Respaldos" "PASS" "El sistema de respaldos tiene permisos seguros" "LOW" ""
        else
            check_result "Permisos de Sistema de Respaldos" "WARN" "Permisos potencialmente inseguros: $backup_perms" "MEDIUM"
            update_html_report "Permisos de Sistema de Respaldos" "WARN" "El sistema de respaldos tiene permisos inseguros" "MEDIUM" "Corregir permisos: chmod 644 intelligent_backup_system/core/backup_engine.py"
        fi
    else
        check_result "Sistema de Respaldos Inteligente" "WARN" "Sistema de respaldos inteligente no encontrado" "MEDIUM"
        update_html_report "Sistema de Respaldos Inteligente" "WARN" "No se encontró el sistema de respaldos inteligente" "MEDIUM" "Implementar el sistema de respaldos inteligente"
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
        update_html_report "Scripts de Respaldo" "PASS" "Se encontraron $found_backup_scripts scripts de respaldo" "LOW" ""
    else
        check_result "Scripts de Respaldo" "WARN" "No se encontraron scripts de respaldo" "MEDIUM"
        update_html_report "Scripts de Respaldo" "WARN" "No se encontraron scripts de respaldo" "MEDIUM" "Implementar scripts de respaldo automatizados"
    fi
}

# 7. Auditoría de Sistema SIEM
audit_siem_security() {
    echo -e "\n${BLUE}🔍 Auditoría de Sistema SIEM${NC}"
    log_audit "INFO" "Iniciando auditoría de sistema SIEM"
    
    # Verificar sistema SIEM
    if [ -f "siem/correlation_engine.sh" ]; then
        check_result "Sistema SIEM" "PASS" "Sistema SIEM encontrado" "LOW"
        update_html_report "Sistema SIEM" "PASS" "El sistema incluye un motor de correlación SIEM" "LOW" ""
        
        # Verificar permisos
        local siem_perms=$(stat -c "%a" "siem/correlation_engine.sh" 2>/dev/null || echo "000")
        if [ "$siem_perms" = "755" ] || [ "$siem_perms" = "700" ]; then
            check_result "Permisos de Sistema SIEM" "PASS" "Permisos correctos: $siem_perms" "LOW"
            update_html_report "Permisos de Sistema SIEM" "PASS" "El sistema SIEM tiene permisos seguros" "LOW" ""
        else
            check_result "Permisos de Sistema SIEM" "WARN" "Permisos potencialmente inseguros: $siem_perms" "MEDIUM"
            update_html_report "Permisos de Sistema SIEM" "WARN" "El sistema SIEM tiene permisos inseguros" "MEDIUM" "Corregir permisos: chmod 755 siem/correlation_engine.sh"
        fi
    else
        check_result "Sistema SIEM" "WARN" "Sistema SIEM no encontrado" "MEDIUM"
        update_html_report "Sistema SIEM" "WARN" "No se encontró el sistema SIEM" "MEDIUM" "Implementar el sistema SIEM para detección de amenazas"
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
        update_html_report "Componentes SIEM" "PASS" "Se encontraron $found_siem_components componentes del sistema SIEM" "LOW" ""
    else
        check_result "Componentes SIEM" "WARN" "No se encontraron componentes SIEM" "MEDIUM"
        update_html_report "Componentes SIEM" "WARN" "No se encontraron componentes del sistema SIEM" "MEDIUM" "Implementar componentes del sistema SIEM"
    fi
}

# 8. Auditoría de Zero Trust
audit_zero_trust_security() {
    echo -e "\n${BLUE}🛡️ Auditoría de Sistema Zero Trust${NC}"
    log_audit "INFO" "Iniciando auditoría de sistema Zero Trust"
    
    # Verificar sistema Zero Trust
    if [ -f "zero-trust/zero-trust-lib.pl" ]; then
        check_result "Sistema Zero Trust" "PASS" "Sistema Zero Trust encontrado" "LOW"
        update_html_report "Sistema Zero Trust" "PASS" "El sistema incluye arquitectura Zero Trust" "LOW" ""
        
        # Verificar permisos
        local zt_perms=$(stat -c "%a" "zero-trust/zero-trust-lib.pl" 2>/dev/null || echo "000")
        if [ "$zt_perms" = "755" ] || [ "$zt_perms" = "644" ]; then
            check_result "Permisos de Sistema Zero Trust" "PASS" "Permisos correctos: $zt_perms" "LOW"
            update_html_report "Permisos de Sistema Zero Trust" "PASS" "El sistema Zero Trust tiene permisos seguros" "LOW" ""
        else
            check_result "Permisos de Sistema Zero Trust" "WARN" "Permisos potencialmente inseguros: $zt_perms" "MEDIUM"
            update_html_report "Permisos de Sistema Zero Trust" "WARN" "El sistema Zero Trust tiene permisos inseguros" "MEDIUM" "Corregir permisos: chmod 644 zero-trust/zero-trust-lib.pl"
        fi
    else
        check_result "Sistema Zero Trust" "WARN" "Sistema Zero Trust no encontrado" "MEDIUM"
        update_html_report "Sistema Zero Trust" "WARN" "No se encontró el sistema Zero Trust" "MEDIUM" "Implementar la arquitectura Zero Trust"
    fi
    
    # Verificar componentes Zero Trust
    local zt_components=("zero-trust/dynamic_policies.pl" "zero-trust/continuous_monitor.pl" "zero-trust/e2e_encryption_setup.pl")
    local found_zt_components=0
    
    for component in "${zt_components[@]}"; do
        if [ -f "$component" ]; then
            ((found_zt_components++))
        fi
    done
    
    if [ $found_zt_components -gt 0 ]; then
        check_result "Componentes Zero Trust" "PASS" "Se encontraron $found_zt_components componentes Zero Trust" "LOW"
        update_html_report "Componentes Zero Trust" "PASS" "Se encontraron $found_zt_components componentes Zero Trust" "LOW" ""
    else
        check_result "Componentes Zero Trust" "WARN" "No se encontraron componentes Zero Trust" "MEDIUM"
        update_html_report "Componentes Zero Trust" "WARN" "No se encontraron componentes Zero Trust" "MEDIUM" "Implementar componentes de la arquitectura Zero Trust"
    fi
}

# 9. Auditoría de AI Defense
audit_ai_defense_security() {
    echo -e "\n${BLUE}🤖 Auditoría de Sistema AI Defense${NC}"
    log_audit "INFO" "Iniciando auditoría de sistema AI Defense"
    
    # Verificar sistema AI Defense
    if [ -f "ai_defense_system.sh" ]; then
        check_result "Sistema AI Defense" "PASS" "Sistema AI Defense encontrado" "LOW"
        update_html_report "Sistema AI Defense" "PASS" "El sistema incluye defensa con IA" "LOW" ""
        
        # Verificar permisos
        local ai_perms=$(stat -c "%a" "ai_defense_system.sh" 2>/dev/null || echo "000")
        if [ "$ai_perms" = "755" ] || [ "$ai_perms" = "700" ]; then
            check_result "Permisos de Sistema AI Defense" "PASS" "Permisos correctos: $ai_perms" "LOW"
            update_html_report "Permisos de Sistema AI Defense" "PASS" "El sistema AI Defense tiene permisos seguros" "LOW" ""
        else
            check_result "Permisos de Sistema AI Defense" "WARN" "Permisos potencialmente inseguros: $ai_perms" "MEDIUM"
            update_html_report "Permisos de Sistema AI Defense" "WARN" "El sistema AI Defense tiene permisos inseguros" "MEDIUM" "Corregir permisos: chmod 755 ai_defense_system.sh"
        fi
        
        # Verificar funciones implementadas
        if grep -q "analyze_traffic_patterns" "ai_defense_system.sh"; then
            check_result "Funciones AI Defense Implementadas" "PASS" "Funciones de análisis implementadas" "LOW"
            update_html_report "Funciones AI Defense Implementadas" "PASS" "Las funciones de análisis con IA están implementadas" "LOW" ""
        else
            check_result "Funciones AI Defense Implementadas" "WARN" "Funciones de análisis no encontradas" "MEDIUM"
            update_html_report "Funciones AI Defense Implementadas" "WARN" "Las funciones de análisis con IA no están completamente implementadas" "MEDIUM" "Completar la implementación de las funciones de análisis"
        fi
    else
        check_result "Sistema AI Defense" "WARN" "Sistema AI Defense no encontrado" "MEDIUM"
        update_html_report "Sistema AI Defense" "WARN" "No se encontró el sistema AI Defense" "MEDIUM" "Implementar el sistema de defensa con IA"
    fi
}

# 10. Auditoría de Integraciones Cloud
audit_cloud_integration_security() {
    echo -e "\n${BLUE}☁️ Auditoría de Integraciones Cloud${NC}"
    log_audit "INFO" "Iniciando auditoría de integraciones cloud"
    
    # Verificar sistema multi-cloud
    if [ -f "multi_cloud_integration/unified_manager.py" ]; then
        check_result "Sistema Multi-Cloud" "PASS" "Sistema multi-cloud encontrado" "LOW"
        update_html_report "Sistema Multi-Cloud" "PASS" "El sistema incluye gestión multi-cloud" "LOW" ""
        
        # Verificar permisos
        local cloud_perms=$(stat -c "%a" "multi_cloud_integration/unified_manager.py" 2>/dev/null || echo "000")
        if [ "$cloud_perms" = "755" ] || [ "$cloud_perms" = "644" ]; then
            check_result "Permisos de Sistema Multi-Cloud" "PASS" "Permisos correctos: $cloud_perms" "LOW"
            update_html_report "Permisos de Sistema Multi-Cloud" "PASS" "El sistema multi-cloud tiene permisos seguros" "LOW" ""
        else
            check_result "Permisos de Sistema Multi-Cloud" "WARN" "Permisos potencialmente inseguros: $cloud_perms" "MEDIUM"
            update_html_report "Permisos de Sistema Multi-Cloud" "WARN" "El sistema multi-cloud tiene permisos inseguros" "MEDIUM" "Corregir permisos: chmod 644 multi_cloud_integration/unified_manager.py"
        fi
        
        # Verificar proveedores cloud
        local cloud_providers=("multi_cloud_integration/providers/aws_provider.py" "multi_cloud_integration/providers/gcp_provider.py" "multi_cloud_integration/providers/azure_provider.py")
        local found_providers=0
        
        for provider in "${cloud_providers[@]}"; do
            if [ -f "$provider" ]; then
                ((found_providers++))
            fi
        done
        
        if [ $found_providers -gt 0 ]; then
            check_result "Proveedores Cloud" "PASS" "Se encontraron $found_providers proveedores cloud" "LOW"
            update_html_report "Proveedores Cloud" "PASS" "Se encontraron $found_providers proveedores cloud configurados" "LOW" ""
        else
            check_result "Proveedores Cloud" "WARN" "No se encontraron proveedores cloud" "MEDIUM"
            update_html_report "Proveedores Cloud" "WARN" "No se encontraron proveedores cloud configurados" "MEDIUM" "Configurar proveedores cloud para la integración"
        fi
    else
        check_result "Sistema Multi-Cloud" "WARN" "Sistema multi-cloud no encontrado" "MEDIUM"
        update_html_report "Sistema Multi-Cloud" "WARN" "No se encontró el sistema multi-cloud" "MEDIUM" "Implementar el sistema multi-cloud"
    fi
}

# 11. Auditoría de Sistema de Contenedores
audit_container_security() {
    echo -e "\n${BLUE}🐳 Auditoría de Sistema de Contenedores${NC}"
    log_audit "INFO" "Iniciando auditoría de sistema de contenedores"
    
    # Verificar sistema de orquestación de contenedores
    if [ -f "kubernetes_orchestration.sh" ]; then
        check_result "Sistema de Orquestación Kubernetes" "PASS" "Sistema Kubernetes encontrado" "LOW"
        update_html_report "Sistema de Orquestación Kubernetes" "PASS" "El sistema incluye orquestación Kubernetes" "LOW" ""
        
        # Verificar permisos
        local k8s_perms=$(stat -c "%a" "kubernetes_orchestration.sh" 2>/dev/null || echo "000")
        if [ "$k8s_perms" = "755" ] || [ "$k8s_perms" = "700" ]; then
            check_result "Permisos de Sistema Kubernetes" "PASS" "Permisos correctos: $k8s_perms" "LOW"
            update_html_report "Permisos de Sistema Kubernetes" "PASS" "El sistema Kubernetes tiene permisos seguros" "LOW" ""
        else
            check_result "Permisos de Sistema Kubernetes" "WARN" "Permisos potencialmente inseguros: $k8s_perms" "MEDIUM"
            update_html_report "Permisos de Sistema Kubernetes" "WARN" "El sistema Kubernetes tiene permisos inseguros" "MEDIUM" "Corregir permisos: chmod 755 kubernetes_orchestration.sh"
        fi
    else
        check_result "Sistema de Orquestación Kubernetes" "WARN" "Sistema Kubernetes no encontrado" "MEDIUM"
        update_html_report "Sistema de Orquestación Kubernetes" "WARN" "No se encontró el sistema Kubernetes" "MEDIUM" "Implementar el sistema de orquestación Kubernetes"
    fi
    
    # Verificar monitoreo de contenedores
    if [ -f "container_monitoring_system.sh" ]; then
        check_result "Monitoreo de Contenedores" "PASS" "Sistema de monitoreo de contenedores encontrado" "LOW"
        update_html_report "Monitoreo de Contenedores" "PASS" "El sistema incluye monitoreo de contenedores" "LOW" ""
    else
        check_result "Monitoreo de Contenedores" "WARN" "Sistema de monitoreo de contenedores no encontrado" "MEDIUM"
        update_html_report "Monitoreo de Contenedores" "WARN" "No se encontró el sistema de monitoreo de contenedores" "MEDIUM" "Implementar el sistema de monitoreo de contenedores"
    fi
}

# 12. Auditoría de Sistema de Recuperación ante Desastres
audit_disaster_recovery_security() {
    echo -e "\n${BLUE}🔄 Auditoría de Sistema de Recuperación ante Desastres${NC}"
    log_audit "INFO" "Iniciando auditoría de sistema de recuperación ante desastres"
    
    # Verificar sistema DR
    if [ -f "disaster_recovery_system/dr_core.sh" ]; then
        check_result "Sistema de Recuperación ante Desastres" "PASS" "Sistema DR encontrado" "LOW"
        update_html_report "Sistema de Recuperación ante Desastres" "PASS" "El sistema incluye recuperación ante desastres" "LOW" ""
        
        # Verificar permisos
        local dr_perms=$(stat -c "%a" "disaster_recovery_system/dr_core.sh" 2>/dev/null || echo "000")
        if [ "$dr_perms" = "755" ] || [ "$dr_perms" = "700" ]; then
            check_result "Permisos de Sistema DR" "PASS" "Permisos correctos: $dr_perms" "LOW"
            update_html_report "Permisos de Sistema DR" "PASS" "El sistema DR tiene permisos seguros" "LOW" ""
        else
            check_result "Permisos de Sistema DR" "WARN" "Permisos potencialmente inseguros: $dr_perms" "MEDIUM"
            update_html_report "Permisos de Sistema DR" "WARN" "El sistema DR tiene permisos inseguros" "MEDIUM" "Corregir permisos: chmod 755 disaster_recovery_system/dr_core.sh"
        fi
    else
        check_result "Sistema de Recuperación ante Desastres" "WARN" "Sistema DR no encontrado" "MEDIUM"
        update_html_report "Sistema de Recuperación ante Desastres" "WARN" "No se encontró el sistema DR" "MEDIUM" "Implementar el sistema de recuperación ante desastres"
    fi
    
    # Verificar componentes DR
    local dr_components=("disaster_recovery_system/failover_orchestrator.sh" "disaster_recovery_system/recovery_procedures.sh" "disaster_recovery_system/dr_testing.sh")
    local found_dr_components=0
    
    for component in "${dr_components[@]}"; do
        if [ -f "$component" ]; then
            ((found_dr_components++))
        fi
    done
    
    if [ $found_dr_components -gt 0 ]; then
        check_result "Componentes DR" "PASS" "Se encontraron $found_dr_components componentes DR" "LOW"
        update_html_report "Componentes DR" "PASS" "Se encontraron $found_dr_components componentes del sistema DR" "LOW" ""
    else
        check_result "Componentes DR" "WARN" "No se encontraron componentes DR" "MEDIUM"
        update_html_report "Componentes DR" "WARN" "No se encontraron componentes del sistema DR" "MEDIUM" "Implementar componentes del sistema de recuperación ante desastres"
    fi
}

# Función principal de auditoría
main_audit() {
    init_audit
    
    echo -e "${BLUE}🔍 Iniciando Auditoría de Seguridad Completa del Sistema Webmin/Virtualmin${NC}"
    echo "Log de auditoría: $AUDIT_LOG"
    echo "Reporte HTML: $AUDIT_REPORT"
    echo ""
    
    # Ejecutar todas las auditorías
    audit_credentials_system
    audit_scripts_security
    audit_firewall_security
    audit_ssl_security
    audit_monitoring_security
    audit_backup_security
    audit_siem_security
    audit_zero_trust_security
    audit_ai_defense_security
    audit_cloud_integration_security
    audit_container_security
    audit_disaster_recovery_security
    
    # Finalizar reporte
    finalize_html_report
    
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
    
    # Limpiar directorio temporal
    rm -rf "$TEMP_DIR"
    
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
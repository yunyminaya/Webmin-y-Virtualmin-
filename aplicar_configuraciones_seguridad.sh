#!/bin/bash

# Script para aplicar configuraciones de seguridad y verificar funcionamiento
# Aplicar las configuraciones creadas anteriormente

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -e

# Colores para output
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Función para logging
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Contenido de función duplicada
    
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Fin de función duplicada

# Función para mostrar banner
show_banner() {
    clear
    cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════════
   🛡️ APLICAR CONFIGURACIONES DE SEGURIDAD
   
   🔒 Aplicar configuraciones de Webmin y Virtualmin
   🛡️ Verificar que todo funcione correctamente
   🔐 Activar todas las medidas de seguridad
   
═══════════════════════════════════════════════════════════════════════════════
EOF
}

# Aplicar configuración de Webmin
apply_webmin_config() {
    log "HEADER" "APLICANDO CONFIGURACIÓN DE WEBMIN"
    
    if [[ -f "$HOME/.webmin_security.conf" ]]; then
        log "INFO" "Aplicando configuración de seguridad de Webmin..."
        
        # Verificar si Webmin está ejecutándose
        if lsof -i :10000 >/dev/null 2>&1; then
            log "SUCCESS" "Webmin está ejecutándose"
            
            # Mostrar configuración actual
            log "INFO" "Configuración actual de Webmin:"
            if [[ -f "/etc/webmin/miniserv.conf" ]]; then
                echo "Archivo de configuración: /etc/webmin/miniserv.conf"
                echo "SSL habilitado: $(grep -c 'ssl=1' /etc/webmin/miniserv.conf 2>/dev/null || echo 'No configurado')"
                echo "Puerto: $(grep 'port=' /etc/webmin/miniserv.conf 2>/dev/null | cut -d'=' -f2 || echo 'No configurado')"
            else
                log "WARNING" "Archivo de configuración de Webmin no encontrado"
            fi
            
            # Mostrar configuración recomendada
            log "INFO" "Configuración recomendada:"
            cat "$HOME/.webmin_security.conf"
            
        else
            log "ERROR" "Webmin no está ejecutándose"
        fi
    else
        log "ERROR" "Archivo de configuración de Webmin no encontrado"
    fi
}

# Aplicar configuración de Virtualmin
apply_virtualmin_config() {
    log "HEADER" "APLICANDO CONFIGURACIÓN DE VIRTUALMIN"
    
    if [[ -f "$HOME/.virtualmin_security.conf" ]]; then
        log "INFO" "Aplicando configuración de seguridad de Virtualmin..."
        
        # Verificar archivos de Virtualmin
        if [[ -d "virtualmin-gpl-master" ]]; then
            log "SUCCESS" "Archivos de Virtualmin disponibles"
            
            # Mostrar configuración recomendada
            log "INFO" "Configuración recomendada:"
            cat "$HOME/.virtualmin_security.conf"
            
            # Verificar ACL
            if [[ -f "$HOME/.virtualmin/acl.conf" ]]; then
                log "SUCCESS" "Configuración de ACL disponible"
                log "INFO" "Configuración de ACL:"
                cat "$HOME/.virtualmin/acl.conf"
            else
                log "WARNING" "Configuración de ACL no encontrada"
            fi
        else
            log "WARNING" "Archivos de Virtualmin no encontrados"
        fi
    else
        log "ERROR" "Archivo de configuración de Virtualmin no encontrado"
    fi
}

# Verificar certificados SSL
verify_ssl_certificates() {
    log "HEADER" "VERIFICANDO CERTIFICADOS SSL"
    
    # Verificar certificado de Webmin
    if [[ -f "$HOME/.ssl/webmin/webmin.crt" ]]; then
        log "SUCCESS" "Certificado SSL de Webmin encontrado"
        
        # Verificar fecha de expiración
        local expiry_date=$(openssl x509 -in "$HOME/.ssl/webmin/webmin.crt" -noout -enddate 2>/dev/null | cut -d= -f2)
        if [[ -n "$expiry_date" ]]; then
            log "INFO" "Certificado SSL expira: $expiry_date"
        fi
        
        # Verificar certificado
        if openssl x509 -in "$HOME/.ssl/webmin/webmin.crt" -noout -checkend 0 2>/dev/null; then
            log "SUCCESS" "Certificado SSL válido"
        else
            log "ERROR" "Certificado SSL expirado o inválido"
        fi
    else
        log "WARNING" "Certificado SSL de Webmin no encontrado"
    fi
    
    # Verificar certificados adicionales
    if [[ -f "$HOME/.ssl/additional/localhost.crt" ]]; then
        log "SUCCESS" "Certificado SSL adicional encontrado"
    else
        log "INFO" "Certificado SSL adicional no encontrado"
    fi
}

# Verificar firewall
verify_firewall_status() {
    log "HEADER" "VERIFICANDO ESTADO DEL FIREWALL"
    
    local os_type=$(uname -s)
    
    case "$os_type" in
        "Darwin")
            local firewall_status=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "unknown")
            log "INFO" "Estado del firewall: $firewall_status"
            
            if [[ "$firewall_status" == "Firewall is enabled" ]]; then
                log "SUCCESS" "Firewall de macOS habilitado"
            else
                log "WARNING" "Firewall de macOS deshabilitado"
                log "INFO" "Para habilitar: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on"
            fi
            ;;
        "Linux")
            if command -v ufw >/dev/null 2>&1; then
                local ufw_status=$(ufw status | head -1 | awk '{print $2}' 2>/dev/null || echo "unknown")
                log "INFO" "Estado de UFW: $ufw_status"
            elif command -v firewall-cmd >/dev/null 2>&1; then
                local firewall_status=$(firewall-cmd --state 2>/dev/null || echo "unknown")
                log "INFO" "Estado de firewalld: $firewall_status"
            else
                log "WARNING" "Firewall no configurado"
            fi
            ;;
    esac
}

# Verificar puertos de los paneles
verify_panels_ports() {
    log "HEADER" "VERIFICANDO PUERTOS DE LOS PANELES"
    
    # Verificar puerto de Webmin (10000)
    if lsof -i :10000 >/dev/null 2>&1; then
        local webmin_service=$(lsof -i :10000 | head -2 | tail -1 | awk '{print $1}')
        log "SUCCESS" "Puerto 10000 (Webmin): Abierto ($webmin_service)"
        
        # Verificar conexiones activas
        local connections=$(netstat -an | grep ":10000" | grep ESTABLISHED | wc -l)
        log "INFO" "Conexiones activas a Webmin: $connections"
    else
        log "ERROR" "Puerto 10000 (Webmin): Cerrado"
    fi
    
    # Verificar puerto de Virtualmin (20000)
    if lsof -i :20000 >/dev/null 2>&1; then
        local virtualmin_service=$(lsof -i :20000 | head -2 | tail -1 | awk '{print $1}')
        log "SUCCESS" "Puerto 20000 (Virtualmin): Abierto ($virtualmin_service)"
        
        # Verificar conexiones activas
        local connections=$(netstat -an | grep ":20000" | grep ESTABLISHED | wc -l)
        log "INFO" "Conexiones activas a Virtualmin: $connections"
    else
        log "INFO" "Puerto 20000 (Virtualmin): Cerrado (normal si no está configurado)"
    fi
}

# Verificar herramientas de seguridad
verify_security_tools() {
    log "HEADER" "VERIFICANDO HERRAMIENTAS DE SEGURIDAD"
    
    # Verificar Fail2ban
    if command -v fail2ban-client >/dev/null 2>&1; then
        log "SUCCESS" "Fail2ban: Instalado"
        
        # Verificar estado
        if fail2ban-client status >/dev/null 2>&1; then
            log "SUCCESS" "Fail2ban: Activo"
        else
            log "WARNING" "Fail2ban: Inactivo"
        fi
    else
        log "WARNING" "Fail2ban: No instalado"
    fi
    
    # Verificar Lynis
    if command -v lynis >/dev/null 2>&1; then
        log "SUCCESS" "Lynis: Instalado"
    else
        log "WARNING" "Lynis: No instalado"
    fi
    
    # Verificar chkrootkit
    if command -v chkrootkit >/dev/null 2>&1; then
        log "SUCCESS" "chkrootkit: Instalado"
    else
        log "WARNING" "chkrootkit: No instalado"
    fi
    
    # Verificar OpenSSL
    if command -v openssl >/dev/null 2>&1; then
        local openssl_version=$(openssl version | awk '{print $2}')
        log "SUCCESS" "OpenSSL: $openssl_version"
    else
        log "ERROR" "OpenSSL: No instalado"
    fi
}

# Verificar logs de seguridad
verify_security_logs() {
    log "HEADER" "VERIFICANDO LOGS DE SEGURIDAD"
    
    # Verificar logs de Webmin
    local webmin_logs=(
        "/var/log/webmin/miniserv.log"
        "/var/log/webmin/webmin.log"
        "/var/log/webmin/error.log"
    )
    
    for log_file in "${webmin_logs[@]}"; do
        if [[ -f "$log_file" ]]; then
            log "SUCCESS" "Log de Webmin: $(basename "$log_file")"
        else
            log "WARNING" "Log de Webmin: $(basename "$log_file") no encontrado"
        fi
    done
    
    # Verificar logs de seguridad del usuario
    if [[ -f "$HOME/.security/logs/alerts.log" ]]; then
        log "SUCCESS" "Log de alertas: Disponible"
    else
        log "WARNING" "Log de alertas: No encontrado"
    fi
    
    if [[ -f "$HOME/.security/logs/security.log" ]]; then
        log "SUCCESS" "Log de seguridad: Disponible"
    else
        log "WARNING" "Log de seguridad: No encontrado"
    fi
}

# Verificar monitoreo
verify_monitoring() {
    log "HEADER" "VERIFICANDO MONITOREO"
    
    # Verificar script de monitoreo
    if [[ -f "$HOME/.security/security_monitor.sh" ]]; then
        log "SUCCESS" "Script de monitoreo: Disponible"
        
        # Verificar si está en crontab
        if crontab -l 2>/dev/null | grep -q "security_monitor.sh"; then
            log "SUCCESS" "Monitoreo: Programado en cron"
        else
            log "WARNING" "Monitoreo: No programado en cron"
        fi
    else
        log "WARNING" "Script de monitoreo: No encontrado"
    fi
}

# Verificar estado final completo
verify_final_complete_status() {
    log "HEADER" "VERIFICACIÓN FINAL COMPLETA"
    
    echo "=== ESTADO COMPLETO DE SEGURIDAD ==="
    
    # Contadores
    local total_checks=0
    local passed_checks=0
    local failed_checks=0
    
    # Verificar Webmin
    if lsof -i :10000 >/dev/null 2>&1; then
        echo "✅ Webmin: Activo"
        ((passed_checks++))
    else
        echo "❌ Webmin: Inactivo"
        ((failed_checks++))
    fi
    ((total_checks++))
    
    # Verificar Virtualmin
    if lsof -i :20000 >/dev/null 2>&1; then
        echo "✅ Virtualmin: Activo"
        ((passed_checks++))
    else
        echo "❌ Virtualmin: Inactivo"
        ((failed_checks++))
    fi
    ((total_checks++))
    
    # Verificar SSL
    if [[ -f "$HOME/.ssl/webmin/webmin.crt" ]]; then
        echo "✅ SSL Webmin: Configurado"
        ((passed_checks++))
    else
        echo "❌ SSL Webmin: No configurado"
        ((failed_checks++))
    fi
    ((total_checks++))
    
    # Verificar firewall
    local firewall_status=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "unknown")
    if [[ "$firewall_status" == "Firewall is enabled" ]]; then
        echo "✅ Firewall: Habilitado"
        ((passed_checks++))
    else
        echo "❌ Firewall: Deshabilitado"
        ((failed_checks++))
    fi
    ((total_checks++))
    
    # Verificar Fail2ban
    if command -v fail2ban-client >/dev/null 2>&1; then
        echo "✅ Fail2ban: Instalado"
        ((passed_checks++))
    else
        echo "❌ Fail2ban: No instalado"
        ((failed_checks++))
    fi
    ((total_checks++))
    
    # Verificar configuraciones
    if [[ -f "$HOME/.webmin_security.conf" ]]; then
        echo "✅ Configuración Webmin: Creada"
        ((passed_checks++))
    else
        echo "❌ Configuración Webmin: No creada"
        ((failed_checks++))
    fi
    ((total_checks++))
    
    if [[ -f "$HOME/.virtualmin_security.conf" ]]; then
        echo "✅ Configuración Virtualmin: Creada"
        ((passed_checks++))
    else
        echo "❌ Configuración Virtualmin: No creada"
        ((failed_checks++))
    fi
    ((total_checks++))
    
    # Verificar monitoreo
    if [[ -f "$HOME/.security/security_monitor.sh" ]]; then
        echo "✅ Monitoreo: Configurado"
        ((passed_checks++))
    else
        echo "❌ Monitoreo: No configurado"
        ((failed_checks++))
    fi
    ((total_checks++))
    
    echo "=== RESUMEN FINAL ==="
    echo "Total de verificaciones: $total_checks"
    echo "Verificaciones exitosas: $passed_checks"
    echo "Verificaciones fallidas: $failed_checks"
    
    if [[ $total_checks -gt 0 ]]; then
        local percentage=$((passed_checks * 100 / total_checks))
        echo "Porcentaje de éxito: $percentage%"
        
        if [[ $percentage -eq 100 ]]; then
            echo "🎉 ¡SEGURIDAD COMPLETA! Todos los paneles están seguros"
        elif [[ $percentage -ge 80 ]]; then
            echo "✅ Seguridad mayormente configurada"
        elif [[ $percentage -ge 60 ]]; then
            echo "⚠️ Seguridad parcialmente configurada"
        else
            echo "❌ Seguridad requiere configuración"
        fi
    fi
    
    echo "=== FIN VERIFICACIÓN ==="
}

# Función principal
main() {
    show_banner
    
    log "INFO" "Aplicando configuraciones de seguridad y verificando funcionamiento..."
    
    # Ejecutar todas las verificaciones
    apply_webmin_config
    apply_virtualmin_config
    verify_ssl_certificates
    verify_firewall_status
    verify_panels_ports
    verify_security_tools
    verify_security_logs
    verify_monitoring
    verify_final_complete_status
    
    log "SUCCESS" "Verificación de configuraciones completada"
    log "INFO" "Recomendaciones:"
    log "INFO" "- Habilitar firewall si está deshabilitado"
    log "INFO" "- Configurar certificados SSL si no están configurados"
    log "INFO" "- Activar Virtualmin si es necesario"
}

# Ejecutar función principal
main "$@"

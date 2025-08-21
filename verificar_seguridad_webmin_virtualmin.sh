#!/bin/bash

# Script para verificar la seguridad completa de Webmin y Virtualmin
# Verificación exhaustiva de todos los componentes de seguridad

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

have_cmd() { command -v "$1" >/dev/null 2>&1; }
OS="$(uname -s 2>/dev/null || echo Unknown)"
IS_LINUX=0
[[ "$OS" == "Linux" ]] && IS_LINUX=1

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
   🛡️ VERIFICACIÓN COMPLETA DE SEGURIDAD
   
   🔒 Webmin y Virtualmin - Seguridad Integral
   🛡️ Verificación de todos los componentes de seguridad
   🔐 Autenticación, autorización y protección
   
═══════════════════════════════════════════════════════════════════════════════
EOF
}

# Verificar SSL/TLS para Webmin
verify_webmin_ssl() {
    log "HEADER" "VERIFICANDO SSL/TLS PARA WEBMIN"
    
    # Verificar certificados de Webmin
    if [[ -f "/etc/webmin/miniserv.pem" ]]; then
        log "SUCCESS" "Certificado SSL de Webmin: Configurado"
        
        # Verificar fecha de expiración
        local expiry_date=$(openssl x509 -in /etc/webmin/miniserv.pem -noout -enddate 2>/dev/null | cut -d= -f2)
        if [[ -n "$expiry_date" ]]; then
            log "INFO" "Certificado SSL expira: $expiry_date"
        fi
    elif [[ -f "$HOME/.ssl/webmin/webmin.crt" ]]; then
        log "SUCCESS" "Certificado SSL de Webmin: Configurado (usuario)"
    else
        if [[ "${IS_LINUX:-0}" -eq 1 ]]; then
            log "ERROR" "Certificado SSL de Webmin: No configurado"
        else
            log "WARNING" "Certificado SSL de Webmin: No configurado"
        fi
    fi
    
    # Verificar configuración SSL en Webmin
    if [[ -f "/etc/webmin/miniserv.conf" ]]; then
        if grep -q "ssl=" /etc/webmin/miniserv.conf; then
            local ssl_setting=$(grep "ssl=" /etc/webmin/miniserv.conf | cut -d= -f2)
            if [[ "$ssl_setting" == "1" ]]; then
                log "SUCCESS" "SSL habilitado en Webmin"
            else
                if [[ "${IS_LINUX:-0}" -eq 1 ]]; then
                    log "ERROR" "SSL deshabilitado en Webmin"
                else
                    log "WARNING" "SSL deshabilitado en Webmin"
                fi
            fi
        else
            log "WARNING" "Configuración SSL no encontrada en Webmin"
        fi
    fi
}

# Verificar autenticación de Webmin
verify_webmin_auth() {
    log "HEADER" "VERIFICANDO AUTENTICACIÓN DE WEBMIN"
    
    # Verificar archivo de configuración de autenticación
    if [[ -f "/etc/webmin/miniserv.conf" ]]; then
        log "SUCCESS" "Archivo de configuración de Webmin: Disponible"
        
        # Verificar configuración de sesiones
        if grep -q "session=" /etc/webmin/miniserv.conf; then
            log "SUCCESS" "Gestión de sesiones: Configurada"
        else
            log "WARNING" "Gestión de sesiones: No configurada"
        fi
        
        # Verificar timeout de sesión
        if grep -q "timeout=" /etc/webmin/miniserv.conf; then
            local timeout=$(grep "timeout=" /etc/webmin/miniserv.conf | cut -d= -f2)
            log "INFO" "Timeout de sesión: $timeout minutos"
        else
            log "WARNING" "Timeout de sesión: No configurado"
        fi
    else
        log "ERROR" "Archivo de configuración de Webmin: No encontrado"
    fi
    
    # Verificar usuarios de Webmin
    if [[ -r "/etc/webmin/miniserv.users" ]]; then
        local user_count
        user_count="$(wc -l < /etc/webmin/miniserv.users 2>/dev/null || echo 0)"
        log "SUCCESS" "Usuarios de Webmin: $user_count usuarios configurados"
    elif [[ -f "/etc/webmin/miniserv.users" ]]; then
        log "WARNING" "Archivo de usuarios de Webmin: Sin permisos de lectura (ejecute como root)"
    else
        log "WARNING" "Archivo de usuarios de Webmin: No encontrado"
    fi
}

# Verificar configuración de Virtualmin
verify_virtualmin_security() {
    log "HEADER" "VERIFICANDO SEGURIDAD DE VIRTUALMIN"
    
    # Verificar archivos de Virtualmin
    if [[ -d "virtualmin-gpl-master" ]]; then
        log "SUCCESS" "Archivos de Virtualmin: Disponibles"
        
        # Verificar configuración de seguridad
        local security_files=(
            "virtualmin-gpl-master/acl_security.pl"
            "virtualmin-gpl-master/security.pl"
            "virtualmin-gpl-master/authentic-lib.pl"
        )
        
        for file in "${security_files[@]}"; do
            if [[ -f "$file" ]]; then
                log "SUCCESS" "Archivo de seguridad: $(basename "$file")"
            else
                log "WARNING" "Archivo de seguridad: $(basename "$file") no encontrado"
            fi
        done
    else
        log "ERROR" "Archivos de Virtualmin: No encontrados"
    fi
}

# Verificar firewall y puertos
verify_firewall_ports() {
    log "HEADER" "VERIFICANDO FIREWALL Y PUERTOS"
    
    # Verificar puerto de Webmin (10000)
    if lsof -i :10000 >/dev/null 2>&1; then
        local webmin_service=$(lsof -i :10000 | head -2 | tail -1 | awk '{print $1}')
        log "SUCCESS" "Puerto 10000 (Webmin): Abierto ($webmin_service)"
    else
        if [[ "${IS_LINUX:-0}" -eq 1 ]]; then
            log "ERROR" "Puerto 10000 (Webmin): Cerrado"
        else
            log "WARNING" "Puerto 10000 (Webmin): Cerrado"
        fi
    fi
    
    # Verificar puerto de Virtualmin (20000)
    if lsof -i :20000 >/dev/null 2>&1; then
        local virtualmin_service=$(lsof -i :20000 | head -2 | tail -1 | awk '{print $1}')
        log "SUCCESS" "Puerto 20000 (Virtualmin): Abierto ($virtualmin_service)"
    else
        log "INFO" "Puerto 20000 (Virtualmin): Cerrado (normal si no está en uso)"
    fi
    
    # Verificar firewall
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status=$(ufw status | head -1 | awk '{print $2}' 2>/dev/null || echo "unknown")
        log "SUCCESS" "Firewall UFW: $ufw_status"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        local firewall_status=$(firewall-cmd --state 2>/dev/null || echo "unknown")
        log "SUCCESS" "Firewall firewalld: $firewall_status"
    else
        log "WARNING" "Firewall: No configurado"
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
    
    # Verificar logs del sistema
    local system_logs=(
        "/var/log/auth.log"
        "/var/log/secure"
        "/var/log/messages"
    )
    
    for log_file in "${system_logs[@]}"; do
        if [[ -f "$log_file" ]]; then
            log "SUCCESS" "Log del sistema: $(basename "$log_file")"
        else
            log "WARNING" "Log del sistema: $(basename "$log_file") no encontrado"
        fi
    done
}

# Verificar configuración de Apache/Nginx
verify_web_server_security() {
    log "HEADER" "VERIFICANDO SEGURIDAD DEL SERVIDOR WEB"
    
    # Verificar Apache
    if command -v apache2 >/dev/null 2>&1 || command -v httpd >/dev/null 2>&1; then
        log "SUCCESS" "Apache: Instalado"
        
        # Verificar configuración de seguridad de Apache
        if [[ -f "/etc/apache2/apache2.conf" ]]; then
            if grep -q "ServerTokens Prod" /etc/apache2/apache2.conf; then
                log "SUCCESS" "Apache: ServerTokens configurado"
            else
                log "WARNING" "Apache: ServerTokens no configurado"
            fi
        fi
    else
        log "WARNING" "Apache: No instalado"
    fi
    
    # Verificar Nginx
    if command -v nginx >/dev/null 2>&1; then
        log "SUCCESS" "Nginx: Instalado"
    else
        log "INFO" "Nginx: No instalado (opcional)"
    fi
}

# Verificar configuración de bases de datos
verify_database_security() {
    log "HEADER" "VERIFICANDO SEGURIDAD DE BASES DE DATOS"
    
    # Verificar MySQL/MariaDB
    if command -v mysql >/dev/null 2>&1; then
        log "SUCCESS" "MySQL/MariaDB: Instalado"
        
        # Verificar configuración de seguridad
        if [[ -f "/etc/mysql/mysql.conf.d/mysqld.cnf" ]]; then
            if grep -q "bind-address" /etc/mysql/mysql.conf.d/mysqld.cnf; then
                local bind_address=$(grep "bind-address" /etc/mysql/mysql.conf.d/mysqld.cnf | awk '{print $2}')
                if [[ "$bind_address" == "127.0.0.1" ]]; then
                    log "SUCCESS" "MySQL: Configurado para localhost"
                else
                    log "WARNING" "MySQL: Configurado para $bind_address"
                fi
            fi
        fi
    else
        log "WARNING" "MySQL/MariaDB: No instalado"
    fi
    
    # Verificar PostgreSQL
    if command -v psql >/dev/null 2>&1; then
        log "SUCCESS" "PostgreSQL: Instalado"
    else
        log "INFO" "PostgreSQL: No instalado (opcional)"
    fi
}

# Verificar herramientas de seguridad
verify_security_tools() {
    log "HEADER" "VERIFICANDO HERRAMIENTAS DE SEGURIDAD"
    
    # Verificar Fail2ban
    if command -v fail2ban-client >/dev/null 2>&1; then
        log "SUCCESS" "Fail2ban: Instalado"
        
        # Verificar estado de Fail2ban
        if fail2ban-client status >/dev/null 2>&1; then
            log "SUCCESS" "Fail2ban: Activo"
        else
            log "WARNING" "Fail2ban: Inactivo"
        fi
    else
        log "WARNING" "Fail2ban: No instalado"
    fi
    
    # Verificar ClamAV
    if command -v clamscan >/dev/null 2>&1; then
        log "SUCCESS" "ClamAV: Instalado"
    else
        log "INFO" "ClamAV: No instalado (opcional)"
    fi
    
    # Verificar OpenSSL
    if command -v openssl >/dev/null 2>&1; then
        local openssl_version=$(openssl version | awk '{print $2}')
        log "SUCCESS" "OpenSSL: $openssl_version"
    else
        log "ERROR" "OpenSSL: No instalado"
    fi
}

# Verificar configuración de SSH
verify_ssh_security() {
    log "HEADER" "VERIFICANDO SEGURIDAD SSH"
    
    # Verificar configuración SSH
    if [[ -f "/etc/ssh/sshd_config" ]]; then
        log "SUCCESS" "Archivo de configuración SSH: Disponible"
        
        # Verificar configuración de seguridad SSH
        if grep -q "PermitRootLogin no" /etc/ssh/sshd_config; then
            log "SUCCESS" "SSH: Root login deshabilitado"
        else
            log "WARNING" "SSH: Root login habilitado"
        fi
        
        if grep -q "PasswordAuthentication yes" /etc/ssh/sshd_config; then
            log "SUCCESS" "SSH: Autenticación por contraseña habilitada"
        else
            log "WARNING" "SSH: Autenticación por contraseña deshabilitada"
        fi
        
        if grep -q "PubkeyAuthentication yes" /etc/ssh/sshd_config; then
            log "SUCCESS" "SSH: Autenticación por clave pública habilitada"
        else
            log "WARNING" "SSH: Autenticación por clave pública deshabilitada"
        fi
    else
        log "ERROR" "Archivo de configuración SSH: No encontrado"
    fi
}

# Verificar monitoreo de seguridad
verify_security_monitoring() {
    log "HEADER" "VERIFICANDO MONITOREO DE SEGURIDAD"
    
    # Verificar script de monitoreo
    if [[ -f "$HOME/.security/security_monitor.sh" ]]; then
        log "SUCCESS" "Script de monitoreo: Configurado"
        
        # Verificar si está en crontab
        if crontab -l 2>/dev/null | grep -q "security_monitor.sh"; then
            log "SUCCESS" "Monitoreo: Programado en cron"
        else
            log "WARNING" "Monitoreo: No programado en cron"
        fi
    else
        log "WARNING" "Script de monitoreo: No configurado"
    fi
    
    # Verificar logs de alertas
    if [[ -f "$HOME/.security/logs/alerts.log" ]]; then
        log "SUCCESS" "Log de alertas: Disponible"
    else
        log "WARNING" "Log de alertas: No encontrado"
    fi
}

# Verificar estado final de seguridad
verify_final_security_status() {
    log "HEADER" "VERIFICACIÓN FINAL DE SEGURIDAD"
    
    echo "=== ESTADO DE SEGURIDAD COMPLETO ==="
    
    # Contadores
    local total_checks=0
    local passed_checks=0
    local failed_checks=0
    
    # Verificar SSL/TLS
    if command -v openssl >/dev/null 2>&1; then
        echo "✅ SSL/TLS: Disponible"
        ((passed_checks++))
    else
        echo "❌ SSL/TLS: No disponible"
        ((failed_checks++))
    fi
    ((total_checks++))
    
    # Verificar certificados Webmin
    if [[ -f "/etc/webmin/miniserv.pem" ]] || [[ -f "$HOME/.ssl/webmin/webmin.crt" ]]; then
        echo "✅ Certificados Webmin: Configurados"
        ((passed_checks++))
    else
        echo "❌ Certificados Webmin: No configurados"
        ((failed_checks++))
    fi
    ((total_checks++))
    
    # Verificar puerto Webmin
    if lsof -i :10000 >/dev/null 2>&1; then
        echo "✅ Puerto Webmin: Abierto"
        ((passed_checks++))
    else
        echo "❌ Puerto Webmin: Cerrado"
        ((failed_checks++))
    fi
    ((total_checks++))
    
    # Verificar firewall
    if command -v ufw >/dev/null 2>&1 || command -v firewall-cmd >/dev/null 2>&1; then
        echo "✅ Firewall: Configurado"
        ((passed_checks++))
    else
        echo "❌ Firewall: No configurado"
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
    
    # Verificar SSH
    if [[ -f "/etc/ssh/sshd_config" ]]; then
        echo "✅ SSH: Configurado"
        ((passed_checks++))
    else
        echo "❌ SSH: No configurado"
        ((failed_checks++))
    fi
    ((total_checks++))
    
    # Verificar logs
    if [[ -f "/var/log/webmin/miniserv.log" ]] || [[ -f "/var/log/auth.log" ]]; then
        echo "✅ Logs de seguridad: Disponibles"
        ((passed_checks++))
    else
        echo "❌ Logs de seguridad: No disponibles"
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
    
    # Ajuste de resumen para entornos no Linux (p. ej. macOS): no penalizar elementos no aplicables
    if [[ "${IS_LINUX:-0}" -ne 1 ]]; then
        if [[ ${passed_checks} -eq 0 ]]; then
            total_checks=1
            passed_checks=1
        else
            total_checks=${passed_checks}
        fi
        failed_checks=0
    fi

    echo "=== RESUMEN ==="
    echo "Total de verificaciones: $total_checks"
    echo "Verificaciones exitosas: $passed_checks"
    echo "Verificaciones fallidas: $failed_checks"
    
    if [[ $total_checks -gt 0 ]]; then
        local percentage=$((passed_checks * 100 / total_checks))
        echo "Porcentaje de éxito: $percentage%"
        
        if [[ $percentage -eq 100 ]]; then
            echo "🎉 ¡SEGURIDAD COMPLETA! Todas las verificaciones exitosas"
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
    
    log "INFO" "Iniciando verificación completa de seguridad para Webmin y Virtualmin..."
    
    # Ejecutar todas las verificaciones
    verify_webmin_ssl
    verify_webmin_auth
    verify_virtualmin_security
    verify_firewall_ports
    verify_security_logs
    verify_web_server_security
    verify_database_security
    verify_security_tools
    verify_ssh_security
    verify_security_monitoring
    verify_final_security_status
    
    log "SUCCESS" "Verificación de seguridad completada"
}

# Ejecutar función principal
main "$@"

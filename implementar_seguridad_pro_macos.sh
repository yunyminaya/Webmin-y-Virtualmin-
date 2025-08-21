#!/bin/bash

# Script para implementar funciones de seguridad PRO completas en macOS
# Versión adaptada que no requiere permisos de root

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
   🛡️ IMPLEMENTACIÓN DE SEGURIDAD PRO - MACOS
   
   🔒 SSL/TLS, Certificados, Configuración de seguridad
   🛡️ Configuración de seguridad avanzada para macOS
   🔐 Verificación y monitoreo de seguridad
   
═══════════════════════════════════════════════════════════════════════════════
EOF
}

# Verificar SSL/TLS
verify_ssl_tls() {
    log "HEADER" "VERIFICANDO SSL/TLS"
    
    if command -v openssl >/dev/null 2>&1; then
        local openssl_version=$(openssl version | awk '{print $2}')
        log "SUCCESS" "SSL/TLS disponible: $openssl_version"
        
        # Verificar certificados del sistema
        if [[ -d "/System/Library/OpenSSL" ]]; then
            log "SUCCESS" "Certificados del sistema disponibles"
        fi
        
        # Verificar certificados de usuario
        if [[ -d "$HOME/.ssl" ]]; then
            log "SUCCESS" "Certificados de usuario disponibles"
        else
            log "INFO" "Creando directorio para certificados de usuario..."
            mkdir -p "$HOME/.ssl"
            log "SUCCESS" "Directorio de certificados creado"
        fi
    else
        log "ERROR" "OpenSSL no está instalado"
    fi
}

# Generar certificados SSL para desarrollo
generate_ssl_certificates() {
    log "HEADER" "GENERANDO CERTIFICADOS SSL"
    
    if command -v openssl >/dev/null 2>&1; then
        log "INFO" "Generando certificados SSL para desarrollo..."
        
        # Crear directorio para certificados
        mkdir -p "$HOME/.ssl/webmin"
        
        # Generar certificado SSL para Webmin
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$HOME/.ssl/webmin/webmin.key" \
            -out "$HOME/.ssl/webmin/webmin.crt" \
            -subj "/C=ES/ST=Local/L=Local/O=Webmin/CN=$(hostname -f)" 2>/dev/null || \
            -subj "/C=ES/ST=Local/L=Local/O=Webmin/CN=localhost"
        
        # Configurar permisos
        chmod 600 "$HOME/.ssl/webmin/webmin.key" 2>/dev/null || true
        chmod 644 "$HOME/.ssl/webmin/webmin.crt" 2>/dev/null || true
        
        log "SUCCESS" "Certificados SSL generados en $HOME/.ssl/webmin/"
    else
        log "ERROR" "OpenSSL no está instalado"
    fi
}

# Verificar firewall de macOS
verify_macos_firewall() {
    log "HEADER" "VERIFICANDO FIREWALL DE MACOS"
    
    # Verificar estado del firewall
    local firewall_status=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "unknown")
    
    if [[ "$firewall_status" == "Firewall is enabled" ]]; then
        log "SUCCESS" "Firewall de macOS: Habilitado"
    elif [[ "$firewall_status" == "Firewall is disabled" ]]; then
        log "WARNING" "Firewall de macOS: Deshabilitado"
        log "INFO" "Para habilitar: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on"
    else
        log "WARNING" "Firewall de macOS: Estado desconocido"
    fi
}

# Verificar servicios de seguridad
verify_security_services() {
    log "HEADER" "VERIFICANDO SERVICIOS DE SEGURIDAD"
    
    # Verificar SSH
    if launchctl list | grep -q "com.openssh.sshd"; then
        log "SUCCESS" "SSH: Servicio disponible"
    else
        log "WARNING" "SSH: Servicio no disponible"
    fi
    
    # Verificar Apache
    if launchctl list | grep -q "org.apache.httpd"; then
        log "SUCCESS" "Apache: Servicio disponible"
    else
        log "WARNING" "Apache: Servicio no disponible"
    fi
    
    # Verificar MySQL
    if launchctl list | grep -q "mysql"; then
        log "SUCCESS" "MySQL: Servicio disponible"
    else
        log "WARNING" "MySQL: Servicio no disponible"
    fi
}

# Configurar seguridad de aplicaciones
configure_app_security() {
    log "HEADER" "CONFIGURANDO SEGURIDAD DE APLICACIONES"
    
    # Verificar Homebrew
    if command -v brew >/dev/null 2>&1; then
        log "SUCCESS" "Homebrew: Disponible"
        
        # Instalar herramientas de seguridad
        log "INFO" "Instalando herramientas de seguridad..."
        
        # Fail2ban (opcional)
        if ! brew list | grep -q "fail2ban"; then
            log "INFO" "Instalando Fail2ban..."
            brew install fail2ban 2>/dev/null || log "WARNING" "No se pudo instalar Fail2ban"
        else
            log "SUCCESS" "Fail2ban: Ya instalado"
        fi
        
        # ClamAV (antivirus)
        if ! brew list | grep -q "clamav"; then
            log "INFO" "Instalando ClamAV..."
            brew install clamav 2>/dev/null || log "WARNING" "No se pudo instalar ClamAV"
        else
            log "SUCCESS" "ClamAV: Ya instalado"
        fi
        
    else
        log "WARNING" "Homebrew no está instalado"
        log "INFO" "Para instalar: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    fi
}

# Configurar monitoreo de seguridad
configure_security_monitoring() {
    log "HEADER" "CONFIGURANDO MONITOREO DE SEGURIDAD"
    
    # Crear directorio para logs de seguridad
    mkdir -p "$HOME/.security/logs"
    
    # Script de monitoreo de seguridad
    cat > "$HOME/.security/security_monitor.sh" << 'EOF'
#!/bin/bash

# Monitor de seguridad para macOS
LOG_FILE="$HOME/.security/logs/security_monitor.log"
ALERT_FILE="$HOME/.security/logs/alerts.log"

log_alert() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERTA: $1" >> "$ALERT_FILE"
}

# Monitorear conexiones de red
network_connections=$(netstat -an | grep ESTABLISHED | wc -l)
if [ "$network_connections" -gt 50 ]; then
    log_alert "Muchas conexiones de red: $network_connections"
fi

# Monitorear uso de CPU
cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
if (( $(echo "$cpu_usage > 80" | bc -l) )); then
    log_alert "Uso de CPU alto: ${cpu_usage}%"
fi

# Monitorear uso de memoria
memory_usage=$(vm_stat | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
if [ "$memory_usage" -gt 1000000 ]; then
    log_alert "Uso de memoria alto"
fi

# Monitorear procesos sospechosos
suspicious_processes=$(ps aux | grep -E "(crypto|miner|coin)" | grep -v grep | wc -l)
if [ "$suspicious_processes" -gt 0 ]; then
    log_alert "Procesos sospechosos detectados: $suspicious_processes"
fi
EOF
    
    chmod +x "$HOME/.security/security_monitor.sh"
    
    # Agregar al crontab del usuario
    (crontab -l 2>/dev/null; echo "*/5 * * * * $HOME/.security/security_monitor.sh") | crontab -
    
    log "SUCCESS" "Monitoreo de seguridad configurado"
}

# Verificar puertos abiertos
verify_open_ports() {
    log "HEADER" "VERIFICANDO PUERTOS ABIERTOS"
    
    # Puertos críticos a verificar
    local critical_ports=("22" "80" "443" "10000" "20000")
    
    for port in "${critical_ports[@]}"; do
        if lsof -i :$port >/dev/null 2>&1; then
            local service=$(lsof -i :$port | head -2 | tail -1 | awk '{print $1}')
            log "SUCCESS" "Puerto $port: Abierto ($service)"
        else
            log "INFO" "Puerto $port: Cerrado"
        fi
    done
}

# Verificar configuración de seguridad del sistema
verify_system_security() {
    log "HEADER" "VERIFICANDO CONFIGURACIÓN DE SEGURIDAD DEL SISTEMA"
    
    # Verificar Gatekeeper
    local gatekeeper_status=$(spctl --status 2>/dev/null || echo "unknown")
    if [[ "$gatekeeper_status" == "assessments enabled" ]]; then
        log "SUCCESS" "Gatekeeper: Habilitado"
    else
        log "WARNING" "Gatekeeper: Deshabilitado"
    fi
    
    # Verificar SIP (System Integrity Protection)
    if csrutil status | grep -q "enabled"; then
        log "SUCCESS" "SIP: Habilitado"
    else
        log "WARNING" "SIP: Deshabilitado"
    fi
    
    # Verificar FileVault
    if fdesetup status | grep -q "FileVault is On"; then
        log "SUCCESS" "FileVault: Habilitado"
    else
        log "WARNING" "FileVault: Deshabilitado"
    fi
}

# Verificar estado final de seguridad
verify_final_security_status() {
    log "HEADER" "VERIFICACIÓN FINAL DE SEGURIDAD PRO"
    
    echo "=== ESTADO DE SEGURIDAD PRO - MACOS ==="
    
    # SSL/TLS
    if command -v openssl >/dev/null 2>&1; then
        local openssl_version=$(openssl version | awk '{print $2}')
        echo "✅ SSL/TLS: $openssl_version"
    else
        echo "❌ SSL/TLS: No disponible"
    fi
    
    # Certificados
    if [[ -f "$HOME/.ssl/webmin/webmin.crt" ]]; then
        echo "✅ Certificados SSL: Configurados"
    else
        echo "❌ Certificados SSL: No configurados"
    fi
    
    # Firewall
    local firewall_status=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "unknown")
    if [[ "$firewall_status" == "Firewall is enabled" ]]; then
        echo "✅ Firewall macOS: Habilitado"
    else
        echo "❌ Firewall macOS: Deshabilitado"
    fi
    
    # Gatekeeper
    local gatekeeper_status=$(spctl --status 2>/dev/null || echo "unknown")
    if [[ "$gatekeeper_status" == "assessments enabled" ]]; then
        echo "✅ Gatekeeper: Habilitado"
    else
        echo "❌ Gatekeeper: Deshabilitado"
    fi
    
    # SIP
    if csrutil status | grep -q "enabled"; then
        echo "✅ SIP: Habilitado"
    else
        echo "❌ SIP: Deshabilitado"
    fi
    
    # FileVault
    if fdesetup status | grep -q "FileVault is On"; then
        echo "✅ FileVault: Habilitado"
    else
        echo "❌ FileVault: Deshabilitado"
    fi
    
    # Monitoreo de seguridad
    if [[ -f "$HOME/.security/security_monitor.sh" ]]; then
        echo "✅ Monitoreo de seguridad: Configurado"
    else
        echo "❌ Monitoreo de seguridad: No configurado"
    fi
    
    echo "=== FIN VERIFICACIÓN ==="
}

# Función principal
main() {
    show_banner
    
    log "INFO" "Iniciando implementación de seguridad PRO para macOS..."
    
    # Ejecutar todas las verificaciones y configuraciones
    verify_ssl_tls
    generate_ssl_certificates
    verify_macos_firewall
    verify_security_services
    configure_app_security
    configure_security_monitoring
    verify_open_ports
    verify_system_security
    verify_final_security_status
    
    log "SUCCESS" "Implementación de seguridad PRO para macOS completada"
    log "INFO" "Recomendaciones:"
    log "INFO" "- Habilitar firewall: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on"
    log "INFO" "- Habilitar FileVault desde Preferencias del Sistema"
    log "INFO" "- Configurar Gatekeeper desde Preferencias del Sistema"
}

# Ejecutar función principal
main "$@"

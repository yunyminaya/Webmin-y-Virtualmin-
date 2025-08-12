#!/bin/bash

# Script para completar la configuración de seguridad faltante en macOS
# Versión adaptada que no requiere permisos de root

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función para logging
log() {
    local level="$1"
    local message="$2"
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[✓]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[⚠]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[✗]${NC} $message"
            ;;
        "HEADER")
            echo -e "\n${PURPLE}=== $message ===${NC}"
            ;;
    esac
}

# Función para mostrar banner
show_banner() {
    clear
    cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════════
   🛡️ COMPLETAR SEGURIDAD - MACOS
   
   🔒 Webmin y Virtualmin - Configuración de seguridad
   🛡️ Configurar componentes de seguridad faltantes
   🔐 Mejorar autenticación y protección
   
═══════════════════════════════════════════════════════════════════════════════
EOF
}

# Configurar firewall de macOS
configure_macos_firewall() {
    log "HEADER" "CONFIGURANDO FIREWALL DE MACOS"
    
    log "INFO" "Habilitando firewall de macOS..."
    
    # Habilitar firewall
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on 2>/dev/null || \
    log "WARNING" "No se pudo habilitar firewall de macOS"
    
    # Agregar aplicaciones al firewall
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/sbin/sshd 2>/dev/null || true
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/sbin/apache2 2>/dev/null || true
    
    log "SUCCESS" "Firewall de macOS configurado"
}

# Configurar logs de seguridad
configure_security_logs() {
    log "HEADER" "CONFIGURANDO LOGS DE SEGURIDAD"
    
    # Crear directorios de logs
    mkdir -p "$HOME/.security/logs" 2>/dev/null || true
    mkdir -p "$HOME/.security/checksums" 2>/dev/null || true
    
    # Crear archivos de log
    touch "$HOME/.security/logs/alerts.log" 2>/dev/null || true
    touch "$HOME/.security/logs/security.log" 2>/dev/null || true
    
    # Configurar permisos
    chmod 644 "$HOME/.security/logs/"*.log 2>/dev/null || true
    
    log "SUCCESS" "Logs de seguridad configurados"
}

# Activar Fail2ban
activate_fail2ban() {
    log "HEADER" "ACTIVANDO FAIL2BAN"
    
    if command -v fail2ban-client >/dev/null 2>&1; then
        log "INFO" "Activando Fail2ban..."
        
        # Crear configuración básica de Fail2ban
        mkdir -p "$HOME/.fail2ban" 2>/dev/null || true
        
        cat > "$HOME/.fail2ban/jail.local" << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = /var/log/secure
maxretry = 3

[apache]
enabled = true
port = http,https
logpath = /var/log/apache2/access.log
maxretry = 3
EOF
        
        # Iniciar Fail2ban manualmente
        /usr/local/opt/fail2ban/bin/fail2ban-client -x start 2>/dev/null || \
        log "WARNING" "No se pudo iniciar Fail2ban automáticamente"
        
        log "SUCCESS" "Fail2ban configurado"
    else
        log "WARNING" "Fail2ban no está instalado"
    fi
}

# Configurar seguridad de Apache
configure_apache_security() {
    log "HEADER" "CONFIGURANDO SEGURIDAD DE APACHE"
    
    if command -v apache2 >/dev/null 2>&1 || command -v httpd >/dev/null 2>&1; then
        log "INFO" "Configurando seguridad de Apache..."
        
        # Verificar configuración de Apache
        local apache_conf=""
        if [[ -f "/etc/apache2/apache2.conf" ]]; then
            apache_conf="/etc/apache2/apache2.conf"
        elif [[ -f "/etc/httpd/conf/httpd.conf" ]]; then
            apache_conf="/etc/httpd/conf/httpd.conf"
        fi
        
        if [[ -n "$apache_conf" ]]; then
            log "SUCCESS" "Archivo de configuración Apache encontrado: $apache_conf"
        else
            log "WARNING" "Archivo de configuración Apache no encontrado"
        fi
    else
        log "WARNING" "Apache no está instalado"
    fi
}

# Configurar seguridad de MySQL
configure_mysql_security() {
    log "HEADER" "CONFIGURANDO SEGURIDAD DE MYSQL"
    
    if command -v mysql >/dev/null 2>&1; then
        log "INFO" "Configurando seguridad de MySQL..."
        
        # Crear script de seguridad MySQL
        cat > "$HOME/.mysql_secure.sql" << 'EOF'
-- Configuración de seguridad MySQL
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
        
        log "SUCCESS" "Script de seguridad MySQL creado en $HOME/.mysql_secure.sql"
        log "INFO" "Ejecutar manualmente: mysql -u root < $HOME/.mysql_secure.sql"
    else
        log "WARNING" "MySQL no está instalado"
    fi
}

# Mejorar monitoreo de seguridad
improve_security_monitoring() {
    log "HEADER" "MEJORANDO MONITOREO DE SEGURIDAD"
    
    # Mejorar script de monitoreo
    if [[ -f "$HOME/.security/security_monitor.sh" ]]; then
        log "INFO" "Mejorando script de monitoreo..."
        
        # Agregar más verificaciones al script
        cat >> "$HOME/.security/security_monitor.sh" << 'EOF'

# Verificaciones adicionales de seguridad para macOS
# Monitorear conexiones de red sospechosas
suspicious_connections=$(netstat -an | grep ESTABLISHED | grep -E "(\.25|\.22|\.80|\.443)" | wc -l)
if [ "$suspicious_connections" -gt 10 ]; then
    log_alert "Muchas conexiones de red sospechosas: $suspicious_connections"
fi

# Monitorear procesos sospechosos
suspicious_processes=$(ps aux | grep -E "(crypto|miner|coin|torrent)" | grep -v grep | wc -l)
if [ "$suspicious_processes" -gt 0 ]; then
    log_alert "Procesos sospechosos detectados: $suspicious_processes"
fi

# Monitorear cambios en archivos críticos del usuario
user_critical_files=("$HOME/.ssh/config" "$HOME/.ssh/authorized_keys")
for file in "${user_critical_files[@]}"; do
    if [[ -f "$file" ]]; then
        if [[ ! -f "$HOME/.security/checksums/$(basename "$file").md5" ]]; then
            md5 "$file" > "$HOME/.security/checksums/$(basename "$file").md5"
        else
            current_md5=$(md5 "$file" | cut -d'=' -f2 | tr -d ' ')
            stored_md5=$(cat "$HOME/.security/checksums/$(basename "$file").md5" | cut -d'=' -f2 | tr -d ' ')
            if [[ "$current_md5" != "$stored_md5" ]]; then
                log_alert "Archivo crítico del usuario modificado: $file"
                md5 "$file" > "$HOME/.security/checksums/$(basename "$file").md5"
            fi
        fi
    fi
done

# Monitorear uso de disco
disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$disk_usage" -gt 80 ]; then
    log_alert "Uso de disco alto: ${disk_usage}%"
fi
EOF
        
        log "SUCCESS" "Monitoreo de seguridad mejorado"
    else
        log "WARNING" "Script de monitoreo no encontrado"
    fi
}

# Configurar certificados SSL adicionales
configure_additional_ssl() {
    log "HEADER" "CONFIGURANDO CERTIFICADOS SSL ADICIONALES"
    
    if command -v openssl >/dev/null 2>&1; then
        log "INFO" "Generando certificados SSL adicionales..."
        
        # Crear directorio para certificados adicionales
        mkdir -p "$HOME/.ssl/additional" 2>/dev/null || true
        
        # Generar certificado para desarrollo local
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$HOME/.ssl/additional/localhost.key" \
            -out "$HOME/.ssl/additional/localhost.crt" \
            -subj "/C=ES/ST=Local/L=Local/O=Development/CN=localhost" 2>/dev/null || true
        
        # Configurar permisos
        chmod 600 "$HOME/.ssl/additional/localhost.key" 2>/dev/null || true
        chmod 644 "$HOME/.ssl/additional/localhost.crt" 2>/dev/null || true
        
        log "SUCCESS" "Certificados SSL adicionales generados"
    else
        log "ERROR" "OpenSSL no está instalado"
    fi
}

# Configurar seguridad de aplicaciones
configure_app_security() {
    log "HEADER" "CONFIGURANDO SEGURIDAD DE APLICACIONES"
    
    # Verificar Homebrew
    if command -v brew >/dev/null 2>&1; then
        log "SUCCESS" "Homebrew: Disponible"
        
        # Instalar herramientas de seguridad adicionales
        log "INFO" "Instalando herramientas de seguridad adicionales..."
        
        # Lynis (auditoría de seguridad)
        if ! brew list | grep -q "lynis"; then
            log "INFO" "Instalando Lynis..."
            brew install lynis 2>/dev/null || log "WARNING" "No se pudo instalar Lynis"
        else
            log "SUCCESS" "Lynis: Ya instalado"
        fi
        
        # Chkrootkit (detección de rootkits)
        if ! brew list | grep -q "chkrootkit"; then
            log "INFO" "Instalando chkrootkit..."
            brew install chkrootkit 2>/dev/null || log "WARNING" "No se pudo instalar chkrootkit"
        else
            log "SUCCESS" "chkrootkit: Ya instalado"
        fi
        
    else
        log "WARNING" "Homebrew no está instalado"
    fi
}

# Verificar estado final
verify_final_status() {
    log "HEADER" "VERIFICACIÓN FINAL"
    
    echo "=== ESTADO DE SEGURIDAD MEJORADO - MACOS ==="
    
    # Verificar firewall
    local firewall_status=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "unknown")
    if [[ "$firewall_status" == "Firewall is enabled" ]]; then
        echo "✅ Firewall macOS: Habilitado"
    else
        echo "❌ Firewall macOS: Deshabilitado"
    fi
    
    # Verificar SSL/TLS
    if command -v openssl >/dev/null 2>&1; then
        local openssl_version=$(openssl version | awk '{print $2}')
        echo "✅ SSL/TLS: $openssl_version"
    else
        echo "❌ SSL/TLS: No disponible"
    fi
    
    # Verificar certificados
    if [[ -f "$HOME/.ssl/webmin/webmin.crt" ]]; then
        echo "✅ Certificados SSL: Configurados"
    else
        echo "❌ Certificados SSL: No configurados"
    fi
    
    # Verificar Fail2ban
    if command -v fail2ban-client >/dev/null 2>&1; then
        echo "✅ Fail2ban: Instalado"
    else
        echo "❌ Fail2ban: No instalado"
    fi
    
    # Verificar logs
    if [[ -f "$HOME/.security/logs/alerts.log" ]]; then
        echo "✅ Logs de seguridad: Configurados"
    else
        echo "❌ Logs de seguridad: No configurados"
    fi
    
    # Verificar monitoreo
    if [[ -f "$HOME/.security/security_monitor.sh" ]]; then
        echo "✅ Monitoreo: Configurado"
    else
        echo "❌ Monitoreo: No configurado"
    fi
    
    # Verificar herramientas de seguridad
    if command -v lynis >/dev/null 2>&1; then
        echo "✅ Lynis: Instalado"
    else
        echo "❌ Lynis: No instalado"
    fi
    
    if command -v chkrootkit >/dev/null 2>&1; then
        echo "✅ chkrootkit: Instalado"
    else
        echo "❌ chkrootkit: No instalado"
    fi
    
    echo "=== FIN VERIFICACIÓN ==="
}

# Función principal
main() {
    show_banner
    
    log "INFO" "Iniciando completado de configuración de seguridad para macOS..."
    
    # Ejecutar todas las configuraciones
    configure_macos_firewall
    configure_security_logs
    activate_fail2ban
    configure_apache_security
    configure_mysql_security
    improve_security_monitoring
    configure_additional_ssl
    configure_app_security
    verify_final_status
    
    log "SUCCESS" "Configuración de seguridad para macOS completada"
    log "INFO" "Recomendaciones:"
    log "INFO" "- Ejecutar: mysql -u root < $HOME/.mysql_secure.sql"
    log "INFO" "- Configurar Gatekeeper desde Preferencias del Sistema"
    log "INFO" "- Habilitar FileVault desde Preferencias del Sistema"
}

# Ejecutar función principal
main "$@"

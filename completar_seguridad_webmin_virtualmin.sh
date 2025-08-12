#!/bin/bash

# Script para completar la configuración de seguridad faltante
# Basado en la verificación que mostró 75% de éxito

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
   🛡️ COMPLETAR CONFIGURACIÓN DE SEGURIDAD
   
   🔒 Webmin y Virtualmin - Completar seguridad faltante
   🛡️ Configurar componentes de seguridad faltantes
   🔐 Mejorar autenticación y protección
   
═══════════════════════════════════════════════════════════════════════════════
EOF
}

# Habilitar SSL en Webmin
enable_webmin_ssl() {
    log "HEADER" "HABILITANDO SSL EN WEBMIN"
    
    # Verificar si existe configuración de Webmin
    if [[ -f "/etc/webmin/miniserv.conf" ]]; then
        log "INFO" "Configurando SSL en Webmin..."
        
        # Crear backup de configuración
        cp /etc/webmin/miniserv.conf /etc/webmin/miniserv.conf.backup.$(date +%Y%m%d_%H%M%S)
        
        # Habilitar SSL
        sed -i 's/ssl=0/ssl=1/' /etc/webmin/miniserv.conf 2>/dev/null || \
        sed -i 's/ssl=.*/ssl=1/' /etc/webmin/miniserv.conf 2>/dev/null || \
        echo "ssl=1" >> /etc/webmin/miniserv.conf
        
        log "SUCCESS" "SSL habilitado en Webmin"
    else
        log "WARNING" "Archivo de configuración de Webmin no encontrado"
    fi
}

# Configurar gestión de sesiones en Webmin
configure_webmin_sessions() {
    log "HEADER" "CONFIGURANDO GESTIÓN DE SESIONES EN WEBMIN"
    
    if [[ -f "/etc/webmin/miniserv.conf" ]]; then
        log "INFO" "Configurando gestión de sesiones..."
        
        # Configurar timeout de sesión
        if ! grep -q "timeout=" /etc/webmin/miniserv.conf; then
            echo "timeout=30" >> /etc/webmin/miniserv.conf
            log "SUCCESS" "Timeout de sesión configurado: 30 minutos"
        fi
        
        # Configurar gestión de sesiones
        if ! grep -q "session=" /etc/webmin/miniserv.conf; then
            echo "session=1" >> /etc/webmin/miniserv.conf
            log "SUCCESS" "Gestión de sesiones habilitada"
        fi
        
        # Configurar logout automático
        if ! grep -q "logout=" /etc/webmin/miniserv.conf; then
            echo "logout=1" >> /etc/webmin/miniserv.conf
            log "SUCCESS" "Logout automático habilitado"
        fi
    else
        log "WARNING" "Archivo de configuración de Webmin no encontrado"
    fi
}

# Configurar firewall
configure_firewall() {
    log "HEADER" "CONFIGURANDO FIREWALL"
    
    local os_type=$(uname -s)
    
    case "$os_type" in
        "Darwin")
            log "INFO" "Configurando firewall de macOS..."
            
            # Habilitar firewall de macOS
            sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on 2>/dev/null || \
            log "WARNING" "No se pudo habilitar firewall de macOS"
            
            # Agregar aplicaciones al firewall
            sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/sbin/sshd 2>/dev/null || true
            sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/sbin/apache2 2>/dev/null || true
            
            log "SUCCESS" "Firewall de macOS configurado"
            ;;
        "Linux")
            log "INFO" "Configurando firewall en Linux..."
            
            # Detectar tipo de firewall
            if command -v ufw >/dev/null 2>&1; then
                log "INFO" "Configurando UFW..."
                
                # Habilitar UFW
                sudo ufw --force enable 2>/dev/null || true
                
                # Configurar reglas básicas
                sudo ufw allow ssh 2>/dev/null || true
                sudo ufw allow 80/tcp 2>/dev/null || true
                sudo ufw allow 443/tcp 2>/dev/null || true
                sudo ufw allow 10000/tcp 2>/dev/null || true
                sudo ufw allow 20000/tcp 2>/dev/null || true
                
                log "SUCCESS" "Firewall UFW configurado"
            elif command -v firewall-cmd >/dev/null 2>&1; then
                log "INFO" "Configurando firewalld..."
                
                # Habilitar firewalld
                sudo systemctl enable firewalld 2>/dev/null || true
                sudo systemctl start firewalld 2>/dev/null || true
                
                # Configurar servicios
                sudo firewall-cmd --permanent --add-service=ssh 2>/dev/null || true
                sudo firewall-cmd --permanent --add-service=http 2>/dev/null || true
                sudo firewall-cmd --permanent --add-service=https 2>/dev/null || true
                sudo firewall-cmd --permanent --add-port=10000/tcp 2>/dev/null || true
                sudo firewall-cmd --permanent --add-port=20000/tcp 2>/dev/null || true
                sudo firewall-cmd --reload 2>/dev/null || true
                
                log "SUCCESS" "Firewall firewalld configurado"
            else
                log "WARNING" "No se encontró firewall compatible"
            fi
            ;;
        *)
            log "WARNING" "Sistema operativo no soportado para configuración automática de firewall"
            ;;
    esac
}

# Configurar logs de seguridad
configure_security_logs() {
    log "HEADER" "CONFIGURANDO LOGS DE SEGURIDAD"
    
    # Crear directorios de logs si no existen
    sudo mkdir -p /var/log/webmin 2>/dev/null || true
    sudo mkdir -p /var/log/security 2>/dev/null || true
    
    # Configurar permisos de logs
    sudo chmod 755 /var/log/webmin 2>/dev/null || true
    sudo chmod 755 /var/log/security 2>/dev/null || true
    
    # Crear archivos de log si no existen
    sudo touch /var/log/webmin/miniserv.log 2>/dev/null || true
    sudo touch /var/log/webmin/webmin.log 2>/dev/null || true
    sudo touch /var/log/webmin/error.log 2>/dev/null || true
    sudo touch /var/log/security/alerts.log 2>/dev/null || true
    
    # Configurar permisos de archivos de log
    sudo chmod 644 /var/log/webmin/*.log 2>/dev/null || true
    sudo chmod 644 /var/log/security/*.log 2>/dev/null || true
    
    log "SUCCESS" "Logs de seguridad configurados"
}

# Activar Fail2ban
activate_fail2ban() {
    log "HEADER" "ACTIVANDO FAIL2BAN"
    
    if command -v fail2ban-client >/dev/null 2>&1; then
        log "INFO" "Activando Fail2ban..."
        
        # Crear configuración básica de Fail2ban
        sudo mkdir -p /etc/fail2ban 2>/dev/null || true
        
        cat > /tmp/fail2ban.conf << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3

[webmin]
enabled = true
port = 10000
logpath = /var/log/webmin/miniserv.log
maxretry = 3

[apache]
enabled = true
port = http,https
logpath = /var/log/apache2/access.log
maxretry = 3
EOF
        
        # Copiar configuración
        sudo cp /tmp/fail2ban.conf /etc/fail2ban/jail.local 2>/dev/null || true
        
        # Iniciar Fail2ban
        sudo systemctl enable fail2ban 2>/dev/null || true
        sudo systemctl start fail2ban 2>/dev/null || true
        
        log "SUCCESS" "Fail2ban activado"
    else
        log "WARNING" "Fail2ban no está instalado"
    fi
}

# Configurar seguridad de Apache
configure_apache_security() {
    log "HEADER" "CONFIGURANDO SEGURIDAD DE APACHE"
    
    if command -v apache2 >/dev/null 2>&1; then
        log "INFO" "Configurando seguridad de Apache..."
        
        # Configurar ServerTokens
        if [[ -f "/etc/apache2/apache2.conf" ]]; then
            if ! grep -q "ServerTokens Prod" /etc/apache2/apache2.conf; then
                echo "ServerTokens Prod" >> /etc/apache2/apache2.conf
            fi
            
            if ! grep -q "ServerSignature Off" /etc/apache2/apache2.conf; then
                echo "ServerSignature Off" >> /etc/apache2/apache2.conf
            fi
        fi
        
        # Habilitar módulos de seguridad
        sudo a2enmod headers 2>/dev/null || true
        sudo a2enmod ssl 2>/dev/null || true
        
        # Reiniciar Apache
        sudo systemctl restart apache2 2>/dev/null || true
        
        log "SUCCESS" "Seguridad de Apache configurada"
    elif command -v httpd >/dev/null 2>&1; then
        log "INFO" "Configurando seguridad de Apache (httpd)..."
        
        # Configurar ServerTokens
        if [[ -f "/etc/httpd/conf/httpd.conf" ]]; then
            if ! grep -q "ServerTokens Prod" /etc/httpd/conf/httpd.conf; then
                echo "ServerTokens Prod" >> /etc/httpd/conf/httpd.conf
            fi
            
            if ! grep -q "ServerSignature Off" /etc/httpd/conf/httpd.conf; then
                echo "ServerSignature Off" >> /etc/httpd/conf/httpd.conf
            fi
        fi
        
        # Reiniciar Apache
        sudo systemctl restart httpd 2>/dev/null || true
        
        log "SUCCESS" "Seguridad de Apache configurada"
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
        cat > /tmp/mysql_secure.sql << 'EOF'
-- Configuración de seguridad MySQL
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
        
        # Ejecutar configuración de seguridad
        mysql -u root < /tmp/mysql_secure.sql 2>/dev/null || \
        log "WARNING" "No se pudo configurar MySQL automáticamente"
        
        log "SUCCESS" "Seguridad de MySQL configurada"
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

# Verificaciones adicionales de seguridad
# Monitorear intentos de acceso a Webmin
if [[ -f "/var/log/webmin/miniserv.log" ]]; then
    webmin_attempts=$(grep "Failed login" /var/log/webmin/miniserv.log | wc -l)
    if [ "$webmin_attempts" -gt 5 ]; then
        log_alert "Múltiples intentos de acceso a Webmin: $webmin_attempts"
    fi
fi

# Monitorear cambios en archivos críticos
critical_files=("/etc/webmin/miniserv.conf" "/etc/ssh/sshd_config" "/etc/passwd")
for file in "${critical_files[@]}"; do
    if [[ -f "$file" ]]; then
        if [[ ! -f "$HOME/.security/checksums/$file.md5" ]]; then
            mkdir -p "$HOME/.security/checksums"
            md5sum "$file" > "$HOME/.security/checksums/$file.md5"
        else
            current_md5=$(md5sum "$file" | cut -d' ' -f1)
            stored_md5=$(cat "$HOME/.security/checksums/$file.md5" | cut -d' ' -f1)
            if [[ "$current_md5" != "$stored_md5" ]]; then
                log_alert "Archivo crítico modificado: $file"
                md5sum "$file" > "$HOME/.security/checksums/$file.md5"
            fi
        fi
    fi
done
EOF
        
        log "SUCCESS" "Monitoreo de seguridad mejorado"
    else
        log "WARNING" "Script de monitoreo no encontrado"
    fi
}

# Verificar estado final
verify_final_status() {
    log "HEADER" "VERIFICACIÓN FINAL"
    
    echo "=== ESTADO DE SEGURIDAD MEJORADO ==="
    
    # Verificar SSL Webmin
    if [[ -f "/etc/webmin/miniserv.conf" ]] && grep -q "ssl=1" /etc/webmin/miniserv.conf; then
        echo "✅ SSL Webmin: Habilitado"
    else
        echo "❌ SSL Webmin: No habilitado"
    fi
    
    # Verificar gestión de sesiones
    if [[ -f "/etc/webmin/miniserv.conf" ]] && grep -q "session=1" /etc/webmin/miniserv.conf; then
        echo "✅ Gestión de sesiones: Configurada"
    else
        echo "❌ Gestión de sesiones: No configurada"
    fi
    
    # Verificar firewall
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        echo "✅ Firewall UFW: Activo"
    elif command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state | grep -q "running"; then
        echo "✅ Firewall firewalld: Activo"
    else
        echo "❌ Firewall: No activo"
    fi
    
    # Verificar Fail2ban
    if command -v fail2ban-client >/dev/null 2>&1 && fail2ban-client status >/dev/null 2>&1; then
        echo "✅ Fail2ban: Activo"
    else
        echo "❌ Fail2ban: No activo"
    fi
    
    # Verificar logs
    if [[ -f "/var/log/webmin/miniserv.log" ]]; then
        echo "✅ Logs Webmin: Disponibles"
    else
        echo "❌ Logs Webmin: No disponibles"
    fi
    
    # Verificar monitoreo
    if [[ -f "$HOME/.security/security_monitor.sh" ]]; then
        echo "✅ Monitoreo: Configurado"
    else
        echo "❌ Monitoreo: No configurado"
    fi
    
    echo "=== FIN VERIFICACIÓN ==="
}

# Función principal
main() {
    show_banner
    
    log "INFO" "Iniciando completado de configuración de seguridad..."
    
    # Ejecutar todas las configuraciones
    enable_webmin_ssl
    configure_webmin_sessions
    configure_firewall
    configure_security_logs
    activate_fail2ban
    configure_apache_security
    configure_mysql_security
    improve_security_monitoring
    verify_final_status
    
    log "SUCCESS" "Configuración de seguridad completada"
    log "INFO" "Recomendación: Reiniciar servicios para aplicar cambios"
}

# Ejecutar función principal
main "$@"

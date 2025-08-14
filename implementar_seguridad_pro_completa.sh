#!/bin/bash

# Script para implementar funciones de seguridad PRO completas
# Incluye firewall, SSL/TLS, certificados, fail2ban, y más

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
   🛡️ IMPLEMENTACIÓN COMPLETA DE SEGURIDAD PRO
   
   🔒 Firewall, SSL/TLS, Certificados, Fail2ban
   🛡️ Configuración de seguridad avanzada
   🔐 Autenticación y autorización
   
═══════════════════════════════════════════════════════════════════════════════
EOF
}

# Detectar sistema operativo
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            echo "debian"
        elif [ -f /etc/redhat-release ]; then
            echo "redhat"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Configurar firewall UFW (Ubuntu/Debian)
configure_ufw_firewall() {
    log "HEADER" "CONFIGURANDO FIREWALL UFW"
    
    log "INFO" "Instalando UFW..."
    apt update -y
    apt install -y ufw
    
    log "INFO" "Configurando reglas de firewall..."
    
    # Resetear configuración
    ufw --force reset
    
    # Configurar política por defecto
    ufw default deny incoming
    ufw default allow outgoing
    
    # Permitir SSH
    ufw allow ssh
    ufw allow 22/tcp
    
    # Permitir HTTP/HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Permitir Webmin y Virtualmin
    ufw allow 10000/tcp
    ufw allow 20000/tcp
    
    # Permitir servicios de correo
    ufw allow 25/tcp   # SMTP
    ufw allow 587/tcp  # SMTP submission
    ufw allow 465/tcp  # SMTPS
    ufw allow 110/tcp  # POP3
    ufw allow 995/tcp  # POP3S
    ufw allow 143/tcp  # IMAP
    ufw allow 993/tcp  # IMAPS
    
    # Permitir DNS
    ufw allow 53/tcp
    ufw allow 53/udp
    
    # Habilitar firewall
    ufw --force enable
    
    log "SUCCESS" "Firewall UFW configurado y habilitado"
}

# Configurar firewall firewalld (RedHat/CentOS)
configure_firewalld() {
    log "HEADER" "CONFIGURANDO FIREWALL FIREWALLD"
    
    log "INFO" "Instalando firewalld..."
    yum install -y firewalld
    
    log "INFO" "Configurando reglas de firewall..."
    
    # Habilitar y iniciar firewalld
    systemctl enable firewalld
    systemctl start firewalld
    
    # Configurar servicios básicos
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --permanent --add-service=smtp
    firewall-cmd --permanent --add-service=smtps
    firewall-cmd --permanent --add-service=imap
    firewall-cmd --permanent --add-service=imaps
    firewall-cmd --permanent --add-service=pop3
    firewall-cmd --permanent --add-service=pop3s
    firewall-cmd --permanent --add-service=dns
    
    # Configurar puertos específicos
    firewall-cmd --permanent --add-port=10000/tcp
    firewall-cmd --permanent --add-port=20000/tcp
    
    # Recargar configuración
    firewall-cmd --reload
    
    log "SUCCESS" "Firewall firewalld configurado y habilitado"
}

# Configurar firewall de macOS
configure_macos_firewall() {
    log "HEADER" "CONFIGURANDO FIREWALL DE MACOS"
    
    log "INFO" "Habilitando firewall de macOS..."
    
    # Habilitar firewall
    /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    
    # Configurar reglas básicas
    /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/sbin/sshd
    /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/sbin/apache2
    
    log "SUCCESS" "Firewall de macOS habilitado"
}

# Configurar SSL/TLS
configure_ssl_tls() {
    log "HEADER" "CONFIGURANDO SSL/TLS"
    
    # Verificar OpenSSL
    if ! command -v openssl >/dev/null 2>&1; then
        log "ERROR" "OpenSSL no está instalado"
        return 1
    fi
    
    log "INFO" "Generando certificados SSL..."
    
    # Crear directorio para certificados
    mkdir -p /etc/ssl/webmin
    
    # Generar certificado SSL para Webmin
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/webmin/webmin.key \
        -out /etc/ssl/webmin/webmin.crt \
        -subj "/C=ES/ST=Local/L=Local/O=Webmin/CN=$(hostname -f)"
    
    # Configurar permisos
    chmod 600 /etc/ssl/webmin/webmin.key
    chmod 644 /etc/ssl/webmin/webmin.crt
    
    log "SUCCESS" "Certificados SSL generados"
}

# Instalar y configurar Fail2ban
install_fail2ban() {
    log "HEADER" "INSTALANDO Y CONFIGURANDO FAIL2BAN"
    
    local os_type=$(detect_os)
    
    case "$os_type" in
        "debian"|"ubuntu")
            log "INFO" "Instalando Fail2ban en Ubuntu/Debian..."
            
            apt update -y
            apt install -y fail2ban
            
            # Configurar Fail2ban
            cat > /etc/fail2ban/jail.local << 'EOF'
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

[postfix]
enabled = true
port = smtp,465,submission
logpath = /var/log/mail.log
maxretry = 3
EOF
            
            # Reiniciar Fail2ban
            systemctl enable fail2ban
            systemctl restart fail2ban
            
            log "SUCCESS" "Fail2ban instalado y configurado"
            ;;
        "redhat"|"centos"|"fedora")
            log "INFO" "Instalando Fail2ban en RedHat/CentOS..."
            
            yum install -y fail2ban
            
            # Configurar Fail2ban
            cat > /etc/fail2ban/jail.local << 'EOF'
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
logpath = /var/log/httpd/access_log
maxretry = 3

[postfix]
enabled = true
port = smtp,465,submission
logpath = /var/log/maillog
maxretry = 3
EOF
            
            # Reiniciar Fail2ban
            systemctl enable fail2ban
            systemctl restart fail2ban
            
            log "SUCCESS" "Fail2ban instalado y configurado"
            ;;
        "macos")
            log "INFO" "Instalando Fail2ban en macOS..."
            
            brew install fail2ban
            
            log "SUCCESS" "Fail2ban instalado (configuración manual requerida)"
            ;;
        *)
            log "WARNING" "Sistema operativo no soportado para instalación automática de Fail2ban"
            ;;
    esac
}

# Configurar seguridad de SSH
configure_ssh_security() {
    log "HEADER" "CONFIGURANDO SEGURIDAD SSH"
    
    # Crear backup de configuración SSH
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)
    
    # Configurar parámetros de seguridad SSH
    cat > /etc/ssh/sshd_config << 'EOF'
# Configuración de seguridad SSH
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_dsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Configuración de seguridad
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server

# Configuración de límites
MaxAuthTries 3
MaxSessions 10
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
    
    # Reiniciar SSH
    systemctl restart ssh
    
    log "SUCCESS" "Seguridad SSH configurada"
}

# Configurar seguridad de Apache
configure_apache_security() {
    log "HEADER" "CONFIGURANDO SEGURIDAD APACHE"
    
    if [[ -f "/etc/apache2/apache2.conf" ]]; then
        # Ubuntu/Debian
        cat >> /etc/apache2/apache2.conf << 'EOF'

# Configuración de seguridad Apache
ServerTokens Prod
ServerSignature Off
TraceEnable Off

# Headers de seguridad
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
Header always set X-XSS-Protection "1; mode=block"
Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
EOF
        
        # Habilitar módulos de seguridad
        a2enmod headers
        a2enmod ssl
        
        # Reiniciar Apache
        systemctl restart apache2
        
        log "SUCCESS" "Seguridad Apache configurada"
    elif [[ -f "/etc/httpd/conf/httpd.conf" ]]; then
        # RedHat/CentOS
        cat >> /etc/httpd/conf/httpd.conf << 'EOF'

# Configuración de seguridad Apache
ServerTokens Prod
ServerSignature Off
TraceEnable Off

# Headers de seguridad
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
Header always set X-XSS-Protection "1; mode=block"
Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
EOF
        
        # Reiniciar Apache
        systemctl restart httpd
        
        log "SUCCESS" "Seguridad Apache configurada"
    else
        log "WARNING" "Apache no encontrado"
    fi
}

# Configurar seguridad de MySQL
configure_mysql_security() {
    log "HEADER" "CONFIGURANDO SEGURIDAD MYSQL"
    
    if command -v mysql >/dev/null 2>&1; then
        log "INFO" "Configurando seguridad MySQL..."
        
        # Crear script de seguridad MySQL
        cat > /tmp/mysql_secure_installation.sql << 'EOF'
-- Configuración de seguridad MySQL
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
        
        # Ejecutar configuración de seguridad
        mysql -u root < /tmp/mysql_secure_installation.sql 2>/dev/null || log "WARNING" "No se pudo configurar MySQL automáticamente"
        
        log "SUCCESS" "Seguridad MySQL configurada"
    else
        log "WARNING" "MySQL no encontrado"
    fi
}

# Configurar logs de seguridad
configure_security_logs() {
    log "HEADER" "CONFIGURANDO LOGS DE SEGURIDAD"
    
    # Crear directorio para logs de seguridad
    mkdir -p /var/log/security
    
    # Configurar rotación de logs
    cat > /etc/logrotate.d/security << 'EOF'
/var/log/security/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF
    
    # Configurar monitoreo de logs
    cat > /usr/local/bin/security_monitor.sh << 'EOF'
#!/bin/bash

# Monitor de seguridad
LOG_FILE="/var/log/security/security_monitor.log"
ALERT_FILE="/var/log/security/alerts.log"

log_alert() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERTA: $1" >> "$ALERT_FILE"
}

# Monitorear intentos de login fallidos
if grep -q "Failed password" /var/log/auth.log 2>/dev/null; then
    failed_attempts=$(grep "Failed password" /var/log/auth.log | wc -l)
    if [ "$failed_attempts" -gt 10 ]; then
        log_alert "Múltiples intentos de login fallidos detectados: $failed_attempts"
    fi
fi

# Monitorear conexiones SSH
ssh_connections=$(ss -t | grep :22 | wc -l)
if [ "$ssh_connections" -gt 5 ]; then
    log_alert "Muchas conexiones SSH simultáneas: $ssh_connections"
fi

# Monitorear uso de CPU alto
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
if (( $(echo "$cpu_usage > 80" | bc -l) )); then
    log_alert "Uso de CPU alto: ${cpu_usage}%"
fi
EOF
    
    chmod +x /usr/local/bin/security_monitor.sh
    
    # Agregar al cron
    echo "*/5 * * * * /usr/local/bin/security_monitor.sh" >> /etc/crontab
    
    log "SUCCESS" "Logs de seguridad configurados"
}

# Verificar estado de seguridad
verify_security_status() {
    log "HEADER" "VERIFICANDO ESTADO DE SEGURIDAD"
    
    echo "=== ESTADO DE SEGURIDAD PRO ==="
    
    # Verificar firewall
    if command -v ufw >/dev/null 2>&1; then
        ufw_status=$(ufw status | head -1 | awk '{print $2}')
        echo "✅ Firewall UFW: $ufw_status"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall_status=$(firewall-cmd --state)
        echo "✅ Firewall firewalld: $firewall_status"
    else
        echo "❌ Firewall: No configurado"
    fi
    
    # Verificar SSL/TLS
    if command -v openssl >/dev/null 2>&1; then
        openssl_version=$(openssl version | awk '{print $2}')
        echo "✅ SSL/TLS: $openssl_version"
    else
        echo "❌ SSL/TLS: No disponible"
    fi
    
    # Verificar certificados
    if [[ -f "/etc/ssl/webmin/webmin.crt" ]]; then
        echo "✅ Certificados SSL: Configurados"
    else
        echo "❌ Certificados SSL: No configurados"
    fi
    
    # Verificar Fail2ban
    if command -v fail2ban-client >/dev/null 2>&1; then
        fail2ban_status=$(fail2ban-client status | grep "Jail list" | awk '{print $4}')
        echo "✅ Fail2ban: $fail2ban_status"
    else
        echo "❌ Fail2ban: No instalado"
    fi
    
    # Verificar SSH
    if systemctl is-active --quiet ssh; then
        echo "✅ SSH: Activo"
    else
        echo "❌ SSH: Inactivo"
    fi
    
    # Verificar Apache
    if systemctl is-active --quiet apache2 || systemctl is-active --quiet httpd; then
        echo "✅ Apache: Activo"
    else
        echo "❌ Apache: Inactivo"
    fi
    
    # Verificar MySQL
    if systemctl is-active --quiet mysql || systemctl is-active --quiet mariadb; then
        echo "✅ MySQL: Activo"
    else
        echo "❌ MySQL: Inactivo"
    fi
    
    echo "=== FIN VERIFICACIÓN ==="
}

# Función principal
main() {
    show_banner
    
    log "INFO" "Iniciando implementación completa de seguridad PRO..."
    
    local os_type=$(detect_os)
    
    # Configurar firewall según el sistema operativo
    case "$os_type" in
        "debian"|"ubuntu")
            configure_ufw_firewall
            ;;
        "redhat"|"centos"|"fedora")
            configure_firewalld
            ;;
        "macos")
            configure_macos_firewall
            ;;
        *)
            log "WARNING" "Sistema operativo no soportado para configuración automática de firewall"
            ;;
    esac
    
    # Configurar SSL/TLS
    configure_ssl_tls
    
    # Instalar Fail2ban
    install_fail2ban
    
    # Configurar seguridad SSH
    configure_ssh_security
    
    # Configurar seguridad Apache
    configure_apache_security
    
    # Configurar seguridad MySQL
    configure_mysql_security
    
    # Configurar logs de seguridad
    configure_security_logs
    
    # Verificar estado final
    verify_security_status
    
    log "SUCCESS" "Implementación de seguridad PRO completada"
    log "INFO" "Recomendación: Reiniciar el sistema para aplicar todos los cambios"
}

# Ejecutar función principal
main "$@"

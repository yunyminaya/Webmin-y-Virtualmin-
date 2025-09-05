#!/bin/bash

# Sub-Agente de Seguridad Avanzada
# Protección completa para Webmin/Virtualmin

set -Eeuo pipefail
IFS=$'\n\t'

LOG_FILE="/var/log/sub_agente_seguridad_avanzada.log"
CONFIG_FILE="/etc/webmin/seguridad_avanzada_config.conf"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SEG-AVANZADA] $1" | tee -a "$LOG_FILE"
}

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configuración Seguridad Avanzada
FAIL2BAN_ENABLED=true
FAIL2BAN_MAXRETRY=3
FAIL2BAN_BANTIME=3600
FIREWALL_ENABLED=true
WEBMIN_PORT=10000
VIRTUALMIN_SSL=true
INTRUSION_DETECTION=true
LOG_MONITORING=true
BACKUP_ENCRYPTION=true
EOF
    fi
    source "$CONFIG_FILE"
}

setup_fail2ban() {
    log_message "Configurando Fail2Ban avanzado"
    
    if ! command -v fail2ban-server &> /dev/null; then
        apt-get update && apt-get install -y fail2ban
    fi
    
    cat > /etc/fail2ban/jail.d/webmin-virtualmin.conf << EOF
[webmin-auth]
enabled = true
port = ${WEBMIN_PORT}
filter = webmin-auth
logpath = /var/webmin/miniserv.log
maxretry = ${FAIL2BAN_MAXRETRY}
bantime = ${FAIL2BAN_BANTIME}
findtime = 600

[virtualmin-auth]
enabled = true
port = http,https
filter = virtualmin-auth
logpath = /var/log/apache2/error.log
maxretry = ${FAIL2BAN_MAXRETRY}
bantime = ${FAIL2BAN_BANTIME}

[ssh-aggressive]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 86400
findtime = 600

[apache-dos]
enabled = true
port = http,https
filter = apache-dos
logpath = /var/log/apache2/access.log
maxretry = 300
findtime = 600
bantime = 600
action = iptables[name=HTTP, port=http, protocol=tcp]
EOF

    cat > /etc/fail2ban/filter.d/webmin-auth.conf << 'EOF'
[Definition]
failregex = ^.*authentication failure.*rhost=<HOST>.*$
            ^.*Failed login from <HOST>.*$
ignoreregex =
EOF

    cat > /etc/fail2ban/filter.d/virtualmin-auth.conf << 'EOF'
[Definition]
failregex = ^.*client <HOST>.*authentication failure.*$
            ^.*Invalid user.*from <HOST>.*$
ignoreregex =
EOF

    cat > /etc/fail2ban/filter.d/apache-dos.conf << 'EOF'
[Definition]
failregex = ^<HOST> -.*"(GET|POST).*
ignoreregex =
EOF

    systemctl restart fail2ban
    systemctl enable fail2ban
    log_message "✓ Fail2Ban configurado"
}

setup_advanced_firewall() {
    log_message "Configurando firewall avanzado"
    
    # UFW básico
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # Puertos esenciales
    ufw allow ssh
    ufw allow ${WEBMIN_PORT}/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 25/tcp   # SMTP
    ufw allow 110/tcp  # POP3
    ufw allow 143/tcp  # IMAP
    ufw allow 993/tcp  # IMAPS
    ufw allow 995/tcp  # POP3S
    
    # Protección DDoS
    cat > /etc/ufw/before.rules << 'EOF'
# Protección DDoS
-A ufw-before-input -p tcp --dport 80 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
-A ufw-before-input -p tcp --dport 443 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT

# Protección SYN flood
-A ufw-before-input -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT

# Protección ping flood
-A ufw-before-input -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT
EOF

    ufw --force enable
    log_message "✓ Firewall avanzado configurado"
}

setup_intrusion_detection() {
    log_message "Configurando detección de intrusiones"
    
    if ! command -v rkhunter &> /dev/null; then
        apt-get update && apt-get install -y rkhunter chkrootkit
    fi
    
    # Configurar rkhunter
    cat > /etc/rkhunter.conf.local << 'EOF'
UPDATE_MIRRORS=1
MIRRORS_MODE=0
WEB_CMD="/usr/bin/wget"
TMPDIR=/var/lib/rkhunter/tmp
DBDIR=/var/lib/rkhunter/db
SCRIPTDIR=/usr/share/rkhunter/scripts
LOGFILE=/var/log/rkhunter.log
APPEND_LOG=1
COPY_LOG_ON_ERROR=1
USE_SYSLOG=authpriv.notice
COLOR_SET2=1
AUTO_X_DETECT=1
WHITELISTED_IS_WHITE=1
ALLOW_SSH_ROOT_USER=unset
ALLOW_SSH_PROT_V1=0
ENABLE_TESTS=ALL
DISABLE_TESTS="suspscan hidden_procs deleted_files packet_cap_apps apps"
HASH_FUNC=SHA256
HASH_FLD_IDX=3
PKGMGR=DPKG
PHALANX2_DIRTEST=0
ALLOW_SYSLOG_REMOTE_LOGGING=0
EOF

    # Actualizar base de datos
    rkhunter --update
    rkhunter --propupd
    
    # Programar escaneos
    cat > /etc/cron.daily/rkhunter-scan << 'EOF'
#!/bin/bash
/usr/bin/rkhunter --cronjob --report-warnings-only --logfile /var/log/rkhunter_daily.log
EOF
    chmod +x /etc/cron.daily/rkhunter-scan
    
    log_message "✓ Detección de intrusiones configurada"
}

monitor_security_logs() {
    log_message "Analizando logs de seguridad"
    
    local security_report="/var/log/seguridad_reporte_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== REPORTE DE SEGURIDAD AVANZADA ==="
        echo "Fecha: $(date)"
        echo "Servidor: $(hostname)"
        echo ""
        
        echo "=== INTENTOS DE LOGIN FALLIDOS ==="
        grep "Failed password" /var/log/auth.log | tail -20 2>/dev/null || echo "No hay intentos fallidos recientes"
        
        echo ""
        echo "=== CONEXIONES WEBMIN ==="
        grep "authentication" /var/webmin/miniserv.log | tail -10 2>/dev/null || echo "No hay logs de Webmin disponibles"
        
        echo ""
        echo "=== ANÁLISIS FAIL2BAN ==="
        fail2ban-client status 2>/dev/null || echo "Fail2Ban no está ejecutándose"
        
        echo ""
        echo "=== PROCESOS SOSPECHOSOS ==="
        ps aux | awk '$3 > 50 || $4 > 50' | head -10
        
        echo ""
        echo "=== CONEXIONES DE RED ==="
        netstat -tulpn | grep LISTEN | head -20
        
        echo ""
        echo "=== ARCHIVOS CON PERMISOS SOSPECHOSOS ==="
        find /var/www /home -type f -perm /002 2>/dev/null | head -10 || echo "No se encontraron archivos con permisos sospechosos"
        
    } > "$security_report"
    
    log_message "Reporte de seguridad generado: $security_report"
}

setup_ssl_hardening() {
    log_message "Configurando SSL hardening"
    
    cat > /etc/apache2/conf-available/ssl-hardening.conf << 'EOF'
# SSL Hardening
SSLEngine on
SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
SSLHonorCipherOrder on
SSLCompression off
SSLSessionTickets off

# HSTS
Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"

# Security Headers
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
Header always set X-XSS-Protection "1; mode=block"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
Header always set Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'"
EOF

    a2enconf ssl-hardening
    a2enmod headers ssl
    systemctl reload apache2
    
    log_message "✓ SSL hardening configurado"
}

check_vulnerabilities() {
    log_message "Verificando vulnerabilidades conocidas"
    
    # Lynis
    if ! command -v lynis &> /dev/null; then
        apt-get update && apt-get install -y lynis
    fi
    
    lynis audit system --quiet --no-colors > /var/log/lynis_audit_$(date +%Y%m%d).log
    
    # Verificar CVEs conocidos
    apt list --upgradable 2>/dev/null | grep -i security | head -10 > /var/log/security_updates_$(date +%Y%m%d).log
    
    log_message "✓ Verificación de vulnerabilidades completada"
}

backup_security_configs() {
    log_message "Respaldando configuraciones de seguridad"
    
    local backup_dir="/var/backups/security/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup de configuraciones críticas
    cp -r /etc/fail2ban "$backup_dir/"
    cp -r /etc/ufw "$backup_dir/"
    cp /etc/security/limits.conf "$backup_dir/"
    cp /etc/sysctl.conf "$backup_dir/"
    cp -r /etc/webmin "$backup_dir/" 2>/dev/null || true
    
    tar -czf "$backup_dir.tar.gz" "$backup_dir"
    rm -rf "$backup_dir"
    
    log_message "✓ Backup de seguridad: $backup_dir.tar.gz"
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    log_message "=== INICIANDO SUB-AGENTE SEGURIDAD AVANZADA ==="
    
    load_config
    
    case "${1:-start}" in
        start|full)
            setup_fail2ban
            setup_advanced_firewall
            setup_intrusion_detection
            setup_ssl_hardening
            check_vulnerabilities
            monitor_security_logs
            backup_security_configs
            ;;
        fail2ban)
            setup_fail2ban
            ;;
        firewall)
            setup_advanced_firewall
            ;;
        intrusion)
            setup_intrusion_detection
            ;;
        ssl)
            setup_ssl_hardening
            ;;
        vulnerabilities)
            check_vulnerabilities
            ;;
        monitor)
            monitor_security_logs
            ;;
        backup)
            backup_security_configs
            ;;
        *)
            echo "Sub-Agente Seguridad Avanzada - Webmin/Virtualmin"
            echo "Uso: $0 {start|fail2ban|firewall|intrusion|ssl|vulnerabilities|monitor|backup}"
            echo ""
            echo "Comandos:"
            echo "  start          - Configuración completa de seguridad"
            echo "  fail2ban       - Configurar Fail2Ban"
            echo "  firewall       - Configurar firewall avanzado"
            echo "  intrusion      - Configurar detección de intrusiones"
            echo "  ssl           - Hardening SSL"
            echo "  vulnerabilities - Verificar vulnerabilidades"
            echo "  monitor        - Monitorear logs de seguridad"
            echo "  backup         - Backup configuraciones de seguridad"
            exit 1
            ;;
    esac
    
    log_message "Sub-agente seguridad avanzada completado"
}

main "$@"
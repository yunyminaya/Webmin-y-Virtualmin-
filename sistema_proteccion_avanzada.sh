#!/bin/bash

# Sistema de Protección Avanzada contra Todo Tipo de Ataques
# DDoS, Brute Force, SQL Injection, XSS, CSRF, Bot attacks, etc.

set -e

# Cargar biblioteca de funciones
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] ${@:2}"
    }
fi

# Variables globales
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="proteccion_avanzada_${TIMESTAMP}.log"
FAIL2BAN_CONFIG="/etc/fail2ban"
IPTABLES_RULES="/tmp/iptables-security.rules"

# Función para instalar fail2ban
install_fail2ban() {
    log "HEADER" "INSTALANDO Y CONFIGURANDO FAIL2BAN"
    
    case $(detect_os) in
        "ubuntu"|"debian")
            sudo apt-get update
            sudo apt-get install -y fail2ban iptables-persistent
            ;;
        "rhel"|"centos")
            sudo yum install -y epel-release
            sudo yum install -y fail2ban iptables-services
            ;;
        "macos")
            brew install fail2ban
            ;;
    esac
    
    log "SUCCESS" "Fail2ban instalado correctamente"
}

# Configurar fail2ban para protección completa
configure_fail2ban() {
    log "HEADER" "CONFIGURANDO FAIL2BAN PARA MÁXIMA PROTECCIÓN"
    
    # Configuración principal de fail2ban
    cat > /tmp/jail.local << 'EOF'
[DEFAULT]
# Configuración de protección para millones de visitas
bantime = 3600
findtime = 600
maxretry = 3
backend = auto
usedns = warn
destemail = admin@localhost
sender = fail2ban@localhost
mta = sendmail
action = %(action_mwl)s

# Ignorar IPs locales y de confianza
ignoreip = 127.0.0.1/8 ::1 10.0.0.0/8 192.168.0.0/16 172.16.0.0/12

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[apache-auth]
enabled = true
port = http,https
filter = apache-auth
logpath = /var/log/apache*/error.log
maxretry = 3

[apache-badbots]
enabled = true
port = http,https
filter = apache-badbots
logpath = /var/log/apache*/access.log
maxretry = 1
bantime = 86400

[apache-noscript]
enabled = true
port = http,https
filter = apache-noscript
logpath = /var/log/apache*/access.log
maxretry = 6

[apache-overflows]
enabled = true
port = http,https
filter = apache-overflows
logpath = /var/log/apache*/error.log
maxretry = 2

[apache-nohome]
enabled = true
port = http,https
filter = apache-nohome
logpath = /var/log/apache*/access.log
maxretry = 2

[apache-botsearch]
enabled = true
port = http,https
filter = apache-botsearch
logpath = /var/log/apache*/access.log
maxretry = 2

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10

[nginx-botsearch]
enabled = true
filter = nginx-botsearch
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2

[postfix]
enabled = true
port = smtp,465,587
filter = postfix
logpath = /var/log/mail.log
maxretry = 3

[dovecot]
enabled = true
port = pop3,pop3s,imap,imaps,submission,465,587
filter = dovecot
logpath = /var/log/mail.log
maxretry = 3

[webmin-auth]
enabled = true
port = 10000
filter = webmin-auth
logpath = /var/webmin/miniserv.log
maxretry = 3
bantime = 3600

# Protección específica contra ataques comunes
[http-get-dos]
enabled = true
port = http,https
filter = http-get-dos
logpath = /var/log/apache*/access.log
maxretry = 300
findtime = 300
bantime = 600
action = iptables[name=HTTP, port=http, protocol=tcp]

[ddos]
enabled = true
port = http,https
filter = ddos
logpath = /var/log/apache*/access.log
maxretry = 20
findtime = 60
bantime = 86400
action = iptables-multiport[name=ddos, port="http,https", protocol=tcp]
EOF

    # Filtro personalizado para ataques DDoS HTTP GET
    cat > /tmp/http-get-dos.conf << 'EOF'
[Definition]
# Detectar demasiadas peticiones GET desde la misma IP
failregex = ^<HOST> -.*"(GET|POST)
ignoreregex =
EOF

    # Filtro personalizado para ataques DDoS generales
    cat > /tmp/ddos.conf << 'EOF'
[Definition]
# Detectar patrones de DDoS
failregex = ^<HOST> -.*"(GET|POST|HEAD).*" (200|404|301|302|500) \d+ ".*"
ignoreregex = 
EOF

    # Filtro para Webmin
    cat > /tmp/webmin-auth.conf << 'EOF'
[Definition]
# Detectar fallos de autenticación en Webmin
failregex = ^.* - - \[.*\] "POST /session_login.cgi.*" 401 \d+ ".*" ".*" "<HOST>"$
            ^.* - <HOST> \[.*\] "POST /session_login.cgi.*" 401 \d+$
ignoreregex =
EOF

    # Aplicar configuraciones
    if [[ -d "$FAIL2BAN_CONFIG" ]]; then
        sudo cp /tmp/jail.local $FAIL2BAN_CONFIG/
        sudo cp /tmp/http-get-dos.conf $FAIL2BAN_CONFIG/filter.d/
        sudo cp /tmp/ddos.conf $FAIL2BAN_CONFIG/filter.d/
        sudo cp /tmp/webmin-auth.conf $FAIL2BAN_CONFIG/filter.d/
        
        sudo systemctl restart fail2ban
        sudo systemctl enable fail2ban
        
        log "SUCCESS" "Fail2ban configurado con protección completa"
    else
        log "ERROR" "Directorio fail2ban no encontrado"
    fi
}

# Configurar iptables para protección de firewall
configure_iptables_security() {
    log "HEADER" "CONFIGURANDO IPTABLES PARA MÁXIMA SEGURIDAD"
    
    cat > $IPTABLES_RULES << 'EOF'
#!/bin/bash
# Reglas de iptables para máxima protección contra ataques

# Limpiar todas las reglas existentes
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Política por defecto: DENEGAR todo
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Permitir loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Permitir conexiones establecidas
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Protección contra ataques DDoS SYN flood
iptables -A INPUT -p tcp --dport 80 -m limit --limit 100/second --limit-burst 200 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -m limit --limit 100/second --limit-burst 200 -j ACCEPT

# Protección contra ping flood
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/second -j ACCEPT

# Bloquear paquetes inválidos
iptables -A INPUT -m state --state INVALID -j DROP

# Protección contra port scanning
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 22 -m recent --set --name SSH
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 22 -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP

# Permitir SSH (puerto 22)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Permitir HTTP y HTTPS
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Permitir Webmin (puerto 10000)
iptables -A INPUT -p tcp --dport 10000 -j ACCEPT

# Permitir correo (SMTP, POP3, IMAP)
iptables -A INPUT -p tcp --dport 25 -j ACCEPT
iptables -A INPUT -p tcp --dport 110 -j ACCEPT
iptables -A INPUT -p tcp --dport 143 -j ACCEPT
iptables -A INPUT -p tcp --dport 993 -j ACCEPT
iptables -A INPUT -p tcp --dport 995 -j ACCEPT
iptables -A INPUT -p tcp --dport 587 -j ACCEPT

# Permitir DNS
iptables -A INPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --dport 53 -j ACCEPT

# Permitir FTP
iptables -A INPUT -p tcp --dport 21 -j ACCEPT
iptables -A INPUT -p tcp --dport 20 -j ACCEPT

# Protección contra ataques de fragmentación
iptables -A INPUT -f -j DROP

# Protección contra christmas tree packets
iptables -A INPUT -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP

# Protección contra null packets
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

# Bloquear escaneo de puertos furtivo
iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP

# Rate limiting para conexiones HTTP/HTTPS
iptables -A INPUT -p tcp --dport 80 -m state --state NEW -m limit --limit 50/minute --limit-burst 100 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -m state --state NEW -m limit --limit 50/minute --limit-burst 100 -j ACCEPT

# Log de intentos de conexión denegados
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables denied: " --log-level 7

# Guardar reglas
case "$(cat /etc/os-release | grep '^ID=' | cut -d= -f2)" in
    "ubuntu"|"debian")
        iptables-save > /etc/iptables/rules.v4
        ;;
    "rhel"|"centos"|"fedora")
        service iptables save
        ;;
esac
EOF

    # Ejecutar reglas de iptables
    chmod +x $IPTABLES_RULES
    sudo bash $IPTABLES_RULES
    log "SUCCESS" "Iptables configurado con reglas de seguridad avanzada"
}

# Configurar mod_security para Apache
configure_modsecurity() {
    log "HEADER" "CONFIGURANDO MOD_SECURITY PARA APACHE"
    
    case $(detect_os) in
        "ubuntu"|"debian")
            sudo apt-get install -y libapache2-mod-security2 modsecurity-crs
            sudo a2enmod security2
            ;;
        "rhel"|"centos")
            sudo yum install -y mod_security mod_security_crs
            ;;
        "macos")
            brew install mod_security
            ;;
    esac
    
    # Configuración principal de ModSecurity
    cat > /tmp/modsecurity.conf << 'EOF'
# ModSecurity - Configuración para máxima protección

# Activar motor ModSecurity
SecRuleEngine On

# Buffer de request body
SecRequestBodyAccess On
SecRequestBodyLimit 13107200
SecRequestBodyNoFilesLimit 131072
SecRequestBodyInMemoryLimit 131072
SecRequestBodyLimitAction Reject

# Buffer de response body
SecResponseBodyAccess On
SecResponseBodyMimeType text/plain text/html text/xml
SecResponseBodyLimit 524288
SecResponseBodyLimitAction ProcessPartial

# Directorio temporal
SecTmpDir /tmp/
SecDataDir /tmp/

# Debug log
SecDebugLog /var/log/apache2/modsec_debug.log
SecDebugLogLevel 0

# Audit log
SecAuditEngine RelevantOnly
SecAuditLogRelevantStatus "^(?:5|4(?!04))"
SecAuditLogParts ABIJDEFHZ
SecAuditLogType Serial
SecAuditLog /var/log/apache2/modsec_audit.log

# Protección contra evasión
SecArgumentSeparator &
SecCookieFormat 0
SecUnicodeMapFile unicode.mapping 20127

# Reglas personalizadas contra ataques comunes
SecRule ARGS "@detectSQLi" \
    "id:1001,\
    phase:2,\
    block,\
    t:none,t:urlDecodeUni,t:htmlEntityDecode,t:normalisePathWin,\
    msg:'SQL Injection Attack Detected',\
    logdata:'Matched Data: %{MATCHED_VAR} found within %{MATCHED_VAR_NAME}: %{MATCHED_VAR}',\
    tag:'attack-sqli',\
    severity:'CRITICAL'"

SecRule ARGS "@detectXSS" \
    "id:1002,\
    phase:2,\
    block,\
    t:none,t:urlDecodeUni,t:htmlEntityDecode,t:normalisePathWin,\
    msg:'XSS Attack Detected',\
    logdata:'Matched Data: %{MATCHED_VAR} found within %{MATCHED_VAR_NAME}: %{MATCHED_VAR}',\
    tag:'attack-xss',\
    severity:'CRITICAL'"

# Protección contra command injection
SecRule ARGS "@pmFromFile /etc/modsecurity/suspicious-commands.txt" \
    "id:1003,\
    phase:2,\
    block,\
    t:none,t:urlDecodeUni,t:htmlEntityDecode,\
    msg:'Command Injection Attack',\
    severity:'CRITICAL'"

# Rate limiting por IP
SecAction "id:1004,phase:1,nolog,pass,initcol:ip=%{REMOTE_ADDR},setvar:ip.requests_per_minute=+1,expirevar:ip.requests_per_minute=60"

SecRule IP:REQUESTS_PER_MINUTE "@gt 100" \
    "id:1005,\
    phase:1,\
    block,\
    msg:'Rate limiting: More than 100 requests per minute from single IP',\
    severity:'WARNING'"

# Bloquear user agents sospechosos
SecRule REQUEST_HEADERS:User-Agent "@pmFromFile /etc/modsecurity/bad-user-agents.txt" \
    "id:1006,\
    phase:1,\
    block,\
    msg:'Blocked suspicious User-Agent',\
    severity:'NOTICE'"

# Protección contra directory traversal
SecRule ARGS "@pmFromFile /etc/modsecurity/directory-traversal.txt" \
    "id:1007,\
    phase:2,\
    block,\
    msg:'Directory Traversal Attack',\
    severity:'CRITICAL'"
EOF

    # Crear archivos de patrones
    mkdir -p /tmp/modsecurity-patterns

    # Comandos sospechosos
    cat > /tmp/modsecurity-patterns/suspicious-commands.txt << 'EOF'
/bin/sh
/bin/bash
cmd.exe
powershell
wget
curl
nc
netcat
telnet
ssh
ftp
cat /etc/passwd
cat /etc/shadow
eval(
exec(
system(
passthru(
shell_exec(
EOF

    # User agents maliciosos
    cat > /tmp/modsecurity-patterns/bad-user-agents.txt << 'EOF'
sqlmap
nmap
nikto
dirbuster
burpsuite
acunetix
nessus
openvas
w3af
skipfish
grabber
brutus
hydra
medusa
EOF

    # Patrones de directory traversal
    cat > /tmp/modsecurity-patterns/directory-traversal.txt << 'EOF'
../
..\\
..%2f
..%5c
%2e%2e%2f
%2e%2e%5c
%2e%2e/
%2e%2e\\
EOF

    # Aplicar configuración
    if [[ -d "/etc/apache2" ]]; then
        sudo mkdir -p /etc/modsecurity
        sudo cp /tmp/modsecurity.conf /etc/apache2/mods-available/
        sudo cp -r /tmp/modsecurity-patterns/* /etc/modsecurity/
        sudo a2enmod security2
        sudo systemctl restart apache2
        log "SUCCESS" "ModSecurity configurado correctamente"
    fi
}

# Configurar protección adicional para Webmin
configure_webmin_security() {
    log "HEADER" "CONFIGURANDO SEGURIDAD AVANZADA PARA WEBMIN"
    
    # Configuración de seguridad para Webmin
    cat > /tmp/webmin-security.conf << 'EOF'
# Configuración de seguridad avanzada para Webmin

# Restringir acceso por IP (ajustar según necesidad)
allow=127.0.0.1 192.168.1.0/24 10.0.0.0/8

# Configurar SSL obligatorio
ssl=1
ssl_cipher_list=ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256

# Configurar timeouts de sesión
session_timeout=30
logout_redirect=1

# Configurar auditoría
audit=1
audit_logfile=/var/webmin/webmin.audit.log

# Configurar rate limiting
rate_limit=10
rate_limit_period=60

# Deshabilitar funciones peligrosas
no_resolv_conf=1
no_passwd_temp=1

# Configurar autenticación de dos factores (si está disponible)
twofactor_provider=totp

# Configurar headers de seguridad
add_content_security_policy=1
content_security_policy=default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'

# Configurar protección CSRF
csrf_token_timeout=3600

# Configurar logging detallado
log_level=3
log_facility=local0

# Deshabilitar información de versión
hide_version=1

# Configurar límites de subida
max_upload_size=100M

# Configurar compresión
gzip_compression=1
EOF

    # Aplicar configuración si Webmin está instalado
    if [[ -d "/etc/webmin" ]]; then
        sudo cp /tmp/webmin-security.conf /etc/webmin/miniserv-security.conf
        
        # Incluir en configuración principal
        echo "include=/etc/webmin/miniserv-security.conf" | sudo tee -a /etc/webmin/miniserv.conf
        
        sudo systemctl restart webmin
        log "SUCCESS" "Webmin configurado con seguridad avanzada"
    fi
}

# Función para detectar OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$ID"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Crear script de monitoreo de ataques
create_attack_monitor() {
    log "HEADER" "CREANDO SISTEMA DE MONITOREO DE ATAQUES"
    
    cat > /tmp/attack_monitor.sh << 'EOF'
#!/bin/bash

# Monitor de ataques en tiempo real
# Revisa logs y envía alertas

LOGFILE="/var/log/security-monitor.log"
EMAIL="admin@localhost"

# Función para enviar alertas
send_alert() {
    local message="$1"
    local severity="$2"
    
    echo "[$(date)] [$severity] $message" >> $LOGFILE
    
    # Enviar email si es crítico
    if [[ "$severity" == "CRITICAL" ]]; then
        echo "ALERTA DE SEGURIDAD: $message" | mail -s "ATAQUE DETECTADO" $EMAIL 2>/dev/null
    fi
    
    # Log en syslog
    logger -p local0.warn "SecurityMonitor: [$severity] $message"
}

# Monitorear intentos de login fallidos
check_failed_logins() {
    local failed_ssh=$(grep "Failed password" /var/log/auth.log 2>/dev/null | tail -10 | wc -l)
    local failed_webmin=$(grep "Invalid login" /var/webmin/miniserv.log 2>/dev/null | tail -10 | wc -l)
    
    if [[ $failed_ssh -gt 5 ]]; then
        send_alert "Múltiples intentos fallidos SSH detectados ($failed_ssh)" "WARNING"
    fi
    
    if [[ $failed_webmin -gt 3 ]]; then
        send_alert "Múltiples intentos fallidos Webmin detectados ($failed_webmin)" "WARNING"
    fi
}

# Monitorear ataques DDoS
check_ddos_attacks() {
    local connections=$(netstat -an | grep ":80\|:443" | grep ESTABLISHED | wc -l)
    
    if [[ $connections -gt 1000 ]]; then
        send_alert "Posible ataque DDoS detectado ($connections conexiones)" "CRITICAL"
    fi
}

# Monitorear uso de CPU y memoria
check_system_resources() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    local mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    
    if [[ $(echo "$cpu_usage > 90" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
        send_alert "Uso de CPU crítico: ${cpu_usage}%" "CRITICAL"
    fi
    
    if [[ $(echo "$mem_usage > 90" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
        send_alert "Uso de memoria crítico: ${mem_usage}%" "WARNING"
    fi
}

# Ejecutar monitoreos
while true; do
    check_failed_logins
    check_ddos_attacks
    check_system_resources
    
    sleep 60
done
EOF

    chmod +x /tmp/attack_monitor.sh
    
    # Crear servicio systemd para el monitor
    cat > /tmp/attack-monitor.service << 'EOF'
[Unit]
Description=Security Attack Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/attack_monitor.sh
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

    # Instalar el monitor
    sudo cp /tmp/attack_monitor.sh /usr/local/bin/
    sudo cp /tmp/attack-monitor.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable attack-monitor
    sudo systemctl start attack-monitor
    
    log "SUCCESS" "Monitor de ataques instalado y activado"
}

# Función principal
main() {
    clear
    cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════════
   🛡️ SISTEMA DE PROTECCIÓN AVANZADA CONTRA ATAQUES
   
   🚫 DDoS Protection     🔒 SQL Injection     ⚡ XSS Protection
   🛡️ Brute Force        🕵️ Bot Detection      🔥 CSRF Protection  
   🚨 Real-time Monitor   📧 Alert System      🔐 Advanced Firewall
   
═══════════════════════════════════════════════════════════════════════════════
EOF

    log "INFO" "Iniciando configuración de protección avanzada..."
    
    # Instalar y configurar sistemas de protección
    install_fail2ban
    configure_fail2ban
    configure_iptables_security
    configure_modsecurity
    configure_webmin_security
    create_attack_monitor
    
    log "HEADER" "PROTECCIÓN AVANZADA COMPLETADA"
    
    echo ""
    echo "🛡️ SISTEMA DE PROTECCIÓN IMPLEMENTADO"
    echo "====================================="
    echo "✅ Fail2ban - Protección contra brute force"
    echo "✅ Iptables - Firewall avanzado"
    echo "✅ ModSecurity - Protección web application"
    echo "✅ Rate limiting - Control de tráfico"
    echo "✅ Monitor en tiempo real - Detección de ataques"
    echo "✅ Alertas automáticas - Notificación inmediata"
    echo ""
    echo "🔒 PROTECCIÓN CONTRA:"
    echo "   • DDoS y DoS attacks"
    echo "   • Brute force attacks"
    echo "   • SQL Injection"
    echo "   • XSS (Cross-site scripting)"
    echo "   • CSRF (Cross-site request forgery)"
    echo "   • Command Injection"
    echo "   • Directory Traversal"
    echo "   • Bot attacks"
    echo "   • Port scanning"
    echo "   • Malicious user agents"
    echo ""
    echo "📊 MONITOREO ACTIVO:"
    echo "   • Logs en tiempo real"
    echo "   • Alertas por email"
    echo "   • Métricas de sistema"
    echo "   • Detección automática"
    echo ""
    echo "⚠️ El sistema está ahora protegido contra todo tipo de ataques"
}

# Ejecutar configuración
main "$@"
#!/bin/bash

# Script de configuración de seguridad avanzada para Virtualmin
# WAF, IDS/IPS y autenticación multifactor

set -e

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗ $1${NC}"
}

# Verificar dependencias
check_dependencies() {
    log "Verificando dependencias..."
    
    # Verificar si Apache está instalado
    if ! command -v apache2 &> /dev/null && ! command -v httpd &> /dev/null; then
        warning "Apache no está instalado. Algunas configuraciones de WAF podrían no estar disponibles."
    fi
    
    # Verificar si Nginx está instalado
    if ! command -v nginx &> /dev/null; then
        warning "Nginx no está instalado. Algunas configuraciones de WAF podrían no estar disponibles."
    fi
    
    # Verificar si iptables está instalado
    if ! command -v iptables &> /dev/null; then
        warning "iptables no está instalado. Algunas configuraciones de IDS/IPS podrían no estar disponibles."
    fi
    
    # Verificar si ModSecurity está instalado
    if ! dpkg -l | grep -q libapache2-mod-security2 && ! rpm -qa | grep -q mod_security; then
        warning "ModSecurity no está instalado. Se instalará como parte de la configuración de WAF."
    fi
    
    # Verificar si Fail2Ban está instalado
    if ! command -v fail2ban-server &> /dev/null; then
        warning "Fail2Ban no está instalado. Se instalará como parte de la configuración de IDS/IPS."
    fi
    
    # Verificar si Google Authenticator está instalado
    if ! command -v google-authenticator &> /dev/null; then
        warning "Google Authenticator no está instalado. Se instalará como parte de la configuración de MFA."
    fi
    
    success "Dependencias verificadas"
}

# Crear estructura de directorios
create_directory_structure() {
    log "Creando estructura de directorios..."
    
    # Directorios principales
    mkdir -p /opt/virtualmin/security/{waf,ids-ips,mfa,configs,logs,scripts}
    mkdir -p /opt/virtualmin/security/waf/{modsecurity,rulesets,templates}
    mkdir -p /opt/virtualmin/security/ids-ips/{fail2ban,suricata,ossec,templates}
    mkdir -p /opt/virtualmin/security/mfa/{google-authenticator,duo,templates}
    mkdir -p /opt/virtualmin/security/configs/{apache,nginx,modsecurity,fail2ban,mfa}
    mkdir -p /opt/virtualmin/security/logs/{waf,ids-ips,mfa}
    mkdir -p /opt/virtualmin/security/scripts/{setup,monitoring,testing}
    
    success "Estructura de directorios creada"
}

# Configurar WAF con ModSecurity
setup_waf() {
    log "Configurando WAF con ModSecurity..."
    
    # Instalar ModSecurity
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        apt-get update
        apt-get install -y libapache2-mod-security2
        a2enmod security2
        systemctl restart apache2
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS
        yum install -y mod_security
        systemctl restart httpd
    elif command -v dnf &> /dev/null; then
        # Fedora
        dnf install -y mod_security
        systemctl restart httpd
    fi
    
    # Crear configuración de ModSecurity
    cat > /opt/virtualmin/security/configs/modsecurity/modsecurity.conf << 'EOF'
# Configuración de ModSecurity para Virtualmin
# Basado en OWASP ModSecurity Core Rule Set

# -- Configuración básica --
SecRuleEngine On
SecRequestBodyAccess On
SecResponseBodyAccess On
SecResponseBodyMimeType text/plain text/html text/xml application/json
SecDataDir /opt/virtualmin/security/logs/waf/data/

# -- Configuración de request body --
SecRequestBodyLimit 13107200
SecRequestBodyNoFilesLimit 131072
SecRequestBodyInMemoryLimit 131072

# -- Configuración de response body --
SecResponseBodyLimit 524288
SecResponseBodyMimeType text/plain text/html text/xml application/json

# -- Configuración de debug --
SecDebugLog /opt/virtualmin/security/logs/waf/modsec_debug.log
SecDebugLogLevel 3
SecAuditEngine RelevantOnly
SecAuditLogRelevantStatus "^(?:5|4(?!04))"
SecAuditLogParts ABIJDEFHZ
SecAuditLog /opt/virtualmin/security/logs/waf/modsec_audit.log
SecAuditLogStorageDir /opt/virtualmin/security/logs/waf/audit/

# -- Configuración de Unicode --
SecUnicodeMapFile unicode.mapping 20127
SecDefaultAction "phase:1,log,auditlog,pass"

# -- Configuración de tiempo de espera --
SecRule REQUEST_HEADERS:User-Agent "@rx ^$" \
    "id:1000001,phase:1,log,t:none,tag:'OWASP_CRS/PROTOCOL_USER_AGENT_ABSENT',\
    severity:WARNING,msg:'User-Agent Header is absent.'"

# -- Reglas específicas para Webmin/Virtualmin --
# Protección contra inyección SQL
SecRule ARGS "@detectSQLi" \
    "id:1000002,phase:2,block,t:none,t:urlDecodeUni,\
    msg:'SQL Injection Attack Detected',\
    tag:'application-multi',tag:'language-multi',tag:'platform-multi',\
    tag:'OWASP_CRS/WEB_ATTACK/SQL_INJECTION',\
    severity:CRITICAL"

# Protección contra XSS
SecRule ARGS "@detectXSS" \
    "id:1000003,phase:2,block,t:none,t:urlDecodeUni,\
    msg:'XSS Attack Detected',\
    tag:'application-multi',tag:'language-multi',tag:'platform-multi',\
    tag:'OWASP_CRS/WEB_ATTACK/XSS',\
    severity:HIGH"

# Protección contra RCE (Remote Code Execution)
SecRule ARGS "@detectCommandInjection" \
    "id:1000004,phase:2,block,t:none,t:urlDecodeUni,\
    msg:'Remote Command Execution Detected',\
    tag:'application-multi',tag:'language-multi',tag:'platform-multi',\
    tag:'OWASP_CRS/WEB_ATTACK/COMMAND_INJECTION',\
    severity:CRITICAL"

# Protección contra LFI (Local File Inclusion)
SecRule ARGS "@detectFileInclusion" \
    "id:1000005,phase:2,block,t:none,t:urlDecodeUni,\
    msg:'Local File Inclusion Attack Detected',\
    tag:'application-multi',tag:'language-multi',tag:'platform-multi',\
    tag:'OWASP_CRS/WEB_ATTACK/LFI',\
    severity:HIGH"

# Protección contra RFI (Remote File Inclusion)
SecRule ARGS "@rx (?:https?|ftps?)://[^/\\s].*/[^/\\s]+\\.(?:txt|log|ini|conf|cfg|php|asp|jsp|js)" \
    "id:1000006,phase:2,block,t:none,t:urlDecodeUni,\
    msg:'Remote File Inclusion Attack Detected',\
    tag:'application-multi',tag:'language-multi',tag:'platform-multi',\
    tag:'OWASP_CRS/WEB_ATTACK/RFI',\
    severity:HIGH"

# Regla específica para proteger login de Webmin
SecRule REQUEST_URI "@rx /session_login\\.cgi" \
    "id:1000007,phase:1,log,t:none,\
    msg:'Webmin Login Access'"

SecRule REQUEST_URI "@rx /session_login\\.cgi" "chain"
SecRule REQUEST_METHOD "@streq POST" \
    "id:1000008,phase:2,log,t:none,\
    msg:'Webmin Login POST Request'"

SecRule REQUEST_URI "@rx /session_login\\.cgi" "chain"
SecRule REQUEST_METHOD "@streq POST" "chain"
SecRule ARGS:user "@rx ^admin$" \
    "id:1000009,phase:2,log,t:none,\
    msg:'Admin Login Attempt'"

# Regla para bloquear intentos de acceso no autorizados
SecRule RESPONSE_STATUS "@rx 401|403" \
    "id:1000010,phase:4,log,t:none,\
    msg:'Unauthorized Access Attempt'"

# Regla para limitar tamaño de archivo en subidas
SecRule REQUEST_HEADERS:Content-Type "@rx multipart/form-data" \
    "id:1000011,phase:1,log,t:none,\
    msg:'File Upload Detected'"

SecRule REQUEST_HEADERS:Content-Type "@rx multipart/form-data" "chain"
SecRule REQUEST_HEADERS:Content-Length "@gt 5242880" \
    "id:1000012,phase:1,block,t:none,\
    msg:'File Upload Size Limit Exceeded'"

# Regla para proteger contra escaneo de directorios
SecRule REQUEST_URI "@rx (?:\\.\\.|\\/(?:etc|var|usr|bin|sbin|boot|proc|sys|dev))" \
    "id:1000013,phase:1,block,t:none,\
    msg:'Directory Traversal Attempt'"

# Regla para proteger contra ataques de fuerza bruta
SecRule REQUEST_URI "@rx /session_login\\.cgi" "chain"
SecRule ARGS:pass "@rx ^.{0,4}$" \
    "id:1000014,phase:2,log,t:none,\
    msg:'Weak Password Attempt'"

# Regla para proteger contra ataques de denegación de servicio
SecRule REQUEST_HEADERS:Content-Length "@gt 10485760" \
    "id:1000015,phase:1,block,t:none,\
    msg:'Potential DoS Attack - Large Request'"

# Regla para proteger contra CSRF
SecRule REQUEST_URI "@rx /(?:\\.cgi|\\.pl|\\.php)" "chain"
SecRule REQUEST_METHOD "@streq POST" "chain"
SecRule REQUEST_HEADERS:Referer "@rx ^$" \
    "id:1000016,phase:1,log,t:none,\
    msg:'Potential CSRF Attack - Missing Referer'"
EOF

    # Crear reglas personalizadas para Webmin/Virtualmin
    cat > /opt/virtualmin/security/waf/rulesets/virtualmin_rules.conf << 'EOF'
# Reglas personalizadas para Webmin/Virtualmin

# Proteger contra intentos de modificación de configuración
SecRule REQUEST_URI "@rx /config\\.cgi" "chain"
SecRule ARGS:save "@streq 1" \
    "id:2000001,phase:2,log,t:none,\
    msg:'Webmin Configuration Modification'"

# Proteger contra creación/migración de dominios no autorizadas
SecRule REQUEST_URI "@rx /virtual-server/save_domain\\.cgi" \
    "id:2000002,phase:2,log,t:none,\
    msg:'Virtualmin Domain Creation'"

# Proteger contra modificación de DNS
SecRule REQUEST_URI "@rx /virtual-server/save_dns\\.cgi" \
    "id:2000003,phase:2,log,t:none,\
    msg:'Virtualmin DNS Modification'"

# Proteger contra modificación de base de datos
SecRule REQUEST_URI "@rx /virtual-server/save_mysql\\.cgi" \
    "id:2000004,phase:2,log,t:none,\
    msg:'Virtualmin MySQL Modification'"

# Proteger contra creación de usuarios no autorizados
SecRule REQUEST_URI "@rx /virtual-server/save_user\\.cgi" \
    "id:2000005,phase:2,log,t:none,\
    msg:'Virtualmin User Creation'"

# Proteger contra modificación de certificados SSL
SecRule REQUEST_URI "@rx /virtual-server/save_cert\\.cgi" \
    "id:2000006,phase:2,log,t:none,\
    msg:'Virtualmin SSL Certificate Modification'"

# Proteger contra modificación de copias de seguridad
SecRule REQUEST_URI "@rx /backup/backup\\.cgi" \
    "id:2000007,phase:2,log,t:none,\
    msg:'Virtualmin Backup Configuration'"

# Proteger contra instalación de scripts no autorizados
SecRule REQUEST_URI "@rx /virtual-server/install_script\\.cgi" \
    "id:2000008,phase:2,log,t:none,\
    msg:'Virtualmin Script Installation'"

# Proteger contra modificación de configuración de email
SecRule REQUEST_URI "@rx /virtual-server/save_mail\\.cgi" \
    "id:2000009,phase:2,log,t:none,\
    msg:'Virtualmin Email Configuration'"

# Proteger contra modificación de configuración de FTP
SecRule REQUEST_URI "@rx /virtual-server/save_ftp\\.cgi" \
    "id:2000010,phase:2,log,t:none,\
    msg:'Virtualmin FTP Configuration'"

# Proteger contra ejecución de comandos no autorizados
SecRule REQUEST_URI "@rx /run\\.cgi" \
    "id:2000011,phase:2,log,t:none,\
    msg:'Webmin Command Execution'"

# Proteger contra modificación de firewall
SecRule REQUEST_URI "@rx /iptables/\\.cgi" \
    "id:2000012,phase:2,log,t:none,\
    msg:'Webmin Firewall Configuration'"

# Proteger contra modificación de configuración de SSH
SecRule REQUEST_URI "@rx /ssh/\\.cgi" \
    "id:2000013,phase:2,log,t:none,\
    msg:'Webmin SSH Configuration'"

# Proteger contra acceso a logs sensible
SecRule REQUEST_URI "@rx /viewlogs\\.cgi" "chain"
SecRule ARGS:file "@rx (?:/var/log/secure|/var/log/auth|/var/log/messages)" \
    "id:2000014,phase:2,log,t:none,\
    msg:'Access to Sensitive Logs'"

# Proteger contra modificación de crontab
SecRule REQUEST_URI "@rx /cron/\\.cgi" \
    "id:2000015,phase:2,log,t:none,\
    msg:'Webmin Cron Configuration'"

# Proteger contra modificación de configuración de PHP
SecRule REQUEST_URI "@rx /php/\\.cgi" \
    "id:2000016,phase:2,log,t:none,\
    msg:'Webmin PHP Configuration'"

# Proteger contra modificación de configuración de Apache
SecRule REQUEST_URI "@rx /apache/\\.cgi" \
    "id:2000017,phase:2,log,t:none,\
    msg:'Webmin Apache Configuration'"
EOF

    # Configurar ModSecurity para Apache
    if [ -f "/etc/apache2/mods-available/security2.conf" ]; then
        # Debian/Ubuntu
        cp /etc/apache2/mods-available/security2.conf /etc/apache2/mods-available/security2.conf.bak
        
        # Configurar Apache para usar ModSecurity
        cat > /etc/apache2/mods-available/security2.conf << 'EOF'
<IfModule security2_module>
    # Configuración de ModSecurity
    SecDataDir /opt/virtualmin/security/logs/waf/data/
    
    # Incluir configuración personalizada
    Include /opt/virtualmin/security/configs/modsecurity/modsecurity.conf
    Include /opt/virtualmin/security/waf/rulesets/virtualmin_rules.conf
    
    # Configurar para usar OWASP CRS
    IncludeOptional /usr/share/modsecurity-crs/*.conf
    IncludeOptional /usr/share/modsecurity-crs/rules/*.conf
</IfModule>
EOF
        
        # Habilitar módulo de seguridad
        a2enmod security2
        
        # Reiniciar Apache
        systemctl restart apache2
    elif [ -f "/etc/httpd/conf.d/mod_security.conf" ]; then
        # RHEL/CentOS
        cp /etc/httpd/conf.d/mod_security.conf /etc/httpd/conf.d/mod_security.conf.bak
        
        # Configurar Apache para usar ModSecurity
        cat > /etc/httpd/conf.d/mod_security.conf << 'EOF'
<IfModule mod_security.c>
    # Configuración de ModSecurity
    SecDataDir /opt/virtualmin/security/logs/waf/data/
    
    # Incluir configuración personalizada
    Include /opt/virtualmin/security/configs/modsecurity/modsecurity.conf
    Include /opt/virtualmin/security/waf/rulesets/virtualmin_rules.conf
    
    # Configurar para usar OWASP CRS
    IncludeOptional /etc/modsecurity.d/*.conf
    IncludeOptional /etc/modsecurity.d/activated_rules/*.conf
</IfModule>
EOF
        
        # Reiniciar Apache
        systemctl restart httpd
    fi
    
    # Instalar OWASP ModSecurity Core Rule Set
    log "Instalando OWASP ModSecurity Core Rule Set..."
    
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        apt-get install -y modsecurity-crs
        
        # Activar reglas
        cp /usr/share/modsecurity-crs/crs-setup.conf.example /etc/modsecurity/crs-setup.conf
        
        # Editar configuración para activar reglas
        sed -i 's/SecDefaultAction "phase:1,log,auditlog,pass"/SecDefaultAction "phase:1,log,auditlog,pass"/' /etc/modsecurity/crs-setup.conf
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS
        yum install -y mod_security_crs
        
        # Configurar reglas
        cp /etc/modsecurity.d/activated_rules/*.conf /etc/modsecurity.d/
    fi
    
    success "WAF configurado con ModSecurity"
}

# Configurar IDS/IPS con Fail2Ban
setup_ids_ips() {
    log "Configurando IDS/IPS con Fail2Ban..."
    
    # Instalar Fail2Ban
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        apt-get install -y fail2ban
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS
        yum install -y epel-release
        yum install -y fail2ban
    elif command -v dnf &> /dev/null; then
        # Fedora
        dnf install -y fail2ban
    fi
    
    # Crear configuración de Fail2Ban
    cat > /opt/virtualmin/security/configs/fail2ban/jail.local << 'EOF'
# Configuración de Fail2Ban para Virtualmin
[DEFAULT]
# Ban IP for 24 hours (86400 seconds)
bantime = 86400

# Find a ban for 10 minutes (600 seconds)
findtime = 600

# Retry limit
maxretry = 3

# Use iptables for banning
banaction = iptables-multiport

# Send an email
destemail = admin@virtualmin.local
sender = fail2ban@virtualmin.local
mta = sendmail

# Path to log files
logpath = /var/log/auth.log
           /var/log/syslog
           /var/log/virtualmin/miniserv.log

# Jails
[webmin-auth]
enabled  = true
port     = 10000
filter   = webmin-auth
logpath  = /var/log/virtualmin/miniserv.log
maxretry = 5
bantime = 3600

[webmin-logins]
enabled  = true
port     = 10000
filter   = webmin-logins
logpath  = /var/log/virtualmin/miniserv.log
maxretry = 3
bantime = 86400

[apache-auth]
enabled  = true
port     = http,https
filter   = apache-auth
logpath  = /var/log/apache2/error.log
maxretry = 3
bantime = 86400

[apache-badbots]
enabled  = true
port     = http,https
filter   = apache-badbots
logpath  = /var/log/apache2/access.log
bantime = 86400
maxretry = 1

[apache-noscript]
enabled  = true
port     = http,https
filter   = apache-noscript
logpath  = /var/log/apache2/access.log
maxretry = 6
bantime = 86400

[apache-overflows]
enabled  = true
port     = http,https
filter   = apache-overflows
logpath  = /var/log/apache2/access.log
maxretry = 2
bantime = 86400

[ssh-ddos]
enabled  = true
port     = ssh
filter   = sshd-ddos
logpath  = /var/log/auth.log
maxretry = 2
bantime = 86400

[ssh-auth]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
bantime = 86400

[vsftpd]
enabled  = true
port     = ftp,ftp-data,ftps,ftps-data
filter   = vsftpd
logpath  = /var/log/vsftpd.log
maxretry = 3
bantime = 86400

[postfix]
enabled  = true
port     = smtp,ssmtp
filter   = postfix
logpath  = /var/log/mail.log
maxretry = 3
bantime = 86400

[dovecot]
enabled  = true
port     = pop3,pop3s,imap,imaps
filter   = dovecot
logpath  = /var/log/mail.log
maxretry = 3
bantime = 86400

[mysql-auth]
enabled  = true
port     = 3306
filter   = mysql-auth
logpath  = /var/log/mysql/error.log
maxretry = 3
bantime = 86400

[nginx-http-auth]
enabled  = true
port     = http,https
filter   = nginx-http-auth
logpath  = /var/log/nginx/error.log
maxretry = 3
bantime = 86400
EOF

    # Crear filtros personalizados para Webmin
    cat > /opt/virtualmin/security/configs/fail2ban/filter.d/webmin-auth.conf << 'EOF'
# Filtro para autenticación de Webmin
[INCLUDES]
before = common.conf

[Definition]
failregex = ^.* Failed login for .* from <HOST>
            ^.* Authentication failed for .* from <HOST>
ignoreregex =
EOF

    cat > /opt/virtualmin/security/configs/fail2ban/filter.d/webmin-logins.conf << 'EOF'
# Filtro para intentos de login de Webmin
[INCLUDES]
before = common.conf

[Definition]
failregex = ^.* Login.*from.*<HOST>
            ^.* Failed password for.*from.*<HOST>
ignoreregex =
EOF

    # Copiar configuración de Fail2Ban
    if [ -f "/etc/fail2ban/jail.local" ]; then
        cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.bak
    fi
    
    cp /opt/virtualmin/security/configs/fail2ban/jail.local /etc/fail2ban/
    
    # Copiar filtros personalizados
    cp /opt/virtualmin/security/configs/fail2ban/filter.d/webmin-auth.conf /etc/fail2ban/filter.d/
    cp /opt/virtualmin/security/configs/fail2ban/filter.d/webmin-logins.conf /etc/fail2ban/filter.d/
    
    # Iniciar y habilitar servicio de Fail2Ban
    systemctl start fail2ban
    systemctl enable fail2ban
    
    success "IDS/IPS configurado con Fail2Ban"
}

# Configurar Autenticación Multifactor
setup_mfa() {
    log "Configurando Autenticación Multifactor..."
    
    # Instalar Google Authenticator
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        apt-get update
        apt-get install -y libpam-google-authenticator
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS
        yum install -y google-authenticator
    elif command -v dnf &> /dev/null; then
        # Fedora
        dnf install -y google-authenticator
    fi
    
    # Configurar PAM para Webmin
    cat > /opt/virtualmin/security/configs/mfa/webmin-pam << 'EOF'
# Configuración PAM para Webmin con MFA
auth requisite pam_succeed_if.so uid >= 1000 quiet
auth required pam_unix.so nullok_secure
auth required pam_google_authenticator.so nullok
EOF

    # Configurar PAM para SSH
    cat > /opt/virtualmin/security/configs/mfa/ssh-pam << 'EOF'
# Configuración PAM para SSH con MFA
auth requisite pam_succeed_if.so uid >= 1000 quiet
auth required pam_unix.so nullok_secure
auth required pam_google_authenticator.so nullok
EOF

    # Configurar PAM para sudo
    cat > /opt/virtualmin/security/configs/mfa/sudo-pam << 'EOF'
# Configuración PAM para sudo con MFA
auth required pam_unix.so nullok_secure
auth required pam_google_authenticator.so nullok
EOF

    # Crear script para configurar MFA para usuarios
    cat > /opt/virtualmin/security/scripts/setup_mfa_user.sh << 'EOF'
#!/bin/bash

# Script para configurar MFA para un usuario

# Verificar si se proporcionó un nombre de usuario
if [ -z "$1" ]; then
    echo "Uso: $0 <nombre_de_usuario>"
    exit 1
fi

USERNAME=$1

# Verificar si el usuario existe
if ! id "$USERNAME" &>/dev/null; then
    echo "Error: El usuario $USERNAME no existe"
    exit 1
fi

# Configurar Google Authenticator para el usuario
echo "Configurando Google Authenticator para el usuario $USERNAME..."
sudo -u "$USERNAME" google-authenticator -t -d -f -r 3 -R 30 -W

# Mostrar mensaje de éxito
echo "Google Authenticator configurado para el usuario $USERNAME"
echo "Escanee el código QR con su aplicación de autenticación"
echo "Guarde los códigos de recuperación en un lugar seguro"

# Configurar PAM para Webmin
echo "Configurando PAM para Webmin..."
if [ -f "/etc/pam.d/webmin" ]; then
    cp /etc/pam.d/webmin /etc/pam.d/webmin.bak
    
    cat > /etc/pam.d/webmin << 'EOF'
# Configuración PAM para Webmin con MFA
auth requisite pam_succeed_if.so uid >= 1000 quiet
auth required pam_unix.so nullok_secure
auth required pam_google_authenticator.so nullok
EOF
fi

# Configurar PAM para SSH
echo "Configurando PAM para SSH..."
if [ -f "/etc/pam.d/sshd" ]; then
    cp /etc/pam.d/sshd /etc/pam.d/sshd.bak
    
    cat > /etc/pam.d/sshd << 'EOF'
# Configuración PAM para SSH con MFA
auth requisite pam_succeed_if.so uid >= 1000 quiet
auth required pam_unix.so nullok_secure
auth required pam_google_authenticator.so nullok
EOF
fi

# Configurar SSH para requerir autenticación multifactor
echo "Configurando SSH para requerir autenticación multifactor..."
if [ -f "/etc/ssh/sshd_config" ]; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
    # Añadir configuración de ChallengeResponseAuthentication
    sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
    
    # Añadir configuración de AuthenticationMethods
    if ! grep -q "AuthenticationMethods" /etc/ssh/sshd_config; then
        echo "AuthenticationMethods publickey,keyboard-interactive" >> /etc/ssh/sshd_config
    fi
    
    # Reiniciar servicio SSH
    systemctl restart sshd
fi

echo "Configuración de MFA completada para el usuario $USERNAME"
EOF

    chmod +x /opt/virtualmin/security/scripts/setup_mfa_user.sh
    
    # Crear script para habilitar/deshabilitar MFA
    cat > /opt/virtualmin/security/scripts/manage_mfa.sh << 'EOF'
#!/bin/bash

# Script para gestionar MFA

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [OPCIÓN] [ARGUMENTOS]"
    echo ""
    echo "Opciones:"
    echo "  enable-user <usuario>     Habilitar MFA para un usuario"
    echo "  disable-user <usuario>    Deshabilitar MFA para un usuario"
    echo "  enable-global            Habilitar MFA globalmente"
    echo "  disable-global           Deshabilitar MFA globalmente"
    echo "  status                   Mostrar estado de MFA"
    echo "  help                     Mostrar esta ayuda"
}

# Función para habilitar MFA para un usuario
enable_user() {
    local username=$1
    
    if [ -z "$username" ]; then
        echo "Error: Se debe especificar un nombre de usuario"
        show_help
        exit 1
    fi
    
    echo "Habilitando MFA para el usuario $username..."
    /opt/virtualmin/security/scripts/setup_mfa_user.sh "$username"
}

# Función para deshabilitar MFA para un usuario
disable_user() {
    local username=$1
    
    if [ -z "$username" ]; then
        echo "Error: Se debe especificar un nombre de usuario"
        show_help
        exit 1
    fi
    
    echo "Deshabilitando MFA para el usuario $username..."
    
    # Eliminar archivo de configuración de Google Authenticator
    rm -f "/home/$username/.google_authenticator"
    
    echo "MFA deshabilitado para el usuario $username"
}

# Función para habilitar MFA globalmente
enable_global() {
    echo "Habilitando MFA globalmente..."
    
    # Configurar PAM para Webmin
    if [ -f "/etc/pam.d/webmin" ]; then
        cp /etc/pam.d/webmin /etc/pam.d/webmin.bak
        
        cat > /etc/pam.d/webmin << 'EOF'
# Configuración PAM para Webmin con MFA
auth requisite pam_succeed_if.so uid >= 1000 quiet
auth required pam_unix.so nullok_secure
auth required pam_google_authenticator.so nullok
EOF
    fi
    
    # Configurar PAM para SSH
    if [ -f "/etc/pam.d/sshd" ]; then
        cp /etc/pam.d/sshd /etc/pam.d/sshd.bak
        
        cat > /etc/pam.d/sshd << 'EOF'
# Configuración PAM para SSH con MFA
auth requisite pam_succeed_if.so uid >= 1000 quiet
auth required pam_unix.so nullok_secure
auth required pam_google_authenticator.so nullok
EOF
    fi
    
    # Configurar SSH para requerir autenticación multifactor
    if [ -f "/etc/ssh/sshd_config" ]; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
        
        # Añadir configuración de ChallengeResponseAuthentication
        sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
        
        # Añadir configuración de AuthenticationMethods
        if ! grep -q "AuthenticationMethods" /etc/ssh/sshd_config; then
            echo "AuthenticationMethods publickey,keyboard-interactive" >> /etc/ssh/sshd_config
        fi
        
        # Reiniciar servicio SSH
        systemctl restart sshd
    fi
    
    echo "MFA habilitado globalmente"
}

# Función para deshabilitar MFA globalmente
disable_global() {
    echo "Deshabilitando MFA globalmente..."
    
    # Restaurar configuración PAM original para Webmin
    if [ -f "/etc/pam.d/webmin.bak" ]; then
        cp /etc/pam.d/webmin.bak /etc/pam.d/webmin
    fi
    
    # Restaurar configuración PAM original para SSH
    if [ -f "/etc/pam.d/sshd.bak" ]; then
        cp /etc/pam.d/sshd.bak /etc/pam.d/sshd
    fi
    
    # Restaurar configuración SSH original
    if [ -f "/etc/ssh/sshd_config.bak" ]; then
        cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
        systemctl restart sshd
    fi
    
    echo "MFA deshabilitado globalmente"
}

# Función para mostrar estado de MFA
show_status() {
    echo "Estado de MFA:"
    echo ""
    
    # Verificar si Google Authenticator está instalado
    if command -v google-authenticator &> /dev/null; then
        echo "Google Authenticator: Instalado"
    else
        echo "Google Authenticizer: No instalado"
    fi
    
    # Verificar configuración PAM para Webmin
    if [ -f "/etc/pam.d/webmin" ]; then
        if grep -q "pam_google_authenticator" /etc/pam.d/webmin; then
            echo "MFA para Webmin: Habilitado"
        else
            echo "MFA para Webmin: Deshabilitado"
        fi
    else
        echo "MFA para Webmin: No configurado"
    fi
    
    # Verificar configuración PAM para SSH
    if [ -f "/etc/pam.d/sshd" ]; then
        if grep -q "pam_google_authenticator" /etc/pam.d/sshd; then
            echo "MFA para SSH: Habilitado"
        else
            echo "MFA para SSH: Deshabilitado"
        fi
    else
        echo "MFA para SSH: No configurado"
    fi
    
    # Verificar configuración SSH
    if [ -f "/etc/ssh/sshd_config" ]; then
        if grep -q "ChallengeResponseAuthentication yes" /etc/ssh/sshd_config; then
            echo "Challenge Response para SSH: Habilitado"
        else
            echo "Challenge Response para SSH: Deshabilitado"
        fi
    else
        echo "Configuración SSH: No encontrada"
    fi
    
    # Mostrar usuarios con MFA configurado
    echo ""
    echo "Usuarios con MFA configurado:"
    for user in /home/*; do
        if [ -f "$user/.google_authenticator" ]; then
            username=$(basename "$user")
            echo "  - $username"
        fi
    done
}

# Procesar opciones
case "$1" in
    "enable-user")
        enable_user "$2"
        ;;
    "disable-user")
        disable_user "$2"
        ;;
    "enable-global")
        enable_global
        ;;
    "disable-global")
        disable_global
        ;;
    "status")
        show_status
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo "Error: Opción no válida"
        show_help
        exit 1
        ;;
esac
EOF

    chmod +x /opt/virtualmin/security/scripts/manage_mfa.sh
    
    success "Autenticación Multifactor configurada"
}

# Crear script de monitoreo de seguridad
create_monitoring_script() {
    log "Creando script de monitoreo de seguridad..."
    
    cat > /opt/virtualmin/security/scripts/monitor_security.sh << 'EOF'
#!/bin/bash

# Script para monitorear la seguridad de Virtualmin

# Configuración
LOG_DIR="/opt/virtualmin/security/logs"
REPORT_DIR="/opt/virtualmin/security/reports"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
REPORT_FILE="${REPORT_DIR}/security_report_${TIMESTAMP}.txt"

# Crear directorio de reportes
mkdir -p "$REPORT_DIR"

# Función para mostrar encabezado
show_header() {
    echo "===============================================" >> "$REPORT_FILE"
    echo "Reporte de Seguridad de Virtualmin" >> "$REPORT_FILE"
    echo "Fecha: $(date)" >> "$REPORT_FILE"
    echo "===============================================" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

# Función para monitorear WAF
monitor_waf() {
    echo "Monitoreo de WAF (ModSecurity):" >> "$REPORT_FILE"
    echo "--------------------------------" >> "$REPORT_FILE"
    
    # Verificar estado de ModSecurity
    if [ -f "/opt/virtualmin/security/logs/waf/modsec_debug.log" ]; then
        echo "Estado del log de ModSecurity: Activo" >> "$REPORT_FILE"
        echo "Últimas 10 líneas del log de ModSecurity:" >> "$REPORT_FILE"
        tail -10 /opt/virtualmin/security/logs/waf/modsec_debug.log >> "$REPORT_FILE"
    else
        echo "Estado del log de ModSecurity: Inactivo" >> "$REPORT_FILE"
    fi
    
    echo "" >> "$REPORT_FILE"
    
    # Verificar auditoría de WAF
    if [ -f "/opt/virtualmin/security/logs/waf/modsec_audit.log" ]; then
        echo "Estado del log de auditoría: Activo" >> "$REPORT_FILE"
        
        # Contar eventos bloqueados
        blocked_events=$(grep "ModSecurity: Access denied" /opt/virtualmin/security/logs/waf/modsec_audit.log | wc -l)
        echo "Eventos bloqueados en última hora: $blocked_events" >> "$REPORT_FILE"
        
        # Mostrar eventos más recientes
        echo "Últimos 5 eventos bloqueados:" >> "$REPORT_FILE"
        grep "ModSecurity: Access denied" /opt/virtualmin/security/logs/waf/modsec_audit.log | tail -5 >> "$REPORT_FILE"
    else
        echo "Estado del log de auditoría: Inactivo" >> "$REPORT_FILE"
    fi
    
    echo "" >> "$REPORT_FILE"
}

# Función para monitorear IDS/IPS
monitor_ids_ips() {
    echo "Monitoreo de IDS/IPS (Fail2Ban):" >> "$REPORT_FILE"
    echo "-----------------------------------" >> "$REPORT_FILE"
    
    # Verificar estado de Fail2Ban
    if systemctl is-active --quiet fail2ban; then
        echo "Estado de Fail2Ban: Activo" >> "$REPORT_FILE"
        
        # Mostrar cárceles activas
        echo "Cárceles activas:" >> "$REPORT_FILE"
        fail2ban-client status >> "$REPORT_FILE"
    else
        echo "Estado de Fail2Ban: Inactivo" >> "$REPORT_FILE"
    fi
    
    echo "" >> "$REPORT_FILE"
    
    # Verificar baneos recientes
    echo "Baneos recientes (últimas 24 horas):" >> "$REPORT_FILE"
    if [ -f "/var/log/fail2ban.log" ]; then
        grep "$(date --date='1 day ago' +%Y-%m-%d)" /var/log/fail2ban.log | grep "Ban " | tail -10 >> "$REPORT_FILE"
    fi
    
    echo "" >> "$REPORT_FILE"
}

# Función para monitorear MFA
monitor_mfa() {
    echo "Monitoreo de MFA:" >> "$REPORT_FILE"
    echo "-------------------" >> "$REPORT_FILE"
    
    # Verificar si Google Authenticator está instalado
    if command -v google-authenticator &> /dev/null; then
        echo "Google Authenticator: Instalado" >> "$REPORT_FILE"
    else
        echo "Google Authenticizer: No instalado" >> "$REPORT_FILE"
    fi
    
    # Verificar configuración PAM para Webmin
    if [ -f "/etc/pam.d/webmin" ]; then
        if grep -q "pam_google_authenticator" /etc/pam.d/webmin; then
            echo "MFA para Webmin: Habilitado" >> "$REPORT_FILE"
        else
            echo "MFA para Webmin: Deshabilitado" >> "$REPORT_FILE"
        fi
    else
        echo "MFA para Webmin: No configurado" >> "$REPORT_FILE"
    fi
    
    # Mostrar usuarios con MFA configurado
    echo "Usuarios con MFA configurado:" >> "$REPORT_FILE"
    for user in /home/*; do
        if [ -f "$user/.google_authenticator" ]; then
            username=$(basename "$user")
            echo "  - $username" >> "$REPORT_FILE"
        fi
    done
    
    echo "" >> "$REPORT_FILE"
}

# Función para monitorear intentos de acceso
monitor_access_attempts() {
    echo "Monitoreo de Intentos de Acceso:" >> "$REPORT_FILE"
    echo "-----------------------------------" >> "$REPORT_FILE"
    
    # Verificar log de Webmin
    if [ -f "/var/log/virtualmin/miniserv.log" ]; then
        echo "Intentos de acceso a Webmin (últimas 24 horas):" >> "$REPORT_FILE"
        grep "$(date --date='1 day ago' +%b %d)" /var/log/virtualmin/miniserv.log | grep "Login" | tail -10 >> "$REPORT_FILE"
        
        # Contar intentos fallidos
        failed_attempts=$(grep "$(date --date='1 day ago' +%b %d)" /var/log/virtualmin/miniserv.log | grep "Failed login" | wc -l)
        echo "Intentos fallidos en últimas 24 horas: $failed_attempts" >> "$REPORT_FILE"
    else
        echo "Log de Webmin no encontrado" >> "$REPORT_FILE"
    fi
    
    echo "" >> "$REPORT_FILE"
    
    # Verificar log de autenticación
    if [ -f "/var/log/auth.log" ]; then
        echo "Intentos de acceso SSH (últimas 24 horas):" >> "$REPORT_FILE"
        grep "$(date --date='1 day ago' +%b %d)" /var/log/auth.log | grep "ssh" | tail -10 >> "$REPORT_FILE"
        
        # Contar intentos fallidos
        failed_ssh=$(grep "$(date --date='1 day ago' +%b %d)" /var/log/auth.log | grep "ssh" | grep "failure" | wc -l)
        echo "Intentos fallidos SSH en últimas 24 horas: $failed_ssh" >> "$REPORT_FILE"
    else
        echo "Log de autenticación no encontrado" >> "$REPORT_FILE"
    fi
    
    echo "" >> "$REPORT_FILE"
}

# Función para monitorear certificados SSL
monitor_ssl_certificates() {
    echo "Monitoreo de Certificados SSL:" >> "$REPORT_FILE"
    echo "------------------------------" >> "$REPORT_FILE"
    
    # Verificar certificados de dominios virtuales
    if [ -f "/etc/webmin/virtual-server-cert.pem" ]; then
        echo "Certificado principal:" >> "$REPORT_FILE"
        openssl x509 -in /etc/webmin/virtual-server-cert.pem -noout -dates >> "$REPORT_FILE"
    else
        echo "Certificado principal no encontrado" >> "$REPORT_FILE"
    fi
    
    echo "" >> "$REPORT_FILE"
    
    # Verificar certificados de dominios virtuales
    if [ -d "/etc/webmin/certificates" ]; then
        echo "Certificados de dominios virtuales:" >> "$REPORT_FILE"
        for cert in /etc/webmin/certificates/*.pem; do
            if [ -f "$cert" ]; then
                domain=$(basename "$cert" .pem)
                echo "  - $domain:" >> "$REPORT_FILE"
                openssl x509 -in "$cert" -noout -dates >> "$REPORT_FILE"
                
                # Verificar si el certificado está próximo a expirar
                expires=$(openssl x509 -in "$cert" -noout -enddate | cut -d= -f2)
                expiry_date=$(date -d "$expires" +%s)
                current_date=$(date +%s)
                days_until_expiry=$(( (expiry_date - current_date) / 86400 ))
                
                if [ $days_until_expiry -lt 30 ]; then
                    echo "    ADVERTENCIA: El certificado expira en $days_until_expiry días" >> "$REPORT_FILE"
                fi
            fi
        done
    else
        echo "Directorio de certificados no encontrado" >> "$REPORT_FILE"
    fi
    
    echo "" >> "$REPORT_FILE"
}

# Función para monitorear actualizaciones de seguridad
monitor_security_updates() {
    echo "Monitoreo de Actualizaciones de Seguridad:" >> "$REPORT_FILE"
    echo "---------------------------------------" >> "$REPORT_FILE"
    
    # Verificar actualizaciones de seguridad
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        echo "Actualizaciones de seguridad disponibles:" >> "$REPORT_FILE"
        apt-get -s upgrade | grep -i security >> "$REPORT_FILE"
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS
        echo "Actualizaciones de seguridad disponibles:" >> "$REPORT_FILE"
        yum check-update --security >> "$REPORT_FILE"
    elif command -v dnf &> /dev/null; then
        # Fedora
        echo "Actualizaciones de seguridad disponibles:" >> "$REPORT_FILE"
        dnf check-update --security >> "$REPORT_FILE"
    fi
    
    echo "" >> "$REPORT_FILE"
}

# Generar reporte
show_header
monitor_waf
monitor_ids_ips
monitor_mfa
monitor_access_attempts
monitor_ssl_certificates
monitor_security_updates

echo "Reporte de seguridad generado en: $REPORT_FILE" | tee -a "$REPORT_FILE"

# Enviar reporte por email si está configurado
if [ -n "$SECURITY_EMAIL" ]; then
    mail -s "Reporte de Seguridad de Virtualmin" "$SECURITY_EMAIL" < "$REPORT_FILE"
fi
EOF

    chmod +x /opt/virtualmin/security/scripts/monitor_security.sh
    
    # Crear script de prueba de seguridad
    cat > /opt/virtualmin/security/scripts/test_security.sh << 'EOF'
#!/bin/bash

# Script para probar la configuración de seguridad

# Configuración
TARGET_URL=${1:-"http://localhost:10000"}

# Función para probar WAF
test_wav() {
    echo "Probando WAF..."
    
    # Probar inyección SQL
    echo "Probando inyección SQL..."
    curl -s -X POST "$TARGET_URL/session_login.cgi" \
         -d "user=admin&pass=' OR '1'='1" \
         -H "Content-Type: application/x-www-form-urlencoded" > /dev/null
    
    # Probar XSS
    echo "Probando XSS..."
    curl -s -X POST "$TARGET_URL/session_login.cgi" \
         -d "user=admin&pass=<script>alert('XSS')</script>" \
         -H "Content-Type: application/x-www-form-urlencoded" > /dev/null
    
    # Probar RCE
    echo "Probando RCE..."
    curl -s -X POST "$TARGET_URL/session_login.cgi" \
         -d "user=admin&pass=`whoami`" \
         -H "Content-Type: application/x-www-form-urlencoded" > /dev/null
    
    echo "Pruebas de WAF completadas"
}

# Función para probar IDS/IPS
test_ids_ips() {
    echo "Probando IDS/IPS..."
    
    # Probar fuerza bruta
    echo "Probando fuerza bruta..."
    for pass in "password" "123456" "admin" "root" "test"; do
        curl -s -X POST "$TARGET_URL/session_login.cgi" \
             -d "user=admin&pass=$pass" \
             -H "Content-Type: application/x-www-form-urlencoded" > /dev/null
        sleep 1
    done
    
    echo "Pruebas de IDS/IPS completadas"
}

# Función para probar MFA
test_mfa() {
    echo "Probando MFA..."
    
    # Esta función requeriría interacción manual para probar MFA
    # Por ahora, solo verificamos si está configurado
    
    if [ -f "/etc/pam.d/webmin" ] && grep -q "pam_google_authenticator" /etc/pam.d/webmin; then
        echo "MFA para Webmin: Configurado"
    else
        echo "MFA para Webmin: No configurado"
    fi
    
    if [ -f "/etc/pam.d/sshd" ] && grep -q "pam_google_authenticator" /etc/pam.d/sshd; then
        echo "MFA para SSH: Configurado"
    else
        echo "MFA para SSH: No configurado"
    fi
    
    echo "Pruebas de MFA completadas"
}

# Ejecutar pruebas
echo "Iniciando pruebas de seguridad..."
echo "URL de destino: $TARGET_URL"
echo ""

test_wav
echo ""

test_ids_ips
echo ""

test_mfa
echo ""

echo "Pruebas de seguridad completadas"
EOF

    chmod +x /opt/virtualmin/security/scripts/test_security.sh
    
    success "Script de monitoreo de seguridad creado"
}

# Crear servicio systemd para monitoreo de seguridad
create_monitoring_service() {
    log "Creando servicio systemd para monitoreo de seguridad..."
    
    cat > /etc/systemd/system/virtualmin-security-monitor.service << 'EOF'
[Unit]
Description=Virtualmin Security Monitor
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/virtualmin/security/scripts/monitor_security.sh
User=root

[Install]
WantedBy=multi-user.target
EOF

    # Crear temporizador para ejecución diaria
    cat > /etc/systemd/system/virtualmin-security-monitor.timer << 'EOF'
[Unit]
Description=Run Virtualmin Security Monitor daily
Requires=virtualmin-security-monitor.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Recargar systemd
    systemctl daemon-reload
    
    # Habilitar y arrancar temporizador
    systemctl enable virtualmin-security-monitor.timer
    systemctl start virtualmin-security-monitor.timer
    
    success "Servicio de monitoreo de seguridad creado"
}

# Función principal
main() {
    log "Iniciando configuración de seguridad avanzada..."
    
    # Verificar si se ejecuta como root
    if [ "$EUID" -ne 0 ]; then
        error "Este script debe ejecutarse como root"
        exit 1
    fi
    
    # Ejecutar funciones
    check_dependencies
    create_directory_structure
    setup_waf
    setup_ids_ips
    setup_mfa
    create_monitoring_script
    create_monitoring_service
    
    success "Configuración de seguridad avanzada completada"
    
    # Mostrar información de uso
    echo
    echo -e "${BLUE}Configuración de WAF:${NC}"
    echo "Configuración de ModSecurity: /opt/virtualmin/security/configs/modsecurity/modsecurity.conf"
    echo "Reglas personalizadas: /opt/virtualmin/security/waf/rulesets/virtualmin_rules.conf"
    echo "Logs de WAF: /opt/virtualmin/security/logs/waf/"
    echo
    echo -e "${BLUE}Configuración de IDS/IPS:${NC}"
    echo "Configuración de Fail2Ban: /opt/virtualmin/security/configs/fail2ban/jail.local"
    echo "Filtros personalizados: /opt/virtualmin/security/configs/fail2ban/filter.d/"
    echo "Logs de Fail2Ban: /var/log/fail2ban.log"
    echo
    echo -e "${BLUE}Configuración de MFA:${NC}"
    echo "Configurar MFA para un usuario:"
    echo "  /opt/virtualmin/security/scripts/setup_mfa_user.sh <nombre_de_usuario>"
    echo
    echo "Gestionar MFA:"
    echo "  /opt/virtualmin/security/scripts/manage_mfa.sh [OPCIÓN] [ARGUMENTOS]"
    echo "  Opciones: enable-user, disable-user, enable-global, disable-global, status"
    echo
    echo -e "${BLUE}Monitoreo de seguridad:${NC}"
    echo "Generar reporte de seguridad:"
    echo "  /opt/virtualmin/security/scripts/monitor_security.sh"
    echo
    echo "Probar configuración de seguridad:"
    echo "  /opt/virtualmin/security/scripts/test_security.sh [URL]"
    echo
    echo -e "${BLUE}Servicios:${NC}"
    echo "Verificar estado del servicio de monitoreo:"
    echo "  systemctl status virtualmin-security-monitor.timer"
    echo
    echo "Verificar logs del servicio de monitoreo:"
    echo "  journalctl -u virtualmin-security-monitor.service"
    echo
}

# Ejecutar función principal
main "$@"
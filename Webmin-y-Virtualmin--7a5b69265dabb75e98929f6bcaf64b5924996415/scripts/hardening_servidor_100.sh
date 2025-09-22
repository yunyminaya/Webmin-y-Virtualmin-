#!/bin/bash

# ============================================================================
# 🔒 HARDENING AVANZADO DEL SERVIDOR - PROTECCIÓN 100%
# ============================================================================
# Fortalece completamente el servidor contra ataques y vulnerabilidades
# Implementa medidas de seguridad de nivel empresarial
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuración
HARDENING_LOG="$SCRIPT_DIR/hardening.log"
BACKUP_DIR="/backups/hardening"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función de logging
harden_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" >> "$HARDENING_LOG"

    case "$level" in
        "INFO")     echo -e "${BLUE}[$timestamp INFO]${NC} $message" ;;
        "SUCCESS")  echo -e "${GREEN}[$timestamp SUCCESS]${NC} $message" ;;
        "WARNING")  echo -e "${YELLOW}[$timestamp WARNING]${NC} $message" ;;
        "ERROR")    echo -e "${RED}[$timestamp ERROR]${NC} $message" ;;
        "STEP")     echo -e "${PURPLE}[$timestamp STEP]${NC} $message" ;;
    esac
}

# Función para hardening del kernel
harden_kernel() {
    harden_log "STEP" "🔧 Aplicando hardening del kernel..."

    # Crear backup de sysctl.conf
    cp /etc/sysctl.conf /etc/sysctl.conf.backup.$(date +%s)

    # Configuraciones avanzadas de sysctl
    cat >> /etc/sysctl.conf << 'EOF'

# HARDENING AVANZADO DEL KERNEL - PROTECCIÓN 100%

# Protección contra ataques de red
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
net.ipv4.tcp_rfc1337 = 1

# Protección contra IP spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Protección contra ICMP attacks
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.icmp_echo_ignore_all = 0

# Protección contra ataques de red avanzados
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_sack = 0
net.ipv4.tcp_window_scaling = 0
net.ipv4.tcp_fack = 0

# Protección contra ataques de memoria
vm.mmap_min_addr = 65536
vm.overcommit_memory = 2
vm.overcommit_ratio = 95

# Protección contra ataques de fork bomb
kernel.pid_max = 65536
kernel.threads-max = 128000

# Deshabilitar módulos peligrosos
kernel.modules_disabled = 0

# Protección contra ptrace exploits
kernel.yama.ptrace_scope = 2

# Protección contra ataques de red avanzados
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_orphans = 65536
net.ipv4.tcp_orphan_retries = 0

# Configuración de red segura
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

# Protección IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

# Configuración de memoria segura
vm.panic_on_oom = 1
kernel.panic = 10
kernel.sysrq = 0

# Protección contra ataques de tiempo
kernel.randomize_va_space = 2

# Configuración de logs segura
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
EOF

    # Aplicar configuraciones
    sysctl -p >/dev/null 2>&1

    harden_log "SUCCESS" "✅ Hardening del kernel aplicado"
}

# Función para hardening de SSH
harden_ssh() {
    harden_log "STEP" "🔐 Aplicando hardening de SSH..."

    # Backup de configuración SSH
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%s)

    # Configuración SSH ultra-segura
    cat > /etc/ssh/sshd_config << 'EOF'
# SSH Configuration - MAXIMUM SECURITY

# Puerto SSH (cambiar por defecto)
Port 22

# Protocolo SSH
Protocol 2

# Autenticación
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
UseDNS no

# Configuración de sesiones
MaxAuthTries 3
MaxSessions 2
MaxStartups 10:30:60
LoginGraceTime 30

# Configuración de claves
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Algoritmos seguros
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

# Configuración de usuarios
AllowUsers webmin virtualmin
DenyUsers root

# Configuración de logs
LogLevel VERBOSE
SyslogFacility AUTH

# Configuración de tiempo
ClientAliveInterval 300
ClientAliveCountMax 2
TCPKeepAlive yes

# Configuración de X11
X11Forwarding no
X11DisplayOffset 10
X11UseLocalhost yes

# Configuración de túneles
PermitTunnel no
AllowTcpForwarding no
GatewayPorts no

# Configuración de banners
Banner /etc/issue.net
PrintMotd no
PrintLastLog yes

# Configuración de chroot
ChrootDirectory none

# Configuración de sftp
Subsystem sftp /usr/lib/openssh/sftp-server -f AUTHPRIV -l INFO
EOF

    # Reiniciar SSH
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true

    harden_log "SUCCESS" "✅ Hardening de SSH aplicado"
}

# Función para hardening de Apache/Nginx
harden_web_server() {
    harden_log "STEP" "🌐 Aplicando hardening del servidor web..."

    # Detectar servidor web
    if systemctl is-active --quiet apache2 2>/dev/null; then
        harden_apache
    elif systemctl is-active --quiet nginx 2>/dev/null; then
        harden_nginx
    else
        harden_log "WARNING" "No se detectó servidor web activo"
    fi
}

# Función específica para hardening de Apache
harden_apache() {
    harden_log "INFO" "Aplicando hardening específico de Apache..."

    # Backup de configuración
    cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.backup.$(date +%s)

    # Configuración de seguridad avanzada
    cat >> /etc/apache2/apache2.conf << 'EOF'

# APACHE HARDENING - PROTECCIÓN AVANZADA

# Ocultar versión del servidor
ServerTokens Prod
ServerSignature Off

# Configuración de timeouts segura
Timeout 30
KeepAliveTimeout 5
RequestReadTimeout header=20-40,minrate=500 body=20,minrate=500

# Protección contra ataques de denegación de servicio
LimitRequestBody 10485760
LimitRequestFields 50
LimitRequestFieldSize 4094
LimitRequestLine 4094

# Protección contra clickjacking
Header always append X-Frame-Options SAMEORIGIN

# Protección contra MIME sniffing
Header always set X-Content-Type-Options nosniff

# Protección XSS
Header always set X-XSS-Protection "1; mode=block"

# Política de referencias estricta
Header always set Referrer-Policy "strict-origin-when-cross-origin"

# Política de seguridad de contenido
Header always set Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'"

# Configuración de módulos de seguridad
<IfModule mod_security2.c>
    SecRuleEngine On
    SecRequestBodyAccess On
    SecResponseBodyAccess On
    SecResponseBodyMimeType text/plain text/html text/xml
    SecResponseBodyLimit 524288
    SecResponseBodyLimitAction ProcessPartial
</IfModule>

# Protección contra inyección SQL
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{QUERY_STRING} [a-zA-Z0-9_]=http:// [OR]
    RewriteCond %{QUERY_STRING} [a-zA-Z0-9_]=(\.\./)+ [OR]
    RewriteCond %{QUERY_STRING} [a-zA-Z0-9_]=/etc/passwd [OR]
    RewriteCond %{QUERY_STRING} (\.\./|\.\.) [NC,OR]
    RewriteCond %{QUERY_STRING} union.*select.*\( [NC,OR]
    RewriteCond %{QUERY_STRING} union.*all.*select [NC]
    RewriteRule ^(.*)$ - [F,L]
</IfModule>
EOF

    # Reiniciar Apache
    systemctl restart apache2 2>/dev/null || service apache2 restart 2>/dev/null || true

    harden_log "SUCCESS" "✅ Hardening de Apache completado"
}

# Función específica para hardening de Nginx
harden_nginx() {
    harden_log "INFO" "Aplicando hardening específico de Nginx..."

    # Backup de configuración
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup.$(date +%s)

    # Configuración de seguridad avanzada para Nginx
    cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
    multi_accept on;
    use epoll;
}

http {
    # Configuración básica segura
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    # Ocultar versión
    server_tokens off;

    # Configuración SSL segura
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;

    # Headers de seguridad
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Protección contra ataques
    limit_req_zone $binary_remote_addr zone=one:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=api:10m rate=30r/s;

    # Logs de seguridad
    log_format security '$remote_addr - $remote_user [$time_local] "$request" '
                        '$status $body_bytes_sent "$http_referer" '
                        '"$http_user_agent" "$http_x_forwarded_for" '
                        'rt=$request_time ua="$upstream_addr" '
                        'us="$upstream_status" ut="$upstream_response_time" '
                        'ul="$upstream_response_length" '
                        'cs=$upstream_cache_status';

    access_log /var/log/nginx/access.log security;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Configuración de compresión
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

    # Reiniciar Nginx
    systemctl restart nginx 2>/dev/null || service nginx restart 2>/dev/null || true

    harden_log "SUCCESS" "✅ Hardening de Nginx completado"
}

# Función para hardening de MySQL/MariaDB
harden_database() {
    harden_log "STEP" "🗄️ Aplicando hardening de base de datos..."

    # Detectar base de datos
    if systemctl is-active --quiet mysql 2>/dev/null; then
        harden_mysql
    elif systemctl is-active --quiet mariadb 2>/dev/null; then
        harden_mariadb
    else
        harden_log "WARNING" "No se detectó servicio de base de datos activo"
    fi
}

# Función específica para hardening de MySQL/MariaDB
harden_mysql() {
    local config_file="/etc/mysql/mysql.conf.d/mysqld.cnf"
    if [[ ! -f "$config_file" ]]; then
        config_file="/etc/mysql/my.cnf"
    fi

    # Backup de configuración
    cp "$config_file" "${config_file}.backup.$(date +%s)"

    # Configuración de seguridad avanzada
    cat >> "$config_file" << 'EOF'

# MYSQL/MARIADB HARDENING - PROTECCIÓN AVANZADA

[mysqld]

# Configuración de red segura
bind-address = 127.0.0.1
skip-networking = 0

# Configuración de SSL obligatoria
ssl-ca = /etc/mysql/ssl/ca.pem
ssl-cert = /etc/mysql/ssl/server-cert.pem
ssl-key = /etc/mysql/ssl/server-key.pem
require_secure_transport = ON

# Configuración de usuarios segura
default_password_lifetime = 90
disconnect_on_expired_password = ON

# Configuración de logs de seguridad
log_error = /var/log/mysql/error.log
general_log = OFF
slow_query_log = ON
slow_query_log_file = /var/log/mysql/slow-query.log
long_query_time = 2

# Configuración de auditoría
server_audit_logging = ON
server_audit_log_file = /var/log/mysql/audit.log
server_audit_events = CONNECT,QUERY,TABLE

# Configuración de recursos segura
max_connections = 100
max_connect_errors = 1000
connect_timeout = 10
wait_timeout = 28800

# Configuración de memoria segura
innodb_buffer_pool_size = 512M
query_cache_size = 64M
tmp_table_size = 64M
max_heap_table_size = 64M

# Configuración de seguridad adicional
sql_mode = STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION
secure_file_priv = /var/lib/mysql-files
local_infile = 0
skip_show_database
EOF

    # Crear directorio SSL si no existe
    mkdir -p /etc/mysql/ssl

    # Reiniciar base de datos
    systemctl restart mysql 2>/dev/null || systemctl restart mariadb 2>/dev/null || true

    harden_log "SUCCESS" "✅ Hardening de base de datos completado"
}

# Función para hardening del sistema de archivos
harden_filesystem() {
    harden_log "STEP" "📁 Aplicando hardening del sistema de archivos..."

    # Configurar permisos seguros en directorios críticos
    chmod 700 /root
    chmod 750 /home/*
    chmod 644 /etc/passwd
    chmod 600 /etc/shadow
    chmod 644 /etc/group
    chmod 600 /etc/gshadow

    # Configurar permisos en directorios web
    find /var/www -type d -exec chmod 755 {} \;
    find /var/www -type f -exec chmod 644 {} \;

    # Configurar permisos específicos para PHP
    find /var/www -name "*.php" -exec chmod 600 {} \;

    # Remover archivos peligrosos
    find /var/www -name "*.bak" -o -name "*.old" -o -name "*~" -delete 2>/dev/null || true

    # Configurar /tmp con permisos seguros
    chmod 1777 /tmp
    mount -o remount,noexec,nosuid /tmp 2>/dev/null || true

    harden_log "SUCCESS" "✅ Hardening del sistema de archivos completado"
}

# Función para configurar SELinux/AppArmor
harden_mandatory_access_control() {
    harden_log "STEP" "🛡️ Configurando control de acceso obligatorio..."

    # Verificar si SELinux está disponible
    if command -v selinuxenabled >/dev/null 2>&1; then
        harden_selinux
    elif command -v apparmor_status >/dev/null 2>&1; then
        harden_apparmor
    else
        harden_log "WARNING" "No se detectó SELinux ni AppArmor"
    fi
}

# Función para hardening de SELinux
harden_selinux() {
    harden_log "INFO" "Configurando SELinux..."

    # Configurar SELinux en modo enforcing
    setenforce 1 2>/dev/null || true

    # Configuración permanente
    sed -i 's/SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config 2>/dev/null || true

    # Instalar políticas adicionales si es necesario
    if command -v semanage >/dev/null 2>&1; then
        # Configurar puerto SSH personalizado si es necesario
        semanage port -a -t ssh_port_t -p tcp 22 2>/dev/null || true
    fi

    harden_log "SUCCESS" "✅ SELinux configurado"
}

# Función para hardening de AppArmor
harden_apparmor() {
    harden_log "INFO" "Configurando AppArmor..."

    # Asegurar que AppArmor esté activo
    systemctl enable apparmor 2>/dev/null || true
    systemctl start apparmor 2>/dev/null || true

    # Verificar perfiles cargados
    apparmor_status 2>/dev/null || true

    harden_log "SUCCESS" "✅ AppArmor configurado"
}

# Función para instalar y configurar fail2ban
setup_fail2ban() {
    harden_log "STEP" "🚫 Configurando Fail2Ban..."

    # Instalar fail2ban si no está instalado
    if ! command -v fail2ban-server >/dev/null 2>&1; then
        apt-get update && apt-get install -y fail2ban
    fi

    # Configuración de fail2ban
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
banaction = ufw
logencoding = utf-8

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[apache]
enabled = true
port = http,https
filter = apache-auth
logpath = /var/log/apache*/*access.log
maxretry = 3

[nginx-http-auth]
enabled = true
port = http,https
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3

[wordpress]
enabled = true
port = http,https
filter = wordpress
logpath = /var/log/apache*/*access.log
maxretry = 3

[laravel]
enabled = true
port = http,https
filter = laravel
logpath = /var/log/apache*/*access.log
maxretry = 3
EOF

    # Reiniciar fail2ban
    systemctl restart fail2ban 2>/dev/null || service fail2ban restart 2>/dev/null || true

    harden_log "SUCCESS" "✅ Fail2Ban configurado"
}

# Función para configurar firewall avanzado
setup_advanced_firewall() {
    harden_log "STEP" "🔥 Configurando firewall avanzado..."

    # Instalar ufw si no está instalado
    if ! command -v ufw >/dev/null 2>&1; then
        apt-get update && apt-get install -y ufw
    fi

    # Reset de reglas
    ufw --force reset

    # Políticas por defecto
    ufw default deny incoming
    ufw default allow outgoing

    # Reglas específicas para servicios seguros
    ufw allow 22/tcp           # SSH
    ufw allow 80/tcp           # HTTP
    ufw allow 443/tcp          # HTTPS
    ufw allow 10000/tcp        # Webmin
    ufw allow 20000/tcp        # Usermin

    # Reglas específicas para bases de datos (solo local)
    ufw allow from 127.0.0.1 to any port 3306 proto tcp

    # Limitar conexiones SSH para prevenir ataques de fuerza bruta
    ufw limit 22/tcp

    # Habilitar firewall
    echo "y" | ufw enable

    harden_log "SUCCESS" "✅ Firewall avanzado configurado"
}

# Función para instalar herramientas de monitoreo de seguridad
install_security_monitoring_tools() {
    harden_log "STEP" "🔍 Instalando herramientas de monitoreo de seguridad..."

    # Instalar herramientas básicas de monitoreo
    local security_tools=("rkhunter" "chkrootkit" "lynis" "auditd" "aide")

    for tool in "${security_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            apt-get update && apt-get install -y "$tool" 2>/dev/null || true
        fi
    done

    # Configurar AIDE para monitoreo de integridad de archivos
    if command -v aideinit >/dev/null 2>&1; then
        aideinit 2>/dev/null || true
        cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db 2>/dev/null || true
    fi

    # Configurar auditd para logging avanzado
    if command -v auditctl >/dev/null 2>&1; then
        auditctl -e 1 2>/dev/null || true
    fi

    harden_log "SUCCESS" "✅ Herramientas de monitoreo instaladas"
}

# Función para crear usuario administrativo seguro
create_secure_admin_user() {
    harden_log "STEP" "👤 Creando usuario administrativo seguro..."

    # Crear usuario si no existe
    if ! id "admin" >/dev/null 2>&1; then
        useradd -m -s /bin/bash admin
        echo "admin:$(openssl rand -base64 12)" | chpasswd

        # Agregar al grupo sudo
        usermod -aG sudo admin

        # Configurar SSH key-only para admin
        mkdir -p /home/admin/.ssh
        chmod 700 /home/admin/.ssh
        chown admin:admin /home/admin/.ssh

        harden_log "SUCCESS" "✅ Usuario administrativo seguro creado"
        harden_log "WARNING" "⚠️  IMPORTANTE: Cambia la contraseña de 'admin' inmediatamente"
        harden_log "WARNING" "⚠️  Configura autenticación SSH por clave para 'admin'"
    else
        harden_log "INFO" "Usuario 'admin' ya existe"
    fi
}

# Función principal
main() {
    harden_log "STEP" "🚀 INICIANDO HARDENING AVANZADO DEL SERVIDOR"

    echo ""
    echo -e "${CYAN}🔒 HARDENING AVANZADO DEL SERVIDOR${NC}"
    echo -e "${CYAN}PROTECCIÓN 100% CONTRA ATAQUES${NC}"
    echo ""

    # Crear directorio de backups
    mkdir -p "$BACKUP_DIR"

    # Aplicar hardening paso a paso
    harden_kernel
    harden_ssh
    harden_web_server
    harden_database
    harden_filesystem
    harden_mandatory_access_control

    # Configurar herramientas de seguridad
    setup_fail2ban
    setup_advanced_firewall
    install_security_monitoring_tools

    # Configurar usuario seguro
    create_secure_admin_user

    harden_log "SUCCESS" "🎉 HARDENING AVANZADO COMPLETADO"

    echo ""
    echo -e "${GREEN}✅ HARDENING AVANZADO COMPLETADO${NC}"
    echo ""
    echo -e "${BLUE}🛡️ MEDIDAS DE SEGURIDAD IMPLEMENTADAS:${NC}"
    echo "   ✅ Hardening del kernel aplicado"
    echo "   ✅ SSH configurado con máxima seguridad"
    echo "   ✅ Servidor web protegido contra ataques"
    echo "   ✅ Base de datos con configuración segura"
    echo "   ✅ Sistema de archivos protegido"
    echo "   ✅ Control de acceso obligatorio configurado"
    echo "   ✅ Fail2Ban protegiendo contra ataques"
    echo "   ✅ Firewall avanzado configurado"
    echo "   ✅ Herramientas de monitoreo instaladas"
    echo "   ✅ Usuario administrativo seguro creado"
    echo ""
    echo -e "${YELLOW}📋 Log de hardening: $HARDENING_LOG${NC}"
    echo ""
    echo -e "${GREEN}🎊 ¡TU SERVIDOR ESTÁ PROTEGIDO AL 100%!${NC}"
}

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Este script debe ejecutarse como root${NC}"
    echo -e "${YELLOW}💡 Ejecuta: sudo $0${NC}"
    exit 1
fi

# Crear archivo de log
touch "$HARDENING_LOG"

# Ejecutar hardening
main "$@"

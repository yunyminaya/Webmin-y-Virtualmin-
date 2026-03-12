#!/bin/bash

# =============================================================================
# INSTALADOR AUTOMÁTICO DE n8n PARA VIRTUALMIN (ESTILO WORDPRESS)
# =============================================================================

set -euo pipefail

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuración global
SCRIPT_VERSION="2.0.0"
N8N_VERSION="latest"
INSTALL_LOG="/var/log/n8n_install.log"
ERROR_LOG="/var/log/n8n_install_error.log"

# Variables de configuración por defecto
DEFAULT_DOMAIN=""
DEFAULT_PORT="5678"
DEFAULT_DB_TYPE="sqlite"
DEFAULT_SSL="true"
DEFAULT_SUBDOMAIN="n8n"
DEFAULT_EMAIL="admin@localhost"

# Archivos de configuración
N8N_CONFIG_DIR="/etc/n8n"
N8N_DATA_DIR="/var/lib/n8n"
N8N_SERVICE_FILE="/etc/systemd/system/n8n.service"
NGINX_CONFIG_DIR="/etc/nginx/sites-available"
APACHE_CONFIG_DIR="/etc/apache2/sites-available"

# =============================================================================
# FUNCIONES DE DIAGNÓSTICO Y VALIDACIÓN
# =============================================================================

log_message() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$INSTALL_LOG"
    
    case $level in
        "ERROR") echo -e "${RED}${message}${NC}" ;;
        "WARN") echo -e "${YELLOW}${message}${NC}" ;;
        "INFO") echo -e "${BLUE}${message}${NC}" ;;
        "SUCCESS") echo -e "${GREEN}${message}${NC}" ;;
        "DEBUG") echo -e "${PURPLE}${message}${NC}" ;;
    esac
}

check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_message "ERROR" "Este script debe ejecutarse como root o con sudo"
        exit 1
    fi
}

detect_virtualmin() {
    if [[ ! -f /usr/libexec/webmin/virtualmin-lib.pl ]] && [[ ! -f /usr/share/webmin/virtualmin-lib.pl ]]; then
        log_message "WARN" "Virtualmin no detectado. El script continuará pero algunas características pueden no estar disponibles."
        return 1
    fi
    log_message "INFO" "Virtualmin detectado - Integración completa disponible"
    return 0
}

check_system_requirements() {
    log_message "INFO" "Verificando requisitos del sistema..."
    
    # Verificar sistema operativo
    if [[ ! -f /etc/os-release ]]; then
        log_message "ERROR" "No se puede determinar el sistema operativo"
        exit 1
    fi
    
    source /etc/os-release
    log_message "INFO" "Sistema detectado: $PRETTY_NAME"
    
    # Verificar arquitectura
    ARCH=$(uname -m)
    if [[ "$ARCH" != "x86_64" ]] && [[ "$ARCH" != "aarch64" ]]; then
        log_message "ERROR" "Arquitectura no soportada: $ARCH"
        exit 1
    fi
    log_message "INFO" "Arquitectura soportada: $ARCH"
    
    # Verificar memoria RAM
    TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [[ $TOTAL_MEM -lt 1024 ]]; then
        log_message "WARN" "Se recomienda al menos 1GB de RAM para n8n (actual: ${TOTAL_MEM}MB)"
    else
        log_message "INFO" "Memoria RAM adecuada: ${TOTAL_MEM}MB"
    fi
    
    # Verificar espacio en disco
    AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
    if [[ $AVAILABLE_SPACE -lt 2097152 ]]; then # 2GB en KB
        log_message "WARN" "Se recomienda al menos 2GB de espacio libre"
    else
        log_message "INFO" "Espacio en disco adecuado"
    fi
}

detect_web_server() {
    if systemctl is-active --quiet nginx 2>/dev/null; then
        WEB_SERVER="nginx"
        log_message "INFO" "Servidor web detectado: Nginx"
    elif systemctl is-active --quiet apache2 2>/dev/null; then
        WEB_SERVER="apache2"
        log_message "INFO" "Servidor web detectado: Apache2"
    elif systemctl is-active --quiet httpd 2>/dev/null; then
        WEB_SERVER="httpd"
        log_message "INFO" "Servidor web detectado: Apache (httpd)"
    else
        WEB_SERVER="none"
        log_message "WARN" "No se detectó ningún servidor web activo"
    fi
}

detect_database() {
    if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mariadb 2>/dev/null; then
        DB_AVAILABLE="mysql"
        log_message "INFO" "Base de datos MySQL/MariaDB detectada"
    elif systemctl is-active --quiet postgresql 2>/dev/null; then
        DB_AVAILABLE="postgresql"
        log_message "INFO" "Base de datos PostgreSQL detectada"
    else
        DB_AVAILABLE="sqlite"
        log_message "INFO" "Usando SQLite (base de datos por defecto)"
    fi
}

check_nodejs() {
    if command -v node >/dev/null 2>&1; then
        NODE_VERSION=$(node --version | sed 's/v//')
        log_message "INFO" "Node.js detectado: versión $NODE_VERSION"
        
        # Verificar versión mínima
        if [[ $(echo "$NODE_VERSION" | cut -d. -f1) -lt 16 ]]; then
            log_message "WARN" "Se recomienda Node.js 16 o superior (actual: $NODE_VERSION)"
            return 1
        fi
        return 0
    else
        log_message "INFO" "Node.js no detectado - se instalará automáticamente"
        return 1
    fi
}

check_port_availability() {
    local port=$1
    if netstat -tuln | grep -q ":$port "; then
        log_message "ERROR" "El puerto $port ya está en uso"
        return 1
    fi
    return 0
}

# =============================================================================
# FUNCIONES DE INSTALACIÓN
# =============================================================================

install_nodejs() {
    log_message "INFO" "Instalando Node.js..."
    
    if [[ "$ID" == "ubuntu" ]] || [[ "$ID" == "debian" ]]; then
        # Ubuntu/Debian
        curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
        apt-get install -y nodejs
    elif [[ "$ID" == "centos" ]] || [[ "$ID" == "rhel" ]] || [[ "$ID" == "rocky" ]] || [[ "$ID" == "almalinux" ]]; then
        # CentOS/RHEL/Rocky/AlmaLinux
        curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -
        yum install -y nodejs
    elif [[ "$ID" == "fedora" ]]; then
        # Fedora
        dnf install -y nodejs
    else
        log_message "ERROR" "Sistema operativo no soportado para instalación automática de Node.js"
        exit 1
    fi
    
    # Verificar instalación
    if command -v node >/dev/null 2>&1; then
        NODE_VERSION=$(node --version)
        log_message "SUCCESS" "Node.js instalado correctamente: $NODE_VERSION"
    else
        log_message "ERROR" "Falló la instalación de Node.js"
        exit 1
    fi
}

install_pm2() {
    log_message "INFO" "Instalando PM2 (Process Manager)..."
    
    npm install -g pm2
    
    if command -v pm2 >/dev/null 2>&1; then
        PM2_VERSION=$(pm2 --version)
        log_message "SUCCESS" "PM2 instalado correctamente: versión $PM2_VERSION"
    else
        log_message "ERROR" "Falló la instalación de PM2"
        exit 1
    fi
}

create_n8n_user() {
    log_message "INFO" "Creando usuario n8n..."
    
    if ! id "n8n" &>/dev/null; then
        useradd -r -s /bin/false -d "$N8N_DATA_DIR" n8n
        log_message "SUCCESS" "Usuario n8n creado correctamente"
    else
        log_message "INFO" "El usuario n8n ya existe"
    fi
}

setup_n8n_directories() {
    log_message "INFO" "Creando directorios de n8n..."
    
    # Crear directorios
    mkdir -p "$N8N_CONFIG_DIR"
    mkdir -p "$N8N_DATA_DIR"
    mkdir -p "$N8N_DATA_DIR/.n8n"
    
    # Establecer permisos
    chown -R n8n:n8n "$N8N_DATA_DIR"
    chown -R n8n:n8n "$N8N_CONFIG_DIR"
    chmod 755 "$N8N_DATA_DIR"
    chmod 755 "$N8N_CONFIG_DIR"
    
    log_message "SUCCESS" "Directorios configurados correctamente"
}

install_n8n() {
    log_message "INFO" "Instalando n8n..."
    
    # Instalar n8n globalmente
    sudo -u n8n npm install -g n8n
    
    # Verificar instalación
    if sudo -u n8n n8n --version >/dev/null 2>&1; then
        N8N_INSTALLED_VERSION=$(sudo -u n8n n8n --version)
        log_message "SUCCESS" "n8n instalado correctamente: versión $N8N_INSTALLED_VERSION"
    else
        log_message "ERROR" "Falló la instalación de n8n"
        exit 1
    fi
}

setup_database() {
    local db_type=$1
    local db_name=$2
    local db_user=$3
    local db_pass=$4
    
    case $db_type in
        "mysql")
            setup_mysql_database "$db_name" "$db_user" "$db_pass"
            ;;
        "postgresql")
            setup_postgresql_database "$db_name" "$db_user" "$db_pass"
            ;;
        "sqlite")
            setup_sqlite_database
            ;;
    esac
}

setup_mysql_database() {
    local db_name=$1
    local db_user=$2
    local db_pass=$3
    
    log_message "INFO" "Configurando base de datos MySQL..."
    
    # Crear base de datos y usuario
    mysql -e "CREATE DATABASE IF NOT EXISTS $db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -e "CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_pass';"
    mysql -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
    
    log_message "SUCCESS" "Base de datos MySQL configurada correctamente"
}

setup_postgresql_database() {
    local db_name=$1
    local db_user=$2
    local db_pass=$3
    
    log_message "INFO" "Configurando base de datos PostgreSQL..."
    
    # Crear base de datos y usuario
    sudo -u postgres psql -c "CREATE DATABASE $db_name;"
    sudo -u postgres psql -c "CREATE USER $db_user WITH PASSWORD '$db_pass';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;"
    
    log_message "SUCCESS" "Base de datos PostgreSQL configurada correctamente"
}

setup_sqlite_database() {
    log_message "INFO" "Configurando base de datos SQLite..."
    
    # Crear directorio para SQLite
    mkdir -p "$N8N_DATA_DIR/database"
    chown -R n8n:n8n "$N8N_DATA_DIR/database"
    
    log_message "SUCCESS" "Base de datos SQLite configurada correctamente"
}

create_n8n_config() {
    local domain=$1
    local port=$2
    local db_type=$3
    local db_name=$4
    local db_user=$5
    local db_pass=$6
    
    log_message "INFO" "Creando configuración de n8n..."
    
    # Crear archivo de configuración
    cat > "$N8N_CONFIG_DIR/n8n.env" << EOF
# Configuración de n8n
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=$(openssl rand -base64 12)

# Configuración de la base de datos
EOF

    case $db_type in
        "mysql")
            cat >> "$N8N_CONFIG_DIR/n8n.env" << EOF
DB_TYPE=mysql
DB_MYSQLDB_DATABASE=$db_name
DB_MYSQLDB_HOST=localhost
DB_MYSQLDB_PORT=3306
DB_MYSQLDB_USER=$db_user
DB_MYSQLDB_PASSWORD=$db_pass
EOF
            ;;
        "postgresql")
            cat >> "$N8N_CONFIG_DIR/n8n.env" << EOF
DB_TYPE=postgresdb
DB_POSTGRESDB_DATABASE=$db_name
DB_POSTGRESDB_HOST=localhost
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_USER=$db_user
DB_POSTGRESDB_PASSWORD=$db_pass
EOF
            ;;
        "sqlite")
            cat >> "$N8N_CONFIG_DIR/n8n.env" << EOF
DB_TYPE=sqlite
DB_SQLITE_VACUUM_ON_CLOSE=true
EOF
            ;;
    esac
    
    # Configuración adicional
    cat >> "$N8N_CONFIG_DIR/n8n.env" << EOF

# Configuración del servidor
N8N_HOST=$domain
N8N_PORT=$port
N8N_PROTOCOL=http

# Configuración de seguridad
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)
N8N_JWT_AUTH_HEADER=authorization
N8N_JWT_AUTH_HEADER_VALUE_PREFIX=Bearer

# Configuración de ejecución
N8N_EXECUTORS_DATA=own
N8N_BINARY_DATA_TTL=24
N8N_DEFAULT_BINARY_DATA_MODE=filesystem

# Configuración de archivos
N8N_USER_FOLDER=$N8N_DATA_DIR/.n8n
N8N_CUSTOM_EXTENSIONS=$N8N_DATA_DIR/custom-nodes

# Configuración de webhook
WEBHOOK_URL=http://$domain:$port/
EOF

    # Establecer permisos
    chown n8n:n8n "$N8N_CONFIG_DIR/n8n.env"
    chmod 600 "$N8N_CONFIG_DIR/n8n.env"
    
    log_message "SUCCESS" "Configuración de n8n creada correctamente"
}

create_systemd_service() {
    log_message "INFO" "Creando servicio systemd para n8n..."
    
    cat > "$N8N_SERVICE_FILE" << EOF
[Unit]
Description=n8n Workflow Automation
Documentation=https://docs.n8n.io/
After=network.target

[Service]
Type=simple
User=n8n
Group=n8n
WorkingDirectory=$N8N_DATA_DIR
EnvironmentFile=$N8N_CONFIG_DIR/n8n.env
ExecStart=/usr/bin/n8n start
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=n8n

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$N8N_DATA_DIR

[Install]
WantedBy=multi-user.target
EOF

    # Recargar systemd y habilitar servicio
    systemctl daemon-reload
    systemctl enable n8n
    
    log_message "SUCCESS" "Servicio systemd creado correctamente"
}

configure_web_server() {
    local domain=$1
    local port=$2
    local ssl_enabled=$3
    
    case $WEB_SERVER in
        "nginx")
            configure_nginx "$domain" "$port" "$ssl_enabled"
            ;;
        "apache2"|"httpd")
            configure_apache "$domain" "$port" "$ssl_enabled"
            ;;
        "none")
            log_message "WARN" "No se configurará ningún servidor web. n8n será accesible directamente en el puerto $port"
            ;;
    esac
}

configure_nginx() {
    local domain=$1
    local port=$2
    local ssl_enabled=$3
    
    log_message "INFO" "Configurando Nginx para n8n..."
    
    cat > "$NGINX_CONFIG_DIR/n8n.conf" << EOF
server {
    listen 80;
    server_name $domain;
    
    # Redirección a HTTPS si SSL está habilitado
EOF

    if [[ "$ssl_enabled" == "true" ]]; then
        cat >> "$NGINX_CONFIG_DIR/n8n.conf" << EOF
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $domain;
    
    # Configuración SSL
    ssl_certificate /etc/ssl/certs/$domain.crt;
    ssl_certificate_key /etc/ssl/private/$domain.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
EOF
    else
        cat >> "$NGINX_CONFIG_DIR/n8n.conf" << EOF
    
    # Configuración de seguridad
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
EOF
    fi

    cat >> "$NGINX_CONFIG_DIR/n8n.conf" << EOF
    
    # Configuración de proxy
    location / {
        proxy_pass http://localhost:$port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Configuración de webhook
    location /webhook {
        proxy_pass http://localhost:$port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Configuración de archivos estáticos
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        proxy_pass http://localhost:$port;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    # Habilitar sitio
    ln -sf "$NGINX_CONFIG_DIR/n8n.conf" "/etc/nginx/sites-enabled/"
    
    # Verificar configuración
    nginx -t
    
    log_message "SUCCESS" "Nginx configurado correctamente"
}

configure_apache() {
    local domain=$1
    local port=$2
    local ssl_enabled=$3
    
    log_message "INFO" "Configurando Apache para n8n..."
    
    cat > "$APACHE_CONFIG_DIR/n8n.conf" << EOF
<VirtualHost *:80>
    ServerName $domain
EOF

    if [[ "$ssl_enabled" == "true" ]]; then
        cat >> "$APACHE_CONFIG_DIR/n8n.conf" << EOF
    # Redirección a HTTPS
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
</VirtualHost>

<VirtualHost *:443>
    ServerName $domain
    
    # Configuración SSL
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/$domain.crt
    SSLCertificateKeyFile /etc/ssl/private/$domain.key
    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384
    SSLHonorCipherOrder off
    SSLSessionCache shared:SSL:10m
    SSLSessionTimeout 10m
EOF
    else
        cat >> "$APACHE_CONFIG_DIR/n8n.conf" << EOF
    
    # Configuración de seguridad
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set X-Content-Type-Options "nosniff"
    Header always set Referrer-Policy "no-referrer-when-downgrade"
    Header always set Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'"
EOF
    fi

    cat >> "$APACHE_CONFIG_DIR/n8n.conf" << EOF
    
    # Configuración de proxy
    ProxyPreserveHost On
    ProxyRequests Off
    ProxyPass / http://localhost:$port/
    ProxyPassReverse / http://localhost:$port/
    
    # Configuración de WebSocket
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} =websocket [NC]
    RewriteRule /(.*) ws://localhost:$port/\$1 [P,L]
    
    # Configuración de webhook
    ProxyPass /webhook http://localhost:$port/webhook
    ProxyPassReverse /webhook http://localhost:$port/webhook
</VirtualHost>
EOF

    # Habilitar módulos necesarios
    a2enmod proxy
    a2enmod proxy_http
    a2enmod proxy_wstunnel
    a2enmod rewrite
    a2enmod headers
    
    if [[ "$ssl_enabled" == "true" ]]; then
        a2enmod ssl
    fi
    
    # Habilitar sitio
    a2ensite n8n.conf
    
    # Verificar configuración
    apache2ctl configtest
    
    log_message "SUCCESS" "Apache configurado correctamente"
}

start_n8n_service() {
    log_message "INFO" "Iniciando servicio n8n..."
    
    systemctl start n8n
    
    # Esperar a que el servicio inicie
    sleep 5
    
    if systemctl is-active --quiet n8n; then
        log_message "SUCCESS" "Servicio n8n iniciado correctamente"
    else
        log_message "ERROR" "Falló el inicio del servicio n8n"
        systemctl status n8n
        exit 1
    fi
}

restart_web_server() {
    case $WEB_SERVER in
        "nginx")
            systemctl restart nginx
            log_message "INFO" "Nginx reiniciado"
            ;;
        "apache2"|"httpd")
            systemctl restart apache2 2>/dev/null || systemctl restart httpd
            log_message "INFO" "Apache reiniciado"
            ;;
        esac
}

# =============================================================================
# FUNCIONES DE INTEGRACIÓN CON VIRTUALMIN
# =============================================================================

create_virtualmin_template() {
    local domain=$1
    local port=$2
    local db_type=$3
    
    log_message "INFO" "Creando plantilla de Virtualmin para n8n..."
    
    # Crear directorio de plantillas si no existe
    mkdir -p /etc/webmin/virtual-server/templates
    
    cat > "/etc/webmin/virtual-server/templates/n8n" << EOF
name=n8n Automation Platform
long_desc=n8n Workflow Automation Platform with automatic installation
code=n8n
category=Web Applications
default_web=apache
default_php=php82
db_type=$db_type
db_name=n8n_
db_user=n8n_
home=$default_web/n8n
alias_mode=dir
alias_dir=n8n
ssl=yes
proxy_pass=http://localhost:$port/

# Scripts de instalación
postinstall_script=install_n8n_virtualmin.sh

# Configuración de recursos
memory_limit=1G
cpu_limit=1
disk_quota=5G

# Características habilitadas
features=web,dns,mail,mysql,database,cron,ssl,logrotate
EOF

    log_message "SUCCESS" "Plantilla de Virtualmin creada correctamente"
}

create_virtualmin_install_script() {
    log_message "INFO" "Creando script de instalación para Virtualmin..."
    
    cat > "/usr/share/webmin/virtual-server/install_n8n_virtualmin.sh" << 'EOF'
#!/bin/bash

# Script de instalación de n8n para Virtualmin
DOMAIN=$1
USER=$2
HOME_DIR=$3

# Variables de configuración
N8N_PORT=5678
N8N_DATA_DIR="$HOME_DIR/n8n"

# Crear directorios
mkdir -p "$N8N_DATA_DIR"
chown $USER:$USER "$N8N_DATA_DIR"

# Instalar n8n como usuario
sudo -u $USER npm install -g n8n

# Crear configuración
cat > "$HOME_DIR/.n8n.env" << CONFIG
N8N_HOST=$DOMAIN
N8N_PORT=$N8N_PORT  
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=$(openssl rand -base64 12)
N8N_USER_FOLDER=$N8N_DATA_DIR/.n8n
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)
CONFIG

# Crear servicio systemd para el usuario
cat > "/etc/systemd/system/n8n-$USER.service" << SERVICE
[Unit]
Description=n8n for $USER
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME_DIR
EnvironmentFile=$HOME_DIR/.n8n.env
ExecStart=/usr/bin/n8n start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

# Habilitar e iniciar servicio
systemctl daemon-reload
systemctl enable "n8n-$USER"
systemctl start "n8n-$USER"

echo "n8n instalado correctamente para $DOMAIN"
echo "Acceso: http://$DOMAIN:$N8N_PORT"
echo "Usuario: admin"
echo "Contraseña: $(grep N8N_BASIC_AUTH_PASSWORD $HOME_DIR/.n8n.env | cut -d= -f2)"
EOF

    chmod +x "/usr/share/webmin/virtual-server/install_n8n_virtualmin.sh"
    
    log_message "SUCCESS" "Script de instalación para Virtualmin creado correctamente"
}

# =============================================================================
# FUNCIONES INTERACTIVAS
# =============================================================================

prompt_domain() {
    while true; do
        read -p "Ingrese el dominio para n8n (ej: n8n.ejemplo.com): " domain
        
        if [[ -z "$domain" ]]; then
            domain="$DEFAULT_SUBDOMAIN.$(hostname -f)"
            log_message "INFO" "Usando dominio por defecto: $domain"
        fi
        
        # Validar formato de dominio
        if [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
            break
        else
            log_message "WARN" "Formato de dominio inválido. Intente nuevamente."
        fi
    done
    
    echo "$domain"
}

prompt_port() {
    while true; do
        read -p "Ingrese el puerto para n8n [$DEFAULT_PORT]: " port
        
        if [[ -z "$port" ]]; then
            port="$DEFAULT_PORT"
        fi
        
        # Validar puerto
        if [[ "$port" =~ ^[0-9]+$ ]] && [[ "$port" -ge 1024 ]] && [[ "$port" -le 65535 ]]; then
            if check_port_availability "$port"; then
                break
            else
                log_message "WARN" "El puerto $port ya está en uso. Elija otro puerto."
            fi
        else
            log_message "WARN" "Puerto inválido. Debe estar entre 1024 y 65535."
        fi
    done
    
    echo "$port"
}

prompt_database_config() {
    echo -e "\n${CYAN}Configuración de Base de Datos${NC}"
    echo "Opciones disponibles:"
    
    if [[ "$DB_AVAILABLE" == "mysql" ]]; then
        echo "1) MySQL/MariaDB"
    fi
    
    if [[ "$DB_AVAILABLE" == "postgresql" ]]; then
        echo "2) PostgreSQL"
    fi
    
    echo "3) SQLite (recomendado para instalaciones simples)"
    
    while true; do
        read -p "Seleccione el tipo de base de datos [1-3]: " db_choice
        
        case $db_choice in
            1)
                if [[ "$DB_AVAILABLE" == "mysql" ]]; then
                    db_type="mysql"
                    break
                else
                    log_message "WARN" "MySQL/MariaDB no está disponible"
                fi
                ;;
            2)
                if [[ "$DB_AVAILABLE" == "postgresql" ]]; then
                    db_type="postgresql"
                    break
                else
                    log_message "WARN" "PostgreSQL no está disponible"
                fi
                ;;
            3)
                db_type="sqlite"
                break
                ;;
            *)
                log_message "WARN" "Opción inválida. Seleccione 1, 2 o 3."
                ;;
        esac
    done
    
    if [[ "$db_type" != "sqlite" ]]; then
        read -p "Nombre de la base de datos [n8n]: " db_name
        db_name="${db_name:-n8n}"
        
        read -p "Usuario de la base de datos [n8n]: " db_user
        db_user="${db_user:-n8n}"
        
        read -s -p "Contraseña de la base de datos: " db_pass
        echo
        if [[ -z "$db_pass" ]]; then
            db_pass=$(openssl rand -base64 16)
            log_message "INFO" "Contraseña generada automáticamente: $db_pass"
        fi
    else
        db_name=""
        db_user=""
        db_pass=""
    fi
    
    echo "$db_type|$db_name|$db_user|$db_pass"
}

prompt_ssl_config() {
    while true; do
        read -p "¿Desea configurar SSL/HTTPS? (y/n) [$DEFAULT_SSL]: " ssl_choice
        
        if [[ -z "$ssl_choice" ]]; then
            ssl_choice="$DEFAULT_SSL"
        fi
        
        case $ssl_choice in
            [Yy]|[Yy][Ee][Ss]|[Tt][Rr][Uu][Ee])
                ssl_enabled="true"
                read -p "Correo electrónico para certificado SSL: " email
                email="${email:-$DEFAULT_EMAIL}"
                break
                ;;
            [Nn]|[Nn][Oo]|[Ff][Aa][Ll][Ss][Ee])
                ssl_enabled="false"
                email=""
                break
                ;;
            *)
                log_message "WARN" "Opción inválida. Ingrese y/n."
                ;;
        esac
    done
    
    echo "$ssl_enabled|$email"
}

# =============================================================================
# FUNCIÓN PRINCIPAL
# =============================================================================

main() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
 _   _            _      _   _                 _____                 _
| \ | |          | |    | \ | |               / ____|               | |
|  \| | ___ _ __ | | ___|  \| | _____      __ | |     _ __ _ __ ___ | |
| . ` |/ _ \ '_ \| |/ _ \ . ` |/ _ \ \ /\ / / | |    | '__| '_ ` _ \| |
| |\  |  __/ | | | |  __/ |\  | (_) \ V  V /  | |____| |  | | | | | | |
|_| \_|\___|_| |_|_|\___|_| \_|\___/ \_/\_/    \_____|_|  |_| |_| |_|_|
                     AUTOMATION PLATFORM INSTALLER
EOF
    echo -e "${NC}"
    
    log_message "INFO" "Iniciando instalación de n8n Automation Platform v$SCRIPT_VERSION"
    
    # Verificación inicial
    check_root_privileges
    detect_virtualmin
    check_system_requirements
    
    # Detectar componentes existentes
    detect_web_server
    detect_database
    check_nodejs
    
    # Instalar dependencias si es necesario
    if ! check_nodejs; then
        install_nodejs
    fi
    
    install_pm2
    
    # Configuración interactiva
    echo -e "\n${CYAN}Configuración de Instalación${NC}"
    domain=$(prompt_domain)
    port=$(prompt_port)
    db_config=$(prompt_database_config)
    IFS='|' read -ra DB Parts <<< "$db_config"
    db_type="${DB Parts[0]}"
    db_name="${DB Parts[1]}"
    db_user="${DB Parts[2]}"
    db_pass="${DB Parts[3]}"
    ssl_config=$(prompt_ssl_config)
    IFS='|' read -ra SSL Parts <<< "$ssl_config"
    ssl_enabled="${SSL Parts[0]}"
    email="${SSL Parts[1]}"
    
    # Resumen de configuración
    echo -e "\n${CYAN}Resumen de Configuración${NC}"
    echo "Dominio: $domain"
    echo "Puerto: $port"
    echo "Base de datos: $db_type"
    if [[ "$db_type" != "sqlite" ]]; then
        echo "Nombre BD: $db_name"
        echo "Usuario BD: $db_user"
    fi
    echo "SSL/HTTPS: $([[ "$ssl_enabled" == "true" ]] && echo "Sí" || echo "No")"
    if [[ "$ssl_enabled" == "true" ]] && [[ -n "$email" ]]; then
        echo "Email SSL: $email"
    fi
    
    read -p "¿Continuar con la instalación? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_message "INFO" "Instalación cancelada por el usuario"
        exit 0
    fi
    
    # Proceso de instalación
    log_message "INFO" "Iniciando proceso de instalación..."
    
    create_n8n_user
    setup_n8n_directories
    install_n8n
    setup_database "$db_type" "$db_name" "$db_user" "$db_pass"
    create_n8n_config "$domain" "$port" "$db_type" "$db_name" "$db_user" "$db_pass"
    create_systemd_service
    configure_web_server "$domain" "$port" "$ssl_enabled"
    
    # Configurar SSL si es necesario
    if [[ "$ssl_enabled" == "true" ]] && [[ -n "$email" ]]; then
        log_message "INFO" "Configurando certificado SSL con Let's Encrypt..."
        if command -v certbot >/dev/null 2>&1; then
            certbot --nginx -d "$domain" --non-interactive --agree-tos --email "$email" --redirect
        else
            log_message "WARN" "Certbot no encontrado. Configure SSL manualmente."
        fi
    fi
    
    # Integración con Virtualmin si está disponible
    if [[ $? -eq 0 ]]; then
        create_virtualmin_template "$domain" "$port" "$db_type"
        create_virtualmin_install_script
    fi
    
    # Iniciar servicios
    start_n8n_service
    restart_web_server
    
    # Mostrar información de acceso
    echo -e "\n${GREEN}¡INSTALACIÓN COMPLETADA EXITOSAMENTE!${NC}"
    echo -e "${CYAN}Información de Acceso:${NC}"
    
    admin_user=$(grep N8N_BASIC_AUTH_USER "$N8N_CONFIG_DIR/n8n.env" | cut -d= -f2)
    admin_pass=$(grep N8N_BASIC_AUTH_PASSWORD "$N8N_CONFIG_DIR/n8n.env" | cut -d= -f2)
    
    if [[ "$ssl_enabled" == "true" ]]; then
        access_url="https://$domain"
    else
        access_url="http://$domain"
    fi
    
    echo "URL de acceso: $access_url"
    echo "Usuario: $admin_user"
    echo "Contraseña: $admin_pass"
    
    echo -e "\n${CYAN}Comandos Útiles:${NC}"
    echo "Verificar estado: systemctl status n8n"
    echo "Reiniciar servicio: systemctl restart n8n"
    echo "Ver logs: journalctl -u n8n -f"
    echo "Configuración: $N8N_CONFIG_DIR/n8n.env"
    echo "Datos: $N8N_DATA_DIR"
    
    if [[ $? -eq 0 ]]; then
        echo -e "\n${CYAN}Integración con Virtualmin:${NC}"
        echo "Plantilla n8n disponible para nuevos servidores virtuales"
        echo "Script de instalación automática integrado"
    fi
    
    log_message "SUCCESS" "Instalación de n8n completada exitosamente"
}

# Ejecutar función principal
main "$@"
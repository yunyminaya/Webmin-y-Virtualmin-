#!/bin/bash

# Script de instalación automatizada de Virtualmin Enterprise
# Este script instala y configura todo el stack de Virtualmin Enterprise

set -e

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de configuración
INSTALL_DIR="/opt/virtualmin-enterprise"
LOG_FILE="/var/log/virtualmin-enterprise-install.log"
BACKUP_DIR="/opt/virtualmin-enterprise/backups"
CONFIG_DIR="/opt/virtualmin-enterprise/config"

# Función para imprimir mensajes con colores
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Función para registrar mensajes en el log
log_message() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Función para verificar si el script se ejecuta como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_message $RED "Este script debe ejecutarse como root" >&2
        exit 1
    fi
}

# Función para crear directorios necesarios
create_directories() {
    print_message $BLUE "Creando directorios necesarios..."
    log_message "Creando directorios necesarios"
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$INSTALL_DIR/scripts"
    mkdir -p "$INSTALL_DIR/playbooks"
    mkdir -p "$INSTALL_DIR/templates"
    mkdir -p "$INSTALL_DIR/cron"
    
    print_message $GREEN "Directorios creados exitosamente"
    log_message "Directorios creados exitosamente"
}

# Función para instalar dependencias del sistema
install_dependencies() {
    print_message $BLUE "Instalando dependencias del sistema..."
    log_message "Instalando dependencias del sistema"
    
    # Detectar distribución
    if [[ -f /etc/debian_version ]]; then
        # Debian/Ubuntu
        apt-get update
        apt-get install -y curl wget git ansible software-properties-common \
                         apt-transport-https ca-certificates gnupg lsb-release \
                         python3 python3-pip python3-venv python3-dev \
                         build-essential libssl-dev libffi-dev \
                         nginx apache2 mysql-server postgresql \
                         redis-server memcached \
                         prometheus grafana \
                         iptables ufw modsecurity \
                         snort suricata openvas lynis \
                         google-authenticator libpam-google-authenticator \
                         gpg rsync htop atop \
                         jmeter locust \
                         docker.io docker-compose
    elif [[ -f /etc/redhat-release ]]; then
        # RHEL/CentOS/Fedora
        yum update -y
        yum install -y curl wget git ansible epel-release \
                     python3 python3-pip python3-devel \
                     gcc gcc-c++ make openssl-devel libffi-devel \
                     nginx httpd mariadb-server postgresql-server \
                     redis memcached \
                     prometheus grafana \
                     iptables-services mod_security \
                     snort suricata openvas lynis \
                     google-authenticator pam_google_authenticator \
                     gnupg rsync htop atop \
                     jmeter locust \
                     docker docker-compose
    else
        print_message $RED "Distribución no soportada" >&2
        log_message "Distribución no soportada"
        exit 1
    fi
    
    print_message $GREEN "Dependencias instaladas exitosamente"
    log_message "Dependencias instaladas exitosamente"
}

# Función para instalar Python y dependencias
install_python_dependencies() {
    print_message $BLUE "Instalando dependencias de Python..."
    log_message "Instalando dependencias de Python"
    
    # Crear entorno virtual
    python3 -m venv "$INSTALL_DIR/venv"
    source "$INSTALL_DIR/venv/bin/activate"
    
    # Actualizar pip
    pip install --upgrade pip
    
    # Instalar dependencias
    pip install flask flask-sqlalchemy flask-login \
                prometheus-client grafana-api \
                requests beautifulsoup4 \
                pyyaml jinja2 \
                cryptography bcrypt \
                psutil
    
    print_message $GREEN "Dependencias de Python instaladas exitosamente"
    log_message "Dependencias de Python instaladas exitosamente"
}

# Función para configurar firewall
configure_firewall() {
    print_message $BLUE "Configurando firewall..."
    log_message "Configurando firewall"
    
    # Reglas básicas de firewall
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian con ufw
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow ssh
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow 10000/tcp  # Webmin
        ufw --force enable
    elif command -v firewall-cmd &> /dev/null; then
        # RHEL/CentOS con firewalld
        systemctl start firewalld
        systemctl enable firewalld
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --permanent --add-port=10000/tcp  # Webmin
        firewall-cmd --reload
    else
        # Usar iptables directamente
        iptables -F
        iptables -X
        iptables -t nat -F
        iptables -t nat -X
        iptables -t mangle -F
        iptables -t mangle -X
        
        # Políticas por defecto
        iptables -P INPUT DROP
        iptables -P FORWARD DROP
        iptables -P OUTPUT ACCEPT
        
        # Permitir tráfico local
        iptables -A INPUT -i lo -j ACCEPT
        
        # Permitir conexiones establecidas
        iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        
        # Permitir SSH
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT
        
        # Permitir HTTP/HTTPS
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
        
        # Permitir Webmin
        iptables -A INPUT -p tcp --dport 10000 -j ACCEPT
        
        # Guardar reglas
        if command -v iptables-save &> /dev/null; then
            iptables-save > /etc/iptables/rules.v4
        fi
    fi
    
    print_message $GREEN "Firewall configurado exitosamente"
    log_message "Firewall configurado exitosamente"
}

# Función para instalar y configurar Virtualmin
install_virtualmin() {
    print_message $BLUE "Instalando Virtualmin..."
    log_message "Instalando Virtualmin"
    
    # Descargar script de instalación de Virtualmin
    cd /tmp
    wget http://software.virtualmin.com/gpl/scripts/install.sh
    
    # Hacer ejecutable el script
    chmod +x install.sh
    
    # Ejecutar instalación con configuración mínima
    ./install.sh --force --hostname localhost --domain localhost --unstable
    
    # Configurar Virtualmin
    /usr/libexec/webmin/setup.sh
    
    print_message $GREEN "Virtualmin instalado exitosamente"
    log_message "Virtualmin instalado exitosamente"
}

# Función para configurar servicios
configure_services() {
    print_message $BLUE "Configurando servicios..."
    log_message "Configurando servicios"
    
    # Habilitar servicios
    systemctl enable nginx
    systemctl enable apache2
    systemctl enable mysql
    systemctl enable postgresql
    systemctl enable redis-server
    systemctl enable memcached
    systemctl enable prometheus
    systemctl enable grafana-server
    systemctl enable docker
    
    # Iniciar servicios
    systemctl start nginx
    systemctl start apache2
    systemctl start mysql
    systemctl start postgresql
    systemctl start redis-server
    systemctl start memcached
    systemctl start prometheus
    systemctl start grafana-server
    systemctl start docker
    
    print_message $GREEN "Servicios configurados exitosamente"
    log_message "Servicios configurados exitosamente"
}

# Función para crear scripts de automatización
create_automation_scripts() {
    print_message $BLUE "Creando scripts de automatización..."
    log_message "Creando scripts de automatización"
    
    # Script de backup
    cat > "$INSTALL_DIR/scripts/backup.sh" << 'EOF'
#!/bin/bash

# Script de backup automatizado

BACKUP_DIR="/opt/virtualmin-enterprise/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/virtualmin_backup_$DATE.tar.gz"

# Crear backup
tar -czf "$BACKUP_FILE" /etc/virtualmin /home /var/www /etc/ssl /etc/mysql /var/lib/postgresql

# Mantener solo los últimos 7 backups
find "$BACKUP_DIR" -name "virtualmin_backup_*.tar.gz" -mtime +7 -delete

echo "Backup creado: $BACKUP_FILE"
EOF
    
    # Script de actualización
    cat > "$INSTALL_DIR/scripts/update.sh" << 'EOF'
#!/bin/bash

# Script de actualización automatizada

# Actualizar sistema
apt-get update && apt-get upgrade -y

# Actualizar Virtualmin
/usr/libexec/webmin/update.sh

# Reiniciar servicios si es necesario
systemctl restart nginx
systemctl restart apache2
systemctl restart mysql
systemctl restart postgresql

echo "Sistema actualizado"
EOF
    
    # Script de monitoreo
    cat > "$INSTALL_DIR/scripts/monitor.sh" << 'EOF'
#!/bin/bash

# Script de monitoreo básico

# Verificar servicios
services=("nginx" "apache2" "mysql" "postgresql" "redis-server" "prometheus" "grafana-server")

for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo "✓ $service está activo"
    else
        echo "✗ $service está inactivo"
        systemctl restart "$service"
    fi
done

# Verificar espacio en disco
df -h | grep -E "(/$|/home|/var)" | awk '{print $5 " " $6}' | while read output; do
    usage=$(echo $output | awk '{print $1}' | sed 's/%//')
    path=$(echo $output | awk '{print $2}')
    
    if [ $usage -gt 80 ]; then
        echo "⚠ Espacio en disco bajo en $path: $usage%"
    fi
done
EOF
    
    # Hacer scripts ejecutables
    chmod +x "$INSTALL_DIR/scripts/backup.sh"
    chmod +x "$INSTALL_DIR/scripts/update.sh"
    chmod +x "$INSTALL_DIR/scripts/monitor.sh"
    
    print_message $GREEN "Scripts de automatización creados exitosamente"
    log_message "Scripts de automatización creados exitosamente"
}

# Función para configurar tareas cron
configure_cron() {
    print_message $BLUE "Configurando tareas cron..."
    log_message "Configurando tareas cron"
    
    # Backup diario a las 2 AM
    echo "0 2 * * * $INSTALL_DIR/scripts/backup.sh >> $LOG_FILE 2>&1" > "$INSTALL_DIR/cron/virtualmin-backup"
    crontab "$INSTALL_DIR/cron/virtualmin-backup"
    
    # Actualización semanal los domingos a las 3 AM
    echo "0 3 * * 0 $INSTALL_DIR/scripts/update.sh >> $LOG_FILE 2>&1" > "$INSTALL_DIR/cron/virtualmin-update"
    crontab "$INSTALL_DIR/cron/virtualmin-update"
    
    # Monitoreo cada 5 minutos
    echo "*/5 * * * * $INSTALL_DIR/scripts/monitor.sh >> $LOG_FILE 2>&1" > "$INSTALL_DIR/cron/virtualmin-monitor"
    crontab "$INSTALL_DIR/cron/virtualmin-monitor"
    
    print_message $GREEN "Tareas cron configuradas exitosamente"
    log_message "Tareas cron configuradas exitosamente"
}

# Función principal
main() {
    print_message $GREEN "Iniciando instalación de Virtualmin Enterprise..."
    log_message "Iniciando instalación de Virtualmin Enterprise"
    
    check_root
    create_directories
    install_dependencies
    install_python_dependencies
    configure_firewall
    install_virtualmin
    configure_services
    create_automation_scripts
    configure_cron
    
    print_message $GREEN "Instalación completada exitosamente"
    log_message "Instalación completada exitosamente"
    
    print_message $BLUE "Información de acceso:"
    print_message $BLUE "Webmin: https://$(hostname -I | awk '{print $1}'):10000"
    print_message $BLUE "Virtualmin: https://$(hostname -I | awk '{print $1}'):10000/virtualmin/"
    print_message $BLUE "Grafana: http://$(hostname -I | awk '{print $1}'):3000 (admin/admin)"
    print_message $BLUE "Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
}

# Ejecutar función principal
main "$@"
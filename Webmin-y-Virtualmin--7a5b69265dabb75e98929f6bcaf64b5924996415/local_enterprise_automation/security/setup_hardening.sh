
#!/bin/bash

# Script de instalación y configuración de hardening automático con OpenVAS y Lynis para Virtualmin Enterprise
# Este script instala y configura herramientas de auditoría de seguridad y hardening automático

set -e

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de configuración
INSTALL_DIR="/opt/virtualmin-enterprise"
LOG_FILE="/var/log/virtualmin-enterprise-hardening.log"
CONFIG_DIR="/opt/virtualmin-enterprise/config/hardening"
REPORTS_DIR="/opt/virtualmin-enterprise/reports/security"

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

# Función para detectar distribución del sistema operativo
detect_distribution() {
    if [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "redhat"
    else
        echo "unknown"
    fi
}

# Función para instalar dependencias
install_dependencies() {
    log_message "Instalando dependencias"
    
    local distribution=$(detect_distribution)
    
    case $distribution in
        "debian")
            apt-get update
            apt-get install -y \
                wget \
                curl \
                gnupg \
                lsb-release \
                apt-transport-https \
                ca-certificates \
                software-properties-common \
                python3 \
                python3-pip \
                python3-dev \
                build-essential \
                libssl-dev \
                libffi-dev \
                libxml2-dev \
                libxslt1-dev \
                zlib1g-dev \
                git \
                nmap \
                netcat \
                tcpdump \
                nikto \
                dirb \
                sqlmap \
                hydra \
                john \
                hashcat \
                aircrack-ng \
                wireshark-common \
                tcpflow \
                ngrep \
                lsof \
                strace \
                lynis \
                chkrootkit \
                rkhunter
            ;;
        "redhat")
            yum update -y
            yum groupinstall -y "Development Tools"
            yum install -y \
                wget \
                curl \
                gnupg \
                lsb-release \
                python3 \
                python3-pip \
                python3-devel \
                gcc \
                gcc-c++ \
                make \
                openssl-devel \
                libffi-devel \
                libxml2-devel \
                libxslt-devel \
                zlib-devel \
                git \
                nmap \
                nmap-ncat \
                tcpdump \
                nikto \
                sqlmap \
                hydra \
                john \
                hashcat \
                aircrack-ng \
                wireshark-cli \
                tcpflow \
                ngrep \
                lsof \
                strace \
                lynis \
                chkrootkit \
                rkhunter
            ;;
        *)
            print_message $RED "Distribución no soportada"
            exit 1
            ;;
    esac
    
    log_message "Dependencias instaladas"
}

# Función para instalar y configurar OpenVAS
install_openvas() {
    log_message "Instalando OpenVAS"
    
    local distribution=$(detect_distribution)
    
    case $distribution in
        "debian")
            # Agregar repositorio de Greenbone
            wget -q -O - https://www.greenbone.net/GBCommunity-GPG-Key.asc | apt-key add -
            echo "deb http://download.greenbone.net/download/2.0/debian/ buster main" > /etc/apt/sources.list.d/greenbone.list
            
            # Actualizar lista de paquetes
            apt-get update
            
            # Instalar OpenVAS
            apt-get install -y gvm
            ;;
        "redhat")
            # Agregar repositorio de Greenbone
            yum install -y https://rpm.greenbone.net/GPG-GREENBONE-RELEASE-PUBLIC.KEY
            yum-config-manager -y --add-repo=https://rpm.greenbone.net/GVM-20.08-rhel-8.repo
            
            # Instalar OpenVAS
            yum install -y gvm-libs
            yum install -y gvm
            ;;
    esac
    
    # Crear usuario y grupo para OpenVAS
    if ! id -u gvm &>/dev/null; then
        useradd -r -s /sbin/nologin gvm >> "$LOG_FILE" 2>&1
    fi
    
    # Configurar permisos
    chown -R gvm:gvm /var/lib/gvm >> "$LOG_FILE" 2>&1
    chown -R gvm:gvm /var/log/gvm >> "$LOG_FILE" 2>&1
    chown -R gvm:gvm /etc/gvm >> "$LOG_FILE" 2>&1
    
    # Inicializar OpenVAS
    gvm-setup >> "$LOG_FILE" 2>&1
    
    # Habilitar y iniciar servicios
    systemctl enable gvm >> "$LOG_FILE" 2>&1
    systemctl start gvm >> "$LOG_FILE" 2>&1
    
    # Esperar a que OpenVAS se inicie completamente
    sleep 30
    
    log_message "OpenVAS instalado"
    print_message $GREEN "OpenVAS instalado"
}

# Función para configurar Lynis
configure_lynis() {
    log_message "Configurando Lynis"
    
    # Crear directorio de configuración
    mkdir -p "$CONFIG_DIR/lynis"
    mkdir -p "$REPORTS_DIR/lynis"
    
    # Copiar archivo de configuración de Lynis
    if [ -f "/etc/lynis/default.prf" ]; then
        cp "/etc/lynis/default.prf" "$CONFIG_DIR/lynis/"
    fi
    
    # Configurar Lynis
    cat > "$CONFIG_DIR/lynis/custom.prf" << 'EOF'
# Configuración personalizada de Lynis para Virtualmin Enterprise

# Habilitar todas las categorías de pruebas
tests=ALL

# Excluir pruebas que puedan ser problemáticas
skip-test=FILE-6322  # Permisos de directorios temporales
skip-test=PKG-7390  # Verificación de actualizaciones de paquetes

# Configurar directorio de informes
report-dir=/opt/virtualmin-enterprise/reports/security/lynis

# Configurar formato de informe
report-format=html,csv,txt

# Configurar nivel de detalle
log-detail=medium

# Habilitar auditoría de archivos de configuración de Virtualmin
scan-custom-dir=/etc/webmin
scan-custom-dir=/etc/virtualmin

# Habilitar auditoría de directorios de sitios web
scan-custom-dir=/home
scan-custom-dir=/var/www

# Configurar perfil de seguridad
profile=server
EOF
    
    # Configurar permisos
    chown -R root:root "$CONFIG_DIR/lynis"
    chmod 644 "$CONFIG_DIR/lynis/custom.prf"
    
    log_message "Lynis configurado"
    print_message $GREEN "Lynis configurado"
}

# Función para configurar chkrootkit
configure_chkrootkit() {
    log_message "Configurando chkrootkit"
    
    # Crear directorio de informes
    mkdir -p "$REPORTS_DIR/chkrootkit"
    
    # Crear script de ejecución diario
    cat > "/etc/cron.daily/chkrootkit" << 'EOF'
#!/bin/bash

# Script de ejecución diaria de chkrootkit

REPORT_DIR="/opt/virtualmin-enterprise/reports/security/chkrootkit"
DATE=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPORT_DIR/chkrootkit_$DATE.log"

# Ejecutar chkrootkit
chkrootkit -q -r / > "$REPORT_FILE" 2>&1

# Si se encuentran rootkits, enviar alerta
if [ -s "$REPORT_FILE" ] && grep -q "INFECTED\|Possible rootkits found" "$REPORT_FILE"; then
    # Enviar alerta por email (configurar email)
    echo "¡ALERTA! Se encontraron posibles rootkits en $(hostname)" | mail -s "Alerta de seguridad - chkrootkit" admin@example.com
    
    # Añadir al log del sistema
    logger "ALERTA: chkrootkit encontró posibles rootkits en $(hostname)"
fi

# Mantener solo los últimos 7 días de informes
find "$REPORT_DIR" -name "chkrootkit_*.log" -mtime +7 -delete
EOF
    
    # Configurar permisos
    chmod +x "/etc/cron.daily/chkrootkit"
    
    log_message "chkrootkit configurado"
    print_message $GREEN "chkrootkit configurado"
}

# Función para configurar rkhunter
configure_rkhunter() {
    log_message "Configurando rkhunter"
    
    # Crear directorio de informes
    mkdir -p "$REPORTS_DIR/rkhunter"
    
    # Configurar rkhunter
    cat > "/etc/rkhunter.conf.local" << 'EOF'
# Configuración personalizada de rkhunter para Virtualmin Enterprise

# Configurar directorio de informes
REPORTDIR=/opt/virtualmin-enterprise/reports/security/rkhunter

# Configurar archivo de log
LOGFILE=/var/log/rkhunter.log

# Habilitar actualización automática de base de datos
UPDATE_MIRRORS=1
MIRRORS_MODE=0

# Configurar directorios a excluir
EXCLUDE_USER_DIRS=/dev/shm,/proc,/sys,/usr/share/doc,/usr/share/man,/usr/share/info,/var/tmp,/tmp

# Configurar archivos a excluir
EXCLUDE_USER_FILES=/etc/ld.so.cache,/etc/mtab,/etc/fstab,/etc/blkid.tab

# Configurar comandos a excluir
EXCLUDE_SCM_CMDS=git,svn,cvs,hg,bzr

# Configurar scripts a excluir
EXCLUDE_SCRIPTS=python,perl,php,ruby,bash,sh

# Configurar aplicaciones web
ALLOW_SSH_ROOT_USER=no
ALLOW_SSH_PROT_V1=0
ALLOW_SSH_PROT_V2=1
ENABLE_TESTS=all

# Configurar alertas por email
MAIL-ON-WARNING=1
MAIL-ON-WARNING=admin@example.com
EOF
    
    # Actualizar base de datos de rkhunter
    rkhunter --update >> "$LOG_FILE" 2>&1
    
    # Crear script de ejecución semanal
    cat > "/etc/cron.weekly/rkhunter" << 'EOF'
#!/bin/bash

# Script de ejecución semanal de rkhunter

REPORT_DIR="/opt/virtualmin-enterprise/reports/security/rkhunter"
DATE=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPORT_DIR/rkhunter_$DATE.log"

# Actualizar base de datos
rkhunter --update --report-warnings-only --cronjob > /dev/null 2>&1

# Ejecutar rkhunter
rkhunter --check --report-warnings-only --cronjob > "$REPORT_FILE" 2>&1

# Mantener solo los últimos 30 días de informes
find "$REPORT_DIR" -name "rkhunter_*.log" -mtime +30 -delete
EOF
    
    # Configurar permisos
    chmod +x "/etc/cron.weekly/rkhunter"
    
    log_message "rkhunter configurado"
    print_message $GREEN "rkhunter configurado"
}

# Función para crear script de gestión de hardening
create_management_script() {
    log_message "Creando script de gestión de hardening"
    
    cat > "$INSTALL_DIR/scripts/manage_hardening.sh" << 'EOF'
#!/bin/bash

# Script de gestión de hardening de seguridad para Virtualmin Enterprise

CONFIG_DIR="/opt/virtualmin-enterprise/config/hardening"
REPORTS_DIR="/opt/virtualmin-enterprise/reports/security"
LOG_FILE="/var/log/virtualmin-enterprise-hardening.log"

# Función para registrar mensajes
log_message() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Función para ejecutar auditoría con Lynis
run_lynis_audit() {
    local scan_type=${1:-system}
    local report_file="$REPORTS_DIR/lynis/lynis_$(date +%Y%m%d_%H%M%S).html"
    
    echo "Ejecutando auditoría con Lynis (tipo: $scan_type)..."
    
    case $scan_type in
        "system")
            lynis audit system --profile server --report-file "$report_file" >> "$LOG_FILE" 2>&1
            ;;
        "docker")
            lynis audit docker --report-file "$report_file" >> "$LOG_FILE" 2>&1
            ;;
        "custom")
            lynis audit system --profile server --include-dir /etc/webmin --include-dir /etc/virtualmin --report-file "$report_file" >> "$LOG_FILE" 2>&1
            ;;
        *)
            lynis audit system --profile server --report-file "$report_file" >> "$LOG_FILE" 2>&1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo "Auditoría con Lynis completada: $report_file"
        log_message "Auditoría con Lynis completada: $report_file"
    else
        echo "Error al ejecutar auditoría con Lynis"
        log_message "Error al ejecutar auditoría con Lynis"
        return 1
    fi
    
    # Mostrar resumen de resultados
    echo "Resumen de auditoría:"
    grep -E "Warnings|Suggestions" "$report_file" | head -10
}

# Función para ejecutar análisis con OpenVAS
run_openvas_scan() {
    local target=${1:-localhost}
    local scan_name=${2:-"Virtualmin Security Scan $(date +%Y%m%d_%H%M%S)"}
    
    echo "Ejecutando análisis con OpenVAS (objetivo: $target)..."
    
    # Obtener ID de usuario de GVM
    local gvm_user_id=$(sudo -u gvm gvm-manage-cmd --gmp-username=admin --gmp-password=admin users get | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    
    if [ -z "$gvm_user_id" ]; then
        echo "Error: No se pudo obtener ID de usuario de GVM"
        return 1
    fi
    
    # Crear tarea de análisis
    local scan_task_id=$(sudo -u gvm gvm-manage-cmd --gmp-username=admin --gmp-password=admin tasks create --name "$scan_name" --target "$target" --config "Full and fast" >> "$LOG_FILE" 2>&1 | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    
    if [ -z "$scan_task_id" ]; then
        echo "Error: No se pudo crear tarea de análisis en OpenVAS"
        return 1
    fi
    
    # Iniciar tarea de análisis
    sudo -u gvm gvm-manage-cmd --gmp-username=admin --gmp-password=admin tasks start --task-id "$scan_task_id" >> "$LOG_FILE" 2>&1
    
    echo "Análisis con OpenVAS iniciado (ID: $scan_task_id)"
    log_message "Análisis con OpenVAS iniciado (ID: $scan_task_id)"
    
    # Mostrar estado del análisis
    echo "Para verificar el estado del análisis, ejecute:"
    echo "sudo -u gvm gvm-manage-cmd --gmp-username=admin --gmp-password=admin tasks get --task-id $scan_task_id"
}

# Función para ejecutar análisis con chkrootkit
run_chkrootkit_scan() {
    local report_file="$REPORTS_DIR/chkrootkit/chkrootkit_$(date +%Y%m%d_%H%M%S).log"
    
    echo "Ejecutando análisis con chkrootkit..."
    
    # Crear directorio de informes si no existe
    mkdir -p "$REPORTS_DIR/chkrootkit"
    
    # Ejecutar chkrootkit
    chkrootkit -q -r / > "$report_file" 2>&1
    
    if [ $? -eq 0 ]; then
        echo "Análisis con chkrootkit completado: $report_file"
        log_message "Aná
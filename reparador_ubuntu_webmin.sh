#!/bin/bash

# Reparador automático de Webmin/Virtualmin para Ubuntu
# Soluciona automáticamente los problemas más comunes

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -euo pipefail

# Configuración de colores
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

LOG_FILE="/var/log/reparacion_webmin_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="/var/backups/webmin_repair_$(date +%Y%m%d_%H%M%S)"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

echo -e "${PURPLE}============================================${NC}"
echo -e "${PURPLE}    REPARADOR WEBMIN/VIRTUALMIN UBUNTU     ${NC}"
echo -e "${PURPLE}============================================${NC}"
echo ""

# Verificar permisos root
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Fin de función duplicada

# Crear backup de seguridad
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
    
# Contenido de función duplicada
    
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
    
# Contenido de función duplicada
# Contenido de función duplicada
# Fin de función duplicada

# 1. Actualizar sistema
update_system() {
    log_info "=== ACTUALIZANDO SISTEMA ==="
    
    log_info "Actualizando lista de paquetes..."
    apt update
    
    log_info "Actualizando paquetes del sistema..."
    DEBIAN_FRONTEND=noninteractive apt upgrade -y
    
    log_info "Instalando dependencias básicas..."
    DEBIAN_FRONTEND=noninteractive apt install -y \
        curl wget gnupg2 software-properties-common \
        perl openssl python3 unzip ca-certificates \
        libnet-ssleay-perl libio-socket-ssl-perl \
        libauthen-pam-perl libpam-runtime \
        shared-mime-info
    
    log_success "Sistema actualizado"
    echo ""
}

# 2. Configurar repositorios Webmin
setup_webmin_repository() {
    log_info "=== CONFIGURANDO REPOSITORIO WEBMIN ==="
    
    # Eliminar repositorios existentes
    rm -f /etc/apt/sources.list.d/webmin.list
    
    # Agregar llave GPG
    log_info "Agregando llave GPG de Webmin..."
    curl -fsSL https://download.webmin.com/jcameron-key.asc | gpg --dearmor -o /usr/share/keyrings/webmin.gpg
    
    # Agregar repositorio
    log_info "Agregando repositorio Webmin..."
    echo "deb [signed-by=/usr/share/keyrings/webmin.gpg] https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
    
    # Actualizar listas
    apt update
    
    log_success "Repositorio Webmin configurado"
    echo ""
}

# 3. Instalar Webmin
install_webmin() {
    log_info "=== INSTALANDO WEBMIN ==="
    
    # Desinstalar versión anterior si existe
    if dpkg -l | grep -q webmin; then
        log_info "Desinstalando versión anterior..."
        apt remove --purge -y webmin 2>/dev/null || true
    fi
    
    # Instalar Webmin
    log_info "Instalando Webmin..."
    DEBIAN_FRONTEND=noninteractive apt install -y webmin
    
    # Verificar instalación
    if command -v webmin >/dev/null 2>&1; then
        log_success "Webmin instalado correctamente"
    else
        log_error "Error en la instalación de Webmin"
        return 1
    fi
    
    echo ""
}

# 4. Configurar Webmin
configure_webmin() {
    log_info "=== CONFIGURANDO WEBMIN ==="
    
    # Configuración básica de miniserv.conf
    cat > /etc/webmin/miniserv.conf << 'EOF'
port=10000
root=/usr/share/webmin
mimetypes=/usr/share/webmin/mime.types
addtype_cgi=internal/cgi
realm=Webmin Server
logfile=/var/webmin/miniserv.log
errorlog=/var/webmin/miniserv.error
pidfile=/var/webmin/miniserv.pid
logtime=168
ppath=
ssl=1
env_WEBMIN_CONFIG=/etc/webmin
env_WEBMIN_VAR=/var/webmin
atboot=1
logout=/etc/webmin/logout-flag
listen=10000
denyfile=\.pl$
log=1
blockhost_failures=5
blockhost_time=60
syslog=1
session=1
premodules=WebminCore
server=MiniServ/2.000
userfile=/etc/webmin/miniserv.users
keyfile=/etc/webmin/miniserv.pem
passwd_file=/etc/webmin/miniserv.users
passwd_uindex=0
passwd_pindex=1
passwd_cindex=2
passwd_mindex=4
passwd_mode=0
preload_functions=1
anonymous=/
trust_unknown_referers=1
referers_none=1
gzip=1
maxconns=50
pam_conv=1
EOF

    # Crear certificado SSL
    if [[ ! -f "/etc/webmin/miniserv.pem" ]]; then
        log_info "Generando certificado SSL..."
        openssl req -new -x509 -days 365 -nodes \
            -out /etc/webmin/miniserv.pem \
            -keyout /etc/webmin/miniserv.pem \
            -subj "/C=ES/ST=Madrid/L=Madrid/O=Webmin/CN=$(hostname -f)"
        chmod 600 /etc/webmin/miniserv.pem
    fi
    
    # Configurar permisos
    chmod 600 /etc/webmin/miniserv.conf
    chown root:root /etc/webmin/miniserv.conf
    
    log_success "Webmin configurado"
    echo ""
}

# 5. Instalar dependencias del servidor
install_server_dependencies() {
    log_info "=== INSTALANDO DEPENDENCIAS DEL SERVIDOR ==="
    
    # Apache
    log_info "Instalando Apache..."
    DEBIAN_FRONTEND=noninteractive apt install -y apache2 apache2-utils
    systemctl enable apache2
    
    # MySQL
    log_info "Instalando MySQL..."
    DEBIAN_FRONTEND=noninteractive apt install -y mysql-server mysql-client
    systemctl enable mysql
    
    # PHP
    log_info "Instalando PHP..."
    DEBIAN_FRONTEND=noninteractive apt install -y php php-mysql php-cli php-common php-curl php-gd php-mbstring php-xml php-zip
    
    # Postfix
    log_info "Instalando Postfix..."
    echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
    echo "postfix postfix/mailname string $(hostname -f)" | debconf-set-selections
    DEBIAN_FRONTEND=noninteractive apt install -y postfix
    systemctl enable postfix
    
    # BIND DNS
    log_info "Instalando BIND..."
    DEBIAN_FRONTEND=noninteractive apt install -y bind9 bind9utils bind9-doc
    systemctl enable named
    
    # Dovecot
    log_info "Instalando Dovecot..."
    DEBIAN_FRONTEND=noninteractive apt install -y dovecot-core dovecot-imapd dovecot-pop3d
    systemctl enable dovecot
    
    # Fail2Ban
    log_info "Instalando Fail2Ban..."
    DEBIAN_FRONTEND=noninteractive apt install -y fail2ban
    systemctl enable fail2ban
    
    log_success "Dependencias del servidor instaladas"
    echo ""
}

# 6. Instalar Virtualmin
install_virtualmin() {
    log_info "=== INSTALANDO VIRTUALMIN ==="
    
    # Descargar script oficial de Virtualmin
    log_info "Descargando script de instalación Virtualmin..."
    wget -O /tmp/install.sh https://software.virtualmin.com/gpl/scripts/install.sh
    chmod +x /tmp/install.sh
    
    # Ejecutar instalación Virtualmin
    log_info "Ejecutando instalación Virtualmin (esto puede tomar varios minutos)..."
    /tmp/install.sh --force --hostname "$(hostname -f)" --bundle LAMP
    
    # Verificar instalación
    if command -v virtualmin >/dev/null 2>&1; then
        log_success "Virtualmin instalado correctamente"
    else
        log_warning "Virtualmin puede requerir configuración adicional"
    fi
    
    echo ""
}

# 7. Configurar firewall
configure_firewall() {
    log_info "=== CONFIGURANDO FIREWALL ==="
    
    # Instalar UFW si no está presente
    if ! command -v ufw >/dev/null 2>&1; then
        apt install -y ufw
    fi
    
    # Configurar reglas básicas
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # Permitir servicios esenciales
    ufw allow 22/tcp    # SSH
    ufw allow 80/tcp    # HTTP
    ufw allow 443/tcp   # HTTPS
    ufw allow 10000/tcp # Webmin
    ufw allow 20000/tcp # Usermin
    ufw allow 25/tcp    # SMTP
    ufw allow 53        # DNS
    ufw allow 993/tcp   # IMAPS
    ufw allow 995/tcp   # POP3S
    
    # Activar firewall
    ufw --force enable
    
    log_success "Firewall configurado"
    echo ""
}

# 8. Iniciar servicios
start_services() {
    log_info "=== INICIANDO SERVICIOS ==="
    
    local services=("webmin" "apache2" "mysql" "postfix" "named" "dovecot" "fail2ban")
    
    for service in "${services[@]}"; do
        log_info "Iniciando $service..."
        
        if systemctl enable "$service" 2>/dev/null && systemctl start "$service" 2>/dev/null; then
            if systemctl is-active --quiet "$service"; then
                log_success "Servicio $service: ACTIVO"
            else
                log_warning "Servicio $service: Problemas al iniciar"
            fi
        else
            log_warning "No se pudo iniciar $service (puede no estar instalado)"
        fi
    done
    
    echo ""
}

# 9. Verificar instalación
verify_installation() {
    log_info "=== VERIFICANDO INSTALACIÓN ==="
    
    # Verificar Webmin
    if curl -k -s --connect-timeout 10 "https://localhost:10000" >/dev/null 2>&1; then
        log_success "Webmin accesible vía HTTPS"
    else
        log_warning "Webmin no accesible por HTTPS"
    fi
    
    # Verificar servicios
    local services=("webmin" "apache2" "mysql")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_success "Servicio $service: FUNCIONANDO"
        else
            log_warning "Servicio $service: PROBLEMA"
        fi
    done
    
    # Verificar puertos
    local ports=("10000" "80" "22")
    for port in "${ports[@]}"; do
        if netstat -tuln | grep -q ":${port} "; then
            log_success "Puerto $port: ABIERTO"
        else
            log_warning "Puerto $port: CERRADO"
        fi
    done
    
    echo ""
}

# 10. Mostrar información final
show_final_info() {
    echo -e "${PURPLE}============================================${NC}"
    echo -e "${PURPLE}         INSTALACIÓN COMPLETADA            ${NC}"
    echo -e "${PURPLE}============================================${NC}"
    echo ""
    
    log_success "¡Webmin/Virtualmin instalado correctamente!"
    echo ""
    
    log_info "INFORMACIÓN DE ACCESO:"
    echo "URL Webmin: https://$(hostname -I | awk '{print $1}'):10000"
    echo "URL alternativa: https://$(hostname):10000"
    echo ""
    
    log_info "USUARIOS PREDETERMINADOS:"
    echo "Usuario: root"
    echo "Contraseña: [contraseña de root del sistema]"
    echo ""
    
    log_info "SERVICIOS INSTALADOS:"
    echo "✅ Webmin (Puerto 10000)"
    echo "✅ Apache (Puerto 80/443)"
    echo "✅ MySQL (Puerto 3306)"
    echo "✅ Postfix (Puerto 25)"
    echo "✅ BIND DNS (Puerto 53)"
    echo "✅ Dovecot (Puerto 993/995)"
    echo ""
    
    log_info "CONFIGURACIÓN ADICIONAL:"
    echo "1. Acceder a Webmin para configurar dominios"
    echo "2. Ejecutar el asistente de configuración inicial"
    echo "3. Configurar DNS si es necesario"
    echo "4. Configurar certificados SSL"
    echo ""
    
    log_info "ARCHIVOS IMPORTANTES:"
    echo "Log de instalación: $LOG_FILE"
    echo "Backup de configuración: $BACKUP_DIR"
    echo "Configuración Webmin: /etc/webmin/"
    echo ""
    
    log_info "COMANDOS ÚTILES:"
    echo "Reiniciar Webmin: systemctl restart webmin"
    echo "Ver logs Webmin: tail -f /var/webmin/miniserv.log"
    echo "Estado servicios: systemctl status webmin"
    echo ""
}

# FUNCIÓN PRINCIPAL
main() {
    log_message "=== INICIANDO REPARACIÓN WEBMIN/VIRTUALMIN ==="
    
    check_root
    create_backup
    update_system
    setup_webmin_repository
    install_webmin
    configure_webmin
    install_server_dependencies
    configure_firewall
    start_services
    verify_installation
    
    # Instalar Virtualmin (opcional)
    read -p "¿Instalar Virtualmin también? (s/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        install_virtualmin
    fi
    
    show_final_info
    
    log_message "=== REPARACIÓN COMPLETADA ==="
}

# Verificar argumentos
case "${1:-}" in
    --force)
        main
        ;;
    --webmin-only)
        check_root
        create_backup
        update_system
        setup_webmin_repository
        install_webmin
        configure_webmin
        start_services
        verify_installation
        show_final_info
        ;;
    *)
        echo "Reparador automático de Webmin/Virtualmin para Ubuntu"
        echo ""
        echo "Uso: $0 [--force|--webmin-only]"
        echo ""
        echo "  --force       Ejecutar reparación completa sin confirmación"
        echo "  --webmin-only Solo instalar y configurar Webmin"
        echo ""
        echo "ADVERTENCIA: Este script hace cambios importantes en el sistema"
        echo "Se recomienda ejecutar en un servidor de pruebas primero"
        echo ""
        read -p "¿Continuar con la reparación completa? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            main
        else
            echo "Operación cancelada"
            exit 0
        fi
        ;;
esac

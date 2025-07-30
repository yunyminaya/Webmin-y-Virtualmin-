#!/bin/bash

# Script de Instalación Unificada: Authentic Theme + Virtualmin
# Instala ambos componentes como un sistema integrado único

set -e

echo "========================================"
echo "  INSTALACIÓN UNIFICADA"
echo "  Authentic Theme + Virtualmin"
echo "  Como un solo sistema integrado"
echo "========================================"
echo

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Funciones de logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[PASO]${NC} $1"
}

# Verificar privilegios de root
if [[ $EUID -ne 0 ]]; then
   log_error "Este script debe ejecutarse como root (usa sudo)"
   exit 1
fi

# Detectar sistema operativo
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        log_info "Sistema detectado: $OS $VER"
    else
        log_error "No se puede detectar el sistema operativo"
        exit 1
    fi
}

# Verificar conectividad a internet
check_internet() {
    log_step "Verificando conectividad a internet..."
    if ping -c 1 google.com &> /dev/null; then
        log_success "Conectividad a internet OK"
    else
        log_error "No hay conectividad a internet. Se requiere para la instalación."
        exit 1
    fi
}

# Actualizar sistema
update_system() {
    log_step "Actualizando sistema base..."
    
    if command -v apt-get &> /dev/null; then
        apt-get update -y
        apt-get upgrade -y
        log_success "Sistema Ubuntu/Debian actualizado"
    elif command -v yum &> /dev/null; then
        yum update -y
        log_success "Sistema CentOS/RHEL actualizado"
    elif command -v dnf &> /dev/null; then
        dnf update -y
        log_success "Sistema Fedora actualizado"
    else
        log_warning "Gestor de paquetes no reconocido, continuando..."
    fi
}

# Instalar dependencias básicas
install_dependencies() {
    log_step "Instalando dependencias básicas..."
    
    if command -v apt-get &> /dev/null; then
        apt-get install -y wget curl unzip software-properties-common
    elif command -v yum &> /dev/null; then
        yum install -y wget curl unzip
    elif command -v dnf &> /dev/null; then
        dnf install -y wget curl unzip
    fi
    
    log_success "Dependencias instaladas"
}

# Descargar e instalar Virtualmin con Authentic Theme
install_virtualmin_unified() {
    log_step "Descargando script oficial de Virtualmin..."
    
    # Descargar script oficial
    cd /tmp
    wget -O virtualmin-install.sh https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh
    
    if [[ $? -eq 0 ]]; then
        log_success "Script descargado correctamente"
        chmod +x virtualmin-install.sh
        
        log_step "Iniciando instalación unificada de Virtualmin + Webmin + Authentic Theme..."
        log_info "Esto puede tomar varios minutos..."
        
        # Ejecutar instalación con bundle LAMP y configuración automática
        ./virtualmin-install.sh --bundle LAMP --yes --force
        
        if [[ $? -eq 0 ]]; then
            log_success "Virtualmin instalado correctamente con stack completo"
        else
            log_error "Error en la instalación de Virtualmin"
            return 1
        fi
    else
        log_error "No se pudo descargar el script de instalación"
        return 1
    fi
}

# Instalar/Actualizar Authentic Theme
install_authentic_theme() {
    log_step "Instalando Authentic Theme como interfaz unificada..."
    
    # Directorio de temas de Webmin
    THEME_DIR="/usr/share/webmin/authentic-theme"
    
    # Si existe el directorio local, usarlo
    if [[ -d "/Users/yunyminaya/Wedmin Y Virtualmin/authentic-theme-master" ]]; then
        log_info "Usando Authentic Theme local..."
        
        # Backup del tema existente si existe
        if [[ -d "$THEME_DIR" ]]; then
            mv "$THEME_DIR" "${THEME_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
        fi
        
        # Copiar tema local
        cp -r "/Users/yunyminaya/Wedmin Y Virtualmin/authentic-theme-master" "$THEME_DIR"
        chown -R root:root "$THEME_DIR"
        chmod -R 755 "$THEME_DIR"
        
        log_success "Authentic Theme local instalado"
    else
        # Descargar la última versión
        log_info "Descargando última versión de Authentic Theme..."
        
        cd /tmp
        wget -O authentic-theme.zip https://github.com/authentic-theme/authentic-theme/archive/refs/heads/master.zip
        
        if [[ $? -eq 0 ]]; then
            unzip -q authentic-theme.zip
            
            # Backup del tema existente si existe
            if [[ -d "$THEME_DIR" ]]; then
                mv "$THEME_DIR" "${THEME_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
            fi
            
            # Instalar nuevo tema
            mv authentic-theme-master "$THEME_DIR"
            chown -R root:root "$THEME_DIR"
            chmod -R 755 "$THEME_DIR"
            
            log_success "Authentic Theme descargado e instalado"
        else
            log_warning "No se pudo descargar Authentic Theme, usando el incluido con Virtualmin"
        fi
    fi
}

# Configurar sistema unificado
configure_unified_system() {
    log_step "Configurando sistema unificado..."
    
    # Configurar Authentic Theme como tema por defecto
    if [[ -f "/etc/webmin/config" ]]; then
        # Backup de configuración
        cp "/etc/webmin/config" "/etc/webmin/config.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Establecer Authentic Theme
        if grep -q "^theme=" "/etc/webmin/config"; then
            sed -i 's/^theme=.*/theme=authentic-theme/' "/etc/webmin/config"
        else
            echo "theme=authentic-theme" >> "/etc/webmin/config"
        fi
        
        log_success "Authentic Theme configurado como tema por defecto"
    fi
    
    # Configurar Virtualmin para inicio automático
    if [[ -f "/etc/webmin/virtual-server/config" ]]; then
        # Habilitar características avanzadas
        echo "show_virtualmin_tab=1" >> "/etc/webmin/virtual-server/config"
        log_success "Virtualmin configurado para interfaz unificada"
    fi
    
    # Configurar puertos del firewall
    configure_firewall
}

# Configurar firewall
configure_firewall() {
    log_step "Configurando firewall para acceso web..."
    
    # UFW (Ubuntu/Debian)
    if command -v ufw &> /dev/null; then
        ufw allow 10000/tcp comment "Webmin/Virtualmin"
        ufw allow 80/tcp comment "HTTP"
        ufw allow 443/tcp comment "HTTPS"
        log_success "Firewall UFW configurado"
    
    # Firewalld (CentOS/RHEL/Fedora)
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=10000/tcp
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
        log_success "Firewall firewalld configurado"
    
    # iptables básico
    elif command -v iptables &> /dev/null; then
        iptables -A INPUT -p tcp --dport 10000 -j ACCEPT
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
        log_success "Firewall iptables configurado"
    else
        log_warning "No se detectó firewall, asegúrate de abrir los puertos manualmente"
    fi
}

# Reiniciar servicios
restart_services() {
    log_step "Reiniciando servicios del sistema unificado..."
    
    # Reiniciar Webmin
    if systemctl is-active --quiet webmin; then
        systemctl restart webmin
        log_success "Webmin reiniciado"
    elif service webmin status &> /dev/null; then
        service webmin restart
        log_success "Webmin reiniciado"
    fi
    
    # Reiniciar Apache si está instalado
    if systemctl is-active --quiet apache2; then
        systemctl restart apache2
        log_success "Apache reiniciado"
    elif systemctl is-active --quiet httpd; then
        systemctl restart httpd
        log_success "Apache reiniciado"
    fi
}

# Obtener información del sistema
get_system_info() {
    # Obtener IP del servidor
    SERVER_IP=$(hostname -I | awk '{print $1}')
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "tu-servidor")
    fi
    
    # Puerto de Webmin
    WEBMIN_PORT="10000"
    if [[ -f "/etc/webmin/miniserv.conf" ]]; then
        WEBMIN_PORT=$(grep "^port=" /etc/webmin/miniserv.conf | cut -d= -f2)
    fi
}

# Mostrar información final
show_final_info() {
    echo
    echo "========================================"
    echo -e "${GREEN}  ¡INSTALACIÓN COMPLETADA!${NC}"
    echo "========================================"
    echo
    log_success "Sistema unificado Virtualmin + Authentic Theme instalado"
    echo
    echo -e "${PURPLE}📋 INFORMACIÓN DE ACCESO:${NC}"
    echo -e "   🌐 URL del Panel: ${BLUE}https://$SERVER_IP:$WEBMIN_PORT${NC}"
    echo -e "   👤 Usuario: ${YELLOW}root${NC}"
    echo -e "   🔑 Contraseña: ${YELLOW}tu contraseña de root${NC}"
    echo
    echo -e "${PURPLE}🚀 PRÓXIMOS PASOS:${NC}"
    echo "   1. Accede al panel web usando la URL de arriba"
    echo "   2. Inicia sesión con tu usuario root"
    echo "   3. Ve a 'Virtualmin Virtual Servers' en el menú"
    echo "   4. Ejecuta el asistente de configuración inicial"
    echo "   5. Crea tu primer dominio virtual"
    echo
    echo -e "${PURPLE}✨ CARACTERÍSTICAS INSTALADAS:${NC}"
    echo "   ✅ Webmin (administración del sistema)"
    echo "   ✅ Virtualmin (hosting virtual)"
    echo "   ✅ Authentic Theme (interfaz moderna)"
    echo "   ✅ Apache Web Server"
    echo "   ✅ MySQL/MariaDB"
    echo "   ✅ PHP (múltiples versiones)"
    echo "   ✅ Postfix (correo)"
    echo "   ✅ BIND (DNS)"
    echo
    echo -e "${GREEN}¡Tu panel de control unificado está listo para usar!${NC}"
    echo
}

# Función principal
main() {
    echo -e "${BLUE}Iniciando instalación unificada...${NC}"
    echo
    
    detect_os
    check_internet
    update_system
    install_dependencies
    install_virtualmin_unified
    install_authentic_theme
    configure_unified_system
    restart_services
    get_system_info
    show_final_info
    
    echo -e "${GREEN}🎉 ¡Instalación unificada completada exitosamente!${NC}"
}

# Ejecutar instalación
main

# Limpiar archivos temporales
cd /
rm -f /tmp/virtualmin-install.sh
rm -f /tmp/authentic-theme.zip
rm -rf /tmp/authentic-theme-master

echo
echo -e "${BLUE}Instalación finalizada. ¡Disfruta de tu nuevo panel unificado!${NC}"
#!/bin/bash

# Instalador unificado para Webmin/Virtualmin
# Versión: 3.0 Enterprise

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para verificar root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: Este script debe ejecutarse como root${NC}" >&2
        exit 1
    fi
}

# Función para verificar sistema operativo
check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        echo -e "${RED}Error: No se pudo determinar el sistema operativo${NC}"
        exit 1
    fi
}

# Función para verificar requisitos del sistema
check_system_requirements() {
    # Verificar memoria RAM (mínimo 2GB, recomendado 4GB)
    local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_gb=$(echo "scale=2; $mem_kb / 1024 / 1024" | bc)
    
    if (( $(echo "$mem_gb < 2" | bc -l) )); then
        echo -e "${RED}Error: Memoria RAM insuficiente (${mem_gb}GB). Mínimo requerido: 2GB${NC}"
        exit 1
    elif (( $(echo "$mem_gb < 4" | bc -l) )); then
        echo -e "${YELLOW}Advertencia: Memoria RAM limitada (${mem_gb}GB). Se recomiendan 4GB o más${NC}"
    fi
    
    # Verificar espacio en disco (mínimo 20GB, recomendado 50GB)
    local disk_kb=$(df -k / | tail -1 | awk '{print $4}')
    local disk_gb=$(echo "scale=2; $disk_kb / 1024 / 1024" | bc)
    
    if (( $(echo "$disk_gb < 20" | bc -l) )); then
        echo -e "${RED}Error: Espacio en disco insuficiente (${disk_gb}GB). Mínimo requerido: 20GB${NC}"
        exit 1
    elif (( $(echo "$disk_gb < 50" | bc -l) )); then
        echo -e "${YELLOW}Advertencia: Espacio en disco limitado (${disk_gb}GB). Se recomiendan 50GB o más${NC}"
    fi
}

# Función para instalar dependencias
install_dependencies() {
    echo -e "${GREEN}Instalando dependencias...${NC}"
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y curl software-properties-common apt-transport-https
            ;;
        centos|rhel|fedora)
            yum install -y curl epel-release
            ;;
        *)
            echo -e "${RED}Error: Sistema operativo no soportado: $OS${NC}"
            exit 1
            ;;
    esac
}

# Función para instalar Webmin
install_webmin() {
    echo -e "${GREEN}Instalando Webmin...${NC}"
    
    case $OS in
        ubuntu|debian)
            curl -o /etc/apt/trusted.gpg.d/webmin.gpg https://download.webmin.com/jcameron-key.asc
            echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
            apt-get update
            apt-get install -y webmin
            ;;
        centos|rhel|fedora)
            curl -o /etc/yum.repos.d/webmin.repo https://download.webmin.com/download/yum/webmin.repo
            yum install -y webmin
            ;;
    esac
}

# Función para instalar Virtualmin
install_virtualmin() {
    echo -e "${GREEN}Instalando Virtualmin...${NC}"
    curl -sSL https://raw.githubusercontent.com/virtualmin/virtualmin-installer/master/install.sh | bash
}

# Función para configurar seguridad
configure_security() {
    echo -e "${GREEN}Configurando seguridad...${NC}"
    
    # Habilitar firewall
    if command -v ufw >/dev/null; then
        ufw allow 10000/tcp
        ufw reload
    elif command -v firewall-cmd >/dev/null; then
        firewall-cmd --permanent --add-port=10000/tcp
        firewall-cmd --reload
    fi
    
    # Configurar certificado SSL
    /usr/share/webmin/install-module.pl /usr/share/webmin/authentic-theme/authentic-theme.wbm
    /usr/share/webmin/install-module.pl /usr/share/webmin/miniserv.pem
    
    # Configurar autenticación de dos factores
    if [ -f /etc/webmin/miniserv.conf ]; then
        echo "twofactor=1" >> /etc/webmin/miniserv.conf
        systemctl restart webmin
    fi
}

# Función principal
main() {
    check_root
    check_os
    check_system_requirements
    install_dependencies
    install_webmin
    install_virtualmin
    configure_security
    
    echo -e "${GREEN}Instalación completada con éxito!${NC}"
    echo -e "Accede a la interfaz en: https://$(hostname -f):10000"
}

# Ejecutar función principal
main
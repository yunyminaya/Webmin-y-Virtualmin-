#!/bin/bash

# ============================================================================
# INSTALADOR WEBMIN/VIRTUALMIN - VERSIÓN FINAL
# ============================================================================
# Este script instala Webmin y Virtualmin directamente sin necesidad de descargar nada
# ============================================================================

set -e

# Colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  INSTALADOR WEBMIN/VIRTUALMIN  ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Detectar sistema operativo
echo -e "${YELLOW}Detectando sistema operativo...${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
    echo -e "${GREEN}Sistema detectado: $PRETTY_NAME${NC}"
else
    echo -e "${RED}Error: No se pudo detectar el sistema operativo${NC}"
    exit 1
fi

# Verificar root
echo -e "${YELLOW}Verificando permisos de root...${NC}"
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Este script debe ejecutarse como root (sudo)${NC}"
    echo -e "${YELLOW}Ejecuta: sudo bash $0${NC}"
    exit 1
fi
echo -e "${GREEN}Permisos de root verificados${NC}"

# Verificar requisitos del sistema
echo -e "${YELLOW}Verificando requisitos del sistema...${NC}"
MEM_GB=$(free -g | awk '/^Mem:/ {print $2}')
DISK_GB=$(df -h / | awk '$NF=="/" {print $4}' | sed 's/G//')

if [ "$MEM_GB" -lt 2 ]; then
    echo -e "${RED}Error: Memoria RAM insuficiente (${MEM_GB}GB). Mínimo requerido: 2GB${NC}"
    exit 1
elif [ "$MEM_GB" -lt 4 ]; then
    echo -e "${YELLOW}Advertencia: Memoria RAM limitada (${MEM_GB}GB). Se recomiendan 4GB o más${NC}"
fi

if [ "$DISK_GB" -lt 20 ]; then
    echo -e "${RED}Error: Espacio en disco insuficiente (${DISK_GB}GB). Mínimo requerido: 20GB${NC}"
    exit 1
elif [ "$DISK_GB" -lt 50 ]; then
    echo -e "${YELLOW}Advertencia: Espacio en disco limitado (${DISK_GB}GB). Se recomiendan 50GB o más${NC}"
fi

echo -e "${GREEN}Requisitos verificados${NC}"

# Instalar dependencias
echo -e "${YELLOW}Instalando dependencias...${NC}"
case $OS in
    ubuntu|debian)
        apt-get update -qq
        apt-get install -y curl wget gnupg2
        ;;
    centos|rhel|fedora|rocky|almalinux)
        if command -v dnf >/dev/null; then
            dnf install -y curl wget gnupg2
        else
            yum install -y curl wget gnupg2
        fi
        ;;
    *)
        echo -e "${RED}Error: Sistema operativo no soportado: $OS${NC}"
        exit 1
        ;;
esac
echo -e "${GREEN}Dependencias instaladas${NC}"

# Instalar Webmin
echo -e "${YELLOW}Instalando Webmin...${NC}"
case $OS in
    ubuntu|debian)
        wget -qO /tmp/webmin.deb http://www.webmin.com/download/deb/webmin-current.deb 2>/dev/null
        dpkg -i /tmp/webmin.deb 2>/dev/null || apt-get install -f -y
        ;;
    centos|rhel|fedora|rocky|almalinux)
        wget -qO /tmp/webmin.rpm http://www.webmin.com/download/rpm/webmin-current.rpm 2>/dev/null
        rpm -U /tmp/webmin.rpm 2>/dev/null
        ;;
esac
echo -e "${GREEN}Webmin instalado${NC}"

# Instalar Virtualmin
echo -e "${YELLOW}Instalando Virtualmin...${NC}"
echo -e "${YELLOW}Esto puede tomar varios minutos...${NC}"
curl -sSL https://software.virtualmin.com/gpl/scripts/install.sh | bash
echo -e "${GREEN}Virtualmin instalado${NC}"

# Configurar firewall
echo -e "${YELLOW}Configurando firewall...${NC}"
if command -v ufw >/dev/null; then
    ufw allow 10000/tcp 2>/dev/null
    ufw reload 2>/dev/null
    echo -e "${GREEN}Firewall UFW configurado${NC}"
elif command -v firewall-cmd >/dev/null; then
    firewall-cmd --permanent --add-port=10000/tcp 2>/dev/null
    firewall-cmd --reload 2>/dev/null
    echo -e "${GREEN}Firewall Firewalld configurado${NC}"
fi

# Obtener IP del servidor
SERVER_IP=$(hostname -I | awk '{print $1}')

# Mostrar resultados
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}        INSTALACIÓN COMPLETADA       ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}Webmin instalado correctamente${NC}"
echo -e "${GREEN}Virtualmin instalado correctamente${NC}"
echo -e "${GREEN}Firewall configurado correctamente${NC}"
echo ""
echo -e "${YELLOW}ACCESO A WEBMIN:${NC}"
echo -e "${GREEN}https://${SERVER_IP}:10000${NC}"
echo ""
echo -e "${YELLOW}ACCESO A VIRTUALMIN:${NC}"
echo -e "${GREEN}https://${SERVER_IP}:10000/virtualmin${NC}"
echo ""
echo -e "${YELLOW}USUARIO: root${NC}"
echo -e "${YELLOW}CONTRASEÑA: Tu contraseña de root${NC}"
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}NOTAS IMPORTANTES:${NC}"
echo -e "${YELLOW}1. Cambia la contraseña de root después del primer inicio${NC}"
echo -e "${YELLOW}2. El firewall ya está configurado para el puerto 10000${NC}"
echo -e "${YELLOW}3. Webmin y Virtualmin se iniciarán automáticamente${NC}"
echo -e "${GREEN}========================================${NC}"

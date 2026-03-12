#!/bin/bash

# ============================================================================
# INSTALADOR WEBMIN/VIRTUALMIN - VERSIÓN FINAL
# ============================================================================
# Este script clona el repositorio e instala Webmin y Virtualmin
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

# Verificar root
echo -e "${YELLOW}Verificando permisos de root...${NC}"
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Este script debe ejecutarse como root (sudo)${NC}"
    echo -e "${YELLOW}Ejecuta: sudo bash $0${NC}"
    exit 1
fi
echo -e "${GREEN}Permisos de root verificados${NC}"

# Clonar repositorio
echo -e "${YELLOW}Clonando repositorio...${NC}"
cd /tmp
rm -rf Webmin-Virtualmin
git clone https://github.com/yunyminaya/Webmin-y-Virtualmin-.git
cd Webmin-Virtualmin-

# Buscar script de instalación
echo -e "${YELLOW}Buscando script de instalación...${NC}"
INSTALL_SCRIPT=""

if [ -f "install.sh" ]; then
    INSTALL_SCRIPT="install.sh"
elif [ -f "install_webmin_ubuntu.sh" ]; then
    INSTALL_SCRIPT="install_webmin_ubuntu.sh"
elif [ -f "instalar_webmin_virtualmin.sh" ]; then
    INSTALL_SCRIPT="instalar_webmin_virtualmin.sh"
else
    echo -e "${RED}Error: No se encontró script de instalación${NC}"
    exit 1
fi

echo -e "${GREEN}Script encontrado: $INSTALL_SCRIPT${NC}"

# Ejecutar script de instalación
echo -e "${YELLOW}Ejecutando script de instalación...${NC}"
chmod +x "$INSTALL_SCRIPT"
bash "$INSTALL_SCRIPT"

# Limpiar
cd /
rm -rf /tmp/Webmin-Virtualmin

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}        INSTALACIÓN COMPLETADA       ${NC}"
echo -e "${GREEN}========================================${NC}"

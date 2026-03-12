#!/bin/bash

# ============================================================================
# INSTALADOR WEBMIN/VIRTUALMIN - DESCARGA AUTOMÁTICA
# ============================================================================
# Este script descarga el repositorio y ejecuta la instalación localmente
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

# Crear directorio temporal
TEMP_DIR=$(mktemp -d)
echo -e "${YELLOW}Directorio temporal: $TEMP_DIR${NC}"

# Clonar repositorio
echo -e "${YELLOW}Clonando repositorio...${NC}"
cd "$TEMP_DIR"
git clone https://github.com/yunyminaya/Webmin-y-Virtualmin-.git
cd Webmin-y-Virtualmin-

# Navegar al subdirectorio correcto
echo -e "${YELLOW}Navegando al subdirectorio correcto...${NC}"
if [ -d "Webmin-y-Virtualmin--7a5b69265dabb75e98929f6bcaf64b5924996415" ]; then
    cd "Webmin-y-Virtualmin--7a5b69265dabb75e98929f6bcaf64b5924996415"
    echo -e "${GREEN}Subdirectorio encontrado${NC}"
else
    echo -e "${RED}Error: No se encontró el subdirectorio${NC}"
    exit 1
fi

# Buscar script de instalación
echo -e "${YELLOW}Buscando script de instalación...${NC}"
INSTALL_SCRIPT=""

if [ -f "install.sh" ]; then
    INSTALL_SCRIPT="install.sh"
elif [ -f "install_simple.sh" ]; then
    INSTALL_SCRIPT="install_simple.sh"
elif [ -f "install_webmin_ubuntu.sh" ]; then
    INSTALL_SCRIPT="install_webmin_ubuntu.sh"
elif [ -f "instalar_webmin_virtualmin.sh" ]; then
    INSTALL_SCRIPT="instalar_webmin_virtualmin.sh"
else
    echo -e "${RED}Error: No se encontró script de instalación${NC}"
    echo -e "${YELLOW}Buscando archivos disponibles...${NC}"
    ls -la *.sh
    exit 1
fi

echo -e "${GREEN}Script encontrado: $INSTALL_SCRIPT${NC}"

# Ejecutar script de instalación
echo -e "${YELLOW}Ejecutando script de instalación...${NC}"
chmod +x "$INSTALL_SCRIPT"
bash "$INSTALL_SCRIPT"

# Limpiar
cd /
rm -rf "$TEMP_DIR"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}        INSTALACIÓN COMPLETADA       ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}Webmin instalado correctamente${NC}"
echo -e "${GREEN}Virtualmin instalado correctamente${NC}"
echo ""
echo -e "${YELLOW}ACCESO A WEBMIN:${NC}"
echo -e "${YELLOW}Ejecuta: https://$(hostname -I | awk '{print $1}'):10000${NC}"
echo ""
echo -e "${YELLOW}ACCESO A VIRTUALMIN:${NC}"
echo -e "${YELLOW}Ejecuta: https://$(hostname -I | awk '{print $1}'):10000/virtualmin${NC}"
echo ""
echo -e "${YELLOW}USUARIO: root${NC}"
echo -e "${YELLOW}CONTRASEÑA: Tu contraseña de root${NC}"
echo ""
echo -e "${GREEN}========================================${NC}"

#!/bin/bash

# ============================================================================
# INSTALADOR WEBMIN/VIRTUALMIN - DESCARGA DIRECTA
# ============================================================================
# Este script descarga el contenido del script de instalación y lo ejecuta
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

# URL del script de instalación
SCRIPT_URL="https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install.sh"

# Descargar el script de instalación
echo -e "${YELLOW}Descargando script de instalación...${NC}"
SCRIPT_CONTENT=$(curl -sSL "$SCRIPT_URL" 2>/dev/null)

# Verificar que el script se descargó correctamente
if [ -z "$SCRIPT_CONTENT" ]; then
    echo -e "${RED}Error: No se pudo descargar el script de instalación${NC}"
    exit 1
fi

# Crear archivo temporal
TEMP_SCRIPT=$(mktemp)
echo "$SCRIPT_CONTENT" > "$TEMP_SCRIPT"

# Dar permisos de ejecución
chmod +x "$TEMP_SCRIPT"

# Ejecutar script de instalación
echo -e "${YELLOW}Ejecutando script de instalación...${NC}"
bash "$TEMP_SCRIPT"

# Limpiar
rm -f "$TEMP_SCRIPT"

# Mostrar resultados
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}        INSTALACIÓN COMPLETADA       ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}Webmin instalado correctamente${NC}"
echo -e "${GREEN}Virtualmin instalado correctamente${NC}"
echo ""
echo -e "${YELLOW}ACCESO A WEBMIN:${NC}"
echo -e "${GREEN}https://$(hostname -I | awk '{print $1}'):10000${NC}"
echo ""
echo -e "${YELLOW}ACCESO A VIRTUALMIN:${NC}"
echo -e "${GREEN}https://$(hostname -I | awk '{print $1}'):10000/virtualmin${NC}"
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

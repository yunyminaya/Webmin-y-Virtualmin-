#!/bin/bash

# ============================================================================
# VERIFICADOR DE ENLACES Y RECURSOS DEL REPOSITORIO
# ============================================================================
# Este script verifica que todos los enlaces y recursos estén disponibles
# ============================================================================

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
GITHUB_USER="yunyminaya"
REPO_NAME="Webmin-y-Virtualmin-"
BRANCH="main"
RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}"
API_URL="https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║     VERIFICADOR DE ENLACES Y RECURSOS DEL REPOSITORIO        ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Función para verificar URL
check_url() {
    local url="$1"
    local name="$2"
    
    if curl -fsSL --head --connect-timeout 10 "$url" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $name: ${GREEN}OK${NC}"
        return 0
    elif wget --spider -q --timeout=10 "$url" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $name: ${GREEN}OK${NC}"
        return 0
    else
        echo -e "${RED}✗${NC} $name: ${RED}ERROR 404${NC}"
        return 1
    fi
}

# Verificar repositorio de GitHub
echo -e "${BLUE}[1/4] Verificando repositorio GitHub...${NC}"
check_url "$API_URL" "API de GitHub"
check_url "https://github.com/${GITHUB_USER}/${REPO_NAME}" "Repositorio GitHub"
echo ""

# Verificar archivos de instalación principales
echo -e "${BLUE}[2/4] Verificando scripts de instalación principales...${NC}"
scripts=(
    "install.sh"
    "install_webmin_virtualmin_complete.sh"
    "install_pro_complete.sh"
    "install_ultra_simple.sh"
    "pro_activation_master.sh"
    "activate_all_pro_features.sh"
)

for script in "${scripts[@]}"; do
    check_url "${RAW_URL}/${script}" "$script"
done
echo ""

# Verificar recursos externos críticos
echo -e "${BLUE}[3/4] Verificando recursos externos...${NC}"
check_url "https://download.webmin.com/jcameron-key.asc" "Webmin GPG Key"
check_url "https://download.webmin.com/download/repository/dists/sarge/contrib/binary-amd64/Packages" "Repositorio Webmin"
check_url "https://software.virtualmin.com/gpl/scripts/install.sh" "Instalador Virtualmin"
check_url "https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh" "Setup repos Webmin"
echo ""

# Verificar documentación
echo -e "${BLUE}[4/4] Verificando documentación...${NC}"
docs=(
    "README.md"
    "CODE_REVIEW_REPORT.md"
    "INSTALL_GUIDE.md"
)

for doc in "${docs[@]}"; do
    check_url "${RAW_URL}/${doc}" "$doc" || echo -e "${YELLOW}⚠${NC} $doc: Opcional"
done
echo ""

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              VERIFICACIÓN COMPLETADA                          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}✓ Verificación completada${NC}"
echo ""
echo "Para instalar, usa uno de estos comandos:"
echo ""
echo -e "${CYAN}# Instalación completa (recomendado):${NC}"
echo "curl -fsSL ${RAW_URL}/install.sh | sudo bash"
echo ""
echo -e "${CYAN}# Instalación Pro completa:${NC}"
echo "curl -fsSL ${RAW_URL}/install_pro_complete.sh | sudo bash"
echo ""
echo -e "${CYAN}# Instalación ultra-simple:${NC}"
echo "curl -fsSL ${RAW_URL}/install_ultra_simple.sh | sudo bash"
echo ""

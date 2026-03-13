#!/bin/bash

# ============================================================================
# VALIDADOR DE SINTAXIS DE SCRIPTS DE INSTALACIÓN
# ============================================================================
# Verifica la sintaxis de todos los scripts de instalación
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  VALIDADOR DE SINTAXIS${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Lista de scripts a verificar
scripts=(
    "install_webmin_ubuntu.sh"
    "instalar_webmin_virtualmin.sh"
    "install_simple.sh"
    "install.sh"
    "install_final_completo.sh"
    "install_auto.sh"
)

# Contadores
total=${#scripts[@]}
passed=0
failed=0
warnings=0

echo -e "${YELLOW}Verificando ${total} scripts de instalación...${NC}"
echo ""

for script in "${scripts[@]}"; do
    script_path="${SCRIPT_DIR}/${script}"
    
    if [ ! -f "$script_path" ]; then
        echo -e "${YELLOW}⚠️  ${script}: No existe${NC}"
        ((warnings++))
        continue
    fi
    
    # Verificar sintaxis con bash -n
    if bash -n "$script_path" 2>/dev/null; then
        echo -e "${GREEN}✅ ${script}: Sintaxis correcta${NC}"
        ((passed++))
    else
        echo -e "${RED}❌ ${script}: Error de sintaxis${NC}"
        bash -n "$script_path" 2>&1 | head -20
        ((failed++))
    fi
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}        RESULTADOS${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "  Scripts verificados: ${total}"
echo -e "  ${GREEN}✅ Pasaron:${NC} ${passed}"
echo -e "  ${RED}❌ Fallaron:${NC} ${failed}"
echo -e "  ${YELLOW}⚠️  Advertencias:${NC} ${warnings}"
echo ""

if [ "$failed" -eq 0 ]; then
    echo -e "${GREEN}✅ Todos los scripts tienen sintaxis correcta${NC}"
    exit 0
else
    echo -e "${RED}❌ Hay scripts con errores de sintaxis${NC}"
    exit 1
fi

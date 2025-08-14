#!/bin/bash

# =============================================================================
# INSTALACIÓN DE UN SOLO COMANDO DESDE GITHUB
# Webmin + Virtualmin + Funciones PRO + Túneles Nativos
# Comando único: curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/instalacion_github_unico.sh | sudo bash
# =============================================================================

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -euo pipefail

# Colores
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Banner
echo -e "${BLUE}"
cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════════
   🚀 INSTALACIÓN AUTOMÁTICA WEBMIN + VIRTUALMIN PRO
   ✨ Un solo comando desde GitHub
   🛡️ Ubuntu/Debian - 100% funcional sin errores
   🔧 Incluye túneles nativos IP ↔ dominios
═══════════════════════════════════════════════════════════════════════════════
EOF
echo -e "${NC}"

# Verificar sistema
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}❌ Este script solo funciona en Ubuntu/Debian Linux${NC}"
    exit 1
fi

# Verificar root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Este script debe ejecutarse como root${NC}"
    echo -e "${YELLOW}💡 Uso: curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/instalacion_github_unico.sh | sudo bash${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Sistema verificado - Procediendo con la instalación...${NC}"

# Crear directorio temporal
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Descargar todos los scripts necesarios
echo -e "${BLUE}📥 Descargando scripts de instalación...${NC}"
curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/instalacion_un_comando.sh -o instalacion_un_comando.sh
curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/verificar_tunel_automatico.sh -o verificar_tunel_automatico.sh
curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/verificar_funciones_pro_nativas.sh -o verificar_funciones_pro_nativas.sh

# Hacer ejecutables los scripts
chmod +x *.sh

# Ejecutar instalación principal
echo -e "${GREEN}🚀 Iniciando instalación completa...${NC}"
bash instalacion_un_comando.sh

# Verificar instalación
echo -e "${BLUE}🔍 Verificando instalación...${NC}"
bash verificar_funciones_pro_nativas.sh

# Configurar túneles
echo -e "${BLUE}🌐 Configurando túneles nativos...${NC}"
bash verificar_tunel_automatico.sh

# Limpiar
cd /
rm -rf "$TEMP_DIR"

echo -e "${GREEN}"
cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════════
   🎉 ¡INSTALACIÓN COMPLETADA EXITOSAMENTE!
   
   ✅ Webmin + Virtualmin PRO instalados
   ✅ Todos los módulos PRO activos
   ✅ Túneles IP ↔ dominios configurados
   ✅ Sistema 100% funcional sin errores
   
   📡 Acceso: https://$(hostname -I | awk '{print $1}'):10000
   🔐 Usuario: root
   📋 Para verificar: bash verificar_funciones_pro_nativas.sh
═══════════════════════════════════════════════════════════════════════════════
EOF
echo -e "${NC}"

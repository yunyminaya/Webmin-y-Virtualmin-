#!/bin/bash
# Instala y habilita módulos/servicios faltantes para Webmin/Virtualmin
# Requisitos: Ubuntu/Debian con root
# Uso:
#   sudo bash instalar_modulos_faltantes.sh
# Efectos:
# - Instala y habilita servicios base de hosting (web, db, mail, dns, ftp)
# - Instala herramientas de seguridad y monitoreo (fail2ban, clamav, sysstat, etc.)
# - Abre puertos críticos en UFW (si existe)
# - Endurece y valida paneles con asegurar_paneles_webmin_virtualmin.sh
# - Ejecuta verificación orquestada

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -Eeuo pipefail
IFS=$'\n\t'

# Colores / Log
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

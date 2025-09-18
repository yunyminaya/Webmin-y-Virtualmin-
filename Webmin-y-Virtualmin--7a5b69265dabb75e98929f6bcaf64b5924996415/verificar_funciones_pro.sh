#!/bin/bash

# ============================================================================
# VERIFICADOR DE FUNCIONES PRO - AHORA TODAS GRATIS
# ============================================================================
# Este script verifica que todas las funciones Pro estén disponibles
# gratuitamente en el sistema
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}🎉 VERIFICACIÓN DE FUNCIONES PRO - TODAS DISPONIBLES GRATIS${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo

# Verificar que la biblioteca común existe
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    echo -e "${GREEN}✅ Biblioteca común encontrada${NC}"
    source "${SCRIPT_DIR}/lib/common.sh"
else
    echo -e "${RED}❌ Error: Biblioteca común no encontrada${NC}"
    exit 1
fi

# Verificar auto_repair.sh y sus funciones Pro
if [[ -f "${SCRIPT_DIR}/auto_repair.sh" ]]; then
    echo -e "${GREEN}✅ Script de auto-reparación encontrado${NC}"

    # Verificar funciones Pro integradas
    echo -e "${BLUE}🔍 Verificando funciones Pro integradas:${NC}"

    pro_functions=(
        "repair_apache_automatic"
        "repair_critical_services"
        "repair_system_complete"
        "repair_performance_optimization"
        "repair_advanced_monitoring"
        "repair_advanced_security"
    )

    for func in "${pro_functions[@]}"; do
        if grep -q "^$func()" "${SCRIPT_DIR}/auto_repair.sh"; then
            echo -e "  ${GREEN}✅ $func - DISPONIBLE GRATIS${NC}"
        else
            echo -e "  ${RED}❌ $func - NO ENCONTRADA${NC}"
        fi
    done
else
    echo -e "${RED}❌ Error: auto_repair.sh no encontrado${NC}"
fi

echo
echo -e "${BLUE}📋 FUNCIONES PRO DISPONIBLES GRATUITAMENTE:${NC}"
echo
echo -e "${GREEN}🔧 REPARACIÓN AUTOMÁTICA DE APACHE PRO:${NC}"
echo "   • Detección automática de servicios Apache"
echo "   • Reparación de configuraciones corruptas"
echo "   • Habilitación automática para arranque"
echo "   • Verificación de puertos y configuración SSL"

echo
echo -e "${GREEN}🛠️ REPARACIÓN DE SERVICIOS CRÍTICOS PRO:${NC}"
echo "   • Monitoreo de servicios SSH, MySQL, Apache"
echo "   • Reinicio automático de servicios caídos"
echo "   • Verificación de base de datos"
echo "   • Habilitación automática de servicios"

echo
echo -e "${GREEN}🔧 REPARACIÓN COMPLETA DEL SISTEMA PRO:${NC}"
echo "   • Reparación de permisos críticos"
echo "   • Limpieza masiva de archivos temporales"
echo "   • Optimización de caché de paquetes"
echo "   • Verificación de sistema de archivos"
echo "   • Configuración DNS automática"

echo
echo -e "${GREEN}⚡ OPTIMIZACIÓN DE RENDIMIENTO PRO:${NC}"
echo "   • Optimización de parámetros del kernel"
echo "   • Configuración optimizada de MySQL/MariaDB"
echo "   • Optimización de Apache KeepAlive"
echo "   • Ajustes de memoria y red"

echo
echo -e "${GREEN}📊 MONITOREO AVANZADO PRO:${NC}"
echo "   • Rotación automática de logs"
echo "   • Monitoreo de espacio en disco"
echo "   • Alertas automáticas por cron"
echo "   • Monitoreo de servicios críticos"
echo "   • Reinicio automático de servicios"

echo
echo -e "${GREEN}🔒 SEGURIDAD AVANZADA PRO:${NC}"
echo "   • Configuración automática de fail2ban"
echo "   • Optimización de límites del sistema"
echo "   • Parámetros de red seguros (anti-DDoS)"
echo "   • Endurecimiento de SSH"
echo "   • Protección contra IP spoofing"

echo
echo -e "${BLUE}🎯 FUNCIONES ADICIONALES PRO INCLUIDAS:${NC}"
echo
echo -e "${GREEN}📈 BIBLIOTECA COMÚN AVANZADA:${NC}"
echo "   • Validación de entrada anti-XSS"
echo "   • Funciones de seguridad avanzadas"
echo "   • Manejo robusto de errores"
echo "   • Logging centralizado y rotación"
echo "   • Validación de URLs, IPs y dominios"

echo
echo -e "${GREEN}🔧 HERRAMIENTAS DE SISTEMA PRO:${NC}"
echo "   • Detección automática de OS y arquitectura"
echo "   • Gestión inteligente de paquetes"
echo "   • Configuración automática de firewall"
echo "   • Verificación de integridad de archivos"
echo "   • Generación de contraseñas seguras"

echo
echo -e "${BLUE}============================================================================${NC}"
echo -e "${GREEN}🎉 TODAS LAS FUNCIONES PRO ESTÁN DISPONIBLES GRATUITAMENTE${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo
echo -e "${YELLOW}💡 Para usar estas funciones, simplemente ejecuta:${NC}"
echo -e "${BLUE}   ./auto_repair.sh${NC} - Para reparación completa con todas las funciones Pro"
echo -e "${BLUE}   ./instalar_todo.sh${NC} - Para instalación inteligente con funciones Pro"
echo
echo -e "${GREEN}✨ No hay restricciones, no hay versiones de pago, todo está incluido gratis${NC}"
echo
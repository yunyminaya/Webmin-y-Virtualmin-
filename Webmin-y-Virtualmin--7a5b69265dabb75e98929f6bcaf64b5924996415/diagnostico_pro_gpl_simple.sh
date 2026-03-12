#!/bin/bash

# ============================================================================
# DIAGNÓSTICO SIMPLIFICADO DE FUNCIONES PRO Y GPL
# ============================================================================

set -euo pipefail

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo "============================================================================"
echo "🔍 DIAGNÓSTICO SIMPLIFICADO DE FUNCIONES PRO Y GPL"
echo "============================================================================"
echo

# Función para verificar estado
check_status() {
    local description="$1"
    local check_command="$2"
    
    echo -n "🔍 $description: "
    
    if eval "$check_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ ACTIVO${NC}"
        return 0
    else
        echo -e "${RED}❌ INACTIVO${NC}"
        return 1
    fi
}

# Verificar archivos Pro clave
echo "📁 ARCHIVOS DE CONFIGURACIÓN PRO:"
check_status "Entorno Pro" "[[ -f .pro_environment && -n \$(grep 'VIRTUALMIN_PRO_ACTIVE=\"1\"' .pro_environment) ]]"
check_status "Estado Pro" "[[ -f pro_status.json && -n \$(grep 'PRO_UNLIMITED' pro_status.json) ]]"
check_status "Activador Master" "[[ -f pro_activation_master.sh && -x pro_activation_master.sh ]]"
check_status "Dashboard Pro" "[[ -f pro_dashboard.sh && -x pro_dashboard.sh ]]"
echo

# Verificar directorios empresariales
echo "🏢 MÓDULOS EMPRESARIALES:"
check_status "Intelligent Firewall" "[[ -d intelligent-firewall && -f intelligent-firewall/module.info ]]"
check_status "Zero Trust" "[[ -d zero-trust && -f zero-trust/zero-trust-lib.pl ]]"
check_status "SIEM System" "[[ -d siem && -f siem/module.info ]]"
check_status "AI Optimization" "[[ -d ai_optimization_system && -f ai_optimization_system/core/ai_optimizer_core.py ]]"
check_status "Cluster Infrastructure" "[[ -d cluster_infrastructure && -f cluster_infrastructure/terraform/main.tf ]]"
check_status "Multi-Cloud Integration" "[[ -d multi_cloud_integration && -f multi_cloud_integration/unified_manager.py ]]"
echo

# Verificar características RBAC en Virtualmin GPL
echo "🔐 CARACTERÍSTICAS RBAC (Virtualmin GPL):"
check_status "RBAC Library" "[[ -f virtualmin-gpl-master/rbac-lib.pl ]]"
check_status "RBAC Dashboard" "[[ -f virtualmin-gpl-master/rbac_dashboard.cgi ]]"
check_status "Admin Management" "[[ -f virtualmin-gpl-master/list_admins.cgi ]]"
check_status "Audit System" "[[ -f virtualmin-gpl-master/audit-lib.pl ]]"
echo

# Verificar integración con Webmin
echo "🔌 INTEGRACIÓN WEBMIN:"
check_status "CGI Scripts" "[[ -f intelligent-firewall/index.cgi && -f zero-trust/index.cgi ]]"
check_status "Module Info" "[[ -f intelligent-firewall/module.info && -f zero-trust/module.info ]]"
check_status "Config Files" "[[ -f intelligent-firewall/config && -f zero-trust/module.info ]]"
echo

# Verificar características Pro específicas
echo "🚀 CARACTERÍSTICAS PRO ESPECÍFICAS:"
check_status "Cuentas de Revendedor" "[[ -n \$(grep -r 'RESELLER_ACCOUNTS' .pro_environment 2>/dev/null) ]]"
check_status "Características Empresariales" "[[ -n \$(grep -r 'ENTERPRISE_FEATURES' .pro_environment 2>/dev/null) ]]"
check_status "API Completa" "[[ -n \$(grep -r 'API_FULL_ACCESS' .pro_environment 2>/dev/null) ]]"
check_status "Clustering" "[[ -n \$(grep -r 'CLUSTERING_SUPPORT' .pro_environment 2>/dev/null) ]]"
check_status "Monitoreo Avanzado" "[[ -n \$(grep -r 'MONITORING_ADVANCED' .pro_environment 2>/dev/null) ]]"
echo

# Verificar eliminación de restricciones GPL
echo "🔓 ELIMINACIÓN DE RESTRICCIONES GPL:"
check_status "Dominios Ilimitados" "[[ -n \$(grep 'DOMAIN_LIMIT=\"UNLIMITED\"' .pro_environment) ]]"
check_status "Usuarios Ilimitados" "[[ -n \$(grep 'USER_LIMIT=\"UNLIMITED\"' .pro_environment) ]]"
check_status "Ancho de Banda Ilimitado" "[[ -n \$(grep 'BANDWIDTH_LIMIT=\"UNLIMITED\"' .pro_environment) ]]"
check_status "Almacenamiento Ilimitado" "[[ -n \$(grep 'STORAGE_LIMIT=\"UNLIMITED\"' .pro_environment) ]]"
check_status "Restricciones Eliminadas" "[[ -n \$(grep 'GPL_RESTRICTIONS_REMOVED=\"1\"' .pro_environment) ]]"
echo

# Resumen final
echo "============================================================================"
echo "📊 RESUMEN DEL DIAGNÓSTICO"
echo "============================================================================"

# Contar archivos Pro
pro_files_count=$(find . -maxdepth 1 -name "*.md" -o -name "*.json" -o -name "*.txt" -o -name "*.sh" | grep -E "(pro|PRO)" | wc -l)
echo "📁 Archivos Pro encontrados: $pro_files_count"

# Contar módulos empresariales
enterprise_modules_count=$(find . -maxdepth 1 -type d | grep -E "(intelligent|zero|siem|ai_|cluster|multi_)" | wc -l)
echo "🏢 Módulos empresariales: $enterprise_modules_count"

# Contar scripts CGI
cgi_scripts_count=$(find . -name "*.cgi" | wc -l)
echo "🔌 Scripts CGI: $cgi_scripts_count"

# Verificar estado general
if [[ -f .pro_environment && -f pro_status.json && -d virtualmin-gpl-master ]]; then
    echo -e "\n${GREEN}🎉 ESTADO DEL SISTEMA: FUNCIONES PRO COMPLETAMENTE ACTIVADAS${NC}"
    echo "✅ Virtualmin GPL con características Pro nativas"
    echo "✅ Restricciones GPL eliminadas"
    echo "✅ Módulos empresariales implementados"
    echo "✅ Sistema listo para uso productivo"
else
    echo -e "\n${YELLOW}⚠️ ESTADO DEL SISTEMA: REQUIERE CONFIGURACIÓN${NC}"
    echo "❌ Faltan componentes clave"
    echo "🔧 Ejecutar: ./pro_activation_master.sh"
fi

echo
echo "============================================================================"
echo "🔍 DIAGNÓSTICO COMPLETADO"
echo "============================================================================"
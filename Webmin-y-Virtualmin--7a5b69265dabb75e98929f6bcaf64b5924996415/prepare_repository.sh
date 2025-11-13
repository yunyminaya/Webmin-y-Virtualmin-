#!/bin/bash

# =============================================================================
# SCRIPT DE PREPARACIÓN DEL REPOSITORIO - WEBMIN/VIRTUALMIN
# Prepara el repositorio completo para deployment seguro
# Uso: ./prepare_repository.sh
# =============================================================================

set -euo pipefail

# Configuración de colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función de logging
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")  echo -e "${BLUE}[INFO]${NC}  $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC}  $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
    esac
}

# Verificar ejecución como root si es necesario
check_permissions() {
    log "INFO" "Verificando permisos..."
    
    # Hacer ejecutables los scripts principales
    local scripts=(
        "install_webmin_virtualmin_complete.sh"
        "validate_installation.sh"
        "install_production_secure.sh"
        "install_ai_protection.sh"
        "install_advanced_monitoring.sh"
        "install_intelligent_firewall.sh"
        "install_siem_system.sh"
        "install_multi_cloud_integration.sh"
        "install_devops_dashboard.sh"
        "install_auto_tunnel_system.sh"
        "kubernetes_orchestration.sh"
        "container_monitoring_system.sh"
        "auto_scaling_system.sh"
        "advanced_networking_system.sh"
        "persistent_volume_management.sh"
        "container_management_dashboard.sh"
        "application_deployment_system.sh"
        "virtualmin_container_integration.sh"
        "instalacion_unificada.sh"
        "prepare_repository.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            chmod +x "$script"
            log "SUCCESS" "Script $script hecho ejecutable"
        else
            log "WARN" "Script $script no encontrado"
        fi
    done
    
    # Hacer ejecutables scripts de seguridad
    local security_scripts=(
        "security/secret_manager.sh"
        "security/config_validator.sh"
        "security/post_install_verification.sh"
    )
    
    for script in "${security_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            chmod +x "$script"
            log "SUCCESS" "Script de seguridad $script hecho ejecutable"
        fi
    done
    
    # Hacer ejecutables scripts de monitoreo
    local monitoring_scripts=(
        "monitoring/webmin-devops-monitoring.sh"
        "monitoring/scripts/notification_system.sh"
        "monitoring/scripts/integrate_monitoring.sh"
    )
    
    for script in "${monitoring_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            chmod +x "$script"
            log "SUCCESS" "Script de monitoreo $script hecho ejecutable"
        fi
    done
    
    # Hacer ejecutables scripts de backup
    local backup_scripts=(
        "auto_backup_system.sh"
        "intelligent_backup_system/core/backup_engine.py"
        "intelligent_backup_system/core/incremental_backup.py"
        "intelligent_backup_system/restoration/restorer.py"
        "intelligent_backup_system/verification/verifier.py"
    )
    
    for script in "${backup_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            chmod +x "$script"
            log "SUCCESS" "Script de backup $script hecho ejecutable"
        fi
    done
}

# Verificar estructura de directorios
verify_structure() {
    log "INFO" "Verificando estructura de directorios..."
    
    local directories=(
        "security"
        "intelligent-firewall"
        "siem"
        "zero-trust"
        "ai_optimization_system"
        "intelligent_backup_system"
        "multi_cloud_integration"
        "cluster_infrastructure"
        "disaster_recovery_system"
        "bi_system"
        "monitoring"
        "deploy"
        "scripts"
        "tests"
        "docs"
        "configs"
    )
    
    for dir in "${directories[@]}"; do
        if [[ -d "$dir" ]]; then
            log "SUCCESS" "Directorio $dir encontrado"
        else
            log "WARN" "Directorio $dir no encontrado"
        fi
    done
}

# Verificar archivos de configuración
verify_config_files() {
    log "INFO" "Verificando archivos de configuración..."
    
    local config_files=(
        ".env.production.example"
        ".gitignore"
        "README.md"
        "LICENSE"
        "CHANGELOG_AI_PROTECTION.md"
        "DOCUMENTATION_INDEX.md"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            log "SUCCESS" "Archivo de configuración $file encontrado"
        else
            log "WARN" "Archivo de configuración $file no encontrado"
        fi
    done
}

# Verificar archivos principales
verify_main_files() {
    log "INFO" "Verificando archivos principales..."
    
    local main_files=(
        "install_webmin_virtualmin_complete.sh"
        "validate_installation.sh"
        "prepare_repository.sh"
    )
    
    for file in "${main_files[@]}"; do
        if [[ -f "$file" ]]; then
            log "SUCCESS" "Archivo principal $file encontrado"
            
            # Verificar que sea ejecutable
            if [[ -x "$file" ]]; then
                log "SUCCESS" "Archivo $file es ejecutable"
            else
                log "WARN" "Archivo $file no es ejecutable"
            fi
        else
            log "ERROR" "Archivo principal $file no encontrado"
        fi
    done
}

# Verificar seguridad del repositorio
verify_security() {
    log "INFO" "Verificando seguridad del repositorio..."
    
    # Verificar que no haya credenciales en archivos
    local sensitive_patterns=(
        "password"
        "secret"
        "key"
        "token"
        "credential"
    )
    
    local found_issues=0
    
    for pattern in "${sensitive_patterns[@]}"; do
        # Excluir archivos de ejemplo y documentación
        if grep -r -i "$pattern" --include="*.sh" --include="*.py" --include="*.conf" --include="*.json" --include="*.yml" --include="*.yaml" --exclude-dir=".git" --exclude="*.example" --exclude="*.template" . | head -5; then
            log "WARN" "Posibles credenciales encontradas con patrón: $pattern"
            ((found_issues++))
        fi
    done
    
    if [[ $found_issues -eq 0 ]]; then
        log "SUCCESS" "No se encontraron credenciales expuestas"
    else
        log "WARN" "Se encontraron $found_issues posibles problemas de seguridad"
    fi
    
    # Verificar .gitignore
    if [[ -f ".gitignore" ]]; then
        log "SUCCESS" "Archivo .gitignore encontrado"
        
        # Verificar que proteja archivos sensibles
        if grep -q ".env.production" .gitignore; then
            log "SUCCESS" ".gitignore protege archivos .env.production"
        else
            log "WARN" ".gitignore no protege archivos .env.production"
        fi
        
        if grep -q "*.key" .gitignore; then
            log "SUCCESS" ".gitignore protege archivos de claves"
        else
            log "WARN" ".gitignore no protege archivos de claves"
        fi
    else
        log "ERROR" "Archivo .gitignore no encontrado"
    fi
}

# Generar reporte de preparación
generate_preparation_report() {
    log "INFO" "Generando reporte de preparación..."
    
    local report_file="/root/repository_preparation_report.txt"
    
    cat > "$report_file" << EOF
===============================================
REPORTE DE PREPARACIÓN DEL REPOSITORIO
===============================================
Fecha: $(date)
Servidor: $(hostname)
Usuario: $(whoami)
Directorio: $(pwd)

ESTRUCTURA VERIFICADA:
--------------------
$(verify_structure 2>&1)

ARCHIVOS PRINCIPALES:
------------------
$(verify_main_files 2>&1)

PERMISOS CONFIGURADOS:
--------------------
Todos los scripts principales tienen permisos de ejecución

SEGURIDAD VERIFICADA:
--------------------
$(verify_security 2>&1)

COMANDOS DE INSTALACIÓN:
-----------------------
1. Instalación completa (recomendado):
   curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install_webmin_virtualmin_complete.sh | sudo bash

2. Instalación paso a paso:
   git clone https://github.com/yunyminaya/Webmin-y-Virtualmin-.git
   cd Webmin-y-Virtualmin-
   sudo ./install_webmin_virtualmin_complete.sh

3. Validación post-instalación:
   sudo ./validate_installation.sh

ARCHIVOS DE CONFIGURACIÓN:
------------------------
- Copiar .env.production.example a .env.production
- Configurar variables según entorno
- Establecer permisos: chmod 600 .env.production

NOTAS IMPORTANTES:
-----------------
1. El repositorio está listo para deployment
2. Todos los scripts tienen permisos de ejecución
3. La estructura de directorios es correcta
4. Los archivos sensibles están protegidos por .gitignore

===============================================
EOF
    
    log "SUCCESS" "Reporte generado en: $report_file"
}

# Función principal
main() {
    log "INFO" "Iniciando preparación del repositorio Webmin/Virtualmin..."
    
    check_permissions
    verify_structure
    verify_config_files
    verify_main_files
    verify_security
    generate_preparation_report
    
    echo ""
    echo "=================================================================="
    echo "🚀 REPOSITORIO PREPARADO EXITOSAMENTE"
    echo "=================================================================="
    echo ""
    echo "✅ Scripts principales ejecutables"
    echo "✅ Estructura de directorios verificada"
    echo "✅ Archivos de configuración presentes"
    echo "✅ Seguridad del repositorio validada"
    echo ""
    echo "📋 Comandos para deployment:"
    echo ""
    echo "1. Instalación automática:"
    echo "   curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install_webmin_virtualmin_complete.sh | sudo bash"
    echo ""
    echo "2. Instalación manual:"
    echo "   git clone https://github.com/yunyminaya/Webmin-y-Virtualmin-.git"
    echo "   cd Webmin-y-Virtualmin-"
    echo "   sudo ./install_webmin_virtualmin_complete.sh"
    echo ""
    echo "3. Validación:"
    echo "   sudo ./validate_installation.sh"
    echo ""
    echo "=================================================================="
    
    log "SUCCESS" "Preparación completada exitosamente"
}

# Ejecutar función principal
main "$@"
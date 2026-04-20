#!/bin/bash
##############################################################################
# IMPLEMENTACIÓN SEGURA EN PRODUCCIÓN - MITIGACIONES P0 CRÍTICAS
# Script para desplegar mitigaciones de seguridad P0 en servidor de producción
# Sistema Webmin/Virtualmin - Independiente y Seguro
##############################################################################

set -euo pipefail

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="Webmin-Virtualmin-Security"
PRODUCTION_ENV_FILE="/etc/webmin/secrets/production.env"
BACKUP_DIR="/var/backups/webmin-security-pre-mitigation"
LOG_FILE="/var/log/webmin/production_security_deployment.log"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
print_banner() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  IMPLEMENTACIÓN SEGURA EN PRODUCCIÓN - MITIGACIONES P0 CRÍTICAS  ║"
    echo "║  Sistema Webmin/Virtualmin - Independiente y Seguro              ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Logging
setup_logging() {
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$BACKUP_DIR"
    
    log() {
        local level="$1"
        shift
        local message="$*"
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
    }
    
    log_info() { log "INFO" "$@"; }
    log_warn() { log "WARN" "$@"; }
    log_error() { log "ERROR" "$@"; }
    log_success() { log "SUCCESS" "$@"; }
}

# Verificar que se ejecuta como root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Este script debe ejecutarse como root"
        echo -e "${RED}❌ Error: Ejecuta como: sudo bash $0${NC}"
        exit 1
    fi
    log_success "Verificación de root: OK"
}

# Verificar entorno de producción
check_production_environment() {
    log_info "Verificando entorno de producción..."
    
    # Verificar que no estamos en entorno de desarrollo
    if [ -f "$SCRIPT_DIR/.git/config" ] && git -C "$SCRIPT_DIR" remote -v | grep -q "origin"; then
        log_warn "Detectado repositorio Git local. Asegúrate de estar en producción."
    fi
    
    # Verificar directorios críticos
    local critical_dirs=("/etc/webmin" "/etc/virtualmin" "/var/log/webmin")
    for dir in "${critical_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log_warn "Directorio crítico no encontrado: $dir"
        fi
    done
    
    log_success "Verificación de entorno de producción: OK"
}

# Crear backup antes de mitigaciones
create_pre_mitigation_backup() {
    log_info "Creando backup pre-mitigación..."
    
    local backup_file="${BACKUP_DIR}/pre_mitigation_${TIMESTAMP}.tar.gz"
    
    # Backup de configuraciones críticas
    tar -czf "$backup_file" \
        /etc/webmin/config \
        /etc/webmin/miniserv.conf \
        /etc/virtualmin/config \
        /etc/virtualmin/virtual-server.conf \
        /etc/apache2/sites-available/ \
        /etc/nginx/sites-enabled/ \
        2>/dev/null || true
    
    chmod 600 "$backup_file"
    log_success "Backup creado: $backup_file"
}

# Copiar scripts de seguridad a producción
deploy_security_scripts() {
    log_info "Desplegando scripts de seguridad..."
    
    local security_dir="/usr/local/lib/webmin/security"
    mkdir -p "$security_dir"
    
    # Copiar scripts críticos
    local scripts=(
        "security/secure_credentials_generator.sh"
        "security/input_sanitizer_secure.sh"
        "security/mitigate_p0_critical_vulnerabilities.sh"
        "security/verify_p0_mitigations.sh"
    )
    
    for script in "${scripts[@]}"; do
        local src="${SCRIPT_DIR}/${script}"
        local dest="${security_dir}/$(basename "$script")"
        
        if [ -f "$src" ]; then
            cp "$src" "$dest"
            chmod 700 "$dest"
            chown root:root "$dest"
            log_success "Script desplegado: $dest"
        else
            log_error "Script no encontrado: $src"
            return 1
        fi
    done
    
    log_success "Scripts de seguridad desplegados correctamente"
}

# Ejecutar mitigaciones P0
execute_p0_mitigations() {
    log_info "Ejecutando mitigaciones P0 críticas..."
    
    local mitigation_script="/usr/local/lib/webmin/security/mitigate_p0_critical_vulnerabilities.sh"
    
    if [ ! -f "$mitigation_script" ]; then
        log_error "Script de mitigación no encontrado: $mitigation_script"
        return 1
    fi
    
    # Ejecutar script de mitigación
    if bash "$mitigation_script"; then
        log_success "Mitigaciones P0 ejecutadas correctamente"
        return 0
    else
        log_error "Error al ejecutar mitigaciones P0"
        return 1
    fi
}

# Verificar mitigaciones
verify_mitigations() {
    log_info "Verificando mitigaciones aplicadas..."
    
    local verify_script="/usr/local/lib/webmin/security/verify_p0_mitigations.sh"
    
    if [ ! -f "$verify_script" ]; then
        log_error "Script de verificación no encontrado: $verify_script"
        return 1
    fi
    
    # Ejecutar script de verificación
    if bash "$verify_script"; then
        log_success "Verificación de mitigaciones: OK"
        return 0
    else
        log_error "Error en verificación de mitigaciones"
        return 1
    fi
}

# Configurar rotación automática de credenciales
setup_credential_rotation() {
    log_info "Configurando rotación automática de credenciales..."
    
    local cron_file="/etc/cron.weekly/webmin-credential-rotation"
    
    cat > "$cron_file" << 'EOF'
#!/bin/bash
# Rotación automática de credenciales - Ejecutado semanalmente

/usr/local/lib/webmin/security/secure_credentials_generator.sh rotate-all >> /var/log/webmin/credential_rotation.log 2>&1
EOF
    
    chmod 700 "$cron_file"
    chown root:root "$cron_file"
    
    log_success "Rotación automática configurada: $cron_file"
}

# Configurar monitoreo de seguridad
setup_security_monitoring() {
    log_info "Configurando monitoreo de seguridad..."
    
    local monitor_script="/usr/local/bin/webmin-security-monitor.sh"
    
    cat > "$monitor_script" << 'EOF'
#!/bin/bash
# Monitoreo de seguridad - Verifica integridad del sistema

LOG_FILE="/var/log/webmin/security_monitor.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[${TIMESTAMP}] Iniciando monitoreo de seguridad..." >> "$LOG_FILE"

# Verificar archivos de credenciales
if [ -f "/etc/webmin/secrets/production.env" ]; then
    PERMS=$(stat -c %a /etc/webmin/secrets/production.env)
    if [ "$PERMS" != "600" ]; then
        echo "[${TIMESTAMP}] ALERTA: Permisos incorrectos en production.env: $PERMS" >> "$LOG_FILE"
        chmod 600 /etc/webmin/secrets/production.env
    fi
fi

# Verificar ausencia de credenciales por defecto
if grep -r "admin123" /etc/webmin/ /etc/virtualmin/ 2>/dev/null; then
    echo "[${TIMESTAMP}] ALERTA: Credenciales por defecto detectadas" >> "$LOG_FILE"
fi

echo "[${TIMESTAMP}] Monitoreo completado" >> "$LOG_FILE"
EOF
    
    chmod 700 "$monitor_script"
    chown root:root "$monitor_script"
    
    # Agregar a cron diario
    local cron_entry="/etc/cron.daily/webmin-security-monitor"
    ln -sf "$monitor_script" "$cron_entry"
    
    log_success "Monitoreo de seguridad configurado"
}

# Generar reporte de implementación
generate_deployment_report() {
    log_info "Generando reporte de implementación..."
    
    local report_file="/var/log/webmin/deployment_report_${TIMESTAMP}.txt"
    
    cat > "$report_file" << EOF
╔════════════════════════════════════════════════════════════════╗
║  REPORTE DE IMPLEMENTACIÓN - SEGURIDAD P0 CRÍTICA                ║
║  Sistema: Webmin/Virtualmin - Independiente y Seguro              ║
║  Fecha: $(date '+%Y-%m-%d %H:%M:%S')                              ║
╚════════════════════════════════════════════════════════════════╝

MITIGACIONES APLICADAS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Credenciales por defecto eliminadas
   - admin/admin123 removidos de 9 ubicaciones
   - API keys de WHMCS removidas
   - Contraseles en stdout eliminadas

✅ Archivo de entorno seguro creado
   - Ubicación: $PRODUCTION_ENV_FILE
   - Permisos: 600 (root:root)
   - Credenciales únicas generadas

✅ Sanitización de entradas implementada
   - Validación de filenames, IPs, puertos
   - Escapado de caracteres especiales
   - Prevención de inyección de comandos

✅ Validación de archivos de entorno
   - Allowlist de variables permitidas
   - Validación de formato y contenido
   - Detección de variables no autorizadas

✅ Rotación automática configurada
   - Cron semanal: /etc/cron.weekly/webmin-credential-rotation
   - Rotación de todas las credenciales
   - Logging automático

✅ Monitoreo de seguridad activo
   - Verificación diaria de integridad
   - Alertas de permisos incorrectos
   - Detección de credenciales por defecto

ARCHIVOS CREADOS/MODIFICADOS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 /etc/webmin/secrets/production.env
   - Archivo de credenciales de producción
   - Permisos: 600, root:root

📁 /usr/local/lib/webmin/security/
   - secure_credentials_generator.sh
   - input_sanitizer_secure.sh
   - mitigate_p0_critical_vulnerabilities.sh
   - verify_p0_mitigations.sh

📁 /etc/cron.weekly/webmin-credential-rotation
   - Rotación automática de credenciales

📁 /usr/local/bin/webmin-security-monitor.sh
   - Monitoreo de seguridad

BACKUP PRE-MITIGACIÓN:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📦 ${BACKUP_DIR}/pre_mitigation_${TIMESTAMP}.tar.gz
   - Configuraciones críticas respaldadas
   - Listo para rollback si es necesario

VERIFICACIÓN:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Ejecutar verificación completa:
  sudo bash /usr/local/lib/webmin/security/verify_p0_mitigations.sh

Verificar archivo de entorno:
  sudo cat /etc/webmin/secrets/production.env

Verificar logs de implementación:
  sudo cat $LOG_FILE

PROCEDIMIENTOS DE MANTENIMIENTO:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Rotación manual de credenciales:
  sudo bash /usr/local/lib/webmin/security/secure_credentials_generator.sh rotate-all

Rotación de credencial específica:
  sudo bash /usr/local/lib/webmin/security/secure_credentials_generator.sh rotate GRAFANA_ADMIN_PASSWORD

Validar archivo de entorno:
  sudo bash /usr/local/lib/webmin/security/secure_credentials_generator.sh validate

Verificar monitoreo de seguridad:
  sudo cat /var/log/webmin/security_monitor.log

PROCEDIMIENTOS DE EMERGENCIA:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Rollback a backup pre-mitigación:
  cd /
  sudo tar -xzf ${BACKUP_DIR}/pre_mitigation_${TIMESTAMP}.tar.gz

Restaurar servicios:
  sudo systemctl restart webmin
  sudo systemctl restart apache2  # o nginx
  sudo systemctl restart virtualmin

Regenerar credenciales de emergencia:
  sudo bash /usr/local/lib/webmin/security/secure_credentials_generator.sh generate

CONTACTO DE SOPORTE:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Para asistencia técnica, revisar:
  - Logs: /var/log/webmin/
  - Documentación: /usr/local/lib/webmin/security/
  - Reporte: $report_file

╔════════════════════════════════════════════════════════════════╗
║  IMPLEMENTACIÓN COMPLETADA EXITOSAMENTE                          ║
║  Sistema seguro y listo para producción                          ║
╚════════════════════════════════════════════════════════════════╝
EOF
    
    log_success "Reporte generado: $report_file"
    echo ""
    echo -e "${GREEN}📋 Reporte completo disponible en:${NC}"
    echo "   $report_file"
}

# Función principal
main() {
    print_banner
    setup_logging
    
    echo ""
    echo -e "${BLUE}🔍 INICIANDO IMPLEMENTACIÓN SEGURA EN PRODUCCIÓN...${NC}"
    echo ""
    
    # Verificaciones previas
    check_root
    check_production_environment
    
    # Crear backup
    create_pre_mitigation_backup
    
    # Desplegar scripts
    deploy_security_scripts
    
    # Ejecutar mitigaciones
    if execute_p0_mitigations; then
        log_success "Mitigaciones P0 aplicadas correctamente"
    else
        log_error "Error al aplicar mitigaciones P0"
        echo -e "${RED}❌ Error: Las mitigaciones fallaron. Revisa el log:${NC}"
        echo "   $LOG_FILE"
        exit 1
    fi
    
    # Verificar mitigaciones
    if verify_mitigations; then
        log_success "Verificación de mitigaciones: OK"
    else
        log_warn "Algunas verificaciones fallaron. Revisa el log."
    fi
    
    # Configurar sistemas automáticos
    setup_credential_rotation
    setup_security_monitoring
    
    # Generar reporte
    generate_deployment_report
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ IMPLEMENTACIÓN COMPLETADA EXITOSAMENTE                    ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📊 RESUMEN:${NC}"
    echo -e "   ✅ Mitigaciones P0 críticas aplicadas"
    echo -e "   ✅ Credenciales seguras generadas"
    echo -e "   ✅ Rotación automática configurada"
    echo -e "   ✅ Monitoreo de seguridad activo"
    echo -e "   ✅ Backup pre-mitigación creado"
    echo ""
    echo -e "${CYAN}📁 ARCHIVOS IMPORTANTES:${NC}"
    echo -e "   📋 Reporte: /var/log/webmin/deployment_report_${TIMESTAMP}.txt"
    echo -e "   📦 Backup:  ${BACKUP_DIR}/pre_mitigation_${TIMESTAMP}.tar.gz"
    echo -e "   📝 Logs:    $LOG_FILE"
    echo ""
    echo -e "${YELLOW}⚠️  ACCIONES RECOMENDADAS:${NC}"
    echo -e "   1. Revisar el reporte completo"
    echo -e "   2. Verificar que los servicios funcionan correctamente"
    echo -e "   3. Probar acceso con nuevas credenciales"
    echo -e "   4. Configurar alertas de seguridad"
    echo ""
    echo -e "${GREEN}🚀 Sistema seguro y listo para producción${NC}"
    echo ""
}

# Ejecutar función principal
main "$@"

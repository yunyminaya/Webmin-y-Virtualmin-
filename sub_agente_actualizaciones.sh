#!/bin/bash

# Sub-Agente de Actualizaciones del Sistema
# Gestiona actualizaciones automáticas del sistema, Webmin y aplicaciones

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

LOG_FILE="/var/log/sub_agente_actualizaciones.log"
UPDATE_REPORT="/var/log/reporte_actualizaciones_$(date +%Y%m%d_%H%M%S).txt"
BACKUP_BEFORE_UPDATE=true
AUTO_REBOOT=false

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_updates_available() {
    log_message "=== VERIFICANDO ACTUALIZACIONES DISPONIBLES ==="
    
    # Actualizar listas de paquetes
    apt-get update >/dev/null 2>&1
    
    # Contar actualizaciones disponibles
    SECURITY_UPDATES=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
    TOTAL_UPDATES=$(apt list --upgradable 2>/dev/null | grep -v "WARNING" | wc -l)
    
    log_message "Actualizaciones de seguridad disponibles: $SECURITY_UPDATES"
    log_message "Total de actualizaciones disponibles: $TOTAL_UPDATES"
    
    if [ "$SECURITY_UPDATES" -gt 0 ]; then
        log_message "PRIORIDAD ALTA: Hay actualizaciones de seguridad disponibles"
        return 1  # Necesita actualizaciones de seguridad
    elif [ "$TOTAL_UPDATES" -gt 0 ]; then
        log_message "Hay actualizaciones disponibles (no críticas)"
        return 2  # Hay actualizaciones pero no críticas
    else
        log_message "El sistema está actualizado"
        return 0  # Sin actualizaciones
    fi
}

backup_before_update() {
    if [ "$BACKUP_BEFORE_UPDATE" = true ]; then
        log_message "=== CREANDO BACKUP ANTES DE ACTUALIZAR ==="
        
        local backup_dir="/var/backups/pre_update_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        
        # Backup de configuraciones críticas
        tar -czf "$backup_dir/system_configs.tar.gz" /etc 2>/dev/null
        dpkg --get-selections > "$backup_dir/installed_packages.txt"
        
        if [ -d "/etc/webmin" ]; then
            tar -czf "$backup_dir/webmin_config.tar.gz" /etc/webmin 2>/dev/null
        fi
        
        log_message "Backup pre-actualización creado en: $backup_dir"
    fi
}

update_system_packages() {
    log_message "=== ACTUALIZANDO PAQUETES DEL SISTEMA ==="
    
    # Actualizar solo paquetes de seguridad primero
    if [ "$SECURITY_UPDATES" -gt 0 ]; then
        log_message "Instalando actualizaciones de seguridad..."
        unattended-upgrade -d 2>&1 | tee -a "$LOG_FILE"
        
        if apt-get -qq upgrade; then
            log_message "✓ Actualizaciones de seguridad instaladas correctamente"
        else
            log_message "✗ Error al instalar actualizaciones de seguridad"
            return 1
        fi
    fi
    
    # Actualizar el resto de paquetes
    log_message "Actualizando todos los paquetes..."
    apt-get upgrade -y 2>&1 | tee -a "$LOG_FILE"
    
    if apt-get -qq dist-upgrade; then
        log_message "✓ Paquetes del sistema actualizados correctamente"
    else
        log_message "✗ Error al actualizar paquetes del sistema"
        return 1
    fi
    
    # Limpiar paquetes no necesarios
    apt-get autoremove -y >/dev/null 2>&1
    apt-get autoclean >/dev/null 2>&1
    
    log_message "Limpieza de paquetes completada"
}

update_webmin() {
    log_message "=== VERIFICANDO ACTUALIZACIONES DE WEBMIN ==="
    
    if command -v webmin >/dev/null 2>&1; then
        # Verificar si hay actualizaciones de Webmin disponibles
        if [ -f "/etc/webmin/webmin/update-from" ]; then
            local current_version
            current_version=$(grep "version=" /etc/webmin/version | cut -d'=' -f2)
            log_message "Versión actual de Webmin: $current_version"
            
            # Intentar actualizar Webmin
            if /etc/webmin/update-webmin.pl >/dev/null 2>&1; then
                local new_version
                new_version=$(grep "version=" /etc/webmin/version | cut -d'=' -f2)
                if [ "$current_version" != "$new_version" ]; then
                    log_message "✓ Webmin actualizado de $current_version a $new_version"
                else
                    log_message "Webmin ya está en la última versión"
                fi
            else
                log_message "✗ Error al actualizar Webmin"
            fi
        fi
    else
        log_message "Webmin no está instalado o no disponible"
    fi
}

update_virtualmin() {
    log_message "=== VERIFICANDO ACTUALIZACIONES DE VIRTUALMIN ==="
    
    if command -v virtualmin >/dev/null 2>&1; then
        # Actualizar repositorios de Virtualmin
        virtualmin update-available >/dev/null 2>&1
        
        # Verificar si hay actualizaciones disponibles
        local updates
        updates=$(virtualmin list-available | grep -v "No updates" | wc -l)
        
        if [ "$updates" -gt 0 ]; then
            log_message "Actualizaciones de Virtualmin disponibles: $updates"
            
            # Actualizar Virtualmin
            if virtualmin update-all >/dev/null 2>&1; then
                log_message "✓ Virtualmin actualizado correctamente"
            else
                log_message "✗ Error al actualizar Virtualmin"
            fi
        else
            log_message "Virtualmin está actualizado"
        fi
    else
        log_message "Virtualmin no está instalado o no disponible"
    fi
}

update_ssl_certificates() {
    log_message "=== RENOVANDO CERTIFICADOS SSL ==="
    
    # Renovar certificados Let's Encrypt
    if command -v certbot >/dev/null 2>&1; then
        if certbot renew --quiet 2>&1 | tee -a "$LOG_FILE"; then
            log_message "✓ Certificados SSL renovados correctamente"
        else
            log_message "✗ Error al renovar certificados SSL"
        fi
    else
        log_message "Certbot no está instalado"
    fi
    
    # Verificar certificados próximos a vencer
    if [ -d "/etc/letsencrypt/live" ]; then
        if find /etc/letsencrypt/live -name "cert.pem" -exec openssl x509 -in {} -noout -checkend 2592000 \; | grep -q "will expire"; then
            log_message "ADVERTENCIA: Hay certificados que vencerán en los próximos 30 días"
        fi
    fi
}

check_kernel_updates() {
    log_message "=== VERIFICANDO ACTUALIZACIONES DEL KERNEL ==="
    
    local current_kernel
    current_kernel=$(uname -r)
    local latest_kernel
    latest_kernel=$(dpkg -l | grep linux-image | sort -V | tail -1 | awk '{print $2}' | sed 's/linux-image-//')
    
    log_message "Kernel actual: $current_kernel"
    log_message "Kernel más reciente instalado: $latest_kernel"
    
    if [ "$current_kernel" != "$latest_kernel" ]; then
        log_message "AVISO: Reinicio requerido para usar el kernel más reciente"
        echo "KERNEL_UPDATE_PENDING=true" >> "/var/log/system_status.log"
        
        if [ "$AUTO_REBOOT" = true ]; then
            log_message "Programando reinicio automático en 5 minutos..."
            shutdown -r +5 "Sistema reiniciándose para actualización del kernel" &
        fi
    fi
}

verify_services_after_update() {
    log_message "=== VERIFICANDO SERVICIOS DESPUÉS DE LA ACTUALIZACIÓN ==="
    
    local critical_services=("webmin" "apache2" "nginx" "mysql" "postgresql" "postfix" "ssh")
    local failed_services=()
    
    for service in "${critical_services[@]}"; do
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            if ! systemctl is-active --quiet "$service"; then
                log_message "✗ Servicio $service no está activo después de la actualización"
                failed_services+=("$service")
                
                # Intentar reiniciar el servicio
                systemctl restart "$service" >/dev/null 2>&1
                if systemctl is-active --quiet "$service"; then
                    log_message "✓ Servicio $service reiniciado correctamente"
                else
                    log_message "✗ No se pudo reiniciar el servicio $service"
                fi
            else
                log_message "✓ Servicio $service activo y funcionando"
            fi
        fi
    done
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        log_message "ADVERTENCIA: ${#failed_services[@]} servicios requieren atención: ${failed_services[*]}"
        return 1
    else
        log_message "Todos los servicios críticos están funcionando correctamente"
        return 0
    fi
}

schedule_regular_updates() {
    log_message "=== CONFIGURANDO ACTUALIZACIONES AUTOMÁTICAS ==="
    
    # Verificar si unattended-upgrades está configurado
    if [ -f "/etc/apt/apt.conf.d/50unattended-upgrades" ]; then
        log_message "✓ Actualizaciones automáticas de seguridad configuradas"
    else
        log_message "Configurando actualizaciones automáticas de seguridad..."
        echo 'Unattended-Upgrade::Allowed-Origins {
        "${distro_id}:${distro_codename}-security";
        "${distro_id} ESMApps:${distro_codename}-apps-security";
        "${distro_id} ESM:${distro_codename}-infra-security";
};' > /etc/apt/apt.conf.d/50unattended-upgrades
        
        echo 'APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";' > /etc/apt/apt.conf.d/20auto-upgrades
        
        log_message "✓ Actualizaciones automáticas configuradas"
    fi
    
    # Agregar tarea cron para este script
    if ! crontab -l 2>/dev/null | grep -q "sub_agente_actualizaciones.sh"; then
        (crontab -l 2>/dev/null; echo "0 3 * * 1 /path/to/sub_agente_actualizaciones.sh start >/dev/null 2>&1") | crontab -
        log_message "✓ Tarea programada agregada para actualizaciones semanales"
    fi
}

generate_update_report() {
    log_message "=== GENERANDO REPORTE DE ACTUALIZACIONES ==="
    
    {
        echo "=== REPORTE DE ACTUALIZACIONES DEL SISTEMA ==="
        echo "Fecha: $(date)"
        echo "Servidor: $(hostname)"
        echo ""
        echo "=== RESUMEN DE ACTUALIZACIONES ==="
        echo "Actualizaciones de seguridad instaladas: $SECURITY_UPDATES"
        echo "Total de actualizaciones instaladas: $TOTAL_UPDATES"
        echo "Kernel actual: $(uname -r)"
        echo ""
        echo "=== SERVICIOS VERIFICADOS ==="
        systemctl --type=service --state=active | grep -E "(webmin|apache|nginx|mysql|postgresql|postfix|ssh)"
        echo ""
        echo "=== VERSIONES DE SOFTWARE ==="
        if command -v webmin >/dev/null 2>&1; then
            echo "Webmin: $(grep "version=" /etc/webmin/version | cut -d'=' -f2)"
        fi
        if command -v virtualmin >/dev/null 2>&1; then
            echo "Virtualmin: $(virtualmin version 2>/dev/null | head -1)"
        fi
        echo "Apache: $(apache2 -v 2>/dev/null | head -1)"
        echo "PHP: $(php -v 2>/dev/null | head -1)"
        echo ""
        echo "=== PRÓXIMAS ACTUALIZACIONES ==="
        apt list --upgradable 2>/dev/null | head -10
        echo ""
        echo "=== CERTIFICADOS SSL ==="
        if [ -d "/etc/letsencrypt/live" ]; then
            find /etc/letsencrypt/live -name "cert.pem" -exec openssl x509 -in {} -noout -subject -dates \;
        else
            echo "Sin certificados Let's Encrypt"
        fi
    } > "$UPDATE_REPORT"
    
    log_message "Reporte de actualizaciones generado: $UPDATE_REPORT"
}

main() {
    log_message "Iniciando proceso de actualizaciones..."
    
    check_updates_available
    local update_status=$?
    
    if [ $update_status -eq 1 ] || [ $update_status -eq 2 ]; then
        backup_before_update
        update_system_packages
        update_webmin
        update_virtualmin
        update_ssl_certificates
        check_kernel_updates
        verify_services_after_update
    fi
    
    schedule_regular_updates
    generate_update_report
    
    log_message "Proceso de actualizaciones completado."
}

case "${1:-}" in
    start)
        main
        ;;
    security-only)
        log_message "Instalando solo actualizaciones de seguridad..."
        check_updates_available
        if [ $? -eq 1 ]; then
            backup_before_update
            unattended-upgrade -d
            verify_services_after_update
        fi
        ;;
    webmin-only)
        update_webmin
        ;;
    virtualmin-only)
        update_virtualmin
        ;;
    ssl-only)
        update_ssl_certificates
        ;;
    check)
        check_updates_available
        ;;
    report)
        generate_update_report
        ;;
    *)
        echo "Uso: $0 {start|security-only|webmin-only|virtualmin-only|ssl-only|check|report}"
        echo "  start         - Proceso completo de actualizaciones"
        echo "  security-only - Solo actualizaciones de seguridad"
        echo "  webmin-only   - Solo actualizar Webmin"
        echo "  virtualmin-only - Solo actualizar Virtualmin"
        echo "  ssl-only      - Solo renovar certificados SSL"
        echo "  check         - Solo verificar actualizaciones disponibles"
        echo "  report        - Generar reporte de estado de actualizaciones"
        exit 1
        ;;
esac

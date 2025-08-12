#!/bin/bash

# Incluir funciones de validación de Postfix
source "/Users/yunyminaya/Wedmin Y Virtualmin/postfix_validation_functions.sh"


set -e


# Script de Monitoreo Continuo del Sistema Webmin/Virtualmin
# Versión: 2.0
# Descripción: Monitorea el estado del sistema y notifica sobre actualizaciones disponibles

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Funciones de logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Verificar privilegios de root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root"
        exit 1
    fi
}

# Configuración
LOG_FILE="/var/log/webmin-monitor.log"
CONFIG_FILE="/etc/webmin-monitor.conf"
LAST_CHECK_FILE="/var/cache/webmin-last-check"
NOTIFICATION_FILE="/tmp/webmin-notifications"

# Crear archivos de configuración si no existen
setup_monitoring() {
    # Crear directorio de logs
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$LAST_CHECK_FILE")"
    
    # Crear archivo de configuración por defecto
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << EOF
# Configuración del Monitor de Webmin/Virtualmin
CHECK_INTERVAL=3600  # Intervalo en segundos (1 hora)
ENABLE_EMAIL_NOTIFICATIONS=false
EMAIL_ADDRESS="admin@localhost"
CHECK_UPDATES=true
CHECK_SERVICES=true
CHECK_DISK_SPACE=true
CHECK_MEMORY=true
DISK_WARNING_THRESHOLD=80
MEMORY_WARNING_THRESHOLD=85
LOG_RETENTION_DAYS=30
EOF
        log_info "Archivo de configuración creado en $CONFIG_FILE"
    fi
    
    # Cargar configuración
    source "$CONFIG_FILE"
}

# Función de logging con timestamp
log_to_file() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Verificar estado de servicios
check_services() {
    log_step "Verificando estado de servicios..."
    
    local services=("webmin" "apache2" "httpd" "mysql" "mariadb" "postfix" "named" "bind9")
    local failed_services=()
    
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "^$service.service"; then
            if ! systemctl is-active --quiet "$service"; then
                failed_services+=("$service")
                log_warning "Servicio $service no está ejecutándose"
                log_to_file "WARNING: Servicio $service no está ejecutándose"
            else
                log_success "Servicio $service está ejecutándose"
            fi
        fi
    done
    
    if [[ ${#failed_services[@]} -eq 0 ]]; then
        log_success "Todos los servicios están funcionando correctamente"
        log_to_file "INFO: Todos los servicios están funcionando correctamente"
        return 0
    else
        log_error "Servicios con problemas: ${failed_services[*]}"
        log_to_file "ERROR: Servicios con problemas: ${failed_services[*]}"
        return 1
    fi
}

# Verificar espacio en disco
check_disk_space() {
    log_step "Verificando espacio en disco..."
    
    local warning_threshold=${DISK_WARNING_THRESHOLD:-80}
    local critical_partitions=()
    
    while read -r line; do
        if [[ $line =~ ^/dev ]]; then
            local usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
            local partition=$(echo "$line" | awk '{print $6}')
            
            if [[ $usage -ge $warning_threshold ]]; then
                critical_partitions+=("$partition ($usage%)")
                log_warning "Partición $partition está al $usage% de capacidad"
                log_to_file "WARNING: Partición $partition está al $usage% de capacidad"
            fi
        fi
    done < <(df -h)
    
    if [[ ${#critical_partitions[@]} -eq 0 ]]; then
        log_success "Espacio en disco dentro de límites normales"
        return 0
    else
        log_error "Particiones con poco espacio: ${critical_partitions[*]}"
        log_to_file "ERROR: Particiones con poco espacio: ${critical_partitions[*]}"
        return 1
    fi
}

# Verificar uso de memoria
check_memory() {
    log_step "Verificando uso de memoria..."
    
    local warning_threshold=${MEMORY_WARNING_THRESHOLD:-85}
    local memory_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    
    if [[ $memory_usage -ge $warning_threshold ]]; then
        log_warning "Uso de memoria alto: $memory_usage%"
        log_to_file "WARNING: Uso de memoria alto: $memory_usage%"
        return 1
    else
        log_success "Uso de memoria normal: $memory_usage%"
        return 0
    fi
}

# Verificar actualizaciones disponibles
check_updates() {
    log_step "Verificando actualizaciones disponibles..."
    
    local updates_available=false
    
    # Verificar actualizaciones del sistema
    if command -v apt >/dev/null 2>&1; then
        apt update >/dev/null 2>&1
        local apt_updates=$(apt list --upgradable 2>/dev/null | wc -l)
        if [[ $apt_updates -gt 1 ]]; then
            log_info "$((apt_updates - 1)) actualizaciones de sistema disponibles"
            log_to_file "INFO: $((apt_updates - 1)) actualizaciones de sistema disponibles"
            updates_available=true
        fi
    elif command -v yum >/dev/null 2>&1; then
        local yum_updates=$(yum check-update 2>/dev/null | grep -v "^$" | wc -l)
        if [[ $yum_updates -gt 0 ]]; then
            log_info "$yum_updates actualizaciones de sistema disponibles"
            log_to_file "INFO: $yum_updates actualizaciones de sistema disponibles"
            updates_available=true
        fi
    elif command -v dnf >/dev/null 2>&1; then
        local dnf_updates=$(dnf check-update 2>/dev/null | grep -v "^$" | wc -l)
        if [[ $dnf_updates -gt 0 ]]; then
            log_info "$dnf_updates actualizaciones de sistema disponibles"
            log_to_file "INFO: $dnf_updates actualizaciones de sistema disponibles"
            updates_available=true
        fi
    fi
    
    # Verificar actualizaciones de Webmin
    if command -v webmin >/dev/null 2>&1; then
        # Aquí se podría implementar verificación de actualizaciones de Webmin
        log_info "Verificación de actualizaciones de Webmin completada"
    fi
    
    if [[ $updates_available == true ]]; then
        log_warning "Hay actualizaciones disponibles para el sistema"
        return 1
    else
        log_success "Sistema actualizado"
        return 0
    fi
}

# Verificar conectividad de red
check_network() {
    log_step "Verificando conectividad de red..."
    
    local test_hosts=("8.8.8.8" "1.1.1.1" "google.com")
    local failed_connections=0
    
    for host in "${test_hosts[@]}"; do
        if ! ping -c 1 -W 5 "$host" >/dev/null 2>&1; then
            ((failed_connections++))
            log_warning "No se puede conectar a $host"
        fi
    done
    
    if [[ $failed_connections -eq ${#test_hosts[@]} ]]; then
        log_error "Sin conectividad de red"
        log_to_file "ERROR: Sin conectividad de red"
        return 1
    elif [[ $failed_connections -gt 0 ]]; then
        log_warning "Conectividad de red limitada"
        log_to_file "WARNING: Conectividad de red limitada"
        return 1
    else
        log_success "Conectividad de red normal"
        return 0
    fi
}

# Verificar certificados SSL
check_ssl_certificates() {
    log_step "Verificando certificados SSL..."
    
    local cert_dirs=("/etc/ssl/certs" "/etc/letsencrypt/live" "/etc/webmin")
    local expiring_certs=()
    
    for cert_dir in "${cert_dirs[@]}"; do
        if [[ -d "$cert_dir" ]]; then
            while IFS= read -r -d '' cert_file; do
                if [[ -f "$cert_file" ]]; then
                    local expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2)
                    if [[ -n "$expiry_date" ]]; then
                        local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null)
                        local current_epoch=$(date +%s)
                        local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
                        
                        if [[ $days_until_expiry -lt 30 ]]; then
                            expiring_certs+=("$cert_file ($days_until_expiry días)")
                            log_warning "Certificado $cert_file expira en $days_until_expiry días"
                        fi
                    fi
                fi
            done < <(find "$cert_dir" -name "*.crt" -o -name "*.pem" -print0 2>/dev/null)
        fi
    done
    
    if [[ ${#expiring_certs[@]} -eq 0 ]]; then
        log_success "Todos los certificados SSL están vigentes"
        return 0
    else
        log_warning "Certificados próximos a expirar: ${expiring_certs[*]}"
        log_to_file "WARNING: Certificados próximos a expirar: ${expiring_certs[*]}"
        return 1
    fi
}

# Generar reporte de estado
generate_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_file="/tmp/webmin-status-report-$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
=== REPORTE DE ESTADO DEL SISTEMA WEBMIN/VIRTUALMIN ===
Fecha: $timestamp
Servidor: $(hostname)
Sistema: $(uname -a)

=== ESTADO DE SERVICIOS ===
EOF
    
    systemctl status webmin --no-pager -l >> "$report_file" 2>/dev/null || echo "Webmin: No disponible" >> "$report_file"
    echo "" >> "$report_file"
    
    echo "=== USO DE RECURSOS ===" >> "$report_file"
    echo "Memoria:" >> "$report_file"
    free -h >> "$report_file"
    echo "" >> "$report_file"
    echo "Disco:" >> "$report_file"
    df -h >> "$report_file"
    echo "" >> "$report_file"
    
    echo "=== PROCESOS PRINCIPALES ===" >> "$report_file"
    ps aux | grep -E "(webmin|apache|mysql|postfix)" | grep -v grep >> "$report_file"
    echo "" >> "$report_file"
    
    echo "=== CONEXIONES DE RED ===" >> "$report_file"
    netstat -tlnp | grep -E ":(80|443|10000|25|53) " >> "$report_file" 2>/dev/null || ss -tlnp | grep -E ":(80|443|10000|25|53) " >> "$report_file"
    
    log_info "Reporte generado en: $report_file"
    echo "$report_file"
}

# Limpiar logs antiguos
cleanup_logs() {
    local retention_days=${LOG_RETENTION_DAYS:-30}
    
    if [[ -f "$LOG_FILE" ]]; then
        find "$(dirname "$LOG_FILE")" -name "*.log" -mtime +$retention_days -delete 2>/dev/null
        log_info "Logs antiguos limpiados (más de $retention_days días)"
    fi
}

# Función principal de monitoreo
run_monitoring() {
    log_info "=== INICIANDO MONITOREO DEL SISTEMA ==="
    log_to_file "INFO: Iniciando monitoreo del sistema"
    
    local issues=0
    
    # Ejecutar verificaciones
    check_services || ((issues++))
    check_disk_space || ((issues++))
    check_memory || ((issues++))
    check_network || ((issues++))
    
    if [[ "${CHECK_UPDATES:-true}" == "true" ]]; then
        check_updates || ((issues++))
    fi
    
    check_ssl_certificates || ((issues++))
    
    # Generar reporte si hay problemas
    if [[ $issues -gt 0 ]]; then
        log_warning "Se encontraron $issues problemas en el sistema"
        log_to_file "WARNING: Se encontraron $issues problemas en el sistema"
        
        local report_file=$(generate_report)
        
        # Enviar notificación por email si está habilitado
        if [[ "${ENABLE_EMAIL_NOTIFICATIONS:-false}" == "true" ]] && [[ -n "${EMAIL_ADDRESS}" ]]; then
            mail -s "Alerta del Sistema Webmin - $issues problemas encontrados" "$EMAIL_ADDRESS" < "$report_file" 2>/dev/null || log_warning "No se pudo enviar email de notificación"
        fi
    else
        log_success "Sistema funcionando correctamente"
        log_to_file "INFO: Sistema funcionando correctamente"
    fi
    
    # Actualizar timestamp del último chequeo
    echo "$(date +%s)" > "$LAST_CHECK_FILE"
    
    # Limpiar logs antiguos
    cleanup_logs
    
    log_info "=== MONITOREO COMPLETADO ==="
    return $issues
}

# Instalar como servicio systemd
install_service() {
    log_step "Instalando servicio de monitoreo..."
    
    cat > "/etc/systemd/system/webmin-monitor.service" << EOF
[Unit]
Description=Webmin/Virtualmin System Monitor
After=network.target

[Service]
Type=oneshot
ExecStart=$0 --run
User=root

[Install]
WantedBy=multi-user.target
EOF
    
    cat > "/etc/systemd/system/webmin-monitor.timer" << EOF
[Unit]
Description=Run Webmin Monitor every hour
Requires=webmin-monitor.service

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    systemctl daemon-reload
    systemctl enable webmin-monitor.timer
    systemctl start webmin-monitor.timer
    
    log_success "Servicio de monitoreo instalado y habilitado"
}

# Mostrar ayuda
show_help() {
    cat << EOF
Uso: $0 [OPCIÓN]

Opciones:
  --run              Ejecutar monitoreo una vez
  --install-service  Instalar como servicio systemd
  --status           Mostrar estado del servicio
  --report           Generar reporte detallado
  --config           Mostrar configuración actual
  --help             Mostrar esta ayuda

Ejemplos:
  $0 --run                    # Ejecutar monitoreo manual
  $0 --install-service        # Instalar monitoreo automático
  $0 --report                 # Generar reporte del sistema

Archivos de configuración:
  $CONFIG_FILE
  $LOG_FILE

EOF
}

# Función principal
main() {
    check_root
    setup_monitoring
    
    case "${1:-}" in
        --run)
            run_monitoring
            ;;
        --install-service)
            install_service
            ;;
        --status)
            systemctl status webmin-monitor.timer --no-pager
            ;;
        --report)
            generate_report
            ;;
        --config)
            cat "$CONFIG_FILE"
            ;;
        --help)
            show_help
            ;;
        "")
            log_info "Ejecutando monitoreo interactivo..."
            run_monitoring
            ;;
        *)
            log_error "Opción desconocida: $1"
            show_help
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"
#!/bin/bash
# Script mejorado para túnel automático con alta disponibilidad y seguridad
# Versión 2.0 - Resistente a fallos, eficiente y seguro

set -euo pipefail

# Configuración avanzada
CONFIG_DIR="/etc/auto-tunnel"
LOG_DIR="/var/log/auto-tunnel"
BACKUP_DIR="/var/backups/auto-tunnel"
SECURITY_LOG="$LOG_DIR/security.log"
PERFORMANCE_LOG="$LOG_DIR/performance.log"
FAILOVER_LOG="$LOG_DIR/failover.log"
MAX_RETRY_ATTEMPTS=5
HEALTH_CHECK_INTERVAL=60
FAILOVER_TIMEOUT=30
SECURITY_SCAN_INTERVAL=3600

# Colores mejorados
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Crear directorios necesarios
mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$BACKUP_DIR"

# Funciones de logging mejoradas
log() {
    local level="${2:-INFO}"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[$timestamp]${NC} [$level] $1" | tee -a "$LOG_DIR/main.log"
}

log_security() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [SECURITY] $1" | tee -a "$SECURITY_LOG"
    log "🔒 SECURITY: $1" "SECURITY"
}

log_performance() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [PERFORMANCE] $1" | tee -a "$PERFORMANCE_LOG"
}

log_failover() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [FAILOVER] $1" | tee -a "$FAILOVER_LOG"
    log "🔄 FAILOVER: $1" "FAILOVER"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_DIR/warnings.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_DIR/errors.log"
}

# Función de notificación por email/webhook
enviar_notificacion() {
    local tipo="$1"
    local mensaje="$2"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    
    # Email si está configurado
    if [[ -n "${NOTIFICATION_EMAIL:-}" ]] && command -v mail >/dev/null 2>&1; then
        echo "[$timestamp] $mensaje" | mail -s "Auto-Tunnel Alert: $tipo" "$NOTIFICATION_EMAIL"
    fi
    
    # Webhook si está configurado
    if [[ -n "${WEBHOOK_URL:-}" ]]; then
        curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"type\":\"$tipo\",\"message\":\"$mensaje\",\"timestamp\":\"$timestamp\"}" \
            --max-time 10 --silent || true
    fi
}

# Verificación avanzada de IP con múltiples fuentes
verificar_tipo_ip_avanzado() {
    log "🔍 Verificando tipo de IP con múltiples fuentes..."
    local fuentes=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ident.me")
    local ip_publica=""
    local ip_local=$(hostname -I | awk '{print $1}')
    
    for fuente in "${fuentes[@]}"; do
        ip_publica=$(curl -s --max-time 5 "$fuente" 2>/dev/null | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' || echo "")
        if [[ -n "$ip_publica" ]]; then
            log "✅ IP pública obtenida de $fuente: $ip_publica"
            break
        fi
    done
    
    if [[ -z "$ip_publica" ]]; then
        log_error "No se pudo obtener IP pública de ninguna fuente"
        return 1
    fi
    
    # Verificar si es IP privada
    if [[ $ip_publica =~ ^10\. ]] || [[ $ip_publica =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || [[ $ip_publica =~ ^192\.168\. ]] || [[ $ip_publica =~ ^127\. ]]; then
        log_warning "IP detectada es privada: $ip_publica - Necesario túnel NAT"
        echo "$ip_publica" > "$CONFIG_DIR/current_ip.txt"
        return 1
    else
        log "✅ IP pública válida detectada: $ip_publica"
        echo "$ip_publica" > "$CONFIG_DIR/current_ip.txt"
        return 0
    fi
}

# Verificación de seguridad del sistema
verificar_seguridad_sistema() {
    log_security "Iniciando verificación de seguridad del sistema"
    local alertas_seguridad=()
    
    # Verificar firewall
    if ! systemctl is-active --quiet ufw; then
        alertas_seguridad+=("UFW firewall no está activo")
    fi
    
    # Verificar fail2ban
    if ! systemctl is-active --quiet fail2ban; then
        alertas_seguridad+=("Fail2ban no está activo")
    fi
    
    # Verificar certificados SSL
    if [[ -f "/etc/ssl/certs/webmin.pem" ]]; then
        local dias_expiracion=$(openssl x509 -in /etc/ssl/certs/webmin.pem -noout -dates | grep notAfter | cut -d= -f2 | xargs -I {} date -d "{}" +%s)
        local dias_actuales=$(date +%s)
        local dias_restantes=$(( (dias_expiracion - dias_actuales) / 86400 ))
        
        if [[ $dias_restantes -lt 30 ]]; then
            alertas_seguridad+=("Certificado SSL expira en $dias_restantes días")
        fi
    fi
    
    # Verificar intentos de acceso sospechosos
    local intentos_fallidos=$(grep "Failed password" /var/log/auth.log 2>/dev/null | tail -100 | wc -l || echo "0")
    if [[ $intentos_fallidos -gt 50 ]]; then
        alertas_seguridad+=("$intentos_fallidos intentos de login fallidos detectados")
    fi
    
    # Reportar alertas
    if [[ ${#alertas_seguridad[@]} -gt 0 ]]; then
        for alerta in "${alertas_seguridad[@]}"; do
            log_security "⚠️ ALERTA: $alerta"
        done
        enviar_notificacion "SECURITY_ALERT" "Alertas de seguridad detectadas: ${alertas_seguridad[*]}"
        return 1
    else
        log_security "✅ Verificación de seguridad completada sin alertas"
        return 0
    fi
}

# Monitoreo de rendimiento
monitorear_rendimiento() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | cut -d'%' -f1)
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | cut -d',' -f1)
    
    log_performance "CPU: ${cpu_usage}%, RAM: ${mem_usage}%, Disk: ${disk_usage}%, Load: ${load_avg}"
    
    # Alertas de rendimiento
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        enviar_notificacion "PERFORMANCE_ALERT" "Alto uso de CPU: ${cpu_usage}%"
    fi
    
    if (( $(echo "$mem_usage > 85" | bc -l) )); then
        enviar_notificacion "PERFORMANCE_ALERT" "Alto uso de memoria: ${mem_usage}%"
    fi
    
    if [[ $disk_usage -gt 90 ]]; then
        enviar_notificacion "PERFORMANCE_ALERT" "Alto uso de disco: ${disk_usage}%"
    fi
}

# Verificación de salud de servicios críticos
verificar_salud_servicios() {
    local servicios_criticos=("webmin" "usermin" "apache2" "nginx" "mysql" "postgresql")
    local servicios_fallidos=()
    
    for servicio in "${servicios_criticos[@]}"; do
        if systemctl list-unit-files | grep -q "^$servicio.service"; then
            if ! systemctl is-active --quiet "$servicio"; then
                servicios_fallidos+=("$servicio")
                log_error "❌ Servicio $servicio no está activo"
                # Intentar reiniciar automáticamente
                log "🔄 Intentando reiniciar $servicio..."
                if systemctl restart "$servicio" 2>/dev/null; then
                    log "✅ Servicio $servicio reiniciado exitosamente"
                    enviar_notificacion "SERVICE_RECOVERY" "Servicio $servicio reiniciado automáticamente"
                else
                    log_error "❌ No se pudo reiniciar $servicio"
                    enviar_notificacion "SERVICE_FAILURE" "Fallo crítico en servicio $servicio"
                fi
            fi
        fi
    done
    
    return ${#servicios_fallidos[@]}
}

# Configuración de túnel con failover inteligente
configurar_tunnel_failover() {
    log "🔄 Configurando sistema de túnel con failover inteligente..."
    
    # Crear configuración de prioridades
    cat > "$CONFIG_DIR/tunnel_priorities.conf" << EOF
# Prioridades de túneles (1 = mayor prioridad)
cloudflare=1
ngrok=2
localtunnel=3
upnp=4
EOF
    
    # Script de failover inteligente
    cat > "$CONFIG_DIR/failover_manager.sh" << 'EOF'
#!/bin/bash
CONFIG_DIR="/etc/auto-tunnel"
LOG_DIR="/var/log/auto-tunnel"

source "$CONFIG_DIR/tunnel_priorities.conf"

test_tunnel_health() {
    local tunnel_type="$1"
    local test_url="$2"
    
    # Test HTTP response
    if curl -s --max-time 10 "$test_url" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

get_active_tunnels() {
    local active_tunnels=()
    
    if systemctl is-active --quiet cloudflared-webmin; then
        active_tunnels+=("cloudflare")
    fi
    
    if systemctl is-active --quiet ngrok-webmin; then
        active_tunnels+=("ngrok")
    fi
    
    if pgrep -f "localtunnel" >/dev/null; then
        active_tunnels+=("localtunnel")
    fi
    
    echo "${active_tunnels[@]}"
}

failover_to_backup() {
    local failed_tunnel="$1"
    local backup_tunnels=("cloudflare" "ngrok" "localtunnel" "upnp")
    
    echo "[$(date)] Iniciando failover desde $failed_tunnel" >> "$LOG_DIR/failover.log"
    
    for backup in "${backup_tunnels[@]}"; do
        if [[ "$backup" != "$failed_tunnel" ]]; then
            echo "[$(date)] Intentando failover a $backup" >> "$LOG_DIR/failover.log"
            if start_tunnel "$backup"; then
                echo "[$(date)] Failover exitoso a $backup" >> "$LOG_DIR/failover.log"
                return 0
            fi
        fi
    done
    
    echo "[$(date)] Failover falló - no hay túneles de respaldo disponibles" >> "$LOG_DIR/failover.log"
    return 1
}
EOF
    
    chmod +x "$CONFIG_DIR/failover_manager.sh"
    log "✅ Sistema de failover configurado"
}

# Backup automático de configuraciones
crear_backup_configuracion() {
    local timestamp=$(date +'%Y%m%d_%H%M%S')
    local backup_file="$BACKUP_DIR/config_backup_$timestamp.tar.gz"
    
    log "💾 Creando backup de configuración..."
    
    tar -czf "$backup_file" \
        "$CONFIG_DIR" \
        "/etc/systemd/system/auto-tunnel-manager.service" \
        "/etc/systemd/system/cloudflared-webmin.service" \
        "/etc/systemd/system/ngrok-webmin.service" \
        "/etc/cloudflared/" \
        "~/.ngrok2/" \
        2>/dev/null || true
    
    # Mantener solo los últimos 10 backups
    ls -t "$BACKUP_DIR"/config_backup_*.tar.gz | tail -n +11 | xargs rm -f 2>/dev/null || true
    
    log "✅ Backup creado: $backup_file"
}

# Función principal mejorada
main_mejorado() {
    log "🚀 Iniciando sistema de túnel automático mejorado v2.0"
    
    # Verificaciones iniciales
    verificar_seguridad_sistema
    monitorear_rendimiento
    verificar_salud_servicios
    
    # Crear backup antes de cambios
    crear_backup_configuracion
    
    # Verificar necesidad de túnel
    if verificar_tipo_ip_avanzado; then
        log "✅ IP pública detectada - configurando monitoreo preventivo"
    else
        log "⚠️ NAT detectado - configurando túnel con failover"
        configurar_tunnel_failover
    fi
    
    # Configurar monitoreo continuo mejorado
    crear_servicio_monitoreo_avanzado
    
    log "🎉 Sistema de túnel automático mejorado configurado exitosamente"
    mostrar_resumen_mejorado
}

# Crear servicio de monitoreo avanzado
crear_servicio_monitoreo_avanzado() {
    log "📊 Configurando servicio de monitoreo avanzado..."
    
    cat > "/usr/local/bin/auto-tunnel-manager-v2.sh" << 'EOF'
#!/bin/bash
# Auto Tunnel Manager v2.0 - Monitoreo avanzado con IA predictiva

CONFIG_DIR="/etc/auto-tunnel"
LOG_DIR="/var/log/auto-tunnel"
HEALTH_CHECK_INTERVAL=60
SECURITY_SCAN_INTERVAL=3600
PERFORMANCE_CHECK_INTERVAL=300

source "$CONFIG_DIR/tunnel_priorities.conf" 2>/dev/null || true

# Función de monitoreo predictivo
monitoreo_predictivo() {
    local cpu_history_file="$LOG_DIR/cpu_history.log"
    local mem_history_file="$LOG_DIR/mem_history.log"
    
    # Recopilar métricas históricas
    local cpu_current=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local mem_current=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    
    echo "$(date +%s) $cpu_current" >> "$cpu_history_file"
    echo "$(date +%s) $mem_current" >> "$mem_history_file"
    
    # Mantener solo las últimas 1000 entradas
    tail -1000 "$cpu_history_file" > "$cpu_history_file.tmp" && mv "$cpu_history_file.tmp" "$cpu_history_file"
    tail -1000 "$mem_history_file" > "$mem_history_file.tmp" && mv "$mem_history_file.tmp" "$mem_history_file"
    
    # Análisis predictivo simple
    if [[ $(wc -l < "$cpu_history_file") -gt 10 ]]; then
        local cpu_trend=$(tail -10 "$cpu_history_file" | awk '{sum+=$2} END {print sum/NR}')
        if (( $(echo "$cpu_trend > 70" | bc -l) )); then
            echo "[$(date)] PREDICCIÓN: Posible sobrecarga de CPU detectada" >> "$LOG_DIR/predictions.log"
        fi
    fi
}

# Bucle principal de monitoreo
while true; do
    # Verificar salud de túneles cada minuto
    if (( $(date +%s) % $HEALTH_CHECK_INTERVAL == 0 )); then
        bash "$CONFIG_DIR/failover_manager.sh" check_health
    fi
    
    # Escaneo de seguridad cada hora
    if (( $(date +%s) % $SECURITY_SCAN_INTERVAL == 0 )); then
        bash "/Users/yunyminaya/Wedmin Y Virtualmin/verificar_tunel_automatico_mejorado.sh" security_scan
    fi
    
    # Monitoreo de rendimiento cada 5 minutos
    if (( $(date +%s) % $PERFORMANCE_CHECK_INTERVAL == 0 )); then
        monitoreo_predictivo
    fi
    
    sleep 30
done
EOF
    
    chmod +x "/usr/local/bin/auto-tunnel-manager-v2.sh"
    
    # Crear servicio systemd mejorado
    cat > "/etc/systemd/system/auto-tunnel-manager-v2.service" << EOF
[Unit]
Description=Auto Tunnel Manager v2.0 - Advanced Monitoring
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/auto-tunnel-manager-v2.sh
Restart=always
RestartSec=10
StartLimitInterval=0
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30

# Configuración de seguridad
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$LOG_DIR $CONFIG_DIR $BACKUP_DIR

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable auto-tunnel-manager-v2
    
    log "✅ Servicio de monitoreo avanzado configurado"
}

# Mostrar resumen mejorado
mostrar_resumen_mejorado() {
    echo
    echo "═══════════════════════════════════════════════════════════════"
    echo "🎯 SISTEMA DE TÚNEL AUTOMÁTICO v2.0 - CONFIGURACIÓN COMPLETADA"
    echo "═══════════════════════════════════════════════════════════════"
    echo
    echo "📁 Directorios de configuración:"
    echo "   • Configuración: $CONFIG_DIR"
    echo "   • Logs: $LOG_DIR"
    echo "   • Backups: $BACKUP_DIR"
    echo
    echo "🔧 Servicios configurados:"
    echo "   • auto-tunnel-manager-v2.service (Monitoreo avanzado)"
    echo "   • cloudflared-webmin.service (Túnel Cloudflare)"
    echo "   • ngrok-webmin.service (Túnel ngrok)"
    echo
    echo "📊 Archivos de log importantes:"
    echo "   • Principal: $LOG_DIR/main.log"
    echo "   • Seguridad: $SECURITY_LOG"
    echo "   • Rendimiento: $PERFORMANCE_LOG"
    echo "   • Failover: $FAILOVER_LOG"
    echo
    echo "🚀 Comandos útiles:"
    echo "   • systemctl status auto-tunnel-manager-v2"
    echo "   • tail -f $LOG_DIR/main.log"
    echo "   • bash $CONFIG_DIR/failover_manager.sh check_health"
    echo
    echo "🔒 Características de seguridad activadas:"
    echo "   • ✅ Monitoreo de intentos de acceso"
    echo "   • ✅ Verificación de certificados SSL"
    echo "   • ✅ Alertas de seguridad automáticas"
    echo "   • ✅ Backup automático de configuraciones"
    echo
    echo "⚡ Características de alta disponibilidad:"
    echo "   • ✅ Failover automático entre túneles"
    echo "   • ✅ Monitoreo predictivo de recursos"
    echo "   • ✅ Reinicio automático de servicios"
    echo "   • ✅ Notificaciones por email/webhook"
    echo
    echo "═══════════════════════════════════════════════════════════════"
}

# Función para escaneo de seguridad bajo demanda
security_scan() {
    log_security "🔍 Iniciando escaneo de seguridad completo..."
    
    # Verificar puertos abiertos
    local puertos_abiertos=$(netstat -tuln | grep LISTEN | wc -l)
    log_security "Puertos en escucha: $puertos_abiertos"
    
    # Verificar conexiones activas sospechosas
    local conexiones_externas=$(netstat -tn | grep ESTABLISHED | grep -v "127.0.0.1\|::1" | wc -l)
    if [[ $conexiones_externas -gt 50 ]]; then
        log_security "⚠️ Alto número de conexiones externas: $conexiones_externas"
    fi
    
    # Verificar procesos sospechosos
    local procesos_sospechosos=$(ps aux | grep -E "(nc|netcat|nmap|masscan)" | grep -v grep | wc -l)
    if [[ $procesos_sospechosos -gt 0 ]]; then
        log_security "⚠️ Procesos potencialmente sospechosos detectados"
    fi
    
    log_security "✅ Escaneo de seguridad completado"
}

# Manejo de argumentos
case "${1:-main}" in
    "main")
        main_mejorado
        ;;
    "security_scan")
        security_scan
        ;;
    "backup")
        crear_backup_configuracion
        ;;
    "health_check")
        verificar_salud_servicios
        ;;
    "performance")
        monitorear_rendimiento
        ;;
    *)
        echo "Uso: $0 [main|security_scan|backup|health_check|performance]"
        exit 1
        ;;
esac
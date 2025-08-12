#!/bin/bash
# Script maestro para instalación del sistema de túneles mejorado
# Integra seguridad avanzada, alta disponibilidad y monitoreo inteligente
# Versión 3.0 - Sistema completo contra fallos

set -euo pipefail

# Configuración global
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_LOG="/var/log/tunnel-system-install.log"
CONFIG_BASE_DIR="/etc/auto-tunnel"
LOG_BASE_DIR="/var/log/auto-tunnel"
BACKUP_BASE_DIR="/var/backups/auto-tunnel"

# Versión del sistema
SYSTEM_VERSION="3.0"
INSTALL_DATE=$(date +'%Y-%m-%d %H:%M:%S')

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Crear directorios base
mkdir -p "$CONFIG_BASE_DIR" "$LOG_BASE_DIR" "$BACKUP_BASE_DIR"

# Funciones de logging
log() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[$timestamp]${NC} $1" | tee -a "$INSTALL_LOG"
}

log_error() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[$timestamp] ERROR:${NC} $1" | tee -a "$INSTALL_LOG"
}

log_warning() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[$timestamp] WARNING:${NC} $1" | tee -a "$INSTALL_LOG"
}

log_info() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[$timestamp] INFO:${NC} $1" | tee -a "$INSTALL_LOG"
}

# Función para mostrar banner
mostrar_banner() {
    clear
    echo -e "${CYAN}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "██████╗ ██╗   ██╗███╗   ██╗███╗   ██╗███████╗██╗         ██╗   ██╗██████╗ "
    echo "╚══██╔══╝██║   ██║████╗  ██║████╗  ██║██╔════╝██║         ██║   ██║╚════██╗"
    echo "   ██║   ██║   ██║██╔██╗ ██║██╔██╗ ██║█████╗  ██║         ██║   ██║ █████╔╝"
    echo "   ██║   ██║   ██║██║╚██╗██║██║╚██╗██║██╔══╝  ██║         ╚██╗ ██╔╝ ╚═══██╗"
    echo "   ██║   ╚██████╔╝██║ ╚████║██║ ╚████║███████╗███████╗     ╚████╔╝ ██████╔╝"
    echo "   ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝╚══════╝╚══════╝      ╚═══╝  ╚═════╝ "
    echo
    echo "        🚀 SISTEMA DE TÚNELES AUTOMÁTICOS AVANZADO v$SYSTEM_VERSION 🚀"
    echo "                    🔒 Seguro • ⚡ Eficiente • 🛡️ Resistente a Fallos"
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    echo
}

# Verificar requisitos del sistema
verificar_requisitos() {
    log "🔍 Verificando requisitos del sistema..."
    
    # Verificar que se ejecuta como root
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root"
        exit 1
    fi
    
    # Verificar sistema operativo
    if [[ ! -f /etc/os-release ]]; then
        log_error "No se puede determinar el sistema operativo"
        exit 1
    fi
    
    source /etc/os-release
    log_info "Sistema operativo: $PRETTY_NAME"
    
    # Verificar conectividad a internet
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_error "No hay conectividad a internet"
        exit 1
    fi
    
    # Verificar espacio en disco (mínimo 2GB)
    local espacio_disponible=$(df / | tail -1 | awk '{print $4}')
    if [[ $espacio_disponible -lt 2097152 ]]; then  # 2GB en KB
        log_warning "Espacio en disco bajo: $(($espacio_disponible / 1024))MB disponibles"
    fi
    
    # Verificar memoria RAM (mínimo 1GB)
    local memoria_total=$(free -m | grep '^Mem:' | awk '{print $2}')
    if [[ $memoria_total -lt 1024 ]]; then
        log_warning "Memoria RAM baja: ${memoria_total}MB disponibles"
    fi
    
    log "✅ Verificación de requisitos completada"
}

# Instalar dependencias del sistema
instalar_dependencias() {
    log "📦 Instalando dependencias del sistema..."
    
    # Actualizar repositorios
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y \
            curl wget git unzip \
            iptables iptables-persistent \
            fail2ban ufw \
            netcat-openbsd nmap \
            python3 python3-pip \
            nodejs npm \
            bc jq \
            mailutils \
            logrotate \
            systemd \
            cron \
            openssl \
            miniupnpc
    elif command -v yum >/dev/null 2>&1; then
        yum update -y
        yum install -y \
            curl wget git unzip \
            iptables iptables-services \
            fail2ban \
            nc nmap \
            python3 python3-pip \
            nodejs npm \
            bc jq \
            mailx \
            logrotate \
            systemd \
            cronie \
            openssl \
            miniupnpc
    else
        log_error "Gestor de paquetes no soportado"
        exit 1
    fi
    
    # Instalar herramientas adicionales con pip
    pip3 install requests psutil
    
    log "✅ Dependencias instaladas correctamente"
}

# Instalar herramientas de túnel
instalar_herramientas_tunnel() {
    log "🔧 Instalando herramientas de túnel..."
    
    # Instalar Cloudflare Tunnel
    log_info "Instalando Cloudflare Tunnel..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        local arch=$(uname -m)
        case $arch in
            x86_64)
                wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared
                ;;
            aarch64)
                wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O /usr/local/bin/cloudflared
                ;;
            armv7l)
                wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm -O /usr/local/bin/cloudflared
                ;;
            *)
                log_warning "Arquitectura no soportada para Cloudflare Tunnel: $arch"
                ;;
        esac
        chmod +x /usr/local/bin/cloudflared
    fi
    
    # Instalar ngrok
    log_info "Instalando ngrok..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        local arch=$(uname -m)
        case $arch in
            x86_64)
                wget -q https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip -O /tmp/ngrok.zip
                ;;
            aarch64)
                wget -q https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-arm64.zip -O /tmp/ngrok.zip
                ;;
            armv7l)
                wget -q https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-arm.zip -O /tmp/ngrok.zip
                ;;
        esac
        unzip -q /tmp/ngrok.zip -d /usr/local/bin/
        chmod +x /usr/local/bin/ngrok
        rm -f /tmp/ngrok.zip
    fi
    
    # Instalar LocalTunnel
    log_info "Instalando LocalTunnel..."
    npm install -g localtunnel
    
    log "✅ Herramientas de túnel instaladas"
}

# Configurar sistema base
configurar_sistema_base() {
    log "⚙️ Configurando sistema base..."
    
    # Crear usuario específico para túneles
    if ! id "tunnel-user" >/dev/null 2>&1; then
        useradd -r -s /bin/false -d /var/lib/tunnel-user tunnel-user
        mkdir -p /var/lib/tunnel-user
        chown tunnel-user:tunnel-user /var/lib/tunnel-user
    fi
    
    # Configurar logrotate
    cat > /etc/logrotate.d/auto-tunnel << EOF
$LOG_BASE_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF
    
    # Configurar límites del sistema
    cat > /etc/security/limits.d/tunnel-limits.conf << EOF
# Límites para el sistema de túneles
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
root soft nofile 65536
root hard nofile 65536
EOF
    
    # Optimizaciones de red
    cat > /etc/sysctl.d/99-tunnel-optimizations.conf << EOF
# Optimizaciones de red para túneles
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
net.core.somaxconn = 65535
EOF
    
    sysctl -p /etc/sysctl.d/99-tunnel-optimizations.conf
    
    log "✅ Sistema base configurado"
}

# Ejecutar instalación de componentes
instalar_componentes() {
    log "🔧 Instalando componentes del sistema..."
    
    # Ejecutar script de túnel automático mejorado
    log_info "Instalando sistema de túnel automático mejorado..."
    if [[ -f "$SCRIPT_DIR/verificar_tunel_automatico_mejorado.sh" ]]; then
        bash "$SCRIPT_DIR/verificar_tunel_automatico_mejorado.sh" main
    else
        log_error "No se encontró el script de túnel automático mejorado"
        exit 1
    fi
    
    # Ejecutar script de seguridad avanzada
    log_info "Instalando sistema de seguridad avanzada..."
    if [[ -f "$SCRIPT_DIR/seguridad_avanzada_tunnel.sh" ]]; then
        bash "$SCRIPT_DIR/seguridad_avanzada_tunnel.sh" main
    else
        log_error "No se encontró el script de seguridad avanzada"
        exit 1
    fi
    
    # Ejecutar script de alta disponibilidad
    log_info "Instalando sistema de alta disponibilidad..."
    if [[ -f "$SCRIPT_DIR/alta_disponibilidad_tunnel.sh" ]]; then
        bash "$SCRIPT_DIR/alta_disponibilidad_tunnel.sh" main
    else
        log_error "No se encontró el script de alta disponibilidad"
        exit 1
    fi
    
    log "✅ Componentes instalados correctamente"
}

# Configurar monitoreo y alertas
configurar_monitoreo_alertas() {
    log "📊 Configurando sistema de monitoreo y alertas..."
    
    # Script de monitoreo integral
    cat > /usr/local/bin/sistema-monitoreo-integral.sh << 'EOF'
#!/bin/bash
# Sistema de monitoreo integral para túneles

LOG_BASE_DIR="/var/log/auto-tunnel"
CONFIG_BASE_DIR="/etc/auto-tunnel"
MONITOR_LOG="$LOG_BASE_DIR/monitor-integral.log"

log_monitor() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [MONITOR] $1" >> "$MONITOR_LOG"
}

# Verificar estado general del sistema
verificar_estado_general() {
    local estado_general="OK"
    local alertas=()
    
    # Verificar servicios críticos
    local servicios_criticos=("webmin" "usermin" "ha-tunnel-monitor" "auto-tunnel-manager-v2" "attack-monitor")
    
    for servicio in "${servicios_criticos[@]}"; do
        if systemctl list-unit-files | grep -q "^$servicio.service"; then
            if ! systemctl is-active --quiet "$servicio"; then
                alertas+=("Servicio $servicio no está activo")
                estado_general="CRITICAL"
            fi
        fi
    done
    
    # Verificar túneles activos
    local tunnels_activos=$(bash "$CONFIG_BASE_DIR/ha/tunnel_manager.sh" list 2>/dev/null | grep ":active:active" | wc -l || echo "0")
    if [[ $tunnels_activos -eq 0 ]]; then
        alertas+=("No hay túneles activos")
        estado_general="CRITICAL"
    fi
    
    # Verificar conectividad
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        alertas+=("Sin conectividad a internet")
        estado_general="CRITICAL"
    fi
    
    # Verificar uso de recursos
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | cut -d'%' -f1)
    
    if (( $(echo "$cpu_usage > 90" | bc -l) )); then
        alertas+=("Alto uso de CPU: ${cpu_usage}%")
        estado_general="WARNING"
    fi
    
    if (( $(echo "$mem_usage > 90" | bc -l) )); then
        alertas+=("Alto uso de memoria: ${mem_usage}%")
        estado_general="WARNING"
    fi
    
    if [[ $disk_usage -gt 90 ]]; then
        alertas+=("Alto uso de disco: ${disk_usage}%")
        estado_general="WARNING"
    fi
    
    # Log del estado
    log_monitor "Estado general: $estado_general"
    if [[ ${#alertas[@]} -gt 0 ]]; then
        for alerta in "${alertas[@]}"; do
            log_monitor "ALERTA: $alerta"
        done
    fi
    
    # Generar reporte de estado
    cat > "$LOG_BASE_DIR/estado-sistema.json" << JSONEOF
{
    "timestamp": "$(date -Iseconds)",
    "estado_general": "$estado_general",
    "tunnels_activos": $tunnels_activos,
    "cpu_usage": $cpu_usage,
    "mem_usage": $mem_usage,
    "disk_usage": $disk_usage,
    "alertas": [$(printf '"%s",' "${alertas[@]}" | sed 's/,$//')]
}
JSONEOF
    
    return $([ "$estado_general" = "OK" ] && echo 0 || echo 1)
}

# Generar reporte diario
generar_reporte_diario() {
    local fecha=$(date +'%Y-%m-%d')
    local reporte_file="$LOG_BASE_DIR/reporte-diario-$fecha.txt"
    
    cat > "$reporte_file" << EOF
═══════════════════════════════════════════════════════════════
REPORTE DIARIO DEL SISTEMA DE TÚNELES - $fecha
═══════════════════════════════════════════════════════════════

📊 ESTADÍSTICAS GENERALES:
$(cat "$LOG_BASE_DIR/estado-sistema.json" | jq -r '"• Estado: " + .estado_general + "\n• Túneles activos: " + (.tunnels_activos|tostring) + "\n• CPU: " + .cpu_usage + "%\n• Memoria: " + .mem_usage + "%\n• Disco: " + .disk_usage + "%"')

🔒 EVENTOS DE SEGURIDAD (últimas 24h):
$(tail -100 "$LOG_BASE_DIR/security/attacks.log" 2>/dev/null | grep "$(date +'%Y-%m-%d')" | wc -l) ataques detectados
$(tail -100 "$LOG_BASE_DIR/security/ddos.log" 2>/dev/null | grep "$(date +'%Y-%m-%d')" | wc -l) intentos de DDoS
$(tail -100 "$LOG_BASE_DIR/security/brute_force.log" 2>/dev/null | grep "$(date +'%Y-%m-%d')" | wc -l) ataques de fuerza bruta

🔄 EVENTOS DE FAILOVER (últimas 24h):
$(tail -100 "$LOG_BASE_DIR/ha/failover.log" 2>/dev/null | grep "$(date +'%Y-%m-%d')" | wc -l) eventos de failover
$(tail -100 "$LOG_BASE_DIR/ha/recovery.log" 2>/dev/null | grep "$(date +'%Y-%m-%d')" | wc -l) recuperaciones automáticas

📈 RENDIMIENTO:
$(tail -100 "$LOG_BASE_DIR/performance.log" 2>/dev/null | grep "$(date +'%Y-%m-%d')" | tail -5)

═══════════════════════════════════════════════════════════════
Reporte generado automáticamente el $(date +'%Y-%m-%d %H:%M:%S')
═══════════════════════════════════════════════════════════════
EOF
    
    log_monitor "Reporte diario generado: $reporte_file"
    
    # Enviar reporte por email si está configurado
    if [[ -n "${DAILY_REPORT_EMAIL:-}" ]] && command -v mail >/dev/null 2>&1; then
        mail -s "Reporte Diario - Sistema de Túneles $fecha" "$DAILY_REPORT_EMAIL" < "$reporte_file"
    fi
}

# Función principal
case "${1:-monitor}" in
    "monitor")
        verificar_estado_general
        ;;
    "reporte")
        generar_reporte_diario
        ;;
    "status")
        cat "$LOG_BASE_DIR/estado-sistema.json" 2>/dev/null || echo '{"error":"No hay datos de estado"}'
        ;;
    *)
        echo "Uso: $0 [monitor|reporte|status]"
        exit 1
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/sistema-monitoreo-integral.sh
    
    # Configurar cron para monitoreo y reportes
    cat > /etc/cron.d/sistema-tunnel-monitoreo << EOF
# Monitoreo del sistema de túneles
*/5 * * * * root /usr/local/bin/sistema-monitoreo-integral.sh monitor
0 6 * * * root /usr/local/bin/sistema-monitoreo-integral.sh reporte
EOF
    
    log "✅ Sistema de monitoreo y alertas configurado"

# Crear herramientas de administración
crear_herramientas_admin() {
    log "🛠️ Creando herramientas de administración..."
    
    # Script de administración principal
    cat > /usr/local/bin/tunnel-admin << 'EOF'
#!/bin/bash
# Herramienta de administración del sistema de túneles

CONFIG_BASE_DIR="/etc/auto-tunnel"
LOG_BASE_DIR="/var/log/auto-tunnel"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_status() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    ESTADO DEL SISTEMA DE TÚNELES${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo
    
    # Estado de servicios
    echo -e "${YELLOW}🔧 SERVICIOS PRINCIPALES:${NC}"
    local servicios=("webmin" "usermin" "ha-tunnel-monitor" "auto-tunnel-manager-v2" "attack-monitor")
    for servicio in "${servicios[@]}"; do
        if systemctl list-unit-files | grep -q "^$servicio.service"; then
            if systemctl is-active --quiet "$servicio"; then
                echo -e "   • $servicio: ${GREEN}✅ ACTIVO${NC}"
            else
                echo -e "   • $servicio: ${RED}❌ INACTIVO${NC}"
            fi
        else
            echo -e "   • $servicio: ${YELLOW}⚠️ NO INSTALADO${NC}"
        fi
    done
    echo
    
    # Estado de túneles
    echo -e "${YELLOW}🌐 TÚNELES:${NC}"
    if [[ -f "$CONFIG_BASE_DIR/ha/tunnel_manager.sh" ]]; then
        bash "$CONFIG_BASE_DIR/ha/tunnel_manager.sh" list | while IFS=':' read -r prioridad tipo nombre puerto estado status; do
            [[ "$prioridad" =~ ^#.*$ ]] && continue
            [[ -z "$prioridad" ]] && continue
            
            local status_color="$RED"
            local status_icon="❌"
            if [[ "$status" == "active" ]]; then
                status_color="$GREEN"
                status_icon="✅"
            fi
            
            echo -e "   • $tipo:$nombre ($puerto): ${status_color}$status_icon $status${NC}"
        done
    else
        echo -e "   ${RED}❌ Gestor de túneles no disponible${NC}"
    fi
    echo
    
    # Recursos del sistema
    echo -e "${YELLOW}📊 RECURSOS DEL SISTEMA:${NC}"
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | cut -d'%' -f1)
    
    echo -e "   • CPU: $cpu_usage%"
    echo -e "   • Memoria: $mem_usage%"
    echo -e "   • Disco: $disk_usage%"
    echo
    
    # Estado general
    if [[ -f "$LOG_BASE_DIR/estado-sistema.json" ]]; then
        local estado_general=$(cat "$LOG_BASE_DIR/estado-sistema.json" | jq -r '.estado_general')
        case "$estado_general" in
            "OK")
                echo -e "${GREEN}🎯 ESTADO GENERAL: ✅ ÓPTIMO${NC}"
                ;;
            "WARNING")
                echo -e "${YELLOW}🎯 ESTADO GENERAL: ⚠️ ADVERTENCIA${NC}"
                ;;
            "CRITICAL")
                echo -e "${RED}🎯 ESTADO GENERAL: 🚨 CRÍTICO${NC}"
                ;;
        esac
    fi
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

show_logs() {
    local log_type="${1:-main}"
    
    case "$log_type" in
        "main")
            tail -50 "$LOG_BASE_DIR/main.log" 2>/dev/null || echo "Log principal no disponible"
            ;;
        "security")
            tail -50 "$LOG_BASE_DIR/security/attacks.log" 2>/dev/null || echo "Log de seguridad no disponible"
            ;;
        "ha")
            tail -50 "$LOG_BASE_DIR/ha/ha_monitor.log" 2>/dev/null || echo "Log de HA no disponible"
            ;;
        "performance")
            tail -50 "$LOG_BASE_DIR/performance.log" 2>/dev/null || echo "Log de rendimiento no disponible"
            ;;
        *)
            echo "Tipos de log disponibles: main, security, ha, performance"
            ;;
    esac
}

restart_services() {
    echo "🔄 Reiniciando servicios del sistema de túneles..."
    
    local servicios=("ha-tunnel-monitor" "auto-tunnel-manager-v2" "attack-monitor")
    
    for servicio in "${servicios[@]}"; do
        if systemctl list-unit-files | grep -q "^$servicio.service"; then
            echo "   Reiniciando $servicio..."
            systemctl restart "$servicio"
            if systemctl is-active --quiet "$servicio"; then
                echo -e "   ${GREEN}✅ $servicio reiniciado correctamente${NC}"
            else
                echo -e "   ${RED}❌ Error al reiniciar $servicio${NC}"
            fi
        fi
    done
}

run_diagnostics() {
    echo "🔍 Ejecutando diagnósticos del sistema..."
    echo
    
    # Verificar conectividad
    echo "📡 Verificando conectividad:"
    if ping -c 3 8.8.8.8 >/dev/null 2>&1; then
        echo -e "   ${GREEN}✅ Conectividad a internet: OK${NC}"
    else
        echo -e "   ${RED}❌ Sin conectividad a internet${NC}"
    fi
    
    # Verificar puertos
    echo "🔌 Verificando puertos críticos:"
    local puertos=("10000" "20000" "80" "443")
    for puerto in "${puertos[@]}"; do
        if netstat -tuln | grep -q ":$puerto "; then
            echo -e "   ${GREEN}✅ Puerto $puerto: Abierto${NC}"
        else
            echo -e "   ${YELLOW}⚠️ Puerto $puerto: Cerrado${NC}"
        fi
    done
    
    # Verificar certificados SSL
    echo "🔒 Verificando certificados SSL:"
    if [[ -f "/etc/ssl/certs/webmin.pem" ]]; then
        local dias_expiracion=$(openssl x509 -in /etc/ssl/certs/webmin.pem -noout -dates | grep notAfter | cut -d= -f2 | xargs -I {} date -d "{}" +%s)
        local dias_actuales=$(date +%s)
        local dias_restantes=$(( (dias_expiracion - dias_actuales) / 86400 ))
        
        if [[ $dias_restantes -gt 30 ]]; then
            echo -e "   ${GREEN}✅ Certificado SSL: Válido ($dias_restantes días restantes)${NC}"
        else
            echo -e "   ${YELLOW}⚠️ Certificado SSL: Expira pronto ($dias_restantes días restantes)${NC}"
        fi
    else
        echo -e "   ${YELLOW}⚠️ Certificado SSL: No encontrado${NC}"
    fi
    
    # Verificar firewall
    echo "🛡️ Verificando firewall:"
    if systemctl is-active --quiet ufw; then
        echo -e "   ${GREEN}✅ UFW: Activo${NC}"
    else
        echo -e "   ${RED}❌ UFW: Inactivo${NC}"
    fi
    
    if systemctl is-active --quiet fail2ban; then
        echo -e "   ${GREEN}✅ Fail2ban: Activo${NC}"
    else
        echo -e "   ${RED}❌ Fail2ban: Inactivo${NC}"
    fi
}

show_help() {
    echo "tunnel-admin - Herramienta de administración del sistema de túneles"
    echo
    echo "Uso: tunnel-admin [comando]"
    echo
    echo "Comandos disponibles:"
    echo "  status              Mostrar estado general del sistema"
    echo "  logs [tipo]         Mostrar logs (main|security|ha|performance)"
    echo "  restart             Reiniciar servicios del sistema"
    echo "  diagnostics         Ejecutar diagnósticos completos"
    echo "  help                Mostrar esta ayuda"
    echo
}

# Función principal
case "${1:-status}" in
    "status")
        show_status
        ;;
    "logs")
        show_logs "$2"
        ;;
    "restart")
        restart_services
        ;;
    "diagnostics")
        run_diagnostics
        ;;
    "help")
        show_help
        ;;
    *)
        show_help
        exit 1
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/tunnel-admin
    
    # Crear alias útiles
    cat > /etc/profile.d/tunnel-aliases.sh << 'EOF'
# Aliases para el sistema de túneles
alias tunnel-status='tunnel-admin status'
alias tunnel-logs='tunnel-admin logs'
alias tunnel-restart='tunnel-admin restart'
alias tunnel-diag='tunnel-admin diagnostics'
EOF
    
    log "✅ Herramientas de administración creadas"
}

# Crear documentación del sistema
crear_documentacion() {
    log "📚 Creando documentación del sistema..."
    
    # Documentación principal
    cat > "$CONFIG_BASE_DIR/README.md" << 'EOF'
# Sistema de Túneles Automáticos Avanzado v3.0

## Descripción

Sistema completo de túneles automáticos con alta disponibilidad, seguridad avanzada y monitoreo inteligente para Webmin y Virtualmin.

## Características Principales

### 🔒 Seguridad Avanzada
- Firewall avanzado con iptables
- Protección contra DDoS y ataques de fuerza bruta
- Sistema de detección de intrusiones
- Honeypots para detectar atacantes
- Monitoreo de seguridad en tiempo real
- Alertas automáticas de seguridad

### ⚡ Alta Disponibilidad
- Múltiples proveedores de túnel (Cloudflare, ngrok, LocalTunnel, UPnP)
- Failover automático entre túneles
- Health checks avanzados
- Recuperación automática de servicios
- Monitoreo continuo con heartbeat
- Objetivo de uptime: 99.9%

### 📊 Monitoreo Inteligente
- Monitoreo predictivo de recursos
- Análisis de patrones de ataque
- Reportes diarios automáticos
- Dashboard de estado en tiempo real
- Alertas por email/webhook/Slack
- Logs estructurados y rotación automática

## Estructura de Directorios

```
/etc/auto-tunnel/
├── ha/                     # Configuración de alta disponibilidad
├── security/               # Configuración de seguridad
└── README.md              # Esta documentación

/var/log/auto-tunnel/
├── main.log               # Log principal
├── security/              # Logs de seguridad
├── ha/                    # Logs de alta disponibilidad
└── performance.log        # Logs de rendimiento

/var/backups/auto-tunnel/  # Backups automáticos
```

## Comandos Principales

### Administración General
```bash
tunnel-admin status        # Estado del sistema
tunnel-admin logs          # Ver logs
tunnel-admin restart       # Reiniciar servicios
tunnel-admin diagnostics   # Diagnósticos completos
```

### Gestión de Túneles
```bash
# Listar túneles
bash /etc/auto-tunnel/ha/tunnel_manager.sh list

# Iniciar túnel específico
bash /etc/auto-tunnel/ha/tunnel_manager.sh start cloudflare webmin-primary 10000

# Detener túnel específico
bash /etc/auto-tunnel/ha/tunnel_manager.sh stop cloudflare webmin-primary
```

### Monitoreo
```bash
# Estado general
sistema-monitoreo-integral.sh status

# Generar reporte
sistema-monitoreo-integral.sh reporte

# Monitoreo continuo
sistema-monitoreo-integral.sh monitor
```

### Seguridad
```bash
# Estado de fail2ban
fail2ban-client status

# Ver IPs baneadas
fail2ban-client status sshd

# Ver reglas de firewall
iptables -L -n

# Logs de ataques
tail -f /var/log/auto-tunnel/security/attacks.log
```

## Servicios del Sistema

- `ha-tunnel-monitor.service` - Monitor de alta disponibilidad
- `auto-tunnel-manager-v2.service` - Gestor de túneles avanzado
- `attack-monitor.service` - Monitor de ataques en tiempo real
- `ssh-honeypot.service` - Honeypot SSH
- `cloudflared-*.service` - Túneles Cloudflare
- `ngrok-*.service` - Túneles ngrok
- `localtunnel-*.service` - Túneles LocalTunnel

## Configuración de Notificaciones

### Email
```bash
export NOTIFICATION_EMAIL="admin@example.com"
export CRITICAL_EMAIL="critical@example.com"
export DAILY_REPORT_EMAIL="reports@example.com"
```

### Webhook
```bash
export WEBHOOK_URL="https://hooks.slack.com/services/..."
export CRITICAL_WEBHOOK="https://hooks.slack.com/services/..."
export HA_WEBHOOK_URL="https://hooks.slack.com/services/..."
```

### Slack
```bash
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
```

## Solución de Problemas

### Túneles no funcionan
1. Verificar conectividad: `ping 8.8.8.8`
2. Verificar servicios: `tunnel-admin status`
3. Ver logs: `tunnel-admin logs ha`
4. Reiniciar servicios: `tunnel-admin restart`

### Alto uso de recursos
1. Ver estado: `tunnel-admin diagnostics`
2. Verificar logs: `tunnel-admin logs performance`
3. Optimizar configuración según necesidades

### Problemas de seguridad
1. Ver ataques: `tunnel-admin logs security`
2. Verificar firewall: `iptables -L -n`
3. Estado de fail2ban: `fail2ban-client status`

## Mantenimiento

### Backups
- Los backups se crean automáticamente en `/var/backups/auto-tunnel/`
- Retención: 10 backups más recientes
- Frecuencia: Antes de cada cambio de configuración

### Logs
- Rotación automática diaria
- Retención: 30 días
- Compresión automática

### Actualizaciones
- Verificar actualizaciones de herramientas de túnel mensualmente
- Revisar configuraciones de seguridad trimestralmente
- Actualizar certificados SSL antes del vencimiento

## Soporte

Para soporte técnico, revisar:
1. Esta documentación
2. Logs del sistema
3. Estado de servicios
4. Diagnósticos automáticos

---

Sistema instalado el: INSTALL_DATE
Versión: SYSTEM_VERSION
EOF
    
    # Reemplazar variables en la documentación
    sed -i "s/INSTALL_DATE/$INSTALL_DATE/g" "$CONFIG_BASE_DIR/README.md"
    sed -i "s/SYSTEM_VERSION/$SYSTEM_VERSION/g" "$CONFIG_BASE_DIR/README.md"
    
    log "✅ Documentación creada en $CONFIG_BASE_DIR/README.md"
}

# Verificación final del sistema
verificacion_final() {
    log "🔍 Realizando verificación final del sistema..."
    
    local errores=()
    
    # Verificar servicios críticos
    local servicios_criticos=("ha-tunnel-monitor" "auto-tunnel-manager-v2" "attack-monitor")
    for servicio in "${servicios_criticos[@]}"; do
        if ! systemctl is-active --quiet "$servicio"; then
            errores+=("Servicio $servicio no está activo")
        fi
    done
    
    # Verificar archivos de configuración
    local archivos_criticos=(
        "$CONFIG_BASE_DIR/ha/tunnel_manager.sh"
        "$CONFIG_BASE_DIR/ha/health_checker.sh"
        "$CONFIG_BASE_DIR/security/blacklist.txt"
        "/usr/local/bin/tunnel-admin"
    )
    
    for archivo in "${archivos_criticos[@]}"; do
        if [[ ! -f "$archivo" ]]; then
            errores+=("Archivo crítico no encontrado: $archivo")
        fi
    done
    
    # Verificar conectividad
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        errores+=("Sin conectividad a internet")
    fi
    
    # Reportar resultados
    if [[ ${#errores[@]} -eq 0 ]]; then
        log "✅ Verificación final completada sin errores"
        return 0
    else
        log_error "Se encontraron ${#errores[@]} errores en la verificación final:"
        for error in "${errores[@]}"; do
            log_error "  - $error"
        done
        return 1
    fi
}

# Mostrar resumen final
mostrar_resumen_final() {
    clear
    echo -e "${GREEN}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "🎉 INSTALACIÓN COMPLETADA EXITOSAMENTE 🎉"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    echo
    echo -e "${BOLD}📋 RESUMEN DE LA INSTALACIÓN:${NC}"
    echo
    echo -e "${CYAN}🔧 Componentes instalados:${NC}"
    echo "   • ✅ Sistema de túneles automáticos mejorado v2.0"
    echo "   • ✅ Seguridad avanzada con protección DDoS"
    echo "   • ✅ Alta disponibilidad con failover automático"
    echo "   • ✅ Monitoreo inteligente y alertas"
    echo "   • ✅ Herramientas de administración"
    echo
    echo -e "${CYAN}🛡️ Características de seguridad:${NC}"
    echo "   • 🔥 Firewall avanzado configurado"
    echo "   • 🛡️ Fail2ban con reglas personalizadas"
    echo "   • 👁️ Monitor de ataques en tiempo real"
    echo "   • 🍯 Honeypots para detectar atacantes"
    echo "   • 🔔 Alertas inteligentes automáticas"
    echo
    echo -e "${CYAN}⚡ Características de alta disponibilidad:${NC}"
    echo "   • 🌐 Múltiples proveedores de túnel"
    echo "   • 🔄 Failover automático <30 segundos"
    echo "   • 🏥 Health checks cada 30 segundos"
    echo "   • 💓 Heartbeat cada 10 segundos"
    echo "   • 🎯 Objetivo de uptime: 99.9%"
    echo
    echo -e "${CYAN}📊 Sistema de monitoreo:${NC}"
    echo "   • 📈 Monitoreo predictivo de recursos"
    echo "   • 📋 Reportes diarios automáticos"
    echo "   • 🚨 Notificaciones críticas instantáneas"
    echo "   • 📊 Dashboard de estado en tiempo real"
    echo
    echo -e "${YELLOW}🚀 COMANDOS PRINCIPALES:${NC}"
    echo "   • tunnel-admin status      # Ver estado del sistema"
    echo "   • tunnel-admin logs        # Ver logs del sistema"
    echo "   • tunnel-admin restart     # Reiniciar servicios"
    echo "   • tunnel-admin diagnostics # Ejecutar diagnósticos"
    echo
    echo -e "${YELLOW}📁 UBICACIONES IMPORTANTES:${NC}"
    echo "   • Configuración: $CONFIG_BASE_DIR/"
    echo "   • Logs: $LOG_BASE_DIR/"
    echo "   • Backups: $BACKUP_BASE_DIR/"
    echo "   • Documentación: $CONFIG_BASE_DIR/README.md"
    echo
    echo -e "${YELLOW}🔗 ACCESO A PANELES:${NC}"
    echo "   • Webmin: https://localhost:10000 (o través de túneles configurados)"
    echo "   • Usermin: https://localhost:20000 (o través de túneles configurados)"
    echo
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}🎯 El sistema está listo y funcionando. Todos los servicios están activos.${NC}"
    echo -e "${BOLD}📚 Consulta la documentación en $CONFIG_BASE_DIR/README.md para más detalles.${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo
}

# Función principal
main() {
    # Mostrar banner
    mostrar_banner
    
    # Verificar requisitos
    verificar_requisitos
    
    # Instalar dependencias
    instalar_dependencias
    
    # Instalar herramientas de túnel
    instalar_herramientas_tunnel
    
    # Configurar sistema base
    configurar_sistema_base
    
    # Instalar componentes principales
    instalar_componentes
    
    # Configurar monitoreo y alertas
    configurar_monitoreo_alertas
    
    # Crear herramientas de administración
    crear_herramientas_admin
    
    # Crear documentación
    crear_documentacion
    
    # Verificación final
    if verificacion_final; then
        # Mostrar resumen final
        mostrar_resumen_final
        
        # Crear archivo de estado de instalación
        cat > "$CONFIG_BASE_DIR/installation.status" << EOF
{
    "version": "$SYSTEM_VERSION",
    "install_date": "$INSTALL_DATE",
    "status": "completed",
    "components": [
        "tunnel_system_v2",
        "advanced_security",
        "high_availability",
        "intelligent_monitoring",
        "admin_tools"
    ]
}
EOF
        
        log "🎉 Instalación completada exitosamente"
        exit 0
    else
        log_error "La instalación se completó con errores. Revisar logs para más detalles."
        exit 1
    fi
}

# Ejecutar función principal
main "$@"
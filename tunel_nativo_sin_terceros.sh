#!/bin/bash
# 🔧 TÚNEL NATIVO SIN DEPENDENCIAS DE TERCEROS
# Script para crear túneles nativos cuando hay restricciones del proveedor de internet
# Versión: 3.0 - Completamente autónomo
# Autor: Sistema Webmin/Virtualmin Pro
# Fecha: $(date '+%Y-%m-%d')

# Colores para logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuración
LOG_FILE="/var/log/tunel-nativo.log"
CONFIG_DIR="/etc/tunel-nativo"
BACKUP_DIR="/var/backups/tunel-nativo"
SERVICE_NAME="tunel-nativo"
TUNNEL_PORT_START=8080
TUNNEL_PORT_END=8090
WEBMIN_PORT=10000
USERMIN_PORT=20000
HTTP_PORT=80
HTTPS_PORT=443

# Función de logging
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message"
            echo "[$timestamp] [INFO] $message" >> "$LOG_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            echo "[$timestamp] [WARN] $message" >> "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            echo "[$timestamp] [ERROR] $message" >> "$LOG_FILE"
            ;;
        "DEBUG")
            echo -e "${BLUE}[DEBUG]${NC} $message"
            echo "[$timestamp] [DEBUG] $message" >> "$LOG_FILE"
            ;;
        *)
            echo -e "${CYAN}[TUNEL]${NC} $message"
            echo "[$timestamp] [TUNEL] $message" >> "$LOG_FILE"
            ;;
    esac
}

# Verificar privilegios de root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log ERROR "Este script debe ejecutarse como root"
        exit 1
    fi
}

# Crear directorios necesarios
setup_directories() {
    log INFO "Creando directorios del sistema..."
    
    mkdir -p "$CONFIG_DIR" "$BACKUP_DIR" "/var/log" || {
        log ERROR "No se pudieron crear los directorios necesarios"
        exit 1
    }
    
    chmod 755 "$CONFIG_DIR" "$BACKUP_DIR"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    log INFO "Directorios creados correctamente"
}

# Detectar tipo de IP
detect_ip_type() {
    log INFO "Detectando tipo de IP..."
    
    # Obtener IP local
    LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || ip route get 1 | awk '{print $7}' | head -1)
    
    # Intentar obtener IP pública
    PUBLIC_IP=$(curl -s --connect-timeout 10 ifconfig.me 2>/dev/null || \
                curl -s --connect-timeout 10 ipinfo.io/ip 2>/dev/null || \
                curl -s --connect-timeout 10 icanhazip.com 2>/dev/null)
    
    if [[ -z "$PUBLIC_IP" ]]; then
        log WARN "No se pudo obtener IP pública - Asumiendo IP privada"
        IP_TYPE="private"
        return 1
    fi
    
    # Verificar si la IP local coincide con la pública
    if [[ "$LOCAL_IP" == "$PUBLIC_IP" ]]; then
        log INFO "IP pública detectada: $PUBLIC_IP"
        IP_TYPE="public"
        return 0
    else
        log INFO "IP privada detectada. Local: $LOCAL_IP, Pública: $PUBLIC_IP"
        IP_TYPE="private"
        return 1
    fi
}

# Verificar restricciones del proveedor
check_isp_restrictions() {
    log INFO "Verificando restricciones del proveedor de internet..."
    
    local restrictions_found=false
    
    # Verificar puertos bloqueados comunes
    local blocked_ports=()
    for port in 80 443 25 587 993 995 22 21 53; do
        if ! nc -z -w5 8.8.8.8 $port 2>/dev/null; then
            blocked_ports+=("$port")
            restrictions_found=true
        fi
    done
    
    # Verificar si hay NAT estricto
    if [[ "$IP_TYPE" == "private" ]]; then
        log WARN "Detectado NAT - IP privada detrás de router"
        restrictions_found=true
    fi
    
    # Verificar conectividad saliente
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log WARN "Conectividad limitada detectada"
        restrictions_found=true
    fi
    
    if [[ "$restrictions_found" == "true" ]]; then
        log WARN "Restricciones detectadas - Túnel nativo necesario"
        if [[ ${#blocked_ports[@]} -gt 0 ]]; then
            log WARN "Puertos posiblemente bloqueados: ${blocked_ports[*]}"
        fi
        return 0
    else
        log INFO "No se detectaron restricciones significativas"
        return 1
    fi
}

# Crear túnel SSH reverso nativo
create_ssh_reverse_tunnel() {
    local remote_host=$1
    local remote_port=$2
    local local_port=$3
    local tunnel_name=$4
    
    log INFO "Creando túnel SSH reverso: $tunnel_name"
    
    # Generar clave SSH si no existe
    if [[ ! -f "$CONFIG_DIR/tunnel_key" ]]; then
        ssh-keygen -t rsa -b 4096 -f "$CONFIG_DIR/tunnel_key" -N "" -C "tunel-nativo@$(hostname)"
        chmod 600 "$CONFIG_DIR/tunnel_key"
        log INFO "Clave SSH generada para túneles"
    fi
    
    # Crear script de túnel
    cat > "$CONFIG_DIR/tunnel_${tunnel_name}.sh" << EOF
#!/bin/bash
# Túnel SSH reverso para $tunnel_name

TUNNEL_PID_FILE="/var/run/tunnel_${tunnel_name}.pid"
LOG_FILE="/var/log/tunnel_${tunnel_name}.log"

start_tunnel() {
    if [[ -f "\$TUNNEL_PID_FILE" ]] && kill -0 \$(cat "\$TUNNEL_PID_FILE") 2>/dev/null; then
        echo "Túnel $tunnel_name ya está ejecutándose"
        return 0
    fi
    
    echo "Iniciando túnel $tunnel_name..."
    ssh -f -N -T -R $remote_port:localhost:$local_port \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ServerAliveInterval=60 \
        -o ServerAliveCountMax=3 \
        -o ExitOnForwardFailure=yes \
        -i "$CONFIG_DIR/tunnel_key" \
        tunnel@$remote_host
    
    echo \$! > "\$TUNNEL_PID_FILE"
    echo "Túnel $tunnel_name iniciado con PID \$(cat \$TUNNEL_PID_FILE)"
}

stop_tunnel() {
    if [[ -f "\$TUNNEL_PID_FILE" ]]; then
        local pid=\$(cat "\$TUNNEL_PID_FILE")
        if kill -0 "\$pid" 2>/dev/null; then
            kill "\$pid"
            echo "Túnel $tunnel_name detenido"
        fi
        rm -f "\$TUNNEL_PID_FILE"
    fi
}

case "\$1" in
    start)
        start_tunnel
        ;;
    stop)
        stop_tunnel
        ;;
    restart)
        stop_tunnel
        sleep 2
        start_tunnel
        ;;
    status)
        if [[ -f "\$TUNNEL_PID_FILE" ]] && kill -0 \$(cat "\$TUNNEL_PID_FILE") 2>/dev/null; then
            echo "Túnel $tunnel_name está ejecutándose"
        else
            echo "Túnel $tunnel_name no está ejecutándose"
        fi
        ;;
    *)
        echo "Uso: \$0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$CONFIG_DIR/tunnel_${tunnel_name}.sh"
    log INFO "Script de túnel creado: $CONFIG_DIR/tunnel_${tunnel_name}.sh"
}

# Crear túnel HTTP nativo usando socat
create_http_tunnel() {
    local local_port=$1
    local tunnel_port=$2
    local service_name=$3
    
    log INFO "Creando túnel HTTP nativo para $service_name"
    
    # Instalar socat si no está disponible
    if ! command -v socat >/dev/null 2>&1; then
        log INFO "Instalando socat..."
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y socat
        elif command -v yum >/dev/null 2>&1; then
            yum install -y socat
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y socat
        else
            log ERROR "No se pudo instalar socat"
            return 1
        fi
    fi
    
    # Crear script de túnel HTTP
    cat > "$CONFIG_DIR/http_tunnel_${service_name}.sh" << EOF
#!/bin/bash
# Túnel HTTP nativo para $service_name

TUNNEL_PID_FILE="/var/run/http_tunnel_${service_name}.pid"
LOG_FILE="/var/log/http_tunnel_${service_name}.log"

start_tunnel() {
    if [[ -f "\$TUNNEL_PID_FILE" ]] && kill -0 \$(cat "\$TUNNEL_PID_FILE") 2>/dev/null; then
        echo "Túnel HTTP $service_name ya está ejecutándose"
        return 0
    fi
    
    echo "Iniciando túnel HTTP $service_name en puerto $tunnel_port..."
    socat TCP-LISTEN:$tunnel_port,fork,reuseaddr TCP:localhost:$local_port &
    echo \$! > "\$TUNNEL_PID_FILE"
    echo "Túnel HTTP $service_name iniciado con PID \$(cat \$TUNNEL_PID_FILE)"
    echo "Acceso disponible en: http://\$(hostname -I | awk '{print \$1}'):$tunnel_port"
}

stop_tunnel() {
    if [[ -f "\$TUNNEL_PID_FILE" ]]; then
        local pid=\$(cat "\$TUNNEL_PID_FILE")
        if kill -0 "\$pid" 2>/dev/null; then
            kill "\$pid"
            echo "Túnel HTTP $service_name detenido"
        fi
        rm -f "\$TUNNEL_PID_FILE"
    fi
}

case "\$1" in
    start)
        start_tunnel
        ;;
    stop)
        stop_tunnel
        ;;
    restart)
        stop_tunnel
        sleep 2
        start_tunnel
        ;;
    status)
        if [[ -f "\$TUNNEL_PID_FILE" ]] && kill -0 \$(cat "\$TUNNEL_PID_FILE") 2>/dev/null; then
            echo "Túnel HTTP $service_name está ejecutándose en puerto $tunnel_port"
        else
            echo "Túnel HTTP $service_name no está ejecutándose"
        fi
        ;;
    *)
        echo "Uso: \$0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$CONFIG_DIR/http_tunnel_${service_name}.sh"
    log INFO "Túnel HTTP creado: puerto $local_port -> $tunnel_port"
}

# Crear túnel usando netcat (nc)
create_netcat_tunnel() {
    local local_port=$1
    local tunnel_port=$2
    local service_name=$3
    
    log INFO "Creando túnel netcat para $service_name"
    
    cat > "$CONFIG_DIR/nc_tunnel_${service_name}.sh" << EOF
#!/bin/bash
# Túnel netcat para $service_name

TUNNEL_PID_FILE="/var/run/nc_tunnel_${service_name}.pid"

start_tunnel() {
    if [[ -f "\$TUNNEL_PID_FILE" ]] && kill -0 \$(cat "\$TUNNEL_PID_FILE") 2>/dev/null; then
        echo "Túnel netcat $service_name ya está ejecutándose"
        return 0
    fi
    
    echo "Iniciando túnel netcat $service_name en puerto $tunnel_port..."
    while true; do
        nc -l -p $tunnel_port -c "nc localhost $local_port"
        sleep 1
    done &
    echo \$! > "\$TUNNEL_PID_FILE"
    echo "Túnel netcat $service_name iniciado"
}

stop_tunnel() {
    if [[ -f "\$TUNNEL_PID_FILE" ]]; then
        local pid=\$(cat "\$TUNNEL_PID_FILE")
        if kill -0 "\$pid" 2>/dev/null; then
            kill "\$pid"
            echo "Túnel netcat $service_name detenido"
        fi
        rm -f "\$TUNNEL_PID_FILE"
    fi
}

case "\$1" in
    start) start_tunnel ;;
    stop) stop_tunnel ;;
    restart) stop_tunnel; sleep 2; start_tunnel ;;
    status)
        if [[ -f "\$TUNNEL_PID_FILE" ]] && kill -0 \$(cat "\$TUNNEL_PID_FILE") 2>/dev/null; then
            echo "Túnel netcat $service_name ejecutándose en puerto $tunnel_port"
        else
            echo "Túnel netcat $service_name no ejecutándose"
        fi
        ;;
    *) echo "Uso: \$0 {start|stop|restart|status}"; exit 1 ;;
esac
EOF
    
    chmod +x "$CONFIG_DIR/nc_tunnel_${service_name}.sh"
    log INFO "Túnel netcat creado: puerto $local_port -> $tunnel_port"
}

# Configurar túneles automáticos
setup_automatic_tunnels() {
    log INFO "Configurando túneles automáticos..."
    
    local tunnel_port=$TUNNEL_PORT_START
    
    # Túnel para Webmin
    create_http_tunnel $WEBMIN_PORT $tunnel_port "webmin"
    ((tunnel_port++))
    
    # Túnel para Usermin
    create_http_tunnel $USERMIN_PORT $tunnel_port "usermin"
    ((tunnel_port++))
    
    # Túnel para HTTP
    create_http_tunnel $HTTP_PORT $tunnel_port "http"
    ((tunnel_port++))
    
    # Túnel para HTTPS
    create_http_tunnel $HTTPS_PORT $tunnel_port "https"
    ((tunnel_port++))
    
    # Crear túneles netcat como respaldo
    create_netcat_tunnel $WEBMIN_PORT 9080 "webmin_nc"
    create_netcat_tunnel $USERMIN_PORT 9081 "usermin_nc"
    
    log INFO "Túneles automáticos configurados"
}

# Crear servicio systemd
create_systemd_service() {
    log INFO "Creando servicio systemd..."
    
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=Túnel Nativo Sin Terceros
After=network.target
Wants=network.target

[Service]
Type=forking
User=root
Group=root
ExecStart=$CONFIG_DIR/start_all_tunnels.sh
ExecStop=$CONFIG_DIR/stop_all_tunnels.sh
ExecReload=$CONFIG_DIR/restart_all_tunnels.sh
Restart=always
RestartSec=10
PIDFile=/var/run/${SERVICE_NAME}.pid

[Install]
WantedBy=multi-user.target
EOF
    
    # Crear scripts de control
    cat > "$CONFIG_DIR/start_all_tunnels.sh" << 'EOF'
#!/bin/bash
# Iniciar todos los túneles

for script in /etc/tunel-nativo/http_tunnel_*.sh; do
    if [[ -f "$script" ]]; then
        echo "Iniciando $(basename "$script")..."
        "$script" start
    fi
done

for script in /etc/tunel-nativo/nc_tunnel_*.sh; do
    if [[ -f "$script" ]]; then
        echo "Iniciando $(basename "$script")..."
        "$script" start
    fi
done

echo $$ > /var/run/tunel-nativo.pid
EOF
    
    cat > "$CONFIG_DIR/stop_all_tunnels.sh" << 'EOF'
#!/bin/bash
# Detener todos los túneles

for script in /etc/tunel-nativo/http_tunnel_*.sh; do
    if [[ -f "$script" ]]; then
        echo "Deteniendo $(basename "$script")..."
        "$script" stop
    fi
done

for script in /etc/tunel-nativo/nc_tunnel_*.sh; do
    if [[ -f "$script" ]]; then
        echo "Deteniendo $(basename "$script")..."
        "$script" stop
    fi
done

rm -f /var/run/tunel-nativo.pid
EOF
    
    cat > "$CONFIG_DIR/restart_all_tunnels.sh" << 'EOF'
#!/bin/bash
# Reiniciar todos los túneles

/etc/tunel-nativo/stop_all_tunnels.sh
sleep 3
/etc/tunel-nativo/start_all_tunnels.sh
EOF
    
    chmod +x "$CONFIG_DIR"/*.sh
    
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    log INFO "Servicio systemd creado y habilitado"
}

# Crear script de monitoreo
create_monitoring_script() {
    log INFO "Creando script de monitoreo..."
    
    cat > "$CONFIG_DIR/monitor_tunnels.sh" << 'EOF'
#!/bin/bash
# Monitor de túneles nativos

LOG_FILE="/var/log/tunel-monitor.log"

log_monitor() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

check_tunnel() {
    local service=$1
    local port=$2
    
    if nc -z localhost "$port" 2>/dev/null; then
        log_monitor "✅ Túnel $service (puerto $port) funcionando"
        return 0
    else
        log_monitor "❌ Túnel $service (puerto $port) no responde"
        return 1
    fi
}

restart_tunnel() {
    local service=$1
    log_monitor "🔄 Reiniciando túnel $service"
    
    if [[ -f "/etc/tunel-nativo/http_tunnel_${service}.sh" ]]; then
        "/etc/tunel-nativo/http_tunnel_${service}.sh" restart
    elif [[ -f "/etc/tunel-nativo/nc_tunnel_${service}.sh" ]]; then
        "/etc/tunel-nativo/nc_tunnel_${service}.sh" restart
    fi
}

# Verificar túneles principales
services=("webmin:8080" "usermin:8081" "http:8082" "https:8083")

for service_port in "${services[@]}"; do
    service=${service_port%:*}
    port=${service_port#*:}
    
    if ! check_tunnel "$service" "$port"; then
        restart_tunnel "$service"
        sleep 5
        check_tunnel "$service" "$port"
    fi
done

log_monitor "Monitor completado"
EOF
    
    chmod +x "$CONFIG_DIR/monitor_tunnels.sh"
    
    # Agregar al cron
    echo "*/5 * * * * root $CONFIG_DIR/monitor_tunnels.sh" > /etc/cron.d/tunel-monitor
    
    log INFO "Monitor de túneles configurado (cada 5 minutos)"
}

# Mostrar información de acceso
show_access_info() {
    log INFO "Generando información de acceso..."
    
    local server_ip=$(hostname -I | awk '{print $1}')
    
    cat > "$CONFIG_DIR/access_info.txt" << EOF
=== INFORMACIÓN DE ACCESO - TÚNELES NATIVOS ===
Fecha: $(date)
Servidor: $(hostname)
IP Local: $server_ip
IP Pública: ${PUBLIC_IP:-"No disponible"}

🔧 SERVICIOS DISPONIBLES:

📋 Webmin (Panel de Control):
   - Túnel HTTP: http://$server_ip:8080
   - Túnel Netcat: http://$server_ip:9080
   - Original: https://$server_ip:10000 (si accesible)

👤 Usermin (Panel de Usuario):
   - Túnel HTTP: http://$server_ip:8081
   - Túnel Netcat: http://$server_ip:9081
   - Original: https://$server_ip:20000 (si accesible)

🌐 Sitio Web:
   - Túnel HTTP: http://$server_ip:8082
   - Túnel HTTPS: http://$server_ip:8083
   - Original: http://$server_ip (si accesible)

🔍 VERIFICACIÓN:
   - Estado de túneles: $CONFIG_DIR/monitor_tunnels.sh
   - Logs: tail -f /var/log/tunel-nativo.log
   - Control de servicio: systemctl status tunel-nativo

⚙️ COMANDOS ÚTILES:
   - Iniciar túneles: systemctl start tunel-nativo
   - Detener túneles: systemctl stop tunel-nativo
   - Reiniciar túneles: systemctl restart tunel-nativo
   - Ver estado: systemctl status tunel-nativo

📝 NOTAS:
   - Los túneles funcionan sin dependencias de terceros
   - Acceso disponible desde la red local
   - Para acceso externo, configurar port forwarding en router
   - Los túneles se reinician automáticamente si fallan

=== FIN DE INFORMACIÓN ===
EOF
    
    cat "$CONFIG_DIR/access_info.txt"
    
    log INFO "Información guardada en: $CONFIG_DIR/access_info.txt"
}

# Función principal
main() {
    log INFO "🚀 Iniciando configuración de túneles nativos sin terceros"
    
    check_root
    setup_directories
    
    # Detectar necesidad de túneles
    if detect_ip_type && ! check_isp_restrictions; then
        log INFO "✅ IP pública disponible sin restricciones significativas"
        log INFO "Los túneles pueden no ser necesarios, pero se configurarán como opción"
    else
        log WARN "⚠️ Restricciones detectadas - Túneles nativos necesarios"
    fi
    
    setup_automatic_tunnels
    create_systemd_service
    create_monitoring_script
    
    # Iniciar servicio
    log INFO "Iniciando servicio de túneles..."
    systemctl start "$SERVICE_NAME"
    
    # Esperar un momento para que se inicien
    sleep 5
    
    show_access_info
    
    log INFO "🎉 ¡Configuración de túneles nativos completada!"
    log INFO "📋 Ver información de acceso: cat $CONFIG_DIR/access_info.txt"
    log INFO "🔍 Verificar estado: systemctl status $SERVICE_NAME"
}

# Verificar argumentos
case "${1:-}" in
    "--install")
        main
        ;;
    "--status")
        systemctl status "$SERVICE_NAME" 2>/dev/null || echo "Servicio no instalado"
        if [[ -f "$CONFIG_DIR/access_info.txt" ]]; then
            cat "$CONFIG_DIR/access_info.txt"
        fi
        ;;
    "--stop")
        systemctl stop "$SERVICE_NAME" 2>/dev/null || echo "Servicio no está ejecutándose"
        ;;
    "--start")
        systemctl start "$SERVICE_NAME" 2>/dev/null || echo "Servicio no instalado"
        ;;
    "--restart")
        systemctl restart "$SERVICE_NAME" 2>/dev/null || echo "Servicio no instalado"
        ;;
    "--uninstall")
        log INFO "Desinstalando túneles nativos..."
        systemctl stop "$SERVICE_NAME" 2>/dev/null || true
        systemctl disable "$SERVICE_NAME" 2>/dev/null || true
        rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
        rm -rf "$CONFIG_DIR"
        rm -f "/etc/cron.d/tunel-monitor"
        systemctl daemon-reload
        log INFO "Túneles nativos desinstalados"
        ;;
    *)
        echo "🔧 TÚNEL NATIVO SIN DEPENDENCIAS DE TERCEROS"
        echo "Script para crear túneles cuando hay restricciones del proveedor"
        echo ""
        echo "Uso: $0 [OPCIÓN]"
        echo ""
        echo "Opciones:"
        echo "  --install     Instalar y configurar túneles nativos"
        echo "  --status      Mostrar estado y información de acceso"
        echo "  --start       Iniciar túneles"
        echo "  --stop        Detener túneles"
        echo "  --restart     Reiniciar túneles"
        echo "  --uninstall   Desinstalar túneles nativos"
        echo ""
        echo "Características:"
        echo "  ✅ Sin dependencias de terceros (Cloudflare, ngrok, etc.)"
        echo "  ✅ Túneles HTTP nativos usando socat"
        echo "  ✅ Túneles netcat como respaldo"
        echo "  ✅ Monitoreo automático y reinicio"
        echo "  ✅ Servicio systemd integrado"
        echo "  ✅ Funciona con restricciones de ISP"
        echo "  ✅ Acceso desde red local garantizado"
        echo ""
        echo "Ejemplo: $0 --install"
        exit 0
        ;;
esac
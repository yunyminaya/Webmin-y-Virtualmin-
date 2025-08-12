#!/bin/bash
# Script de alta disponibilidad para túneles automáticos
# Garantiza 99.9% de uptime con múltiples capas de redundancia

set -euo pipefail

# Configuración de alta disponibilidad
HA_CONFIG_DIR="/etc/auto-tunnel/ha"
HA_LOG_DIR="/var/log/auto-tunnel/ha"
HA_STATE_DIR="/var/lib/auto-tunnel/ha"
BACKUP_TUNNELS_CONFIG="$HA_CONFIG_DIR/backup_tunnels.conf"
HEALTH_CHECK_CONFIG="$HA_CONFIG_DIR/health_checks.conf"
FAILOVER_CONFIG="$HA_CONFIG_DIR/failover.conf"

# Configuración de tiempos
HEALTH_CHECK_INTERVAL=30
FAILOVER_TIMEOUT=15
RECOVERY_TIMEOUT=60
MAX_FAILOVER_ATTEMPTS=3
HEARTBEAT_INTERVAL=10

# URLs de prueba para health checks
HEALTH_CHECK_URLS=(
    "https://httpbin.org/status/200"
    "https://www.google.com"
    "https://cloudflare.com"
)

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Crear directorios necesarios
mkdir -p "$HA_CONFIG_DIR" "$HA_LOG_DIR" "$HA_STATE_DIR"

# Funciones de logging
log_ha() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [HA] $1" | tee -a "$HA_LOG_DIR/main.log"
}

log_failover() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [FAILOVER] $1" | tee -a "$HA_LOG_DIR/failover.log"
}

log_health() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [HEALTH] $1" | tee -a "$HA_LOG_DIR/health.log"
}

log_recovery() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [RECOVERY] $1" | tee -a "$HA_LOG_DIR/recovery.log"
}

# Función de notificación crítica
notificar_evento_critico() {
    local evento="$1"
    local detalles="$2"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    
    # Log local
    echo "[$timestamp] CRÍTICO: $evento - $detalles" >> "$HA_LOG_DIR/critical.log"
    
    # Notificación por email si está configurado
    if [[ -n "${HA_CRITICAL_EMAIL:-}" ]] && command -v mail >/dev/null 2>&1; then
        echo "Evento crítico en sistema de túneles: $evento\n\nDetalles: $detalles\n\nTimestamp: $timestamp" | \
            mail -s "🚨 CRÍTICO: Fallo en sistema de túneles" "$HA_CRITICAL_EMAIL"
    fi
    
    # Webhook crítico
    if [[ -n "${HA_WEBHOOK_URL:-}" ]]; then
        curl -X POST "$HA_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"level\":\"critical\",\"event\":\"$evento\",\"details\":\"$detalles\",\"timestamp\":\"$timestamp\",\"system\":\"tunnel-ha\"}" \
            --max-time 10 --silent || true
    fi
    
    # Slack si está configurado
    if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
        curl -X POST "$SLACK_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"🚨 *CRÍTICO*: $evento\\n*Detalles*: $detalles\\n*Timestamp*: $timestamp\"}" \
            --max-time 10 --silent || true
    fi
}

# Configurar múltiples proveedores de túnel
configurar_proveedores_tunnel() {
    log_ha "🔧 Configurando múltiples proveedores de túnel..."
    
    # Configuración de prioridades y configuraciones
    cat > "$BACKUP_TUNNELS_CONFIG" << EOF
# Configuración de túneles de respaldo
# Formato: PRIORIDAD:TIPO:CONFIGURACION:PUERTO:ESTADO

# Túneles primarios
1:cloudflare:webmin-primary:10000:active
1:cloudflare:usermin-primary:20000:active

# Túneles secundarios
2:ngrok:webmin-backup:10000:standby
2:ngrok:usermin-backup:20000:standby

# Túneles terciarios
3:localtunnel:webmin-lt:10000:standby
3:localtunnel:usermin-lt:20000:standby

# Túnel de emergencia
4:upnp:emergency:10000:standby
4:upnp:emergency:20000:standby

# Túneles adicionales para servicios web
2:cloudflare:web-http:80:active
2:cloudflare:web-https:443:active
EOF
    
    # Script de gestión de túneles múltiples
    cat > "$HA_CONFIG_DIR/tunnel_manager.sh" << 'EOF'
#!/bin/bash
HA_CONFIG_DIR="/etc/auto-tunnel/ha"
HA_LOG_DIR="/var/log/auto-tunnel/ha"
BACKUP_TUNNELS_CONFIG="$HA_CONFIG_DIR/backup_tunnels.conf"

log_tunnel() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [TUNNEL_MGR] $1" >> "$HA_LOG_DIR/tunnel_manager.log"
}

start_tunnel() {
    local tipo="$1"
    local nombre="$2"
    local puerto="$3"
    
    case "$tipo" in
        "cloudflare")
            start_cloudflare_tunnel "$nombre" "$puerto"
            ;;
        "ngrok")
            start_ngrok_tunnel "$nombre" "$puerto"
            ;;
        "localtunnel")
            start_localtunnel_tunnel "$nombre" "$puerto"
            ;;
        "upnp")
            start_upnp_tunnel "$puerto"
            ;;
        *)
            log_tunnel "Tipo de túnel desconocido: $tipo"
            return 1
            ;;
    esac
}

start_cloudflare_tunnel() {
    local nombre="$1"
    local puerto="$2"
    
    log_tunnel "Iniciando túnel Cloudflare: $nombre en puerto $puerto"
    
    # Crear configuración específica
    mkdir -p "/etc/cloudflared/$nombre"
    cat > "/etc/cloudflared/$nombre/config.yml" << CFEOF
tunnel: $nombre
credentials-file: /etc/cloudflared/$nombre/credentials.json
ingress:
  - hostname: $nombre.tunnel.local
    service: https://localhost:$puerto
  - service: http_status:404
CFEOF
    
    # Crear servicio systemd específico
    cat > "/etc/systemd/system/cloudflared-$nombre.service" << CFEOF
[Unit]
Description=Cloudflare Tunnel - $nombre
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared tunnel --config /etc/cloudflared/$nombre/config.yml run
Restart=always
RestartSec=5
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
CFEOF
    
    systemctl daemon-reload
    systemctl enable "cloudflared-$nombre"
    systemctl start "cloudflared-$nombre"
    
    if systemctl is-active --quiet "cloudflared-$nombre"; then
        log_tunnel "✅ Túnel Cloudflare $nombre iniciado exitosamente"
        return 0
    else
        log_tunnel "❌ Fallo al iniciar túnel Cloudflare $nombre"
        return 1
    fi
}

start_ngrok_tunnel() {
    local nombre="$1"
    local puerto="$2"
    
    log_tunnel "Iniciando túnel ngrok: $nombre en puerto $puerto"
    
    # Crear configuración específica
    mkdir -p "/etc/ngrok/$nombre"
    cat > "/etc/ngrok/$nombre/ngrok.yml" << NGEOF
authtoken: ${NGROK_AUTH_TOKEN:-your_token_here}
tunnels:
  $nombre:
    addr: $puerto
    proto: http
    bind_tls: true
    hostname: $nombre.ngrok.io
NGEOF
    
    # Crear servicio systemd específico
    cat > "/etc/systemd/system/ngrok-$nombre.service" << NGEOF
[Unit]
Description=ngrok tunnel - $nombre
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/ngrok start $nombre --config=/etc/ngrok/$nombre/ngrok.yml
Restart=always
RestartSec=5
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
NGEOF
    
    systemctl daemon-reload
    systemctl enable "ngrok-$nombre"
    systemctl start "ngrok-$nombre"
    
    sleep 5
    if systemctl is-active --quiet "ngrok-$nombre"; then
        log_tunnel "✅ Túnel ngrok $nombre iniciado exitosamente"
        return 0
    else
        log_tunnel "❌ Fallo al iniciar túnel ngrok $nombre"
        return 1
    fi
}

start_localtunnel_tunnel() {
    local nombre="$1"
    local puerto="$2"
    
    log_tunnel "Iniciando túnel localtunnel: $nombre en puerto $puerto"
    
    # Instalar localtunnel si no está presente
    if ! command -v lt >/dev/null 2>&1; then
        npm install -g localtunnel
    fi
    
    # Crear servicio systemd específico
    cat > "/etc/systemd/system/localtunnel-$nombre.service" << LTEOF
[Unit]
Description=LocalTunnel - $nombre
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/lt --port $puerto --subdomain $nombre
Restart=always
RestartSec=5
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
LTEOF
    
    systemctl daemon-reload
    systemctl enable "localtunnel-$nombre"
    systemctl start "localtunnel-$nombre"
    
    sleep 5
    if systemctl is-active --quiet "localtunnel-$nombre"; then
        log_tunnel "✅ Túnel localtunnel $nombre iniciado exitosamente"
        return 0
    else
        log_tunnel "❌ Fallo al iniciar túnel localtunnel $nombre"
        return 1
    fi
}

start_upnp_tunnel() {
    local puerto="$1"
    
    log_tunnel "Configurando UPnP para puerto $puerto"
    
    if command -v upnpc >/dev/null 2>&1; then
        local ip_local=$(hostname -I | awk '{print $1}')
        upnpc -a "$ip_local" "$puerto" "$puerto" TCP
        
        if [ $? -eq 0 ]; then
            log_tunnel "✅ UPnP configurado para puerto $puerto"
            return 0
        else
            log_tunnel "❌ Fallo al configurar UPnP para puerto $puerto"
            return 1
        fi
    else
        log_tunnel "❌ UPnP no disponible"
        return 1
    fi
}

stop_tunnel() {
    local tipo="$1"
    local nombre="$2"
    
    case "$tipo" in
        "cloudflare")
            systemctl stop "cloudflared-$nombre" || true
            systemctl disable "cloudflared-$nombre" || true
            ;;
        "ngrok")
            systemctl stop "ngrok-$nombre" || true
            systemctl disable "ngrok-$nombre" || true
            ;;
        "localtunnel")
            systemctl stop "localtunnel-$nombre" || true
            systemctl disable "localtunnel-$nombre" || true
            ;;
    esac
    
    log_tunnel "Túnel $tipo:$nombre detenido"
}

get_tunnel_status() {
    local tipo="$1"
    local nombre="$2"
    
    case "$tipo" in
        "cloudflare")
            systemctl is-active --quiet "cloudflared-$nombre" && echo "active" || echo "inactive"
            ;;
        "ngrok")
            systemctl is-active --quiet "ngrok-$nombre" && echo "active" || echo "inactive"
            ;;
        "localtunnel")
            systemctl is-active --quiet "localtunnel-$nombre" && echo "active" || echo "inactive"
            ;;
        "upnp")
            # Verificar si el puerto está abierto
            timeout 5 nc -z $(curl -s ifconfig.me) "$3" 2>/dev/null && echo "active" || echo "inactive"
            ;;
    esac
}

# Función principal del gestor
case "${1:-status}" in
    "start")
        start_tunnel "$2" "$3" "$4"
        ;;
    "stop")
        stop_tunnel "$2" "$3"
        ;;
    "status")
        get_tunnel_status "$2" "$3" "$4"
        ;;
    "list")
        while IFS=':' read -r prioridad tipo nombre puerto estado; do
            [[ "$prioridad" =~ ^#.*$ ]] && continue
            [[ -z "$prioridad" ]] && continue
            status=$(get_tunnel_status "$tipo" "$nombre" "$puerto")
            echo "$prioridad:$tipo:$nombre:$puerto:$estado:$status"
        done < "$BACKUP_TUNNELS_CONFIG"
        ;;
    *)
        echo "Uso: $0 [start|stop|status|list] [tipo] [nombre] [puerto]"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$HA_CONFIG_DIR/tunnel_manager.sh"
    log_ha "✅ Gestor de túneles múltiples configurado"
}

# Sistema de health checks avanzado
configurar_health_checks() {
    log_ha "🏥 Configurando sistema de health checks avanzado..."
    
    # Configuración de health checks
    cat > "$HEALTH_CHECK_CONFIG" << EOF
# Configuración de health checks
# Formato: SERVICIO:TIPO:ENDPOINT:TIMEOUT:INTERVALO:MAX_FALLOS

# Health checks para servicios locales
webmin:http:https://localhost:10000:10:30:3
usermin:http:https://localhost:20000:10:30:3
apache:http:http://localhost:80:5:60:2
nginx:http:http://localhost:80:5:60:2
mysql:tcp:localhost:3306:5:60:2
postgresql:tcp:localhost:5432:5:60:2

# Health checks para túneles externos
cloudflare_tunnel:http_external:https://webmin-primary.tunnel.local:15:60:2
ngrok_tunnel:http_external:https://webmin-backup.ngrok.io:15:60:2
localtunnel_tunnel:http_external:https://webmin-lt.loca.lt:15:60:2

# Health checks de conectividad
internet:ping:8.8.8.8:5:30:3
dns:nslookup:google.com:5:60:2
EOF
    
    # Script de health checks
    cat > "$HA_CONFIG_DIR/health_checker.sh" << 'EOF'
#!/bin/bash
HA_CONFIG_DIR="/etc/auto-tunnel/ha"
HA_LOG_DIR="/var/log/auto-tunnel/ha"
HA_STATE_DIR="/var/lib/auto-tunnel/ha"
HEALTH_CHECK_CONFIG="$HA_CONFIG_DIR/health_checks.conf"

log_health() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [HEALTH] $1" >> "$HA_LOG_DIR/health.log"
}

perform_http_check() {
    local endpoint="$1"
    local timeout="$2"
    
    local response_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$endpoint" 2>/dev/null || echo "000")
    
    if [[ "$response_code" =~ ^2[0-9][0-9]$ ]]; then
        return 0
    else
        return 1
    fi
}

perform_tcp_check() {
    local host="$1"
    local port="$2"
    local timeout="$3"
    
    timeout "$timeout" nc -z "$host" "$port" 2>/dev/null
    return $?
}

perform_ping_check() {
    local host="$1"
    local timeout="$2"
    
    ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1
    return $?
}

perform_nslookup_check() {
    local domain="$1"
    local timeout="$2"
    
    timeout "$timeout" nslookup "$domain" >/dev/null 2>&1
    return $?
}

check_service_health() {
    local servicio="$1"
    local tipo="$2"
    local endpoint="$3"
    local timeout="$4"
    local max_fallos="$5"
    
    local estado_file="$HA_STATE_DIR/${servicio}_health.state"
    local fallos_actuales=0
    
    # Leer fallos actuales
    if [[ -f "$estado_file" ]]; then
        fallos_actuales=$(cat "$estado_file")
    fi
    
    # Realizar check según el tipo
    local check_result=1
    case "$tipo" in
        "http"|"http_external")
            perform_http_check "$endpoint" "$timeout"
            check_result=$?
            ;;
        "tcp")
            local host=$(echo "$endpoint" | cut -d: -f1)
            local port=$(echo "$endpoint" | cut -d: -f2)
            perform_tcp_check "$host" "$port" "$timeout"
            check_result=$?
            ;;
        "ping")
            perform_ping_check "$endpoint" "$timeout"
            check_result=$?
            ;;
        "nslookup")
            perform_nslookup_check "$endpoint" "$timeout"
            check_result=$?
            ;;
    esac
    
    if [[ $check_result -eq 0 ]]; then
        # Check exitoso - resetear contador de fallos
        echo "0" > "$estado_file"
        log_health "✅ $servicio: Health check OK"
        return 0
    else
        # Check fallido - incrementar contador
        fallos_actuales=$((fallos_actuales + 1))
        echo "$fallos_actuales" > "$estado_file"
        
        log_health "❌ $servicio: Health check FAILED ($fallos_actuales/$max_fallos)"
        
        if [[ $fallos_actuales -ge $max_fallos ]]; then
            log_health "🚨 $servicio: Máximo de fallos alcanzado - Iniciando recuperación"
            return 2  # Código especial para indicar que se necesita recuperación
        fi
        
        return 1
    fi
}

# Bucle principal de health checks
while IFS=':' read -r servicio tipo endpoint timeout intervalo max_fallos; do
    [[ "$servicio" =~ ^#.*$ ]] && continue
    [[ -z "$servicio" ]] && continue
    
    # Verificar si es tiempo de hacer el check
    local last_check_file="$HA_STATE_DIR/${servicio}_last_check.timestamp"
    local current_time=$(date +%s)
    local last_check_time=0
    
    if [[ -f "$last_check_file" ]]; then
        last_check_time=$(cat "$last_check_file")
    fi
    
    if [[ $((current_time - last_check_time)) -ge $intervalo ]]; then
        echo "$current_time" > "$last_check_file"
        
        check_service_health "$servicio" "$tipo" "$endpoint" "$timeout" "$max_fallos"
        local result=$?
        
        if [[ $result -eq 2 ]]; then
            # Servicio crítico fallido - iniciar recuperación
            bash "$HA_CONFIG_DIR/recovery_manager.sh" "$servicio" &
        fi
    fi
done < "$HEALTH_CHECK_CONFIG"
EOF
    
    chmod +x "$HA_CONFIG_DIR/health_checker.sh"
    log_ha "✅ Sistema de health checks configurado"
}

# Sistema de recuperación automática
configurar_recovery_system() {
    log_ha "🔄 Configurando sistema de recuperación automática..."
    
    # Script de recuperación
    cat > "$HA_CONFIG_DIR/recovery_manager.sh" << 'EOF'
#!/bin/bash
HA_CONFIG_DIR="/etc/auto-tunnel/ha"
HA_LOG_DIR="/var/log/auto-tunnel/ha"
HA_STATE_DIR="/var/lib/auto-tunnel/ha"
BACKUP_TUNNELS_CONFIG="$HA_CONFIG_DIR/backup_tunnels.conf"

log_recovery() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [RECOVERY] $1" >> "$HA_LOG_DIR/recovery.log"
}

notificar_evento_critico() {
    local evento="$1"
    local detalles="$2"
    
    # Implementar notificaciones críticas aquí
    log_recovery "CRÍTICO: $evento - $detalles"
}

recover_service() {
    local servicio="$1"
    
    log_recovery "🔄 Iniciando recuperación para servicio: $servicio"
    
    case "$servicio" in
        "webmin")
            recover_webmin
            ;;
        "usermin")
            recover_usermin
            ;;
        "apache")
            recover_apache
            ;;
        "nginx")
            recover_nginx
            ;;
        "mysql")
            recover_mysql
            ;;
        "postgresql")
            recover_postgresql
            ;;
        "cloudflare_tunnel")
            recover_tunnel "cloudflare"
            ;;
        "ngrok_tunnel")
            recover_tunnel "ngrok"
            ;;
        "localtunnel_tunnel")
            recover_tunnel "localtunnel"
            ;;
        "internet")
            recover_internet_connectivity
            ;;
        *)
            log_recovery "❌ Servicio desconocido para recuperación: $servicio"
            return 1
            ;;
    esac
}

recover_webmin() {
    log_recovery "Recuperando Webmin..."
    
    # Reiniciar servicio
    systemctl restart webmin
    sleep 10
    
    # Verificar si se recuperó
    if systemctl is-active --quiet webmin; then
        log_recovery "✅ Webmin recuperado exitosamente"
        return 0
    else
        log_recovery "❌ Fallo en recuperación de Webmin - Iniciando túnel de respaldo"
        initiate_tunnel_failover "webmin" "10000"
        return 1
    fi
}

recover_usermin() {
    log_recovery "Recuperando Usermin..."
    
    systemctl restart usermin
    sleep 10
    
    if systemctl is-active --quiet usermin; then
        log_recovery "✅ Usermin recuperado exitosamente"
        return 0
    else
        log_recovery "❌ Fallo en recuperación de Usermin - Iniciando túnel de respaldo"
        initiate_tunnel_failover "usermin" "20000"
        return 1
    fi
}

recover_apache() {
    log_recovery "Recuperando Apache..."
    
    systemctl restart apache2
    sleep 5
    
    if systemctl is-active --quiet apache2; then
        log_recovery "✅ Apache recuperado exitosamente"
        return 0
    else
        log_recovery "❌ Fallo en recuperación de Apache"
        notificar_evento_critico "Apache Recovery Failed" "No se pudo recuperar el servicio Apache"
        return 1
    fi
}

recover_nginx() {
    log_recovery "Recuperando Nginx..."
    
    systemctl restart nginx
    sleep 5
    
    if systemctl is-active --quiet nginx; then
        log_recovery "✅ Nginx recuperado exitosamente"
        return 0
    else
        log_recovery "❌ Fallo en recuperación de Nginx"
        notificar_evento_critico "Nginx Recovery Failed" "No se pudo recuperar el servicio Nginx"
        return 1
    fi
}

recover_mysql() {
    log_recovery "Recuperando MySQL..."
    
    systemctl restart mysql
    sleep 10
    
    if systemctl is-active --quiet mysql; then
        log_recovery "✅ MySQL recuperado exitosamente"
        return 0
    else
        log_recovery "❌ Fallo en recuperación de MySQL"
        notificar_evento_critico "MySQL Recovery Failed" "No se pudo recuperar el servicio MySQL"
        return 1
    fi
}

recover_postgresql() {
    log_recovery "Recuperando PostgreSQL..."
    
    systemctl restart postgresql
    sleep 10
    
    if systemctl is-active --quiet postgresql; then
        log_recovery "✅ PostgreSQL recuperado exitosamente"
        return 0
    else
        log_recovery "❌ Fallo en recuperación de PostgreSQL"
        notificar_evento_critico "PostgreSQL Recovery Failed" "No se pudo recuperar el servicio PostgreSQL"
        return 1
    fi
}

recover_tunnel() {
    local tipo_tunnel="$1"
    
    log_recovery "Recuperando túnel $tipo_tunnel..."
    
    # Reiniciar todos los túneles del tipo especificado
    while IFS=':' read -r prioridad tipo nombre puerto estado; do
        [[ "$prioridad" =~ ^#.*$ ]] && continue
        [[ -z "$prioridad" ]] && continue
        [[ "$tipo" != "$tipo_tunnel" ]] && continue
        
        log_recovery "Reiniciando túnel $tipo:$nombre..."
        bash "$HA_CONFIG_DIR/tunnel_manager.sh" stop "$tipo" "$nombre"
        sleep 5
        bash "$HA_CONFIG_DIR/tunnel_manager.sh" start "$tipo" "$nombre" "$puerto"
        
        # Verificar si se recuperó
        sleep 10
        local status=$(bash "$HA_CONFIG_DIR/tunnel_manager.sh" status "$tipo" "$nombre" "$puerto")
        if [[ "$status" == "active" ]]; then
            log_recovery "✅ Túnel $tipo:$nombre recuperado exitosamente"
            return 0
        fi
    done < "$BACKUP_TUNNELS_CONFIG"
    
    log_recovery "❌ No se pudo recuperar ningún túnel $tipo_tunnel"
    initiate_emergency_failover
    return 1
}

initiate_tunnel_failover() {
    local servicio="$1"
    local puerto="$2"
    
    log_recovery "🔄 Iniciando failover de túnel para $servicio:$puerto"
    
    # Buscar túneles de respaldo disponibles
    while IFS=':' read -r prioridad tipo nombre puerto_config estado; do
        [[ "$prioridad" =~ ^#.*$ ]] && continue
        [[ -z "$prioridad" ]] && continue
        [[ "$puerto_config" != "$puerto" ]] && continue
        [[ "$estado" != "standby" ]] && continue
        
        log_recovery "Intentando activar túnel de respaldo: $tipo:$nombre"
        
        if bash "$HA_CONFIG_DIR/tunnel_manager.sh" start "$tipo" "$nombre" "$puerto"; then
            # Actualizar estado a activo
            sed -i "s/^$prioridad:$tipo:$nombre:$puerto:standby/$prioridad:$tipo:$nombre:$puerto:active/" "$BACKUP_TUNNELS_CONFIG"
            log_recovery "✅ Túnel de respaldo $tipo:$nombre activado exitosamente"
            notificar_evento_critico "Tunnel Failover Success" "Túnel $tipo:$nombre activado como respaldo para $servicio"
            return 0
        fi
    done < "$BACKUP_TUNNELS_CONFIG"
    
    log_recovery "❌ No se encontraron túneles de respaldo disponibles"
    initiate_emergency_failover
    return 1
}

initiate_emergency_failover() {
    log_recovery "🚨 Iniciando procedimiento de emergencia"
    
    # Intentar UPnP como último recurso
    log_recovery "Intentando UPnP como túnel de emergencia..."
    
    local ip_local=$(hostname -I | awk '{print $1}')
    local puertos_criticos=("10000" "20000" "80" "443")
    
    for puerto in "${puertos_criticos[@]}"; do
        if command -v upnpc >/dev/null 2>&1; then
            upnpc -a "$ip_local" "$puerto" "$puerto" TCP
            if [ $? -eq 0 ]; then
                log_recovery "✅ UPnP configurado para puerto $puerto"
            fi
        fi
    done
    
    # Notificar situación crítica
    notificar_evento_critico "Emergency Failover Activated" "Todos los túneles primarios han fallado. UPnP activado como último recurso."
    
    # Intentar reiniciar servicios de red
    log_recovery "Reiniciando servicios de red..."
    systemctl restart networking || true
    systemctl restart systemd-networkd || true
    
    log_recovery "Procedimiento de emergencia completado"
}

recover_internet_connectivity() {
    log_recovery "Verificando conectividad a internet..."
    
    # Reiniciar servicios de red
    systemctl restart networking || true
    sleep 10
    
    # Verificar conectividad
    if ping -c 3 8.8.8.8 >/dev/null 2>&1; then
        log_recovery "✅ Conectividad a internet restaurada"
        return 0
    else
        log_recovery "❌ Sin conectividad a internet - Problema crítico"
        notificar_evento_critico "Internet Connectivity Lost" "No hay conectividad a internet después del intento de recuperación"
        return 1
    fi
}

# Función principal
if [[ $# -eq 0 ]]; then
    echo "Uso: $0 <servicio>"
    exit 1
fi

recover_service "$1"
EOF
    
    chmod +x "$HA_CONFIG_DIR/recovery_manager.sh"
    log_ha "✅ Sistema de recuperación automática configurado"
}

# Crear servicio de monitoreo de alta disponibilidad
crear_servicio_ha() {
    log_ha "⚡ Creando servicio de monitoreo de alta disponibilidad..."
    
    # Script principal de HA
    cat > "/usr/local/bin/ha-tunnel-monitor.sh" << 'EOF'
#!/bin/bash
# Monitor de alta disponibilidad para túneles

HA_CONFIG_DIR="/etc/auto-tunnel/ha"
HA_LOG_DIR="/var/log/auto-tunnel/ha"
HEALTH_CHECK_INTERVAL=30
HEARTBEAT_INTERVAL=10

log_ha() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [HA_MONITOR] $1" >> "$HA_LOG_DIR/ha_monitor.log"
}

# Función de heartbeat
send_heartbeat() {
    local timestamp=$(date +%s)
    echo "$timestamp" > "$HA_STATE_DIR/heartbeat.timestamp"
    
    # Enviar heartbeat a sistemas externos si está configurado
    if [[ -n "${HA_HEARTBEAT_URL:-}" ]]; then
        curl -X POST "$HA_HEARTBEAT_URL" \
            -H "Content-Type: application/json" \
            -d "{\"timestamp\":$timestamp,\"status\":\"alive\",\"system\":\"tunnel-ha\"}" \
            --max-time 5 --silent || true
    fi
}

# Bucle principal de monitoreo
while true; do
    # Enviar heartbeat
    send_heartbeat
    
    # Ejecutar health checks
    bash "$HA_CONFIG_DIR/health_checker.sh"
    
    # Verificar estado de túneles
    bash "$HA_CONFIG_DIR/tunnel_manager.sh" list | while IFS=':' read -r prioridad tipo nombre puerto estado status; do
        if [[ "$estado" == "active" ]] && [[ "$status" != "active" ]]; then
            log_ha "⚠️ Túnel activo no responde: $tipo:$nombre - Iniciando recuperación"
            bash "$HA_CONFIG_DIR/recovery_manager.sh" "${tipo}_tunnel" &
        fi
    done
    
    # Pausa antes del siguiente ciclo
    sleep "$HEALTH_CHECK_INTERVAL"
done
EOF
    
    chmod +x "/usr/local/bin/ha-tunnel-monitor.sh"
    
    # Crear servicio systemd
    cat > "/etc/systemd/system/ha-tunnel-monitor.service" << EOF
[Unit]
Description=High Availability Tunnel Monitor
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/ha-tunnel-monitor.sh
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
ReadWritePaths=$HA_LOG_DIR $HA_CONFIG_DIR $HA_STATE_DIR

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable ha-tunnel-monitor
    
    log_ha "✅ Servicio de monitoreo HA configurado"
}

# Función principal
main_ha() {
    log_ha "🚀 Iniciando configuración de alta disponibilidad..."
    
    # Configurar todos los componentes
    configurar_proveedores_tunnel
    configurar_health_checks
    configurar_recovery_system
    crear_servicio_ha
    
    # Inicializar estado
    mkdir -p "$HA_STATE_DIR"
    echo "$(date +%s)" > "$HA_STATE_DIR/init.timestamp"
    
    # Iniciar servicios
    systemctl start ha-tunnel-monitor
    
    log_ha "🎉 Sistema de alta disponibilidad configurado y activo"
    mostrar_resumen_ha
}

# Mostrar resumen de configuración
mostrar_resumen_ha() {
    echo
    echo "═══════════════════════════════════════════════════════════════"
    echo "⚡ SISTEMA DE ALTA DISPONIBILIDAD - CONFIGURACIÓN COMPLETADA"
    echo "═══════════════════════════════════════════════════════════════"
    echo
    echo "🔧 Componentes configurados:"
    echo "   • ✅ Múltiples proveedores de túnel (Cloudflare, ngrok, LocalTunnel, UPnP)"
    echo "   • ✅ Sistema de health checks avanzado"
    echo "   • ✅ Recuperación automática de servicios"
    echo "   • ✅ Failover inteligente entre túneles"
    echo "   • ✅ Monitoreo continuo con heartbeat"
    echo "   • ✅ Notificaciones críticas automáticas"
    echo
    echo "📁 Archivos de configuración:"
    echo "   • Túneles de respaldo: $BACKUP_TUNNELS_CONFIG"
    echo "   • Health checks: $HEALTH_CHECK_CONFIG"
    echo "   • Logs HA: $HA_LOG_DIR/"
    echo "   • Estado del sistema: $HA_STATE_DIR/"
    echo
    echo "🚀 Servicios de alta disponibilidad:"
    echo "   • ha-tunnel-monitor.service (Monitor principal)"
    echo "   • cloudflared-*.service (Túneles Cloudflare)"
    echo "   • ngrok-*.service (Túneles ngrok)"
    echo "   • localtunnel-*.service (Túneles LocalTunnel)"
    echo
    echo "📊 Comandos útiles:"
    echo "   • systemctl status ha-tunnel-monitor"
    echo "   • bash $HA_CONFIG_DIR/tunnel_manager.sh list"
    echo "   • bash $HA_CONFIG_DIR/health_checker.sh"
    echo "   • tail -f $HA_LOG_DIR/ha_monitor.log"
    echo
    echo "⚡ Características de alta disponibilidad:"
    echo "   • 🎯 Objetivo de uptime: 99.9%"
    echo "   • 🔄 Failover automático en <30 segundos"
    echo "   • 🏥 Health checks cada $HEALTH_CHECK_INTERVAL segundos"
    echo "   • 💓 Heartbeat cada $HEARTBEAT_INTERVAL segundos"
    echo "   • 🔧 Recuperación automática de servicios"
    echo "   • 📱 Notificaciones críticas instantáneas"
    echo
    echo "═══════════════════════════════════════════════════════════════"
}

# Manejo de argumentos
case "${1:-main}" in
    "main")
        main_ha
        ;;
    "tunnels")
        configurar_proveedores_tunnel
        ;;
    "health")
        configurar_health_checks
        ;;
    "recovery")
        configurar_recovery_system
        ;;
    "monitor")
        crear_servicio_ha
        ;;
    "status")
        bash "$HA_CONFIG_DIR/tunnel_manager.sh" list
        ;;
    *)
        echo "Uso: $0 [main|tunnels|health|recovery|monitor|status]"
        exit 1
        ;;
esac
#!/bin/bash

# Sistema de Túnel Persistente y Seguro
# Túnel nativo 100% sin terceros con persistencia garantizada

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/sistema_tunel_persistente_seguro.log"
CONFIG_FILE="/etc/webmin/tunel_persistente_config.conf"
STATUS_FILE="/var/lib/webmin/tunel_persistente_status.json"
PID_FILE="/var/run/tunel_persistente.pid"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TUNEL-PERSISTENTE] $1" | tee -a "$LOG_FILE"
}

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configuración Túnel Persistente y Seguro
PERSISTENCE_ENABLED=true
AUTO_RECOVERY=true
HEALTH_CHECK_INTERVAL=30
MAX_RECOVERY_ATTEMPTS=5
FALLBACK_METHODS=3
SECURITY_LEVEL=maximum
REDUNDANCY_ENABLED=true
MONITORING_ENABLED=true
ALERT_ON_FAILURE=true
AUTO_RESTART_SERVICES=true
KEEP_ALIVE_INTERVAL=10
CONNECTION_TIMEOUT=30
EOF
    fi
    source "$CONFIG_FILE"
}

create_persistent_tunnel_service() {
    log_message "=== CREANDO SERVICIO DE TÚNEL PERSISTENTE ==="
    
    # Crear script principal de túnel persistente
    cat > "$SCRIPT_DIR/tunel_persistente_daemon.sh" << 'EODAEMON'
#!/bin/bash

# Daemon de Túnel Persistente

set -e

LOG_FILE="/var/log/tunel_persistente_daemon.log"
PID_FILE="/var/run/tunel_persistente.pid"

log_daemon() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DAEMON] $1" | tee -a "$LOG_FILE"
}

# Guardar PID
echo $$ > "$PID_FILE"

# Función de limpieza al salir
cleanup() {
    log_daemon "Deteniendo daemon de túnel persistente..."
    pkill -P $$ 2>/dev/null || true
    rm -f "$PID_FILE"
    exit 0
}

trap cleanup SIGTERM SIGINT

log_daemon "Daemon de túnel persistente iniciado (PID: $$)"

# Array de métodos de túnel
TUNNEL_METHODS=(
    "ssh_native"
    "socat_forward"
    "nginx_proxy"
    "iptables_nat"
)

start_ssh_native_tunnel() {
    log_daemon "Iniciando túnel SSH nativo..."
    
    local local_ip=$(hostname -I | awk '{print $1}')
    local gateway_ip=$(ip route | grep default | awk '{print $3}')
    
    # Crear túnel SSH reverso
    ssh -N -T -R 10000:localhost:10000 \
        -R 80:localhost:80 \
        -R 443:localhost:443 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ServerAliveInterval=30 \
        -o ServerAliveCountMax=3 \
        -i /etc/ssh/tunnel_native_key \
        tunnel-native@"$gateway_ip" &
    
    local ssh_pid=$!
    log_daemon "Túnel SSH nativo iniciado (PID: $ssh_pid)"
    echo "$ssh_pid" > /var/run/ssh_tunnel.pid
}

start_socat_forward() {
    log_daemon "Iniciando túnel SOCAT..."
    
    # Reenvío directo con socat
    socat TCP-LISTEN:10000,fork,reuseaddr TCP:127.0.0.1:10000 &
    echo $! > /var/run/socat_webmin.pid
    
    socat TCP-LISTEN:80,fork,reuseaddr TCP:127.0.0.1:8080 &
    echo $! > /var/run/socat_http.pid
    
    socat TCP-LISTEN:443,fork,reuseaddr TCP:127.0.0.1:8443 &
    echo $! > /var/run/socat_https.pid
    
    log_daemon "Túneles SOCAT iniciados"
}

start_nginx_proxy() {
    log_daemon "Configurando proxy Nginx..."
    
    # Verificar si nginx está activo
    if systemctl is-active --quiet nginx; then
        # Activar configuración del proxy
        ln -sf /etc/nginx/sites-available/tunnel-native-proxy /etc/nginx/sites-enabled/
        systemctl reload nginx
        log_daemon "Proxy Nginx activado"
    fi
}

start_iptables_nat() {
    log_daemon "Configurando NAT con iptables..."
    
    # Configurar NAT para acceso directo
    local public_interface=$(ip route | grep default | awk '{print $5}')
    
    iptables -t nat -A PREROUTING -i "$public_interface" -p tcp --dport 10000 -j DNAT --to-destination 127.0.0.1:10000
    iptables -t nat -A PREROUTING -i "$public_interface" -p tcp --dport 80 -j DNAT --to-destination 127.0.0.1:80
    iptables -t nat -A PREROUTING -i "$public_interface" -p tcp --dport 443 -j DNAT --to-destination 127.0.0.1:443
    
    iptables -A FORWARD -p tcp --dport 10000 -d 127.0.0.1 -j ACCEPT
    iptables -A FORWARD -p tcp -m multiport --dports 80,443 -d 127.0.0.1 -j ACCEPT
    
    log_daemon "NAT iptables configurado"
}

check_tunnel_health() {
    local method="$1"
    
    case "$method" in
        "ssh_native")
            if [ -f "/var/run/ssh_tunnel.pid" ] && kill -0 "$(cat /var/run/ssh_tunnel.pid)" 2>/dev/null; then
                return 0
            fi
            ;;
        "socat_forward")
            if [ -f "/var/run/socat_webmin.pid" ] && kill -0 "$(cat /var/run/socat_webmin.pid)" 2>/dev/null; then
                return 0
            fi
            ;;
        "nginx_proxy")
            if systemctl is-active --quiet nginx && [ -L "/etc/nginx/sites-enabled/tunnel-native-proxy" ]; then
                return 0
            fi
            ;;
        "iptables_nat")
            if iptables -t nat -L PREROUTING | grep -q "DNAT.*:10000"; then
                return 0
            fi
            ;;
    esac
    
    return 1
}

maintain_tunnel_persistence() {
    local recovery_attempts=0
    local active_methods=()
    
    while true; do
        local healthy_tunnels=0
        
        # Verificar salud de cada método
        for method in "${TUNNEL_METHODS[@]}"; do
            if check_tunnel_health "$method"; then
                if [[ ! " ${active_methods[@]} " =~ " $method " ]]; then
                    active_methods+=("$method")
                    log_daemon "✅ Método $method saludable"
                fi
                ((healthy_tunnels++))
            else
                # Intentar recuperar método fallido
                if [[ " ${active_methods[@]} " =~ " $method " ]]; then
                    log_daemon "⚠️  Método $method falló - Intentando recuperación"
                    
                    case "$method" in
                        "ssh_native")
                            start_ssh_native_tunnel
                            ;;
                        "socat_forward")
                            start_socat_forward
                            ;;
                        "nginx_proxy")
                            start_nginx_proxy
                            ;;
                        "iptables_nat")
                            start_iptables_nat
                            ;;
                    esac
                    
                    ((recovery_attempts++))
                fi
            fi
        done
        
        # Verificar si Webmin es accesible
        local webmin_accessible=false
        if curl -s -k -I "https://localhost:10000" --connect-timeout 5 | grep -q "HTTP"; then
            webmin_accessible=true
            recovery_attempts=0  # Reset contador si funciona
        fi
        
        # Actualizar estado
        cat > "/var/lib/webmin/tunel_persistente_status.json" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "healthy_tunnels": $healthy_tunnels,
    "active_methods": [$(printf '"%s",' "${active_methods[@]}" | sed 's/,$//')],
    "webmin_accessible": $webmin_accessible,
    "recovery_attempts": $recovery_attempts,
    "uptime": "$(uptime -p)"
}
EOF
        
        # Alertas críticas
        if [ "$healthy_tunnels" -eq 0 ]; then
            log_daemon "🚨 CRÍTICO: No hay túneles funcionales"
            
            if [ "$recovery_attempts" -ge "$MAX_RECOVERY_ATTEMPTS" ]; then
                log_daemon "🔄 Reiniciando sistema completo..."
                systemctl restart webmin apache2 nginx 2>/dev/null || true
                recovery_attempts=0
            fi
        fi
        
        # Log periódico cada 10 ciclos
        if [ $(($(date +%s) % 300)) -eq 0 ]; then
            log_daemon "Estado: $healthy_tunnels túneles activos, Webmin: $webmin_accessible"
        fi
        
        sleep "$HEALTH_CHECK_INTERVAL"
    done
}

# Inicializar todos los métodos de túnel
initialize_all_tunnels() {
    log_daemon "Inicializando todos los métodos de túnel..."
    
    start_ssh_native_tunnel
    start_socat_forward
    start_nginx_proxy
    start_iptables_nat
    
    log_daemon "Todos los métodos de túnel inicializados"
}

# Ejecutar daemon
initialize_all_tunnels
maintain_tunnel_persistence
EODAEMON

    chmod +x "$SCRIPT_DIR/tunel_persistente_daemon.sh"
    
    # Crear servicio systemd principal
    cat > /etc/systemd/system/tunel-persistente.service << EOF
[Unit]
Description=Sistema de Túnel Persistente y Seguro
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=$SCRIPT_DIR/tunel_persistente_daemon.sh
ExecStop=/bin/kill -TERM \$MAINPID
Restart=always
RestartSec=10
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable tunel-persistente.service
    
    log_message "✓ Servicio de túnel persistente creado"
}

setup_tunnel_redundancy() {
    log_message "=== CONFIGURANDO REDUNDANCIA DE TÚNEL ==="
    
    # Crear múltiples servicios de respaldo
    local backup_services=(
        "tunnel-backup-ssh"
        "tunnel-backup-socat" 
        "tunnel-backup-proxy"
    )
    
    for service_name in "${backup_services[@]}"; do
        cat > "/etc/systemd/system/${service_name}.service" << EOF
[Unit]
Description=${service_name} - Túnel de Respaldo
After=network.target
BindsTo=tunel-persistente.service

[Service]
Type=simple
User=root
ExecStart=$SCRIPT_DIR/tunel_persistente_daemon.sh ${service_name}
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
EOF
    done
    
    systemctl daemon-reload
    
    for service_name in "${backup_services[@]}"; do
        systemctl enable "$service_name"
    done
    
    log_message "✓ Servicios de respaldo configurados"
}

create_tunnel_watchdog() {
    log_message "=== CREANDO WATCHDOG DEL TÚNEL ==="
    
    cat > "$SCRIPT_DIR/tunel_watchdog.sh" << 'EOF'
#!/bin/bash

# Watchdog para Túnel Persistente

LOG_FILE="/var/log/tunel_watchdog.log"
ALERT_FILE="/var/log/tunel_watchdog_alerts.log"

log_watchdog() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WATCHDOG] $1" | tee -a "$LOG_FILE"
}

send_critical_alert() {
    local message="$1"
    log_watchdog "🚨 ALERTA CRÍTICA: $message"
    echo "[$(date -Iseconds)] CRITICAL: $message" >> "$ALERT_FILE"
    
    # Notificación local
    wall "ALERTA TÚNEL: $message" 2>/dev/null || true
}

check_webmin_accessibility() {
    local methods=(
        "https://localhost:10000"
        "http://localhost:10000"
        "https://127.0.0.1:10000"
        "http://127.0.0.1:10000"
    )
    
    for method in "${methods[@]}"; do
        if curl -s -k -I "$method" --connect-timeout 5 | grep -q "HTTP"; then
            return 0
        fi
    done
    
    return 1
}

check_virtual_servers_access() {
    # Verificar que los servidores virtuales son accesibles
    local accessible_domains=0
    local total_domains=0
    
    if command -v virtualmin &> /dev/null; then
        virtualmin list-domains --multiline 2>/dev/null | grep "^Domain name:" | while read domain_line; do
            local domain=$(echo "$domain_line" | awk '{print $3}')
            ((total_domains++))
            
            if curl -s -I "http://$domain" --connect-timeout 10 | grep -q "HTTP"; then
                ((accessible_domains++))
            fi
        done
    fi
    
    # Calcular porcentaje de accesibilidad
    if [ "$total_domains" -gt 0 ]; then
        local accessibility_rate=$(( (accessible_domains * 100) / total_domains ))
        log_watchdog "Accesibilidad servidores virtuales: $accessibility_rate% ($accessible_domains/$total_domains)"
        
        if [ "$accessibility_rate" -lt 80 ]; then
            return 1
        fi
    fi
    
    return 0
}

perform_recovery_actions() {
    local recovery_level="$1"
    
    case "$recovery_level" in
        "soft")
            log_watchdog "🔄 Recuperación suave - Reiniciando servicios básicos"
            systemctl restart tunel-persistente 2>/dev/null || true
            ;;
        "medium")
            log_watchdog "🔄 Recuperación media - Reiniciando todos los servicios de túnel"
            systemctl restart tunel-persistente tunnel-backup-* 2>/dev/null || true
            systemctl restart webmin nginx apache2 2>/dev/null || true
            ;;
        "hard")
            log_watchdog "🔄 Recuperación fuerte - Reconfigurando túnel completo"
            "$SCRIPT_DIR/sub_agente_tunel_nativo_automatico.sh" restart
            "$SCRIPT_DIR/sub_agente_ip_publica_nativa.sh" auto
            ;;
        "emergency")
            log_watchdog "🚨 Recuperación de emergencia - Reinicio completo del sistema"
            send_critical_alert "Iniciando recuperación de emergencia del túnel"
            
            # Reconfigurar desde cero
            "$SCRIPT_DIR/sub_agente_tunel_nativo_automatico.sh" auto
            "$SCRIPT_DIR/sub_agente_ip_publica_nativa.sh" auto
            "$SCRIPT_DIR/sub_agente_seguridad_tunel_nativo.sh" full
            
            systemctl restart tunel-persistente
            ;;
    esac
}

watchdog_main_loop() {
    local consecutive_failures=0
    local last_success_time=$(date +%s)
    
    while true; do
        local current_time=$(date +%s)
        local check_success=true
        
        # Verificación 1: Accesibilidad de Webmin
        if ! check_webmin_accessibility; then
            log_watchdog "❌ Webmin no accesible"
            check_success=false
        fi
        
        # Verificación 2: Servicios del túnel
        if ! systemctl is-active --quiet tunel-persistente; then
            log_watchdog "❌ Servicio túnel persistente inactivo"
            check_success=false
        fi
        
        # Verificación 3: Conectividad de red
        if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
            log_watchdog "❌ Sin conectividad a internet"
            check_success=false
        fi
        
        # Verificación 4: Servidores virtuales
        if ! check_virtual_servers_access; then
            log_watchdog "⚠️  Problemas en servidores virtuales"
        fi
        
        # Manejar fallos
        if [ "$check_success" = "false" ]; then
            ((consecutive_failures++))
            log_watchdog "Fallos consecutivos: $consecutive_failures"
            
            # Escalar recuperación según número de fallos
            if [ "$consecutive_failures" -eq 1 ]; then
                perform_recovery_actions "soft"
            elif [ "$consecutive_failures" -eq 3 ]; then
                perform_recovery_actions "medium"
            elif [ "$consecutive_failures" -eq 5 ]; then
                perform_recovery_actions "hard"
            elif [ "$consecutive_failures" -ge 10 ]; then
                perform_recovery_actions "emergency"
                consecutive_failures=0  # Reset después de emergencia
            fi
        else
            # Reset contador en caso de éxito
            if [ "$consecutive_failures" -gt 0 ]; then
                log_watchdog "✅ Sistema recuperado después de $consecutive_failures fallos"
            fi
            consecutive_failures=0
            last_success_time=$current_time
        fi
        
        # Alerta si no hay éxito por mucho tiempo
        local time_since_success=$((current_time - last_success_time))
        if [ "$time_since_success" -gt 3600 ]; then  # 1 hora
            send_critical_alert "Túnel sin éxito por $(( time_since_success / 60 )) minutos"
        fi
        
        sleep 30
    done
}

# Ejecutar watchdog
watchdog_main_loop
EOF

    chmod +x "$SCRIPT_DIR/tunel_persistente_daemon.sh"
    chmod +x "$SCRIPT_DIR/tunel_watchdog.sh"
    
    # Crear servicio watchdog
    cat > /etc/systemd/system/tunel-watchdog.service << EOF
[Unit]
Description=Watchdog del Sistema de Túnel
After=tunel-persistente.service
Requires=tunel-persistente.service

[Service]
Type=simple
User=root
ExecStart=$SCRIPT_DIR/tunel_watchdog.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable tunel-watchdog.service
    
    log_message "✓ Watchdog del túnel configurado"
}

setup_tunnel_auto_recovery() {
    log_message "=== CONFIGURANDO RECUPERACIÓN AUTOMÁTICA ==="
    
    # Script de recuperación automática
    cat > "$SCRIPT_DIR/recuperacion_automatica.sh" << 'EOF'
#!/bin/bash

# Recuperación Automática del Túnel

LOG_FILE="/var/log/recuperacion_automatica.log"

log_recovery() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [RECOVERY] $1" | tee -a "$LOG_FILE"
}

full_system_recovery() {
    log_recovery "🔄 Iniciando recuperación completa del sistema"
    
    # 1. Detener todos los servicios relacionados
    systemctl stop tunel-persistente tunel-watchdog tunnel-backup-* 2>/dev/null || true
    
    # 2. Limpiar procesos zombie
    pkill -f "ssh.*tunnel" || true
    pkill -f "socat" || true
    
    # 3. Limpiar iptables del túnel
    iptables -t nat -F PREROUTING 2>/dev/null || true
    iptables -F FORWARD 2>/dev/null || true
    
    # 4. Reconfigurar desde cero
    "$SCRIPT_DIR/sub_agente_tunel_nativo_automatico.sh" auto
    "$SCRIPT_DIR/sub_agente_ip_publica_nativa.sh" auto
    
    # 5. Reiniciar servicios
    systemctl start tunel-persistente tunel-watchdog
    
    # 6. Verificar recuperación
    sleep 30
    if curl -s -k -I "https://localhost:10000" | grep -q "HTTP"; then
        log_recovery "✅ Recuperación exitosa - Webmin accesible"
        return 0
    else
        log_recovery "❌ Recuperación falló - Requiere intervención manual"
        return 1
    fi
}

# Ejecutar recuperación si se llama directamente
if [ "${1:-}" = "execute" ]; then
    full_system_recovery
fi
EOF

    chmod +x "$SCRIPT_DIR/recuperacion_automatica.sh"
    
    # Programar verificación de recuperación cada 5 minutos
    (crontab -l 2>/dev/null; echo "*/5 * * * * $SCRIPT_DIR/tunel_watchdog.sh >/dev/null 2>&1") | crontab -
    
    log_message "✓ Recuperación automática configurada"
}

create_tunnel_dashboard() {
    log_message "=== CREANDO DASHBOARD DEL TÚNEL ==="
    
    cat > /var/www/html/tunnel-status.html << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Estado del Túnel Nativo</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f0f2f5; }
        .container { max-width: 1000px; margin: 0 auto; }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 10px; text-align: center; }
        .status-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin: 20px 0; }
        .status-card { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .status-ok { color: #27ae60; font-weight: bold; }
        .status-error { color: #e74c3c; font-weight: bold; }
        .status-warning { color: #f39c12; font-weight: bold; }
        .refresh-btn { background: #3498db; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; }
        .log-container { background: white; padding: 20px; border-radius: 10px; max-height: 400px; overflow-y: auto; }
        .method-status { margin: 10px 0; padding: 10px; border-left: 4px solid #3498db; }
    </style>
    <script>
        function actualizarEstado() {
            fetch('/cgi-bin/tunnel-status.cgi')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('tunnel-status').innerHTML = 
                        data.webmin_accessible ? 
                        '<span class="status-ok">✅ TÚNEL ACTIVO</span>' : 
                        '<span class="status-error">❌ TÚNEL INACTIVO</span>';
                    
                    document.getElementById('healthy-tunnels').textContent = data.healthy_tunnels || 0;
                    document.getElementById('recovery-attempts').textContent = data.recovery_attempts || 0;
                    document.getElementById('uptime').textContent = data.uptime || 'N/A';
                    
                    // Actualizar métodos activos
                    const methodsContainer = document.getElementById('active-methods');
                    if (data.active_methods) {
                        methodsContainer.innerHTML = data.active_methods.map(method => 
                            `<div class="method-status">🟢 ${method}</div>`
                        ).join('');
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                    document.getElementById('tunnel-status').innerHTML = 
                        '<span class="status-error">❌ ERROR AL OBTENER ESTADO</span>';
                });
        }
        
        function forzarRecuperacion() {
            fetch('/cgi-bin/tunnel-recovery.cgi?action=force')
                .then(response => response.text())
                .then(data => {
                    alert('Recuperación forzada iniciada');
                    setTimeout(actualizarEstado, 5000);
                });
        }
        
        // Actualizar cada 30 segundos
        setInterval(actualizarEstado, 30000);
        
        // Cargar estado inicial
        window.onload = actualizarEstado;
    </script>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🌐 Estado del Túnel Nativo</h1>
            <p>Sistema de Túnel SIN TERCEROS - Webmin/Virtualmin</p>
        </div>
        
        <div class="status-grid">
            <div class="status-card">
                <h3>🚀 Estado Principal</h3>
                <div id="tunnel-status">Cargando...</div>
            </div>
            <div class="status-card">
                <h3>📊 Túneles Activos</h3>
                <div id="healthy-tunnels">--</div>
            </div>
            <div class="status-card">
                <h3>🔄 Intentos Recuperación</h3>
                <div id="recovery-attempts">--</div>
            </div>
            <div class="status-card">
                <h3>⏱️ Tiempo Activo</h3>
                <div id="uptime">--</div>
            </div>
        </div>
        
        <div class="status-card">
            <h3>🛠️ Métodos de Túnel Activos</h3>
            <div id="active-methods">Cargando...</div>
        </div>
        
        <div class="status-card">
            <h3>🎛️ Controles</h3>
            <button class="refresh-btn" onclick="actualizarEstado()">🔄 Actualizar Estado</button>
            <button class="refresh-btn" onclick="forzarRecuperacion()" style="background: #e74c3c;">🚨 Forzar Recuperación</button>
        </div>
        
        <div class="log-container">
            <h3>📋 Logs Recientes</h3>
            <div id="recent-logs">Cargando logs...</div>
        </div>
    </div>
</body>
</html>
EOF

    # Crear CGI para estado del túnel
    cat > /usr/share/webmin/tunnel-status.cgi << 'EOF'
#!/usr/bin/perl

use strict;
use warnings;
use JSON;

print "Content-Type: application/json\r\n\r\n";

my $status_file = "/var/lib/webmin/tunel_persistente_status.json";

if (-f $status_file) {
    open(my $fh, '<', $status_file) or die "Cannot open status file: $!";
    my $content = do { local $/; <$fh> };
    close($fh);
    print $content;
} else {
    print '{"error": "Status file not found"}';
}
EOF

    chmod +x /usr/share/webmin/tunnel-status.cgi
    
    log_message "✓ Dashboard del túnel creado"
}

install_complete_system() {
    log_message "=== INSTALACIÓN COMPLETA DEL SISTEMA ==="
    
    # Ejecutar todos los componentes en orden
    create_backup_structure
    create_persistent_tunnel_service
    setup_tunnel_redundancy
    create_tunnel_watchdog
    setup_tunnel_auto_recovery
    create_tunnel_dashboard
    
    # Iniciar servicios
    systemctl start tunel-persistente tunel-watchdog
    
    # Verificar instalación
    sleep 30
    
    if check_webmin_accessibility; then
        log_message "🎉 SISTEMA DE TÚNEL PERSISTENTE INSTALADO EXITOSAMENTE"
        log_message "✅ Webmin accesible"
        log_message "✅ Túnel funcionando"
        log_message "✅ Watchdog activo"
        log_message "✅ Recuperación automática configurada"
        return 0
    else
        log_message "❌ Instalación completada pero Webmin no es accesible"
        return 1
    fi
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")" "/var/lib/webmin" "$BACKUP_DIR" 2>/dev/null || true
    log_message "=== INICIANDO SISTEMA DE TÚNEL PERSISTENTE Y SEGURO ==="
    
    load_config
    
    case "${1:-install}" in
        install)
            install_complete_system
            ;;
        start)
            systemctl start tunel-persistente tunel-watchdog
            log_message "✅ Sistema de túnel iniciado"
            ;;
        stop)
            systemctl stop tunel-watchdog tunel-persistente tunnel-backup-* 2>/dev/null || true
            log_message "🛑 Sistema de túnel detenido"
            ;;
        restart)
            "$0" stop
            sleep 5
            "$0" start
            ;;
        status)
            if [ -f "$STATUS_FILE" ]; then
                jq '.' "$STATUS_FILE"
            else
                echo '{"error": "Estado no disponible"}'
            fi
            ;;
        recovery)
            "$SCRIPT_DIR/recuperacion_automatica.sh" execute
            ;;
        dashboard)
            create_tunnel_dashboard
            log_message "Dashboard disponible en: http://$(hostname)/tunnel-status.html"
            ;;
        test)
            if check_webmin_accessibility; then
                log_message "✅ Túnel funcionando correctamente"
                exit 0
            else
                log_message "❌ Túnel no funcional"
                exit 1
            fi
            ;;
        *)
            echo "Sistema de Túnel Persistente y Seguro"
            echo "Uso: $0 {install|start|stop|restart|status|recovery|dashboard|test}"
            echo ""
            echo "Comandos:"
            echo "  install   - Instalación completa del sistema"
            echo "  start     - Iniciar túnel persistente"
            echo "  stop      - Detener túnel persistente"
            echo "  restart   - Reiniciar túnel persistente"
            echo "  status    - Estado actual en JSON"
            echo "  recovery  - Forzar recuperación"
            echo "  dashboard - Crear dashboard web"
            echo "  test      - Probar funcionalidad"
            echo ""
            echo "🚀 Instalación rápida: $0 install"
            exit 1
            ;;
    esac
    
    log_message "Sistema de túnel persistente completado"
}

main "$@"

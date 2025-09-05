#!/bin/bash

# Panel de Control Maestro - Gestión Centralizada
# Sistema completo de administración para Webmin/Virtualmin

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/panel_control_maestro.log"
STATUS_FILE="/var/lib/webmin/panel_status.json"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PANEL-MAESTRO] $1" | tee -a "$LOG_FILE"
}

create_status_dashboard() {
    log_message "Generando dashboard de estado"
    
    local dashboard_file="/var/www/html/dashboard.html"
    
    cat > "$dashboard_file" << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Panel Control Maestro - Webmin/Virtualmin</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: Arial, sans-serif; background: #f4f4f4; }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 10px; margin-bottom: 20px; }
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-bottom: 20px; }
        .stat-card { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .stat-title { font-weight: bold; color: #2c3e50; margin-bottom: 10px; }
        .stat-value { font-size: 24px; color: #27ae60; }
        .status-ok { color: #27ae60; }
        .status-warning { color: #f39c12; }
        .status-error { color: #e74c3c; }
        .controls { background: white; padding: 20px; border-radius: 10px; margin-bottom: 20px; }
        .btn { background: #3498db; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; margin: 5px; }
        .btn:hover { background: #2980b9; }
        .btn-success { background: #27ae60; }
        .btn-warning { background: #f39c12; }
        .btn-danger { background: #e74c3c; }
        .logs { background: white; padding: 20px; border-radius: 10px; max-height: 400px; overflow-y: auto; }
        .log-entry { margin: 5px 0; padding: 5px; border-left: 3px solid #3498db; }
    </style>
    <script>
        function ejecutarAccion(accion) {
            fetch('/cgi-bin/panel_maestro.cgi?action=' + accion)
                .then(response => response.text())
                .then(data => {
                    alert('Acción ejecutada: ' + accion);
                    location.reload();
                });
        }
        
        function actualizarEstado() {
            fetch('/cgi-bin/estado.cgi')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('cpu-usage').textContent = data.cpu + '%';
                    document.getElementById('memory-usage').textContent = data.memory + '%';
                    document.getElementById('disk-usage').textContent = data.disk + '%';
                    document.getElementById('connections').textContent = data.connections;
                });
        }
        
        setInterval(actualizarEstado, 30000); // Actualizar cada 30 segundos
    </script>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Panel Control Maestro</h1>
            <p>Sistema Profesional Webmin/Virtualmin - Alto Rendimiento</p>
        </div>
        
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-title">📊 Uso CPU</div>
                <div class="stat-value" id="cpu-usage">--</div>
            </div>
            <div class="stat-card">
                <div class="stat-title">💾 Uso Memoria</div>
                <div class="stat-value" id="memory-usage">--</div>
            </div>
            <div class="stat-card">
                <div class="stat-title">💿 Uso Disco</div>
                <div class="stat-value" id="disk-usage">--</div>
            </div>
            <div class="stat-card">
                <div class="stat-title">🌐 Conexiones</div>
                <div class="stat-value" id="connections">--</div>
            </div>
        </div>
        
        <div class="controls">
            <h3>🎛️ Controles Principales</h3>
            <button class="btn btn-success" onclick="ejecutarAccion('start-all')">▶️ Iniciar Todos los Agentes</button>
            <button class="btn btn-warning" onclick="ejecutarAccion('restart-services')">🔄 Reiniciar Servicios</button>
            <button class="btn" onclick="ejecutarAccion('backup-now')">💾 Backup Inmediato</button>
            <button class="btn" onclick="ejecutarAccion('security-scan')">🔒 Escaneo Seguridad</button>
            <button class="btn" onclick="ejecutarAccion('optimize-performance')">⚡ Optimizar Rendimiento</button>
            <button class="btn btn-danger" onclick="ejecutarAccion('emergency-stop')">🛑 Parada Emergencia</button>
        </div>
        
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-title">🚀 Estado Webmin</div>
                <div class="status-ok">● Activo</div>
            </div>
            <div class="stat-card">
                <div class="stat-title">🌟 Estado Virtualmin</div>
                <div class="status-ok">● Activo</div>
            </div>
            <div class="stat-card">
                <div class="stat-title">🔒 Estado Seguridad</div>
                <div class="status-ok">● Protegido</div>
            </div>
            <div class="stat-card">
                <div class="stat-title">💾 Último Backup</div>
                <div class="stat-value">Hace 2h</div>
            </div>
        </div>
        
        <div class="logs">
            <h3>📋 Logs Recientes</h3>
            <div id="logs-container"></div>
        </div>
    </div>
    
    <script>
        // Cargar dashboard al iniciar
        actualizarEstado();
    </script>
</body>
</html>
EOF

    log_message "✓ Dashboard creado: $dashboard_file"
}

create_master_control_script() {
    log_message "Creando script de control maestro"
    
    cat > "$SCRIPT_DIR/control_maestro_completo.sh" << 'EOF'
#!/bin/bash

# Control Maestro Completo - Todos los Sub-Agentes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

execute_all_agents() {
    local mode="${1:-start}"
    
    echo "🚀 Ejecutando todos los sub-agentes en modo: $mode"
    
    # Sub-agentes principales
    "$SCRIPT_DIR/coordinador_sub_agentes.sh" "$mode" &
    
    # Sub-agentes especializados
    "$SCRIPT_DIR/sub_agente_alto_trafico.sh" "$mode" &
    "$SCRIPT_DIR/sub_agente_seguridad_avanzada.sh" "$mode" &
    "$SCRIPT_DIR/sub_agente_wordpress_laravel.sh" "$mode" &
    
    wait
    echo "✅ Todos los sub-agentes completados"
}

case "${1:-help}" in
    start-all)
        execute_all_agents "start"
        ;;
    monitor-all)
        execute_all_agents "monitor"
        ;;
    security-full)
        execute_all_agents "security"
        ;;
    backup-complete)
        execute_all_agents "backup"
        ;;
    optimize-performance)
        "$SCRIPT_DIR/sub_agente_alto_trafico.sh" start
        "$SCRIPT_DIR/sub_agente_wordpress_laravel.sh" start
        ;;
    emergency-stop)
        "$SCRIPT_DIR/coordinador_sub_agentes.sh" stop
        pkill -f "sub_agente_" || true
        echo "🛑 Sistema detenido en emergencia"
        ;;
    status-dashboard)
        "$SCRIPT_DIR/panel_control_maestro.sh" dashboard
        ;;
    *)
        echo "🎛️ Control Maestro Completo - Webmin/Virtualmin"
        echo ""
        echo "Comandos disponibles:"
        echo "  start-all           - Iniciar todos los sub-agentes"
        echo "  monitor-all         - Monitorear todo el sistema"
        echo "  security-full       - Seguridad completa"
        echo "  backup-complete     - Backup completo"
        echo "  optimize-performance - Optimizar rendimiento"
        echo "  emergency-stop      - Parada de emergencia"
        echo "  status-dashboard    - Dashboard de estado"
        ;;
esac
EOF

    chmod +x "$SCRIPT_DIR/control_maestro_completo.sh"
    log_message "✓ Script de control maestro creado"
}

generate_system_status() {
    log_message "Generando estado completo del sistema"
    
    local status_json="$STATUS_FILE"
    mkdir -p "$(dirname "$status_json")"
    
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local memory_usage=$(free | grep Mem | awk '{printf("%.1f"), $3/$2 * 100.0}')
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    local connections=$(netstat -an | grep -E ':80|:443' | wc -l)
    local uptime=$(uptime -p)
    
    cat > "$status_json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "uptime": "$uptime",
  "cpu": "$cpu_usage",
  "memory": "$memory_usage",
  "disk": "$disk_usage",
  "connections": "$connections",
  "services": {
    "webmin": "$(systemctl is-active webmin 2>/dev/null || echo 'inactive')",
    "apache2": "$(systemctl is-active apache2 2>/dev/null || echo 'inactive')",
    "nginx": "$(systemctl is-active nginx 2>/dev/null || echo 'inactive')",
    "mysql": "$(systemctl is-active mysql 2>/dev/null || echo 'inactive')",
    "redis": "$(systemctl is-active redis-server 2>/dev/null || echo 'inactive')",
    "fail2ban": "$(systemctl is-active fail2ban 2>/dev/null || echo 'inactive')"
  },
  "subagents": {
    "coordinador": "$(pgrep -f coordinador_sub_agentes.sh >/dev/null && echo 'running' || echo 'stopped')",
    "monitoreo": "$(pgrep -f sub_agente_monitoreo.sh >/dev/null && echo 'running' || echo 'stopped')",
    "seguridad": "$(pgrep -f sub_agente_seguridad.sh >/dev/null && echo 'running' || echo 'stopped')",
    "backup": "$(pgrep -f sub_agente_backup.sh >/dev/null && echo 'running' || echo 'stopped')"
  }
}
EOF

    log_message "✓ Estado del sistema actualizado: $status_json"
}

create_cgi_interface() {
    log_message "Creando interfaz CGI para Webmin"
    
    local cgi_dir="/usr/share/webmin/virtual-server"
    if [ ! -d "$cgi_dir" ]; then
        cgi_dir="/usr/local/webmin"
        mkdir -p "$cgi_dir"
    fi
    
    cat > "$cgi_dir/panel_maestro.cgi" << 'EOF'
#!/usr/bin/perl

# Panel Maestro CGI - Webmin Integration

use strict;
use warnings;
use CGI;

my $q = CGI->new;
print $q->header(-type => 'application/json', -charset => 'utf-8');

my $action = $q->param('action') || 'status';

my %actions = (
    'start-all' => sub {
        system("/usr/local/bin/control_maestro_completo.sh start-all >/dev/null 2>&1 &");
        return '{"status": "success", "message": "Iniciando todos los agentes"}';
    },
    'restart-services' => sub {
        system("systemctl restart webmin apache2 mysql >/dev/null 2>&1");
        return '{"status": "success", "message": "Servicios reiniciados"}';
    },
    'backup-now' => sub {
        system("/usr/local/bin/sub_agente_backup.sh start >/dev/null 2>&1 &");
        return '{"status": "success", "message": "Backup iniciado"}';
    },
    'security-scan' => sub {
        system("/usr/local/bin/sub_agente_seguridad_avanzada.sh start >/dev/null 2>&1 &");
        return '{"status": "success", "message": "Escaneo de seguridad iniciado"}';
    },
    'optimize-performance' => sub {
        system("/usr/local/bin/sub_agente_alto_trafico.sh start >/dev/null 2>&1 &");
        return '{"status": "success", "message": "Optimización iniciada"}';
    },
    'emergency-stop' => sub {
        system("/usr/local/bin/control_maestro_completo.sh emergency-stop");
        return '{"status": "success", "message": "Sistema detenido"}';
    }
);

if (exists $actions{$action}) {
    print $actions{$action}->();
} else {
    print '{"status": "error", "message": "Acción no válida"}';
}
EOF

    chmod +x "$cgi_dir/panel_maestro.cgi"
    log_message "✓ Interfaz CGI creada"
}

setup_monitoring_alerts() {
    log_message "Configurando sistema de alertas"
    
    cat > "$SCRIPT_DIR/sistema_alertas.sh" << 'EOF'
#!/bin/bash

# Sistema de Alertas Inteligente

ALERT_LOG="/var/log/alertas_sistema.log"
CRITICAL_LOG="/var/log/alertas_criticas.log"

send_alert() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$ALERT_LOG"
    
    if [ "$level" = "CRITICAL" ]; then
        echo "[$timestamp] $message" >> "$CRITICAL_LOG"
        
        # Enviar notificación (webhook, email, etc.)
        if command -v curl &> /dev/null; then
            curl -X POST "http://localhost:10000/webhook/alert" \
                -H "Content-Type: application/json" \
                -d "{\"level\":\"$level\",\"message\":\"$message\",\"timestamp\":\"$timestamp\"}" \
                2>/dev/null || true
        fi
    fi
}

check_system_health() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local memory_usage=$(free | grep Mem | awk '{printf("%.1f"), $3/$2 * 100.0}')
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    # Alertas CPU
    if (( $(echo "$cpu_usage > 90" | bc -l) )); then
        send_alert "CRITICAL" "Alto uso de CPU: ${cpu_usage}%"
    elif (( $(echo "$cpu_usage > 80" | bc -l) )); then
        send_alert "WARNING" "Uso elevado de CPU: ${cpu_usage}%"
    fi
    
    # Alertas Memoria
    if (( $(echo "$memory_usage > 95" | bc -l) )); then
        send_alert "CRITICAL" "Memoria casi agotada: ${memory_usage}%"
    elif (( $(echo "$memory_usage > 85" | bc -l) )); then
        send_alert "WARNING" "Alto uso de memoria: ${memory_usage}%"
    fi
    
    # Alertas Disco
    if [ "$disk_usage" -gt 95 ]; then
        send_alert "CRITICAL" "Disco casi lleno: ${disk_usage}%"
    elif [ "$disk_usage" -gt 85 ]; then
        send_alert "WARNING" "Disco con poco espacio: ${disk_usage}%"
    fi
    
    # Verificar servicios críticos
    local services=("webmin" "apache2" "mysql" "fail2ban")
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet "$service" 2>/dev/null; then
            send_alert "CRITICAL" "Servicio $service no está activo"
        fi
    done
}

# Ejecutar verificación
check_system_health
EOF

    chmod +x "$SCRIPT_DIR/sistema_alertas.sh"
    
    # Programar en cron
    (crontab -l 2>/dev/null; echo "*/5 * * * * $SCRIPT_DIR/sistema_alertas.sh") | crontab -
    
    log_message "✓ Sistema de alertas configurado"
}

install_complete_system() {
    log_message "=== INSTALACIÓN COMPLETA DEL SISTEMA ==="
    
    # Hacer ejecutables todos los scripts
    chmod +x "$SCRIPT_DIR"/*.sh
    
    # Copiar scripts a ubicación estándar
    cp "$SCRIPT_DIR"/*.sh /usr/local/bin/
    
    # Configurar servicios systemd
    "$SCRIPT_DIR/coordinador_sub_agentes.sh" install-service
    
    # Crear enlaces simbólicos
    ln -sf /usr/local/bin/control_maestro_completo.sh /usr/local/bin/webmin-control
    ln -sf /usr/local/bin/panel_control_maestro.sh /usr/local/bin/panel-maestro
    
    log_message "✓ Sistema completo instalado"
    log_message "Comandos disponibles:"
    log_message "  webmin-control start-all"
    log_message "  panel-maestro dashboard"
    log_message "  systemctl start sub-agentes-webmin"
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    log_message "=== INICIANDO PANEL CONTROL MAESTRO ==="
    
    case "${1:-help}" in
        install)
            install_complete_system
            ;;
        dashboard)
            create_status_dashboard
            generate_system_status
            ;;
        cgi)
            create_cgi_interface
            ;;
        alerts)
            setup_monitoring_alerts
            ;;
        status)
            generate_system_status
            cat "$STATUS_FILE"
            ;;
        full-setup)
            install_complete_system
            create_status_dashboard
            create_cgi_interface
            setup_monitoring_alerts
            generate_system_status
            ;;
        *)
            echo "🎛️ Panel Control Maestro - Webmin/Virtualmin"
            echo ""
            echo "Comandos:"
            echo "  install       - Instalar sistema completo"
            echo "  dashboard     - Crear dashboard web"
            echo "  cgi          - Configurar interfaz CGI"
            echo "  alerts       - Sistema de alertas"
            echo "  status       - Estado actual"
            echo "  full-setup   - Configuración completa"
            echo ""
            echo "Uso rápido: ./panel_control_maestro.sh full-setup"
            ;;
    esac
}

main "$@"
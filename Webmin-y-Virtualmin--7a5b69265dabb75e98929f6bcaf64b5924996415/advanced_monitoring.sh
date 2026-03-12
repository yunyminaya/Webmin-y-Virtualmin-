#!/bin/bash

# Sistema de Monitoreo Avanzado para Webmin y Virtualmin
# Versión: Enterprise Advanced 2025
# Características: Monitoreo en tiempo real, alertas, dashboards, métricas históricas, detección de anomalías

set -euo pipefail
IFS=$'\n\t'

# Directorios y archivos
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="/etc/advanced_monitoring"
DATA_DIR="/var/lib/advanced_monitoring"
LOG_DIR="/var/log/advanced_monitoring"
WEB_DIR="/var/www/html/monitoring"
DB_FILE="$DATA_DIR/metrics.db"

# Configuración por defecto
MONITOR_INTERVAL="${MONITOR_INTERVAL:-30}"
ENABLE_EMAIL_ALERTS="${ENABLE_EMAIL_ALERTS:-true}"
ENABLE_TELEGRAM_ALERTS="${ENABLE_TELEGRAM_ALERTS:-false}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
EMAIL_RECIPIENT="${EMAIL_RECIPIENT:-admin@localhost}"
ANOMALY_DETECTION="${ANOMALY_DETECTION:-true}"
HISTORICAL_DATA="${HISTORICAL_DATA:-true}"

# Funciones de logging
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" | tee -a "$LOG_DIR/monitoring.log"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" >&2 | tee -a "$LOG_DIR/monitoring.log"
}

log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $*" | tee -a "$LOG_DIR/monitoring.log"
}

# Crear directorios necesarios
create_directories() {
    mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$LOG_DIR" "$WEB_DIR"
    chmod 755 "$CONFIG_DIR" "$DATA_DIR" "$LOG_DIR" "$WEB_DIR"
}

# Inicializar base de datos SQLite para métricas históricas
init_database() {
    if [[ ! -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" << EOF
CREATE TABLE metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    metric_type TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    value REAL NOT NULL,
    unit TEXT
);

CREATE TABLE alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    alert_type TEXT NOT NULL,
    severity TEXT NOT NULL,
    message TEXT NOT NULL,
    resolved BOOLEAN DEFAULT FALSE
);

CREATE TABLE anomalies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    metric_name TEXT NOT NULL,
    expected_value REAL,
    actual_value REAL,
    deviation REAL,
    confidence REAL
);

CREATE INDEX idx_metrics_timestamp ON metrics(timestamp);
CREATE INDEX idx_metrics_type ON metrics(metric_type, metric_name);
CREATE INDEX idx_alerts_timestamp ON alerts(timestamp);
CREATE INDEX idx_anomalies_timestamp ON anomalies(timestamp);
EOF
        log_info "Base de datos de métricas inicializada"
    fi
}

# Función para almacenar métricas en la base de datos
store_metric() {
    local metric_type="$1"
    local metric_name="$2"
    local value="$3"
    local unit="${4:-}"

    if [[ "$HISTORICAL_DATA" == "true" ]]; then
        sqlite3 "$DB_FILE" "INSERT INTO metrics (metric_type, metric_name, value, unit) VALUES ('$metric_type', '$metric_name', $value, '$unit');"
    fi
}

# Función para obtener métricas históricas
get_historical_metrics() {
    local metric_name="$1"
    local hours="${2:-24}"

    sqlite3 "$DB_FILE" "SELECT strftime('%s', timestamp)*1000 as time_ms, value FROM metrics WHERE metric_name='$metric_name' AND timestamp >= datetime('now', '-${hours} hours') ORDER BY timestamp;"
}

# Monitoreo de CPU en tiempo real
monitor_cpu() {
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

    # CPU por núcleo
    local cpu_cores
    cpu_cores=$(nproc)
    local cpu_per_core=()
    for ((i=0; i<cpu_cores; i++)); do
        local core_usage
        core_usage=$(mpstat -P "$i" 1 1 | awk 'NR==4 {print 100 - $NF}')
        cpu_per_core+=("$core_usage")
        store_metric "cpu" "core_$i" "$core_usage" "%"
    done

    store_metric "cpu" "total" "$cpu_usage" "%"
    echo "$cpu_usage"
}

# Monitoreo de memoria
monitor_memory() {
    local mem_total mem_used mem_free mem_available mem_usage
    read -r mem_total mem_used mem_free mem_available <<< "$(free -m | awk 'NR==2{printf "%.0f %.0f %.0f %.0f", $2, $3, $4, $7}')"
    mem_usage=$(echo "scale=2; $mem_used * 100 / $mem_total" | bc)

    # Memoria swap
    local swap_total swap_used swap_free swap_usage
    read -r swap_total swap_used swap_free <<< "$(free -m | awk 'NR==3{printf "%.0f %.0f %.0f", $2, $3, $4}')"
    swap_usage=$( [[ $swap_total -gt 0 ]] && echo "scale=2; $swap_used * 100 / $swap_total" | bc || echo "0" )

    store_metric "memory" "total" "$mem_total" "MB"
    store_metric "memory" "used" "$mem_used" "MB"
    store_metric "memory" "free" "$mem_free" "MB"
    store_metric "memory" "available" "$mem_available" "MB"
    store_metric "memory" "usage_percent" "$mem_usage" "%"
    store_metric "memory" "swap_total" "$swap_total" "MB"
    store_metric "memory" "swap_used" "$swap_used" "MB"
    store_metric "memory" "swap_usage_percent" "$swap_usage" "%"

    echo "$mem_usage"
}

# Monitoreo de disco
monitor_disk() {
    local disk_data=()

    # Obtener información de todos los discos
    while IFS= read -r line; do
        if [[ $line =~ ^/dev ]]; then
            local filesystem mountpoint usage
            read -r filesystem usage mountpoint <<< "$(echo "$line" | awk '{print $1, $5, $6}')"
            usage="${usage%\%}"

            store_metric "disk" "${filesystem//\//_}" "$usage" "%"

            # Espacio total y usado
            local total used
            read -r total used <<< "$(df -BG "$mountpoint" | awk 'NR==2{print $2, $3}' | sed 's/G//g')"
            store_metric "disk" "${filesystem//\//_}_total" "$total" "GB"
            store_metric "disk" "${filesystem//\//_}_used" "$used" "GB"

            disk_data+=("$filesystem:$usage")
        fi
    done < <(df -h | grep '^/dev')

    # I/O de disco
    local disk_io
    disk_io=$(iostat -d 1 1 | awk 'NR>3 {sum+=$2+$3} END {print sum}')
    store_metric "disk" "io_total" "$disk_io" "KB/s"

    echo "${disk_data[*]}"
}

# Monitoreo de red
monitor_network() {
    local interfaces=()
    local rx_total=0 tx_total=0

    # Obtener estadísticas de red por interfaz
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*[a-zA-Z0-9]+: ]]; then
            local iface rx_bytes tx_bytes
            iface=$(echo "$line" | awk -F: '{print $1}' | xargs)
            rx_bytes=$(echo "$line" | awk '{print $2}')
            tx_bytes=$(echo "$line" | awk '{print $10}')

            if [[ -n "$iface" && "$iface" != "lo" ]]; then
                store_metric "network" "${iface}_rx" "$rx_bytes" "bytes"
                store_metric "network" "${iface}_tx" "$tx_bytes" "bytes"
                rx_total=$((rx_total + rx_bytes))
                tx_total=$((tx_total + tx_bytes))
                interfaces+=("$iface")
            fi
        fi
    done < <(cat /proc/net/dev)

    store_metric "network" "total_rx" "$rx_total" "bytes"
    store_metric "network" "total_tx" "$tx_total" "bytes"

    # Conexiones activas
    local active_connections
    active_connections=$(netstat -tun | grep ESTABLISHED | wc -l)
    store_metric "network" "active_connections" "$active_connections" "count"

    echo "$rx_total:$tx_total:$active_connections"
}

# Monitoreo de servicios críticos
monitor_services() {
    local services=("webmin" "apache2" "mysql" "postfix" "dovecot" "sshd" "named")
    local service_status=()

    for service in "${services[@]}"; do
        local status="stopped"
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            status="running"
        elif service "$service" status &>/dev/null; then
            status="running"
        fi

        store_metric "service" "$service" "$( [[ "$status" == "running" ]] && echo 1 || echo 0 )" "status"
        service_status+=("$service:$status")
    done

    echo "${service_status[*]}"
}

# Monitoreo específico de Virtualmin/Webmin
monitor_virtualmin() {
    local webmin_procs=0 webmin_conns=0 domains=0 mysql_conns=0

    # Procesos Webmin
    webmin_procs=$(pgrep -f webmin | wc -l)
    store_metric "virtualmin" "webmin_processes" "$webmin_procs" "count"

    # Conexiones activas a Webmin
    if [[ -f /var/webmin/miniserv.pid ]]; then
        webmin_conns=$(netstat -tlnp 2>/dev/null | grep :10000 | wc -l)
    fi
    store_metric "virtualmin" "webmin_connections" "$webmin_conns" "count"

    # Dominios Virtualmin
    if [[ -d /etc/virtualmin ]]; then
        domains=$(find /etc/virtualmin -name "*.conf" 2>/dev/null | wc -l)
    fi
    store_metric "virtualmin" "domains" "$domains" "count"

    # Conexiones MySQL
    if command -v mysql &> /dev/null; then
        mysql_conns=$(mysql -e "SHOW PROCESSLIST;" 2>/dev/null | wc -l 2>/dev/null || echo "1")
        mysql_conns=$((mysql_conns - 1))
    fi
    store_metric "virtualmin" "mysql_connections" "$mysql_conns" "count"

    echo "$webmin_procs:$webmin_conns:$domains:$mysql_conns"
}

# Sistema de alertas
send_email_alert() {
    local subject="$1"
    local message="$2"

    if [[ "$ENABLE_EMAIL_ALERTS" == "true" ]]; then
        echo "$message" | mail -s "$subject" "$EMAIL_RECIPIENT"
        log_info "Alerta por email enviada: $subject"
    fi
}

send_telegram_alert() {
    local message="$1"

    if [[ "$ENABLE_TELEGRAM_ALERTS" == "true" && -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$message" \
            -d parse_mode="HTML" >/dev/null
        log_info "Alerta por Telegram enviada"
    fi
}

create_alert() {
    local alert_type="$1"
    local severity="$2"
    local message="$3"

    # Almacenar en base de datos
    sqlite3 "$DB_FILE" "INSERT INTO alerts (alert_type, severity, message) VALUES ('$alert_type', '$severity', '$message');"

    # Enviar alertas
    local alert_msg="🚨 ALERTA $severity: $alert_type
$message
Timestamp: $(date)"

    send_email_alert "[$severity] $alert_type" "$alert_msg"
    send_telegram_alert "$alert_msg"

    log_warning "Alerta creada: $alert_type ($severity)"
}

# Verificar umbrales y crear alertas
check_thresholds() {
    local cpu_usage="$1"
    local mem_usage="$2"
    local disk_usage="$3"

    # Umbrales configurables
    local CPU_CRITICAL="${CPU_CRITICAL:-95}"
    local CPU_WARNING="${CPU_WARNING:-80}"
    local MEM_CRITICAL="${MEM_CRITICAL:-95}"
    local MEM_WARNING="${MEM_WARNING:-85}"
    local DISK_CRITICAL="${DISK_CRITICAL:-95}"
    local DISK_WARNING="${DISK_WARNING:-85}"

    # Alertas de CPU
    if (( $(echo "$cpu_usage > $CPU_CRITICAL" | bc -l) )); then
        create_alert "CPU_CRITICAL" "CRITICAL" "Uso de CPU crítico: ${cpu_usage}% (umbral: ${CPU_CRITICAL}%)"
    elif (( $(echo "$cpu_usage > $CPU_WARNING" | bc -l) )); then
        create_alert "CPU_WARNING" "WARNING" "Uso de CPU alto: ${cpu_usage}% (umbral: ${CPU_WARNING}%)"
    fi

    # Alertas de memoria
    if (( $(echo "$mem_usage > $MEM_CRITICAL" | bc -l) )); then
        create_alert "MEMORY_CRITICAL" "CRITICAL" "Uso de memoria crítico: ${mem_usage}% (umbral: ${MEM_CRITICAL}%)"
    elif (( $(echo "$mem_usage > $MEM_WARNING" | bc -l) )); then
        create_alert "MEMORY_WARNING" "WARNING" "Uso de memoria alto: ${mem_usage}% (umbral: ${MEM_WARNING}%)"
    fi

    # Alertas de disco
    if (( $(echo "$disk_usage > $DISK_CRITICAL" | bc -l) )); then
        create_alert "DISK_CRITICAL" "CRITICAL" "Uso de disco crítico: ${disk_usage}% (umbral: ${DISK_CRITICAL}%)"
    elif (( $(echo "$disk_usage > $DISK_WARNING" | bc -l) )); then
        create_alert "DISK_WARNING" "WARNING" "Uso de disco alto: ${disk_usage}% (umbral: ${DISK_WARNING}%)"
    fi
}

# Detección de anomalías usando estadísticas básicas
detect_anomalies() {
    if [[ "$ANOMALY_DETECTION" != "true" ]]; then
        return
    fi

    local metric_name="$1"
    local current_value="$2"
    local threshold="${3:-2.0}"  # Desviación estándar

    # Obtener datos históricos de las últimas 24 horas
    local historical_data
    historical_data=$(get_historical_metrics "$metric_name" 24)

    if [[ -z "$historical_data" ]]; then
        return
    fi

    # Calcular media y desviación estándar usando awk
    local stats
    stats=$(echo "$historical_data" | awk -F'|' '{sum+=$2; sumsq+=$2*$2; n++} END {if(n>0){mean=sum/n; std=sqrt(sumsq/n - mean*mean); print mean, std}}')

    if [[ -n "$stats" ]]; then
        local mean std
        read -r mean std <<< "$stats"

        if (( $(echo "$std > 0" | bc -l) )); then
            local z_score
            z_score=$(echo "scale=2; ($current_value - $mean) / $std" | bc -l)

            # Si la desviación es mayor que el umbral
            if (( $(echo "${z_score#-} > $threshold" | bc -l) )); then
                local direction
                direction=$(( $(echo "$current_value > $mean" | bc -l) )) && direction="alta" || direction="baja"

                sqlite3 "$DB_FILE" "INSERT INTO anomalies (metric_name, expected_value, actual_value, deviation, confidence) VALUES ('$metric_name', $mean, $current_value, $z_score, 0.95);"

                create_alert "ANOMALY_DETECTED" "WARNING" "Anomalía detectada en $metric_name: valor actual $current_value (esperado ~$mean), desviación $z_score sigma. Tendencia $direction."
            fi
        fi
    fi
}

# Generar dashboard HTML interactivo
generate_dashboard() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    cat > "$WEB_DIR/index.html" << EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard de Monitoreo Avanzado - Webmin/Virtualmin</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/luxon@3.0.1/build/global/luxon.min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f5f7fa; color: #333; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; text-align: center; }
        .container { max-width: 1400px; margin: 0 auto; padding: 20px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(400px, 1fr)); gap: 20px; margin: 20px 0; }
        .card { background: white; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); padding: 20px; }
        .card h3 { margin-bottom: 15px; color: #667eea; border-bottom: 2px solid #f0f0f0; padding-bottom: 10px; }
        .metric { display: flex; justify-content: space-between; align-items: center; margin: 10px 0; }
        .metric-value { font-size: 1.5em; font-weight: bold; }
        .status-good { color: #28a745; }
        .status-warning { color: #ffc107; }
        .status-critical { color: #dc3545; }
        .chart-container { position: relative; height: 300px; margin: 20px 0; }
        .alerts { max-height: 300px; overflow-y: auto; }
        .alert { padding: 10px; margin: 5px 0; border-radius: 5px; border-left: 4px solid; }
        .alert-critical { background: #f8d7da; border-left-color: #dc3545; }
        .alert-warning { background: #fff3cd; border-left-color: #ffc107; }
        .alert-info { background: #d1ecf1; border-left-color: #17a2b8; }
        .refresh-btn { background: #667eea; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; margin: 10px; }
        .refresh-btn:hover { background: #5a6fd8; }
        .tabs { display: flex; margin-bottom: 20px; }
        .tab { padding: 10px 20px; background: #f8f9fa; border: none; cursor: pointer; border-radius: 5px 5px 0 0; }
        .tab.active { background: white; border-bottom: 2px solid #667eea; }
        .tab-content { display: none; }
        .tab-content.active { display: block; }
    </style>
</head>
<body>
    <div class="header">
        <h1>📊 Dashboard de Monitoreo Avanzado</h1>
        <p>Webmin & Virtualmin Enterprise Monitoring</p>
        <p id="last-update">Última actualización: $timestamp</p>
    </div>

    <div class="container">
        <button class="refresh-btn" onclick="refreshData()">🔄 Actualizar</button>

        <div class="tabs">
            <button class="tab active" onclick="showTab('overview')">Vista General</button>
            <button class="tab" onclick="showTab('performance')">Performance</button>
            <button class="tab" onclick="showTab('services')">Servicios</button>
            <button class="tab" onclick="showTab('alerts')">Alertas</button>
        </div>

        <div id="overview" class="tab-content active">
            <div class="grid">
                <div class="card">
                    <h3>💻 CPU</h3>
                    <canvas id="cpuChart" class="chart-container"></canvas>
                </div>
                <div class="card">
                    <h3>🧠 Memoria</h3>
                    <canvas id="memoryChart" class="chart-container"></canvas>
                </div>
                <div class="card">
                    <h3>💾 Disco</h3>
                    <canvas id="diskChart" class="chart-container"></canvas>
                </div>
                <div class="card">
                    <h3>🌐 Red</h3>
                    <canvas id="networkChart" class="chart-container"></canvas>
                </div>
            </div>
        </div>

        <div id="performance" class="tab-content">
            <div class="grid">
                <div class="card">
                    <h3>CPU por Núcleo</h3>
                    <canvas id="cpuCoresChart" class="chart-container"></canvas>
                </div>
                <div class="card">
                    <h3>Uso de Memoria Detallado</h3>
                    <canvas id="memoryDetailedChart" class="chart-container"></canvas>
                </div>
                <div class="card">
                    <h3>I/O de Disco</h3>
                    <canvas id="diskIOChart" class="chart-container"></canvas>
                </div>
                <div class="card">
                    <h3>Conexiones de Red</h3>
                    <canvas id="networkConnectionsChart" class="chart-container"></canvas>
                </div>
            </div>
        </div>

        <div id="services" class="tab-content">
            <div class="grid">
                <div class="card">
                    <h3>Estado de Servicios</h3>
                    <div id="services-status"></div>
                </div>
                <div class="card">
                    <h3>Métricas Virtualmin</h3>
                    <div id="virtualmin-metrics"></div>
                </div>
            </div>
        </div>

        <div id="alerts" class="tab-content">
            <div class="card">
                <h3>🚨 Alertas Recientes</h3>
                <div id="alerts-list" class="alerts"></div>
            </div>
        </div>
    </div>

    <script>
        let cpuChart, memoryChart, diskChart, networkChart;
        let cpuCoresChart, memoryDetailedChart, diskIOChart, networkConnectionsChart;

        async function fetchData() {
            try {
                const response = await fetch('data.json');
                return await response.json();
            } catch (error) {
                console.error('Error fetching data:', error);
                return null;
            }
        }

        function updateCharts(data) {
            if (!data) return;

            // CPU Chart
            if (!cpuChart) {
                cpuChart = new Chart(document.getElementById('cpuChart'), {
                    type: 'line',
                    data: {
                        labels: data.cpu.labels,
                        datasets: [{
                            label: 'CPU Usage %',
                            data: data.cpu.values,
                            borderColor: '#667eea',
                            backgroundColor: 'rgba(102, 126, 234, 0.1)',
                            tension: 0.4
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        scales: {
                            y: { beginAtZero: true, max: 100 }
                        }
                    }
                });
            } else {
                cpuChart.data.labels = data.cpu.labels;
                cpuChart.data.datasets[0].data = data.cpu.values;
                cpuChart.update();
            }

            // Memory Chart
            if (!memoryChart) {
                memoryChart = new Chart(document.getElementById('memoryChart'), {
                    type: 'doughnut',
                    data: {
                        labels: ['Usada', 'Libre'],
                        datasets: [{
                            data: [data.memory.used, data.memory.total - data.memory.used],
                            backgroundColor: ['#dc3545', '#28a745']
                        }]
                    }
                });
            } else {
                memoryChart.data.datasets[0].data = [data.memory.used, data.memory.total - data.memory.used];
                memoryChart.update();
            }

            // Disk Chart
            if (!diskChart) {
                diskChart = new Chart(document.getElementById('diskChart'), {
                    type: 'bar',
                    data: {
                        labels: data.disk.labels,
                        datasets: [{
                            label: 'Uso de Disco %',
                            data: data.disk.values,
                            backgroundColor: '#ffc107'
                        }]
                    },
                    options: {
                        scales: {
                            y: { beginAtZero: true, max: 100 }
                        }
                    }
                });
            } else {
                diskChart.data.labels = data.disk.labels;
                diskChart.data.datasets[0].data = data.disk.values;
                diskChart.update();
            }

            // Network Chart
            if (!networkChart) {
                networkChart = new Chart(document.getElementById('networkChart'), {
                    type: 'line',
                    data: {
                        labels: data.network.labels,
                        datasets: [{
                            label: 'RX (KB/s)',
                            data: data.network.rx,
                            borderColor: '#28a745'
                        }, {
                            label: 'TX (KB/s)',
                            data: data.network.tx,
                            borderColor: '#dc3545'
                        }]
                    }
                });
            } else {
                networkChart.data.labels = data.network.labels;
                networkChart.data.datasets[0].data = data.network.rx;
                networkChart.data.datasets[1].data = data.network.tx;
                networkChart.update();
            }
        }

        function updateServices(data) {
            const servicesDiv = document.getElementById('services-status');
            servicesDiv.innerHTML = data.services.map(service => {
                const [name, status] = service.split(':');
                const statusClass = status === 'running' ? 'status-good' : 'status-critical';
                return \`<div class="metric">
                    <span>\${name}</span>
                    <span class="metric-value \${statusClass}">\${status.toUpperCase()}</span>
                </div>\`;
            }).join('');
        }

        function updateVirtualmin(data) {
            const vmDiv = document.getElementById('virtualmin-metrics');
            vmDiv.innerHTML = \`
                <div class="metric">
                    <span>Procesos Webmin</span>
                    <span class="metric-value">\${data.virtualmin.processes}</span>
                </div>
                <div class="metric">
                    <span>Conexiones Webmin</span>
                    <span class="metric-value">\${data.virtualmin.connections}</span>
                </div>
                <div class="metric">
                    <span>Dominios</span>
                    <span class="metric-value">\${data.virtualmin.domains}</span>
                </div>
                <div class="metric">
                    <span>Conexiones MySQL</span>
                    <span class="metric-value">\${data.virtualmin.mysql_connections}</span>
                </div>
            \`;
        }

        function updateAlerts(data) {
            const alertsDiv = document.getElementById('alerts-list');
            alertsDiv.innerHTML = data.alerts.slice(0, 10).map(alert => {
                const severityClass = alert.severity.toLowerCase();
                return \`<div class="alert alert-\${severityClass}">
                    <strong>\${alert.timestamp}</strong> - \${alert.alert_type}<br>
                    \${alert.message}
                </div>\`;
            }).join('');
        }

        async function refreshData() {
            const data = await fetchData();
            if (data) {
                updateCharts(data);
                updateServices(data);
                updateVirtualmin(data);
                updateAlerts(data);
                document.getElementById('last-update').textContent = 'Última actualización: ' + new Date().toLocaleString();
            }
        }

        function showTab(tabName) {
            document.querySelectorAll('.tab').forEach(tab => tab.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));

            document.querySelector(\`button[onclick="showTab('\${tabName}')"]\`).classList.add('active');
            document.getElementById(tabName).classList.add('active');
        }

        // Auto-refresh every 30 seconds
        setInterval(refreshData, 30000);

        // Initial load
        refreshData();
    </script>
</body>
</html>
EOF

    log_info "Dashboard HTML generado: $WEB_DIR/index.html"
}

# Generar datos JSON para el dashboard
generate_json_data() {
    local json_file="$WEB_DIR/data.json"

    # Obtener datos históricos para gráficos
    local cpu_data
    cpu_data=$(get_historical_metrics "cpu_total" 1 | jq -s 'map({x: .[0], y: .[1]})' 2>/dev/null || echo "[]")

    local memory_data
    memory_data=$(get_historical_metrics "memory_usage_percent" 1 | jq -s 'map({x: .[0], y: .[1]})' 2>/dev/null || echo "[]")

    # Datos actuales
    local current_cpu current_memory current_disk current_network current_services current_virtualmin

    # Recopilar datos actuales
    current_cpu=$(monitor_cpu)
    current_memory=$(monitor_memory)
    current_disk=$(monitor_disk)
    current_network=$(monitor_network)
    current_services=$(monitor_services)
    current_virtualmin=$(monitor_virtualmin)

    # Crear JSON
    cat > "$json_file" << EOF
{
  "timestamp": "$(date +%s)",
  "cpu": {
    "current": $current_cpu,
    "labels": $(get_historical_metrics "cpu_total" 1 | awk -F'|' '{print strftime("%H:%M", $1/1000)}' | jq -s '.'),
    "values": $(get_historical_metrics "cpu_total" 1 | awk -F'|' '{print $2}' | jq -s '.')
  },
  "memory": {
    "total": $(sqlite3 "$DB_FILE" "SELECT value FROM metrics WHERE metric_name='memory_total' ORDER BY timestamp DESC LIMIT 1;" 2>/dev/null || echo "8192"),
    "used": $(sqlite3 "$DB_FILE" "SELECT value FROM metrics WHERE metric_name='memory_used' ORDER BY timestamp DESC LIMIT 1;" 2>/dev/null || echo "1024"),
    "usage_percent": $current_memory
  },
  "disk": {
    "labels": ["Root"],
    "values": [$(echo "$current_disk" | grep -o '[0-9]\+' | head -1 || echo "50")]
  },
  "network": {
    "labels": $(get_historical_metrics "network_total_rx" 1 | awk -F'|' '{print strftime("%H:%M", $1/1000)}' | jq -s '.'),
    "rx": $(get_historical_metrics "network_total_rx" 1 | awk -F'|' '{print $2/1024}' | jq -s '.'),
    "tx": $(get_historical_metrics "network_total_tx" 1 | awk -F'|' '{print $2/1024}' | jq -s '.')
  },
  "services": $(echo "$current_services" | jq -R 'split(" ") | map(split(":"))'),
  "virtualmin": {
    "processes": $(echo "$current_virtualmin" | cut -d: -f1),
    "connections": $(echo "$current_virtualmin" | cut -d: -f2),
    "domains": $(echo "$current_virtualmin" | cut -d: -f3),
    "mysql_connections": $(echo "$current_virtualmin" | cut -d: -f4)
  },
  "alerts": $(sqlite3 "$DB_FILE" "SELECT timestamp, alert_type, severity, message FROM alerts WHERE resolved=0 ORDER BY timestamp DESC LIMIT 10;" | jq -R 'split("\n") | map(split("|") | {timestamp: .[0], alert_type: .[1], severity: .[2], message: .[3]}) | .[:-1]' 2>/dev/null || echo "[]")
}
EOF
}

# Función principal de monitoreo
perform_monitoring() {
    log_info "Iniciando ciclo de monitoreo..."

    # Recopilar métricas
    local cpu_usage mem_usage disk_usage network_data services_data virtualmin_data

    cpu_usage=$(monitor_cpu)
    mem_usage=$(monitor_memory)
    disk_usage=$(monitor_disk)
    network_data=$(monitor_network)
    services_data=$(monitor_services)
    virtualmin_data=$(monitor_virtualmin)

    # Verificar umbrales y alertas
    check_thresholds "$cpu_usage" "$mem_usage" "$disk_usage"

    # Detectar anomalías
    detect_anomalies "cpu_total" "$cpu_usage"
    detect_anomalies "memory_usage_percent" "$mem_usage"

    # Generar datos para dashboard
    generate_json_data

    log_info "Ciclo de monitoreo completado"
}

# Función para ejecutar monitoreo continuo
run_continuous_monitoring() {
    log_info "Iniciando monitoreo continuo (intervalo: ${MONITOR_INTERVAL}s)"

    # Generar dashboard inicial
    generate_dashboard

    while true; do
        perform_monitoring
        sleep "$MONITOR_INTERVAL"
    done
}

# Función de ayuda
show_help() {
    cat << EOF
Sistema de Monitoreo Avanzado para Webmin & Virtualmin
Versión: Enterprise Advanced 2025

USO:
    $0 [opciones]

OPCIONES:
    -c, --continuous    Ejecutar monitoreo continuo
    -i, --interval SEC  Intervalo de monitoreo en segundos (default: 30)
    -s, --setup         Configurar el sistema de monitoreo
    -d, --dashboard     Generar dashboard web
    -h, --help          Mostrar esta ayuda

CONFIGURACIÓN POR VARIABLES DE ENTORNO:
    MONITOR_INTERVAL        Intervalo de monitoreo (segundos)
    ENABLE_EMAIL_ALERTS     Habilitar alertas por email (true/false)
    ENABLE_TELEGRAM_ALERTS  Habilitar alertas por Telegram (true/false)
    TELEGRAM_BOT_TOKEN      Token del bot de Telegram
    TELEGRAM_CHAT_ID        ID del chat de Telegram
    EMAIL_RECIPIENT         Destinatario de emails
    ANOMALY_DETECTION       Habilitar detección de anomalías (true/false)
    HISTORICAL_DATA         Almacenar datos históricos (true/false)

ARCHIVOS:
    /etc/advanced_monitoring/    Configuración
    /var/lib/advanced_monitoring/ Base de datos y datos
    /var/log/advanced_monitoring/ Logs
    /var/www/html/monitoring/     Dashboard web

EJEMPLOS:
    $0 --setup                    # Configurar el sistema
    $0 -c -i 60                   # Monitoreo continuo cada 60s
    $0 --dashboard                # Generar dashboard

NOTAS:
    - Requiere permisos de root para monitoreo completo
    - Las métricas se almacenan en SQLite para análisis histórico
    - El dashboard web está disponible en /monitoring/
EOF
}

# Función de configuración inicial
setup_system() {
    log_info "Configurando sistema de monitoreo avanzado..."

    # Crear directorios
    create_directories

    # Inicializar base de datos
    init_database

    # Configurar permisos
    chown -R www-data:www-data "$WEB_DIR" 2>/dev/null || true

    # Crear archivo de configuración por defecto
    cat > "$CONFIG_DIR/config.sh" << EOF
# Configuración del Sistema de Monitoreo Avanzado
# Modificar estas variables según sea necesario

# Intervalo de monitoreo (segundos)
MONITOR_INTERVAL=30

# Alertas por email
ENABLE_EMAIL_ALERTS=true
EMAIL_RECIPIENT="admin@localhost"

# Alertas por Telegram
ENABLE_TELEGRAM_ALERTS=false
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# Umbrales de alerta
CPU_WARNING=80
CPU_CRITICAL=95
MEM_WARNING=85
MEM_CRITICAL=95
DISK_WARNING=85
DISK_CRITICAL=95

# Características avanzadas
ANOMALY_DETECTION=true
HISTORICAL_DATA=true

# Umbrales para detección de anomalías (desviación estándar)
ANOMALY_THRESHOLD=2.0
EOF

    # Crear servicio systemd
    cat > /etc/systemd/system/advanced-monitoring.service << EOF
[Unit]
Description=Advanced Monitoring Service for Webmin/Virtualmin
After=network.target

[Service]
Type=simple
User=root
ExecStart=$SCRIPT_DIR/advanced_monitoring.sh --continuous
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    log_success "Sistema de monitoreo configurado"
    log_info "Para iniciar el servicio: systemctl enable --now advanced-monitoring"
    log_info "Dashboard disponible en: http://tu-servidor/monitoring/"
}

# Función principal
main() {
    # Verificar permisos de root
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root (sudo)"
        exit 1
    fi

    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--continuous) CONTINUOUS_MODE=true ;;
            -i|--interval) MONITOR_INTERVAL="$2"; shift ;;
            -s|--setup) setup_system; exit 0 ;;
            -d|--dashboard) generate_dashboard; generate_json_data; exit 0 ;;
            -h|--help) show_help; exit 0 ;;
            *) log_error "Opción desconocida: $1"; show_help; exit 1 ;;
        esac
        shift
    done

    echo "=========================================="
    echo "  SISTEMA DE MONITOREO AVANZADO"
    echo "  Webmin & Virtualmin Enterprise"
    echo "=========================================="
    echo

    # Configurar sistema si no está configurado
    if [[ ! -f "$CONFIG_DIR/config.sh" ]]; then
        log_info "Sistema no configurado, ejecutando configuración inicial..."
        setup_system
    fi

    # Cargar configuración
    if [[ -f "$CONFIG_DIR/config.sh" ]]; then
        source "$CONFIG_DIR/config.sh"
    fi

    # Ejecutar monitoreo
    if [[ "${CONTINUOUS_MODE:-false}" == "true" ]]; then
        run_continuous_monitoring
    else
        perform_monitoring
    fi
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
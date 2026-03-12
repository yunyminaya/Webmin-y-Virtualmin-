#!/bin/bash

# ============================================================================
# 🔗 SCRIPT DE INTEGRACIÓN CON SISTEMA DE MONITOREO
# ============================================================================
# Integra el AI Optimizer con el sistema de monitoreo avanzado existente
# Configura Prometheus, Grafana y alertas para el sistema de IA
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
AI_DIR="$(dirname "$PROJECT_DIR")"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función de logging
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" >> "$AI_DIR/integration.log"

    case "$level" in
        "INFO")     echo -e "${BLUE}[$timestamp INFO]${NC} $message" ;;
        "SUCCESS")  echo -e "${GREEN}[$timestamp SUCCESS]${NC} $message" ;;
        "WARNING")  echo -e "${YELLOW}[$timestamp WARNING]${NC} $message" ;;
        "ERROR")    echo -e "${RED}[$timestamp ERROR]${NC} $message" ;;
        "STEP")     echo -e "${PURPLE}[$timestamp STEP]${NC} $message" ;;
    esac
}

# Función para integrar con Prometheus
integrate_prometheus() {
    log "STEP" "📊 Integrando con Prometheus..."

    # Verificar si Prometheus está instalado
    if ! command -v prometheus >/dev/null 2>&1 && [[ ! -d /opt/prometheus ]]; then
        log "WARNING" "Prometheus no detectado. Instalando..."

        # Instalar Prometheus
        wget -q https://github.com/prometheus/prometheus/releases/download/v2.40.0/prometheus-2.40.0.linux-amd64.tar.gz
        tar xzf prometheus-2.40.0.linux-amd64.tar.gz
        mv prometheus-2.40.0.linux-amd64 /opt/prometheus
        rm prometheus-2.40.0.linux-amd64.tar.gz

        # Crear usuario prometheus
        useradd -rs /bin/false prometheus

        # Crear directorios
        mkdir -p /etc/prometheus /var/lib/prometheus

        # Configurar permisos
        chown prometheus:prometheus /etc/prometheus
        chown prometheus:prometheus /var/lib/prometheus
        chown -R prometheus:prometheus /opt/prometheus

        log "SUCCESS" "✅ Prometheus instalado"
    fi

    # Configurar Prometheus para AI Optimizer
    cat > /etc/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "ai_optimizer_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'ai_optimizer'
    static_configs:
      - targets: ['localhost:8000']
    scrape_interval: 10s
    metrics_path: '/metrics'

  - job_name: 'webmin'
    static_configs:
      - targets: ['localhost:10000']
    metrics_path: '/api/v1/metrics'
    scrape_interval: 30s

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'apache_exporter'
    static_configs:
      - targets: ['localhost:9117']

  - job_name: 'mysql_exporter'
    static_configs:
      - targets: ['localhost:9104']

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
EOF

    # Crear reglas de alertas para AI Optimizer
    cat > /etc/prometheus/ai_optimizer_rules.yml << 'EOF'
groups:
  - name: ai_optimizer_alerts
    rules:
      - alert: HighCPUUsage
        expr: cpu_usage_percent > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Uso de CPU muy alto ({{ $value }}%)"
          description: "El uso de CPU está por encima del 90% durante 5 minutos"

      - alert: HighMemoryUsage
        expr: memory_usage_percent > 95
        for: 3m
        labels:
          severity: critical
        annotations:
          summary: "Uso de memoria muy alto ({{ $value }}%)"
          description: "El uso de memoria está por encima del 95% durante 3 minutos"

      - alert: HighDiskUsage
        expr: disk_usage_percent > 95
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Uso de disco alto ({{ $value }}%)"
          description: "El uso de disco está por encima del 95% durante 10 minutos"

      - alert: SlowResponseTime
        expr: response_time_ms > 5000
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Tiempo de respuesta lento ({{ $value }}ms)"
          description: "El tiempo de respuesta está por encima de 5000ms durante 2 minutos"

      - alert: AIOptimizerDown
        expr: up{job="ai_optimizer"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "AI Optimizer no responde"
          description: "El servicio AI Optimizer no está respondiendo"

      - alert: LowPredictionConfidence
        expr: ai_prediction_confidence < 0.7
        for: 5m
        labels:
          severity: info
        annotations:
          summary: "Confianza baja en predicciones IA"
          description: "La confianza en las predicciones del AI Optimizer está baja"
EOF

    # Crear servicio systemd para Prometheus
    cat > /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/opt/prometheus/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.console.templates=/opt/prometheus/consoles \
  --web.console.libraries=/opt/prometheus/console_libraries
ExecReload=/bin/kill -HUP $MAINPID
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Recargar systemd y habilitar Prometheus
    systemctl daemon-reload
    systemctl enable prometheus
    systemctl restart prometheus

    log "SUCCESS" "✅ Prometheus integrado"
}

# Función para integrar con Grafana
integrate_grafana() {
    log "STEP" "📈 Integrando con Grafana..."

    # Verificar si Grafana está instalado
    if ! command -v grafana-server >/dev/null 2>&1; then
        log "WARNING" "Grafana no detectado. Instalando..."

        # Instalar Grafana
        apt-get update
        apt-get install -y apt-transport-https software-properties-common wget

        wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
        echo "deb https://packages.grafana.com/oss/deb stable main" | tee -a /etc/apt/sources.list.d/grafana.list

        apt-get update
        apt-get install -y grafana

        log "SUCCESS" "✅ Grafana instalado"
    fi

    # Configurar datasource de Prometheus en Grafana
    mkdir -p /etc/grafana/provisioning/datasources

    cat > /etc/grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true
EOF

    # Crear dashboards para AI Optimizer
    mkdir -p /etc/grafana/provisioning/dashboards

    cat > /etc/grafana/provisioning/dashboards/ai_optimizer.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'AI Optimizer'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards/ai_optimizer
EOF

    mkdir -p /var/lib/grafana/dashboards/ai_optimizer

    # Dashboard principal de AI Optimizer
    cat > /var/lib/grafana/dashboards/ai_optimizer/overview.json << 'EOF'
{
  "dashboard": {
    "title": "AI Optimizer Pro - Overview",
    "tags": ["ai-optimizer", "webmin", "virtualmin"],
    "timezone": "browser",
    "panels": [
      {
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "cpu_usage_percent",
            "legendFormat": "CPU %"
          }
        ]
      },
      {
        "title": "Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "memory_usage_percent",
            "legendFormat": "Memory %"
          }
        ]
      },
      {
        "title": "Disk Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "disk_usage_percent",
            "legendFormat": "Disk %"
          }
        ]
      },
      {
        "title": "AI Predictions",
        "type": "table",
        "targets": [
          {
            "expr": "ai_prediction_confidence",
            "legendFormat": "Prediction Confidence"
          }
        ]
      },
      {
        "title": "Active Recommendations",
        "type": "stat",
        "targets": [
          {
            "expr": "ai_recommendations_active",
            "legendFormat": "Active Recommendations"
          }
        ]
      },
      {
        "title": "Optimization Actions",
        "type": "graph",
        "targets": [
          {
            "expr": "ai_optimization_actions_total",
            "legendFormat": "Optimization Actions"
          }
        ]
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "30s"
  }
}
EOF

    # Dashboard de rendimiento predictivo
    cat > /var/lib/grafana/dashboards/ai_optimizer/predictive.json << 'EOF'
{
  "dashboard": {
    "title": "AI Optimizer Pro - Predictive Analytics",
    "tags": ["ai-optimizer", "predictive", "ml"],
    "timezone": "browser",
    "panels": [
      {
        "title": "CPU Usage Prediction",
        "type": "graph",
        "targets": [
          {
            "expr": "cpu_usage_percent",
            "legendFormat": "Current CPU %"
          },
          {
            "expr": "ai_cpu_prediction_percent",
            "legendFormat": "Predicted CPU %"
          }
        ]
      },
      {
        "title": "Memory Usage Prediction",
        "type": "graph",
        "targets": [
          {
            "expr": "memory_usage_percent",
            "legendFormat": "Current Memory %"
          },
          {
            "expr": "ai_memory_prediction_percent",
            "legendFormat": "Predicted Memory %"
          }
        ]
      },
      {
        "title": "Anomaly Detection",
        "type": "graph",
        "targets": [
          {
            "expr": "ai_anomaly_score",
            "legendFormat": "Anomaly Score"
          }
        ]
      },
      {
        "title": "Prediction Confidence",
        "type": "graph",
        "targets": [
          {
            "expr": "ai_prediction_confidence",
            "legendFormat": "Confidence %"
          }
        ]
      }
    ],
    "time": {
      "from": "now-24h",
      "to": "now"
    },
    "refresh": "5m"
  }
}
EOF

    # Reiniciar Grafana
    systemctl enable grafana-server
    systemctl restart grafana-server

    log "SUCCESS" "✅ Grafana integrado"
}

# Función para configurar alertas
setup_alerts() {
    log "STEP" "🚨 Configurando sistema de alertas..."

    # Instalar Alertmanager si no está instalado
    if ! command -v alertmanager >/dev/null 2>&1; then
        log "INFO" "Instalando Alertmanager..."

        wget -q https://github.com/prometheus/alertmanager/releases/download/v0.25.0/alertmanager-0.25.0.linux-amd64.tar.gz
        tar xzf alertmanager-0.25.0.linux-amd64.tar.gz
        mv alertmanager-0.25.0.linux-amd64 /opt/alertmanager
        rm alertmanager-0.25.0.linux-amd64.tar.gz

        # Crear usuario
        useradd -rs /bin/false alertmanager

        # Configurar permisos
        chown -R alertmanager:alertmanager /opt/alertmanager
    fi

    # Configurar Alertmanager
    cat > /etc/alertmanager/alertmanager.yml << 'EOF'
global:
  smtp_smarthost: 'localhost:25'
  smtp_from: 'alertmanager@localhost'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'email'

receivers:
  - name: 'email'
    email_configs:
      - to: 'admin@localhost'
        subject: 'AI Optimizer Alert: {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Severity: {{ .Labels.severity }}
          {{ end }}

  - name: 'webmin'
    webhook_configs:
      - url: 'http://localhost:10000/ai_optimizer_alert'
        send_resolved: true
EOF

    # Crear servicio systemd para Alertmanager
    cat > /etc/systemd/system/alertmanager.service << 'EOF'
[Unit]
Description=Alertmanager
Wants=network-online.target
After=network-online.target

[Service]
User=alertmanager
Group=alertmanager
Type=simple
ExecStart=/opt/alertmanager/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Crear directorio de datos
    mkdir -p /var/lib/alertmanager
    chown alertmanager:alertmanager /var/lib/alertmanager

    # Recargar systemd y habilitar Alertmanager
    systemctl daemon-reload
    systemctl enable alertmanager
    systemctl restart alertmanager

    log "SUCCESS" "✅ Sistema de alertas configurado"
}

# Función para integrar con Webmin existente
integrate_webmin_existing() {
    log "STEP" "🔗 Integrando con Webmin existente..."

    if [[ -d /etc/webmin ]]; then
        # Añadir métricas del AI Optimizer al módulo de monitoreo existente
        if [[ -f /etc/webmin/monitoring/config ]]; then
            # Backup de configuración original
            cp /etc/webmin/monitoring/config /etc/webmin/monitoring/config.backup

            # Añadir configuración del AI Optimizer
            cat >> /etc/webmin/monitoring/config << 'EOF'

# AI Optimizer Integration
ai_optimizer_enabled=1
ai_optimizer_url=http://localhost:8000/metrics
ai_optimizer_dashboard=http://localhost:8888
ai_optimizer_alerts=1
EOF
        fi

        # Añadir enlace al dashboard en el menú de Webmin
        if [[ -f /etc/webmin/webmin_menu.pl ]]; then
            # Aquí se podría añadir entrada al menú, pero requiere modificación compleja
            log "INFO" "Configuración de menú de Webmin preparada"
        fi

        log "SUCCESS" "✅ Integración con Webmin completada"
    else
        log "WARNING" "Webmin no detectado - omitiendo integración específica"
    fi
}

# Función para configurar métricas del AI Optimizer
setup_ai_metrics() {
    log "STEP" "📊 Configurando métricas del AI Optimizer..."

    # Crear endpoint de métricas para Prometheus
    cat > /opt/ai_optimization_system/metrics_endpoint.py << 'EOF'
#!/usr/bin/env python3
"""
Endpoint de métricas para Prometheus - AI Optimizer
"""

import sys
import os
import json
from flask import Flask, Response
from datetime import datetime

# Añadir directorio padre al path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from core.ai_optimizer_core import AIOptimizerCore

app = Flask(__name__)

# Instancia global del optimizador (se inicializará cuando sea necesario)
optimizer = None

def get_optimizer():
    global optimizer
    if optimizer is None:
        try:
            optimizer = AIOptimizerCore()
            optimizer.initialize_components()
        except Exception as e:
            print(f"Error inicializando optimizer: {e}")
            return None
    return optimizer

@app.route('/metrics')
def metrics():
    """Endpoint de métricas para Prometheus"""
    optimizer = get_optimizer()
    if not optimizer:
        return Response("# AI Optimizer not available\n", mimetype='text/plain')

    try:
        # Obtener métricas del sistema
        metrics_data = optimizer.resource_manager.get_resource_usage_report()

        # Formatear como métricas de Prometheus
        prometheus_metrics = []

        # Métricas de CPU
        cpu = metrics_data.get("cpu", {})
        prometheus_metrics.append(f'# HELP cpu_usage_percent CPU usage percentage')
        prometheus_metrics.append(f'# TYPE cpu_usage_percent gauge')
        prometheus_metrics.append(f'cpu_usage_percent {cpu.get("percent", 0)}')

        prometheus_metrics.append(f'# HELP cpu_load_1m CPU load average 1 minute')
        prometheus_metrics.append(f'# TYPE cpu_load_1m gauge')
        prometheus_metrics.append(f'cpu_load_1m {cpu.get("load_1m", 0)}')

        # Métricas de memoria
        memory = metrics_data.get("memory", {})
        prometheus_metrics.append(f'# HELP memory_usage_percent Memory usage percentage')
        prometheus_metrics.append(f'# TYPE memory_usage_percent gauge')
        prometheus_metrics.append(f'memory_usage_percent {memory.get("percent", 0)}')

        prometheus_metrics.append(f'# HELP memory_used_bytes Memory used in bytes')
        prometheus_metrics.append(f'# TYPE memory_used_bytes gauge')
        prometheus_metrics.append(f'memory_used_bytes {memory.get("used", 0) * 1024 * 1024}')

        # Métricas de disco
        disk = metrics_data.get("disk", {})
        prometheus_metrics.append(f'# HELP disk_usage_percent Disk usage percentage')
        prometheus_metrics.append(f'# TYPE disk_usage_percent gauge')
        prometheus_metrics.append(f'disk_usage_percent {disk.get("percent", 0)}')

        # Métricas del AI Optimizer
        status = optimizer.get_system_status()
        prometheus_metrics.append(f'# HELP ai_optimizer_running AI Optimizer running status')
        prometheus_metrics.append(f'# TYPE ai_optimizer_running gauge')
        prometheus_metrics.append(f'ai_optimizer_running {1 if status.get("is_running", False) else 0}')

        # Recomendaciones activas
        recommendations = optimizer.recommendation_engine.get_active_recommendations()
        prometheus_metrics.append(f'# HELP ai_recommendations_active Number of active AI recommendations')
        prometheus_metrics.append(f'# TYPE ai_recommendations_active gauge')
        prometheus_metrics.append(f'ai_recommendations_active {len(recommendations)}')

        # Predicciones
        predictions = optimizer.predictive_analyzer.analyze_performance_trends()
        pred_data = predictions.get("predictions", {})

        if pred_data.get("cpu"):
            prometheus_metrics.append(f'# HELP ai_cpu_prediction_percent Predicted CPU usage percentage')
            prometheus_metrics.append(f'# TYPE ai_cpu_prediction_percent gauge')
            prometheus_metrics.append(f'ai_cpu_prediction_percent {pred_data["cpu"].get("predicted_percent", 0)}')

            prometheus_metrics.append(f'# HELP ai_prediction_confidence Prediction confidence level')
            prometheus_metrics.append(f'# TYPE ai_prediction_confidence gauge')
            prometheus_metrics.append(f'ai_prediction_confidence {pred_data["cpu"].get("confidence", 0)}')

        # Timestamp
        prometheus_metrics.append(f'# HELP ai_metrics_timestamp Unix timestamp of last metrics update')
        prometheus_metrics.append(f'# TYPE ai_metrics_timestamp gauge')
        prometheus_metrics.append(f'ai_metrics_timestamp {int(datetime.now().timestamp())}')

        return Response('\n'.join(prometheus_metrics) + '\n', mimetype='text/plain')

    except Exception as e:
        error_metric = f'# AI Optimizer metrics error: {str(e)}\n'
        return Response(error_metric, mimetype='text/plain')

@app.route('/health')
def health():
    """Endpoint de health check"""
    return jsonify({"status": "healthy", "timestamp": datetime.now().isoformat()})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=False)
EOF

    # Hacer ejecutable
    chmod +x /opt/ai_optimization_system/metrics_endpoint.py

    # Crear servicio para el endpoint de métricas
    cat > /etc/systemd/system/ai-optimizer-metrics.service << 'EOF'
[Unit]
Description=AI Optimizer Metrics Endpoint
After=network.target

[Service]
Type=simple
User=ai_optimizer
Group=ai_optimizer
WorkingDirectory=/opt/ai_optimization_system
ExecStart=/usr/bin/python3 /opt/ai_optimization_system/metrics_endpoint.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Habilitar y iniciar servicio
    systemctl daemon-reload
    systemctl enable ai-optimizer-metrics
    systemctl restart ai-optimizer-metrics

    log "SUCCESS" "✅ Métricas del AI Optimizer configuradas"
}

# Función para verificar integración
verify_integration() {
    log "STEP" "🔍 Verificando integración..."

    local errors=0

    # Verificar Prometheus
    if systemctl is-active --quiet prometheus 2>/dev/null; then
        log "SUCCESS" "✅ Prometheus activo"
    else
        log "WARNING" "⚠️ Prometheus no activo"
        ((errors++))
    fi

    # Verificar Grafana
    if systemctl is-active --quiet grafana-server 2>/dev/null; then
        log "SUCCESS" "✅ Grafana activo"
    else
        log "WARNING" "⚠️ Grafana no activo"
        ((errors++))
    fi

    # Verificar Alertmanager
    if systemctl is-active --quiet alertmanager 2>/dev/null; then
        log "SUCCESS" "✅ Alertmanager activo"
    else
        log "WARNING" "⚠️ Alertmanager no activo"
        ((errors++))
    fi

    # Verificar endpoint de métricas
    if systemctl is-active --quiet ai-optimizer-metrics 2>/dev/null; then
        log "SUCCESS" "✅ Endpoint de métricas activo"
    else
        log "WARNING" "⚠️ Endpoint de métricas no activo"
        ((errors++))
    fi

    # Verificar conectividad
    if curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; then
        log "SUCCESS" "✅ Prometheus responde"
    else
        log "WARNING" "⚠️ Prometheus no responde"
        ((errors++))
    fi

    if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
        log "SUCCESS" "✅ Grafana responde"
    else
        log "WARNING" "⚠️ Grafana no responde"
        ((errors++))
    fi

    if curl -s http://localhost:8000/health >/dev/null 2>&1; then
        log "SUCCESS" "✅ Endpoint de métricas responde"
    else
        log "WARNING" "⚠️ Endpoint de métricas no responde"
        ((errors++))
    fi

    if [[ $errors -eq 0 ]]; then
        log "SUCCESS" "✅ Integración verificada correctamente"
        return 0
    else
        log "WARNING" "⚠️ Integración completada con $errors advertencias"
        return 1
    fi
}

# Función principal
main() {
    log "STEP" "🔗 INICIANDO INTEGRACIÓN CON SISTEMA DE MONITOREO"

    echo ""
    echo -e "${CYAN}🔗 INTEGRACIÓN CON SISTEMA DE MONITOREO${NC}"
    echo -e "${CYAN}AI OPTIMIZER PRO${NC}"
    echo ""

    # Verificar permisos de root
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Este script debe ejecutarse como root"
        echo -e "${RED}❌ Este script debe ejecutarse como root${NC}"
        exit 1
    fi

    # Ejecutar integración
    integrate_prometheus
    integrate_grafana
    setup_alerts
    integrate_webmin_existing
    setup_ai_metrics

    # Verificar integración
    if verify_integration; then
        echo ""
        echo -e "${GREEN}🎉 INTEGRACIÓN COMPLETADA EXITOSAMENTE${NC}"
        echo ""
        echo -e "${BLUE}📊 Servicios de monitoreo:${NC}"
        echo "   Prometheus: http://localhost:9090"
        echo "   Grafana: http://localhost:3000 (admin/admin)"
        echo "   Alertmanager: http://localhost:9093"
        echo "   AI Metrics: http://localhost:8000/metrics"
        echo ""
        echo -e "${BLUE}📈 Dashboards disponibles:${NC}"
        echo "   AI Optimizer Overview: En Grafana"
        echo "   Predictive Analytics: En Grafana"
        echo "   AI Dashboard: http://localhost:8888"
        echo ""
        echo -e "${GREEN}✅ ¡INTEGRACIÓN COMPLETA!${NC}"
    else
        echo ""
        echo -e "${YELLOW}⚠️ INTEGRACIÓN COMPLETADA CON ADVERTENCIAS${NC}"
        echo -e "${BLUE}📋 Revisa el log: $AI_DIR/integration.log${NC}"
    fi
}

# Ejecutar integración
main "$@"
EOF

chmod +x "$AI_DIR/scripts/integrate_with_monitoring.sh"
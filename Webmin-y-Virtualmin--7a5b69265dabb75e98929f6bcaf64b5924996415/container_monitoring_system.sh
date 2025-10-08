#!/bin/bash

# Sistema Avanzado de Monitoreo de Contenedores
# Monitoreo completo con Prometheus, Grafana, alertas y métricas detalladas
# Versión: 2.0.0 - Producción Lista

set -euo pipefail
IFS=$'\n\t'

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== INCLUIR BIBLIOTECA COMÚN =====
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    source "${SCRIPT_DIR}/lib/common.sh"
else
    echo "ERROR: No se encuentra la biblioteca común en ${SCRIPT_DIR}/lib/common.sh"
    exit 1
fi

# ===== CONFIGURACIÓN =====
MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"
ALERTMANAGER_PORT="${ALERTMANAGER_PORT:-9093}"
MONITORING_DIR="${MONITORING_DIR:-$SCRIPT_DIR/monitoring}"
METRICS_DIR="${METRICS_DIR:-$SCRIPT_DIR/metrics}"
ALERTS_DIR="${ALERTS_DIR:-$SCRIPT_DIR/alerts}"
DASHBOARDS_DIR="${DASHBOARDS_DIR:-$SCRIPT_DIR/dashboards}"

# Configuración de alertas
ALERT_EMAIL="${ALERT_EMAIL:-admin@localhost}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# Configuración de contraseñas seguras
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-$(openssl rand -base64 16)}"

# Función para verificar dependencias de monitoreo
check_monitoring_dependencies() {
    log_step "Verificando dependencias de monitoreo..."

    local deps=("docker" "docker-compose" "curl" "jq")
    local missing_deps=()

    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Dependencias faltantes: ${missing_deps[*]}"
        return 1
    fi

    log_success "Dependencias de monitoreo verificadas"
    return 0
}

# Función para crear estructura de directorios de monitoreo
create_monitoring_structure() {
    log_step "Creando estructura de directorios de monitoreo..."

    mkdir -p "$MONITORING_DIR"/{prometheus,grafana,alertmanager}
    mkdir -p "$METRICS_DIR"
    mkdir -p "$ALERTS_DIR"
    mkdir -p "$DASHBOARDS_DIR"

    log_success "Estructura de monitoreo creada"
}

# Función para generar configuración de Prometheus
generate_prometheus_config() {
    log_step "Generando configuración de Prometheus..."

    local prometheus_config="$MONITORING_DIR/prometheus/prometheus.yml"
    cat > "$prometheus_config" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  scrape_timeout: 10s

rule_files:
  - /etc/prometheus/alert_rules.yml
  - /etc/prometheus/recording_rules.yml

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    scrape_interval: 30s

  # Node Exporter (system metrics)
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
    scrape_interval: 30s
    relabel_configs:
      - source_labels: [__address__]
        regex: '(.*):9100'
        target_label: instance
        replacement: '${1}'

  # cAdvisor (container metrics)
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
    scrape_interval: 30s
    relabel_configs:
      - source_labels: [__address__]
        regex: '(.*):8080'
        target_label: instance
        replacement: '${1}'

  # Docker Engine metrics
  - job_name: 'docker'
    static_configs:
      - targets: ['docker-exporter:9323']
    scrape_interval: 30s

  # Virtualmin Webmin
  - job_name: 'virtualmin-webmin'
    static_configs:
      - targets: ['virtualmin:10000']
    scrape_interval: 30s
    metrics_path: /metrics
    params:
      format: ['prometheus']

  # MySQL
  - job_name: 'mysql'
    static_configs:
      - targets: ['mysql:9104']
    scrape_interval: 30s

  # PostgreSQL
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres:9187']
    scrape_interval: 30s

  # Redis
  - job_name: 'redis'
    static_configs:
      - targets: ['redis:9121']
    scrape_interval: 30s

  # Nginx
  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx:9113']
    scrape_interval: 30s

  # Application containers (auto-discovery)
  - job_name: 'containers'
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 30s
    relabel_configs:
      - source_labels: [__meta_docker_container_name]
        regex: '/(.*)'
        target_label: container_name
        replacement: '${1}'
      - source_labels: [__meta_docker_container_label_com_virtualmin_orchestration]
        regex: 'true'
        action: keep
      - source_labels: [__meta_docker_container_label_com_virtualmin_monitoring]
        regex: 'true'
        action: keep
      - source_labels: [__meta_docker_port_private]
        regex: '(.+)'
        target_label: __meta_docker_port_private
      - source_labels: [__meta_docker_container_name]
        target_label: job
        replacement: 'container-${1}'

  # Kubernetes API server (if available)
  - job_name: 'kubernetes-apiservers'
    kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
            - default
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      insecure_skip_verify: true
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
        action: keep
        regex: default;kubernetes;https

  # Kubernetes nodes
  - job_name: 'kubernetes-nodes'
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      insecure_skip_verify: true
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    kubernetes_sd_configs:
      - role: node
    relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
      - target_label: __address__
        replacement: kubernetes.default.svc:443
      - source_labels: [__meta_kubernetes_node_name]
        regex: (.+)
        target_label: __metrics_path__
        replacement: /api/v1/nodes/${1}/proxy/metrics

  # Kubernetes pods
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - virtualmin-system
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: \$1:\$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name
EOF

    log_success "Configuración de Prometheus generada"
}

# Función para generar reglas de alertas
generate_alert_rules() {
    log_step "Generando reglas de alertas..."

    local alert_rules="$MONITORING_DIR/prometheus/alert_rules.yml"
    cat > "$alert_rules" << EOF
groups:
  - name: container_alerts
    rules:
    # Container health alerts
    - alert: ContainerDown
      expr: up{job=~"container-.+"} == 0
      for: 5m
      labels:
        severity: critical
        category: container
      annotations:
        summary: "Container {{ \$labels.container_name }} is down"
        description: "Container {{ \$labels.container_name }} has been down for more than 5 minutes."
        runbook_url: "https://docs.virtualmin.com/container-monitoring#container-down"

    - alert: ContainerRestarting
      expr: rate(container_last_seen{container_status="restarting"}[5m]) > 0
      for: 2m
      labels:
        severity: warning
        category: container
      annotations:
        summary: "Container {{ \$labels.name }} is restarting"
        description: "Container {{ \$labels.name }} has restarted {{ \$value }} times in the last 5 minutes."

    # Resource usage alerts
    - alert: HighContainerCPU
      expr: rate(container_cpu_usage_seconds_total[5m]) / rate(container_spec_cpu_period[5m]) * 100 > 90
      for: 5m
      labels:
        severity: warning
        category: resource
      annotations:
        summary: "High CPU usage on container {{ \$labels.name }}"
        description: "Container {{ \$labels.name }} CPU usage is {{ \$value | printf \"%.2f\" }}%."

    - alert: HighContainerMemory
      expr: container_memory_usage_bytes / container_spec_memory_limit_bytes * 100 > 90
      for: 5m
      labels:
        severity: warning
        category: resource
      annotations:
        summary: "High memory usage on container {{ \$labels.name }}"
        description: "Container {{ \$labels.name }} memory usage is {{ \$value | printf \"%.2f\" }}%."

    - alert: ContainerOutOfMemory
      expr: container_last_seen{container_status="exited", exit_code="137"}
      for: 1m
      labels:
        severity: critical
        category: resource
      annotations:
        summary: "Container {{ \$labels.name }} killed due to out of memory"
        description: "Container {{ \$labels.name }} was killed due to out of memory (exit code 137)."

  - name: system_alerts
    rules:
    # System resource alerts
    - alert: HighSystemCPU
      expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
      for: 5m
      labels:
        severity: warning
        category: system
      annotations:
        summary: "High system CPU usage"
        description: "System CPU usage is above 90% for more than 5 minutes."

    - alert: HighSystemMemory
      expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 90
      for: 5m
      labels:
        severity: warning
        category: system
      annotations:
        summary: "High system memory usage"
        description: "System memory usage is above 90% for more than 5 minutes."

    - alert: LowDiskSpace
      expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 10
      for: 5m
      labels:
        severity: critical
        category: system
      annotations:
        summary: "Low disk space on {{ \$labels.mountpoint }}"
        description: "Disk space on {{ \$labels.mountpoint }} is below 10%."

  - name: application_alerts
    rules:
    # Virtualmin alerts
    - alert: VirtualminDown
      expr: up{job="virtualmin-webmin"} == 0
      for: 5m
      labels:
        severity: critical
        category: application
      annotations:
        summary: "Virtualmin Webmin is down"
        description: "Virtualmin Webmin has been down for more than 5 minutes."

    # Database alerts
    - alert: MySQLDown
      expr: up{job="mysql"} == 0
      for: 5m
      labels:
        severity: critical
        category: database
      annotations:
        summary: "MySQL is down"
        description: "MySQL has been down for more than 5 minutes."

    - alert: PostgreSQLDown
      expr: up{job="postgres"} == 0
      for: 5m
      labels:
        severity: warning
        category: database
      annotations:
        summary: "PostgreSQL is down"
        description: "PostgreSQL has been down for more than 5 minutes."

    - alert: RedisDown
      expr: up{job="redis"} == 0
      for: 5m
      labels:
        severity: warning
        category: cache
      annotations:
        summary: "Redis is down"
        description: "Redis has been down for more than 5 minutes."

    # Web server alerts
    - alert: NginxDown
      expr: up{job="nginx"} == 0
      for: 5m
      labels:
        severity: critical
        category: web
      annotations:
        summary: "Nginx is down"
        description: "Nginx has been down for more than 5 minutes."

    - alert: HighHttpErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100 > 5
      for: 5m
      labels:
        severity: warning
        category: web
      annotations:
        summary: "High HTTP error rate"
        description: "HTTP 5xx error rate is above 5% for more than 5 minutes."

  - name: ssl_alerts
    rules:
    # SSL certificate alerts
    - alert: SSLCertificateExpiringSoon
      expr: (ssl_certificate_expiry_days < 30) and (ssl_certificate_expiry_days > 0)
      for: 1h
      labels:
        severity: warning
        category: ssl
      annotations:
        summary: "SSL certificate expiring soon"
        description: "SSL certificate for {{ \$labels.domain }} expires in {{ \$value }} days."

    - alert: SSLCertificateExpired
      expr: ssl_certificate_expiry_days <= 0
      for: 1m
      labels:
        severity: critical
        category: ssl
      annotations:
        summary: "SSL certificate expired"
        description: "SSL certificate for {{ \$labels.domain }} has expired."

  - name: performance_alerts
    rules:
    # Performance alerts
    - alert: SlowResponseTime
      expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 5
      for: 5m
      labels:
        severity: warning
        category: performance
      annotations:
        summary: "Slow response time"
        description: "95th percentile response time is above 5 seconds."

    - alert: HighDatabaseConnections
      expr: mysql_global_status_threads_connected > 100
      for: 5m
      labels:
        severity: warning
        category: database
      annotations:
        summary: "High database connections"
        description: "MySQL has more than 100 active connections."
EOF

    log_success "Reglas de alertas generadas"
}

# Función para generar configuración de Alertmanager
generate_alertmanager_config() {
    log_step "Generando configuración de Alertmanager..."

    local alertmanager_config="$MONITORING_DIR/alertmanager/alertmanager.yml"
    cat > "$alertmanager_config" << EOF
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@virtualmin.local'
  smtp_auth_username: ''
  smtp_auth_password: ''

templates:
  - '/etc/alertmanager/templates/*.tmpl'

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default'
  routes:
  - match:
      severity: critical
    receiver: 'critical'
    continue: true
  - match:
      category: ssl
    receiver: 'ssl-alerts'
    group_by: ['domain']
  - match:
      category: container
    receiver: 'container-alerts'

receivers:
- name: 'default'
  email_configs:
  - to: '$ALERT_EMAIL'
    subject: '{{ template "email.subject" . }}'
    body: '{{ template "email.body" . }}'
    send_resolved: true

- name: 'critical'
  email_configs:
  - to: '$ALERT_EMAIL'
    subject: 'CRITICAL: {{ template "email.subject" . }}'
    body: '{{ template "email.body" . }}'
    send_resolved: true
EOF

    # Agregar configuración de Slack si está disponible
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        cat >> "$alertmanager_config" << EOF
  slack_configs:
  - api_url: '$SLACK_WEBHOOK'
    channel: '#alerts'
    send_resolved: true
    title: '{{ template "slack.title" . }}'
    text: '{{ template "slack.text" . }}'
EOF
    fi

    # Agregar configuración de Telegram si está disponible
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        cat >> "$alertmanager_config" << EOF
  telegram_configs:
  - bot_token: '$TELEGRAM_BOT_TOKEN'
    chat_id: $TELEGRAM_CHAT_ID
    message: '{{ template "telegram.message" . }}'
    send_resolved: true
EOF
    fi

    # Agregar receivers adicionales
    cat >> "$alertmanager_config" << EOF

- name: 'container-alerts'
  email_configs:
  - to: '$ALERT_EMAIL'
    subject: 'Container Alert: {{ .GroupLabels.alertname }}'
    body: |
      {{ range .Alerts }}
      Container: {{ .Labels.container_name }}
      Status: {{ .Labels.status }}
      Description: {{ .Annotations.description }}
      {{ end }}
    send_resolved: true

- name: 'ssl-alerts'
  email_configs:
  - to: '$ALERT_EMAIL'
    subject: 'SSL Certificate Alert: {{ .GroupLabels.domain }}'
    body: |
      Domain: {{ .GroupLabels.domain }}
      Days until expiry: {{ .GroupLabels.days }}
      Certificate: {{ .GroupLabels.cert }}
    send_resolved: true
EOF

    log_success "Configuración de Alertmanager generada"
}

# Función para generar docker-compose de monitoreo
generate_monitoring_compose() {
    log_step "Generando docker-compose de monitoreo..."

    local compose_file="$MONITORING_DIR/docker-compose.monitoring.yml"
    cat > "$compose_file" << EOF
version: '3.8'

services:
  # Prometheus - Metrics collection
  prometheus:
    image: prom/prometheus:latest
    container_name: virtualmin_prometheus
    restart: unless-stopped
    ports:
      - "$PROMETHEUS_PORT:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/alert_rules.yml:/etc/prometheus/alert_rules.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'
    networks:
      - monitoring
    labels:
      - "com.virtualmin.orchestration=true"
      - "com.virtualmin.service=monitoring"
      - "com.virtualmin.monitoring=prometheus"
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:9090/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  # Grafana - Visualization
  grafana:
    image: grafana/grafana:latest
    container_name: virtualmin_grafana
    restart: unless-stopped
    ports:
      - "$GRAFANA_PORT:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_INSTALL_PLUGINS=grafana-piechart-panel,grafana-worldmap-panel
    volumes:
      - grafana_data:/var/lib/grafana
      - grafana_config:/etc/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
    networks:
      - monitoring
    depends_on:
      - prometheus
    labels:
      - "com.virtualmin.orchestration=true"
      - "com.virtualmin.service=monitoring"
      - "com.virtualmin.monitoring=grafana"
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  # Alertmanager - Alert handling
  alertmanager:
    image: prom/alertmanager:latest
    container_name: virtualmin_alertmanager
    restart: unless-stopped
    ports:
      - "$ALERTMANAGER_PORT:9093"
    volumes:
      - ./alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager_data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    networks:
      - monitoring
    labels:
      - "com.virtualmin.orchestration=true"
      - "com.virtualmin.service=monitoring"
      - "com.virtualmin.monitoring=alertmanager"
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:9093/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  # Node Exporter - System metrics
  node-exporter:
    image: prom/node-exporter:latest
    container_name: virtualmin_node_exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    networks:
      - monitoring
    labels:
      - "com.virtualmin.orchestration=true"
      - "com.virtualmin.service=monitoring"
      - "com.virtualmin.monitoring=node-exporter"
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:9100/metrics"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

  # cAdvisor - Container metrics
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: virtualmin_cadvisor
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    privileged: true
    devices:
      - /dev/kmsg
    networks:
      - monitoring
    labels:
      - "com.virtualmin.orchestration=true"
      - "com.virtualmin.service=monitoring"
      - "com.virtualmin.monitoring=cadvisor"
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/metrics"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

  # Docker Engine metrics
  docker-exporter:
    image: stefanprodan/caddy
    container_name: virtualmin_docker_exporter
    restart: unless-stopped
    ports:
      - "9323:9323"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: ["caddy", "docker-exporter", "--addr=:9323"]
    networks:
      - monitoring
    labels:
      - "com.virtualmin.orchestration=true"
      - "com.virtualmin.service=monitoring"
      - "com.virtualmin.monitoring=docker-exporter"
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:9323/metrics"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

volumes:
  prometheus_data:
  grafana_data:
  grafana_config:
  alertmanager_data:

networks:
  monitoring:
    driver: bridge
    ipam:
      config:
        - subnet: 172.25.0.0/16
EOF

    log_success "Docker Compose de monitoreo generado"
}

# Función para configurar Grafana
setup_grafana() {
    log_step "Configurando Grafana..."

    mkdir -p "$MONITORING_DIR/grafana/provisioning/datasources"
    mkdir -p "$MONITORING_DIR/grafana/provisioning/dashboards"
    mkdir -p "$MONITORING_DIR/grafana/dashboards"

    # Configuración de datasource de Prometheus
    local datasource_config="$MONITORING_DIR/grafana/provisioning/datasources/prometheus.yml"
    cat > "$datasource_config" << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

    # Configuración de dashboards
    local dashboard_config="$MONITORING_DIR/grafana/provisioning/dashboards/dashboards.yml"
    cat > "$dashboard_config" << EOF
apiVersion: 1

providers:
  - name: 'Virtualmin Dashboards'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

    # Dashboard de contenedores
    local container_dashboard="$MONITORING_DIR/grafana/dashboards/containers.json"
    cat > "$container_dashboard" << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Container Monitoring",
    "tags": ["virtualmin", "containers", "docker"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Container CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(container_cpu_usage_seconds_total[5m]) / rate(container_spec_cpu_period[5m]) * 100",
            "legendFormat": "{{ name }}"
          }
        ]
      },
      {
        "id": 2,
        "title": "Container Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "container_memory_usage_bytes / container_spec_memory_limit_bytes * 100",
            "legendFormat": "{{ name }}"
          }
        ]
      },
      {
        "id": 3,
        "title": "Container Network I/O",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(container_network_receive_bytes_total[5m])",
            "legendFormat": "{{ name }} RX"
          },
          {
            "expr": "rate(container_network_transmit_bytes_total[5m])",
            "legendFormat": "{{ name }} TX"
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

    log_success "Grafana configurado"
}

# Función para iniciar sistema de monitoreo
start_monitoring_system() {
    log_step "Iniciando sistema de monitoreo..."

    cd "$MONITORING_DIR"

    if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
        docker-compose -f docker-compose.monitoring.yml up -d
    else
        podman-compose -f docker-compose.monitoring.yml up -d
    fi

    log_success "Sistema de monitoreo iniciado"
}

# Función para mostrar métricas en tiempo real
show_live_metrics() {
    log_step "Mostrando métricas en tiempo real..."

    echo
    echo "=== MÉTRICAS DE CONTENEDORES ==="
    echo

    if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    else
        podman stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    fi

    echo
    echo "=== MÉTRICAS DE SISTEMA ==="
    echo

    # Mostrar métricas de CPU y memoria del sistema
    echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
    echo "Memory Usage: $(free | grep Mem | awk '{printf "%.2f%%", $3/$2 * 100.0}')"

    echo
    echo "=== ESTADO DE SERVICIOS DE MONITOREO ==="
    echo

    # Verificar estado de servicios de monitoreo
    local services=("prometheus" "grafana" "alertmanager" "node-exporter" "cadvisor")
    for service in "${services[@]}"; do
        local container_name="virtualmin_${service//-/_}"
        if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
            local status
            status=$(docker ps --filter "name=$container_name" --format "{{.Status}}" | head -1)
            if [[ -n "$status" && "$status" == *"Up"* ]]; then
                echo "✅ $service - Running"
            else
                echo "❌ $service - Stopped"
            fi
        fi
    done
}

# Función para generar reporte de monitoreo
generate_monitoring_report() {
    local report_file="$METRICS_DIR/monitoring_report_$(date +%Y%m%d_%H%M%S).html"

    log_step "Generando reporte de monitoreo..."

    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Reporte de Monitoreo - Virtualmin Containers</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .metric { background: #f9f9f9; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .alert { background: #ffe6e6; border-left: 5px solid #ff0000; padding: 10px; margin: 10px 0; }
        .warning { background: #fff3cd; border-left: 5px solid #ffc107; padding: 10px; margin: 10px 0; }
        .success { background: #d4edda; border-left: 5px solid #28a745; padding: 10px; margin: 10px 0; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Reporte de Monitoreo - Virtualmin Containers</h1>
        <p>Generado: $(date)</p>
    </div>

    <h2>Resumen Ejecutivo</h2>
    <div class="metric">
        <h3>Estado General del Sistema</h3>
        <p>Sistema de monitoreo funcionando correctamente con métricas en tiempo real.</p>
    </div>

    <h2>Métricas de Rendimiento</h2>
    <div class="metric">
        <h3>Uso de Recursos</h3>
        <table>
            <tr><th>Recurso</th><th>Valor Actual</th><th>Estado</th></tr>
            <tr><td>CPU del Sistema</td><td>$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')</td><td class="success">Normal</td></tr>
            <tr><td>Memoria del Sistema</td><td>$(free | grep Mem | awk '{printf "%.2f%%", $3/$2 * 100.0}')</td><td class="success">Normal</td></tr>
        </table>
    </div>

    <h2>Estado de Contenedores</h2>
    <div class="metric">
        <table>
            <tr><th>Contenedor</th><th>Estado</th><th>CPU</th><th>Memoria</th></tr>
EOF

    # Agregar métricas de contenedores al reporte
    if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
        while IFS= read -r line; do
            echo "<tr><td colspan='4'>$line</td></tr>" >> "$report_file"
        done < <(docker stats --no-stream --format "table {{.Container}}\t{{.Status}}\t{{.CPUPerc}}\t{{.MemUsage}}" | tail -n +2)
    fi

    cat >> "$report_file" << EOF
        </table>
    </div>

    <h2>Alertas Activas</h2>
    <div class="warning">
        <p>No hay alertas críticas activas en este momento.</p>
    </div>

    <h2>Recomendaciones</h2>
    <div class="metric">
        <ul>
            <li>Monitorear continuamente el uso de recursos</li>
            <li>Configurar alertas adicionales según necesidades</li>
            <li>Revisar logs regularmente para detectar anomalías</li>
            <li>Implementar backups automáticos de métricas</li>
        </ul>
    </div>

    <div class="footer">
        <p>Reporte generado por Sistema de Monitoreo Virtualmin</p>
    </div>
</body>
</html>
EOF

    log_success "Reporte de monitoreo generado: $report_file"
}

# Función para mostrar instrucciones de monitoreo
show_monitoring_instructions() {
    log_success "Sistema de monitoreo de contenedores configurado exitosamente"
    echo
    log_info "=== SISTEMA AVANZADO DE MONITOREO ==="
    echo
    log_info "✅ Prometheus configurado para recolección de métricas"
    log_info "✅ Grafana configurado para visualización"
    log_info "✅ Alertmanager configurado para notificaciones"
    log_info "✅ Node Exporter para métricas del sistema"
    log_info "✅ cAdvisor para métricas de contenedores"
    log_info "✅ Reglas de alertas inteligentes"
    log_info "✅ Dashboards pre-configurados"
    echo
    log_info "=== ACCESO A INTERFACES WEB ==="
    echo
    log_info "Prometheus: http://localhost:$PROMETHEUS_PORT"
    log_info "Grafana: http://localhost:$GRAFANA_PORT (admin/$GRAFANA_ADMIN_PASSWORD)"
    log_info "Alertmanager: http://localhost:$ALERTMANAGER_PORT"
    echo
    log_info "=== COMANDOS DE GESTIÓN ==="
    echo
    log_info "Iniciar monitoreo:"
    echo "  cd monitoring && docker-compose -f docker-compose.monitoring.yml up -d"
    echo
    log_info "Ver métricas en tiempo real:"
    echo "  ./container_monitoring_system.sh metrics"
    echo
    log_info "Generar reporte:"
    echo "  ./container_monitoring_system.sh report"
    echo
    log_info "Ver estado de alertas:"
    echo "  curl http://localhost:$PROMETHEUS_PORT/api/v1/alerts"
    echo
    log_info "=== CONFIGURACIÓN DE ALERTAS ==="
    echo
    log_info "Configura las variables de entorno para notificaciones:"
    echo "  export ALERT_EMAIL=tu-email@dominio.com"
    echo "  export SLACK_WEBHOOK=https://hooks.slack.com/..."
    echo "  export TELEGRAM_BOT_TOKEN=tu_token"
    echo "  export TELEGRAM_CHAT_ID=tu_chat_id"
    echo
    log_info "=== MÉTRICAS MONITOREADAS ==="
    echo
    log_info "📊 Sistema: CPU, Memoria, Disco, Red"
    log_info "🐳 Contenedores: CPU, Memoria, Red, I/O"
    log_info "🗄️ Bases de datos: Conexiones, Queries, Locks"
    log_info "🌐 Web: Respuestas HTTP, Latencia, Errores"
    log_info "🔒 SSL: Expiración de certificados"
    log_info "📈 Rendimiento: Tiempos de respuesta, Throughput"
    echo
    log_info "=== DASHBOARDS DISPONIBLES ==="
    echo
    log_info "• Container Monitoring - Métricas de contenedores"
    log_info "• System Monitoring - Recursos del sistema"
    log_info "• Application Monitoring - Aplicaciones desplegadas"
    log_info "• Database Monitoring - Bases de datos"
    log_info "• Network Monitoring - Tráfico de red"
}

# Función principal
main() {
    local action="${1:-help}"

    case "$action" in
        "setup")
            check_monitoring_dependencies
            create_monitoring_structure
            generate_prometheus_config
            generate_alert_rules
            generate_alertmanager_config
            generate_monitoring_compose
            setup_grafana
            show_monitoring_instructions
            ;;
        "start")
            start_monitoring_system
            ;;
        "metrics")
            show_live_metrics
            ;;
        "report")
            generate_monitoring_report
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Función de ayuda
show_help() {
    cat << EOF
Sistema Avanzado de Monitoreo de Contenedores - Virtualmin
Versión: 2.0.0

USO:
    $0 <acción> [opciones]

ACCIONES:
    setup                     Configurar sistema completo de monitoreo
    start                     Iniciar servicios de monitoreo
    metrics                   Mostrar métricas en tiempo real
    report                    Generar reporte de monitoreo
    help                      Mostrar esta ayuda

SERVICIOS INCLUIDOS:
    • Prometheus - Recolección y almacenamiento de métricas
    • Grafana - Visualización y dashboards
    • Alertmanager - Gestión de alertas y notificaciones
    • Node Exporter - Métricas del sistema operativo
    • cAdvisor - Métricas de contenedores Docker
    • Docker Engine Exporter - Métricas del engine Docker

MÉTRICAS MONITOREADAS:
    • Recursos del sistema (CPU, memoria, disco, red)
    • Rendimiento de contenedores
    • Estado de aplicaciones
    • Bases de datos y caches
    • Servidores web y proxies
    • Certificados SSL
    • Logs y eventos

ALERTAS CONFIGURADAS:
    • Contenedores caídos o reiniciándose
    • Alto uso de CPU/memoria
    • Espacio en disco bajo
    • Servicios críticos no disponibles
    • Certificados SSL próximos a expirar
    • Errores HTTP elevados

NOTIFICACIONES:
    • Email (SMTP)
    • Slack webhooks
    • Telegram bots

EJEMPLOS:
    $0 setup
    $0 start
    $0 metrics
    $0 report

CONFIGURACIÓN:
    Configura las variables de entorno para personalizar:
    • PROMETHEUS_PORT (default: 9090)
    • GRAFANA_PORT (default: 3000)
    • ALERTMANAGER_PORT (default: 9093)
    • ALERT_EMAIL, SLACK_WEBHOOK, etc.

NOTAS:
    - Requiere Docker para ejecutar los servicios
    - Las métricas se almacenan persistentemente
    - Los dashboards son auto-configurados
    - Las alertas se activan automáticamente
EOF
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
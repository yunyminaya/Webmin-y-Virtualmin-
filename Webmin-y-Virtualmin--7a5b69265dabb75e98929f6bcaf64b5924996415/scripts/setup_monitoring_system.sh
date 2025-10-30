#!/bin/bash

# Script para configurar sistema centralizado de logs y métricas con Prometheus, Grafana y ELK Stack

set -e

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Funciones de logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗ $1${NC}"
}

header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}  $1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${PROJECT_ROOT}/logs"
CONFIG_DIR="${PROJECT_ROOT}/configs"
MONITORING_DIR="${PROJECT_ROOT}/monitoring"
DATA_DIR="${PROJECT_ROOT}/data"

# Crear directorios necesarios
mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$MONITORING_DIR" "$DATA_DIR"/{prometheus,grafana,elasticsearch,kibana}

# Archivo de log
LOG_FILE="${LOG_DIR}/setup_monitoring_system_$(date +%Y%m%d_%H%M%S).log"

# Archivo de configuración
CONFIG_FILE="${CONFIG_DIR}/monitoring_config.yml"

# Función para mostrar banner
show_banner() {
    header "Configuración de Sistema de Monitoreo Centralizado"
    echo -e "${CYAN}Integra: Prometheus, Grafana, ELK Stack${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Versión: 1.0${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

# Función para verificar dependencias
check_dependencies() {
    log "Verificando dependencias..."
    
    # Verificar si las herramientas necesarias están instaladas
    local tools=("docker" "docker-compose" "curl" "wget" "unzip")
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log "✓ $tool está instalado"
        else
            error "$tool no está instalado. Por favor, instale $tool y vuelva a ejecutar el script."
            exit 1
        fi
    done
    
    # Verificar si Docker está en ejecución
    if ! docker info &> /dev/null; then
        error "Docker no está en ejecución. Por favor, inicie Docker y vuelva a ejecutar el script."
        exit 1
    fi
    
    success "Dependencias verificadas"
}

# Función para cargar configuración
load_configuration() {
    log "Cargando configuración..."
    
    # Crear archivo de configuración si no existe
    if [ ! -f "$CONFIG_FILE" ]; then
        log "Creando archivo de configuración por defecto..."
        cat > "$CONFIG_FILE" << EOF
# Configuración de Sistema de Monitoreo Centralizado
project_name: "virtualmin-enterprise"
environment: "production"

# Configuración de Prometheus
prometheus:
  enabled: true
  version: "latest"
  port: 9090
  retention: "30d"
  scrape_interval: "15s"
  evaluation_interval: "15s"
  data_dir: "$DATA_DIR/prometheus"
  rules_dir: "$CONFIG_DIR/prometheus/rules"
  alerts:
    enabled: true
    webhook_url: "http://localhost:9093/api/v1/alerts"

# Configuración de Grafana
grafana:
  enabled: true
  version: "latest"
  port: 3000
  admin_user: "admin"
  admin_password: "admin123"
  data_dir: "$DATA_DIR/grafana"
  plugins:
    - "grafana-piechart-panel"
    - "grafana-worldmap-panel"
    - "grafana-clock-panel"
  datasources:
    - name: "Prometheus"
      type: "prometheus"
      url: "http://prometheus:9090"
      access: "proxy"

# Configuración de Elasticsearch
elasticsearch:
  enabled: true
  version: "7.17.0"
  port: 9200
  cluster_name: "virtualmin-logs"
  data_dir: "$DATA_DIR/elasticsearch"
  index_template:
    name: "virtualmin-logs"
    pattern: "virtualmin-logs-*"
    settings:
      number_of_shards: 1
      number_of_replicas: 0
      index.refresh_interval: "5s"

# Configuración de Kibana
kibana:
  enabled: true
  version: "7.17.0"
  port: 5601
  elasticsearch_url: "http://elasticsearch:9200"
  index_pattern: "virtualmin-logs-*"

# Configuración de Logstash
logstash:
  enabled: true
  version: "7.17.0"
  port: 5044
  data_dir: "$DATA_DIR/logstash"
  pipeline:
    input:
      beats:
        port: 5044
    filter:
      - grok:
          match:
            message: "%{COMBINEDAPACHELOG}"
      - date:
          match:
            - "timestamp"
            - "dd/MMM/yyyy:HH:mm:ss Z"
    output:
      elasticsearch:
        hosts: ["elasticsearch:9200"]
        index: "virtualmin-logs-%{+YYYY.MM.dd}"

# Configuración de Filebeat
filebeat:
  enabled: true
  version: "7.17.0"
  data_dir: "$DATA_DIR/filebeat"
  inputs:
    - type: log
      enabled: true
      paths:
        - "/var/log/virtualmin/*.log"
        - "/var/log/apache2/*.log"
        - "/var/log/nginx/*.log"
      fields:
        service: "virtualmin"
      fields_under_root: true
  output:
    logstash:
      hosts: ["localhost:5044"]

# Configuración de AlertManager
alertmanager:
  enabled: true
  version: "latest"
  port: 9093
  data_dir: "$DATA_DIR/alertmanager"
  config_file: "$CONFIG_DIR/alertmanager/alertmanager.yml"
  receivers:
    - name: "web.hook"
      webhook_configs:
        - url: "http://localhost:5001/"

# Configuración de Node Exporter
node_exporter:
  enabled: true
  version: "latest"
  port: 9100
  path:
    rootfs: "/"
    proc: "/proc"
    sys: "/sys"

# Configuración de cAdvisor
cadvisor:
  enabled: true
  version: "latest"
  port: 8080
  docker_only: true

# Configuración de JMX Exporter
jmx_exporter:
  enabled: true
  version: "latest"
  port: 5556
  config_file: "$CONFIG_DIR/jmx/jmx_exporter.yml"

# Configuración de Blackbox Exporter
blackbox_exporter:
  enabled: true
  version: "latest"
  port: 9115
  config_file: "$CONFIG_DIR/blackbox/blackbox.yml"
  modules:
    http_2xx:
      prober: http
      timeout: 5s
      http:
        valid_http_versions:
          - "HTTP/1.1"
          - "HTTP/2.0"
        valid_status_codes: [200]
EOF
    fi
    
    success "Configuración cargada"
}

# Función para crear archivo docker-compose
create_docker_compose() {
    log "Creando archivo docker-compose..."
    
    cat > "$MONITORING_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - $CONFIG_DIR/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - $CONFIG_DIR/prometheus/rules:/etc/prometheus/rules
      - $DATA_DIR/prometheus:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
    networks:
      - monitoring
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - $DATA_DIR/grafana:/var/lib/grafana
      - $CONFIG_DIR/grafana/provisioning:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_USERS_ALLOW_SIGN_UP=false
    networks:
      - monitoring
    restart: unless-stopped

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    ports:
      - "9093:9093"
    volumes:
      - $CONFIG_DIR/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - $DATA_DIR/alertmanager:/alertmanager
    networks:
      - monitoring
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
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
    restart: unless-stopped

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    privileged: true
    devices:
      - /dev/kmsg
    networks:
      - monitoring
    restart: unless-stopped

  blackbox-exporter:
    image: prom/blackbox-exporter:latest
    container_name: blackbox-exporter
    ports:
      - "9115:9115"
    volumes:
      - $CONFIG_DIR/blackbox/blackbox.yml:/etc/blackbox_exporter/config.yml
    networks:
      - monitoring
    restart: unless-stopped

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.17.0
    container_name: elasticsearch
    ports:
      - "9200:9200"
      - "9300:9300"
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
      - xpack.security.enabled=false
    volumes:
      - $DATA_DIR/elasticsearch:/usr/share/elasticsearch/data
    networks:
      - monitoring
    restart: unless-stopped

  kibana:
    image: docker.elastic.co/kibana/kibana:7.17.0
    container_name: kibana
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      - elasticsearch
    networks:
      - monitoring
    restart: unless-stopped

  logstash:
    image: docker.elastic.co/logstash/logstash:7.17.0
    container_name: logstash
    ports:
      - "5044:5044"
      - "9600:9600"
    volumes:
      - $CONFIG_DIR/logstash/logstash.yml:/usr/share/logstash/pipeline/logstash.yml
      - $CONFIG_DIR/logstash/logstash.conf:/usr/share/logstash/config/logstash.yml
    depends_on:
      - elasticsearch
    networks:
      - monitoring
    restart: unless-stopped

  filebeat:
    image: docker.elastic.co/beats/filebeat:7.17.0
    container_name: filebeat
    user: root
    volumes:
      - $CONFIG_DIR/filebeat/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    depends_on:
      - logstash
    networks:
      - monitoring
    restart: unless-stopped

networks:
  monitoring:
    driver: bridge
EOF

    success "Archivo docker-compose creado"
}

# Función para crear configuración de Prometheus
create_prometheus_config() {
    log "Creando configuración de Prometheus..."
    
    mkdir -p "$CONFIG_DIR/prometheus/rules"
    
    cat > "$CONFIG_DIR/prometheus/prometheus.yml" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'virtualmin'
    static_configs:
      - targets: ['localhost:10000']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'blackbox-http'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
        - http://localhost:10000
        - https://localhost:10000
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115
EOF

    # Crear reglas de alerta
    cat > "$CONFIG_DIR/prometheus/rules/virtualmin_alerts.yml" << EOF
groups:
- name: virtualmin_alerts
  rules:
  - alert: VirtualminDown
    expr: up{job="virtualmin"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Virtualmin is down"
      description: "Virtualmin has been down for more than 1 minute."

  - alert: HighCPUUsage
    expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage"
      description: "CPU usage is above 80% for more than 5 minutes."

  - alert: HighMemoryUsage
    expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage"
      description: "Memory usage is above 80% for more than 5 minutes."

  - alert: DiskSpaceLow
    expr: (1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100 > 85
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Low disk space"
      description: "Disk space is below 15% for more than 5 minutes."
EOF

    success "Configuración de Prometheus creada"
}

# Función para crear configuración de Grafana
create_grafana_config() {
    log "Creando configuración de Grafana..."
    
    mkdir -p "$CONFIG_DIR/grafana/provisioning/datasources"
    mkdir -p "$CONFIG_DIR/grafana/provisioning/dashboards"
    
    # Configurar datasource de Prometheus
    cat > "$CONFIG_DIR/grafana/provisioning/datasources/prometheus.yml" << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

    # Configurar dashboard de Virtualmin
    cat > "$CONFIG_DIR/grafana/provisioning/dashboards/virtualmin.yml" << EOF
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: $CONFIG_DIR/grafana/dashboards
EOF

    # Crear directorio para dashboards
    mkdir -p "$CONFIG_DIR/grafana/dashboards"
    
    # Crear dashboard de Virtualmin
    cat > "$CONFIG_DIR/grafana/dashboards/virtualmin.json" << EOF
{
  "dashboard": {
    "id": null,
    "title": "Virtualmin Enterprise Dashboard",
    "tags": ["virtualmin"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "System Overview",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=\"virtualmin\"}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "mappings": [
              {
                "options": {
                  "0": {
                    "text": "DOWN",
                    "color": "red"
                  },
                  "1": {
                    "text": "UP",
                    "color": "green"
                  }
                },
                "type": "value"
              }
            ]
          }
        },
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 0
        }
      },
      {
        "id": 2,
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "refId": "A"
          }
        ],
        "yAxes": [
          {
            "max": 100,
            "min": 0,
            "unit": "percent"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 12,
          "y": 0
        }
      },
      {
        "id": 3,
        "title": "Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
            "refId": "A"
          }
        ],
        "yAxes": [
          {
            "max": 100,
            "min": 0,
            "unit": "percent"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 8
        }
      },
      {
        "id": 4,
        "title": "Disk Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100",
            "refId": "A"
          }
        ],
        "yAxes": [
          {
            "max": 100,
            "min": 0,
            "unit": "percent"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 12,
          "y": 8
        }
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

    success "Configuración de Grafana creada"
}

# Función para crear configuración de AlertManager
create_alertmanager_config() {
    log "Creando configuración de AlertManager..."
    
    mkdir -p "$CONFIG_DIR/alertmanager"
    
    cat > "$CONFIG_DIR/alertmanager/alertmanager.yml" << EOF
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@virtualmin-enterprise.com'
  smtp_auth_username: 'alerts@virtualmin-enterprise.com'
  smtp_auth_password: 'password'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
- name: 'web.hook'
  webhook_configs:
  - url: 'http://localhost:5001/'

inhibit_rules:
- source_match:
    severity: 'critical'
  target_match:
    severity: 'warning'
  equal: ['alertname', 'dev', 'instance']
EOF

    success "Configuración de AlertManager creada"
}

# Función para crear configuración de ELK Stack
create_elk_config() {
    log "Creando configuración de ELK Stack..."
    
    # Configuración de Logstash
    mkdir -p "$CONFIG_DIR/logstash"
    
    cat > "$CONFIG_DIR/logstash/logstash.yml" << EOF
http.host: "0.0.0.0"
xpack.monitoring.elasticsearch.hosts: [ "http://elasticsearch:9200" ]
path.config: /usr/share/logstash/pipeline
EOF

    cat > "$CONFIG_DIR/logstash/logstash.conf" << EOF
input {
  beats {
    port => 5044
  }
}

filter {
  if [fields][service] == "virtualmin" {
    grok {
      match => { "message" => "%{COMBINEDAPACHELOG}" }
    }
    
    date {
      match => [ "timestamp", "dd/MMM/yyyy:HH:mm:ss Z" ]
    }
    
    mutate {
      convert => { "response" => "integer" }
      convert => { "bytes" => "integer" }
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "virtualmin-logs-%{+YYYY.MM.dd}"
  }
}
EOF

    # Configuración de Filebeat
    mkdir -p "$CONFIG_DIR/filebeat"
    
    cat > "$CONFIG_DIR/filebeat/filebeat.yml" << EOF
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/virtualmin/*.log
    - /var/log/apache2/*.log
    - /var/log/nginx/*.log
  fields:
    service: virtualmin
  fields_under_root: true

output.logstash:
  hosts: ["logstash:5044"]

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
  permissions: 0644
EOF

    # Configuración de Blackbox Exporter
    mkdir -p "$CONFIG_DIR/blackbox"
    
    cat > "$CONFIG_DIR/blackbox/blackbox.yml" << EOF
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_http_versions:
        - "HTTP/1.1"
        - "HTTP/2.0"
      valid_status_codes: [200]
  tcp_connect:
    prober: tcp
    timeout: 5s
EOF

    success "Configuración de ELK Stack creada"
}

# Función para iniciar servicios de monitoreo
start_monitoring_services() {
    log "Iniciando servicios de monitoreo..."
    
    cd "$MONITORING_DIR"
    
    # Iniciar servicios con docker-compose
    docker-compose up -d | tee -a "$LOG_FILE"
    
    # Esperar a que los servicios estén disponibles
    log "Esperando a que los servicios estén disponibles..."
    sleep 30
    
    # Verificar estado de los servicios
    log "Verificando estado de los servicios..."
    docker-compose ps | tee -a "$LOG_FILE"
    
    success "Servicios de monitoreo iniciados"
}

# Función para configurar scraping de Virtualmin
configure_virtualmin_scraping() {
    log "Configurando scraping de métricas de Virtualmin..."
    
    # Verificar si Virtualmin está en ejecución
    if ! curl -f http://localhost:10000/ &> /dev/null; then
        warning "Virtualmin no está disponible en http://localhost:10000/"
        return 1
    fi
    
    # Instalar exporter de Virtualmin si existe
    if [ -f "$PROJECT_ROOT/webmin/virtualmin_exporter.pl" ]; then
        log "Instalando exporter de Virtualmin..."
        cp "$PROJECT_ROOT/webmin/virtualmin_exporter.pl" /usr/libexec/webmin/
        chmod +x /usr/libexec/webmin/virtualmin_exporter.pl
        
        # Configurar Virtualmin para habilitar el exporter
        cat > /etc/webmin/virtualmin-exporter/config << EOF
enabled=1
port=10001
path=/metrics
EOF
        
        # Reiniciar Webmin para aplicar cambios
        systemctl restart webmin | tee -a "$LOG_FILE"
        
        success "Exporter de Virtualmin configurado"
    else
        warning "Exporter de Virtualmin no encontrado. Configurando scraping básico..."
        
        # Añadir scraping básico a Prometheus
        cat >> "$CONFIG_DIR/prometheus/prometheus.yml" << EOF

  - job_name: 'virtualmin-basic'
    static_configs:
      - targets: ['localhost:10000']
    metrics_path: '/unauthenticated'
    scrape_interval: 60s
    params:
      file: 'status.cgi'
EOF
        
        success "Scraping básico de Virtualmin configurado"
    fi
}

# Función para importar dashboards de Grafana
import_grafana_dashboards() {
    log "Importando dashboards de Grafana..."
    
    # Esperar a que Grafana esté disponible
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f http://localhost:3000/api/health &> /dev/null; then
            log "Grafana está disponible"
            break
        fi
        
        log "Esperando a que Grafana esté disponible (intento $attempt/$max_attempts)..."
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        error "Grafana no está disponible después de $max_attempts intentos"
        return 1
    fi
    
    # Importar dashboard de Virtualmin
    local dashboard_file="$CONFIG_DIR/grafana/dashboards/virtualmin.json"
    
    if [ -f "$dashboard_file" ]; then
        # Autenticarse en Grafana
        local grafana_auth=$(echo -n "admin:admin123" | base64)
        
        # Importar dashboard
        curl -X POST \
            -H "Authorization: Basic $grafana_auth" \
            -H "Content-Type: application/json" \
            -d @"$dashboard_file" \
            http://localhost:3000/api/dashboards/db | tee -a "$LOG_FILE"
        
        success "Dashboard de Virtualmin importado"
    else
        warning "Dashboard de Virtualmin no encontrado"
    fi
}

# Función para crear script de mantenimiento
create_maintenance_script() {
    log "Creando script de mantenimiento..."
    
    cat > "$PROJECT_ROOT/scripts/maintain_monitoring_system.sh" << 'EOF'
#!/bin/bash

# Script de mantenimiento para el sistema de monitoreo

set -e

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗ $1${NC}"
}

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MONITORING_DIR="$PROJECT_ROOT/monitoring"
LOG_DIR="$PROJECT_ROOT/logs"

# Archivo de log
LOG_FILE="$LOG_DIR/maintain_monitoring_system_$(date +%Y%m%d_%H%M%S).log"

# Función para verificar estado de los servicios
check_services() {
    log "Verificando estado de los servicios..."
    
    cd "$MONITORING_DIR"
    
    # Verificar estado de los contenedores
    local services=("prometheus" "grafana" "alertmanager" "elasticsearch" "kibana" "logstash")
    
    for service in "${services[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "$service"; then
            log "✓ $service está en ejecución"
        else
            warning "$service no está en ejecución. Reiniciando..."
            docker-compose up -d "$service"
        fi
    done
    
    success "Verificación de servicios completada"
}

# Función para limpiar logs antiguos
cleanup_logs() {
    log "Limpiando logs antiguos..."
    
    # Mantener solo los últimos 7 días de logs
    find "$LOG_DIR" -name "*.log" -type f -mtime +7 -delete
    
    # Limpiar logs de Elasticsearch
    local elasticsearch_url="http://localhost:9200"
    local retention_days=7
    
    # Obtener índices antiguos
    local old_indices=$(curl -s "$elasticsearch_url/_cat/indices?v" | grep "virtualmin-logs-" | awk '{print $3}' | sort -r | tail -n +$retention_days)
    
    for index in $old_indices; do
        log "Eliminando índice: $index"
        curl -X DELETE "$elasticsearch_url/$index"
    done
    
    success "Limpieza de logs completada"
}

# Función para actualizar configuración
update_config() {
    log "Actualizando configuración..."
    
    # Recargar configuración de Prometheus
    docker exec prometheus kill -HUP 1
    
    # Recargar configuración de AlertManager
    docker exec alertmanager kill -HUP 1
    
    success "Configuración actualizada"
}

# Función principal
main() {
    log "Iniciando mantenimiento del sistema de monitoreo..."
    
    check_services
    cleanup_logs
    update_config
    
    success "Mantenimiento del sistema de monitoreo completado"
}

# Ejecutar función principal
main "$@"
EOF

    chmod +x "$PROJECT_ROOT/scripts/maintain_monitoring_system.sh"
    
    # Crear tarea programada para mantenimiento diario
    cat > /etc/cron.d/virtualmin-monitoring-maintenance << EOF
# Mantenimiento diario del sistema de monitoreo
0 2 * * * root $PROJECT_ROOT/scripts/maintain_monitoring_system.sh
EOF
    
    success "Script de mantenimiento creado"
}

# Función para mostrar resumen final
show_summary() {
    header "Resumen de Configuración"
    
    echo -e "${CYAN}Servicios configurados:${NC}" | tee -a "$LOG_FILE"
    echo -e "  - Prometheus (Puerto: 9090)" | tee -a "$LOG_FILE"
    echo -e "  - Grafana (Puerto: 3000)" | tee -a "$LOG_FILE"
    echo -e "  - AlertManager (Puerto: 9093)" | tee -a "$LOG_FILE"
    echo -e "  - Elasticsearch (Puerto: 9200)" | tee -a "$LOG_FILE"
    echo -e "  - Kibana (Puerto: 5601)" | tee -a "$LOG_FILE"
    echo -e "  - Logstash (Puerto: 5044)" | tee -a "$LOG_FILE"
    echo -e "  - Filebeat" | tee -a "$LOG_FILE"
    echo -e "  - Node Exporter (Puerto: 9100)" | tee -a "$LOG_FILE"
    echo -e "  - cAdvisor (Puerto: 8080)" | tee -a "$LOG_FILE"
    echo -e "  - Blackbox Exporter (Puerto: 9115)" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo -e "${CYAN}URLs de acceso:${NC}" | tee -a "$LOG_FILE"
    echo -e "  - Prometheus: http://localhost:9090" | tee -a "$LOG_FILE"
    echo -e "  - Grafana: http://localhost:3000 (admin/admin123)" | tee -a "$LOG_FILE"
    echo -e "  - Kibana: http://localhost:5601" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo -e "${CYAN}Configuración:${NC}" | tee -a "$LOG_FILE"
    echo -e "  - Docker Compose: $MONITORING_DIR/docker-compose.yml" | tee -a "$LOG_FILE"
    echo -e "  - Configuración de Prometheus: $CONFIG_DIR/prometheus/prometheus.yml" | tee -a "$LOG_FILE"
    echo -e "  - Configuración de Grafana: $CONFIG_DIR/grafana/" | tee -a "$LOG_FILE"
    echo -e "  - Configuración de AlertManager: $CONFIG_DIR/alertmanager/alertmanager.yml" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo -e "${CYAN}Logs:${NC} $LOG_FILE" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    success "¡Sistema de monitoreo configurado exitosamente!"
}

# Función principal
main() {
    # Mostrar banner
    show_banner
    
    # Verificar si se ejecuta como root
    if [ "$EUID" -ne 0 ]; then
        error "Este script debe ejecutarse como root"
        exit 1
    fi
    
    # Ejecutar funciones principales
    check_dependencies
    load_configuration
    create_docker_compose
    create_prometheus_config
    create_grafana_config
    create_alertmanager_config
    create_elk_config
    start_monitoring_services
    configure_virtualmin_scraping
    import_grafana_dashboards
    create_maintenance_script
    show_summary
}

# Manejo de interrupción
trap 'error "Script interrumpido por el usuario"; exit 1' INT TERM

# Ejecutar función principal
main "$@"
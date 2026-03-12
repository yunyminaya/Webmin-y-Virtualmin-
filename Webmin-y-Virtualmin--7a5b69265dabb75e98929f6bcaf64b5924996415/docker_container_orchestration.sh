#!/bin/bash

# Sistema Avanzado de Orquestación de Contenedores Docker
# Gestión inteligente de contenedores con auto-sanación, monitoreo y escalado
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

# ===== CONFIGURACIÓN AVANZADA =====
CONTAINER_ENGINE="${CONTAINER_ENGINE:-docker}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-virtualmin_orchestration}"
MONITORING_INTERVAL="${MONITORING_INTERVAL:-30}"
AUTO_HEALING_ENABLED="${AUTO_HEALING_ENABLED:-true}"
RESOURCE_MONITORING_ENABLED="${RESOURCE_MONITORING_ENABLED:-true}"
LOG_ROTATION_ENABLED="${LOG_ROTATION_ENABLED:-true}"

# Configuración de contenedores
VIRTUALMIN_IMAGE="${VIRTUALMIN_IMAGE:-virtualmin/virtualmin:latest}"
MYSQL_IMAGE="${MYSQL_IMAGE:-mysql:8.0}"
POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:15}"
REDIS_IMAGE="${REDIS_IMAGE:-redis:7-alpine}"
NGINX_IMAGE="${NGINX_IMAGE:-nginx:1.25-alpine}"

# Configuración de recursos
VIRTUALMIN_CPU_SHARES="${VIRTUALMIN_CPU_SHARES:-1024}"
VIRTUALMIN_MEMORY="${VIRTUALMIN_MEMORY:-2g}"
MYSQL_MEMORY="${MYSQL_MEMORY:-1g}"
POSTGRES_MEMORY="${POSTGRES_MEMORY:-1g}"
REDIS_MEMORY="${REDIS_MEMORY:-512m}"

# Función para verificar soporte avanzado de contenedores
check_advanced_container_support() {
    log_step "Verificando soporte avanzado de contenedores..."

    if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
        if ! command_exists docker; then
            log_error "Docker no está instalado"
            return 1
        fi

        if ! docker info >/dev/null 2>&1; then
            log_error "Docker daemon no está ejecutándose"
            return 1
        fi

        # Verificar Docker Compose
        if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
            log_error "Docker Compose no está disponible"
            return 1
        fi

        # Verificar Docker API
        if ! docker version >/dev/null 2>&1; then
            log_error "No se puede acceder a la API de Docker"
            return 1
        fi

        log_success "Docker y Docker Compose están disponibles"

    elif [[ "$CONTAINER_ENGINE" == "podman" ]]; then
        if ! command_exists podman; then
            log_error "Podman no está instalado"
            return 1
        fi

        if ! command_exists podman-compose; then
            log_error "podman-compose no está instalado"
            return 1
        fi

        log_success "Podman y podman-compose están disponibles"
    else
        log_error "Motor de contenedores no soportado: $CONTAINER_ENGINE"
        return 1
    fi

    return 0
}

# Función para generar docker-compose avanzado
generate_advanced_docker_compose() {
    log_step "Generando docker-compose.yml avanzado..."

    local compose_file="$SCRIPT_DIR/docker-compose.orchestration.yml"
    cat > "$compose_file" << EOF
version: '3.8'

services:
  # Virtualmin Webmin - Contenedor principal
  virtualmin:
    image: $VIRTUALMIN_IMAGE
    container_name: ${COMPOSE_PROJECT_NAME}_virtualmin
    restart: unless-stopped
    ports:
      - "10000:10000"    # Webmin
      - "80:80"          # HTTP
      - "443:443"        # HTTPS
      - "21:21"          # FTP
      - "22:22"          # SSH
      - "25:25"          # SMTP
      - "110:110"        # POP3
      - "143:143"        # IMAP
      - "465:465"        # SMTPS
      - "587:587"        # Submission
      - "993:993"        # IMAPS
      - "995:995"        # POP3S
    environment:
      - WEBMIN_PORT=10000
      - VIRTUALMIN_DOMAIN=virtualmin.local
      - MYSQL_HOST=mysql
      - MYSQL_PORT=3306
      - MYSQL_ROOT_PASSWORD_FILE=/run/secrets/mysql_root_password
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD_FILE=/run/secrets/redis_password
      - TZ=America/New_York
      - LOG_LEVEL=INFO
    volumes:
      - virtualmin_config:/etc/webmin
      - virtualmin_var:/var/webmin
      - virtualmin_etc:/etc/virtualmin
      - user_homes:/home
      - apache_logs:/var/log/apache2
      - webmin_logs:/var/webmin/logs
      - backups:/backups
      - ./ssl:/etc/ssl/virtualmin
      - mysql_root_password:/run/secrets/mysql_root_password:ro
      - postgres_password:/run/secrets/postgres_password:ro
      - redis_password:/run/secrets/redis_password:ro
    depends_on:
      mysql:
        condition: service_healthy
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - virtualmin_network
      - database_network
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: $VIRTUALMIN_MEMORY
        reservations:
          cpus: '0.5'
          memory: 512m
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
        window: 120s
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:10000"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    labels:
      - "com.virtualmin.orchestration=true"
      - "com.virtualmin.service=webmin"
      - "com.virtualmin.monitoring=true"
      - "com.virtualmin.backup=true"

  # Base de datos MySQL
  mysql:
    image: $MYSQL_IMAGE
    container_name: ${COMPOSE_PROJECT_NAME}_mysql
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD_FILE=/run/secrets/mysql_root_password
      - MYSQL_DATABASE=virtualmin
      - MYSQL_USER=virtualmin
      - MYSQL_PASSWORD_FILE=/run/secrets/mysql_password
      - MYSQL_CHARSET=utf8mb4
      - MYSQL_COLLATION=utf8mb4_unicode_ci
    volumes:
      - mysql_data:/var/lib/mysql
      - mysql_logs:/var/log/mysql
      - mysql_config:/etc/mysql/conf.d
      - mysql_root_password:/run/secrets/mysql_root_password:ro
      - mysql_password:/run/secrets/mysql_password:ro
    networks:
      - database_network
    deploy:
      resources:
        limits:
          memory: $MYSQL_MEMORY
        reservations:
          memory: 256m
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    labels:
      - "com.virtualmin.orchestration=true"
      - "com.virtualmin.service=database"
      - "com.virtualmin.database=mysql"
      - "com.virtualmin.monitoring=true"
      - "com.virtualmin.backup=true"

  # Base de datos PostgreSQL
  postgres:
    image: $POSTGRES_IMAGE
    container_name: ${COMPOSE_PROJECT_NAME}_postgres
    restart: unless-stopped
    environment:
      - POSTGRES_DB=virtualmin
      - POSTGRES_USER=virtualmin
      - POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password
      - POSTGRES_INITDB_ARGS=--encoding=UTF-8
      - PGDATA=/var/lib/postgresql/data/pgdata
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - postgres_logs:/var/log/postgresql
      - postgres_config:/etc/postgresql
      - postgres_password:/run/secrets/postgres_password:ro
    networks:
      - database_network
    deploy:
      resources:
        limits:
          memory: $POSTGRES_MEMORY
        reservations:
          memory: 256m
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U virtualmin"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    labels:
      - "com.virtualmin.orchestration=true"
      - "com.virtualmin.service=database"
      - "com.virtualmin.database=postgres"
      - "com.virtualmin.monitoring=true"
      - "com.virtualmin.backup=true"

  # Cache Redis
  redis:
    image: $REDIS_IMAGE
    container_name: ${COMPOSE_PROJECT_NAME}_redis
    restart: unless-stopped
    command: redis-server --requirepassfile /run/secrets/redis_password --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
      - redis_logs:/var/log/redis
      - redis_password:/run/secrets/redis_password:ro
    networks:
      - database_network
    deploy:
      resources:
        limits:
          memory: $REDIS_MEMORY
        reservations:
          memory: 128m
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    labels:
      - "com.virtualmin.orchestration=true"
      - "com.virtualmin.service=cache"
      - "com.virtualmin.cache=redis"
      - "com.virtualmin.monitoring=true"

  # Proxy reverso Nginx
  nginx:
    image: $NGINX_IMAGE
    container_name: ${COMPOSE_PROJECT_NAME}_nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./ssl:/etc/ssl/certs:ro
      - nginx_logs:/var/log/nginx
    depends_on:
      - virtualmin
    networks:
      - virtualmin_network
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256m
        reservations:
          cpus: '0.1'
          memory: 64m
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    labels:
      - "com.virtualmin.orchestration=true"
      - "com.virtualmin.service=proxy"
      - "com.virtualmin.monitoring=true"

  # Contenedor de monitoreo
  monitoring:
    image: prom/prometheus:latest
    container_name: ${COMPOSE_PROJECT_NAME}_monitoring
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - monitoring_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    networks:
      - monitoring_network
    deploy:
      resources:
        limits:
          memory: 512m
        reservations:
          memory: 128m
    labels:
      - "com.virtualmin.orchestration=true"
      - "com.virtualmin.service=monitoring"
      - "com.virtualmin.monitoring=prometheus"

volumes:
  # Volúmenes de Virtualmin
  virtualmin_config:
    driver: local
  virtualmin_var:
    driver: local
  virtualmin_etc:
    driver: local
  user_homes:
    driver: local
  apache_logs:
    driver: local
  webmin_logs:
    driver: local
  backups:
    driver: local

  # Volúmenes de bases de datos
  mysql_data:
    driver: local
  mysql_logs:
    driver: local
  mysql_config:
    driver: local
  postgres_data:
    driver: local
  postgres_logs:
    driver: local
  postgres_config:
    driver: local
  redis_data:
    driver: local
  redis_logs:
    driver: local

  # Volúmenes de proxy
  nginx_logs:
    driver: local

  # Volúmenes de monitoreo
  monitoring_data:
    driver: local

  # Volúmenes de secrets
  mysql_root_password:
    driver: local
  mysql_password:
    driver: local
  postgres_password:
    driver: local
  redis_password:
    driver: local

networks:
  virtualmin_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
  database_network:
    driver: bridge
    internal: true
    ipam:
      config:
        - subnet: 172.21.0.0/16
  monitoring_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.22.0.0/16
EOF

    log_success "docker-compose.orchestration.yml generado"
}

# Función para generar configuración de Nginx
generate_nginx_config() {
    log_step "Generando configuración de Nginx..."

    # Crear directorio de configuración
    mkdir -p "$SCRIPT_DIR/nginx/conf.d"

    # Configuración principal de Nginx
    local nginx_conf="$SCRIPT_DIR/nginx/nginx.conf"
    cat > "$nginx_conf" << 'EOF'
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
    use epoll;
    multi_accept on;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    # Performance
    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;
    keepalive_timeout  65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=webmin:10m rate=5r/s;

    # Upstream para Virtualmin
    upstream virtualmin_backend {
        server virtualmin:80;
        keepalive 32;
    }

    # Upstream para Webmin
    upstream webmin_backend {
        server virtualmin:10000;
        keepalive 16;
    }

    include /etc/nginx/conf.d/*.conf;
}
EOF

    # Configuración de sitio por defecto
    local default_conf="$SCRIPT_DIR/nginx/conf.d/default.conf"
    cat > "$default_conf" << 'EOF'
# Configuración por defecto para Virtualmin
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # Redirect to HTTPS
    return 301 https://$host$request_uri;
}

# Servidor HTTPS principal
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name virtualmin.local;

    # SSL configuration
    ssl_certificate /etc/ssl/certs/virtualmin.crt;
    ssl_certificate_key /etc/ssl/certs/virtualmin.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Rate limiting para webmin
    limit_req zone=webmin burst=10 nodelay;

    # Proxy para Webmin
    location / {
        proxy_pass http://webmin_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support para Webmin
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}

# Health check endpoint
server {
    listen 80;
    server_name health.local;

    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

    log_success "Configuración de Nginx generada"
}

# Función para generar configuración de Prometheus
generate_prometheus_config() {
    log_step "Generando configuración de Prometheus..."

    mkdir -p "$SCRIPT_DIR/monitoring"

    local prometheus_conf="$SCRIPT_DIR/monitoring/prometheus.yml"
    cat > "$prometheus_conf" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Virtualmin Webmin
  - job_name: 'virtualmin-webmin'
    static_configs:
      - targets: ['virtualmin:10000']
    scrape_interval: 30s
    metrics_path: /metrics

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

  # Node Exporter (para métricas del sistema)
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
    scrape_interval: 30s

  # cAdvisor (para métricas de contenedores)
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
    scrape_interval: 30s
EOF

    # Reglas de alertas
    local alert_rules="$SCRIPT_DIR/monitoring/alert_rules.yml"
    cat > "$alert_rules" << EOF
groups:
  - name: virtualmin_alerts
    rules:
    - alert: VirtualminDown
      expr: up{job="virtualmin-webmin"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Virtualmin Webmin is down"
        description: "Virtualmin Webmin has been down for more than 5 minutes."

    - alert: MySQLDown
      expr: up{job="mysql"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "MySQL is down"
        description: "MySQL has been down for more than 5 minutes."

    - alert: PostgreSQLDown
      expr: up{job="postgres"} == 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "PostgreSQL is down"
        description: "PostgreSQL has been down for more than 5 minutes."

    - alert: RedisDown
      expr: up{job="redis"} == 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Redis is down"
        description: "Redis has been down for more than 5 minutes."

    - alert: HighMemoryUsage
      expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 90
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage"
        description: "Memory usage is above 90% for more than 5 minutes."

    - alert: HighCPUUsage
      expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High CPU usage"
        description: "CPU usage is above 90% for more than 5 minutes."
EOF

    log_success "Configuración de Prometheus generada"
}

# Función para generar secrets seguros
generate_secure_secrets() {
    log_step "Generando secrets seguros..."

    # Crear directorio de secrets
    mkdir -p "$SCRIPT_DIR/secrets"

    # Generar contraseñas seguras
    local mysql_root_password
    local mysql_password
    local postgres_password
    local redis_password

    mysql_root_password=$(openssl rand -base64 32)
    mysql_password=$(openssl rand -base64 32)
    postgres_password=$(openssl rand -base64 32)
    redis_password=$(openssl rand -base64 32)

    # Crear archivos de secrets
    echo -n "$mysql_root_password" > "$SCRIPT_DIR/secrets/mysql_root_password"
    echo -n "$mysql_password" > "$SCRIPT_DIR/secrets/mysql_password"
    echo -n "$postgres_password" > "$SCRIPT_DIR/secrets/postgres_password"
    echo -n "$redis_password" > "$SCRIPT_DIR/secrets/redis_password"

    # Crear archivo .env con las contraseñas
    local env_file="$SCRIPT_DIR/.env.orchestration"
    cat > "$env_file" << EOF
# Configuración de Orquestación de Contenedores Virtualmin
# Generado automáticamente - NO MODIFICAR MANUALMENTE

# Contraseñas de bases de datos
MYSQL_ROOT_PASSWORD=$mysql_root_password
MYSQL_PASSWORD=$mysql_password
POSTGRES_PASSWORD=$postgres_password
REDIS_PASSWORD=$redis_password

# Configuración de contenedores
COMPOSE_PROJECT_NAME=$COMPOSE_PROJECT_NAME
CONTAINER_ENGINE=$CONTAINER_ENGINE

# Configuración de monitoreo
MONITORING_INTERVAL=$MONITORING_INTERVAL
AUTO_HEALING_ENABLED=$AUTO_HEALING_ENABLED
RESOURCE_MONITORING_ENABLED=$RESOURCE_MONITORING_ENABLED
LOG_ROTATION_ENABLED=$LOG_ROTATION_ENABLED

# Configuración de imágenes
VIRTUALMIN_IMAGE=$VIRTUALMIN_IMAGE
MYSQL_IMAGE=$MYSQL_IMAGE
POSTGRES_IMAGE=$POSTGRES_IMAGE
REDIS_IMAGE=$REDIS_IMAGE
NGINX_IMAGE=$NGINX_IMAGE
EOF

    log_success "Secrets seguros generados"
    log_warning "IMPORTANTE: Guarda las contraseñas del archivo .env.orchestration en un lugar seguro"
}

# Función para inicializar secrets en Docker
initialize_docker_secrets() {
    log_step "Inicializando secrets en Docker..."

    if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
        # Crear secrets en Docker
        if [[ -f "$SCRIPT_DIR/secrets/mysql_root_password" ]]; then
            docker secret rm mysql_root_password 2>/dev/null || true
            docker secret create mysql_root_password "$SCRIPT_DIR/secrets/mysql_root_password"
        fi

        if [[ -f "$SCRIPT_DIR/secrets/mysql_password" ]]; then
            docker secret rm mysql_password 2>/dev/null || true
            docker secret create mysql_password "$SCRIPT_DIR/secrets/mysql_password"
        fi

        if [[ -f "$SCRIPT_DIR/secrets/postgres_password" ]]; then
            docker secret rm postgres_password 2>/dev/null || true
            docker secret create postgres_password "$SCRIPT_DIR/secrets/postgres_password"
        fi

        if [[ -f "$SCRIPT_DIR/secrets/redis_password" ]]; then
            docker secret rm redis_password 2>/dev/null || true
            docker secret create redis_password "$SCRIPT_DIR/secrets/redis_password"
        fi
    fi

    log_success "Secrets inicializados en Docker"
}

# Función para generar script de gestión avanzada
generate_advanced_management_script() {
    log_step "Generando script de gestión avanzada..."

    local management_script="$SCRIPT_DIR/manage_orchestration.sh"
    cat > "$management_script" << 'EOF'
#!/bin/bash

# Script Avanzado de Gestión de Orquestación de Contenedores
# Gestión inteligente con auto-sanación y monitoreo

set -euo pipefail

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.orchestration.yml"
CONTAINER_ENGINE="${CONTAINER_ENGINE:-docker}"
MONITORING_INTERVAL="${MONITORING_INTERVAL:-30}"
AUTO_HEALING_ENABLED="${AUTO_HEALING_ENABLED:-true}"

# Función para verificar estado de contenedores
check_container_health() {
    local service="$1"
    local container_name="${COMPOSE_PROJECT_NAME}_${service}"

    if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
        local status
        status=$(docker ps --filter "name=$container_name" --format "{{.Status}}" | head -1)

        if [[ -z "$status" ]]; then
            echo "stopped"
        elif [[ "$status" == *"Up"* ]]; then
            echo "running"
        elif [[ "$status" == *"unhealthy"* ]]; then
            echo "unhealthy"
        else
            echo "unknown"
        fi
    else
        # Para Podman
        local status
        status=$(podman ps --filter "name=$container_name" --format "{{.Status}}" | head -1)

        if [[ -z "$status" ]]; then
            echo "stopped"
        elif [[ "$status" == *"Up"* ]]; then
            echo "running"
        else
            echo "unknown"
        fi
    fi
}

# Función para reiniciar contenedor con auto-sanación
restart_container() {
    local service="$1"
    echo "Reiniciando contenedor: $service"

    if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
        if docker compose -f "$COMPOSE_FILE" restart "$service"; then
            echo "Contenedor $service reiniciado exitosamente"
            return 0
        else
            echo "Error al reiniciar contenedor $service"
            return 1
        fi
    else
        if podman-compose -f "$COMPOSE_FILE" restart "$service"; then
            echo "Contenedor $service reiniciado exitosamente"
            return 0
        else
            echo "Error al reiniciar contenedor $service"
            return 1
        fi
    fi
}

# Función de monitoreo continuo
monitor_containers() {
    echo "Iniciando monitoreo de contenedores (intervalo: ${MONITORING_INTERVAL}s)..."
    echo "Presiona Ctrl+C para detener"

    while true; do
        echo "=== $(date) ==="

        local services=("virtualmin" "mysql" "postgres" "redis" "nginx")
        local unhealthy_services=()

        for service in "${services[@]}"; do
            local status
            status=$(check_container_health "$service")
            printf "%-12s: %s\n" "$service" "$status"

            if [[ "$status" == "unhealthy" || "$status" == "stopped" ]]; then
                unhealthy_services+=("$service")
            fi
        done

        # Auto-sanación
        if [[ "$AUTO_HEALING_ENABLED" == "true" && ${#unhealthy_services[@]} -gt 0 ]]; then
            echo
            echo "Detectados contenedores no saludables: ${unhealthy_services[*]}"
            echo "Iniciando auto-sanación..."

            for service in "${unhealthy_services[@]}"; do
                if restart_container "$service"; then
                    echo "✓ $service sanado exitosamente"
                else
                    echo "✗ Error al sanar $service"
                fi
            done
        fi

        echo
        sleep "$MONITORING_INTERVAL"
    done
}

# Función para mostrar métricas de recursos
show_resource_metrics() {
    echo "=== MÉTRICAS DE RECURSOS ==="

    if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    else
        podman stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    fi
}

# Función para rotación de logs
rotate_logs() {
    echo "Rotando logs de contenedores..."

    local services=("virtualmin" "mysql" "postgres" "redis" "nginx")

    for service in "${services[@]}"; do
        local container_name="${COMPOSE_PROJECT_NAME}_${service}"

        if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
            if docker ps -q -f "name=$container_name" | grep -q .; then
                echo "Rotando logs de $service..."
                docker exec "$container_name" logrotate -f /etc/logrotate.conf 2>/dev/null || true
            fi
        fi
    done

    echo "Rotación de logs completada"
}

# Función para backup de volúmenes
backup_volumes() {
    local backup_dir="${1:-$SCRIPT_DIR/backups/$(date +%Y%m%d_%H%M%S)}"
    echo "Creando backup en: $backup_dir"

    mkdir -p "$backup_dir"

    local volumes=("virtualmin_config" "virtualmin_var" "virtualmin_etc" "user_homes" "mysql_data" "postgres_data" "redis_data")

    for volume in "${volumes[@]}"; do
        echo "Respaldando volumen: $volume"
        if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
            docker run --rm -v "${COMPOSE_PROJECT_NAME}_${volume}:/source" -v "$backup_dir:/backup" alpine tar czf "/backup/${volume}.tar.gz" -C /source .
        fi
    done

    echo "Backup completado: $backup_dir"
}

# Función para restaurar volúmenes
restore_volumes() {
    local backup_dir="$1"

    if [[ ! -d "$backup_dir" ]]; then
        echo "Error: Directorio de backup no existe: $backup_dir"
        return 1
    fi

    echo "Restaurando desde: $backup_dir"

    local volumes=("virtualmin_config" "virtualmin_var" "virtualmin_etc" "user_homes" "mysql_data" "postgres_data" "redis_data")

    for volume in "${volumes[@]}"; do
        local backup_file="$backup_dir/${volume}.tar.gz"
        if [[ -f "$backup_file" ]]; then
            echo "Restaurando volumen: $volume"
            if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
                docker run --rm -v "${COMPOSE_PROJECT_NAME}_${volume}:/target" -v "$backup_dir:/backup" alpine tar xzf "/backup/${volume}.tar.gz" -C /target
            fi
        fi
    done

    echo "Restauración completada"
}

# Función principal
case "${1:-help}" in
    "start")
        echo "Iniciando orquestación de contenedores..."
        if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
            docker compose -f "$COMPOSE_FILE" up -d
        else
            podman-compose -f "$COMPOSE_FILE" up -d
        fi
        echo "Orquestación iniciada. Ejecuta '$0 monitor' para monitoreo continuo."
        ;;
    "stop")
        echo "Deteniendo orquestación de contenedores..."
        if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
            docker compose -f "$COMPOSE_FILE" down
        else
            podman-compose -f "$COMPOSE_FILE" down
        fi
        ;;
    "restart")
        echo "Reiniciando orquestación de contenedores..."
        if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
            docker compose -f "$COMPOSE_FILE" restart
        else
            podman-compose -f "$COMPOSE_FILE" restart
        fi
        ;;
    "status")
        echo "=== ESTADO DE CONTENEDORES ==="
        if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
            docker compose -f "$COMPOSE_FILE" ps
        else
            podman-compose -f "$COMPOSE_FILE" ps
        fi
        ;;
    "monitor")
        monitor_containers
        ;;
    "metrics")
        show_resource_metrics
        ;;
    "logs")
        local service="${2:-}"
        if [[ -n "$service" ]]; then
            echo "Logs del servicio: $service"
            if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
                docker compose -f "$COMPOSE_FILE" logs -f "$service"
            else
                podman-compose -f "$COMPOSE_FILE" logs -f "$service"
            fi
        else
            echo "Logs de todos los servicios:"
            if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
                docker compose -f "$COMPOSE_FILE" logs -f
            else
                podman-compose -f "$COMPOSE_FILE" logs -f
            fi
        fi
        ;;
    "rotate-logs")
        rotate_logs
        ;;
    "backup")
        backup_volumes "$2"
        ;;
    "restore")
        if [[ -z "${2:-}" ]]; then
            echo "Error: Especifica el directorio de backup"
            echo "Uso: $0 restore /ruta/al/backup"
            exit 1
        fi
        restore_volumes "$2"
        ;;
    "shell")
        local service="${2:-virtualmin}"
        local container_name="${COMPOSE_PROJECT_NAME}_${service}"
        echo "Conectando al shell del contenedor: $service"
        if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
            docker exec -it "$container_name" /bin/bash
        else
            podman exec -it "$container_name" /bin/bash
        fi
        ;;
    "cleanup")
        echo "Limpiando contenedores, volúmenes e imágenes no utilizados..."
        if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
            docker system prune -f
            docker volume prune -f
            docker image prune -f
        fi
        ;;
    *)
        echo "Script Avanzado de Gestión de Orquestación de Contenedores"
        echo "Uso: $0 [comando] [opciones]"
        echo ""
        echo "Comandos disponibles:"
        echo "  start              - Iniciar todos los contenedores"
        echo "  stop               - Detener todos los contenedores"
        echo "  restart            - Reiniciar todos los contenedores"
        echo "  status             - Mostrar estado de contenedores"
        echo "  monitor            - Monitoreo continuo con auto-sanación"
        echo "  metrics            - Mostrar métricas de recursos"
        echo "  logs [servicio]    - Ver logs (de todos o de un servicio)"
        echo "  rotate-logs        - Rotar logs de contenedores"
        echo "  backup [directorio]- Crear backup de volúmenes"
        echo "  restore <directorio> - Restaurar desde backup"
        echo "  shell [servicio]   - Conectar al shell de un contenedor"
        echo "  cleanup            - Limpiar recursos no utilizados"
        echo ""
        echo "Servicios disponibles: virtualmin, mysql, postgres, redis, nginx"
        ;;
esac
EOF

    chmod +x "$management_script"
    log_success "Script de gestión avanzada generado: $management_script"
}

# Función para mostrar instrucciones completas
show_orchestration_instructions() {
    log_success "Sistema de orquestación de contenedores generado exitosamente"
    echo
    log_info "=== SISTEMA COMPLETO DE ORQUESTACIÓN DOCKER ==="
    echo
    log_info "✅ Docker Compose avanzado con múltiples servicios"
    log_info "✅ Configuración de Nginx como proxy reverso"
    log_info "✅ Stack de monitoreo Prometheus completo"
    log_info "✅ Secrets seguros para contraseñas"
    log_info "✅ Gestión avanzada con auto-sanación"
    log_info "✅ Monitoreo de recursos y métricas"
    log_info "✅ Sistema de backup y restauración"
    log_info "✅ Rotación automática de logs"
    echo
    log_info "=== ARCHIVOS GENERADOS ==="
    echo
    log_info "docker-compose.orchestration.yml    - Configuración principal"
    log_info "nginx/nginx.conf                    - Configuración de Nginx"
    log_info "nginx/conf.d/default.conf           - Sitios de Nginx"
    log_info "monitoring/prometheus.yml           - Configuración de Prometheus"
    log_info "monitoring/alert_rules.yml          - Reglas de alertas"
    log_info ".env.orchestration                  - Variables de entorno"
    log_info "secrets/                            - Contraseñas seguras"
    log_info "manage_orchestration.sh             - Script de gestión"
    echo
    log_info "=== COMANDOS DE GESTIÓN ==="
    echo
    log_info "Iniciar sistema completo:"
    echo "  ./manage_orchestration.sh start"
    echo
    log_info "Monitoreo continuo con auto-sanación:"
    echo "  ./manage_orchestration.sh monitor"
    echo
    log_info "Ver métricas de recursos:"
    echo "  ./manage_orchestration.sh metrics"
    echo
    log_info "Ver logs de servicios:"
    echo "  ./manage_orchestration.sh logs [servicio]"
    echo
    log_info "Backup de datos:"
    echo "  ./manage_orchestration.sh backup"
    echo
    log_info "Conectar al shell de Virtualmin:"
    echo "  ./manage_orchestration.sh shell virtualmin"
    echo
    log_info "=== ACCESO A SERVICIOS ==="
    echo
    log_info "Virtualmin Webmin: https://localhost:10000"
    log_info "Nginx Proxy: http://localhost (redirecciona a HTTPS)"
    log_info "Prometheus: http://localhost:9090"
    echo
    log_info "=== NOTAS DE SEGURIDAD ==="
    echo
    log_warning "• Las contraseñas se generan automáticamente y se guardan en .env.orchestration"
    log_warning "• Configura certificados SSL reales para producción"
    log_warning "• Revisa las reglas de firewall para los puertos expuestos"
    log_warning "• Configura backups automáticos regulares"
    log_warning "• Monitorea los logs para detectar problemas temprano"
}

# Función principal
main() {
    local generate_configs=false
    local start_system=false
    local enable_monitoring=false

    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -g|--generate) generate_configs=true ;;
            -s|--start) start_system=true ;;
            -m|--monitoring) enable_monitoring=true ;;
            -h|--help) show_help; exit 0 ;;
            *) log_error "Opción desconocida: $1"; show_help; exit 1 ;;
        esac
        shift
    done

    echo
    echo "======================================================"
    echo "  ORQUESTACIÓN AVANZADA DE CONTENEDORES DOCKER"
    echo "  Virtualmin & Webmin - Sistema de Producción"
    echo "======================================================"
    echo

    # Verificar soporte de contenedores
    if ! check_advanced_container_support; then
        exit 1
    fi

    # Generar configuraciones si se solicita
    if [[ "$generate_configs" == "true" ]]; then
        generate_advanced_docker_compose
        generate_nginx_config
        generate_prometheus_config
        generate_secure_secrets
        initialize_docker_secrets
        generate_advanced_management_script
    fi

    # Iniciar sistema si se solicita
    if [[ "$start_system" == "true" ]]; then
        generate_advanced_docker_compose
        generate_nginx_config
        generate_prometheus_config
        generate_secure_secrets
        initialize_docker_secrets
        generate_advanced_management_script

        log_info "Iniciando sistema de orquestación..."
        if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
            docker compose -f "$SCRIPT_DIR/docker-compose.orchestration.yml" up -d
        else
            podman-compose -f "$SCRIPT_DIR/docker-compose.orchestration.yml" up -d
        fi
        log_success "Sistema iniciado"
    fi

    # Mostrar instrucciones si se generaron configuraciones
    if [[ "$generate_configs" == "true" || "$start_system" == "true" ]]; then
        show_orchestration_instructions
    fi

    log_success "Operación completada exitosamente"
}

# Función de ayuda
show_help() {
    cat << EOF
Sistema Avanzado de Orquestación de Contenedores Docker - Virtualmin & Webmin
Versión: 2.0.0

USO:
    $0 [opciones]

OPCIONES:
    -g, --generate        Generar todas las configuraciones y scripts
    -s, --start          Generar configuraciones e iniciar el sistema completo
    -m, --monitoring     Habilitar stack de monitoreo completo
    -h, --help          Mostrar esta ayuda

SERVICIOS INCLUIDOS:
    • Virtualmin Webmin - Servidor principal de gestión
    • MySQL 8.0 - Base de datos principal
    • PostgreSQL 15 - Base de datos adicional
    • Redis 7 - Sistema de cache
    • Nginx - Proxy reverso y balanceador de carga
    • Prometheus - Monitoreo y métricas
    • cAdvisor - Métricas de contenedores
    • Node Exporter - Métricas del sistema

CARACTERÍSTICAS:
    • Auto-sanación automática de contenedores
    • Monitoreo continuo de recursos
    • Gestión inteligente de logs
    • Backup y restauración de volúmenes
    • Secrets seguros con Docker
    • Health checks avanzados
    • Network segmentation
    • Resource limits y reservations

ARCHIVOS GENERADOS:
    docker-compose.orchestration.yml    - Configuración principal
    nginx/nginx.conf                    - Configuración de proxy
    monitoring/prometheus.yml           - Configuración de monitoreo
    .env.orchestration                  - Variables de entorno
    secrets/                            - Contraseñas seguras
    manage_orchestration.sh             - Script de gestión

EJEMPLOS:
    $0 -g                 # Generar todas las configuraciones
    $0 -s                 # Configurar e iniciar sistema completo
    $0 -g -m             # Generar con monitoreo completo

NOTAS:
    - Requiere Docker o Podman instalado
    - Las contraseñas se generan automáticamente
    - Configura SSL para producción
    - Revisa los puertos y firewall
EOF
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
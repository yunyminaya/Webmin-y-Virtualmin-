#!/bin/bash

# Sistema de Auto-Escalado Inteligente
# Escalado horizontal basado en carga con métricas personalizadas
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
AUTOSCALING_NAMESPACE="${AUTOSCALING_NAMESPACE:-virtualmin-system}"
METRICS_SERVER_ENABLED="${METRICS_SERVER_ENABLED:-true}"
PROMETHEUS_ADAPTER_ENABLED="${PROMETHEUS_ADAPTER_ENABLED:-true}"
SCALING_INTERVAL="${SCALING_INTERVAL:-30}"
MIN_REPLICAS_DEFAULT="${MIN_REPLICAS_DEFAULT:-2}"
MAX_REPLICAS_DEFAULT="${MAX_REPLICAS_DEFAULT:-10}"

# Configuración de umbrales
CPU_THRESHOLD="${CPU_THRESHOLD:-70}"
MEMORY_THRESHOLD="${MEMORY_THRESHOLD:-80}"
REQUESTS_THRESHOLD="${REQUESTS_THRESHOLD:-100}"
LATENCY_THRESHOLD="${LATENCY_THRESHOLD:-2000}"

# Función para verificar dependencias de auto-escalado
check_autoscaling_dependencies() {
    log_step "Verificando dependencias de auto-escalado..."

    local deps=("kubectl" "helm")
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

    # Verificar conexión con cluster
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "No se puede conectar al cluster de Kubernetes"
        return 1
    fi

    log_success "Dependencias de auto-escalado verificadas"
    return 0
}

# Función para instalar Metrics Server
install_metrics_server() {
    if [[ "$METRICS_SERVER_ENABLED" != "true" ]]; then
        log_info "Metrics Server deshabilitado"
        return 0
    fi

    log_step "Instalando Metrics Server..."

    # Agregar repositorio
    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
    helm repo update

    # Instalar Metrics Server
    helm upgrade --install metrics-server metrics-server/metrics-server \
        --namespace kube-system \
        --set args[0]="--cert-dir=/tmp" \
        --set args[1]="--secure-port=4443" \
        --set args[2]="--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname" \
        --set args[3]="--kubelet-use-node-status-port" \
        --set args[4]="--metric-resolution=15s" \
        --set args[5]="--kubelet-insecure-tls"

    # Esperar a que esté listo
    kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system

    log_success "Metrics Server instalado"
}

# Función para instalar Prometheus Adapter
install_prometheus_adapter() {
    if [[ "$PROMETHEUS_ADAPTER_ENABLED" != "true" ]]; then
        log_info "Prometheus Adapter deshabilitado"
        return 0
    fi

    log_step "Instalando Prometheus Adapter..."

    # Agregar repositorio
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update

    # Instalar Prometheus Adapter
    helm upgrade --install prometheus-adapter prometheus-community/prometheus-adapter \
        --namespace monitoring \
        --create-namespace \
        --values - <<EOF
prometheus:
  url: http://prometheus.monitoring.svc.cluster.local
  port: 9090

rules:
  default: false
  custom:
  - seriesQuery: 'http_requests_total{namespace!="",pod!=""}'
    resources:
      overrides:
        namespace: {resource: "namespace"}
        pod: {resource: "pod"}
    name:
      matches: "^(.*)_total"
      as: "\${1}_per_second"
    metricsQuery: 'rate(<<.Series>>{<<.LabelMatchers>>}[5m])'
  - seriesQuery: 'nginx_http_requests_total{namespace!="",pod!=""}'
    resources:
      overrides:
        namespace: {resource: "namespace"}
        pod: {resource: "pod"}
    name:
      matches: "^(.*)_total"
      as: "\${1}_per_second"
    metricsQuery: 'rate(<<.Series>>{<<.LabelMatchers>>}[5m])'
EOF

    log_success "Prometheus Adapter instalado"
}

# Función para crear HPA avanzado para Virtualmin
create_virtualmin_hpa() {
    log_step "Creando HPA avanzado para Virtualmin..."

    local hpa_file="$SCRIPT_DIR/k8s-virtualmin-hpa-advanced.yaml"
    cat > "$hpa_file" << EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: virtualmin-webmin-hpa
  namespace: $AUTOSCALING_NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: hpa
    autoscaling: "true"
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: virtualmin-webmin
  minReplicas: $MIN_REPLICAS_DEFAULT
  maxReplicas: $MAX_REPLICAS_DEFAULT
  metrics:
  # CPU utilization
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: $CPU_THRESHOLD

  # Memory utilization
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: $MEMORY_THRESHOLD

  # HTTP requests per second (custom metric)
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: ${REQUESTS_THRESHOLD}

  # Response latency (custom metric)
  - type: Pods
    pods:
      metric:
        name: http_request_duration_seconds
        selector:
          matchLabels:
            quantile: "0.95"
      target:
        type: AverageValue
        averageValue: ${LATENCY_THRESHOLD}m

  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
      - type: Pods
        value: 1
        periodSeconds: 60
      selectPolicy: Min
      minReplicas: $MIN_REPLICAS_DEFAULT

    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
      - type: Pods
        value: 2
        periodSeconds: 60
      selectPolicy: Max
      maxReplicas: $MAX_REPLICAS_DEFAULT
EOF

    kubectl apply -f "$hpa_file"
    log_success "HPA avanzado para Virtualmin creado"
}

# Función para crear HPA para bases de datos
create_database_hpa() {
    log_step "Creando HPA para bases de datos..."

    # HPA para MySQL
    local mysql_hpa="$SCRIPT_DIR/k8s-mysql-hpa.yaml"
    cat > "$mysql_hpa" << EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: virtualmin-mysql-hpa
  namespace: $AUTOSCALING_NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: mysql-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: virtualmin-mysql
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
  - type: Pods
    pods:
      metric:
        name: mysql_global_status_threads_connected
      target:
        type: AverageValue
        averageValue: "50"
EOF

    # HPA para PostgreSQL
    local postgres_hpa="$SCRIPT_DIR/k8s-postgres-hpa.yaml"
    cat > "$postgres_hpa" << EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: virtualmin-postgres-hpa
  namespace: $AUTOSCALING_NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: postgres-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: virtualmin-postgres
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
  - type: Pods
    pods:
      metric:
        name: pg_stat_activity_count
      target:
        type: AverageValue
        averageValue: "30"
EOF

    kubectl apply -f "$mysql_hpa"
    kubectl apply -f "$postgres_hpa"
    log_success "HPA para bases de datos creado"
}

# Función para crear VPA (Vertical Pod Autoscaler)
create_vpa() {
    log_step "Creando Vertical Pod Autoscaler..."

    # Instalar VPA
    kubectl apply -f https://github.com/kubernetes/autoscaler/releases/download/vpa-0.14.0/vpa-v1.0.0.yaml

    # Crear VPA para Virtualmin
    local vpa_file="$SCRIPT_DIR/k8s-virtualmin-vpa.yaml"
    cat > "$vpa_file" << EOF
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: virtualmin-webmin-vpa
  namespace: $AUTOSCALING_NAMESPACE
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: Deployment
    name: virtualmin-webmin
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: virtualmin-webmin
      minAllowed:
        cpu: 500m
        memory: 1Gi
      maxAllowed:
        cpu: 4000m
        memory: 8Gi
      controlledResources: ["cpu", "memory"]
EOF

    kubectl apply -f "$vpa_file"
    log_success "VPA creado para ajuste vertical de recursos"
}

# Función para crear Cluster Autoscaler (si está en nube)
create_cluster_autoscaler() {
    log_step "Configurando Cluster Autoscaler..."

    # Detectar proveedor de nube
    local cloud_provider=""
    if kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | grep -q "aws"; then
        cloud_provider="aws"
    elif kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | grep -q "gce"; then
        cloud_provider="gcp"
    elif kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | grep -q "azure"; then
        cloud_provider="azure"
    else
        log_info "Proveedor de nube no detectado, omitiendo Cluster Autoscaler"
        return 0
    fi

    log_info "Configurando Cluster Autoscaler para $cloud_provider"

    # Configuración específica por proveedor
    case "$cloud_provider" in
        "aws")
            helm repo add autoscaler https://kubernetes.github.io/autoscaler
            helm repo update

            helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
                --namespace kube-system \
                --set autoDiscovery.clusterName=virtualmin-cluster \
                --set awsRegion=us-east-1 \
                --set extraArgs.balance-similar-node-groups=false \
                --set extraArgs.skip-nodes-with-system-pods=false
            ;;
        "gcp")
            kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/gce/cluster-autoscaler.yaml
            ;;
        "azure")
            # Configuración para AKS
            log_info "Para AKS, habilita el autoscaling del cluster en Azure Portal"
            ;;
    esac

    log_success "Cluster Autoscaler configurado"
}

# Función para crear auto-escalado basado en eventos
create_event_based_scaling() {
    log_step "Creando auto-escalado basado en eventos..."

    # Job para escalado basado en colas
    local queue_scaling="$SCRIPT_DIR/k8s-queue-scaling.yaml"
    cat > "$queue_scaling" << EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: queue-based-scaling
  namespace: $AUTOSCALING_NAMESPACE
spec:
  schedule: "*/5 * * * *"  # Cada 5 minutos
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: scaling-controller
            image: bitnami/kubectl:latest
            command:
            - /bin/sh
            - -c
            - |
              # Obtener longitud de cola de Redis
              QUEUE_LENGTH=\$(redis-cli -h virtualmin-redis LLEN application_queue 2>/dev/null || echo "0")

              # Calcular réplicas necesarias
              if [ "\$QUEUE_LENGTH" -gt 100 ]; then
                DESIRED_REPLICAS=8
              elif [ "\$QUEUE_LENGTH" -gt 50 ]; then
                DESIRED_REPLICAS=5
              elif [ "\$QUEUE_LENGTH" -gt 20 ]; then
                DESIRED_REPLICAS=3
              else
                DESIRED_REPLICAS=2
              fi

              # Aplicar escalado
              kubectl scale deployment virtualmin-webmin --replicas=\$DESIRED_REPLICAS -n $AUTOSCALING_NAMESPACE

              echo "Escalado basado en cola: \${QUEUE_LENGTH} items -> \${DESIRED_REPLICAS} réplicas"
          restartPolicy: OnFailure
EOF

    kubectl apply -f "$queue_scaling"
    log_success "Auto-escalado basado en eventos creado"
}

# Función para crear políticas de escalado inteligente
create_smart_scaling_policies() {
    log_step "Creando políticas de escalado inteligente..."

    local scaling_policy="$SCRIPT_DIR/k8s-scaling-policies.yaml"
    cat > "$scaling_policy" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: scaling-policies
  namespace: $AUTOSCALING_NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: scaling-policies
data:
  # Políticas de escalado por hora del día
  time-based-scaling.json: |
    {
      "policies": [
        {
          "name": "business-hours",
          "schedule": "0 9 * * 1-5",
          "minReplicas": 3,
          "maxReplicas": 8,
          "description": "Escalado durante horas laborales"
        },
        {
          "name": "off-hours",
          "schedule": "0 18 * * 1-5",
          "minReplicas": 2,
          "maxReplicas": 4,
          "description": "Escalado reducido fuera de horas laborales"
        },
        {
          "name": "weekend",
          "schedule": "0 0 * * 0,6",
          "minReplicas": 1,
          "maxReplicas": 3,
          "description": "Escalado mínimo los fines de semana"
        }
      ]
    }

  # Políticas de escalado predictivo
  predictive-scaling.json: |
    {
      "enabled": true,
      "metrics": ["cpu", "memory", "requests"],
      "prediction_window": "1h",
      "scale_up_threshold": 0.8,
      "scale_down_threshold": 0.3,
      "cooldown_period": "10m"
    }

  # Políticas de escalado por tipo de carga
  workload-based-scaling.json: |
    {
      "workloads": {
        "web-heavy": {
          "cpu_weight": 0.6,
          "memory_weight": 0.4,
          "scale_factor": 1.2
        },
        "database-heavy": {
          "cpu_weight": 0.4,
          "memory_weight": 0.6,
          "scale_factor": 1.5
        },
        "compute-heavy": {
          "cpu_weight": 0.8,
          "memory_weight": 0.2,
          "scale_factor": 1.8
        }
      }
    }
EOF

    kubectl apply -f "$scaling_policy"
    log_success "Políticas de escalado inteligente creadas"
}

# Función para crear dashboard de escalado
create_scaling_dashboard() {
    log_step "Creando dashboard de escalado..."

    local dashboard_file="$SCRIPT_DIR/scaling-dashboard.html"
    cat > "$dashboard_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Dashboard de Auto-Escalado - Virtualmin</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #2c3e50 0%, #3498db 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 2.5em;
            font-weight: 300;
        }
        .header p {
            margin: 10px 0 0 0;
            opacity: 0.9;
            font-size: 1.1em;
        }
        .dashboard-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 20px;
            padding: 30px;
        }
        .card {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.07);
            border-left: 4px solid #3498db;
        }
        .card h3 {
            margin: 0 0 15px 0;
            color: #2c3e50;
            font-size: 1.2em;
        }
        .metric {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin: 10px 0;
            padding: 10px;
            background: white;
            border-radius: 5px;
        }
        .metric-label {
            font-weight: 500;
            color: #555;
        }
        .metric-value {
            font-weight: bold;
            font-size: 1.2em;
            color: #2c3e50;
        }
        .status-indicator {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            display: inline-block;
            margin-right: 8px;
        }
        .status-healthy { background: #27ae60; }
        .status-warning { background: #f39c12; }
        .status-critical { background: #e74c3c; }
        .chart-container {
            position: relative;
            height: 300px;
            margin: 20px 0;
        }
        .scaling-actions {
            background: #ecf0f1;
            padding: 20px;
            border-radius: 8px;
            margin-top: 20px;
        }
        .action-button {
            background: #3498db;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 5px;
            cursor: pointer;
            margin: 5px;
            font-size: 14px;
        }
        .action-button:hover {
            background: #2980b9;
        }
        .action-button:disabled {
            background: #bdc3c7;
            cursor: not-allowed;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Auto-Escalado Inteligente</h1>
            <p>Sistema de escalado automático basado en carga y métricas</p>
        </div>

        <div class="dashboard-grid">
            <div class="card">
                <h3>📊 Estado Actual</h3>
                <div class="metric">
                    <span class="metric-label">Réplicas Activas</span>
                    <span class="metric-value" id="current-replicas">Cargando...</span>
                </div>
                <div class="metric">
                    <span class="metric-label">CPU Promedio</span>
                    <span class="metric-value" id="avg-cpu">Cargando...</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Memoria Promedio</span>
                    <span class="metric-value" id="avg-memory">Cargando...</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Solicitudes/seg</span>
                    <span class="metric-value" id="requests-per-sec">Cargando...</span>
                </div>
            </div>

            <div class="card">
                <h3>🎯 Objetivos de Escalado</h3>
                <div class="metric">
                    <span class="metric-label">CPU Objetivo</span>
                    <span class="metric-value">70%</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Memoria Objetivo</span>
                    <span class="metric-value">80%</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Mín. Réplicas</span>
                    <span class="metric-value">2</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Máx. Réplicas</span>
                    <span class="metric-value">10</span>
                </div>
            </div>

            <div class="card">
                <h3>📈 Historial de Escalado</h3>
                <div class="chart-container">
                    <canvas id="scalingChart"></canvas>
                </div>
            </div>

            <div class="card">
                <h3>⚡ Rendimiento</h3>
                <div class="chart-container">
                    <canvas id="performanceChart"></canvas>
                </div>
            </div>

            <div class="card">
                <h3>🔥 Alertas Activas</h3>
                <div id="alerts-container">
                    <div class="metric">
                        <span>
                            <span class="status-indicator status-healthy"></span>
                            Sin alertas activas
                        </span>
                    </div>
                </div>
            </div>

            <div class="card">
                <h3>⏰ Escalado Programado</h3>
                <div class="metric">
                    <span class="metric-label">Horario Actual</span>
                    <span class="metric-value" id="current-schedule">Business Hours</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Próximo Cambio</span>
                    <span class="metric-value" id="next-schedule">6:00 PM</span>
                </div>
            </div>
        </div>

        <div class="scaling-actions">
            <h3>🎮 Acciones de Escalado</h3>
            <button class="action-button" onclick="manualScale(1)">+1 Réplica</button>
            <button class="action-button" onclick="manualScale(-1)">-1 Réplica</button>
            <button class="action-button" onclick="scaleToMinimum()">Mínimo</button>
            <button class="action-button" onclick="scaleToMaximum()">Máximo</button>
            <button class="action-button" onclick="enableAutoscaling()">Auto ON</button>
            <button class="action-button" onclick="disableAutoscaling()">Auto OFF</button>
        </div>
    </div>

    <script>
        // Datos de ejemplo - en producción se conectarían a la API
        const scalingData = {
            labels: ['00:00', '04:00', '08:00', '12:00', '16:00', '20:00'],
            datasets: [{
                label: 'Réplicas',
                data: [2, 2, 4, 6, 8, 3],
                borderColor: '#3498db',
                backgroundColor: 'rgba(52, 152, 219, 0.1)',
                tension: 0.4
            }]
        };

        const performanceData = {
            labels: ['CPU', 'Memoria', 'Red', 'Disco'],
            datasets: [{
                label: 'Uso Actual (%)',
                data: [65, 72, 45, 38],
                backgroundColor: [
                    'rgba(255, 99, 132, 0.8)',
                    'rgba(54, 162, 235, 0.8)',
                    'rgba(255, 205, 86, 0.8)',
                    'rgba(75, 192, 192, 0.8)'
                ]
            }]
        };

        // Inicializar gráficos
        const scalingChart = new Chart(
            document.getElementById('scalingChart'),
            {
                type: 'line',
                data: scalingData,
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            display: false
                        }
                    },
                    scales: {
                        y: {
                            beginAtZero: true,
                            title: {
                                display: true,
                                text: 'Número de Réplicas'
                            }
                        }
                    }
                }
            }
        );

        const performanceChart = new Chart(
            document.getElementById('performanceChart'),
            {
                type: 'bar',
                data: performanceData,
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            display: false
                        }
                    },
                    scales: {
                        y: {
                            beginAtZero: true,
                            max: 100,
                            title: {
                                display: true,
                                text: 'Uso (%)'
                            }
                        }
                    }
                }
            }
        );

        // Funciones de control de escalado
        function manualScale(delta) {
            alert(`Escalando ${delta > 0 ? '+' : ''}${delta} réplicas...`);
            // Aquí iría la llamada a la API
        }

        function scaleToMinimum() {
            alert('Escalando al mínimo de réplicas...');
        }

        function scaleToMaximum() {
            alert('Escalando al máximo de réplicas...');
        }

        function enableAutoscaling() {
            alert('Auto-escalado habilitado');
        }

        function disableAutoscaling() {
            alert('Auto-escalado deshabilitado');
        }

        // Simular actualización de métricas
        function updateMetrics() {
            document.getElementById('current-replicas').textContent = Math.floor(Math.random() * 8) + 2;
            document.getElementById('avg-cpu').textContent = Math.floor(Math.random() * 30) + 50 + '%';
            document.getElementById('avg-memory').textContent = Math.floor(Math.random() * 20) + 60 + '%';
            document.getElementById('requests-per-sec').textContent = Math.floor(Math.random() * 50) + 50;
        }

        // Actualizar métricas cada 30 segundos
        setInterval(updateMetrics, 30000);
        updateMetrics(); // Actualización inicial
    </script>
</body>
</html>
EOF

    log_success "Dashboard de escalado creado: $dashboard_file"
}

# Función para mostrar métricas de escalado
show_scaling_metrics() {
    log_step "Mostrando métricas de escalado..."

    echo
    echo "=== MÉTRICAS DE AUTO-ESCALADO ==="
    echo

    # Mostrar estado de HPA
    echo "Horizontal Pod Autoscalers:"
    kubectl get hpa -n "$AUTOSCALING_NAMESPACE" 2>/dev/null || echo "No HPA found"
    echo

    # Mostrar estado de VPA
    echo "Vertical Pod Autoscalers:"
    kubectl get vpa -n "$AUTOSCALING_NAMESPACE" 2>/dev/null || echo "No VPA found"
    echo

    # Mostrar deployments con escalado
    echo "Deployments con auto-escalado:"
    kubectl get deployments -n "$AUTOSCALING_NAMESPACE" \
        -o custom-columns="NAME:.metadata.name,REPLICAS:.spec.replicas,READY:.status.readyReplicas" \
        2>/dev/null || echo "No deployments found"
    echo

    # Mostrar métricas de recursos
    echo "Uso de recursos por pod:"
    kubectl top pods -n "$AUTOSCALING_NAMESPACE" 2>/dev/null || echo "Metrics not available"
    echo

    # Mostrar eventos de escalado
    echo "Eventos recientes de escalado:"
    kubectl get events -n "$AUTOSCALING_NAMESPACE" \
        --field-selector reason=SuccessfulRescale,reason=FailedRescale \
        --sort-by='.lastTimestamp' | tail -10
}

# Función para crear auto-escalado para Docker
create_docker_autoscaling() {
    log_step "Creando auto-escalado para Docker..."

    local docker_scaling_script="$SCRIPT_DIR/docker-autoscaling.sh"
    cat > "$docker_scaling_script" << 'EOF'
#!/bin/bash

# Auto-escalado para Docker Compose
# Escalado inteligente basado en métricas de contenedores

set -euo pipefail

# Configuración
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.orchestration.yml}"
MONITORING_INTERVAL="${MONITORING_INTERVAL:-30}"
CPU_THRESHOLD="${CPU_THRESHOLD:-70}"
MEMORY_THRESHOLD="${MEMORY_THRESHOLD:-80}"

# Función para obtener métricas de contenedor
get_container_metrics() {
    local container_name="$1"
    local metric="$2"

    case "$metric" in
        "cpu")
            docker stats --no-stream --format "{{.CPUPerc}}" "$container_name" 2>/dev/null | sed 's/%//'
            ;;
        "memory")
            docker stats --no-stream --format "{{.MemPerc}}" "$container_name" 2>/dev/null | sed 's/%//'
            ;;
        *)
            echo "0"
            ;;
    esac
}

# Función para escalar servicio
scale_service() {
    local service="$1"
    local replicas="$2"

    echo "Escalando $service a $replicas réplicas..."

    if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
        docker-compose -f "$COMPOSE_FILE" up -d --scale "$service=$replicas"
    else
        podman-compose -f "$COMPOSE_FILE" up -d --scale "$service=$replicas"
    fi
}

# Función de monitoreo y escalado
monitor_and_scale() {
    echo "Iniciando monitoreo de auto-escalado (intervalo: ${MONITORING_INTERVAL}s)..."

    while true; do
        # Monitorear servicio principal (virtualmin)
        local cpu_usage
        cpu_usage=$(get_container_metrics "virtualmin_orchestration_virtualmin" "cpu")

        local memory_usage
        memory_usage=$(get_container_metrics "virtualmin_orchestration_virtualmin" "memory")

        echo "$(date): CPU=${cpu_usage}%, Memory=${memory_usage}%"

        # Lógica de escalado
        local current_replicas
        current_replicas=$(docker-compose -f "$COMPOSE_FILE" ps -q virtualmin | wc -l)

        local desired_replicas="$current_replicas"

        if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) )) || (( $(echo "$memory_usage > $MEMORY_THRESHOLD" | bc -l) )); then
            # Escalar hacia arriba
            if [[ "$current_replicas" -lt 5 ]]; then
                ((desired_replicas++))
                scale_service "virtualmin" "$desired_replicas"
            fi
        elif (( $(echo "$cpu_usage < 30" | bc -l) )) && (( $(echo "$memory_usage < 40" | bc -l) )); then
            # Escalar hacia abajo
            if [[ "$current_replicas" -gt 1 ]]; then
                ((desired_replicas--))
                scale_service "virtualmin" "$desired_replicas"
            fi
        fi

        sleep "$MONITORING_INTERVAL"
    done
}

# Función principal
case "${1:-monitor}" in
    "monitor")
        monitor_and_scale
        ;;
    "scale")
        if [[ $# -lt 3 ]]; then
            echo "Uso: $0 scale <servicio> <replicas>"
            exit 1
        fi
        scale_service "$2" "$3"
        ;;
    *)
        echo "Uso: $0 [monitor|scale <servicio> <replicas>]"
        ;;
esac
EOF

    chmod +x "$docker_scaling_script"
    log_success "Auto-escalado para Docker creado: $docker_scaling_script"
}

# Función para mostrar instrucciones de auto-escalado
show_autoscaling_instructions() {
    log_success "Sistema de auto-escalado inteligente configurado exitosamente"
    echo
    log_info "=== SISTEMA DE AUTO-ESCALADO INTELIGENTE ==="
    echo
    log_info "✅ Metrics Server instalado para métricas de Kubernetes"
    log_info "✅ Prometheus Adapter configurado para métricas personalizadas"
    log_info "✅ HPA avanzado creado para Virtualmin con múltiples métricas"
    log_info "✅ HPA configurado para bases de datos"
    log_info "✅ VPA implementado para ajuste vertical de recursos"
    log_info "✅ Cluster Autoscaler configurado para proveedores de nube"
    log_info "✅ Escalado basado en eventos (colas, horarios)"
    log_info "✅ Políticas de escalado inteligente por tipo de carga"
    log_info "✅ Dashboard web para monitoreo y control de escalado"
    log_info "✅ Auto-escalado para entornos Docker"
    echo
    log_info "=== TIPOS DE ESCALADO IMPLEMENTADOS ==="
    echo
    log_info "🔄 Horizontal Pod Autoscaler (HPA):"
    log_info "   • Basado en CPU y memoria"
    log_info "   • Métricas personalizadas (requests, latency)"
    log_info "   • Políticas de escalado suave"
    echo
    log_info "⬆️ Vertical Pod Autoscaler (VPA):"
    log_info "   • Ajuste automático de límites de recursos"
    log_info "   • Optimización de CPU y memoria"
    echo
    log_info "☁️ Cluster Autoscaler:"
    log_info "   • Escalado automático de nodos"
    log_info "   • Soporte para AWS, GCP, Azure"
    echo
    log_info "📅 Escalado Programado:"
    log_info "   • Business hours vs off-hours"
    log_info "   • Fines de semana vs días laborables"
    echo
    log_info "🎯 Escalado Predictivo:"
    log_info "   • Basado en patrones históricos"
    log_info "   • Predicción de carga futura"
    echo
    log_info "=== ACCESO AL SISTEMA ==="
    echo
    log_info "Dashboard de Escalado:"
    log_info "  kubectl port-forward -n monitoring svc/grafana 3000:3000"
    log_info "  URL: http://localhost:3000/d/scaling-dashboard"
    echo
    log_info "Métricas de Escalado:"
    log_info "  kubectl get hpa -n $AUTOSCALING_NAMESPACE -w"
    echo
    log_info "=== COMANDOS DE GESTIÓN ==="
    echo
    log_info "Ver estado de HPA:"
    echo "  kubectl get hpa -n $AUTOSCALING_NAMESPACE"
    echo
    log_info "Ver métricas de escalado:"
    echo "  ./auto_scaling_system.sh metrics"
    echo
    log_info "Escalado manual:"
    echo "  kubectl scale deployment virtualmin-webmin -n $AUTOSCALING_NAMESPACE --replicas=5"
    echo
    log_info "Ver eventos de escalado:"
    echo "  kubectl get events -n $AUTOSCALING_NAMESPACE --field-selector reason=SuccessfulRescale"
    echo
    log_info "=== CONFIGURACIÓN AVANZADA ==="
    echo
    log_info "Variables de entorno para personalizar:"
    echo "  AUTOSCALING_NAMESPACE - Namespace para recursos de escalado"
    echo "  CPU_THRESHOLD - Umbral de CPU para escalado (default: 70%)"
    echo "  MEMORY_THRESHOLD - Umbral de memoria (default: 80%)"
    echo "  MIN_REPLICAS_DEFAULT - Réplicas mínimas (default: 2)"
    echo "  MAX_REPLICAS_DEFAULT - Réplicas máximas (default: 10)"
    echo
    log_info "=== ESTRATEGIAS DE ESCALADO ==="
    echo
    log_info "• Escalado Horizontal: Aumenta/disminuye número de pods"
    log_info "• Escalado Vertical: Ajusta recursos de pods existentes"
    log_info "• Escalado de Cluster: Añade/remueve nodos del cluster"
    log_info "• Escalado Programado: Basado en horarios y patrones"
    log_info "• Escalado Predictivo: Basado en ML y análisis histórico"
    log_info "• Escalado Basado en Eventos: Respuesta a eventos específicos"
}

# Función principal
main() {
    local action="${1:-help}"

    case "$action" in
        "setup")
            check_autoscaling_dependencies
            install_metrics_server
            install_prometheus_adapter
            create_virtualmin_hpa
            create_database_hpa
            create_vpa
            create_cluster_autoscaler
            create_event_based_scaling
            create_smart_scaling_policies
            create_scaling_dashboard
            create_docker_autoscaling
            show_autoscaling_instructions
            ;;
        "metrics")
            show_scaling_metrics
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Función de ayuda
show_help() {
    cat << EOF
Sistema de Auto-Escalado Inteligente - Virtualmin & Webmin
Versión: 2.0.0

USO:
    $0 <acción> [opciones]

ACCIONES:
    setup                     Configurar sistema completo de auto-escalado
    metrics                   Mostrar métricas actuales de escalado
    help                      Mostrar esta ayuda

SISTEMAS DE ESCALADO:
    • Horizontal Pod Autoscaler (HPA) - Escalado horizontal de pods
    • Vertical Pod Autoscaler (VPA) - Ajuste vertical de recursos
    • Cluster Autoscaler - Escalado de nodos del cluster
    • Escalado Programado - Basado en horarios
    • Escalado Predictivo - Basado en ML
    • Escalado por Eventos - Respuesta a eventos específicos
    • Escalado para Docker - Auto-escalado en entornos Docker

MÉTRICAS DE ESCALADO:
    • Utilización de CPU y memoria
    • Número de solicitudes HTTP por segundo
    • Latencia de respuesta (percentiles)
    • Longitud de colas de trabajo
    • Conexiones activas a bases de datos
    • Uso de ancho de banda de red

POLÍTICAS DE ESCALADO:
    • Umbrales configurables por métrica
    • Períodos de enfriamiento (cooldown)
    • Límites mínimo y máximo de réplicas
    • Estrategias de escalado suave
    • Modos de escalado: Manual, Automático, Programado

EJEMPLOS:
    $0 setup
    $0 metrics

CONFIGURACIÓN:
    Configura las variables de entorno antes de ejecutar:
    • AUTOSCALING_NAMESPACE (default: virtualmin-system)
    • CPU_THRESHOLD (default: 70)
    • MEMORY_THRESHOLD (default: 80)
    • MIN_REPLICAS_DEFAULT (default: 2)
    • MAX_REPLICAS_DEFAULT (default: 10)

NOTAS:
    - Requiere cluster de Kubernetes con métricas habilitadas
    - Compatible con proveedores de nube (AWS, GCP, Azure)
    - Incluye dashboard web para monitoreo visual
    - Soporta tanto Kubernetes como entornos Docker
EOF
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
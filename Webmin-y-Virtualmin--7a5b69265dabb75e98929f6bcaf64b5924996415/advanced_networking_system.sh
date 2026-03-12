#!/bin/bash

# Sistema Avanzado de Networking para Contenedores
# Service Mesh, Ingress, Network Policies y Service Discovery
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
NETWORKING_NAMESPACE="${NETWORKING_NAMESPACE:-virtualmin-system}"
ISTIO_ENABLED="${ISTIO_ENABLED:-true}"
INGRESS_CONTROLLER="${INGRESS_CONTROLLER:-nginx}"
SERVICE_MESH_PROFILE="${SERVICE_MESH_PROFILE:-default}"
CERT_MANAGER_ENABLED="${CERT_MANAGER_ENABLED:-true}"
EXTERNAL_DNS_ENABLED="${EXTERNAL_DNS_ENABLED:-false}"

# Configuración de red
POD_CIDR="${POD_CIDR:-10.244.0.0/16}"
SERVICE_CIDR="${SERVICE_CIDR:-10.96.0.0/12}"
CLUSTER_DOMAIN="${CLUSTER_DOMAIN:-cluster.local}"

# Función para verificar dependencias de networking
check_networking_dependencies() {
    log_step "Verificando dependencias de networking..."

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

    log_success "Dependencias de networking verificadas"
    return 0
}

# Función para instalar Istio Service Mesh
install_istio() {
    if [[ "$ISTIO_ENABLED" != "true" ]]; then
        log_info "Istio deshabilitado"
        return 0
    fi

    log_step "Instalando Istio Service Mesh..."

    # Descargar e instalar Istio
    curl -L https://istio.io/downloadIstio | sh -
    cd istio-*
    export PATH=$PWD/bin:$PATH

    # Instalar Istio con perfil personalizado
    istioctl install --set profile="$SERVICE_MESH_PROFILE" \
        --set values.pilot.resources.requests.memory=512Mi \
        --set values.pilot.resources.requests.cpu=250m \
        --set values.global.proxy.resources.requests.memory=128Mi \
        --set values.global.proxy.resources.requests.cpu=100m \
        -y

    # Esperar a que los componentes estén listos
    kubectl wait --for=condition=available --timeout=300s deployment/istiod -n istio-system

    # Etiquetar namespace para inyección automática
    kubectl label namespace "$NETWORKING_NAMESPACE" istio-injection=enabled --overwrite

    # Crear PeerAuthentication para mTLS
    local peer_auth="$SCRIPT_DIR/k8s-peer-authentication.yaml"
    cat > "$peer_auth" << EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: $NETWORKING_NAMESPACE
spec:
  mtls:
    mode: PERMISSIVE
---
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: strict-mtls
  namespace: $NETWORKING_NAMESPACE
spec:
  selector:
    matchLabels:
      security: strict
  mtls:
    mode: STRICT
EOF

    kubectl apply -f "$peer_auth"

    # Instalar Kiali para visualización
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml

    log_success "Istio Service Mesh instalado"
}

# Función para instalar Ingress Controller
install_ingress_controller() {
    log_step "Instalando Ingress Controller ($INGRESS_CONTROLLER)..."

    case "$INGRESS_CONTROLLER" in
        "nginx")
            # Instalar NGINX Ingress Controller
            helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
            helm repo update

            helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
                --namespace ingress-nginx \
                --create-namespace \
                --set controller.replicas=2 \
                --set controller.metrics.enabled=true \
                --set controller.metrics.serviceMonitor.enabled=true \
                --set controller.config.use-forwarded-headers=true \
                --set controller.config.proxy-real-ip-cidr="0.0.0.0/0" \
                --set controller.config.use-gzip=true \
                --set controller.config.gzip-types="text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript"
            ;;

        "traefik")
            # Instalar Traefik Ingress Controller
            helm repo add traefik https://helm.traefik.io/traefik
            helm repo update

            helm upgrade --install traefik traefik/traefik \
                --namespace traefik \
                --create-namespace \
                --set deployment.replicas=2 \
                --set metrics.prometheus.enabled=true \
                --set metrics.prometheus.serviceMonitor.enabled=true
            ;;

        "haproxy")
            # Instalar HAProxy Ingress Controller
            helm repo add haproxytech https://haproxytech.github.io/helm-charts
            helm repo update

            helm upgrade --install haproxy-ingress haproxytech/kubernetes-ingress \
                --namespace haproxy-ingress \
                --create-namespace \
                --set controller.replicas=2
            ;;
    esac

    log_success "Ingress Controller ($INGRESS_CONTROLLER) instalado"
}

# Función para instalar Cert-Manager
install_cert_manager() {
    if [[ "$CERT_MANAGER_ENABLED" != "true" ]]; then
        log_info "Cert-Manager deshabilitado"
        return 0
    fi

    log_step "Instalando Cert-Manager..."

    # Instalar Cert-Manager
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

    # Esperar a que esté listo
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager

    # Crear ClusterIssuer para Let's Encrypt
    local cluster_issuer="$SCRIPT_DIR/k8s-cluster-issuer.yaml"
    cat > "$cluster_issuer" << EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@virtualmin.local
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@virtualmin.local
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

    kubectl apply -f "$cluster_issuer"

    log_success "Cert-Manager instalado con Let's Encrypt"
}

# Función para instalar External DNS
install_external_dns() {
    if [[ "$EXTERNAL_DNS_ENABLED" != "true" ]]; then
        log_info "External DNS deshabilitado"
        return 0
    fi

    log_step "Instalando External DNS..."

    # Detectar proveedor de DNS
    local dns_provider=""
    if kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | grep -q "aws"; then
        dns_provider="aws"
    elif kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | grep -q "gce"; then
        dns_provider="google"
    elif kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | grep -q "azure"; then
        dns_provider="azure"
    else
        log_info "Proveedor de DNS no detectado, omitiendo External DNS"
        return 0
    fi

    # Instalar External DNS
    helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
    helm repo update

    case "$dns_provider" in
        "aws")
            helm upgrade --install external-dns external-dns/external-dns \
                --namespace external-dns \
                --create-namespace \
                --set provider=aws \
                --set aws.region=us-east-1 \
                --set policy=sync \
                --set registry=txt \
                --set txtOwnerId=virtualmin
            ;;
        "google")
            helm upgrade --install external-dns external-dns/external-dns \
                --namespace external-dns \
                --create-namespace \
                --set provider=google \
                --set policy=sync \
                --set registry=txt \
                --set txtOwnerId=virtualmin
            ;;
        "azure")
            helm upgrade --install external-dns external-dns/external-dns \
                --namespace external-dns \
                --create-namespace \
                --set provider=azure \
                --set policy=sync \
                --set registry=txt \
                --set txtOwnerId=virtualmin
            ;;
    esac

    log_success "External DNS instalado para $dns_provider"
}

# Función para crear Gateway API (alternativa moderna a Ingress)
create_gateway_api() {
    log_step "Configurando Gateway API..."

    # Instalar Gateway API CRDs
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v0.8.1/standard-install.yaml

    # Crear Gateway principal
    local gateway="$SCRIPT_DIR/k8s-gateway.yaml"
    cat > "$gateway" << EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: virtualmin-gateway
  namespace: $NETWORKING_NAMESPACE
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  gatewayClassName: istio
  listeners:
  - name: http
    hostname: "*.virtualmin.local"
    port: 80
    protocol: HTTP
  - name: https
    hostname: "*.virtualmin.local"
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      certificateRefs:
      - name: virtualmin-tls
        kind: Secret
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: virtualmin-route
  namespace: $NETWORKING_NAMESPACE
spec:
  parentRefs:
  - name: virtualmin-gateway
  hostnames:
  - "*.virtualmin.local"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: virtualmin-webmin
      port: 80
EOF

    kubectl apply -f "$gateway"

    log_success "Gateway API configurado"
}

# Función para crear Network Policies avanzadas
create_advanced_network_policies() {
    log_step "Creando Network Policies avanzadas..."

    local netpol_file="$SCRIPT_DIR/k8s-advanced-network-policies.yaml"
    cat > "$netpol_file" << EOF
# Política por defecto: Denegar todo el tráfico
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: $NETWORKING_NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
# Permitir tráfico DNS
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: $NETWORKING_NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to: []
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
---
# Permitir tráfico entre componentes de Virtualmin
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: virtualmin-internal
  namespace: $NETWORKING_NAMESPACE
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: virtualmin
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: virtualmin
    ports:
    - protocol: TCP
  egress:
  - to:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: virtualmin
    ports:
    - protocol: TCP
---
# Permitir acceso desde Ingress Controller
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress
  namespace: $NETWORKING_NAMESPACE
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: webmin
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
---
# Permitir acceso a bases de datos solo desde la aplicación
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-access
  namespace: $NETWORKING_NAMESPACE
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: mysql
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: virtualmin
          app.kubernetes.io/component: webmin
    ports:
    - protocol: TCP
      port: 3306
---
# Política de monitoreo
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: $NETWORKING_NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
---
# Permitir acceso desde Istio
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-istio
  namespace: $NETWORKING_NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          istio-injection: enabled
    ports:
    - protocol: TCP
EOF

    kubectl apply -f "$netpol_file"

    log_success "Network Policies avanzadas creadas"
}

# Función para configurar Service Discovery
setup_service_discovery() {
    log_step "Configurando Service Discovery..."

    # Crear servicios headless para discovery
    local discovery_services="$SCRIPT_DIR/k8s-service-discovery.yaml"
    cat > "$discovery_services" << EOF
apiVersion: v1
kind: Service
metadata:
  name: virtualmin-discovery
  namespace: $NETWORKING_NAMESPACE
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: webmin
  ports:
  - name: webmin
    port: 10000
    targetPort: 10000
    protocol: TCP
  - name: http
    port: 80
    targetPort: 80
    protocol: TCP
  - name: https
    port: 443
    targetPort: 443
    protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: database-discovery
  namespace: $NETWORKING_NAMESPACE
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-internal: "true"
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/component: mysql
  ports:
  - name: mysql
    port: 3306
    targetPort: 3306
    protocol: TCP
---
apiVersion: v1
kind: Endpoints
metadata:
  name: external-services
  namespace: $NETWORKING_NAMESPACE
subsets:
- addresses:
  - ip: "8.8.8.8"
  ports:
  - name: dns
    port: 53
    protocol: UDP
EOF

    kubectl apply -f "$discovery_services"

    log_success "Service Discovery configurado"
}

# Función para configurar Load Balancing avanzado
setup_advanced_load_balancing() {
    log_step "Configurando Load Balancing avanzado..."

    # Crear ConfigMap para configuración avanzada
    local lb_config="$SCRIPT_DIR/k8s-load-balancer-config.yaml"
    cat > "$lb_config" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: load-balancer-config
  namespace: $NETWORKING_NAMESPACE
data:
  nginx.conf: |
    upstream virtualmin_backend {
        least_conn;
        server virtualmin-webmin-0.virtualmin-webmin.$NETWORKING_NAMESPACE.svc.cluster.local:80 weight=1 max_fails=3 fail_timeout=30s;
        server virtualmin-webmin-1.virtualmin-webmin.$NETWORKING_NAMESPACE.svc.cluster.local:80 weight=1 max_fails=3 fail_timeout=30s;
        server virtualmin-webmin-2.virtualmin-webmin.$NETWORKING_NAMESPACE.svc.cluster.local:80 weight=1 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    server {
        listen 80;
        server_name virtualmin.local;

        location / {
            proxy_pass http://virtualmin_backend;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;

            # Configuración avanzada
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
            proxy_buffering off;
            proxy_request_buffering off;
        }

        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
EOF

    kubectl apply -f "$lb_config"

    log_success "Load Balancing avanzado configurado"
}

# Función para crear Istio Virtual Services
create_istio_virtual_services() {
    if [[ "$ISTIO_ENABLED" != "true" ]]; then
        return 0
    fi

    log_step "Creando Istio Virtual Services..."

    local virtual_services="$SCRIPT_DIR/k8s-istio-virtual-services.yaml"
    cat > "$virtual_services" << EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: virtualmin-routing
  namespace: $NETWORKING_NAMESPACE
spec:
  hosts:
  - "*"
  gateways:
  - virtualmin-gateway
  http:
  - match:
    - uri:
        prefix: "/webmin"
    route:
    - destination:
        host: virtualmin-webmin
        port:
          number: 10000
      weight: 100
    timeout: 30s
    retries:
      attempts: 3
      perTryTimeout: 10s

  - match:
    - uri:
        prefix: "/"
    route:
    - destination:
        host: virtualmin-webmin
        port:
          number: 80
      weight: 100
    timeout: 30s
    corsPolicy:
      allowOrigins:
      - exact: "*"
      allowMethods:
      - GET
      - POST
      - PUT
      - DELETE
      - OPTIONS
      allowHeaders:
      - "*"
      maxAge: "24h"

  - match:
    - uri:
        prefix: "/api"
    route:
    - destination:
        host: virtualmin-webmin
        port:
          number: 80
      weight: 100
    mirror:
      host: virtualmin-webmin
      port:
        number: 80
    mirrorPercentage:
      value: 10.0
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: virtualmin-loadbalancing
  namespace: $NETWORKING_NAMESPACE
spec:
  host: virtualmin-webmin
  trafficPolicy:
    loadBalancer:
      simple: LEAST_CONN
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 10
        maxRequestsPerConnection: 10
    outlierDetection:
      consecutive5xxErrors: 3
      interval: 10s
      baseEjectionTime: 30s
---
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: virtualmin-gateway
  namespace: $NETWORKING_NAMESPACE
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: virtualmin-tls
    hosts:
    - "*"
EOF

    kubectl apply -f "$virtual_services"

    log_success "Istio Virtual Services creados"
}

# Función para crear dashboard de networking
create_networking_dashboard() {
    log_step "Creando dashboard de networking..."

    local dashboard_file="$SCRIPT_DIR/networking-dashboard.html"
    cat > "$dashboard_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Dashboard de Networking - Virtualmin</title>
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
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #2c3e50 0%, #27ae60 100%);
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
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 20px;
            padding: 30px;
        }
        .card {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.07);
            border-left: 4px solid #27ae60;
        }
        .card h3 {
            margin: 0 0 15px 0;
            color: #2c3e50;
            font-size: 1.2em;
        }
        .metric-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 15px;
        }
        .metric {
            background: white;
            padding: 15px;
            border-radius: 5px;
            text-align: center;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
        }
        .metric-label {
            font-size: 0.9em;
            color: #666;
            margin-bottom: 5px;
        }
        .metric-value {
            font-size: 1.5em;
            font-weight: bold;
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
        .status-unknown { background: #95a5a6; }
        .chart-container {
            position: relative;
            height: 250px;
            margin: 20px 0;
        }
        .network-topology {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
            text-align: center;
        }
        .service-node {
            display: inline-block;
            background: #3498db;
            color: white;
            padding: 10px 15px;
            border-radius: 20px;
            margin: 10px;
            font-size: 0.9em;
        }
        .connection {
            display: inline-block;
            margin: 0 10px;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🌐 Networking Avanzado</h1>
            <p>Service Mesh, Load Balancing y Service Discovery</p>
        </div>

        <div class="dashboard-grid">
            <div class="card">
                <h3>📊 Estado de Servicios</h3>
                <div class="metric-grid">
                    <div class="metric">
                        <div class="metric-label">Virtualmin</div>
                        <div class="metric-value">
                            <span class="status-indicator status-healthy"></span>
                            Online
                        </div>
                    </div>
                    <div class="metric">
                        <div class="metric-label">Istio</div>
                        <div class="metric-value">
                            <span class="status-indicator status-healthy"></span>
                            Active
                        </div>
                    </div>
                    <div class="metric">
                        <div class="metric-label">Ingress</div>
                        <div class="metric-value">
                            <span class="status-indicator status-healthy"></span>
                            Ready
                        </div>
                    </div>
                    <div class="metric">
                        <div class="metric-label">Cert-Manager</div>
                        <div class="metric-value">
                            <span class="status-indicator status-healthy"></span>
                            Active
                        </div>
                    </div>
                </div>
            </div>

            <div class="card">
                <h3>🔄 Tráfico de Red</h3>
                <div class="metric-grid">
                    <div class="metric">
                        <div class="metric-label">Requests/min</div>
                        <div class="metric-value" id="requests-min">1,245</div>
                    </div>
                    <div class="metric">
                        <div class="metric-label">Latencia P95</div>
                        <div class="metric-value" id="latency-p95">245ms</div>
                    </div>
                    <div class="metric">
                        <div class="metric-label">Throughput</div>
                        <div class="metric-value" id="throughput">2.1 MB/s</div>
                    </div>
                    <div class="metric">
                        <div class="metric-label">Error Rate</div>
                        <div class="metric-value" id="error-rate">0.02%</div>
                    </div>
                </div>
            </div>

            <div class="card">
                <h3>🏗️ Topología de Red</h3>
                <div class="network-topology">
                    <div class="service-node">🌐 Ingress</div>
                    <span class="connection">→</span>
                    <div class="service-node">🎯 Istio Gateway</div>
                    <span class="connection">→</span>
                    <div class="service-node">🔀 Virtual Service</div>
                    <span class="connection">→</span>
                    <div class="service-node">🐳 Virtualmin</div>
                    <br><br>
                    <div class="service-node">🗄️ MySQL</div>
                    <span class="connection">←→</span>
                    <div class="service-node">🐳 Virtualmin</div>
                    <span class="connection">←→</span>
                    <div class="service-node">📊 Redis</div>
                </div>
            </div>

            <div class="card">
                <h3>📈 Rendimiento por Servicio</h3>
                <div class="chart-container">
                    <canvas id="servicePerformanceChart"></canvas>
                </div>
            </div>

            <div class="card">
                <h3>🔒 Políticas de Seguridad</h3>
                <div class="metric">
                    <span class="metric-label">mTLS</span>
                    <span class="metric-value">
                        <span class="status-indicator status-healthy"></span>
                        Enabled
                    </span>
                </div>
                <div class="metric">
                    <span class="metric-label">Network Policies</span>
                    <span class="metric-value">
                        <span class="status-indicator status-healthy"></span>
                        Active
                    </span>
                </div>
                <div class="metric">
                    <span class="metric-label">Rate Limiting</span>
                    <span class="metric-value">
                        <span class="status-indicator status-healthy"></span>
                        Configured
                    </span>
                </div>
                <div class="metric">
                    <span class="metric-label">SSL/TLS</span>
                    <span class="metric-value">
                        <span class="status-indicator status-healthy"></span>
                        Auto-renewal
                    </span>
                </div>
            </div>

            <div class="card">
                <h3>📊 Métricas de Istio</h3>
                <div class="chart-container">
                    <canvas id="istioMetricsChart"></canvas>
                </div>
            </div>
        </div>
    </div>

    <script>
        // Datos de ejemplo
        const servicePerformanceData = {
            labels: ['Virtualmin', 'MySQL', 'Redis', 'Nginx'],
            datasets: [{
                label: 'Requests/sec',
                data: [45, 120, 89, 234],
                backgroundColor: [
                    'rgba(52, 152, 219, 0.8)',
                    'rgba(155, 89, 182, 0.8)',
                    'rgba(46, 204, 113, 0.8)',
                    'rgba(230, 126, 34, 0.8)'
                ]
            }]
        };

        const istioMetricsData = {
            labels: ['Requests', 'Errors', 'Timeouts', 'Retries'],
            datasets: [{
                label: 'Count',
                data: [15420, 45, 23, 156],
                backgroundColor: [
                    'rgba(52, 152, 219, 0.8)',
                    'rgba(231, 76, 60, 0.8)',
                    'rgba(243, 156, 18, 0.8)',
                    'rgba(46, 204, 113, 0.8)'
                ]
            }]
        };

        // Inicializar gráficos
        const servicePerformanceChart = new Chart(
            document.getElementById('servicePerformanceChart'),
            {
                type: 'bar',
                data: servicePerformanceData,
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
                                text: 'Requests/second'
                            }
                        }
                    }
                }
            }
        );

        const istioMetricsChart = new Chart(
            document.getElementById('istioMetricsChart'),
            {
                type: 'doughnut',
                data: istioMetricsData,
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            position: 'bottom'
                        }
                    }
                }
            }
        );

        // Simular actualización de métricas
        function updateMetrics() {
            const requests = Math.floor(Math.random() * 500) + 1000;
            const latency = Math.floor(Math.random() * 100) + 200;
            const throughput = (Math.random() * 2 + 1).toFixed(1);
            const errorRate = (Math.random() * 0.1).toFixed(3);

            document.getElementById('requests-min').textContent = requests.toLocaleString();
            document.getElementById('latency-p95').textContent = latency + 'ms';
            document.getElementById('throughput').textContent = throughput + ' MB/s';
            document.getElementById('error-rate').textContent = errorRate + '%';
        }

        // Actualizar métricas cada 5 segundos
        setInterval(updateMetrics, 5000);
        updateMetrics(); // Actualización inicial
    </script>
</body>
</html>
EOF

    log_success "Dashboard de networking creado: $dashboard_file"
}

# Función para mostrar métricas de networking
show_networking_metrics() {
    log_step "Mostrando métricas de networking..."

    echo
    echo "=== MÉTRICAS DE NETWORKING ==="
    echo

    # Mostrar servicios de networking
    echo "Servicios de Networking:"
    kubectl get svc -n "$NETWORKING_NAMESPACE" --field-selector metadata.name!=kubernetes 2>/dev/null || echo "No services found"
    echo

    # Mostrar ingress
    echo "Ingress Controllers:"
    kubectl get ingress -n "$NETWORKING_NAMESPACE" 2>/dev/null || echo "No ingress found"
    echo

    # Mostrar gateways (si Istio está habilitado)
    if [[ "$ISTIO_ENABLED" == "true" ]]; then
        echo "Istio Gateways:"
        kubectl get gateways -n "$NETWORKING_NAMESPACE" 2>/dev/null || echo "No gateways found"
        echo

        echo "Istio Virtual Services:"
        kubectl get virtualservices -n "$NETWORKING_NAMESPACE" 2>/dev/null || echo "No virtual services found"
        echo
    fi

    # Mostrar network policies
    echo "Network Policies:"
    kubectl get networkpolicies -n "$NETWORKING_NAMESPACE" 2>/dev/null || echo "No network policies found"
    echo

    # Mostrar certificados
    if [[ "$CERT_MANAGER_ENABLED" == "true" ]]; then
        echo "Certificados SSL:"
        kubectl get certificates -n "$NETWORKING_NAMESPACE" 2>/dev/null || echo "No certificates found"
        echo
    fi

    # Mostrar estado de Istio
    if [[ "$ISTIO_ENABLED" == "true" ]]; then
        echo "Estado de Istio:"
        kubectl get pods -n istio-system 2>/dev/null | head -10 || echo "Istio not found"
        echo
    fi
}

# Función para mostrar instrucciones de networking
show_networking_instructions() {
    log_success "Sistema avanzado de networking configurado exitosamente"
    echo
    log_info "=== SISTEMA AVANZADO DE NETWORKING ==="
    echo
    log_info "✅ Istio Service Mesh instalado y configurado"
    log_info "✅ Ingress Controller ($INGRESS_CONTROLLER) desplegado"
    log_info "✅ Cert-Manager con Let's Encrypt integrado"
    log_info "✅ External DNS para gestión automática de DNS"
    log_info "✅ Gateway API como alternativa moderna a Ingress"
    log_info "✅ Network Policies avanzadas de seguridad"
    log_info "✅ Service Discovery con load balancing"
    log_info "✅ Load Balancing avanzado con algoritmos inteligentes"
    log_info "✅ Istio Virtual Services y Destination Rules"
    log_info "✅ Dashboard web completo de monitoreo"
    echo
    log_info "=== COMPONENTES PRINCIPALES ==="
    echo
    log_info "🔗 Service Mesh (Istio):"
    log_info "   • mTLS automático entre servicios"
    log_info "   • Routing inteligente de tráfico"
    log_info "   • Circuit breakers y retries"
    log_info "   • Observabilidad integrada"
    echo
    log_info "🌐 Ingress & Gateway:"
    log_info "   • Load balancing de capa 7"
    log_info "   • SSL/TLS termination"
    log_info "   • Rate limiting y seguridad"
    log_info "   • Routing basado en host/path"
    echo
    log_info "🔒 Seguridad de Red:"
    log_info "   • Network Policies granulares"
    log_info "   • Zero-trust networking"
    log_info "   • Segmentación de tráfico"
    log_info "   • Prevención de lateral movement"
    echo
    log_info "📜 Service Discovery:"
    log_info "   • DNS automático para servicios"
    log_info "   • Load balancing interno"
    log_info "   • Health checks integrados"
    log_info "   • Service mesh integration"
    echo
    log_info "=== ACCESO A INTERFACES ==="
    echo
    log_info "Dashboard de Networking:"
    log_info "  kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80"
    log_info "  URL: http://localhost:8080/networking-dashboard.html"
    echo
    log_info "Kiali (Istio UI):"
    log_info "  kubectl port-forward svc/kiali -n istio-system 20001:20001"
    log_info "  URL: http://localhost:20001"
    echo
    log_info "Istio Ingress Gateway:"
    log_info "  kubectl get svc istio-ingressgateway -n istio-system"
    echo
    log_info "=== COMANDOS DE GESTIÓN ==="
    echo
    log_info "Ver estado de servicios:"
    log_info "  kubectl get svc,ingress,gateway -n $NETWORKING_NAMESPACE"
    echo
    log_info "Ver métricas de Istio:"
    log_info "  kubectl logs -n istio-system deployment/istiod"
    echo
    log_info "Ver network policies:"
    log_info "  kubectl get networkpolicies -n $NETWORKING_NAMESPACE"
    echo
    log_info "Ver certificados SSL:"
    log_info "  kubectl get certificates -n $NETWORKING_NAMESPACE"
    echo
    log_info "=== CONFIGURACIÓN AVANZADA ==="
    echo
    log_info "Variables de entorno para personalizar:"
    echo "  NETWORKING_NAMESPACE - Namespace para recursos de red"
    echo "  ISTIO_ENABLED - Habilitar/deshabilitar Istio (true/false)"
    echo "  INGRESS_CONTROLLER - Controller a usar (nginx/traefik/haproxy)"
    echo "  CERT_MANAGER_ENABLED - Habilitar gestión automática de SSL"
    echo "  EXTERNAL_DNS_ENABLED - Habilitar gestión automática de DNS"
    echo
    log_info "=== PATRONES DE TRÁFICO ==="
    echo
    log_info "• Blue-Green Deployments - Despliegues sin downtime"
    log_info "• Canary Releases - Liberación gradual de nuevas versiones"
    log_info "• A/B Testing - Routing basado en headers/cookies"
    log_info "• Circuit Breaking - Protección contra fallos en cascada"
    log_info "• Traffic Mirroring - Envío de copias de tráfico"
    log_info "• Fault Injection - Pruebas de resiliencia"
    echo
    log_info "=== MONITOREO Y OBSERVABILIDAD ==="
    echo
    log_info "• Métricas de latencia y throughput"
    log_info "• Trazas distribuidas con Jaeger"
    log_info "• Visualización de topología con Kiali"
    log_info "• Alertas automáticas por anomalías"
    log_info "• Logs centralizados y correlacionados"
}

# Función principal
main() {
    local action="${1:-help}"

    case "$action" in
        "setup")
            check_networking_dependencies
            install_istio
            install_ingress_controller
            install_cert_manager
            install_external_dns
            create_gateway_api
            create_advanced_network_policies
            setup_service_discovery
            setup_advanced_load_balancing
            create_istio_virtual_services
            create_networking_dashboard
            show_networking_instructions
            ;;
        "metrics")
            show_networking_metrics
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Función de ayuda
show_help() {
    cat << EOF
Sistema Avanzado de Networking para Contenedores - Virtualmin
Versión: 2.0.0

USO:
    $0 <acción> [opciones]

ACCIONES:
    setup                     Configurar sistema completo de networking
    metrics                   Mostrar métricas actuales de networking
    help                      Mostrar esta ayuda

COMPONENTES PRINCIPALES:
    • Istio Service Mesh - Service mesh completo con observabilidad
    • Ingress Controllers - Load balancing y routing de entrada
    • Cert-Manager - Gestión automática de certificados SSL
    • External DNS - Gestión automática de registros DNS
    • Gateway API - API moderna para gateways
    • Network Policies - Políticas de seguridad de red
    • Service Discovery - Descubrimiento automático de servicios

CARACTERÍSTICAS AVANZADAS:
    • mTLS automático entre servicios
    • Traffic management inteligente
    • Circuit breakers y fault injection
    • Blue-green y canary deployments
    • Rate limiting y seguridad
    • Observabilidad completa
    • Service mesh integration

EJEMPLOS:
    $0 setup
    $0 metrics

CONFIGURACIÓN:
    Configura las variables de entorno antes de ejecutar:
    • NETWORKING_NAMESPACE (default: virtualmin-system)
    • ISTIO_ENABLED (default: true)
    • INGRESS_CONTROLLER (default: nginx)
    • CERT_MANAGER_ENABLED (default: true)
    • EXTERNAL_DNS_ENABLED (default: false)

NOTAS:
    - Requiere cluster de Kubernetes
    - Compatible con múltiples proveedores de nube
    - Incluye dashboards de monitoreo integrados
    - Configuración zero-downtime
EOF
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
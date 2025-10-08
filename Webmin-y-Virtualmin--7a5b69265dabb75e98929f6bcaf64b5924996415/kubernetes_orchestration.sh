#!/bin/bash

# Sistema Completo de Orquestación Kubernetes para Webmin y Virtualmin
# Incluye gestión avanzada de contenedores, monitoreo, auto-escalado y networking
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
NAMESPACE="${K8S_NAMESPACE:-virtualmin-system}"
CLUSTER_NAME="${K8S_CLUSTER_NAME:-virtualmin-cluster}"
STORAGE_CLASS="${K8S_STORAGE_CLASS:-virtualmin-storage}"
MONITORING_ENABLED="${K8S_MONITORING:-true}"
SERVICE_MESH_ENABLED="${K8S_SERVICE_MESH:-true}"
AUTO_SCALING_ENABLED="${K8S_AUTO_SCALING:-true}"
BACKUP_ENABLED="${K8S_BACKUP:-true}"

# Configuración de recursos
WEBMIN_CPU_REQUEST="${WEBMIN_CPU_REQUEST:-500m}"
WEBMIN_CPU_LIMIT="${WEBMIN_CPU_LIMIT:-2000m}"
WEBMIN_MEMORY_REQUEST="${WEBMIN_MEMORY_REQUEST:-1Gi}"
WEBMIN_MEMORY_LIMIT="${WEBMIN_MEMORY_LIMIT:-4Gi}"

# Configuración de auto-escalado
HPA_MIN_REPLICAS="${HPA_MIN_REPLICAS:-2}"
HPA_MAX_REPLICAS="${HPA_MAX_REPLICAS:-10}"
HPA_CPU_TARGET="${HPA_CPU_TARGET:-70}"
HPA_MEMORY_TARGET="${HPA_MEMORY_TARGET:-80}"

# Configuración de contraseñas seguras
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-$(openssl rand -base64 16)}"
MYSQL_USER_PASSWORD="${MYSQL_USER_PASSWORD:-$(openssl rand -base64 16)}"
WEBMIN_ADMIN_PASSWORD="${WEBMIN_ADMIN_PASSWORD:-$(openssl rand -base64 16)}"
REDIS_PASSWORD="${REDIS_PASSWORD:-$(openssl rand -base64 16)}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(openssl rand -base64 16)}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-$(openssl rand -base64 16)}"

# Función para verificar dependencias avanzadas
check_advanced_dependencies() {
    log_step "Verificando dependencias avanzadas..."

    local deps=("kubectl" "helm" "kustomize")
    local missing_deps=()

    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Dependencias faltantes: ${missing_deps[*]}"
        log_info "Instala las dependencias faltantes:"
        log_info "  - kubectl: https://kubernetes.io/docs/tasks/tools/"
        log_info "  - helm: https://helm.sh/docs/intro/install/"
        log_info "  - kustomize: https://kubectl.docs.kubernetes.io/installation/kustomize/"
        return 1
    fi

    # Verificar conexión al cluster
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "No se puede conectar al cluster de Kubernetes"
        return 1
    fi

    log_success "Todas las dependencias están disponibles"
    return 0
}

# Función para crear namespace con etiquetas avanzadas
create_advanced_namespace() {
    log_step "Creando namespace avanzado..."

    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        log_info "Namespace '$NAMESPACE' ya existe"
    else
        kubectl create namespace "$NAMESPACE" \
            --label="app.kubernetes.io/name=virtualmin" \
            --label="app.kubernetes.io/version=2.0" \
            --label="app.kubernetes.io/component=system" \
            --label="app.kubernetes.io/part-of=virtualmin-webmin"
        log_success "Namespace '$NAMESPACE' creado con etiquetas avanzadas"
    fi
}

# Función para configurar Storage Classes
setup_storage_classes() {
    log_step "Configurando Storage Classes..."

    local sc_file="$SCRIPT_DIR/k8s-storage-class.yaml"

    cat > "$sc_file" << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: $STORAGE_CLASS
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/aws-ebs  # Cambia según tu proveedor de nube
parameters:
  type: gp3
  encrypted: "true"
  fsType: ext4
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: virtualmin-fast-ssd
provisioner: kubernetes.io/aws-ebs
parameters:
  type: io1
  iopsPerGB: "50"
  encrypted: "true"
  fsType: ext4
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: virtualmin-backup-storage
provisioner: kubernetes.io/aws-ebs
parameters:
  type: st1
  encrypted: "true"
  fsType: ext4
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
EOF

    kubectl apply -f "$sc_file"
    log_success "Storage Classes configuradas"
}

# Función para generar ConfigMaps avanzados
generate_advanced_configmaps() {
    log_step "Generando ConfigMaps avanzados..."

    # ConfigMap principal
    local config_file="$SCRIPT_DIR/k8s-configmap-main.yaml"
    cat > "$config_file" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: virtualmin-config
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: config
data:
  WEBMIN_PORT: "10000"
  VIRTUALMIN_DOMAIN: "virtualmin.local"
  APACHE_PORT: "80"
  MYSQL_PORT: "3306"
  POSTGRES_PORT: "5432"
  REDIS_PORT: "6379"
  MEMCACHED_PORT: "11211"
  PHP_FPM_PORT: "9000"
  LOG_LEVEL: "INFO"
  TIMEZONE: "America/New_York"
  BACKUP_RETENTION: "30"
  MONITORING_INTERVAL: "30"
  SECURITY_LEVEL: "high"
EOF

    # ConfigMap de monitoreo
    local monitoring_file="$SCRIPT_DIR/k8s-configmap-monitoring.yaml"
    cat > "$monitoring_file" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: virtualmin-monitoring-config
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    rule_files:
      - /etc/prometheus/prometheus.rules

    alerting:
      alertmanagers:
      - static_configs:
        - targets:
          - alertmanager:9093

    scrape_configs:
      - job_name: 'virtualmin-webmin'
        static_configs:
        - targets: ['localhost:10000']
        metrics_path: /metrics
        scrape_interval: 30s

      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
        - role: pod
        namespaces:
          names:
          - $NAMESPACE

      - job_name: 'kubernetes-services'
        kubernetes_sd_configs:
        - role: service
        namespaces:
          names:
          - $NAMESPACE
EOF

    kubectl apply -f "$config_file"
    kubectl apply -f "$monitoring_file"
    log_success "ConfigMaps avanzados generados y aplicados"
}

# Función para generar Secrets
generate_secrets() {
    log_step "Generando Secrets..."

    local secret_file="$SCRIPT_DIR/k8s-secrets.yaml"
    cat > "$secret_file" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: virtualmin-secrets
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: secrets
type: Opaque
data:
  # Contraseñas seguras generadas automáticamente o desde variables de entorno
  mysql-root-password: "$(echo -n "$MYSQL_ROOT_PASSWORD" | base64)"
  mysql-user-password: "$(echo -n "$MYSQL_USER_PASSWORD" | base64)"
  webmin-admin-password: "$(echo -n "$WEBMIN_ADMIN_PASSWORD" | base64)"
  redis-password: "$(echo -n "$REDIS_PASSWORD" | base64)"
  postgres-password: "$(echo -n "$POSTGRES_PASSWORD" | base64)"
---
apiVersion: v1
kind: Secret
metadata:
  name: virtualmin-tls
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: tls
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi... # Reemplaza con certificado real en base64
  tls.key: LS0tLS1CRUdJTi... # Reemplaza con clave privada real en base64
EOF

    kubectl apply -f "$secret_file"
    log_success "Secrets generados y aplicados"
}

# Función para generar PersistentVolumeClaims avanzados
generate_advanced_pvcs() {
    log_step "Generando PersistentVolumeClaims avanzados..."

    local pvc_file="$SCRIPT_DIR/k8s-pvcs.yaml"
    cat > "$pvc_file" << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: virtualmin-webmin-config
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: webmin-config
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: $STORAGE_CLASS
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: virtualmin-user-data
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: user-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: $STORAGE_CLASS
  resources:
    requests:
      storage: 100Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: virtualmin-mysql-data
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: mysql-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: virtualmin-fast-ssd
  resources:
    requests:
      storage: 50Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: virtualmin-postgres-data
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: postgres-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: virtualmin-fast-ssd
  resources:
    requests:
      storage: 50Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: virtualmin-redis-data
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: redis-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: virtualmin-fast-ssd
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: virtualmin-backups
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: backups
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: virtualmin-backup-storage
  resources:
    requests:
      storage: 500Gi
EOF

    kubectl apply -f "$pvc_file"
    log_success "PVCs avanzados generados y aplicados"
}

# Función para generar Deployment avanzado
generate_advanced_deployment() {
    log_step "Generando Deployment avanzado..."

    local deployment_file="$SCRIPT_DIR/k8s-deployment-advanced.yaml"
    cat > "$deployment_file" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: virtualmin-webmin
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/version: "2.0"
    app.kubernetes.io/component: webmin
    app.kubernetes.io/part-of: virtualmin-system
spec:
  replicas: $HPA_MIN_REPLICAS
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app.kubernetes.io/name: virtualmin
      app.kubernetes.io/component: webmin
  template:
    metadata:
      labels:
        app.kubernetes.io/name: virtualmin
        app.kubernetes.io/component: webmin
        app.kubernetes.io/version: "2.0"
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "10000"
        prometheus.io/path: "/metrics"
    spec:
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
      - name: virtualmin-webmin
        image: virtualmin/virtualmin:latest
        ports:
        - containerPort: 10000
          name: webmin
          protocol: TCP
        - containerPort: 80
          name: http
          protocol: TCP
        - containerPort: 443
          name: https
          protocol: TCP
        env:
        - name: WEBMIN_PORT
          valueFrom:
            configMapKeyRef:
              name: virtualmin-config
              key: WEBMIN_PORT
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: virtualmin-secrets
              key: mysql-root-password
        - name: WEBMIN_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: virtualmin-secrets
              key: webmin-admin-password
        resources:
          requests:
            cpu: $WEBMIN_CPU_REQUEST
            memory: $WEBMIN_MEMORY_REQUEST
          limits:
            cpu: $WEBMIN_CPU_LIMIT
            memory: $WEBMIN_MEMORY_LIMIT
        livenessProbe:
          httpGet:
            path: /
            port: 10000
          initialDelaySeconds: 300
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: 10000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        volumeMounts:
        - name: webmin-config
          mountPath: /etc/webmin
        - name: virtualmin-config
          mountPath: /etc/virtualmin
        - name: user-data
          mountPath: /home
        - name: apache-logs
          mountPath: /var/log/apache2
        - name: webmin-logs
          mountPath: /var/webmin/logs
      volumes:
      - name: webmin-config
        persistentVolumeClaim:
          claimName: virtualmin-webmin-config
      - name: virtualmin-config
        configMap:
          name: virtualmin-config
      - name: user-data
        persistentVolumeClaim:
          claimName: virtualmin-user-data
      - name: apache-logs
        emptyDir: {}
      - name: webmin-logs
        emptyDir: {}
EOF

    kubectl apply -f "$deployment_file"
    log_success "Deployment avanzado generado y aplicado"
}

# Función para generar servicios avanzados
generate_advanced_services() {
    log_step "Generando servicios avanzados..."

    local services_file="$SCRIPT_DIR/k8s-services-advanced.yaml"
    cat > "$services_file" << EOF
apiVersion: v1
kind: Service
metadata:
  name: virtualmin-webmin
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: webmin
    app.kubernetes.io/part-of: virtualmin-system
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
  name: virtualmin-mysql
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: mysql
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: mysql
  ports:
  - name: mysql
    port: 3306
    targetPort: 3306
    protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: virtualmin-postgres
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: postgres
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: postgres
  ports:
  - name: postgres
    port: 5432
    targetPort: 5432
    protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: virtualmin-redis
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: redis
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: redis
  ports:
  - name: redis
    port: 6379
    targetPort: 6379
    protocol: TCP
EOF

    kubectl apply -f "$services_file"
    log_success "Servicios avanzados generados y aplicados"
}

# Función para configurar HorizontalPodAutoscaler
setup_hpa() {
    if [[ "$AUTO_SCALING_ENABLED" != "true" ]]; then
        log_info "Auto-escalado deshabilitado"
        return 0
    fi

    log_step "Configurando HorizontalPodAutoscaler..."

    local hpa_file="$SCRIPT_DIR/k8s-hpa.yaml"
    cat > "$hpa_file" << EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: virtualmin-webmin-hpa
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: virtualmin-webmin
  minReplicas: $HPA_MIN_REPLICAS
  maxReplicas: $HPA_MAX_REPLICAS
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: $HPA_CPU_TARGET
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: $HPA_MEMORY_TARGET
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
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
EOF

    kubectl apply -f "$hpa_file"
    log_success "HPA configurado"
}

# Función para configurar Ingress avanzado
setup_advanced_ingress() {
    log_step "Configurando Ingress avanzado..."

    local ingress_file="$SCRIPT_DIR/k8s-ingress-advanced.yaml"
    cat > "$ingress_file" << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: virtualmin-ingress
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - virtualmin.local
    - "*.virtualmin.local"
    secretName: virtualmin-tls
  rules:
  - host: virtualmin.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: virtualmin-webmin
            port:
              number: 80
      - path: /webmin
        pathType: Prefix
        backend:
          service:
            name: virtualmin-webmin
            port:
              number: 10000
  - host: "*.virtualmin.local"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: virtualmin-webmin
            port:
              number: 80
EOF

    kubectl apply -f "$ingress_file"
    log_success "Ingress avanzado configurado"
}

# Función para configurar Network Policies
setup_network_policies() {
    log_step "Configurando Network Policies..."

    local netpol_file="$SCRIPT_DIR/k8s-network-policies.yaml"
    cat > "$netpol_file" << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: virtualmin-webmin-policy
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: network-policy
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: virtualmin
      app.kubernetes.io/component: webmin
  policyTypes:
  - Ingress
  - Egress
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
    - protocol: TCP
      port: 10000
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
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 443
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: virtualmin-database-policy
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: network-policy
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
EOF

    kubectl apply -f "$netpol_file"
    log_success "Network Policies configuradas"
}

# Función para instalar stack de monitoreo
setup_monitoring_stack() {
    if [[ "$MONITORING_ENABLED" != "true" ]]; then
        log_info "Monitoreo deshabilitado"
        return 0
    fi

    log_step "Instalando stack de monitoreo..."

    # Agregar repositorio de Prometheus
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update

    # Instalar Prometheus Operator
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --set grafana.adminPassword="$GRAFANA_ADMIN_PASSWORD" \
        --set prometheus.service.type=ClusterIP \
        --set grafana.service.type=ClusterIP

    # Instalar métricas de Kubernetes
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

    log_success "Stack de monitoreo instalado"
}

# Función para configurar Service Mesh (Istio)
setup_service_mesh() {
    if [[ "$SERVICE_MESH_ENABLED" != "true" ]]; then
        log_info "Service Mesh deshabilitado"
        return 0
    fi

    log_step "Configurando Service Mesh (Istio)..."

    # Instalar Istio
    curl -L https://istio.io/downloadIstio | sh -
    cd istio-*
    export PATH=$PWD/bin:$PATH

    # Instalar Istio con perfil demo
    istioctl install --set profile=demo -y

    # Etiquetar namespace para inyección automática
    kubectl label namespace $NAMESPACE istio-injection=enabled

    # Crear PeerAuthentication para mTLS
    local peer_auth_file="$SCRIPT_DIR/k8s-peer-authentication.yaml"
    cat > "$peer_auth_file" << EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: $NAMESPACE
spec:
  mtls:
    mode: PERMISSIVE
EOF

    kubectl apply -f "$peer_auth_file"
    log_success "Service Mesh configurado"
}

# Función para configurar backup system
setup_backup_system() {
    if [[ "$BACKUP_ENABLED" != "true" ]]; then
        log_info "Sistema de backup deshabilitado"
        return 0
    fi

    log_step "Configurando sistema de backup..."

    # Instalar Velero para backups
    helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
    helm repo update

    helm upgrade --install velero vmware-tanzu/velero \
        --namespace velero \
        --create-namespace \
        --set configuration.provider=aws \
        --set configuration.backupStorageLocation.bucket=virtualmin-backups \
        --set configuration.backupStorageLocation.config.region=us-east-1 \
        --set configuration.volumeSnapshotLocation.config.region=us-east-1

    # Crear CronJob para backups automáticos
    local backup_job_file="$SCRIPT_DIR/k8s-backup-job.yaml"
    cat > "$backup_job_file" << EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: virtualmin-backup
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: virtualmin
    app.kubernetes.io/component: backup
spec:
  schedule: "0 2 * * *"  # Ejecutar diariamente a las 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: velero/velero:v1.9.5
            command:
            - velero
            - backup
            - create
            - virtualmin-daily-$(date +\%Y\%m\%d)
            - --include-namespaces
            - $NAMESPACE
          restartPolicy: OnFailure
EOF

    kubectl apply -f "$backup_job_file"
    log_success "Sistema de backup configurado"
}

# Función para mostrar estado completo del sistema
show_system_status() {
    log_step "Mostrando estado completo del sistema..."

    echo
    echo "=========================================="
    echo "  ESTADO DEL SISTEMA VIRTUALMIN KUBERNETES"
    echo "=========================================="
    echo

    # Mostrar namespaces
    echo "Namespaces:"
    kubectl get namespaces | grep -E "(NAME|$NAMESPACE|monitoring|istio|velero)"
    echo

    # Mostrar pods
    echo "Pods en $NAMESPACE:"
    kubectl get pods -n "$NAMESPACE" -o wide
    echo

    # Mostrar servicios
    echo "Servicios en $NAMESPACE:"
    kubectl get services -n "$NAMESPACE"
    echo

    # Mostrar PVCs
    echo "PersistentVolumeClaims en $NAMESPACE:"
    kubectl get pvc -n "$NAMESPACE"
    echo

    # Mostrar HPA
    if [[ "$AUTO_SCALING_ENABLED" == "true" ]]; then
        echo "HorizontalPodAutoscalers en $NAMESPACE:"
        kubectl get hpa -n "$NAMESPACE"
        echo
    fi

    # Mostrar Ingress
    echo "Ingress en $NAMESPACE:"
    kubectl get ingress -n "$NAMESPACE"
    echo

    # Mostrar estado de monitoreo
    if [[ "$MONITORING_ENABLED" == "true" ]]; then
        echo "Pods de monitoreo:"
        kubectl get pods -n monitoring 2>/dev/null || echo "Namespace monitoring no encontrado"
        echo
    fi
}

# Función para mostrar instrucciones completas
show_complete_instructions() {
    log_success "Sistema de orquestación Kubernetes configurado exitosamente"
    echo
    log_info "=== SISTEMA COMPLETO DE ORQUESTACIÓN ==="
    echo
    log_info "✅ Cluster Kubernetes avanzado configurado"
    log_info "✅ Storage Classes para diferentes tipos de almacenamiento"
    log_info "✅ ConfigMaps y Secrets seguros"
    log_info "✅ PersistentVolumeClaims para persistencia de datos"
    log_info "✅ Deployment con probes de salud y límites de recursos"
    log_info "✅ Servicios LoadBalancer y ClusterIP"
    log_info "✅ HorizontalPodAutoscaler para auto-escalado"
    log_info "✅ Ingress con SSL y rate limiting"
    log_info "✅ Network Policies para seguridad de red"
    if [[ "$MONITORING_ENABLED" == "true" ]]; then
        log_info "✅ Stack de monitoreo Prometheus + Grafana"
    fi
    if [[ "$SERVICE_MESH_ENABLED" == "true" ]]; then
        log_info "✅ Service Mesh Istio con mTLS"
    fi
    if [[ "$BACKUP_ENABLED" == "true" ]]; then
        log_info "✅ Sistema de backup automático con Velero"
    fi
    echo
    log_info "=== ACCESO AL SISTEMA ==="
    echo
    log_info "Virtualmin Webmin:"
    log_info "  kubectl port-forward -n $NAMESPACE svc/virtualmin-webmin 10000:10000"
    log_info "  Accede en: https://localhost:10000"
    echo
    if [[ "$MONITORING_ENABLED" == "true" ]]; then
        log_info "Grafana (Monitoreo):"
        log_info "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
        log_info "  URL: http://localhost:3000"
        log_info "  Usuario: admin"
        log_info "  Contraseña: $GRAFANA_ADMIN_PASSWORD"
        echo
    fi
    log_info "=== COMANDOS ÚTILES ==="
    echo
    log_info "Ver logs del deployment:"
    echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=webmin -f"
    echo
    log_info "Escalar manualmente:"
    echo "  kubectl scale deployment virtualmin-webmin -n $NAMESPACE --replicas=3"
    echo
    log_info "Ver métricas de auto-escalado:"
    echo "  kubectl get hpa -n $NAMESPACE -w"
    echo
    log_info "Backup manual:"
    echo "  velero backup create manual-backup --include-namespaces $NAMESPACE"
    echo
    log_info "=== PRÓXIMOS PASOS ==="
    echo
    log_info "1. Configurar certificados SSL reales"
    log_info "2. Ajustar Storage Classes según tu proveedor de nube"
    log_info "3. Configurar políticas de seguridad adicionales"
    log_info "4. Implementar CI/CD para despliegues automatizados"
    log_info "5. Configurar alertas y notificaciones"
}

# Función principal
main() {
    local generate_configs=false
    local apply_configs=false
    local setup_monitoring=false
    local setup_mesh=false
    local setup_backup=false
    local show_status=false
    local cleanup=false

    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -g|--generate) generate_configs=true ;;
            -a|--apply) apply_configs=true ;;
            -m|--monitoring) setup_monitoring=true ;;
            -s|--service-mesh) setup_mesh=true ;;
            -b|--backup) setup_backup=true ;;
            --status) show_status=true ;;
            -c|--cleanup) cleanup=true ;;
            -h|--help) show_help; exit 0 ;;
            *) log_error "Opción desconocida: $1"; show_help; exit 1 ;;
        esac
        shift
    done

    echo
    echo "======================================================"
    echo "  ORQUESTACIÓN COMPLETA KUBERNETES"
    echo "  Virtualmin & Webmin - Sistema de Producción"
    echo "======================================================"
    echo

    # Verificar dependencias
    if ! check_advanced_dependencies; then
        exit 1
    fi

    # Crear namespace
    create_advanced_namespace

    # Configurar Storage Classes
    setup_storage_classes

    # Generar configuraciones si se solicita
    if [[ "$generate_configs" == "true" ]]; then
        generate_advanced_configmaps
        generate_secrets
        generate_advanced_pvcs
        generate_advanced_deployment
        generate_advanced_services
        setup_hpa
        setup_advanced_ingress
        setup_network_policies
    fi

    # Aplicar configuraciones si se solicita
    if [[ "$apply_configs" == "true" ]]; then
        generate_advanced_configmaps
        generate_secrets
        generate_advanced_pvcs
        generate_advanced_deployment
        generate_advanced_services
        setup_hpa
        setup_advanced_ingress
        setup_network_policies
    fi

    # Configurar monitoreo si se solicita
    if [[ "$setup_monitoring" == "true" ]]; then
        setup_monitoring_stack
    fi

    # Configurar service mesh si se solicita
    if [[ "$setup_mesh" == "true" ]]; then
        setup_service_mesh
    fi

    # Configurar backup si se solicita
    if [[ "$setup_backup" == "true" ]]; then
        setup_backup_system
    fi

    # Mostrar estado si se solicita
    if [[ "$show_status" == "true" ]]; then
        show_system_status
    fi

    # Limpiar si se solicita
    if [[ "$cleanup" == "true" ]]; then
        cleanup_system
    fi

    # Mostrar instrucciones si se generaron configuraciones
    if [[ "$generate_configs" == "true" || "$apply_configs" == "true" ]]; then
        show_complete_instructions
    fi

    log_success "Operación completada exitosamente"
}

# Función de ayuda
show_help() {
    cat << EOF
Sistema Completo de Orquestación Kubernetes - Virtualmin & Webmin
Versión: 2.0.0

USO:
    $0 [opciones]

OPCIONES:
    -g, --generate        Generar todos los archivos de configuración YAML
    -a, --apply          Aplicar todas las configuraciones a Kubernetes
    -m, --monitoring     Instalar stack completo de monitoreo
    -s, --service-mesh   Configurar Service Mesh (Istio)
    -b, --backup         Configurar sistema de backup automático
    --status             Mostrar estado completo del sistema
    -c, --cleanup        Limpiar todas las configuraciones
    -h, --help          Mostrar esta ayuda

VARIABLES DE ENTORNO:
    K8S_NAMESPACE           Namespace (default: virtualmin-system)
    K8S_STORAGE_CLASS       Storage Class principal
    K8S_MONITORING          Habilitar monitoreo (true/false)
    K8S_SERVICE_MESH        Habilitar Service Mesh (true/false)
    K8S_AUTO_SCALING        Habilitar auto-escalado (true/false)
    K8S_BACKUP             Habilitar backup automático (true/false)
    MYSQL_ROOT_PASSWORD    Contraseña root MySQL (auto-generada si no se especifica)
    MYSQL_USER_PASSWORD    Contraseña usuario MySQL (auto-generada si no se especifica)
    WEBMIN_ADMIN_PASSWORD  Contraseña admin Webmin (auto-generada si no se especifica)
    REDIS_PASSWORD         Contraseña Redis (auto-generada si no se especifica)
    POSTGRES_PASSWORD      Contraseña PostgreSQL (auto-generada si no se especifica)
    GRAFANA_ADMIN_PASSWORD Contraseña admin Grafana (auto-generada si no se especifica)

RECURSOS CONFIGURADOS:
    • Storage Classes para diferentes tipos de almacenamiento
    • ConfigMaps y Secrets seguros
    • PersistentVolumeClaims para persistencia
    • Deployments con health checks y resource limits
    • Services LoadBalancer y ClusterIP
    • HorizontalPodAutoscaler para auto-escalado
    • Ingress con SSL y rate limiting
    • Network Policies para seguridad
    • Prometheus + Grafana para monitoreo
    • Istio Service Mesh con mTLS
    • Velero para backups automáticos

EJEMPLOS:
    $0 -g                 # Generar todas las configuraciones
    $0 -a                 # Aplicar todas las configuraciones
    $0 -g -a -m -s -b     # Configuración completa del sistema
    $0 --status           # Ver estado del sistema

NOTAS:
    - Requiere kubectl, helm y kustomize instalados
    - Configura las variables de entorno según tus necesidades
    - Los archivos YAML se generan en el directorio actual
    - Este sistema está diseñado para producción
EOF
}

# Función de limpieza
cleanup_system() {
    log_step "Limpiando sistema completo..."

    # Eliminar recursos en orden inverso
    local resources=(
        "ingress/virtualmin-ingress"
        "hpa/virtualmin-webmin-hpa"
        "service/virtualmin-webmin"
        "service/virtualmin-mysql"
        "service/virtualmin-postgres"
        "service/virtualmin-redis"
        "deployment/virtualmin-webmin"
        "pvc/virtualmin-webmin-config"
        "pvc/virtualmin-user-data"
        "pvc/virtualmin-mysql-data"
        "pvc/virtualmin-postgres-data"
        "pvc/virtualmin-redis-data"
        "pvc/virtualmin-backups"
        "configmap/virtualmin-config"
        "configmap/virtualmin-monitoring-config"
        "secret/virtualmin-secrets"
        "secret/virtualmin-tls"
        "networkpolicy/virtualmin-webmin-policy"
        "networkpolicy/virtualmin-database-policy"
        "cronjob/virtualmin-backup"
    )

    for resource in "${resources[@]}"; do
        if kubectl get "$resource" -n "$NAMESPACE" >/dev/null 2>&1; then
            kubectl delete "$resource" -n "$NAMESPACE" --ignore-not-found=true
            log_info "Eliminado: $resource"
        fi
    done

    # Eliminar namespace si está vacío
    local resources_count
    resources_count=$(kubectl get all -n "$NAMESPACE" 2>/dev/null | wc -l)

    if [[ $resources_count -le 1 ]]; then
        kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
        log_info "Namespace eliminado: $NAMESPACE"
    fi

    # Limpiar Helm releases
    helm uninstall prometheus -n monitoring --ignore-not-found
    helm uninstall velero -n velero --ignore-not-found

    # Limpiar Istio si está instalado
    if command_exists istioctl; then
        istioctl uninstall --purge -y
    fi

    log_success "Limpieza completada"
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
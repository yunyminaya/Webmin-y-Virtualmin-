#!/bin/bash

# Script de Preparación Kubernetes
# Configuración básica para desplegar Virtualmin en Kubernetes
# Versión: 1.0.0 - Proof of Concept

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

# Configuración de Kubernetes
NAMESPACE="${K8S_NAMESPACE:-virtualmin}"
DEPLOYMENT_NAME="${K8S_DEPLOYMENT_NAME:-virtualmin-webmin}"
SERVICE_NAME="${K8S_SERVICE_NAME:-virtualmin-service}"
PVC_NAME="${K8S_PVC_NAME:-virtualmin-storage}"

# Función para verificar kubectl
check_kubectl() {
    log_step "Verificando kubectl..."

    if ! command_exists kubectl; then
        log_error "kubectl no está instalado"
        log_info "Instala kubectl: https://kubernetes.io/docs/tasks/tools/"
        return 1
    fi

    # Verificar conexión al cluster
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "No se puede conectar al cluster de Kubernetes"
        log_info "Verifica tu configuración de kubectl"
        return 1
    fi

    log_success "kubectl configurado correctamente"
    return 0
}

# Función para crear namespace
create_namespace() {
    log_step "Creando namespace de Kubernetes..."

    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        log_info "Namespace '$NAMESPACE' ya existe"
    else
        kubectl create namespace "$NAMESPACE"
        log_success "Namespace '$NAMESPACE' creado"
    fi
}

# Función para generar PersistentVolumeClaim
generate_pvc() {
    local pvc_file="$SCRIPT_DIR/k8s-pvc.yaml"
    log_step "Generando PersistentVolumeClaim..."

    cat > "$pvc_file" << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $PVC_NAME
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: standard  # Cambia según tu storage class
EOF

    log_success "PVC generado: $pvc_file"
}

# Función para generar ConfigMap
generate_configmap() {
    local config_file="$SCRIPT_DIR/k8s-configmap.yaml"
    log_step "Generando ConfigMap..."

    cat > "$config_file" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: virtualmin-config
  namespace: $NAMESPACE
data:
  WEBMIN_PORT: "10000"
  VIRTUALMIN_DOMAIN: "tu-dominio.com"
  APACHE_PORT: "80"
  MYSQL_PORT: "3306"
EOF

    log_success "ConfigMap generado: $config_file"
}

# Función para generar Deployment
generate_deployment() {
    local deployment_file="$SCRIPT_DIR/k8s-deployment.yaml"
    log_step "Generando Deployment..."

    cat > "$deployment_file" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOYMENT_NAME
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: virtualmin
  template:
    metadata:
      labels:
        app: virtualmin
    spec:
      containers:
      - name: virtualmin
        image: ubuntu:22.04
        ports:
        - containerPort: 10000
          name: webmin
        - containerPort: 80
          name: http
        - containerPort: 443
          name: https
        env:
        - name: WEBMIN_PORT
          valueFrom:
            configMapKeyRef:
              name: virtualmin-config
              key: WEBMIN_PORT
        volumeMounts:
        - name: virtualmin-storage
          mountPath: /var/webmin
        - name: virtualmin-storage
          mountPath: /etc/webmin
        - name: virtualmin-storage
          mountPath: /etc/virtualmin
        - name: virtualmin-storage
          mountPath: /home
      volumes:
      - name: virtualmin-storage
        persistentVolumeClaim:
          claimName: $PVC_NAME
EOF

    log_success "Deployment generado: $deployment_file"
}

# Función para generar Service
generate_service() {
    local service_file="$SCRIPT_DIR/k8s-service.yaml"
    log_step "Generando Service..."

    cat > "$service_file" << EOF
apiVersion: v1
kind: Service
metadata:
  name: $SERVICE_NAME
  namespace: $NAMESPACE
spec:
  selector:
    app: virtualmin
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
  type: LoadBalancer
EOF

    log_success "Service generado: $service_file"
}

# Función para generar Ingress (opcional)
generate_ingress() {
    local ingress_file="$SCRIPT_DIR/k8s-ingress.yaml"
    log_step "Generando Ingress..."

    cat > "$ingress_file" << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: virtualmin-ingress
  namespace: $NAMESPACE
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - tu-dominio.com
    secretName: virtualmin-tls
  rules:
  - host: tu-dominio.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $SERVICE_NAME
            port:
              number: 80
EOF

    log_success "Ingress generado: $ingress_file"
}

# Función para aplicar configuración a Kubernetes
apply_kubernetes_config() {
    log_step "Aplicando configuración a Kubernetes..."

    local files=(
        "$SCRIPT_DIR/k8s-pvc.yaml"
        "$SCRIPT_DIR/k8s-configmap.yaml"
        "$SCRIPT_DIR/k8s-deployment.yaml"
        "$SCRIPT_DIR/k8s-service.yaml"
    )

    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            log_info "Aplicando $file..."
            kubectl apply -f "$file"
        else
            log_warning "Archivo no encontrado: $file"
        fi
    done

    log_success "Configuración aplicada a Kubernetes"
}

# Función para mostrar estado del despliegue
show_deployment_status() {
    log_step "Mostrando estado del despliegue..."

    echo
    echo "Estado de los recursos de Kubernetes:"
    echo

    # Mostrar pods
    echo "Pods:"
    kubectl get pods -n "$NAMESPACE" -o wide
    echo

    # Mostrar servicios
    echo "Servicios:"
    kubectl get services -n "$NAMESPACE"
    echo

    # Mostrar PVCs
    echo "PersistentVolumeClaims:"
    kubectl get pvc -n "$NAMESPACE"
    echo

    # Mostrar logs del pod (si existe)
    local pod_name
    pod_name=$(kubectl get pods -n "$NAMESPACE" -l app=virtualmin -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -n "$pod_name" ]]; then
        echo "Logs del pod (últimas 20 líneas):"
        kubectl logs -n "$NAMESPACE" "$pod_name" --tail=20
        echo
    fi
}

# Función para limpiar configuración de Kubernetes
cleanup_kubernetes() {
    log_step "Limpiando configuración de Kubernetes..."

    local resources=(
        "deployment/$DEPLOYMENT_NAME"
        "service/$SERVICE_NAME"
        "configmap/virtualmin-config"
        "pvc/$PVC_NAME"
    )

    for resource in "${resources[@]}"; do
        if kubectl get "$resource" -n "$NAMESPACE" >/dev/null 2>&1; then
            kubectl delete "$resource" -n "$NAMESPACE"
            log_info "Eliminado: $resource"
        fi
    done

    # Eliminar namespace si está vacío
    local resources_count
    resources_count=$(kubectl get all -n "$NAMESPACE" 2>/dev/null | wc -l)

    if [[ $resources_count -le 1 ]]; then
        kubectl delete namespace "$NAMESPACE" 2>/dev/null || true
        log_info "Namespace eliminado: $NAMESPACE"
    fi

    log_success "Limpieza completada"
}

# Función para mostrar instrucciones de uso
show_instructions() {
    log_success "Configuración de Kubernetes generada exitosamente"
    echo
    log_info "=== INSTRUCCIONES DE DESPLIEGUE ==="
    echo
    log_info "1. Revisa y ajusta los archivos YAML generados:"
    echo "   - k8s-deployment.yaml (configuración del contenedor)"
    echo "   - k8s-service.yaml (exposición de servicios)"
    echo "   - k8s-pvc.yaml (almacenamiento persistente)"
    echo "   - k8s-configmap.yaml (variables de configuración)"
    echo
    log_info "2. Aplica la configuración:"
    echo "   kubectl apply -f k8s-pvc.yaml"
    echo "   kubectl apply -f k8s-configmap.yaml"
    echo "   kubectl apply -f k8s-deployment.yaml"
    echo "   kubectl apply -f k8s-service.yaml"
    echo
    log_info "3. Verifica el estado:"
    echo "   kubectl get all -n $NAMESPACE"
    echo
    log_info "4. Accede a Virtualmin:"
    echo "   kubectl get services -n $NAMESPACE"
    echo "   # Busca la IP externa del LoadBalancer"
    echo
    log_info "=== NOTAS IMPORTANTES ==="
    echo
    log_warning "• Este es un despliegue básico para desarrollo/pruebas"
    log_warning "• Para producción necesitarás:"
    log_warning "  - StorageClass adecuado"
    log_warning "  - Secrets para SSL"
    log_warning "  - Resource limits y requests"
    log_warning "  - Network policies"
    log_warning "  - Backup strategies"
    echo
    log_info "=== PRÓXIMOS PASOS ==="
    echo
    log_info "1. Instalar Virtualmin dentro del contenedor"
    log_info "2. Configurar persistencia de datos"
    log_info "3. Implementar health checks"
    log_info "4. Configurar Ingress con SSL"
    log_info "5. Implementar auto-scaling"
}

# Función para mostrar ayuda
show_help() {
    cat << EOF
Script de Preparación Kubernetes - Virtualmin
Versión: 1.0.0

USO:
    $0 [opciones]

OPCIONES:
    -g, --generate     Generar archivos YAML
    -a, --apply        Aplicar configuración a Kubernetes
    -s, --status       Mostrar estado del despliegue
    -c, --cleanup      Limpiar configuración de Kubernetes
    -i, --ingress      Generar Ingress (opcional)
    -h, --help         Mostrar esta ayuda

VARIABLES DE ENTORNO:
    K8S_NAMESPACE          Namespace (default: virtualmin)
    K8S_DEPLOYMENT_NAME    Nombre del deployment
    K8S_SERVICE_NAME       Nombre del service
    K8S_PVC_NAME          Nombre del PVC

EJEMPLOS:
    $0 -g                 # Generar archivos YAML
    $0 -g -a              # Generar y aplicar
    $0 -s                 # Ver estado
    $0 -c                 # Limpiar configuración

ARCHIVOS GENERADOS:
    k8s-deployment.yaml   # Deployment de Kubernetes
    k8s-service.yaml      # Service de Kubernetes
    k8s-pvc.yaml         # PersistentVolumeClaim
    k8s-configmap.yaml   # ConfigMap
    k8s-ingress.yaml     # Ingress (opcional)

NOTAS:
    - Requiere kubectl configurado y conectado al cluster
    - Los archivos YAML se generan en el directorio actual
    - Ajusta los recursos según tus necesidades
    - Este script es para POC - no usar en producción sin modificaciones
EOF
}

# Función principal
main() {
    local generate_files=false
    local apply_config=false
    local show_status=false
    local cleanup_config=false
    local generate_ingress=false

    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -g|--generate) generate_files=true ;;
            -a|--apply) apply_config=true ;;
            -s|--status) show_status=true ;;
            -c|--cleanup) cleanup_config=true ;;
            -i|--ingress) generate_ingress=true ;;
            -h|--help) show_help; exit 0 ;;
            *) log_error "Opción desconocida: $1"; show_help; exit 1 ;;
        esac
        shift
    done

    echo
    echo "=========================================="
    echo "  PREPARACIÓN KUBERNETES"
    echo "  Virtualmin & Webmin"
    echo "=========================================="
    echo

    # Verificar kubectl
    if ! check_kubectl; then
        exit 1
    fi

    # Crear namespace
    create_namespace

    # Generar archivos si se solicita
    if [[ "$generate_files" == "true" ]]; then
        generate_pvc
        generate_configmap
        generate_deployment
        generate_service

        if [[ "$generate_ingress" == "true" ]]; then
            generate_ingress
        fi
    fi

    # Aplicar configuración si se solicita
    if [[ "$apply_config" == "true" ]]; then
        apply_kubernetes_config
    fi

    # Mostrar estado si se solicita
    if [[ "$show_status" == "true" ]]; then
        show_deployment_status
    fi

    # Limpiar configuración si se solicita
    if [[ "$cleanup_config" == "true" ]]; then
        cleanup_kubernetes
    fi

    # Mostrar instrucciones si se generaron archivos
    if [[ "$generate_files" == "true" ]]; then
        show_instructions
    fi

    log_success "Operación completada"
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

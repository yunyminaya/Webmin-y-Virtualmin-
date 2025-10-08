#!/bin/bash
# Script de despliegue automatizado para clúster Enterprise Webmin/Virtualmin
# Combina Terraform + Ansible para despliegue completo

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
ANSIBLE_DIR="${SCRIPT_DIR}/ansible"
LOG_FILE="${SCRIPT_DIR}/deploy-$(date +%Y%m%d-%H%M%S).log"

# Variables de entorno requeridas
REQUIRED_VARS=(
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
    "AWS_DEFAULT_REGION"
    "TF_VAR_cluster_name"
    "TF_VAR_admin_email"
    "ANSIBLE_VAULT_PASSWORD"
)

# Función de logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOG_FILE" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}" | tee -a "$LOG_FILE"
}

# Verificar prerrequisitos
check_prerequisites() {
    log "Verificando prerrequisitos..."

    # Verificar herramientas instaladas
    command -v terraform >/dev/null 2>&1 || error "Terraform no está instalado"
    command -v ansible >/dev/null 2>&1 || error "Ansible no está instalado"
    command -v aws >/dev/null 2>&1 || error "AWS CLI no está instalado"

    # Verificar variables de entorno
    for var in "${REQUIRED_VARS[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            error "Variable de entorno $var no está definida"
        fi
    done

    # Verificar archivos de configuración
    [[ -f "${TERRAFORM_DIR}/main.tf" ]] || error "Archivo main.tf no encontrado"
    [[ -f "${ANSIBLE_DIR}/cluster.yml" ]] || error "Playbook cluster.yml no encontrado"
    [[ -f "${ANSIBLE_DIR}/inventory.ini" ]] || error "Inventario inventory.ini no encontrado"

    # Verificar SSH key
    [[ -f ~/.ssh/cluster-key.pem ]] || error "SSH key cluster-key.pem no encontrada"

    log "Prerrequisitos verificados correctamente"
}

# Función para inicializar Terraform
terraform_init() {
    log "Inicializando Terraform..."
    cd "$TERRAFORM_DIR"

    if ! terraform init -upgrade; then
        error "Error inicializando Terraform"
    fi

    log "Terraform inicializado correctamente"
}

# Función para planificar cambios
terraform_plan() {
    log "Planificando cambios en infraestructura..."
    cd "$TERRAFORM_DIR"

    if ! terraform plan -out=tfplan; then
        error "Error en terraform plan"
    fi

    log "Plan de Terraform generado correctamente"
}

# Función para aplicar cambios
terraform_apply() {
    log "Aplicando cambios en infraestructura..."
    cd "$TERRAFORM_DIR"

    if ! terraform apply tfplan; then
        error "Error aplicando cambios con Terraform"
    fi

    log "Infraestructura desplegada correctamente"
}

# Función para generar inventario dinámico
generate_inventory() {
    log "Generando inventario dinámico de Ansible..."
    cd "$TERRAFORM_DIR"

    # Obtener outputs de Terraform
    LOAD_BALANCER_IPS=$(terraform output -json load_balancer_ips | jq -r '.[]')
    WEB_NODE_IPS=$(terraform output -json web_node_ips | jq -r '.[]')
    API_NODE_IPS=$(terraform output -json api_node_ips | jq -r '.[]')
    DATABASE_NODE_IPS=$(terraform output -json database_node_ips | jq -r '.[]')
    STORAGE_NODE_IPS=$(terraform output -json storage_node_ips | jq -r '.[]')
    MONITORING_NODE_IPS=$(terraform output -json monitoring_node_ips | jq -r '.[]')
    BACKUP_NODE_IPS=$(terraform output -json backup_node_ips | jq -r '.[]')

    # Generar inventario dinámico
    cat > "${ANSIBLE_DIR}/inventory.ini" << EOF
# Inventario generado automáticamente - $(date)

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/cluster-key.pem
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

[load_balancers]
${LOAD_BALANCER_IPS}

[web_nodes]
${WEB_NODE_IPS}

[api_nodes]
${API_NODE_IPS}

[database_nodes]
${DATABASE_NODE_IPS}

[storage_nodes]
${STORAGE_NODE_IPS}

[monitoring_nodes]
${MONITORING_NODE_IPS}

[backup_nodes]
${BACKUP_NODE_IPS}

# Variables específicas por grupo
[load_balancers:vars]
haproxy_role=primary
keepalived_role=MASTER
keepalived_priority=100

[web_nodes:vars]
webmin_install=true
virtualmin_install=true

[api_nodes:vars]
webmin_api=true
virtualmin_api=true

[database_nodes:vars]
mariadb_galera=true
galera_cluster_name=webmin_cluster

[storage_nodes:vars]
glusterfs_volume_name=gv0

[monitoring_nodes:vars]
prometheus_retention=30d
grafana_admin_user=admin

[backup_nodes:vars]
backup_retention_days=30
EOF

    log "Inventario dinámico generado correctamente"
}

# Función para ejecutar Ansible
run_ansible() {
    log "Ejecutando configuración con Ansible..."
    cd "$ANSIBLE_DIR"

    # Ejecutar playbook principal
    if ! ansible-playbook -i inventory.ini cluster.yml; then
        error "Error ejecutando Ansible playbook"
    fi

    log "Configuración con Ansible completada correctamente"
}

# Función para verificar despliegue
verify_deployment() {
    log "Verificando despliegue del clúster..."

    cd "$ANSIBLE_DIR"

    # Verificar conectividad
    if ! ansible all -i inventory.ini -m ping; then
        error "Error de conectividad con nodos del clúster"
    fi

    # Verificar servicios críticos
    ansible all -i inventory.ini -m service -a "name=haproxy state=started" --check || warning "HAProxy no está ejecutándose en algunos nodos"
    ansible monitoring_nodes -i inventory.ini -m service -a "name=prometheus state=started" --check || warning "Prometheus no está ejecutándose"
    ansible monitoring_nodes -i inventory.ini -m service -a "name=grafana-server state=started" --check || warning "Grafana no está ejecutándose"

    log "Verificación del despliegue completada"
}

# Función para limpiar recursos en caso de error
cleanup() {
    warning "Error detectado. Ejecutando limpieza..."

    cd "$TERRAFORM_DIR"
    terraform destroy -auto-approve || warning "Error durante la limpieza automática"

    error "Despliegue fallido. Recursos limpiados."
}

# Función principal
main() {
    log "Iniciando despliegue del clúster Enterprise Webmin/Virtualmin"
    log "Log file: $LOG_FILE"

    # Configurar trap para cleanup en caso de error
    trap cleanup ERR

    # Ejecutar fases del despliegue
    check_prerequisites
    terraform_init
    terraform_plan

    # Confirmar aplicación
    read -p "¿Aplicar cambios en infraestructura? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Despliegue cancelado por el usuario"
        exit 0
    fi

    terraform_apply
    generate_inventory
    run_ansible
    verify_deployment

    # Ejecutar verificación completa
    log "Ejecutando verificación post-despliegue..."
    if ! ./verify-deployment.sh; then
        warning "La verificación post-despliegue encontró algunos problemas"
        warning "Revisa los logs y reportes generados para más detalles"
    fi

    log "🎉 Despliegue del clúster completado exitosamente!"
    log "Accede a la consola de monitoreo en: $(terraform output -raw monitoring_url)"
    log "Dashboard Webmin/Virtualmin: $(terraform output -raw webmin_url)"
    log ""
    log "📋 Próximos pasos:"
    log "1. Revisa el reporte de verificación generado"
    log "2. Configura alertas adicionales en Grafana si es necesario"
    log "3. Ejecuta pruebas de carga para validar rendimiento"
    log "4. Documenta cualquier configuración específica del entorno"
}

# Ejecutar función principal
main "$@"
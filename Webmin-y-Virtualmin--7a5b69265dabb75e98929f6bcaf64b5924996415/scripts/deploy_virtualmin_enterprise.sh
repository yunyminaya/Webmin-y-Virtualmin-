#!/bin/bash

# Script Maestro de Orquestación para Virtualmin Enterprise
# Integra Terraform, Ansible, pruebas de estrés y configuración de seguridad

set -e

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuración global
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${PROJECT_ROOT}/logs"
CONFIG_DIR="${PROJECT_ROOT}/configs"
REPORTS_DIR="${PROJECT_ROOT}/reports"

# Crear directorios necesarios
mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$REPORTS_DIR"

# Archivo de log
LOG_FILE="${LOG_DIR}/deploy_virtualmin_enterprise_$(date +%Y%m%d_%H%M%S).log"

# Funciones de logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓ $1${NC}" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗ $1${NC}" | tee -a "$LOG_FILE"
}

header() {
    echo -e "${PURPLE}================================${NC}" | tee -a "$LOG_FILE"
    echo -e "${PURPLE}  $1${NC}" | tee -a "$LOG_FILE"
    echo -e "${PURPLE}================================${NC}" | tee -a "$LOG_FILE"
}

# Función para mostrar banner
show_banner() {
    header "Virtualmin Enterprise Orchestration System"
    echo -e "${CYAN}Integrando Terraform, Ansible, Pruebas de Estrés y Seguridad${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

# Función para verificar dependencias
check_dependencies() {
    log "Verificando dependencias..."
    
    # Verificar herramientas necesarias
    local tools=("terraform" "ansible" "aws" "jq" "curl")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        error "Las siguientes herramientas no están instaladas: ${missing_tools[*]}"
        error "Por favor, instale las herramientas necesarias y vuelva a ejecutar el script."
        exit 1
    fi
    
    # Verificar credenciales de AWS
    if ! aws sts get-caller-identity &> /dev/null; then
        error "No se pudieron verificar las credenciales de AWS."
        error "Por favor, configure sus credenciales de AWS y vuelva a ejecutar el script."
        exit 1
    fi
    
    success "Dependencias verificadas"
}

# Función para cargar configuración
load_config() {
    log "Cargando configuración..."
    
    # Configuración predeterminada
    CLUSTER_NAME="${CLUSTER_NAME:-virtualmin-enterprise}"
    ENVIRONMENT="${ENVIRONMENT:-production}"
    AWS_REGION="${AWS_REGION:-us-east-1}"
    DOMAIN_NAME="${DOMAIN_NAME:-virtualmin-enterprise.com}"
    
    # Cargar variables de entorno si existe el archivo
    if [ -f "${CONFIG_DIR}/.env" ]; then
        source "${CONFIG_DIR}/.env"
        log "Variables de entorno cargadas desde ${CONFIG_DIR}/.env"
    fi
    
    # Crear archivo de configuración si no existe
    if [ ! -f "${CONFIG_DIR}/config.yml" ]; then
        cat > "${CONFIG_DIR}/config.yml" << EOF
# Configuración de Virtualmin Enterprise
cluster_name: $CLUSTER_NAME
environment: $ENVIRONMENT
aws_region: $AWS_REGION
domain_name: $DOMAIN_NAME

# Configuración de infraestructura
instance_types:
  web: t3.medium
  api: t3.medium
  database: db.t3.medium
  storage: t3.large
  monitoring: t3.small

# Configuración de autoescalado
auto_scaling:
  web:
    min_size: 2
    max_size: 10
    desired_capacity: 2
    cpu_threshold: 70
    memory_threshold: 80
  api:
    min_size: 2
    max_size: 10
    desired_capacity: 2
    cpu_threshold: 70
    memory_threshold: 80

# Configuración de seguridad
security:
  waf: true
  ids_ips: true
  mfa: true

# Configuración de pruebas de estrés
stress_testing:
  enabled: true
  tool: "jmeter"  # jmeter o locust
  users: 100
  duration: 300  # segundos
EOF
        log "Archivo de configuración creado en ${CONFIG_DIR}/config.yml"
    fi
    
    # Leer configuración desde YAML
    eval $(python3 -c "
import yaml
with open('${CONFIG_DIR}/config.yml', 'r') as f:
    config = yaml.safe_load(f)
for key, value in config.items():
    if isinstance(value, dict):
        for sub_key, sub_value in value.items():
            print(f'{key.upper()}_{sub_key.upper()}={sub_value}')
    else:
        print(f'{key.upper()}={value}')
")
EOF
)
    
    success "Configuración cargada"
}

# Función para validar configuración
validate_config() {
    log "Validando configuración..."
    
    # Validar nombre del clúster
    if [[ ! "$CLUSTER_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
        error "El nombre del clúster solo puede contener letras, números y guiones."
        exit 1
    fi
    
    # Validar dominio
    if [[ ! "$DOMAIN_NAME" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        error "El formato del dominio no es válido."
        exit 1
    fi
    
    # Validar región de AWS
    local valid_regions=("us-east-1" "us-west-1" "us-west-2" "eu-west-1" "eu-central-1" "ap-southeast-1" "ap-southeast-2")
    if [[ ! " ${valid_regions[@]} " =~ " ${AWS_REGION} " ]]; then
        warning "La región de AWS $AWS_REGION puede no ser compatible. Usando us-east-1 como alternativa."
        AWS_REGION="us-east-1"
    fi
    
    # Validar herramientas de pruebas de estrés
    if [[ "$STRESS_TESTING_TOOL" != "jmeter" && "$STRESS_TESTING_TOOL" != "locust" ]]; then
        warning "Herramienta de pruebas de estrés no válida. Usando JMeter como alternativa."
        STRESS_TESTING_TOOL="jmeter"
    fi
    
    success "Configuración validada"
}

# Función para ejecutar Terraform
run_terraform() {
    log "Ejecutando Terraform..."
    
    local tf_dir="${PROJECT_ROOT}/cluster_infrastructure/terraform"
    
    if [ ! -d "$tf_dir" ]; then
        error "Directorio de Terraform no encontrado: $tf_dir"
        exit 1
    fi
    
    cd "$tf_dir"
    
    # Inicializar Terraform
    log "Inicializando Terraform..."
    terraform init | tee -a "$LOG_FILE"
    
    # Validar configuración
    log "Validando configuración de Terraform..."
    terraform validate | tee -a "$LOG_FILE"
    
    # Planificar despliegue
    log "Planificando despliegue de infraestructura..."
    terraform plan -var="cluster_name=$CLUSTER_NAME" -var="environment=$ENVIRONMENT" -var="aws_region=$AWS_REGION" -var="domain_name=$DOMAIN_NAME" | tee -a "$LOG_FILE"
    
    # Aplicar configuración
    log "Aplicando configuración de infraestructura..."
    terraform apply -var="cluster_name=$CLUSTER_NAME" -var="environment=$ENVIRONMENT" -var="aws_region=$AWS_REGION" -var="domain_name=$DOMAIN_NAME" -auto-approve | tee -a "$LOG_FILE"
    
    # Guardar outputs
    log "Guardando outputs de Terraform..."
    terraform output -json > "${CONFIG_DIR}/terraform_outputs.json"
    
    cd "$PROJECT_ROOT"
    
    success "Infraestructura desplegada con Terraform"
}

# Función para ejecutar Ansible
run_ansible() {
    log "Ejecutando Ansible..."
    
    local ansible_dir="${PROJECT_ROOT}/cluster_infrastructure/ansible"
    
    if [ ! -d "$ansible_dir" ]; then
        error "Directorio de Ansible no encontrado: $ansible_dir"
        exit 1
    fi
    
    cd "$ansible_dir"
    
    # Instalar colecciones de Ansible
    log "Instalando colecciones de Ansible..."
    ansible-galaxy collection install -r requirements.yml | tee -a "$LOG_FILE"
    
    # Generar inventario dinámico
    log "Generando inventario dinámico..."
    python3 scripts/generate_inventory.py --terraform-outputs "${CONFIG_DIR}/terraform_outputs.json" --output inventory/hosts.ini | tee -a "$LOG_FILE"
    
    # Ejecutar playbook de despliegue
    log "Ejecutando playbook de despliegue..."
    ansible-playbook -i inventory/hosts.ini playbooks/deploy.yml --extra-vars "cluster_name=$CLUSTER_NAME environment=$ENVIRONMENT domain_name=$DOMAIN_NAME" | tee -a "$LOG_FILE"
    
    cd "$PROJECT_ROOT"
    
    success "Aplicaciones desplegadas con Ansible"
}

# Función para configurar seguridad avanzada
setup_security() {
    log "Configurando seguridad avanzada..."
    
    # Ejecutar script de configuración de seguridad
    if [ "$SECURITY_WAF" = "true" ] || [ "$SECURITY_IDS_IPS" = "true" ] || [ "$SECURITY_MFA" = "true" ]; then
        log "Ejecutando script de configuración de seguridad..."
        "${SCRIPT_DIR}/setup_advanced_security.sh" | tee -a "$LOG_FILE"
        success "Configuración de seguridad avanzada completada"
    else
        warning "Configuración de seguridad avanzada deshabilitada"
    fi
}

# Función para ejecutar pruebas de estrés
run_stress_tests() {
    log "Ejecutando pruebas de estrés..."
    
    if [ "$STRESS_TESTING_ENABLED" != "true" ]; then
        warning "Pruebas de estrés deshabilitadas"
        return
    fi
    
    # Ejecutar script de configuración de pruebas de estrés
    log "Configurando herramientas de pruebas de estrés..."
    "${SCRIPT_DIR}/setup_stress_testing.sh" | tee -a "$LOG_FILE"
    
    # Obtener URL de destino
    local target_url="https://www.${DOMAIN_NAME}"
    
    # Ejecutar pruebas según la herramienta configurada
    if [ "$STRESS_TESTING_TOOL" = "jmeter" ]; then
        log "Ejecutando pruebas de estrés con JMeter..."
        "${PROJECT_ROOT}/opt/virtualmin/stress-testing/scripts/run_jmeter_test.sh" api "$STRESS_TESTING_USERS" 10 "$STRESS_TESTING_DURATION" "$target_url" | tee -a "$LOG_FILE"
    elif [ "$STRESS_TESTING_TOOL" = "locust" ]; then
        log "Ejecutando pruebas de estrés con Locust..."
        "${PROJECT_ROOT}/opt/virtualmin/stress-testing/scripts/run_locust_test.sh" api "$STRESS_TESTING_USERS" 5 "$STRESS_TESTING_DURATION" "localhost" "10000" "false" | tee -a "$LOG_FILE"
    fi
    
    success "Pruebas de estrés completadas"
}

# Función para generar reportes
generate_reports() {
    log "Generando reportes..."
    
    local report_file="${REPORTS_DIR}/deployment_report_$(date +%Y%m%d_%H%M%S).html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte de Despliegue - Virtualmin Enterprise</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background-color: #2c3e50;
            color: white;
            padding: 20px;
            text-align: center;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .section {
            margin-bottom: 30px;
            padding: 15px;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        .section h2 {
            color: #2c3e50;
            border-bottom: 1px solid #ddd;
            padding-bottom: 10px;
        }
        .status {
            padding: 5px 10px;
            border-radius: 3px;
            color: white;
            font-weight: bold;
        }
        .success {
            background-color: #27ae60;
        }
        .warning {
            background-color: #f39c12;
        }
        .error {
            background-color: #e74c3c;
        }
        .log-container {
            background-color: #f8f9fa;
            border: 1px solid #ddd;
            border-radius: 5px;
            padding: 15px;
            font-family: monospace;
            white-space: pre-wrap;
            max-height: 300px;
            overflow-y: auto;
        }
        .metrics {
            display: flex;
            justify-content: space-between;
            flex-wrap: wrap;
        }
        .metric {
            background-color: #f8f9fa;
            border: 1px solid #ddd;
            border-radius: 5px;
            padding: 15px;
            margin: 10px;
            text-align: center;
            min-width: 150px;
        }
        .metric-value {
            font-size: 24px;
            font-weight: bold;
            color: #2c3e50;
        }
        .metric-label {
            font-size: 14px;
            color: #7f8c8d;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Reporte de Despliegue - Virtualmin Enterprise</h1>
        <p>Fecha: $(date +'%d/%m/%Y %H:%M:%S')</p>
    </div>
    
    <div class="section">
        <h2>Resumen de Despliegue</h2>
        <p><strong>Clúster:</strong> $CLUSTER_NAME</p>
        <p><strong>Entorno:</strong> $ENVIRONMENT</p>
        <p><strong>Región:</strong> $AWS_REGION</p>
        <p><strong>Dominio:</strong> $DOMAIN_NAME</p>
        <p><strong>Estado:</strong> <span class="status success">Completado</span></p>
    </div>
    
    <div class="section">
        <h2>Infraestructura</h2>
        <p><strong>Estado:</strong> <span class="status success">Desplegada</span></p>
        <p><strong>Herramienta:</strong> Terraform</p>
        <div class="metrics">
            <div class="metric">
                <div class="metric-value">$(terraform -chdir=cluster_infrastructure/terraform show -json 2>/dev/null | jq '.values.root_module.resources | length' || echo "N/A")</div>
                <div class="metric-label">Recursos</div>
            </div>
            <div class="metric">
                <div class="metric-value">$(terraform -chdir=cluster_infrastructure/terraform output -json 2>/dev/null | jq 'keys | length' || echo "N/A")</div>
                <div class="metric-label">Outputs</div>
            </div>
        </div>
    </div>
    
    <div class="section">
        <h2>Configuración de Aplicaciones</h2>
        <p><strong>Estado:</strong> <span class="status success">Configurada</span></p>
        <p><strong>Herramienta:</strong> Ansible</p>
        <div class="metrics">
            <div class="metric">
                <div class="metric-value">$(ansible-inventory -i cluster_infrastructure/ansible/inventory/hosts.ini --list | jq '.all.children | length' 2>/dev/null || echo "N/A")</div>
                <div class="metric-label">Grupos</div>
            </div>
            <div class="metric">
                <div class="metric-value">$(ansible-inventory -i cluster_infrastructure/ansible/inventory/hosts.ini --list | jq '.all.hosts | length' 2>/dev/null || echo "N/A")</div>
                <div class="metric-label">Hosts</div>
            </div>
        </div>
    </div>
    
    <div class="section">
        <h2>Seguridad</h2>
        <p><strong>WAF:</strong> <span class="status $([ "$SECURITY_WAF" = "true" ] && echo "success" || echo "warning")">$([ "$SECURITY_WAF" = "true" ] && echo "Configurado" || echo "No configurado")</span></p>
        <p><strong>IDS/IPS:</strong> <span class="status $([ "$SECURITY_IDS_IPS" = "true" ] && echo "success" || echo "warning")">$([ "$SECURITY_IDS_IPS" = "true" ] && echo "Configurado" || echo "No configurado")</span></p>
        <p><strong>MFA:</strong> <span class="status $([ "$SECURITY_MFA" = "true" ] && echo "success" || echo "warning")">$([ "$SECURITY_MFA" = "true" ] && echo "Configurado" || echo "No configurado")</span></p>
    </div>
    
    <div class="section">
        <h2>Pruebas de Estrés</h2>
        <p><strong>Estado:</strong> <span class="status $([ "$STRESS_TESTING_ENABLED" = "true" ] && echo "success" || echo "warning")">$([ "$STRESS_TESTING_ENABLED" = "true" ] && echo "Completadas" || echo "No ejecutadas")</span></p>
        <p><strong>Herramienta:</strong> $STRESS_TESTING_TOOL</p>
        <p><strong>Usuarios:</strong> $STRESS_TESTING_USERS</p>
        <p><strong>Duración:</strong> $STRESS_TESTING_DURATION segundos</p>
    </div>
    
    <div class="section">
        <h2>Logs de Despliegue</h2>
        <div class="log-container">$(tail -50 "$LOG_FILE")</div>
    </div>
    
    <div class="section">
        <h2>Accesos Rápidos</h2>
        <p><strong>Webmin:</strong> <a href="https://www.$DOMAIN_NAME:10000">https://www.$DOMAIN_NAME:10000</a></p>
        <p><strong>Virtualmin:</strong> <a href="https://www.$DOMAIN_NAME:10000/virtual-server/">https://www.$DOMAIN_NAME:10000/virtual-server/</a></p>
        <p><strong>Dashboard de Monitoreo:</strong> <a href="https://www.$DOMAIN_NAME:3000">https://www.$DOMAIN_NAME:3000</a></p>
    </div>
</body>
</html>
EOF
    
    success "Reporte generado: $report_file"
}

# Función para limpiar recursos
cleanup() {
    log "Realizando limpieza temporal..."
    
    # Limpiar archivos temporales
    find /tmp -name "virtualmin-*" -type f -mtime +1 -delete 2>/dev/null || true
    
    success "Limpieza temporal completada"
}

# Función para mostrar resumen final
show_summary() {
    header "Resumen del Despliegue"
    
    echo -e "${CYAN}Clúster:${NC} $CLUSTER_NAME" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Entorno:${NC} $ENVIRONMENT" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Región:${NC} $AWS_REGION" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Dominio:${NC} $DOMAIN_NAME" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo -e "${CYAN}Accesos:${NC}" | tee -a "$LOG_FILE"
    echo -e "  Webmin: https://www.$DOMAIN_NAME:10000" | tee -a "$LOG_FILE"
    echo -e "  Virtualmin: https://www.$DOMAIN_NAME:10000/virtual-server/" | tee -a "$LOG_FILE"
    echo -e "  Monitoreo: https://www.$DOMAIN_NAME:3000" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo -e "${CYAN}Logs:${NC} $LOG_FILE" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Reportes:${NC} $REPORTS_DIR" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    success "¡Despliegue completado exitosamente!"
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
    load_config
    validate_config
    run_terraform
    run_ansible
    setup_security
    run_stress_tests
    generate_reports
    cleanup
    show_summary
}

# Manejo de interrupción
trap 'error "Script interrumpido por el usuario"; exit 1' INT TERM

# Ejecutar función principal
main "$@"
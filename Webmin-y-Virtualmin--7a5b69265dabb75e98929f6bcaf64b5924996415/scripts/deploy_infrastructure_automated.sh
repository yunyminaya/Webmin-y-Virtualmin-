#!/bin/bash

# Script de automatización total con Ansible/Terraform para Virtualmin Enterprise
# Este script implementa un despliegue 100% automático con auto-recuperación y autoescalado

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

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="${PROJECT_ROOT}/configs"
LOG_DIR="${PROJECT_ROOT}/logs"
TERRAFORM_DIR="${PROJECT_ROOT}/cluster_infrastructure/terraform"
ANSIBLE_DIR="${PROJECT_ROOT}/cluster_infrastructure/ansible"

# Crear directorios necesarios
mkdir -p "$LOG_DIR" "$CONFIG_DIR"

# Archivo de log
LOG_FILE="${LOG_DIR}/deploy_$(date +%Y%m%d_%H%M%S).log"

# Archivo de configuración
CONFIG_FILE="$CONFIG_DIR/deploy_config.yml"

# Función para mostrar banner
show_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           Virtualmin Enterprise - Despliegue Automatizado         ║"
    echo "║               100% Automatizado con Ansible/Terraform             ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Función para verificar dependencias
check_dependencies() {
    log "Verificando dependencias..."
    
    # Verificar si las herramientas necesarias están instaladas
    local tools=("terraform" "ansible" "jq" "curl" "git" "docker" "kubectl")
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log "✓ $tool está instalado"
        else
            error "$tool no está instalado. Por favor, instale $tool y vuelva a ejecutar el script."
            exit 1
        fi
    done
    
    success "Dependencias verificadas"
}

# Función para cargar configuración
load_configuration() {
    log "Cargando configuración..."
    
    # Crear archivo de configuración si no existe
    if [ ! -f "$CONFIG_FILE" ]; then
        log "Creando archivo de configuración por defecto..."
        cat > "$CONFIG_FILE" << EOF
# Configuración de despliegue automatizado
deployment:
  environment: production
  region: us-east-1
  providers: aws
  auto_recovery: true
  auto_scaling: true
  
# Configuración de infraestructura
infrastructure:
  # Configuración de red
  network:
    vpc_cidr: "10.0.0.0/16"
    public_subnet_cidrs: ["10.0.1.0/24", "10.0.2.0/24"]
    private_subnet_cidrs: ["10.0.10.0/24", "10.0.20.0/24"]
    
  # Configuración de instancias
  instances:
    web_servers:
      count: 2
      instance_type: "t3.medium"
      ami: "ami-0c55b159cbfafe1f0"
      
    database:
      instance_type: "db.t3.medium"
      engine: "mysql"
      version: "8.0"
      storage_size: 50
      
  # Configuración de balanceador de carga
  load_balancer:
    type: "application"
    ssl_certificate: true
    
# Configuración de autoescalado
auto_scaling:
  web_servers:
    min_size: 2
    max_size: 10
    desired_capacity: 2
    target_cpu_utilization: 70
    scale_up_cooldown: 300
    scale_down_cooldown: 300
    
# Configuración de monitoreo
monitoring:
  prometheus: true
  grafana: true
  alertmanager: true
  
# Configuración de seguridad
security:
  waf: true
  ddos_protection: true
  ssl_policy: "ELBSecurityPolicy-TLS-1-2-2017-01"
  
# Configuración de backup
backup:
  enabled: true
  retention_days: 30
  schedule: "0 2 * * *"
EOF
    fi
    
    success "Configuración cargada"
}

# Función para inicializar Terraform
init_terraform() {
    log "Inicializando Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Inicializar Terraform
    terraform init | tee -a "$LOG_FILE"
    
    success "Terraform inicializado"
}

# Función para planificar infraestructura con Terraform
plan_terraform() {
    log "Planificando infraestructura con Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Obtener variables de configuración
    local region=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('infrastructure', {}).get('region', 'us-east-1'))
" 2>/dev/null || echo "us-east-1")
    
    # Crear plan de Terraform
    terraform plan \
        -var="region=$region" \
        -out=terraform.plan | tee -a "$LOG_FILE"
    
    success "Plan de Terraform creado"
}

# Función para aplicar infraestructura con Terraform
apply_terraform() {
    log "Aplicando infraestructura con Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Aplicar configuración de Terraform
    terraform apply -auto-approve terraform.plan | tee -a "$LOG_FILE"
    
    # Exportar outputs de Terraform para Ansible
    terraform output -json > "$ANSIBLE_DIR/terraform_outputs.json"
    
    success "Infraestructura aplicada con Terraform"
}

# Función para provisionar con Ansible
run_ansible() {
    log "Provisionando sistemas con Ansible..."
    
    cd "$ANSIBLE_DIR"
    
    # Actualizar inventory dinámicamente basado en outputs de Terraform
    python3 scripts/generate_inventory.py terraform_outputs.json | tee -a "$LOG_FILE"
    
    # Ejecutar playbook principal
    ansible-playbook -i inventory.ini site.yml | tee -a "$LOG_FILE"
    
    success "Sistemas provisionados con Ansible"
}

# Función para configurar auto-recuperación
setup_auto_recovery() {
    log "Configurando sistema de auto-recuperación..."
    
    # Verificar si la auto-recuperación está habilitada
    local auto_recovery=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('deployment', {}).get('auto_recovery', True))
" 2>/dev/null || echo "True")
    
    if [ "$auto_recovery" == "True" ]; then
        # Crear directorio de scripts de recuperación
        local recovery_dir="${PROJECT_ROOT}/scripts/recovery"
        mkdir -p "$recovery_dir"
        
        # Crear script de monitoreo y recuperación
        cat > "$recovery_dir/monitor_and_recover.sh" << 'EOF'
#!/bin/bash

# Script de monitoreo y recuperación automática

set -e

# Configuración
ALERT_THRESHOLD=3
RECOVERY_SCRIPTS_DIR="/opt/virtualmin-enterprise/recovery"
LOG_FILE="/var/log/virtualmin-enterprise/recovery.log"

# Función para verificar servicio
check_service() {
    local service=$1
    if systemctl is-active --quiet "$service"; then
        return 0
    else
        return 1
    fi
}

# Función para reiniciar servicio
restart_service() {
    local service=$1
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Reiniciando servicio: $service" >> "$LOG_FILE"
    systemctl restart "$service"
    
    # Esperar a que el servicio se inicie
    sleep 10
    
    # Verificar si el servicio está activo
    if check_service "$service"; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] Servicio $service recuperado exitosamente" >> "$LOG_FILE"
        return 0
    else
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] Error al recuperar servicio $service" >> "$LOG_FILE"
        return 1
    fi
}

# Función principal de monitoreo
monitor_services() {
    local services=("virtualmin" "webmin" "nginx" "mysql" "prometheus")
    
    for service in "${services[@]}"; do
        if ! check_service "$service"; then
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] Servicio $service está caído" >> "$LOG_FILE"
            
            # Intentar recuperación
            if restart_service "$service"; then
                # Enviar alerta de recuperación
                curl -X POST -H 'Content-type: application/json' \
                    --data '{"text":"Virtualmin Enterprise: Servicio '$service' recuperado automáticamente"}' \
                    "$SLACK_WEBHOOK_URL" 2>/dev/null || true
            else
                # Enviar alerta crítica
                curl -X POST -H 'Content-type: application/json' \
                    --data '{"text":"Virtualmin Enterprise: CRÍTICO - No se pudo recuperar servicio '$service'"}' \
                    "$SLACK_WEBHOOK_URL" 2>/dev/null || true
            fi
        fi
    done
}

# Ejecutar monitoreo
monitor_services
EOF
        
        # Hacer ejecutable el script
        chmod +x "$recovery_dir/monitor_and_recover.sh"
        
        # Crear servicio systemd para monitoreo y recuperación
        cat > "/etc/systemd/system/virtualmin-auto-recovery.service" << EOF
[Unit]
Description=Virtualmin Enterprise Auto Recovery Service
After=network.target

[Service]
Type=oneshot
ExecStart=$recovery_dir/monitor_and_recover.sh
User=root

[Install]
WantedBy=multi-user.target
EOF
        
        # Crear timer para ejecución periódica
        cat > "/etc/systemd/system/virtualmin-auto-recovery.timer" << EOF
[Unit]
Description=Virtualmin Enterprise Auto Recovery Timer
Requires=virtualmin-auto-recovery.service

[Timer]
OnCalendar=*:0/5
Unit=virtualmin-auto-recovery.service

[Install]
WantedBy=timers.target
EOF
        
        # Habilitar e iniciar el timer
        systemctl daemon-reload
        systemctl enable virtualmin-auto-recovery.timer
        systemctl start virtualmin-auto-recovery.timer
        
        success "Sistema de auto-recuperación configurado"
    else
        log "Auto-recuperación deshabilitada en la configuración"
    fi
}

# Función para configurar autoescalado
setup_auto_scaling() {
    log "Configurando sistema de autoescalado..."
    
    # Verificar si el autoescalado está habilitado
    local auto_scaling=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('deployment', {}).get('auto_scaling', True))
" 2>/dev/null || echo "True")
    
    if [ "$auto_scaling" == "True" ]; then
        # Obtener configuración de autoescalado
        local min_size=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('auto_scaling', {}).get('web_servers', {}).get('min_size', 2))
" 2>/dev/null || echo "2")
        
        local max_size=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('auto_scaling', {}).get('web_servers', {}).get('max_size', 10))
" 2>/dev/null || echo "10")
        
        local desired_capacity=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('auto_scaling', {}).get('web_servers', {}).get('desired_capacity', 2))
" 2>/dev/null || echo "2")
        
        local target_cpu=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('auto_scaling', {}).get('web_servers', {}).get('target_cpu_utilization', 70))
" 2>/dev/null || echo "70")
        
        # Crear script de autoescalado
        local scaling_dir="${PROJECT_ROOT}/scripts/scaling"
        mkdir -p "$scaling_dir"
        
        cat > "$scaling_dir/auto_scaling.py" << EOF
#!/usr/bin/env python3

import json
import time
import requests
import logging
from datetime import datetime

# Configuración
LOG_FILE = "/var/log/virtualmin-enterprise/auto_scaling.log"
PROMETHEUS_URL = "http://localhost:9090"
MIN_SIZE = $min_size
MAX_SIZE = $max_size
DESIRED_CAPACITY = $desired_capacity
TARGET_CPU = $target_cpu
SCALE_UP_THRESHOLD = TARGET_CPU + 10
SCALE_DOWN_THRESHOLD = TARGET_CPU - 10

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

def get_current_cpu_utilization():
    """Obtener la utilización actual de CPU desde Prometheus"""
    try:
        response = requests.get(
            f"{PROMETHEUS_URL}/api/v1/query",
            params={"query": "avg(100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100))"}
        )
        response.raise_for_status()
        data = response.json()
        
        if data["status"] == "success" and data["data"]["result"]:
            return float(data["data"]["result"][0]["value"][1])
        else:
            logger.error("No se pudieron obtener métricas de CPU")
            return None
    except Exception as e:
        logger.error(f"Error al obtener métricas de CPU: {str(e)}")
        return None

def get_current_instance_count():
    """Obtener el número actual de instancias"""
    try:
        response = requests.get("http://localhost:8080/api/instances")
        response.raise_for_status()
        data = response.json()
        return data.get("count", DESIRED_CAPACITY)
    except Exception as e:
        logger.error(f"Error al obtener número de instancias: {str(e)}")
        return DESIRED_CAPACITY

def scale_instances(target_count):
    """Escalar el número de instancias"""
    target_count = max(MIN_SIZE, min(MAX_SIZE, target_count))
    
    if target_count == get_current_instance_count():
        logger.info(f"El número de instancias ya es {target_count}, no se requiere escalado")
        return True
    
    try:
        response = requests.post(
            "http://localhost:8080/api/scale",
            json={"count": target_count}
        )
        response.raise_for_status()
        
        logger.info(f"Solicitud de escalado enviada: {get_current_instance_count()} -> {target_count}")
        return True
    except Exception as e:
        logger.error(f"Error al escalar instancias: {str(e)}")
        return False

def main():
    """Función principal de autoescalado"""
    logger.info("Iniciando ciclo de autoescalado")
    
    # Obtener métricas actuales
    cpu_utilization = get_current_cpu_utilization()
    if cpu_utilization is None:
        logger.error("No se pudo obtener la utilización de CPU, omitiendo ciclo de autoescalado")
        return
    
    current_instances = get_current_instance_count()
    
    # Determinar si se requiere escalado
    if cpu_utilization > SCALE_UP_THRESHOLD and current_instances < MAX_SIZE:
        # Escalar hacia arriba
        target_instances = min(current_instances + 1, MAX_SIZE)
        logger.info(f"CPU alta ({cpu_utilization:.2f}%), escalando hacia arriba a {target_instances} instancias")
        scale_instances(target_instances)
    elif cpu_utilization < SCALE_DOWN_THRESHOLD and current_instances > MIN_SIZE:
        # Escalar hacia abajo
        target_instances = max(current_instances - 1, MIN_SIZE)
        logger.info(f"CPU baja ({cpu_utilization:.2f}%), escalando hacia abajo a {target_instances} instancias")
        scale_instances(target_instances)
    else:
        logger.info(f"CPU normal ({cpu_utilization:.2f}%), no se requiere escalado")

if __name__ == "__main__":
    main()
EOF
        
        # Hacer ejecutable el script
        chmod +x "$scaling_dir/auto_scaling.py"
        
        # Crear servicio systemd para autoescalado
        cat > "/etc/systemd/system/virtualmin-auto-scaling.service" << EOF
[Unit]
Description=Virtualmin Enterprise Auto Scaling Service
After=network.target

[Service]
Type=oneshot
ExecStart=$scaling_dir/auto_scaling.py
User=root

[Install]
WantedBy=multi-user.target
EOF
        
        # Crear timer para ejecución periódica
        cat > "/etc/systemd/system/virtualmin-auto-scaling.timer" << EOF
[Unit]
Description=Virtualmin Enterprise Auto Scaling Timer
Requires=virtualmin-auto-scaling.service

[Timer]
OnCalendar=*:0/2
Unit=virtualmin-auto-scaling.service

[Install]
WantedBy=timers.target
EOF
        
        # Habilitar e iniciar el timer
        systemctl daemon-reload
        systemctl enable virtualmin-auto-scaling.timer
        systemctl start virtualmin-auto-scaling.timer
        
        success "Sistema de autoescalado configurado"
    else
        log "Autoescalado deshabilitado en la configuración"
    fi
}

# Función para validar despliegue
validate_deployment() {
    log "Validando despliegue..."
    
    # Obtener URLs de los servicios
    local web_url=$(terraform -chdir="$TERRAFORM_DIR" output -raw web_url 2>/dev/null || echo "")
    local grafana_url=$(terraform -chdir="$TERRAFORM_DIR" output -raw grafana_url 2>/dev/null || echo "")
    
    # Verificar que los servicios estén respondiendo
    if [ -n "$web_url" ]; then
        if curl -f -s "$web_url" > /dev/null; then
            success "Servicio web está respondiendo en $web_url"
        else
            error "Servicio web no está respondiendo en $web_url"
            return 1
        fi
    fi
    
    if [ -n "$grafana_url" ]; then
        if curl -f -s "$grafana_url" > /dev/null; then
            success "Grafana está respondiendo en $grafana_url"
        else
            error "Grafana no está respondiendo en $grafana_url"
            return 1
        fi
    fi
    
    success "Validación de despliegue completada"
}

# Función para mostrar resumen
show_summary() {
    log "Mostrando resumen del despliegue..."
    
    # Obtener URLs de los servicios
    local web_url=$(terraform -chdir="$TERRAFORM_DIR" output -raw web_url 2>/dev/null || echo "")
    local grafana_url=$(terraform -chdir="$TERRAFORM_DIR" output -raw grafana_url 2>/dev/null || echo "")
    
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    Resumen del Despliegue                        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${GREEN}✓ Infraestructura desplegada con Terraform${NC}"
    echo -e "${GREEN}✓ Sistemas provisionados con Ansible${NC}"
    echo -e "${GREEN}✓ Sistema de auto-recuperación configurado${NC}"
    echo -e "${GREEN}✓ Sistema de autoescalado configurado${NC}"
    echo ""
    echo -e "${CYAN}Servicios Disponibles:${NC}"
    [ -n "$web_url" ] && echo -e "  - ${BLUE}Webmin/Virtualmin:${NC} $web_url"
    [ -n "$grafana_url" ] && echo -e "  - ${BLUE}Grafana:${NC} $grafana_url"
    echo ""
    echo -e "${CYAN}Logs:${NC} $LOG_FILE"
    echo ""
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
    init_terraform
    plan_terraform
    apply_terraform
    run_ansible
    setup_auto_recovery
    setup_auto_scaling
    validate_deployment
    show_summary
}

# Manejo de interrupción
trap 'error "Script interrumpido por el usuario"; exit 1' INT TERM

# Ejecutar función principal
main "$@"
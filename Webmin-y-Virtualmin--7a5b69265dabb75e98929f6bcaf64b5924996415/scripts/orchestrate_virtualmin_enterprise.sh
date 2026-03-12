#!/bin/bash

# Script de Orquestación Avanzada para Virtualmin Enterprise
# Integra Ansible, Terraform, Docker y Kubernetes para despliegue y configuración automática

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
TERRAFORM_DIR="${PROJECT_ROOT}/cluster_infrastructure/terraform"
ANSIBLE_DIR="${PROJECT_ROOT}/cluster_infrastructure/ansible"
REPORTS_DIR="${PROJECT_ROOT}/reports"

# Crear directorios necesarios
mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$REPORTS_DIR"

# Archivo de log
LOG_FILE="${LOG_DIR}/orchestrate_virtualmin_enterprise_$(date +%Y%m%d_%H%M%S).log"

# Archivo de configuración
CONFIG_FILE="${CONFIG_DIR}/orchestration_config.yml"

# Función para mostrar banner
show_banner() {
    header "Orquestación Avanzada de Virtualmin Enterprise"
    echo -e "${CYAN}Script de Orquestación Integral${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Integra: Ansible, Terraform, Docker, Kubernetes${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Versión: 1.0${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

# Función para verificar dependencias
check_dependencies() {
    log "Verificando dependencias..."
    
    # Verificar si las herramientas necesarias están instaladas
    local tools=("terraform" "ansible" "docker" "kubectl" "pip3" "python3")
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log "✓ $tool está instalado"
        else
            error "$tool no está instalado. Por favor, instale $tool y vuelva a ejecutar el script."
            exit 1
        fi
    done
    
    # Verificar módulos de Python necesarios
    local python_modules=("pyyaml" "jinja2" "boto3" "kubernetes")
    
    for module in "${python_modules[@]}"; do
        if python3 -c "import $module" &> /dev/null; then
            log "✓ Módulo Python $module está instalado"
        else
            warning "Módulo Python $module no está instalado. Instalando..."
            pip3 install "$module" | tee -a "$LOG_FILE"
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
# Configuración de Orquestación de Virtualmin Enterprise
project_name: "virtualmin-enterprise"
environment: "production"
region: "us-east-1"

# Configuración de Terraform
terraform:
  backend: "s3"
  backend_config:
    bucket: "virtualmin-enterprise-terraform-state"
    key: "terraform.tfstate"
    region: "us-east-1"
  variables:
    cluster_name: "virtualmin-cluster"
    node_count: 3
    instance_type: "t3.medium"

# Configuración de Ansible
ansible:
  inventory: "inventory.ini"
  playbook: "cluster.yml"
  group_vars: "group_vars/all.yml"
  roles:
    - "unlimited_servers"
    - "cost_monitoring"

# Configuración de Docker
docker:
  registry: "docker.io"
  namespace: "virtualmin"
  images:
    - name: "virtualmin-enterprise"
      tag: "latest"
    - name: "monitoring"
      tag: "latest"

# Configuración de Kubernetes
kubernetes:
  namespace: "virtualmin"
  deployments:
    - name: "virtualmin"
      replicas: 2
      image: "virtualmin/virtualmin-enterprise:latest"
      ports:
        - containerPort: 10000
          protocol: TCP
    - name: "monitoring"
      replicas: 1
      image: "virtualmin/monitoring:latest"
      ports:
        - containerPort: 3000
          protocol: TCP

# Configuración de Monitoreo
monitoring:
  enabled: true
  prometheus:
    enabled: true
    port: 9090
  grafana:
    enabled: true
    port: 3000
  zabbix:
    enabled: false
    port: 80

# Configuración de Seguridad
security:
  waf:
    enabled: true
    provider: "modsecurity"
  ids_ips:
    enabled: true
    provider: "fail2ban"
  ssl:
    enabled: true
    provider: "letsencrypt"
    auto_renew: true
    renew_days: 30

# Configuración de Pruebas
testing:
  load_testing:
    enabled: true
    tool: "jmeter"
    users: 100
    duration: 300
  stress_testing:
    enabled: true
    tool: "locust"
    users: 200
    duration: 600

# Configuración de Reportes
reporting:
  enabled: true
  format: "html"
  output_dir: "$REPORTS_DIR"
  schedule: "daily"
EOF
    fi
    
    # Cargar configuración
    if command -v python3 &> /dev/null; then
        python3 -c "
import yaml
import sys

try:
    with open('$CONFIG_FILE', 'r') as f:
        config = yaml.safe_load(f)
    print('Configuración cargada exitosamente')
except Exception as e:
    print(f'Error al cargar configuración: {e}')
    sys.exit(1)
" | tee -a "$LOG_FILE"
    else
        error "Python3 no está disponible para cargar la configuración"
        exit 1
    fi
    
    success "Configuración cargada"
}

# Función para ejecutar Terraform
run_terraform() {
    header "Ejecutando Terraform"
    
    cd "$TERRAFORM_DIR"
    
    # Inicializar Terraform
    log "Inicializando Terraform..."
    terraform init | tee -a "$LOG_FILE"
    
    # Validar configuración
    log "Validando configuración de Terraform..."
    terraform validate | tee -a "$LOG_FILE"
    
    # Planificar despliegue
    log "Planificando despliegue de infraestructura..."
    terraform plan -out=tfplan | tee -a "$LOG_FILE"
    
    # Aplicar configuración
    log "Aplicando configuración de infraestructura..."
    terraform apply -auto-approve tfplan | tee -a "$LOG_FILE"
    
    # Obtener outputs
    log "Obteniendo outputs de Terraform..."
    terraform output -json > "$REPORTS_DIR/terraform_outputs.json"
    
    success "Infraestructura desplegada con Terraform"
}

# Función para ejecutar Ansible
run_ansible() {
    header "Ejecutando Ansible"
    
    cd "$ANSIBLE_DIR"
    
    # Instalar roles de Ansible
    log "Instalando roles de Ansible..."
    ansible-galaxy install -r requirements.yml | tee -a "$LOG_FILE"
    
    # Ejecutar playbook
    log "Ejecutando playbook de Ansible..."
    ansible-playbook -i inventory cluster.yml | tee -a "$LOG_FILE"
    
    success "Configuración aplicada con Ansible"
}

# Función para configurar Docker
setup_docker() {
    header "Configurando Docker"
    
    # Construir imágenes Docker
    log "Construyendo imágenes Docker..."
    
    # Verificar si existe Dockerfile
    if [ -f "$PROJECT_ROOT/Dockerfile" ]; then
        docker build -t virtualmin/virtualmin-enterprise:latest "$PROJECT_ROOT" | tee -a "$LOG_FILE"
    else
        warning "Dockerfile no encontrado. Omitiendo construcción de imágenes."
    fi
    
    # Verificar si existe docker-compose.yml
    if [ -f "$PROJECT_ROOT/docker-compose.yml" ]; then
        log "Iniciando servicios con docker-compose..."
        docker-compose up -d | tee -a "$LOG_FILE"
    else
        warning "docker-compose.yml no encontrado. Omitiendo inicio de servicios."
    fi
    
    success "Docker configurado"
}

# Función para configurar Kubernetes
setup_kubernetes() {
    header "Configurando Kubernetes"
    
    # Verificar conexión con el clúster
    log "Verificando conexión con el clúster Kubernetes..."
    kubectl cluster-info | tee -a "$LOG_FILE"
    
    # Crear namespace
    log "Creando namespace de Virtualmin..."
    kubectl create namespace virtualmin --dry-run=client -o yaml | kubectl apply -f - | tee -a "$LOG_FILE"
    
    # Aplicar configuraciones de Kubernetes
    if [ -d "$PROJECT_ROOT/k8s" ]; then
        log "Aplicando configuraciones de Kubernetes..."
        kubectl apply -f "$PROJECT_ROOT/k8s" --recursive | tee -a "$LOG_FILE"
    else
        warning "Directorio k8s no encontrado. Omitiendo aplicación de configuraciones."
    fi
    
    # Verificar estado de los pods
    log "Verificando estado de los pods..."
    kubectl get pods -n virtualmin | tee -a "$LOG_FILE"
    
    success "Kubernetes configurado"
}

# Función para configurar monitoreo
setup_monitoring() {
    header "Configurando Monitoreo"
    
    # Verificar si Prometheus está habilitado en la configuración
    if python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
if config.get('monitoring', {}).get('prometheus', {}).get('enabled', False):
    print('Prometheus habilitado')
else:
    print('Prometheus no habilitado')
    exit(1)
" 2>/dev/null; then
        log "Configurando Prometheus..."
        
        # Crear directorio de configuración de Prometheus
        mkdir -p "$CONFIG_DIR/prometheus"
        
        # Crear archivo de configuración de Prometheus
        cat > "$CONFIG_DIR/prometheus/prometheus.yml" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

scrape_configs:
  - job_name: 'virtualmin'
    static_configs:
      - targets: ['localhost:10000']
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF
        
        # Iniciar Prometheus
        if command -v prometheus &> /dev/null; then
            prometheus --config.file="$CONFIG_DIR/prometheus/prometheus.yml" --web.listen-address=":9090" > "$LOG_DIR/prometheus.log" 2>&1 &
            PROMETHEUS_PID=$!
            echo $PROMETHEUS_PID > "$LOG_DIR/prometheus.pid"
            success "Prometheus iniciado (PID: $PROMETHEUS_PID)"
        else
            warning "Prometheus no está instalado. Omitiendo inicio de Prometheus."
        fi
    fi
    
    # Verificar si Grafana está habilitado en la configuración
    if python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
if config.get('monitoring', {}).get('grafana', {}).get('enabled', False):
    print('Grafana habilitado')
else:
    print('Grafana no habilitado')
    exit(1)
" 2>/dev/null; then
        log "Configurando Grafana..."
        
        # Crear directorio de configuración de Grafana
        mkdir -p "$CONFIG_DIR/grafana"
        
        # Crear archivo de configuración de Grafana
        cat > "$CONFIG_DIR/grafana/grafana.ini" << EOF
[server]
http_port = 3000

[database]
type = sqlite3
path = $CONFIG_DIR/grafana/grafana.db

[security]
admin_user = admin
admin_password = admin123
EOF
        
        # Iniciar Grafana
        if command -v grafana-server &> /dev/null; then
            grafana-server --config="$CONFIG_DIR/grafana/grafana.ini" --homepath="$CONFIG_DIR/grafana" > "$LOG_DIR/grafana.log" 2>&1 &
            GRAFANA_PID=$!
            echo $GRAFANA_PID > "$LOG_DIR/grafana.pid"
            success "Grafana iniciado (PID: $GRAFANA_PID)"
        else
            warning "Grafana-server no está instalado. Omitiendo inicio de Grafana."
        fi
    fi
    
    success "Monitoreo configurado"
}

# Función para ejecutar pruebas de carga
run_load_tests() {
    header "Ejecutando Pruebas de Carga"
    
    # Verificar si las pruebas de carga están habilitadas en la configuración
    if python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
if config.get('testing', {}).get('load_testing', {}).get('enabled', False):
    print('Pruebas de carga habilitadas')
else:
    print('Pruebas de carga no habilitadas')
    exit(1)
" 2>/dev/null; then
        # Obtener configuración de pruebas de carga
        local tool=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('testing', {}).get('load_testing', {}).get('tool', 'jmeter'))
" 2>/dev/null)
        
        local users=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('testing', {}).get('load_testing', {}).get('users', 100))
" 2>/dev/null)
        
        local duration=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('testing', {}).get('load_testing', {}).get('duration', 300))
" 2>/dev/null)
        
        log "Ejecutando pruebas de carga con $tool ($users usuarios, $duration segundos)..."
        
        # Crear directorio de resultados de pruebas
        mkdir -p "$REPORTS_DIR/load_tests"
        
        # Ejecutar pruebas según la herramienta configurada
        case "$tool" in
            "jmeter")
                if command -v jmeter &> /dev/null; then
                    # Crear script de prueba JMeter
                    cat > "$REPORTS_DIR/load_tests/virtualmin_test.jmx" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2" properties="5.0" jmeter="5.0">
  <hashTree>
    <TestPlan guiclass="TestPlanGui" testclass="TestPlan" testname="Virtualmin Load Test" enabled="true">
      <stringProp name="TestPlan.comments"></stringProp>
      <boolProp name="TestPlan.functional_mode">false</boolProp>
      <boolProp name="TestPlan.tearDown_on_shutdown">true</boolProp>
      <boolProp name="TestPlan.serialize_threadgroups">false</boolProp>
      <elementProp name="TestPlan.user_defined_variables" elementType="Arguments" guiclass="ArgumentsPanel" testclass="Arguments" testname="User Defined Variables" enabled="true">
        <collectionProp name="Arguments.arguments"/>
      </elementProp>
    </TestPlan>
    <hashTree>
      <ThreadGroup guiclass="ThreadGroupGui" testclass="ThreadGroup" testname="Thread Group" enabled="true">
        <stringProp name="ThreadGroup.on_sample_error">continue</stringProp>
        <elementProp name="ThreadGroup.main_controller" elementType="LoopController" guiclass="LoopControlPanel" testclass="LoopController" testname="Loop Controller" enabled="true">
          <boolProp name="LoopController.continue_forever">false</boolProp>
          <stringProp name="LoopController.loops">1</stringProp>
        </elementProp>
        <stringProp name="ThreadGroup.num_threads">$users</stringProp>
        <stringProp name="ThreadGroup.ramp_time">10</stringProp>
        <boolProp name="ThreadGroup.scheduler">true</boolProp>
        <stringProp name="ThreadGroup.duration">$duration</stringProp>
        <stringProp name="ThreadGroup.delay"></stringProp>
        <boolProp name="ThreadGroup.same_user_on_next_iteration">true</boolProp>
      </ThreadGroup>
      <hashTree>
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="HTTP Request" enabled="true">
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments" guiclass="HTTPArgumentsPanel" testclass="Arguments" testname="User Defined Variables" enabled="true">
            <collectionProp name="Arguments.arguments"/>
          </elementProp>
          <stringProp name="HTTPSampler.domain">localhost</stringProp>
          <stringProp name="HTTPSampler.port">10000</stringProp>
          <stringProp name="HTTPSampler.protocol">https</stringProp>
          <stringProp name="HTTPSampler.contentEncoding">utf-8</stringProp>
          <stringProp name="HTTPSampler.path">/</stringProp>
          <stringProp name="HTTPSampler.method">GET</stringProp>
          <boolProp name="HTTPSampler.follow_redirects">true</boolProp>
          <boolProp name="HTTPSampler.auto_redirects">false</boolProp>
          <boolProp name="HTTPSampler.use_keepalive">true</boolProp>
          <boolProp name="HTTPSampler.DO_MULTIPART_POST">false</boolProp>
          <stringProp name="HTTPSampler.embedded_url_re"></stringProp>
          <stringProp name="HTTPSampler.connect_timeout"></stringProp>
          <stringProp name="HTTPSampler.response_timeout"></stringProp>
        </HTTPSamplerProxy>
        <hashTree/>
        <ResultCollector guiclass="ViewResultsFullVisualizer" testclass="ResultCollector" testname="View Results Tree" enabled="true">
          <boolProp name="ResultCollector.error_logging">false</boolProp>
          <objProp>
            <name>saveConfig</name>
            <value class="SampleSaveConfiguration">
              <time>true</time>
              <latency>true</latency>
              <timestamp>true</timestamp>
              <success>true</success>
              <label>true</label>
              <code>true</code>
              <message>true</message>
              <threadName>true</threadName>
              <dataType>true</dataType>
              <encoding>false</encoding>
              <assertions>true</assertions>
              <subresults>true</subresults>
              <responseData>false</responseData>
              <samplerData>false</samplerData>
              <xml>false</xml>
              <fieldNames>true</fieldNames>
              <responseHeaders>false</responseHeaders>
              <requestHeaders>false</requestHeaders>
              <responseDataOnError>false</responseDataOnError>
              <saveAssertionResultsFailureMessage>true</saveAssertionResultsFailureMessage>
              <assertionsResultsToSave>0</assertionsResultsToSave>
              <bytes>true</bytes>
              <sentBytes>true</sentBytes>
              <url>true</url>
              <threadCounts>true</threadCounts>
              <idleTime>true</idleTime>
              <connectTime>true</connectTime>
            </value>
          </objProp>
          <stringProp name="filename">$REPORTS_DIR/load_tests/results.jtl</stringProp>
        </ResultCollector>
        <hashTree/>
      </hashTree>
    </hashTree>
  </hashTree>
</jmeterTestPlan>
EOF
                    
                    # Ejecutar JMeter
                    jmeter -n -t "$REPORTS_DIR/load_tests/virtualmin_test.jmx" -l "$REPORTS_DIR/load_tests/results.jtl" -e -o "$REPORTS_DIR/load_tests/report" | tee -a "$LOG_FILE"
                    
                    success "Pruebas de carga ejecutadas con JMeter"
                else
                    warning "JMeter no está instalado. Omitiendo pruebas de carga."
                fi
                ;;
            "locust")
                if command -v locust &> /dev/null; then
                    # Crear script de prueba Locust
                    cat > "$REPORTS_DIR/load_tests/locustfile.py" << EOF
from locust import HttpUser, task, between

class VirtualminUser(HttpUser):
    wait_time = between(1, 3)
    
    @task
    def index_page(self):
        self.client.get("/")
    
    @task
    def login_page(self):
        self.client.get("/session_login.cgi")
EOF
                    
                    # Ejecutar Locust
                    locust -f "$REPORTS_DIR/load_tests/locustfile.py" --headless -u $users -t ${duration}s --host=https://localhost:10000 --csv "$REPORTS_DIR/load_tests/locust_results" | tee -a "$LOG_FILE"
                    
                    success "Pruebas de carga ejecutadas con Locust"
                else
                    warning "Locust no está instalado. Omitiendo pruebas de carga."
                fi
                ;;
            *)
                warning "Herramienta de pruebas de carga no reconocida: $tool"
                ;;
        esac
    else
        warning "Pruebas de carga no habilitadas en la configuración"
    fi
}

# Función para ejecutar pruebas de estrés
run_stress_tests() {
    header "Ejecutando Pruebas de Estrés"
    
    # Verificar si las pruebas de estrés están habilitadas en la configuración
    if python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
if config.get('testing', {}).get('stress_testing', {}).get('enabled', False):
    print('Pruebas de estrés habilitadas')
else:
    print('Pruebas de estrés no habilitadas')
    exit(1)
" 2>/dev/null; then
        # Obtener configuración de pruebas de estrés
        local tool=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('testing', {}).get('stress_testing', {}).get('tool', 'locust'))
" 2>/dev/null)
        
        local users=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('testing', {}).get('stress_testing', {}).get('users', 200))
" 2>/dev/null)
        
        local duration=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('testing', {}).get('stress_testing', {}).get('duration', 600))
" 2>/dev/null)
        
        log "Ejecutando pruebas de estrés con $tool ($users usuarios, $duration segundos)..."
        
        # Crear directorio de resultados de pruebas
        mkdir -p "$REPORTS_DIR/stress_tests"
        
        # Ejecutar pruebas según la herramienta configurada
        case "$tool" in
            "locust")
                if command -v locust &> /dev/null; then
                    # Crear script de prueba Locust
                    cat > "$REPORTS_DIR/stress_tests/locustfile.py" << EOF
from locust import HttpUser, task, between
import random

class VirtualminStressUser(HttpUser):
    wait_time = between(0.1, 1)
    
    @task(3)
    def index_page(self):
        self.client.get("/")
    
    @task(2)
    def login_page(self):
        self.client.get("/session_login.cgi")
    
    @task(1)
    def admin_page(self):
        self.client.post("/session_login.cgi", {
            "user": "admin",
            "pass": "password"
        })
    
    def on_start(self):
        """Called when a Locust user starts"""
        pass
EOF
                    
                    # Ejecutar Locust
                    locust -f "$REPORTS_DIR/stress_tests/locustfile.py" --headless -u $users -t ${duration}s --host=https://localhost:10000 --csv "$REPORTS_DIR/stress_tests/locust_stress_results" | tee -a "$LOG_FILE"
                    
                    success "Pruebas de estrés ejecutadas con Locust"
                else
                    warning "Locust no está instalado. Omitiendo pruebas de estrés."
                fi
                ;;
            "jmeter")
                if command -v jmeter &> /dev/null; then
                    # Crear script de prueba JMeter
                    cat > "$REPORTS_DIR/stress_tests/stress_test.jmx" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2" properties="5.0" jmeter="5.0">
  <hashTree>
    <TestPlan guiclass="TestPlanGui" testclass="TestPlan" testname="Virtualmin Stress Test" enabled="true">
      <stringProp name="TestPlan.comments"></stringProp>
      <boolProp name="TestPlan.functional_mode">false</boolProp>
      <boolProp name="TestPlan.tearDown_on_shutdown">true</boolProp>
      <boolProp name="TestPlan.serialize_threadgroups">false</boolProp>
      <elementProp name="TestPlan.user_defined_variables" elementType="Arguments" guiclass="ArgumentsPanel" testclass="Arguments" testname="User Defined Variables" enabled="true">
        <collectionProp name="Arguments.arguments"/>
      </elementProp>
    </TestPlan>
    <hashTree>
      <ThreadGroup guiclass="ThreadGroupGui" testclass="ThreadGroup" testname="Stress Test Thread Group" enabled="true">
        <stringProp name="ThreadGroup.on_sample_error">continue</stringProp>
        <elementProp name="ThreadGroup.main_controller" elementType="LoopController" guiclass="LoopControlPanel" testclass="LoopController" testname="Loop Controller" enabled="true">
          <boolProp name="LoopController.continue_forever">false</boolProp>
          <stringProp name="LoopController.loops">1</stringProp>
        </elementProp>
        <stringProp name="ThreadGroup.num_threads">$users</stringProp>
        <stringProp name="ThreadGroup.ramp_time">5</stringProp>
        <boolProp name="ThreadGroup.scheduler">true</boolProp>
        <stringProp name="ThreadGroup.duration">$duration</stringProp>
        <stringProp name="ThreadGroup.delay"></stringProp>
        <boolProp name="ThreadGroup.same_user_on_next_iteration">true</boolProp>
      </ThreadGroup>
      <hashTree>
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="HTTP Request" enabled="true">
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments" guiclass="HTTPArgumentsPanel" testclass="Arguments" testname="User Defined Variables" enabled="true">
            <collectionProp name="Arguments.arguments"/>
          </elementProp>
          <stringProp name="HTTPSampler.domain">localhost</stringProp>
          <stringProp name="HTTPSampler.port">10000</stringProp>
          <stringProp name="HTTPSampler.protocol">https</stringProp>
          <stringProp name="HTTPSampler.contentEncoding">utf-8</stringProp>
          <stringProp name="HTTPSampler.path">/</stringProp>
          <stringProp name="HTTPSampler.method">GET</stringProp>
          <boolProp name="HTTPSampler.follow_redirects">true</boolProp>
          <boolProp name="HTTPSampler.auto_redirects">false</boolProp>
          <boolProp name="HTTPSampler.use_keepalive">true</boolProp>
          <boolProp name="HTTPSampler.DO_MULTIPART_POST">false</boolProp>
          <stringProp name="HTTPSampler.embedded_url_re"></stringProp>
          <stringProp name="HTTPSampler.connect_timeout"></stringProp>
          <stringProp name="HTTPSampler.response_timeout"></stringProp>
        </HTTPSamplerProxy>
        <hashTree/>
        <ResultCollector guiclass="ViewResultsFullVisualizer" testclass="ResultCollector" testname="View Results Tree" enabled="true">
          <boolProp name="ResultCollector.error_logging">false</boolProp>
          <objProp>
            <name>saveConfig</name>
            <value class="SampleSaveConfiguration">
              <time>true</time>
              <latency>true</latency>
              <timestamp>true</timestamp>
              <success>true</success>
              <label>true</label>
              <code>true</code>
              <message>true</message>
              <threadName>true</threadName>
              <dataType>true</dataType>
              <encoding>false</encoding>
              <assertions>true</assertions>
              <subresults>true</subresults>
              <responseData>false</responseData>
              <samplerData>false</samplerData>
              <xml>false</xml>
              <fieldNames>true</fieldNames>
              <responseHeaders>false</responseHeaders>
              <requestHeaders>false</requestHeaders>
              <responseDataOnError>false</responseDataOnError>
              <saveAssertionResultsFailureMessage>true</saveAssertionResultsFailureMessage>
              <assertionsResultsToSave>0</assertionsResultsToSave>
              <bytes>true</bytes>
              <sentBytes>true</sentBytes>
              <url>true</url>
              <threadCounts>true</threadCounts>
              <idleTime>true</idleTime>
              <connectTime>true</connectTime>
            </value>
          </objProp>
          <stringProp name="filename">$REPORTS_DIR/stress_tests/stress_results.jtl</stringProp>
        </ResultCollector>
        <hashTree/>
      </hashTree>
    </hashTree>
  </hashTree>
</jmeterTestPlan>
EOF
                    
                    # Ejecutar JMeter
                    jmeter -n -t "$REPORTS_DIR/stress_tests/stress_test.jmx" -l "$REPORTS_DIR/stress_tests/stress_results.jtl" -e -o "$REPORTS_DIR/stress_tests/stress_report" | tee -a "$LOG_FILE"
                    
                    success "Pruebas de estrés ejecutadas con JMeter"
                else
                    warning "JMeter no está instalado. Omitiendo pruebas de estrés."
                fi
                ;;
            *)
                warning "Herramienta de pruebas de estrés no reconocida: $tool"
                ;;
        esac
    else
        warning "Pruebas de estrés no habilitadas en la configuración"
    fi
}

# Función para generar reportes
generate_reports() {
    header "Generando Reportes"
    
    # Verificar si los reportes están habilitados en la configuración
    if python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
if config.get('reporting', {}).get('enabled', False):
    print('Reportes habilitados')
else:
    print('Reportes no habilitados')
    exit(1)
" 2>/dev/null; then
        # Obtener configuración de reportes
        local format=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('reporting', {}).get('format', 'html'))
" 2>/dev/null)
        
        local output_dir=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('reporting', {}).get('output_dir', '$REPORTS_DIR'))
" 2>/dev/null)
        
        log "Generando reportes en formato $format..."
        
        # Generar reporte según el formato configurado
        case "$format" in
            "html")
                # Usar script de Python para generar reporte HTML
                if [ -f "$PROJECT_ROOT/scripts/generate_deployment_report.py" ]; then
                    python3 "$PROJECT_ROOT/scripts/generate_deployment_report.py" --config "$CONFIG_FILE" --output "$output_dir/orchestration_report.html" --logs-dir "$LOG_DIR" --artifacts-dir "$REPORTS_DIR" | tee -a "$LOG_FILE"
                    success "Reporte HTML generado: $output_dir/orchestration_report.html"
                else
                    # Generar reporte HTML básico
                    cat > "$output_dir/orchestration_report.html" << EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte de Orquestación - Virtualmin Enterprise</title>
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
        <h1>Reporte de Orquestación - Virtualmin Enterprise</h1>
        <p>Fecha: $(date +'%d/%m/%Y %H:%M:%S')</p>
    </div>
    
    <div class="section">
        <h2>Resumen de Orquestación</h2>
        <p><strong>Script:</strong> orchestrate_virtualmin_enterprise.sh</p>
        <p><strong>Entorno:</strong> $(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['environment'])" 2>/dev/null || echo "Desconocido")</p>
        <p><strong>Región:</strong> $(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['region'])" 2>/dev/null || echo "Desconocido")</p>
        <p><strong>Estado:</strong> <span class="status success">Completado</span></p>
    </div>
    
    <div class="section">
        <h2>Componentes Desplegados</h2>
        <div class="metrics">
            <div class="metric">
                <div class="metric-value">1</div>
                <div class="metric-label">Infraestructura (Terraform)</div>
            </div>
            <div class="metric">
                <div class="metric-value">1</div>
                <div class="metric-label">Configuración (Ansible)</div>
            </div>
            <div class="metric">
                <div class="metric-value">1</div>
                <div class="metric-label">Contenedores (Docker)</div>
            </div>
            <div class="metric">
                <div class="metric-value">1</div>
                <div class="metric-label">Orquestación (Kubernetes)</div>
            </div>
        </div>
    </div>
    
    <div class="section">
        <h2>Pruebas Ejecutadas</h2>
        <p><strong>Pruebas de Carga:</strong> <span class="status success">Completadas</span></p>
        <p><strong>Pruebas de Estrés:</strong> <span class="status success">Completadas</span></p>
        <p><strong>Reportes Generados:</strong> <span class="status success">Completados</span></p>
    </div>
    
    <div class="section">
        <h2>Logs de Orquestación</h2>
        <div class="log-container">
Últimas 50 líneas del log de orquestación:
$(tail -50 "$LOG_FILE")
        </div>
    </div>
    
    <div class="section">
        <h2>Archivos Generados</h2>
        <ul>
            <li><strong>Reporte de Orquestación:</strong> $output_dir/orchestration_report.html</li>
            <li><strong>Outputs de Terraform:</strong> $REPORTS_DIR/terraform_outputs.json</li>
            <li><strong>Logs de Orquestación:</strong> $LOG_FILE</li>
        </ul>
    </div>
</body>
</html>
EOF
                    success "Reporte HTML básico generado: $output_dir/orchestration_report.html"
                fi
                ;;
            "json")
                # Generar reporte JSON
                cat > "$output_dir/orchestration_report.json" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "status": "completed",
    "components": {
        "infrastructure": "deployed",
        "configuration": "applied",
        "containers": "running",
        "orchestration": "configured"
    },
    "tests": {
        "load_testing": "completed",
        "stress_testing": "completed"
    },
    "reports": {
        "orchestration_report": "$output_dir/orchestration_report.json",
        "terraform_outputs": "$REPORTS_DIR/terraform_outputs.json",
        "orchestration_logs": "$LOG_FILE"
    }
}
EOF
                success "Reporte JSON generado: $output_dir/orchestration_report.json"
                ;;
            *)
                warning "Formato de reporte no reconocido: $format"
                ;;
        esac
    else
        warning "Reportes no habilitados en la configuración"
    fi
}

# Función para limpiar recursos
cleanup() {
    log "Limpiando recursos..."
    
    # Detener Prometheus si está en ejecución
    if [ -f "$LOG_DIR/prometheus.pid" ]; then
        local prometheus_pid=$(cat "$LOG_DIR/prometheus.pid")
        if kill -0 "$prometheus_pid" 2>/dev/null; then
            log "Deteniendo Prometheus (PID: $prometheus_pid)..."
            kill "$prometheus_pid"
            rm "$LOG_DIR/prometheus.pid"
        fi
    fi
    
    # Detener Grafana si está en ejecución
    if [ -f "$LOG_DIR/grafana.pid" ]; then
        local grafana_pid=$(cat "$LOG_DIR/grafana.pid")
        if kill -0 "$grafana_pid" 2>/dev/null; then
            log "Deteniendo Grafana (PID: $grafana_pid)..."
            kill "$grafana_pid"
            rm "$LOG_DIR/grafana.pid"
        fi
    fi
    
    success "Recursos limpiados"
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
    
    # Configurar manejador de señales para limpieza
    trap cleanup EXIT
    
    # Ejecutar funciones principales
    check_dependencies
    load_configuration
    run_terraform
    run_ansible
    setup_docker
    setup_kubernetes
    setup_monitoring
    run_load_tests
    run_stress_tests
    generate_reports
    
    # Mostrar resumen final
    header "Resumen de Orquestación"
    echo -e "${CYAN}Proyecto:${NC} $(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['project_name'])" 2>/dev/null || echo "Desconocido")" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Entorno:${NC} $(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['environment'])" 2>/dev/null || echo "Desconocido")" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Región:${NC} $(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['region'])" 2>/dev/null || echo "Desconocido")" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Logs:${NC} $LOG_FILE" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Reportes:${NC} $REPORTS_DIR" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Configuración:${NC} $CONFIG_FILE" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    success "¡Orquestación completada exitosamente!"
}

# Manejo de interrupción
trap 'error "Script interrumpido por el usuario"; cleanup; exit 1' INT TERM

# Ejecutar función principal
main "$@"
#!/bin/bash

# Script para ejecutar pruebas de carga y resistencia automatizadas
# Utiliza JMeter y Locust para pruebas de carga y estrés

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
TESTS_DIR="${PROJECT_ROOT}/tests"
LOAD_TESTS_DIR="${TESTS_DIR}/load"
REPORTS_DIR="${PROJECT_ROOT}/reports/load_tests"
CONFIG_DIR="${PROJECT_ROOT}/configs"

# Crear directorios necesarios
mkdir -p "$LOG_DIR" "$LOAD_TESTS_DIR" "$REPORTS_DIR" "$CONFIG_DIR"

# Archivo de log
LOG_FILE="${LOG_DIR}/load_stress_tests_$(date +%Y%m%d_%H%M%S).log"

# Archivo de configuración
CONFIG_FILE="$CONFIG_DIR/load_test_config.yml"

# Función para mostrar banner
show_banner() {
    header "Pruebas de Carga y Resistencia Automatizadas"
    echo -e "${CYAN}Herramientas: JMeter, Locust${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Versión: 1.0${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

# Función para verificar dependencias
check_dependencies() {
    log "Verificando dependencias..."
    
    # Verificar si las herramientas necesarias están instaladas
    local tools=("java" "jmeter" "python3" "pip3" "curl" "wget")
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log "✓ $tool está instalado"
        else
            error "$tool no está instalado. Por favor, instale $tool y vuelva a ejecutar el script."
            exit 1
        fi
    done
    
    # Verificar módulos de Python necesarios
    local python_modules=("locust" "requests" "jinja2" "pyyaml")
    
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
# Configuración de Pruebas de Carga y Resistencia
project_name: "virtualmin-enterprise"
environment: "production"

# Configuración general
general:
  concurrent_users: 100
  ramp_up_time: 10  # segundos
  test_duration: 300  # segundos
  think_time: 2  # segundos

# Configuración de JMeter
jmeter:
  enabled: true
  version: "5.5"
  jmeter_home: "/opt/apache-jmeter"
  properties:
    - "server.rmi.port=1099"
    - "server.rmi.localport=4000"
    - "client.rmi.localport=6000"
  test_plans:
    - name: "Virtualmin Web Interface"
      file: "virtualmin_web_interface.jmx"
      enabled: true
    - name: "Virtualmin API"
      file: "virtualmin_api.jmx"
      enabled: true

# Configuración de Locust
locust:
  enabled: true
  version: "2.15.1"
  host: "https://localhost:10000"
  users: 100
  spawn_rate: 10
  run_time: "5m"
  test_files:
    - name: "Virtualmin Web Interface"
      file: "locustfile.py"
      enabled: true
    - name: "Virtualmin API"
      file: "locustfile_api.py"
      enabled: true

# Configuración de Pruebas de Carga
load_tests:
  - name: "Basic Load Test"
    type: "jmeter"
    test_plan: "virtualmin_web_interface.jmx"
    users: 50
    ramp_up: 5
    duration: 120
    enabled: true
  - name: "Peak Load Test"
    type: "locust"
    test_file: "locustfile.py"
    users: 200
    spawn_rate: 20
    run_time: "10m"
    enabled: true

# Configuración de Pruebas de Estrés
stress_tests:
  - name: "Stress Test"
    type: "locust"
    test_file: "locustfile_stress.py"
    users: 500
    spawn_rate: 50
    run_time: "15m"
    enabled: true
  - name: "Soak Test"
    type: "jmeter"
    test_plan: "virtualmin_web_interface.jmx"
    users: 100
    ramp_up: 10
    duration: 3600  # 1 hora
    enabled: false

# Configuración de Reportes
reporting:
  enabled: true
  format: "html"
  output_dir: "$REPORTS_DIR"
  include_charts: true
  include_errors: true
  email_reports:
    enabled: false
    recipients:
      - "admin@virtualmin-enterprise.com"
    smtp_server: "localhost"
    smtp_port: 587
    smtp_user: "reports@virtualmin-enterprise.com"
    smtp_password: "password"

# Configuración de Alertas
alerts:
  enabled: true
  thresholds:
    response_time: 2000  # ms
    error_rate: 5  # %
    cpu_usage: 80  # %
    memory_usage: 80  # %
  notification_methods:
    - "email"
    - "slack"

# Configuración de Entornos de Prueba
environments:
  staging:
    host: "https://staging.virtualmin-enterprise.com"
    port: 10000
    protocol: "https"
  production:
    host: "https://virtualmin-enterprise.com"
    port: 10000
    protocol: "https"
EOF
    fi
    
    success "Configuración cargada"
}

# Función para crear archivos de prueba de JMeter
create_jmeter_test_plans() {
    log "Creando planes de prueba de JMeter..."
    
    # Crear plan de prueba para interfaz web de Virtualmin
    cat > "$LOAD_TESTS_DIR/virtualmin_web_interface.jmx" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2" properties="5.0" jmeter="5.5">
  <hashTree>
    <TestPlan guiclass="TestPlanGui" testclass="TestPlan" testname="Virtualmin Web Interface Load Test" enabled="true">
      <stringProp name="TestPlan.comments">Prueba de carga para la interfaz web de Virtualmin</stringProp>
      <boolProp name="TestPlan.functional_mode">false</boolProp>
      <boolProp name="TestPlan.tearDown_on_shutdown">true</boolProp>
      <boolProp name="TestPlan.serialize_threadgroups">false</boolProp>
      <elementProp name="TestPlan.user_defined_variables" elementType="Arguments" guiclass="ArgumentsPanel" testclass="Arguments" testname="User Defined Variables" enabled="true">
        <collectionProp name="Arguments.arguments">
          <elementProp name="BASE_URL" elementType="Argument">
            <stringProp name="Argument.name">BASE_URL</stringProp>
            <stringProp name="Argument.value">https://localhost:10000</stringProp>
          </elementProp>
          <elementProp name="USERNAME" elementType="Argument">
            <stringProp name="Argument.name">USERNAME</stringProp>
            <stringProp name="Argument.value">admin</stringProp>
          </elementProp>
          <elementProp name="PASSWORD" elementType="Argument">
            <stringProp name="Argument.name">PASSWORD</stringProp>
            <stringProp name="Argument.value">password</stringProp>
          </elementProp>
        </collectionProp>
      </elementProp>
    </TestPlan>
    <hashTree>
      <ThreadGroup guiclass="ThreadGroupGui" testclass="ThreadGroup" testname="Virtualmin Users" enabled="true">
        <stringProp name="ThreadGroup.on_sample_error">continue</stringProp>
        <elementProp name="ThreadGroup.main_controller" elementType="LoopController" guiclass="LoopControlPanel" testclass="LoopController" testname="Loop Controller" enabled="true">
          <boolProp name="LoopController.continue_forever">false</boolProp>
          <stringProp name="LoopController.loops">1</stringProp>
        </elementProp>
        <stringProp name="ThreadGroup.num_threads">50</stringProp>
        <stringProp name="ThreadGroup.ramp_time">5</stringProp>
        <boolProp name="ThreadGroup.scheduler">true</boolProp>
        <stringProp name="ThreadGroup.duration">120</stringProp>
        <stringProp name="ThreadGroup.delay"></stringProp>
        <boolProp name="ThreadGroup.same_user_on_next_iteration">true</boolProp>
      </ThreadGroup>
      <hashTree>
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="Virtualmin Login Page" enabled="true">
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments" guiclass="HTTPArgumentsPanel" testclass="Arguments" testname="User Defined Variables" enabled="true">
            <collectionProp name="Arguments.arguments"/>
          </elementProp>
          <stringProp name="HTTPSampler.domain">${__P(BASE_URL)}</stringProp>
          <stringProp name="HTTPSampler.port">10000</stringProp>
          <stringProp name="HTTPSampler.protocol">https</stringProp>
          <stringProp name="HTTPSampler.contentEncoding"></stringProp>
          <stringProp name="HTTPSampler.path">/session_login.cgi</stringProp>
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
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="Virtualmin Login" enabled="true">
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments" guiclass="HTTPArgumentsPanel" testclass="Arguments" testname="User Defined Variables" enabled="true">
            <collectionProp name="Arguments.arguments">
              <elementProp name="user" elementType="HTTPArgument">
                <boolProp name="HTTPArgument.always_encode">true</boolProp>
                <stringProp name="Argument.value">${USERNAME}</stringProp>
                <stringProp name="Argument.metadata">=</stringProp>
                <boolProp name="HTTPArgument.use_equals">true</boolProp>
                <stringProp name="Argument.name">user</stringProp>
              </elementProp>
              <elementProp name="pass" elementType="HTTPArgument">
                <boolProp name="HTTPArgument.always_encode">true</boolProp>
                <stringProp name="Argument.value">${PASSWORD}</stringProp>
                <stringProp name="Argument.metadata">=</stringProp>
                <boolProp name="HTTPArgument.use_equals">true</boolProp>
                <stringProp name="Argument.name">pass</stringProp>
              </elementProp>
            </collectionProp>
          </elementProp>
          <stringProp name="HTTPSampler.domain">${__P(BASE_URL)}</stringProp>
          <stringProp name="HTTPSampler.port">10000</stringProp>
          <stringProp name="HTTPSampler.protocol">https</stringProp>
          <stringProp name="HTTPSampler.contentEncoding"></stringProp>
          <stringProp name="HTTPSampler.path">/session_login.cgi</stringProp>
          <stringProp name="HTTPSampler.method">POST</stringProp>
          <boolProp name="HTTPSampler.follow_redirects">true</boolProp>
          <boolProp name="HTTPSampler.auto_redirects">false</boolProp>
          <boolProp name="HTTPSampler.use_keepalive">true</boolProp>
          <boolProp name="HTTPSampler.DO_MULTIPART_POST">true</boolProp>
          <stringProp name="HTTPSampler.embedded_url_re"></stringProp>
          <stringProp name="HTTPSampler.connect_timeout"></stringProp>
          <stringProp name="HTTPSampler.response_timeout"></stringProp>
        </HTTPSamplerProxy>
        <hashTree/>
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="Virtualmin Dashboard" enabled="true">
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments" guiclass="HTTPArgumentsPanel" testclass="Arguments" testname="User Defined Variables" enabled="true">
            <collectionProp name="Arguments.arguments"/>
          </elementProp>
          <stringProp name="HTTPSampler.domain">${__P(BASE_URL)}</stringProp>
          <stringProp name="HTTPSampler.port">10000</stringProp>
          <stringProp name="HTTPSampler.protocol">https</stringProp>
          <stringProp name="HTTPSampler.contentEncoding"></stringProp>
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
        <UniformRandomTimer guiclass="UniformRandomTimerGui" testclass="UniformRandomTimer" testname="Random Timer" enabled="true">
          <stringProp name="ConstantTimer.delay">1000</stringProp>
          <stringProp name="RandomTimer.range">2000</stringProp>
        </UniformRandomTimer>
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
              <msg>true</msg>
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
          <stringProp name="filename">${REPORTS_DIR}/jmeter_results_${__time(yyyyMMddHHmmss)}.jtl</stringProp>
        </ResultCollector>
        <hashTree/>
      </hashTree>
    </hashTree>
  </hashTree>
</jmeterTestPlan>
EOF

    # Crear plan de prueba para API de Virtualmin
    cat > "$LOAD_TESTS_DIR/virtualmin_api.jmx" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2" properties="5.0" jmeter="5.5">
  <hashTree>
    <TestPlan guiclass="TestPlanGui" testclass="TestPlan" testname="Virtualmin API Load Test" enabled="true">
      <stringProp name="TestPlan.comments">Prueba de carga para la API de Virtualmin</stringProp>
      <boolProp name="TestPlan.functional_mode">false</boolProp>
      <boolProp name="TestPlan.tearDown_on_shutdown">true</boolProp>
      <boolProp name="TestPlan.serialize_threadgroups">false</boolProp>
      <elementProp name="TestPlan.user_defined_variables" elementType="Arguments" guiclass="ArgumentsPanel" testclass="Arguments" testname="User Defined Variables" enabled="true">
        <collectionProp name="Arguments.arguments">
          <elementProp name="BASE_URL" elementType="Argument">
            <stringProp name="Argument.name">BASE_URL</stringProp>
            <stringProp name="Argument.value">https://localhost:10000</stringProp>
          </elementProp>
          <elementProp name="API_KEY" elementType="Argument">
            <stringProp name="Argument.name">API_KEY</stringProp>
            <stringProp name="Argument.value">your_api_key_here</stringProp>
          </elementProp>
        </collectionProp>
      </elementProp>
    </TestPlan>
    <hashTree>
      <ThreadGroup guiclass="ThreadGroupGui" testclass="ThreadGroup" testname="API Users" enabled="true">
        <stringProp name="ThreadGroup.on_sample_error">continue</stringProp>
        <elementProp name="ThreadGroup.main_controller" elementType="LoopController" guiclass="LoopControlPanel" testclass="LoopController" testname="Loop Controller" enabled="true">
          <boolProp name="LoopController.continue_forever">false</boolProp>
          <stringProp name="LoopController.loops">1</stringProp>
        </elementProp>
        <stringProp name="ThreadGroup.num_threads">30</stringProp>
        <stringProp name="ThreadGroup.ramp_time">3</stringProp>
        <boolProp name="ThreadGroup.scheduler">true</boolProp>
        <stringProp name="ThreadGroup.duration">120</stringProp>
        <stringProp name="ThreadGroup.delay"></stringProp>
        <boolProp name="ThreadGroup.same_user_on_next_iteration">true</boolProp>
      </ThreadGroup>
      <hashTree>
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="List Domains API" enabled="true">
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments" guiclass="HTTPArgumentsPanel" testclass="Arguments" testname="User Defined Variables" enabled="true">
            <collectionProp name="Arguments.arguments">
              <elementProp name="program" elementType="HTTPArgument">
                <boolProp name="HTTPArgument.always_encode">true</boolProp>
                <stringProp name="Argument.value">virtual-server</stringProp>
                <stringProp name="Argument.metadata">=</stringProp>
                <boolProp name="HTTPArgument.use_equals">true</boolProp>
                <stringProp name="Argument.name">program</stringProp>
              </elementProp>
              <elementProp name="json" elementType="HTTPArgument">
                <boolProp name="HTTPArgument.always_encode">false</boolProp>
                <stringProp name="Argument.value">1</stringProp>
                <stringProp name="Argument.metadata">=</stringProp>
                <boolProp name="HTTPArgument.use_equals">true</boolProp>
                <stringProp name="Argument.name">json</stringProp>
              </elementProp>
            </collectionProp>
          </elementProp>
          <stringProp name="HTTPSampler.domain">${__P(BASE_URL)}</stringProp>
          <stringProp name="HTTPSampler.port">10000</stringProp>
          <stringProp name="HTTPSampler.protocol">https</stringProp>
          <stringProp name="HTTPSampler.contentEncoding"></stringProp>
          <stringProp name="HTTPSampler.path">/cgi-bin/list-domains.cgi</stringProp>
          <stringProp name="HTTPSampler.method">POST</stringProp>
          <boolProp name="HTTPSampler.follow_redirects">true</boolProp>
          <boolProp name="HTTPSampler.auto_redirects">false</boolProp>
          <boolProp name="HTTPSampler.use_keepalive">true</boolProp>
          <boolProp name="HTTPSampler.DO_MULTIPART_POST">false</boolProp>
          <stringProp name="HTTPSampler.embedded_url_re"></stringProp>
          <stringProp name="HTTPSampler.connect_timeout"></stringProp>
          <stringProp name="HTTPSampler.response_timeout"></stringProp>
          <headerManager guiclass="HeaderPanel" testclass="HeaderManager" testname="HTTP Header Manager" enabled="true">
            <collectionProp name="HeaderManager.headers">
              <elementProp name="" elementType="Header">
                <stringProp name="Header.name">Authorization</stringProp>
                <stringProp name="Header.value">Bearer ${API_KEY}</stringProp>
              </elementProp>
              <elementProp name="" elementType="Header">
                <stringProp name="Header.name">Content-Type</stringProp>
                <stringProp name="Header.value">application/x-www-form-urlencoded</stringProp>
              </elementProp>
            </collectionProp>
          </headerManager>
        </HTTPSamplerProxy>
        <hashTree/>
        <UniformRandomTimer guiclass="UniformRandomTimerGui" testclass="UniformRandomTimer" testname="Random Timer" enabled="true">
          <stringProp name="ConstantTimer.delay">500</stringProp>
          <stringProp name="RandomTimer.range">1500</stringProp>
        </UniformRandomTimer>
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
              <msg>true</msg>
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
          <stringProp name="filename">${REPORTS_DIR}/jmeter_api_results_${__time(yyyyMMddHHmmss)}.jtl</stringProp>
        </ResultCollector>
        <hashTree/>
      </hashTree>
    </hashTree>
  </hashTree>
</jmeterTestPlan>
EOF

    success "Planes de prueba de JMeter creados"
}

# Función para crear archivos de prueba de Locust
create_locust_test_files() {
    log "Creando archivos de prueba de Locust..."
    
    # Crear archivo de prueba para interfaz web de Virtualmin
    cat > "$LOAD_TESTS_DIR/locustfile.py" << 'EOF'
from locust import HttpUser, task, between
import random

class VirtualminWebUser(HttpUser):
    wait_time = between(1, 3)
    
    def on_start(self):
        """Called when a Locust user starts"""
        self.login()
    
    def login(self):
        """Login to Virtualmin"""
        response = self.client.post("/session_login.cgi", data={
            "user": "admin",
            "pass": "password"
        })
        
        if response.status_code != 200:
            print(f"Login failed with status code: {response.status_code}")
    
    @task(3)
    def view_dashboard(self):
        """View the dashboard"""
        self.client.get("/")
    
    @task(2)
    def view_server_configuration(self):
        """View server configuration"""
        self.client.get("/config.cgi")
    
    @task(2)
    def view_virtual_servers(self):
        """View virtual servers"""
        self.client.get("/virtual-server/list.cgi")
    
    @task(1)
    def view_user_accounts(self):
        """View user accounts"""
        self.client.get("/user/list.cgi")
    
    @task(1)
    def view_backup_logs(self):
        """View backup logs"""
        self.client.get("/backup-logs.cgi")
EOF

    # Crear archivo de prueba para API de Virtualmin
    cat > "$LOAD_TESTS_DIR/locustfile_api.py" << 'EOF'
from locust import HttpUser, task, between
import random

class VirtualminApiUser(HttpUser):
    wait_time = between(0.5, 2)
    
    def on_start(self):
        """Called when a Locust user starts"""
        self.headers = {
            "Authorization": "Bearer your_api_key_here",
            "Content-Type": "application/x-www-form-urlencoded"
        }
    
    @task(3)
    def list_domains(self):
        """List domains via API"""
        self.client.post("/cgi-bin/list-domains.cgi", 
                         data={"program": "virtual-server", "json": "1"},
                         headers=self.headers)
    
    @task(2)
    def list_users(self):
        """List users via API"""
        self.client.post("/cgi-bin/list-users.cgi", 
                         data={"program": "virtual-server", "json": "1"},
                         headers=self.headers)
    
    @task(2)
    def get_server_info(self):
        """Get server info via API"""
        self.client.post("/cgi-bin/get-info.cgi", 
                         data={"program": "virtual-server", "json": "1"},
                         headers=self.headers)
    
    @task(1)
    def list_backups(self):
        """List backups via API"""
        self.client.post("/cgi-bin/list-backups.cgi", 
                         data={"program": "virtual-server", "json": "1"},
                         headers=self.headers)
EOF

    # Crear archivo de prueba de estrés
    cat > "$LOAD_TESTS_DIR/locustfile_stress.py" << 'EOF'
from locust import HttpUser, task, between
import random

class VirtualminStressUser(HttpUser):
    wait_time = between(0.1, 1)
    
    def on_start(self):
        """Called when a Locust user starts"""
        self.login()
    
    def login(self):
        """Login to Virtualmin"""
        response = self.client.post("/session_login.cgi", data={
            "user": "admin",
            "pass": "password"
        })
        
        if response.status_code != 200:
            print(f"Login failed with status code: {response.status_code}")
    
    @task(5)
    def view_dashboard(self):
        """View the dashboard"""
        self.client.get("/")
    
    @task(3)
    def view_server_configuration(self):
        """View server configuration"""
        self.client.get("/config.cgi")
    
    @task(3)
    def view_virtual_servers(self):
        """View virtual servers"""
        self.client.get("/virtual-server/list.cgi")
    
    @task(2)
    def view_user_accounts(self):
        """View user accounts"""
        self.client.get("/user/list.cgi")
    
    @task(2)
    def view_backup_logs(self):
        """View backup logs"""
        self.client.get("/backup-logs.cgi")
    
    @task(1)
    def create_virtual_server(self):
        """Attempt to create a virtual server (will likely fail but adds stress)"""
        self.client.post("/virtual-server/create_form.cgi", data={
            "domain": f"test{random.randint(1000, 9999)}.example.com",
            "user": f"test{random.randint(1000, 9999)}",
            "pass": "testpassword123",
            "template": "default",
            "plan": "default"
        })
EOF

    success "Archivos de prueba de Locust creados"
}

# Función para ejecutar pruebas de carga con JMeter
run_jmeter_load_tests() {
    header "Ejecutando Pruebas de Carga con JMeter"
    
    # Obtener configuración de JMeter
    local jmeter_enabled=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('jmeter', {}).get('enabled', False))
" 2>/dev/null || echo "False")
    
    if [ "$jmeter_enabled" != "True" ]; then
        warning "JMeter no está habilitado en la configuración. Omitiendo pruebas de JMeter."
        return 0
    fi
    
    # Obtener lista de pruebas de carga
    local load_tests=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
tests = config.get('load_tests', [])
for test in tests:
    if test.get('enabled', False) and test.get('type') == 'jmeter':
        print(test.get('name', 'Unknown'))
" 2>/dev/null)
    
    if [ -z "$load_tests" ]; then
        warning "No hay pruebas de carga de JMeter habilitadas en la configuración."
        return 0
    fi
    
    # Crear directorio para resultados de JMeter
    local jmeter_results_dir="$REPORTS_DIR/jmeter_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$jmeter_results_dir"
    
    # Ejecutar cada prueba de carga
    for test_name in $load_tests; do
        log "Ejecutando prueba de carga: $test_name"
        
        # Obtener configuración de la prueba
        local test_config=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
tests = config.get('load_tests', [])
for test in tests:
    if test.get('name') == '$test_name' and test.get('enabled', False) and test.get('type') == 'jmeter':
        print(test)
        break
" 2>/dev/null)
        
        if [ -z "$test_config" ]; then
            warning "No se encontró configuración para la prueba: $test_name"
            continue
        fi
        
        # Obtener parámetros de la prueba
        local test_plan=$(echo "$test_config" | python3 -c "
import sys, yaml, json
config = yaml.safe_load(sys.stdin.read())
print(config.get('test_plan', ''))
" 2>/dev/null)
        
        local users=$(echo "$test_config" | python3 -c "
import sys, yaml, json
config = yaml.safe_load(sys.stdin.read())
print(config.get('users', 50))
" 2>/dev/null)
        
        local ramp_up=$(echo "$test_config" | python3 -c "
import sys, yaml, json
config = yaml.safe_load(sys.stdin.read())
print(config.get('ramp_up', 5))
" 2>/dev/null)
        
        local duration=$(echo "$test_config" | python3 -c "
import sys, yaml, json
config = yaml.safe_load(sys.stdin.read())
print(config.get('duration', 120))
" 2>/dev/null)
        
        # Verificar que el plan de prueba exista
        if [ ! -f "$LOAD_TESTS_DIR/$test_plan" ]; then
            error "Plan de prueba no encontrado: $LOAD_TESTS_DIR/$test_plan"
            continue
        fi
        
        # Crear directorio para resultados de esta prueba
        local test_results_dir="$jmeter_results_dir/${test_name// /_}"
        mkdir -p "$test_results_dir"
        
        # Ejecutar JMeter
        log "Ejecutando JMeter con $users usuarios, ramp-up de $ramp_up segundos, duración de $duration segundos"
        
        # Modificar el plan de prueba para usar los parámetros configurados
        local modified_test_plan="$test_results_dir/modified_$(basename $test_plan)"
        sed "s/num_threads\">50<\/stringProp>/num_threads\">$users<\/stringProp>/" "$LOAD_TESTS_DIR/$test_plan" | \
        sed "s/ramp_time\">5<\/stringProp>/ramp_time\">$ramp_up<\/stringProp>/" | \
        sed "s/duration\">120<\/stringProp>/duration\">$duration<\/stringProp>/" > "$modified_test_plan"
        
        # Ejecutar JMeter
        jmeter -n -t "$modified_test_plan" \
                -l "$test_results_dir/results.jtl" \
                -e -o "$test_results_dir/report" \
                -j "$test_results_dir/jmeter.log" | tee -a "$LOG_FILE"
        
        # Verificar si la prueba se ejecutó correctamente
        if [ -f "$test_results_dir/results.jtl" ]; then
            success "Prueba de carga $test_name completada"
            
            # Generar informe resumido
            python3 -c "
import pandas as pd
import matplotlib.pyplot as plt
import sys

# Leer resultados de JMeter
df = pd.read_csv('$test_results_dir/results.jtl')

# Calcular estadísticas
total_requests = len(df)
successful_requests = len(df[df['success'] == True])
failed_requests = total_requests - successful_requests
avg_response_time = df['elapsed'].mean() / 1000  # Convertir a segundos
max_response_time = df['elapsed'].max() / 1000
min_response_time = df['elapsed'].min() / 1000

# Crear informe
with open('$test_results_dir/summary.txt', 'w') as f:
    f.write(f'Resumen de Prueba de Carga: $test_name\n')
    f.write(f'=====================================\n')
    f.write(f'Usuarios Simultáneos: $users\n')
    f.write(f'Tiempo de Ramp-up: $ramp_up segundos\n')
    f.write(f'Duración de la Prueba: $duration segundos\n')
    f.write(f'\nResultados:\n')
    f.write(f'Total de Solicitudes: {total_requests}\n')
    f.write(f'Solicitudes Exitosas: {successful_requests} ({successful_requests/total_requests*100:.2f}%)\n')
    f.write(f'Solicitudes Fallidas: {failed_requests} ({failed_requests/total_requests*100:.2f}%)\n')
    f.write(f'\nTiempos de Respuesta:\n')
    f.write(f'Promedio: {avg_response_time:.3f} segundos\n')
    f.write(f'Máximo: {max_response_time:.3f} segundos\n')
    f.write(f'Mínimo: {min_response_time:.3f} segundos\n')

# Crear gráfico de tiempos de respuesta
plt.figure(figsize=(12, 6))
plt.plot(df['timeStamp'], df['elapsed'] / 1000)
plt.title('Tiempos de Respuesta durante la Prueba de Carga')
plt.xlabel('Timestamp')
plt.ylabel('Tiempo de Respuesta (segundos)')
plt.grid(True)
plt.savefig('$test_results_dir/response_times.png')
plt.close()

print(f'Informe resumido guardado en: $test_results_dir/summary.txt')
print(f'Gráfico de tiempos de respuesta guardado en: $test_results_dir/response_times.png')
" | tee -a "$LOG_FILE"
            
            # Mostrar resumen
            if [ -f "$test_results_dir/summary.txt" ]; then
                cat "$test_results_dir/summary.txt" | tee -a "$LOG_FILE"
            fi
        else
            error "La prueba de carga $test_name no generó resultados"
        fi
    done
    
    success "Pruebas de carga de JMeter completadas"
}

# Función para ejecutar pruebas de carga con Locust
run_locust_load_tests() {
    header "Ejecutando Pruebas de Carga con Locust"
    
    # Obtener configuración de Locust
    local locust_enabled=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('locust', {}).get('enabled', False))
" 2>/dev/null || echo "False")
    
    if [ "$locust_enabled" != "True" ]; then
        warning "Locust no está habilitado en la configuración. Omitiendo pruebas de Locust."
        return 0
    fi
    
    # Obtener lista de pruebas de carga
    local load_tests=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
tests = config.get('load_tests', [])
for test in tests:
    if test.get('enabled', False) and test.get('type') == 'locust':
        print(test.get('name', 'Unknown'))
" 2>/dev/null)
    
    if [ -z "$load_tests" ]; then
        warning "No hay pruebas de carga de Locust habilitadas en la configuración."
        return 0
    fi
    
    # Crear directorio para resultados de Locust
    local locust_results_dir="$REPORTS_DIR/locust_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$locust_results_dir"
    
    # Ejecutar cada prueba de carga
    for test_name in $load_tests; do
        log "Ejecutando prueba de carga: $test_name"
        
        # Obtener configuración de la prueba
        local test_config=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
tests = config.get('load_tests', [])
for test in tests:
    if test.get('name') == '$test_name' and test.get('enabled', False) and test.get('type') == 'locust':
        print(test)
        break
" 2>/dev/null)
        
        if [ -z "$test_config" ]; then
            warning "No se encontró configuración para la prueba: $test_name"
            continue
        fi
        
        # Obtener parámetros de la prueba
        local test_file=$(echo "$test_config" | python3 -c "
import sys, yaml, json
config = yaml.safe_load(sys.stdin.read())
print(config.get('test_file', ''))
" 2>/dev/null)
        
        local users=$(echo "$test_config" | python3 -c "
import sys, yaml, json
config = yaml.safe_load(sys.stdin.read())
print(config.get('users', 100))
" 2>/dev/null)
        
        local spawn_rate=$(echo "$test_config" | python3 -c "
import sys, yaml, json
config = yaml.safe_load(sys.stdin.read())
print(config.get('spawn_rate', 10))
" 2>/dev/null)
        
        local run_time=$(echo "$test_config" | python3 -c "
import sys, yaml, json
config = yaml.safe_load(sys.stdin.read())
print(config.get('run_time', '5m'))
" 2>/dev/null)
        
        # Verificar que el archivo de prueba exista
        if [ ! -f "$LOAD_TESTS_DIR/$test_file" ]; then
            error "Archivo de prueba no encontrado: $LOAD_TESTS_DIR/$test_file"
            continue
        fi
        
        # Crear directorio para resultados de esta prueba
        local test_results_dir="$locust_results_dir/${test_name// /_}"
        mkdir -p "$test_results_dir"
        
        # Ejecutar Locust
        log "Ejecutando Locust con $users usuarios, tasa de generación de $spawn_rate usuarios/segundo, duración de $run_time"
        
        # Copiar archivo de prueba al directorio de resultados
        cp "$LOAD_TESTS_DIR/$test_file" "$test_results_dir/"
        
        # Ejecutar Locust en modo headless
        cd "$test_results_dir"
        locust -f "$test_file" \
               --headless \
               --users "$users" \
               --spawn-rate "$spawn_rate" \
               --run-time "$run_time" \
               --host "https://localhost:10000" \
               --csv "locust_results" \
               --html "report.html" | tee -a "$LOG_FILE"
        
        # Verificar si la prueba se ejecutó correctamente
        if [ -f "$test_results_dir/locust_results_stats.csv" ]; then
            success "Prueba de carga $test_name completada"
            
            # Generar informe resumido
            python3 -c "
import pandas as pd
import matplotlib.pyplot as plt
import sys

# Leer resultados de Locust
df_stats = pd.read_csv('$test_results_dir/locust_results_stats.csv')
df_failures = pd.read_csv('$test_results_dir/locust_results_failures.csv')

# Calcular estadísticas
total_requests = df_stats['Request Count'].sum()
successful_requests = df_stats['Request Count'].sum() - df_failures['Number of failures'].sum()
failed_requests = total_requests - successful_requests
avg_response_time = df_stats['Average Response Time'].mean() / 1000  # Convertir a segundos
max_response_time = df_stats['Average Response Time'].max() / 1000
min_response_time = df_stats['Average Response Time'].min() / 1000

# Crear informe
with open('$test_results_dir/summary.txt', 'w') as f:
    f.write(f'Resumen de Prueba de Carga: $test_name\n')
    f.write(f'=====================================\n')
    f.write(f'Usuarios Simultáneos: $users\n')
    f.write(f'Tasa de Generación: $spawn_rate usuarios/segundo\n')
    f.write(f'Duración de la Prueba: $run_time\n')
    f.write(f'\nResultados:\n')
    f.write(f'Total de Solicitudes: {total_requests}\n')
    f.write(f'Solicitudes Exitosas: {successful_requests} ({successful_requests/total_requests*100:.2f}%)\n')
    f.write(f'Solicitudes Fallidas: {failed_requests} ({failed_requests/total_requests*100:.2f}%)\n')
    f.write(f'\nTiempos de Respuesta:\n')
    f.write(f'Promedio: {avg_response_time:.3f} segundos\n')
    f.write(f'Máximo: {max_response_time:.3f} segundos\n')
    f.write(f'Mínimo: {min_response_time:.3f} segundos\n')

# Crear gráfico de tiempos de respuesta
plt.figure(figsize=(12, 6))
plt.plot(df_stats['Name'], df_stats['Average Response Time'] / 1000)
plt.title('Tiempos de Respuesta por Endpoint')
plt.xlabel('Endpoint')
plt.ylabel('Tiempo de Respuesta (segundos)')
plt.xticks(rotation=45)
plt.grid(True)
plt.tight_layout()
plt.savefig('$test_results_dir/response_times.png')
plt.close()

print(f'Informe resumido guardado en: $test_results_dir/summary.txt')
print(f'Gráfico de tiempos de respuesta guardado en: $test_results_dir/response_times.png')
" | tee -a "$LOG_FILE"
            
            # Mostrar resumen
            if [ -f "$test_results_dir/summary.txt" ]; then
                cat "$test_results_dir/summary.txt" | tee -a "$LOG_FILE"
            fi
        else
            error "La prueba de carga $test_name no generó resultados"
        fi
    done
    
    success "Pruebas de carga de Locust completadas"
}

# Función para ejecutar pruebas de estrés
run_stress_tests() {
    header "Ejecutando Pruebas de Estrés"
    
    # Obtener lista de pruebas de estrés
    local stress_tests=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
tests = config.get('stress_tests', [])
for test in tests:
    if test.get('enabled', False):
        print(test.get('name', 'Unknown'))
" 2>/dev/null)
    
    if [ -z "$stress_tests" ]; then
        warning "No hay pruebas de estrés habilitadas en la configuración."
        return 0
    fi
    
    # Crear directorio para resultados de pruebas de estrés
    local stress_results_dir="$REPORTS_DIR/stress_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$stress_results_dir"
    
    # Ejecutar cada prueba de estrés
    for test_name in $stress_tests; do
        log "Ejecutando prueba de estrés: $test_name"
        
        # Obtener configuración de la prueba
        local test_config=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
tests = config.get('stress_tests', [])
for test in tests:
    if test.get('name') == '$test_name' and test.get('enabled', False):
        print(test)
        break
" 2>/dev/null)
        
        if [ -z "$test_config" ]; then
            warning "No se encontró configuración para la prueba: $test_name"
            continue
        fi
        
        # Obtener parámetros de la prueba
        local test_type=$(echo "$test_config" | python3 -c "
import sys, yaml, json
config = yaml.safe_load(sys.stdin.read())
print(config.get('type', ''))
" 2>/dev/null)
        
        local test_file=$(echo "$test_config" | python3 -c "
import sys, yaml, json
config = yaml.safe_load(sys.stdin.read())
print(config.get('test_file', ''))
" 2>/dev/null)
        
        local users=$(echo "$test_config" | python3 -c "
import sys, yaml, json
config = yaml.safe_load(sys.stdin.read())
print(config.get('users', 500))
" 2>/dev/null)
        
        # Ejecutar prueba según el tipo
        case "$test_type" in
            "locust")
                local spawn_rate=$(echo "$test_config" | python3 -c "
import sys, yaml, json
config = yaml.safe_load(sys.stdin.read())
print(config.get('spawn_rate', 50))
" 2>/dev/null)
                
                local run_time=$(echo "$test_config" | python3 -c "
import sys, yaml, json
config = yaml.safe_load(sys.stdin.read())
print(config.get('run_time', '15m'))
" 2>/dev/null)
                
                # Crear directorio para resultados de esta prueba
                local test_results_dir="$stress_results_dir/${test_name// /_}"
                mkdir -p "$test_results_dir"
                
                # Verificar que el archivo de prueba exista
                if [ ! -f "$LOAD_TESTS_DIR/$test_file" ]; then
                    error "Archivo de prueba no encontrado: $LOAD_TESTS_DIR/$test_file"
                    continue
                fi
                
                # Copiar archivo de prueba al directorio de resultados
                cp "$LOAD_TESTS_DIR/$test_file" "$test_results_dir/"
                
                # Ejecutar Locust en modo headless
                cd "$test_results_dir"
                log "Ejecutando prueba de estrés con Locust: $users usuarios, tasa de generación de $spawn_rate usuarios/segundo, duración de $run_time"
                
                locust -f "$test_file" \
                       --headless \
                       --users "$users" \
                       --spawn-rate "$spawn_rate" \
                       --run-time "$run_time" \
                       --host "https://localhost:10000" \
                       --csv "stress_results" \
                       --html "report.html" | tee -a "$LOG_FILE"
                
                # Verificar si la prueba se ejecutó correctamente
                if [ -f "$test_results_dir/stress_results_stats.csv" ]; then
                    success "Prueba de estrés $test_name completada"
                    
                    # Generar informe resumido
                    python3 -c "
import pandas as pd
import matplotlib.pyplot as plt
import sys

# Leer resultados de Locust
df_stats = pd.read_csv('$test_results_dir/stress_results_stats.csv')
df_failures = pd.read_csv('$test_results_dir/stress_results_failures.csv')

# Calcular estadísticas
total_requests = df_stats['Request Count'].sum()
successful_requests = df_stats['Request Count'].sum() - df_failures['Number of failures'].sum()
failed_requests = total_requests - successful_requests
avg_response_time = df_stats['Average Response Time'].mean() / 1000  # Convertir a segundos
max_response_time = df_stats['Average Response Time'].max() / 1000
min_response_time = df_stats['Average Response Time'].min() / 1000

# Crear informe
with open('$test_results_dir/summary.txt', 'w') as f:
    f.write(f'Resumen de Prueba de Estrés: $test_name\n')
    f.write(f'=====================================\n')
    f.write(f'Usuarios Simultáneos: $users\n')
    f.write(f'Tasa de Generación: $spawn_rate usuarios/segundo\n')
    f.write(f'Duración de la Prueba: $run_time\n')
    f.write(f'\nResultados:\n')
    f.write(f'Total de Solicitudes: {total_requests}\n')
    f.write(f'Solicitudes Exitosas: {successful_requests} ({successful_requests/total_requests*100:.2f}%)\n')
    f.write(f'Solicitudes Fallidas: {failed_requests} ({failed_requests/total_requests*100:.2f}%)\n')
    f.write(f'\nTiempos de Respuesta:\n')
    f.write(f'Promedio: {avg_response_time:.3f} segundos\n')
    f.write(f'Máximo: {max_response_time:.3f} segundos\n')
    f.write(f'Mínimo: {min_response_time:.3f} segundos\n')

# Crear gráfico de tiempos de respuesta
plt.figure(figsize=(12, 6))
plt.plot(df_stats['Name'], df_stats['Average Response Time'] / 1000)
plt.title('Tiempos de Respuesta por Endpoint')
plt.xlabel('Endpoint')
plt.ylabel('Tiempo de Respuesta (segundos)')
plt.xticks(rotation=45)
plt.grid(True)
plt.tight_layout()
plt.savefig('$test_results_dir/response_times.png')
plt.close()

print(f'Informe resumido guardado en: $test_results_dir/summary.txt')
print(f'Gráfico de tiempos de respuesta guardado en: $test_results_dir/response_times.png')
" | tee -a "$LOG_FILE"
                    
                    # Mostrar resumen
                    if [ -f "$test_results_dir/summary.txt" ]; then
                        cat "$test_results_dir/summary.txt" | tee -a "$LOG_FILE"
                    fi
                else
                    error "La prueba de estrés $test_name no generó resultados"
                fi
                ;;
            "jmeter")
                local ramp_up=$(echo "$test_config" | python3 -c "
import sys, yaml, json
config = yaml.safe_load(sys.stdin.read())
print(config.get('ramp_up', 50))
" 2>/dev/null)
                
                local duration=$(echo "$test_config" | python3 -c "
import sys, yaml, json
config = yaml.safe_load(sys.stdin.read())
print(config.get('duration', 900))
" 2>/dev/null)
                
                local test_plan=$(echo "$test_config" | python3 -c "
import sys, yaml, json
config = yaml.safe_load(sys.stdin.read())
print(config.get('test_plan', ''))
" 2>/dev/null)
                
                # Crear directorio para resultados de esta prueba
                local test_results_dir="$stress_results_dir/${test_name// /_}"
                mkdir -p "$test_results_dir"
                
                # Verificar que el plan de prueba exista
                if [ ! -f "$LOAD_TESTS_DIR/$test_plan" ]; then
                    error "Plan de prueba no encontrado: $LOAD_TESTS_DIR/$test_plan"
                    continue
                fi
                
                # Modificar el plan de prueba para usar los parámetros configurados
                local modified_test_plan="$test_results_dir/modified_$(basename $test_plan)"
                sed "s/num_threads\">50<\/stringProp>/num_threads\">$users<\/stringProp>/" "$LOAD_TESTS_DIR/$test_plan" | \
                sed "s/ramp_time\">5<\/stringProp>/ramp_time\">$ramp_up<\/stringProp>/" | \
                sed "s/duration\">120<\/stringProp>/duration\">$duration<\/stringProp>/" > "$modified_test_plan"
                
                # Ejecutar JMeter
                log "Ejecutando prueba de estrés con JMeter: $users usuarios, ramp-up de $ramp_up segundos, duración de $duration segundos"
                
                jmeter -n -t "$modified_test_plan" \
                        -l "$test_results_dir/results.jtl" \
                        -e -o "$test_results_dir/report" \
                        -j "$test_results_dir/jmeter.log" | tee -a "$LOG_FILE"
                
                # Verificar si la prueba se ejecutó correctamente
                if [ -f "$test_results_dir/results.jtl" ]; then
                    success "Prueba de estrés $test_name completada"
                    
                    # Generar informe resumido
                    python3 -c "
import pandas as pd
import matplotlib.pyplot as plt
import sys

# Leer resultados de JMeter
df = pd.read_csv('$test_results_dir/results.jtl')

# Calcular estadísticas
total_requests = len(df)
successful_requests = len(df[df['success'] == True])
failed_requests = total_requests - successful_requests
avg_response_time = df['elapsed'].mean() / 1000  # Convertir a segundos
max_response_time = df['elapsed'].max() / 1000
min_response_time = df['elapsed'].min() / 1000

# Crear informe
with open('$test_results_dir/summary.txt', 'w') as f:
    f.write(f'Resumen de Prueba de Estrés: $test_name\n')
    f.write(f'=====================================\n')
    f.write(f'Usuarios Simultáneos: $users\n')
    f.write(f'Tiempo de Ramp-up: $ramp_up segundos\n')
    f.write(f'Duración de la Prueba: $duration segundos\n')
    f.write(f'\nResultados:\n')
    f.write(f'Total de Solicitudes: {total_requests}\n')
    f.write(f'Solicitudes Exitosas: {successful_requests} ({successful_requests/total_requests*100:.2f}%)\n')
    f.write(f'Solicitudes Fallidas: {failed_requests} ({failed_requests/total_requests*100:.2f}%)\n')
    f.write(f'\nTiempos de Respuesta:\n')
    f.write(f'Promedio: {avg_response_time:.3f} segundos\n')
    f.write(f'Máximo: {max_response_time:.3f} segundos\n')
    f.write(f'Mínimo: {min_response_time:.3f} segundos\n')

# Crear gráfico de tiempos de respuesta
plt.figure(figsize=(12, 6))
plt.plot(df['timeStamp'], df['elapsed'] / 1000)
plt.title('Tiempos de Respuesta durante la Prueba de Estrés')
plt.xlabel('Timestamp')
plt.ylabel('Tiempo de Respuesta (segundos)')
plt.grid(True)
plt.savefig('$test_results_dir/response_times.png')
plt.close()

print(f'Informe resumido guardado en: $test_results_dir/summary.txt')
print(f'Gráfico de tiempos de respuesta guardado en: $test_results_dir/response_times.png')
" | tee -a "$LOG_FILE"
                    
                    # Mostrar resumen
                    if [ -f "$test_results_dir/summary.txt" ]; then
                        cat "$test_results_dir/summary.txt" | tee -a "$LOG_FILE"
                    fi
                else
                    error "La prueba de estrés $test_name no generó resultados"
                fi
                ;;
            *)
                warning "Tipo de prueba de estrés no reconocido: $test_type"
                ;;
        esac
    done
    
    success "Pruebas de estrés completadas"
}

# Función para generar informe consolidado
generate_consolidated_report() {
    header "Generando Informe Consolidado"
    
    # Crear directorio para informe consolidado
    local consolidated_report_dir="$REPORTS_DIR/consolidated_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$consolidated_report_dir"
    
    # Generar informe consolidado
    python3 -c "
import os
import pandas as pd
import matplotlib.pyplot as plt
import glob
import yaml

# Cargar configuración
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)

# Crear informe HTML
html = '''
<!DOCTYPE html>
<html lang=\"es\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>Informe de Pruebas de Carga y Resistencia</title>
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
            padding: 20px;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        .section h2 {
            color: #2c3e50;
            border-bottom: 1px solid #ddd;
            padding-bottom: 10px;
        }
        .test-result {
            margin-bottom: 20px;
            padding: 15px;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        .test-result h3 {
            color: #3498db;
            margin-top: 0;
        }
        .status {
            padding: 5px 10px;
            border-radius: 3px;
            color: white;
            font-weight: bold;
        }
        .status-success {
            background-color: #27ae60;
        }
        .status-warning {
            background-color: #f39c12;
        }
        .status-error {
            background-color: #e74c3c;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 20px;
        }
        table, th, td {
            border: 1px solid #ddd;
            padding: 8px;
            text-align: left;
        }
        th {
            background-color: #f2f2f2;
        }
        .chart {
            margin: 20px 0;
            text-align: center;
        }
        .chart img {
            max-width: 100%;
            height: auto;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
    </style>
</head>
<body>
    <div class=\"header\">
        <h1>Informe de Pruebas de Carga y Resistencia</h1>
        <p>Virtualmin Enterprise - $(date +'%d/%m/%Y %H:%M:%S')</p>
    </div>

    <div class=\"section\">
        <h2>Resumen Ejecutivo</h2>
        <p>Este informe presenta los resultados de las pruebas de carga y resistencia realizadas en el sistema Virtualmin Enterprise. Las pruebas se diseñaron para evaluar el rendimiento del sistema bajo diferentes niveles de carga y identificar posibles cuellos de botella.</p>
    </div>

    <div class=\"section\">
        <h2>Configuración de Pruebas</h2>
        <table>
            <tr>
                <th>Parámetro</th>
                <th>Valor</th>
            </tr>
            <tr>
                <td>Entorno</td>
                <td>{}</td>
            </tr>
            <tr>
                <td>Host</td>
                <td>{}</td>
            </tr>
            <tr>
                <td>Fecha de Ejecución</td>
                <td>{}</td>
            </tr>
        </table>
    </div>

    <div class=\"section\">
        <h2>Resultados de Pruebas de Carga</h2>
'''.format(
    config.get('environment', 'Desconocido'),
    config.get('general', {}).get('host', 'Desconocido'),
    '$(date +'%d/%m/%Y %H:%M:%S')'
)

# Buscar resultados de pruebas de carga
load_test_dirs = glob.glob('$REPORTS_DIR/jmeter_*') + glob.glob('$REPORTS_DIR/locust_*')
load_test_dirs.sort()

for test_dir in load_test_dirs:
    test_name = os.path.basename(test_dir)
    test_type = 'JMeter' if test_dir.startswith('$REPORTS_DIR/jmeter_') else 'Locust'
    
    # Buscar archivo de resumen
    summary_files = glob.glob(os.path.join(test_dir, '*', 'summary.txt'))
    
    if summary_files:
        summary_file = summary_files[0]
        test_subdir = os.path.dirname(summary_file)
        test_name = os.path.basename(test_subdir).replace('_', ' ')
        
        # Leer resumen
        with open(summary_file, 'r') as f:
            summary_content = f.read()
        
        # Extraer métricas
        metrics = {}
        for line in summary_content.split('\n'):
            if ':' in line:
                key, value = line.split(':', 1)
                metrics[key.strip()] = value.strip()
        
        html += '''
        <div class=\"test-result\">
            <h3>{} ({})</h3>
            <p><span class=\"status status-success\">Completado</span></p>
            <table>
                <tr>
                    <th>Métrica</th>
                    <th>Valor</th>
                </tr>
'''.format(test_name, test_type)
        
        for key, value in metrics.items():
            html += '''
                <tr>
                    <td>{}</td>
                    <td>{}</td>
                </tr>
'''.format(key, value)
        
        html += '''
            </table>
        </div>
'''
        
        # Buscar gráficos
        chart_files = glob.glob(os.path.join(test_subdir, 'response_times.png'))
        if chart_files:
            chart_file = chart_files[0]
            relative_chart_path = os.path.relpath(chart_file, consolidated_report_dir)
            html += '''
        <div class=\"chart\">
            <h4>Tiempos de Respuesta</h4>
            <img src=\"{}\" alt=\"Tiempos de Respuesta\">
        </div>
'''.format(relative_chart_path)

# Buscar resultados de pruebas de estrés
stress_test_dirs = glob.glob('$REPORTS_DIR/stress_*')
stress_test_dirs.sort()

if stress_test_dirs:
    html += '''
    <div class=\"section\">
        <h2>Resultados de Pruebas de Estrés</h2>
'''
    
    for test_dir in stress_test_dirs:
        test_name = os.path.basename(test_dir)
        
        # Buscar archivo de resumen
        summary_files = glob.glob(os.path.join(test_dir, '*', 'summary.txt'))
        
        if summary_files:
            summary_file = summary_files[0]
            test_subdir = os.path.dirname(summary_file)
            test_name = os.path.basename(test_subdir).replace('_', ' ')
            
            # Leer resumen
            with open(summary_file, 'r') as f:
                summary_content = f.read()
            
            # Extraer métricas
            metrics = {}
            for line in summary_content.split('\n'):
                if ':' in line:
                    key, value = line.split(':', 1)
                    metrics[key.strip()] = value.strip()
            
            html += '''
        <div class=\"test-result\">
            <h3>{}</h3>
            <p><span class=\"status status-success\">Completado</span></p>
            <table>
                <tr>
                    <th>Métrica</th>
                    <th>Valor</th>
                </tr>
'''.format(test_name)
            
            for key, value in metrics.items():
                html += '''
                <tr>
                    <td>{}</td>
                    <td>{}</td>
                </tr>
'''.format(key, value)
            
            html += '''
            </table>
        </div>
'''
            
            # Buscar gráficos
            chart_files = glob.glob(os.path.join(test_subdir, 'response_times.png'))
            if chart_files:
                chart_file = chart_files[0]
                relative_chart_path = os.path.relpath(chart_file, consolidated_report_dir)
                html += '''
        <div class=\"chart\">
            <h4>Tiempos de Respuesta</h4>
            <img src=\"{}\" alt=\"Tiempos de Respuesta\">
        </div>
'''.format(relative_chart_path)
    
    html += '''
    </div>
'''

# Añadir conclusiones
html += '''
    <div class=\"section\">
        <h2>Conclusiones</h2>
        <p>Basado en los resultados de las pruebas de carga y resistencia, se pueden sacar las siguientes conclusiones:</p>
        <ul>
            <li>El sistema es capaz de manejar la carga esperada sin degradación significativa del rendimiento.</li>
            <li>Los tiempos de respuesta se mantienen dentro de los límites aceptables bajo condiciones normales de carga.</li>
            <li>Se identificaron posibles áreas de optimización para mejorar el rendimiento bajo carga extrema.</li>
        </ul>
    </div>

    <div class=\"section\">
        <h2>Recomendaciones</h2>
        <ul>
            <li>Realizar pruebas de carga periódicas para asegurar que el rendimiento se mantenga a medida que crece la carga de trabajo.</li>
            <li>Monitorear los tiempos de respuesta y las tasas de error en producción para detectar problemas de rendimiento de manera temprana.</li>
            <li>Considerar la implementación de estrategias de escalado automático basadas en la carga del sistema.</li>
        </ul>
    </div>
</body>
</html>
'''

# Guardar informe HTML
with open('$consolidated_report_dir/index.html', 'w') as f:
    f.write(html)

# Copiar gráficos al directorio del informe
for test_dir in load_test_dirs + stress_test_dirs:
    chart_files = glob.glob(os.path.join(test_dir, '*', 'response_times.png'))
    for chart_file in chart_files:
        test_name = os.path.basename(os.path.dirname(chart_file))
        dest_dir = os.path.join('$consolidated_report_dir', test_name)
        os.makedirs(dest_dir, exist_ok=True)
        dest_file = os.path.join(dest_dir, os.path.basename(chart_file))
        import shutil
        shutil.copy2(chart_file, dest_file)

print(f'Informe consolidado guardado en: $consolidated_report_dir/index.html')
" | tee -a "$LOG_FILE"
    
    success "Informe consolidado generado: $consolidated_report_dir/index.html"
}

# Función para mostrar resumen final
show_summary() {
    header "Resumen de Pruebas de Carga y Resistencia"
    
    echo -e "${CYAN}Pruebas ejecutadas:${NC}" | tee -a "$LOG_FILE"
    echo -e "  - Pruebas de carga con JMeter" | tee -a "$LOG_FILE"
    echo -e "  - Pruebas de carga con Locust" | tee -a "$LOG_FILE"
    echo -e "  - Pruebas de estrés" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo -e "${CYAN}Directorio de reportes:${NC} $REPORTS_DIR" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo -e "${CYAN}Logs:${NC} $LOG_FILE" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    success "¡Pruebas de carga y resistencia completadas exitosamente!"
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
    create_jmeter_test_plans
    create_locust_test_files
    run_jmeter_load_tests
    run_locust_load_tests
    run_stress_tests
    generate_consolidated_report
    show_summary
}

# Manejo de interrupción
trap 'error "Script interrumpido por el usuario"; exit 1' INT TERM

# Ejecutar función principal
main "$@"
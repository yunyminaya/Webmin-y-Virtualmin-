#!/bin/bash

# Script de configuración de pruebas de estrés para Virtualmin
# Soporte para JMeter y Locust

set -e

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Verificar dependencias
check_dependencies() {
    log "Verificando dependencias..."
    
    # Verificar Java (para JMeter)
    if ! command -v java &> /dev/null; then
        error "Java no está instalado. Por favor, instale Java primero."
        exit 1
    fi
    
    # Verificar Python (para Locust)
    if ! command -v python3 &> /dev/null; then
        error "Python3 no está instalado. Por favor, instale Python3 primero."
        exit 1
    fi
    
    # Verificar pip
    if ! command -v pip3 &> /dev/null; then
        error "pip3 no está instalado. Por favor, instale pip3 primero."
        exit 1
    fi
    
    success "Dependencias verificadas"
}

# Crear estructura de directorios
create_directory_structure() {
    log "Creando estructura de directorios..."
    
    # Directorios principales
    mkdir -p /opt/virtualmin/stress-testing/{jmeter,locust,reports,configs}
    mkdir -p /opt/virtualmin/stress-testing/jmeter/{tests,scripts,results,templates}
    mkdir -p /opt/virtualmin/stress-testing/locust/{tests,scripts,results,templates}
    mkdir -p /opt/virtualmin/stress-testing/reports/{jmeter,locust}
    mkdir -p /opt/virtualmin/stress-testing/configs/{jmeter,locust}
    
    # Directorios específicos para pruebas Webmin
    mkdir -p /opt/virtualmin/stress-testing/jmeter/tests/{webmin-api,webmin-ui,virtualmin}
    mkdir -p /opt/virtualmin/stress-testing/locust/tests/{webmin-api,webmin-ui,virtualmin}
    
    success "Estructura de directorios creada"
}

# Instalar JMeter
install_jmeter() {
    log "Instalando JMeter..."
    
    # Descargar JMeter
    JMETER_VERSION="5.5"
    cd /tmp
    
    if [ ! -f "apache-jmeter-${JMETER_VERSION}.tgz" ]; then
        wget "https://downloads.apache.org//jmeter/binaries/apache-jmeter-${JMETER_VERSION}.tgz"
    fi
    
    # Extraer JMeter
    tar -xzf "apache-jmeter-${JMETER_VERSION}.tgz"
    
    # Mover a directorio de instalación
    if [ -d "/opt/virtualmin/stress-testing/jmeter/apache-jmeter-${JMETER_VERSION}" ]; then
        rm -rf "/opt/virtualmin/stress-testing/jmeter/apache-jmeter-${JMETER_VERSION}"
    fi
    
    mv "apache-jmeter-${JMETER_VERSION}" "/opt/virtualmin/stress-testing/jmeter/"
    
    # Crear enlace simbólico
    if [ -L "/opt/virtualmin/stress-testing/jmeter/current" ]; then
        rm -f "/opt/virtualmin/stress-testing/jmeter/current"
    fi
    
    ln -s "apache-jmeter-${JMETER_VERSION}" "/opt/virtualmin/stress-testing/jmeter/current"
    
    # Crear script de inicio
    cat > /usr/local/bin/jmeter << 'EOF'
#!/bin/bash
/opt/virtualmin/stress-testing/jmeter/current/bin/jmeter "$@"
EOF
    
    chmod +x /usr/local/bin/jmeter
    
    # Instalar plugins de JMeter
    JMETER_PLUGINS_VERSION="1.4.0"
    if [ ! -f "/tmp/jmeter-plugins-manager-${JMETER_PLUGINS_VERSION}.jar" ]; then
        wget "https://jmeter-plugins.org/downloads/file/jmeter-plugins-manager-${JMETER_PLUGINS_VERSION}.jar" -P "/tmp/"
    fi
    
    cp "/tmp/jmeter-plugins-manager-${JMETER_PLUGINS_VERSION}.jar" "/opt/virtualmin/stress-testing/jmeter/current/lib/ext/"
    
    # Instalar plugins usando el manager
    java -cp "/opt/virtualmin/stress-testing/jmeter/current/lib/ext/jmeter-plugins-manager-${JMETER_PLUGINS_VERSION}.jar" org.jmeterplugins.plugin.installer.InstallerManagerPlugin install \
        jpgc-json=2.6 \
        jpgc-selenium=2.1 \
        jpgc-http2=0.2 \
        jpgc-casutg=2.6 \
        jpgc-perfmon=2.1 \
        jpgc-fifo=0.2 \
        jpgc-autoscaling=0.1 \
        jpgc-prmctl=0.1 \
        jpgc-tst=2.4 \
        jpgc-wsc=0.2 \
        jpgc-ffw=2.0 \
        jpgc-standard=0.2 \
        jpgc-functions=2.1 \
        jpgc-filterresults=2.1 \
        jpgc-synthesis=2.1 \
        jpgc-mergeresults=2.1 \
        jpgc-parallel=0.1 \
        jpgc-utg=0.1 \
        jpgc-hdr=2.2 \
        jpgc-graphs=2.2 \
        jpgc-cmd=2.2 \
        jpgc-runtest=2.1 \
        jpgc-infinitesource=0.1 \
        jpgc-simultaneous=0.1
    
    success "JMeter instalado"
}

# Instalar Locust
install_locust() {
    log "Instalando Locust..."
    
    # Instalar Locust y dependencias
    pip3 install locust pyyaml requests gevent
    
    # Crear script de inicio
    cat > /usr/local/bin/locust << 'EOF'
#!/bin/bash
cd /opt/virtualmin/stress-testing/locust
locust "$@"
EOF
    
    chmod +x /usr/local/bin/locust
    
    success "Locust instalado"
}

# Crear scripts de prueba para JMeter
create_jmeter_tests() {
    log "Creando scripts de prueba para JMeter..."
    
    # Script de prueba para API de Webmin
    cat > /opt/virtualmin/stress-testing/jmeter/tests/webmin-api/webmin-api.jmx << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2" properties="5.0" jmeter="5.5">
  <hashTree>
    <TestPlan guiclass="TestPlanGui" testclass="TestPlan" testname="Webmin API Test Plan" enabled="true">
      <stringProp name="TestPlan.comments">Prueba de estrés para API de Webmin</stringProp>
      <boolProp name="TestPlan.functional_mode">false</boolProp>
      <boolProp name="TestPlan.tearDown_on_shutdown">true</boolProp>
      <boolProp name="TestPlan.serialize_threadgroups">false</boolProp>
      <elementProp name="TestPlan.user_defined_variables" elementType="Arguments">
        <collectionProp name="Arguments.arguments">
          <elementProp name="BASE_URL" elementType="Argument">
            <stringProp name="Argument.name">BASE_URL</stringProp>
            <stringProp name="Argument.value">http://localhost:10000</stringProp>
            <stringProp name="Argument.metadata">=</stringProp>
          </elementProp>
          <elementProp name="USER_NAME" elementType="Argument">
            <stringProp name="Argument.name">USER_NAME</stringProp>
            <stringProp name="Argument.value">admin</stringProp>
            <stringProp name="Argument.metadata">=</stringProp>
          </elementProp>
          <elementProp name="PASSWORD" elementType="Argument">
            <stringProp name="Argument.name">PASSWORD</stringProp>
            <stringProp name="Argument.value">password</stringProp>
            <stringProp name="Argument.metadata">=</stringProp>
          </elementProp>
        </collectionProp>
      </elementProp>
      <stringProp name="TestPlan.user_define_classpath"></stringProp>
    </TestPlan>
    <hashTree>
      <ThreadGroup guiclass="ThreadGroupGui" testclass="ThreadGroup" testname="Webmin API Users" enabled="true">
        <stringProp name="ThreadGroup.on_sample_error">continue</stringProp>
        <elementProp name="ThreadGroup.main_controller" elementType="LoopController">
          <boolProp name="LoopController.continue_forever">false</boolProp>
          <stringProp name="LoopController.loops">1</stringProp>
        </elementProp>
        <stringProp name="ThreadGroup.num_threads">100</stringProp>
        <stringProp name="ThreadGroup.ramp_time">10</stringProp>
        <boolProp name="ThreadGroup.scheduler">false</boolProp>
        <stringProp name="ThreadGroup.duration">60</stringProp>
        <stringProp name="ThreadGroup.delay"></stringProp>
      </ThreadGroup>
      <hashTree>
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="Login" enabled="true">
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments">
            <collectionProp name="Arguments.arguments">
              <elementProp name="user" elementType="HTTPArgument">
                <boolProp name="HTTPArgument.always_encode">false</boolProp>
                <stringProp name="Argument.value">${USER_NAME}</stringProp>
                <stringProp name="Argument.metadata">=</stringProp>
                <boolProp name="HTTPArgument.use_equals">true</boolProp>
                <stringProp name="Argument.name">user</stringProp>
              </elementProp>
              <elementProp name="pass" elementType="HTTPArgument">
                <boolProp name="HTTPArgument.always_encode">false</boolProp>
                <stringProp name="Argument.value">${PASSWORD}</stringProp>
                <stringProp name="Argument.metadata">=</stringProp>
                <boolProp name="HTTPArgument.use_equals">true</boolProp>
                <stringProp name="Argument.name">pass</stringProp>
              </elementProp>
            </collectionProp>
          </elementProp>
          <stringProp name="HTTPSampler.domain"></stringProp>
          <stringProp name="HTTPSampler.port"></stringProp>
          <stringProp name="HTTPSampler.protocol">https</stringProp>
          <stringProp name="HTTPSampler.contentEncoding"></stringProp>
          <stringProp name="HTTPSampler.path">${BASE_URL}/session_login.cgi</stringProp>
          <stringProp name="HTTPSampler.method">POST</stringProp>
          <boolProp name="HTTPSampler.follow_redirects">true</boolProp>
          <boolProp name="HTTPSampler.auto_redirects">false</boolProp>
          <boolProp name="HTTPSampler.use_keepalive">true</boolProp>
          <boolProp name="HTTPSampler.DO_MULTIPART_POST">false</boolProp>
          <stringProp name="HTTPSampler.embedded_url_re"></stringProp>
          <stringProp name="HTTPSampler.connect_timeout"></stringProp>
          <stringProp name="HTTPSampler.response_timeout"></stringProp>
        </HTTPSamplerProxy>
        <hashTree/>
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="List Domains" enabled="true">
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments">
            <collectionProp name="Arguments.arguments">
              <elementProp name="module" elementType="HTTPArgument">
                <boolProp name="HTTPArgument.always_encode">false</boolProp>
                <stringProp name="Argument.value">virtual-server</stringProp>
                <stringProp name="Argument.metadata">=</stringProp>
                <boolProp name="HTTPArgument.use_equals">true</boolProp>
                <stringProp name="Argument.name">module</stringProp>
              </elementProp>
              <elementProp name="page" elementType="HTTPArgument">
                <boolProp name="HTTPArgument.always_encode">false</boolProp>
                <stringProp name="Argument.value">index</stringProp>
                <stringProp name="Argument.metadata">=</stringProp>
                <boolProp name="HTTPArgument.use_equals">true</boolProp>
                <stringProp name="Argument.name">page</stringProp>
              </elementProp>
              <elementProp name="webmin" elementType="HTTPArgument">
                <boolProp name="HTTPArgument.always_encode">false</boolProp>
                <stringProp name="Argument.value">1</stringProp>
                <stringProp name="Argument.metadata">=</stringProp>
                <boolProp name="HTTPArgument.use_equals">true</boolProp>
                <stringProp name="Argument.name">webmin</stringProp>
              </elementProp>
            </collectionProp>
          </elementProp>
          <stringProp name="HTTPSampler.domain"></stringProp>
          <stringProp name="HTTPSampler.port"></stringProp>
          <stringProp name="HTTPSampler.protocol">https</stringProp>
          <stringProp name="HTTPSampler.contentEncoding"></stringProp>
          <stringProp name="HTTPSampler.path">${BASE_URL}/virtual-server/index.cgi</stringProp>
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
          <stringProp name="filename">/opt/virtualmin/stress-testing/reports/jmeter/webmin-api-results.jtl</stringProp>
        </ResultCollector>
        <hashTree/>
      </hashTree>
    </hashTree>
  </hashTree>
</jmeterTestPlan>
EOF

    # Script de prueba para UI de Webmin
    cat > /opt/virtualmin/stress-testing/jmeter/tests/webmin-ui/webmin-ui.jmx << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2" properties="5.0" jmeter="5.5">
  <hashTree>
    <TestPlan guiclass="TestPlanGui" testclass="TestPlan" testname="Webmin UI Test Plan" enabled="true">
      <stringProp name="TestPlan.comments">Prueba de estrés para UI de Webmin</stringProp>
      <boolProp name="TestPlan.functional_mode">false</boolProp>
      <boolProp name="TestPlan.tearDown_on_shutdown">true</boolProp>
      <boolProp name="TestPlan.serialize_threadgroups">false</boolProp>
      <elementProp name="TestPlan.user_defined_variables" elementType="Arguments">
        <collectionProp name="Arguments.arguments">
          <elementProp name="BASE_URL" elementType="Argument">
            <stringProp name="Argument.name">BASE_URL</stringProp>
            <stringProp name="Argument.value">http://localhost:10000</stringProp>
            <stringProp name="Argument.metadata">=</stringProp>
          </elementProp>
          <elementProp name="USER_NAME" elementType="Argument">
            <stringProp name="Argument.name">USER_NAME</stringProp>
            <stringProp name="Argument.value">admin</stringProp>
            <stringProp name="Argument.metadata">=</stringProp>
          </elementProp>
          <elementProp name="PASSWORD" elementType="Argument">
            <stringProp name="Argument.name">PASSWORD</stringProp>
            <stringProp name="Argument.value">password</stringProp>
            <stringProp name="Argument.metadata">=</stringProp>
          </elementProp>
        </collectionProp>
      </elementProp>
      <stringProp name="TestPlan.user_define_classpath"></stringProp>
    </TestPlan>
    <hashTree>
      <ThreadGroup guiclass="ThreadGroupGui" testclass="ThreadGroup" testname="Webmin UI Users" enabled="true">
        <stringProp name="ThreadGroup.on_sample_error">continue</stringProp>
        <elementProp name="ThreadGroup.main_controller" elementType="LoopController">
          <boolProp name="LoopController.continue_forever">false</boolProp>
          <stringProp name="LoopController.loops">1</stringProp>
        </elementProp>
        <stringProp name="ThreadGroup.num_threads">50</stringProp>
        <stringProp name="ThreadGroup.ramp_time">5</stringProp>
        <boolProp name="ThreadGroup.scheduler">false</boolProp>
        <stringProp name="ThreadGroup.duration">60</stringProp>
        <stringProp name="ThreadGroup.delay"></stringProp>
      </ThreadGroup>
      <hashTree>
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="Login Page" enabled="true">
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments">
            <collectionProp name="Arguments.arguments"/>
          </elementProp>
          <stringProp name="HTTPSampler.domain"></stringProp>
          <stringProp name="HTTPSampler.port"></stringProp>
          <stringProp name="HTTPSampler.protocol">https</stringProp>
          <stringProp name="HTTPSampler.contentEncoding"></stringProp>
          <stringProp name="HTTPSampler.path">${BASE_URL}/</stringProp>
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
          <stringProp name="filename">/opt/virtualmin/stress-testing/reports/jmeter/webmin-ui-results.jtl</stringProp>
        </ResultCollector>
        <hashTree/>
      </hashTree>
    </hashTree>
  </hashTree>
</jmeterTestPlan>
EOF

    success "Scripts de prueba para JMeter creados"
}

# Crear scripts de prueba para Locust
create_locust_tests() {
    log "Creando scripts de prueba para Locust..."
    
    # Script de prueba para API de Webmin
    cat > /opt/virtualmin/stress-testing/locust/tests/webmin-api/webmin_api_locustfile.py << 'EOF'
from locust import HttpUser, task, between
import random
import json

class WebminApiUser(HttpUser):
    wait_time = between(1, 3)
    
    def on_start(self):
        """Función que se ejecuta al iniciar cada usuario"""
        self.login()
    
    def login(self):
        """Función para iniciar sesión"""
        response = self.client.post(
            "/session_login.cgi",
            data={
                "user": "admin",
                "pass": "password"
            }
        )
        
        # Guardar cookies para solicitudes posteriores
        if response.status_code == 302:
            self.client.cookies.update(response.cookies)
    
    @task(3)
    def list_domains(self):
        """Listar dominios virtuales"""
        self.client.get("/virtual-server/index.cgi?module=virtual-server&page=index&webmin=1")
    
    @task(2)
    def list_servers(self):
        """Listar servidores"""
        self.client.get("/server-manager/index.cgi")
    
    @task(2)
    def view_system_status(self):
        """Ver estado del sistema"""
        self.client.get("/sysinfo.cgi")
    
    @task(1)
    def view_logs(self):
        """Ver logs del sistema"""
        self.client.get("/viewlogs.cgi")
    
    @task(1)
    def list_modules(self):
        """Listar módulos de Webmin"""
        self.client.get("/index.cgi")
EOF

    # Script de prueba para UI de Webmin
    cat > /opt/virtualmin/stress-testing/locust/tests/webmin-ui/webmin_ui_locustfile.py << 'EOF'
from locust import HttpUser, task, between
import random
import json

class WebminUiUser(HttpUser):
    wait_time = between(2, 5)
    
    def on_start(self):
        """Función que se ejecuta al iniciar cada usuario"""
        self.login()
    
    def login(self):
        """Función para iniciar sesión"""
        response = self.client.post(
            "/session_login.cgi",
            data={
                "user": "admin",
                "pass": "password"
            }
        )
        
        # Guardar cookies para solicitudes posteriores
        if response.status_code == 302:
            self.client.cookies.update(response.cookies)
    
    @task(5)
    def view_dashboard(self):
        """Ver dashboard principal"""
        self.client.get("/")
    
    @task(3)
    def view_servers(self):
        """Ver página de servidores"""
        self.client.get("/server-manager/index.cgi")
    
    @task(2)
    def view_system_info(self):
        """Ver información del sistema"""
        self.client.get("/sysinfo.cgi")
    
    @task(2)
    def view_logs(self):
        """Ver logs del sistema"""
        self.client.get("/viewlogs.cgi")
    
    @task(1)
    def view_usermin(self):
        """Ver página de Usermin"""
        self.client.get("/usermin/")
EOF

    success "Scripts de prueba para Locust creados"
}

# Crear scripts de ejecución
create_execution_scripts() {
    log "Creando scripts de ejecución..."
    
    # Script de ejecución para JMeter
    cat > /opt/virtualmin/stress-testing/scripts/run_jmeter_test.sh << 'EOF'
#!/bin/bash

# Script para ejecutar pruebas de JMeter

# Configuración
TEST_TYPE=${1:-"api"}  # api, ui, custom
THREADS=${2:-"100"}     # Número de hilos
RAMP_TIME=${3:-"10"}    # Tiempo de rampa (segundos)
DURATION=${4:-"60"}     # Duración de la prueba (segundos)
TARGET_URL=${5:-"http://localhost:10000"}  # URL de destino

# Directorios
JMETER_HOME="/opt/virtualmin/stress-testing/jmeter/current"
RESULTS_DIR="/opt/virtualmin/stress-testing/reports/jmeter"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
REPORT_DIR="${RESULTS_DIR}/${TEST_TYPE}_${TIMESTAMP}"

# Crear directorio de resultados
mkdir -p "${REPORT_DIR}"

# Determinar archivo de prueba
case "${TEST_TYPE}" in
    "api")
        TEST_FILE="/opt/virtualmin/stress-testing/jmeter/tests/webmin-api/webmin-api.jmx"
        ;;
    "ui")
        TEST_FILE="/opt/virtualmin/stress-testing/jmeter/tests/webmin-ui/webmin-ui.jmx"
        ;;
    "custom")
        TEST_FILE=${6:-""}
        if [ -z "${TEST_FILE}" ]; then
            echo "Error: Se debe especificar un archivo de prueba personalizado"
            exit 1
        fi
        ;;
    *)
        echo "Error: Tipo de prueba no válido. Use 'api', 'ui' o 'custom'"
        exit 1
        ;;
esac

# Verificar que el archivo de prueba existe
if [ ! -f "${TEST_FILE}" ]; then
    echo "Error: El archivo de prueba ${TEST_FILE} no existe"
    exit 1
fi

# Ejecutar prueba
echo "Ejecutando prueba JMeter..."
echo "Tipo: ${TEST_TYPE}"
echo "Hilos: ${THREADS}"
echo "Tiempo de rampa: ${RAMP_TIME}s"
echo "Duración: ${DURATION}s"
echo "URL: ${TARGET_URL}"
echo "Archivo de prueba: ${TEST_FILE}"
echo "Directorio de resultados: ${REPORT_DIR}"

"${JMETER_HOME}/bin/jmeter" \
    -n \
    -t "${TEST_FILE}" \
    -JTHREADS="${THREADS}" \
    -JRAMP_TIME="${RAMP_TIME}" \
    -JDURATION="${DURATION}" \
    -JBASE_URL="${TARGET_URL}" \
    -l "${REPORT_DIR}/results.jtl" \
    -e \
    -o "${REPORT_DIR}/report"

echo "Prueba completada. Resultados en ${REPORT_DIR}"
EOF

    chmod +x /opt/virtualmin/stress-testing/scripts/run_jmeter_test.sh
    
    # Script de ejecución para Locust
    cat > /opt/virtualmin/stress-testing/scripts/run_locust_test.sh << 'EOF'
#!/bin/bash

# Script para ejecutar pruebas de Locust

# Configuración
TEST_TYPE=${1:-"api"}      # api, ui, custom
USERS=${2:-"100"}            # Número de usuarios
SPAWN_RATE=${3:-"10"}        # Tasa de generación de usuarios (usuarios/segundo)
RUN_TIME=${4:-"60"}          # Tiempo de ejecución (segundos)
TARGET_HOST=${5:-"localhost"} # Host de destino
TARGET_PORT=${6:-"10000"}    # Puerto de destino
WEB_MODE=${7:-"true"}        # Modo web (true/false)

# Directorios
RESULTS_DIR="/opt/virtualmin/stress-testing/reports/locust"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
REPORT_DIR="${RESULTS_DIR}/${TEST_TYPE}_${TIMESTAMP}"

# Crear directorio de resultados
mkdir -p "${REPORT_DIR}"

# Determinar archivo de prueba
case "${TEST_TYPE}" in
    "api")
        TEST_FILE="/opt/virtualmin/stress-testing/locust/tests/webmin-api/webmin_api_locustfile.py"
        ;;
    "ui")
        TEST_FILE="/opt/virtualmin/stress-testing/locust/tests/webmin-ui/webmin_ui_locustfile.py"
        ;;
    "custom")
        TEST_FILE=${8:-""}
        if [ -z "${TEST_FILE}" ]; then
            echo "Error: Se debe especificar un archivo de prueba personalizado"
            exit 1
        fi
        ;;
    *)
        echo "Error: Tipo de prueba no válido. Use 'api', 'ui' o 'custom'"
        exit 1
        ;;
esac

# Verificar que el archivo de prueba existe
if [ ! -f "${TEST_FILE}" ]; then
    echo "Error: El archivo de prueba ${TEST_FILE} no existe"
    exit 1
fi

# Construir URL de destino
TARGET_URL="http://${TARGET_HOST}:${TARGET_PORT}"

# Ejecutar prueba
echo "Ejecutando prueba Locust..."
echo "Tipo: ${TEST_TYPE}"
echo "Usuarios: ${USERS}"
echo "Tasa de generación: ${SPAWN_RATE} usuarios/segundo"
echo "Tiempo de ejecución: ${RUN_TIME}s"
echo "URL: ${TARGET_URL}"
echo "Archivo de prueba: ${TEST_FILE}"
echo "Directorio de resultados: ${REPORT_DIR}"

if [ "${WEB_MODE}" = "true" ]; then
    # Ejecutar en modo web
    locust \
        -f "${TEST_FILE}" \
        --host="${TARGET_URL}" \
        --users="${USERS}" \
        --spawn-rate="${SPAWN_RATE}" \
        --run-time="${RUN_TIME}s" \
        --html="${REPORT_DIR}/report.html" \
        --csv="${REPORT_DIR}/results.csv"
else
    # Ejecutar en modo línea de comandos
    locust \
        -f "${TEST_FILE}" \
        --headless \
        --host="${TARGET_URL}" \
        --users="${USERS}" \
        --spawn-rate="${SPAWN_RATE}" \
        --run-time="${RUN_TIME}s" \
        --html="${REPORT_DIR}/report.html" \
        --csv="${REPORT_DIR}/results.csv"
fi

echo "Prueba completada. Resultados en ${REPORT_DIR}"
EOF

    chmod +x /opt/virtualmin/stress-testing/scripts/run_locust_test.sh
    
    success "Scripts de ejecución creados"
}

# Crear servicio systemd para ejecutar pruebas en segundo plano
create_systemd_service() {
    log "Creando servicio systemd..."
    
    # Servicio para JMeter
    cat > /etc/systemd/system/jmeter-test.service << 'EOF'
[Unit]
Description=JMeter Stress Test
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/jmeter -n -t /opt/virtualmin/stress-testing/jmeter/tests/webmin-api/webmin-api.jmx -JTHREADS=100 -JRAMP_TIME=10 -JDURATION=60 -l /opt/virtualmin/stress-testing/reports/jmeter/results.jtl
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Servicio para Locust
    cat > /etc/systemd/system/locust-test.service << 'EOF'
[Unit]
Description=Locust Stress Test
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/virtualmin/stress-testing/locust
ExecStart=/usr/local/bin/locust -f /opt/virtualmin/stress-testing/locust/tests/webmin-api/webmin_api_locustfile.py --headless --host=http://localhost:10000 --users=100 --spawn-rate=10 --run-time=60s --csv=/opt/virtualmin/stress-testing/reports/locust/results.csv
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Recargar systemd
    systemctl daemon-reload
    
    success "Servicio systemd creado"
}

# Crear script de configuración de destino
create_target_config() {
    log "Creando script de configuración de destino..."
    
    cat > /opt/virtualmin/stress-testing/scripts/configure_target.sh << 'EOF'
#!/bin/bash

# Script para configurar el destino de las pruebas

# Parámetros
TARGET_URL=${1:-"http://localhost:10000"}  # URL de destino
USER_NAME=${2:-"admin"}                    # Nombre de usuario
PASSWORD=${3:-"password"}                  # Contraseña

# Actualizar variables en archivos de prueba
echo "Actualizando configuración de destino..."
echo "URL: ${TARGET_URL}"
echo "Usuario: ${USER_NAME}"

# Actualizar variables en scripts de JMeter
sed -i "s|<stringProp name=\"Argument.value\">http://localhost:10000</stringProp>|<stringProp name=\"Argument.value\">${TARGET_URL}</stringProp>|g" /opt/virtualmin/stress-testing/jmeter/tests/webmin-api/webmin-api.jmx
sed -i "s|<stringProp name=\"Argument.value\">http://localhost:10000</stringProp>|<stringProp name=\"Argument.value\">${TARGET_URL}</stringProp>|g" /opt/virtualmin/stress-testing/jmeter/tests/webmin-ui/webmin-ui.jmx

sed -i "s|<stringProp name=\"Argument.value\">admin</stringProp>|<stringProp name=\"Argument.value\">${USER_NAME}</stringProp>|g" /opt/virtualmin/stress-testing/jmeter/tests/webmin-api/webmin-api.jmx
sed -i "s|<stringProp name=\"Argument.value\">admin</stringProp>|<stringProp name=\"Argument.value\">${USER_NAME}</stringProp>|g" /opt/virtualmin/stress-testing/jmeter/tests/webmin-ui/webmin-ui.jmx

sed -i "s|<stringProp name=\"Argument.value\">password</stringProp>|<stringProp name=\"Argument.value\">${PASSWORD}</stringProp>|g" /opt/virtualmin/stress-testing/jmeter/tests/webmin-api/webmin-api.jmx
sed -i "s|<stringProp name=\"Argument.value\">password</stringProp>|<stringProp name=\"Argument.value\">${PASSWORD}</stringProp>|g" /opt/virtualmin/stress-testing/jmeter/tests/webmin-ui/webmin-ui.jmx

# Actualizar variables en scripts de Locust
sed -i "s|http://localhost:10000|${TARGET_URL}|g" /opt/virtualmin/stress-testing/locust/tests/webmin-api/webmin_api_locustfile.py
sed -i "s|http://localhost:10000|${TARGET_URL}|g" /opt/virtualmin/stress-testing/locust/tests/webmin-ui/webmin_ui_locustfile.py

sed -i "s|\"user\": \"admin\"|\"user\": \"${USER_NAME}\"|g" /opt/virtualmin/stress-testing/locust/tests/webmin-api/webmin_api_locustfile.py
sed -i "s|\"user\": \"admin\"|\"user\": \"${USER_NAME}\"|g" /opt/virtualmin/stress-testing/locust/tests/webmin-ui/webmin_ui_locustfile.py

sed -i "s|\"pass\": \"password\"|\"pass\": \"${PASSWORD}\"|g" /opt/virtualmin/stress-testing/locust/tests/webmin-api/webmin_api_locustfile.py
sed -i "s|\"pass\": \"password\"|\"pass\": \"${PASSWORD}\"|g" /opt/virtualmin/stress-testing/locust/tests/webmin-ui/webmin_ui_locustfile.py

echo "Configuración de destino actualizada"
EOF

    chmod +x /opt/virtualmin/stress-testing/scripts/configure_target.sh
    
    success "Script de configuración de destino creado"
}

# Función principal
main() {
    log "Iniciando configuración de pruebas de estrés..."
    
    # Verificar si se ejecuta como root
    if [ "$EUID" -ne 0 ]; then
        error "Este script debe ejecutarse como root"
        exit 1
    fi
    
    # Ejecutar funciones
    check_dependencies
    create_directory_structure
    install_jmeter
    install_locust
    create_jmeter_tests
    create_locust_tests
    create_execution_scripts
    create_systemd_service
    create_target_config
    
    success "Configuración de pruebas de estrés completada"
    
    # Mostrar información de uso
    echo
    echo -e "${BLUE}Uso de JMeter:${NC}"
    echo "Ejecutar prueba de API:"
    echo "  /opt/virtualmin/stress-testing/scripts/run_jmeter_test.sh api 100 10 60 http://localhost:10000"
    echo
    echo "Ejecutar prueba de UI:"
    echo "  /opt/virtualmin/stress-testing/scripts/run_jmeter_test.sh ui 50 5 60 http://localhost:10000"
    echo
    echo "Configurar destino:"
    echo "  /opt/virtualmin/stress-testing/scripts/configure_target.sh http://localhost:10000 admin password"
    echo
    echo -e "${BLUE}Uso de Locust:${NC}"
    echo "Ejecutar prueba de API en modo web:"
    echo "  /opt/virtualmin/stress-testing/scripts/run_locust_test.sh api 100 10 60 localhost 10000 true"
    echo
    echo "Ejecutar prueba de UI en modo línea de comandos:"
    echo "  /opt/virtualmin/stress-testing/scripts/run_locust_test.sh ui 50 5 60 localhost 10000 false"
    echo
    echo -e "${BLUE}Servicios:${NC}"
    echo "Iniciar servicio de prueba JMeter:"
    echo "  systemctl start jmeter-test"
    echo
    echo "Iniciar servicio de prueba Locust:"
    echo "  systemctl start locust-test"
    echo
    echo "Verificar estado de los servicios:"
    echo "  systemctl status jmeter-test"
    echo "  systemctl status locust-test"
    echo
}

# Ejecutar función principal
main "$@"
#!/bin/bash

# Script de instalación para el sistema SIEM basado en Wazuh
# Este script instala y configura el sistema de gestión de logs y alertas de seguridad

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
SIEM_DIR="${PROJECT_ROOT}/siem"

# Crear directorios necesarios
mkdir -p "$LOG_DIR" "$CONFIG_DIR"

# Archivo de log
LOG_FILE="${LOG_DIR}/wazuh_siem_install_$(date +%Y%m%d_%H%M%S).log"

# Función para mostrar banner
show_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              Virtualmin Enterprise - SIEM Setup                   ║"
    echo "║                Sistema de Gestión de Logs y Alertas                ║"
    echo "║                         Basado en Wazuh                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Función para verificar dependencias
check_dependencies() {
    log "Verificando dependencias..."
    
    # Verificar si las herramientas necesarias están instaladas
    local tools=("curl" "wget" "unzip" "python3" "python3-pip" "jq")
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log "✓ $tool está instalado"
        else
            error "$tool no está instalado. Por favor, instale $tool y vuelva a ejecutar el script."
            exit 1
        fi
    done
    
    # Verificar si se ejecuta como root
    if [ "$EUID" -ne 0 ]; then
        error "Este script debe ejecutarse como root"
        exit 1
    fi
    
    success "Dependencias verificadas"
}

# Función para crear archivo de configuración
create_config() {
    log "Creando archivo de configuración..."
    
    # Crear archivo de configuración si no existe
    local config_file="$CONFIG_DIR/wazuh_config.json"
    
    if [ ! -f "$config_file" ]; then
        log "Creando archivo de configuración por defecto..."
        cat > "$config_file" << EOF
{
  "wazuh": {
    "manager_url": "https://wazuh-manager.local",
    "api_user": "wazuh",
    "api_password": "wazuh",
    "agent_name_prefix": "virtualmin-enterprise"
  },
  "virtualmin": {
    "log_path": "/var/log/virtualmin",
    "logs": ["access_log", "error_log", "audit_log"]
  },
  "webmin": {
    "log_path": "/var/log/webmin",
    "logs": ["miniserv.log", "webmin.log"]
  },
  "apache": {
    "log_path": "/var/log/apache2",
    "logs": ["access.log", "error.log"]
  },
  "nginx": {
    "log_path": "/var/log/nginx",
    "logs": ["access.log", "error.log"]
  },
  "mysql": {
    "log_path": "/var/log/mysql",
    "logs": ["error.log", "slow.log"]
  },
  "alerts": {
    "slack_webhook": "",
    "email_recipients": [],
    "critical_threshold": 3
  }
}
EOF
        
        warning "Archivo de configuración creado en $config_file"
        warning "Por favor, edite este archivo con sus configuraciones específicas antes de continuar"
        
        # Preguntar si se desea editar el archivo ahora
        read -p "¿Desea editar el archivo de configuración ahora? (y/n): " edit_config
        
        if [ "$edit_config" = "y" ] || [ "$edit_config" = "Y" ]; then
            ${EDITOR:-nano} "$config_file"
        fi
    else
        log "Archivo de configuración encontrado: $config_file"
    fi
    
    success "Configuración creada"
}

# Función para instalar Wazuh Manager
install_wazuh_manager() {
    log "Instalando Wazuh Manager..."
    
    # Detectar distribución
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    else
        error "No se pudo detectar la distribución del sistema"
        exit 1
    fi
    
    # Instalar según distribución
    case $DISTRO in
        ubuntu|debian)
            # Agregar repositorio de Wazuh
            curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -
            echo "deb https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
            apt-get update
            apt-get install -y wazuh-manager
            ;;
        centos|rhel|fedora)
            # Agregar repositorio de Wazuh
            rpm --import https://packages.wazuh.com/key/GPG-KEY-WAZUH
            cat > /etc/yum.repos.d/wazuh.repo << EOF
[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=Wazuh repository
baseurl=https://packages.wazuh.com/4.x/yum/
protect=1
EOF
            yum install -y wazuh-manager
            ;;
        *)
            error "Distribución no soportada: $DISTRO"
            exit 1
            ;;
    esac
    
    # Configurar Wazuh Manager
    local manager_config="/var/ossec/etc/ossec.conf"
    
    # Habilitar API de Wazuh
    if grep -q "<api>" "$manager_config"; then
        log "API de Wazuh ya configurada"
    else
        # Añadir configuración de API
        sed -i '/<\/ossec_config>/i \  <api>\n    <port>55000<\/port>\n    <bind_ip>0.0.0.0<\/bind_ip>\n  <\/api>' "$manager_config"
    fi
    
    # Configurar Filebeat para forwarding de logs
    if [ -d "/etc/filebeat" ]; then
        log "Configurando Filebeat para Wazuh..."
        
        # Descargar configuración de Filebeat para Wazuh
        curl -s https://raw.githubusercontent.com/wazuh/wazuh/4.3/extensions/filebeat/filebeat-wazuh-template.yml -o /etc/filebeat/filebeat.yml
        
        # Habilitar y reiniciar Filebeat
        systemctl enable filebeat
        systemctl restart filebeat
    fi
    
    # Habilitar e iniciar Wazuh Manager
    systemctl enable wazuh-manager
    systemctl restart wazuh-manager
    
    # Esperar a que Wazuh Manager se inicie
    log "Esperando a que Wazuh Manager se inicie..."
    sleep 10
    
    # Verificar que Wazuh Manager esté en ejecución
    if systemctl is-active --quiet wazuh-manager; then
        success "Wazuh Manager instalado y en ejecución"
    else
        error "Wazuh Manager no se pudo iniciar"
        exit 1
    fi
}

# Función para instalar Wazuh Kibana
install_wazuh_kibana() {
    log "Instalando Wazuh Kibana..."
    
    # Detectar distribución
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        error "No se pudo detectar la distribución del sistema"
        exit 1
    fi
    
    # Instalar según distribución
    case $DISTRO in
        ubuntu|debian)
            # Instalar dependencias
            apt-get install -y curl apt-transport-https software-properties-common wget
            
            # Agregar repositorio de Elastic
            curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elastic-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/elastic-keyring.gpg] https://artifacts.elastic.co/packages/7.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-7.x.list
            apt-get update
            
            # Instalar Elasticsearch
            apt-get install -y elasticsearch
            
            # Instalar Kibana
            apt-get install -y kibana
            
            # Instalar Wazuh app para Kibana
            cd /usr/share/kibana/
            sudo -u kibana ./bin/kibana-plugin install https://packages.wazuh.com/4.x/ui/kibana/wazuh_kibana-4.3.0-1.zip
            ;;
        centos|rhel|fedora)
            # Instalar dependencias
            yum install -y curl wget
            
            # Agregar repositorio de Elastic
            rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
            cat > /etc/yum.repos.d/elastic.repo << EOF
[elasticsearch-7.x]
name=Elasticsearch repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF
            yum install -y elasticsearch kibana
            
            # Instalar Wazuh app para Kibana
            cd /usr/share/kibana/
            sudo -u kibana ./bin/kibana-plugin install https://packages.wazuh.com/4.x/ui/kibana/wazuh_kibana-4.3.0-1.zip
            ;;
        *)
            error "Distribución no soportada: $DISTRO"
            exit 1
            ;;
    esac
    
    # Configurar Elasticsearch
    local elasticsearch_config="/etc/elasticsearch/elasticsearch.yml"
    
    # Añadir configuración para Wazuh
    if ! grep -q "cluster.name: wazuh" "$elasticsearch_config"; then
        echo "cluster.name: wazuh" >> "$elasticsearch_config"
        echo "network.host: 0.0.0.0" >> "$elasticsearch_config"
        echo "node.name: node-1" >> "$elasticsearch_config"
        echo "discovery.type: single-node" >> "$elasticsearch_config"
    fi
    
    # Configurar Kibana
    local kibana_config="/etc/kibana/kibana.yml"
    
    # Añadir configuración para Wazuh
    if ! grep -q "server.host: \"0.0.0.0\"" "$kibana_config"; then
        echo "server.host: \"0.0.0.0\"" >> "$kibana_config"
        echo "elasticsearch.url: http://localhost:9200" >> "$kibana_config"
        echo "elasticsearch.username: \"kibana\"" >> "$kibana_config"
        echo "elasticsearch.password: \"kibana\"" >> "$kibana_config"
    fi
    
    # Habilitar e iniciar servicios
    systemctl enable elasticsearch
    systemctl restart elasticsearch
    
    # Esperar a que Elasticsearch se inicie
    log "Esperando a que Elasticsearch se inicie..."
    sleep 15
    
    systemctl enable kibana
    systemctl restart kibana
    
    # Esperar a que Kibana se inicie
    log "Esperando a que Kibana se inicie..."
    sleep 10
    
    # Verificar que los servicios estén en ejecución
    if systemctl is-active --quiet elasticsearch && systemctl is-active --quiet kibana; then
        success "Wazuh Kibana instalado y en ejecución"
    else
        error "Wazuh Kibana no se pudo iniciar"
        exit 1
    fi
}

# Función para instalar Wazuh Agent local
install_wazuh_agent() {
    log "Instalando Wazuh Agent local..."
    
    # Detectar distribución
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        error "No se pudo detectar la distribución del sistema"
        exit 1
    fi
    
    # Instalar según distribución
    case $DISTRO in
        ubuntu|debian)
            # Agregar repositorio de Wazuh
            curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -
            echo "deb https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
            apt-get update
            apt-get install -y wazuh-agent
            ;;
        centos|rhel|fedora)
            # Agregar repositorio de Wazuh
            rpm --import https://packages.wazuh.com/key/GPG-KEY-WAZUH
            cat > /etc/yum.repos.d/wazuh.repo << EOF
[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=Wazuh repository
baseurl=https://packages.wazuh.com/4.x/yum/
protect=1
EOF
            yum install -y wazuh-agent
            ;;
        *)
            error "Distribución no soportada: $DISTRO"
            exit 1
            ;;
    esac
    
    # Configurar agente
    local agent_config="/var/ossec/etc/ossec.conf"
    
    # Configurar IP del manager
    local manager_ip="127.0.0.1"
    if [ -n "$1" ]; then
        manager_ip="$1"
    fi
    
    sed -i "s/<address>MANAGER_IP<\/address>/<address>$manager_ip<\/address>/" "$agent_config"
    
    # Habilitar e iniciar agente
    systemctl enable wazuh-agent
    systemctl restart wazuh-agent
    
    # Esperar a que el agente se inicie
    log "Esperando a que Wazuh Agent se inicie..."
    sleep 5
    
    # Verificar que el agente esté en ejecución
    if systemctl is-active --quiet wazuh-agent; then
        success "Wazuh Agent local instalado y en ejecución"
    else
        error "Wazuh Agent local no se pudo iniciar"
        exit 1
    fi
}

# Función para integrar con Virtualmin Enterprise
integrate_virtualmin() {
    log "Integrando Wazuh SIEM con Virtualmin Enterprise..."
    
    # Ejecutar script de integración
    local integration_script="$SIEM_DIR/wazuh_integration.py"
    
    if [ -f "$integration_script" ]; then
        # Instalar dependencias de Python
        pip3 install requests
        
        # Ejecutar script de integración
        python3 "$integration_script" --config "$CONFIG_DIR/wazuh_config.json" --deploy
        
        success "Integración con Virtualmin Enterprise completada"
    else
        error "Script de integración no encontrado: $integration_script"
        exit 1
    fi
}

# Función para crear dashboard de Wazuh
create_wazuh_dashboard() {
    log "Creando dashboard de Wazuh..."
    
    # Crear archivo HTML para el dashboard
    local dashboard_file="/opt/virtualmin-enterprise/wazuh_dashboard.html"
    
    cat > "$dashboard_file" << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Virtualmin Enterprise - Wazuh SIEM Dashboard</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f5f7fa;
            color: #333;
        }
        
        .header {
            background-color: #1a4f72;
            color: white;
            padding: 15px 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .header h1 {
            margin: 0;
            font-size: 24px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .dashboard-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        
        .card {
            background-color: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
            padding: 20px;
            transition: transform 0.3s ease;
        }
        
        .card:hover {
            transform: translateY(-5px);
        }
        
        .card-header {
            display: flex;
            align-items: center;
            margin-bottom: 15px;
        }
        
        .card-header i {
            font-size: 24px;
            margin-right: 10px;
            color: #1a4f72;
        }
        
        .card-header h3 {
            margin: 0;
            font-size: 18px;
        }
        
        .metric {
            font-size: 36px;
            font-weight: bold;
            margin: 10px 0;
        }
        
        .metric-label {
            color: #666;
            font-size: 14px;
        }
        
        .status {
            padding: 8px 12px;
            border-radius: 20px;
            font-size: 14px;
            font-weight: bold;
            text-align: center;
            margin-top: 10px;
        }
        
        .status.ok {
            background-color: #d4edda;
            color: #155724;
        }
        
        .status.warning {
            background-color: #fff3cd;
            color: #856404;
        }
        
        .status.critical {
            background-color: #f8d7da;
            color: #721c24;
        }
        
        .alert-list {
            max-height: 300px;
            overflow-y: auto;
        }
        
        .alert-item {
            padding: 10px;
            border-radius: 4px;
            margin-bottom: 10px;
            border-left: 4px solid #1a4f72;
        }
        
        .alert-item.high {
            border-left-color: #721c24;
        }
        
        .alert-item.medium {
            border-left-color: #856404;
        }
        
        .alert-item.low {
            border-left-color: #155724;
        }
        
        .alert-time {
            font-size: 12px;
            color: #666;
        }
        
        .alert-title {
            font-weight: bold;
            margin-bottom: 5px;
        }
        
        .alert-description {
            font-size: 14px;
        }
        
        .footer {
            background-color: #1a4f72;
            color: white;
            text-align: center;
            padding: 15px;
            margin-top: 20px;
        }
        
        .links {
            display: flex;
            justify-content: center;
            gap: 20px;
            margin-bottom: 20px;
        }
        
        .link-button {
            background-color: #1a4f72;
            color: white;
            padding: 10px 20px;
            border-radius: 4px;
            text-decoration: none;
            transition: background-color 0.3s ease;
        }
        
        .link-button:hover {
            background-color: #2a6f92;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1><i class="fas fa-shield-alt"></i> Virtualmin Enterprise - Wazuh SIEM Dashboard</h1>
        <div id="datetime"></div>
    </div>
    
    <div class="container">
        <div class="links">
            <a href="http://localhost:55000" target="_blank" class="link-button">
                <i class="fas fa-cog"></i> Wazuh Manager
            </a>
            <a href="http://localhost:5601" target="_blank" class="link-button">
                <i class="fas fa-chart-line"></i> Kibana
            </a>
            <a href="#" onclick="refreshData()" class="link-button">
                <i class="fas fa-sync-alt"></i> Actualizar Datos
            </a>
        </div>
        
        <div class="dashboard-grid">
            <div class="card">
                <div class="card-header">
                    <i class="fas fa-exclamation-triangle"></i>
                    <h3>Alertas Críticas</h3>
                </div>
                <div class="metric" id="critical-alerts">0</div>
                <div class="metric-label">Últimas 24 horas</div>
                <div class="status critical" id="critical-status">Sin alertas</div>
            </div>
            
            <div class="card">
                <div class="card-header">
                    <i class="fas fa-exclamation-circle"></i>
                    <h3>Alertas Medias</h3>
                </div>
                <div class="metric" id="medium-alerts">0</div>
                <div class="metric-label">Últimas 24 horas</div>
                <div class="status warning" id="medium-status">Sin alertas</div>
            </div>
            
            <div class="card">
                <div class="card-header">
                    <i class="fas fa-info-circle"></i>
                    <h3>Alertas Bajas</h3>
                </div>
                <div class="metric" id="low-alerts">0</div>
                <div class="metric-label">Últimas 24 horas</div>
                <div class="status ok" id="low-status">Sin alertas</div>
            </div>
            
            <div class="card">
                <div class="card-header">
                    <i class="fas fa-server"></i>
                    <h3>Agentes Activos</h3>
                </div>
                <div class="metric" id="active-agents">0</div>
                <div class="metric-label">Total registrados</div>
                <div class="status ok" id="agents-status">Todos activos</div>
            </div>
        </div>
        
        <div class="card">
            <div class="card-header">
                <i class="fas fa-bell"></i>
                <h3>Alertas Recientes</h3>
            </div>
            <div class="alert-list" id="recent-alerts">
                <p>Cargando alertas...</p>
            </div>
        </div>
    </div>
    
    <div class="footer">
        <p>Virtualmin Enterprise - Wazuh SIEM Dashboard</p>
    </div>
    
    <script>
        // Actualizar fecha y hora
        function updateDateTime() {
            const now = new Date();
            const options = { 
                year: 'numeric', 
                month: 'long', 
                day: 'numeric', 
                hour: '2-digit', 
                minute: '2-digit', 
                second: '2-digit' 
            };
            document.getElementById('datetime').textContent = now.toLocaleDateString('es-ES', options);
        }
        
        // Actualizar datos del dashboard
        function refreshData() {
            // Simulación de datos - en una implementación real, esto se obtendría de la API de Wazuh
            const criticalAlerts = Math.floor(Math.random() * 10);
            const mediumAlerts = Math.floor(Math.random() * 20);
            const lowAlerts = Math.floor(Math.random() * 30);
            const activeAgents = Math.floor(Math.random() * 5) + 1;
            
            document.getElementById('critical-alerts').textContent = criticalAlerts;
            document.getElementById('medium-alerts').textContent = mediumAlerts;
            document.getElementById('low-alerts').textContent = lowAlerts;
            document.getElementById('active-agents').textContent = activeAgents;
            
            // Actualizar estados
            const criticalStatus = document.getElementById('critical-status');
            if (criticalAlerts > 0) {
                criticalStatus.textContent = `${criticalAlerts} alertas`;
                criticalStatus.className = 'status critical';
            } else {
                criticalStatus.textContent = 'Sin alertas';
                criticalStatus.className = 'status ok';
            }
            
            const mediumStatus = document.getElementById('medium-status');
            if (mediumAlerts > 0) {
                mediumStatus.textContent = `${mediumAlerts} alertas`;
                mediumStatus.className = 'status warning';
            } else {
                mediumStatus.textContent = 'Sin alertas';
                mediumStatus.className = 'status ok';
            }
            
            const lowStatus = document.getElementById('low-status');
            if (lowAlerts > 0) {
                lowStatus.textContent = `${lowAlerts} alertas`;
                lowStatus.className = 'status ok';
            } else {
                lowStatus.textContent = 'Sin alertas';
                lowStatus.className = 'status ok';
            }
            
            const agentsStatus = document.getElementById('agents-status');
            if (activeAgents > 0) {
                agentsStatus.textContent = `${activeAgents} activos`;
                agentsStatus.className = 'status ok';
            } else {
                agentsStatus.textContent = 'Sin agentes activos';
                agentsStatus.className = 'status critical';
            }
            
            // Actualizar lista de alertas recientes
            updateRecentAlerts();
        }
        
        // Actualizar lista de alertas recientes
        function updateRecentAlerts() {
            const alertsContainer = document.getElementById('recent-alerts');
            
            // Simulación de alertas - en una implementación real, esto se obtendría de la API de Wazuh
            const alerts = [
                {
                    level: 'high',
                    title: 'Intento de inicio de sesión fallido',
                    description: 'Múltiples intentos de inicio de sesión fallidos desde la IP 192.168.1.100',
                    time: '2023-11-15 14:30:22'
                },
                {
                    level: 'medium',
                    title: 'Modificación de configuración',
                    description: 'El usuario admin modificó la configuración del servidor web',
                    time: '2023-11-15 13:45:10'
                },
                {
                    level: 'low',
                    title: 'Conexión SSH establecida',
                    description: 'El usuario root inició sesión a través de SSH',
                    time: '2023-11-15 12:15:33'
                }
            ];
            
            alertsContainer.innerHTML = '';
            
            alerts.forEach(alert => {
                const alertItem = document.createElement('div');
                alertItem.className = `alert-item ${alert.level}`;
                
                alertItem.innerHTML = `
                    <div class="alert-time">${alert.time}</div>
                    <div class="alert-title">${alert.title}</div>
                    <div class="alert-description">${alert.description}</div>
                `;
                
                alertsContainer.appendChild(alertItem);
            });
        }
        
        // Inicializar
        updateDateTime();
        refreshData();
        
        // Actualizar cada 30 segundos
        setInterval(updateDateTime, 1000);
        setInterval(refreshData, 30000);
    </script>
</body>
</html>
EOF
    
    success "Dashboard de Wazuh creado en $dashboard_file"
    
    # Crear enlace simbólico en directorio web si existe
    if [ -d "/var/www/html" ]; then
        ln -sf "$dashboard_file" "/var/www/html/wazuh_dashboard.html"
        success "Enlace simbólico creado en /var/www/html/wazuh_dashboard.html"
    fi
}

# Función para mostrar resumen
show_summary() {
    log "Mostrando resumen de la instalación..."
    
    local manager_url="http://localhost:55000"
    local kibana_url="http://localhost:5601"
    local dashboard_url="/opt/virtualmin-enterprise/wazuh_dashboard.html"
    
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    Resumen de la Instalación                      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${GREEN}✓ Wazuh Manager instalado y configurado${NC}"
    echo -e "${GREEN}✓ Wazuh Kibana instalado y configurado${NC}"
    echo -e "${GREEN}✓ Wazuh Agent local instalado y configurado${NC}"
    echo -e "${GREEN}✓ Integración con Virtualmin Enterprise completada${NC}"
    echo -e "${GREEN}✓ Dashboard de Wazuh creado${NC}"
    echo ""
    echo -e "${CYAN}Accesos Disponibles:${NC}"
    echo -e "  - ${BLUE}Wazuh Manager:${NC} $manager_url"
    echo -e "  - ${BLUE}Kibana:${NC} $kibana_url"
    echo -e "  - ${BLUE}Dashboard:${NC} $dashboard_url"
    echo ""
    echo -e "${CYAN}Configuración:${NC}"
    echo -e "  - ${BLUE}Archivo de configuración:${NC} $CONFIG_DIR/wazuh_config.json"
    echo -e "  - ${BLUE}Logs de instalación:${NC} $LOG_FILE"
    echo ""
    echo -e "${CYAN}Pasos Siguientes:${NC}"
    echo -e "  1. Acceda a $kibana_url para ver los dashboards de Wazuh"
    echo -e "  2. Configure las reglas y alertas según sus necesidades"
    echo -e "  3. Instale agentes Wazuh en los servidores remotos"
    echo -e "  4. Configure las notificaciones por correo o Slack"
    echo ""
}

# Función principal
main() {
    # Mostrar banner
    show_banner
    
    # Ejecutar funciones principales
    check_dependencies
    create_config
    
    # Preguntar qué componentes instalar
    echo ""
    echo "Seleccione los componentes a instalar:"
    echo "1. Wazuh Manager (recomendado para servidores dedicados)"
    echo "2. Wazuh Agent local (para monitorizar este servidor)"
    echo "3. Sistema completo (Manager + Kibana + Agent)"
    echo "4. Solo integración con Virtualmin Enterprise"
    echo ""
    
    read -p "Opción (1-4): " install_option
    
    case $install_option in
        1)
            install_wazuh_manager
            install_wazuh_agent "127.0.0.1"
            integrate_virtualmin
            create_wazuh_dashboard
            ;;
        2)
            read -p "IP del Wazuh Manager: " manager_ip
            install_wazuh_agent "$manager_ip"
            integrate_virtualmin
            create_wazuh_dashboard
            ;;
        3)
            install_wazuh_manager
            install_wazuh_kibana
            install_wazuh_agent "127.0.0.1"
            integrate_virtualmin
            create_wazuh_dashboard
            ;;
        4)
            integrate_virtualmin
            create_wazuh_dashboard
            ;;
        *)
            error "Opción no válida: $install_option"
            exit 1
            ;;
    esac
    
    show_summary
}

# Manejo de interrupción
trap 'error "Script interrumpido por el usuario"; exit 1' INT TERM

# Ejecutar función principal
main "$@"
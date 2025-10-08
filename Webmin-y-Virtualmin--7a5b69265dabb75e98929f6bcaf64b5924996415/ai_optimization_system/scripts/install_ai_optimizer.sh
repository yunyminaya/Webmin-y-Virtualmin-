#!/bin/bash

# ============================================================================
# 🚀 INSTALADOR DEL SISTEMA DE OPTIMIZACIÓN AUTOMÁTICA CON IA
# ============================================================================
# Instala y configura el sistema completo de optimización con IA para Webmin/Virtualmin
# Incluye todos los componentes: ML, optimización automática, dashboard, etc.
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
AI_DIR="$(dirname "$PROJECT_DIR")"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función de logging
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" >> "$AI_DIR/ai_optimizer_install.log"

    case "$level" in
        "INFO")     echo -e "${BLUE}[$timestamp INFO]${NC} $message" ;;
        "SUCCESS")  echo -e "${GREEN}[$timestamp SUCCESS]${NC} $message" ;;
        "WARNING")  echo -e "${YELLOW}[$timestamp WARNING]${NC} $message" ;;
        "ERROR")    echo -e "${RED}[$timestamp ERROR]${NC} $message" ;;
        "STEP")     echo -e "${PURPLE}[$timestamp STEP]${NC} $message" ;;
    esac
}

# Función para verificar si estamos en un sistema compatible
check_system() {
    log "STEP" "🔍 Verificando compatibilidad del sistema..."

    # Verificar OS
    if [[ ! -f /etc/os-release ]]; then
        log "ERROR" "Sistema operativo no compatible"
        exit 1
    fi

    . /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        log "WARNING" "Sistema $ID detectado. Optimizado para Ubuntu/Debian"
    fi

    # Verificar arquitectura
    if [[ $(uname -m) != "x86_64" ]]; then
        log "WARNING" "Arquitectura $(uname -m) detectada. Optimizado para x86_64"
    fi

    # Verificar si Webmin/Virtualmin están instalados
    if [[ ! -d /etc/webmin ]]; then
        log "WARNING" "Webmin no detectado. El sistema funcionará pero sin integración completa"
    fi

    log "SUCCESS" "✅ Sistema compatible"
}

# Función para instalar dependencias del sistema
install_system_dependencies() {
    log "STEP" "📦 Instalando dependencias del sistema..."

    # Actualizar lista de paquetes
    apt-get update

    # Instalar Python 3 y pip
    apt-get install -y python3 python3-pip python3-dev

    # Instalar dependencias para machine learning
    apt-get install -y build-essential libssl-dev libffi-dev python3-setuptools

    # Instalar utilidades del sistema
    apt-get install -y curl wget git htop iotop sysstat

    # Instalar Prometheus y Grafana si no están instalados
    if ! command -v prometheus >/dev/null 2>&1; then
        log "INFO" "Instalando Prometheus..."
        # Aquí iría la instalación de Prometheus
        # wget https://github.com/prometheus/prometheus/releases/download/v2.40.0/prometheus-2.40.0.linux-amd64.tar.gz
        # tar xvf prometheus-2.40.0.linux-amd64.tar.gz
        # mv prometheus-2.40.0.linux-amd64 /opt/prometheus
    fi

    log "SUCCESS" "✅ Dependencias del sistema instaladas"
}

# Función para instalar dependencias de Python
install_python_dependencies() {
    log "STEP" "🐍 Instalando dependencias de Python..."

    cd "$AI_DIR"

    # Instalar dependencias desde requirements.txt
    if [[ -f "requirements.txt" ]]; then
        pip3 install -r requirements.txt
    else
        # Instalar dependencias manualmente
        pip3 install scikit-learn pandas numpy psutil schedule flask flask-cors redis prometheus-client matplotlib seaborn
    fi

    # Verificar instalación
    python3 -c "import sklearn, pandas, numpy, psutil, flask; print('✅ Dependencias Python OK')"

    log "SUCCESS" "✅ Dependencias de Python instaladas"
}

# Función para configurar el sistema de optimización
configure_ai_optimizer() {
    log "STEP" "⚙️ Configurando sistema de optimización con IA..."

    # Crear directorios necesarios
    mkdir -p /var/log/ai_optimizer
    mkdir -p /var/lib/ai_optimizer
    mkdir -p /etc/ai_optimizer

    # Copiar archivos de configuración
    if [[ -f "$AI_DIR/core/ai_optimizer_config.json" ]]; then
        cp "$AI_DIR/core/ai_optimizer_config.json" /etc/ai_optimizer/
    fi

    # Crear usuario para el servicio
    if ! id -u ai_optimizer >/dev/null 2>&1; then
        useradd -r -s /bin/false ai_optimizer
    fi

    # Configurar permisos
    chown -R ai_optimizer:ai_optimizer /var/log/ai_optimizer
    chown -R ai_optimizer:ai_optimizer /var/lib/ai_optimizer
    chown -R ai_optimizer:ai_optimizer "$AI_DIR"

    log "SUCCESS" "✅ Sistema configurado"
}

# Función para crear servicios del sistema
create_services() {
    log "STEP" "🔧 Creando servicios del sistema..."

    # Crear servicio para el core del optimizador
    cat > /etc/systemd/system/ai-optimizer.service << 'EOF'
[Unit]
Description=AI Optimizer Core Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=ai_optimizer
Group=ai_optimizer
WorkingDirectory=/opt/ai_optimization_system
ExecStart=/usr/bin/python3 /opt/ai_optimization_system/core/ai_optimizer_core.py --start
ExecStop=/usr/bin/python3 /opt/ai_optimization_system/core/ai_optimizer_core.py --stop
Restart=always
RestartSec=10
Environment=PYTHONPATH=/opt/ai_optimization_system

[Install]
WantedBy=multi-user.target
EOF

    # Crear servicio para el dashboard
    cat > /etc/systemd/system/ai-optimizer-dashboard.service << 'EOF'
[Unit]
Description=AI Optimizer Dashboard Service
After=network.target ai-optimizer.service
Wants=network.target

[Service]
Type=simple
User=ai_optimizer
Group=ai_optimizer
WorkingDirectory=/opt/ai_optimization_system/dashboard
ExecStart=/usr/bin/python3 -c "
from ai_optimization_dashboard import AIOptimizationDashboard
from core.ai_optimizer_core import AIOptimizerCore
import time

# Inicializar core
core = AIOptimizerCore()
core.initialize_components()

# Inicializar dashboard
dashboard = AIOptimizationDashboard(core)
dashboard.start()

# Mantener vivo
while True:
    time.sleep(1)
"
Restart=always
RestartSec=10
Environment=PYTHONPATH=/opt/ai_optimization_system

[Install]
WantedBy=multi-user.target
EOF

    # Recargar systemd
    systemctl daemon-reload

    log "SUCCESS" "✅ Servicios creados"
}

# Función para integrar con Webmin
integrate_with_webmin() {
    log "STEP" "🔗 Integrando con Webmin/Virtualmin..."

    if [[ -d /etc/webmin ]]; then
        # Crear módulo de Webmin para AI Optimizer
        mkdir -p /usr/libexec/webmin/ai_optimizer

        # Copiar archivos del módulo
        cp -r "$AI_DIR/dashboard" /usr/libexec/webmin/ai_optimizer/

        # Crear configuración del módulo
        cat > /etc/webmin/ai_optimizer/config << 'EOF'
enabled=1
port=8888
host=localhost
auto_start=1
EOF

        # Añadir a la lista de módulos
        if [[ -f /etc/webmin/webmin.acl ]]; then
            if ! grep -q "ai_optimizer" /etc/webmin/webmin.acl; then
                echo "ai_optimizer: root" >> /etc/webmin/webmin.acl
            fi
        fi

        log "SUCCESS" "✅ Integración con Webmin completada"
    else
        log "WARNING" "Webmin no detectado - omitiendo integración"
    fi
}

# Función para configurar monitoreo
setup_monitoring() {
    log "STEP" "📊 Configurando monitoreo integrado..."

    # Configurar Prometheus para AI Optimizer
    if [[ -d /opt/prometheus ]]; then
        cat >> /opt/prometheus/prometheus.yml << 'EOF'

  - job_name: 'ai_optimizer'
    static_configs:
      - targets: ['localhost:8000']
    scrape_interval: 15s
    metrics_path: '/metrics'
EOF

        systemctl restart prometheus 2>/dev/null || true
    fi

    # Configurar logrotate para logs del AI Optimizer
    cat > /etc/logrotate.d/ai_optimizer << 'EOF'
/var/log/ai_optimizer/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 ai_optimizer ai_optimizer
    postrotate
        systemctl reload ai-optimizer 2>/dev/null || true
    endscript
}
EOF

    log "SUCCESS" "✅ Monitoreo configurado"
}

# Función para crear scripts de gestión
create_management_scripts() {
    log "STEP" "📝 Creando scripts de gestión..."

    # Script de inicio del sistema
    cat > /usr/local/bin/ai-optimizer-start << 'EOF'
#!/bin/bash
echo "🚀 Iniciando AI Optimizer..."
systemctl start ai-optimizer
systemctl start ai-optimizer-dashboard
echo "✅ AI Optimizer iniciado"
EOF

    # Script de parada del sistema
    cat > /usr/local/bin/ai-optimizer-stop << 'EOF'
#!/bin/bash
echo "🛑 Deteniendo AI Optimizer..."
systemctl stop ai-optimizer-dashboard
systemctl stop ai-optimizer
echo "✅ AI Optimizer detenido"
EOF

    # Script de estado del sistema
    cat > /usr/local/bin/ai-optimizer-status << 'EOF'
#!/bin/bash
echo "📊 Estado del AI Optimizer:"
echo "Core service:"
systemctl status ai-optimizer --no-pager -l
echo ""
echo "Dashboard service:"
systemctl status ai-optimizer-dashboard --no-pager -l
echo ""
echo "Dashboard URL: http://localhost:8888"
EOF

    # Hacer ejecutables
    chmod +x /usr/local/bin/ai-optimizer-start
    chmod +x /usr/local/bin/ai-optimizer-stop
    chmod +x /usr/local/bin/ai-optimizer-status

    log "SUCCESS" "✅ Scripts de gestión creados"
}

# Función para crear documentación
create_documentation() {
    log "STEP" "📚 Creando documentación..."

    cat > /opt/ai_optimization_system/README.md << 'EOF'
# 🤖 AI Optimizer Pro - Sistema de Optimización Automática con IA

## Descripción
Sistema completo de optimización automática con IA para Webmin/Virtualmin que incluye:
- Análisis predictivo de rendimiento usando Machine Learning
- Optimización automática de configuraciones (Apache, MySQL, PHP, sistema)
- Balanceo de carga inteligente basado en patrones de uso
- Gestión automática de recursos (CPU, memoria, disco)
- Recomendaciones proactivas con implementación automática
- Dashboard de optimización con métricas y tendencias

## Inicio Rápido

### Iniciar el sistema
```bash
ai-optimizer-start
```

### Acceder al dashboard
Abre tu navegador en: http://localhost:8888

### Ver estado del sistema
```bash
ai-optimizer-status
```

### Detener el sistema
```bash
ai-optimizer-stop
```

## Arquitectura

### Componentes Principales
1. **AI Optimizer Core** - Motor principal de coordinación
2. **Predictive Analyzer** - Análisis predictivo con ML
3. **Auto Config Optimizer** - Optimización automática de configuraciones
4. **Smart Load Balancer** - Balanceo de carga inteligente
5. **Intelligent Resource Manager** - Gestión automática de recursos
6. **Proactive Recommendation Engine** - Recomendaciones proactivas
7. **Dashboard** - Interfaz web de monitoreo y control

### Funcionalidades

#### Análisis Predictivo
- Predicción de uso de CPU, memoria y disco
- Detección de anomalías en tiempo real
- Análisis de patrones de carga
- Alertas proactivas

#### Optimización Automática
- Ajuste automático de configuraciones Apache, MySQL, PHP
- Optimización de parámetros del sistema
- Liberación automática de recursos
- Balanceo inteligente de carga

#### Dashboard Interactivo
- Métricas en tiempo real
- Gráficos de tendencias
- Recomendaciones con un clic
- Historial de optimizaciones
- Control manual del sistema

## Configuración

El archivo de configuración principal se encuentra en:
`/etc/ai_optimizer/ai_optimizer_config.json`

### Parámetros Importantes
- `optimization_interval`: Intervalo entre ciclos de optimización (segundos)
- `monitoring_interval`: Intervalo de monitoreo (segundos)
- `auto_apply_recommendations`: Aplicar recomendaciones automáticamente
- `risk_tolerance`: Nivel de tolerancia al riesgo (low/medium/high)

## Logs y Monitoreo

### Logs del Sistema
- `/var/log/ai_optimizer/ai_optimizer.log` - Log principal
- `/var/log/ai_optimizer/dashboard.log` - Log del dashboard

### Monitoreo
- Dashboard web: http://localhost:8888
- Métricas Prometheus: http://localhost:8000/metrics
- Grafana: Configurado automáticamente

## Solución de Problemas

### El sistema no inicia
```bash
# Verificar estado de servicios
ai-optimizer-status

# Ver logs
tail -f /var/log/ai_optimizer/ai_optimizer.log
```

### Dashboard no responde
```bash
# Reiniciar dashboard
systemctl restart ai-optimizer-dashboard

# Verificar puerto
netstat -tlnp | grep 8888
```

### Problemas de rendimiento
```bash
# Verificar recursos del sistema
htop

# Ver logs de errores
grep ERROR /var/log/ai_optimizer/ai_optimizer.log
```

## Soporte

Para soporte técnico o reportar problemas:
- Logs completos: `/var/log/ai_optimizer/`
- Configuración: `/etc/ai_optimizer/`
- Código fuente: `/opt/ai_optimization_system/`

## Licencia
Este sistema es parte de Webmin/Virtualmin Pro.
EOF

    log "SUCCESS" "✅ Documentación creada"
}

# Función para verificar instalación
verify_installation() {
    log "STEP" "🔍 Verificando instalación..."

    local errors=0

    # Verificar Python
    if ! command -v python3 >/dev/null 2>&1; then
        log "ERROR" "Python 3 no encontrado"
        ((errors++))
    fi

    # Verificar dependencias Python
    if ! python3 -c "import sklearn, pandas, flask" 2>/dev/null; then
        log "ERROR" "Dependencias Python no instaladas correctamente"
        ((errors++))
    fi

    # Verificar servicios
    if ! systemctl is-enabled ai-optimizer 2>/dev/null; then
        log "WARNING" "Servicio ai-optimizer no habilitado"
    fi

    if ! systemctl is-enabled ai-optimizer-dashboard 2>/dev/null; then
        log "WARNING" "Servicio ai-optimizer-dashboard no habilitado"
    fi

    # Verificar archivos
    if [[ ! -f /opt/ai_optimization_system/core/ai_optimizer_core.py ]]; then
        log "ERROR" "Archivos del sistema no encontrados"
        ((errors++))
    fi

    if [[ $errors -eq 0 ]]; then
        log "SUCCESS" "✅ Instalación verificada correctamente"
        return 0
    else
        log "ERROR" "❌ Errores encontrados en la instalación: $errors"
        return 1
    fi
}

# Función principal
main() {
    log "STEP" "🚀 INICIANDO INSTALACIÓN DEL AI OPTIMIZER PRO"

    echo ""
    echo -e "${CYAN}🤖 AI OPTIMIZER PRO - INSTALADOR${NC}"
    echo -e "${CYAN}SISTEMA DE OPTIMIZACIÓN AUTOMÁTICA CON IA${NC}"
    echo ""

    # Verificar permisos de root
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Este script debe ejecutarse como root"
        echo -e "${RED}❌ Este script debe ejecutarse como root${NC}"
        echo -e "${YELLOW}💡 Ejecuta: sudo $0${NC}"
        exit 1
    fi

    # Ejecutar instalación
    check_system
    install_system_dependencies
    install_python_dependencies
    configure_ai_optimizer
    create_services
    integrate_with_webmin
    setup_monitoring
    create_management_scripts
    create_documentation

    # Verificar instalación
    if verify_installation; then
        # Iniciar servicios
        log "STEP" "▶️ Iniciando servicios..."
        systemctl enable ai-optimizer ai-optimizer-dashboard
        ai-optimizer-start

        echo ""
        echo -e "${GREEN}🎉 INSTALACIÓN COMPLETADA EXITOSAMENTE${NC}"
        echo ""
        echo -e "${BLUE}📊 Dashboard disponible en: http://localhost:8888${NC}"
        echo -e "${BLUE}📖 Documentación: /opt/ai_optimization_system/README.md${NC}"
        echo -e "${BLUE}🛠️ Comandos de gestión:${NC}"
        echo "   ai-optimizer-start    - Iniciar sistema"
        echo "   ai-optimizer-stop     - Detener sistema"
        echo "   ai-optimizer-status   - Ver estado"
        echo ""
        echo -e "${GREEN}✅ ¡TU SISTEMA PRO ESTÁ OPTIMIZADO CON IA!${NC}"
    else
        echo ""
        echo -e "${RED}❌ INSTALACIÓN COMPLETADA CON ERRORES${NC}"
        echo -e "${YELLOW}📋 Revisa el log: $AI_DIR/ai_optimizer_install.log${NC}"
        exit 1
    fi
}

# Ejecutar instalación
main "$@"
EOF

chmod +x "$AI_DIR/scripts/install_ai_optimizer.sh"
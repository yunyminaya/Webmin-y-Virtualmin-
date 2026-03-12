#!/bin/bash
# Instalador de Integración Multi-Nube para Webmin y Virtualmin
# Instala todas las dependencias y configura el sistema completo

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función de logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Verificar si estamos ejecutando como root
if [[ $EUID -ne 0 ]]; then
   error "Este script debe ejecutarse como root"
   exit 1
fi

# Detectar distribución
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    elif [[ -f /etc/redhat-release ]]; then
        DISTRO="rhel"
        VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | head -1)
    else
        error "No se pudo detectar la distribución"
        exit 1
    fi

    log "Distribución detectada: $DISTRO $VERSION"
}

# Instalar dependencias del sistema
install_system_dependencies() {
    log "Instalando dependencias del sistema..."

    case $DISTRO in
        ubuntu|debian)
            apt-get update
            apt-get install -y python3 python3-pip python3-dev \
                perl libperl-dev \
                curl wget git \
                build-essential \
                libssl-dev \
                jq
            ;;
        centos|rhel|fedora)
            yum update -y
            yum install -y python3 python3-pip python3-devel \
                perl perl-devel \
                curl wget git \
                gcc gcc-c++ \
                openssl-devel \
                jq
            ;;
        *)
            error "Distribución no soportada: $DISTRO"
            exit 1
            ;;
    esac

    log "Dependencias del sistema instaladas"
}

# Instalar bibliotecas Python para multi-nube
install_python_libraries() {
    log "Instalando bibliotecas Python para integración multi-nube..."

    pip3 install --upgrade pip

    # AWS SDK
    pip3 install boto3 botocore

    # Azure SDK
    pip3 install azure-identity azure-mgmt-compute azure-mgmt-storage azure-mgmt-network azure-mgmt-costmanagement

    # GCP SDK
    pip3 install google-cloud-compute google-cloud-storage google-cloud-billing

    # Otras dependencias
    pip3 install schedule pyyaml requests python-dateutil

    log "Bibliotecas Python instaladas"
}

# Instalar módulos Perl adicionales si es necesario
install_perl_modules() {
    log "Instalando módulos Perl..."

    # Verificar si cpanm está disponible
    if ! command -v cpanm &> /dev/null; then
        curl -L https://cpanmin.us | perl - App::cpanminus
    fi

    # Instalar módulos necesarios
    cpanm JSON Data::Dumper LWP::UserAgent HTTP::Request

    log "Módulos Perl instalados"
}

# Configurar directorios
setup_directories() {
    log "Configurando directorios..."

    # Crear directorio principal
    mkdir -p /opt/multi-cloud-integration
    mkdir -p /opt/multi-cloud-integration/logs
    mkdir -p /opt/multi-cloud-integration/config
    mkdir -p /opt/multi-cloud-integration/backups

    # Crear directorio en Webmin
    WEBMIN_ROOT="/usr/libexec/webmin"
    if [[ -d "$WEBMIN_ROOT" ]]; then
        mkdir -p "$WEBMIN_ROOT/multi-cloud"
        ln -sf /opt/multi-cloud-integration "$WEBMIN_ROOT/multi-cloud/module"
    fi

    # Configurar permisos
    chown -R www-data:www-data /opt/multi-cloud-integration 2>/dev/null || true
    chmod -R 755 /opt/multi-cloud-integration

    log "Directorios configurados"
}

# Copiar archivos del sistema
copy_system_files() {
    log "Copiando archivos del sistema..."

    # Copiar todo el directorio multi_cloud_integration
    if [[ -d "multi_cloud_integration" ]]; then
        cp -r multi_cloud_integration/* /opt/multi-cloud-integration/
    else
        error "Directorio multi_cloud_integration no encontrado"
        exit 1
    fi

    # Hacer ejecutables los scripts
    find /opt/multi-cloud-integration -name "*.py" -exec chmod +x {} \;
    find /opt/multi-cloud-integration -name "*.sh" -exec chmod +x {} \;
    find /opt/multi-cloud-integration -name "*.cgi" -exec chmod +x {} \;

    log "Archivos del sistema copiados"
}

# Configurar archivo de configuración
setup_configuration() {
    log "Configurando archivo de configuración..."

    CONFIG_FILE="/opt/multi-cloud-integration/multi_cloud_config.json"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << EOF
{
  "aws": {
    "access_key_id": "${AWS_ACCESS_KEY_ID:-}",
    "secret_access_key": "${AWS_SECRET_ACCESS_KEY:-}",
    "region": "${AWS_DEFAULT_REGION:-us-east-1}"
  },
  "azure": {
    "subscription_id": "${AZURE_SUBSCRIPTION_ID:-}",
    "client_id": "${AZURE_CLIENT_ID:-}",
    "client_secret": "${AZURE_CLIENT_SECRET:-}",
    "tenant_id": "${AZURE_TENANT_ID:-}"
  },
  "gcp": {
    "project_id": "${GCP_PROJECT_ID:-}",
    "credentials_file": "${GOOGLE_APPLICATION_CREDENTIALS:-}"
  },
  "general": {
    "backup_regions": ["us-east-1", "us-west-2", "eu-west-1"],
    "cost_optimization_threshold": 0.8,
    "migration_timeout": 3600,
    "monitoring_interval": 60,
    "log_level": "INFO"
  }
}
EOF
        log "Archivo de configuración creado: $CONFIG_FILE"
        warning "Configure las credenciales de nube en $CONFIG_FILE antes de usar el sistema"
    else
        log "Archivo de configuración ya existe"
    fi

    # Configurar variables de entorno
    ENV_FILE="/etc/environment"
    if ! grep -q "MULTI_CLOUD_CONFIG" "$ENV_FILE"; then
        echo "MULTI_CLOUD_CONFIG=$CONFIG_FILE" >> "$ENV_FILE"
    fi
}

# Configurar servicios systemd
setup_services() {
    log "Configurando servicios systemd..."

    # Servicio de monitoreo
    cat > /etc/systemd/system/multi-cloud-monitor.service << EOF
[Unit]
Description=Multi-Cloud Monitor Service
After=network.target

[Service]
Type=simple
User=www-data
ExecStart=/usr/bin/python3 /opt/multi-cloud-integration/monitoring_manager.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Servicio de optimización de costos
    cat > /etc/systemd/system/multi-cloud-optimizer.service << EOF
[Unit]
Description=Multi-Cloud Cost Optimizer Service
After=network.target

[Service]
Type=simple
User=www-data
ExecStart=/usr/bin/python3 /opt/multi-cloud-integration/cost_optimizer.py
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

    # Servicio de backups
    cat > /etc/systemd/system/multi-cloud-backup.service << EOF
[Unit]
Description=Multi-Cloud Backup Service
After=network.target

[Service]
Type=simple
User=www-data
ExecStart=/usr/bin/python3 /opt/multi-cloud-integration/backup_manager.py
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

    # Recargar systemd
    systemctl daemon-reload

    log "Servicios systemd configurados"
}

# Configurar Webmin/Virtualmin
setup_webmin_integration() {
    log "Configurando integración con Webmin/Virtualmin..."

    WEBMIN_ROOT="/usr/libexec/webmin"
    VIRTUALMIN_ROOT="/usr/libexec/webmin/virtualmin"

    if [[ -d "$WEBMIN_ROOT" ]]; then
        # Copiar módulo CGI
        cp /opt/multi-cloud-integration/webmin_integration.cgi "$WEBMIN_ROOT/"

        # Crear enlace simbólico en virtualmin si existe
        if [[ -d "$VIRTUALMIN_ROOT" ]]; then
            ln -sf "$WEBMIN_ROOT/webmin_integration.cgi" "$VIRTUALMIN_ROOT/"
        fi

        # Configurar permisos
        chown www-data:www-data "$WEBMIN_ROOT/webmin_integration.cgi" 2>/dev/null || true
        chmod 755 "$WEBMIN_ROOT/webmin_integration.cgi"

        log "Integración con Webmin/Virtualmin configurada"
    else
        warning "Webmin no encontrado. La integración CGI no se configuró."
    fi
}

# Configurar Apache/Nginx para el dashboard
setup_web_server() {
    log "Configurando servidor web para dashboard..."

    DASHBOARD_FILE="/opt/multi-cloud-integration/dashboard.html"

    # Detectar servidor web
    if systemctl is-active --quiet apache2 || systemctl is-active --quiet httpd; then
        # Apache
        cat > /etc/apache2/sites-available/multi-cloud-dashboard.conf << EOF
<VirtualHost *:80>
    ServerName multi-cloud.local
    DocumentRoot /opt/multi-cloud-integration

    <Directory /opt/multi-cloud-integration>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    Alias /multi-cloud /opt/multi-cloud-integration
    <Directory /opt/multi-cloud-integration>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
        a2ensite multi-cloud-dashboard.conf
        systemctl reload apache2

    elif systemctl is-active --quiet nginx; then
        # Nginx
        cat > /etc/nginx/sites-available/multi-cloud-dashboard << EOF
server {
    listen 80;
    server_name multi-cloud.local;

    root /opt/multi-cloud-integration;
    index dashboard.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /multi-cloud {
        alias /opt/multi-cloud-integration;
        index dashboard.html;
    }

    location ~ \.cgi$ {
        include fastcgi_params;
        fastcgi_pass unix:/var/run/fcgiwrap.socket;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF
        ln -sf /etc/nginx/sites-available/multi-cloud-dashboard /etc/nginx/sites-enabled/
        systemctl reload nginx
    fi

    log "Servidor web configurado"
}

# Configurar logging
setup_logging() {
    log "Configurando sistema de logging..."

    LOG_DIR="/opt/multi-cloud-integration/logs"

    # Crear archivos de log
    touch "$LOG_DIR/multi-cloud.log"
    touch "$LOG_DIR/monitoring.log"
    touch "$LOG_DIR/backup.log"
    touch "$LOG_DIR/migration.log"

    # Configurar logrotate
    cat > /etc/logrotate.d/multi-cloud << EOF
$LOG_DIR/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    create 644 www-data www-data
    postrotate
        systemctl reload multi-cloud-monitor
        systemctl reload multi-cloud-optimizer
        systemctl reload multi-cloud-backup
    endscript
}
EOF

    log "Sistema de logging configurado"
}

# Crear script de inicialización
create_init_script() {
    log "Creando script de inicialización..."

    cat > /opt/multi-cloud-integration/init_multi_cloud.sh << 'EOF'
#!/bin/bash
# Script de inicialización del sistema multi-nube

cd /opt/multi-cloud-integration

# Activar entorno virtual si existe
if [[ -d "venv" ]]; then
    source venv/bin/activate
fi

# Iniciar servicios
echo "Iniciando servicios multi-nube..."

# Iniciar monitoreo
python3 -c "
from monitoring_manager import monitor
monitor.start_monitoring()
print('Monitoreo iniciado')
" &

# Iniciar optimización de costos
python3 -c "
from cost_optimizer import cost_optimizer
cost_optimizer.start_optimization()
print('Optimización de costos iniciada')
" &

# Iniciar sistema de backups
python3 -c "
from backup_manager import backup_manager
backup_manager.start_scheduler()
print('Sistema de backups iniciado')
" &

echo "Sistema multi-nube inicializado"
EOF

    chmod +x /opt/multi-cloud-integration/init_multi_cloud.sh

    log "Script de inicialización creado"
}

# Función de verificación
verify_installation() {
    log "Verificando instalación..."

    # Verificar archivos
    files_to_check=(
        "/opt/multi-cloud-integration/__init__.py"
        "/opt/multi-cloud-integration/config.py"
        "/opt/multi-cloud-integration/unified_manager.py"
        "/opt/multi-cloud-integration/dashboard.html"
    )

    for file in "${files_to_check[@]}"; do
        if [[ ! -f "$file" ]]; then
            error "Archivo faltante: $file"
            return 1
        fi
    done

    # Verificar bibliotecas Python
    python3 -c "
import boto3
import azure.identity
from google.cloud import compute_v1
print('Bibliotecas Python verificadas')
" 2>/dev/null

    if [[ $? -ne 0 ]]; then
        error "Bibliotecas Python no instaladas correctamente"
        return 1
    fi

    # Verificar servicios systemd
    services_to_check=(
        "multi-cloud-monitor.service"
        "multi-cloud-optimizer.service"
        "multi-cloud-backup.service"
    )

    for service in "${services_to_check[@]}"; do
        if ! systemctl list-units --full -all | grep -q "$service"; then
            error "Servicio faltante: $service"
            return 1
        fi
    done

    log "Verificación completada exitosamente"
    return 0
}

# Función principal
main() {
    log "=== Instalador de Integración Multi-Nube para Webmin/Virtualmin ==="
    log "Versión: 1.0.0"
    echo

    detect_distro
    install_system_dependencies
    install_python_libraries
    install_perl_modules
    setup_directories
    copy_system_files
    setup_configuration
    setup_services
    setup_webmin_integration
    setup_web_server
    setup_logging
    create_init_script

    if verify_installation; then
        log ""
        log "🎉 ¡Instalación completada exitosamente!"
        echo
        info "Pasos siguientes:"
        info "1. Configure las credenciales de nube en /opt/multi-cloud-integration/multi_cloud_config.json"
        info "2. Inicie los servicios: systemctl start multi-cloud-monitor multi-cloud-optimizer multi-cloud-backup"
        info "3. Acceda al dashboard en: http://multi-cloud.local/dashboard.html"
        info "4. En Webmin/Virtualmin: Ir a Multi-Cloud Management"
        echo
        info "Documentación completa en: /opt/multi-cloud-integration/README.md"
    else
        error "La instalación falló. Revise los logs para más detalles."
        exit 1
    fi
}

# Manejar argumentos
case "${1:-}" in
    --help|-h)
        echo "Instalador de Integración Multi-Nube"
        echo "Uso: $0 [opciones]"
        echo ""
        echo "Opciones:"
        echo "  --help, -h          Mostrar esta ayuda"
        echo "  --verify            Solo verificar instalación existente"
        echo "  --update            Actualizar instalación existente"
        echo ""
        exit 0
        ;;
    --verify)
        if verify_installation; then
            log "Instalación verificada correctamente"
            exit 0
        else
            error "Problemas encontrados en la instalación"
            exit 1
        fi
        ;;
    --update)
        log "Actualizando instalación..."
        copy_system_files
        setup_services
        setup_webmin_integration
        log "Actualización completada"
        exit 0
        ;;
    *)
        main
        ;;
esac
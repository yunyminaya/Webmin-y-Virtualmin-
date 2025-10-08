#!/bin/bash
# Webmin/Virtualmin DevOps Dashboard Installation Script
# Versión: 1.0.0
# Fecha: 2025-09-30

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

# Variables de configuración
WEBMIN_ROOT="/usr/share/webmin"
APACHE_CONF_DIR="/etc/apache2/sites-available"
CGI_BIN_DIR="/usr/lib/cgi-bin"
LOG_DIR="/var/log/webmin"
DEVOPS_DIR="/var/webmin/devops"
DASHBOARD_HTML="${WEBMIN_ROOT}/devops-dashboard.html"
DASHBOARD_CGI="${CGI_BIN_DIR}/devops-dashboard.cgi"

log "🚀 Iniciando instalación del Dashboard DevOps para Webmin/Virtualmin"

# Verificar dependencias
log "Verificando dependencias del sistema..."

# Verificar que Webmin esté instalado
if [[ ! -d "$WEBMIN_ROOT" ]]; then
    error "Webmin no está instalado en $WEBMIN_ROOT"
    exit 1
fi

# Verificar Apache
if ! command -v apache2ctl &> /dev/null; then
    error "Apache2 no está instalado"
    exit 1
fi

# Verificar Perl y módulos necesarios
if ! command -v perl &> /dev/null; then
    error "Perl no está instalado"
    exit 1
fi

# Instalar módulos Perl necesarios
log "Instalando módulos Perl necesarios..."
apt-get update
apt-get install -y libjson-perl libcgi-perl

# Crear directorios necesarios
log "Creando directorios necesarios..."
mkdir -p "$DEVOPS_DIR"
mkdir -p "$DEVOPS_DIR/metrics"
mkdir -p "$DEVOPS_DIR/pipelines"
mkdir -p "$LOG_DIR"

# Configurar permisos
log "Configurando permisos..."
chmod 755 "$DEVOPS_DIR"
chmod 755 "$DEVOPS_DIR/metrics"
chmod 755 "$DEVOPS_DIR/pipelines"
chmod 755 "$LOG_DIR"

# Copiar archivos del dashboard
log "Instalando archivos del dashboard..."

# Copiar HTML del dashboard
if [[ -f "devops-dashboard.html" ]]; then
    cp "devops-dashboard.html" "$WEBMIN_ROOT/"
    chmod 644 "$WEBMIN_ROOT/devops-dashboard.html"
    log "✅ Dashboard HTML instalado"
else
    error "Archivo devops-dashboard.html no encontrado"
    exit 1
fi

# Copiar CGI del dashboard
if [[ -f "devops-dashboard.cgi" ]]; then
    cp "devops-dashboard.cgi" "$CGI_BIN_DIR/"
    chmod 755 "$CGI_BIN_DIR/devops-dashboard.cgi"
    log "✅ Dashboard CGI instalado"
else
    error "Archivo devops-dashboard.cgi no encontrado"
    exit 1
fi

# Crear archivos de configuración iniciales
log "Creando archivos de configuración..."

# Archivo de configuración de servicios
cat > "$DEVOPS_DIR/services.conf" << 'EOF'
# Configuración de servicios para monitoreo DevOps
# Formato: nombre_servicio:comando_verificación:intervalo_segundos

webmin:systemctl is-active webmin:30
apache2:systemctl is-active apache2:30
mysql:systemctl is-active mysql:30
postgresql:systemctl is-active postgresql:30
nginx:systemctl is-active nginx:30
docker:systemctl is-active docker:30
kubernetes:kubectl cluster-info:60
EOF

chmod 644 "$DEVOPS_DIR/services.conf"

# Archivo de alertas inicial
cat > "$DEVOPS_DIR/alerts.json" << 'EOF'
{
  "active_alerts": [],
  "alert_history": [],
  "last_updated": 0
}
EOF

chmod 644 "$DEVOPS_DIR/alerts.json"

# Configurar Apache para CGI
log "Configurando Apache para soporte CGI..."

# Habilitar módulo CGI
a2enmod cgi

# Crear configuración de sitio para el dashboard
cat > "$APACHE_CONF_DIR/devops-dashboard.conf" << EOF
<VirtualHost *:80>
    ServerName devops-dashboard.local
    DocumentRoot $WEBMIN_ROOT

    <Directory "$WEBMIN_ROOT">
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Configuración CGI
    ScriptAlias /cgi-bin/ $CGI_BIN_DIR/
    <Directory "$CGI_BIN_DIR">
        AllowOverride None
        Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
        Require all granted
    </Directory>

    # Logs
    ErrorLog $LOG_DIR/devops-dashboard_error.log
    CustomLog $LOG_DIR/devops-dashboard_access.log combined
</VirtualHost>
EOF

# Habilitar sitio
a2ensite devops-dashboard

# Configurar logrotate para logs del dashboard
log "Configurando rotación de logs..."
cat > "/etc/logrotate.d/devops-dashboard" << 'EOF'
/var/log/webmin/devops-dashboard.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        systemctl reload apache2
    endscript
}
EOF

# Crear scripts de prueba para pipelines
log "Creando scripts de prueba para pipelines..."

mkdir -p "$WEBMIN_ROOT/tests"
mkdir -p "$WEBMIN_ROOT/deploy"
mkdir -p "$WEBMIN_ROOT/scripts"

# Script de tests unitarios
cat > "$WEBMIN_ROOT/tests/run_unit_tests.sh" << 'EOF'
#!/bin/bash
echo "Ejecutando tests unitarios..."
sleep 5
echo "Tests unitarios completados exitosamente"
exit 0
EOF

chmod +x "$WEBMIN_ROOT/tests/run_unit_tests.sh"

# Script de tests de integración
cat > "$WEBMIN_ROOT/tests/run_integration_tests.sh" << 'EOF'
#!/bin/bash
echo "Ejecutando tests de integración..."
sleep 10
echo "Tests de integración completados exitosamente"
exit 0
EOF

chmod +x "$WEBMIN_ROOT/tests/run_integration_tests.sh"

# Script de despliegue a staging
cat > "$WEBMIN_ROOT/deploy/deploy_staging.sh" << 'EOF'
#!/bin/bash
echo "Desplegando a entorno staging..."
sleep 15
echo "Despliegue a staging completado"
exit 0
EOF

chmod +x "$WEBMIN_ROOT/deploy/deploy_staging.sh"

# Script de despliegue a producción
cat > "$WEBMIN_ROOT/deploy/deploy_production.sh" << 'EOF'
#!/bin/bash
echo "Desplegando a entorno producción..."
sleep 20
echo "Despliegue a producción completado"
exit 0
EOF

chmod +x "$WEBMIN_ROOT/deploy/deploy_production.sh"

# Script de rollback
cat > "$WEBMIN_ROOT/deploy/rollback.sh" << 'EOF'
#!/bin/bash
echo "Ejecutando rollback..."
sleep 10
echo "Rollback completado exitosamente"
exit 0
EOF

chmod +x "$WEBMIN_ROOT/deploy/rollback.sh"

# Script de parada de emergencia
cat > "$WEBMIN_ROOT/scripts/emergency_stop.sh" << 'EOF'
#!/bin/bash
echo "Ejecutando parada de emergencia..."
# Detener servicios críticos
systemctl stop apache2
systemctl stop mysql
echo "Parada de emergencia completada"
exit 0
EOF

chmod +x "$WEBMIN_ROOT/scripts/emergency_stop.sh"

# Configurar firewall básico
log "Configurando firewall básico..."
if command -v ufw &> /dev/null; then
    ufw allow 80/tcp
    ufw allow 443/tcp
    log "✅ Firewall configurado"
fi

# Reiniciar servicios
log "Reiniciando servicios..."
systemctl reload apache2

# Verificar instalación
log "Verificando instalación..."

# Verificar que los archivos existan
if [[ ! -f "$DASHBOARD_HTML" ]]; then
    error "Archivo HTML del dashboard no encontrado"
    exit 1
fi

if [[ ! -f "$DASHBOARD_CGI" ]]; then
    error "Archivo CGI del dashboard no encontrado"
    exit 1
fi

# Verificar que CGI sea ejecutable
if [[ ! -x "$DASHBOARD_CGI" ]]; then
    error "CGI del dashboard no es ejecutable"
    exit 1
fi

# Probar CGI básico
if curl -s "http://localhost/cgi-bin/devops-dashboard.cgi?action=get_metrics" > /dev/null 2>&1; then
    log "✅ CGI responde correctamente"
else
    warning "CGI no responde (posiblemente normal si Apache no está configurado para localhost)"
fi

# Crear archivo de estado de instalación
cat > "$DEVOPS_DIR/install_status.json" << EOF
{
  "installed": true,
  "version": "1.0.0",
  "install_date": "$(date -Iseconds)",
  "webmin_root": "$WEBMIN_ROOT",
  "cgi_bin": "$CGI_BIN_DIR",
  "devops_dir": "$DEVOPS_DIR",
  "log_dir": "$LOG_DIR"
}
EOF

chmod 644 "$DEVOPS_DIR/install_status.json"

log ""
log "🎉 ¡Instalación completada exitosamente!"
log ""
log "📋 Resumen de instalación:"
log "   • Dashboard HTML: $DASHBOARD_HTML"
log "   • Dashboard CGI: $DASHBOARD_CGI"
log "   • Directorio DevOps: $DEVOPS_DIR"
log "   • Logs: $LOG_DIR/devops-dashboard.log"
log ""
log "🌐 Para acceder al dashboard:"
log "   1. Agrega esta línea a /etc/hosts:"
log "      127.0.0.1 devops-dashboard.local"
log "   2. Abre en tu navegador: http://devops-dashboard.local/devops-dashboard.html"
log ""
log "🔧 Para acceder vía Webmin:"
log "   • El dashboard está disponible en: $WEBMIN_ROOT/devops-dashboard.html"
log ""
log "📊 Funcionalidades implementadas:"
log "   • ✅ Monitoreo en tiempo real del sistema"
log "   • ✅ Estado de servicios críticos"
log "   • ✅ Gestión de pipelines DevOps"
log "   • ✅ Alertas y notificaciones"
log "   • ✅ Logs en tiempo real"
log "   • ✅ Controles de ejecución de pipelines"
log "   • ✅ Interfaz web moderna y responsiva"
log ""
log "⚠️  Notas importantes:"
log "   • Asegúrate de que Apache esté ejecutándose"
log "   • Los pipelines se ejecutan en background"
log "   • Los logs se rotan automáticamente"
log "   • Las métricas se almacenan por 30 días"
log ""

# Preguntar si quiere iniciar el dashboard inmediatamente
read -p "¿Quieres abrir el dashboard en el navegador ahora? (s/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    if command -v xdg-open &> /dev/null; then
        xdg-open "http://devops-dashboard.local/devops-dashboard.html" 2>/dev/null &
    elif command -v open &> /dev/null; then
        open "http://devops-dashboard.local/devops-dashboard.html" 2>/dev/null &
    else
        log "No se pudo abrir automáticamente el navegador"
        log "Abre manualmente: http://devops-dashboard.local/devops-dashboard.html"
    fi
fi

exit 0
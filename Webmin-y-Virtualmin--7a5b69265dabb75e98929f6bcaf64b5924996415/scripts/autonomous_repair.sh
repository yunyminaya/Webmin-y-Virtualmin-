#!/bin/bash

# ============================================================================
# 🔧 SISTEMA DE AUTO-REPARACIÓN AUTÓNOMA COMPLETA
# ============================================================================
# Sistema que se ejecuta automáticamente sin intervención humana
# Detecta, diagnostica y repara problemas automáticamente
# Se ejecuta como servicio systemd o cron job
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuración del sistema autónomo
AUTO_REPAIR_LOG="$SCRIPT_DIR/auto_repair_daemon.log"
AUTO_REPAIR_STATUS="$SCRIPT_DIR/auto_repair_status.json"
BACKUP_DIR="/backups/auto_repair_autonomous"
MONITORING_INTERVAL=300  # 5 minutos por defecto
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-root@localhost}"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función de logging autónoma
autonomous_log() {
    local level="$1"
    local component="$2"
    local message="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Log principal
    echo "[$timestamp] [$level] [$component] $message" >> "$AUTO_REPAIR_LOG"

    # Log del sistema
    logger -t "AUTO_REPAIR[$component]" "$level: $message"

    # Mostrar en pantalla solo si no es ejecución automática
    if [[ "${AUTO_MODE:-false}" != "true" ]]; then
        case "$level" in
            "CRITICAL") echo -e "${RED}[$component CRITICAL]${NC} $message" ;;
            "WARNING")  echo -e "${YELLOW}[$component WARNING]${NC} $message" ;;
            "INFO")     echo -e "${BLUE}[$component INFO]${NC} $message" ;;
            "SUCCESS")  echo -e "${GREEN}[$component SUCCESS]${NC} $message" ;;
            "REPAIR")   echo -e "${PURPLE}[$component REPAIR]${NC} $message" ;;
        esac
    fi
}

# Función para actualizar estado del sistema
update_system_status() {
    local status_data="$1"
    echo "$status_data" > "$AUTO_REPAIR_STATUS"
}

# Función para enviar notificaciones automáticas
send_notification() {
    local subject="$1"
    local message="$2"
    local priority="${3:-normal}"

    # Intentar enviar email si está configurado
    if command -v mail >/dev/null 2>&1 && [[ -n "$NOTIFICATION_EMAIL" ]]; then
        echo "$message" | mail -s "$subject" "$NOTIFICATION_EMAIL"
    fi

    # Log de notificación
    autonomous_log "INFO" "NOTIFICATION" "Enviada: $subject"
}

# Función de monitoreo continuo autónoma
autonomous_monitoring() {
    autonomous_log "INFO" "MONITORING" "Iniciando monitoreo autónomo del sistema..."

    local issues_found=0
    local critical_issues=0
    local repairs_attempted=0
    local repairs_successful=0

    # Monitoreo de servicios críticos
    local critical_services=("webmin" "apache2" "nginx" "mysql" "mariadb" "postfix" "dovecot" "ssh" "ufw" "fail2ban")

    for service in "${critical_services[@]}"; do
        if ! systemctl is-active --quiet "$service" 2>/dev/null; then
            autonomous_log "WARNING" "MONITORING" "Servicio $service inactivo detectado"
            ((issues_found++))
            ((critical_issues++))

            # Intentar reparación automática
            if autonomous_repair_service "$service"; then
                ((repairs_attempted++))
                ((repairs_successful++))
                autonomous_log "SUCCESS" "MONITORING" "Servicio $service reparado automáticamente"
            else
                ((repairs_attempted++))
                autonomous_log "CRITICAL" "MONITORING" "FALLÓ reparación automática de $service"
            fi
        fi
    done

    # Monitoreo de recursos del sistema
    local mem_usage cpu_usage disk_usage

    mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}' 2>/dev/null || echo "0")
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' 2>/dev/null || echo "0")
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//' 2>/dev/null || echo "0")

    # Reparaciones automáticas de recursos
    if [[ $mem_usage -gt 90 ]]; then
        autonomous_log "CRITICAL" "MONITORING" "Memoria crítica: ${mem_usage}%"
        if autonomous_free_memory; then
            autonomous_log "SUCCESS" "MONITORING" "Memoria liberada automáticamente"
        fi
    elif [[ $mem_usage -gt 80 ]]; then
        autonomous_log "WARNING" "MONITORING" "Memoria alta: ${mem_usage}%"
        ((issues_found++))
    fi

    if [[ $cpu_usage -gt 95 ]]; then
        autonomous_log "CRITICAL" "MONITORING" "CPU crítica: ${cpu_usage}%"
        if autonomous_kill_high_cpu_processes; then
            autonomous_log "SUCCESS" "MONITORING" "Procesos de alta CPU terminados"
        fi
    fi

    if [[ $disk_usage -gt 95 ]]; then
        autonomous_log "CRITICAL" "MONITORING" "Disco crítico: ${disk_usage}%"
        if autonomous_clean_disk_space; then
            autonomous_log "SUCCESS" "MONITORING" "Espacio en disco liberado"
        fi
    fi

    # Monitoreo de red y conectividad
    if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        autonomous_log "CRITICAL" "MONITORING" "Sin conectividad a internet"
        if autonomous_repair_network; then
            autonomous_log "SUCCESS" "MONITORING" "Conectividad restaurada"
        fi
    fi

    # Actualizar estado del sistema
    local status_data
    status_data=$(cat << EOF
{
    "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')",
    "issues_found": $issues_found,
    "critical_issues": $critical_issues,
    "repairs_attempted": $repairs_attempted,
    "repairs_successful": $repairs_successful,
    "system_resources": {
        "memory_usage": $mem_usage,
        "cpu_usage": $cpu_usage,
        "disk_usage": $disk_usage
    },
    "services_status": "monitored"
}
EOF
    )
    update_system_status "$status_data"

    # Generar reporte automático si hay problemas
    if [[ $issues_found -gt 0 ]]; then
        autonomous_generate_report
    fi

    # Notificaciones automáticas para problemas críticos
    if [[ $critical_issues -gt 0 ]]; then
        send_notification "ALERTA: Problemas Críticos Detectados" "Se encontraron $critical_issues problemas críticos en el sistema. Reparaciones automáticas ejecutadas: $repairs_successful/$repairs_attempted exitosas." "high"
    fi

    autonomous_log "INFO" "MONITORING" "Monitoreo completado: $issues_found problemas encontrados, $repairs_successful reparaciones exitosas"
}

# Función de reparación automática de servicios
autonomous_repair_service() {
    local service="$1"
    autonomous_log "REPAIR" "SERVICE" "Intentando reparación automática de $service"

    # Intentar reinicio simple primero
    if systemctl restart "$service" 2>/dev/null; then
        sleep 3
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            return 0
        fi
    fi

    # Para Apache específico
    if [[ "$service" == "apache2" ]]; then
        return $(autonomous_repair_apache)
    fi

    # Para servicios de base de datos
    if [[ "$service" == "mysql" ]] || [[ "$service" == "mariadb" ]]; then
        return $(autonomous_repair_database)
    fi

    # Para Webmin
    if [[ "$service" == "webmin" ]]; then
        return $(autonomous_repair_webmin)
    fi

    # Reparación genérica final
    if systemctl start "$service" 2>/dev/null; then
        sleep 2
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            return 0
        fi
    fi

    return 1
}

# Función específica para reparar Apache automáticamente
autonomous_repair_apache() {
    autonomous_log "REPAIR" "APACHE" "Reparación especializada de Apache iniciada"

    # Verificar configuración
    if ! apache2ctl configtest >/dev/null 2>&1; then
        autonomous_log "WARNING" "APACHE" "Configuración inválida detectada"

        # Backup de configuración actual
        mkdir -p "$BACKUP_DIR"
        cp -r /etc/apache2 "$BACKUP_DIR/apache_backup_$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true

        # Crear configuración mínima
        cat > /etc/apache2/apache2.conf << 'EOF'
DefaultRuntimeDir ${APACHE_RUN_DIR}
PidFile ${APACHE_PID_FILE}
Timeout 300
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 5
User www-data
Group www-data
ErrorLog ${APACHE_LOG_DIR}/error.log
LogLevel warn
IncludeOptional mods-enabled/*.load
IncludeOptional mods-enabled/*.conf
Include ports.conf
<Directory />
    Options FollowSymLinks
    AllowOverride None
    Require all denied
</Directory>
<Directory /var/www/>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
IncludeOptional sites-enabled/*.conf
EOF

        # Crear sitio por defecto
        mkdir -p /etc/apache2/sites-available
        cat > /etc/apache2/sites-available/000-default.conf << 'EOF'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

        ln -sf /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-enabled/ 2>/dev/null || true
    fi

    # Crear directorios necesarios
    mkdir -p /var/www/html
    mkdir -p /var/log/apache2

    # Crear index.html básico
    cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Servidor Apache - Auto-Reparado</title></head>
<body><h1>Apache reparado automáticamente</h1><p>Sistema funcionando correctamente</p></body>
</html>
EOF

    # Intentar iniciar Apache
    if systemctl start apache2 2>/dev/null; then
        sleep 3
        if systemctl is-active --quiet apache2 2>/dev/null; then
            autonomous_log "SUCCESS" "APACHE" "Apache reparado y funcionando"
            return 0
        fi
    fi

    autonomous_log "ERROR" "APACHE" "No se pudo reparar Apache automáticamente"
    return 1
}

# Función para reparar base de datos automáticamente
autonomous_repair_database() {
    autonomous_log "REPAIR" "DATABASE" "Reparación automática de base de datos"

    # Detectar tipo de base de datos
    local db_service=""
    if systemctl list-units | grep -q mysql; then
        db_service="mysql"
    elif systemctl list-units | grep -q mariadb; then
        db_service="mariadb"
    fi

    if [[ -n "$db_service" ]]; then
        if systemctl restart "$db_service" 2>/dev/null; then
            sleep 5
            if systemctl is-active --quiet "$db_service" 2>/dev/null; then
                autonomous_log "SUCCESS" "DATABASE" "Base de datos reparada"
                return 0
            fi
        fi
    fi

    return 1
}

# Función para reparar Webmin automáticamente
autonomous_repair_webmin() {
    autonomous_log "REPAIR" "WEBMIN" "Reparación automática de Webmin"

    if systemctl restart webmin 2>/dev/null; then
        sleep 3
        if systemctl is-active --quiet webmin 2>/dev/null; then
            autonomous_log "SUCCESS" "WEBMIN" "Webmin reparado"
            return 0
        fi
    fi

    return 1
}

# Función para liberar memoria automáticamente
autonomous_free_memory() {
    autonomous_log "REPAIR" "MEMORY" "Liberando memoria del sistema"

    # Liberar cache de memoria
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

    # Limpiar archivos temporales
    find /tmp -name "*.tmp" -type f -mtime +1 -delete 2>/dev/null || true

    autonomous_log "SUCCESS" "MEMORY" "Memoria liberada"
    return 0
}

# Función para terminar procesos de alta CPU
autonomous_kill_high_cpu_processes() {
    autonomous_log "REPAIR" "CPU" "Terminando procesos de alta CPU"

    # Encontrar procesos con CPU > 90%
    local high_cpu_pids
    high_cpu_pids=$(ps aux --no-headers | awk '$3 > 90 {print $2}' | head -5)

    if [[ -n "$high_cpu_pids" ]]; then
        echo "$high_cpu_pids" | xargs kill -9 2>/dev/null || true
        autonomous_log "SUCCESS" "CPU" "Procesos de alta CPU terminados"
    fi

    return 0
}

# Función para limpiar espacio en disco
autonomous_clean_disk_space() {
    autonomous_log "REPAIR" "DISK" "Liberando espacio en disco"

    # Limpiar cache de paquetes
    if command -v apt-get >/dev/null 2>&1; then
        apt-get clean >/dev/null 2>&1
        apt-get autoclean >/dev/null 2>&1
    fi

    # Limpiar archivos de log antiguos
    find /var/log -name "*.log.*" -type f -mtime +7 -delete 2>/dev/null || true

    # Limpiar archivos temporales
    find /tmp -type f -mtime +7 -delete 2>/dev/null || true

    autonomous_log "SUCCESS" "DISK" "Espacio en disco liberado"
    return 0
}

# Función para reparar conectividad de red
autonomous_repair_network() {
    autonomous_log "REPAIR" "NETWORK" "Reparando conectividad de red"

    # Reiniciar servicios de red
    systemctl restart networking 2>/dev/null || true
    systemctl restart NetworkManager 2>/dev/null || true

    # Verificar conectividad
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        autonomous_log "SUCCESS" "NETWORK" "Conectividad restaurada"
        return 0
    fi

    return 1
}

# Función para generar reportes automáticos
autonomous_generate_report() {
    autonomous_log "INFO" "REPORT" "Generando reporte automático"

    local report_file="$SCRIPT_DIR/auto_repair_report_$(date +%Y%m%d_%H%M%S).html"

    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Reporte de Auto-Reparación Autónoma</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #007cba; color: white; padding: 15px; border-radius: 5px; }
        .status { padding: 10px; margin: 10px 0; border-radius: 5px; }
        .ok { background: #d4edda; color: #155724; }
        .warning { background: #fff3cd; color: #856404; }
        .error { background: #f8d7da; color: #721c24; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔧 Reporte de Auto-Reparación Autónoma</h1>
        <p>Generado automáticamente: TIMESTAMP</p>
    </div>
EOF

    # Agregar datos del estado
    if [[ -f "$AUTO_REPAIR_STATUS" ]]; then
        echo "<div class=\"status\">" >> "$report_file"
        echo "<h2>Estado del Sistema</h2>" >> "$report_file"
        echo "<pre>$(cat "$AUTO_REPAIR_STATUS")</pre>" >> "$report_file"
        echo "</div>" >> "$report_file"
    fi

    # Agregar logs recientes
    echo "<div class=\"status\">" >> "$report_file"
    echo "<h2>Logs Recientes</h2>" >> "$report_file"
    echo "<pre>$(tail -20 "$AUTO_REPAIR_LOG" 2>/dev/null || echo "No hay logs disponibles")</pre>" >> "$report_file"
    echo "</div>" >> "$report_file"

    echo "</body></html>" >> "$report_file"

    # Reemplazar timestamp
    sed -i "s/TIMESTAMP/$(date)/" "$report_file"

    autonomous_log "SUCCESS" "REPORT" "Reporte generado: $report_file"
}

# Función para instalar el sistema autónomo
install_autonomous_system() {
    autonomous_log "INFO" "INSTALL" "Instalando sistema de auto-reparación autónoma"

    # Crear directorios necesarios
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$SCRIPT_DIR"

    # Crear archivo de configuración
    cat > "$SCRIPT_DIR/autonomous_config.sh" << EOF
#!/bin/bash
# Configuración del sistema autónomo
MONITORING_INTERVAL=$MONITORING_INTERVAL
NOTIFICATION_EMAIL=$NOTIFICATION_EMAIL
AUTO_REPAIR_LOG=$AUTO_REPAIR_LOG
AUTO_REPAIR_STATUS=$AUTO_REPAIR_STATUS
BACKUP_DIR=$BACKUP_DIR
EOF

    # Crear script de servicio systemd
    cat > "/etc/systemd/system/auto-repair.service" << EOF
[Unit]
Description=Auto-Repair Autonomous System
After=network.target

[Service]
Type=simple
User=root
ExecStart=$SCRIPT_DIR/autonomous_repair.sh daemon
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

    # Crear script de cron para monitoreo continuo
    cat > "/etc/cron.d/auto-repair" << EOF
# Auto-Repair Autonomous System
*/5 * * * * root $SCRIPT_DIR/autonomous_repair.sh monitor
EOF

    # Recargar systemd y habilitar servicio
    systemctl daemon-reload
    systemctl enable auto-repair
    systemctl start auto-repair

    autonomous_log "SUCCESS" "INSTALL" "Sistema autónomo instalado y activado"
}

# Función para ejecutar como daemon
run_as_daemon() {
    autonomous_log "INFO" "DAEMON" "Iniciando modo daemon"

    while true; do
        autonomous_monitoring
        sleep "$MONITORING_INTERVAL"
    done
}

# Función para ejecutar monitoreo único
run_monitoring() {
    export AUTO_MODE=true
    autonomous_monitoring
}

# Función principal
main() {
    case "${1:-}" in
        "install")
            install_autonomous_system
            ;;
        "daemon")
            run_as_daemon
            ;;
        "monitor")
            run_monitoring
            ;;
        "repair")
            autonomous_repair_apache
            ;;
        "status")
            if [[ -f "$AUTO_REPAIR_STATUS" ]]; then
                cat "$AUTO_REPAIR_STATUS"
            else
                echo "Sistema autónomo no inicializado"
            fi
            ;;
        "report")
            autonomous_generate_report
            ;;
        *)
            echo "Uso: $0 {install|daemon|monitor|repair|status|report}"
            echo ""
            echo "Comandos:"
            echo "  install  - Instalar el sistema autónomo"
            echo "  daemon   - Ejecutar como servicio continuo"
            echo "  monitor  - Ejecutar monitoreo único"
            echo "  repair   - Ejecutar reparación manual"
            echo "  status   - Ver estado del sistema"
            echo "  report   - Generar reporte"
            exit 1
            ;;
    esac
}

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Este script debe ejecutarse como root${NC}"
    echo -e "${YELLOW}💡 Ejecuta: sudo $0${NC}"
    exit 1
fi

# Crear archivos de log
mkdir -p "$SCRIPT_DIR"
touch "$AUTO_REPAIR_LOG"
touch "$AUTO_REPAIR_STATUS"

# Ejecutar función principal
main "$@"

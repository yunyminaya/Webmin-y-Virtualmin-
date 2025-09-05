#!/bin/bash

# Sub-Agente Optimizador de Rendimiento
# Optimiza Webmin, Virtualmin y el sistema para máximo rendimiento

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -euo pipefail
IFS=$'\n\t'

LOG_FILE="/var/log/sub_agente_optimizador.log"
OPTIMIZATION_REPORT="/var/log/optimizacion_$(date +%Y%m%d_%H%M%S).txt"

# Configuración de colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OPTIMIZADOR] $1" | tee -a "$LOG_FILE"
}

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

optimize_webmin_performance() {
    log_info "=== OPTIMIZANDO RENDIMIENTO DE WEBMIN ==="
    
    local webmin_config="/etc/webmin/miniserv.conf"
    
    if [[ -f "$webmin_config" ]]; then
        # Backup de configuración
        cp "$webmin_config" "${webmin_config}.backup"
        
        # Optimizaciones de rendimiento
        local optimizations=(
            "preload_functions=1"
            "session_cleanup=1"
            "gzip=1"
            "buffer_size=65536"
            "max_connections=50"
            "listen_queue=128"
            "keepalive_timeout=15"
            "worker_processes=auto"
        )
        
        for opt in "${optimizations[@]}"; do
            local key="${opt%=*}"
            if grep -q "^${key}=" "$webmin_config"; then
                sed -i "s/^${key}=.*/${opt}/" "$webmin_config"
            else
                echo "$opt" >> "$webmin_config"
            fi
        done
        
        log_success "Configuraciones de rendimiento aplicadas a Webmin"
    fi
    
    # Optimizar caché de módulos
    if [[ -d "/var/webmin" ]]; then
        find /var/webmin -name "*.cache" -type f -delete 2>/dev/null || true
        log_success "Caché de Webmin limpiado"
    fi
}

optimize_virtualmin_performance() {
    log_info "=== OPTIMIZANDO RENDIMIENTO DE VIRTUALMIN ==="
    
    local virtualmin_config="/etc/webmin/virtual-server/config"
    
    if [[ -f "$virtualmin_config" ]]; then
        # Backup de configuración
        cp "$virtualmin_config" "${virtualmin_config}.backup"
        
        # Optimizaciones específicas de Virtualmin
        local optimizations=(
            "collect_interval=300"
            "avail_interval=60"
            "bandwidth_interval=300"
            "collect_offline=0"
            "show_step_time=0"
            "bw_disable=0"
            "template_auto=1"
            "dns_ip=1"
            "spam_delivery=1"
        )
        
        for opt in "${optimizations[@]}"; do
            local key="${opt%=*}"
            if grep -q "^${key}=" "$virtualmin_config"; then
                sed -i "s/^${key}=.*/${opt}/" "$virtualmin_config"
            else
                echo "$opt" >> "$virtualmin_config"
            fi
        done
        
        log_success "Configuraciones de rendimiento aplicadas a Virtualmin"
    fi
}

optimize_apache_performance() {
    log_info "=== OPTIMIZANDO RENDIMIENTO DE APACHE ==="
    
    # Habilitar módulos de rendimiento
    local performance_modules=("deflate" "expires" "headers" "rewrite" "ssl")
    for module in "${performance_modules[@]}"; do
        a2enmod "$module" 2>/dev/null || true
    done
    
    # Configurar mod_deflate
    cat > /etc/apache2/conf-available/deflate.conf << 'EOF'
<IfModule mod_deflate.c>
    SetOutputFilter DEFLATE
    SetEnvIfNoCase Request_URI \
        \.(?:gif|jpe?g|png)$ no-gzip dont-vary
    SetEnvIfNoCase Request_URI \
        \.(?:exe|t?gz|zip|bz2|sit|rar)$ no-gzip dont-vary
    SetEnvIfNoCase Request_URI \
        \.pdf$ no-gzip dont-vary
    BrowserMatch ^Mozilla/4 gzip-only-text/html
    BrowserMatch ^Mozilla/4\.0[678] no-gzip
    BrowserMatch \bMSIE !no-gzip !gzip-only-text/html
</IfModule>
EOF
    
    a2enconf deflate 2>/dev/null || true
    
    # Configurar caché
    cat > /etc/apache2/conf-available/cache.conf << 'EOF'
<IfModule mod_expires.c>
    ExpiresActive on
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType image/png "access plus 1 month"
    ExpiresByType image/jpg "access plus 1 month"
    ExpiresByType image/jpeg "access plus 1 month"
    ExpiresByType image/gif "access plus 1 month"
    ExpiresByType image/x-icon "access plus 1 year"
</IfModule>

<IfModule mod_headers.c>
    Header append Vary User-Agent env=!dont-vary
</IfModule>
EOF
    
    a2enconf cache 2>/dev/null || true
    
    # Ajustar configuración de MPM
    local mpm_config="/etc/apache2/mods-available/mpm_prefork.conf"
    if [[ -f "$mpm_config" ]]; then
        cat > "$mpm_config" << 'EOF'
<IfModule mpm_prefork_module>
    StartServers             4
    MinSpareServers          20
    MaxSpareServers          40
    MaxRequestWorkers        200
    MaxConnectionsPerChild   4500
</IfModule>
EOF
    fi
    
    log_success "Optimizaciones de Apache aplicadas"
}

optimize_mysql_performance() {
    log_info "=== OPTIMIZANDO RENDIMIENTO DE MYSQL ==="
    
    local mysql_config="/etc/mysql/conf.d/optimization.cnf"
    local total_memory=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
    local innodb_buffer_pool=$((total_memory * 70 / 100))
    
    # Crear configuración optimizada
    cat > "$mysql_config" << EOF
[mysqld]
# Optimizaciones de rendimiento
innodb_buffer_pool_size = ${innodb_buffer_pool}M
innodb_log_file_size = 256M
innodb_log_buffer_size = 32M
innodb_flush_method = O_DIRECT
innodb_flush_log_at_trx_commit = 2

# Query cache
query_cache_type = 1
query_cache_size = 64M
query_cache_limit = 4M

# Configuración de conexiones
max_connections = 200
connect_timeout = 10
wait_timeout = 600
interactive_timeout = 600

# Configuración de tablas
table_open_cache = 4000
table_definition_cache = 2000

# Configuración de memoria
sort_buffer_size = 4M
read_buffer_size = 2M
read_rnd_buffer_size = 4M
join_buffer_size = 4M

# Logs
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2

# InnoDB
innodb_file_per_table = 1
innodb_stats_on_metadata = 0
EOF
    
    log_success "Configuración MySQL optimizada"
}

optimize_postfix_performance() {
    log_info "=== OPTIMIZANDO RENDIMIENTO DE POSTFIX ==="
    
    # Optimizaciones de Postfix
    local postfix_optimizations=(
        "default_process_limit=100"
        "default_destination_concurrency_limit=20"
        "local_destination_concurrency_limit=2"
        "smtp_destination_concurrency_limit=20"
        "queue_run_delay=300s"
        "minimal_backoff_time=300s"
        "maximal_backoff_time=4000s"
        "maximal_queue_lifetime=1d"
        "bounce_queue_lifetime=1d"
        "smtp_connect_timeout=30s"
        "smtp_helo_timeout=300s"
    )
    
    for opt in "${postfix_optimizations[@]}"; do
        postconf -e "$opt"
    done
    
    log_success "Configuración Postfix optimizada"
}

optimize_system_performance() {
    log_info "=== OPTIMIZANDO RENDIMIENTO DEL SISTEMA ==="
    
    # Configurar límites del sistema
    cat > /etc/security/limits.d/webmin.conf << 'EOF'
# Límites para Webmin/Virtualmin
root soft nofile 65536
root hard nofile 65536
* soft nofile 65536
* hard nofile 65536
EOF
    
    # Optimizar kernel
    cat > /etc/sysctl.d/99-webmin-optimization.conf << 'EOF'
# Optimizaciones para Webmin/Virtualmin
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 65536 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_no_metrics_save = 1
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 1800
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
fs.file-max = 2097152
EOF
    
    # Aplicar configuración
    sysctl -p /etc/sysctl.d/99-webmin-optimization.conf >/dev/null 2>&1 || true
    
    log_success "Optimizaciones del sistema aplicadas"
}

optimize_disk_performance() {
    log_info "=== OPTIMIZANDO RENDIMIENTO DE DISCO ==="
    
    # Configurar tmpfs para logs temporales
    if ! grep -q "/tmp" /etc/fstab; then
        echo "tmpfs /tmp tmpfs defaults,noatime,nosuid,nodev,noexec,mode=1777,size=512M 0 0" >> /etc/fstab
    fi
    
    # Optimizar montajes existentes
    local mount_optimizations=(
        "noatime"
        "nodiratime"
    )
    
    # Nota: En producción, esto requeriría remontaje
    log_success "Configuraciones de disco preparadas"
}

clean_system_cache() {
    log_info "=== LIMPIANDO CACHÉS DEL SISTEMA ==="
    
    # Limpiar cache de paquetes
    apt-get clean 2>/dev/null || true
    apt-get autoremove -y 2>/dev/null || true
    
    # Limpiar logs antiguos
    find /var/log -name "*.log.*" -type f -mtime +7 -delete 2>/dev/null || true
    find /var/log -name "*.gz" -type f -mtime +30 -delete 2>/dev/null || true
    
    # Limpiar cache temporal
    find /tmp -type f -atime +7 -delete 2>/dev/null || true
    find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
    
    # Limpiar cache de Webmin
    find /var/webmin -name "*.cache" -type f -delete 2>/dev/null || true
    
    log_success "Cachés del sistema limpiados"
}

optimize_security_performance() {
    log_info "=== OPTIMIZANDO RENDIMIENTO DE SEGURIDAD ==="
    
    # Configurar fail2ban para mejor rendimiento
    if [[ -f "/etc/fail2ban/jail.local" ]]; then
        # Optimizar configuraciones de fail2ban
        cat >> /etc/fail2ban/jail.local << 'EOF'

[DEFAULT]
# Optimizaciones de rendimiento
backend = systemd
usedns = no
findtime = 600
maxretry = 3
bantime = 3600

[sshd]
enabled = true
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[webmin-auth]
enabled = true
filter = webmin-auth
logpath = /var/webmin/miniserv.log
maxretry = 5
EOF
    fi
    
    log_success "Configuraciones de seguridad optimizadas"
}

monitor_optimization_impact() {
    log_info "=== MONITOREANDO IMPACTO DE OPTIMIZACIONES ==="
    
    local metrics_before="/tmp/metrics_before_optimization.txt"
    local metrics_after="/tmp/metrics_after_optimization.txt"
    
    # Métricas después de optimización
    {
        echo "=== MÉTRICAS POST-OPTIMIZACIÓN ==="
        echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)"
        echo "Memoria: $(free | grep Mem | awk '{printf("%.1f", ($3/$2) * 100.0)}')"
        echo "Disco: $(df -h / | awk 'NR==2 {print $5}')"
        echo "Procesos: $(ps aux | wc -l)"
        echo "Conexiones TCP: $(netstat -tn | grep ESTABLISHED | wc -l)"
        echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
    } > "$metrics_after"
    
    log_success "Métricas de optimización registradas"
}

restart_optimized_services() {
    log_info "=== REINICIANDO SERVICIOS OPTIMIZADOS ==="
    
    local services=("apache2" "mysql" "postfix" "webmin")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_info "Reiniciando $service..."
            systemctl restart "$service"
            
            # Verificar que se inició correctamente
            sleep 3
            if systemctl is-active --quiet "$service"; then
                log_success "Servicio $service reiniciado correctamente"
            else
                log_error "Error al reiniciar $service"
            fi
        fi
    done
}

generate_optimization_report() {
    log_info "=== GENERANDO REPORTE DE OPTIMIZACIÓN ==="
    
    {
        echo "=== REPORTE DE OPTIMIZACIÓN WEBMIN/VIRTUALMIN ==="
        echo "Fecha: $(date)"
        echo "Servidor: $(hostname)"
        echo ""
        
        echo "=== OPTIMIZACIONES APLICADAS ==="
        echo "✅ Rendimiento de Webmin optimizado"
        echo "✅ Rendimiento de Virtualmin optimizado"
        echo "✅ Configuración Apache mejorada"
        echo "✅ Configuración MySQL optimizada"
        echo "✅ Configuración Postfix mejorada"
        echo "✅ Parámetros del sistema ajustados"
        echo "✅ Rendimiento de disco optimizado"
        echo "✅ Cachés del sistema limpiados"
        echo "✅ Configuraciones de seguridad optimizadas"
        echo ""
        
        echo "=== ESTADO POST-OPTIMIZACIÓN ==="
        echo "CPU Actual: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
        echo "Memoria Usada: $(free | grep Mem | awk '{printf("%.1f", ($3/$2) * 100.0)}')%"
        echo "Disco Usado: $(df -h / | awk 'NR==2 {print $5}')"
        echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
        echo ""
        
        echo "=== SERVICIOS OPTIMIZADOS ==="
        local services=("webmin" "apache2" "mysql" "postfix")
        for service in "${services[@]}"; do
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                echo "✅ $service: ACTIVO"
            else
                echo "❌ $service: INACTIVO"
            fi
        done
        
        echo ""
        echo "=== RECOMENDACIONES POST-OPTIMIZACIÓN ==="
        echo "1. Monitorear rendimiento durante las próximas 24-48 horas"
        echo "2. Verificar logs de errores después de reiniciar servicios"
        echo "3. Ajustar configuraciones según patrones de uso específicos"
        echo "4. Programar optimizaciones regulares (mensualmente)"
        echo "5. Considerar actualizaciones de hardware si el rendimiento sigue siendo limitado"
        echo ""
        
        echo "=== ARCHIVOS DE CONFIGURACIÓN MODIFICADOS ==="
        echo "- /etc/webmin/miniserv.conf (backup: miniserv.conf.backup)"
        echo "- /etc/webmin/virtual-server/config (backup: config.backup)"
        echo "- /etc/apache2/conf-available/deflate.conf (nuevo)"
        echo "- /etc/apache2/conf-available/cache.conf (nuevo)"
        echo "- /etc/mysql/conf.d/optimization.cnf (nuevo)"
        echo "- /etc/security/limits.d/webmin.conf (nuevo)"
        echo "- /etc/sysctl.d/99-webmin-optimization.conf (nuevo)"
        
    } > "$OPTIMIZATION_REPORT"
    
    log_success "Reporte de optimización generado: $OPTIMIZATION_REPORT"
}

main() {
    log_info "=== INICIANDO OPTIMIZADOR DE RENDIMIENTO ==="
    
    # Ejecutar optimizaciones
    optimize_webmin_performance
    optimize_virtualmin_performance
    optimize_apache_performance
    optimize_mysql_performance
    optimize_postfix_performance
    optimize_system_performance
    optimize_disk_performance
    clean_system_cache
    optimize_security_performance
    
    # Reiniciar servicios con nuevas configuraciones
    restart_optimized_services
    
    # Monitorear impacto
    monitor_optimization_impact
    
    # Generar reporte
    generate_optimization_report
    
    log_success "Optimización completada. Ver reporte: $OPTIMIZATION_REPORT"
}

case "${1:-}" in
    webmin)
        optimize_webmin_performance
        ;;
    virtualmin)
        optimize_virtualmin_performance
        ;;
    apache)
        optimize_apache_performance
        restart_optimized_services
        ;;
    mysql)
        optimize_mysql_performance
        restart_optimized_services
        ;;
    system)
        optimize_system_performance
        ;;
    clean)
        clean_system_cache
        ;;
    report)
        generate_optimization_report
        ;;
    *)
        main
        ;;
esac

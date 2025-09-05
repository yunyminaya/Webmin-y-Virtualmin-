#!/bin/bash

# Sub-Agente Monitor de Servidores Virtuales
# Supervisión 24/7 de dominios y servidores virtuales

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/sub_agente_monitor_servidores_virtuales.log"
STATUS_FILE="/var/lib/webmin/virtual_servers_status.json"
CONFIG_FILE="/etc/webmin/monitor_virtual_config.conf"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [MONITOR-VIRTUAL] $1" | tee -a "$LOG_FILE"
}

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configuración Monitor Servidores Virtuales
MONITOR_ENABLED=true
CHECK_INTERVAL=300
HEALTH_CHECK_TIMEOUT=30
MAX_FAILED_CHECKS=3
AUTO_RESTART_SERVICES=true
NOTIFICATION_ENABLED=true
DNS_CHECK_ENABLED=true
SSL_CHECK_ENABLED=true
PERFORMANCE_MONITORING=true
DOMAIN_EXPIRY_CHECK=true
ALERT_THRESHOLD_RESPONSE_TIME=5000
EOF
    fi
    source "$CONFIG_FILE"
}

get_virtual_servers() {
    log_message "Obteniendo lista de servidores virtuales"
    
    local servers_list="/tmp/virtual_servers.tmp"
    > "$servers_list"
    
    # Método 1: Comando virtualmin
    if command -v virtualmin &> /dev/null; then
        virtualmin list-domains --multiline 2>/dev/null | grep "^Domain name:" | awk '{print $3}' >> "$servers_list"
    fi
    
    # Método 2: Archivo de configuración
    if [ -f "/etc/webmin/virtual-server/domains" ]; then
        grep -v "^#" "/etc/webmin/virtual-server/domains" | awk '{print $1}' | grep -v "^$" >> "$servers_list"
    fi
    
    # Método 3: Apache VirtualHosts
    if [ -d "/etc/apache2/sites-available" ]; then
        grep -h "ServerName\|ServerAlias" /etc/apache2/sites-available/*.conf 2>/dev/null | awk '{print $2}' | grep -v "^$" >> "$servers_list"
    fi
    
    # Método 4: Nginx server blocks
    if [ -d "/etc/nginx/sites-available" ]; then
        grep -h "server_name" /etc/nginx/sites-available/* 2>/dev/null | awk '{for(i=2;i<=NF;i++) print $i}' | sed 's/;//g' >> "$servers_list"
    fi
    
    # Eliminar duplicados y limpiar
    sort "$servers_list" | uniq | grep -E "^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$" > "${servers_list}.clean"
    mv "${servers_list}.clean" "$servers_list"
    
    echo "$servers_list"
}

check_domain_health() {
    local domain="$1"
    local health_status="healthy"
    local issues=()
    local response_time=0
    
    # Test DNS
    if [ "$DNS_CHECK_ENABLED" = "true" ]; then
        if ! nslookup "$domain" >/dev/null 2>&1; then
            health_status="unhealthy"
            issues+=("DNS_FAILED")
        fi
    fi
    
    # Test HTTP Response
    local start_time=$(date +%s%N)
    if curl -s -I -m "$HEALTH_CHECK_TIMEOUT" "http://$domain" >/dev/null 2>&1; then
        local end_time=$(date +%s%N)
        response_time=$(( (end_time - start_time) / 1000000 ))
        
        if [ "$response_time" -gt "$ALERT_THRESHOLD_RESPONSE_TIME" ]; then
            health_status="slow"
            issues+=("SLOW_RESPONSE:${response_time}ms")
        fi
    else
        health_status="unhealthy"
        issues+=("HTTP_FAILED")
    fi
    
    # Test HTTPS
    if [ "$SSL_CHECK_ENABLED" = "true" ]; then
        if ! curl -s -k -I -m "$HEALTH_CHECK_TIMEOUT" "https://$domain" >/dev/null 2>&1; then
            issues+=("HTTPS_FAILED")
        else
            # Verificar certificado SSL
            local cert_expiry=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null | grep "notAfter" | cut -d= -f2)
            if [ -n "$cert_expiry" ]; then
                local expiry_timestamp=$(date -d "$cert_expiry" +%s 2>/dev/null || echo "0")
                local current_timestamp=$(date +%s)
                local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
                
                if [ "$days_until_expiry" -lt 30 ]; then
                    issues+=("SSL_EXPIRING:${days_until_expiry}days")
                fi
            fi
        fi
    fi
    
    # Test Base de Datos (si es aplicación web)
    local web_root="/var/www/$domain"
    if [ -d "$web_root" ]; then
        # WordPress
        if [ -f "$web_root/wp-config.php" ]; then
            if ! curl -s "http://$domain/wp-admin/admin-ajax.php" | grep -q "0"; then
                issues+=("WP_DB_FAILED")
            fi
        fi
        
        # Laravel
        if [ -f "$web_root/artisan" ]; then
            cd "$web_root"
            if ! php artisan tinker --execute="DB::connection()->getPdo();" >/dev/null 2>&1; then
                issues+=("LARAVEL_DB_FAILED")
            fi
        fi
    fi
    
    echo "{\"domain\":\"$domain\",\"status\":\"$health_status\",\"response_time\":$response_time,\"issues\":[\"$(IFS=','; echo "${issues[*]}")\"],\"last_check\":\"$(date -Iseconds)\"}"
}

monitor_all_virtual_servers() {
    log_message "=== MONITOREANDO TODOS LOS SERVIDORES VIRTUALES ==="
    
    local servers_file=$(get_virtual_servers)
    local total_domains=0
    local healthy_domains=0
    local unhealthy_domains=0
    local slow_domains=0
    
    local status_array="["
    local first_domain=true
    
    if [ -f "$servers_file" ]; then
        while read domain; do
            if [ -n "$domain" ]; then
                ((total_domains++))
                log_message "Verificando: $domain"
                
                local domain_status=$(check_domain_health "$domain")
                local status=$(echo "$domain_status" | jq -r '.status')
                
                case "$status" in
                    "healthy")
                        ((healthy_domains++))
                        ;;
                    "unhealthy")
                        ((unhealthy_domains++))
                        log_message "❌ Dominio con problemas: $domain"
                        ;;
                    "slow")
                        ((slow_domains++))
                        log_message "⚠️  Dominio lento: $domain"
                        ;;
                esac
                
                # Agregar al JSON
                if [ "$first_domain" = "true" ]; then
                    first_domain=false
                else
                    status_array+=","
                fi
                status_array+="$domain_status"
            fi
        done < "$servers_file"
        
        rm -f "$servers_file"
    fi
    
    status_array+="]"
    
    # Crear reporte JSON completo
    cat > "$STATUS_FILE" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "summary": {
        "total_domains": $total_domains,
        "healthy": $healthy_domains,
        "unhealthy": $unhealthy_domains,
        "slow": $slow_domains,
        "success_rate": $(( total_domains > 0 ? (healthy_domains * 100) / total_domains : 0 ))
    },
    "domains": $status_array
}
EOF
    
    log_message "Estado actualizado: $total_domains dominios ($healthy_domains ok, $unhealthy_domains fallos, $slow_domains lentos)"
    
    # Alertas si hay problemas
    if [ "$unhealthy_domains" -gt 0 ] || [ "$slow_domains" -gt 3 ]; then
        send_critical_alert "$unhealthy_domains dominios con fallos, $slow_domains dominios lentos"
    fi
}

send_critical_alert() {
    local message="$1"
    log_message "🚨 ALERTA CRÍTICA: $message"
    
    # Log de alertas críticas
    echo "[$(date -Iseconds)] SERVIDORES VIRTUALES: $message" >> "/var/log/alertas_criticas_virtuales.log"
    
    # Webhook notification
    if command -v curl &> /dev/null && [ -n "${NOTIFICATION_WEBHOOK:-}" ]; then
        curl -X POST "$NOTIFICATION_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"alert\":\"CRITICAL\",\"service\":\"virtual_servers\",\"message\":\"$message\",\"timestamp\":\"$(date -Iseconds)\"}" \
            2>/dev/null || true
    fi
}

auto_repair_services() {
    log_message "=== REPARACIÓN AUTOMÁTICA DE SERVICIOS ==="
    
    if [ "$AUTO_RESTART_SERVICES" != "true" ]; then
        log_message "Reparación automática deshabilitada"
        return 0
    fi
    
    local services_restarted=0
    
    # Verificar servicios críticos
    local critical_services=("apache2" "nginx" "mysql" "mariadb" "bind9" "named" "postfix" "dovecot")
    
    for service in "${critical_services[@]}"; do
        if systemctl list-unit-files | grep -q "^${service}.service"; then
            if ! systemctl is-active --quiet "$service"; then
                log_message "⚠️  Servicio $service inactivo - Reiniciando"
                systemctl restart "$service" 2>/dev/null || true
                ((services_restarted++))
                
                sleep 5
                
                if systemctl is-active --quiet "$service"; then
                    log_message "✅ Servicio $service reiniciado exitosamente"
                else
                    log_message "❌ Error al reiniciar $service"
                    send_critical_alert "No se pudo reiniciar el servicio $service"
                fi
            fi
        fi
    done
    
    log_message "Servicios reiniciados: $services_restarted"
}

check_virtual_server_resources() {
    log_message "=== VERIFICANDO RECURSOS DE SERVIDORES VIRTUALES ==="
    
    local resource_report="/var/log/recursos_virtuales_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== REPORTE DE RECURSOS SERVIDORES VIRTUALES ==="
        echo "Fecha: $(date)"
        echo ""
        
        # Verificar uso de disco por dominio
        echo "=== USO DE DISCO POR DOMINIO ==="
        if [ -d "/home" ]; then
            du -sh /home/* 2>/dev/null | sort -hr | head -20
        fi
        
        echo ""
        echo "=== PROCESOS POR USUARIO/DOMINIO ==="
        ps aux | awk '{user[$1]++} END {for (u in user) print user[u], u}' | sort -nr | head -10
        
        echo ""
        echo "=== CONEXIONES POR SERVICIO ==="
        netstat -tulpn | grep LISTEN | awk '{print $4}' | cut -d: -f2 | sort | uniq -c | sort -nr
        
        echo ""
        echo "=== BASES DE DATOS POR USUARIO ==="
        if command -v mysql &> /dev/null; then
            mysql -e "SELECT User, COUNT(*) as DB_Count FROM mysql.db GROUP BY User;" 2>/dev/null || echo "No se pudo acceder a MySQL"
        fi
        
        echo ""
        echo "=== ARCHIVOS LOGS GRANDES ==="
        find /var/log /home/*/logs -name "*.log" -size +100M 2>/dev/null | head -10
        
        echo ""
        echo "=== ALERTAS DE RECURSOS ==="
        local high_usage_domains=()
        
        if [ -d "/home" ]; then
            while read size domain; do
                local size_gb=$(echo "$size" | sed 's/G.*//' | sed 's/M.*/0.001/')
                if (( $(echo "$size_gb > 10" | bc -l 2>/dev/null || echo "0") )); then
                    high_usage_domains+=("$domain: $size")
                fi
            done < <(du -sh /home/* 2>/dev/null | grep -E "[0-9]+G")
        fi
        
        if [ ${#high_usage_domains[@]} -gt 0 ]; then
            echo "⚠️  Dominios con alto uso de disco:"
            printf '%s\n' "${high_usage_domains[@]}"
        else
            echo "✅ Uso de disco normal en todos los dominios"
        fi
        
    } > "$resource_report"
    
    log_message "✓ Reporte de recursos: $resource_report"
}

monitor_domain_accessibility() {
    log_message "=== MONITOREANDO ACCESIBILIDAD DE DOMINIOS ==="
    
    local servers_file=$(get_virtual_servers)
    local accessibility_report="/var/log/accesibilidad_dominios_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== REPORTE DE ACCESIBILIDAD DE DOMINIOS ==="
        echo "Fecha: $(date)"
        echo ""
        
        local total_checked=0
        local accessible=0
        local inaccessible=0
        local slow_response=0
        
        if [ -f "$servers_file" ]; then
            while read domain; do
                if [ -n "$domain" ]; then
                    ((total_checked++))
                    echo "Verificando: $domain"
                    
                    # Test HTTP
                    local start_time=$(date +%s%N)
                    if curl -s -I -m "$HEALTH_CHECK_TIMEOUT" "http://$domain" | grep -q "HTTP/[12]"; then
                        local end_time=$(date +%s%N)
                        local response_time=$(( (end_time - start_time) / 1000000 ))
                        
                        echo "  ✅ HTTP: OK (${response_time}ms)"
                        ((accessible++))
                        
                        if [ "$response_time" -gt "$ALERT_THRESHOLD_RESPONSE_TIME" ]; then
                            echo "  ⚠️  Respuesta lenta: ${response_time}ms"
                            ((slow_response++))
                        fi
                    else
                        echo "  ❌ HTTP: FALLÓ"
                        ((inaccessible++))
                    fi
                    
                    # Test HTTPS
                    if curl -s -k -I -m "$HEALTH_CHECK_TIMEOUT" "https://$domain" | grep -q "HTTP/[12]"; then
                        echo "  ✅ HTTPS: OK"
                    else
                        echo "  ⚠️  HTTPS: FALLÓ"
                    fi
                    
                    # Test específico de aplicación
                    local web_root="/var/www/$domain"
                    if [ -d "$web_root" ]; then
                        if [ -f "$web_root/wp-config.php" ]; then
                            if curl -s "http://$domain" | grep -q "wp-content"; then
                                echo "  ✅ WordPress: OK"
                            else
                                echo "  ❌ WordPress: PROBLEMA"
                            fi
                        elif [ -f "$web_root/artisan" ]; then
                            if curl -s "http://$domain" | grep -q -E "(Laravel|Blade|csrf_token)"; then
                                echo "  ✅ Laravel: OK"
                            else
                                echo "  ❌ Laravel: PROBLEMA"
                            fi
                        fi
                    fi
                    
                    echo ""
                fi
            done < "$servers_file"
            
            rm -f "$servers_file"
        fi
        
        echo "=== RESUMEN ==="
        echo "Total verificados: $total_checked"
        echo "Accesibles: $accessible"
        echo "Inaccesibles: $inaccessible"
        echo "Respuesta lenta: $slow_response"
        echo "Tasa de éxito: $(( total_checked > 0 ? (accessible * 100) / total_checked : 0 ))%"
        
        if [ "$inaccessible" -gt 0 ]; then
            echo ""
            echo "⚠️  ACCIÓN REQUERIDA: $inaccessible dominios inaccesibles"
        fi
        
    } > "$accessibility_report"
    
    log_message "✓ Reporte de accesibilidad: $accessibility_report"
    
    # Enviar alerta si hay problemas
    if [ "$inaccessible" -gt 0 ]; then
        send_critical_alert "$inaccessible dominios inaccesibles de $total_checked total"
    fi
}

auto_fix_virtual_servers() {
    log_message "=== REPARACIÓN AUTOMÁTICA DE SERVIDORES VIRTUALES ==="
    
    local fixes_applied=0
    
    # Verificar configuración Apache
    if command -v apache2ctl &> /dev/null; then
        if ! apache2ctl configtest >/dev/null 2>&1; then
            log_message "⚠️  Configuración Apache con errores - Intentando reparar"
            
            # Deshabilitar sitios problemáticos temporalmente
            local broken_sites=$(apache2ctl configtest 2>&1 | grep -o '/etc/apache2/sites-enabled/[^:]*' | head -5)
            for site in $broken_sites; do
                if [ -f "$site" ]; then
                    a2dissite "$(basename "$site" .conf)" 2>/dev/null || true
                    log_message "Sitio deshabilitado temporalmente: $(basename "$site")"
                    ((fixes_applied++))
                fi
            done
            
            systemctl reload apache2
        fi
    fi
    
    # Verificar configuración Nginx
    if command -v nginx &> /dev/null; then
        if ! nginx -t >/dev/null 2>&1; then
            log_message "⚠️  Configuración Nginx con errores - Intentando reparar"
            
            # Mover archivos problemáticos
            local nginx_sites="/etc/nginx/sites-enabled"
            if [ -d "$nginx_sites" ]; then
                for site in "$nginx_sites"/*; do
                    if [ -f "$site" ] && ! nginx -t >/dev/null 2>&1; then
                        mv "$site" "${site}.disabled.$(date +%Y%m%d_%H%M%S)"
                        log_message "Sitio Nginx deshabilitado: $(basename "$site")"
                        ((fixes_applied++))
                    fi
                done
            fi
            
            nginx -s reload 2>/dev/null || systemctl restart nginx
        fi
    fi
    
    # Limpiar logs grandes
    find /var/log /home/*/logs -name "*.log" -size +500M 2>/dev/null | while read large_log; do
        if [ -f "$large_log" ]; then
            tail -1000 "$large_log" > "${large_log}.tmp"
            mv "${large_log}.tmp" "$large_log"
            log_message "Log truncado: $large_log"
            ((fixes_applied++))
        fi
    done
    
    # Reiniciar servicios si es necesario
    auto_repair_services
    
    log_message "Reparaciones aplicadas: $fixes_applied"
}

continuous_monitoring() {
    log_message "=== INICIANDO MONITOREO CONTINUO ==="
    
    local check_count=0
    local last_full_check=0
    
    while true; do
        ((check_count++))
        local current_time=$(date +%s)
        
        log_message "Verificación #$check_count"
        
        # Monitoreo básico cada ciclo
        monitor_all_virtual_servers
        
        # Verificación completa cada hora
        if [ $((current_time - last_full_check)) -gt 3600 ]; then
            check_virtual_server_resources
            auto_fix_virtual_servers
            last_full_check=$current_time
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

generate_daily_report() {
    log_message "=== GENERANDO REPORTE DIARIO ==="
    
    local daily_report="/var/log/reporte_diario_virtuales_$(date +%Y%m%d).txt"
    
    {
        echo "=========================================="
        echo "REPORTE DIARIO - SERVIDORES VIRTUALES"
        echo "=========================================="
        echo "Fecha: $(date)"
        echo "Servidor: $(hostname)"
        echo ""
        
        echo "=== RESUMEN EJECUTIVO ==="
        if [ -f "$STATUS_FILE" ]; then
            local total=$(jq -r '.summary.total_domains' "$STATUS_FILE" 2>/dev/null || echo "0")
            local healthy=$(jq -r '.summary.healthy' "$STATUS_FILE" 2>/dev/null || echo "0")
            local success_rate=$(jq -r '.summary.success_rate' "$STATUS_FILE" 2>/dev/null || echo "0")
            
            echo "Total de dominios monitoreados: $total"
            echo "Dominios operativos: $healthy"
            echo "Tasa de éxito: $success_rate%"
            
            if [ "$success_rate" -gt 95 ]; then
                echo "✅ ESTADO: EXCELENTE"
            elif [ "$success_rate" -gt 85 ]; then
                echo "⚠️  ESTADO: BUENO"
            else
                echo "❌ ESTADO: REQUIERE ATENCIÓN"
            fi
        fi
        
        echo ""
        echo "=== ESTADÍSTICAS DEL DÍA ==="
        echo "Verificaciones realizadas: $(grep -c "Verificando:" "$LOG_FILE" || echo "0")"
        echo "Reparaciones automáticas: $(grep -c "Reparaciones aplicadas:" "$LOG_FILE" || echo "0")"
        echo "Alertas generadas: $(grep -c "ALERTA CRÍTICA" "$LOG_FILE" || echo "0")"
        
        echo ""
        echo "=== DOMINIOS CON PROBLEMAS FRECUENTES ==="
        grep "❌\|⚠️ " "$LOG_FILE" | awk '{print $4}' | sort | uniq -c | sort -nr | head -5
        
        echo ""
        echo "=== RECOMENDACIONES ==="
        local unhealthy=$(jq -r '.summary.unhealthy' "$STATUS_FILE" 2>/dev/null || echo "0")
        if [ "$unhealthy" -gt 0 ]; then
            echo "🔧 Revisar dominios inaccesibles"
            echo "🔧 Verificar configuración DNS"
            echo "🔧 Comprobar configuración de servidor web"
        else
            echo "✅ Todos los servidores virtuales operativos"
        fi
        
    } > "$daily_report"
    
    log_message "✓ Reporte diario: $daily_report"
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")" "/var/lib/webmin" 2>/dev/null || true
    log_message "=== INICIANDO MONITOR DE SERVIDORES VIRTUALES ==="
    
    load_config
    
    case "${1:-monitor}" in
        monitor)
            monitor_all_virtual_servers
            ;;
        continuous)
            continuous_monitoring
            ;;
        repair)
            auto_fix_virtual_servers
            ;;
        resources)
            check_virtual_server_resources
            ;;
        accessibility)
            monitor_domain_accessibility
            ;;
        report)
            generate_daily_report
            cat "$daily_report" 2>/dev/null || echo "No hay reporte disponible"
            ;;
        status)
            if [ -f "$STATUS_FILE" ]; then
                jq '.' "$STATUS_FILE"
            else
                echo '{"error": "No hay estado disponible"}'
            fi
            ;;
        full)
            monitor_all_virtual_servers
            check_virtual_server_resources
            monitor_domain_accessibility
            auto_fix_virtual_servers
            generate_daily_report
            ;;
        *)
            echo "Sub-Agente Monitor de Servidores Virtuales"
            echo "Uso: $0 {monitor|continuous|repair|resources|accessibility|report|status|full}"
            echo ""
            echo "Comandos:"
            echo "  monitor       - Monitorear todos los servidores virtuales"
            echo "  continuous    - Monitoreo continuo 24/7"
            echo "  repair        - Reparación automática de problemas"
            echo "  resources     - Verificar recursos por dominio"
            echo "  accessibility - Probar accesibilidad de dominios"
            echo "  report        - Generar reporte diario"
            echo "  status        - Estado actual en JSON"
            echo "  full          - Verificación completa"
            exit 1
            ;;
    esac
    
    log_message "Monitor de servidores virtuales completado"
}

main "$@"
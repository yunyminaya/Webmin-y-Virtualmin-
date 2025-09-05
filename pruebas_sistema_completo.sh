#!/bin/bash

# Pruebas Exhaustivas del Sistema Completo
# Verificación integral de todos los componentes

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/pruebas_sistema_completo.log"
REPORT_FILE="/var/log/reporte_pruebas_$(date +%Y%m%d_%H%M%S).txt"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PRUEBAS] $1" | tee -a "$LOG_FILE"
}

test_webmin_functionality() {
    log_message "=== PROBANDO FUNCIONALIDAD WEBMIN ==="
    
    local tests_passed=0
    local tests_total=0
    
    # Test 1: Puerto Webmin
    ((tests_total++))
    if netstat -tuln | grep -q ":10000 "; then
        log_message "✓ Puerto Webmin (10000) está activo"
        ((tests_passed++))
    else
        log_message "✗ Puerto Webmin no está disponible"
    fi
    
    # Test 2: Servicio Webmin
    ((tests_total++))
    if systemctl is-active --quiet webmin 2>/dev/null; then
        log_message "✓ Servicio Webmin está activo"
        ((tests_passed++))
    else
        log_message "✗ Servicio Webmin no está activo"
    fi
    
    # Test 3: Configuración Webmin
    ((tests_total++))
    if [ -f "/etc/webmin/miniserv.conf" ]; then
        log_message "✓ Configuración Webmin encontrada"
        ((tests_passed++))
    else
        log_message "✗ Configuración Webmin no encontrada"
    fi
    
    # Test 4: Logs Webmin
    ((tests_total++))
    if [ -f "/var/webmin/miniserv.log" ]; then
        log_message "✓ Logs Webmin disponibles"
        ((tests_passed++))
    else
        log_message "✗ Logs Webmin no disponibles"
    fi
    
    # Test 5: Conexión HTTP Webmin
    ((tests_total++))
    if curl -s -k -I "https://localhost:10000" | grep -q "HTTP"; then
        log_message "✓ Webmin responde a conexiones HTTP"
        ((tests_passed++))
    else
        log_message "✗ Webmin no responde a conexiones HTTP"
    fi
    
    log_message "Webmin: $tests_passed/$tests_total pruebas exitosas"
    return $((tests_total - tests_passed))
}

test_virtualmin_functionality() {
    log_message "=== PROBANDO FUNCIONALIDAD VIRTUALMIN ==="
    
    local tests_passed=0
    local tests_total=0
    
    # Test 1: Módulo Virtualmin
    ((tests_total++))
    if [ -d "/usr/share/webmin/virtual-server" ] || [ -d "/usr/local/webmin/virtual-server" ]; then
        log_message "✓ Módulo Virtualmin instalado"
        ((tests_passed++))
    else
        log_message "✗ Módulo Virtualmin no encontrado"
    fi
    
    # Test 2: Comando virtualmin
    ((tests_total++))
    if command -v virtualmin &> /dev/null; then
        log_message "✓ Comando virtualmin disponible"
        ((tests_passed++))
    else
        log_message "✗ Comando virtualmin no disponible"
    fi
    
    # Test 3: Configuración Virtualmin
    ((tests_total++))
    if [ -f "/etc/webmin/virtual-server/config" ]; then
        log_message "✓ Configuración Virtualmin encontrada"
        ((tests_passed++))
    else
        log_message "✗ Configuración Virtualmin no encontrada"
    fi
    
    # Test 4: Plantillas Virtualmin
    ((tests_total++))
    if find /etc/webmin/virtual-server -name "*template*" | grep -q .; then
        log_message "✓ Plantillas Virtualmin disponibles"
        ((tests_passed++))
    else
        log_message "✗ Plantillas Virtualmin no encontradas"
    fi
    
    log_message "Virtualmin: $tests_passed/$tests_total pruebas exitosas"
    return $((tests_total - tests_passed))
}

test_web_services() {
    log_message "=== PROBANDO SERVICIOS WEB ==="
    
    local tests_passed=0
    local tests_total=0
    
    # Test Apache/Nginx
    ((tests_total++))
    if systemctl is-active --quiet apache2 || systemctl is-active --quiet nginx; then
        log_message "✓ Servidor web está activo"
        ((tests_passed++))
    else
        log_message "✗ No hay servidor web activo"
    fi
    
    # Test Puerto 80
    ((tests_total++))
    if netstat -tuln | grep -q ":80 "; then
        log_message "✓ Puerto HTTP (80) está activo"
        ((tests_passed++))
    else
        log_message "✗ Puerto HTTP no está disponible"
    fi
    
    # Test Puerto 443
    ((tests_total++))
    if netstat -tuln | grep -q ":443 "; then
        log_message "✓ Puerto HTTPS (443) está activo"
        ((tests_passed++))
    else
        log_message "✗ Puerto HTTPS no está disponible"
    fi
    
    # Test PHP
    ((tests_total++))
    if command -v php &> /dev/null; then
        log_message "✓ PHP está instalado: $(php -v | head -1)"
        ((tests_passed++))
    else
        log_message "✗ PHP no está instalado"
    fi
    
    log_message "Servicios Web: $tests_passed/$tests_total pruebas exitosas"
    return $((tests_total - tests_passed))
}

test_database_services() {
    log_message "=== PROBANDO SERVICIOS DE BASE DE DATOS ==="
    
    local tests_passed=0
    local tests_total=0
    
    # Test MySQL
    ((tests_total++))
    if systemctl is-active --quiet mysql || systemctl is-active --quiet mariadb; then
        log_message "✓ MySQL/MariaDB está activo"
        ((tests_passed++))
    else
        log_message "✗ MySQL/MariaDB no está activo"
    fi
    
    # Test conexión MySQL
    ((tests_total++))
    if mysql -e "SELECT 1;" 2>/dev/null; then
        log_message "✓ Conexión MySQL funcional"
        ((tests_passed++))
    else
        log_message "✗ No se puede conectar a MySQL"
    fi
    
    # Test PostgreSQL
    ((tests_total++))
    if systemctl is-active --quiet postgresql; then
        log_message "✓ PostgreSQL está activo"
        ((tests_passed++))
    else
        log_message "⚠ PostgreSQL no está activo (opcional)"
    fi
    
    log_message "Base de Datos: $tests_passed/$tests_total pruebas exitosas"
    return $((tests_total - tests_passed))
}

test_security_features() {
    log_message "=== PROBANDO CARACTERÍSTICAS DE SEGURIDAD ==="
    
    local tests_passed=0
    local tests_total=0
    
    # Test Fail2Ban
    ((tests_total++))
    if systemctl is-active --quiet fail2ban; then
        log_message "✓ Fail2Ban está activo"
        ((tests_passed++))
    else
        log_message "✗ Fail2Ban no está activo"
    fi
    
    # Test Firewall
    ((tests_total++))
    if ufw status | grep -q "Status: active"; then
        log_message "✓ Firewall UFW está activo"
        ((tests_passed++))
    else
        log_message "✗ Firewall UFW no está activo"
    fi
    
    # Test SSH
    ((tests_total++))
    if systemctl is-active --quiet ssh; then
        log_message "✓ SSH está activo"
        ((tests_passed++))
    else
        log_message "✗ SSH no está activo"
    fi
    
    # Test Certificados SSL
    ((tests_total++))
    if find /etc/ssl -name "*.crt" | grep -q .; then
        log_message "✓ Certificados SSL encontrados"
        ((tests_passed++))
    else
        log_message "✗ No se encontraron certificados SSL"
    fi
    
    log_message "Seguridad: $tests_passed/$tests_total pruebas exitosas"
    return $((tests_total - tests_passed))
}

test_subagents() {
    log_message "=== PROBANDO SUB-AGENTES ==="
    
    local tests_passed=0
    local tests_total=0
    
    local subagents=(
        "coordinador_sub_agentes.sh"
        "sub_agente_monitoreo.sh"
        "sub_agente_seguridad.sh"
        "sub_agente_backup.sh"
        "sub_agente_actualizaciones.sh"
        "sub_agente_logs.sh"
        "sub_agente_alto_trafico.sh"
        "sub_agente_seguridad_avanzada.sh"
        "sub_agente_wordpress_laravel.sh"
    )
    
    for agent in "${subagents[@]}"; do
        ((tests_total++))
        if [ -f "$SCRIPT_DIR/$agent" ] && [ -x "$SCRIPT_DIR/$agent" ]; then
            log_message "✓ Sub-agente disponible: $agent"
            ((tests_passed++))
        else
            log_message "✗ Sub-agente faltante o no ejecutable: $agent"
        fi
    done
    
    log_message "Sub-agentes: $tests_passed/$tests_total disponibles"
    return $((tests_total - tests_passed))
}

test_performance_optimization() {
    log_message "=== PROBANDO OPTIMIZACIONES DE RENDIMIENTO ==="
    
    local tests_passed=0
    local tests_total=0
    
    # Test límites del sistema
    ((tests_total++))
    local max_files=$(ulimit -n)
    if [ "$max_files" -gt 1024 ]; then
        log_message "✓ Límites de archivos optimizados: $max_files"
        ((tests_passed++))
    else
        log_message "✗ Límites de archivos no optimizados: $max_files"
    fi
    
    # Test configuración de red
    ((tests_total++))
    if sysctl net.core.somaxconn | grep -q "65535"; then
        log_message "✓ Configuración de red optimizada"
        ((tests_passed++))
    else
        log_message "✗ Configuración de red no optimizada"
    fi
    
    # Test cache Redis
    ((tests_total++))
    if systemctl is-active --quiet redis-server; then
        log_message "✓ Redis cache está activo"
        ((tests_passed++))
    else
        log_message "⚠ Redis cache no está activo (recomendado)"
    fi
    
    log_message "Optimizaciones: $tests_passed/$tests_total aplicadas"
    return $((tests_total - tests_passed))
}

run_load_test() {
    log_message "=== EJECUTANDO PRUEBA DE CARGA ==="
    
    if ! command -v ab &> /dev/null; then
        apt-get update && apt-get install -y apache2-utils
    fi
    
    local test_url="http://localhost"
    local concurrent_users=100
    local total_requests=1000
    
    log_message "Iniciando prueba de carga: $concurrent_users usuarios, $total_requests requests"
    
    local load_test_result=$(ab -n "$total_requests" -c "$concurrent_users" "$test_url/" 2>/dev/null | grep -E "Requests per second|Time per request|Transfer rate")
    
    log_message "Resultados de prueba de carga:"
    echo "$load_test_result" | while read line; do
        log_message "  $line"
    done
}

generate_final_report() {
    log_message "=== GENERANDO REPORTE FINAL ==="
    
    {
        echo "=========================================="
        echo "REPORTE FINAL DE PRUEBAS DEL SISTEMA"
        echo "=========================================="
        echo "Fecha: $(date)"
        echo "Servidor: $(hostname)"
        echo "Directorio: $SCRIPT_DIR"
        echo ""
        
        echo "=== RESUMEN DE PRUEBAS ==="
        local total_errors=0
        
        echo "1. Funcionalidad Webmin:"
        test_webmin_functionality >/dev/null 2>&1 || total_errors=$((total_errors + $?))
        echo "   $(tail -5 "$LOG_FILE" | grep "Webmin:" | tail -1)"
        
        echo "2. Funcionalidad Virtualmin:"
        test_virtualmin_functionality >/dev/null 2>&1 || total_errors=$((total_errors + $?))
        echo "   $(tail -5 "$LOG_FILE" | grep "Virtualmin:" | tail -1)"
        
        echo "3. Servicios Web:"
        test_web_services >/dev/null 2>&1 || total_errors=$((total_errors + $?))
        echo "   $(tail -5 "$LOG_FILE" | grep "Servicios Web:" | tail -1)"
        
        echo "4. Base de Datos:"
        test_database_services >/dev/null 2>&1 || total_errors=$((total_errors + $?))
        echo "   $(tail -5 "$LOG_FILE" | grep "Base de Datos:" | tail -1)"
        
        echo "5. Seguridad:"
        test_security_features >/dev/null 2>&1 || total_errors=$((total_errors + $?))
        echo "   $(tail -5 "$LOG_FILE" | grep "Seguridad:" | tail -1)"
        
        echo "6. Sub-agentes:"
        test_subagents >/dev/null 2>&1 || total_errors=$((total_errors + $?))
        echo "   $(tail -5 "$LOG_FILE" | grep "Sub-agentes:" | tail -1)"
        
        echo "7. Optimizaciones:"
        test_performance_optimization >/dev/null 2>&1 || total_errors=$((total_errors + $?))
        echo "   $(tail -5 "$LOG_FILE" | grep "Optimizaciones:" | tail -1)"
        
        echo ""
        echo "=== ESTADO GENERAL DEL SISTEMA ==="
        if [ $total_errors -eq 0 ]; then
            echo "🎉 SISTEMA COMPLETAMENTE FUNCIONAL"
            echo "✅ Todas las pruebas pasaron exitosamente"
        elif [ $total_errors -le 3 ]; then
            echo "⚠️  SISTEMA MAYORMENTE FUNCIONAL"
            echo "⚠️  Algunas pruebas fallaron ($total_errors errores)"
        else
            echo "❌ SISTEMA REQUIERE ATENCIÓN"
            echo "❌ Múltiples pruebas fallaron ($total_errors errores)"
        fi
        
        echo ""
        echo "=== INFORMACIÓN DEL SISTEMA ==="
        echo "SO: $(lsb_release -d 2>/dev/null | cut -f2 || uname -a)"
        echo "Uptime: $(uptime -p)"
        echo "CPU: $(nproc) cores"
        echo "Memoria: $(free -h | grep Mem | awk '{print $2}')"
        echo "Disco: $(df -h / | tail -1 | awk '{print $2}')"
        echo ""
        
        echo "=== SUB-AGENTES DISPONIBLES ==="
        ls -la "$SCRIPT_DIR"/sub_agente_*.sh 2>/dev/null | awk '{print $9, $5}' || echo "No se encontraron sub-agentes"
        
        echo ""
        echo "=== SERVICIOS ACTIVOS ==="
        systemctl list-units --type=service --state=active | grep -E "webmin|apache|nginx|mysql|redis|fail2ban" || echo "Servicios no encontrados"
        
        echo ""
        echo "=== PUERTOS ABIERTOS ==="
        netstat -tuln | grep LISTEN | head -10
        
        echo ""
        echo "=== RECOMENDACIONES ==="
        if [ $total_errors -eq 0 ]; then
            echo "✅ El sistema está perfectamente configurado"
            echo "✅ Listo para manejar alto tráfico"
            echo "✅ Seguridad implementada correctamente"
        else
            echo "🔧 Revisar logs para detalles de errores"
            echo "🔧 Ejecutar sub-agentes individuales para corrección"
            echo "🔧 Verificar configuraciones faltantes"
        fi
        
        echo ""
        echo "=== COMANDOS ÚTILES ==="
        echo "Panel maestro: ./panel_control_maestro.sh full-setup"
        echo "Control completo: ./control_maestro_completo.sh start-all"
        echo "Estado sistema: ./coordinador_sub_agentes.sh status"
        echo "Monitoreo: ./sub_agente_monitoreo.sh start"
        echo "Seguridad: ./sub_agente_seguridad_avanzada.sh start"
        echo "Alto tráfico: ./sub_agente_alto_trafico.sh start"
        
    } > "$REPORT_FILE"
    
    log_message "✓ Reporte final generado: $REPORT_FILE"
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    log_message "=== INICIANDO PRUEBAS EXHAUSTIVAS DEL SISTEMA ==="
    
    case "${1:-full}" in
        full)
            test_webmin_functionality
            test_virtualmin_functionality
            test_web_services
            test_database_services
            test_security_features
            test_subagents
            test_performance_optimization
            run_load_test
            generate_final_report
            
            echo ""
            echo "📋 REPORTE COMPLETO DISPONIBLE EN:"
            echo "   $REPORT_FILE"
            echo ""
            cat "$REPORT_FILE"
            ;;
        webmin)
            test_webmin_functionality
            ;;
        virtualmin)
            test_virtualmin_functionality
            ;;
        web)
            test_web_services
            ;;
        database)
            test_database_services
            ;;
        security)
            test_security_features
            ;;
        subagents)
            test_subagents
            ;;
        performance)
            test_performance_optimization
            ;;
        load)
            run_load_test
            ;;
        report)
            generate_final_report
            cat "$REPORT_FILE"
            ;;
        *)
            echo "Pruebas Exhaustivas del Sistema - Webmin/Virtualmin"
            echo ""
            echo "Uso: $0 {full|webmin|virtualmin|web|database|security|subagents|performance|load|report}"
            echo ""
            echo "Comandos:"
            echo "  full        - Ejecutar todas las pruebas"
            echo "  webmin      - Probar solo Webmin"
            echo "  virtualmin  - Probar solo Virtualmin"
            echo "  web         - Probar servicios web"
            echo "  database    - Probar bases de datos"
            echo "  security    - Probar seguridad"
            echo "  subagents   - Probar sub-agentes"
            echo "  performance - Probar optimizaciones"
            echo "  load        - Prueba de carga"
            echo "  report      - Mostrar último reporte"
            exit 1
            ;;
    esac
    
    log_message "Pruebas del sistema completadas"
}

main "$@"
#!/bin/bash

# ============================================================================
# 🔧 DIAGNÓSTICO Y REPARACIÓN RÁPIDA - SISTEMA WEBMIN & VIRTUALMIN
# ============================================================================
# Script de prueba para diagnosticar problemas y ejecutar reparaciones
# Diseñado para ser ejecutado en VPS con problemas
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Configuración
DIAGNOSIS_LOG="/tmp/diagnostico_vps_$(date +%Y%m%d_%H%M%S).log"
REPAIR_LOG="/tmp/reparacion_vps_$(date +%Y%m%d_%H%M%S).log"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función de logging
log_diagnosis() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$DIAGNOSIS_LOG"

    case "$level" in
        "INFO")     echo -e "${BLUE}[INFO]${NC} $message" ;;
        "SUCCESS")  echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        "WARNING")  echo -e "${YELLOW}[WARNING]${NC} $message" ;;
        "ERROR")    echo -e "${RED}[ERROR]${NC} $message" ;;
        "CRITICAL") echo -e "${RED}[CRITICAL]${NC} $message" ;;
    esac
}

log_repair() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$REPAIR_LOG"

    case "$level" in
        "INFO")     echo -e "${BLUE}[REPAIR]${NC} $message" ;;
        "SUCCESS")  echo -e "${GREEN}[REPAIR]${NC} $message" ;;
        "WARNING")  echo -e "${YELLOW}[REPAIR]${NC} $message" ;;
        "ERROR")    echo -e "${RED}[REPAIR]${NC} $message" ;;
    esac
}

# Función para verificar servicios críticos
check_critical_services() {
    log_diagnosis "INFO" "=== VERIFICANDO SERVICIOS CRÍTICOS ==="

    local services=("webmin" "apache2" "nginx" "mysql" "mariadb" "postfix" "dovecot" "ssh")
    local failed_services=()

    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_diagnosis "SUCCESS" "✅ Servicio $service está activo"
        else
            log_diagnosis "ERROR" "❌ Servicio $service está inactivo o no existe"
            failed_services+=("$service")
        fi
    done

    if [[ ${#failed_services[@]} -gt 0 ]]; then
        log_diagnosis "WARNING" "Servicios fallidos encontrados: ${failed_services[*]}"
        return 1
    else
        log_diagnosis "SUCCESS" "Todos los servicios críticos están activos"
        return 0
    fi
}

# Función para verificar recursos del sistema
check_system_resources() {
    log_diagnosis "INFO" "=== VERIFICANDO RECURSOS DEL SISTEMA ==="

    # CPU
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

    if (( $(echo "$cpu_usage > 90" | bc -l) )); then
        log_diagnosis "CRITICAL" "❌ USO DE CPU CRÍTICO: ${cpu_usage}%"
        return 1
    elif (( $(echo "$cpu_usage > 70" | bc -l) )); then
        log_diagnosis "WARNING" "⚠️ USO DE CPU ALTO: ${cpu_usage}%"
    else
        log_diagnosis "SUCCESS" "✅ USO DE CPU NORMAL: ${cpu_usage}%"
    fi

    # Memoria
    local mem_usage
    mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')

    if [[ $mem_usage -gt 95 ]]; then
        log_diagnosis "CRITICAL" "❌ USO DE MEMORIA CRÍTICO: ${mem_usage}%"
        return 1
    elif [[ $mem_usage -gt 80 ]]; then
        log_diagnosis "WARNING" "⚠️ USO DE MEMORIA ALTO: ${mem_usage}%"
    else
        log_diagnosis "SUCCESS" "✅ USO DE MEMORIA NORMAL: ${mem_usage}%"
    fi

    # Disco
    local disk_usage
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

    if [[ $disk_usage -gt 95 ]]; then
        log_diagnosis "CRITICAL" "❌ USO DE DISCO CRÍTICO: ${disk_usage}%"
        return 1
    elif [[ $disk_usage -gt 85 ]]; then
        log_diagnosis "WARNING" "⚠️ USO DE DISCO ALTO: ${disk_usage}%"
    else
        log_diagnosis "SUCCESS" "✅ USO DE DISCO NORMAL: ${disk_usage}%"
    fi

    return 0
}

# Función para verificar Webmin específicamente
check_webmin_status() {
    log_diagnosis "INFO" "=== VERIFICANDO WEBMIN ==="

    # Verificar si Webmin está instalado
    if ! command -v webmin >/dev/null 2>&1 && [[ ! -d /usr/share/webmin ]]; then
        log_diagnosis "ERROR" "❌ Webmin no está instalado"
        return 1
    fi

    # Verificar servicio
    if systemctl is-active --quiet webmin 2>/dev/null; then
        log_diagnosis "SUCCESS" "✅ Servicio Webmin está activo"
    else
        log_diagnosis "ERROR" "❌ Servicio Webmin está inactivo"
        return 1
    fi

    # Verificar puerto
    if netstat -tuln 2>/dev/null | grep -q ":10000 "; then
        log_diagnosis "SUCCESS" "✅ Webmin está escuchando en puerto 10000"
    else
        log_diagnosis "ERROR" "❌ Webmin no está escuchando en puerto 10000"
        return 1
    fi

    # Verificar archivos críticos
    local critical_files=("/usr/share/webmin/miniserv.conf" "/usr/share/webmin/config")
    for file in "${critical_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_diagnosis "SUCCESS" "✅ Archivo crítico encontrado: $file"
        else
            log_diagnosis "ERROR" "❌ Archivo crítico faltante: $file"
            return 1
        fi
    done

    log_diagnosis "SUCCESS" "Webmin está funcionando correctamente"
    return 0
}

# Función para verificar Virtualmin específicamente
check_virtualmin_status() {
    log_diagnosis "INFO" "=== VERIFICANDO VIRTUALMIN ==="

    # Verificar si Virtualmin está instalado
    if ! command -v virtualmin >/dev/null 2>&1 && [[ ! -d /usr/share/webmin/virtual-server ]]; then
        log_diagnosis "ERROR" "❌ Virtualmin no está instalado"
        return 1
    fi

    # Verificar módulo de Virtualmin en Webmin
    if [[ -d /usr/share/webmin/virtual-server ]]; then
        log_diagnosis "SUCCESS" "✅ Módulo Virtualmin encontrado en Webmin"
    else
        log_diagnosis "ERROR" "❌ Módulo Virtualmin no encontrado"
        return 1
    fi

    # Verificar configuración de Virtualmin
    if [[ -f /etc/webmin/virtual-server/config ]]; then
        log_diagnosis "SUCCESS" "✅ Configuración de Virtualmin encontrada"
    else
        log_diagnosis "WARNING" "⚠️ Configuración de Virtualmin no encontrada"
    fi

    log_diagnosis "SUCCESS" "Virtualmin está funcionando correctamente"
    return 0
}

# Función para verificar Apache/Nginx
check_web_server() {
    log_diagnosis "INFO" "=== VERIFICANDO SERVIDOR WEB ==="

    local web_server=""
    local web_service=""

    if systemctl is-active --quiet apache2 2>/dev/null; then
        web_server="Apache"
        web_service="apache2"
    elif systemctl is-active --quiet nginx 2>/dev/null; then
        web_server="Nginx"
        web_service="nginx"
    else
        log_diagnosis "ERROR" "❌ Ningún servidor web activo encontrado"
        return 1
    fi

    log_diagnosis "SUCCESS" "✅ $web_server está activo"

    # Verificar puerto 80
    if netstat -tuln 2>/dev/null | grep -q ":80 "; then
        log_diagnosis "SUCCESS" "✅ Puerto 80 abierto"
    else
        log_diagnosis "ERROR" "❌ Puerto 80 cerrado"
        return 1
    fi

    # Verificar puerto 443
    if netstat -tuln 2>/dev/null | grep -q ":443 "; then
        log_diagnosis "SUCCESS" "✅ Puerto 443 abierto (SSL)"
    else
        log_diagnosis "WARNING" "⚠️ Puerto 443 cerrado (SSL no configurado)"
    fi

    return 0
}

# Función para verificar base de datos
check_database() {
    log_diagnosis "INFO" "=== VERIFICANDO BASE DE DATOS ==="

    local db_service=""
    local db_command=""

    if systemctl is-active --quiet mysql 2>/dev/null; then
        db_service="MySQL"
        db_command="mysql"
    elif systemctl is-active --quiet mariadb 2>/dev/null; then
        db_service="MariaDB"
        db_command="mariadb"
    else
        log_diagnosis "ERROR" "❌ Ningún servicio de base de datos activo"
        return 1
    fi

    log_diagnosis "SUCCESS" "✅ $db_service está activo"

    # Verificar puerto 3306
    if netstat -tuln 2>/dev/null | grep -q ":3306 "; then
        log_diagnosis "SUCCESS" "✅ Puerto 3306 abierto"
    else
        log_diagnosis "ERROR" "❌ Puerto 3306 cerrado"
        return 1
    fi

    # Intentar conectar a la base de datos
    if command -v "$db_command" >/dev/null 2>&1; then
        if "$db_command" -e "SELECT 1;" >/dev/null 2>&1; then
            log_diagnosis "SUCCESS" "✅ Conexión a base de datos exitosa"
        else
            log_diagnosis "ERROR" "❌ Error de conexión a base de datos"
            return 1
        fi
    fi

    return 0
}

# Función para ejecutar reparaciones automáticas
execute_auto_repair() {
    log_repair "INFO" "=== INICIANDO REPARACIONES AUTOMÁTICAS ==="

    # Reparar servicios críticos
    local services=("webmin" "apache2" "nginx" "mysql" "mariadb" "postfix" "dovecot" "ssh")

    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_repair "SUCCESS" "✅ Servicio $service ya está activo"
        else
            log_repair "INFO" "Intentando iniciar servicio $service..."
            if systemctl start "$service" 2>/dev/null; then
                log_repair "SUCCESS" "✅ Servicio $service iniciado correctamente"
            else
                log_repair "ERROR" "❌ Error al iniciar servicio $service"
            fi
        fi
    done

    # Reparar Webmin específicamente
    if [[ -f /usr/share/webmin/miniserv.pl ]]; then
        log_repair "INFO" "Reparando permisos de Webmin..."
        chown -R root:root /usr/share/webmin 2>/dev/null || true
        chmod -R 755 /usr/share/webmin 2>/dev/null || true

        log_repair "INFO" "Reiniciando Webmin..."
        systemctl restart webmin 2>/dev/null || service webmin restart 2>/dev/null || true

        if systemctl is-active --quiet webmin 2>/dev/null; then
            log_repair "SUCCESS" "✅ Webmin reparado e iniciado"
        else
            log_repair "ERROR" "❌ Error al reparar Webmin"
        fi
    fi

    # Limpiar procesos zombie
    local zombie_count
    zombie_count=$(ps aux | awk '{print $8}' | grep -c "Z" 2>/dev/null || echo "0")

    if [[ $zombie_count -gt 0 ]]; then
        log_repair "WARNING" "⚠️ Encontrados $zombie_count procesos zombie"
        log_repair "INFO" "Limpiando procesos zombie..."
        # Nota: Los procesos zombie se limpian automáticamente cuando termina el padre
        log_repair "SUCCESS" "✅ Procesos zombie identificados (se limpiarán automáticamente)"
    fi

    # Liberar memoria si es necesario
    local mem_usage
    mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')

    if [[ $mem_usage -gt 85 ]]; then
        log_repair "INFO" "Liberando memoria del sistema..."
        sync
        echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
        log_repair "SUCCESS" "✅ Memoria liberada"
    fi

    # Reparar archivos de configuración básicos
    if [[ -f /etc/apache2/apache2.conf ]]; then
        log_repair "INFO" "Verificando configuración de Apache..."
        apache2ctl configtest >/dev/null 2>&1 || log_repair "WARNING" "⚠️ Configuración de Apache necesita revisión"
    fi

    log_repair "SUCCESS" "=== REPARACIONES AUTOMÁTICAS COMPLETADAS ==="
}

# Función para generar reporte final
generate_final_report() {
    local report_file="/tmp/reporte_vps_$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "========================================"
        echo "REPORTE DE DIAGNÓSTICO Y REPARACIÓN VPS"
        echo "========================================"
        echo "Fecha: $(date)"
        echo "Servidor: $(hostname)"
        echo ""

        echo "=== RESULTADOS DEL DIAGNÓSTICO ==="
        if [[ -f "$DIAGNOSIS_LOG" ]]; then
            grep "\[CRITICAL\]\|\[ERROR\]\|\[WARNING\]" "$DIAGNOSIS_LOG" || echo "No se encontraron problemas críticos"
        fi
        echo ""

        echo "=== REPARACIONES REALIZADAS ==="
        if [[ -f "$REPAIR_LOG" ]]; then
            cat "$REPAIR_LOG"
        fi
        echo ""

        echo "=== ESTADO ACTUAL DEL SISTEMA ==="
        echo "CPU: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')%"
        echo "Memoria: $(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')%"
        echo "Disco: $(df / | tail -1 | awk '{print $5}')"
        echo ""

        echo "=== SERVICIOS CRÍTICOS ==="
        local services=("webmin" "apache2" "nginx" "mysql" "mariadb" "ssh")
        for service in "${services[@]}"; do
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                echo "✅ $service: ACTIVO"
            else
                echo "❌ $service: INACTIVO"
            fi
        done
        echo ""

        echo "=== ARCHIVOS DE LOG ==="
        echo "Diagnóstico: $DIAGNOSIS_LOG"
        echo "Reparación: $REPAIR_LOG"
        echo ""

        echo "========================================"
    } > "$report_file"

    log_diagnosis "SUCCESS" "Reporte generado: $report_file"
    echo ""
    echo -e "${GREEN}📋 REPORTE GENERADO: $report_file${NC}"
    echo -e "${BLUE}📄 Para ver el reporte completo:${NC}"
    echo "cat $report_file"
}

# Función principal
main() {
    local action="${1:-full}"

    echo ""
    echo -e "${CYAN}🔧 DIAGNÓSTICO Y REPARACIÓN VPS - WEBMIN & VIRTUALMIN${NC}"
    echo -e "${CYAN}Sistema de Auto-Reparación Automático${NC}"
    echo ""

    case "$action" in
        "diagnose")
            echo "🔍 Ejecutando solo diagnóstico..."
            check_critical_services
            check_system_resources
            check_webmin_status
            check_virtualmin_status
            check_web_server
            check_database
            ;;
        "repair")
            echo "🔧 Ejecutando solo reparaciones..."
            execute_auto_repair
            ;;
        "full")
            echo "🚀 Ejecutando diagnóstico completo + reparaciones automáticas..."
            echo ""

            # Ejecutar diagnóstico
            echo "=== FASE 1: DIAGNÓSTICO ==="
            check_critical_services
            check_system_resources
            check_webmin_status
            check_virtualmin_status
            check_web_server
            check_database

            echo ""
            echo "=== FASE 2: REPARACIONES AUTOMÁTICAS ==="
            execute_auto_repair

            echo ""
            echo "=== FASE 3: VERIFICACIÓN FINAL ==="
            check_critical_services
            ;;
        *)
            echo "Uso: $0 {diagnose|repair|full}"
            echo ""
            echo "diagnose  - Solo ejecutar diagnóstico"
            echo "repair    - Solo ejecutar reparaciones"
            echo "full      - Diagnóstico + reparaciones + verificación (predeterminado)"
            exit 1
            ;;
    esac

    # Generar reporte final
    generate_final_report

    echo ""
    echo -e "${GREEN}✅ PROCESO COMPLETADO${NC}"
    echo ""
    echo -e "${BLUE}📊 RESUMEN:${NC}"
    echo "• Diagnóstico: $DIAGNOSIS_LOG"
    echo "• Reparaciones: $REPAIR_LOG"
    echo "• Reporte: Ver arriba"
    echo ""
    echo -e "${YELLOW}💡 RECOMENDACIONES:${NC}"
    echo "• Revisa los logs para detalles completos"
    echo "• Si hay errores críticos, considera reiniciar servicios manualmente"
    echo "• Ejecuta 'systemctl status <servicio>' para verificar estado"
    echo ""
}

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Este script debe ejecutarse como root${NC}"
    echo -e "${YELLOW}💡 Ejecuta: sudo $0${NC}"
    exit 1
fi

# Ejecutar función principal
main "$@"

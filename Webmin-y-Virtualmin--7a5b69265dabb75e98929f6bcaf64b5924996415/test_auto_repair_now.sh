#!/bin/bash

# ============================================================================
# 🧪 PRUEBA RÁPIDA DEL SISTEMA DE AUTO-REPARACIÓN
# ============================================================================
# Script simple para probar si el auto-reparador funciona en tu VPS
# Ejecuta diagnóstico básico y reparaciones automáticas
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Configuración
TEST_LOG="/tmp/prueba_auto_repair_$(date +%Y%m%d_%H%M%S).log"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función de logging
test_log() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$TEST_LOG"

    case "$level" in
        "INFO")     echo -e "${BLUE}[TEST]${NC} $message" ;;
        "SUCCESS")  echo -e "${GREEN}[TEST]${NC} $message" ;;
        "WARNING")  echo -e "${YELLOW}[TEST]${NC} $message" ;;
        "ERROR")    echo -e "${RED}[TEST]${NC} $message" ;;
        "CRITICAL") echo -e "${RED}[CRITICAL]${NC} $message" ;;
    esac
}

# Función para probar servicios críticos
test_critical_services() {
    test_log "INFO" "🔍 Probando servicios críticos..."

    local services=("webmin" "apache2" "nginx" "mysql" "mariadb" "ssh")
    local failed_count=0

    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            test_log "SUCCESS" "✅ $service: ACTIVO"
        else
            test_log "ERROR" "❌ $service: INACTIVO/NO INSTALADO"
            ((failed_count++))
        fi
    done

    test_log "INFO" "Servicios probados: ${#services[@]}, Fallidos: $failed_count"
    return $failed_count
}

# Función para probar recursos del sistema
test_system_resources() {
    test_log "INFO" "📊 Probando recursos del sistema..."

    # CPU
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' 2>/dev/null || echo "N/A")

    if [[ "$cpu_usage" != "N/A" ]]; then
        if (( $(echo "$cpu_usage > 90" | bc -l 2>/dev/null || echo "0") )); then
            test_log "CRITICAL" "❌ CPU SOBRECARGADO: ${cpu_usage}%"
        elif (( $(echo "$cpu_usage > 70" | bc -l 2>/dev/null || echo "0") )); then
            test_log "WARNING" "⚠️ CPU ALTO: ${cpu_usage}%"
        else
            test_log "SUCCESS" "✅ CPU NORMAL: ${cpu_usage}%"
        fi
    fi

    # Memoria
    local mem_usage
    mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}' 2>/dev/null || echo "N/A")

    if [[ "$mem_usage" != "N/A" ]]; then
        if [[ $mem_usage -gt 95 ]]; then
            test_log "CRITICAL" "❌ MEMORIA CRÍTICA: ${mem_usage}%"
        elif [[ $mem_usage -gt 80 ]]; then
            test_log "WARNING" "⚠️ MEMORIA ALTA: ${mem_usage}%"
        else
            test_log "SUCCESS" "✅ MEMORIA NORMAL: ${mem_usage}%"
        fi
    fi

    # Disco
    local disk_usage
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//' 2>/dev/null || echo "N/A")

    if [[ "$disk_usage" != "N/A" ]]; then
        if [[ $disk_usage -gt 95 ]]; then
            test_log "CRITICAL" "❌ DISCO CRÍTICO: ${disk_usage}%"
        elif [[ $disk_usage -gt 85 ]]; then
            test_log "WARNING" "⚠️ DISCO ALTO: ${disk_usage}%"
        else
            test_log "SUCCESS" "✅ DISCO NORMAL: ${disk_usage}%"
        fi
    fi
}

# Función para probar Webmin específicamente
test_webmin_access() {
    test_log "INFO" "🌐 Probando acceso a Webmin..."

    # Verificar si Webmin está instalado
    if [[ ! -d /usr/share/webmin ]]; then
        test_log "ERROR" "❌ Webmin no está instalado"
        return 1
    fi

    # Verificar servicio
    if systemctl is-active --quiet webmin 2>/dev/null; then
        test_log "SUCCESS" "✅ Servicio Webmin activo"
    else
        test_log "ERROR" "❌ Servicio Webmin inactivo"
        return 1
    fi

    # Verificar puerto
    if timeout 5 bash -c "</dev/tcp/localhost/10000" 2>/dev/null; then
        test_log "SUCCESS" "✅ Puerto 10000 accesible"
    else
        test_log "ERROR" "❌ Puerto 10000 no accesible"
        return 1
    fi

    test_log "SUCCESS" "✅ Webmin funcionando correctamente"
    return 0
}

# Función para ejecutar reparaciones básicas
run_basic_repairs() {
    test_log "INFO" "🔧 Ejecutando reparaciones básicas..."

    local repaired_count=0

    # Intentar iniciar servicios críticos
    local services=("webmin" "apache2" "nginx" "mysql" "mariadb")

    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet "$service" 2>/dev/null && systemctl list-units --type=service | grep -q "$service"; then
            test_log "INFO" "Intentando iniciar $service..."
            if systemctl start "$service" 2>/dev/null; then
                test_log "SUCCESS" "✅ $service iniciado correctamente"
                ((repaired_count++))
            else
                test_log "ERROR" "❌ Error al iniciar $service"
            fi
        fi
    done

    # Liberar memoria si es necesario
    local mem_usage
    mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}' 2>/dev/null || echo "0")

    if [[ $mem_usage -gt 85 ]]; then
        test_log "INFO" "Liberando memoria del sistema..."
        sync
        echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
        test_log "SUCCESS" "✅ Memoria liberada"
        ((repaired_count++))
    fi

    test_log "INFO" "Reparaciones completadas: $repaired_count servicios reparados"
    return $repaired_count
}

# Función para mostrar resultados de la prueba
show_test_results() {
    local test_status="$1"
    local issues_found="$2"
    local repairs_made="$3"

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                           📊 RESULTADOS DE LA PRUEBA                        ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [[ $test_status -eq 0 ]]; then
        echo -e "${GREEN}✅ RESULTADO: SISTEMA FUNCIONANDO CORRECTAMENTE${NC}"
    else
        echo -e "${RED}❌ RESULTADO: PROBLEMAS DETECTADOS${NC}"
    fi

    echo ""
    echo -e "${BLUE}📋 DETALLES:${NC}"
    echo "   • Problemas encontrados: $issues_found"
    echo "   • Reparaciones realizadas: $repairs_made"
    echo "   • Log completo: $TEST_LOG"
    echo ""

    if [[ $issues_found -gt 0 ]]; then
        echo -e "${YELLOW}⚠️ RECOMENDACIONES:${NC}"
        echo "   • Revisa el log completo para detalles específicos"
        echo "   • Considera ejecutar reparaciones manuales adicionales"
        echo "   • Verifica la configuración de servicios críticos"
        echo ""
    fi

    if [[ $repairs_made -gt 0 ]]; then
        echo -e "${GREEN}🔧 REPARACIONES REALIZADAS:${NC}"
        echo "   • Servicios reiniciados automáticamente"
        echo "   • Memoria liberada si era necesario"
        echo "   • Sistema optimizado para mejor rendimiento"
        echo ""
    fi

    echo -e "${BLUE}📊 PARA MÁS DETALLES:${NC}"
    echo "   cat $TEST_LOG"
    echo ""

    if [[ $test_status -eq 0 ]]; then
        echo -e "${GREEN}🎉 ¡TU SISTEMA ESTÁ FUNCIONANDO PERFECTAMENTE!${NC}"
    else
        echo -e "${YELLOW}📞 CONSIDERA EJECUTAR EL DIAGNÓSTICO COMPLETO:${NC}"
        echo "   sudo bash scripts/diagnostico_reparacion_vps.sh full"
        echo ""
    fi
}

# Función principal
main() {
    echo ""
    echo -e "${CYAN}🧪 PRUEBA RÁPIDA DEL SISTEMA DE AUTO-REPARACIÓN${NC}"
    echo -e "${CYAN}Webmin & Virtualmin VPS${NC}"
    echo ""

    local issues_found=0
    local repairs_made=0
    local test_status=0

    # Ejecutar pruebas
    echo "=== FASE 1: PRUEBAS DE SERVICIOS ==="
    if ! test_critical_services; then
        ((issues_found++))
        test_status=1
    fi

    echo ""
    echo "=== FASE 2: PRUEBAS DE RECURSOS ==="
    test_system_resources

    echo ""
    echo "=== FASE 3: PRUEBA DE WEBMIN ==="
    if ! test_webmin_access; then
        ((issues_found++))
        test_status=1
    fi

    echo ""
    echo "=== FASE 4: REPARACIONES AUTOMÁTICAS ==="
    if repairs_made=$(run_basic_repairs); then
        test_log "INFO" "Reparaciones completadas exitosamente"
    else
        test_log "WARNING" "Algunas reparaciones pueden haber fallado"
    fi

    echo ""
    echo "=== FASE 5: VERIFICACIÓN FINAL ==="
    if test_webmin_access; then
        test_log "SUCCESS" "✅ Verificación final exitosa"
    else
        test_log "ERROR" "❌ Verificación final fallida"
        test_status=1
    fi

    # Mostrar resultados
    show_test_results "$test_status" "$issues_found" "$repairs_made"

    test_log "INFO" "Prueba rápida completada - Status: $test_status, Issues: $issues_found, Repairs: $repairs_made"

    return $test_status
}

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Este script debe ejecutarse como root${NC}"
    echo -e "${YELLOW}💡 Ejecuta: sudo $0${NC}"
    exit 1
fi

# Crear archivo de log
touch "$TEST_LOG"

# Ejecutar prueba
main "$@"

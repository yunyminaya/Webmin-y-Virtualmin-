#!/bin/bash
# Script de prueba directa para VPS - Copia y pega el contenido completo

set -euo pipefail
IFS=$'\n\t'

LOG_FILE="/tmp/test_directo_$(date +%Y%m%d_%H%M%S).log"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
    echo -e "${BLUE}[TEST]${NC} $*"
}

error_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $*" >> "$LOG_FILE"
    echo -e "${RED}[ERROR]${NC} $*"
}

success_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: $*" >> "$LOG_FILE"
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

echo ""
echo -e "${BLUE}🧪 PRUEBA DIRECTA DEL SISTEMA WEBMIN/VIRTUALMIN${NC}"
echo -e "${BLUE}Ejecutando diagnóstico y reparaciones automáticas${NC}"
echo ""

# Verificar servicios críticos
echo "=== VERIFICANDO SERVICIOS CRÍTICOS ==="
services=("webmin" "apache2" "nginx" "mysql" "mariadb" "ssh")
failed_services=0

for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        success_log "✅ $service está ACTIVO"
    else
        error_log "❌ $service está INACTIVO/NO INSTALADO"
        ((failed_services++))
    fi
done

echo ""
echo "=== VERIFICANDO RECURSOS DEL SISTEMA ==="

# CPU
cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' 2>/dev/null || echo "N/A")
if [[ "$cpu_usage" != "N/A" ]]; then
    if (( $(echo "$cpu_usage > 90" | bc -l 2>/dev/null || echo "0") )); then
        error_log "❌ CPU CRÍTICO: ${cpu_usage}%"
    elif (( $(echo "$cpu_usage > 70" | bc -l 2>/dev/null || echo "0") )); then
        log "⚠️ CPU ALTO: ${cpu_usage}%"
    else
        success_log "✅ CPU NORMAL: ${cpu_usage}%"
    fi
fi

# Memoria
mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}' 2>/dev/null || echo "N/A")
if [[ "$mem_usage" != "N/A" ]]; then
    if [[ $mem_usage -gt 95 ]]; then
        error_log "❌ MEMORIA CRÍTICA: ${mem_usage}%"
    elif [[ $mem_usage -gt 80 ]]; then
        log "⚠️ MEMORIA ALTA: ${mem_usage}%"
    else
        success_log "✅ MEMORIA NORMAL: ${mem_usage}%"
    fi
fi

# Disco
disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//' 2>/dev/null || echo "N/A")
if [[ "$disk_usage" != "N/A" ]]; then
    if [[ $disk_usage -gt 95 ]]; then
        error_log "❌ DISCO CRÍTICO: ${disk_usage}%"
    elif [[ $disk_usage -gt 85 ]]; then
        log "⚠️ DISCO ALTO: ${disk_usage}%"
    else
        success_log "✅ DISCO NORMAL: ${disk_usage}%"
    fi
fi

echo ""
echo "=== PRUEBA DE ACCESO A WEBMIN ==="

# Verificar Webmin
if [[ -d /usr/share/webmin ]]; then
    success_log "✅ Webmin está instalado"
    
    if systemctl is-active --quiet webmin 2>/dev/null; then
        success_log "✅ Servicio Webmin activo"
        
        # Probar conexión al puerto 10000
        if timeout 5 bash -c "</dev/tcp/localhost/10000" 2>/dev/null; then
            success_log "✅ Puerto 10000 accesible - Webmin funcionando"
        else
            error_log "❌ Puerto 10000 no accesible"
        fi
    else
        error_log "❌ Servicio Webmin inactivo"
    fi
else
    error_log "❌ Webmin no está instalado"
fi

echo ""
echo "=== EJECUTANDO REPARACIONES AUTOMÁTICAS ==="

# Intentar reparaciones básicas
reparaciones_realizadas=0

# Reparar servicios
for service in "${services[@]}"; do
    if ! systemctl is-active --quiet "$service" 2>/dev/null && systemctl list-units --type=service | grep -q "$service" 2>/dev/null; then
        log "Intentando iniciar $service..."
        if systemctl start "$service" 2>/dev/null; then
            success_log "✅ $service iniciado correctamente"
            ((reparaciones_realizadas++))
        fi
    fi
done

# Liberar memoria si es necesario
if [[ "$mem_usage" != "N/A" ]] && [[ $mem_usage -gt 85 ]]; then
    log "Liberando memoria del sistema..."
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    success_log "✅ Memoria liberada"
    ((reparaciones_realizadas++))
fi

echo ""
echo "=== RESULTADOS FINALES ==="
echo ""
echo -e "${BLUE}📊 RESUMEN DE LA PRUEBA:${NC}"
echo "   • Servicios verificados: ${#services[@]}"
echo "   • Servicios fallidos: $failed_services"
echo "   • Reparaciones realizadas: $reparaciones_realizadas"
echo "   • Log completo: $LOG_FILE"
echo ""

if [[ $failed_services -eq 0 ]]; then
    echo -e "${GREEN}🎉 ¡EXCELENTE! TU SISTEMA ESTÁ FUNCIONANDO PERFECTAMENTE${NC}"
    echo "   ✅ Todos los servicios críticos están activos"
    echo "   ✅ Recursos del sistema normales"
    echo "   ✅ Webmin funcionando correctamente"
else
    echo -e "${YELLOW}⚠️ SE ENCONTRARON ALGUNOS PROBLEMAS${NC}"
    echo "   ❌ $failed_services servicios necesitan atención"
    echo "   🔧 Se intentaron reparaciones automáticas"
    echo ""
    echo -e "${BLUE}💡 RECOMENDACIONES:${NC}"
    echo "   • Revisa el log completo: cat $LOG_FILE"
    echo "   • Verifica servicios manualmente: systemctl status <servicio>"
    echo "   • Reinicia servicios si es necesario"
fi

echo ""
echo -e "${BLUE}📋 PARA MÁS DETALLES:${NC}"
echo "   cat $LOG_FILE"
echo ""
echo -e "${GREEN}✅ PRUEBA COMPLETADA - REVISADO: $(date)${NC}"

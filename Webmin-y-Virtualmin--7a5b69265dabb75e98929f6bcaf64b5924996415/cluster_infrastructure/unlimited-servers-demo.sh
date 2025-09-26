#!/bin/bash
# Demo script para SERVIDORES ILIMITADOS
# Muestra las capacidades de escalado automático

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${PURPLE}============================================================================${NC}"
echo -e "${CYAN}🚀 DEMO: SERVIDORES ILIMITADOS EN ACCIÓN${NC}"
echo -e "${PURPLE}============================================================================${NC}"
echo

# Función para simular escalado
simulate_scaling() {
    local current_servers=$1
    local target_servers=$2
    local scaling_type=$3

    echo -e "${BLUE}📊 ESCALADO ${scaling_type^^}:${NC}"
    echo -e "${YELLOW}   Servidores actuales: ${current_servers}${NC}"
    echo -e "${YELLOW}   Servidores objetivo: ${target_servers}${NC}"
    echo

    # Simular proceso de escalado
    for ((i=current_servers; i<=target_servers; i++)); do
        echo -e "${GREEN}   ✅ Aprovisionando servidor ${i}...${NC}"
        sleep 0.1

        # Simular verificación de salud
        if (( RANDOM % 100 < 95 )); then
            echo -e "${CYAN}      ✓ Servidor ${i} saludable${NC}"
        else
            echo -e "${RED}      ✗ Servidor ${i} falló - reprovisionando...${NC}"
            ((i--))
        fi
    done

    echo -e "${GREEN}   🎉 Escalado completado: ${target_servers} servidores activos${NC}"
    echo
}

# Función para mostrar métricas
show_metrics() {
    echo -e "${BLUE}📈 MÉTRICAS DE RENDIMIENTO:${NC}"
    echo -e "${CYAN}   CPU Usage:${NC} $(shuf -i 10-85 -n 1)%"
    echo -e "${CYAN}   Memory Usage:${NC} $(shuf -i 20-90 -n 1)%"
    echo -e "${CYAN}   Network I/O:${NC} $(shuf -i 100-2000 -n 1) MB/s"
    echo -e "${CYAN}   Active Connections:${NC} $(shuf -i 1000-50000 -n 1)"
    echo -e "${CYAN}   Response Time:${NC} $(shuf -i 10-200 -n 1)ms"
    echo
}

# Función para simular failover
simulate_failover() {
    local failed_server=$1
    local backup_server=$2

    echo -e "${RED}🚨 FAILOVER DETECTADO:${NC}"
    echo -e "${YELLOW}   Servidor ${failed_server} no responde${NC}"
    echo -e "${CYAN}   Activando servidor backup ${backup_server}...${NC}"
    sleep 1
    echo -e "${GREEN}   ✅ Failover completado - Tráfico redirigido${NC}"
    echo
}

# Demo principal
main() {
    echo -e "${GREEN}🧠 SISTEMA DE ESCALADO INTELIGENTE ACTIVADO${NC}"
    echo -e "${BLUE}🔍 INVENTARIO DINÁMICO: Detectando servidores...${NC}"
    echo

    # Fase 1: Escalado inicial
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}FASE 1: ESCALADO INICIAL${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    simulate_scaling 0 10 "inicial"

    # Mostrar métricas iniciales
    show_metrics

    # Fase 2: Escalado por carga
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}FASE 2: ESCALADO POR CARGA (CPU > 80%)${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    simulate_scaling 10 25 "predictivo"

    # Simular failover
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}FASE 3: FAILOVER AUTOMÁTICO${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    simulate_failover 15 26
    simulate_scaling 25 26 "failover"

    # Fase 3: Escalado masivo
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}FASE 4: ESCALADO MASIVO (DEMANDA PICO)${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    simulate_scaling 26 100 "masivo"

    # Fase 4: Optimización
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}FASE 5: OPTIMIZACIÓN INTELIGENTE${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🧠 IA analizando patrones de carga...${NC}"
    sleep 2
    echo -e "${GREEN}   📊 Patrón identificado: Carga cíclica${NC}"
    echo -e "${GREEN}   💰 Optimización: Reduciendo 20 servidores inactivos${NC}"
    simulate_scaling 100 80 "optimización"

    # Estado final
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🎉 DEMO COMPLETADA - SERVIDORES ILIMITADOS FUNCIONANDO${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${CYAN}📊 ESTADO FINAL:${NC}"
    echo -e "${GREEN}   ✅ 80 servidores activos${NC}"
    echo -e "${GREEN}   ✅ Balanceo de carga optimizado${NC}"
    echo -e "${GREEN}   ✅ Failover automático configurado${NC}"
    echo -e "${GREEN}   ✅ Monitoreo inteligente activo${NC}"
    echo -e "${GREEN}   ✅ Backup distribuido funcionando${NC}"
    echo
    echo -e "${BLUE}🔄 EL SISTEMA CONTINÚA MONITOREANDO Y ESCALANDO AUTOMÁTICAMENTE${NC}"
    echo -e "${YELLOW}💡 El clúster puede crecer hasta ∞ servidores según la demanda${NC}"
    echo
    echo -e "${PURPLE}============================================================================${NC}"
    echo -e "${CYAN}🎯 SERVIDORES ILIMITADOS: ESCALABILIDAD SIN LÍMITES${NC}"
    echo -e "${PURPLE}============================================================================${NC}"
}

# Ejecutar demo
main "$@"
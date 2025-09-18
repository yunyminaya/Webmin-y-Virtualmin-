#!/bin/bash

# ============================================================================
# 📊 DASHBOARD DE ESTADO DEL SISTEMA DE AUTO-REPARACIÓN AUTÓNOMA
# ============================================================================
# Muestra el estado en tiempo real del sistema autónomo
# Reportes, estadísticas y control del sistema
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTONOMOUS_SCRIPT="$SCRIPT_DIR/autonomous_repair.sh"
STATUS_FILE="$SCRIPT_DIR/auto_repair_status.json"
LOG_FILE="$SCRIPT_DIR/auto_repair_daemon.log"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función para mostrar estado del sistema
show_system_status() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║               📊 DASHBOARD DEL SISTEMA AUTÓNOMO                   ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Estado del servicio
    echo -e "${BLUE}🔧 ESTADO DEL SERVICIO:${NC}"
    if systemctl is-active --quiet auto-repair 2>/dev/null; then
        echo -e "${GREEN}   ✅ Servicio activo y funcionando${NC}"
    else
        echo -e "${RED}   ❌ Servicio inactivo${NC}"
    fi
    echo ""

    # Información del sistema
    if [[ -f "$STATUS_FILE" ]]; then
        echo -e "${BLUE}📈 ÚLTIMA ACTUALIZACIÓN:${NC}"
        local timestamp
        timestamp=$(grep -o '"timestamp":"[^"]*"' "$STATUS_FILE" | cut -d'"' -f4 2>/dev/null || echo "N/A")
        echo "   📅 $timestamp"
        echo ""

        echo -e "${BLUE}🎯 ESTADÍSTICAS DE REPARACIÓN:${NC}"
        local issues_found repairs_attempted repairs_successful
        issues_found=$(grep -o '"issues_found":[0-9]*' "$STATUS_FILE" | cut -d':' -f2 2>/dev/null || echo "0")
        repairs_attempted=$(grep -o '"repairs_attempted":[0-9]*' "$STATUS_FILE" | cut -d':' -f2 2>/dev/null || echo "0")
        repairs_successful=$(grep -o '"repairs_successful":[0-9]*' "$STATUS_FILE" | cut -d':' -f2 2>/dev/null || echo "0")

        echo "   🔍 Problemas encontrados: $issues_found"
        echo "   🔧 Reparaciones intentadas: $repairs_attempted"
        echo "   ✅ Reparaciones exitosas: $repairs_successful"
        echo ""

        echo -e "${BLUE}💻 RECURSOS DEL SISTEMA:${NC}"
        local mem_usage cpu_usage disk_usage
        mem_usage=$(grep -o '"memory_usage":[0-9]*' "$STATUS_FILE" | cut -d':' -f2 2>/dev/null || echo "N/A")
        cpu_usage=$(grep -o '"cpu_usage":[0-9]*' "$STATUS_FILE" | cut -d':' -f2 2>/dev/null || echo "N/A")
        disk_usage=$(grep -o '"disk_usage":[0-9]*' "$STATUS_FILE" | cut -d':' -f2 2>/dev/null || echo "N/A")

        if [[ $mem_usage -gt 80 ]]; then
            echo -e "   🧠 Memoria: ${RED}$mem_usage%${NC} (ALTO)"
        else
            echo -e "   🧠 Memoria: ${GREEN}$mem_usage%${NC}"
        fi

        if [[ $cpu_usage -gt 90 ]]; then
            echo -e "   ⚡ CPU: ${RED}$cpu_usage%${NC} (CRÍTICO)"
        elif [[ $cpu_usage -gt 70 ]]; then
            echo -e "   ⚡ CPU: ${YELLOW}$cpu_usage%${NC} (ALTO)"
        else
            echo -e "   ⚡ CPU: ${GREEN}$cpu_usage%${NC}"
        fi

        if [[ $disk_usage -gt 85 ]]; then
            echo -e "   💾 Disco: ${RED}$disk_usage%${NC} (CRÍTICO)"
        elif [[ $disk_usage -gt 70 ]]; then
            echo -e "   💾 Disco: ${YELLOW}$disk_usage%${NC} (ALTO)"
        else
            echo -e "   💾 Disco: ${GREEN}$disk_usage%${NC}"
        fi
    else
        echo -e "${YELLOW}   ⚠️ No hay información de estado disponible${NC}"
        echo "      El sistema aún no ha completado su primer ciclo de monitoreo"
    fi
    echo ""
}

# Función para mostrar logs recientes
show_recent_logs() {
    echo -e "${BLUE}📝 LOGS RECIENTES:${NC}"
    echo "═══════════════════════════════════════════════════════════════"

    if [[ -f "$LOG_FILE" ]]; then
        tail -15 "$LOG_FILE" | while read -r line; do
            if echo "$line" | grep -q "SUCCESS"; then
                echo -e "${GREEN}$line${NC}"
            elif echo "$line" | grep -q "ERROR\|CRITICAL"; then
                echo -e "${RED}$line${NC}"
            elif echo "$line" | grep -q "WARNING"; then
                echo -e "${YELLOW}$line${NC}"
            else
                echo "$line"
            fi
        done
    else
        echo -e "${YELLOW}   No hay logs disponibles aún${NC}"
    fi
    echo ""
}

# Función para mostrar servicios monitoreados
show_monitored_services() {
    echo -e "${BLUE}🔍 SERVICIOS MONITOREADOS:${NC}"
    echo "═══════════════════════════════════════════════════════════════"

    local services=("webmin" "apache2" "nginx" "mysql" "mariadb" "postfix" "dovecot" "ssh" "ufw" "fail2ban")

    for service in "${services[@]}"; do
        printf "   %-15s " "$service:"
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo -e "${GREEN}✅ ACTIVO${NC}"
        else
            echo -e "${RED}❌ INACTIVO${NC}"
        fi
    done
    echo ""
}

# Función para mostrar acciones disponibles
show_available_actions() {
    echo -e "${BLUE}🎮 ACCIONES DISPONIBLES:${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo "   1. 🔄 Reiniciar servicio autónomo"
    echo "   2. 📊 Generar reporte inmediato"
    echo "   3. 🔧 Ejecutar reparación manual"
    echo "   4. 📧 Probar envío de email"
    echo "   5. 🛑 Detener sistema autónomo"
    echo "   6. ▶️  Iniciar sistema autónomo"
    echo "   7. 📋 Ver configuración actual"
    echo "   8. 🔄 Recargar configuración"
    echo "   9. 📈 Ver estadísticas detalladas"
    echo "   0. 🚪 Salir del dashboard"
    echo ""
}

# Función para ejecutar acciones
execute_action() {
    local action="$1"

    case "$action" in
        1)
            echo -e "${BLUE}🔄 Reiniciando servicio autónomo...${NC}"
            systemctl restart auto-repair
            sleep 2
            if systemctl is-active --quiet auto-repair; then
                echo -e "${GREEN}✅ Servicio reiniciado correctamente${NC}"
            else
                echo -e "${RED}❌ Error al reiniciar servicio${NC}"
            fi
            ;;
        2)
            echo -e "${BLUE}📊 Generando reporte...${NC}"
            "$AUTONOMOUS_SCRIPT" report
            echo -e "${GREEN}✅ Reporte generado${NC}"
            ;;
        3)
            echo -e "${BLUE}🔧 Ejecutando reparación manual...${NC}"
            "$AUTONOMOUS_SCRIPT" monitor
            echo -e "${GREEN}✅ Reparación completada${NC}"
            ;;
        4)
            echo -e "${BLUE}📧 Probando envío de email...${NC}"
            echo "Prueba de email del sistema autónomo" | mail -s "Prueba Auto-Repair" root@localhost 2>/dev/null && \
                echo -e "${GREEN}✅ Email enviado correctamente${NC}" || \
                echo -e "${RED}❌ Error al enviar email${NC}"
            ;;
        5)
            echo -e "${YELLOW}🛑 Deteniendo sistema autónomo...${NC}"
            systemctl stop auto-repair
            systemctl disable auto-repair
            echo -e "${GREEN}✅ Sistema detenido${NC}"
            ;;
        6)
            echo -e "${BLUE}▶️ Iniciando sistema autónomo...${NC}"
            systemctl enable auto-repair
            systemctl start auto-repair
            sleep 2
            if systemctl is-active --quiet auto-repair; then
                echo -e "${GREEN}✅ Sistema iniciado correctamente${NC}"
            else
                echo -e "${RED}❌ Error al iniciar sistema${NC}"
            fi
            ;;
        7)
            echo -e "${BLUE}📋 Configuración actual:${NC}"
            if [[ -f "$SCRIPT_DIR/autonomous_config.sh" ]]; then
                echo "═══════════════════════════════════════════════════════════════"
                cat "$SCRIPT_DIR/autonomous_config.sh"
            else
                echo -e "${RED}❌ Archivo de configuración no encontrado${NC}"
            fi
            ;;
        8)
            echo -e "${BLUE}🔄 Recargando configuración...${NC}"
            systemctl daemon-reload
            echo -e "${GREEN}✅ Configuración recargada${NC}"
            ;;
        9)
            echo -e "${BLUE}📈 Estadísticas detalladas:${NC}"
            echo "═══════════════════════════════════════════════════════════════"
            if [[ -f "$STATUS_FILE" ]]; then
                cat "$STATUS_FILE" | python3 -m json.tool 2>/dev/null || cat "$STATUS_FILE"
            else
                echo -e "${YELLOW}No hay estadísticas disponibles${NC}"
            fi
            ;;
        0)
            echo -e "${GREEN}👋 ¡Hasta luego! El sistema continúa funcionando automáticamente.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Opción no válida${NC}"
            ;;
    esac

    echo ""
    read -p "Presiona Enter para continuar..."
}

# Función principal del dashboard
main_dashboard() {
    while true; do
        clear
        show_system_status
        show_monitored_services
        show_recent_logs
        show_available_actions

        read -p "Selecciona una acción (0-9): " choice
        echo ""

        if [[ "$choice" =~ ^[0-9]$ ]]; then
            execute_action "$choice"
        else
            echo -e "${RED}❌ Por favor ingresa un número válido (0-9)${NC}"
            sleep 2
        fi
    done
}

# Función para mostrar ayuda
show_help() {
    echo "Dashboard del Sistema de Auto-Reparación Autónoma"
    echo ""
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  --dashboard, -d    Mostrar dashboard interactivo (por defecto)"
    echo "  --status, -s       Mostrar estado del sistema"
    echo "  --logs, -l         Mostrar logs recientes"
    echo "  --services, -v     Mostrar estado de servicios"
    echo "  --help, -h         Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 --dashboard     # Dashboard interactivo completo"
    echo "  $0 --status        # Solo estado del sistema"
    echo "  $0 --logs          # Solo logs recientes"
}

# Procesar argumentos
case "${1:-}" in
    "--dashboard"|"-d"|"")
        main_dashboard
        ;;
    "--status"|"-s")
        show_system_status
        ;;
    "--logs"|"-l")
        show_recent_logs
        ;;
    "--services"|"-v")
        show_monitored_services
        ;;
    "--help"|"-h")
        show_help
        ;;
    *)
        echo -e "${RED}Opción no válida: $1${NC}"
        show_help
        exit 1
        ;;
esac

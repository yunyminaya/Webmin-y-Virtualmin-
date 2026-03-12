#!/bin/bash

# ============================================================================
# 🎮 DASHBOARD DE CONTROL DEL SISTEMA INTELIGENTE COMPLETO
# ============================================================================
# Control total del sistema de auto-reparación y auto-actualización
# Interfaz interactiva para monitoreo y control en tiempo real
# ============================================================================

# Configuración
INTELLIGENT_SCRIPT="/opt/auto_repair_system/intelligent_auto_update.sh"
STATUS_FILE="/opt/auto_repair_system/update_status.json"
LOG_FILE="/var/log/auto_update_system.log"
REPAIR_LOG="/root/auto_repair.log"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Función para mostrar header
show_header() {
    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        🎮 DASHBOARD DEL SISTEMA INTELIGENTE COMPLETO          ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}🤖 Sistema de Auto-Reparación + Auto-Actualización Inteligente${NC}"
    echo -e "${WHITE}📡 Comunicación automática con GitHub${NC}"
    echo -e "${WHITE}🛡️ Servidores funcionando 24/7 sin intervención humana${NC}"
    echo ""
}

# Función para mostrar estado general
show_system_status() {
    echo -e "${BLUE}🔧 ESTADO GENERAL DEL SISTEMA:${NC}"
    echo "═══════════════════════════════════════════════════════════════"

    # Estado de servicios
    local auto_repair_status auto_update_status
    auto_repair_status=$(systemctl is-active auto-repair 2>/dev/null && echo "✅ ACTIVO" || echo "❌ INACTIVO")
    auto_update_status=$(systemctl is-active auto-update 2>/dev/null && echo "✅ ACTIVO" || echo "❌ INACTIVO")

    echo -e "   🔄 Auto-Reparación:     ${GREEN}$auto_repair_status${NC}"
    echo -e "   📡 Auto-Actualización:  ${GREEN}$auto_update_status${NC}"

    # Estado de servicios críticos
    echo ""
    echo -e "${BLUE}🔍 SERVICIOS CRÍTICOS:${NC}"
    local services=("apache2" "mysql" "mariadb" "webmin" "ssh")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            printf "   %-10s ${GREEN}✅ ACTIVO${NC}\n" "$service:"
        elif systemctl list-units | grep -q "$service" 2>/dev/null; then
            printf "   %-10s ${RED}❌ INACTIVO${NC}\n" "$service:"
        else
            printf "   %-10s ${YELLOW}⚠️ NO INSTALADO${NC}\n" "$service:"
        fi
    done

    # Recursos del sistema
    echo ""
    echo -e "${BLUE}💻 RECURSOS DEL SISTEMA:${NC}"
    local mem_usage cpu_usage disk_usage
    mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}' 2>/dev/null || echo "N/A")
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' 2>/dev/null || echo "N/A")
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//' 2>/dev/null || echo "N/A")

    if [[ "$mem_usage" != "N/A" ]]; then
        if [[ $mem_usage -gt 80 ]]; then
            echo -e "   🧠 Memoria:  ${RED}$mem_usage%${NC} (ALTA)"
        else
            echo -e "   🧠 Memoria:  ${GREEN}$mem_usage%${NC}"
        fi
    fi

    if [[ "$cpu_usage" != "N/A" ]]; then
        if [[ $cpu_usage -gt 90 ]]; then
            echo -e "   ⚡ CPU:      ${RED}$cpu_usage%${NC} (CRÍTICO)"
        elif [[ $cpu_usage -gt 70 ]]; then
            echo -e "   ⚡ CPU:      ${YELLOW}$cpu_usage%${NC} (ALTO)"
        else
            echo -e "   ⚡ CPU:      ${GREEN}$cpu_usage%${NC}"
        fi
    fi

    if [[ "$disk_usage" != "N/A" ]]; then
        if [[ $disk_usage -gt 85 ]]; then
            echo -e "   💾 Disco:    ${RED}$disk_usage%${NC} (CRÍTICO)"
        elif [[ $disk_usage -gt 70 ]]; then
            echo -e "   💾 Disco:    ${YELLOW}$disk_usage%${NC} (ALTO)"
        else
            echo -e "   💾 Disco:    ${GREEN}$disk_usage%${NC}"
        fi
    fi
}

# Función para mostrar estado de GitHub y actualizaciones
show_github_status() {
    echo ""
    echo -e "${BLUE}🌐 ESTADO DE GITHUB Y ACTUALIZACIONES:${NC}"
    echo "═══════════════════════════════════════════════════════════════"

    # Conectividad con GitHub
    if curl -s --connect-timeout 5 "https://api.github.com" >/dev/null; then
        echo -e "   🌐 Conectividad GitHub: ${GREEN}✅ CONECTADO${NC}"
    else
        echo -e "   🌐 Conectividad GitHub: ${RED}❌ SIN CONEXIÓN${NC}"
    fi

    # Versión actual
    if [[ -f "/opt/auto_repair_system/version.txt" ]]; then
        local current_version
        current_version=$(cat "/opt/auto_repair_system/version.txt")
        echo -e "   📦 Versión actual: ${CYAN}$current_version${NC}"
    else
        echo -e "   📦 Versión actual: ${YELLOW}DESCONOCIDA${NC}"
    fi

    # Última verificación
    if [[ -f "$STATUS_FILE" ]]; then
        local last_check
        last_check=$(grep -o '"last_update_check":"[^"]*"' "$STATUS_FILE" 2>/dev/null | cut -d'"' -f4 || echo "Nunca")
        echo -e "   📅 Última verificación: ${WHITE}$last_check${NC}"
    fi
}

# Función para mostrar logs recientes
show_recent_logs() {
    echo ""
    echo -e "${BLUE}📝 LOGS RECIENTES DEL SISTEMA:${NC}"
    echo "═══════════════════════════════════════════════════════════════"

    # Logs de auto-reparación
    echo -e "${YELLOW}🔧 LOGS DE AUTO-REPARACIÓN:${NC}"
    if [[ -f "$REPAIR_LOG" ]]; then
        tail -3 "$REPAIR_LOG" 2>/dev/null | while read -r line; do
            if echo "$line" | grep -q "✅"; then
                echo -e "   ${GREEN}$line${NC}"
            elif echo "$line" | grep -q "❌"; then
                echo -e "   ${RED}$line${NC}"
            elif echo "$line" | grep -q "⚠️"; then
                echo -e "   ${YELLOW}$line${NC}"
            else
                echo -e "   ${WHITE}$line${NC}"
            fi
        done
    else
        echo -e "   ${YELLOW}No hay logs de auto-reparación${NC}"
    fi

    # Logs de auto-actualización
    echo ""
    echo -e "${YELLOW}📡 LOGS DE AUTO-ACTUALIZACIÓN:${NC}"
    if [[ -f "$LOG_FILE" ]]; then
        tail -3 "$LOG_FILE" 2>/dev/null | while read -r line; do
            if echo "$line" | grep -q "SUCCESS"; then
                echo -e "   ${GREEN}$line${NC}"
            elif echo "$line" | grep -q "CRITICAL\|ERROR"; then
                echo -e "   ${RED}$line${NC}"
            elif echo "$line" | grep -q "WARNING"; then
                echo -e "   ${YELLOW}$line${NC}"
            else
                echo -e "   ${WHITE}$line${NC}"
            fi
        done
    else
        echo -e "   ${YELLOW}No hay logs de auto-actualización${NC}"
    fi
}

# Función para mostrar menú de acciones
show_menu() {
    echo ""
    echo -e "${BLUE}🎮 ACCIONES DISPONIBLES:${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "   ${CYAN}1.${NC} 🔄 Verificar actualizaciones desde GitHub"
    echo -e "   ${CYAN}2.${NC} 📊 Generar reporte completo del sistema"
    echo -e "   ${CYAN}3.${NC} 🔧 Ejecutar reparación manual de servicios"
    echo -e "   ${CYAN}4.${NC} 📧 Probar envío de alertas por email"
    echo -e "   ${CYAN}5.${NC} 💾 Crear backup manual del sistema"
    echo -e "   ${CYAN}6.${NC} 🔄 Reiniciar servicios inteligentes"
    echo -e "   ${CYAN}7.${NC} 📋 Ver configuración actual"
    echo -e "   ${CYAN}8.${NC} 🚨 Ejecutar recuperación de emergencia"
    echo -e "   ${CYAN}9.${NC} 📁 Ver backups disponibles"
    echo -e "   ${CYAN}10.${NC} 📈 Ver estadísticas detalladas"
    echo -e "   ${CYAN}11.${NC} 🛑 Detener sistema inteligente"
    echo -e "   ${CYAN}12.${NC} ▶️ Iniciar sistema inteligente"
    echo -e "   ${CYAN}0.${NC} 🚪 Salir del dashboard"
    echo ""
}

# Función para ejecutar acciones
execute_action() {
    local action="$1"
    echo ""

    case "$action" in
        1)
            echo -e "${BLUE}🔄 Verificando actualizaciones desde GitHub...${NC}"
            if [[ -f "$INTELLIGENT_SCRIPT" ]]; then
                "$INTELLIGENT_SCRIPT" update
                echo -e "${GREEN}✅ Verificación completada${NC}"
            else
                echo -e "${RED}❌ Sistema inteligente no encontrado${NC}"
            fi
            ;;
        2)
            echo -e "${BLUE}📊 Generando reporte completo...${NC}"
            {
                echo "=== REPORTE COMPLETO DEL SISTEMA INTELIGENTE ==="
                echo "Fecha: $(date)"
                echo "Servidor: $(hostname)"
                echo ""
                echo "=== ESTADO DE SERVICIOS ==="
                systemctl status auto-repair --no-pager -l 2>/dev/null || echo "Auto-repair no disponible"
                echo ""
                systemctl status auto-update --no-pager -l 2>/dev/null || echo "Auto-update no disponible"
                echo ""
                echo "=== RECURSOS DEL SISTEMA ==="
                free -h
                echo ""
                df -h
                echo ""
                echo "=== ÚLTIMOS LOGS ==="
                echo "Auto-Reparación:"
                tail -10 "$REPAIR_LOG" 2>/dev/null || echo "No disponible"
                echo ""
                echo "Auto-Actualización:"
                tail -10 "$LOG_FILE" 2>/dev/null || echo "No disponible"
            } > "/tmp/system_report_$(date +%Y%m%d_%H%M%S).txt"
            echo -e "${GREEN}✅ Reporte generado en /tmp/system_report_*.txt${NC}"
            ;;
        3)
            echo -e "${BLUE}🔧 Ejecutando reparación manual de servicios...${NC}"
            if [[ -f "$INTELLIGENT_SCRIPT" ]]; then
                "$INTELLIGENT_SCRIPT" monitor
                echo -e "${GREEN}✅ Reparación completada${NC}"
            else
                echo -e "${RED}❌ Sistema inteligente no encontrado${NC}"
            fi
            ;;
        4)
            echo -e "${BLUE}📧 Probando envío de alertas por email...${NC}"
            local test_message
            test_message="Prueba del sistema inteligente - $(date)"
            echo "$test_message" | mail -s "Sistema Inteligente - Prueba" root@localhost 2>/dev/null && \
                echo -e "${GREEN}✅ Email enviado correctamente${NC}" || \
                echo -e "${RED}❌ Error enviando email${NC}"
            ;;
        5)
            echo -e "${BLUE}💾 Creando backup manual...${NC}"
            if [[ -f "$INTELLIGENT_SCRIPT" ]]; then
                "$INTELLIGENT_SCRIPT" monitor
                echo -e "${GREEN}✅ Backup creado${NC}"
            else
                echo -e "${RED}❌ Sistema inteligente no encontrado${NC}"
            fi
            ;;
        6)
            echo -e "${BLUE}🔄 Reiniciando servicios inteligentes...${NC}"
            systemctl restart auto-repair 2>/dev/null && echo -e "${GREEN}✅ Auto-repair reiniciado${NC}" || echo -e "${RED}❌ Error en auto-repair${NC}"
            systemctl restart auto-update 2>/dev/null && echo -e "${GREEN}✅ Auto-update reiniciado${NC}" || echo -e "${RED}❌ Error en auto-update${NC}"
            ;;
        7)
            echo -e "${BLUE}📋 Configuración actual:${NC}"
            echo "═══════════════════════════════════════════════════════════════"
            if [[ -f "/opt/auto_repair_system/config.sh" ]]; then
                cat "/opt/auto_repair_system/config.sh"
            else
                echo -e "${RED}❌ Archivo de configuración no encontrado${NC}"
            fi
            ;;
        8)
            echo -e "${BLUE}🚨 Ejecutando recuperación de emergencia...${NC}"
            if [[ -x "/usr/local/bin/emergency-recovery" ]]; then
                /usr/local/bin/emergency-recovery
                echo -e "${GREEN}✅ Recuperación completada${NC}"
            else
                echo -e "${RED}❌ Script de recuperación no encontrado${NC}"
            fi
            ;;
        9)
            echo -e "${BLUE}📁 Backups disponibles:${NC}"
            echo "═══════════════════════════════════════════════════════════════"
            if [[ -d "/backups/auto_updates" ]]; then
                find "/backups/auto_updates" -name "backup_*" -type d | sort | while read -r backup; do
                    local backup_date
                    backup_date=$(basename "$backup" | sed 's/backup_//')
                    echo -e "   📦 ${WHITE}$backup_date${NC}"
                done
            else
                echo -e "${YELLOW}   No hay backups disponibles${NC}"
            fi
            ;;
        10)
            echo -e "${BLUE}📈 Estadísticas detalladas:${NC}"
            echo "═══════════════════════════════════════════════════════════════"
            if [[ -f "$STATUS_FILE" ]]; then
                cat "$STATUS_FILE" | python3 -m json.tool 2>/dev/null || cat "$STATUS_FILE"
            else
                echo -e "${YELLOW}No hay estadísticas disponibles${NC}"
            fi
            ;;
        11)
            echo -e "${YELLOW}🛑 Deteniendo sistema inteligente...${NC}"
            systemctl stop auto-repair 2>/dev/null || echo "Auto-repair ya detenido"
            systemctl stop auto-update 2>/dev/null || echo "Auto-update ya detenido"
            systemctl disable auto-repair 2>/dev/null || echo "Auto-repair ya deshabilitado"
            systemctl disable auto-update 2>/dev/null || echo "Auto-update ya deshabilitado"
            echo -e "${GREEN}✅ Sistema inteligente detenido${NC}"
            ;;
        12)
            echo -e "${BLUE}▶️ Iniciando sistema inteligente...${NC}"
            systemctl enable auto-repair 2>/dev/null && systemctl start auto-repair 2>/dev/null && echo -e "${GREEN}✅ Auto-repair iniciado${NC}" || echo -e "${RED}❌ Error en auto-repair${NC}"
            systemctl enable auto-update 2>/dev/null && systemctl start auto-update 2>/dev/null && echo -e "${GREEN}✅ Auto-update iniciado${NC}" || echo -e "${RED}❌ Error en auto-update${NC}"
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
        show_header
        show_system_status
        show_github_status
        show_recent_logs
        show_menu

        read -p "Selecciona una opción (0-12): " choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 0 ]] && [[ "$choice" -le 12 ]]; then
            execute_action "$choice"
        else
            echo -e "${RED}❌ Por favor ingresa un número válido (0-12)${NC}"
            sleep 2
        fi
    done
}

# Función para mostrar ayuda
show_help() {
    echo "Dashboard del Sistema Inteligente Completo"
    echo ""
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  --dashboard, -d    Mostrar dashboard interactivo (por defecto)"
    echo "  --status, -s       Mostrar estado del sistema"
    echo "  --update, -u       Verificar actualizaciones"
    echo "  --repair, -r       Ejecutar reparación manual"
    echo "  --logs, -l         Mostrar logs recientes"
    echo "  --help, -h         Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 --dashboard     # Dashboard interactivo completo"
    echo "  $0 --status        # Solo estado del sistema"
    echo "  $0 --update        # Verificar actualizaciones"
    echo ""
    echo "Comandos directos:"
    echo "  intelligent-control status    # Estado completo"
    echo "  intelligent-control update    # Forzar actualización"
    echo "  emergency-recovery           # Recuperación de emergencia"
}

# Procesar argumentos
case "${1:-}" in
    "--dashboard"|"-d"|"")
        main_dashboard
        ;;
    "--status"|"-s")
        show_header
        show_system_status
        show_github_status
        ;;
    "--update"|"-u")
        execute_action 1
        ;;
    "--repair"|"-r")
        execute_action 3
        ;;
    "--logs"|"-l")
        show_header
        show_recent_logs
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

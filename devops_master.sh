#!/bin/bash

# DevOps Master - Sistema Completo de Despliegue Automático para Webmin/Virtualmin
# Interfaz unificada para gestionar todo el flujo DevOps

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Directorio base
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Scripts del sistema
AGENT_SCRIPT="$BASE_DIR/agente_devops_webmin.sh"
CONFIG_SCRIPT="$BASE_DIR/configurar_agente_devops.sh"
WEBHOOK_SCRIPT="$BASE_DIR/github_webhook_integration.sh"
MONITOR_SCRIPT="$BASE_DIR/monitor_despliegues.sh"

# Archivos de configuración
MASTER_CONFIG="$BASE_DIR/devops_master_config.json"
STATUS_FILE="$BASE_DIR/devops_status.json"
MASTER_LOG="$BASE_DIR/devops_master.log"

# Variables globales
VERSION="1.0.0"
AUTHOR="DevOps Agent for Webmin/Virtualmin"

# Función para mostrar banner
show_banner() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${WHITE}                    🚀 DEVOPS MASTER WEBMIN/VIRTUALMIN 🚀                    ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${WHITE}                         Sistema de Despliegue Automático                     ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${WHITE}                                Version $VERSION                                ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Función para mostrar encabezados
show_header() {
    echo -e "\n${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}🔧 $1${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}\n"
}

# Función para mostrar información
show_info() {
    echo -e "${YELLOW}[INFO]${NC} ℹ️  $1"
}

# Función para mostrar éxito
show_success() {
    echo -e "${GREEN}[SUCCESS]${NC} ✅ $1"
}

# Función para mostrar errores
show_error() {
    echo -e "${RED}[ERROR]${NC} ❌ $1"
}

# Función para mostrar advertencias
show_warning() {
    echo -e "${YELLOW}[WARNING]${NC} ⚠️  $1"
}

# Función para logging
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [${level}] ${message}" >> "$MASTER_LOG"
}

# Función para verificar dependencias
check_dependencies() {
    local missing_deps=()
    local required_commands=("jq" "curl" "ssh" "git")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ "${#missing_deps[@]}" -gt 0 ]; then
        show_error "Dependencias faltantes: ${missing_deps[*]}"
        show_info "Para instalar en macOS: brew install ${missing_deps[*]}"
        show_info "Para instalar en Ubuntu: apt-get install ${missing_deps[*]}"
        return 1
    fi
    
    return 0
}

# Función para verificar scripts del sistema
check_system_scripts() {
    local missing_scripts=()
    local scripts=(
        "$AGENT_SCRIPT:Agente DevOps"
        "$CONFIG_SCRIPT:Configurador"
        "$WEBHOOK_SCRIPT:Integración GitHub"
        "$MONITOR_SCRIPT:Monitor de Despliegues"
    )
    
    for script_info in "${scripts[@]}"; do
        local script_path=$(echo "$script_info" | cut -d':' -f1)
        local script_name=$(echo "$script_info" | cut -d':' -f2)
        
        if [ ! -f "$script_path" ]; then
            missing_scripts+=("$script_name")
        else
            chmod +x "$script_path"
        fi
    done
    
    if [ "${#missing_scripts[@]}" -gt 0 ]; then
        show_error "Scripts faltantes: ${missing_scripts[*]}"
        return 1
    fi
    
    return 0
}

# Función para obtener estado del sistema
get_system_status() {
    local agent_config="$BASE_DIR/agente_devops_config.json"
    local webhook_config="$BASE_DIR/webhook_config.json"
    local monitor_config="$BASE_DIR/monitor_config.json"
    local deployment_status="$BASE_DIR/deployment_status.json"
    
    local status="{"
    status="$status\"timestamp\":\"$(date -Iseconds)\","
    status="$status\"version\":\"$VERSION\","
    
    # Estado de configuraciones
    if [ -f "$agent_config" ]; then
        status="$status\"agent_configured\":true,"
        local servers_count=$(jq '.servers | length' "$agent_config" 2>/dev/null || echo "0")
        status="$status\"servers_configured\":$servers_count,"
    else
        status="$status\"agent_configured\":false,"
        status="$status\"servers_configured\":0,"
    fi
    
    if [ -f "$webhook_config" ]; then
        status="$status\"webhook_configured\":true,"
        local webhook_port=$(jq -r '.webhook_port // "0"' "$webhook_config" 2>/dev/null)
        status="$status\"webhook_port\":$webhook_port,"
    else
        status="$status\"webhook_configured\":false,"
        status="$status\"webhook_port\":0,"
    fi
    
    if [ -f "$monitor_config" ]; then
        status="$status\"monitoring_configured\":true,"
    else
        status="$status\"monitoring_configured\":false,"
    fi
    
    # Estado de servicios
    local webhook_running=false
    if [ -f "$webhook_config" ]; then
        local port=$(jq -r '.webhook_port // 9000' "$webhook_config" 2>/dev/null)
        if netstat -an 2>/dev/null | grep -q ":$port.*LISTEN" || lsof -i ":$port" >/dev/null 2>&1; then
            webhook_running=true
        fi
    fi
    status="$status\"webhook_running\":$webhook_running,"
    
    # Estado de salud del último monitoreo
    if [ -f "$deployment_status" ]; then
        local health_status=$(jq -r '.global_status // "UNKNOWN"' "$deployment_status" 2>/dev/null)
        local last_check=$(jq -r '.timestamp // ""' "$deployment_status" 2>/dev/null)
        status="$status\"health_status\":\"$health_status\","
        status="$status\"last_health_check\":\"$last_check\","
    else
        status="$status\"health_status\":\"UNKNOWN\","
        status="$status\"last_health_check\":\"\","
    fi
    
    status="$status\"system_ready\":$([ -f "$agent_config" ] && echo true || echo false)"
    status="$status}"
    
    echo "$status"
}

# Función para mostrar dashboard
show_dashboard() {
    show_banner
    
    local status=$(get_system_status)
    
    echo -e "${CYAN}📊 DASHBOARD DEL SISTEMA${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    
    # Estado general
    local system_ready=$(echo "$status" | jq -r '.system_ready')
    if [ "$system_ready" = "true" ]; then
        echo -e "${GREEN}🟢 Sistema:${NC} Configurado y listo"
    else
        echo -e "${RED}🔴 Sistema:${NC} Requiere configuración"
    fi
    
    # Configuraciones
    local agent_configured=$(echo "$status" | jq -r '.agent_configured')
    local servers_count=$(echo "$status" | jq -r '.servers_configured')
    if [ "$agent_configured" = "true" ]; then
        echo -e "${GREEN}🟢 Agente DevOps:${NC} Configurado ($servers_count servidores)"
    else
        echo -e "${RED}🔴 Agente DevOps:${NC} No configurado"
    fi
    
    local webhook_configured=$(echo "$status" | jq -r '.webhook_configured')
    local webhook_running=$(echo "$status" | jq -r '.webhook_running')
    local webhook_port=$(echo "$status" | jq -r '.webhook_port')
    if [ "$webhook_configured" = "true" ]; then
        if [ "$webhook_running" = "true" ]; then
            echo -e "${GREEN}🟢 GitHub Webhook:${NC} Configurado y ejecutándose (puerto $webhook_port)"
        else
            echo -e "${YELLOW}🟡 GitHub Webhook:${NC} Configurado pero no ejecutándose"
        fi
    else
        echo -e "${RED}🔴 GitHub Webhook:${NC} No configurado"
    fi
    
    local monitoring_configured=$(echo "$status" | jq -r '.monitoring_configured')
    if [ "$monitoring_configured" = "true" ]; then
        echo -e "${GREEN}🟢 Monitoreo:${NC} Configurado"
    else
        echo -e "${RED}🔴 Monitoreo:${NC} No configurado"
    fi
    
    # Estado de salud
    local health_status=$(echo "$status" | jq -r '.health_status')
    local last_check=$(echo "$status" | jq -r '.last_health_check')
    
    case "$health_status" in
        "OK")
            echo -e "${GREEN}🟢 Salud del Sistema:${NC} Todos los servidores operativos"
            ;;
        "WARNING")
            echo -e "${YELLOW}🟡 Salud del Sistema:${NC} Advertencias detectadas"
            ;;
        "CRITICAL")
            echo -e "${RED}🔴 Salud del Sistema:${NC} Problemas críticos"
            ;;
        *)
            echo -e "${BLUE}🔵 Salud del Sistema:${NC} Sin verificar"
            ;;
    esac
    
    if [ -n "$last_check" ] && [ "$last_check" != "" ]; then
        echo -e "${CYAN}🕒 Última verificación:${NC} $last_check"
    fi
    
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}"
}

# Función para configuración inicial
initial_setup() {
    show_header "CONFIGURACIÓN INICIAL DEL SISTEMA"
    
    show_info "Iniciando configuración paso a paso..."
    
    # Paso 1: Configurar agente DevOps
    show_info "Paso 1: Configurando Agente DevOps"
    if [ -f "$CONFIG_SCRIPT" ]; then
        "$CONFIG_SCRIPT"
    else
        show_error "Script de configuración no encontrado"
        return 1
    fi
    
    # Paso 2: Configurar webhook (opcional)
    echo -e "\n${BLUE}¿Desea configurar integración con GitHub? [Y/n]:${NC} "
    read -r setup_webhook
    
    if [[ ! "$setup_webhook" =~ ^[Nn]$ ]]; then
        show_info "Paso 2: Configurando GitHub Webhook"
        if [ -f "$WEBHOOK_SCRIPT" ]; then
            "$WEBHOOK_SCRIPT"
        else
            show_error "Script de webhook no encontrado"
        fi
    fi
    
    # Paso 3: Configurar monitoreo
    echo -e "\n${BLUE}¿Desea configurar monitoreo automático? [Y/n]:${NC} "
    read -r setup_monitoring
    
    if [[ ! "$setup_monitoring" =~ ^[Nn]$ ]]; then
        show_info "Paso 3: Configurando Monitoreo"
        if [ -f "$MONITOR_SCRIPT" ]; then
            "$MONITOR_SCRIPT"
        else
            show_error "Script de monitoreo no encontrado"
        fi
    fi
    
    # Guardar configuración maestra
    local master_config="{
        \"version\": \"$VERSION\",
        \"setup_completed\": true,
        \"setup_date\": \"$(date -Iseconds)\",
        \"webhook_enabled\": $([ ! "$setup_webhook" =~ ^[Nn]$ ] && echo true || echo false),
        \"monitoring_enabled\": $([ ! "$setup_monitoring" =~ ^[Nn]$ ] && echo true || echo false)
    }"
    
    echo "$master_config" > "$MASTER_CONFIG"
    
    show_success "Configuración inicial completada"
    log_message "INFO" "Configuración inicial completada"
}

# Función para ejecutar despliegue
run_deployment() {
    show_header "EJECUTAR DESPLIEGUE"
    
    if [ ! -f "$BASE_DIR/agente_devops_config.json" ]; then
        show_error "El agente DevOps no está configurado. Use la opción de configuración primero."
        return 1
    fi
    
    echo -e "${BLUE}Opciones de despliegue:${NC}"
    echo -e "  ${YELLOW}1.${NC} Simulación (solo mostrar comandos)"
    echo -e "  ${YELLOW}2.${NC} Ejecución real"
    echo -e "  ${YELLOW}3.${NC} Ejecución con monitoreo en tiempo real"
    
    echo -e "\n${BLUE}Seleccione una opción [1-3]:${NC} "
    read -r deploy_choice
    
    case $deploy_choice in
        1)
            show_info "Ejecutando despliegue en modo simulación"
            "$AGENT_SCRIPT" --modo simulacion
            ;;
        2)
            show_info "Ejecutando despliegue real"
            "$AGENT_SCRIPT" --modo ejecucion_real
            ;;
        3)
            show_info "Ejecutando despliegue con monitoreo"
            # Ejecutar despliegue en background
            "$AGENT_SCRIPT" --modo ejecucion_real &
            local deploy_pid=$!
            
            # Monitorear progreso
            show_info "Despliegue iniciado (PID: $deploy_pid)"
            show_info "Monitoreando progreso..."
            
            while kill -0 $deploy_pid 2>/dev/null; do
                sleep 5
                show_info "Despliegue en progreso..."
            done
            
            wait $deploy_pid
            local exit_code=$?
            
            if [ $exit_code -eq 0 ]; then
                show_success "Despliegue completado exitosamente"
            else
                show_error "Despliegue falló con código de salida: $exit_code"
            fi
            ;;
        *)
            show_error "Opción inválida"
            return 1
            ;;
    esac
    
    log_message "INFO" "Despliegue ejecutado - Modo: $deploy_choice"
}

# Función para gestionar servicios
manage_services() {
    show_header "GESTIÓN DE SERVICIOS"
    
    echo -e "${BLUE}Servicios disponibles:${NC}"
    echo -e "  ${YELLOW}1.${NC} GitHub Webhook Server"
    echo -e "  ${YELLOW}2.${NC} Monitor de Despliegues"
    echo -e "  ${YELLOW}3.${NC} Ver estado de todos los servicios"
    
    echo -e "\n${BLUE}Seleccione un servicio [1-3]:${NC} "
    read -r service_choice
    
    case $service_choice in
        1)
            echo -e "\n${BLUE}Acciones para GitHub Webhook:${NC}"
            echo -e "  ${YELLOW}1.${NC} Iniciar servidor"
            echo -e "  ${YELLOW}2.${NC} Ver estado"
            echo -e "  ${YELLOW}3.${NC} Probar webhook"
            
            echo -e "\n${BLUE}Seleccione una acción [1-3]:${NC} "
            read -r webhook_action
            
            case $webhook_action in
                1)
                    "$WEBHOOK_SCRIPT" --start-server
                    ;;
                2)
                    "$WEBHOOK_SCRIPT" --status
                    ;;
                3)
                    "$WEBHOOK_SCRIPT" --test
                    ;;
            esac
            ;;
        2)
            echo -e "\n${BLUE}Acciones para Monitor:${NC}"
            echo -e "  ${YELLOW}1.${NC} Verificación única"
            echo -e "  ${YELLOW}2.${NC} Monitoreo continuo"
            echo -e "  ${YELLOW}3.${NC} Ver estado actual"
            echo -e "  ${YELLOW}4.${NC} Ver alertas"
            
            echo -e "\n${BLUE}Seleccione una acción [1-4]:${NC} "
            read -r monitor_action
            
            case $monitor_action in
                1)
                    "$MONITOR_SCRIPT" --check
                    ;;
                2)
                    "$MONITOR_SCRIPT" --monitor
                    ;;
                3)
                    "$MONITOR_SCRIPT" --status
                    ;;
                4)
                    "$MONITOR_SCRIPT" --alerts
                    ;;
            esac
            ;;
        3)
            show_info "Estado de servicios:"
            
            # Verificar webhook
            if [ -f "$BASE_DIR/webhook_config.json" ]; then
                local port=$(jq -r '.webhook_port // 9000' "$BASE_DIR/webhook_config.json" 2>/dev/null)
                if netstat -an 2>/dev/null | grep -q ":$port.*LISTEN" || lsof -i ":$port" >/dev/null 2>&1; then
                    show_success "GitHub Webhook Server: Ejecutándose (puerto $port)"
                else
                    show_warning "GitHub Webhook Server: Detenido"
                fi
            else
                show_info "GitHub Webhook Server: No configurado"
            fi
            
            # Verificar monitoreo
            if [ -f "$BASE_DIR/deployment_status.json" ]; then
                local last_check=$(jq -r '.timestamp // ""' "$BASE_DIR/deployment_status.json" 2>/dev/null)
                if [ -n "$last_check" ]; then
                    show_success "Monitor de Despliegues: Última verificación $last_check"
                else
                    show_info "Monitor de Despliegues: Sin verificaciones"
                fi
            else
                show_info "Monitor de Despliegues: No configurado"
            fi
            ;;
    esac
}

# Función para ver logs y reportes
view_logs_reports() {
    show_header "LOGS Y REPORTES"
    
    echo -e "${BLUE}Opciones disponibles:${NC}"
    echo -e "  ${YELLOW}1.${NC} Ver logs del sistema maestro"
    echo -e "  ${YELLOW}2.${NC} Ver logs de despliegues"
    echo -e "  ${YELLOW}3.${NC} Ver logs de webhook"
    echo -e "  ${YELLOW}4.${NC} Ver logs de monitoreo"
    echo -e "  ${YELLOW}5.${NC} Ver reportes de salud"
    echo -e "  ${YELLOW}6.${NC} Limpiar logs antiguos"
    
    echo -e "\n${BLUE}Seleccione una opción [1-6]:${NC} "
    read -r log_choice
    
    case $log_choice in
        1)
            if [ -f "$MASTER_LOG" ]; then
                echo -e "${CYAN}Últimas 50 líneas del log maestro:${NC}\n"
                tail -50 "$MASTER_LOG"
            else
                show_info "No hay log maestro"
            fi
            ;;
        2)
            local deploy_logs=("$BASE_DIR"/deploy_*.log)
            if [ -f "${deploy_logs[0]}" ]; then
                echo -e "${CYAN}Logs de despliegue disponibles:${NC}"
                ls -la "$BASE_DIR"/deploy_*.log | tail -10
                echo -e "\n${BLUE}¿Ver el más reciente? [Y/n]:${NC} "
                read -r view_recent
                if [[ ! "$view_recent" =~ ^[Nn]$ ]]; then
                    local latest_log=$(ls -t "$BASE_DIR"/deploy_*.log | head -1)
                    echo -e "\n${CYAN}Contenido de $latest_log:${NC}\n"
                    tail -50 "$latest_log"
                fi
            else
                show_info "No hay logs de despliegue"
            fi
            ;;
        3)
            if [ -f "$BASE_DIR/webhook.log" ]; then
                echo -e "${CYAN}Últimas 50 líneas del log de webhook:${NC}\n"
                tail -50 "$BASE_DIR/webhook.log"
            else
                show_info "No hay log de webhook"
            fi
            ;;
        4)
            if [ -f "$BASE_DIR/monitor.log" ]; then
                echo -e "${CYAN}Últimas 50 líneas del log de monitoreo:${NC}\n"
                tail -50 "$BASE_DIR/monitor.log"
            else
                show_info "No hay log de monitoreo"
            fi
            ;;
        5)
            if [ -d "$BASE_DIR/reports" ]; then
                local reports=("$BASE_DIR/reports"/health_report_*.json)
                if [ -f "${reports[0]}" ]; then
                    echo -e "${CYAN}Reportes de salud disponibles:${NC}"
                    ls -la "$BASE_DIR/reports"/health_report_*.json | tail -5
                    echo -e "\n${BLUE}¿Ver el más reciente? [Y/n]:${NC} "
                    read -r view_report
                    if [[ ! "$view_report" =~ ^[Nn]$ ]]; then
                        local latest_report=$(ls -t "$BASE_DIR/reports"/health_report_*.json | head -1)
                        echo -e "\n${CYAN}Contenido de $latest_report:${NC}\n"
                        cat "$latest_report" | jq .
                    fi
                else
                    show_info "No hay reportes de salud"
                fi
            else
                show_info "No hay directorio de reportes"
            fi
            ;;
        6)
            echo -e "${BLUE}¿Limpiar logs antiguos? [y/N]:${NC} "
            read -r clean_logs
            if [[ "$clean_logs" =~ ^[Yy]$ ]]; then
                # Limpiar logs de despliegue (mantener últimos 10)
                find "$BASE_DIR" -name "deploy_*.log" -type f | sort -r | tail -n +11 | xargs -r rm
                
                # Truncar logs grandes
                for log_file in "$MASTER_LOG" "$BASE_DIR/webhook.log" "$BASE_DIR/monitor.log"; do
                    if [ -f "$log_file" ] && [ $(wc -l < "$log_file") -gt 1000 ]; then
                        tail -500 "$log_file" > "${log_file}.tmp" && mv "${log_file}.tmp" "$log_file"
                    fi
                done
                
                show_success "Logs limpiados"
            fi
            ;;
    esac
}

# Función para mostrar ayuda
show_help() {
    show_header "AYUDA DEL SISTEMA DEVOPS"
    
    echo -e "${CYAN}DevOps Master v$VERSION${NC}"
    echo -e "Sistema completo de despliegue automático para Webmin/Virtualmin\n"
    
    echo -e "${BLUE}Componentes del sistema:${NC}"
    echo -e "  🤖 ${YELLOW}Agente DevOps:${NC} Ejecuta despliegues automáticos con backup y rollback"
    echo -e "  🔗 ${YELLOW}GitHub Webhook:${NC} Integración con repositorios para despliegues automáticos"
    echo -e "  📊 ${YELLOW}Monitor:${NC} Supervisa la salud de servidores y genera alertas"
    echo -e "  🎛️  ${YELLOW}Configurador:${NC} Interfaz para configurar todos los componentes\n"
    
    echo -e "${BLUE}Flujo de trabajo típico:${NC}"
    echo -e "  1. Configurar servidores y credenciales"
    echo -e "  2. Configurar integración con GitHub (opcional)"
    echo -e "  3. Configurar monitoreo automático"
    echo -e "  4. Ejecutar despliegues manuales o automáticos"
    echo -e "  5. Monitorear salud del sistema\n"
    
    echo -e "${BLUE}Características principales:${NC}"
    echo -e "  ✅ Despliegues sin downtime (graceful reload)"
    echo -e "  ✅ Backup automático antes de cada despliegue"
    echo -e "  ✅ Rollback automático en caso de fallo"
    echo -e "  ✅ Estrategia canary (probar en un servidor primero)"
    echo -e "  ✅ Ventanas de tiempo para despliegues"
    echo -e "  ✅ Monitoreo continuo de salud"
    echo -e "  ✅ Alertas automáticas"
    echo -e "  ✅ Integración con GitHub webhooks\n"
    
    echo -e "${BLUE}Uso desde línea de comandos:${NC}"
    echo -e "  $0                    Mostrar menú interactivo"
    echo -e "  $0 --dashboard        Mostrar dashboard"
    echo -e "  $0 --deploy           Ejecutar despliegue"
    echo -e "  $0 --status           Mostrar estado del sistema"
    echo -e "  $0 --setup            Configuración inicial"
    echo -e "  $0 --help             Mostrar esta ayuda\n"
}

# Función para mostrar menú principal
show_menu() {
    show_dashboard
    
    echo -e "\n${BLUE}🎛️  MENÚ PRINCIPAL${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${YELLOW}1.${NC} 🚀 Ejecutar Despliegue"
    echo -e "  ${YELLOW}2.${NC} ⚙️  Configurar Sistema"
    echo -e "  ${YELLOW}3.${NC} 🔧 Gestionar Servicios"
    echo -e "  ${YELLOW}4.${NC} 📊 Monitoreo y Salud"
    echo -e "  ${YELLOW}5.${NC} 📋 Logs y Reportes"
    echo -e "  ${YELLOW}6.${NC} 🔄 Configuración Inicial"
    echo -e "  ${YELLOW}7.${NC} ❓ Ayuda"
    echo -e "  ${YELLOW}8.${NC} 🚪 Salir"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    
    echo -e "\n${BLUE}Seleccione una opción${NC} ${YELLOW}[1-8]${NC}: "
    read -r choice
    
    case $choice in
        1)
            run_deployment
            ;;
        2)
            echo -e "\n${BLUE}Opciones de configuración:${NC}"
            echo -e "  ${YELLOW}1.${NC} Configurar Agente DevOps"
            echo -e "  ${YELLOW}2.${NC} Configurar GitHub Webhook"
            echo -e "  ${YELLOW}3.${NC} Configurar Monitoreo"
            
            echo -e "\n${BLUE}Seleccione [1-3]:${NC} "
            read -r config_choice
            
            case $config_choice in
                1) "$CONFIG_SCRIPT" ;;
                2) "$WEBHOOK_SCRIPT" ;;
                3) "$MONITOR_SCRIPT" ;;
            esac
            ;;
        3)
            manage_services
            ;;
        4)
            "$MONITOR_SCRIPT" --check
            ;;
        5)
            view_logs_reports
            ;;
        6)
            initial_setup
            ;;
        7)
            show_help
            ;;
        8)
            show_success "¡Hasta luego!"
            log_message "INFO" "Sistema DevOps Master cerrado"
            exit 0
            ;;
        *)
            show_error "Opción inválida. Use 1-8"
            ;;
    esac
}

# Función principal
main() {
    # Verificar dependencias
    if ! check_dependencies; then
        exit 1
    fi
    
    # Verificar scripts del sistema
    if ! check_system_scripts; then
        show_error "Algunos scripts del sistema no están disponibles"
        show_info "Asegúrese de que todos los archivos estén en el directorio: $BASE_DIR"
        exit 1
    fi
    
    # Inicializar log
    log_message "INFO" "Sistema DevOps Master iniciado - Versión $VERSION"
    
    # Bucle principal del menú
    while true; do
        show_menu
        echo
        echo -e "${BLUE}Presione Enter para continuar...${NC}"
        read -r
    done
}

# Manejo de argumentos de línea de comandos
case "${1:-}" in
    --dashboard)
        show_dashboard
        ;;
    --deploy)
        run_deployment
        ;;
    --status)
        get_system_status | jq .
        ;;
    --setup)
        initial_setup
        ;;
    --help)
        show_help
        ;;
    "")
        main
        ;;
    *)
        show_error "Opción desconocida: $1"
        echo "Use --help para ver opciones disponibles"
        exit 1
        ;;
esac
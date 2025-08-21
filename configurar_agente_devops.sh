#!/bin/bash

# Configurador del Agente DevOps para Webmin/Virtualmin
# Este script permite configurar fácilmente los parámetros del agente

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -e

# Colores para output
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Directorio base
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$BASE_DIR/agente_devops_config.json"
AGENT_SCRIPT="$BASE_DIR/agente_devops_webmin.sh"

# Función para mostrar encabezados
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Fin de función duplicada

# Función para mostrar información
show_info() {
    echo -e "${YELLOW}[INFO]${NC} ℹ️  $1"
}

# Función para mostrar éxito
show_success() {
    echo -e "${GREEN}[SUCCESS]${NC} ✅ $1"
}

# Función para mostrar errores
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

# Función para leer input del usuario
read_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [ -n "$default" ]; then
        echo -e "${BLUE}$prompt${NC} ${YELLOW}[default: $default]${NC}: "
    else
        echo -e "${BLUE}$prompt${NC}: "
    fi
    
    read -r input
    if [ -z "$input" ] && [ -n "$default" ]; then
        input="$default"
    fi
    
    eval "$var_name='$input'"
}

# Función para validar IP o dominio
validate_host() {
    local host="$1"
    
    # Validar IP
    if [[ $host =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    fi
    
    # Validar dominio
    if [[ $host =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.[a-zA-Z]{2,}$ ]]; then
        return 0
    fi
    
    # Permitir localhost
    if [ "$host" = "localhost" ]; then
        return 0
    fi
    
    return 1
}

# Función para configurar servidores
configure_servers() {
    show_header "CONFIGURACIÓN DE SERVIDORES"
    
    local servers_json="["
    local server_count=0
    
    while true; do
        server_count=$((server_count + 1))
        echo -e "\n${CYAN}Configurando servidor #$server_count${NC}"
        
        local host user port web
        
        # Configurar host
        while true; do
            read_input "Host/IP del servidor" "" "host"
            if validate_host "$host"; then
                break
            else
                show_error "Host inválido. Use una IP válida, dominio o 'localhost'"
            fi
        done
        
        # Configurar usuario
        read_input "Usuario SSH" "deploy" "user"
        
        # Configurar puerto
        while true; do
            read_input "Puerto SSH" "22" "port"
            if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
                break
            else
                show_error "Puerto inválido. Use un número entre 1 y 65535"
            fi
        done
        
        # Configurar servidor web
        while true; do
            echo -e "${BLUE}Servidor web${NC} ${YELLOW}[1=apache2, 2=nginx]${NC}: "
            read -r web_choice
            case $web_choice in
                1|apache2)
                    web="apache2"
                    break
                    ;;
                2|nginx)
                    web="nginx"
                    break
                    ;;
                "")
                    web="apache2"
                    break
                    ;;
                *)
                    show_error "Opción inválida. Use 1 para Apache2 o 2 para Nginx"
                    ;;
            esac
        done
        
        # Agregar servidor al JSON
        if [ $server_count -gt 1 ]; then
            servers_json="$servers_json,"
        fi
        
        servers_json="$servers_json\n    {\"host\":\"$host\",\"user\":\"$user\",\"port\":$port,\"web\":\"$web\"}"
        
        # Preguntar si agregar más servidores
        echo -e "\n${BLUE}¿Agregar otro servidor?${NC} ${YELLOW}[y/N]${NC}: "
        read -r add_more
        if [[ ! "$add_more" =~ ^[Yy]$ ]]; then
            break
        fi
    done
    
    servers_json="$servers_json\n]"
    echo -e "$servers_json"
}

# Función para configurar ventana de tiempo
configure_time_window() {
    show_header "CONFIGURACIÓN DE VENTANA DE TIEMPO"
    
    echo -e "${BLUE}Opciones de ventana de tiempo:${NC}"
    echo -e "  ${YELLOW}1.${NC} Siempre (always)"
    echo -e "  ${YELLOW}2.${NC} Ventana específica (HH:MM–HH:MM Timezone)"
    echo -e "  ${YELLOW}3.${NC} Madrugada (02:00–04:00 America/New_York)"
    echo -e "  ${YELLOW}4.${NC} Noche (22:00–02:00 America/New_York)"
    
    while true; do
        echo -e "\n${BLUE}Seleccione una opción${NC} ${YELLOW}[1-4]${NC}: "
        read -r window_choice
        
        case $window_choice in
            1)
                echo "always"
                return
                ;;
            2)
                read_input "Hora de inicio (HH:MM)" "02:00" "start_time"
                read_input "Hora de fin (HH:MM)" "04:00" "end_time"
                read_input "Zona horaria" "America/New_York" "timezone"
                echo "$start_time–$end_time $timezone"
                return
                ;;
            3)
                echo "02:00–04:00 America/New_York"
                return
                ;;
            4)
                echo "22:00–02:00 America/New_York"
                return
                ;;
            "")
                echo "02:00–04:00 America/New_York"
                return
                ;;
            *)
                show_error "Opción inválida. Use 1, 2, 3 o 4"
                ;;
        esac
    done
}

# Función para configurar modo de operación
configure_mode() {
    show_header "CONFIGURACIÓN DE MODO DE OPERACIÓN"
    
    echo -e "${BLUE}Modos disponibles:${NC}"
    echo -e "  ${YELLOW}1.${NC} Simulación (solo muestra comandos, no ejecuta)"
    echo -e "  ${YELLOW}2.${NC} Ejecución real (ejecuta comandos reales)"
    
    while true; do
        echo -e "\n${BLUE}Seleccione el modo${NC} ${YELLOW}[1-2]${NC}: "
        read -r mode_choice
        
        case $mode_choice in
            1|"")
                echo "simulacion"
                return
                ;;
            2)
                echo "ejecucion_real"
                return
                ;;
            *)
                show_error "Opción inválida. Use 1 para simulación o 2 para ejecución real"
                ;;
        esac
    done
}

# Función para configurar estrategia
configure_strategy() {
    show_header "CONFIGURACIÓN DE ESTRATEGIA DE DESPLIEGUE"
    
    echo -e "${BLUE}Estrategias disponibles:${NC}"
    echo -e "  ${YELLOW}1.${NC} Canary then rollout (primero un servidor, luego el resto)"
    echo -e "  ${YELLOW}2.${NC} Sequential (todos los servidores secuencialmente)"
    
    while true; do
        echo -e "\n${BLUE}Seleccione la estrategia${NC} ${YELLOW}[1-2]${NC}: "
        read -r strategy_choice
        
        case $strategy_choice in
            1|"")
                echo "canary_then_rollout"
                return
                ;;
            2)
                echo "sequential"
                return
                ;;
            *)
                show_error "Opción inválida. Use 1 o 2"
                ;;
        esac
    done
}

# Función para configurar Laravel
configure_laravel() {
    show_header "CONFIGURACIÓN DE LARAVEL"
    
    echo -e "${BLUE}¿Su aplicación usa Laravel?${NC} ${YELLOW}[y/N]${NC}: "
    read -r laravel_choice
    
    if [[ "$laravel_choice" =~ ^[Yy]$ ]]; then
        echo "si"
    else
        echo "no"
    fi
}

# Función para generar configuración
generate_config() {
    show_header "GENERANDO CONFIGURACIÓN"
    
    local servers ventana modo rama estrategia laravel repo backup_dir log_path
    
    # Configurar servidores
    servers=$(configure_servers)
    
    # Configurar ventana de tiempo
    ventana=$(configure_time_window)
    
    # Configurar modo
    modo=$(configure_mode)
    
    # Configurar rama
    read_input "Rama de Git" "main" "rama"
    
    # Configurar estrategia
    estrategia=$(configure_strategy)
    
    # Configurar Laravel
    laravel=$(configure_laravel)
    
    # Configurar rutas
    read_input "Ruta del repositorio" "/srv/webmin-repo" "repo"
    read_input "Directorio de backups" "/var/backups/virtualmin" "backup_dir"
    read_input "Archivo de log" "/var/log/virtualmin-auto-update.log" "log_path"
    
    # Generar JSON de configuración
    local config_json="{
    \"servers\": $servers,
    \"ventana\": \"$ventana\",
    \"modo\": \"$modo\",
    \"rama\": \"$rama\",
    \"estrategia\": \"$estrategia\",
    \"laravel\": \"$laravel\",
    \"ruta_repo\": \"$repo\",
    \"backup_dir_base\": \"$backup_dir\",
    \"log_path\": \"$log_path\",
    \"hold_packages\": [\"apache2\", \"nginx\", \"php*-fpm\", \"mariadb-server\", \"mysql-server\"]
}"
    
    # Guardar configuración
    echo -e "$config_json" > "$CONFIG_FILE"
    
    show_success "Configuración guardada en: $CONFIG_FILE"
    
    # Mostrar resumen
    show_header "RESUMEN DE CONFIGURACIÓN"
    echo -e "${CYAN}Archivo de configuración:${NC} $CONFIG_FILE"
    echo -e "${CYAN}Modo:${NC} $modo"
    echo -e "${CYAN}Ventana:${NC} $ventana"
    echo -e "${CYAN}Rama:${NC} $rama"
    echo -e "${CYAN}Estrategia:${NC} $estrategia"
    echo -e "${CYAN}Laravel:${NC} $laravel"
    echo -e "${CYAN}Servidores configurados:${NC} $(echo "$servers" | grep -o '"host"' | wc -l)"
}

# Función para mostrar configuración actual
show_current_config() {
    show_header "CONFIGURACIÓN ACTUAL"
    
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${CYAN}Archivo:${NC} $CONFIG_FILE"
        echo -e "${CYAN}Contenido:${NC}"
        cat "$CONFIG_FILE" | jq . 2>/dev/null || cat "$CONFIG_FILE"
    else
        show_info "No existe configuración. Use la opción 1 para crear una."
    fi
}

# Función para ejecutar agente con configuración
run_agent_with_config() {
    show_header "EJECUTANDO AGENTE DEVOPS"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        show_error "No existe configuración. Cree una primero."
        return 1
    fi
    
    if [ ! -f "$AGENT_SCRIPT" ]; then
        show_error "No se encuentra el script del agente: $AGENT_SCRIPT"
        return 1
    fi
    
    # Leer configuración
    local modo=$(jq -r '.modo' "$CONFIG_FILE" 2>/dev/null || echo "simulacion")
    local ventana=$(jq -r '.ventana' "$CONFIG_FILE" 2>/dev/null || echo "always")
    local rama=$(jq -r '.rama' "$CONFIG_FILE" 2>/dev/null || echo "main")
    local estrategia=$(jq -r '.estrategia' "$CONFIG_FILE" 2>/dev/null || echo "canary_then_rollout")
    local laravel=$(jq -r '.laravel' "$CONFIG_FILE" 2>/dev/null || echo "no")
    local repo=$(jq -r '.ruta_repo' "$CONFIG_FILE" 2>/dev/null || echo "/srv/webmin-repo")
    local backup_dir=$(jq -r '.backup_dir_base' "$CONFIG_FILE" 2>/dev/null || echo "/var/backups/virtualmin")
    local log_path=$(jq -r '.log_path' "$CONFIG_FILE" 2>/dev/null || echo "/var/log/virtualmin-auto-update.log")
    
    show_info "Ejecutando agente con configuración:"
    echo -e "  ${CYAN}Modo:${NC} $modo"
    echo -e "  ${CYAN}Ventana:${NC} $ventana"
    echo -e "  ${CYAN}Rama:${NC} $rama"
    echo -e "  ${CYAN}Estrategia:${NC} $estrategia"
    
    # Ejecutar agente
    chmod +x "$AGENT_SCRIPT"
    "$AGENT_SCRIPT" \
        --modo "$modo" \
        --ventana "$ventana" \
        --rama "$rama" \
        --estrategia "$estrategia" \
        --laravel "$laravel" \
        --repo "$repo" \
        --backup-dir "$backup_dir" \
        --log "$log_path"
}

# Función para probar conectividad
test_connectivity() {
    show_header "PRUEBA DE CONECTIVIDAD"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        show_error "No existe configuración. Cree una primero."
        return 1
    fi
    
    # Leer servidores de la configuración
    local servers=$(jq -r '.servers[] | "\(.host) \(.user) \(.port)"' "$CONFIG_FILE" 2>/dev/null)
    
    if [ -z "$servers" ]; then
        show_error "No se pudieron leer los servidores de la configuración"
        return 1
    fi
    
    echo "$servers" | while read -r host user port; do
        if [ -n "$host" ]; then
            show_info "Probando conectividad a $user@$host:$port"
            
            if timeout 10 ssh -o ConnectTimeout=5 -o BatchMode=yes -p "$port" "$user@$host" "echo 'Conectividad OK'" 2>/dev/null; then
                show_success "Conectividad exitosa a $host"
            else
                show_error "No se puede conectar a $host"
            fi
        fi
    done
}

# Función para mostrar menú principal
show_menu() {
    show_header "CONFIGURADOR AGENTE DEVOPS WEBMIN/VIRTUALMIN"
    
    echo -e "${BLUE}Opciones disponibles:${NC}"
    echo -e "  ${YELLOW}1.${NC} Crear/Editar configuración"
    echo -e "  ${YELLOW}2.${NC} Mostrar configuración actual"
    echo -e "  ${YELLOW}3.${NC} Ejecutar agente con configuración"
    echo -e "  ${YELLOW}4.${NC} Probar conectividad a servidores"
    echo -e "  ${YELLOW}5.${NC} Mostrar ayuda del agente"
    echo -e "  ${YELLOW}6.${NC} Salir"
    
    echo -e "\n${BLUE}Seleccione una opción${NC} ${YELLOW}[1-6]${NC}: "
    read -r choice
    
    case $choice in
        1)
            generate_config
            ;;
        2)
            show_current_config
            ;;
        3)
            run_agent_with_config
            ;;
        4)
            test_connectivity
            ;;
        5)
            if [ -f "$AGENT_SCRIPT" ]; then
                chmod +x "$AGENT_SCRIPT"
                "$AGENT_SCRIPT" --help
            else
                show_error "No se encuentra el script del agente"
            fi
            ;;
        6)
            show_success "¡Hasta luego!"
            exit 0
            ;;
        *)
            show_error "Opción inválida. Use 1-6"
            ;;
    esac
}

# Función principal
main() {
    # Verificar dependencias
    if ! command -v jq >/dev/null 2>&1; then
        show_info "jq no está instalado. Algunas funciones pueden no funcionar correctamente."
        show_info "Para instalar jq: brew install jq (macOS) o apt-get install jq (Ubuntu)"
    fi
    
    # Bucle principal del menú
    while true; do
        echo
        show_menu
        echo
        echo -e "${BLUE}Presione Enter para continuar...${NC}"
        read -r
    done
}

# Ejecutar función principal
main "$@"

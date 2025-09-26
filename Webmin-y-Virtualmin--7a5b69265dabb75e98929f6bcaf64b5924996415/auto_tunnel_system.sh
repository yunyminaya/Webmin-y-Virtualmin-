#!/bin/bash
# auto_tunnel_system.sh
# Sistema de Túnel Automático para IPs Privadas
# Convierte automáticamente IPs privadas en públicas con monitoreo 24/7

# Configuración del sistema
SCRIPT_VERSION="2.0.0"
SCRIPT_NAME="Auto Tunnel System"
LOG_FILE="/var/log/auto_tunnel_system.log"
CONFIG_FILE="/etc/auto_tunnel_config.conf"
PID_FILE="/var/run/auto_tunnel_system.pid"
TUNNEL_PID_FILE="/var/run/ssh_tunnel.pid"
MONITOR_PID_FILE="/var/run/tunnel_monitor.pid"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Verificar que el script se ejecute como root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Este script debe ejecutarse como root${NC}"
    echo -e "${YELLOW}Ejemplo: sudo $0 $@${NC}"
    exit 1
fi

# Función de logging
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" >> "$LOG_FILE"
    echo -e "${timestamp} [${level}] ${message}"
}

# Función para verificar si una IP es privada
is_private_ip() {
    local ip="$1"
    # Rangos de IP privadas:
    # 10.0.0.0/8
    # 172.16.0.0/12
    # 192.168.0.0/16
    # 169.254.0.0/16 (APIPA)

    if [[ $ip =~ ^10\. ]]; then
        return 0  # Verdadero - es privada
    elif [[ $ip =~ ^172\.1[6-9]\. ]] || [[ $ip =~ ^172\.2[0-9]\. ]] || [[ $ip =~ ^172\.3[0-1]\. ]]; then
        return 0  # Verdadero - es privada
    elif [[ $ip =~ ^192\.168\. ]]; then
        return 0  # Verdadero - es privada
    elif [[ $ip =~ ^169\.254\. ]]; then
        return 0  # Verdadero - es privada
    else
        return 1  # Falso - es pública
    fi
}

# Función para obtener la IP externa actual
get_external_ip() {
    # Intentar múltiples servicios para obtener la IP externa
    local ip_services=(
        "https://api.ipify.org"
        "https://checkip.amazonaws.com"
        "https://icanhazip.com"
        "https://ipinfo.io/ip"
    )

    for service in "${ip_services[@]}"; do
        local ip=$(curl -s --connect-timeout 5 --max-time 10 "$service" 2>/dev/null | tr -d '[:space:]')
        if [[ -n "$ip" ]] && [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
    done

    # Si no se puede obtener IP externa, usar IP local como fallback
    hostname -I | awk '{print $1}'
}

# Función para verificar conectividad a internet
check_internet() {
    # Verificar conectividad probando múltiples hosts
    local test_hosts=("8.8.8.8" "1.1.1.1" "208.67.222.222")
    local timeout=5

    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1; then
            return 0
        fi
    done

    return 1
}

# Función para configurar el túnel SSH
setup_ssh_tunnel() {
    local remote_host="$1"
    local remote_user="$2"
    local remote_port="${3:-22}"
    local local_port="${4:-80}"
    local tunnel_port="${5:-8080}"

    log "INFO" "Configurando túnel SSH reverse a ${remote_user}@${remote_host}:${remote_port}"

    # Verificar que SSH esté disponible
    if ! command -v ssh >/dev/null 2>&1; then
        log "ERROR" "SSH no está instalado en el sistema"
        return 1
    fi

    # Crear clave SSH si no existe
    local ssh_key="/root/.ssh/auto_tunnel_key"
    if [[ ! -f "$ssh_key" ]]; then
        log "INFO" "Generando nueva clave SSH para túnel automático"
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh
        ssh-keygen -t rsa -b 4096 -f "$ssh_key" -N "" -C "auto-tunnel-system"
    fi

    # Intentar conexión SSH y agregar clave al known_hosts
    log "INFO" "Probando conexión SSH y configurando autenticación"
    ssh-keyscan -H "$remote_host" >> /root/.ssh/known_hosts 2>/dev/null

    # Configurar el túnel SSH reverse
    local ssh_cmd="ssh -i $ssh_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/root/.ssh/known_hosts -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -R ${tunnel_port}:localhost:${local_port} -N ${remote_user}@${remote_host} -p ${remote_port}"

    log "INFO" "Iniciando túnel SSH: $ssh_cmd"

    # Ejecutar el túnel en background
    nohup $ssh_cmd >/dev/null 2>&1 &
    local tunnel_pid=$!

    # Guardar el PID del túnel
    echo "$tunnel_pid" > "$TUNNEL_PID_FILE"

    # Esperar un momento y verificar que el túnel esté funcionando
    sleep 3
    if kill -0 "$tunnel_pid" 2>/dev/null; then
        log "SUCCESS" "Túnel SSH establecido exitosamente (PID: $tunnel_pid)"
        return 0
    else
        log "ERROR" "Falló al establecer el túnel SSH"
        return 1
    fi
}

# Función para verificar estado del túnel
check_tunnel_status() {
    if [[ -f "$TUNNEL_PID_FILE" ]]; then
        local tunnel_pid=$(cat "$TUNNEL_PID_FILE")
        if kill -0 "$tunnel_pid" 2>/dev/null; then
            return 0  # Túnel activo
        else
            # Limpiar PID file si el proceso no existe
            rm -f "$TUNNEL_PID_FILE"
        fi
    fi
    return 1  # Túnel inactivo
}

# Función para detener el túnel
stop_tunnel() {
    if [[ -f "$TUNNEL_PID_FILE" ]]; then
        local tunnel_pid=$(cat "$TUNNEL_PID_FILE")
        if kill -0 "$tunnel_pid" 2>/dev/null; then
            log "INFO" "Deteniendo túnel SSH (PID: $tunnel_pid)"
            kill "$tunnel_pid" 2>/dev/null
            sleep 2
            if kill -0 "$tunnel_pid" 2>/dev/null; then
                kill -9 "$tunnel_pid" 2>/dev/null
            fi
        fi
        rm -f "$TUNNEL_PID_FILE"
        log "SUCCESS" "Túnel SSH detenido"
    fi
}

# Función del monitor 24/7
tunnel_monitor() {
    log "INFO" "Iniciando monitor 24/7 del sistema de túnel"

    while true; do
        # Verificar conectividad a internet
        if ! check_internet; then
            log "WARNING" "Sin conectividad a internet - esperando..."
            sleep 30
            continue
        fi

        # Obtener IP externa actual
        local current_ip=$(get_external_ip)
        if [[ -z "$current_ip" ]]; then
            log "ERROR" "No se pudo obtener la IP externa"
            sleep 30
            continue
        fi

        # Verificar si la IP es privada
        if is_private_ip "$current_ip"; then
            log "INFO" "IP privada detectada: $current_ip - Verificando túnel"

            # Verificar estado del túnel
            if ! check_tunnel_status; then
                log "WARNING" "Túnel inactivo - Intentando reconectar"

                # Leer configuración del túnel
                if [[ -f "$CONFIG_FILE" ]]; then
                    source "$CONFIG_FILE"

                    if [[ -n "$TUNNEL_REMOTE_HOST" ]] && [[ -n "$TUNNEL_REMOTE_USER" ]]; then
                        if setup_ssh_tunnel "$TUNNEL_REMOTE_HOST" "$TUNNEL_REMOTE_USER" "$TUNNEL_REMOTE_PORT" "$TUNNEL_LOCAL_PORT" "$TUNNEL_PORT"; then
                            log "SUCCESS" "Túnel restablecido exitosamente"
                        else
                            log "ERROR" "Falló al restablecer el túnel"
                        fi
                    else
                        log "ERROR" "Configuración de túnel incompleta en $CONFIG_FILE"
                    fi
                else
                    log "ERROR" "Archivo de configuración no encontrado: $CONFIG_FILE"
                fi
            else
                log "INFO" "Túnel activo y funcionando correctamente"
            fi
        else
            log "INFO" "IP pública detectada: $current_ip - No se requiere túnel"

            # Si hay un túnel activo, detenerlo
            if check_tunnel_status; then
                log "INFO" "Deteniendo túnel innecesario (IP pública disponible)"
                stop_tunnel
            fi
        fi

        # Verificar cada 60 segundos
        sleep 60
    done
}

# Función para configurar el sistema
configure_system() {
    log "INFO" "Configurando sistema de túnel automático"

    # Crear directorios necesarios
    mkdir -p /etc/auto-tunnel
    mkdir -p /var/log
    mkdir -p /var/run

    # Crear archivo de configuración si no existe
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configuración del Sistema de Túnel Automático
# Modificar estos valores según sus necesidades

# Configuración del servidor remoto para túnel SSH
TUNNEL_REMOTE_HOST="tu-servidor-remoto.com"
TUNNEL_REMOTE_USER="tunnel_user"
TUNNEL_REMOTE_PORT="22"
TUNNEL_LOCAL_PORT="80"
TUNNEL_PORT="8080"

# Configuración de monitoreo
MONITOR_INTERVAL="60"
ENABLE_AUTO_RESTART="true"

# Configuración de alertas (opcional)
ALERT_EMAIL=""
ALERT_WEBHOOK=""
EOF

        log "INFO" "Archivo de configuración creado: $CONFIG_FILE"
        echo -e "${YELLOW}⚠️  IMPORTANTE: Configure los parámetros en $CONFIG_FILE antes de continuar${NC}"
    fi

    # Instalar dependencias
    log "INFO" "Verificando dependencias del sistema"

    local dependencies=("curl" "ssh" "ping" "nohup")
    local missing_deps=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "WARNING" "Dependencias faltantes: ${missing_deps[*]}"
        echo -e "${YELLOW}Instalando dependencias faltantes...${NC}"

        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y "${missing_deps[@]}"
        elif command -v yum >/dev/null 2>&1; then
            yum install -y "${missing_deps[@]}"
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y "${missing_deps[@]}"
        else
            log "ERROR" "No se pudo instalar dependencias - gestor de paquetes no reconocido"
            return 1
        fi
    fi

    log "SUCCESS" "Sistema configurado correctamente"
}

# Función para mostrar estado del sistema
show_status() {
    echo -e "${BLUE}=== ESTADO DEL SISTEMA DE TÚNEL AUTOMÁTICO ===${NC}"
    echo

    # Verificar conectividad
    echo -e "${CYAN}🔗 Conectividad a Internet:${NC}"
    if check_internet; then
        echo -e "   ✅ ${GREEN}Conectado${NC}"
    else
        echo -e "   ❌ ${RED}Sin conexión${NC}"
    fi

    # Mostrar IP externa
    local external_ip=$(get_external_ip)
    echo -e "${CYAN}🌐 IP Externa:${NC} $external_ip"

    # Verificar si es IP privada
    if is_private_ip "$external_ip"; then
        echo -e "${CYAN}🏠 Tipo de IP:${NC} ${YELLOW}Privada${NC} (Requiere túnel)"
    else
        echo -e "${CYAN}🌍 Tipo de IP:${NC} ${GREEN}Pública${NC} (No requiere túnel)"
    fi

    # Estado del túnel
    echo -e "${CYAN}🚇 Estado del Túnel:${NC}"
    if check_tunnel_status; then
        local tunnel_pid=$(cat "$TUNNEL_PID_FILE" 2>/dev/null)
        echo -e "   ✅ ${GREEN}Activo${NC} (PID: $tunnel_pid)"
    else
        echo -e "   ❌ ${RED}Inactivo${NC}"
    fi

    # Estado del monitor
    echo -e "${CYAN}👁️  Estado del Monitor:${NC}"
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local monitor_pid=$(cat "$MONITOR_PID_FILE" 2>/dev/null)
        if kill -0 "$monitor_pid" 2>/dev/null; then
            echo -e "   ✅ ${GREEN}Activo${NC} (PID: $monitor_pid)"
        else
            echo -e "   ❌ ${RED}Inactivo${NC} (proceso muerto)"
            rm -f "$MONITOR_PID_FILE"
        fi
    else
        echo -e "   ❌ ${RED}No iniciado${NC}"
    fi

    # Configuración
    echo -e "${CYAN}⚙️  Configuración:${NC}"
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "   ✅ ${GREEN}Archivo de configuración presente${NC}"
        if [[ -n "${TUNNEL_REMOTE_HOST:-}" ]]; then
            echo -e "   📍 Servidor remoto: ${TUNNEL_REMOTE_HOST}"
        fi
    else
        echo -e "   ❌ ${RED}Archivo de configuración faltante${NC}"
    fi

    echo
}

# Función para iniciar el servicio
start_service() {
    log "INFO" "Iniciando servicio de túnel automático"

    # Verificar que no esté ya ejecutándose
    if [[ -f "$PID_FILE" ]]; then
        local existing_pid=$(cat "$PID_FILE")
        if kill -0 "$existing_pid" 2>/dev/null; then
            log "WARNING" "El servicio ya está ejecutándose (PID: $existing_pid)"
            echo -e "${YELLOW}El servicio ya está ejecutándose${NC}"
            return 1
        else
            rm -f "$PID_FILE"
        fi
    fi

    # Configurar el sistema si es necesario
    configure_system

    # Iniciar el monitor en background
    log "INFO" "Iniciando monitor del túnel"
    tunnel_monitor &
    local monitor_pid=$!

    # Guardar PIDs
    echo "$monitor_pid" > "$MONITOR_PID_FILE"
    echo "$$" > "$PID_FILE"

    log "SUCCESS" "Servicio de túnel automático iniciado (PID: $monitor_pid)"
    echo -e "${GREEN}✅ Servicio de túnel automático iniciado${NC}"
    echo -e "${BLUE}📊 Use '$0 status' para ver el estado del sistema${NC}"
}

# Función para detener el servicio
stop_service() {
    log "INFO" "Deteniendo servicio de túnel automático"

    # Detener el túnel si está activo
    stop_tunnel

    # Detener el monitor
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local monitor_pid=$(cat "$MONITOR_PID_FILE")
        if kill -0 "$monitor_pid" 2>/dev/null; then
            log "INFO" "Deteniendo monitor (PID: $monitor_pid)"
            kill "$monitor_pid" 2>/dev/null
            sleep 2
            if kill -0 "$monitor_pid" 2>/dev/null; then
                kill -9 "$monitor_pid" 2>/dev/null
            fi
        fi
        rm -f "$MONITOR_PID_FILE"
    fi

    # Limpiar archivos PID
    rm -f "$PID_FILE"

    log "SUCCESS" "Servicio de túnel automático detenido"
    echo -e "${GREEN}✅ Servicio de túnel automático detenido${NC}"
}

# Función principal
main() {
    local command="${1:-status}"

    case "$command" in
        "start")
            start_service
            ;;
        "stop")
            stop_service
            ;;
        "restart")
            stop_service
            sleep 2
            start_service
            ;;
        "status")
            show_status
            ;;
        "configure")
            configure_system
            ;;
        "test")
            echo -e "${BLUE}=== PRUEBA DEL SISTEMA DE TÚNEL ===${NC}"
            echo

            echo -e "${CYAN}🔗 Probando conectividad a internet...${NC}"
            if check_internet; then
                echo -e "   ✅ ${GREEN}Conectividad OK${NC}"
            else
                echo -e "   ❌ ${RED}Sin conectividad${NC}"
            fi

            echo -e "${CYAN}🌐 Obteniendo IP externa...${NC}"
            local ip=$(get_external_ip)
            if [[ -n "$ip" ]]; then
                echo -e "   ✅ ${GREEN}IP externa: $ip${NC}"
                if is_private_ip "$ip"; then
                    echo -e "   ℹ️  ${YELLOW}IP privada detectada - túnel requerido${NC}"
                else
                    echo -e "   ℹ️  ${GREEN}IP pública detectada - túnel no requerido${NC}"
                fi
            else
                echo -e "   ❌ ${RED}No se pudo obtener IP externa${NC}"
            fi

            echo -e "${CYAN}🚇 Verificando estado del túnel...${NC}"
            if check_tunnel_status; then
                echo -e "   ✅ ${GREEN}Túnel activo${NC}"
            else
                echo -e "   ❌ ${RED}Túnel inactivo${NC}"
            fi
            ;;
        "help"|"-h"|"--help")
            echo -e "${BLUE}=== SISTEMA DE TÚNEL AUTOMÁTICO ===${NC}"
            echo
            echo -e "${CYAN}Uso:${NC} $0 [comando]"
            echo
            echo -e "${GREEN}Comandos disponibles:${NC}"
            echo "  start      - Iniciar el servicio de túnel automático"
            echo "  stop       - Detener el servicio de túnel automático"
            echo "  restart    - Reiniciar el servicio"
            echo "  status     - Mostrar estado del sistema"
            echo "  configure  - Configurar el sistema"
            echo "  test       - Ejecutar pruebas del sistema"
            echo "  help       - Mostrar esta ayuda"
            echo
            echo -e "${YELLOW}Ejemplos:${NC}"
            echo "  $0 start          # Iniciar el servicio"
            echo "  $0 status         # Ver estado actual"
            echo "  $0 configure      # Configurar parámetros"
            ;;
        *)
            echo -e "${RED}Comando desconocido: $command${NC}"
            echo -e "${YELLOW}Use '$0 help' para ver comandos disponibles${NC}"
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"
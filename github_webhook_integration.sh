#!/bin/bash

# Integración con GitHub Webhooks para Agente DevOps Webmin/Virtualmin
# Este script configura y maneja webhooks de GitHub para despliegues automáticos

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Directorio base
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEBHOOK_CONFIG="$BASE_DIR/webhook_config.json"
WEBHOOK_LOG="$BASE_DIR/webhook.log"
AGENT_SCRIPT="$BASE_DIR/agente_devops_webmin.sh"
CONFIG_SCRIPT="$BASE_DIR/configurar_agente_devops.sh"
WEBHOOK_PORT=9000
WEBHOOK_SECRET=""

# Función para mostrar encabezados
show_header() {
    echo -e "\n${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}🔗 $1${NC}"
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

# Función para logging
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [${level}] ${message}" >> "$WEBHOOK_LOG"
}

# Función para generar secreto aleatorio
generate_secret() {
    openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p -c 32
}

# Función para verificar firma HMAC
verify_signature() {
    local payload="$1"
    local signature="$2"
    local secret="$3"
    
    if [ -z "$secret" ]; then
        return 0  # Sin secreto, no verificar
    fi
    
    local expected=$(echo -n "$payload" | openssl dgst -sha256 -hmac "$secret" | cut -d' ' -f2)
    local received=$(echo "$signature" | sed 's/sha256=//')
    
    if [ "$expected" = "$received" ]; then
        return 0
    else
        return 1
    fi
}

# Función para procesar webhook de GitHub
process_github_webhook() {
    local payload="$1"
    local signature="$2"
    
    log_message "INFO" "Procesando webhook de GitHub"
    
    # Verificar firma si hay secreto configurado
    if [ -n "$WEBHOOK_SECRET" ]; then
        if ! verify_signature "$payload" "$signature" "$WEBHOOK_SECRET"; then
            log_message "ERROR" "Firma de webhook inválida"
            echo '{"status":"error","message":"Invalid signature"}'
            return 1
        fi
        log_message "INFO" "Firma de webhook verificada"
    fi
    
    # Parsear payload JSON
    local ref=$(echo "$payload" | jq -r '.ref // empty' 2>/dev/null)
    local repository=$(echo "$payload" | jq -r '.repository.full_name // empty' 2>/dev/null)
    local commit=$(echo "$payload" | jq -r '.head_commit.id // empty' 2>/dev/null)
    local branch=$(echo "$ref" | sed 's|refs/heads/||')
    
    log_message "INFO" "Webhook recibido - Repo: $repository, Branch: $branch, Commit: $commit"
    
    # Verificar si es la rama correcta
    local target_branch=$(jq -r '.target_branch // "main"' "$WEBHOOK_CONFIG" 2>/dev/null)
    if [ "$branch" != "$target_branch" ]; then
        log_message "INFO" "Ignorando push a rama $branch (esperando $target_branch)"
        echo '{"status":"ignored","message":"Branch not monitored"}'
        return 0
    fi
    
    # Ejecutar agente DevOps
    log_message "INFO" "Iniciando despliegue automático"
    
    if [ -f "$AGENT_SCRIPT" ]; then
        # Ejecutar en background y capturar PID
        nohup "$AGENT_SCRIPT" --modo ejecucion_real > "$BASE_DIR/deploy_$(date +%Y%m%d_%H%M%S).log" 2>&1 &
        local deploy_pid=$!
        
        log_message "INFO" "Despliegue iniciado con PID: $deploy_pid"
        
        echo "{\"status\":\"started\",\"message\":\"Deployment started\",\"pid\":$deploy_pid,\"commit\":\"$commit\"}"
        return 0
    else
        log_message "ERROR" "Script del agente no encontrado: $AGENT_SCRIPT"
        echo '{"status":"error","message":"Agent script not found"}'
        return 1
    fi
}

# Función para crear servidor webhook simple
start_webhook_server() {
    local port="$1"
    
    show_header "INICIANDO SERVIDOR WEBHOOK"
    
    show_info "Puerto: $port"
    show_info "Log: $WEBHOOK_LOG"
    
    # Crear directorio para logs si no existe
    mkdir -p "$(dirname "$WEBHOOK_LOG")"
    
    log_message "INFO" "Servidor webhook iniciado en puerto $port"
    
    # Servidor webhook simple usando netcat y bash
    while true; do
        {
            # Leer request HTTP
            local request_line=""
            local headers=""
            local content_length=0
            local signature=""
            
            # Leer primera línea (método y path)
            read -r request_line
            
            # Leer headers
            while IFS= read -r line; do
                line=$(echo "$line" | tr -d '\r')
                if [ -z "$line" ]; then
                    break
                fi
                
                headers="$headers$line\n"
                
                # Extraer Content-Length
                if [[ "$line" =~ ^[Cc]ontent-[Ll]ength:[[:space:]]*([0-9]+) ]]; then
                    content_length="${BASH_REMATCH[1]}"
                fi
                
                # Extraer signature de GitHub
                if [[ "$line" =~ ^[Xx]-[Hh]ub-[Ss]ignature-256:[[:space:]]*(.+) ]]; then
                    signature="${BASH_REMATCH[1]}"
                fi
            done
            
            # Leer payload si hay Content-Length
            local payload=""
            if [ "$content_length" -gt 0 ]; then
                payload=$(head -c "$content_length")
            fi
            
            # Procesar solo requests POST a /webhook
            if [[ "$request_line" =~ ^POST[[:space:]]+/webhook ]]; then
                log_message "INFO" "Webhook request recibido"
                
                local response=$(process_github_webhook "$payload" "$signature")
                local status_code=200
                
                if [[ "$response" =~ \"status\":\"error\" ]]; then
                    status_code=400
                fi
                
                # Enviar respuesta HTTP
                echo "HTTP/1.1 $status_code OK"
                echo "Content-Type: application/json"
                echo "Content-Length: ${#response}"
                echo "Connection: close"
                echo ""
                echo "$response"
            else
                # Respuesta para otros requests
                local response='{"status":"ok","message":"GitHub Webhook Server for Webmin/Virtualmin DevOps Agent"}'
                echo "HTTP/1.1 200 OK"
                echo "Content-Type: application/json"
                echo "Content-Length: ${#response}"
                echo "Connection: close"
                echo ""
                echo "$response"
            fi
        } | nc -l -p "$port" -q 1
        
        # Pequeña pausa para evitar bucle muy rápido
        sleep 0.1
    done
}

# Función para configurar webhook
configure_webhook() {
    show_header "CONFIGURACIÓN DE WEBHOOK"
    
    local repo_url target_branch webhook_secret use_secret
    
    # Configurar repositorio
    echo -e "${BLUE}URL del repositorio GitHub${NC} ${YELLOW}(ej: https://github.com/user/repo)${NC}: "
    read -r repo_url
    
    # Configurar rama objetivo
    echo -e "${BLUE}Rama a monitorear${NC} ${YELLOW}[default: main]${NC}: "
    read -r target_branch
    if [ -z "$target_branch" ]; then
        target_branch="main"
    fi
    
    # Configurar secreto
    echo -e "${BLUE}¿Usar secreto para verificar webhooks?${NC} ${YELLOW}[Y/n]${NC}: "
    read -r use_secret
    
    if [[ ! "$use_secret" =~ ^[Nn]$ ]]; then
        webhook_secret=$(generate_secret)
        show_success "Secreto generado: $webhook_secret"
        show_info "Guarde este secreto para configurar en GitHub"
    else
        webhook_secret=""
    fi
    
    # Configurar puerto
    echo -e "${BLUE}Puerto del servidor webhook${NC} ${YELLOW}[default: 9000]${NC}: "
    read -r webhook_port
    if [ -z "$webhook_port" ]; then
        webhook_port=9000
    fi
    
    # Generar configuración
    local config="{
    \"repository_url\": \"$repo_url\",
    \"target_branch\": \"$target_branch\",
    \"webhook_secret\": \"$webhook_secret\",
    \"webhook_port\": $webhook_port,
    \"created_at\": \"$(date -Iseconds)\"
}"
    
    echo "$config" > "$WEBHOOK_CONFIG"
    
    show_success "Configuración guardada en: $WEBHOOK_CONFIG"
    
    # Mostrar instrucciones para GitHub
    show_header "INSTRUCCIONES PARA CONFIGURAR EN GITHUB"
    
    echo -e "${CYAN}1. Vaya a su repositorio en GitHub${NC}"
    echo -e "${CYAN}2. Vaya a Settings > Webhooks > Add webhook${NC}"
    echo -e "${CYAN}3. Configure los siguientes valores:${NC}"
    echo -e "   ${YELLOW}Payload URL:${NC} http://su-servidor:$webhook_port/webhook"
    echo -e "   ${YELLOW}Content type:${NC} application/json"
    if [ -n "$webhook_secret" ]; then
        echo -e "   ${YELLOW}Secret:${NC} $webhook_secret"
    fi
    echo -e "   ${YELLOW}Events:${NC} Just the push event"
    echo -e "   ${YELLOW}Active:${NC} ✓"
    
    echo -e "\n${CYAN}4. Para probar el webhook:${NC}"
    echo -e "   ${YELLOW}curl -X POST http://localhost:$webhook_port/webhook${NC}"
}

# Función para mostrar estado del webhook
show_webhook_status() {
    show_header "ESTADO DEL WEBHOOK"
    
    if [ -f "$WEBHOOK_CONFIG" ]; then
        echo -e "${CYAN}Configuración:${NC}"
        cat "$WEBHOOK_CONFIG" | jq . 2>/dev/null || cat "$WEBHOOK_CONFIG"
        
        local port=$(jq -r '.webhook_port // 9000' "$WEBHOOK_CONFIG" 2>/dev/null)
        
        echo -e "\n${CYAN}Estado del servidor:${NC}"
        if netstat -an 2>/dev/null | grep -q ":$port.*LISTEN" || lsof -i ":$port" >/dev/null 2>&1; then
            show_success "Servidor webhook ejecutándose en puerto $port"
        else
            show_info "Servidor webhook no está ejecutándose"
        fi
        
        if [ -f "$WEBHOOK_LOG" ]; then
            echo -e "\n${CYAN}Últimas entradas del log:${NC}"
            tail -10 "$WEBHOOK_LOG" 2>/dev/null || echo "Log vacío"
        fi
    else
        show_info "No hay configuración de webhook. Use la opción 1 para crear una."
    fi
}

# Función para probar webhook
test_webhook() {
    show_header "PRUEBA DE WEBHOOK"
    
    if [ ! -f "$WEBHOOK_CONFIG" ]; then
        show_error "No hay configuración de webhook"
        return 1
    fi
    
    local port=$(jq -r '.webhook_port // 9000' "$WEBHOOK_CONFIG" 2>/dev/null)
    local target_branch=$(jq -r '.target_branch // "main"' "$WEBHOOK_CONFIG" 2>/dev/null)
    
    # Payload de prueba
    local test_payload="{
        \"ref\": \"refs/heads/$target_branch\",
        \"repository\": {
            \"full_name\": \"test/repo\"
        },
        \"head_commit\": {
            \"id\": \"test123456789\"
        }
    }"
    
    show_info "Enviando webhook de prueba a puerto $port"
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$test_payload" \
        "http://localhost:$port/webhook" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        show_success "Webhook enviado exitosamente"
        echo -e "${CYAN}Respuesta:${NC} $response"
    else
        show_error "Error enviando webhook. ¿Está el servidor ejecutándose?"
    fi
}

# Función para mostrar logs
show_logs() {
    show_header "LOGS DEL WEBHOOK"
    
    if [ -f "$WEBHOOK_LOG" ]; then
        echo -e "${BLUE}Archivo de log:${NC} $WEBHOOK_LOG"
        echo -e "${BLUE}Últimas 50 líneas:${NC}\n"
        tail -50 "$WEBHOOK_LOG"
    else
        show_info "No hay archivo de log"
    fi
}

# Función para limpiar logs
clean_logs() {
    show_header "LIMPIEZA DE LOGS"
    
    if [ -f "$WEBHOOK_LOG" ]; then
        local log_size=$(wc -l < "$WEBHOOK_LOG")
        echo -e "${BLUE}Líneas actuales en log:${NC} $log_size"
        
        echo -e "${BLUE}¿Limpiar archivo de log?${NC} ${YELLOW}[y/N]${NC}: "
        read -r confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            > "$WEBHOOK_LOG"
            show_success "Log limpiado"
        else
            show_info "Operación cancelada"
        fi
    else
        show_info "No hay archivo de log para limpiar"
    fi
}

# Función para mostrar menú principal
show_menu() {
    show_header "INTEGRACIÓN GITHUB WEBHOOK - AGENTE DEVOPS"
    
    echo -e "${BLUE}Opciones disponibles:${NC}"
    echo -e "  ${YELLOW}1.${NC} Configurar webhook"
    echo -e "  ${YELLOW}2.${NC} Mostrar estado del webhook"
    echo -e "  ${YELLOW}3.${NC} Iniciar servidor webhook"
    echo -e "  ${YELLOW}4.${NC} Probar webhook"
    echo -e "  ${YELLOW}5.${NC} Ver logs"
    echo -e "  ${YELLOW}6.${NC} Limpiar logs"
    echo -e "  ${YELLOW}7.${NC} Configurar agente DevOps"
    echo -e "  ${YELLOW}8.${NC} Salir"
    
    echo -e "\n${BLUE}Seleccione una opción${NC} ${YELLOW}[1-8]${NC}: "
    read -r choice
    
    case $choice in
        1)
            configure_webhook
            ;;
        2)
            show_webhook_status
            ;;
        3)
            if [ -f "$WEBHOOK_CONFIG" ]; then
                local port=$(jq -r '.webhook_port // 9000' "$WEBHOOK_CONFIG" 2>/dev/null)
                WEBHOOK_SECRET=$(jq -r '.webhook_secret // ""' "$WEBHOOK_CONFIG" 2>/dev/null)
                start_webhook_server "$port"
            else
                show_error "Configure el webhook primero (opción 1)"
            fi
            ;;
        4)
            test_webhook
            ;;
        5)
            show_logs
            ;;
        6)
            clean_logs
            ;;
        7)
            if [ -f "$CONFIG_SCRIPT" ]; then
                chmod +x "$CONFIG_SCRIPT"
                "$CONFIG_SCRIPT"
            else
                show_error "Script de configuración no encontrado: $CONFIG_SCRIPT"
            fi
            ;;
        8)
            show_success "¡Hasta luego!"
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
    local missing_deps=()
    
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    if ! command -v nc >/dev/null 2>&1; then
        missing_deps+=("netcat")
    fi
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        show_error "Dependencias faltantes: ${missing_deps[*]}"
        show_info "Para instalar en macOS: brew install ${missing_deps[*]}"
        show_info "Para instalar en Ubuntu: apt-get install ${missing_deps[*]}"
        exit 1
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

# Manejo de argumentos de línea de comandos
case "${1:-}" in
    --start-server)
        if [ -f "$WEBHOOK_CONFIG" ]; then
            local port=$(jq -r '.webhook_port // 9000' "$WEBHOOK_CONFIG" 2>/dev/null)
            WEBHOOK_SECRET=$(jq -r '.webhook_secret // ""' "$WEBHOOK_CONFIG" 2>/dev/null)
            start_webhook_server "$port"
        else
            show_error "Configure el webhook primero"
            exit 1
        fi
        ;;
    --test)
        test_webhook
        ;;
    --status)
        show_webhook_status
        ;;
    --help)
        echo "Integración GitHub Webhook para Agente DevOps Webmin/Virtualmin"
        echo ""
        echo "Uso: $0 [opción]"
        echo ""
        echo "Opciones:"
        echo "  --start-server    Iniciar servidor webhook"
        echo "  --test           Probar webhook"
        echo "  --status         Mostrar estado"
        echo "  --help           Mostrar ayuda"
        echo ""
        echo "Sin argumentos: Mostrar menú interactivo"
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
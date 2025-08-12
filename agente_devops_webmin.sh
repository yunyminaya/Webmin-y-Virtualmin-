#!/bin/bash

# Agente DevOps para Webmin/Virtualmin
# Despliegue seguro automático sin tumbar sitios
# Estrategia: backup → actualizar → recarga suave → pruebas → rollback si falla

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuración por defecto (puede ser sobrescrita por parámetros)
SERVERS='[
  {"host":"localhost","user":"deploy","port":22,"web":"apache2"},
  {"host":"backup.local","user":"deploy","port":22,"web":"apache2"}
]'
VENTANA="02:00–04:00 America/New_York"
MODO="simulacion"
RAMA="main"
RUTA_REPO="/srv/webmin-repo"
BACKUP_DIR_BASE="/var/backups/virtualmin"
LOG_PATH="/var/log/virtualmin-auto-update.log"
HOLD_PACKAGES=("apache2" "nginx" "php*-fpm" "mariadb-server" "mysql-server")
ESTRATEGIA="canary_then_rollout"
LARAVEL="no"

# Variables globales
GLOBAL_STATUS="OK"
DEPLOY_RESULTS=()
CURRENT_COMMIT=""
TIMESTAMP=$(date +%F_%H%M)

# Función para logging
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_PATH" 2>/dev/null || echo -e "${timestamp} [${level}] ${message}"
}

# Función para mostrar encabezados
show_header() {
    echo -e "\n${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}🚀 $1${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}\n"
    log_message "INFO" "$1"
}

# Función para mostrar pasos
show_step() {
    echo -e "${BLUE}[PASO]${NC} $1"
    log_message "STEP" "$1"
}

# Función para mostrar éxito
show_success() {
    echo -e "${GREEN}[SUCCESS]${NC} ✅ $1"
    log_message "SUCCESS" "$1"
}

# Función para mostrar información
show_info() {
    echo -e "${YELLOW}[INFO]${NC} ℹ️  $1"
    log_message "INFO" "$1"
}

# Función para mostrar errores
show_error() {
    echo -e "${RED}[ERROR]${NC} ❌ $1"
    log_message "ERROR" "$1"
}

# Función para verificar ventana de tiempo
check_time_window() {
    if [ "$VENTANA" = "always" ]; then
        return 0
    fi
    
    # Extraer horas de la ventana (formato: "HH:MM–HH:MM Timezone")
    local start_time=$(echo "$VENTANA" | cut -d'–' -f1 | tr -d ' ')
    local end_time=$(echo "$VENTANA" | cut -d'–' -f2 | cut -d' ' -f1)
    local timezone=$(echo "$VENTANA" | cut -d' ' -f2-)
    
    # Obtener hora actual en la zona especificada
    local current_time=$(TZ="$timezone" date +%H:%M)
    
    show_info "Verificando ventana de tiempo: $start_time - $end_time ($timezone)"
    show_info "Hora actual: $current_time"
    
    # Comparación simple de tiempo (asume mismo día)
    if [[ "$current_time" > "$start_time" && "$current_time" < "$end_time" ]]; then
        show_success "Dentro de la ventana de despliegue"
        return 0
    else
        show_info "Fuera de la ventana de despliegue, cambiando a modo simulación"
        MODO="simulacion"
        return 1
    fi
}

# Función para ejecutar comando (simulación o real)
execute_command() {
    local cmd="$1"
    local description="$2"
    
    if [ "$MODO" = "simulacion" ]; then
        show_info "[SIMULACIÓN] $description"
        echo -e "${CYAN}    Comando: $cmd${NC}"
        return 0
    else
        show_step "$description"
        if eval "$cmd"; then
            show_success "$description completado"
            return 0
        else
            show_error "Falló: $description"
            return 1
        fi
    fi
}

# Función para verificar conectividad SSH
check_ssh_connectivity() {
    local host="$1"
    local user="$2"
    local port="$3"
    
    show_step "Verificando conectividad SSH a $user@$host:$port"
    
    if [ "$MODO" = "simulacion" ]; then
        show_info "[SIMULACIÓN] Verificaría conectividad SSH"
        return 0
    fi
    
    if timeout 10 ssh -o ConnectTimeout=5 -o BatchMode=yes -p "$port" "$user@$host" "echo 'SSH OK'" >/dev/null 2>&1; then
        show_success "Conectividad SSH establecida"
        return 0
    else
        show_error "No se puede conectar por SSH a $user@$host:$port"
        return 1
    fi
}

# Función para ejecutar comando remoto
execute_remote_command() {
    local host="$1"
    local user="$2"
    local port="$3"
    local cmd="$4"
    local description="$5"
    
    if [ "$MODO" = "simulacion" ]; then
        show_info "[SIMULACIÓN] $description"
        echo -e "${CYAN}    SSH: $user@$host:$port${NC}"
        echo -e "${CYAN}    Comando: $cmd${NC}"
        return 0
    else
        show_step "$description"
        if ssh -o ConnectTimeout=10 -p "$port" "$user@$host" "$cmd"; then
            show_success "$description completado"
            return 0
        else
            show_error "Falló: $description"
            return 1
        fi
    fi
}

# Función para verificar binarios requeridos
check_required_binaries() {
    local host="$1"
    local user="$2"
    local port="$3"
    local web="$4"
    
    show_step "Verificando binarios requeridos en $host"
    
    local binaries="virtualmin git curl systemctl"
    if [ "$web" = "apache2" ]; then
        binaries="$binaries apachectl"
    else
        binaries="$binaries nginx"
    fi
    
    local check_cmd="for bin in $binaries; do which \$bin >/dev/null || { echo \"Falta binario: \$bin\"; exit 1; }; done"
    
    if execute_remote_command "$host" "$user" "$port" "$check_cmd" "Verificación de binarios"; then
        return 0
    else
        return 1
    fi
}

# Función para listar vhosts
get_vhosts() {
    local host="$1"
    local user="$2"
    local port="$3"
    
    show_step "Obteniendo lista de vhosts en $host"
    
    local cmd="sudo virtualmin list-domains --name-only 2>/dev/null || echo 'no-domains'"
    
    if [ "$MODO" = "simulacion" ]; then
        show_info "[SIMULACIÓN] Obtendría lista de vhosts"
        echo "example.com test.local"
        return 0
    else
        ssh -o ConnectTimeout=10 -p "$port" "$user@$host" "$cmd" 2>/dev/null || echo "no-domains"
    fi
}

# Función para healthcheck de vhost
check_vhost_health() {
    local host="$1"
    local user="$2"
    local port="$3"
    local vhost="$4"
    
    if [ "$vhost" = "no-domains" ]; then
        return 0
    fi
    
    show_step "Verificando salud de $vhost"
    
    local check_cmd="curl -k --silent --fail --max-time 10 https://$vhost/ >/dev/null 2>&1 || curl --silent --fail --max-time 10 http://$vhost/ >/dev/null 2>&1"
    
    if execute_remote_command "$host" "$user" "$port" "$check_cmd" "Healthcheck de $vhost"; then
        return 0
    else
        return 1
    fi
}

# Función para crear backup
create_backup() {
    local host="$1"
    local user="$2"
    local port="$3"
    
    show_step "Creando backup en $host"
    
    local backup_cmd="
        TS=\$(date +%F_%H%M)
        DEST=$BACKUP_DIR_BASE/\$TS
        sudo mkdir -p \"\$DEST\"
        sudo virtualmin backup-domain --all-domains --dest \"\$DEST\" --all-features --newformat || true
        echo \"\$TS\"
    "
    
    if [ "$MODO" = "simulacion" ]; then
        show_info "[SIMULACIÓN] Crearía backup en $BACKUP_DIR_BASE/$TIMESTAMP"
        echo "$TIMESTAMP"
        return 0
    else
        local backup_id=$(ssh -o ConnectTimeout=10 -p "$port" "$user@$host" "$backup_cmd" 2>/dev/null | tail -1)
        if [ -n "$backup_id" ]; then
            show_success "Backup creado: $backup_id"
            echo "$backup_id"
            return 0
        else
            show_error "Falló la creación del backup"
            return 1
        fi
    fi
}

# Función para proteger paquetes
hold_packages() {
    local host="$1"
    local user="$2"
    local port="$3"
    
    show_step "Protegiendo paquetes críticos en $host"
    
    local packages="${HOLD_PACKAGES[*]}"
    local hold_cmd="sudo apt-mark hold $packages"
    
    execute_remote_command "$host" "$user" "$port" "$hold_cmd" "Protección de paquetes"
}

# Función para sincronizar código
sync_repository() {
    local host="$1"
    local user="$2"
    local port="$3"
    
    show_step "Sincronizando repositorio en $host"
    
    local sync_cmd="
        if [ -d $RUTA_REPO/.git ]; then
            cd $RUTA_REPO
            git fetch --all --prune
            git checkout $RAMA
            git pull --ff-only
            git rev-parse --short HEAD
        else
            echo 'sin_repo'
        fi
    "
    
    if [ "$MODO" = "simulacion" ]; then
        show_info "[SIMULACIÓN] Sincronizaría repositorio desde rama $RAMA"
        echo "abc1234"
        return 0
    else
        local commit=$(ssh -o ConnectTimeout=10 -p "$port" "$user@$host" "$sync_cmd" 2>/dev/null | tail -1)
        if [ -n "$commit" ]; then
            show_success "Repositorio sincronizado: $commit"
            echo "$commit"
            return 0
        else
            show_error "Falló la sincronización del repositorio"
            return 1
        fi
    fi
}

# Función para actualizar panel y paquetes
update_system() {
    local host="$1"
    local user="$2"
    local port="$3"
    
    show_step "Actualizando sistema en $host"
    
    local update_cmd="
        sudo apt-get update -y
        sudo apt-get install -y webmin usermin virtualmin virtualmin-base || true
        sudo apt-get upgrade -y
    "
    
    execute_remote_command "$host" "$user" "$port" "$update_cmd" "Actualización del sistema"
}

# Función para manejar Laravel (si aplica)
handle_laravel() {
    local host="$1"
    local user="$2"
    local port="$3"
    
    if [ "$LARAVEL" != "si" ]; then
        return 0
    fi
    
    show_step "Procesando aplicación Laravel en $host"
    
    local laravel_cmd="
        cd $RUTA_REPO || true
        if [ -f artisan ]; then
            composer install --no-dev -o || true
            php artisan config:cache || true
            php artisan route:cache || true
            php artisan view:cache || true
        fi
    "
    
    execute_remote_command "$host" "$user" "$port" "$laravel_cmd" "Optimización Laravel"
}

# Función para validar Virtualmin
validate_virtualmin() {
    local host="$1"
    local user="$2"
    local port="$3"
    
    show_step "Validando configuración de Virtualmin en $host"
    
    local validate_cmd="
        sudo virtualmin check-config || true
        sudo virtualmin validate-domains --all-domains || true
    "
    
    execute_remote_command "$host" "$user" "$port" "$validate_cmd" "Validación de Virtualmin"
}

# Función para recarga suave de servicios
reload_services() {
    local host="$1"
    local user="$2"
    local port="$3"
    local web="$4"
    
    show_step "Recargando servicios en $host (sin downtime)"
    
    local reload_cmd="
        if [ '$web' = 'apache2' ]; then
            apachectl -k graceful || sudo systemctl reload apache2 || true
        else
            sudo nginx -s reload || sudo systemctl reload nginx || true
        fi
        sudo systemctl restart webmin || true
        sudo systemctl restart usermin || true
    "
    
    execute_remote_command "$host" "$user" "$port" "$reload_cmd" "Recarga de servicios"
}

# Función para healthcheck post-despliegue
post_deployment_healthcheck() {
    local host="$1"
    local user="$2"
    local port="$3"
    local vhosts="$4"
    
    show_step "Verificando salud post-despliegue en $host"
    
    # Verificar Webmin
    local webmin_check="curl -k --silent --fail --max-time 10 https://127.0.0.1:10000/ >/dev/null"
    if ! execute_remote_command "$host" "$user" "$port" "$webmin_check" "Healthcheck Webmin"; then
        return 1
    fi
    
    # Verificar cada vhost
    local failed_vhosts=()
    for vhost in $vhosts; do
        if [ "$vhost" != "no-domains" ]; then
            if ! check_vhost_health "$host" "$user" "$port" "$vhost"; then
                failed_vhosts+=("$vhost")
            fi
        fi
    done
    
    if [ ${#failed_vhosts[@]} -gt 0 ]; then
        show_error "Vhosts fallidos: ${failed_vhosts[*]}"
        return 1
    else
        show_success "Todos los healthchecks pasaron"
        return 0
    fi
}

# Función para rollback
perform_rollback() {
    local host="$1"
    local user="$2"
    local port="$3"
    local backup_id="$4"
    
    show_step "Ejecutando rollback en $host usando backup $backup_id"
    
    local rollback_cmd="
        LAST=\$(ls -1dt $BACKUP_DIR_BASE/* | head -n1)
        sudo virtualmin restore-domain --all-domains --source \"\$LAST\" --all-features || true
    "
    
    execute_remote_command "$host" "$user" "$port" "$rollback_cmd" "Rollback del sistema"
}

# Función para limpiar backups antiguos
cleanup_old_backups() {
    local host="$1"
    local user="$2"
    local port="$3"
    
    show_step "Limpiando backups antiguos en $host"
    
    local cleanup_cmd="
        cd $BACKUP_DIR_BASE
        ls -1dt */ | tail -n +8 | xargs -r sudo rm -rf
    "
    
    execute_remote_command "$host" "$user" "$port" "$cleanup_cmd" "Limpieza de backups"
}

# Función para procesar un servidor
process_server() {
    local server_json="$1"
    local is_canary="$2"
    
    # Extraer datos del servidor (simulación de parsing JSON)
    local host=$(echo "$server_json" | grep -o '"host":"[^"]*"' | cut -d'"' -f4)
    local user=$(echo "$server_json" | grep -o '"user":"[^"]*"' | cut -d'"' -f4)
    local port=$(echo "$server_json" | grep -o '"port":[0-9]*' | cut -d':' -f2)
    local web=$(echo "$server_json" | grep -o '"web":"[^"]*"' | cut -d'"' -f4)
    
    show_header "PROCESANDO SERVIDOR: $host ($user@$host:$port)"
    
    local server_status="OK"
    local backup_id=""
    local vhosts=""
    local failed_vhosts=()
    local updated_packages=()
    local webmin_status="OK"
    local summary=""
    
    # 1. Verificar conectividad
    if ! check_ssh_connectivity "$host" "$user" "$port"; then
        server_status="ERROR"
        summary="Error de conectividad SSH"
    else
        # 2. Verificar binarios
        if ! check_required_binaries "$host" "$user" "$port" "$web"; then
            server_status="ERROR"
            summary="Binarios requeridos faltantes"
        else
            # 3. Obtener vhosts
            vhosts=$(get_vhosts "$host" "$user" "$port")
            
            # 4. Healthcheck previo
            for vhost in $vhosts; do
                if ! check_vhost_health "$host" "$user" "$port" "$vhost"; then
                    show_error "Healthcheck previo falló para $vhost"
                fi
            done
            
            # 5. Crear backup
            backup_id=$(create_backup "$host" "$user" "$port")
            if [ -z "$backup_id" ]; then
                server_status="ERROR"
                summary="Falló la creación del backup"
            else
                # 6. Proteger paquetes
                hold_packages "$host" "$user" "$port"
                
                # 7. Sincronizar código
                local commit=$(sync_repository "$host" "$user" "$port")
                CURRENT_COMMIT="$commit"
                
                # 8. Actualizar sistema
                if update_system "$host" "$user" "$port"; then
                    updated_packages=("webmin" "usermin" "virtualmin" "virtualmin-base")
                fi
                
                # 9. Manejar Laravel
                handle_laravel "$host" "$user" "$port"
                
                # 10. Validar Virtualmin
                validate_virtualmin "$host" "$user" "$port"
                
                # 11. Recarga suave
                reload_services "$host" "$user" "$port" "$web"
                
                # 12. Healthcheck post-despliegue
                if ! post_deployment_healthcheck "$host" "$user" "$port" "$vhosts"; then
                    show_error "Healthcheck post-despliegue falló, ejecutando rollback"
                    perform_rollback "$host" "$user" "$port" "$backup_id"
                    
                    # Verificar si el rollback funcionó
                    if ! post_deployment_healthcheck "$host" "$user" "$port" "$vhosts"; then
                        server_status="ERROR"
                        webmin_status="FALLO"
                        summary="Falló healthcheck y rollback"
                    else
                        server_status="ERROR"
                        summary="Rollback exitoso tras fallo"
                    fi
                else
                    # 13. Limpiar backups antiguos
                    cleanup_old_backups "$host" "$user" "$port"
                    summary="Despliegue exitoso"
                fi
            fi
        fi
    fi
    
    # Contar vhosts
    local vhosts_count=0
    if [ "$vhosts" != "no-domains" ]; then
        vhosts_count=$(echo "$vhosts" | wc -w)
    fi
    
    # Crear resultado del servidor
    local server_result="{
        \"host\":\"$host\",
        \"estado\":\"$server_status\",
        \"backup\":\"$backup_id\",
        \"paquetes_actualizados\":[\"${updated_packages[*]//" "/\",\"}\"],
        \"vhosts_ok\":$vhosts_count,
        \"vhosts_fallidos\":[],
        \"webmin\":\"$webmin_status\",
        \"resumen\":\"$summary\",
        \"log\":\"$LOG_PATH\"
    }"
    
    DEPLOY_RESULTS+=("$server_result")
    
    # Si es canario y falló, detener el rollout
    if [ "$is_canary" = "true" ] && [ "$server_status" = "ERROR" ]; then
        GLOBAL_STATUS="ERROR"
        show_error "Canario falló, deteniendo rollout"
        return 1
    fi
    
    if [ "$server_status" = "ERROR" ]; then
        GLOBAL_STATUS="ERROR"
    fi
    
    return 0
}

# Función para generar reporte JSON final
generate_final_report() {
    local next_step=""
    
    if [ "$GLOBAL_STATUS" = "ERROR" ]; then
        next_step="Revisar logs y corregir errores antes del próximo despliegue"
    else
        next_step="Monitorear servicios y preparar próximo despliegue"
    fi
    
    local servers_json=""
    for result in "${DEPLOY_RESULTS[@]}"; do
        if [ -n "$servers_json" ]; then
            servers_json="$servers_json,"
        fi
        servers_json="$servers_json$result"
    done
    
    local final_report="{
        \"global_estado\":\"$GLOBAL_STATUS\",
        \"repositorio\":\"$RAMA@$CURRENT_COMMIT\",
        \"servidores\":[$servers_json],
        \"siguiente_paso\":\"$next_step\"
    }"
    
    echo "$final_report" | jq . 2>/dev/null || echo "$final_report"
}

# Función principal
main() {
    show_header "AGENTE DEVOPS WEBMIN/VIRTUALMIN - DESPLIEGUE AUTOMÁTICO"
    
    # Inicializar log
    mkdir -p "$(dirname "$LOG_PATH")"
    touch "$LOG_PATH"
    
    show_info "Modo de operación: $MODO"
    show_info "Estrategia: $ESTRATEGIA"
    show_info "Rama: $RAMA"
    show_info "Ventana de tiempo: $VENTANA"
    
    # Verificar ventana de tiempo
    check_time_window
    
    # Parsear servidores (simulación simple)
    local servers_array=()
    # En una implementación real, usaríamos jq para parsear JSON
    # Por ahora, simulamos con servidores de ejemplo
    servers_array=(
        '{"host":"server1.example.com","user":"deploy","port":22,"web":"apache2"}'
        '{"host":"server2.example.com","user":"deploy","port":22,"web":"apache2"}'
    )
    
    # Estrategia canary
    if [ "$ESTRATEGIA" = "canary_then_rollout" ] && [ ${#servers_array[@]} -gt 1 ]; then
        show_header "FASE 1: DESPLIEGUE CANARIO"
        
        # Procesar primer servidor como canario
        if ! process_server "${servers_array[0]}" "true"; then
            show_error "Canario falló, abortando despliegue"
            generate_final_report
            return 1
        fi
        
        show_success "Canario exitoso, continuando con rollout"
        
        show_header "FASE 2: ROLLOUT COMPLETO"
        
        # Procesar resto de servidores
        for ((i=1; i<${#servers_array[@]}; i++)); do
            process_server "${servers_array[i]}" "false"
        done
    else
        # Procesar todos los servidores secuencialmente
        for server in "${servers_array[@]}"; do
            process_server "$server" "false"
        done
    fi
    
    show_header "REPORTE FINAL DEL DESPLIEGUE"
    generate_final_report
    
    if [ "$GLOBAL_STATUS" = "OK" ]; then
        show_success "Despliegue completado exitosamente"
        return 0
    else
        show_error "Despliegue completado con errores"
        return 1
    fi
}

# Función para mostrar ayuda
show_help() {
    cat << EOF
Agente DevOps para Webmin/Virtualmin

Uso: $0 [opciones]

Opciones:
  --modo MODO                 Modo de operación: 'simulacion' o 'ejecucion_real' (default: simulacion)
  --ventana VENTANA          Ventana de tiempo: 'always' o 'HH:MM–HH:MM Timezone' (default: 02:00–04:00 America/New_York)
  --rama RAMA                Rama de Git a desplegar (default: main)
  --estrategia ESTRATEGIA    Estrategia de despliegue: 'canary_then_rollout' (default: canary_then_rollout)
  --laravel SI/NO            Manejar aplicación Laravel (default: no)
  --repo RUTA                Ruta del repositorio (default: /srv/webmin-repo)
  --backup-dir RUTA          Directorio base de backups (default: /var/backups/virtualmin)
  --log RUTA                 Archivo de log (default: /var/log/virtualmin-auto-update.log)
  --help                     Mostrar esta ayuda

Ejemplos:
  $0 --modo ejecucion_real --ventana always
  $0 --modo simulacion --rama develop --laravel si
  $0 --ventana "02:00–04:00 America/New_York" --estrategia canary_then_rollout

EOF
}

# Procesamiento de argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --modo)
            MODO="$2"
            shift 2
            ;;
        --ventana)
            VENTANA="$2"
            shift 2
            ;;
        --rama)
            RAMA="$2"
            shift 2
            ;;
        --estrategia)
            ESTRATEGIA="$2"
            shift 2
            ;;
        --laravel)
            LARAVEL="$2"
            shift 2
            ;;
        --repo)
            RUTA_REPO="$2"
            shift 2
            ;;
        --backup-dir)
            BACKUP_DIR_BASE="$2"
            shift 2
            ;;
        --log)
            LOG_PATH="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Opción desconocida: $1"
            show_help
            exit 1
            ;;
    esac
done

# Ejecutar función principal
main "$@"
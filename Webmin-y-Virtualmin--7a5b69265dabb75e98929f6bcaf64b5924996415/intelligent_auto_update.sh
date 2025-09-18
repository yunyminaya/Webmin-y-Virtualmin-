#!/bin/bash

# ============================================================================
# 🤖 SISTEMA DE AUTO-ACTUALIZACIÓN INTELIGENTE DESDE GITHUB
# ============================================================================
# Sistema que se comunica con GitHub, detecta actualizaciones automáticamente
# Se actualiza solo, mantiene backups, se recupera de errores automáticamente
# Mantiene servidores virtuales funcionando 24/7 sin intervención humana
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Configuración del sistema inteligente
GITHUB_REPO="yunyminaya/Webmin-y-Virtualmin-"
GITHUB_API_URL="https://api.github.com/repos/${GITHUB_REPO}"
GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main"
LOCAL_REPO_DIR="/opt/auto_repair_system"
BACKUP_DIR="/backups/auto_updates"
LOG_FILE="/var/log/auto_update_system.log"
STATUS_FILE="/opt/auto_repair_system/update_status.json"
MONITORING_INTERVAL=3600  # 1 hora por defecto

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función de logging inteligente
intelligent_log() {
    local level="$1"
    local component="$2"
    local message="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Log principal
    echo "[$timestamp] [$level] [$component] $message" >> "$LOG_FILE"

    # Log del sistema
    logger -t "AUTO_UPDATE[$component]" "$level: $message"

    # Mostrar en pantalla solo si no es ejecución automática
    if [[ "${AUTO_MODE:-false}" != "true" ]]; then
        case "$level" in
            "CRITICAL") echo -e "${RED}[$component CRITICAL]${NC} $message" ;;
            "WARNING")  echo -e "${YELLOW}[$component WARNING]${NC} $message" ;;
            "INFO")     echo -e "${BLUE}[$component INFO]${NC} $message" ;;
            "SUCCESS")  echo -e "${GREEN}[$component SUCCESS]${NC} $message" ;;
            "UPDATE")   echo -e "${PURPLE}[$component UPDATE]${NC} $message" ;;
        esac
    fi
}

# Función para verificar conectividad con GitHub
check_github_connectivity() {
    if ! curl -s --connect-timeout 10 "$GITHUB_API_URL" >/dev/null; then
        intelligent_log "CRITICAL" "GITHUB" "No hay conectividad con GitHub"
        return 1
    fi
    intelligent_log "SUCCESS" "GITHUB" "Conectividad con GitHub OK"
    return 0
}

# Función para obtener información de la última versión de GitHub
get_latest_version_info() {
    local api_response
    api_response=$(curl -s "$GITHUB_API_URL/releases/latest" 2>/dev/null)

    if [[ -z "$api_response" ]] || echo "$api_response" | grep -q "Not Found"; then
        # Si no hay releases, obtener info del último commit
        api_response=$(curl -s "$GITHUB_API_URL/commits/main" 2>/dev/null)
        if [[ -z "$api_response" ]]; then
            intelligent_log "CRITICAL" "VERSION" "No se puede obtener información de versión de GitHub"
            return 1
        fi
        LATEST_COMMIT=$(echo "$api_response" | grep -o '"sha":"[^"]*"' | head -1 | cut -d'"' -f4)
        LATEST_DATE=$(echo "$api_response" | grep -o '"date":"[^"]*"' | head -1 | cut -d'"' -f4)
        LATEST_MESSAGE=$(echo "$api_response" | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4 | tr -d '\n')
    else
        LATEST_VERSION=$(echo "$api_response" | grep -o '"tag_name":"[^"]*"' | head -1 | cut -d'"' -f4)
        LATEST_COMMIT=$(echo "$api_response" | grep -o '"target_commitish":"[^"]*"' | head -1 | cut -d'"' -f4)
        LATEST_DATE=$(echo "$api_response" | grep -o '"published_at":"[^"]*"' | head -1 | cut -d'"' -f4)
        LATEST_MESSAGE=$(echo "$api_response" | grep -o '"body":"[^"]*"' | head -1 | cut -d'"' -f4 | tr -d '\n')
    fi

    intelligent_log "INFO" "VERSION" "Última versión detectada: ${LATEST_VERSION:-$LATEST_COMMIT}"
}

# Función para comparar versiones locales vs GitHub
compare_versions() {
    local local_version_file="$LOCAL_REPO_DIR/version.txt"
    local current_version=""

    # Obtener versión local
    if [[ -f "$local_version_file" ]]; then
        current_version=$(cat "$local_version_file")
    fi

    # Comparar versiones
    if [[ "$current_version" != "${LATEST_VERSION:-$LATEST_COMMIT}" ]]; then
        intelligent_log "UPDATE" "VERSION" "Nueva versión disponible: ${LATEST_VERSION:-$LATEST_COMMIT}"
        intelligent_log "UPDATE" "VERSION" "Versión actual: ${current_version:-Ninguna}"
        return 0  # Hay actualización disponible
    else
        intelligent_log "INFO" "VERSION" "Sistema está actualizado: $current_version"
        return 1  # No hay actualización
    fi
}

# Función para crear backup inteligente antes de actualizar
create_intelligent_backup() {
    local backup_timestamp
    backup_timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/backup_$backup_timestamp"

    intelligent_log "UPDATE" "BACKUP" "Creando backup inteligente antes de actualizar..."

    # Crear directorio de backup
    mkdir -p "$backup_path"

    # Backup de configuraciones críticas
    local critical_configs=(
        "/etc/apache2"
        "/etc/mysql"
        "/etc/webmin"
        "/etc/postfix"
        "/etc/dovecot"
        "/var/www"
        "/opt/auto_repair_system"
        "/root/auto_repair.sh"
        "/etc/systemd/system/auto-repair.service"
    )

    for config in "${critical_configs[@]}"; do
        if [[ -e "$config" ]]; then
            intelligent_log "INFO" "BACKUP" "Haciendo backup de: $config"
            cp -r "$config" "$backup_path/" 2>/dev/null || true
        fi
    done

    # Backup de bases de datos si existen
    if command -v mysqldump >/dev/null 2>&1; then
        intelligent_log "INFO" "BACKUP" "Haciendo backup de bases de datos..."
        mkdir -p "$backup_path/databases"
        mysql -e "SHOW DATABASES;" 2>/dev/null | grep -v Database | while read -r db; do
            if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]]; then
                mysqldump "$db" > "$backup_path/databases/${db}.sql" 2>/dev/null || true
            fi
        done
    fi

    # Crear archivo de información del backup
    cat > "$backup_path/backup_info.txt" << EOF
BACKUP AUTOMÁTICO - $backup_timestamp
Versión anterior: $(cat "$LOCAL_REPO_DIR/version.txt" 2>/dev/null || echo "Desconocida")
Nueva versión: ${LATEST_VERSION:-$LATEST_COMMIT}
Fecha: $(date)
Servidor: $(hostname)
EOF

    intelligent_log "SUCCESS" "BACKUP" "Backup creado exitosamente: $backup_path"

    # Limpiar backups antiguos (mantener solo los últimos 5)
    find "$BACKUP_DIR" -name "backup_*" -type d | sort | head -n -5 | xargs rm -rf 2>/dev/null || true
}

# Función para descargar e instalar actualización desde GitHub
download_and_install_update() {
    intelligent_log "UPDATE" "INSTALL" "Descargando e instalando actualización desde GitHub..."

    # Crear directorio temporal
    local temp_dir
    temp_dir=$(mktemp -d)
    local update_success=true

    # Lista de archivos críticos a actualizar
    local critical_files=(
        "scripts/autonomous_repair.sh"
        "scripts/auto_repair_complete.sh"
        "scripts/repair_apache_auto.sh"
        "install_autonomous_system.sh"
        "dashboard_autonomous.sh"
        "README_AUTONOMOUS_SYSTEM.md"
    )

    for file in "${critical_files[@]}"; do
        local remote_url="$GITHUB_RAW_URL/$file"
        local local_path="$LOCAL_REPO_DIR/$file"

        intelligent_log "INFO" "DOWNLOAD" "Descargando: $file"

        # Crear directorio si no existe
        mkdir -p "$(dirname "$local_path")"

        # Descargar archivo
        if curl -s "$remote_url" -o "$local_path" 2>/dev/null; then
            intelligent_log "SUCCESS" "DOWNLOAD" "Archivo descargado: $file"
        else
            intelligent_log "WARNING" "DOWNLOAD" "Error descargando: $file"
            update_success=false
        fi
    done

    # Actualizar versión local
    echo "${LATEST_VERSION:-$LATEST_COMMIT}" > "$LOCAL_REPO_DIR/version.txt"

    # Dar permisos de ejecución a scripts
    find "$LOCAL_REPO_DIR" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

    if [[ "$update_success" == true ]]; then
        intelligent_log "SUCCESS" "INSTALL" "Actualización descargada exitosamente"
        return 0
    else
        intelligent_log "WARNING" "INSTALL" "Actualización completada con algunos errores"
        return 1
    fi
}

# Función para aplicar actualización de manera inteligente
apply_intelligent_update() {
    intelligent_log "UPDATE" "APPLY" "Aplicando actualización de manera inteligente..."

    local apply_success=true

    # Detener servicios críticos temporalmente
    local critical_services=("apache2" "mysql" "mariadb" "webmin" "postfix" "dovecot")

    intelligent_log "INFO" "APPLY" "Deteniendo servicios críticos para actualización..."
    for service in "${critical_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            systemctl stop "$service" 2>/dev/null || true
            intelligent_log "INFO" "APPLY" "Servicio detenido: $service"
        fi
    done

    # Aplicar actualización del sistema autónomo
    if [[ -f "$LOCAL_REPO_DIR/scripts/autonomous_repair.sh" ]]; then
        intelligent_log "INFO" "APPLY" "Actualizando script autónomo principal..."

        # Backup del script actual
        cp "/root/autonomous_repair.sh" "/root/autonomous_repair.sh.backup.$(date +%s)" 2>/dev/null || true

        # Copiar nueva versión
        cp "$LOCAL_REPO_DIR/scripts/autonomous_repair.sh" "/root/autonomous_repair.sh"

        # Dar permisos
        chmod +x "/root/autonomous_repair.sh"

        intelligent_log "SUCCESS" "APPLY" "Script autónomo actualizado"
    fi

    # Reiniciar servicios críticos
    intelligent_log "INFO" "APPLY" "Reiniciando servicios críticos..."
    for service in "${critical_services[@]}"; do
        if systemctl list-units | grep -q "$service"; then
            systemctl start "$service" 2>/dev/null || true
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                intelligent_log "SUCCESS" "APPLY" "Servicio reiniciado: $service"
            else
                intelligent_log "WARNING" "APPLY" "Error reiniciando: $service"
                apply_success=false
            fi
        fi
    done

    # Reiniciar servicio de auto-reparación
    if systemctl restart auto-repair 2>/dev/null; then
        intelligent_log "SUCCESS" "APPLY" "Servicio de auto-reparación reiniciado"
    else
        intelligent_log "WARNING" "APPLY" "Error reiniciando servicio de auto-reparación"
        apply_success=false
    fi

    if [[ "$apply_success" == true ]]; then
        intelligent_log "SUCCESS" "APPLY" "Actualización aplicada exitosamente"
        return 0
    else
        intelligent_log "WARNING" "APPLY" "Actualización aplicada con algunos errores"
        return 1
    fi
}

# Función de recuperación automática en caso de fallo
automatic_recovery() {
    local recovery_type="$1"
    intelligent_log "CRITICAL" "RECOVERY" "Iniciando recuperación automática: $recovery_type"

    case "$recovery_type" in
        "update_failed")
            intelligent_log "INFO" "RECOVERY" "Restaurando desde backup por fallo de actualización..."

            # Buscar último backup válido
            local last_backup
            last_backup=$(find "$BACKUP_DIR" -name "backup_*" -type d | sort | tail -1)

            if [[ -n "$last_backup" ]]; then
                intelligent_log "INFO" "RECOVERY" "Restaurando backup: $last_backup"

                # Restaurar configuraciones críticas
                if [[ -d "$last_backup/etc" ]]; then
                    cp -r "$last_backup/etc/apache2" /etc/ 2>/dev/null || true
                    cp -r "$last_backup/etc/mysql" /etc/ 2>/dev/null || true
                    cp -r "$last_backup/etc/webmin" /etc/ 2>/dev/null || true
                fi

                # Restaurar script autónomo
                if [[ -f "$last_backup/root/auto_repair.sh" ]]; then
                    cp "$last_backup/root/auto_repair.sh" "/root/autonomous_repair.sh"
                    chmod +x "/root/autonomous_repair.sh"
                fi

                # Reiniciar servicios
                systemctl restart auto-repair 2>/dev/null || true
                systemctl restart apache2 2>/dev/null || true
                systemctl restart mysql 2>/dev/null || true
                systemctl restart webmin 2>/dev/null || true

                intelligent_log "SUCCESS" "RECOVERY" "Recuperación automática completada"
                return 0
            else
                intelligent_log "CRITICAL" "RECOVERY" "No se encontraron backups para recuperación"
                return 1
            fi
            ;;
        "service_critical")
            intelligent_log "INFO" "RECOVERY" "Recuperación de servicios críticos..."

            # Reinicio completo del sistema
            systemctl restart auto-repair 2>/dev/null || true

            # Verificar y reparar servicios esenciales
            local essential_services=("apache2" "mysql" "mariadb" "webmin")
            for service in "${essential_services[@]}"; do
                if ! systemctl is-active --quiet "$service" 2>/dev/null && systemctl list-units | grep -q "$service"; then
                    systemctl start "$service" 2>/dev/null || true
                fi
            done

            intelligent_log "SUCCESS" "RECOVERY" "Recuperación de servicios completada"
            return 0
            ;;
    esac
}

# Función de monitoreo inteligente del sistema
intelligent_system_monitoring() {
    intelligent_log "INFO" "MONITOR" "Iniciando monitoreo inteligente del sistema..."

    local system_issues=0
    local critical_issues=0

    # Monitoreo de servicios críticos
    local critical_services=("auto-repair" "apache2" "mysql" "mariadb" "webmin" "ssh" "ufw")

    for service in "${critical_services[@]}"; do
        if ! systemctl is-active --quiet "$service" 2>/dev/null && systemctl list-units | grep -q "$service"; then
            intelligent_log "CRITICAL" "MONITOR" "Servicio crítico caído: $service"
            systemctl start "$service" 2>/dev/null || intelligent_log "ERROR" "MONITOR" "No se pudo iniciar $service"
            ((critical_issues++))
        fi
    done

    # Monitoreo de recursos del sistema
    local mem_usage cpu_usage disk_usage
    mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}' 2>/dev/null || echo "0")
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' 2>/dev/null || echo "0")
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//' 2>/dev/null || echo "0")

    if [[ $mem_usage -gt 90 ]]; then
        intelligent_log "CRITICAL" "MONITOR" "Memoria crítica: ${mem_usage}%"
        sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
        ((system_issues++))
    fi

    if [[ $cpu_usage -gt 95 ]]; then
        intelligent_log "CRITICAL" "MONITOR" "CPU crítica: ${cpu_usage}%"
        ((system_issues++))
    fi

    if [[ $disk_usage -gt 95 ]]; then
        intelligent_log "CRITICAL" "MONITOR" "Disco crítico: ${disk_usage}%"
        ((system_issues++))
    fi

    # Monitoreo de conectividad con GitHub
    if ! check_github_connectivity; then
        ((system_issues++))
    fi

    # Actualizar estado del sistema
    local status_data
    status_data=$(cat << EOF
{
    "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')",
    "system_issues": $system_issues,
    "critical_issues": $critical_issues,
    "memory_usage": $mem_usage,
    "cpu_usage": $cpu_usage,
    "disk_usage": $disk_usage,
    "github_connectivity": $(check_github_connectivity && echo "true" || echo "false"),
    "last_update_check": "$(date '+%Y-%m-%d %H:%M:%S')",
    "current_version": "$(cat "$LOCAL_REPO_DIR/version.txt" 2>/dev/null || echo "unknown")"
}
EOF
    )
    echo "$status_data" > "$STATUS_FILE"

    # Recuperación automática si hay problemas críticos
    if [[ $critical_issues -gt 0 ]]; then
        automatic_recovery "service_critical"
    fi

    intelligent_log "INFO" "MONITOR" "Monitoreo completado: $system_issues problemas del sistema, $critical_issues problemas críticos"
}

# Función principal de auto-actualización inteligente
intelligent_auto_update() {
    intelligent_log "UPDATE" "MAIN" "=== INICIANDO SISTEMA DE AUTO-ACTUALIZACIÓN INTELIGENTE ==="

    # Verificar conectividad con GitHub
    if ! check_github_connectivity; then
        intelligent_log "CRITICAL" "MAIN" "Sin conectividad con GitHub - abortando actualización"
        return 1
    fi

    # Obtener información de versión
    get_latest_version_info

    # Verificar si hay actualizaciones
    if compare_versions; then
        intelligent_log "UPDATE" "MAIN" "Actualización disponible - iniciando proceso inteligente"

        # Crear backup inteligente
        create_intelligent_backup

        # Descargar actualización
        if download_and_install_update; then
            # Aplicar actualización
            if apply_intelligent_update; then
                intelligent_log "SUCCESS" "MAIN" "=== ACTUALIZACIÓN COMPLETADA EXITOSAMENTE ==="

                # Notificación de éxito
                echo "🎉 Sistema actualizado exitosamente a la versión: ${LATEST_VERSION:-$LATEST_COMMIT}" | mail -s "Auto-Update Success" root@localhost 2>/dev/null || true

                return 0
            else
                intelligent_log "CRITICAL" "MAIN" "Error aplicando actualización - iniciando recuperación"
                automatic_recovery "update_failed"
                return 1
            fi
        else
            intelligent_log "CRITICAL" "MAIN" "Error descargando actualización"
            return 1
        fi
    else
        intelligent_log "INFO" "MAIN" "Sistema está actualizado - no se requieren cambios"
        return 0
    fi
}

# Función para ejecutar como daemon inteligente
run_intelligent_daemon() {
    intelligent_log "INFO" "DAEMON" "Iniciando daemon inteligente de auto-actualización"

    while true; do
        # Monitoreo continuo del sistema
        intelligent_system_monitoring

        # Verificación de actualizaciones
        intelligent_auto_update

        # Esperar intervalo configurado
        intelligent_log "INFO" "DAEMON" "Esperando $MONITORING_INTERVAL segundos para siguiente ciclo..."
        sleep "$MONITORING_INTERVAL"
    done
}

# Función para instalación inicial del sistema inteligente
install_intelligent_system() {
    intelligent_log "INSTALL" "MAIN" "Instalando sistema de auto-actualización inteligente..."

    # Crear directorios necesarios
    mkdir -p "$LOCAL_REPO_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "/var/log"

    # Instalar dependencias necesarias
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y curl wget git jq 2>/dev/null || true
    fi

    # Crear servicio systemd para auto-actualización
    cat > /etc/systemd/system/auto-update.service << EOF
[Unit]
Description=Intelligent Auto-Update System
After=network.target auto-repair.service
Wants=network.target

[Service]
Type=simple
User=root
ExecStart=$LOCAL_REPO_DIR/intelligent_auto_update.sh daemon
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

    # Crear script de auto-actualización inteligente
    cat > "$LOCAL_REPO_DIR/intelligent_auto_update.sh" << 'EOF'
#!/bin/bash
# Script de auto-actualización inteligente - contenido se reemplaza automáticamente
echo "Sistema de auto-actualización inteligente"
EOF

    # Copiar este script a la ubicación correcta
    cp "$0" "$LOCAL_REPO_DIR/intelligent_auto_update.sh"
    chmod +x "$LOCAL_REPO_DIR/intelligent_auto_update.sh"

    # Crear configuración inicial
    cat > "$LOCAL_REPO_DIR/config.sh" << EOF
#!/bin/bash
# Configuración del sistema inteligente
MONITORING_INTERVAL=$MONITORING_INTERVAL
GITHUB_REPO=$GITHUB_REPO
LOCAL_REPO_DIR=$LOCAL_REPO_DIR
BACKUP_DIR=$BACKUP_DIR
LOG_FILE=$LOG_FILE
STATUS_FILE=$STATUS_FILE
EOF

    # Recargar systemd y habilitar servicio
    systemctl daemon-reload
    systemctl enable auto-update
    systemctl start auto-update

    # Crear versión inicial
    echo "initial_install" > "$LOCAL_REPO_DIR/version.txt"

    intelligent_log "SUCCESS" "INSTALL" "Sistema inteligente instalado correctamente"

    # Ejecutar primera actualización
    intelligent_auto_update
}

# Función para mostrar estado del sistema inteligente
show_intelligent_status() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         🤖 SISTEMA DE AUTO-ACTUALIZACIÓN INTELIGENTE          ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Estado del servicio
    echo -e "${BLUE}🔧 ESTADO DEL SISTEMA:${NC}"
    if systemctl is-active --quiet auto-update 2>/dev/null; then
        echo -e "${GREEN}   ✅ Sistema inteligente activo${NC}"
    else
        echo -e "${RED}   ❌ Sistema inteligente inactivo${NC}"
    fi

    if systemctl is-active --quiet auto-repair 2>/dev/null; then
        echo -e "${GREEN}   ✅ Sistema de auto-reparación activo${NC}"
    else
        echo -e "${RED}   ❌ Sistema de auto-reparación inactivo${NC}"
    fi

    # Estado de GitHub
    echo ""
    echo -e "${BLUE}🌐 CONECTIVIDAD GITHUB:${NC}"
    if check_github_connectivity; then
        echo -e "${GREEN}   ✅ Conectado a GitHub${NC}"
    else
        echo -e "${RED}   ❌ Sin conexión a GitHub${NC}"
    fi

    # Información de versión
    echo ""
    echo -e "${BLUE}📦 INFORMACIÓN DE VERSIÓN:${NC}"
    if [[ -f "$LOCAL_REPO_DIR/version.txt" ]]; then
        local current_version
        current_version=$(cat "$LOCAL_REPO_DIR/version.txt")
        echo "   📋 Versión actual: $current_version"
    else
        echo -e "${YELLOW}   ⚠️ Versión desconocida${NC}"
    fi

    # Estado del sistema
    if [[ -f "$STATUS_FILE" ]]; then
        echo ""
        echo -e "${BLUE}📊 ÚLTIMO ESTADO DEL SISTEMA:${NC}"
        local last_check
        last_check=$(grep -o '"last_update_check":"[^"]*"' "$STATUS_FILE" 2>/dev/null | cut -d'"' -f4 || echo "N/A")
        echo "   📅 Última verificación: $last_check"

        local system_issues
        system_issues=$(grep -o '"system_issues":[0-9]*' "$STATUS_FILE" 2>/dev/null | cut -d':' -f2 || echo "0")
        if [[ "$system_issues" -gt 0 ]]; then
            echo -e "   ⚠️ Problemas del sistema: ${RED}$system_issues${NC}"
        else
            echo -e "   ✅ Sistema saludable: ${GREEN}$system_issues problemas${NC}"
        fi
    fi

    # Últimos logs
    echo ""
    echo -e "${BLUE}📝 ÚLTIMOS LOGS:${NC}"
    if [[ -f "$LOG_FILE" ]]; then
        tail -5 "$LOG_FILE" | while read -r line; do
            if echo "$line" | grep -q "SUCCESS"; then
                echo -e "${GREEN}   $line${NC}"
            elif echo "$line" | grep -q "CRITICAL\|ERROR"; then
                echo -e "${RED}   $line${NC}"
            elif echo "$line" | grep -q "WARNING"; then
                echo -e "${YELLOW}   $line${NC}"
            else
                echo "   $line"
            fi
        done
    else
        echo -e "${YELLOW}   ⚠️ No hay logs disponibles${NC}"
    fi

    echo ""
    echo -e "${BLUE}🎮 ACCIONES DISPONIBLES:${NC}"
    echo "   1. 🔄 Verificar actualizaciones manualmente"
    echo "   2. 📊 Generar reporte del sistema"
    echo "   3. 🔧 Ejecutar recuperación manual"
    echo "   4. 📋 Ver configuración actual"
    echo "   5. 🛑 Detener sistema inteligente"
    echo "   6. ▶️ Reiniciar sistema inteligente"
    echo "   7. 📦 Forzar actualización desde GitHub"
    echo "   8. 🔍 Ver logs completos"
    echo "   9. 📁 Ver backups disponibles"
    echo "   0. 🚪 Salir"
    echo ""
}

# Procesar argumentos de línea de comandos
case "${1:-}" in
    "install")
        install_intelligent_system
        ;;
    "daemon")
        run_intelligent_daemon
        ;;
    "update")
        intelligent_auto_update
        ;;
    "monitor")
        intelligent_system_monitoring
        ;;
    "status")
        show_intelligent_status
        ;;
    "recovery")
        automatic_recovery "service_critical"
        ;;
    *)
        echo "Uso: $0 {install|daemon|update|monitor|status|recovery}"
        echo ""
        echo "Comandos:"
        echo "  install  - Instalar el sistema inteligente completo"
        echo "  daemon   - Ejecutar como servicio continuo"
        echo "  update   - Verificar y aplicar actualizaciones"
        echo "  monitor  - Ejecutar monitoreo del sistema"
        echo "  status   - Mostrar estado del sistema inteligente"
        echo "  recovery - Ejecutar recuperación automática"
        exit 1
        ;;
esac

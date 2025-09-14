#!/bin/bash

# =============================================================================
# SISTEMA DE VALIDACIÓN DE REPOSITORIO OFICIAL
# Solo acepta actualizaciones del repositorio oficial
# Bloquea actualizaciones de repositorios no autorizados
#
# Desarrollado por: Yuny Minaya
# =============================================================================

# Configuración del repositorio oficial
OFFICIAL_REPO_URL="https://github.com/yunyminaya/Webmin-y-Virtualmin-"
OFFICIAL_REPO_DOMAIN="github.com"
OFFICIAL_REPO_OWNER="yunyminaya"
OFFICIAL_REPO_NAME="Webmin-y-Virtualmin-"
OFFICIAL_REPO_BRANCH="main"

# Archivos de configuración
REPO_CONFIG_FILE="/opt/webmin-official/repo_validation.conf"
REPO_LOG_FILE="/var/log/webmin-repo-validation.log"
BLOCKED_UPDATES_LOG="/var/log/webmin-blocked-updates.log"

# Función de logging para validación de repositorio
repo_log() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [REPO:$level] $message" >> "$REPO_LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [REPO:$level] $message"
}

# Función para bloquear actualización no autorizada
block_update() {
    local source_url="$1"
    local reason="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    repo_log "BLOCKED" "ACTUALIZACIÓN BLOQUEADA - URL: $source_url - Razón: $reason"

    # Registrar en log de bloqueados
    echo "$timestamp|BLOQUEADO|$source_url|$reason" >> "$BLOCKED_UPDATES_LOG"

    # Enviar alerta si está configurado
    send_block_alert "$source_url" "$reason"

    return 1
}

# Función para validar URL de repositorio
validate_repository_url() {
    local repo_url="$1"

    repo_log "VALIDATE" "Validando URL de repositorio: $repo_url"

    # Verificar dominio oficial
    if ! echo "$repo_url" | grep -q "$OFFICIAL_REPO_DOMAIN"; then
        block_update "$repo_url" "Dominio no autorizado"
        return 1
    fi

    # Verificar propietario oficial
    if ! echo "$repo_url" | grep -q "$OFFICIAL_REPO_OWNER"; then
        block_update "$repo_url" "Propietario no autorizado"
        return 1
    fi

    # Verificar nombre de repositorio oficial
    if ! echo "$repo_url" | grep -q "$OFFICIAL_REPO_NAME"; then
        block_update "$repo_url" "Repositorio no autorizado"
        return 1
    fi

    repo_log "SUCCESS" "URL de repositorio validada correctamente: $repo_url"
    return 0
}

# Función para validar hash de commit
validate_commit_hash() {
    local commit_hash="$1"
    local repo_url="$2"

    repo_log "VALIDATE" "Validando hash de commit: $commit_hash"

    # Verificar formato del hash
    if ! echo "$commit_hash" | grep -qE "^[a-f0-9]{7,40}$"; then
        block_update "$repo_url" "Hash de commit inválido: $commit_hash"
        return 1
    fi

    # Verificar que el commit existe en el repositorio oficial
    if ! curl -s "https://api.github.com/repos/$OFFICIAL_REPO_OWNER/Webmin-y-Virtualmin-/commits/$commit_hash" >/dev/null 2>&1; then
        block_update "$repo_url" "Commit no existe en repositorio oficial: $commit_hash"
        return 1
    fi

    repo_log "SUCCESS" "Hash de commit validado: $commit_hash"
    return 0
}

# Función para validar archivo específico
validate_file() {
    local file_path="$1"
    local expected_hash="$2"
    local repo_url="$3"

    repo_log "VALIDATE" "Validando archivo: $file_path"

    # Verificar que el archivo existe
    if [[ ! -f "$file_path" ]]; then
        block_update "$repo_url" "Archivo no encontrado: $file_path"
        return 1
    fi

    # Calcular hash del archivo
    local actual_hash=""
    if command -v sha256sum >/dev/null 2>&1; then
        actual_hash=$(sha256sum "$file_path" 2>/dev/null | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        actual_hash=$(shasum -a 256 "$file_path" 2>/dev/null | awk '{print $1}')
    else
        block_update "$repo_url" "No se puede calcular hash - herramientas faltantes"
        return 1
    fi

    # Comparar hashes
    if [[ "$actual_hash" != "$expected_hash" ]]; then
        block_update "$repo_url" "Hash de archivo no coincide - Archivo: $file_path"
        return 1
    fi

    repo_log "SUCCESS" "Archivo validado correctamente: $file_path"
    return 0
}

# Función para validar actualización completa
validate_update() {
    local update_source="$1"
    local update_files="$2"

    repo_log "INFO" "=== VALIDANDO ACTUALIZACIÓN COMPLETA ==="
    repo_log "INFO" "Fuente: $update_source"
    repo_log "INFO" "Archivos: $update_files"

    # Validar URL del repositorio
    if ! validate_repository_url "$update_source"; then
        repo_log "CRITICAL" "ACTUALIZACIÓN RECHAZADA - Repositorio no autorizado"
        return 1
    fi

    # Validar cada archivo si se proporciona lista
    if [[ -n "$update_files" ]]; then
        while IFS= read -r file_info; do
            local file_path=$(echo "$file_info" | cut -d: -f1)
            local expected_hash=$(echo "$file_info" | cut -d: -f2)

            if ! validate_file "$file_path" "$expected_hash" "$update_source"; then
                repo_log "CRITICAL" "ACTUALIZACIÓN RECHAZADA - Archivo inválido: $file_path"
                return 1
            fi
        done <<< "$update_files"
    fi

    repo_log "SUCCESS" "ACTUALIZACIÓN VALIDADA Y APROBADA"
    return 0
}

# Función para verificar actualizaciones disponibles
check_official_updates() {
    repo_log "INFO" "Verificando actualizaciones oficiales..."

    # Obtener último commit del repositorio oficial
    local latest_commit=""
    local api_url="https://api.github.com/repos/$OFFICIAL_REPO_OWNER/Webmin-y-Virtualmin-/commits/$OFFICIAL_REPO_BRANCH"

    if command -v curl >/dev/null 2>&1; then
        latest_commit=$(curl -s "$api_url" 2>/dev/null | grep '"sha"' | head -1 | cut -d'"' -f4)
    elif command -v wget >/dev/null 2>&1; then
        latest_commit=$(wget -q -O- "$api_url" 2>/dev/null | grep '"sha"' | head -1 | cut -d'"' -f4)
    fi

    if [[ -z "$latest_commit" ]]; then
        repo_log "WARNING" "No se pudo obtener información de actualizaciones"
        return 1
    fi

    repo_log "INFO" "Último commit oficial: $latest_commit"

    # Comparar con commit local actual
    local current_commit=""
    if [[ -d ".git" ]]; then
        current_commit=$(git rev-parse HEAD 2>/dev/null)
    fi

    if [[ "$latest_commit" != "$current_commit" ]]; then
        repo_log "INFO" "Nueva actualización disponible: $latest_commit"
        return 0  # Hay actualización disponible
    else
        repo_log "INFO" "Sistema actualizado - Commit actual: $current_commit"
        return 1  # No hay actualización
    fi
}

# Función para aplicar actualización oficial
apply_official_update() {
    repo_log "INFO" "Aplicando actualización oficial..."

    # Verificar que estamos en un repositorio git
    if [[ ! -d ".git" ]]; then
        repo_log "ERROR" "No se encuentra repositorio git local"
        return 1
    fi

    # Obtener cambios del repositorio oficial
    if git fetch origin 2>/dev/null; then
        repo_log "SUCCESS" "Cambios obtenidos del repositorio oficial"
    else
        repo_log "ERROR" "Error al obtener cambios del repositorio oficial"
        return 1
    fi

    # Aplicar cambios
    if git pull origin "$OFFICIAL_REPO_BRANCH" 2>/dev/null; then
        repo_log "SUCCESS" "Actualización aplicada exitosamente"
        return 0
    else
        repo_log "ERROR" "Error al aplicar actualización"
        return 1
    fi
}

# Función para enviar alerta de bloqueo
send_block_alert() {
    local blocked_url="$1"
    local reason="$2"

    repo_log "ALERT" "Enviando alerta de actualización bloqueada"

    # Intentar enviar email si postfix está disponible
    if command -v mail >/dev/null 2>&1 && systemctl is-active --quiet postfix 2>/dev/null; then
        echo "ALERTA DE SEGURIDAD: Actualización Bloqueada

Una actualización desde un repositorio no autorizado fue bloqueada:

URL Bloqueada: $blocked_url
Razón: $reason
Timestamp: $(date)
Servidor: $(hostname)

Esta acción fue registrada en los logs de seguridad.
No se permite actualizaciones de repositorios no oficiales.

Atentamente,
Sistema de Validación de Repositorio Oficial" | mail -s "ALERTA: Actualización Bloqueada" root 2>/dev/null || true
    fi

    # También registrar en syslog
    logger -p local0.alert "Webmin Security: Blocked update from unauthorized repository: $blocked_url"
}

# Función para mostrar estado de validación
show_validation_status() {
    echo ""
    echo "=== ESTADO DE VALIDACIÓN DE REPOSITORIO ==="
    echo ""

    # Mostrar configuración oficial
    echo "Repositorio Oficial Configurado:"
    echo "  URL: $OFFICIAL_REPO_URL"
    echo "  Dominio: $OFFICIAL_REPO_DOMAIN"
    echo "  Propietario: $OFFICIAL_REPO_OWNER"
    echo "  Repositorio: $OFFICIAL_REPO_NAME"
    echo "  Rama: $OFFICIAL_REPO_BRANCH"
    echo ""

    # Verificar estado de actualizaciones
    if check_official_updates; then
        echo "✅ Actualización disponible"
    else
        echo "✅ Sistema actualizado"
    fi

    echo ""

    # Mostrar estadísticas de bloqueos
    if [[ -f "$BLOCKED_UPDATES_LOG" ]]; then
        local blocked_count=$(wc -l < "$BLOCKED_UPDATES_LOG")
        echo "Estadísticas de Seguridad:"
        echo "  Intentos de actualización bloqueados: $blocked_count"
        echo ""

        if [[ $blocked_count -gt 0 ]]; then
            echo "Últimos intentos bloqueados:"
            tail -5 "$BLOCKED_UPDATES_LOG" | while read -r line; do
                local timestamp=$(echo "$line" | cut -d'|' -f1)
                local url=$(echo "$line" | cut -d'|' -f3)
                local reason=$(echo "$line" | cut -d'|' -f4)
                echo "  ❌ $timestamp - $reason"
                echo "     URL: $url"
            done
        fi
    else
        echo "Estadísticas de Seguridad:"
        echo "  ✅ No hay intentos de actualización bloqueados"
    fi

    echo ""
}

# Función para crear configuración inicial
create_initial_config() {
    mkdir -p "$(dirname "$REPO_CONFIG_FILE")"

    cat > "$REPO_CONFIG_FILE" << EOF
# Configuración de Validación de Repositorio Oficial
# Generado automáticamente - NO MODIFICAR

OFFICIAL_REPO_URL="$OFFICIAL_REPO_URL"
OFFICIAL_REPO_DOMAIN="$OFFICIAL_REPO_DOMAIN"
OFFICIAL_REPO_OWNER="$OFFICIAL_REPO_OWNER"
OFFICIAL_REPO_NAME="$OFFICIAL_REPO_NAME"
OFFICIAL_REPO_BRANCH="$OFFICIAL_REPO_BRANCH"

VALIDATION_ENABLED="true"
AUTO_UPDATE_ENABLED="true"
ALERTS_ENABLED="true"

# Estadísticas
VALIDATION_COUNT="0"
BLOCKED_COUNT="0"
LAST_VALIDATION="$(date)"
EOF

    repo_log "SUCCESS" "Configuración inicial creada: $REPO_CONFIG_FILE"
}

# Función principal del sistema de validación
main_repo_validation() {
    # Crear configuración si no existe
    if [[ ! -f "$REPO_CONFIG_FILE" ]]; then
        create_initial_config
    fi

    # Verificar actualizaciones oficiales
    if check_official_updates; then
        repo_log "INFO" "Actualización oficial disponible"

        # Aplicar actualización si está habilitado
        if [[ "$(grep 'AUTO_UPDATE_ENABLED' "$REPO_CONFIG_FILE" | cut -d'"' -f2)" == "true" ]]; then
            apply_official_update
        else
            repo_log "INFO" "Auto-actualización deshabilitada"
        fi
    fi

    repo_log "SUCCESS" "Validación de repositorio completada"
}

# Procesar argumentos de línea de comandos
case "${1:-}" in
    validate)
        if [[ -n "$2" ]]; then
            validate_update "$2" "$3"
        else
            echo "Uso: $0 validate <url_repositorio> [archivos]"
            exit 1
        fi
        ;;
    status)
        show_validation_status
        ;;
    update)
        if check_official_updates; then
            apply_official_update
        else
            echo "Sistema ya actualizado"
        fi
        ;;
    check)
        if check_official_updates; then
            echo "Actualización disponible"
            exit 0
        else
            echo "Sistema actualizado"
            exit 1
        fi
        ;;
    *)
        # Ejecutar validación principal si no hay argumentos
        if [[ $# -eq 0 ]]; then
            main_repo_validation
        else
            echo "Uso: $0 {validate|status|update|check}"
            echo ""
            echo "Sistema de Validación de Repositorio Oficial"
            echo "Solo permite actualizaciones del repositorio oficial autorizado"
            exit 1
        fi
        ;;
esac

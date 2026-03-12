#!/bin/bash

# ============================================================================
# SISTEMA DE ACTUALIZACIÓN SEGURA - REPOSITORIO OFICIAL EXCLUSIVO
# ============================================================================
# Solo permite actualizaciones desde el repositorio oficial autorizado:
# https://github.com/yunyminaya/Webmin-y-Virtualmin-
#
# Bloquea cualquier intento de actualización desde fuentes no autorizadas
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== INCLUIR BIBLIOTECA COMÚN =====
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    source "${SCRIPT_DIR}/lib/common.sh"
else
    echo "ERROR: No se encuentra la biblioteca común en ${SCRIPT_DIR}/lib/common.sh"
    exit 1
fi

# ============================================================================
# CONFIGURACIÓN DE SEGURIDAD
# ============================================================================

# REPOSITORIO OFICIAL AUTORIZADO (ÚNICO PERMITIDO)
declare -r OFFICIAL_REPO_HTTPS="https://github.com/yunyminaya/Webmin-y-Virtualmin-.git"
declare -r OFFICIAL_REPO_SSH="git@github.com:yunyminaya/Webmin-y-Virtualmin-.git"
declare -r OFFICIAL_REPO_NAME="yunyminaya/Webmin-y-Virtualmin-"

# Archivos de configuración de seguridad
declare -r UPDATE_LOG="${SCRIPT_DIR}/logs/secure_updates.log"
declare -r SECURITY_LOCK="${SCRIPT_DIR}/.update_security_lock"

# ============================================================================
# FUNCIONES DE VERIFICACIÓN DE SEGURIDAD
# ============================================================================

# Función para verificar origen del repositorio
verify_repository_origin() {
    log_info "🔒 Verificando origen del repositorio..."

    # Verificar que estamos en un repositorio git
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        handle_error 200 "No se encuentra repositorio Git válido"
    fi

    # Obtener información de remotes
    local origin_url
    origin_url=$(git remote get-url origin 2>/dev/null || echo "")

    local upstream_url
    upstream_url=$(git remote get-url upstream 2>/dev/null || echo "")

    log_info "Remote origin: $origin_url"
    log_info "Remote upstream: $upstream_url"

    # Verificar que origin apunta al repositorio oficial
    if [[ "$origin_url" != "$OFFICIAL_REPO_HTTPS" && "$origin_url" != "$OFFICIAL_REPO_SSH" ]]; then
        log_error "🚨 ORIGEN NO AUTORIZADO DETECTADO"
        log_error "Origen actual: $origin_url"
        log_error "Origen autorizado: $OFFICIAL_REPO_HTTPS"
        handle_error 201 "Repositorio no autorizado - Solo se permiten actualizaciones desde $OFFICIAL_REPO_NAME"
    fi

    log_success "✅ Origen del repositorio verificado y autorizado"
    return 0
}

# Función para verificar integridad del repositorio
verify_repository_integrity() {
    log_info "🔍 Verificando integridad del repositorio..."

    # Verificar que tenemos acceso de lectura
    if ! git status >/dev/null 2>&1; then
        handle_error 202 "No se puede acceder al estado del repositorio"
    fi

    # Verificar que no hay cambios locales que puedan comprometer la actualización
    local git_status
    git_status=$(git status --porcelain 2>/dev/null || echo "")

    if [[ -n "$git_status" ]]; then
        log_warning "⚠️ Se detectaron cambios locales:"
        echo "$git_status"

        if ! confirm_action "¿Deseas continuar con la actualización? Los cambios locales podrían perderse"; then
            log_info "Actualización cancelada por el usuario"
            exit 0
        fi
    fi

    log_success "✅ Integridad del repositorio verificada"
    return 0
}

# Función para validar firma de commits (si están disponibles)
verify_commit_signatures() {
    log_info "🔐 Verificando firmas de commits..."

    # Verificar el último commit
    local latest_commit
    latest_commit=$(git rev-parse HEAD 2>/dev/null || echo "")

    if [[ -n "$latest_commit" ]]; then
        local commit_info
        commit_info=$(git show --format="%H %s %an <%ae>" --no-patch "$latest_commit" 2>/dev/null || echo "")
        log_info "Último commit: $commit_info"

        # Verificar si hay verificación GPG disponible
        if git verify-commit "$latest_commit" >/dev/null 2>&1; then
            log_success "✅ Firma GPG verificada para el último commit"
        else
            log_info "ℹ️ No hay firma GPG para verificar (opcional)"
        fi
    fi

    return 0
}

# Función para crear backup antes de actualizar
create_update_backup() {
    log_info "💾 Creando backup antes de la actualización..."

    local backup_dir="${SCRIPT_DIR}/backups/pre_update_$(date +%Y%m%d_%H%M%S)"

    if ensure_directory "$backup_dir"; then
        # Backup de archivos críticos
        local critical_files=(
            "auto_repair.sh"
            "instalar_todo.sh"
            "lib/common.sh"
            "configs/"
            "logs/"
        )

        for item in "${critical_files[@]}"; do
            if [[ -e "${SCRIPT_DIR}/${item}" ]]; then
                cp -r "${SCRIPT_DIR}/${item}" "$backup_dir/" 2>/dev/null || true
                log_debug "Backup creado: $item"
            fi
        done

        log_success "✅ Backup creado en: $backup_dir"
        echo "$backup_dir" > "${SCRIPT_DIR}/.last_backup_path"
    else
        log_warning "⚠️ No se pudo crear backup - continuando sin backup"
    fi

    return 0
}

# ============================================================================
# FUNCIÓN PRINCIPAL DE ACTUALIZACIÓN SEGURA
# ============================================================================

perform_secure_update() {
    log_info "🚀 Iniciando actualización segura desde repositorio oficial..."

    # Verificar conectividad con el repositorio oficial
    log_info "🌐 Verificando conectividad con repositorio oficial..."

    if ! git ls-remote --heads origin >/dev/null 2>&1; then
        handle_error 203 "No se puede conectar con el repositorio oficial"
    fi

    log_success "✅ Conectividad con repositorio oficial verificada"

    # Obtener información de actualizaciones disponibles
    log_info "📥 Obteniendo información de actualizaciones..."

    git fetch origin 2>/dev/null || {
        handle_error 204 "Error al obtener información del repositorio oficial"
    }

    # Verificar si hay actualizaciones disponibles
    local local_commit
    local_commit=$(git rev-parse HEAD 2>/dev/null || echo "")

    local remote_commit
    remote_commit=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null || echo "")

    if [[ "$local_commit" == "$remote_commit" ]]; then
        log_success "✅ El sistema está actualizado a la última versión"
        log_info "Commit actual: ${local_commit:0:8}"
        return 0
    fi

    log_info "📋 Actualizaciones disponibles:"
    log_info "Commit local:  ${local_commit:0:8}"
    log_info "Commit remoto: ${remote_commit:0:8}"

    # Mostrar cambios que se van a aplicar
    log_info "📝 Cambios que se aplicarán:"
    git log --oneline "${local_commit}..${remote_commit}" 2>/dev/null || true

    # Confirmar actualización
    if ! confirm_action "¿Deseas aplicar estas actualizaciones desde el repositorio oficial?"; then
        log_info "Actualización cancelada por el usuario"
        exit 0
    fi

    # Crear backup antes de actualizar
    create_update_backup

    # Aplicar actualización
    log_info "⬇️ Aplicando actualización desde repositorio oficial..."

    if git pull origin main 2>/dev/null || git pull origin master 2>/dev/null; then
        log_success "✅ Actualización aplicada correctamente"

        # Verificar integridad después de la actualización
        verify_repository_integrity

        # Registrar actualización exitosa
        local update_time
        update_time=$(get_timestamp)
        echo "[$update_time] Actualización exitosa desde $OFFICIAL_REPO_NAME - Commit: ${remote_commit:0:8}" >> "$UPDATE_LOG"

        # Ejecutar auto-reparación después de la actualización
        if [[ -f "${SCRIPT_DIR}/auto_repair.sh" ]]; then
            log_info "🔧 Ejecutando auto-reparación después de la actualización..."
            bash "${SCRIPT_DIR}/auto_repair.sh" || log_warning "Auto-reparación completada con advertencias"
        fi

        log_success "🎉 ¡Actualización completada exitosamente!"
        return 0
    else
        handle_error 205 "Error al aplicar la actualización"
    fi
}

# ============================================================================
# FUNCIÓN DE BLOQUEO DE ACTUALIZACIONES NO AUTORIZADAS
# ============================================================================

block_unauthorized_updates() {
    log_info "🛡️ Configurando bloqueo de actualizaciones no autorizadas..."

    # Crear archivo de bloqueo de seguridad
    cat > "$SECURITY_LOCK" << EOF
# BLOQUEO DE SEGURIDAD - NO ELIMINAR
# Este archivo protege contra actualizaciones no autorizadas
OFFICIAL_REPO_ONLY="$OFFICIAL_REPO_HTTPS"
LOCK_CREATED="$(get_timestamp)"
SECURITY_LEVEL="MAXIMUM"
EOF

    # Configurar hooks de git para verificar origen (si es posible)
    local git_hooks_dir="${SCRIPT_DIR}/.git/hooks"
    if [[ -d "$git_hooks_dir" ]]; then
        # Hook pre-push para verificar destino
        cat > "${git_hooks_dir}/pre-push" << 'EOF'
#!/bin/bash
# Hook de seguridad - Solo permite push al repositorio oficial

OFFICIAL_REPO="https://github.com/yunyminaya/Webmin-y-Virtualmin-.git"

while read local_ref local_sha remote_ref remote_sha; do
    if [[ "$2" != "$OFFICIAL_REPO" && "$2" != "git@github.com:yunyminaya/Webmin-y-Virtualmin-.git" ]]; then
        echo "🚨 ERROR: Solo se permite push al repositorio oficial"
        echo "Repositorio autorizado: $OFFICIAL_REPO"
        echo "Intento de push a: $2"
        exit 1
    fi
done
EOF
        chmod +x "${git_hooks_dir}/pre-push" 2>/dev/null || true
        log_success "✅ Hook de seguridad configurado"
    fi

    log_success "✅ Bloqueo de seguridad activado"
}

# ============================================================================
# FUNCIÓN PARA MOSTRAR ESTADO DE SEGURIDAD
# ============================================================================

show_security_status() {
    log_info "🔒 Estado de Seguridad del Sistema de Actualizaciones"
    echo
    echo "📍 Repositorio Oficial Autorizado:"
    echo "   $OFFICIAL_REPO_HTTPS"
    echo

    echo "🔍 Verificaciones de Seguridad:"

    # Verificar origen
    local origin_url
    origin_url=$(git remote get-url origin 2>/dev/null || echo "No configurado")

    if [[ "$origin_url" == "$OFFICIAL_REPO_HTTPS" || "$origin_url" == "$OFFICIAL_REPO_SSH" ]]; then
        echo "   ✅ Origen del repositorio: AUTORIZADO"
    else
        echo "   ❌ Origen del repositorio: NO AUTORIZADO"
    fi

    # Verificar archivo de bloqueo
    if [[ -f "$SECURITY_LOCK" ]]; then
        echo "   ✅ Bloqueo de seguridad: ACTIVO"
    else
        echo "   ⚠️ Bloqueo de seguridad: INACTIVO"
    fi

    # Mostrar última actualización
    if [[ -f "$UPDATE_LOG" ]]; then
        echo "   📅 Última actualización:"
        tail -1 "$UPDATE_LOG" 2>/dev/null | sed 's/^/      /' || echo "      No hay registro"
    fi

    echo
    echo "🛡️ Solo se permiten actualizaciones desde el repositorio oficial autorizado"
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    log_info "🔒 SISTEMA DE ACTUALIZACIÓN SEGURA - REPOSITORIO OFICIAL EXCLUSIVO"
    log_info "Repositorio autorizado: $OFFICIAL_REPO_NAME"
    echo

    # Verificar que estamos en el directorio correcto
    if [[ ! -f "${SCRIPT_DIR}/auto_repair.sh" ]]; then
        handle_error 199 "No se encuentra en el directorio del proyecto Webmin/Virtualmin"
    fi

    case "${1:-update}" in
        "update"|"")
            verify_repository_origin
            verify_repository_integrity
            verify_commit_signatures
            perform_secure_update
            ;;
        "status")
            show_security_status
            ;;
        "secure")
            verify_repository_origin
            block_unauthorized_updates
            log_success "🔒 Sistema de seguridad configurado"
            ;;
        "help"|"-h"|"--help")
            echo "Uso: $0 [opción]"
            echo
            echo "Opciones:"
            echo "  update    Actualizar desde repositorio oficial (por defecto)"
            echo "  status    Mostrar estado de seguridad"
            echo "  secure    Configurar bloqueos de seguridad"
            echo "  help      Mostrar esta ayuda"
            echo
            echo "Repositorio oficial autorizado:"
            echo "  $OFFICIAL_REPO_HTTPS"
            ;;
        *)
            handle_error 198 "Opción no válida: $1. Usa 'help' para ver opciones disponibles"
            ;;
    esac
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
#!/bin/bash
################################################################################
# auto_update_from_github.sh - Auto-actualización automática desde GitHub
#
# Se instala en cada servidor y:
# 1. Revisa cada 5 minutos si hay cambios nuevos en GitHub
# 2. Si hay cambios, los descarga y aplica automáticamente
# 3. Instala scripts, módulos CGI, configs, todo
#
# Instalación:
#   curl -sL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/auto_update_from_github.sh | bash
#
# O manual:
#   ./auto_update_from_github.sh --install
################################################################################

set -euo pipefail

REPO_URL="https://github.com/yunyminaya/Webmin-y-Virtualmin-.git"
BRANCH="main"
INSTALL_DIR="/opt/openvm-update"
LOG="/var/log/openvm-auto-update.log"
STATE_FILE="/opt/openvm-update/.last-commit"
WEBMIN_DIR="/usr/share/webmin"
VSERVER_DIR="/usr/share/webmin/virtual-server"
CRON_MARKER="# OPENVM-AUTO-UPDATE"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

# ============================================================
# MODO INSTALACIÓN
# ============================================================
install_auto_update() {
    log "=== INSTALANDO AUTO-UPDATE DESDE GITHUB ==="
    
    # Crear directorio
    mkdir -p "$INSTALL_DIR"
    
    # Clonar repo si no existe
    if [[ ! -d "$INSTALL_DIR/.git" ]]; then
        git clone --depth 1 -b "$BRANCH" "$REPO_URL" "$INSTALL_DIR" 2>&1 | tee -a "$LOG"
    fi
    
    # Guardar commit actual
    cd "$INSTALL_DIR"
    git rev-parse HEAD > "$STATE_FILE"
    
    # Copiar este script a /usr/local/bin
    cp "$INSTALL_DIR/auto_update_from_github.sh" /usr/local/bin/openvm-auto-update 2>/dev/null || true
    chmod +x /usr/local/bin/openvm-auto-update
    
    # Instalar cron job (cada 5 minutos)
    if ! crontab -l 2>/dev/null | grep -q "openvm-auto-update"; then
        (crontab -l 2>/dev/null; echo "$CRON_MARKER"; echo "*/5 * * * * /usr/local/bin/openvm-auto-update --check 2>&1 | tee -a $LOG") | crontab -
    fi
    
    # Primera ejecución - aplicar todo
    apply_update
    
    log "=== AUTO-UPDATE INSTALADO ==="
    log "Se ejecutará cada 5 minutos automáticamente"
    log "Para forzar actualización: openvm-auto-update --force"
}

# ============================================================
# APLICAR ACTUALIZACIÓN
# ============================================================
apply_update() {
    cd "$INSTALL_DIR"
    
    local CURRENT_COMMIT
    CURRENT_COMMIT=$(cat "$STATE_FILE" 2>/dev/null || echo "none")
    
    log "Commit actual: $CURRENT_COMMIT"
    log "Commit nuevo: $(git rev-parse HEAD)"
    
    # === COPIAR SCRIPTS A /usr/local/bin ===
    for script in auto_restore_universal.sh auto_backup_github.sh migrate_to_virtualmin.sh; do
        if [[ -f "$INSTALL_DIR/$script" ]]; then
            local target_name
            target_name=$(echo "$script" | sed 's/\.sh$//; s/_/-/g')
            install -o root -g root -m 0755 "$INSTALL_DIR/$script" "/usr/local/bin/$target_name"
            log "  Script: $target_name instalado"
        fi
    done
    
    # === COPIAR MÓDULOS OPENVM A WEBMIN ===
    for module_dir in "$INSTALL_DIR"/openvm-*/; do
        [[ -d "$module_dir" ]] || continue
        local module_name
        module_name=$(basename "$module_dir")
        
        # Copiar CGI scripts
        for cgi in "$module_dir"/*.cgi; do
            [[ -f "$cgi" ]] || continue
            install -o root -g root -m 0755 "$cgi" "$WEBMIN_DIR/$module_name/" 2>/dev/null || true
        done
        
        # Copiar lib.pl
        for lib in "$module_dir"/*.pl; do
            [[ -f "$lib" ]] || continue
            install -o root -g root -m 0644 "$lib" "$WEBMIN_DIR/$module_name/" 2>/dev/null || true
        done
        
        # Copiar configs
        for conf in "$module_dir"/config "$module_dir"/module.info; do
            [[ -f "$conf" ]] || continue
            install -o root -g root -m 0644 "$conf" "$WEBMIN_DIR/$module_name/" 2>/dev/null || true
        done
        
        log "  Módulo: $module_name actualizado"
    done
    
    # === COPIAR ARCHIVOS PRO A VIRTUALMIN ===
    if [[ -d "$INSTALL_DIR/virtualmin-gpl-master/pro" ]]; then
        for f in "$INSTALL_DIR"/virtualmin-gpl-master/pro/*.cgi "$INSTALL_DIR"/virtualmin-gpl-master/pro/*.pl; do
            [[ -f "$f" ]] || continue
            install -o root -g root -m 0755 "$f" "$VSERVER_DIR/" 2>/dev/null || true
        done
        log "  Archivos pro actualizados"
    fi
    
    # === COPIAR LIBRERÍAS PRINCIPALES ===
    for lib in "$INSTALL_DIR"/virtualmin-gpl-master/*.pl "$INSTALL_DIR"/virtualmin-gpl-master/*.lib; do
        [[ -f "$lib" ]] || continue
        install -o root -g root -m 0644 "$lib" "$VSERVER_DIR/" 2>/dev/null || true
    done
    
    # === COPIAR TEMA AUTHENTIC ===
    if [[ -d "$INSTALL_DIR/authentic-theme-master" ]]; then
        for f in "$INSTALL_DIR"/authentic-theme-master/*.pl "$INSTALL_DIR"/authentic-theme-master/*.cgi; do
            [[ -f "$f" ]] || continue
            install -o root -g root -m 0755 "$f" "$WEBMIN_DIR/authentic-theme/" 2>/dev/null || true
        done
        log "  Tema authentic actualizado"
    fi
    
    # === RELOAD WEBMIN ===
    systemctl reload webmin 2>/dev/null || /etc/webmin/restart 2>/dev/null || true
    
    # Guardar nuevo commit
    git rev-parse HEAD > "$STATE_FILE"
    
    log "=== ACTUALIZACIÓN APLICADA EXITOSAMENTE ==="
}

# ============================================================
# MODO CHECK (ejecutado por cron)
# ============================================================
check_and_update() {
    [[ ! -d "$INSTALL_DIR/.git" ]] && { log "ERROR: No instalado. Ejecutar con --install"; exit 1; }
    
    cd "$INSTALL_DIR"
    
    # Guardar commit actual
    local OLD_COMMIT
    OLD_COMMIT=$(git rev-parse HEAD)
    
    # Hacer pull
    git fetch --depth 1 origin "$BRANCH" 2>&1 | tee -a "$LOG"
    git reset --hard "origin/$BRANCH" 2>&1 | tee -a "$LOG"
    
    local NEW_COMMIT
    NEW_COMMIT=$(git rev-parse HEAD)
    
    if [[ "$OLD_COMMIT" != "$NEW_COMMIT" ]]; then
        log "=== NUEVA ACTUALIZACIÓN DETECTADA ==="
        log "De: $OLD_COMMIT"
        log "A:   $NEW_COMMIT"
        
        # Mostrar qué cambió
        git log --oneline "$OLD_COMMIT..$NEW_COMMIT" 2>/dev/null | tee -a "$LOG"
        
        # Aplicar
        apply_update
    else
        # Silencioso si no hay cambios (no loguear cada 5 min)
        :
    fi
}

# ============================================================
# MODO FORCE
# ============================================================
force_update() {
    log "=== FORZANDO ACTUALIZACIÓN ==="
    cd "$INSTALL_DIR" 2>/dev/null || { log "No instalado. Ejecutar con --install"; exit 1; }
    git fetch --depth 1 origin "$BRANCH" 2>&1 | tee -a "$LOG"
    git reset --hard "origin/$BRANCH" 2>&1 | tee -a "$LOG"
    apply_update
}

# ============================================================
# MODO STATUS
# ============================================================
show_status() {
    echo "=== OPENVM AUTO-UPDATE STATUS ==="
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        cd "$INSTALL_DIR"
        echo "  Instalado: SÍ"
        echo "  Repo: $REPO_URL"
        echo "  Branch: $BRANCH"
        echo "  Commit actual: $(git rev-parse --short HEAD)"
        echo "  Último commit: $(git log -1 --oneline)"
        echo "  Último update: $(stat -c '%y' "$STATE_FILE" 2>/dev/null || stat -f '%Sm' "$STATE_FILE" 2>/dev/null)"
        echo "  Cron instalado: $(crontab -l 2>/dev/null | grep -c 'openvm-auto-update') jobs"
    else
        echo "  Instalado: NO"
        echo "  Para instalar: $0 --install"
    fi
}

# ============================================================
# MAIN
# ============================================================
case "${1:-}" in
    --install)  install_auto_update ;;
    --check)    check_and_update ;;
    --force)    force_update ;;
    --status)   show_status ;;
    --uninstall)
        crontab -l 2>/dev/null | grep -v "openvm-auto-update" | grep -v "$CRON_MARKER" | crontab -
        rm -rf "$INSTALL_DIR"
        rm -f /usr/local/bin/openvm-auto-update
        echo "Auto-update desinstalado"
        ;;
    *)
        echo "Uso: $0 {--install|--check|--force|--status|--uninstall}"
        echo ""
        echo "  --install    Instalar auto-update (primera vez)"
        echo "  --check      Verificar si hay actualizaciones (cron)"
        echo "  --force      Forzar actualización ahora"
        echo "  --status     Mostrar estado actual"
        echo "  --uninstall  Desinstalar auto-update"
        ;;
esac

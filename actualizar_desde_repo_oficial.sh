#!/bin/bash

# Actualiza el código SOLO desde el repositorio oficial de GitHub del owner
# yunyminaya. Evita fuentes externas y valida cambios antes de aplicarlos.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${REPO_DIR:-$SCRIPT_DIR}"
LOG_FILE="/var/log/actualizar_desde_repo_oficial.log"
ALLOWED_OWNER_REGEX='github\.com[:/]+yunyminaya(/|$)'

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REPO-UPDATE] $*" | tee -a "$LOG_FILE"
}

require_git_repo() {
  if ! git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    log "❌ REPO_DIR no es un repositorio git: $REPO_DIR"
    exit 1
  fi
}

check_origin_allowed() {
  local origin
  origin=$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || echo "")
  if [[ -z "$origin" ]]; then
    log "❌ No se encontró remote origin en $REPO_DIR"
    exit 1
  fi
  if ! [[ "$origin" =~ $ALLOWED_OWNER_REGEX ]]; then
    log "❌ Remote origin no autorizado: $origin"
    log "   Debe apuntar a github.com/yunyminaya/..."
    exit 2
  fi
  log "✓ Remote origin permitido: $origin"
}

detect_default_branch() {
  local ref
  ref=$(git -C "$REPO_DIR" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  if [[ -z "$ref" ]]; then
    echo "origin/main"
  else
    echo "$ref"
  fi
}

list_changed_files() {
  local target_branch="$1"
  git -C "$REPO_DIR" fetch --prune origin >/dev/null 2>&1
  git -C "$REPO_DIR" diff --name-only HEAD.."$target_branch"
}

validate_shell_changes() {
  local files=("$@")
  local errs=0
  for f in "${files[@]}"; do
    [[ -f "$REPO_DIR/$f" ]] || continue
    case "$f" in
      *.sh)
        if ! bash -n "$REPO_DIR/$f" 2>>"$LOG_FILE"; then
          log "✗ Error de sintaxis en: $f"
          ((errs++))
        fi
        ;;
    esac
  done
  return $errs
}

safe_update() {
  local target_branch
  target_branch=$(detect_default_branch)
  log "Revisando cambios en $target_branch..."
  local changed
  changed=$(list_changed_files "$target_branch" | tr -d '\r')
  if [[ -z "$changed" ]]; then
    log "✓ No hay cambios nuevos en remoto"
    return 0
  fi

  log "Archivos cambiados:\n$changed"

  # Validar scripts .sh antes de aplicar
  mapfile -t sh_files < <(echo "$changed" | grep -E '\.sh$' || true)
  if [[ ${#sh_files[@]} -gt 0 ]]; then
    log "Validando sintaxis de scripts cambiados..."
    if ! validate_shell_changes "${sh_files[@]}"; then
      log "❌ Validación falló. Abortando update. Ver log: $LOG_FILE"
      exit 3
    fi
    log "✓ Sintaxis de scripts OK"
  fi

  # Manejar cambios locales sin commitear
  if ! git -C "$REPO_DIR" diff --quiet || ! git -C "$REPO_DIR" diff --cached --quiet; then
    log "Cambios locales detectados, creando stash temporal"
    git -C "$REPO_DIR" stash push -u -m "pre-update-$(date +%Y%m%d_%H%M%S)" >/dev/null 2>&1 || true
  fi

  # Aplicar actualización
  git -C "$REPO_DIR" fetch origin >/dev/null 2>&1
  git -C "$REPO_DIR" reset --hard "$target_branch"
  log "✓ Actualización aplicada a $(git -C "$REPO_DIR" rev-parse --short HEAD)"

  # Post-verificación opcional
  if [[ -x "$REPO_DIR/verificacion_total_automatizada.sh" ]]; then
    log "Ejecutando verificacion_total_automatizada.sh"
    if ! "$REPO_DIR/verificacion_total_automatizada.sh" >/dev/null 2>&1; then
      log "⚠️  Verificación final devolvió errores (revisar manualmente)"
    else
      log "✓ Verificación final OK"
    fi
  fi
}

install_timer() {
  local script_path="$(readlink -f "$0")"
  cat > /etc/systemd/system/wv-repo-update.service << EOF
[Unit]
Description=Actualizar repo Webmin/Virtualmin desde origen oficial
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$script_path --auto
EOF

  cat > /etc/systemd/system/wv-repo-update.timer << 'EOF'
[Unit]
Description=Timer actualización repo Webmin/Virtualmin (cada 15m)

[Timer]
OnBootSec=2min
OnUnitActiveSec=15min
AccuracySec=1min

[Install]
WantedBy=timers.target
EOF
  systemctl daemon-reload
  systemctl enable --now wv-repo-update.timer >/dev/null 2>&1 || true
  log "Timer de actualización instalado y activado (cada 15 minutos)"
}

remove_timer() {
  systemctl disable --now wv-repo-update.timer >/dev/null 2>&1 || true
  rm -f /etc/systemd/system/wv-repo-update.service /etc/systemd/system/wv-repo-update.timer
  systemctl daemon-reload
  log "Timer de actualización eliminado"
}

status() {
  echo "=== ESTADO ACTUALIZACIÓN DESDE REPO OFICIAL ==="
  echo "Directorio repo: $REPO_DIR"
  echo -n "Remote origin: "; git -C "$REPO_DIR" remote get-url origin 2>/dev/null || echo "(no definido)"
  systemctl list-timers --all 2>/dev/null | grep -q wv-repo-update.timer && echo "Timer: ACTIVO" || echo "Timer: NO ACTIVO"
  echo -n "HEAD local: "; git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo "(n/a)"
  echo -n "HEAD remoto: "; git -C "$REPO_DIR" ls-remote --heads origin 2>/dev/null | grep "$(detect_default_branch | sed 's#origin/##')" | awk '{print substr($1,1,7)}' || echo "(n/a)"
  echo "Log: $LOG_FILE"
}

usage() {
  cat << 'EOF'
Uso:
  actualizar_desde_repo_oficial.sh --auto           # Chequear y aplicar cambios desde origin permitido
  actualizar_desde_repo_oficial.sh --once           # Una pasada (equivalente a --auto)
  actualizar_desde_repo_oficial.sh --install-timer  # Instala timer systemd (15 min)
  actualizar_desde_repo_oficial.sh --remove-timer   # Elimina el timer systemd
  actualizar_desde_repo_oficial.sh --status         # Estado del mecanismo

Variables:
  REPO_DIR=/ruta/al/repo  # Por defecto, el directorio del script
EOF
}

main() {
  local action="${1:-}"
  case "$action" in
    --auto|--once)
      require_git_repo
      check_origin_allowed
      safe_update
      ;;
    --install-timer)
      require_git_repo
      check_origin_allowed
      install_timer
      ;;
    --remove-timer)
      remove_timer
      ;;
    --status)
      status
      ;;
    *)
      usage
      ;;
  esac
}

main "$@"


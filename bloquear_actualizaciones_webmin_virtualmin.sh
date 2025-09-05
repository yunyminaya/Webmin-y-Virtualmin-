#!/bin/bash

# Bloquear actualizaciones y cambios de configuración de Webmin/Virtualmin
# Objetivo: que Webmin y Virtualmin sean independientes de actualizaciones
# que puedan modificar su seguridad o funciones, manteniendo control total.

set -Eeuo pipefail
IFS=$'\n\t'

LOG_FILE="/var/log/webmin_virtualmin_lock.log"
PREF_FILE="/etc/apt/preferences.d/hold-webmin-virtualmin.pref"
KEEP_CONF_FILE="/etc/apt/apt.conf.d/99webmin-virtualmin-keepconf"
BASELINE_DIR="/var/lib/webmin/security_baseline"
BASELINE_SUMS="$BASELINE_DIR/checksums.sha256"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WMIN-VMIN-LOCK] $*" | tee -a "$LOG_FILE"
}

require_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "Este script requiere privilegios de root" >&2
    exit 1
  fi
}

get_installed_packages() {
  dpkg -l 2>/dev/null | awk '/^ii/ && ($2 ~ /^(webmin|virtualmin|usermin)/) {print $2}' | sort -u
}

ensure_dirs() {
  mkdir -p "$(dirname "$LOG_FILE")" "$BASELINE_DIR"
}

write_apt_preferences() {
  cat > "$PREF_FILE" << 'EOF'
# Mantener Webmin/Virtualmin sin actualizar salvo intervención manual
Package: webmin*
Pin: release *
Pin-Priority: -1

Package: virtualmin*
Pin: release *
Pin-Priority: -1

Package: usermin*
Pin: release *
Pin-Priority: -1
EOF
  log "Preferencias APT escritas en $PREF_FILE"
}

write_keepconf_options() {
  cat > "$KEEP_CONF_FILE" << 'EOF'
// Conservar configuraciones locales en actualizaciones de paquetes
DPkg::Options {
  "--force-confdef";
  "--force-confold";
};
EOF
  log "Política de conservar conffiles escrita en $KEEP_CONF_FILE"
}

hold_packages() {
  local pkgs=("$@")
  if [ ${#pkgs[@]} -eq 0 ]; then
    pkgs=($(get_installed_packages))
  fi
  if [ ${#pkgs[@]} -eq 0 ]; then
    log "No se detectaron paquetes webmin/virtualmin instalados"
    return 0
  fi
  log "Aplicando hold a: ${pkgs[*]}"
  apt-mark hold "${pkgs[@]}" >/dev/null
}

unhold_packages() {
  local pkgs=("$@")
  if [ ${#pkgs[@]} -eq 0 ]; then
    pkgs=($(get_installed_packages))
  fi
  if [ ${#pkgs[@]} -eq 0 ]; then
    log "No se detectaron paquetes webmin/virtualmin instalados"
    return 0
  fi
  log "Quitando hold de: ${pkgs[*]}"
  apt-mark unhold "${pkgs[@]}" >/dev/null
}

snapshot_baseline() {
  local files=(
    /etc/webmin/miniserv.conf
    /etc/webmin/config
    /etc/webmin/webmin.acl
  )
  if [ -d /etc/webmin/virtual-server ]; then
    while IFS= read -r f; do files+=("$f"); done < <(find /etc/webmin/virtual-server -type f 2>/dev/null | sort)
  fi
  mkdir -p "$BASELINE_DIR"
  : > "$BASELINE_SUMS"
  local any=0
  for f in "${files[@]}"; do
    if [ -f "$f" ]; then
      sha256sum "$f" >> "$BASELINE_SUMS"
      any=1
    fi
  done
  if [ "$any" -eq 1 ]; then
    log "Baseline de seguridad actualizado: $BASELINE_SUMS"
  else
    log "Aviso: no se encontraron archivos de configuración para baselínea"
  fi
}

verify_baseline() {
  if [ ! -s "$BASELINE_SUMS" ]; then
    log "No existe baselínea. Cree una con --snapshot"
    return 2
  fi
  local tmp="$(mktemp)"; cp "$BASELINE_SUMS" "$tmp"
  # Recalcular sumas existentes, ignorando archivos que ya no están
  local exitcode=0
  while IFS= read -r line; do
    local sum="${line%% *}"
    local path="${line#* }"; path="${path#* }"  # maneja posibles espacios
    if [ -f "$path" ]; then
      local now
      now=$(sha256sum "$path" | awk '{print $1}')
      if [ "$now" != "$sum" ]; then
        log "CAMBIO detectado en: $path"
        exitcode=1
      fi
    else
      log "Archivo faltante (ignorado en verificación): $path"
    fi
  done < "$tmp"
  rm -f "$tmp"
  if [ "$exitcode" -eq 0 ]; then
    log "Verificación OK: sin cambios inesperados"
  fi
  return "$exitcode"
}

install_guard_timer() {
  local script_path="$(readlink -f "$0")"
  cat > /etc/systemd/system/webmin-virtualmin-guard.service << EOF
[Unit]
Description=Guard verificación cambios Webmin/Virtualmin

[Service]
Type=oneshot
ExecStart=$script_path --verify
EOF

  cat > /etc/systemd/system/webmin-virtualmin-guard.timer << 'EOF'
[Unit]
Description=Programar guard Webmin/Virtualmin (cada 12h)

[Timer]
OnBootSec=10min
OnUnitActiveSec=12h
AccuracySec=5min

[Install]
WantedBy=timers.target
EOF
  systemctl daemon-reload
  systemctl enable --now webmin-virtualmin-guard.timer >/dev/null 2>&1 || true
  log "Guard de verificación instalado y activado"
}

remove_guard_timer() {
  systemctl disable --now webmin-virtualmin-guard.timer >/dev/null 2>&1 || true
  rm -f /etc/systemd/system/webmin-virtualmin-guard.timer /etc/systemd/system/webmin-virtualmin-guard.service
  systemctl daemon-reload
  log "Guard de verificación desinstalado"
}

status_report() {
  echo "=== ESTADO BLOQUEO WEBMIN/VIRTUALMIN ==="
  echo "Preferencias APT: $([ -f "$PREF_FILE" ] && echo 'PRESENTE' || echo 'NO')"
  echo "Conservar conffiles: $([ -f "$KEEP_CONF_FILE" ] && echo 'PRESENTE' || echo 'NO')"
  echo "Paquetes en hold:"; apt-mark showhold | grep -E '^(webmin|virtualmin|usermin)' || echo "(ninguno)"
  echo "Baseline: $([ -s "$BASELINE_SUMS" ] && echo "PRESENTE ($BASELINE_SUMS)" || echo 'NO')"
  systemctl list-timers --all 2>/dev/null | grep -q "webmin-virtualmin-guard.timer" && echo "Guard timer: ACTIVO" || echo "Guard timer: NO ACTIVO"
}

usage() {
  cat << 'EOF'
Uso:
  bloquear_actualizaciones_webmin_virtualmin.sh --lock       # Bloquear actualizaciones (hold + pin + keepconf)
  bloquear_actualizaciones_webmin_virtualmin.sh --unlock     # Permitir actualizaciones nuevamente
  bloquear_actualizaciones_webmin_virtualmin.sh --snapshot   # Guardar baseline de configs críticas
  bloquear_actualizaciones_webmin_virtualmin.sh --verify     # Verificar que no haya cambios inesperados
  bloquear_actualizaciones_webmin_virtualmin.sh --install-guard  # Instalar verificación periódica (systemd timer)
  bloquear_actualizaciones_webmin_virtualmin.sh --remove-guard   # Quitar verificación periódica
  bloquear_actualizaciones_webmin_virtualmin.sh --status     # Ver estado actual
EOF
}

main() {
  require_root
  ensure_dirs
  local action="${1:-}"
  case "$action" in
    --lock)
      write_apt_preferences
      write_keepconf_options
      hold_packages
      snapshot_baseline || true
      log "Bloqueo aplicado (hold + pin + keepconf)."
      ;;
    --unlock)
      unhold_packages || true
      rm -f "$PREF_FILE" "$KEEP_CONF_FILE"
      systemctl daemon-reload 2>/dev/null || true
      log "Bloqueo retirado (unhold + sin pin + sin keepconf)."
      ;;
    --snapshot)
      snapshot_baseline
      ;;
    --verify)
      verify_baseline
      ;;
    --install-guard)
      install_guard_timer
      ;;
    --remove-guard)
      remove_guard_timer
      ;;
    --status)
      status_report
      ;;
    *)
      usage
      ;;
  esac
}

main "$@"


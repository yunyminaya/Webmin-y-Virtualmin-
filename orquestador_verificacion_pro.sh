#!/bin/bash
# Orquestador de Verificación PRO (Webmin + Virtualmin)
# Uso:
#   sudo bash orquestador_verificacion_pro.sh            # Verifica todo sin cambios
#
# Consolida verificadores existentes y añade comprobaciones directas de servicios,
# puertos, firewall, Webmin/Virtualmin y calidad de scripts. Devuelve código !=0 si hay errores.

set -euo pipefail

# Colores / Log
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
log() { local L="$1"; shift; echo -e "${L}[$(date '+%F %T')] $*${NC}"; }
info(){ log "${BLUE}" "$*"; }
ok()  { log "${GREEN}" "$*"; }
warn(){ log "${YELLOW}" "$*"; }
err() { log "${RED}" "$*"; }

# Estado
ERR_COUNT=0
WARN_COUNT=0

# Reporte
TS="$(date +%Y%m%d_%H%M%S)"
mkdir -p reportes 2>/dev/null || true
REPORT="reportes/reporte_verificacion_pro_${TS}.md"

# Opciones
ALLOW_NONROOT=0
for a in "$@"; do
  case "$a" in
    --best-effort) ALLOW_NONROOT=1 ;;
  esac
done

# Detección de plataforma
OS="$(uname -s 2>/dev/null || echo Unknown)"
IS_LINUX=0
[[ "$OS" == "Linux" ]] && IS_LINUX=1

require_root() {
  if [[ "${ALLOW_NONROOT:-0}" -eq 1 && "${EUID:-$(id -u)}" -ne 0 ]]; then
    warn "Ejecución sin root (best-effort). Algunas comprobaciones se omitirán."
    return 0
  fi
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "Se requieren privilegios de root. Usa: sudo $0"
    exit 1
  fi
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

append_md() { echo -e "$*" >> "$REPORT"; }

write_header() {
  cat > "$REPORT" <<EOF
# ✅ Reporte Verificación PRO (Webmin + Virtualmin)
Fecha: $(date)
Host: $(hostname -f 2>/dev/null || hostname)

Este reporte consolida verificaciones automáticas y estado en vivo del servidor.

EOF
}

run_script_if_present() {
  local script="$1"; local name="$2"
  append_md "\n## ${name}\n"
  if [[ -x "./$script" ]]; then
    info "Ejecutando $name ..."
    if "./$script" | tee -a "$REPORT"; then
      ok "$name OK"
    else
      warn "$name reportó advertencias/errores"
      ((WARN_COUNT++)) || true
    fi
  elif [[ -f "./$script" ]]; then
    chmod +x "./$script" || true
    info "Ejecutando $name ..."
    if "./$script" | tee -a "$REPORT"; then
      ok "$name OK"
    else
      warn "$name reportó advertencias/errores"
      ((WARN_COUNT++)) || true
    fi
  else
    warn "No se encontró $name ($script)"
    append_md "- No encontrado: \`$script\`"
    ((WARN_COUNT++)) || true
  fi
}

run_cmd_check() {
  local title="$1"; shift
  append_md "\n## ${title}\n"
  append_md "Comando: \`$*\`\n"
  append_md "\n\`\`\`\n"

  # Evitar error si no se pasó comando
  if [[ $# -eq 0 ]]; then
    append_md "(sin comando)\n"
    append_md "\n\`\`\`\n"
    warn "${title} - SIN COMANDO"
    return 0
  fi

  # Ejecutar comando capturando salida
  local cmd=("$@")
  if "${cmd[@]}" >> "$REPORT" 2>&1; then
    append_md "\n\`\`\`\n"
    ok "${title}"
  else
    append_md "\n\`\`\`\n"
    err "${title} - ERROR"
    ((ERR_COUNT++)) || true
  fi
}

check_services() {
  append_md "\n## Estado de servicios críticos\n"
  local svcs=( webmin apache2 nginx postfix dovecot fail2ban clamav-daemon clamav-freshclam spamassassin opendkim mysql mariadb )
  local any_fail=0
  for s in "${svcs[@]}"; do
    if have_cmd systemctl && systemctl list-unit-files | grep -q "^${s}\.service"; then
      if systemctl is-active --quiet "$s" 2>/dev/null; then
        append_md "- ${s}: ACTIVE"
      else
        append_md "- ${s}: INACTIVE"
        any_fail=1
      fi
    fi
  done
  if [[ $any_fail -eq 1 ]]; then
    warn "Algún servicio crítico está INACTIVO"
    ((ERR_COUNT++)) || true
  else
    ok "Servicios críticos activos"
  fi
}

check_ports() {
  append_md "\n## Puertos de paneles y correo (escucha)\n"
  local patterns=':10000|:20000|:25 |:587 |:465 |:993 |:995 |:80 |:443 '
  if have_cmd ss; then
    append_md "Fuente: ss -tln\n\n\`\`\`\n"
    ss -tln | egrep "$patterns" >> "$REPORT" 2>&1 || true
    append_md "\n\`\`\`\n"
  elif have_cmd netstat; then
    local os="$(uname -s 2>/dev/null || echo Unknown)"
    if [[ "$os" == "Darwin" ]]; then
      append_md "Fuente: netstat -anv (Darwin)\n\n\`\`\`\n"
      netstat -anv | egrep '\.(10000|20000|25|587|465|993|995|80|443)\b.*(LISTEN|UDP)' >> "$REPORT" 2>&1 || true
      append_md "\n\`\`\`\n"
    else
      append_md "Fuente: netstat -tln\n\n\`\`\`\n"
      netstat -tln 2>/dev/null | egrep ":(10000|20000|25|587|465|993|995|80|443)\b" >> "$REPORT" 2>&1 || true
      append_md "\n\`\`\`\n"
    fi
  elif have_cmd lsof; then
    append_md "Fuente: lsof -nPiTCP -sTCP:LISTEN\n\n\`\`\`\n"
    lsof -nPiTCP -sTCP:LISTEN | egrep ":(10000|20000|25|587|465|993|995|80|443)\b" >> "$REPORT" 2>&1 || true
    append_md "\n\`\`\`\n"
  else
    append_md "- No se encontró ss/netstat/lsof\n"
    ((WARN_COUNT++)) || true
  fi
}

check_ufw() {
  append_md "\n## UFW (Firewall)\n"
  if have_cmd ufw; then
    append_md "\n\`\`\`\n"
    ufw status | sed -n '1,120p' >> "$REPORT" 2>&1 || true
    append_md "\n\`\`\`\n"
    ok "Estado UFW capturado"
  else
    append_md "- UFW no instalado\n"
    warn "UFW no instalado"
    ((WARN_COUNT++)) || true
  fi
}

check_webmin_config() {
  append_md "\n## Configuración Webmin\n"
  if [[ -d /etc/webmin ]]; then
    local theme="NO"
    local ssl="NO"
    grep -q '^theme=authentic-theme' /etc/webmin/config 2>/dev/null && theme="SI"
    grep -q '^ssl=1' /etc/webmin/miniserv.conf 2>/dev/null && ssl="SI"
    append_md "- Authentic Theme por defecto: ${theme}\n"
    append_md "- SSL habilitado: ${ssl}\n"
    if [[ "$theme" != "SI" || "$ssl" != "SI" ]]; then
      warn "Webmin no cumple totalmente (theme/ssl)"
      [[ "${IS_LINUX:-0}" -eq 1 ]] && ((ERR_COUNT++)) || true
    else
      ok "Webmin con theme y SSL correctos"
    fi
  else
    append_md "- /etc/webmin no encontrado\n"
    ((WARN_COUNT++)) || true
  fi
}

check_postfix_integrations() {
  append_md "\n## Postfix (DKIM/SPF)\n"
  if have_cmd postconf; then
    local sm=$(postconf -h smtpd_milters 2>/dev/null || true)
    local nsm=$(postconf -h non_smtpd_milters 2>/dev/null || true)
    local srs=$(postconf -h smtpd_recipient_restrictions 2>/dev/null || true)
    append_md "- smtpd_milters: ${sm}\n"
    append_md "- non_smtpd_milters: ${nsm}\n"
    append_md "- smtpd_recipient_restrictions: ${srs}\n"
    local dkim_ok=0; local spf_ok=0
    [[ "$sm" =~ 127.0.0.1:8891 ]] || [[ "$nsm" =~ 127.0.0.1:8891 ]] && dkim_ok=1
    [[ "$srs" =~ policyd-spf ]] && spf_ok=1
    if [[ $dkim_ok -eq 1 && $spf_ok -eq 1 ]]; then
      ok "Integraciones DKIM/SPF presentes"
    else
      warn "Integraciones DKIM/SPF incompletas"
      [[ "${IS_LINUX:-0}" -eq 1 ]] && ((ERR_COUNT++)) || true
    fi
  else
    append_md "- postconf no disponible\n"
    ((WARN_COUNT++)) || true
  fi
}

check_scripts_quality() {
  append_md "\n## Calidad de scripts (.sh)\n"
  local SYNTAX_ERRORS="$(mktemp -t shlint.XXXXXX)"
  local found=0; local failed=0
  while IFS= read -r -d '' f; do
    found=1
    if bash -n "$f" 2>>"$SYNTAX_ERRORS"; then
      :
    else
      echo "$f" >> "$SYNTAX_ERRORS"
      failed=1
    fi
  done < <(find . -type f -name "*.sh" -print0)

  if [[ $found -eq 0 ]]; then
    append_md "- No se encontraron scripts .sh\n"
  elif [[ $failed -eq 1 ]]; then
    append_md "- Errores de sintaxis detectados:\n\n\`\`\`\n"
    cat "$SYNTAX_ERRORS" >> "$REPORT"
    append_md "\n\`\`\`\n"
    err "Errores de sintaxis en scripts"
    ((ERR_COUNT++)) || true
  else
    append_md "- Sin errores de sintaxis en scripts\n"
    ok "Scripts válidos (bash -n)"
  fi

  if have_cmd shellcheck; then
    append_md "\n### ShellCheck (resumen)\n\n\`\`\`\n"
    shellcheck -S warning -x $(git ls-files "*.sh" 2>/dev/null || echo) >> "$REPORT" 2>&1 || true
    append_md "\n\`\`\`\n"
  fi
}

check_duplicates() {
  append_md "\n## Posibles duplicados (contenido)\n"
  if have_cmd fdupes; then
    local DUP="$(mktemp -t dup.XXXXXX)"
    if fdupes -r . >"$DUP" 2>/dev/null; then
      if [[ -s "$DUP" ]]; then
        append_md "Se detectaron archivos con contenido duplicado:\n\n\`\`\`\n"
        cat "$DUP" >> "$REPORT"
        append_md "\n\`\`\`\n"
        warn "Duplicados detectados"
        ((WARN_COUNT++)) || true
      else
        append_md "- Sin duplicados por contenido\n"
        ok "Sin duplicados"
      fi
    fi
  else
    append_md "- fdupes no instalado; saltando\n"
  fi
}

main() {
  require_root
  write_header

  info "Iniciando verificación consolidada (reporte: $REPORT)"

  # Ejecutar verificadores del proyecto (si existen)
  run_script_if_present "verificar_instalacion_un_comando.sh" "Verificar Instalación Un Comando"
  run_script_if_present "verificar_funciones_pro_completas.sh" "Verificar Funciones PRO Completas"
  run_script_if_present "verificar_funciones_pro_nativas.sh" "Verificar Funciones PRO Nativas"
  run_script_if_present "verificar_seguridad_webmin_virtualmin.sh" "Verificar Seguridad Webmin/Virtualmin"
  run_script_if_present "verificar_seguridad_completa.sh" "Verificar Seguridad Completa"
  run_script_if_present "verificador_servicios.sh" "Verificador de Servicios"
  run_script_if_present "verificar_sistema_pro.sh" "Verificar Sistema PRO"
  run_script_if_present "verificacion_completa_funciones.sh" "Verificación Completa de Funciones"

  # Comprobaciones directas
  check_services
  check_ports
  check_ufw
  check_webmin_config
  check_postfix_integrations
  check_scripts_quality
  check_duplicates

  # Resumen
  append_md "\n# Resumen Final\n"
  append_md "- Advertencias: ${WARN_COUNT}\n"
  append_md "- Errores: ${ERR_COUNT}\n"
  if [[ ${ERR_COUNT} -eq 0 ]]; then
    ok "Verificación completada: SIN ERRORES"
    echo "Reporte: $REPORT"
    exit 0
  else
    err "Verificación completada con ERRORES (${ERR_COUNT})"
    echo "Reporte: $REPORT"
    exit 1
  fi
}

main "$@"

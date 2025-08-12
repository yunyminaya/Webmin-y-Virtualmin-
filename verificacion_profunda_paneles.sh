#!/bin/bash
# Verificación Profunda de Webmin y Virtualmin (no deja fuera ninguna función clave)
# - Requiere Linux (Ubuntu/Debian) y privilegios root
# - Crea reporte detallado en reportes/reporte_profundo_paneles_*.md
# - No destructivo: solo lectura y validaciones

set -Eeuo pipefail
IFS=$'\n\t'

# Colores / Log
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'
log() { local L="$1"; shift; echo -e "${L}[$(date '+%F %T')] $*${NC}"; }
info(){ log "${BLUE}" "$*"; }
ok()  { log "${GREEN}" "$*"; }
warn(){ log "${YELLOW}" "$*"; }
err() { log "${RED}" "$*"; }

# Estado
ERR_COUNT=0
WARN_COUNT=0
PASS_COUNT=0
SECTION_ERR=0

# Helpers
have_cmd(){ command -v "$1" >/dev/null 2>&1; }
incr_pass(){ ((PASS_COUNT++)) || true; }
incr_warn(){ ((WARN_COUNT++)) || true; }
incr_err(){  ((ERR_COUNT++))  || true; ((SECTION_ERR++)) || true; }

# Reporte
TS="$(date +%Y%m%d_%H%M%S)"
mkdir -p reportes 2>/dev/null || true
REPORT="reportes/reporte_profundo_paneles_${TS}.md"
append_md(){ echo -e "$*" >> "$REPORT"; }
OS="$(uname -s 2>/dev/null || echo Unknown)"
IS_LINUX=0
[[ "$OS" == "Linux" ]] && IS_LINUX=1

# Opciones
ALLOW_NONROOT=0
for arg in "$@"; do
  case "$arg" in
    --best-effort) ALLOW_NONROOT=1 ;;
  esac
done

require_root() {
  if [[ "${ALLOW_NONROOT:-0}" -eq 1 || "${IS_LINUX:-0}" -ne 1 ]]; then
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
      warn "Ejecución sin root (best-effort/portable). Algunas comprobaciones pueden omitirse."
      return 0
    fi
  fi
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "Se requieren privilegios de root. Usa: sudo $0"
    exit 1
  fi
}

write_header() {
  cat > "$REPORT" <<EOF
# 🔍 Verificación Profunda Webmin/Virtualmin
Fecha: $(date)
Host: $(hostname -f 2>/dev/null || hostname)

Este informe realiza validaciones profundas de:
- Núcleo Webmin y configuración SSL/Miniserv
- Núcleo Virtualmin y características
- Servicios HTTP/HTTPS, PHP
- Pila de correo (Postfix, Dovecot, DKIM, SPF)
- Seguridad (UFW/Fail2ban)
- Bases de datos (MySQL/MariaDB y PostgreSQL)
- DNS (Bind9/named)
- Usermin
EOF
}

hr() { append_md "\n---\n"; }

section_start() {
  SECTION_ERR=0
  append_md "\n## $1\n"
}

section_end() {
  if [[ $SECTION_ERR -eq 0 ]]; then
    ok "Sección OK"
  else
    warn "Sección con $SECTION_ERR error(es)/advertencia(s)"
  fi
}

md_cmd() {
  append_md "\nComando: \`$*\`\n\`\`\`\n"
  "$@" >> "$REPORT" 2>&1 || true
  append_md "\n\`\`\`\n"
}

check_webmin_core() {
  section_start "Webmin - Núcleo y configuración"
  local cfg="/etc/webmin/miniserv.conf"
  if systemctl is-active --quiet webmin 2>/dev/null; then
    append_md "- Servicio Webmin: ACTIVO"
    incr_pass
  else
    append_md "- Servicio Webmin: INACTIVO"
    [[ "${IS_LINUX:-0}" -eq 1 ]] && incr_err || incr_warn
  fi

  # Puerto
  if have_cmd ss; then
    if ss -tln 2>/dev/null | grep -Eq ':(10000)\b'; then
      append_md "- Puerto 10000 en escucha: SI"
      incr_pass
    else
      append_md "- Puerto 10000 en escucha: NO"
      [[ "${IS_LINUX:-0}" -eq 1 ]] && incr_err || incr_warn
    fi
  elif have_cmd netstat; then
    local os="$(uname -s 2>/dev/null || echo Unknown)"
    if [[ "$os" == "Darwin" ]]; then
      if netstat -anv | egrep '\.10000\b.*LISTEN' >/dev/null 2>&1; then
        append_md "- Puerto 10000 en escucha: SI"
        incr_pass
      else
        append_md "- Puerto 10000 en escucha: NO"
        [[ "${IS_LINUX:-0}" -eq 1 ]] && incr_err || incr_warn
      fi
    else
      if netstat -tln 2>/dev/null | egrep ':10000\b' >/dev/null 2>&1; then
        append_md "- Puerto 10000 en escucha: SI"
        incr_pass
      else
        append_md "- Puerto 10000 en escucha: NO"
        [[ "${IS_LINUX:-0}" -eq 1 ]] && incr_err || incr_warn
      fi
    fi
  elif have_cmd lsof; then
    if lsof -nPiTCP:10000 -sTCP:LISTEN >/dev/null 2>&1; then
      append_md "- Puerto 10000 en escucha: SI"
      incr_pass
    else
      append_md "- Puerto 10000 en escucha: NO"
      [[ "${IS_LINUX:-0}" -eq 1 ]] && incr_err || incr_warn
    fi
  else
    append_md "- Herramienta de puertos no disponible"
    incr_warn
  fi

  # Config Miniserv
  if [[ -f "$cfg" ]]; then
    local ssl=$(grep -E '^ssl=' "$cfg" 2>/dev/null | cut -d= -f2 || echo "0")
    local bind=$(grep -E '^bind=' "$cfg" 2>/dev/null | cut -d= -f2 || echo "desconocido")
    local tls10=$(grep -E '^no_tls1=' "$cfg" 2>/dev/null | cut -d= -f2 || echo "0")
    local tls11=$(grep -E '^no_tls1_1=' "$cfg" 2>/dev/null | cut -d= -f2 || echo "0")
    append_md "- ssl=1: ${ssl:-0}"
    append_md "- bind: ${bind}"
    append_md "- no_tls1=1: ${tls10}"
    append_md "- no_tls1_1=1: ${tls11}"
    [[ "$ssl" == "1" ]] && incr_pass || incr_warn
    [[ "$tls10" == "1" && "$tls11" == "1" ]] && incr_pass || incr_warn

    # Certificado
    local pem="/etc/webmin/miniserv.pem"
    if [[ -s "$pem" ]]; then
      append_md "- Certificado SSL: PRESENTE"
      if have_cmd openssl; then
        if openssl x509 -in "$pem" -noout -text >/dev/null 2>&1; then
          append_md "- Certificado legible (openssl): OK"
          incr_pass
        fi
        if openssl x509 -in "$pem" -checkend 2592000 >/dev/null 2>&1; then
          append_md "- Vigencia > 30 días: OK"
        else
          append_md "- Vigencia > 30 días: NO (renovar pronto)"
          incr_warn
        fi
      fi
    else
      append_md "- Certificado SSL: AUSENTE"
      incr_warn
    fi
  else
    append_md "- Archivo $cfg: NO ENCONTRADO"
    [[ "${IS_LINUX:-0}" -eq 1 ]] && incr_err || incr_warn
  fi

  # Versión y módulos base
  local wver="(desconocida)"
  [[ -f /etc/webmin/version ]] && wver="$(cat /etc/webmin/version 2>/dev/null || echo desconocida)"
  append_md "- Versión Webmin: ${wver}"

  local modules=(
    filemin cron useradmin software init mount quota disk system package-updates logrotate proc
  )
  local missing=0
  for m in "${modules[@]}"; do
    if [[ -d "/usr/share/webmin/$m" ]] || [[ -f "/etc/webmin/$m/config" ]]; then
      append_md "- Módulo $m: PRESENTE"
      incr_pass
    else
      append_md "- Módulo $m: NO"
      missing=1
      incr_warn
    fi
  done
  ((missing==0)) || warn "Faltan módulos Webmin (recomendado instalar)"
  section_end
}

enumerate_webmin_modules() {
  section_start "Webmin - Enumeración de módulos"
  local base="/usr/share/webmin"
  if [[ -d "$base" ]]; then
    append_md "- Directorio base: $base"
    append_md "- Módulos detectados:"
    append_md '```'
    ls -1 "$base" | sort >> "$REPORT" 2>&1 || true
    append_md '```'
    incr_pass
  else
    append_md "- Directorio $base: NO ENCONTRADO"
    incr_warn
  fi
  section_end
}

check_virtualmin_core() {
  section_start "Virtualmin - Núcleo y características"
  local vdir="/etc/webmin/virtual-server"
  if command -v virtualmin >/dev/null 2>&1; then
    append_md "- Comando virtualmin: DISPONIBLE"
    incr_pass
    md_cmd virtualmin version
    # check-config (no modifica; valida estado)
    append_md "- check-config:"
    md_cmd virtualmin check-config
    append_md "- list-features:"
    md_cmd virtualmin list-features

    # Validación de features clave
    local feat_out
    feat_out="$(virtualmin list-features 2>/dev/null || true)"
    local expected=(dns mail web webalizer mysql postgres ssl)
    for f in "${expected[@]}"; do
      if echo "$feat_out" | grep -qw "$f"; then
        append_md "- Feature '${f}': PRESENTE"
        incr_pass
      else
        append_md "- Feature '${f}': AUSENTE"
        incr_warn
      fi
    done

    # plugins si existe
    if virtualmin help 2>/dev/null | grep -q list-plugins; then
      append_md "- list-plugins:"
      md_cmd virtualmin list-plugins
    fi
  else
    append_md "- Comando virtualmin: NO DISPONIBLE"
    [[ "${IS_LINUX:-0}" -eq 1 ]] && incr_err || incr_warn
  fi

  # Presencia del módulo y librerías
  local lib_ok=0
  if [[ -d "$vdir" ]] || [[ -d "/usr/share/webmin/virtual-server" ]]; then
    append_md "- Módulo virtual-server: PRESENTE"
    incr_pass
    for f in virtual-server-lib.pl domain-lib.pl mail-lib.pl database-lib.pl; do
      if [[ -f "/usr/share/webmin/virtual-server/$f" ]] || [[ -f "$vdir/$f" ]] || [[ -f "virtualmin-gpl-master/$f" ]]; then
        append_md "- Librería $f: OK"
        lib_ok=1
      else
        append_md "- Librería $f: FALTA"
        incr_warn
      fi
    done
  else
    append_md "- Módulo virtual-server: AUSENTE"
    [[ "${IS_LINUX:-0}" -eq 1 ]] && incr_err || incr_warn
  fi

  section_end
}

enumerate_virtualmin_assets() {
  section_start "Virtualmin - Archivos del módulo"
  local d1="/usr/share/webmin/virtual-server"
  local d2="/etc/webmin/virtual-server"
  if [[ -d "$d1" || -d "$d2" ]]; then
    local dir="$d1"
    [[ -d "$d2" && ! -d "$d1" ]] && dir="$d2"
    append_md "- Directorio módulo: $dir"
    append_md "- Archivos principales:"
    append_md '```'
    ls -1 "$dir" | egrep '(\.pl|\.cgi|\.pm)$' | sort >> "$REPORT" 2>&1 || true
    append_md '```'
    incr_pass
  else
    append_md "- Módulo virtual-server no encontrado"
    incr_err
  fi
  section_end
}

check_http_stack() {
  section_start "HTTP/HTTPS - Apache/Nginx y PHP"
  local any_web=0
  if systemctl is-active --quiet apache2 2>/dev/null; then
    append_md "- Apache2: ACTIVO"
    incr_pass; any_web=1
    md_cmd apache2 -v
    # Respuesta HTTP
    append_md "- Respuesta HTTP localhost:80"
    md_cmd bash -lc "curl -fsSI --max-time 5 http://127.0.0.1/ || true"
  else
    append_md "- Apache2: INACTIVO"
    incr_warn
  fi

  if systemctl is-active --quiet nginx 2>/dev/null; then
    append_md "- Nginx: ACTIVO"
    incr_pass; any_web=1
    md_cmd nginx -v
    append_md "- Respuesta HTTP localhost:80"
    md_cmd bash -lc "curl -fsSI --max-time 5 http://127.0.0.1/ || true"
  else
    append_md "- Nginx: INACTIVO"
    incr_warn
  fi

  if [[ $any_web -eq 0 ]]; then
    [[ "${IS_LINUX:-0}" -eq 1 ]] && incr_err || incr_warn
  fi

  if command -v php >/dev/null 2>&1; then
    append_md "- PHP: PRESENTE"
    md_cmd php -v
    incr_pass
  else
    append_md "- PHP: AUSENTE"
    incr_warn
  fi
  section_end
}

check_mail_stack() {
  section_start "Correo - Postfix, Dovecot, DKIM, SPF"
  # Postfix
  if systemctl is-active --quiet postfix 2>/dev/null; then
    append_md "- Postfix: ACTIVO"
    incr_pass
    if have_cmd postconf; then
      local sm=$(postconf -h smtpd_milters 2>/dev/null || true)
      local nsm=$(postconf -h non_smtpd_milters 2>/dev/null || true)
      local srs=$(postconf -h smtpd_recipient_restrictions 2>/dev/null || true)
      append_md "- smtpd_milters: ${sm}"
      append_md "- non_smtpd_milters: ${nsm}"
      append_md "- recipient_restrictions: ${srs}"
      [[ "$sm" =~ 127.0.0.1:8891 || "$nsm" =~ 127.0.0.1:8891 ]] && incr_pass || incr_warn
      [[ "$srs" =~ policyd-spf ]] && incr_pass || incr_warn
    fi
  else
    append_md "- Postfix: INACTIVO"
    [[ "${IS_LINUX:-0}" -eq 1 ]] && incr_err || incr_warn
  fi

  # Dovecot
  if systemctl is-active --quiet dovecot 2>/dev/null; then
    append_md "- Dovecot: ACTIVO"
    incr_pass
  else
    append_md "- Dovecot: INACTIVO (si no se usa IMAP/POP3 es opcional)"
    incr_warn
  fi

  # OpenDKIM
  if systemctl is-active --quiet opendkim 2>/dev/null; then
    append_md "- OpenDKIM: ACTIVO"
    incr_pass
  else
    append_md "- OpenDKIM: INACTIVO"
    incr_warn
  fi

  # Puertos relevantes
  append_md "- Puertos SMTP(25,465,587) y IMAPS(993):"
  if have_cmd ss; then
    md_cmd bash -lc "ss -ltn '( sport = :25 or sport = :465 or sport = :587 or sport = :993 )' 2>/dev/null || ss -tln | egrep ':25|:465|:587|:993' || true"
  elif have_cmd netstat; then
    md_cmd bash -lc 'os="$(uname -s 2>/dev/null || echo Unknown)"; if [ "$os" = "Darwin" ]; then netstat -anv | egrep "\\.(25|465|587|993)\\b.*LISTEN" || true; else netstat -tln 2>/dev/null | egrep ":(25|465|587|993)\\b" || true; fi'
  elif have_cmd lsof; then
    md_cmd bash -lc 'lsof -nPiTCP -sTCP:LISTEN | egrep ":(25|465|587|993)\\b" || true'
  else
    append_md "- No hay ss/netstat/lsof disponibles"
  fi
  section_end
}

check_security_stack() {
  section_start "Seguridad - UFW/Fail2ban"
  if have_cmd ufw; then
    append_md "- UFW detectado:"
    md_cmd ufw status
    if ufw status 2>/dev/null | grep -q "10000"; then incr_pass; else incr_warn; fi
  else
    append_md "- UFW: NO DETECTADO"
    incr_warn
  fi

  if systemctl is-active --quiet fail2ban 2>/dev/null; then
    append_md "- Fail2ban: ACTIVO"
    incr_pass
    md_cmd fail2ban-client status
  else
    append_md "- Fail2ban: INACTIVO"
    incr_warn
  fi
  section_end
}

check_db_stack() {
  section_start "Bases de datos - MySQL/MariaDB y PostgreSQL"
  # MySQL/MariaDB
  if systemctl is-active --quiet mysql 2>/dev/null; then
    append_md "- MySQL/MariaDB: ACTIVO"
    incr_pass
    md_cmd mysql --version
    md_cmd bash -lc "mysql -e 'SELECT 1;' 2>&1 || true"
  else
    append_md "- MySQL/MariaDB: INACTIVO"
    incr_warn
  fi

  # PostgreSQL
  if systemctl is-active --quiet postgresql 2>/dev/null; then
    append_md "- PostgreSQL: ACTIVO"
    incr_pass
    md_cmd psql --version
  else
    append_md "- PostgreSQL: INACTIVO (opcional)"
    incr_warn
  fi
  section_end
}

check_dns_stack() {
  section_start "DNS - Bind9/named"
  if systemctl is-active --quiet bind9 2>/dev/null || systemctl is-active --quiet named 2>/dev/null; then
    append_md "- DNS (bind9/named): ACTIVO"
    incr_pass
  else
    append_md "- DNS (bind9/named): INACTIVO (opcional si no gestiona DNS)"
    incr_warn
  fi
  append_md "- Puertos DNS (53/tcp, 53/udp):"
  if have_cmd ss; then
    md_cmd bash -lc "ss -lntu | egrep '(:53\\b)' || true"
  elif have_cmd netstat; then
    md_cmd bash -lc 'os="$(uname -s 2>/dev/null || echo Unknown)"; if [ "$os" = "Darwin" ]; then netstat -anv | egrep "\\.53\\b.*(LISTEN|UDP)" || true; else netstat -lntu 2>/dev/null | egrep "(:53\\b)" || true; fi'
  elif have_cmd lsof; then
    md_cmd bash -lc 'lsof -nPi :53 -sTCP:LISTEN || true'
  else
    append_md "- No hay ss/netstat/lsof disponibles"
  fi
  section_end
}

check_usermin() {
  section_start "Usermin"
  local ucfg="/etc/usermin/miniserv.conf"
  if [[ -f "$ucfg" ]]; then
    append_md "- Config Usermin: PRESENTE"
    incr_pass
  else
    append_md "- Config Usermin: AUSENTE"
    incr_warn
  fi

  if systemctl is-active --quiet usermin 2>/dev/null; then
    append_md "- Servicio Usermin: ACTIVO"
    incr_pass
  else
    append_md "- Servicio Usermin: INACTIVO"
    incr_warn
  fi

  if have_cmd ss; then
    ss -tln 2>/dev/null | grep -Eq ':(20000)\b' && append_md "- Puerto 20000 en escucha: SI" || append_md "- Puerto 20000 en escucha: NO"
  else
    netstat -tln 2>/dev/null | grep -q ":20000 " && append_md "- Puerto 20000 en escucha: SI" || append_md "- Puerto 20000 en escucha: NO"
  fi
  section_end
}

check_access_probes() {
  section_start "Sondas de acceso Webmin"
  if have_cmd curl; then
    append_md "- HTTP Headers (HTTPS 10000):"
    md_cmd bash -lc "curl -k -sS -D - --max-time 5 https://127.0.0.1:10000/ -o /dev/null || true"

    # Detección de MiniServ en encabezados
    local server_hdr
    server_hdr="$(curl -k -sSI --max-time 5 https://127.0.0.1:10000/ 2>/dev/null | awk -F': ' 'BEGIN{IGNORECASE=1}/^Server:/{print $2; exit}')"
    if [[ -n "$server_hdr" ]]; then
      append_md "- Encabezado Server: ${server_hdr}"
      if echo "$server_hdr" | grep -qi "MiniServ"; then
        append_md "- MiniServ detectado: SI"
        incr_pass
      else
        append_md "- MiniServ detectado: NO"
        incr_warn
      fi
    fi

    append_md "- Intento HTTP (fallback):"
    md_cmd bash -lc "curl -sS -D - --max-time 5 http://127.0.0.1:10000/ -o /dev/null || true"
  else
    append_md "- curl no disponible"
    incr_warn
  fi
  section_end
}

check_system_summary() {
  section_start "Resumen del sistema"

  local uptime_s="N/A"
  local loadavg_s="N/A"
  local mem_s="N/A"
  local disk_s="N/A"

  if have_cmd uptime; then
    uptime_s="$(uptime 2>/dev/null | sed 's/^.*up //; s/, *[0-9][0-9]* user.*$//' 2>/dev/null || true)"
    # Compatibilidad BSD/GNU (load average vs load averages)
    loadavg_s="$(uptime 2>/dev/null | awk -F'load averages?: ' '{print $2}' 2>/dev/null || true)"
    [[ -z "$loadavg_s" ]] && loadavg_s="$(uptime 2>/dev/null | awk -F'load average: ' '{print $2}' 2>/dev/null || true)"
    [[ -z "$loadavg_s" ]] && loadavg_s="N/A"
  fi

  if have_cmd free; then
    mem_s="$(free -h 2>/dev/null | awk '/^Mem:/ {print $7 \" libres de \" $2}' 2>/dev/null || echo N/A)"
  fi

  if have_cmd df; then
    disk_s="$(df -h / 2>/dev/null | awk 'NR==2 {print $4 \" libres de \" $2}' 2>/dev/null || echo N/A)"
  fi

  append_md "- Uptime: ${uptime_s}"
  append_md "- Load average: ${loadavg_s}"
  append_md "- Memoria: ${mem_s}"
  append_md "- Disco /: ${disk_s}"
  section_end
}

main() {
  require_root
  write_header
  info "Iniciando verificación profunda (reporte: $REPORT)"

  check_webmin_core
  hr
  enumerate_webmin_modules
  hr
  check_virtualmin_core
  hr
  enumerate_virtualmin_assets
  hr
  check_http_stack
  hr
  check_mail_stack
  hr
  check_security_stack
  hr
  check_db_stack
  hr
  check_dns_stack
  hr
  check_usermin
  hr
  check_access_probes
  hr
  check_system_summary

  append_md "\n# Resumen Final\n"
  append_md "- Pasos OK: ${PASS_COUNT}"
  append_md "- Advertencias: ${WARN_COUNT}"
  append_md "- Errores: ${ERR_COUNT}"
  echo "Reporte: $REPORT"

  if [[ ${ERR_COUNT} -eq 0 ]]; then
    ok "Verificación profunda completada: SIN ERRORES"
    exit 0
  else
    err "Verificación profunda completada con ERRORES (${ERR_COUNT})"
    exit 1
  fi
}

main "$@"

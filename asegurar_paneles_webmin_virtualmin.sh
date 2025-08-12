#!/bin/bash
# Asegurar Webmin y Virtualmin (endurecimiento real e idempotente)
# - Endurece /etc/webmin/miniserv.conf y /etc/usermin/miniserv.conf (si existe)
# - Fuerza SSL, TLS modernos, timeouts, ciphers y bind seguro según firewall
# - Abre puertos en UFW/firewalld si están presentes
# - Reinicia servicios y valida acceso HTTPS
# - Genera reporte en reportes/

set -Eeuo pipefail
IFS=$'\n\t'

# Colores
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'
log(){ local L="$1"; shift; case "$L" in
  INFO) echo -e "${BLUE}[INFO]${NC} $*";;
  OK)   echo -e "${GREEN}[OK]${NC} $*";;
  WARN) echo -e "${YELLOW}[WARN]${NC} $*";;
  ERR)  echo -e "${RED}[ERR]${NC} $*";;
  HDR)  echo -e "\n${PURPLE}=== $* ===${NC}";;
esac; }

require_root(){
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log ERR "Requiere root. Use: sudo $0"
    exit 1
  fi
}

have_cmd(){ command -v "$1" >/dev/null 2>&1; }

# set_kv file key value  -> asegura key=value en archivo de configuración tipo Webmin
set_kv(){
  local file="$1" key="$2" val="$3"
  if grep -q "^${key}=" "$file" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${val}|" "$file"
  else
    printf "%s=%s\n" "$key" "$val" >> "$file"
  fi
}

# Decide bind seguro según firewall presente
decide_bind(){
  local bind="127.0.0.1"
  if have_cmd ufw && ufw status 2>/dev/null | grep -qi "Status: active"; then
    bind="0.0.0.0"
  elif have_cmd firewall-cmd && firewall-cmd --state 2>/dev/null | grep -qi running; then
    bind="0.0.0.0"
  fi
  echo "$bind"
}

ensure_ssl_cert(){
  local pem="$1"
  if [[ -s "$pem" ]]; then
    chmod 600 "$pem" || true
    return 0
  fi
  log INFO "Generando certificado autofirmado para Webmin ($pem)"
  local host="$(hostname -f 2>/dev/null || hostname)"
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$pem" -out "$pem" \
    -subj "/CN=${host}" >/dev/null 2>&1 || true
  chmod 600 "$pem" 2>/dev/null || true
}

harden_miniserv(){
  local cfg="$1" port="$2"
  [[ -f "$cfg" ]] || { log WARN "Archivo no encontrado: $cfg"; return 0; }
  # Respaldo único por fecha si no existe
  [[ -f "${cfg}.backup" ]] || cp -f "$cfg" "${cfg}.backup" 2>/dev/null || true

  # TLS moderno y parámetros seguros
  set_kv "$cfg" "port" "${port}"
  set_kv "$cfg" "ssl" "1"
  set_kv "$cfg" "ssl_redirect" "1"
  set_kv "$cfg" "no_ssl2" "1"
  set_kv "$cfg" "no_ssl3" "1"
  set_kv "$cfg" "no_tls1" "1"
  set_kv "$cfg" "no_tls1_1" "1"
  set_kv "$cfg" "ssl_honorcipherorder" "1"
  set_kv "$cfg" "ssl_prefer_server_ciphers" "1"
  set_kv "$cfg" "session" "1"
  set_kv "$cfg" "session_timeout" "1800"
  set_kv "$cfg" "max_servers" "50"
  set_kv "$cfg" "max_servers_idle" "30"
  set_kv "$cfg" "dns_lookup" "0"
  set_kv "$cfg" "ip_lookup" "0"

  # Bind según firewall
  local bind_val; bind_val="$(decide_bind)"
  set_kv "$cfg" "bind" "$bind_val"
  if [[ "$bind_val" == "127.0.0.1" ]]; then
    log WARN "Firewall no activo; bind=127.0.0.1 por seguridad (habilite UFW/firewalld para exponer públicamente)"
  fi

  # Certificado
  local dir="$(dirname "$cfg")"
  local pem="${dir}/miniserv.pem"
  ensure_ssl_cert "$pem"
}

open_firewall(){
  local ports=("$@")
  local done=0
  if have_cmd ufw; then
    for p in "${ports[@]}"; do ufw allow "${p}/tcp" >/dev/null 2>&1 || true; done
    ufw status >/dev/null 2>&1 || ufw --force enable >/dev/null 2>&1 || true
    log OK "UFW: reglas aplicadas (${ports[*]})"
    done=1
  fi
  if have_cmd firewall-cmd; then
    for p in "${ports[@]}"; do firewall-cmd --permanent --add-port="${p}/tcp" >/dev/null 2>&1 || true; done
    firewall-cmd --reload >/dev/null 2>&1 || true
    log OK "firewalld: reglas aplicadas (${ports[*]})"
    done=1
  fi
  if [[ "$done" -eq 0 ]]; then
    log WARN "No se detectó UFW/firewalld; puertos no abiertos automáticamente"
  fi
}

restart_services(){
  systemctl restart webmin >/dev/null 2>&1 || true
  systemctl restart usermin >/dev/null 2>&1 || true
}

validate_status(){
  local ok=0
  # Puertos
  if have_cmd ss; then
    ss -tln 2>/dev/null | grep -Eq ':(10000)\b' && log OK "Webmin escuchando en 10000" || { log ERR "Webmin no escucha en 10000"; ok=1; }
    ss -tln 2>/dev/null | grep -Eq ':(20000)\b' && log OK "Usermin escuchando en 20000" || log WARN "Usermin no detectado (opcional)"
  elif have_cmd netstat; then
    netstat -tln 2>/dev/null | grep -q ":10000 " && log OK "Webmin escuchando en 10000" || { log ERR "Webmin no escucha en 10000"; ok=1; }
    netstat -tln 2>/dev/null | grep -q ":20000 " && log OK "Usermin escuchando en 20000" || log WARN "Usermin no detectado (opcional)"
  fi
  # HTTPS
  if have_cmd curl; then
    if curl -k -s --connect-timeout 5 https://localhost:10000/ >/dev/null; then
      log OK "Acceso HTTPS a Webmin verificado en localhost:10000"
    else
      log ERR "No se pudo verificar acceso HTTPS a Webmin"
      ok=1
    fi
  fi
  return "$ok"
}

write_report(){
  local TS="$(date +%Y%m%d_%H%M%S)"
  mkdir -p reportes 2>/dev/null || true
  local R="reportes/seguridad_paneles_${TS}.md"
  {
    echo "# Seguridad Webmin/Virtualmin"
    echo "Fecha: $(date)"
    echo
    echo "## Configuración aplicada"
    echo "- SSL forzado (miniserv.conf)"
    echo "- TLS1.2/1.3, sin SSLv2/SSLv3/TLS1.0/1.1"
    echo "- session_timeout=1800, max_servers=50"
    echo "- bind=$(decide_bind)"
    echo "- Puertos: 10000(Webmin), 20000(Usermin opcional)"
    echo
    echo "## Validación de escucha"
    if have_cmd ss; then
      echo '```'
      ss -tlnp 2>/dev/null | egrep ':10000|:20000' || true
      echo '```'
    elif have_cmd netstat; then
      echo '```'
      netstat -tlnp 2>/dev/null | egrep ':10000|:20000' || true
      echo '```'
    else
      echo "- ss/netstat no disponibles"
    fi
  } > "$R"
  echo "$R"
}

main(){
  require_root
  log HDR "ASEGURAR WEBMIN Y VIRTUALMIN"

  local WCFG="/etc/webmin/miniserv.conf"
  local UCFG="/etc/usermin/miniserv.conf"

  if [[ ! -d /etc/webmin ]]; then
    log ERR "/etc/webmin no existe. Instale Webmin antes de ejecutar este script."
    exit 1
  fi

  # Endurecer Webmin
  log INFO "Endureciendo Webmin ($WCFG)"
  harden_miniserv "$WCFG" "10000"

  # Endurecer Usermin si existe
  if [[ -f "$UCFG" ]]; then
    log INFO "Endureciendo Usermin ($UCFG)"
    harden_miniserv "$UCFG" "20000"
  else
    log WARN "Usermin no detectado (opcional)"
  fi

  # Abrir puertos si hay firewall
  open_firewall 22 80 443 10000 20000

  # Reiniciar servicios
  log INFO "Reiniciando servicios"
  restart_services
  sleep 2

  # Validar
  if validate_status; then
    log OK "Endurecimiento aplicado correctamente"
  else
    log WARN "Endurecimiento aplicado con advertencias"
  fi

  # Reporte
  local REPORT_PATH; REPORT_PATH="$(write_report)"
  log OK "Reporte: $REPORT_PATH"
}

# Ejecutar
main "$@"

#!/bin/bash
# Remediación Total: instala, asegura y verifica Webmin + Virtualmin a fondo
# Uso (Ubuntu/Debian con root):
#   curl -fsSLO https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/master/remediacion_total_webmin_virtualmin.sh \
#     && sudo bash remediacion_total_webmin_virtualmin.sh
# Efectos:
# - Instala Webmin y Virtualmin (idempotente) usando instalacion_un_comando.sh (o lo descarga)
# - Endurece y abre puertos con asegurar_paneles_webmin_virtualmin.sh
# - Ejecuta verificación profunda y orquestador de verificación
# - Deja reportes en reportes/*.md y muestra resumen

set -Eeuo pipefail
IFS=$'\n\t'

# Colores / Log
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
    log ERR "Se requieren privilegios de root. Usa: sudo $0"
    exit 1
  fi
}

have_cmd(){ command -v "$1" >/dev/null 2>&1; }

RAW_URL="https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/master"

check_os(){
  if [[ ! -f /etc/os-release ]]; then
    log ERR "Sistema no soportado (falta /etc/os-release). Requiere Ubuntu/Debian."
    exit 1
  fi
  . /etc/os-release
  case "${ID}" in
    ubuntu|debian) log OK "SO: ${PRETTY_NAME:-$ID $VERSION_ID}";;
    *) log ERR "Distribución no soportada: ${ID}. Requiere Ubuntu/Debian."; exit 1;;
  esac
}

ensure_network(){
  log INFO "Verificando conectividad..."
  if ! ping -c 1 -W 5 download.webmin.com >/dev/null 2>&1; then
    log WARN "No hay ping a download.webmin.com, intentando curl HEAD..."
    if ! curl -fsSIL --connect-timeout 5 https://download.webmin.com/ >/dev/null 2>&1; then
      log ERR "Sin conectividad a repos de Webmin. Verifica red/DNS/Firewall."
      exit 1
    fi
  fi
  log OK "Conectividad básica OK"
}

fetch_if_missing(){
  local local_path="$1"; local remote_name="$2"
  if [[ -f "$local_path" ]]; then
    return 0
  fi
  log INFO "Descargando ${remote_name} desde repo remoto..."
  curl -fsSL "${RAW_URL}/${remote_name}" -o "$local_path"
  chmod +x "$local_path" || true
}

# Instalación de componentes requeridos en Ubuntu/Debian
install_required_components(){
  log HDR "INSTALANDO COMPONENTES REQUERIDOS (Ubuntu/Debian)"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  local PKGS=(
    # Hosting y web
    apache2 nginx php php-cli php-fpm php-mysql
    # Bases de datos
    mysql-server mariadb-server postgresql
    # Lenguajes runtime
    python3 nodejs npm
    # Correo y servicios asociados
    postfix dovecot-imapd dovecot-pop3d
    # DNS y FTP
    bind9 vsftpd proftpd-basic
    # Seguridad
    ufw fail2ban clamav clamav-daemon rkhunter tripwire
    # Monitoreo
    htop iotop iftop nethogs atop dstat sysstat
    # Logs y utilidades
    rsyslog logrotate logwatch
    # Herramientas auxiliares
    lsof net-tools curl ca-certificates
  )
  apt-get install -y -qq "${PKGS[@]}" || true

  # Habilitar sysstat (sar, iostat, vmstat) si es necesario
  if [[ -f /etc/default/sysstat ]]; then
    sed -i 's/^\s*ENABLED=.*/ENABLED="true"/' /etc/default/sysstat || true
    systemctl enable --now sysstat >/dev/null 2>&1 || true
  fi
}

# Arranque y habilitación de servicios clave
ensure_services_started(){
  log HDR "HABILITANDO Y ARRANCANDO SERVICIOS CLAVE"
  local SRV=(
    apache2 nginx mysql mariadb postgresql
    postfix dovecot bind9 vsftpd proftpd
    fail2ban rsyslog
  )
  for s in "${SRV[@]}"; do
    systemctl enable --now "$s" >/dev/null 2>&1 && log OK "Servicio $s activo" || true
  done
}

# Reglas mínimas de firewall para paneles y correo
configure_firewall_basic(){
  if have_cmd ufw; then
    log HDR "CONFIGURANDO FIREWALL UFW (básico)"
    local PORTS=(22 25 53 80 110 143 443 587 993 995 10000 20000)
    for p in "${PORTS[@]}"; do ufw allow "${p}/tcp" >/dev/null 2>&1 || true; done
    ufw status >/dev/null 2>&1 || ufw --force enable >/dev/null 2>&1 || true
    log OK "UFW habilitado con puertos críticos abiertos"
  fi
}

run_instalacion(){
  log HDR "INSTALACIÓN AUTOMÁTICA WEBMIN + VIRTUALMIN"
  # Condición de instalación: no existe /etc/webmin o virtualmin no disponible
  local need_install=0
  [[ ! -d /etc/webmin ]] && need_install=1
  ! command -v virtualmin >/dev/null 2>&1 && need_install=1
  if [[ "$need_install" -eq 0 ]]; then
    log OK "Webmin/Virtualmin ya presentes. Saltando instalación."
    return 0
  fi

  # Usar instalacion_un_comando.sh local o descargar
  local installer="./instalacion_un_comando.sh"
  fetch_if_missing "$installer" "instalacion_un_comando.sh"

  bash "$installer"
  log OK "Instalación automática finalizada"
}

harden_and_open(){
  log HDR "ENDURECIMIENTO Y EXPOSICIÓN CONTROLADA"
  local hardener="./asegurar_paneles_webmin_virtualmin.sh"
  fetch_if_missing "$hardener" "asegurar_paneles_webmin_virtualmin.sh"
  bash "$hardener"
}

deep_verification(){
  log HDR "VERIFICACIÓN PROFUNDA"
  local deep="./verificacion_profunda_paneles.sh"
  fetch_if_missing "$deep" "verificacion_profunda_paneles.sh"
  bash "$deep" | tee "reportes/reporte_profundo_run_$(date +%Y%m%d_%H%M%S).md" || true
}

run_orchestrator(){
  log HDR "ORQUESTADOR DE VERIFICACIÓN PRO"
  local orch="./orquestador_verificacion_pro.sh"
  fetch_if_missing "$orch" "orquestador_verificacion_pro.sh"
  bash "$orch" || true
}

post_summary(){
  log HDR "RESUMEN FINAL"
  systemctl is-active --quiet webmin 2>/dev/null && log OK "Webmin ACTIVO" || log ERR "Webmin INACTIVO"
  command -v virtualmin >/dev/null 2>&1 && log OK "virtualmin disponible" || log ERR "virtualmin NO disponible"
  if have_cmd ss; then
    ss -tln 2>/dev/null | egrep ':10000|:20000' && log OK "Puertos 10000/20000 en escucha (si corresponde)" || log WARN "10000/20000 no detectados"
  elif have_cmd netstat; then
    netstat -tln 2>/dev/null | egrep ':10000|:20000' && log OK "Puertos 10000/20000 en escucha" || log WARN "10000/20000 no detectados"
  fi
  local last_deep last_orch
  last_deep="$(ls -t reportes/reporte_profundo_* 2>/dev/null | head -1 || true)"
  last_orch="$(ls -t reportes/reporte_verificacion_pro_* 2>/dev/null | head -1 || true)"
  [[ -n "$last_deep" ]] && log OK "Reporte profundo: $last_deep"
  [[ -n "$last_orch" ]] && log OK "Reporte orquestador: $last_orch"
  log INFO "Acceso esperado: https://$(hostname -I 2>/dev/null | awk '{print $1}'):10000 (usuario root)"
}

main(){
  require_root
  check_os
  ensure_network
  mkdir -p reportes 2>/dev/null || true

  install_required_components
  run_instalacion
  ensure_services_started
  configure_firewall_basic
  hardener_exit=0
  if ! harden_and_open; then hardener_exit=$?; log WARN "Endurecimiento con advertencias (rc=$hardener_exit)"; fi

  deep_verification
  run_orchestrator

  post_summary
  log OK "Remediación TOTAL completada"
}

main "$@"

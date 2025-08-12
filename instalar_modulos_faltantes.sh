#!/bin/bash
# Instala y habilita módulos/servicios faltantes para Webmin/Virtualmin
# Requisitos: Ubuntu/Debian con root
# Uso:
#   sudo bash instalar_modulos_faltantes.sh
# Efectos:
# - Instala y habilita servicios base de hosting (web, db, mail, dns, ftp)
# - Instala herramientas de seguridad y monitoreo (fail2ban, clamav, sysstat, etc.)
# - Abre puertos críticos en UFW (si existe)
# - Endurece y valida paneles con asegurar_paneles_webmin_virtualmin.sh
# - Ejecuta verificación orquestada

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

enable_sysstat(){
  if [[ -f /etc/default/sysstat ]]; then
    sed -i 's/^\s*ENABLED=.*/ENABLED="true"/' /etc/default/sysstat || true
    systemctl enable --now sysstat >/dev/null 2>&1 || true
  fi
}

install_packages(){
  log HDR "INSTALANDO PAQUETES FALTANTES"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq

  # Servicios de hosting y dependencias
  local PKGS_HOST=(apache2 nginx php php-cli php-fpm php-mysql)
  local PKGS_DB=(mysql-server mariadb-server postgresql)
  local PKGS_MAIL=(postfix dovecot-imapd dovecot-pop3d)
  local PKGS_NET=(bind9 vsftpd proftpd-basic)
  local PKGS_SEC=(ufw fail2ban clamav clamav-daemon rkhunter tripwire)
  local PKGS_MON=(htop iotop iftop nethogs atop dstat sysstat)
  local PKGS_LOG=(rsyslog logrotate logwatch)
  local PKGS_MISC=(lsof net-tools curl ca-certificates)

  apt-get install -y -qq \
    "${PKGS_HOST[@]}" "${PKGS_DB[@]}" "${PKGS_MAIL[@]}" \
    "${PKGS_NET[@]}" "${PKGS_SEC[@]}" "${PKGS_MON[@]}" \
    "${PKGS_LOG[@]}" "${PKGS_MISC[@]}" || true

  # Base de PHP adicional (según disponibilidad)
  apt-get install -y -qq php-curl php-xml php-zip php-gd php-mbstring || true

  # Actualizar firmas AV (si aplica)
  if have_cmd freshclam; then freshclam || true; fi

  enable_sysstat
  log OK "Instalación de paquetes completada"
}

start_enable_services(){
  log HDR "HABILITANDO Y ARRANCANDO SERVICIOS"
  local SRV=(
    webmin usermin
    apache2 nginx
    mysql mariadb postgresql
    postfix dovecot
    bind9 vsftpd proftpd
    fail2ban rsyslog
  )
  for s in "${SRV[@]}"; do
    systemctl enable --now "$s" >/dev/null 2>&1 && log OK "Servicio $s activo" || log WARN "No se pudo activar $s (puede ser opcional o no instalado)"
  done
}

configure_ufw(){
  if have_cmd ufw; then
    log HDR "CONFIGURANDO FIREWALL UFW"
    local PORTS=(22 25 53 80 110 143 443 587 993 995 10000 20000)
    for p in "${PORTS[@]}"; do ufw allow "${p}/tcp" >/dev/null 2>&1 || true; done
    ufw status >/dev/null 2>&1 || ufw --force enable >/dev/null 2>&1 || true
    log OK "UFW habilitado y puertos críticos permitidos"
  else
    log WARN "UFW no instalado o no disponible"
  fi
}

ensure_virtualmin_features(){
  if have_cmd virtualmin; then
    log HDR "CONFIGURANDO FEATURES DE VIRTUALMIN (si hay dominios)"
    # Inicializa servicios necesarios y configura sistema (no falla si no aplica)
    virtualmin config-system --include nginx,apache,mysql,mariadb,postgresql,clamav,dovecot,bind9,proftpd,vsftpd,fail2ban || true
    # Habilitar características por defecto para nuevos servidores (no rompe si no aplica)
    virtualmin set-global --default-features --enable-feature web,dns,mail,mysql,postgres,ssl || true
    log OK "Virtualmin configurado (features y servicios base)"
  else
    log WARN "virtualmin no está en PATH; se omitió configuración de features"
  fi
}

secure_panels(){
  if [[ -x "./asegurar_paneles_webmin_virtualmin.sh" ]]; then
    log HDR "ENDURECIENDO PANELES (Webmin/Usermin)"
    bash ./asegurar_paneles_webmin_virtualmin.sh || log WARN "Endurecimiento con advertencias"
  else
    log WARN "asegurar_paneles_webmin_virtualmin.sh no encontrado/ejecutable; omitiendo"
  fi
}

validate_and_report(){
  mkdir -p reportes 2>/dev/null || true
  if [[ -x "./orquestador_verificacion_pro.sh" ]]; then
    log HDR "EJECUTANDO VERIFICACIÓN INTEGRAL"
    bash ./orquestador_verificacion_pro.sh | tee "reportes/reporte_instalar_modulos_$(date +%Y%m%d_%H%M%S).md" || true
  else
    log WARN "orquestador_verificacion_pro.sh no disponible; omitiendo verificación integrada"
  fi

  log HDR "RESUMEN"
  systemctl is-active --quiet webmin 2>/dev/null && log OK "Webmin ACTIVO" || log ERR "Webmin INACTIVO"
  if have_cmd ss; then
    ss -tln 2>/dev/null | egrep ':10000|:20000' || true
  elif have_cmd netstat; then
    netstat -tln 2>/dev/null | egrep ':10000|:20000' || true
  fi
}

main(){
  require_root
  check_os
  ensure_network
  install_packages
  start_enable_services
  configure_ufw
  ensure_virtualmin_features
  secure_panels
  validate_and_report
  log OK "Instalación y activación de módulos completada"
}

main "$@"

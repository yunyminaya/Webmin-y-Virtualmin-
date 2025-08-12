#!/bin/bash
# Orquestador de Seguridad PRO para Webmin + Virtualmin
# Uso:
#   sudo bash orquestador_seguridad_pro.sh            # Solo verificar
#   sudo bash orquestador_seguridad_pro.sh --fix      # Verificar y corregir automáticamente
#
# Sistema objetivo: Ubuntu/Debian (servidor). Idempotente.
# Este orquestador NO instala paneles; asume Webmin/Virtualmin ya instalados.

set -euo pipefail

# Colores / Log
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
log() { local L="$1"; shift; echo -e "${L}[$(date '+%F %T')] $*${NC}"; }
info(){ log "${BLUE}" "$*"; }
ok()  { log "${GREEN}" "$*"; }
warn(){ log "${YELLOW}" "$*"; }
err() { log "${RED}" "$*"; }

RUN_FIX="false"
[[ "${1:-}" == "--fix" ]] && RUN_FIX="true"

# Reporte
TS="$(date +%Y%m%d_%H%M%S)"
mkdir -p reportes 2>/dev/null || true
REPORT="reportes/reporte_seguridad_orquestada_${TS}.md"

# Estado
WARN_COUNT=0

# Utilidades
require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "Se requieren privilegios de root. Usa: sudo $0 [--fix]"
    exit 1
  fi
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

detect_os() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "${ID:-unknown}"
  else
    echo "unknown"
  fi
}

apt_install() {
  # Instala paquetes si apt-get existe
  if have_cmd apt-get; then
    DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1 || true
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" >/dev/null 2>&1 || true
  fi
}

svc_enable_start() {
  local svc="$1"
  if have_cmd systemctl && systemctl list-unit-files | grep -q "^${svc}\.service"; then
    systemctl enable "$svc" >/dev/null 2>&1 || true
    systemctl start "$svc"  >/dev/null 2>&1 || true
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
      ok "Servicio ${svc}: ACTIVO"
    else
      warn "Servicio ${svc}: INACTIVO"
      ((WARN_COUNT++)) || true
    fi
  fi
}

# Endurecimiento Webmin (mínimo seguro)
ensure_webmin_ssl() {
  info "Verificando SSL en Webmin..."
  if [[ -d /etc/webmin ]]; then
    local conf="/etc/webmin/miniserv.conf"
    local pem="/etc/webmin/miniserv.pem"
    if [[ ! -f "$pem" ]] && have_cmd openssl; then
      local host; host="$(hostname -f 2>/dev/null || hostname)"
      openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$pem" -out "$pem" \
        -subj "/C=ES/ST=Local/L=Local/O=Webmin/CN=${host}" >/dev/null 2>&1 || true
      chmod 600 "$pem" 2>/dev/null || true
      ok "Certificado autosignado generado para Webmin"
    fi
    if [[ -f "$conf" ]]; then
      if grep -q '^ssl=' "$conf"; then
        sed -i 's/^ssl=.*/ssl=1/' "$conf" || true
      else
        echo "ssl=1" >> "$conf"
      fi
      # No forzamos ciphers avanzados para evitar lockout; mantener mínimo seguro
    fi
    svc_enable_start webmin
  else
    warn "Directorio /etc/webmin no encontrado. Saltando SSL Webmin."
    ((WARN_COUNT++)) || true
  fi
}

# Firewall
ensure_ufw_rules() {
  local OS_ID; OS_ID="$(detect_os)"
  if [[ "$OS_ID" != "ubuntu" && "$OS_ID" != "debian" ]]; then
    warn "UFW solo auto-config en Ubuntu/Debian (detectado: $OS_ID)."
    return 0
  fi
  info "Asegurando UFW y reglas necesarias..."
  apt_install ufw
  local rules=( "ssh" "80/tcp" "443/tcp" "10000/tcp" "20000/tcp" "25/tcp" "587/tcp" "465/tcp" "110/tcp" "143/tcp" "993/tcp" "995/tcp" )
  for r in "${rules[@]}"; do ufw allow "$r" >/dev/null 2>&1 || true; done
  ufw --force enable >/dev/null 2>&1 || true
  ok "UFW habilitado con reglas para paneles y correo"
}

# Fail2ban (jails comunes)
ensure_fail2ban() {
  info "Asegurando Fail2ban con jails básicos..."
  apt_install fail2ban
  if [[ -d /etc/fail2ban ]]; then
    local jail="/etc/fail2ban/jail.local"
    cat > "$jail" <<'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
backend = systemd

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s

[postfix]
enabled = true

[postfix-sasl]
enabled = true

[dovecot]
enabled = true

[recidive]
enabled = true
logpath = /var/log/fail2ban.log
bantime = 1w
findtime = 1d
maxretry = 5

[apache-auth]
enabled = true

[apache-badbots]
enabled = true

[apache-noscript]
enabled = true
EOF
    systemctl enable fail2ban >/dev/null 2>&1 || true
    systemctl restart fail2ban >/dev/null 2>&1 || true
    ok "Fail2ban configurado con jails comunes"
  else
    warn "No se encontró /etc/fail2ban."
    ((WARN_COUNT++)) || true
  fi
}

# ModSecurity (Apache)
ensure_modsecurity() {
  if have_cmd apache2ctl || [[ -d /etc/apache2 ]]; then
    info "Asegurando ModSecurity + CRS (Apache)..."
    apt_install libapache2-mod-security2 modsecurity-crs
    a2enmod security2 >/dev/null 2>&1 || true
    # Activar engine
    if [[ -f /etc/modsecurity/modsecurity.conf-recommended ]]; then
      cp -f /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf || true
      sed -i 's/^SecRuleEngine .*/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf || true
    fi
    # CRS (según distro)
    if [[ -d /usr/share/modsecurity-crs ]]; then
      if [[ ! -e /etc/modsecurity/crs-setup.conf ]]; then
        cp -f /usr/share/modsecurity-crs/crs-setup.conf.example /etc/modsecurity/crs-setup.conf || true
      fi
      if [[ -d /usr/share/modsecurity-crs/rules && ! -e /etc/modsecurity/rules ]]; then
        ln -sf /usr/share/modsecurity-crs/rules /etc/modsecurity/rules || true
      fi
      # Incluir CRS en security2.conf si no está
      local sec2="/etc/apache2/mods-available/security2.conf"
      grep -q "crs-setup.conf" "$sec2" 2>/dev/null || \
        sed -i '/^<\/IfModule>/i IncludeOptional /etc/modsecurity/crs-setup.conf\nIncludeOptional /etc/modsecurity/rules/*.conf' "$sec2" || true
    fi
    systemctl reload apache2 >/dev/null 2>&1 || systemctl restart apache2 >/dev/null 2>&1 || true
    ok "ModSecurity habilitado"
  else
    info "Apache no detectado. Saltando ModSecurity."
  fi
}

# ModEvasive (Apache)
ensure_evasive() {
  if have_cmd apache2ctl || [[ -d /etc/apache2 ]]; then
    info "Asegurando ModEvasive (Apache)..."
    apt_install libapache2-mod-evasive
    local confdir="/etc/apache2/mods-available"
    local conf="$confdir/evasive.conf"
    mkdir -p /var/log/mod_evasive 2>/dev/null || true
    cat > "$conf" <<'EOF'
<IfModule mod_evasive20.c>
  DOSHashTableSize    3097
  DOSPageCount        5
  DOSSiteCount        100
  DOSPageInterval     1
  DOSSiteInterval     1
  DOSBlockingPeriod   300
  DOSEmailNotify      root@localhost
  DOSLogDir           "/var/log/mod_evasive"
  DOSSystemCommand    "/bin/true"
  DOSWhitelist        127.0.0.1
</IfModule>
EOF
    a2enmod evasive >/dev/null 2>&1 || true
    systemctl reload apache2 >/dev/null 2>&1 || systemctl restart apache2 >/dev/null 2>&1 || true
    ok "ModEvasive habilitado"
  else
    info "Apache no detectado. Saltando ModEvasive."
  fi
}

# Unattended Upgrades
ensure_unattended() {
  local OS_ID; OS_ID="$(detect_os)"
  if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
    info "Asegurando unattended-upgrades..."
    apt_install unattended-upgrades apt-listchanges
    systemctl enable unattended-upgrades >/dev/null 2>&1 || true
    systemctl start unattended-upgrades  >/dev/null 2>&1 || true
    ok "Unattended-upgrades activo"
  fi
}

# Servicios críticos
ensure_core_services() {
  info "Habilitando servicios críticos si existen..."
  local svcs=( webmin apache2 nginx postfix dovecot fail2ban clamav-daemon clamav-freshclam spamassassin mysql mariadb )
  for s in "${svcs[@]}"; do
    svc_enable_start "$s"
  done
}

# Ejecutar verificador si existe
run_script_if_present() {
  local script="$1"; local name="$2"
  if [[ -x "./$script" ]]; then
    info "Ejecutando $name ..."
    "./$script" | tee -a "$REPORT" || { warn "$name reportó advertencias"; ((WARN_COUNT++)) || true; }
  elif [[ -f "./$script" ]]; then
    chmod +x "./$script" || true
    info "Ejecutando $name ..."
    "./$script" | tee -a "$REPORT" || { warn "$name reportó advertencias"; ((WARN_COUNT++)) || true; }
  else
    warn "No se encontró $name ($script)"
    ((WARN_COUNT++)) || true
  fi
}

write_report_header() {
  cat > "$REPORT" <<EOF
# 🔐 Reporte Orquestador de Seguridad PRO (Webmin + Virtualmin)
Fecha: $(date)
Host: $(hostname -f 2>/dev/null || hostname)

## Modo
- Correcciones automáticas: ${RUN_FIX}
EOF
}

append_runtime_status() {
  {
    echo -e "\n## Estado de servicios críticos"
    if have_cmd systemctl; then
      systemctl is-active webmin apache2 nginx postfix dovecot fail2ban clamav-daemon clamav-freshclam spamassassin mysql mariadb 2>/dev/null || true
    fi

    echo -e "\n## UFW (primeras líneas)"
    if have_cmd ufw; then ufw status | sed -n '1,80p'; fi

    echo -e "\n## Puertos (paneles y correo)"
    if have_cmd ss; then
      ss -tlnp | egrep ':10000|:20000|:25 |:587 |:465 |:993 |:995 |:80 |:443 ' || true
    elif have_cmd netstat; then
      netstat -tlnp | egrep ':10000|:20000|:25 |:587 |:465 |:993 |:995 |:80 |:443 ' || true
    fi

    echo -e "\n## Fail2ban"
    if have_cmd fail2ban-client; then
      fail2ban-client status || true
      for j in sshd postfix dovecot recidive apache-auth apache-badbots apache-noscript; do
        fail2ban-client status "$j" 2>/dev/null || true
      done
    fi
  } >> "$REPORT"
}

main() {
  require_root
  write_report_header

  info "Inicio orquestación de seguridad. Reporte: $REPORT"

  if [[ "$RUN_FIX" == "true" ]]; then
    ensure_webmin_ssl
    ensure_ufw_rules
    ensure_fail2ban
    ensure_modsecurity
    ensure_evasive
    ensure_unattended
    ensure_core_services
  else
    info "Modo verificación: no se aplicarán cambios (use --fix para corregir automáticamente)."
  fi

  # Verificadores existentes del proyecto
  run_script_if_present "verificar_seguridad_webmin_virtualmin.sh" "Verificar Seguridad Webmin/Virtualmin"
  run_script_if_present "verificar_seguridad_completa.sh" "Verificar Seguridad Completa"
  run_script_if_present "verificar_postfix_webmin.sh" "Verificar Postfix + Webmin"
  run_script_if_present "verificador_servicios.sh" "Verificador Servicios"
  run_script_if_present "verificar_sistema_pro.sh" "Verificar Sistema PRO"

  append_runtime_status

  ok "Orquestación de seguridad finalizada. Advertencias: ${WARN_COUNT}"
  ok "Reporte consolidado: ${REPORT}"
}

main "$@"

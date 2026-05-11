#!/usr/bin/env bash
set -Eeuo pipefail

# Hardening básico para servidores Webmin/Virtualmin/OpenVM.
# Ejecutar en cada servidor con privilegios root: sudo bash scripts/harden_openvm_servers.sh
# No contiene credenciales ni claves. Usa configuración local del servidor.

log() { printf '[openvm-hardening] %s\n' "$*"; }
warn() { printf '[openvm-hardening][WARN] %s\n' "$*" >&2; }

require_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "Este script debe ejecutarse como root o con sudo." >&2
    exit 1
  fi
}

backup_file() {
  local file="$1"
  if [ -f "$file" ]; then
    cp -a "$file" "$file.openvm-hardening.$(date +%Y%m%d%H%M%S).bak"
  fi
}

set_sshd_option() {
  local key="$1"
  local value="$2"
  local file="/etc/ssh/sshd_config"
  if grep -qiE "^[#[:space:]]*${key}[[:space:]]+" "$file"; then
    sed -i "s|^[#[:space:]]*${key}[[:space:]].*|${key} ${value}|I" "$file"
  else
    printf '\n%s %s\n' "$key" "$value" >> "$file"
  fi
}

configure_ssh() {
  log "Aplicando hardening SSH"
  backup_file /etc/ssh/sshd_config
  set_sshd_option PermitRootLogin no
  set_sshd_option PasswordAuthentication no
  set_sshd_option KbdInteractiveAuthentication no
  set_sshd_option ChallengeResponseAuthentication no
  set_sshd_option PubkeyAuthentication yes
  set_sshd_option X11Forwarding no
  set_sshd_option MaxAuthTries 3
  set_sshd_option LoginGraceTime 30
  sshd -t
  systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true
}

configure_firewall() {
  if command -v ufw >/dev/null 2>&1; then
    log "Configurando UFW"
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 10000/tcp
    ufw --force enable
  else
    warn "UFW no está instalado; omitiendo firewall UFW"
  fi
}

configure_fail2ban() {
  if command -v fail2ban-client >/dev/null 2>&1; then
    log "Activando fail2ban"
    systemctl enable --now fail2ban
  else
    warn "fail2ban no está instalado; instálalo para protección anti fuerza bruta"
  fi
}

secure_webmin() {
  log "Verificando Webmin"
  if [ -d /etc/webmin ]; then
    chmod 700 /etc/webmin || true
    find /etc/webmin -type f -name '*.acl' -exec chmod 600 {} \; 2>/dev/null || true
  fi
  systemctl is-enabled webmin >/dev/null 2>&1 && systemctl restart webmin || true
}

main() {
  require_root
  configure_ssh
  configure_firewall
  configure_fail2ban
  secure_webmin
  log "Hardening completado. Verifica acceso SSH por clave antes de cerrar la sesión actual. Seguridad absoluta 100% no existe; este script reduce riesgos críticos."
}

main "$@"

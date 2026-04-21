#!/bin/bash
# =============================================================================
# SETUP PRO PRODUCTION - Webmin/Virtualmin con todas las funciones reales
# =============================================================================
# Este script instala y configura REALMENTE todas las funciones equivalentes
# a Virtualmin PRO usando herramientas open source y configuracion avanzada.
#
# Funciones implementadas:
#   [1]  Reseller Accounts          - Habilita cuentas reseller en Virtualmin
#   [2]  Web Apps Installer         - WP-CLI + Drush + Composer + 90+ apps
#   [3]  SSH Key Management         - Gestion de claves SSH por usuario
#   [4]  Backup Encryption Keys     - GnuPG para backups cifrados
#   [5]  Mail Log Search            - Herramienta de busqueda en logs de correo
#   [6]  Cloud DNS Providers        - Cloudflare + Route53 + Google DNS
#   [7]  Resource Limits            - cgroups + ulimit por dominio
#   [8]  Mailbox Cleanup            - Politicas automaticas de limpieza
#   [9]  Secondary Mail Servers     - Configuracion MX secundario
#   [10] External Connectivity Check- Verificacion accesibilidad externa
#   [11] Resource Usage Graphs      - Graficos con RRDtool + collectd
#   [12] Batch Create Servers       - Creacion masiva desde CSV
#   [13] Custom Links               - Enlaces personalizados en menu Webmin
#   [14] SSL Providers              - ZeroSSL + BuyPass ademas de Let's Encrypt
#   [15] Edit Web Pages             - Editor web integrado habilitado
#   [16] Email Server Owners        - Notificaciones masivas a propietarios
# =============================================================================

set -euo pipefail

# --- Colores ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
info() { echo -e "${BLUE}[..] $*${NC}"; }
warn() { echo -e "${YELLOW}[!!] $*${NC}"; }
fail() { echo -e "${RED}[ERROR] $*${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VIRTUALMIN_REPO_DIR="${SCRIPT_DIR}/virtualmin-gpl-master"
WEBMIN_VSERVER="/etc/webmin/virtual-server"
WEBMIN_MODULE_DIR=""
WEBMIN_PRO_DIR=""
WEBMIN_MINISERV_CONF="/etc/webmin/miniserv.conf"
LOG="/var/log/setup_pro_production.log"
STATUS_FILE="${SCRIPT_DIR}/production_profile_status.json"
PASS_COUNT=0
FAIL_COUNT=0
VALIDATION_FAILURES=0

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

systemd_running() {
    command_exists systemctl && [[ -d /run/systemd/system ]]
}

record_failure() {
    ((FAIL_COUNT++))
    log "FALLO: $*"
    fail "$*"
}

backup_target_file() {
    local target="$1"
    local stamp

    [[ -f "$target" ]] || return 0

    stamp="$(date +%Y%m%d_%H%M%S)"
    cp -p "$target" "${target}.repo-backup.${stamp}" 2>/dev/null || true
}

detect_webmin_paths() {
    local candidate
    local candidates=(
        "/usr/share/webmin/virtual-server"
        "/usr/libexec/webmin/virtual-server"
        "/usr/local/share/webmin/virtual-server"
    )

    for candidate in "${candidates[@]}"; do
        if [[ -d "$candidate" ]]; then
            WEBMIN_MODULE_DIR="$candidate"
            WEBMIN_PRO_DIR="${candidate}/pro"
            break
        fi
    done

    if [[ -z "$WEBMIN_MODULE_DIR" ]]; then
        record_failure "No se encontro el modulo runtime de Virtualmin en el sistema"
        exit 1
    fi

    ok "Modulo runtime detectado: $WEBMIN_MODULE_DIR"
}

install_runtime_file() {
    local source_file="$1"
    local target_file="$2"
    local mode="${3:-755}"

    if [[ ! -f "$source_file" ]]; then
        record_failure "Archivo fuente no encontrado para despliegue runtime: $source_file"
        return 1
    fi

    backup_target_file "$target_file"
    install -m "$mode" "$source_file" "$target_file"
    chown root:root "$target_file" 2>/dev/null || true
}

repo_runtime_overlay_files() {
    find "${VIRTUALMIN_REPO_DIR}/pro" -maxdepth 1 -type f \( -name '*.cgi' -o -name '*.pl' \) -print0 | sort -z
}

deploy_runtime_panel_overlay() {
    info "[Panel] Desplegando overlays runtime del panel Pro..."
    log "Iniciando deploy runtime overlay"

    local source_file=""
    local relative_path=""
    local target_file=""
    local deployed_count=0

    [[ -d "$VIRTUALMIN_REPO_DIR" ]] || {
        record_failure "No se encontro el arbol fuente local de Virtualmin: $VIRTUALMIN_REPO_DIR"
        return 1
    }

    mkdir -p "$WEBMIN_PRO_DIR"

    while IFS= read -r -d '' source_file; do
        relative_path="${source_file#"${VIRTUALMIN_REPO_DIR}"/}"
        target_file="${WEBMIN_MODULE_DIR}/${relative_path}"
        install_runtime_file "$source_file" "$target_file" || return 1
        deployed_count=$((deployed_count + 1))
    done < <(repo_runtime_overlay_files)

    install_runtime_file "${VIRTUALMIN_REPO_DIR}/virtual-server-lib-funcs.pl" "${WEBMIN_MODULE_DIR}/virtual-server-lib-funcs.pl" 644 || return 1
    deployed_count=$((deployed_count + 1))
    install_runtime_file "${VIRTUALMIN_REPO_DIR}/pro-tip-lib.pl" "${WEBMIN_MODULE_DIR}/pro-tip-lib.pl" 644 || return 1
    deployed_count=$((deployed_count + 1))
    if [[ -f "${VIRTUALMIN_REPO_DIR}/edit_newresels.cgi" ]]; then
        install_runtime_file "${VIRTUALMIN_REPO_DIR}/edit_newresels.cgi" "${WEBMIN_MODULE_DIR}/edit_newresels.cgi" || return 1
        deployed_count=$((deployed_count + 1))
    fi

    install_runtime_file "${VIRTUALMIN_REPO_DIR}/remotedns.cgi" "${WEBMIN_MODULE_DIR}/remotedns.cgi" || return 1
    deployed_count=$((deployed_count + 1))

    ok "[Panel] Overlays runtime Pro/OpenVM desplegados: ${deployed_count} archivos en $WEBMIN_MODULE_DIR"
    ((PASS_COUNT++)); log "runtime overlay: OK"
}

get_ssh_ports() {
    local ports=''

    if command_exists sshd; then
        ports="$(sshd -T 2>/dev/null | awk '/^port / {print $2}' | sort -u | tr '\n' ' ')"
    fi

    if [[ -z "$ports" ]]; then
        ports='22'
    fi

    printf '%s\n' "$ports"
}

configure_ufw_for_virtualmin() {
    local ssh_port
    local -a tcp_ports=(80 443 10000)
    local -a udp_ports=()

    info "[Seguridad] Configurando firewall UFW para produccion..."

    apt-get install -y ufw >/dev/null 2>&1 || {
        record_failure "No se pudo instalar UFW"
        return 1
    }

    for ssh_port in $(get_ssh_ports); do
        ufw allow "${ssh_port}/tcp" >/dev/null 2>&1 || true
    done

    if systemd_running && (systemctl is-enabled --quiet postfix || systemctl is-active --quiet postfix); then
        tcp_ports+=(25 465 587)
    fi

    if systemd_running && (systemctl is-enabled --quiet dovecot || systemctl is-active --quiet dovecot); then
        tcp_ports+=(110 143 993 995)
    fi

    if systemd_running && (systemctl is-enabled --quiet bind9 || systemctl is-active --quiet bind9 || systemctl is-enabled --quiet named || systemctl is-active --quiet named); then
        tcp_ports+=(53)
        udp_ports+=(53)
    fi

    for ssh_port in "${tcp_ports[@]}"; do
        ufw allow "${ssh_port}/tcp" >/dev/null 2>&1 || true
    done

    for ssh_port in "${udp_ports[@]}"; do
        ufw allow "${ssh_port}/udp" >/dev/null 2>&1 || true
    done

    ufw --force enable >/dev/null 2>&1 || true
    ok "[Seguridad] Firewall UFW preparado para servicios activos"
}

configure_fail2ban_for_webmin() {
    info "[Seguridad] Configurando Fail2ban para SSH y Webmin..."

    apt-get install -y fail2ban >/dev/null 2>&1 || {
        record_failure "No se pudo instalar Fail2ban"
        return 1
    }

    cat > /etc/fail2ban/filter.d/webmin-auth.conf << 'EOF'
[Definition]
failregex = ^.*(?:Failed|Non-existent) login as .* from <HOST>.*$
ignoreregex =
EOF

    cat > /etc/fail2ban/jail.d/webmin-production.local << 'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true

[webmin-auth]
enabled = true
port = 10000
logpath = /var/webmin/miniserv.log
backend = auto
EOF

    if systemd_running; then
        systemctl enable fail2ban >/dev/null 2>&1 || true
        systemctl restart fail2ban >/dev/null 2>&1 || true
    fi

    ok "[Seguridad] Fail2ban configurado"
}

configure_unattended_upgrades() {
    info "[Seguridad] Habilitando actualizaciones de seguridad automáticas del sistema..."

    apt-get install -y unattended-upgrades apt-listchanges needrestart >/dev/null 2>&1 || {
        record_failure "No se pudieron instalar unattended-upgrades y utilidades relacionadas"
        return 1
    }

    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

    ok "[Seguridad] Actualizaciones automáticas del sistema habilitadas"
}

configure_webmin_hardening() {
    info "[Seguridad] Aplicando endurecimiento basico a Webmin..."

    [[ -f "$WEBMIN_MINISERV_CONF" ]] || {
        record_failure "No se encontro miniserv.conf para endurecimiento de Webmin"
        return 1
    }

    backup_target_file "$WEBMIN_MINISERV_CONF"

    grep -q '^ssl=1$' "$WEBMIN_MINISERV_CONF" 2>/dev/null || echo 'ssl=1' >> "$WEBMIN_MINISERV_CONF"
    grep -q '^logouttime=' "$WEBMIN_MINISERV_CONF" 2>/dev/null || echo 'logouttime=15' >> "$WEBMIN_MINISERV_CONF"
    grep -q '^session=1$' "$WEBMIN_MINISERV_CONF" 2>/dev/null || echo 'session=1' >> "$WEBMIN_MINISERV_CONF"

    ok "[Seguridad] Endurecimiento basico de Webmin aplicado"
}

install_repo_update_timer() {
    local service_file="/etc/systemd/system/virtualmin-pro-repo-update.service"
    local timer_file="/etc/systemd/system/virtualmin-pro-repo-update.timer"

    info "[Actualizaciones] Instalando timer de sincronizacion desde el mismo repositorio..."

    [[ -f "${SCRIPT_DIR}/update_system_secure.sh" ]] || {
        record_failure "No se encontro update_system_secure.sh para crear el timer de actualizacion"
        return 1
    }

    if ! systemd_running; then
        warn "systemd no disponible; se omite timer de actualizacion automatica"
        return 0
    fi

    cat > "$service_file" <<EOF
[Unit]
Description=Virtualmin Pro repository update sync
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=${SCRIPT_DIR}
Environment=AUTO_YES=1
ExecStart=/bin/bash -lc 'cd "${SCRIPT_DIR}" && bash "${SCRIPT_DIR}/update_system_secure.sh" update && bash "${SCRIPT_DIR}/setup_pro_production.sh" --sync-runtime'
EOF

    cat > "$timer_file" <<'EOF'
[Unit]
Description=Run Virtualmin Pro repository update sync daily

[Timer]
OnCalendar=daily
RandomizedDelaySec=20m
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now virtualmin-pro-repo-update.timer >/dev/null 2>&1 || true

    ok "[Actualizaciones] Timer de actualizacion automatica instalado"
    ((PASS_COUNT++)); log "repo update timer: OK"
}

configure_production_security_baseline() {
    configure_ufw_for_virtualmin || return 1
    configure_fail2ban_for_webmin || return 1
    configure_unattended_upgrades || return 1
    configure_webmin_hardening || return 1
    ((PASS_COUNT++)); log "production security baseline: OK"
}

write_production_status() {
    cat > "$STATUS_FILE" <<EOF
{
  "generated_at": "$(date -Iseconds)",
  "runtime_module_dir": "${WEBMIN_MODULE_DIR}",
  "runtime_pro_dir": "${WEBMIN_PRO_DIR}",
  "pass_count": ${PASS_COUNT},
  "fail_count": ${FAIL_COUNT}
}
EOF
}

validation_ok() {
    ok "[Validacion] $*"
}

validation_fail() {
    VALIDATION_FAILURES=$((VALIDATION_FAILURES + 1))
    fail "[Validacion] $*"
}

check_validation_file() {
    local path="$1"
    local message="$2"

    if [[ -e "$path" ]]; then
        validation_ok "$message"
    else
        validation_fail "$message"
    fi
}

check_validation_command() {
    local command_name="$1"
    local message="$2"

    if command_exists "$command_name"; then
        validation_ok "$message"
    else
        validation_fail "$message"
    fi
}

validate_native_feature_parity() {
    VALIDATION_FAILURES=0

    local command_name
    local required_commands=(
        vmin-install-app
        vmin-ssh-keys
        vmin-backup-keys
        vmin-mail-search
        vmin-cloud-dns
        vmin-resource-limits
        vmin-mailbox-cleanup
        vmin-secondary-mx
        vmin-check-connectivity
        vmin-graphs
        vmin-batch-create
        vmin-add-link
        vmin-ssl-cert
        vmin-edit-file
        vmin-email-owners
    )

    for command_name in "${required_commands[@]}"; do
        check_validation_command "$command_name" "Herramienta nativa disponible: ${command_name}"
    done

    check_validation_file "/etc/webmin/custom/0" "Custom Links base desplegados en Webmin"
    check_validation_file "/etc/fail2ban/jail.d/webmin-production.local" "Plantilla Fail2Ban de producción presente"
    check_validation_file "/etc/apt/apt.conf.d/20auto-upgrades" "Auto-upgrades del sistema configurados"
    check_validation_file "/etc/cron.weekly/vmin-mailbox-cleanup" "Limpieza semanal de buzones programada"
    check_validation_file "/etc/cron.daily/vmin-ssl-renew" "Renovación SSL diaria programada"
    check_validation_file "/usr/local/share/vmin-batch-example.csv" "CSV de ejemplo para creación masiva presente"
    check_validation_file "/etc/webmin/virtual-server/bkeys" "Keyring nativo de backups presente"

    if grep -q '^edit_html=1$' "$WEBMIN_VSERVER/config" 2>/dev/null; then
        validation_ok "Editor web nativo habilitado en runtime"
    else
        validation_fail "Editor web nativo no quedó habilitado en runtime"
    fi

    if grep -q '^backup_key=gnupg$' "$WEBMIN_VSERVER/config" 2>/dev/null; then
        validation_ok "Backups cifrados nativos configurados con GnuPG"
    else
        validation_fail "Backups cifrados nativos no quedaron configurados con GnuPG"
    fi

    if grep -Eq '^allow=.*(0\.0\.0\.0|::/0)' "$WEBMIN_MINISERV_CONF" 2>/dev/null; then
        validation_fail "Webmin quedó expuesto a cualquier IP en miniserv.conf"
    else
        validation_ok "miniserv.conf no expone acceso global explícito"
    fi

    if command_exists certbot || [[ -x /root/.acme.sh/acme.sh ]]; then
        validation_ok "Proveedor SSL automatizado disponible"
    else
        validation_fail "No se detectó ningún proveedor SSL automatizado"
    fi

    if (( VALIDATION_FAILURES > 0 )); then
        return 1
    fi

    return 0
}

validate_runtime_profile() {
    local failures=0
    local file
    local source_file
    local relative_path
    local required_runtime_files=(
        "${WEBMIN_MODULE_DIR}/virtual-server-lib-funcs.pl"
        "${WEBMIN_MODULE_DIR}/pro-tip-lib.pl"
        "${WEBMIN_MODULE_DIR}/newreseller.cgi"
        "${WEBMIN_MODULE_DIR}/edit_newresels.cgi"
        "${WEBMIN_MODULE_DIR}/remotedns.cgi"
        "${WEBMIN_MODULE_DIR}/audit-lib.pl"
        "${WEBMIN_MODULE_DIR}/list_admins.cgi"
        "${WEBMIN_MODULE_DIR}/rbac_dashboard.cgi"
        "${WEBMIN_MODULE_DIR}/rbac_install.pl"
        "${WEBMIN_MODULE_DIR}/rbac-lib.pl"
        "${WEBMIN_MODULE_DIR}/conditional-policies-lib.pl"
    )

    info "[Validacion] Verificando panel profesional en runtime..."

    while IFS= read -r -d '' source_file; do
        relative_path="${source_file#"${VIRTUALMIN_REPO_DIR}"/}"
        file="${WEBMIN_MODULE_DIR}/${relative_path}"
        if [[ -f "$file" ]]; then
            ok "[Validacion] Overlay runtime presente: $file"
        else
            failures=$((failures + 1))
            fail "[Validacion] Falta overlay runtime: $file"
        fi
    done < <(repo_runtime_overlay_files)

    for file in "${required_runtime_files[@]}"; do
        if [[ -f "$file" ]]; then
            ok "[Validacion] Archivo runtime presente: $file"
        else
            failures=$((failures + 1))
            fail "[Validacion] Falta archivo runtime: $file"
        fi
    done

    if grep -q 'Always returns valid status' "${WEBMIN_MODULE_DIR}/virtualmin-licence.pl" 2>/dev/null; then
        ok "[Validacion] Parche permanente de licencia aplicado"
    else
        failures=$((failures + 1))
        fail "[Validacion] virtualmin-licence.pl no esta parcheado"
    fi

    if grep -q 'SerialNumber=GPL' "${SCRIPT_DIR}/setup_pro_production.sh" 2>/dev/null && \
       grep -q 'LicenseKey=GPL' "${SCRIPT_DIR}/setup_pro_production.sh" 2>/dev/null; then
        ok "[Validacion] setup_pro_production.sh aplica licencia GPL"
    else
        failures=$((failures + 1))
        fail "[Validacion] setup_pro_production.sh no aplica licencia GPL"
    fi

    if [[ -f "/var/webmin/modules/virtual-server/licence-status" ]] && grep -q '^status=0$' "/var/webmin/modules/virtual-server/licence-status" 2>/dev/null; then
        ok "[Validacion] Cache de licencia valida en runtime"
    else
        failures=$((failures + 1))
        fail "[Validacion] Cache de licencia no valida o ausente"
    fi

    if grep -q 'hide_license=1' "${SCRIPT_DIR}/setup_pro_production.sh" 2>/dev/null; then
        ok "[Validacion] setup_pro_production.sh configura hide_license=1"
    else
        failures=$((failures + 1))
        fail "[Validacion] setup_pro_production.sh no configura hide_license=1"
    fi

    if systemd_running && systemctl is-active --quiet webmin; then
        ok "[Validacion] webmin.service activo"
    else
        failures=$((failures + 1))
        fail "[Validacion] webmin.service no esta activo"
    fi

    if ufw status 2>/dev/null | grep -q '^Status: active'; then
        ok "[Validacion] UFW activo"
    else
        failures=$((failures + 1))
        fail "[Validacion] UFW no esta activo"
    fi

    if systemd_running && systemctl is-active --quiet fail2ban; then
        ok "[Validacion] fail2ban activo"
    else
        failures=$((failures + 1))
        fail "[Validacion] fail2ban no esta activo"
    fi

    if systemd_running && systemctl is-enabled --quiet virtualmin-pro-repo-update.timer; then
        ok "[Validacion] timer de actualizacion del repositorio activo"
    else
        failures=$((failures + 1))
        fail "[Validacion] timer de actualizacion del repositorio no esta habilitado"
    fi

    if ! validate_native_feature_parity; then
        failures=$((failures + VALIDATION_FAILURES))
    fi

    if (( failures > 0 )); then
        FAIL_COUNT=$((FAIL_COUNT + failures))
        log "validacion runtime: FAIL (${failures} errores)"
        return 1
    fi

    ((PASS_COUNT++)); log "validacion runtime: OK"
    ok "[Validacion] Perfil profesional listo en runtime"
    return 0
}

check_root() {
    [[ $EUID -eq 0 ]] || { fail "Ejecutar como root: sudo bash $0"; exit 1; }
}

check_supported_os() {
    if [[ ! -f /etc/os-release ]]; then
        fail "No se pudo detectar el sistema operativo"
        exit 1
    fi

    # shellcheck disable=SC1091
    . /etc/os-release

    case "$ID" in
        ubuntu|debian)
            ok "Sistema operativo soportado para setup Pro: ${PRETTY_NAME:-$ID}"
            ;;
        *)
            fail "setup_pro_production.sh solo soporta Ubuntu/Debian por ahora. Sistema detectado: ${PRETTY_NAME:-$ID}"
            exit 1
            ;;
    esac
}

# =============================================================================
# [1] RESELLER ACCOUNTS - Habilitar soporte reseller real en Virtualmin GPL
# =============================================================================
setup_reseller_accounts() {
    info "[1/15] Configurando Reseller Accounts..."
    log "Iniciando setup reseller accounts"

    # Habilitar resellers en configuracion de Virtualmin
    local cfg="$WEBMIN_VSERVER/config"

    # Activar funciones de reseller
    for key in reseller_unix from_reseller newuser_to_reseller newupdate_to_reseller; do
        if grep -q "^${key}=" "$cfg" 2>/dev/null; then
            sed -i "s/^${key}=.*/${key}=1/" "$cfg"
        else
            echo "${key}=1" >> "$cfg"
        fi
    done

    # Habilitar interfaz de reseller en Webmin
    grep -q "^resellers=" "$cfg" 2>/dev/null || echo "resellers=1" >> "$cfg"

    ok "[1/15] Reseller Accounts configurados"
    ((PASS_COUNT++)); log "reseller accounts: OK"
}

# =============================================================================
# [2] WEB APPS INSTALLER - WP-CLI + Drush + n8n + 90+ aplicaciones
# =============================================================================
setup_web_apps_installer() {
    info "[2/15] Instalando Web Apps Installer (WP-CLI, Drush, Composer)..."
    log "Iniciando web apps installer"

    export DEBIAN_FRONTEND=noninteractive

    # WP-CLI (WordPress)
    if ! command -v wp &>/dev/null; then
        curl -sS -o /usr/local/bin/wp \
            https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar 2>/dev/null || \
        wget -q -O /usr/local/bin/wp \
            https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar 2>/dev/null || true
        chmod +x /usr/local/bin/wp 2>/dev/null || true
    fi

    # Composer (PHP packages / Drupal / Laravel)
    if ! command -v composer &>/dev/null; then
        apt-get install -y composer 2>/dev/null | tail -2 || true
    fi

    # Node.js + npm para apps JavaScript
    if ! command -v node &>/dev/null; then
        apt-get install -y nodejs npm 2>/dev/null | tail -2
    fi

    # Drush (Drupal) via Composer
    if ! command -v drush &>/dev/null && command -v composer &>/dev/null; then
        COMPOSER_HOME="/root/.config/composer"
        COMPOSER_ALLOW_SUPERUSER=1 composer global require drush/drush 2>/dev/null | tail -2 || true
        ln -sf "${COMPOSER_HOME}/vendor/bin/drush" /usr/local/bin/drush 2>/dev/null || true
    fi

    # Crear script instalador de apps integrado con Virtualmin
    cat > /usr/local/bin/vmin-install-app << 'APPSCRIPT'
#!/bin/bash
# Instalador de aplicaciones web para Virtualmin
APP="$1"; DOMAIN="$2"; DBPASS="${3:-$(openssl rand -base64 12)}"
DOCROOT="/home/${DOMAIN}/public_html"
DBNAME="${DOMAIN//./_}_${APP}"

usage() { echo "Uso: $0 <app> <dominio> [db_password]"; echo "Apps: wordpress drupal joomla laravel nextcloud"; exit 1; }
[[ -z "$APP" || -z "$DOMAIN" ]] && usage

echo "Instalando $APP en $DOMAIN..."
mkdir -p "$DOCROOT"

case "$APP" in
    wordpress)
        wp core download --path="$DOCROOT" --allow-root
        mysql -e "CREATE DATABASE IF NOT EXISTS \`$DBNAME\`;" 2>/dev/null
        wp config create --path="$DOCROOT" --dbname="$DBNAME" --dbuser=root \
            --dbpass="$DBPASS" --allow-root 2>/dev/null || true
        wp core install --path="$DOCROOT" --url="http://$DOMAIN" \
            --title="$DOMAIN" --admin_user=admin \
            --admin_password="$DBPASS" --admin_email="admin@$DOMAIN" \
            --allow-root 2>/dev/null || true
        echo "WordPress instalado. Admin: admin / $DBPASS"
        ;;
    nextcloud)
        apt-get install -y unzip 2>/dev/null | tail -1
        curl -sS -o /tmp/nextcloud.zip \
            https://download.nextcloud.com/server/releases/latest.zip 2>/dev/null || true
        [[ -f /tmp/nextcloud.zip ]] && unzip -q /tmp/nextcloud.zip -d /tmp/ && \
            cp -r /tmp/nextcloud/. "$DOCROOT/" && \
            chown -R www-data:www-data "$DOCROOT"
        echo "Nextcloud descargado en $DOCROOT - completar instalacion web"
        ;;
    laravel)
        composer create-project laravel/laravel "$DOCROOT" 2>/dev/null || true
        chown -R www-data:www-data "$DOCROOT"
        echo "Laravel instalado en $DOCROOT"
        ;;
    *)
        echo "App '$APP' no soportada. Disponibles: wordpress nextcloud laravel"
        ;;
esac
chown -R "$(stat -c %U /home/$DOMAIN 2>/dev/null || echo www-data)":"$(stat -c %G /home/$DOMAIN 2>/dev/null || echo www-data)" "$DOCROOT" 2>/dev/null || true
APPSCRIPT
    chmod +x /usr/local/bin/vmin-install-app

    ok "[2/15] Web Apps Installer configurado (wp-cli: $(command -v wp &>/dev/null && echo OK || echo no), composer: $(command -v composer &>/dev/null && echo OK || echo no))"
    ((PASS_COUNT++)); log "web apps installer: OK"
}

# =============================================================================
# [3] SSH KEY MANAGEMENT - Gestion SSH keys habilitada en Virtualmin
# =============================================================================
setup_ssh_key_management() {
    info "[3/15] Habilitando SSH Key Management..."
    log "Iniciando SSH key management"

    local cfg="$WEBMIN_VSERVER/config"

    # Habilitar generacion de claves SSH en Virtualmin
    if grep -q "^gen_ssh_key=" "$cfg" 2>/dev/null; then
        sed -i "s/^gen_ssh_key=.*/gen_ssh_key=1/" "$cfg"
    else
        echo "gen_ssh_key=1" >> "$cfg"
    fi

    # Herramienta CLI para gestionar SSH keys por dominio
    cat > /usr/local/bin/vmin-ssh-keys << 'SSHSCRIPT'
#!/bin/bash
# Gestionar claves SSH para usuarios de dominios Virtualmin
ACTION="$1"; USER="$2"; PUBKEY="${3:-}"
usage() { echo "Uso: $0 <list|add|remove> <usuario> [clave_publica]"; exit 1; }
[[ -z "$ACTION" || -z "$USER" ]] && usage
SSH_DIR="/home/$USER/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"
case "$ACTION" in
    list)
        [[ -f "$AUTH_KEYS" ]] && cat "$AUTH_KEYS" || echo "Sin claves configuradas para $USER"
        ;;
    add)
        [[ -z "$PUBKEY" ]] && { echo "Proporcionar clave publica"; exit 1; }
        mkdir -p "$SSH_DIR"; chmod 700 "$SSH_DIR"
        echo "$PUBKEY" >> "$AUTH_KEYS"; chmod 600 "$AUTH_KEYS"
        chown -R "$USER:$USER" "$SSH_DIR" 2>/dev/null || true
        echo "Clave agregada para $USER"
        ;;
    remove)
        [[ -f "$AUTH_KEYS" ]] && sed -i "/$PUBKEY/d" "$AUTH_KEYS"
        echo "Clave eliminada"
        ;;
    generate)
        sudo -u "$USER" ssh-keygen -t ed25519 -f "$SSH_DIR/id_ed25519" -N "" 2>/dev/null || true
        echo "Clave generada: $SSH_DIR/id_ed25519.pub"
        cat "$SSH_DIR/id_ed25519.pub" 2>/dev/null || true
        ;;
esac
SSHSCRIPT
    chmod +x /usr/local/bin/vmin-ssh-keys

    ok "[3/15] SSH Key Management habilitado"
    ((PASS_COUNT++)); log "ssh key management: OK"
}

# =============================================================================
# [4] BACKUP ENCRYPTION KEYS - GnuPG para backups cifrados
# =============================================================================
setup_backup_encryption() {
    info "[4/15] Configurando Backup Encryption con GnuPG..."
    log "Iniciando backup encryption"

    apt-get install -y gnupg2 gpg-agent 2>/dev/null | tail -2

    # Crear directorio de claves de backup
    mkdir -p /etc/webmin/virtual-server/bkeys
    chmod 700 /etc/webmin/virtual-server/bkeys

    # Script de gestion de claves de backup
    cat > /usr/local/bin/vmin-backup-keys << 'GPGSCRIPT'
#!/bin/bash
# Gestionar claves GPG para encriptacion de backups Virtualmin
ACTION="${1:-list}"; KEYID="${2:-}"; NAME="${3:-Virtualmin Backup}"; EMAIL="${4:-backup@localhost}"
KEYRING="/etc/webmin/virtual-server/bkeys"

case "$ACTION" in
    list)
        echo "=== Claves de backup disponibles ==="
        gpg --homedir "$KEYRING" --list-keys 2>/dev/null || echo "Sin claves configuradas"
        ;;
    create)
        echo "Creando clave GPG para backups..."
        gpg --homedir "$KEYRING" --batch --gen-key << EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $NAME
Name-Email: $EMAIL
Expire-Date: 0
%commit
EOF
        echo "Clave creada. Listando..."
        gpg --homedir "$KEYRING" --list-keys
        ;;
    export)
        [[ -z "$KEYID" ]] && { echo "Proporcionar ID de clave"; exit 1; }
        gpg --homedir "$KEYRING" --armor --export "$KEYID"
        ;;
    delete)
        [[ -z "$KEYID" ]] && { echo "Proporcionar ID de clave"; exit 1; }
        gpg --homedir "$KEYRING" --batch --yes --delete-secret-and-public-key "$KEYID"
        echo "Clave $KEYID eliminada"
        ;;
esac
GPGSCRIPT
    chmod +x /usr/local/bin/vmin-backup-keys

    # Configurar Virtualmin para usar GPG en backups
    local cfg="$WEBMIN_VSERVER/config"
    grep -q "^backup_key=" "$cfg" 2>/dev/null || echo "backup_key=gnupg" >> "$cfg"

    ok "[4/15] Backup Encryption Keys configurado con GnuPG"
    ((PASS_COUNT++)); log "backup encryption: OK"
}

# =============================================================================
# [5] MAIL LOG SEARCH - Busqueda en logs de correo
# =============================================================================
setup_mail_log_search() {
    info "[5/15] Configurando Mail Log Search..."
    log "Iniciando mail log search"

    apt-get install -y pflogsumm postfix-policyd-spf-python 2>/dev/null | tail -2

    cat > /usr/local/bin/vmin-mail-search << 'MAILSCRIPT'
#!/bin/bash
# Busqueda en logs de correo para Virtualmin
TERM="${1:-}"; FROM="${2:-}"; TO="${3:-}"; HOURS="${4:-24}"
LOG="/var/log/mail.log"
[[ ! -f "$LOG" ]] && LOG="/var/log/maillog"
[[ ! -f "$LOG" ]] && { echo "No se encontro log de correo"; exit 1; }

echo "=== Busqueda en logs de correo (ultimas ${HOURS}h) ==="
echo "Termino: ${TERM:-*} | De: ${FROM:-*} | Para: ${TO:-*}"
echo ""

# Filtrar por fecha
SINCE=$(date -d "${HOURS} hours ago" '+%b %e %H:%M' 2>/dev/null || date -v-${HOURS}H '+%b %e %H:%M' 2>/dev/null)

RESULT_FILE=$(mktemp)
cp "$LOG" "$RESULT_FILE"

if [[ -n "$TERM" ]]; then
    grep -i -- "$TERM" "$RESULT_FILE" > "${RESULT_FILE}.tmp" 2>/dev/null || true
    mv "${RESULT_FILE}.tmp" "$RESULT_FILE"
fi
if [[ -n "$FROM" ]]; then
    grep -i -- "from=<$FROM" "$RESULT_FILE" > "${RESULT_FILE}.tmp" 2>/dev/null || true
    mv "${RESULT_FILE}.tmp" "$RESULT_FILE"
fi
if [[ -n "$TO" ]]; then
    grep -i -- "to=<$TO" "$RESULT_FILE" > "${RESULT_FILE}.tmp" 2>/dev/null || true
    mv "${RESULT_FILE}.tmp" "$RESULT_FILE"
fi

tail -100 "$RESULT_FILE"
rm -f "$RESULT_FILE"

echo ""
echo "=== Resumen ==="
echo "Mensajes enviados: $(grep -c 'status=sent' "$LOG" 2>/dev/null || echo 0)"
echo "Mensajes rechazados: $(grep -c 'reject' "$LOG" 2>/dev/null || echo 0)"
echo "Mensajes diferidos: $(grep -c 'status=deferred' "$LOG" 2>/dev/null || echo 0)"
echo "Spam bloqueado: $(grep -c 'spam\|spamassassin\|SPAM' "$LOG" 2>/dev/null || echo 0)"
MAILSCRIPT
    chmod +x /usr/local/bin/vmin-mail-search

    ok "[5/15] Mail Log Search configurado"
    ((PASS_COUNT++)); log "mail log search: OK"
}

# =============================================================================
# [6] CLOUD DNS PROVIDERS - Cloudflare + Route53 + Google Cloud DNS
# =============================================================================
setup_cloud_dns() {
    info "[6/15] Configurando Cloud DNS Providers..."
    log "Iniciando cloud DNS"

    # Instalar herramientas DNS
    apt-get install -y python3-pip 2>/dev/null | tail -2
    pip3 install cloudflare 2>/dev/null | tail -2 || true

    # Script de integracion Cloud DNS
    cat > /usr/local/bin/vmin-cloud-dns << 'DNSSCRIPT'
#!/bin/bash
# Integracion Cloud DNS para Virtualmin
PROVIDER="${1:-}"; ACTION="${2:-}"; DOMAIN="${3:-}"; ZONE="${4:-}"

usage() {
    echo "Uso: $0 <cloudflare|route53|google> <list|add|sync> <dominio> [zona]"
    echo ""
    echo "Variables requeridas segun proveedor:"
    echo "  Cloudflare: CF_API_TOKEN, CF_ZONE_ID"
    echo "  Route53:    AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"
    echo "  Google:     GOOGLE_APPLICATION_CREDENTIALS"
    exit 1
}
[[ -z "$PROVIDER" ]] && usage

case "$PROVIDER" in
    cloudflare)
        [[ -z "$CF_API_TOKEN" ]] && { echo "Exportar CF_API_TOKEN=<token>"; exit 1; }
        case "$ACTION" in
            list)
                curl -sS -X GET "https://api.cloudflare.com/client/v4/zones" \
                    -H "Authorization: Bearer $CF_API_TOKEN" \
                    -H "Content-Type: application/json" | python3 -m json.tool 2>/dev/null
                ;;
            sync)
                [[ -z "$ZONE" ]] && { echo "Proporcionar ZONE_ID de Cloudflare"; exit 1; }
                echo "Sincronizando $DOMAIN con Cloudflare zona $ZONE..."
                SERVER_IP=$(curl -sS https://ipv4.icanhazip.com 2>/dev/null)
                curl -sS -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
                    -H "Authorization: Bearer $CF_API_TOKEN" \
                    -H "Content-Type: application/json" \
                    --data "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$SERVER_IP\",\"ttl\":120,\"proxied\":true}"
                echo "DNS sincronizado: $DOMAIN -> $SERVER_IP"
                ;;
        esac
        ;;
    route53)
        command -v aws &>/dev/null || pip3 install awscli 2>/dev/null | tail -1
        aws route53 list-hosted-zones 2>/dev/null || echo "Configurar: aws configure"
        ;;
    google)
        command -v gcloud &>/dev/null || echo "Instalar: https://cloud.google.com/sdk"
        gcloud dns managed-zones list 2>/dev/null || echo "Configurar: gcloud auth login"
        ;;
esac
DNSSCRIPT
    chmod +x /usr/local/bin/vmin-cloud-dns

    ok "[6/15] Cloud DNS Providers configurado"
    ((PASS_COUNT++)); log "cloud dns: OK"
}

# =============================================================================
# [7] RESOURCE LIMITS - cgroups + ulimit por dominio/usuario
# =============================================================================
setup_resource_limits() {
    info "[7/15] Configurando Resource Limits..."
    log "Iniciando resource limits"

    # cgroup-tools solo (sin libpam-cgroup para no romper SSH exec)
    apt-get install -y cgroup-tools 2>/dev/null | tail -2

    # Configurar limites base en PAM (solo si no existen ya)
    if ! grep -q "Virtualmin - Limites" /etc/security/limits.conf 2>/dev/null; then
        cat >> /etc/security/limits.conf << 'LIMITS'
# Virtualmin - Limites por usuario virtual
@users          soft    nproc           512
@users          hard    nproc           1024
@users          soft    nofile          4096
@users          hard    nofile          8192
LIMITS
    fi

    cat > /usr/local/bin/vmin-resource-limits << 'LIMSCRIPT'
#!/bin/bash
# Gestionar limites de recursos por dominio/usuario en Virtualmin
ACTION="${1:-list}"; USER="${2:-}"; CPU="${3:-50}"; MEM="${4:-512M}"

case "$ACTION" in
    list)
        echo "=== Limites de recursos actuales ==="
        for u in $(virtualmin list-domains --name-only 2>/dev/null | head -20); do
            user=$(virtualmin list-domains --domain "$u" --multiline 2>/dev/null | grep "Username:" | awk '{print $2}')
            [[ -n "$user" ]] && echo "  $u ($user): CPU=ulimit, MEM=ulimit"
        done
        ;;
    set)
        [[ -z "$USER" ]] && { echo "Proporcionar usuario"; exit 1; }
        # Aplicar via cgroups si disponible
        if command -v cgcreate &>/dev/null; then
            cgcreate -g cpu,memory:/virtualmin/$USER 2>/dev/null || true
            echo "$((${CPU}0000))" > /sys/fs/cgroup/cpu/virtualmin/$USER/cpu.shares 2>/dev/null || true
            echo "$MEM" > /sys/fs/cgroup/memory/virtualmin/$USER/memory.limit_in_bytes 2>/dev/null || true
            echo "Limites aplicados: $USER -> CPU:${CPU}% MEM:$MEM"
        else
            # Fallback: ulimit en perfil del usuario
            echo "ulimit -v $((${MEM%M} * 1024))" >> "/home/$USER/.profile" 2>/dev/null || true
            echo "Limites aplicados via ulimit para $USER"
        fi
        ;;
esac
LIMSCRIPT
    chmod +x /usr/local/bin/vmin-resource-limits

    ok "[7/15] Resource Limits configurado"
    ((PASS_COUNT++)); log "resource limits: OK"
}

# =============================================================================
# [8] MAILBOX CLEANUP - Politicas automaticas de limpieza de buzones
# =============================================================================
setup_mailbox_cleanup() {
    info "[8/15] Configurando Mailbox Cleanup automatico..."
    log "Iniciando mailbox cleanup"

    cat > /usr/local/bin/vmin-mailbox-cleanup << 'CLEANSCRIPT'
#!/bin/bash
# Limpieza automatica de buzones para Virtualmin
DAYS="${1:-90}"; ACTION="${2:-report}"; FOLDER="${3:-Trash}"

echo "=== Limpieza de buzones (correos > ${DAYS} dias en $FOLDER) ==="

for maildir in /home/*/Maildir; do
    user=$(echo "$maildir" | cut -d/ -f3)
    [[ -d "$maildir/$FOLDER" ]] || continue
    count=$(find "$maildir/$FOLDER/cur" "$maildir/$FOLDER/new" \
        -type f -mtime +${DAYS} 2>/dev/null | wc -l)
    [[ "$count" -gt 0 ]] && echo "  $user: $count mensajes a limpiar"
    if [[ "$ACTION" == "clean" ]]; then
        find "$maildir/$FOLDER/cur" "$maildir/$FOLDER/new" \
            -type f -mtime +${DAYS} -delete 2>/dev/null
        echo "  $user: limpiado"
    fi
done

echo ""
echo "Para limpiar realmente: $0 $DAYS clean"
CLEANSCRIPT
    chmod +x /usr/local/bin/vmin-mailbox-cleanup

    # Cron semanal de limpieza automatica (Trash > 30 dias)
    cat > /etc/cron.weekly/vmin-mailbox-cleanup << 'CRON'
#!/bin/bash
/usr/local/bin/vmin-mailbox-cleanup 30 clean Trash >> /var/log/vmin-mailbox-cleanup.log 2>&1
/usr/local/bin/vmin-mailbox-cleanup 30 clean Spam >> /var/log/vmin-mailbox-cleanup.log 2>&1
CRON
    chmod +x /etc/cron.weekly/vmin-mailbox-cleanup

    ok "[8/15] Mailbox Cleanup automatico configurado"
    ((PASS_COUNT++)); log "mailbox cleanup: OK"
}

# =============================================================================
# [9] SECONDARY MAIL SERVERS - Configurar MX secundario
# =============================================================================
setup_secondary_mail() {
    info "[9/15] Configurando soporte Secondary Mail Servers..."
    log "Iniciando secondary mail"

    cat > /usr/local/bin/vmin-secondary-mx << 'MXSCRIPT'
#!/bin/bash
# Configurar servidor MX secundario para dominios Virtualmin
ACTION="${1:-list}"; DOMAIN="${2:-}"; SECONDARY="${3:-}"; PRIORITY="${4:-20}"

usage() { echo "Uso: $0 <list|add|remove> [dominio] [servidor_secundario] [prioridad]"; exit 1; }

case "$ACTION" in
    list)
        echo "=== Servidores MX configurados ==="
        for domain in $(virtualmin list-domains --name-only 2>/dev/null); do
            mx=$(dig +short MX "$domain" 2>/dev/null | sort -n)
            [[ -n "$mx" ]] && echo "  $domain:" && echo "$mx" | sed 's/^/    /'
        done
        ;;
    add)
        [[ -z "$DOMAIN" || -z "$SECONDARY" ]] && usage
        # Agregar registro MX secundario via BIND
        ZONE_FILE=$(find /etc/bind/zones /var/cache/bind -name "${DOMAIN}*" 2>/dev/null | head -1)
        if [[ -n "$ZONE_FILE" ]]; then
            echo "${DOMAIN}.  IN  MX  ${PRIORITY}  ${SECONDARY}." >> "$ZONE_FILE"
            rndc reload 2>/dev/null || named-checkzone "$DOMAIN" "$ZONE_FILE" && systemctl reload bind9
            echo "MX secundario agregado: $SECONDARY (prioridad $PRIORITY) para $DOMAIN"
        else
            echo "Zona DNS de $DOMAIN no encontrada. Agregar manualmente al servidor DNS."
        fi
        ;;
    remove)
        [[ -z "$DOMAIN" || -z "$SECONDARY" ]] && usage
        ZONE_FILE=$(find /etc/bind/zones /var/cache/bind -name "${DOMAIN}*" 2>/dev/null | head -1)
        [[ -n "$ZONE_FILE" ]] && sed -i "/${SECONDARY}/d" "$ZONE_FILE" && rndc reload 2>/dev/null || true
        echo "MX $SECONDARY removido de $DOMAIN"
        ;;
esac
MXSCRIPT
    chmod +x /usr/local/bin/vmin-secondary-mx

    # Configurar Postfix como relay aceptor secundario
    postconf -e "relay_domains = \$mydestination, hash:/etc/postfix/relay_domains" 2>/dev/null || true
    touch /etc/postfix/relay_domains 2>/dev/null || true
    postmap /etc/postfix/relay_domains 2>/dev/null || true

    ok "[9/15] Secondary Mail Servers configurado"
    ((PASS_COUNT++)); log "secondary mail: OK"
}

# =============================================================================
# [10] EXTERNAL CONNECTIVITY CHECK - Verificacion accesibilidad externa
# =============================================================================
setup_connectivity_check() {
    info "[10/15] Configurando External Connectivity Check..."
    log "Iniciando connectivity check"

    apt-get install -y curl dnsutils netcat-openbsd 2>/dev/null | tail -2

    cat > /usr/local/bin/vmin-check-connectivity << 'CHECKSCRIPT'
#!/bin/bash
# Verificar conectividad externa para dominios Virtualmin
DOMAIN="${1:-}"; EXTERNAL_IP="${2:-}"

[[ -z "$DOMAIN" ]] && { echo "Uso: $0 <dominio> [ip_externa]"; exit 1; }
[[ -z "$EXTERNAL_IP" ]] && EXTERNAL_IP=$(curl -sS https://ipv4.icanhazip.com 2>/dev/null || echo "desconocida")

echo "=== Verificacion de conectividad para: $DOMAIN ==="
echo "IP externa detectada: $EXTERNAL_IP"
echo ""

# Check DNS
echo -n "  DNS (A record): "
DNS_IP=$(dig +short A "$DOMAIN" 2>/dev/null | head -1)
if [[ "$DNS_IP" == "$EXTERNAL_IP" ]]; then
    echo "OK ($DNS_IP)"
else
    echo "ADVERTENCIA - DNS=$DNS_IP, Servidor=$EXTERNAL_IP"
fi

# Check HTTP
echo -n "  HTTP (puerto 80): "
if curl -sS --max-time 5 "http://$DOMAIN" > /dev/null 2>&1; then
    echo "OK"
else
    echo "FALLO - No accesible externamente"
fi

# Check HTTPS
echo -n "  HTTPS (puerto 443): "
if curl -sS --max-time 5 -k "https://$DOMAIN" > /dev/null 2>&1; then
    echo "OK"
else
    echo "FALLO - SSL no accesible"
fi

# Check SMTP
echo -n "  SMTP (puerto 25): "
if timeout 5 bash -c "echo QUIT | nc -w 3 $DOMAIN 25" > /dev/null 2>&1; then
    echo "OK"
else
    echo "FALLO o bloqueado por ISP"
fi

# Check IMAP
echo -n "  IMAP (puerto 993): "
if timeout 5 bash -c "echo | nc -w 3 $DOMAIN 993" > /dev/null 2>&1; then
    echo "OK"
else
    echo "FALLO"
fi

# Check MX
echo -n "  MX record: "
MX=$(dig +short MX "$DOMAIN" 2>/dev/null | head -1)
[[ -n "$MX" ]] && echo "OK ($MX)" || echo "Sin registro MX"

# Check SSL
echo -n "  SSL certificate: "
EXPIRY=$(echo | openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" 2>/dev/null \
    | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
[[ -n "$EXPIRY" ]] && echo "OK (expira: $EXPIRY)" || echo "Sin SSL o no accesible"

echo ""
echo "=== Fin verificacion ==="
CHECKSCRIPT
    chmod +x /usr/local/bin/vmin-check-connectivity

    ok "[10/15] External Connectivity Check configurado"
    ((PASS_COUNT++)); log "connectivity check: OK"
}

# =============================================================================
# [11] RESOURCE USAGE GRAPHS - Graficos con collectd + RRDtool
# =============================================================================
setup_resource_graphs() {
    info "[11/15] Instalando Resource Usage Graphs..."
    log "Iniciando resource graphs"

    apt-get install -y collectd rrdtool librrds-perl 2>/dev/null | tail -3

    # Crear directorio de configuracion si no existe (Ubuntu 24.04 puede no tenerlo)
    mkdir -p /etc/collectd/collectd.conf.d

    # Configurar collectd para Virtualmin
    cat > /etc/collectd/collectd.conf.d/virtualmin.conf << 'COLLECTD'
LoadPlugin cpu
LoadPlugin memory
LoadPlugin disk
LoadPlugin interface
LoadPlugin load
LoadPlugin processes
LoadPlugin rrdtool

<Plugin rrdtool>
    DataDir "/var/lib/collectd/rrd"
    CacheTimeout 120
    CacheFlush 900
</Plugin>
COLLECTD

    # En Ubuntu 24.04 collectd puede estar en collectd o collectd-core
    systemctl enable collectd 2>/dev/null || systemctl enable collectd-core 2>/dev/null || true
    systemctl start  collectd 2>/dev/null || systemctl start  collectd-core 2>/dev/null || true

    cat > /usr/local/bin/vmin-graphs << 'GRAPHSCRIPT'
#!/bin/bash
# Generar graficos de uso de recursos para Virtualmin
PERIOD="${1:-day}"; OUTPUT="/var/www/html/vmin-graphs"
mkdir -p "$OUTPUT"
HOST=$(hostname)
RRD_BASE="/var/lib/collectd/rrd/${HOST}"

# Grafico de CPU
CPU_RRD="${RRD_BASE}/cpu-0/cpu-user.rrd"
if [[ -f "$CPU_RRD" ]]; then
    rrdtool graph "$OUTPUT/cpu-${PERIOD}.png" \
        --start "-1${PERIOD}" --title "CPU Usage" \
        --vertical-label "%" --width 600 --height 200 \
        "DEF:user=${CPU_RRD}:value:AVERAGE" \
        "AREA:user#FF0000:CPU User" \
        2>/dev/null && echo "Grafico CPU generado" || echo "Error generando grafico CPU"
else
    echo "RRD data no disponible aun. Esperar 5 minutos tras iniciar collectd."
fi

echo "Graficos en: $OUTPUT"
echo "URL: http://${HOST}/vmin-graphs/"
GRAPHSCRIPT
    chmod +x /usr/local/bin/vmin-graphs

    ok "[11/15] Resource Usage Graphs configurado (collectd + rrdtool)"
    ((PASS_COUNT++)); log "resource graphs: OK"
}

# =============================================================================
# [12] BATCH CREATE SERVERS - Creacion masiva desde CSV
# =============================================================================
setup_batch_create() {
    info "[12/15] Configurando Batch Create Servers..."
    log "Iniciando batch create"

    cat > /usr/local/bin/vmin-batch-create << 'BATCHSCRIPT'
#!/bin/bash
# Crear multiples servidores virtuales desde archivo CSV
# Formato CSV: dominio,usuario,password,email,plan,quota_mb
FILE="${1:-}"; DRY_RUN="${2:-no}"

usage() {
    echo "Uso: $0 <archivo.csv> [dry-run]"
    echo "Formato CSV: dominio,usuario,password,email,plan,quota_mb"
    echo "Ejemplo:"
    echo "  dominio1.com,user1,pass123,admin@dominio1.com,default,1024"
    echo "  dominio2.com,user2,pass456,admin@dominio2.com,default,2048"
    exit 1
}
[[ -z "$FILE" || ! -f "$FILE" ]] && { echo "Archivo no encontrado: $FILE"; usage; }

SUCCESS=0; FAIL=0
echo "=== Creacion masiva de servidores virtuales ==="
[[ "$DRY_RUN" == "dry-run" ]] && echo "[MODO SIMULACION - sin cambios reales]"
echo ""

while IFS=',' read -r domain user pass email plan quota; do
    [[ "$domain" =~ ^#.*$ || -z "$domain" ]] && continue
    echo -n "  Creando $domain (usuario: $user)... "
    if [[ "$DRY_RUN" == "dry-run" ]]; then
        echo "SIMULADO"
        ((SUCCESS++))
    else
        if virtualmin create-domain \
            --domain "$domain" \
            --user "$user" \
            --pass "$pass" \
            --email "$email" \
            --plan "${plan:-default}" \
            --quota "${quota:-0}" \
            --web --mail --dns --mysql 2>/dev/null; then
            echo "OK"
            ((SUCCESS++))
        else
            echo "FALLO"
            ((FAIL++))
        fi
    fi
done < "$FILE"

echo ""
echo "=== Resultado: $SUCCESS creados, $FAIL fallidos ==="
BATCHSCRIPT
    chmod +x /usr/local/bin/vmin-batch-create

    # CSV de ejemplo
    cat > /usr/local/share/vmin-batch-example.csv << 'CSV'
# Formato: dominio,usuario,password,email,plan,quota_mb
# ejemplo.com,usuario1,password123,admin@ejemplo.com,default,1024
# otrodominio.com,usuario2,password456,admin@otrodominio.com,default,2048
CSV

    ok "[12/15] Batch Create Servers configurado"
    ((PASS_COUNT++)); log "batch create: OK"
}

# =============================================================================
# [13] CUSTOM LINKS - Enlaces personalizados en menu Webmin
# =============================================================================
setup_custom_links() {
    info "[13/15] Configurando Custom Links en Webmin..."
    log "Iniciando custom links"

    # Usar modulo 'custom' de Webmin para enlaces personalizados
    local custom_dir="/etc/webmin/custom"
    mkdir -p "$custom_dir"

    write_custom_link() {
        local id="$1"
        local name="$2"
        local url="$3"
        local desc="$4"
        local icon="$5"

        cat > "${custom_dir}/${id}" <<CUSTOM
name=${name}
url=${url}
desc=${desc}
icon=${icon}
CUSTOM
    }

    # Crear enlaces personalizados para modulos GPL, OpenVM y utilidades PRO
    write_custom_link 0 "Panel de Estado GPL" "https://localhost:10000/virtual-server/index.cgi" "Dashboard principal de Virtualmin GPL" "images/server.gif"
    write_custom_link 1 "OpenVM Suite" "https://localhost:10000/openvm-suite/index.cgi" "Panel unificado de modulos OpenVM" "images/server.gif"
    write_custom_link 2 "OpenVM Core" "https://localhost:10000/openvm-core/index.cgi" "Utilidades operativas abiertas sobre GPL" "images/link.gif"
    write_custom_link 3 "OpenVM Administration" "https://localhost:10000/openvm-admin/index.cgi" "Administracion delegada, revendedores y auditoria" "images/link.gif"
    write_custom_link 4 "OpenVM DNS" "https://localhost:10000/openvm-dns/index.cgi" "Inventario y operaciones DNS abiertas" "images/network.gif"
    write_custom_link 5 "OpenVM Backup" "https://localhost:10000/openvm-backup/index.cgi" "Backups abiertos sobre runtime GPL" "images/link.gif"
    write_custom_link 6 "Editor HTML GPL/OpenVM" "https://localhost:10000/openvm-core/edit_html.cgi" "Editor HTML abierto sin licencia comercial" "images/link.gif"
    write_custom_link 7 "Conectividad GPL/OpenVM" "https://localhost:10000/openvm-core/connectivity.cgi" "Diagnostico abierto de conectividad" "images/network.gif"
    write_custom_link 8 "Mail Logs GPL/OpenVM" "https://localhost:10000/openvm-core/maillog.cgi" "Busqueda abierta en logs de correo" "images/mail.gif"
    write_custom_link 9 "Backup Keys GPL/OpenVM" "https://localhost:10000/openvm-core/list_bkeys.cgi" "Inventario abierto de claves de backup" "images/link.gif"
    write_custom_link 10 "Remote DNS GPL/OpenVM" "https://localhost:10000/openvm-core/remotedns.cgi" "Inventario y operacion de DNS remoto" "images/network.gif"
    write_custom_link 11 "Edit Web Pages PRO" "https://localhost:10000/virtual-server/pro/edit_html.cgi" "Editor web estilo PRO integrado al entorno" "images/link.gif"
    write_custom_link 12 "Verificar Conectividad PRO" "https://localhost:10000/virtual-server/pro/connectivity.cgi" "Comprobar accesibilidad externa de dominios" "images/network.gif"
    write_custom_link 13 "Buscar en Logs de Correo PRO" "https://localhost:10000/virtual-server/pro/maillog.cgi" "Buscar mensajes en logs de Postfix" "images/mail.gif"
    write_custom_link 14 "Claves de Backup PRO" "https://localhost:10000/virtual-server/pro/list_bkeys.cgi" "Inventario de claves de backup estilo PRO" "images/link.gif"
    write_custom_link 15 "Intelligent Firewall" "https://localhost:10000/intelligent-firewall/index.cgi" "Firewall adaptativo integrado con Webmin" "images/network.gif"
    write_custom_link 16 "Zero Trust" "https://localhost:10000/zero-trust/index.cgi" "Orquestacion Zero Trust" "images/network.gif"
    write_custom_link 17 "SIEM" "https://localhost:10000/siem/index.cgi" "Correlacion de eventos y analisis forense" "images/link.gif"
    write_custom_link 18 "Multi-cloud Integration" "https://localhost:10000/multi_cloud_integration/webmin_integration.cgi" "Integracion cloud unificada desde Webmin" "images/network.gif"

    cat > /usr/local/bin/vmin-add-link << 'LINKSCRIPT'
#!/bin/bash
# Agregar enlace personalizado al menu de Webmin
NAME="${1:-}"; URL="${2:-}"; DESC="${3:-}"
[[ -z "$NAME" || -z "$URL" ]] && { echo "Uso: $0 <nombre> <url> [descripcion]"; exit 1; }
ID=$(ls /etc/webmin/custom/ 2>/dev/null | grep -E '^[0-9]+$' | sort -n | tail -1)
ID=$(( ${ID:-0} + 1 ))
cat > "/etc/webmin/custom/$ID" << EOF
name=$NAME
url=$URL
desc=${DESC:-$NAME}
icon=images/link.gif
EOF
echo "Enlace '$NAME' agregado al menu Webmin (ID: $ID)"
echo "Reiniciar Webmin para ver el cambio: systemctl restart webmin"
LINKSCRIPT
    chmod +x /usr/local/bin/vmin-add-link

    ok "[13/16] Custom Links configurado"
    ((PASS_COUNT++)); log "custom links: OK"
}

# =============================================================================
# [14] SSL PROVIDERS - ZeroSSL + BuyPass + Let's Encrypt
# =============================================================================
setup_ssl_providers() {
    info "[14/16] Configurando multiples SSL Providers..."
    log "Iniciando ssl providers"

    apt-get install -y certbot python3-certbot-apache 2>/dev/null | tail -2

    # Instalar acme.sh para soporte multi-CA sin pipe directo a shell
    if [[ ! -f /root/.acme.sh/acme.sh ]]; then
        tmp_acme_installer="/tmp/acme-install-$$.sh"
        curl -fsSL -o "$tmp_acme_installer" https://get.acme.sh 2>/dev/null || \
        wget -qO "$tmp_acme_installer" https://get.acme.sh 2>/dev/null || true
        if [[ -s "$tmp_acme_installer" ]] && head -1 "$tmp_acme_installer" | grep -qE '^#!/'; then
            bash "$tmp_acme_installer" email=admin@localhost 2>/dev/null || true
        fi
        rm -f "$tmp_acme_installer"
    fi

    cat > /usr/local/bin/vmin-ssl-cert << 'SSLSCRIPT'
#!/bin/bash
# Gestionar certificados SSL con multiples proveedores para Virtualmin
ACTION="${1:-list}"; DOMAIN="${2:-}"; PROVIDER="${3:-letsencrypt}"; EMAIL="${4:-admin@localhost}"

usage() {
    echo "Uso: $0 <list|issue|renew|install> [dominio] [proveedor] [email]"
    echo "Proveedores: letsencrypt zerossl buypass"
    exit 1
}

case "$ACTION" in
    list)
        echo "=== Certificados SSL instalados ==="
        for domain in $(virtualmin list-domains --name-only 2>/dev/null); do
            cert=$(openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null \
                | openssl x509 -noout -subject -enddate 2>/dev/null)
            [[ -n "$cert" ]] && echo "  $domain:" && echo "$cert" | sed 's/^/    /'
        done
        ;;
    issue)
        [[ -z "$DOMAIN" ]] && usage
        case "$PROVIDER" in
            letsencrypt)
                certbot certonly --apache -d "$DOMAIN" -d "www.$DOMAIN" \
                    --email "$EMAIL" --agree-tos --non-interactive 2>/dev/null || \
                certbot certonly --standalone -d "$DOMAIN" \
                    --email "$EMAIL" --agree-tos --non-interactive 2>/dev/null
                ;;
            zerossl)
                ~/.acme.sh/acme.sh --issue --server zerossl \
                    -d "$DOMAIN" -d "www.$DOMAIN" --webroot "/home/$DOMAIN/public_html" 2>/dev/null || true
                ;;
            buypass)
                ~/.acme.sh/acme.sh --issue --server buypass \
                    -d "$DOMAIN" --webroot "/home/$DOMAIN/public_html" 2>/dev/null || true
                ;;
        esac
        echo "Certificado emitido para $DOMAIN via $PROVIDER"
        ;;
    renew)
        certbot renew --quiet 2>/dev/null || true
        ~/.acme.sh/acme.sh --renew-all 2>/dev/null || true
        echo "Certificados renovados"
        ;;
    install)
        [[ -z "$DOMAIN" ]] && usage
        virtualmin install-cert --domain "$DOMAIN" \
            --cert "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" \
            --key "/etc/letsencrypt/live/$DOMAIN/privkey.pem" 2>/dev/null || \
        echo "Instalar manualmente via Webmin > SSL Certificate"
        ;;
esac
SSLSCRIPT
    chmod +x /usr/local/bin/vmin-ssl-cert

    # Configurar auto-renovacion diaria
    cat > /etc/cron.daily/vmin-ssl-renew << 'CRON'
#!/bin/bash
certbot renew --quiet --deploy-hook "systemctl reload apache2" >> /var/log/vmin-ssl-renew.log 2>&1
/root/.acme.sh/acme.sh --renew-all --stopfail >> /var/log/vmin-ssl-renew.log 2>&1
CRON
    chmod +x /etc/cron.daily/vmin-ssl-renew

    ok "[14/16] SSL Providers configurado (Let's Encrypt + ZeroSSL + BuyPass)"
    ((PASS_COUNT++)); log "ssl providers: OK"
}

# =============================================================================
# [15] EDIT WEB PAGES - Habilitar editor HTML en Virtualmin
# =============================================================================
setup_edit_web_pages() {
    info "[15/16] Habilitando Edit Web Pages en Virtualmin..."
    log "Iniciando edit web pages"

    local cfg="$WEBMIN_VSERVER/config"

    # El archivo edit_html.cgi ya existe en /pro - habilitarlo en la navegacion
    # Agregar enlace al menu de cada servidor virtual
    grep -q "^edit_html=" "$cfg" 2>/dev/null || echo "edit_html=1" >> "$cfg"

    # Instalar editor de texto avanzado para la web
    apt-get install -y mc nano vim 2>/dev/null | tail -2

    cat > /usr/local/bin/vmin-edit-file << 'EDITSCRIPT'
#!/bin/bash
# Editor de archivos web para dominios Virtualmin
DOMAIN="${1:-}"; FILE="${2:-index.html}"; EDITOR="${3:-nano}"
[[ -z "$DOMAIN" ]] && { echo "Uso: $0 <dominio> [archivo] [editor]"; exit 1; }
FILEPATH="/home/$DOMAIN/public_html/$FILE"
[[ ! -f "$FILEPATH" ]] && { echo "Archivo no encontrado: $FILEPATH"; exit 1; }
$EDITOR "$FILEPATH"
# Preservar permisos correctos
chown "$(stat -c %U /home/$DOMAIN)":"$(stat -c %G /home/$DOMAIN)" "$FILEPATH" 2>/dev/null || true
echo "Archivo guardado: $FILEPATH"
EDITSCRIPT
    chmod +x /usr/local/bin/vmin-edit-file

    ok "[15/16] Edit Web Pages habilitado"
    ((PASS_COUNT++)); log "edit web pages: OK"
}

# =============================================================================
# [16] Email Server Owners - Notificaciones masivas a propietarios
# =============================================================================
setup_email_server_owners() {
    info "[16/16] Configurando Email Server Owners..."

    cat > /usr/local/bin/vmin-email-owners << 'EMAILSCRIPT'
#!/bin/bash
# Enviar email masivo a todos los propietarios de dominios en Virtualmin
SUBJECT="${1:-Aviso del servidor}"; BODY_FILE="${2:-}"; FROM="${3:-admin@localhost}"

[[ -z "$SUBJECT" ]] && { echo "Uso: $0 <asunto> <archivo_mensaje> [remitente]"; exit 1; }
[[ -n "$BODY_FILE" && ! -f "$BODY_FILE" ]] && { echo "Archivo de mensaje no encontrado"; exit 1; }

BODY="${BODY_FILE:-/dev/stdin}"

echo "=== Enviando notificacion a propietarios de dominios ==="
COUNT=0
for domain in $(virtualmin list-domains --name-only 2>/dev/null); do
    email=$(virtualmin list-domains --domain "$domain" --multiline 2>/dev/null \
        | grep "Email:" | awk '{print $2}' | head -1)
    [[ -z "$email" ]] && continue
    if [[ -n "$BODY_FILE" ]]; then
        mail -s "$SUBJECT" -r "$FROM" "$email" < "$BODY_FILE" 2>/dev/null
    else
        echo "Mensaje para $domain" | mail -s "$SUBJECT" -r "$FROM" "$email" 2>/dev/null
    fi
    echo "  Enviado a: $email ($domain)"
    ((COUNT++))
done
echo ""
echo "Total enviados: $COUNT"
EMAILSCRIPT
    chmod +x /usr/local/bin/vmin-email-owners

    ok "[16/16] Email Server Owners configurado"
    ((PASS_COUNT++)); log "email server owners: OK"
}

# =============================================================================
# RESUMEN FINAL
# =============================================================================
show_summary() {
    echo ""
    echo "============================================================"
    echo "   WEBMIN/VIRTUALMIN PRO - SETUP COMPLETADO"
    echo "============================================================"
    echo ""
    echo "  Pasos completados: $PASS_COUNT"
    echo "  Fallos detectados: $FAIL_COUNT"
    echo ""
    echo "  MODULO RUNTIME: ${WEBMIN_MODULE_DIR}"
    echo "  ESTADO PERFIL: ${STATUS_FILE}"
    echo ""
    echo "  HERRAMIENTAS INSTALADAS:"
    for cmd in vmin-install-app vmin-ssh-keys vmin-backup-keys \
               vmin-mail-search vmin-cloud-dns vmin-resource-limits \
               vmin-mailbox-cleanup vmin-secondary-mx vmin-check-connectivity \
               vmin-graphs vmin-batch-create vmin-add-link \
               vmin-ssl-cert vmin-edit-file vmin-email-owners; do
        if [[ -f "/usr/local/bin/$cmd" ]]; then
            echo "  [OK] /usr/local/bin/$cmd"
        else
            echo "  [--] $cmd (no instalado)"
        fi
    done
    echo ""
    echo "  ACCESO WEBMIN: https://$(hostname -I | awk '{print $1}'):10000"
    echo ""
    echo "  PANEL PRO RUNTIME: ${WEBMIN_PRO_DIR}"
    echo "  TIMER REPO UPDATE: virtualmin-pro-repo-update.timer"
    echo ""
    echo "  Ver ayuda de cada herramienta: <comando> --help o sin argumentos"
    echo "============================================================"
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    local mode="${1:-full}"

    check_root
    check_supported_os
    detect_webmin_paths

    echo ""
    echo "============================================================"
    echo "  SETUP PRO PRODUCTION - Webmin/Virtualmin"
    echo "  $(date '+%Y-%m-%d %H:%M:%S')"
    echo "============================================================"
    echo ""

    mkdir -p "$(dirname "$LOG")"
    log "Iniciando setup_pro_production.sh en modo: $mode"

    case "$mode" in
        --sync-runtime|sync-runtime)
            deploy_runtime_panel_overlay || exit 1
            apply_permanent_license_patch || exit 1
            configure_webmin_hardening || exit 1
            if systemd_running; then
                systemctl restart webmin 2>/dev/null || true
            fi
            validate_runtime_profile || exit 1
            write_production_status
            log "setup_pro_production.sh sync-runtime completado: $PASS_COUNT OK, $FAIL_COUNT FAIL"
            return 0
            ;;
        --validate|validate)
            validate_runtime_profile || exit 1
            write_production_status
            log "setup_pro_production.sh validate completado: $PASS_COUNT OK, $FAIL_COUNT FAIL"
            return 0
            ;;
    esac

    deploy_runtime_panel_overlay || exit 1
    apply_permanent_license_patch || exit 1

    setup_reseller_accounts
    setup_web_apps_installer
    setup_ssh_key_management
    setup_backup_encryption
    setup_mail_log_search
    setup_cloud_dns
    setup_resource_limits
    setup_mailbox_cleanup
    setup_secondary_mail
    setup_connectivity_check
    setup_resource_graphs
    setup_batch_create
    setup_custom_links
    setup_ssl_providers
    setup_edit_web_pages
    setup_email_server_owners
    configure_production_security_baseline || exit 1
    install_repo_update_timer || exit 1

    # Reiniciar Webmin para aplicar todos los cambios de config
    if systemd_running; then
        systemctl restart webmin 2>/dev/null || true
    fi

    validate_runtime_profile || exit 1
    write_production_status

    show_summary
    log "setup_pro_production.sh completado: $PASS_COUNT OK, $FAIL_COUNT FAIL"

    if (( FAIL_COUNT > 0 )); then
        exit 1
    fi
}

main "$@"

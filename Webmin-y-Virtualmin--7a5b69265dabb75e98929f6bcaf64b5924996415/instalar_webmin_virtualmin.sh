#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

TEMP_DIR="$(mktemp -d /tmp/webmin-virtualmin-install.XXXXXX)"
readonly TEMP_DIR
readonly INSTALL_LOG="${INSTALL_LOG:-/var/log/webmin-virtualmin-install.log}"
readonly REPORT_PATH="${REPORT_PATH:-/root/webmin_virtualmin_installation_report.txt}"
readonly VIRTUALMIN_INSTALL_URL="${VIRTUALMIN_INSTALL_URL:-https://download.virtualmin.com/virtualmin-install}"
readonly REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main}"
readonly REPO_INSTALLER_URL="${REPO_INSTALLER_URL:-${REPO_RAW_BASE}/install_pro_complete.sh}"
readonly REPO_INSTALLER_SHA256="${REPO_INSTALLER_SHA256:-4bd1bb111c8b125185c9b9b4db37dbb6d6dbe1df8e9edcefcb26d818a48c81eb}"
readonly REPO_PROFILE_STATUS_FILE="${REPO_PROFILE_STATUS_FILE:-/root/webmin_repo_profile_status.txt}"
readonly VIRTUALMIN_AUTO_FQDN_DOMAIN="${VIRTUALMIN_AUTO_FQDN_DOMAIN:-sslip.io}"
readonly ALLOW_REMOTE_BOOTSTRAP="${ALLOW_REMOTE_BOOTSTRAP:-0}"
readonly SCRIPT_SOURCE="${BASH_SOURCE[0]-}"

OS=''
VERSION_ID=''
INSTALL_TYPE=''
INSTALL_BUNDLE=''
INSTALL_HOSTNAME=''
SERVER_IP=''
GRADE_B_FLAG=0
REPO_PROFILE_APPLIED=0
REPO_PROFILE_MESSAGE='not-requested'
SCRIPT_DIR=''

cleanup() {
    local exit_code=$?
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    exit "$exit_code"
}

trap cleanup EXIT INT TERM

log_info() {
    printf '%b[INFO]%b %s\n' "$GREEN" "$NC" "$*"
}

log_warn() {
    printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$*"
}

log_error() {
    printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$*" >&2
}

fail() {
    log_error "$*"
    exit 1
}

init_script_dir() {
    if [[ -n "$SCRIPT_SOURCE" && -f "$SCRIPT_SOURCE" ]]; then
        SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$SCRIPT_SOURCE")" && pwd)"
    fi
}

sha256_file() {
    local file_path="$1"

    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file_path" | awk '{print $1}'
        return 0
    fi

    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file_path" | awk '{print $1}'
        return 0
    fi

    fail 'No se encontro sha256sum ni shasum para validar integridad.'
}

verify_download_checksum() {
    local file_path="$1"
    local expected_checksum="$2"
    local source_url="$3"
    local actual_checksum=""

    [[ -n "$expected_checksum" ]] || fail "No hay checksum configurado para validar ${source_url}."

    actual_checksum="$(sha256_file "$file_path")"
    [[ "$actual_checksum" == "$expected_checksum" ]] || \
        fail "Checksum invalido para ${source_url}. Esperado: ${expected_checksum} Actual: ${actual_checksum}"
}

enable_logging() {
    mkdir -p "$(dirname "$INSTALL_LOG")"
    : > "$INSTALL_LOG"
    chmod 600 "$INSTALL_LOG"
    exec > >(tee -a "$INSTALL_LOG") 2>&1
}

check_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        fail 'Este instalador debe ejecutarse como root.'
    fi
}

detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        fail 'No se pudo detectar el sistema operativo.'
    fi

    # shellcheck disable=SC1091
    . /etc/os-release

    OS="$ID"
    if [[ -z "$OS" || -z "$VERSION_ID" ]]; then
        fail 'Falta informacion del sistema operativo en /etc/os-release.'
    fi
}

is_grade_a_supported_os() {
    local major_version="${VERSION_ID%%.*}"

    case "$OS" in
        ubuntu)
            [[ "$VERSION_ID" == '22.04' || "$VERSION_ID" == '24.04' ]]
            ;;
        debian)
            [[ "$VERSION_ID" == '12' || "$VERSION_ID" == '13' ]]
            ;;
        rocky|almalinux|rhel)
            [[ "$major_version" == '8' || "$major_version" == '9' || "$major_version" == '10' ]]
            ;;
        *)
            return 1
            ;;
    esac
}

is_grade_b_supported_os() {
    case "$OS" in
        centos|centos_stream|fedora|amzn|ol|openeuler|cloudlinux)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

check_supported_os() {
    if is_grade_a_supported_os; then
        return 0
    fi

    if [[ "${VIRTUALMIN_ALLOW_GRADE_B:-0}" == '1' ]] && is_grade_b_supported_os; then
        GRADE_B_FLAG=1
        log_warn "SO grado B detectado ($OS $VERSION_ID). Se continuara con --os-grade B. No es la ruta recomendada para produccion."
        return 0
    fi

    fail "SO no soportado para esta instalacion automatica: $OS $VERSION_ID. Usa Ubuntu 22.04/24.04, Debian 12/13, Rocky/AlmaLinux/RHEL 8-10, o exporta VIRTUALMIN_ALLOW_GRADE_B=1 para pruebas controladas."
}

check_system_requirements() {
    local mem_kb mem_gb disk_kb disk_gb

    mem_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
    disk_kb="$(df -k / | awk 'END {print $4}')"

    mem_gb=$((mem_kb / 1024 / 1024))
    disk_gb=$((disk_kb / 1024 / 1024))

    if (( mem_gb < 2 )); then
        fail "RAM insuficiente (${mem_gb}GB). Se requieren al menos 2GB."
    fi

    if (( disk_gb < 20 )); then
        fail "Espacio insuficiente (${disk_gb}GB libres). Se requieren al menos 20GB."
    fi

    if (( mem_gb < 4 )); then
        log_warn "RAM limitada (${mem_gb}GB). Para full install se recomiendan 4GB o mas."
    fi

    if (( disk_gb < 40 )); then
        log_warn "Espacio justo (${disk_gb}GB libres). Para produccion se recomiendan 40GB o mas."
    fi
}

wait_for_apt_ready() {
    local waited=0
    local timeout=900

    if [[ "$OS" != 'ubuntu' && "$OS" != 'debian' ]]; then
        return 0
    fi

    if systemd_running; then
        systemctl stop apt-daily.service apt-daily-upgrade.service unattended-upgrades 2>/dev/null || true
        systemctl stop apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
    fi

    while pgrep -x apt >/dev/null 2>&1 || \
          pgrep -x apt-get >/dev/null 2>&1 || \
          pgrep -x dpkg >/dev/null 2>&1 || \
          pgrep -x unattended-upgr >/dev/null 2>&1; do
        sleep 5
        waited=$((waited + 5))

        if (( waited >= timeout )); then
            fail "apt/dpkg sigue ocupado despues de ${timeout}s."
        fi
    done

    dpkg --configure -a >/dev/null 2>&1 || true
}

systemd_running() {
    command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]
}

ensure_downloader() {
    if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
        return 0
    fi

    case "$OS" in
        ubuntu|debian)
            wait_for_apt_ready
            apt-get update
            wait_for_apt_ready
            apt-get install -y curl wget ca-certificates
            ;;
        rocky|almalinux|rhel|centos|centos_stream|fedora|amzn|ol|openeuler|cloudlinux)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y curl wget ca-certificates
            elif command -v yum >/dev/null 2>&1; then
                yum install -y curl wget ca-certificates
            else
                fail 'No se encontro gestor de paquetes compatible para instalar curl/wget.'
            fi
            ;;
        *)
            fail 'No se pudo instalar un cliente HTTP en este sistema.'
            ;;
    esac
}

download_file() {
    local url="$1"
    local destination="$2"
    local expected_checksum="${3:-}"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$destination"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$destination" "$url"
    else
        fail 'No hay curl ni wget disponibles para descargar archivos.'
    fi

    if [[ -n "$expected_checksum" ]]; then
        verify_download_checksum "$destination" "$expected_checksum" "$url"
    fi
}

is_deb_package_installed() {
    local package_name="$1"
    dpkg-query -W -f='${Status}' "$package_name" 2>/dev/null | grep -q 'install ok installed'
}

is_rpm_package_installed() {
    local package_name="$1"
    rpm -q "$package_name" >/dev/null 2>&1
}

assert_fresh_system() {
    local -a detected=()

    if [[ "${VIRTUALMIN_ALLOW_PRECONFIGURED:-0}" == '1' ]]; then
        log_warn 'Se omite la validacion de sistema limpio porque VIRTUALMIN_ALLOW_PRECONFIGURED=1.'
        return 0
    fi

    if [[ "$OS" == 'ubuntu' || "$OS" == 'debian' ]]; then
        local -a packages=(apache2 nginx mariadb-server mysql-server postfix bind9 webmin usermin virtualmin-base virtualmin-core)
        local package_name
        for package_name in "${packages[@]}"; do
            if is_deb_package_installed "$package_name"; then
                detected+=("$package_name")
            fi
        done
    else
        local -a packages=(httpd nginx mariadb-server mysql-server postfix bind webmin usermin virtualmin-base virtualmin-core)
        local package_name
        for package_name in "${packages[@]}"; do
            if is_rpm_package_installed "$package_name"; then
                detected+=("$package_name")
            fi
        done
    fi

    if (( ${#detected[@]} > 0 )); then
        fail "Sistema no limpio detectado. Paquetes ya presentes: ${detected[*]}. Para produccion usa un SO fresco o exporta VIRTUALMIN_ALLOW_PRECONFIGURED=1 si sabes exactamente lo que haces."
    fi
}

is_fqdn() {
    local hostname_value="$1"
    local fqdn_regex='^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$'

    [[ -n "$hostname_value" ]] || return 1
    [[ ! "$hostname_value" =~ (^localhost$|\.local$|\.localdomain$) ]] || return 1
    [[ "$hostname_value" =~ $fqdn_regex ]]
}

get_server_ip() {
    local ip_address=''

    ip_address="$(hostname -I 2>/dev/null | awk '{print $1}')"

    if [[ -z "$ip_address" || "$ip_address" == '127.0.0.1' ]]; then
        ip_address="$(ip route get 1 2>/dev/null | awk '{print $7; exit}')"
    fi

    if [[ -z "$ip_address" || "$ip_address" == '127.0.0.1' ]]; then
        ip_address='127.0.0.1'
    fi

    printf '%s\n' "$ip_address"
}

get_current_hostname() {
    local hostname_value=''

    hostname_value="$(hostname -f 2>/dev/null || true)"

    if [[ -z "$hostname_value" ]]; then
        hostname_value="$(hostnamectl --static 2>/dev/null || true)"
    fi

    if [[ -z "$hostname_value" ]]; then
        hostname_value="$(hostname 2>/dev/null || true)"
    fi

    printf '%s\n' "$hostname_value"
}

build_auto_fqdn_from_ip() {
    local ip_address='' ip_label=''

    ip_address="$(get_server_ip)"
    [[ -n "$ip_address" && "$ip_address" != '127.0.0.1' ]] || return 1

    ip_label="${ip_address//./-}"
    ip_label="${ip_label//:/-}"
    ip_label="${ip_label//[^A-Za-z0-9-]/-}"
    ip_label="${ip_label#-}"
    ip_label="${ip_label%-}"
    [[ -n "$ip_label" ]] || return 1

    printf '%s.%s\n' "$ip_label" "$VIRTUALMIN_AUTO_FQDN_DOMAIN"
}

resolve_install_settings() {
    local requested_type="${VIRTUALMIN_TYPE:-auto}"
    local current_hostname=''
    local auto_generated_hostname=''

    INSTALL_BUNDLE="${VIRTUALMIN_BUNDLE:-LAMP}"
    INSTALL_BUNDLE="${INSTALL_BUNDLE^^}"

    case "$INSTALL_BUNDLE" in
        LAMP|LEMP)
            ;;
        *)
            fail "Bundle invalido: $INSTALL_BUNDLE. Usa LAMP o LEMP."
            ;;
    esac

    if [[ -n "${VIRTUALMIN_HOSTNAME:-}" ]]; then
        INSTALL_HOSTNAME="$VIRTUALMIN_HOSTNAME"
    else
        current_hostname="$(get_current_hostname)"
        if is_fqdn "$current_hostname"; then
            INSTALL_HOSTNAME="$current_hostname"
        elif auto_generated_hostname="$(build_auto_fqdn_from_ip 2>/dev/null)" && is_fqdn "$auto_generated_hostname"; then
            INSTALL_HOSTNAME="$auto_generated_hostname"
            log_warn "No se detecto FQDN valido. Se generara automaticamente $INSTALL_HOSTNAME para permitir instalacion full."
        fi
    fi

    if [[ -n "$INSTALL_HOSTNAME" ]] && ! is_fqdn "$INSTALL_HOSTNAME"; then
        fail "Hostname invalido: $INSTALL_HOSTNAME. Debe ser un FQDN valido, por ejemplo panel.example.com."
    fi

    case "$requested_type" in
        auto)
            if [[ -n "$INSTALL_HOSTNAME" ]]; then
                INSTALL_TYPE='full'
            else
                INSTALL_TYPE='full'
                fail 'No se pudo generar un FQDN valido para forzar instalacion full. Configura VIRTUALMIN_HOSTNAME o revisa la IP principal del servidor.'
            fi
            ;;
        full|mini)
            INSTALL_TYPE="$requested_type"
            ;;
        *)
            fail "Tipo de instalacion invalido: $requested_type. Usa auto, full o mini."
            ;;
    esac

    if [[ "$INSTALL_TYPE" == 'full' && -z "$INSTALL_HOSTNAME" ]]; then
        fail 'La instalacion full requiere un FQDN valido. Configura el hostname del servidor o exporta VIRTUALMIN_HOSTNAME=panel.example.com.'
    fi
}

ensure_hostname_resolution() {
    local short_hostname hosts_line

    [[ -n "$INSTALL_HOSTNAME" ]] || return 0

    short_hostname="${INSTALL_HOSTNAME%%.*}"
    SERVER_IP="$(get_server_ip)"

    if [[ -z "$SERVER_IP" || "$SERVER_IP" == '127.0.0.1' ]]; then
        SERVER_IP='127.0.1.1'
    fi

    if grep -Eq "(^|[[:space:]])${INSTALL_HOSTNAME//./\\.}($|[[:space:]])" /etc/hosts 2>/dev/null; then
        return 0
    fi

    hosts_line="$(printf '%s %s %s' "$SERVER_IP" "$INSTALL_HOSTNAME" "$short_hostname")"
    printf '%s\n' "$hosts_line" >> /etc/hosts
}

install_virtualmin() {
    local installer_path="$TEMP_DIR/virtualmin-install"
    local -a installer_args=(--bundle "$INSTALL_BUNDLE" --type "$INSTALL_TYPE" --yes)

    if [[ -n "$INSTALL_HOSTNAME" ]]; then
        installer_args+=(--hostname "$INSTALL_HOSTNAME")
    fi

    if [[ "${VIRTUALMIN_DISABLE_HOSTNAME_SSL:-0}" == '1' ]]; then
        installer_args+=(--no-hostname-ssl)
    fi

    if (( GRADE_B_FLAG == 1 )); then
        installer_args+=(--os-grade B)
    fi

    log_info "Descargando instalador oficial desde $VIRTUALMIN_INSTALL_URL"
    download_file "$VIRTUALMIN_INSTALL_URL" "$installer_path"
    chmod 700 "$installer_path"

    if [[ "$OS" == 'ubuntu' || "$OS" == 'debian' ]]; then
        wait_for_apt_ready
    fi

    log_info "Ejecutando instalador oficial de Virtualmin ($INSTALL_BUNDLE / $INSTALL_TYPE)"
    sh "$installer_path" "${installer_args[@]}"
}

fix_mail_delivery_compat() {
    local wrapper_info arch

    command -v postconf >/dev/null 2>&1 || return 0
    [[ -x /usr/bin/procmail-wrapper ]] || return 0

    arch="$(uname -m 2>/dev/null || true)"
    wrapper_info="$(file /usr/bin/procmail-wrapper 2>/dev/null || true)"

    case "$arch" in
        arm64|aarch64)
            if printf '%s\n' "$wrapper_info" | grep -Eqi 'Intel 80386|x86-64'; then
                log_warn "Ajustando Postfix a Maildir directo por incompatibilidad de procmail-wrapper en $arch."
                postconf -e 'mailbox_command=' 'home_mailbox=Maildir/'
                if systemd_running; then
                    systemctl reload postfix 2>/dev/null || systemctl restart postfix 2>/dev/null || true
                else
                    service postfix reload 2>/dev/null || service postfix restart 2>/dev/null || true
                fi
            fi
            ;;
    esac
}

configure_firewall() {
    if command -v ufw >/dev/null 2>&1; then
        if ufw status 2>/dev/null | grep -q '^Status: active'; then
            ufw allow 10000/tcp >/dev/null 2>&1 || true
        fi
        return 0
    fi

    if command -v firewall-cmd >/dev/null 2>&1; then
        if systemd_running && systemctl is-active --quiet firewalld; then
            firewall-cmd --permanent --add-port=10000/tcp >/dev/null 2>&1 || true
            firewall-cmd --reload >/dev/null 2>&1 || true
        fi
    fi
}

ensure_webmin_running() {
    [[ -d /etc/webmin ]] || fail 'No se encontro /etc/webmin despues de la instalacion.'

    if systemd_running; then
        systemctl enable webmin >/dev/null 2>&1 || true
        systemctl restart webmin >/dev/null 2>&1 || systemctl start webmin >/dev/null 2>&1 || true
        if ! systemctl is-active --quiet webmin; then
            fail 'webmin.service no quedo activo despues de la instalacion.'
        fi
    else
        service webmin restart >/dev/null 2>&1 || service webmin start >/dev/null 2>&1 || true
    fi
}

supports_repo_profile() {
    [[ "$OS" == 'ubuntu' || "$OS" == 'debian' ]]
}

apply_repository_profile() {
    local profile_installer="$TEMP_DIR/install_pro_complete.sh"
    local local_profile_installer=""

    if [[ "${VIRTUALMIN_SKIP_REPO_PROFILE:-0}" == '1' ]]; then
        REPO_PROFILE_MESSAGE='skipped-by-env'
        log_warn 'Se omite el perfil profesional del repositorio porque VIRTUALMIN_SKIP_REPO_PROFILE=1.'
        return 0
    fi

    if ! supports_repo_profile; then
        REPO_PROFILE_MESSAGE="unsupported-os:${OS}-${VERSION_ID}"
        log_warn "El perfil profesional del repositorio solo esta soportado automaticamente en Ubuntu/Debian. Se mantiene la instalacion base en $OS $VERSION_ID."
        return 0
    fi

    log_info 'Aplicando perfil profesional del panel desde el mismo repositorio.'

    if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/install_pro_complete.sh" ]]; then
        local_profile_installer="$SCRIPT_DIR/install_pro_complete.sh"
        profile_installer="$local_profile_installer"
    else
        if [[ "$ALLOW_REMOTE_BOOTSTRAP" != '1' ]]; then
            fail 'No se encontro install_pro_complete.sh local. Para produccion usa el checkout completo del repositorio o exporta ALLOW_REMOTE_BOOTSTRAP=1 para una descarga remota controlada.'
        fi

        download_file "$REPO_INSTALLER_URL" "$profile_installer" "$REPO_INSTALLER_SHA256"
        chmod 700 "$profile_installer"
    fi

    if bash "$profile_installer" --post-base; then
        REPO_PROFILE_APPLIED=1
        REPO_PROFILE_MESSAGE='applied'
        log_info 'Perfil profesional del repositorio aplicado correctamente.'
        return 0
    fi

    REPO_PROFILE_MESSAGE='failed'
    fail 'La instalacion base termino, pero fallo la aplicacion del perfil profesional del repositorio.'
}

write_repo_profile_status() {
    mkdir -p "$(dirname "$REPO_PROFILE_STATUS_FILE")"
    cat > "$REPO_PROFILE_STATUS_FILE" <<EOF
repo_profile_applied=$REPO_PROFILE_APPLIED
repo_profile_message=$REPO_PROFILE_MESSAGE
repo_installer_url=$REPO_INSTALLER_URL
EOF
    chmod 600 "$REPO_PROFILE_STATUS_FILE"
}

write_install_report() {
    local access_host

    mkdir -p "$(dirname "$REPORT_PATH")"

    if [[ -n "$INSTALL_HOSTNAME" ]]; then
        access_host="$INSTALL_HOSTNAME"
    else
        access_host="$SERVER_IP"
    fi

    cat > "$REPORT_PATH" <<EOF
Webmin / Virtualmin installation report
Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Operating system: $OS $VERSION_ID
Bundle: $INSTALL_BUNDLE
Install type: $INSTALL_TYPE
Hostname: ${INSTALL_HOSTNAME:-not-set}
Server IP: $SERVER_IP
Webmin URL: https://$access_host:10000
Log file: $INSTALL_LOG
Official installer: $VIRTUALMIN_INSTALL_URL
Repository profile applied: $REPO_PROFILE_APPLIED
Repository profile status: $REPO_PROFILE_MESSAGE
Repository installer: $REPO_INSTALLER_URL
Repository profile status file: $REPO_PROFILE_STATUS_FILE
EOF

    chmod 600 "$REPORT_PATH"
}

show_completion_message() {
    local access_host

    if [[ -n "$INSTALL_HOSTNAME" ]]; then
        access_host="$INSTALL_HOSTNAME"
    else
        access_host="$SERVER_IP"
    fi

    printf '\n'
    printf '%b========================================%b\n' "$GREEN" "$NC"
    printf '%b   INSTALACION COMPLETADA CON EXITO    %b\n' "$GREEN" "$NC"
    printf '%b========================================%b\n' "$GREEN" "$NC"
    printf '%bAcceso:%b https://%s:10000\n' "$CYAN" "$NC" "$access_host"
    printf '%bUsuario:%b root\n' "$YELLOW" "$NC"
    printf '%bLog:%b %s\n' "$YELLOW" "$NC" "$INSTALL_LOG"
    printf '%bReporte:%b %s\n' "$YELLOW" "$NC" "$REPORT_PATH"
    printf '%bPerfil repo:%b %s\n' "$YELLOW" "$NC" "$REPO_PROFILE_MESSAGE"
}

main() {
    init_script_dir
    enable_logging
    log_info 'Inicio de instalacion automatica Webmin/Virtualmin.'

    check_root
    detect_os
    check_supported_os
    check_system_requirements
    assert_fresh_system
    ensure_downloader
    resolve_install_settings
    ensure_hostname_resolution
    install_virtualmin
    fix_mail_delivery_compat
    configure_firewall
    ensure_webmin_running
    apply_repository_profile

    SERVER_IP="$(get_server_ip)"
    write_repo_profile_status
    write_install_report
    show_completion_message
}

main "$@"

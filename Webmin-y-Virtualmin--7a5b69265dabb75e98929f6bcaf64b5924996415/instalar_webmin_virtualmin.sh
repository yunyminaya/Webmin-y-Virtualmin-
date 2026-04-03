#!/bin/bash

set -euo pipefail
IFS=$'
	'

readonly RED='[0;31m'
readonly GREEN='[0;32m'
readonly YELLOW='[1;33m'
readonly CYAN='[0;36m'
readonly NC='[0m'
readonly TEMP_DIR="/tmp/virtualmin_secure_install_$$"
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none

cleanup() {
    local exit_code=$?
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    exit "$exit_code"
}
trap cleanup EXIT INT TERM
mkdir -p "$TEMP_DIR"

get_server_ip() {
    local ip=""
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [[ -z "$ip" || "$ip" == "127.0.0.1" ]]; then
        ip=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
    fi
    if [[ -z "$ip" || "$ip" == "127.0.0.1" ]]; then
        ip=$(ifconfig 2>/dev/null | awk '/inet / && $2 != "127.0.0.1" {print $2; exit}')
    fi
    if [[ -z "$ip" ]]; then
        ip="127.0.0.1"
    fi
    printf '%s
' "$ip"
}

get_virtualmin_hostname() {
    local current short fallback
    current=$(hostname -f 2>/dev/null || hostname 2>/dev/null || true)
    if [[ -n "$current" && "$current" == *.* ]]; then
        printf '%s
' "$current"
        return 0
    fi

    if [[ -n "${VIRTUALMIN_HOSTNAME:-}" ]]; then
        printf '%s
' "$VIRTUALMIN_HOSTNAME"
        return 0
    fi

    short=$(hostname -s 2>/dev/null || hostname 2>/dev/null || printf 'server')
    fallback="${short}.localdomain"
    printf '%s
' "$fallback"
}


ensure_hostname_resolution() {
    local fqdn short host_ip hosts_line
    fqdn=$(get_virtualmin_hostname)
    short=${fqdn%%.*}
    host_ip=$(get_server_ip)
    [[ -n "$host_ip" && "$host_ip" != "127.0.0.1" ]] || host_ip="127.0.1.1"

    if grep -Eq "(^|[[:space:]])${fqdn//./\.}($|[[:space:]])" /etc/hosts 2>/dev/null; then
        return 0
    fi

    hosts_line=$(printf '%s %s %s' "$host_ip" "$fqdn" "$short")
    printf '%s
' "$hosts_line" >> /etc/hosts
}

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo -e "${RED}Error: Este script debe ejecutarse como root${NC}" >&2
        exit 1
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS="$ID"
        VERSION="$VERSION_ID"
    else
        echo -e "${RED}Error: No se pudo determinar el sistema operativo${NC}" >&2
        exit 1
    fi
}


wait_for_apt_ready() {
    local waited=0
    local timeout=900

    if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
        return 0
    fi

    if systemd_running; then
        systemctl stop apt-daily.service apt-daily-upgrade.service unattended-upgrades 2>/dev/null || true
        systemctl stop apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
    fi

    while pgrep -x apt >/dev/null 2>&1 ||           pgrep -x apt-get >/dev/null 2>&1 ||           pgrep -x dpkg >/dev/null 2>&1 ||           pgrep -x unattended-upgr >/dev/null 2>&1; do
        sleep 5
        waited=$((waited + 5))
        if (( waited >= timeout )); then
            echo -e "${RED}Error: apt/dpkg sigue ocupado tras ${timeout}s${NC}" >&2
            return 1
        fi
    done

    dpkg --configure -a >/dev/null 2>&1 || true
}

check_system_requirements() {
    local mem_kb mem_gb disk_kb disk_gb
    mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    mem_gb=$((mem_kb / 1024 / 1024))
    disk_kb=$(df -k / | awk 'END {print $4}')
    disk_gb=$((disk_kb / 1024 / 1024))

    if [[ "$mem_gb" -lt 2 ]]; then
        echo -e "${RED}Error: Memoria RAM insuficiente (${mem_gb}GB). Mínimo requerido: 2GB${NC}" >&2
        exit 1
    elif [[ "$mem_gb" -lt 4 ]]; then
        echo -e "${YELLOW}Advertencia: Memoria RAM limitada (${mem_gb}GB). Se recomiendan 4GB o más${NC}"
    fi

    if [[ "$disk_gb" -lt 20 ]]; then
        echo -e "${RED}Error: Espacio en disco insuficiente (${disk_gb}GB). Mínimo requerido: 20GB${NC}" >&2
        exit 1
    elif [[ "$disk_gb" -lt 50 ]]; then
        echo -e "${YELLOW}Advertencia: Espacio en disco limitado (${disk_gb}GB). Se recomiendan 50GB o más${NC}"
    fi
}

install_dependencies() {
    echo -e "${GREEN}Instalando dependencias...${NC}"
    case "$OS" in
        ubuntu|debian)
            wait_for_apt_ready
            apt-get update
            wait_for_apt_ready
            apt-get install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates iproute2 net-tools iputils-ping
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y curl wget gnupg2 ca-certificates iproute net-tools iputils
            else
                yum install -y curl wget gnupg2 ca-certificates iproute net-tools iputils
            fi
            ;;
        *)
            echo -e "${RED}Error: Sistema operativo no soportado: $OS${NC}" >&2
            exit 1
            ;;
    esac
}

install_webmin() {
    echo -e "${GREEN}Instalando Webmin...${NC}"
    case "$OS" in
        ubuntu|debian)
            local webmin_deb="$TEMP_DIR/webmin-current.deb"
            curl -fsSL -o "$webmin_deb" https://www.webmin.com/download/deb/webmin-current.deb
            wait_for_apt_ready
            apt-get install -y perl
            wait_for_apt_ready
            apt-get install -y "$webmin_deb"
            ;;
        centos|rhel|fedora|rocky|almalinux)
            local webmin_rpm="$TEMP_DIR/webmin-current.rpm"
            curl -fsSL -o "$webmin_rpm" https://www.webmin.com/download/rpm/webmin-current.rpm
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y "$webmin_rpm"
            else
                yum localinstall -y "$webmin_rpm"
            fi
            ;;
    esac
}

install_virtualmin() {
    local installer_path="$TEMP_DIR/virtualmin-install.sh"
    local mem_kb mem_gb install_hostname
    local -a installer_args=(--force)

    echo -e "${GREEN}Instalando Virtualmin...${NC}"
    curl -fsSL -o "$installer_path" https://software.virtualmin.com/gpl/scripts/install.sh
    if ! head -1 "$installer_path" | grep -qE '^#!/bin/(ba)?sh'; then
        echo -e "${RED}Error: El instalador oficial de Virtualmin no parece válido${NC}" >&2
        exit 1
    fi

    mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    mem_gb=$((mem_kb / 1024 / 1024))
    if [[ "$mem_gb" -lt 4 ]]; then
        echo -e "${YELLOW}Memoria limitada detectada (${mem_gb}GB). Usando modo minimal${NC}"
        installer_args+=(--minimal)
    fi

    install_hostname=$(get_virtualmin_hostname)
    if [[ -n "$install_hostname" ]]; then
        echo -e "${YELLOW}Usando hostname para Virtualmin: ${install_hostname}${NC}"
        installer_args+=(--hostname "$install_hostname")
    fi

    wait_for_apt_ready
    bash "$installer_path" "${installer_args[@]}"
}

configure_webmin_listen() {
    local miniserv_conf="/etc/webmin/miniserv.conf"
    [[ -f "$miniserv_conf" ]] || return 0

    cp "$miniserv_conf" "${miniserv_conf}.backup.$(date +%s)"
    grep -vE '^(listen|bind)=' "$miniserv_conf" > "${miniserv_conf}.tmp"
    printf 'listen=10000
bind=0.0.0.0
' >> "${miniserv_conf}.tmp"
    mv "${miniserv_conf}.tmp" "$miniserv_conf"
}

configure_security() {
    echo -e "${GREEN}Configurando seguridad básica...${NC}"
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 10000/tcp
        ufw reload
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=10000/tcp
        firewall-cmd --reload
    fi
}


ensure_root_alias() {
    if [[ -f /etc/aliases ]] && ! grep -Eq '^root\s*:' /etc/aliases; then
        printf 'root: root
' >> /etc/aliases
        if command -v newaliases >/dev/null 2>&1; then
            newaliases >/dev/null 2>&1 || true
        fi
    fi
}

configure_apache_servername() {
    local fqdn conf_file
    fqdn=$(get_virtualmin_hostname)

    if [[ -d /etc/apache2 ]]; then
        conf_file='/etc/apache2/conf-available/servername.conf'
        printf 'ServerName %s
' "$fqdn" > "$conf_file"
        if command -v a2enconf >/dev/null 2>&1; then
            a2enconf servername >/dev/null 2>&1 || true
        fi
    elif [[ -d /etc/httpd ]]; then
        conf_file='/etc/httpd/conf.d/servername.conf'
        printf 'ServerName %s
' "$fqdn" > "$conf_file"
    fi
}


fix_mail_delivery_compat() {
    local wrapper_info arch

    command -v postconf >/dev/null 2>&1 || return 0
    [[ -x /usr/bin/procmail-wrapper ]] || return 0

    arch=$(uname -m 2>/dev/null || true)
    wrapper_info=$(file /usr/bin/procmail-wrapper 2>/dev/null || true)

    case "$arch" in
        arm64|aarch64)
            if printf '%s
' "$wrapper_info" | grep -Eqi 'Intel 80386|x86-64'; then
                echo -e "${YELLOW}Ajustando Postfix para Maildir directo por incompatibilidad de procmail-wrapper en ${arch}.${NC}"
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

systemd_running() {
    command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]
}

start_webmin_service() {
    if systemd_running; then
        systemctl enable webmin
        systemctl start webmin
        sleep 2
    else
        service webmin status >/dev/null 2>&1 || service webmin start
    fi
}

restart_webmin_service() {
    if systemd_running; then
        systemctl restart webmin
        sleep 3
    else
        service webmin restart >/dev/null 2>&1 || {
            service webmin stop >/dev/null 2>&1 || true
            service webmin start
        }
    fi
}

main() {
    check_root
    check_os
    check_system_requirements
    install_dependencies
    ensure_hostname_resolution
    install_webmin

    start_webmin_service

    install_virtualmin
    ensure_root_alias
    configure_apache_servername
    fix_mail_delivery_compat
    configure_webmin_listen
    configure_security

    restart_webmin_service

    local server_ip
    server_ip=$(get_server_ip)

    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}     INSTALACIÓN COMPLETADA SEGURA     ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${CYAN}Acceso:${NC} https://${server_ip}:10000"
    echo -e "${YELLOW}Usuario:${NC} root"
    echo -e "${YELLOW}Contraseña:${NC} la contraseña actual de root"
    echo -e "${YELLOW}Nota:${NC} No se habilitan túneles públicos automáticos en esta versión segura."
}

main

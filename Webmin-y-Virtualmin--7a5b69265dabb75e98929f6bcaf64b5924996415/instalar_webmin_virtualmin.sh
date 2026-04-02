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
            apt-get update
            apt-get install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y curl wget gnupg2 ca-certificates
            else
                yum install -y curl wget gnupg2 ca-certificates
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
            rm -f /usr/share/keyrings/webmin.gpg /etc/apt/sources.list.d/webmin.list
            curl -fsSL https://download.webmin.com/jcameron-key.asc | gpg --dearmor -o /usr/share/keyrings/webmin.gpg
            echo "deb [signed-by=/usr/share/keyrings/webmin.gpg] https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
            apt-get update
            apt-get install -y webmin
            ;;
        centos|rhel|fedora|rocky|almalinux)
            curl -fsSL -o /etc/yum.repos.d/webmin.repo https://download.webmin.com/download/yum/webmin.repo
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y webmin
            else
                yum install -y webmin
            fi
            ;;
    esac
}

install_virtualmin() {
    local installer_path="$TEMP_DIR/virtualmin-install.sh"
    local mem_kb mem_gb
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

main() {
    check_root
    check_os
    check_system_requirements
    install_dependencies
    install_webmin

    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable webmin
        systemctl start webmin
        sleep 2
    else
        service webmin start
    fi

    install_virtualmin
    configure_webmin_listen
    configure_security

    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart webmin
        sleep 3
    else
        service webmin restart
    fi

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

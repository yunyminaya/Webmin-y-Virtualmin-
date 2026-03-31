#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

# Instalador unificado para Webmin/Virtualmin con túnel opcional
# Versión: 4.1 Secure

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

readonly TUNNEL_PORT=10000
readonly TUNNEL_LOG_FILE="/var/localtunnel.log"
readonly TUNNEL_PID_FILE="/var/run/localtunnel.pid"
readonly TEMP_DIR="/tmp/virtualmin_unified_install_$$"
readonly PUBLIC_TUNNEL_ENABLED="${PUBLIC_TUNNEL_ENABLED:-0}"

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
        ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
    fi
    if [[ -z "$ip" || "$ip" == "127.0.0.1" ]]; then
        ip=$(ifconfig 2>/dev/null | grep -E "inet [0-9]" | grep -v "127.0.0.1" | awk '{print $2}' | head -1)
    fi
    if [[ -z "$ip" ]]; then
        ip="127.0.0.1"
    fi
    echo "$ip"
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
        echo -e "${RED}Error: No se pudo determinar el sistema operativo${NC}"
        exit 1
    fi
}

check_system_requirements() {
    local mem_kb mem_gb disk_kb disk_gb
    mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    mem_gb=$((mem_kb / 1024 / 1024))
    disk_kb=$(df -k / | tail -1 | awk '{print $4}')
    disk_gb=$((disk_kb / 1024 / 1024))

    if [[ "$mem_gb" -lt 2 ]]; then
        echo -e "${RED}Error: Memoria RAM insuficiente (${mem_gb}GB). Mínimo requerido: 2GB${NC}"
        exit 1
    elif [[ "$mem_gb" -lt 4 ]]; then
        echo -e "${YELLOW}Advertencia: Memoria RAM limitada (${mem_gb}GB). Se recomiendan 4GB o más${NC}"
    fi

    if [[ "$disk_gb" -lt 20 ]]; then
        echo -e "${RED}Error: Espacio en disco insuficiente (${disk_gb}GB). Mínimo requerido: 20GB${NC}"
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
            apt-get install -y curl wget gnupg2 software-properties-common apt-transport-https
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y curl wget gnupg2 epel-release
            else
                yum install -y curl wget gnupg2 epel-release
            fi
            ;;
        *)
            echo -e "${RED}Error: Sistema operativo no soportado: $OS${NC}"
            exit 1
            ;;
    esac
}

install_nodejs() {
    echo -e "${GREEN}Instalando Node.js y npm para túnel localtunnel...${NC}"
    case "$OS" in
        ubuntu|debian)
            apt-get install -y nodejs npm
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y nodejs npm
            else
                yum install -y nodejs npm
            fi
            ;;
    esac

    command -v node >/dev/null 2>&1 || { echo -e "${RED}❌ Error: No se pudo instalar Node.js${NC}"; return 1; }
    command -v npm >/dev/null 2>&1 || { echo -e "${RED}❌ Error: No se pudo instalar npm${NC}"; return 1; }
}

install_localtunnel() {
    echo -e "${GREEN}Instalando localtunnel...${NC}"
    command -v npm >/dev/null 2>&1 || { echo -e "${RED}❌ Error: npm no está disponible${NC}"; return 1; }
    npm install -g localtunnel
    command -v lt >/dev/null 2>&1 || { echo -e "${RED}❌ Error: No se pudo instalar localtunnel${NC}"; return 1; }
}

start_localtunnel() {
    local port="${1:-10000}"
    local subdomain tunnel_pid tunnel_url

    echo -e "${CYAN}🚀 Iniciando túnel localtunnel en puerto $port...${NC}"

    if [[ -f "$TUNNEL_PID_FILE" ]]; then
        local old_pid
        old_pid=$(cat "$TUNNEL_PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            kill "$old_pid" 2>/dev/null || true
            sleep 2
        fi
        rm -f "$TUNNEL_PID_FILE"
    fi

    rm -f "$TUNNEL_LOG_FILE"
    subdomain="webmin-$(hostname | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')-$(date +%s | tail -c 6)"
    nohup lt --port "$port" --subdomain "$subdomain" > "$TUNNEL_LOG_FILE" 2>&1 &
    tunnel_pid=$!
    echo "$tunnel_pid" > "$TUNNEL_PID_FILE"

    for _ in $(seq 1 30); do
        if [[ -f "$TUNNEL_LOG_FILE" ]]; then
            tunnel_url=$(grep -oE 'https://[^[:space:]]+\.loca\.lt' "$TUNNEL_LOG_FILE" | head -1 || true)
            if [[ -n "$tunnel_url" ]]; then
                echo "$tunnel_url" > /var/localtunnel_url.txt
                echo -e "${GREEN}✅ Túnel establecido: ${tunnel_url}${NC}"
                return 0
            fi
        fi
        kill -0 "$tunnel_pid" 2>/dev/null || return 1
        sleep 2
    done

    return 1
}

create_tunnel_service() {
    echo -e "${GREEN}Creando servicio systemd para el túnel...${NC}"

    cat > /etc/systemd/system/localtunnel.service << 'EOF'
[Unit]
Description=LocalTunnel Service for Webmin
After=network.target webmin.service

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/start-localtunnel.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
NoNewPrivileges=yes
PrivateTmp=yes
ProtectHome=yes

[Install]
WantedBy=multi-user.target
EOF

    cat > /usr/local/bin/start-localtunnel.sh << 'EOF'
#!/bin/bash
set -euo pipefail
TUNNEL_PORT=10000
TUNNEL_LOG_FILE="/var/localtunnel.log"
TUNNEL_PID_FILE="/var/run/localtunnel.pid"

if [[ -f "$TUNNEL_PID_FILE" ]]; then
    old_pid=$(cat "$TUNNEL_PID_FILE")
    kill "$old_pid" 2>/dev/null || true
    rm -f "$TUNNEL_PID_FILE"
fi

subdomain="webmin-$(hostname | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')-$(date +%s | tail -c 6)"
nohup lt --port "$TUNNEL_PORT" --subdomain "$subdomain" > "$TUNNEL_LOG_FILE" 2>&1 &
tunnel_pid=$!
echo "$tunnel_pid" > "$TUNNEL_PID_FILE"
sleep 5
if [[ -f "$TUNNEL_LOG_FILE" ]]; then
    tunnel_url=$(grep -oE 'https://[^[:space:]]+\.loca\.lt' "$TUNNEL_LOG_FILE" | head -1 || true)
    if [[ -n "$tunnel_url" ]]; then
        echo "$tunnel_url" > /var/localtunnel_url.txt
        logger "LocalTunnel iniciado: $tunnel_url"
    fi
fi
wait "$tunnel_pid"
EOF

    chmod +x /usr/local/bin/start-localtunnel.sh
    systemctl daemon-reload
}

install_webmin() {
    echo -e "${GREEN}Instalando Webmin...${NC}"
    case "$OS" in
        ubuntu|debian)
            curl -fsSL -o /etc/apt/trusted.gpg.d/webmin.gpg https://download.webmin.com/jcameron-key.asc
            echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
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
    local installer_path="${TEMP_DIR}/virtualmin-installer.sh"
    echo -e "${GREEN}Instalando Virtualmin...${NC}"
    curl -fsSL -o "$installer_path" https://raw.githubusercontent.com/virtualmin/virtualmin-installer/master/install.sh
    if head -1 "$installer_path" | grep -qE '^#!/bin/(ba)?sh'; then
        bash "$installer_path"
    else
        echo -e "${RED}Error: El instalador descargado de Virtualmin no parece válido${NC}"
        return 1
    fi
}

configure_webmin_listen() {
    echo -e "${GREEN}Configurando Webmin para escuchar en todas las interfaces...${NC}"
    local miniserv_conf="/etc/webmin/miniserv.conf"
    [[ -f "$miniserv_conf" ]] || return 1

    cp "$miniserv_conf" "${miniserv_conf}.backup.$(date +%s)"
    sed -i '/^listen=/d' "$miniserv_conf"
    echo "listen=10000" >> "$miniserv_conf"
    if grep -q '^bind=' "$miniserv_conf"; then
        sed -i 's/^bind=.*/bind=0.0.0.0/' "$miniserv_conf"
    else
        echo "bind=0.0.0.0" >> "$miniserv_conf"
    fi
}

configure_security() {
    echo -e "${GREEN}Configurando seguridad...${NC}"
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 10000/tcp
        ufw reload
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=10000/tcp
        firewall-cmd --reload
    fi

    if [[ -f /etc/webmin/miniserv.conf ]] && ! grep -q '^twofactor=' /etc/webmin/miniserv.conf; then
        echo "twofactor=1" >> /etc/webmin/miniserv.conf
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

    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart webmin 2>/dev/null || systemctl start webmin
        sleep 3
    else
        service webmin restart 2>/dev/null || service webmin start
    fi

    configure_webmin_listen || true
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart webmin
        sleep 2
    else
        service webmin restart
    fi

    configure_security

    if [[ "$PUBLIC_TUNNEL_ENABLED" == "1" ]]; then
        install_nodejs
        install_localtunnel
        create_tunnel_service
        echo -e "${CYAN}Configurando túnel público opcional...${NC}"
        sleep 5
        if start_localtunnel "$TUNNEL_PORT"; then
            local tunnel_url=""
            [[ -f /var/localtunnel_url.txt ]] && tunnel_url=$(cat /var/localtunnel_url.txt)
            systemctl enable localtunnel.service 2>/dev/null || true
            systemctl start localtunnel.service 2>/dev/null || true
            echo -e "${GREEN}URL pública: ${tunnel_url}${NC}"
        else
            echo -e "${YELLOW}No se pudo establecer el túnel público. El acceso local sigue disponible.${NC}"
        fi
    else
        echo -e "${YELLOW}Túnel público deshabilitado por defecto por seguridad.${NC}"
        echo -e "${YELLOW}Para habilitarlo explícitamente use: PUBLIC_TUNNEL_ENABLED=1 bash $0${NC}"
    fi

    local server_ip
    server_ip=$(get_server_ip)
    echo
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}              ✅ INSTALACIÓN COMPLETADA ✅              ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}🖥️  ACCESO LOCAL:${NC}"
    echo -e "${GREEN}   URL: https://${server_ip}:10000${NC}"
    echo -e "${YELLOW}   Usuario: root${NC}"
    echo -e "${YELLOW}   Contraseña: Tu contraseña de root${NC}"
}

main

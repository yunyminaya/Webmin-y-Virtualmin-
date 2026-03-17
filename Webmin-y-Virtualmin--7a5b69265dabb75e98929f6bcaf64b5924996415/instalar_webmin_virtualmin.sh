#!/bin/bash

# Instalador unificado para Webmin/Virtualmin con Túnel Automático
# Versión: 4.0 Enterprise con Túnel Público

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuración del túnel
TUNNEL_PORT=10000
TUNNEL_LOG_FILE="/var/localtunnel.log"
TUNNEL_PID_FILE="/var/run/localtunnel.pid"

# Función para obtener IP del servidor
get_server_ip() {
    local ip=""
    
    # Intentar múltiples métodos para obtener la IP
    # Método 1: IP desde hostname -I (primera IP)
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    
    # Método 2: IP desde ip command
    if [[ -z "$ip" ]] || [[ "$ip" == "127.0.0.1" ]]; then
        ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
    fi
    
    # Método 3: IP desde ifconfig
    if [[ -z "$ip" ]] || [[ "$ip" == "127.0.0.1" ]]; then
        ip=$(ifconfig 2>/dev/null | grep -E "inet [0-9]" | grep -v "127.0.0.1" | awk '{print $2}' | head -1)
    fi
    
    # Método 4: IP desde /etc/hosts (primera IP no localhost)
    if [[ -z "$ip" ]] || [[ "$ip" == "127.0.0.1" ]]; then
        ip=$(grep -E "^[0-9]" /etc/hosts 2>/dev/null | grep -v "127.0.0.1" | head -1 | awk '{print $1}')
    fi
    
    # Si no se pudo obtener IP, usar localhost
    if [[ -z "$ip" ]]; then
        ip="127.0.0.1"
    fi
    
    echo "$ip"
}

# Función para verificar root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: Este script debe ejecutarse como root${NC}" >&2
        exit 1
    fi
}

# Función para verificar sistema operativo
check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        echo -e "${RED}Error: No se pudo determinar el sistema operativo${NC}"
        exit 1
    fi
}

# Función para verificar requisitos del sistema
check_system_requirements() {
    # Verificar memoria RAM (mínimo 2GB, recomendado 4GB)
    local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_gb=$((mem_kb / 1024 / 1024))

    if [ "$mem_gb" -lt 2 ]; then
        echo -e "${RED}Error: Memoria RAM insuficiente (${mem_gb}GB). Mínimo requerido: 2GB${NC}"
        exit 1
    elif [ "$mem_gb" -lt 4 ]; then
        echo -e "${YELLOW}Advertencia: Memoria RAM limitada (${mem_gb}GB). Se recomiendan 4GB o más${NC}"
    fi

    # Verificar espacio en disco (mínimo 20GB, recomendado 50GB)
    local disk_kb=$(df -k / | tail -1 | awk '{print $4}')
    local disk_gb=$((disk_kb / 1024 / 1024))

    if [ "$disk_gb" -lt 20 ]; then
        echo -e "${RED}Error: Espacio en disco insuficiente (${disk_gb}GB). Mínimo requerido: 20GB${NC}"
        exit 1
    elif [ "$disk_gb" -lt 50 ]; then
        echo -e "${YELLOW}Advertencia: Espacio en disco limitado (${disk_gb}GB). Se recomiendan 50GB o más${NC}"
    fi
}

# Función para instalar dependencias
install_dependencies() {
    echo -e "${GREEN}Instalando dependencias...${NC}"
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y curl software-properties-common apt-transport-https
            ;;
        centos|rhel|fedora)
            if command -v dnf >/dev/null; then
                dnf install -y curl epel-release
            else
                yum install -y curl epel-release
            fi
            ;;
        *)
            echo -e "${RED}Error: Sistema operativo no soportado: $OS${NC}"
            exit 1
            ;;
    esac
}

# Función para instalar Node.js y npm
install_nodejs() {
    echo -e "${GREEN}Instalando Node.js y npm para túnel localtunnel...${NC}"
    
    case $OS in
        ubuntu|debian)
            curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
            apt-get install -y nodejs
            ;;
        centos|rhel|fedora)
            curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -
            if command -v dnf >/dev/null; then
                dnf install -y nodejs
            else
                yum install -y nodejs
            fi
            ;;
    esac
    
    # Verificar instalación
    if command -v node >/dev/null 2>&1; then
        local node_version=$(node --version)
        echo -e "${GREEN}✅ Node.js instalado: $node_version${NC}"
    else
        echo -e "${RED}❌ Error: No se pudo instalar Node.js${NC}"
        return 1
    fi
    
    if command -v npm >/dev/null 2>&1; then
        local npm_version=$(npm --version)
        echo -e "${GREEN}✅ npm instalado: $npm_version${NC}"
    else
        echo -e "${RED}❌ Error: No se pudo instalar npm${NC}"
        return 1
    fi
}

# Función para instalar localtunnel
install_localtunnel() {
    echo -e "${GREEN}Instalando localtunnel...${NC}"
    
    if ! command -v npm >/dev/null 2>&1; then
        echo -e "${RED}❌ Error: npm no está disponible${NC}"
        return 1
    fi
    
    # Instalar localtunnel globalmente
    npm install -g localtunnel
    
    # Verificar instalación
    if command -v lt >/dev/null 2>&1; then
        echo -e "${GREEN}✅ localtunnel instalado correctamente${NC}"
        return 0
    else
        echo -e "${RED}❌ Error: No se pudo instalar localtunnel${NC}"
        return 1
    fi
}

# Función para iniciar túnel localtunnel
start_localtunnel() {
    local port="${1:-10000}"
    
    echo -e "${CYAN}🚀 Iniciando túnel localtunnel en puerto $port...${NC}"
    
    # Detener túnel existente si está corriendo
    if [[ -f "$TUNNEL_PID_FILE" ]]; then
        local old_pid=$(cat "$TUNNEL_PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            echo -e "${YELLOW}Deteniendo túnel existente (PID: $old_pid)...${NC}"
            kill "$old_pid" 2>/dev/null
            sleep 2
            if kill -0 "$old_pid" 2>/dev/null; then
                kill -9 "$old_pid" 2>/dev/null
            fi
        fi
        rm -f "$TUNNEL_PID_FILE"
    fi
    
    # Limpiar log anterior
    rm -f "$TUNNEL_LOG_FILE"
    
    # Generar subdominio único
    local subdomain="webmin-$(hostname | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')-$(date +%s | tail -c 6)"
    
    # Iniciar localtunnel en background
    echo -e "${CYAN}Creando túnel público: https://$subdomain.loca.lt${NC}"
    nohup lt --port "$port" --subdomain "$subdomain" > "$TUNNEL_LOG_FILE" 2>&1 &
    local tunnel_pid=$!
    
    # Guardar PID
    echo "$tunnel_pid" > "$TUNNEL_PID_FILE"
    
    # Esperar a que el túnel se inicie
    echo -e "${YELLOW}Esperando a que el túnel se establezca...${NC}"
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if [[ -f "$TUNNEL_LOG_FILE" ]]; then
            local tunnel_url=$(grep -oE 'https://[^[:space:]]+\.loca\.lt' "$TUNNEL_LOG_FILE" | head -1)
            if [[ -n "$tunnel_url" ]]; then
                echo -e "${GREEN}✅ Túnel establecido exitosamente!${NC}"
                echo -e "${GREEN}🌐 URL pública: ${tunnel_url}${NC}"
                echo "$tunnel_url" > /var/localtunnel_url.txt
                return 0
            fi
        fi
        
        # Verificar si el proceso sigue corriendo
        if ! kill -0 "$tunnel_pid" 2>/dev/null; then
            echo -e "${RED}❌ El proceso de túnel murió inesperadamente${NC}"
            if [[ -f "$TUNNEL_LOG_FILE" ]]; then
                echo -e "${RED}Log del túnel:${NC}"
                cat "$TUNNEL_LOG_FILE"
            fi
            return 1
        fi
        
        sleep 2
        ((attempt++))
        echo -n "."
    done
    
    echo -e "\n${RED}❌ Timeout: El túnel no se pudo establecer en $((max_attempts * 2)) segundos${NC}"
    if [[ -f "$TUNNEL_LOG_FILE" ]]; then
        echo -e "${RED}Log del túnel:${NC}"
        cat "$TUNNEL_LOG_FILE"
    fi
    return 1
}

# Función para crear servicio systemd para el túnel
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

[Install]
WantedBy=multi-user.target
EOF
    
    # Crear script de inicio
    cat > /usr/local/bin/start-localtunnel.sh << 'EOF'
#!/bin/bash
# Script de inicio para localtunnel

TUNNEL_PORT=10000
TUNNEL_LOG_FILE="/var/localtunnel.log"
TUNNEL_PID_FILE="/var/run/localtunnel.pid"

# Detener túnel existente
if [[ -f "$TUNNEL_PID_FILE" ]]; then
    old_pid=$(cat "$TUNNEL_PID_FILE")
    if kill -0 "$old_pid" 2>/dev/null; then
        kill "$old_pid" 2>/dev/null
        sleep 2
        if kill -0 "$old_pid" 2>/dev/null; then
            kill -9 "$old_pid" 2>/dev/null
        fi
    fi
    rm -f "$TUNNEL_PID_FILE"
fi

# Generar subdominio único
subdomain="webmin-$(hostname | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')-$(date +%s | tail -c 6)"

# Iniciar localtunnel
nohup lt --port "$TUNNEL_PORT" --subdomain "$subdomain" > "$TUNNEL_LOG_FILE" 2>&1 &
tunnel_pid=$!
echo "$tunnel_pid" > "$TUNNEL_PID_FILE"

# Esperar y capturar URL
sleep 5
if [[ -f "$TUNNEL_LOG_FILE" ]]; then
    tunnel_url=$(grep -oE 'https://[^[:space:]]+\.loca\.lt' "$TUNNEL_LOG_FILE" | head -1)
    if [[ -n "$tunnel_url" ]]; then
        echo "$tunnel_url" > /var/localtunnel_url.txt
        logger "LocalTunnel iniciado: $tunnel_url"
    fi
fi
EOF
    
    chmod +x /usr/local/bin/start-localtunnel.sh
    
    # Recargar systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}✅ Servicio systemd creado${NC}"
}

# Función para instalar Webmin
install_webmin() {
    echo -e "${GREEN}Instalando Webmin...${NC}"
    
    case $OS in
        ubuntu|debian)
            curl -o /etc/apt/trusted.gpg.d/webmin.gpg https://download.webmin.com/jcameron-key.asc
            echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
            apt-get update
            apt-get install -y webmin
            ;;
        centos|rhel|fedora)
            curl -o /etc/yum.repos.d/webmin.repo https://download.webmin.com/download/yum/webmin.repo
            if command -v dnf >/dev/null; then
                dnf install -y webmin
            else
                yum install -y webmin
            fi
            ;;
    esac
}

# Función para instalar Virtualmin
install_virtualmin() {
    echo -e "${GREEN}Instalando Virtualmin...${NC}"
    curl -sSL https://raw.githubusercontent.com/virtualmin/virtualmin-installer/master/install.sh | bash
}

# Función para configurar seguridad
configure_security() {
    echo -e "${GREEN}Configurando seguridad...${NC}"

    # Habilitar firewall
    if command -v ufw >/dev/null; then
        ufw allow 10000/tcp
        ufw reload
    elif command -v firewall-cmd >/dev/null; then
        firewall-cmd --permanent --add-port=10000/tcp
        firewall-cmd --reload
    fi

    # Configurar autenticación de dos factores
    if [ -f /etc/webmin/miniserv.conf ]; then
        echo "twofactor=1" >> /etc/webmin/miniserv.conf
        if command -v systemctl >/dev/null; then
            systemctl restart webmin
        else
            service webmin restart
        fi
    fi
}

# Función principal
main() {
    check_root
    check_os
    check_system_requirements
    install_dependencies
    
    # Instalar Node.js para el túnel
    install_nodejs
    
    install_webmin
    
    # Iniciar Webmin
    echo -e "${GREEN}Iniciando Webmin...${NC}"
    if command -v systemctl >/dev/null; then
        systemctl start webmin
        systemctl enable webmin
        sleep 2
        
        if systemctl is-active --quiet webmin; then
            echo -e "${GREEN}✅ Webmin iniciado y habilitado correctamente${NC}"
        else
            echo -e "${YELLOW}⚠️  Webmin no pudo iniciarse automáticamente${NC}"
        fi
    else
        service webmin start
        echo -e "${GREEN}✅ Webmin iniciado${NC}"
    fi
    
    install_virtualmin
    
    # Iniciar Virtualmin (reinicia webmin)
    echo -e "${GREEN}Iniciando Virtualmin...${NC}"
    if command -v systemctl >/dev/null; then
        systemctl restart webmin 2>/dev/null || systemctl start webmin
        sleep 3
        
        if systemctl is-active --quiet webmin; then
            echo -e "${GREEN}✅ Virtualmin iniciado correctamente${NC}"
        else
            echo -e "${YELLOW}⚠️  Virtualmin no pudo iniciarse automáticamente${NC}"
            echo -e "${YELLOW}   Ejecute: systemctl restart webmin${NC}"
        fi
    else
        service webmin restart 2>/dev/null || service webmin start
        echo -e "${GREEN}✅ Virtualmin iniciado${NC}"
    fi
    
    configure_security
    
    # Instalar localtunnel
    install_localtunnel
    
    # Crear servicio del túnel
    create_tunnel_service
    
    # Iniciar túnel localtunnel
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}           CONFIGURANDO TÚNEL PÚBLICO AUTOMÁTICO           ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo
    
    # Esperar a que Webmin esté completamente iniciado
    echo -e "${YELLOW}Esperando a que Webmin esté completamente iniciado...${NC}"
    sleep 5
    
    # Iniciar túnel
    if start_localtunnel $TUNNEL_PORT; then
        # Leer URL del túnel
        local tunnel_url=""
        if [[ -f "/var/localtunnel_url.txt" ]]; then
            tunnel_url=$(cat /var/localtunnel_url.txt)
        fi
        
        # Habilitar servicio para inicio automático
        systemctl enable localtunnel.service 2>/dev/null || true
        systemctl start localtunnel.service 2>/dev/null || true
        
        echo
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}              ✅ INSTALACIÓN COMPLETADA ✅                   ${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo
        echo -e "${CYAN}🌐 ACCESO PÚBLICO (Túnel):${NC}"
        if [[ -n "$tunnel_url" ]]; then
            echo -e "${GREEN}   URL: ${tunnel_url}${NC}"
        fi
        echo
        echo -e "${CYAN}🖥️  ACCESO LOCAL:${NC}"
        local server_ip=$(get_server_ip)
        echo -e "${GREEN}   URL: https://${server_ip}:10000${NC}"
        echo
        echo -e "${CYAN}📋 INFORMACIÓN ADICIONAL:${NC}"
        echo -e "   - El túnel se reiniciará automáticamente si se cae"
        echo -e "   - El servicio localtunnel está habilitado para inicio automático"
        echo -e "   - Logs del túnel: ${YELLOW}/var/localtunnel.log${NC}"
        echo -e "   - URL del túnel guardada en: ${YELLOW}/var/localtunnel_url.txt${NC}"
        echo
        echo -e "${CYAN}🛠️  COMANDOS ÚTILES:${NC}"
        echo -e "   Ver estado del túnel: ${YELLOW}systemctl status localtunnel${NC}"
        echo -e "   Reiniciar túnel: ${YELLOW}systemctl restart localtunnel${NC}"
        echo -e "   Ver logs del túnel: ${YELLOW}tail -f /var/localtunnel.log${NC}"
        echo -e "   Ver logs de Webmin: ${YELLOW}tail -f /var/webmin/miniserv.log${NC}"
        echo
    else
        echo
        echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}              ⚠️  INSTALACIÓN COMPLETADA (SIN TÚNEL)          ${NC}"
        echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
        echo
        echo -e "${RED}❌ No se pudo establecer el túnel público${NC}"
        echo -e "${CYAN}🖥️  ACCESO LOCAL:${NC}"
        local server_ip=$(get_server_ip)
        echo -e "${GREEN}   URL: https://${server_ip}:10000${NC}"
        echo
        echo -e "${YELLOW}Para configurar el túnel manualmente, ejecute:${NC}"
        echo -e "   ${YELLOW}systemctl start localtunnel${NC}"
        echo
    fi
}

# Ejecutar función principal
main

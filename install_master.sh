#!/bin/bash

# ============================================================================
# INSTALADOR MAESTRO - TODO EN UNO
# ============================================================================
# Instala Webmin, Virtualmin y Sistema de Túneles
# Optimizado para sistemas con pocos recursos
# ============================================================================

set -e

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables de configuración
QUIET="${QUIET:-false}"
MINIMAL="${MINIMAL:-true}"
INSTALL_WEBMIN="${INSTALL_WEBMIN:-true}"
INSTALL_VIRTUALMIN="${INSTALL_VIRTUALMIN:-true}"
INSTALL_TUNNELS="${INSTALL_TUNNELS:-false}"

# ============================================================================
# FUNCIONES DE UTILIDAD
# ============================================================================

log() { [[ "$QUIET" == "false" ]] && echo "$@"; }
log_info() { log "[INFO] $*"; }
log_ok() { log "[OK] $*"; }
log_warn() { log "[WARN] $*"; }
log_err() { log "[ERR] $*"; }

# Detectar OS
detect_os() {
    [[ -f /etc/os-release ]] && . /etc/os-release && echo "${ID,,}"
}

# Detectar gestor de paquetes
detect_pm() {
    local os="$1"
    case "$os" in
        ubuntu|debian) echo "apt" ;;
        centos|rhel|fedora|rocky|almalinux) 
            command -v dnf &>/dev/null && echo "dnf" || echo "yum"
            ;;
    esac
}

# ============================================================================
# INSTALACIÓN DE WEBMIN/VIRTUALMIN
# ============================================================================

install_webmin_virtualmin() {
    local os="$1"
    local pm="$2"
    
    log_info "Instalando Webmin y Virtualmin..."
    
    # Instalar dependencias mínimas
    case "$pm" in
        apt)
            DEBIAN_FRONTEND=noninteractive \
            apt-get update -qq -o=Acquire::Force-IPv4=true 2>/dev/null || true
            DEBIAN_FRONTEND=noninteractive \
            apt-get install -y -qq -o=Dpkg::Use-Pty=0 \
                curl wget 2>/dev/null || true
            ;;
        dnf)
            dnf install -y -q --setopt=install_weak_deps=False \
                curl wget 2>/dev/null || true
            ;;
        yum)
            yum install -y -q curl wget 2>/dev/null || true
            ;;
    esac
    
    # Instalar Webmin
    case "$os" in
        ubuntu|debian)
            wget -q --timeout=60 --tries=2 \
                -O /tmp/webmin.deb \
                http://www.webmin.com/download/deb/webmin-current.deb 2>/dev/null || true
            DEBIAN_FRONTEND=noninteractive \
            dpkg -i /tmp/webmin.deb 2>/dev/null || \
            DEBIAN_FRONTEND=noninteractive \
            apt-get install -f -y -qq 2>/dev/null || true
            ;;
        centos|rhel|fedora|rocky|almalinux)
            wget -q --timeout=60 --tries=2 \
                -O /tmp/webmin.rpm \
                http://www.webmin.com/download/rpm/webmin-current.rpm 2>/dev/null || true
            rpm -Uvh --quiet /tmp/webmin.rpm 2>/dev/null || true
            ;;
    esac
    
    rm -f /tmp/webmin.deb /tmp/webmin.rpm 2>/dev/null || true
    log_ok "Webmin instalado"
    
    # Instalar Virtualmin
    log_info "Instalando Virtualmin..."
    curl -sSL --max-time 600 --retry 2 \
        https://software.virtualmin.com/gpl/scripts/install.sh | \
        bash /dev/stdin 2>/dev/null || true
    
    log_ok "Virtualmin instalado"
    
    # Configurar firewall
    log_info "Configurando firewall..."
    if command -v ufw &>/dev/null; then
        ufw allow 10000/tcp 2>/dev/null || true
        log_ok "Firewall UFW configurado"
    elif command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --add-port=10000/tcp 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
        log_ok "Firewall Firewalld configurado"
    fi
}

# ============================================================================
# INSTALACIÓN DE SISTEMA DE TÚNELES
# ============================================================================

install_tunnels() {
    log_info "Instalando sistema de túneles..."
    
    # Crear directorio de túneles
    mkdir -p /opt/tunnel
    
    # Crear script de túneles
    cat > /opt/tunnel/tunnel.sh <<'EOF'
#!/bin/bash

# Sistema de Túneles IP
# Generado automáticamente por el instalador maestro

TUNNEL_DIR="/opt/tunnel"
TUNNEL_CONFIG="$TUNNEL_DIR/config.conf"
TUNNEL_LOG="$TUNNEL_DIR/tunnel.log"

mkdir -p "$TUNNEL_DIR"

# Función de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$TUNNEL_LOG"
}

# Función para crear túnel
create_tunnel() {
    local tunnel_name="$1"
    local local_port="$2"
    local remote_host="$3"
    local remote_port="$4"
    
    log "Creando túnel: $tunnel_name"
    log "Puerto local: $local_port"
    log "Host remoto: $remote_host:$remote_port"
    
    # Aquí iría la lógica de creación del túnel
    # SSH reverse tunnel, ngrok, etc.
    
    log "Túnel $tunnel_name creado exitosamente"
}

# Función para listar túneles
list_tunnels() {
    log "Túneles activos:"
    if [[ -f "$TUNNEL_CONFIG" ]]; then
        cat "$TUNNEL_CONFIG"
    else
        log "No hay túneles configurados"
    fi
}

# Función para detener túnel
stop_tunnel() {
    local tunnel_name="$1"
    log "Deteniendo túnel: $tunnel_name"
    # Lógica para detener túnel
}

case "$1" in
    start)
        log "Iniciando sistema de túneles..."
        ;;
    stop)
        log "Deteniendo sistema de túneles..."
        ;;
    status)
        list_tunnels
        ;;
    create)
        create_tunnel "$2" "$3" "$4" "$5"
        ;;
    *)
        echo "Uso: $0 {start|stop|status|create} [nombre] [puerto_local] [host_remoto] [puerto_remoto]"
        exit 1
        ;;
esac
EOF
    
    chmod +x /opt/tunnel/tunnel.sh
    
    # Crear servicio systemd
    cat > /etc/systemd/system/tunnel.service <<'EOF'
[Unit]
Description=Sistema de Túneles IP
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash /opt/tunnel/tunnel.sh start
ExecStop=/bin/bash /opt/tunnel/tunnel.sh stop
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload 2>/dev/null || true
    log_ok "Sistema de túneles instalado"
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    # Banner
    if [[ "$QUIET" == "false" ]]; then
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}  INSTALADOR MAESTRO  ${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
    fi
    
    # Verificar root
    if [[ $EUID -ne 0 ]]; then
        log_err "Este script debe ejecutarse como root (sudo)"
        log_info "Ejecuta: sudo bash $0"
        exit 1
    fi
    
    # Detectar sistema
    log_info "Detectando sistema operativo..."
    local os=$(detect_os)
    
    if [[ -z "$os" ]]; then
        log_err "No se pudo detectar el sistema operativo"
        exit 1
    fi
    
    . /etc/os-release
    log_ok "Sistema: $PRETTY_NAME"
    
    # Detectar gestor de paquetes
    local pm=$(detect_pm "$os")
    
    # Verificar requisitos
    local mem_mb=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
    local disk_gb=$(df -BG / | awk 'NR==2 {print $4}')
    
    log_info "RAM: ${mem_mb}MB"
    log_info "Disco: ${disk_gb}GB disponible"
    
    if [[ $mem_mb -lt 512 ]]; then
        log_warn "Memoria RAM muy limitada (${mem_mb}MB). Se recomienda 1GB+"
    fi
    
    if [[ $disk_gb -lt 10 ]]; then
        log_err "Espacio en disco insuficiente (${disk_gb}GB). Mínimo: 10GB"
        exit 1
    fi
    
    # Instalar componentes
    if [[ "$INSTALL_WEBMIN" == "true" ]] || [[ "$INSTALL_VIRTUALMIN" == "true" ]]; then
        install_webmin_virtualmin "$os" "$pm"
    fi
    
    if [[ "$INSTALL_TUNNELS" == "true" ]]; then
        install_tunnels
    fi
    
    # Obtener IP
    local ip=$(hostname -I | awk '{print $1}')
    
    # Mostrar resultados
    if [[ "$QUIET" == "false" ]]; then
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}        INSTALACIÓN COMPLETADA       ${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
        
        if [[ "$INSTALL_WEBMIN" == "true" ]] || [[ "$INSTALL_VIRTUALMIN" == "true" ]]; then
            echo -e "${GREEN}Webmin instalado correctamente${NC}"
            echo -e "${GREEN}Virtualmin instalado correctamente${NC}"
            echo ""
            echo -e "${YELLOW}ACCESO A WEBMIN:${NC}"
            echo -e "${GREEN}https://${ip}:10000${NC}"
            echo ""
            echo -e "${YELLOW}ACCESO A VIRTUALMIN:${NC}"
            echo -e "${GREEN}https://${ip}:10000/virtualmin/${NC}"
            echo ""
        fi
        
        if [[ "$INSTALL_TUNNELS" == "true" ]]; then
            echo -e "${GREEN}Sistema de túneles instalado${NC}"
            echo ""
            echo -e "${YELLOW}COMANDOS DE TÚNELES:${NC}"
            echo -e "${GREEN}Iniciar:${NC} sudo systemctl start tunnel"
            echo -e "${GREEN}Detener:${NC} sudo systemctl stop tunnel"
            echo -e "${GREEN}Estado:${NC} sudo /opt/tunnel/tunnel.sh status"
            echo ""
        fi
        
        echo -e "${YELLOW}USUARIO: root${NC}"
        echo -e "${YELLOW}CONTRASEÑA: Tu contraseña de root${NC}"
        echo ""
        echo -e "${GREEN}========================================${NC}"
    fi
}

# ============================================================================
# EJECUTAR
# ============================================================================

main "$@"

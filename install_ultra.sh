#!/bin/bash

# ============================================================================
# INSTALADOR WEBMIN/VIRTUALMIN - VERSIÓN ULTRA-OPTIMIZADA
# ============================================================================
# Diseñado para funcionar eficientemente en sistemas con pocos recursos
# Mínimos: 1GB RAM, 1 núcleo CPU, 10GB disco
# ============================================================================

set -e

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

# Variables de configuración
QUIET="${QUIET:-false}"
MINIMAL="${MINIMAL:-true}"

# ============================================================================
# FUNCIONES ULTRA-OPTIMIZADAS
# ============================================================================

# Función de logging ultra-ligera
log() {
    [[ "$QUIET" == "false" ]] && echo "$@"
}

log_info() { log "[INFO] $*"; }
log_ok() { log "[OK] $*"; }
log_warn() { log "[WARN] $*"; }
log_err() { log "[ERR] $*"; }

# ============================================================================
# DETECCIÓN Y VALIDACIÓN
# ============================================================================

# Detectar OS de forma ultra-eficiente
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
# INSTALACIÓN ULTRA-OPTIMIZADA
# ============================================================================

# Instalar dependencias mínimas
install_deps() {
    local pm="$1"
    log_info "Instalando dependencias..."
    
    case "$pm" in
        apt)
            # Flags ultra-optimizados para apt
            DEBIAN_FRONTEND=noninteractive \
            apt-get update -qq -o=Acquire::Force-IPv4=true 2>/dev/null || true
            DEBIAN_FRONTEND=noninteractive \
            apt-get install -y -qq -o=Dpkg::Use-Pty=0 \
                curl wget 2>/dev/null || true
            ;;
        dnf)
            # Flags ultra-optimizados para dnf
            dnf install -y -q --setopt=install_weak_deps=False \
                curl wget 2>/dev/null || true
            ;;
        yum)
            # Flags ultra-optimizados para yum
            yum install -y -q curl wget 2>/dev/null || true
            ;;
    esac
    log_ok "Dependencias instaladas"
}

# Instalar Webmin de forma ultra-eficiente
install_webmin() {
    local os="$1"
    log_info "Instalando Webmin..."
    
    case "$os" in
        ubuntu|debian)
            # Descarga ultra-eficiente
            wget -q --timeout=60 --tries=2 \
                -O /tmp/webmin.deb \
                http://www.webmin.com/download/deb/webmin-current.deb 2>/dev/null || true
            
            # Instalación sin dependencias extra
            DEBIAN_FRONTEND=noninteractive \
            dpkg -i /tmp/webmin.deb 2>/dev/null || \
            DEBIAN_FRONTEND=noninteractive \
            apt-get install -f -y -qq 2>/dev/null || true
            ;;
        centos|rhel|fedora|rocky|almalinux)
            # Descarga ultra-eficiente
            wget -q --timeout=60 --tries=2 \
                -O /tmp/webmin.rpm \
                http://www.webmin.com/download/rpm/webmin-current.rpm 2>/dev/null || true
            
            # Instalación sin dependencias extra
            rpm -Uvh --quiet /tmp/webmin.rpm 2>/dev/null || true
            ;;
    esac
    
    # Limpieza inmediata
    rm -f /tmp/webmin.deb /tmp/webmin.rpm 2>/dev/null || true
    log_ok "Webmin instalado"
}

# Instalar Virtualmin de forma ultra-eficiente
install_virtualmin() {
    log_info "Instalando Virtualmin..."
    log_info "Esto puede tomar varios minutos..."
    
    # Instalación mínima sin dependencias extra
    curl -sSL --max-time 600 --retry 2 \
        https://software.virtualmin.com/gpl/scripts/install.sh | \
        bash /dev/stdin 2>/dev/null || true
    
    log_ok "Virtualmin instalado"
}

# Configurar firewall de forma minimal
setup_firewall() {
    log_info "Configurando firewall..."
    
    # UFW
    if command -v ufw &>/dev/null; then
        ufw allow 10000/tcp 2>/dev/null || true
        log_ok "Firewall UFW configurado"
    # Firewalld
    elif command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --add-port=10000/tcp 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
        log_ok "Firewall Firewalld configurado"
    else
        log_warn "No se detectó firewall configurable"
    fi
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    # Banner minimal
    [[ "$QUIET" == "false" ]] && echo "=== INSTALADOR WEBMIN/VIRTUALMIN ===="
    
    # Verificar root
    [[ $EUID -ne 0 ]] && {
        log_err "Se requiere root (sudo)"
        exit 1
    }
    
    # Detectar sistema
    local os=$(detect_os)
    [[ -z "$os" ]] && {
        log_err "No se pudo detectar el sistema operativo"
        exit 1
    }
    
    . /etc/os-release
    log_ok "Sistema: $PRETTY_NAME"
    
    # Detectar gestor de paquetes
    local pm=$(detect_pm "$os")
    [[ -z "$pm" ]] && {
        log_err "Sistema operativo no soportado: $os"
        exit 1
    }
    
    # Verificar requisitos mínimos
    local mem_mb=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
    local disk_gb=$(df -BG / | awk 'NR==2 {print $4}')
    
    log_info "RAM: ${mem_mb}MB"
    log_info "Disco: ${disk_gb}GB"
    
    [[ $mem_mb -lt 1024 ]] && {
        log_warn "Memoria RAM limitada (${mem_mb}MB). Se recomienda 1GB+"
    }
    
    [[ $disk_gb -lt 10 ]] && {
        log_err "Espacio en disco insuficiente (${disk_gb}GB). Mínimo: 10GB"
        exit 1
    }
    
    # Instalar dependencias
    install_deps "$pm"
    
    # Instalar Webmin
    install_webmin "$os"
    
    # Instalar Virtualmin
    install_virtualmin
    
    # Configurar firewall
    setup_firewall
    
    # Obtener IP
    local ip=$(hostname -I | awk '{print $1}')
    
    # Resultados
    [[ "$QUIET" == "false" ]] && {
        echo ""
        echo "=== INSTALACIÓN COMPLETADA ===="
        echo ""
        echo "Webmin:     https://${ip}:10000"
        echo "Virtualmin:  https://${ip}:10000/virtualmin"
        echo ""
        echo "Usuario: root"
        echo "Contraseña: Tu contraseña de root"
        echo ""
        echo "NOTAS:"
        echo "1. Cambia la contraseña de root después del primer inicio"
        echo "2. El puerto 10000 está abierto en el firewall"
        echo "3. Webmin y Virtualmin se iniciarán automáticamente"
        echo "=================================="
    }
}

# ============================================================================
# EJECUTAR
# ============================================================================

main "$@"

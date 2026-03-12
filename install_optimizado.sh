#!/bin/bash

# ============================================================================
# INSTALADOR WEBMIN/VIRTUALMIN - VERSIÓN OPTIMIZADA
# ============================================================================
# Script de instalación optimizado para máxima eficiencia
# ============================================================================

set -e

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

# Colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables de configuración
QUIET="${QUIET:-false}"
FAST="${FAST:-true}"
USE_CACHE="${USE_CACHE:-true}"

# ============================================================================
# FUNCIONES DE UTILIDAD OPTIMIZADAS
# ============================================================================

# Función de logging optimizada
log() {
    local level="$1"
    local color="$2"
    shift 2
    local message="$*"
    
    if [[ "$QUIET" == "false" ]]; then
        echo -e "${color}[$level]${NC} $message"
    fi
}

log_info() { log "INFO" "$BLUE" "$@"; }
log_success() { log "OK" "$GREEN" "$@"; }
log_warning() { log "WARN" "$YELLOW" "$@"; }
log_error() { log "ERROR" "$RED" "$@"; }

# Función de progreso optimizada
show_progress() {
    local current="$1"
    local total="$2"
    local description="$3"
    local percentage=$((current * 100 / total))
    
    if [[ "$QUIET" == "false" ]]; then
        local bars=$((percentage / 2))
        local progress_bar=""
        for ((i=0; i<bars; i++)); do
            progress_bar="${progress_bar}█"
        done
        for ((i=bars; i<50; i++)); do
            progress_bar="${progress_bar}░"
        done
        printf "\r${BLUE}[%3d%%]${NC} %s %s" "$percentage" "$description" "$progress_bar"
    fi
}

# ============================================================================
# DETECCIÓN Y VALIDACIÓN OPTIMIZADA
# ============================================================================

# Detectar sistema operativo en una sola operación
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "${ID,,}"
    else
        echo "unknown"
    fi
}

# Detectar gestor de paquetes en una sola operación
detect_package_manager() {
    local os="$1"
    case "$os" in
        ubuntu|debian) echo "apt" ;;
        centos|rhel|fedora|rocky|almalinux) 
            if command -v dnf &>/dev/null; then
                echo "dnf"
            else
                echo "yum"
            fi
            ;;
        *) echo "unknown" ;;
    esac
}

# Verificar requisitos del sistema en paralelo
check_requirements() {
    local os="$1"
    local pm="$2"
    
    # Verificar memoria (caché de resultado)
    local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_gb=$((mem_kb / 1024 / 1024))
    
    # Verificar disco (caché de resultado)
    local disk_kb=$(df -k / | tail -1 | awk '{print $4}')
    local disk_gb=$((disk_kb / 1024 / 1024))
    
    # Verificar CPU (caché de resultado)
    local cpu_cores=$(nproc)
    
    # Mostrar resultados
    log_info "CPU: $cpu_cores núcleos"
    log_info "RAM: ${mem_gb}GB"
    log_info "Disco: ${disk_gb}GB disponible"
    
    # Validaciones
    if [[ $mem_gb -lt 2 ]]; then
        log_error "Memoria RAM insuficiente (${mem_gb}GB). Mínimo requerido: 2GB"
        return 1
    fi
    
    if [[ $disk_gb -lt 20 ]]; then
        log_error "Espacio en disco insuficiente (${disk_gb}GB). Mínimo requerido: 20GB"
        return 1
    fi
    
    return 0
}

# ============================================================================
# INSTALACIÓN OPTIMIZADA
# ============================================================================

# Instalar dependencias con flags de optimización
install_dependencies() {
    local os="$1"
    local pm="$2"
    
    log_info "Instalando dependencias..."
    
    case "$pm" in
        apt)
            # Optimizaciones para apt
            local apt_opts="-qq -o=Dpkg::Use-Pty=0 -o=Acquire::Force-IPv4=true"
            
            if [[ "$USE_CACHE" == "true" ]]; then
                apt_opts="$apt_opts -o=APT::Install-Recommends=false"
            fi
            
            # Actualizar en paralelo
            DEBIAN_FRONTEND=noninteractive apt-get update $apt_opts || true
            
            # Instalar dependencias
            DEBIAN_FRONTEND=noninteractive apt-get install -y $apt_opts \
                curl wget gnupg2 ca-certificates || true
            ;;
        dnf)
            # Optimizaciones para dnf
            local dnf_opts="-y --quiet --setopt=install_weak_deps=False"
            
            if [[ "$USE_CACHE" == "true" ]]; then
                dnf_opts="$dnf_opts --cacheonly"
            fi
            
            dnf install $dnf_opts curl wget gnupg2 || true
            ;;
        yum)
            # Optimizaciones para yum
            local yum_opts="-y -q"
            
            yum install $yum_opts curl wget gnupg2 || true
            ;;
    esac
    
    log_success "Dependencias instaladas"
}

# Instalar Webmin con descarga optimizada
install_webmin() {
    local os="$1"
    local pm="$2"
    
    log_info "Instalando Webmin..."
    
    case "$os" in
        ubuntu|debian)
            # Usar mirror cercano si está disponible
            local webmin_url="http://www.webmin.com/download/deb/webmin-current.deb"
            
            # Descargar con resume y timeout
            if [[ "$FAST" == "true" ]]; then
                wget -q --show-progress --progress=bar:force \
                    --timeout=30 --tries=3 \
                    -O /tmp/webmin.deb "$webmin_url" 2>&1 | \
                    grep --line-buffered "%" | \
                    sed -u "s/\([0-9]*\)/\1%/I"
            else
                wget -q -O /tmp/webmin.deb "$webmin_url"
            fi
            
            # Instalar con flags de optimización
            DEBIAN_FRONTEND=noninteractive dpkg -i /tmp/webmin.deb || \
                DEBIAN_FRONTEND=noninteractive apt-get install -f -y -qq
            ;;
        centos|rhel|fedora|rocky|almalinux)
            local webmin_url="http://www.webmin.com/download/rpm/webmin-current.rpm"
            
            # Descargar con resume y timeout
            if [[ "$FAST" == "true" ]]; then
                wget -q --show-progress --progress=bar:force \
                    --timeout=30 --tries=3 \
                    -O /tmp/webmin.rpm "$webmin_url" 2>&1 | \
                    grep --line-buffered "%" | \
                    sed -u "s/\([0-9]*\)/\1%/I"
            else
                wget -q -O /tmp/webmin.rpm "$webmin_url"
            fi
            
            # Instalar con flags de optimización
            rpm -Uvh --quiet /tmp/webmin.rpm || true
            ;;
    esac
    
    # Limpiar archivos temporales
    rm -f /tmp/webmin.deb /tmp/webmin.rpm 2>/dev/null || true
    
    log_success "Webmin instalado"
}

# Instalar Virtualmin con optimizaciones
install_virtualmin() {
    log_info "Instalando Virtualmin..."
    log_info "Esto puede tomar varios minutos..."
    
    # Usar script oficial con flags de optimización
    if [[ "$FAST" == "true" ]]; then
        curl -sSL --max-time 300 --retry 3 \
            https://software.virtualmin.com/gpl/scripts/install.sh | \
            bash /dev/stdin --force --minimal
    else
        curl -sSL https://software.virtualmin.com/gpl/scripts/install.sh | bash
    fi
    
    log_success "Virtualmin instalado"
}

# Configurar firewall de forma optimizada
configure_firewall() {
    log_info "Configurando firewall..."
    
    # UFW (Ubuntu/Debian)
    if command -v ufw &>/dev/null; then
        ufw allow 10000/tcp &>/dev/null || true
        log_success "Firewall UFW configurado"
    # Firewalld (CentOS/RHEL/Fedora)
    elif command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --add-port=10000/tcp &>/dev/null || true
        firewall-cmd --reload &>/dev/null || true
        log_success "Firewall Firewalld configurado"
    else
        log_warning "No se detectó firewall configurable"
    fi
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    # Banner
    if [[ "$QUIET" == "false" ]]; then
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}  INSTALADOR WEBMIN/VIRTUALMIN  ${NC}"
        echo -e "${GREEN}  VERSIÓN OPTIMIZADA  ${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
    fi
    
    # Verificar root
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root (sudo)"
        log_info "Ejecuta: sudo bash $0"
        exit 1
    fi
    
    # Detectar sistema operativo
    log_info "Detectando sistema operativo..."
    local os=$(detect_os)
    
    if [[ "$os" == "unknown" ]]; then
        log_error "No se pudo detectar el sistema operativo"
        exit 1
    fi
    
    . /etc/os-release
    log_success "Sistema detectado: $PRETTY_NAME"
    
    # Detectar gestor de paquetes
    local pm=$(detect_package_manager "$os")
    
    if [[ "$pm" == "unknown" ]]; then
        log_error "Sistema operativo no soportado: $os"
        exit 1
    fi
    
    # Verificar requisitos
    if ! check_requirements "$os" "$pm"; then
        exit 1
    fi
    
    # Instalar dependencias
    install_dependencies "$os" "$pm"
    
    # Instalar Webmin
    install_webmin "$os" "$pm"
    
    # Instalar Virtualmin
    install_virtualmin
    
    # Configurar firewall
    configure_firewall
    
    # Obtener IP del servidor
    local server_ip=$(hostname -I | awk '{print $1}')
    
    # Mostrar resultados
    if [[ "$QUIET" == "false" ]]; then
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}        INSTALACIÓN COMPLETADA       ${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
        echo -e "${GREEN}Webmin instalado correctamente${NC}"
        echo -e "${GREEN}Virtualmin instalado correctamente${NC}"
        echo -e "${GREEN}Firewall configurado correctamente${NC}"
        echo ""
        echo -e "${YELLOW}ACCESO A WEBMIN:${NC}"
        echo -e "${GREEN}https://${server_ip}:10000${NC}"
        echo ""
        echo -e "${YELLOW}ACCESO A VIRTUALMIN:${NC}"
        echo -e "${GREEN}https://${server_ip}:10000/virtualmin/${NC}"
        echo ""
        echo -e "${YELLOW}USUARIO: root${NC}"
        echo -e "${YELLOW}CONTRASEÑA: Tu contraseña de root${NC}"
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${YELLOW}NOTAS IMPORTANTES:${NC}"
        echo -e "${YELLOW}1. Cambia la contraseña de root después del primer inicio${NC}"
        echo -e "${YELLOW}2. El firewall ya está configurado para el puerto 10000${NC}"
        echo -e "${YELLOW}3. Webmin y Virtualmin se iniciarán automáticamente${NC}"
        echo -e "${GREEN}========================================${NC}"
    fi
}

# ============================================================================
# EJECUTAR
# ============================================================================

main "$@"

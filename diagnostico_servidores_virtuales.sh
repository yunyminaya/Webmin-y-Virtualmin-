#!/bin/bash

# Script de Diagnóstico para Problemas de Servidores Virtuales
# Identifica y corrige problemas comunes en Virtualmin

set -e

echo "========================================"
echo "  DIAGNÓSTICO DE SERVIDORES VIRTUALES"
echo "  Virtualmin Troubleshooting"
echo "========================================"
echo

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Funciones de logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[DIAGNÓSTICO]${NC} $1"
}

# Variables globales
PROBLEMS_FOUND=0
SOLUTIONS_APPLIED=0

# Detectar sistema operativo
detect_os() {
    log_step "Detectando sistema operativo..."
    
    if [[ "$(uname)" == "Darwin" ]]; then
        OS="macOS"
        log_warning "Sistema detectado: macOS - Virtualmin requiere Linux"
        ((PROBLEMS_FOUND++))
    elif [[ -f /etc/debian_version ]]; then
        OS="Debian/Ubuntu"
        log_success "Sistema detectado: $OS"
    elif [[ -f /etc/redhat-release ]]; then
        OS="RedHat/CentOS"
        log_success "Sistema detectado: $OS"
    else
        OS="Desconocido"
        log_error "Sistema operativo no soportado"
        ((PROBLEMS_FOUND++))
    fi
}

# Verificar instalación de Webmin
check_webmin() {
    log_step "Verificando instalación de Webmin..."
    
    # Verificar en ubicaciones comunes
    WEBMIN_LOCATIONS=(
        "/etc/webmin"
        "/usr/local/webmin"
        "/opt/webmin"
        "/usr/share/webmin"
    )
    
    WEBMIN_FOUND=false
    for location in "${WEBMIN_LOCATIONS[@]}"; do
        if [[ -d "$location" ]]; then
            log_success "Webmin encontrado en: $location"
            WEBMIN_DIR="$location"
            WEBMIN_FOUND=true
            break
        fi
    done
    
    if [[ "$WEBMIN_FOUND" == "false" ]]; then
        log_error "Webmin no está instalado"
        ((PROBLEMS_FOUND++))
        return 1
    fi
}

# Verificar instalación de Virtualmin
check_virtualmin() {
    log_step "Verificando instalación de Virtualmin..."
    
    if [[ -z "$WEBMIN_DIR" ]]; then
        log_error "Webmin no encontrado, no se puede verificar Virtualmin"
        ((PROBLEMS_FOUND++))
        return 1
    fi
    
    VIRTUALMIN_LOCATIONS=(
        "$WEBMIN_DIR/virtual-server"
        "$WEBMIN_DIR/virtualmin"
    )
    
    VIRTUALMIN_FOUND=false
    for location in "${VIRTUALMIN_LOCATIONS[@]}"; do
        if [[ -d "$location" ]]; then
            log_success "Virtualmin encontrado en: $location"
            VIRTUALMIN_DIR="$location"
            VIRTUALMIN_FOUND=true
            break
        fi
    done
    
    if [[ "$VIRTUALMIN_FOUND" == "false" ]]; then
        log_error "Virtualmin no está instalado"
        ((PROBLEMS_FOUND++))
        return 1
    fi
}

# Verificar servicios necesarios
check_services() {
    log_step "Verificando servicios necesarios..."
    
    REQUIRED_SERVICES=("apache2" "mysql" "bind9" "postfix")
    
    if [[ "$OS" == "macOS" ]]; then
        # Verificar servicios en macOS
        if brew services list | grep -q "mysql.*started"; then
            log_success "MySQL está ejecutándose"
        else
            log_error "MySQL no está ejecutándose"
            ((PROBLEMS_FOUND++))
        fi
        
        if pgrep -f httpd > /dev/null; then
            log_success "Apache está ejecutándose"
        else
            log_error "Apache no está ejecutándose"
            ((PROBLEMS_FOUND++))
        fi
        
        # DNS y Mail no están típicamente disponibles en macOS
        log_warning "DNS (BIND) y Mail (Postfix) no están disponibles nativamente en macOS"
        ((PROBLEMS_FOUND++))
        
    else
        # Verificar servicios en Linux
        for service in "${REQUIRED_SERVICES[@]}"; do
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                log_success "$service está ejecutándose"
            else
                log_error "$service no está ejecutándose"
                ((PROBLEMS_FOUND++))
            fi
        done
    fi
}

# Verificar puertos
check_ports() {
    log_step "Verificando puertos necesarios..."
    
    REQUIRED_PORTS=("10000" "80" "443" "3306" "25" "53")
    
    for port in "${REQUIRED_PORTS[@]}"; do
        if netstat -an 2>/dev/null | grep -q ":$port " || ss -an 2>/dev/null | grep -q ":$port "; then
            log_success "Puerto $port está en uso"
        else
            log_warning "Puerto $port no está en uso"
            case $port in
                "10000") log_info "  → Webmin no está ejecutándose" ;;
                "80"|"443") log_info "  → Servidor web no está ejecutándose" ;;
                "3306") log_info "  → MySQL no está ejecutándose" ;;
                "25") log_info "  → Servidor de correo no está ejecutándose" ;;
                "53") log_info "  → Servidor DNS no está ejecutándose" ;;
            esac
            ((PROBLEMS_FOUND++))
        fi
    done
}

# Verificar configuración de Virtualmin
check_virtualmin_config() {
    log_step "Verificando configuración de Virtualmin..."
    
    if [[ -z "$WEBMIN_DIR" ]]; then
        return 1
    fi
    
    CONFIG_FILE="$WEBMIN_DIR/virtual-server/config"
    if [[ -f "$CONFIG_FILE" ]]; then
        log_success "Archivo de configuración de Virtualmin encontrado"
        
        # Verificar configuraciones importantes
        if grep -q "^home_base=" "$CONFIG_FILE"; then
            HOME_BASE=$(grep "^home_base=" "$CONFIG_FILE" | cut -d'=' -f2)
            log_info "Directorio base de homes: $HOME_BASE"
        else
            log_warning "Directorio base de homes no configurado"
            ((PROBLEMS_FOUND++))
        fi
        
        if grep -q "^dns=1" "$CONFIG_FILE"; then
            log_success "DNS está habilitado"
        else
            log_warning "DNS no está habilitado"
            ((PROBLEMS_FOUND++))
        fi
        
        if grep -q "^mail=1" "$CONFIG_FILE"; then
            log_success "Mail está habilitado"
        else
            log_warning "Mail no está habilitado"
            ((PROBLEMS_FOUND++))
        fi
        
    else
        log_error "Archivo de configuración de Virtualmin no encontrado"
        ((PROBLEMS_FOUND++))
    fi
}

# Verificar logs de error
check_error_logs() {
    log_step "Verificando logs de error..."
    
    LOG_LOCATIONS=(
        "/var/log/webmin/miniserv.error"
        "/var/log/webmin/miniserv.log"
        "/var/log/apache2/error.log"
        "/var/log/httpd/error_log"
        "/var/log/mysql/error.log"
        "/var/log/mysqld.log"
    )
    
    for log_file in "${LOG_LOCATIONS[@]}"; do
        if [[ -f "$log_file" ]]; then
            log_info "Verificando $log_file..."
            
            # Buscar errores recientes (últimas 50 líneas)
            if tail -50 "$log_file" | grep -i "error\|failed\|denied" > /dev/null; then
                log_warning "Errores encontrados en $log_file"
                echo "  Últimos errores:"
                tail -10 "$log_file" | grep -i "error\|failed\|denied" | head -3 | sed 's/^/    /'
                ((PROBLEMS_FOUND++))
            fi
        fi
    done
}

# Proporcionar soluciones
provide_solutions() {
    log_step "Proporcionando soluciones..."
    
    echo
    echo -e "${PURPLE}🔧 SOLUCIONES RECOMENDADAS:${NC}"
    echo
    
    if [[ "$OS" == "macOS" ]]; then
        echo -e "${YELLOW}1. PROBLEMA PRINCIPAL: macOS no es compatible${NC}"
        echo "   Virtualmin está diseñado para Linux. Opciones:"
        echo "   a) Usar Docker con Ubuntu:"
        echo "      docker run -it --rm -p 10000:10000 ubuntu:20.04"
        echo "   b) Usar una máquina virtual con Ubuntu"
        echo "   c) Usar el script adaptado: ./instalacion_macos.sh"
        echo
    fi
    
    if [[ "$WEBMIN_FOUND" == "false" ]]; then
        echo -e "${YELLOW}2. Instalar Webmin:${NC}"
        if [[ "$OS" == "macOS" ]]; then
            echo "   ./instalacion_macos.sh"
        else
            echo "   wget https://download.webmin.com/download/webmin/webmin-current.tar.gz"
            echo "   tar -xzf webmin-current.tar.gz"
            echo "   cd webmin-* && sudo ./setup.sh"
        fi
        echo
    fi
    
    if [[ "$VIRTUALMIN_FOUND" == "false" ]]; then
        echo -e "${YELLOW}3. Instalar Virtualmin:${NC}"
        if [[ "$OS" != "macOS" ]]; then
            echo "   wget https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh"
            echo "   sudo bash virtualmin-install.sh --bundle LAMP"
        fi
        echo
    fi
    
    echo -e "${YELLOW}4. Verificar servicios:${NC}"
    if [[ "$OS" == "macOS" ]]; then
        echo "   brew services start mysql"
        echo "   sudo brew services start httpd"
    else
        echo "   sudo systemctl start apache2 mysql bind9 postfix"
        echo "   sudo systemctl enable apache2 mysql bind9 postfix"
    fi
    echo
    
    echo -e "${YELLOW}5. Verificar firewall:${NC}"
    if [[ "$OS" == "macOS" ]]; then
        echo "   sudo pfctl -d  # Deshabilitar firewall temporalmente"
    else
        echo "   sudo ufw allow 10000"
        echo "   sudo ufw allow 80"
        echo "   sudo ufw allow 443"
    fi
    echo
    
    echo -e "${YELLOW}6. Acceder a Webmin:${NC}"
    echo "   https://localhost:10000"
    echo "   Usuario: root (Linux) o tu usuario (macOS)"
    echo
}

# Función principal
main() {
    log_info "Iniciando diagnóstico de servidores virtuales..."
    echo
    
    detect_os
    check_webmin
    check_virtualmin
    check_services
    check_ports
    check_virtualmin_config
    check_error_logs
    
    echo
    echo -e "${PURPLE}📊 RESUMEN DEL DIAGNÓSTICO:${NC}"
    echo -e "   Problemas encontrados: ${RED}$PROBLEMS_FOUND${NC}"
    echo -e "   Sistema operativo: ${BLUE}$OS${NC}"
    
    if [[ $PROBLEMS_FOUND -gt 0 ]]; then
        provide_solutions
    else
        log_success "¡No se encontraron problemas! El sistema parece estar configurado correctamente."
    fi
    
    echo
    log_info "Diagnóstico completado."
}

# Ejecutar función principal
main "$@"
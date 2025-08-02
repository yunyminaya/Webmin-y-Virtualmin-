#!/bin/bash

# Script de Instalación para macOS: Webmin + Virtualmin
# Adaptado específicamente para sistemas macOS

set -e

echo "========================================"
echo "  INSTALACIÓN WEBMIN + VIRTUALMIN"
echo "  Específico para macOS"
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
    echo -e "${PURPLE}[PASO]${NC} $1"
}

# Verificar que estamos en macOS
if [[ "$(uname)" != "Darwin" ]]; then
    log_error "Este script está diseñado específicamente para macOS"
    exit 1
fi

# Verificar Homebrew
check_homebrew() {
    log_step "Verificando Homebrew..."
    if ! command -v brew &> /dev/null; then
        log_warning "Homebrew no está instalado. Instalando..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        log_success "Homebrew instalado"
    else
        log_success "Homebrew ya está instalado"
    fi
}

# Instalar dependencias
install_dependencies() {
    log_step "Instalando dependencias necesarias..."
    
    # Actualizar Homebrew
    brew update
    
    # Instalar Perl (necesario para Webmin)
    if ! brew list perl &> /dev/null; then
        brew install perl
        log_success "Perl instalado"
    fi
    
    # Instalar OpenSSL
    if ! brew list openssl &> /dev/null; then
        brew install openssl
        log_success "OpenSSL instalado"
    fi
    
    # Instalar wget
    if ! brew list wget &> /dev/null; then
        brew install wget
        log_success "wget instalado"
    fi
    
    log_success "Todas las dependencias instaladas"
}

# Descargar e instalar Webmin
install_webmin() {
    log_step "Descargando e instalando Webmin..."
    
    # Crear directorio temporal
    TEMP_DIR="/tmp/webmin_install"
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Descargar Webmin
    WEBMIN_VERSION="2.202"
    WEBMIN_URL="https://github.com/webmin/webmin/archive/refs/tags/${WEBMIN_VERSION}.tar.gz"
    
    log_info "Descargando Webmin ${WEBMIN_VERSION}..."
    wget -O webmin.tar.gz "$WEBMIN_URL"
    
    # Extraer
    tar -xzf webmin.tar.gz
    cd "webmin-${WEBMIN_VERSION}"
    
    # Configurar instalación
    log_info "Configurando Webmin..."
    
    # Crear directorio de instalación
    WEBMIN_DIR="/usr/local/webmin"
    sudo mkdir -p "$WEBMIN_DIR"
    
    # Copiar archivos
    sudo cp -r * "$WEBMIN_DIR/"
    
    # Configurar permisos
    sudo chown -R root:wheel "$WEBMIN_DIR"
    sudo chmod +x "$WEBMIN_DIR/setup.sh"
    
    # Ejecutar setup
    cd "$WEBMIN_DIR"
    sudo ./setup.sh <<EOF
$WEBMIN_DIR
/var/log/webmin
10000
root
y
y
y
y
EOF
    
    log_success "Webmin instalado en $WEBMIN_DIR"
}

# Descargar e instalar Virtualmin
install_virtualmin() {
    log_step "Instalando Virtualmin..."
    
    # Copiar módulo de Virtualmin
    VIRTUALMIN_SRC="$(pwd)/virtualmin-gpl-master"
    VIRTUALMIN_DST="/usr/local/webmin/virtual-server"
    
    if [[ -d "$VIRTUALMIN_SRC" ]]; then
        sudo cp -r "$VIRTUALMIN_SRC" "$VIRTUALMIN_DST"
        sudo chown -R root:wheel "$VIRTUALMIN_DST"
        log_success "Virtualmin copiado a Webmin"
    else
        log_error "Directorio virtualmin-gpl-master no encontrado"
        return 1
    fi
}

# Instalar Authentic Theme
install_authentic_theme() {
    log_step "Instalando Authentic Theme..."
    
    # Copiar tema
    THEME_SRC="$(pwd)/authentic-theme-master"
    THEME_DST="/usr/local/webmin/authentic-theme"
    
    if [[ -d "$THEME_SRC" ]]; then
        sudo cp -r "$THEME_SRC" "$THEME_DST"
        sudo chown -R root:wheel "$THEME_DST"
        
        # Configurar como tema por defecto
        sudo sed -i '' 's/theme=.*/theme=authentic-theme/' /usr/local/webmin/config
        
        log_success "Authentic Theme instalado y configurado"
    else
        log_error "Directorio authentic-theme-master no encontrado"
        return 1
    fi
}

# Configurar servicios
configure_services() {
    log_step "Configurando servicios..."
    
    # Crear script de inicio para Webmin
    sudo tee /usr/local/bin/webmin-start > /dev/null <<EOF
#!/bin/bash
cd /usr/local/webmin
./miniserv.pl /usr/local/webmin/miniserv.conf &
EOF
    
    sudo chmod +x /usr/local/bin/webmin-start
    
    # Crear LaunchDaemon para inicio automático
    sudo tee /Library/LaunchDaemons/com.webmin.plist > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.webmin</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/webmin-start</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF
    
    # Cargar el servicio
    sudo launchctl load /Library/LaunchDaemons/com.webmin.plist
    
    log_success "Servicios configurados"
}

# Verificar instalación
verify_installation() {
    log_step "Verificando instalación..."
    
    # Verificar que Webmin esté ejecutándose
    sleep 5
    if curl -k -s https://localhost:10000 > /dev/null; then
        log_success "Webmin está ejecutándose en puerto 10000"
    else
        log_warning "Webmin puede no estar ejecutándose correctamente"
    fi
    
    # Verificar archivos
    if [[ -f "/usr/local/webmin/miniserv.pl" ]]; then
        log_success "Archivos de Webmin encontrados"
    else
        log_error "Archivos de Webmin no encontrados"
    fi
    
    if [[ -d "/usr/local/webmin/virtual-server" ]]; then
        log_success "Módulo Virtualmin encontrado"
    else
        log_error "Módulo Virtualmin no encontrado"
    fi
    
    if [[ -d "/usr/local/webmin/authentic-theme" ]]; then
        log_success "Authentic Theme encontrado"
    else
        log_error "Authentic Theme no encontrado"
    fi
}

# Mostrar información final
show_final_info() {
    echo
    echo -e "${PURPLE}📋 INSTALACIÓN COMPLETADA${NC}"
    echo -e "   🌐 URL del Panel: ${BLUE}https://localhost:10000${NC}"
    echo -e "   👤 Usuario: ${YELLOW}$(whoami)${NC}"
    echo -e "   🔑 Contraseña: ${YELLOW}tu contraseña de usuario${NC}"
    echo
    echo -e "${PURPLE}🚀 PRÓXIMOS PASOS:${NC}"
    echo "   1. Abre tu navegador"
    echo "   2. Ve a https://localhost:10000"
    echo "   3. Acepta el certificado SSL"
    echo "   4. Inicia sesión con tu usuario de macOS"
    echo "   5. Configura Virtualmin en el módulo correspondiente"
    echo
    echo -e "${YELLOW}⚠️  NOTA IMPORTANTE:${NC}"
    echo "   Este es Webmin con Virtualmin adaptado para macOS."
    echo "   Algunas funciones pueden requerir configuración adicional."
    echo "   Para hosting completo, considera usar Docker con Ubuntu."
    echo
}

# Función principal
main() {
    log_info "Iniciando instalación de Webmin + Virtualmin para macOS..."
    
    check_homebrew
    install_dependencies
    install_webmin
    install_virtualmin
    install_authentic_theme
    configure_services
    verify_installation
    show_final_info
    
    log_success "¡Instalación completada!"
}

# Ejecutar función principal
main "$@"
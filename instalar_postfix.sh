#!/bin/bash

# Script para instalar Postfix si no está disponible

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Detectar sistema operativo
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS="$ID"
    elif [[ -f /etc/redhat-release ]]; then
        if grep -q "CentOS" /etc/redhat-release; then
            OS="centos"
        elif grep -q "Red Hat" /etc/redhat-release; then
            OS="rhel"
        fi
    else
        OS="unknown"
    fi
}

# Instalar Postfix según el sistema operativo
install_postfix() {
    detect_os
    
    log_info "Detectado sistema operativo: $OS"
    
    case "$OS" in
        "ubuntu"|"debian")
            log_info "Instalando Postfix en Ubuntu/Debian..."
            sudo apt-get update
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y postfix
            ;;
        "centos"|"rhel"|"fedora")
            log_info "Instalando Postfix en CentOS/RHEL/Fedora..."
            sudo yum install -y postfix || sudo dnf install -y postfix
            ;;
        "macos")
            log_info "En macOS, Postfix viene preinstalado pero puede estar deshabilitado"
            log_info "Para habilitar Postfix en macOS:"
            echo "  sudo launchctl load -w /System/Library/LaunchDaemons/org.postfix.master.plist"
            ;;
        *)
            log_error "Sistema operativo no soportado: $OS"
            exit 1
            ;;
    esac
    
    # Verificar instalación
    if command -v postconf >/dev/null 2>&1; then
        log_success "Postfix instalado correctamente"
        postconf mail_version
    else
        log_error "Error al instalar Postfix"
        exit 1
    fi
}

# Verificar si Postfix ya está instalado
if command -v postconf >/dev/null 2>&1; then
    log_success "Postfix ya está instalado"
    postconf mail_version
else
    log_info "Postfix no está instalado. Procediendo con la instalación..."
    install_postfix
fi

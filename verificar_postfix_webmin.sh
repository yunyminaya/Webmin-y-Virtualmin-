#!/bin/bash

# =============================================================================
# VERIFICACIÓN Y CORRECCIÓN DE POSTFIX PARA WEBMIN/VIRTUALMIN
# Script para prevenir errores de postconf en paneles de administración
# =============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[PASO]${NC} $1"
}

# Función para detectar sistema operativo
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        DISTRO="macos"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS="linux"
        DISTRO="$ID"
    elif [[ -f /etc/redhat-release ]]; then
        OS="linux"
        if grep -q "CentOS" /etc/redhat-release; then
            DISTRO="centos"
        elif grep -q "Red Hat" /etc/redhat-release; then
            DISTRO="rhel"
        elif grep -q "Fedora" /etc/redhat-release; then
            DISTRO="fedora"
        fi
    elif [[ -f /etc/debian_version ]]; then
        OS="linux"
        DISTRO="debian"
    else
        OS="unknown"
        DISTRO="unknown"
    fi
    
    export OS DISTRO
}

# Función para verificar si postconf está disponible
check_postconf_available() {
    if command -v postconf >/dev/null 2>&1; then
        return 0
    elif [[ -x "/usr/sbin/postconf" ]]; then
        export PATH="$PATH:/usr/sbin"
        return 0
    elif [[ -x "/usr/bin/postconf" ]]; then
        export PATH="$PATH:/usr/bin"
        return 0
    else
        return 1
    fi
}

# Función para verificar instalación de Postfix
check_postfix_installation() {
    log_step "Verificando instalación de Postfix..."
    
    if check_postconf_available; then
        local postfix_version=$(postconf mail_version 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
        log_success "Postfix está instalado - Versión: $postfix_version"
        return 0
    else
        log_warning "Postfix no está instalado o postconf no está disponible"
        return 1
    fi
}

# Función para verificar configuración de Postfix
check_postfix_configuration() {
    log_step "Verificando configuración de Postfix..."
    
    if ! check_postconf_available; then
        log_error "No se puede verificar configuración - Postfix no disponible"
        return 1
    fi
    
    # Verificar parámetros críticos
    local critical_params=("queue_directory" "command_directory" "daemon_directory" "data_directory" "mail_owner")
    local config_ok=true
    
    for param in "${critical_params[@]}"; do
        if postconf "$param" >/dev/null 2>&1; then
            local value=$(postconf "$param" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
            log_success "$param = $value"
        else
            log_error "No se pudo obtener parámetro: $param"
            config_ok=false
        fi
    done
    
    if [[ "$config_ok" == true ]]; then
        log_success "Configuración de Postfix verificada correctamente"
        return 0
    else
        log_error "Problemas en la configuración de Postfix"
        return 1
    fi
}

# Función para verificar servicios de Postfix
check_postfix_service() {
    log_step "Verificando servicio de Postfix..."
    
    detect_os
    
    case "$OS" in
        "linux")
            if systemctl is-active postfix >/dev/null 2>&1; then
                log_success "Servicio Postfix está activo"
            elif systemctl is-enabled postfix >/dev/null 2>&1; then
                log_warning "Servicio Postfix está habilitado pero no activo"
                log_info "Para iniciar: sudo systemctl start postfix"
            else
                log_warning "Servicio Postfix no está habilitado"
                log_info "Para habilitar: sudo systemctl enable postfix"
            fi
            ;;
        "macos")
            if launchctl list | grep -q "org.postfix.master"; then
                log_success "Servicio Postfix está activo en macOS"
            else
                log_warning "Servicio Postfix no está activo en macOS"
                log_info "Para activar: sudo launchctl load -w /System/Library/LaunchDaemons/org.postfix.master.plist"
            fi
            ;;
        *)
            log_warning "No se puede verificar servicio en sistema: $OS"
            ;;
    esac
}

# Función para verificar puertos de Postfix
check_postfix_ports() {
    log_step "Verificando puertos de Postfix..."
    
    local smtp_ports=("25" "587" "465")
    
    for port in "${smtp_ports[@]}"; do
        if netstat -ln 2>/dev/null | grep -q ":$port " || ss -ln 2>/dev/null | grep -q ":$port "; then
            log_success "Puerto $port está en uso (probablemente Postfix)"
        else
            log_warning "Puerto $port no está en uso"
        fi
    done
}

# Función para verificar logs de Postfix
check_postfix_logs() {
    log_step "Verificando logs de Postfix..."
    
    local log_files=("/var/log/mail.log" "/var/log/maillog" "/var/log/postfix.log")
    local log_found=false
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            log_success "Log encontrado: $log_file"
            
            # Verificar errores recientes
            if tail -n 50 "$log_file" 2>/dev/null | grep -i "error\|fatal\|warning" | head -5; then
                log_warning "Se encontraron mensajes de error/warning en logs"
            fi
            
            log_found=true
            break
        fi
    done
    
    if [[ "$log_found" == false ]]; then
        log_warning "No se encontraron logs de Postfix en ubicaciones estándar"
    fi
}

# Función para crear configuración mínima de Postfix
create_minimal_postfix_config() {
    log_step "Creando configuración mínima de Postfix..."
    
    if [[ ! -f "/etc/postfix/main.cf" ]]; then
        log_warning "Archivo main.cf no existe, creando configuración básica"
        
        sudo mkdir -p /etc/postfix
        
        cat << EOF | sudo tee /etc/postfix/main.cf > /dev/null
# Configuración mínima de Postfix para Webmin/Virtualmin
# Generada automáticamente

# Configuración básica
queue_directory = /var/spool/postfix
command_directory = /usr/sbin
daemon_directory = /usr/libexec/postfix
data_directory = /var/lib/postfix
mail_owner = postfix

# Configuración de red
myhostname = $(hostname -f 2>/dev/null || echo "localhost.localdomain")
mydomain = $(hostname -d 2>/dev/null || echo "localdomain")
myorigin = \$myhostname
inet_interfaces = localhost
mydestination = \$myhostname, localhost.\$mydomain, localhost

# Configuración de seguridad
smtpd_banner = \$myhostname ESMTP
biff = no
append_dot_mydomain = no
readme_directory = no

# Configuración de alias
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases

# Configuración de entrega
home_mailbox = Maildir/
mailbox_command = 

# Configuración de red
relayhost = 
networks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
mailbox_size_limit = 0
recipient_delimiter = +
inet_protocols = all
EOF
        
        log_success "Configuración básica de Postfix creada"
    else
        log_info "Archivo main.cf ya existe"
    fi
}

# Función para instalar Postfix si no está disponible
install_postfix_if_needed() {
    if ! check_postconf_available; then
        log_step "Postfix no está instalado. Iniciando instalación..."
        
        detect_os
        
        case "$DISTRO" in
            "ubuntu"|"debian")
                log_info "Instalando Postfix en Ubuntu/Debian..."
                sudo apt-get update
                sudo DEBIAN_FRONTEND=noninteractive apt-get install -y postfix
                ;;
            "centos"|"rhel"|"fedora")
                log_info "Instalando Postfix en CentOS/RHEL/Fedora..."
                if command -v dnf >/dev/null 2>&1; then
                    sudo dnf install -y postfix
                else
                    sudo yum install -y postfix
                fi
                ;;
            "macos")
                log_info "En macOS, Postfix viene preinstalado"
                log_info "Habilitando servicio..."
                sudo launchctl load -w /System/Library/LaunchDaemons/org.postfix.master.plist 2>/dev/null || true
                ;;
            *)
                log_error "Sistema operativo no soportado para instalación automática: $DISTRO"
                return 1
                ;;
        esac
        
        # Verificar instalación
        if check_postconf_available; then
            log_success "Postfix instalado correctamente"
        else
            log_error "Error al instalar Postfix"
            return 1
        fi
    else
        log_info "Postfix ya está instalado"
    fi
}

# Función para generar reporte de estado
generate_status_report() {
    log_step "Generando reporte de estado..."
    
    local report_file="./postfix_status_report.txt"
    
    cat > "$report_file" << EOF
═══════════════════════════════════════════════════════════════════════════════
REPORTE DE ESTADO DE POSTFIX PARA WEBMIN/VIRTUALMIN
Generado: $(date)
Sistema: $OS ($DISTRO)
═══════════════════════════════════════════════════════════════════════════════

ESTADO DE INSTALACIÓN:
EOF
    
    if check_postconf_available; then
        echo "✅ Postfix está instalado y disponible" >> "$report_file"
        postconf mail_version >> "$report_file" 2>/dev/null || echo "❌ Error al obtener versión" >> "$report_file"
    else
        echo "❌ Postfix no está instalado o no está disponible" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "CONFIGURACIÓN CRÍTICA:" >> "$report_file"
    
    if check_postconf_available; then
        local critical_params=("queue_directory" "command_directory" "daemon_directory")
        for param in "${critical_params[@]}"; do
            if postconf "$param" >/dev/null 2>&1; then
                echo "✅ $param: $(postconf "$param" 2>/dev/null | cut -d'=' -f2)" >> "$report_file"
            else
                echo "❌ $param: No disponible" >> "$report_file"
            fi
        done
    else
        echo "❌ No se puede verificar configuración - Postfix no disponible" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "RECOMENDACIONES:" >> "$report_file"
    
    if ! check_postconf_available; then
        echo "• Instalar Postfix usando el script: ./instalar_postfix.sh" >> "$report_file"
        echo "• Verificar que /usr/sbin esté en PATH" >> "$report_file"
    fi
    
    echo "• Ejecutar verificación completa: ./verificacion_final_autonomo.sh" >> "$report_file"
    echo "• Revisar logs de Postfix en /var/log/mail.log" >> "$report_file"
    
    log_success "Reporte generado: $report_file"
}

# Función para mostrar resumen
show_summary() {
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}📋 RESUMEN DE VERIFICACIÓN DE POSTFIX${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    
    if check_postconf_available; then
        echo -e "${GREEN}✅ ESTADO GENERAL: POSTFIX OPERATIVO${NC}"
        echo
        echo -e "${GREEN}Funciones verificadas:${NC}"
        echo "   • Instalación de Postfix"
        echo "   • Configuración básica"
        echo "   • Servicios del sistema"
        echo "   • Puertos de red"
        echo "   • Archivos de log"
    else
        echo -e "${RED}❌ ESTADO GENERAL: POSTFIX NO DISPONIBLE${NC}"
        echo
        echo -e "${YELLOW}Acciones requeridas:${NC}"
        echo "   • Instalar Postfix"
        echo "   • Configurar servicios"
        echo "   • Verificar PATH del sistema"
    fi
    
    echo
    echo -e "${BLUE}📁 Archivos generados:${NC}"
    echo "   • postfix_status_report.txt - Reporte detallado"
    echo
    echo -e "${PURPLE}🔧 Scripts relacionados:${NC}"
    echo "   • ./instalar_postfix.sh - Instalador automático"
    echo "   • ./verificacion_final_autonomo.sh - Verificación completa"
    echo "   • ./corregir_error_postfix.sh - Corrección de errores"
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
}

# Función principal
main() {
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}🔍 VERIFICACIÓN DE POSTFIX PARA WEBMIN/VIRTUALMIN${NC}"
    echo -e "${CYAN}   Prevención del error: /usr/sbin/postconf: not found${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    
    # Detectar sistema operativo
    detect_os
    log_info "Sistema detectado: $OS ($DISTRO)"
    echo
    
    # Verificaciones principales
    check_postfix_installation
    
    if check_postconf_available; then
        check_postfix_configuration
        check_postfix_service
        check_postfix_ports
        check_postfix_logs
    else
        log_warning "Saltando verificaciones avanzadas - Postfix no disponible"
        
        # Ofrecer instalación automática
        echo
        read -p "¿Desea instalar Postfix automáticamente? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_postfix_if_needed
            if check_postconf_available; then
                create_minimal_postfix_config
                check_postfix_configuration
            fi
        fi
    fi
    
    echo
    
    # Generar reporte
    generate_status_report
    
    # Mostrar resumen
    show_summary
}

# Ejecutar función principal
main "$@"
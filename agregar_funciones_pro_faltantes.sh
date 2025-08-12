#!/bin/bash

# Script para agregar las funciones PRO que faltan y asegurar 100% de funcionalidad
# Basado en la verificación anterior que mostró 97% de éxito

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función para logging
log() {
    local level="$1"
    local message="$2"
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[✓]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[⚠]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[✗]${NC} $message"
            ;;
        "HEADER")
            echo -e "\n${PURPLE}=== $message ===${NC}"
            ;;
    esac
}

# Función para mostrar banner
show_banner() {
    clear
    cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════════
   🚀 AGREGAR FUNCIONES PRO FALTANTES
   
   ✨ Completar al 100% todas las funciones PRO
   🛡️ Instalar componentes faltantes
   🔧 Configurar servicios opcionales
   
═══════════════════════════════════════════════════════════════════════════════
EOF
}

# Detectar sistema operativo
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            echo "debian"
        elif [ -f /etc/redhat-release ]; then
            echo "redhat"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Instalar herramientas de monitoreo faltantes
install_monitoring_tools() {
    log "HEADER" "INSTALANDO HERRAMIENTAS DE MONITOREO PRO"
    
    local os_type=$(detect_os)
    
    case "$os_type" in
        "debian"|"ubuntu")
            log "INFO" "Instalando herramientas de monitoreo en Ubuntu/Debian..."
            
            # Actualizar repositorios
            apt update -y
            
            # Instalar herramientas de monitoreo
            apt install -y htop iotop nethogs iftop
            
            log "SUCCESS" "Herramientas de monitoreo instaladas"
            ;;
        "redhat"|"centos"|"fedora")
            log "INFO" "Instalando herramientas de monitoreo en RedHat/CentOS..."
            
            # Instalar EPEL si no está disponible
            if ! rpm -q epel-release >/dev/null 2>&1; then
                yum install -y epel-release
            fi
            
            # Instalar herramientas de monitoreo
            yum install -y htop iotop nethogs iftop
            
            log "SUCCESS" "Herramientas de monitoreo instaladas"
            ;;
        "macos")
            log "INFO" "Instalando herramientas de monitoreo en macOS..."
            
            # Verificar si Homebrew está instalado
            if ! command -v brew >/dev/null 2>&1; then
                log "WARNING" "Homebrew no está instalado. Instalando..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            
            # Instalar herramientas de monitoreo
            brew install htop iotop nethogs iftop
            
            log "SUCCESS" "Herramientas de monitoreo instaladas"
            ;;
        *)
            log "WARNING" "Sistema operativo no soportado para instalación automática"
            log "INFO" "Instale manualmente: htop, iotop, nethogs, iftop"
            ;;
    esac
}

# Configurar firewall
configure_firewall() {
    log "HEADER" "CONFIGURANDO FIREWALL PRO"
    
    local os_type=$(detect_os)
    
    case "$os_type" in
        "debian"|"ubuntu")
            log "INFO" "Configurando UFW en Ubuntu/Debian..."
            
            # Instalar UFW si no está instalado
            if ! command -v ufw >/dev/null 2>&1; then
                apt install -y ufw
            fi
            
            # Habilitar UFW
            ufw --force enable
            
            # Configurar reglas básicas
            ufw allow ssh
            ufw allow 80/tcp
            ufw allow 443/tcp
            ufw allow 10000/tcp  # Webmin
            ufw allow 20000/tcp  # Virtualmin
            
            log "SUCCESS" "Firewall UFW configurado"
            ;;
        "redhat"|"centos"|"fedora")
            log "INFO" "Configurando firewalld en RedHat/CentOS..."
            
            # Instalar firewalld si no está instalado
            if ! command -v firewall-cmd >/dev/null 2>&1; then
                yum install -y firewalld
            fi
            
            # Habilitar firewalld
            systemctl enable firewalld
            systemctl start firewalld
            
            # Configurar reglas básicas
            firewall-cmd --permanent --add-service=ssh
            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
            firewall-cmd --permanent --add-port=10000/tcp
            firewall-cmd --permanent --add-port=20000/tcp
            firewall-cmd --reload
            
            log "SUCCESS" "Firewall firewalld configurado"
            ;;
        "macos")
            log "INFO" "Configurando firewall en macOS..."
            
            # Habilitar firewall de macOS
            /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
            
            log "SUCCESS" "Firewall de macOS habilitado"
            ;;
        *)
            log "WARNING" "Sistema operativo no soportado para configuración automática de firewall"
            ;;
    esac
}

# Instalar Dovecot (servidor IMAP/POP3)
install_dovecot() {
    log "HEADER" "INSTALANDO DOVECOT PRO"
    
    local os_type=$(detect_os)
    
    case "$os_type" in
        "debian"|"ubuntu")
            log "INFO" "Instalando Dovecot en Ubuntu/Debian..."
            
            apt update -y
            apt install -y dovecot-core dovecot-imapd dovecot-pop3d
            
            # Configurar Dovecot básico
            cat > /etc/dovecot/conf.d/10-mail.conf << 'EOF'
mail_location = maildir:~/Maildir
EOF
            
            # Reiniciar Dovecot
            systemctl enable dovecot
            systemctl restart dovecot
            
            log "SUCCESS" "Dovecot instalado y configurado"
            ;;
        "redhat"|"centos"|"fedora")
            log "INFO" "Instalando Dovecot en RedHat/CentOS..."
            
            yum install -y dovecot
            
            # Configurar Dovecot básico
            cat > /etc/dovecot/conf.d/10-mail.conf << 'EOF'
mail_location = maildir:~/Maildir
EOF
            
            # Reiniciar Dovecot
            systemctl enable dovecot
            systemctl restart dovecot
            
            log "SUCCESS" "Dovecot instalado y configurado"
            ;;
        "macos")
            log "INFO" "Instalando Dovecot en macOS..."
            
            brew install dovecot
            
            log "SUCCESS" "Dovecot instalado (configuración manual requerida)"
            ;;
        *)
            log "WARNING" "Sistema operativo no soportado para instalación automática de Dovecot"
            ;;
    esac
}

# Instalar SpamAssassin
install_spamassassin() {
    log "HEADER" "INSTALANDO SPAMASSASSIN PRO"
    
    local os_type=$(detect_os)
    
    case "$os_type" in
        "debian"|"ubuntu")
            log "INFO" "Instalando SpamAssassin en Ubuntu/Debian..."
            
            apt update -y
            apt install -y spamassassin spamc
            
            # Habilitar SpamAssassin
            systemctl enable spamassassin
            systemctl start spamassassin
            
            log "SUCCESS" "SpamAssassin instalado y configurado"
            ;;
        "redhat"|"centos"|"fedora")
            log "INFO" "Instalando SpamAssassin en RedHat/CentOS..."
            
            yum install -y spamassassin
            
            # Habilitar SpamAssassin
            systemctl enable spamassassin
            systemctl start spamassassin
            
            log "SUCCESS" "SpamAssassin instalado y configurado"
            ;;
        "macos")
            log "INFO" "Instalando SpamAssassin en macOS..."
            
            brew install spamassassin
            
            log "SUCCESS" "SpamAssassin instalado (configuración manual requerida)"
            ;;
        *)
            log "WARNING" "Sistema operativo no soportado para instalación automática de SpamAssassin"
            ;;
    esac
}

# Instalar phpMyAdmin
install_phpmyadmin() {
    log "HEADER" "INSTALANDO PHPMYADMIN PRO"
    
    local os_type=$(detect_os)
    
    case "$os_type" in
        "debian"|"ubuntu")
            log "INFO" "Instalando phpMyAdmin en Ubuntu/Debian..."
            
            apt update -y
            apt install -y phpmyadmin
            
            # Configurar Apache para phpMyAdmin
            ln -sf /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
            a2enconf phpmyadmin
            systemctl reload apache2
            
            log "SUCCESS" "phpMyAdmin instalado y configurado"
            ;;
        "redhat"|"centos"|"fedora")
            log "INFO" "Instalando phpMyAdmin en RedHat/CentOS..."
            
            yum install -y phpMyAdmin
            
            log "SUCCESS" "phpMyAdmin instalado"
            ;;
        "macos")
            log "INFO" "Instalando phpMyAdmin en macOS..."
            
            brew install phpmyadmin
            
            log "SUCCESS" "phpMyAdmin instalado (configuración manual requerida)"
            ;;
        *)
            log "WARNING" "Sistema operativo no soportado para instalación automática de phpMyAdmin"
            ;;
    esac
}

# Verificar y corregir permisos de scripts DevOps
fix_devops_permissions() {
    log "HEADER" "CORRIGIENDO PERMISOS DE SCRIPTS DEVOPS PRO"
    
    local devops_scripts=(
        "agente_devops_webmin.sh"
        "coordinador_sub_agentes.sh"
        "sub_agente_monitoreo.sh"
        "sub_agente_seguridad.sh"
        "sub_agente_backup.sh"
        "sub_agente_actualizaciones.sh"
        "sub_agente_logs.sh"
        "sub_agente_especialista_codigo.sh"
        "sub_agente_optimizador.sh"
        "sub_agente_ingeniero_codigo.sh"
        "sub_agente_verificador_backup.sh"
    )
    
    for script in "${devops_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            chmod +x "$script"
            log "SUCCESS" "Permisos corregidos para $script"
        else
            log "WARNING" "Script $script no encontrado"
        fi
    done
}

# Verificar espacio en disco
check_disk_space() {
    log "HEADER" "VERIFICANDO ESPACIO EN DISCO"
    
    local disk_usage=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [[ $disk_usage -gt 90 ]]; then
        log "ERROR" "Espacio en disco crítico: ${disk_usage}% usado"
        log "INFO" "Recomendación: Liberar espacio o expandir disco"
    elif [[ $disk_usage -gt 80 ]]; then
        log "WARNING" "Espacio en disco bajo: ${disk_usage}% usado"
        log "INFO" "Recomendación: Considerar limpieza de archivos temporales"
    else
        log "SUCCESS" "Espacio en disco adecuado: ${disk_usage}% usado"
    fi
}

# Función principal
main() {
    show_banner
    
    log "INFO" "Iniciando agregado de funciones PRO faltantes..."
    
    # Ejecutar todas las instalaciones y configuraciones
    install_monitoring_tools
    configure_firewall
    install_dovecot
    install_spamassassin
    install_phpmyadmin
    fix_devops_permissions
    check_disk_space
    
    log "HEADER" "VERIFICACIÓN FINAL"
    
    # Ejecutar verificación final
    if [[ -f "verificar_pro_simple.sh" ]]; then
        log "INFO" "Ejecutando verificación final..."
        ./verificar_pro_simple.sh
    else
        log "WARNING" "Script de verificación no encontrado"
    fi
    
    log "SUCCESS" "Proceso de agregado de funciones PRO completado"
    log "INFO" "Recomendación: Reiniciar el sistema para aplicar todos los cambios"
}

# Ejecutar función principal
main "$@"

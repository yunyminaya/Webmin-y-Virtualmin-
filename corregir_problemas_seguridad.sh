#!/bin/bash

# Script para corregir automáticamente problemas de seguridad en Webmin/Virtualmin

# Colores para los mensajes
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"
NC="\033[0m" # No Color

# Variables globales
LOG_FILE="/var/log/correccion_seguridad.log"
BACKUP_DIR="/root/security_backups/$(date +%Y%m%d_%H%M%S)"
DRY_RUN=false
VERBOSE=false
FIX_ALL=false

# Función para mostrar el banner
show_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║   Corrección Automática de Problemas de Seguridad             ║"
    echo "║   para Webmin y Virtualmin                                   ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Función para mostrar mensajes
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $timestamp - $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $timestamp - $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $timestamp - $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $timestamp - $message"
            ;;
        *)
            echo -e "$timestamp - $message"
            ;;
    esac
    
    # Registrar en el archivo de log si no estamos en modo dry-run
    if [ "$DRY_RUN" = false ]; then
        echo "[$level] $timestamp - $message" >> "$LOG_FILE"
    fi
}

# Función para crear copia de seguridad de un archivo
backup_file() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        log "WARNING" "No se puede hacer copia de seguridad de $file_path: El archivo no existe"
        return 1
    fi
    
    # Crear directorio de copia de seguridad si no existe
    if [ ! -d "$BACKUP_DIR" ]; then
        if [ "$DRY_RUN" = false ]; then
            mkdir -p "$BACKUP_DIR"
        fi
        log "INFO" "Creado directorio de copias de seguridad: $BACKUP_DIR"
    fi
    
    # Obtener la ruta relativa para mantener la estructura de directorios
    local rel_path=$(echo "$file_path" | sed 's/^\///')
    local backup_path="$BACKUP_DIR/$rel_path"
    local backup_dir=$(dirname "$backup_path")
    
    if [ "$DRY_RUN" = false ]; then
        # Crear directorio de destino si no existe
        mkdir -p "$backup_dir"
        
        # Copiar el archivo
        cp -p "$file_path" "$backup_path"
        
        if [ $? -eq 0 ]; then
            log "INFO" "Copia de seguridad creada: $backup_path"
            return 0
        else
            log "ERROR" "Error al crear copia de seguridad de $file_path"
            return 1
        fi
    else
        log "INFO" "[DRY-RUN] Se crearía copia de seguridad de $file_path en $backup_path"
        return 0
    fi
}

# Función para verificar si un servicio está instalado
service_is_installed() {
    local service_name="$1"
    
    if command -v "$service_name" &> /dev/null || \
       [ -f "/etc/init.d/$service_name" ] || \
       [ -f "/usr/lib/systemd/system/$service_name.service" ] || \
       [ -f "/etc/systemd/system/$service_name.service" ]; then
        return 0
    else
        return 1
    fi
}

# Función para verificar si un servicio está activo
service_is_active() {
    local service_name="$1"
    
    if command -v systemctl &> /dev/null; then
        systemctl is-active --quiet "$service_name" 2>/dev/null
        return $?
    elif command -v service &> /dev/null; then
        service "$service_name" status &>/dev/null
        return $?
    elif [ -f "/etc/init.d/$service_name" ]; then
        /etc/init.d/"$service_name" status &>/dev/null
        return $?
    elif command -v launchctl &> /dev/null; then
        launchctl list | grep -q "$service_name"
        return $?
    else
        ps aux | grep -v grep | grep -q "$service_name"
        return $?
    fi
}

# Función para detectar el sistema operativo
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VERSION=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        OS="debian"
        VERSION=$(cat /etc/debian_version)
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
    elif [ -f /etc/centos-release ]; then
        OS="centos"
    elif [ -f /etc/fedora-release ]; then
        OS="fedora"
    elif [ -x /usr/bin/sw_vers ]; then
        OS="macos"
        VERSION=$(sw_vers -productVersion)
    else
        OS="unknown"
        VERSION="unknown"
    fi
    
    log "INFO" "Sistema operativo detectado: $OS $VERSION"
    return 0
}

# Función para actualizar el sistema
update_system() {
    log "INFO" "Iniciando actualización del sistema..."
    
    # Detectar el sistema operativo
    detect_os
    
    if [ "$DRY_RUN" = false ]; then
        case "$OS" in
            "ubuntu"|"debian")
                apt-get update
                apt-get upgrade -y
                apt-get dist-upgrade -y
                apt-get autoremove -y
                apt-get autoclean
                log "SUCCESS" "Sistema Ubuntu/Debian actualizado"
                ;;
            "rhel"|"centos")
                if command -v dnf &> /dev/null; then
                    dnf update -y
                    dnf autoremove -y
                    dnf clean all
                else
                    yum update -y
                    yum autoremove -y
                    yum clean all
                fi
                log "SUCCESS" "Sistema RHEL/CentOS actualizado"
                ;;
            "fedora")
                dnf update -y
                dnf autoremove -y
                dnf clean all
                log "SUCCESS" "Sistema Fedora actualizado"
                ;;
            "macos")
                softwareupdate -i -a
                log "SUCCESS" "Sistema macOS actualizado"
                ;;
            *)
                log "ERROR" "No se pudo actualizar el sistema: Sistema operativo no soportado"
                return 1
                ;;
        esac
    else
        log "INFO" "[DRY-RUN] Se actualizaría el sistema operativo $OS"
    fi
    
    return 0
}

# Función para actualizar Webmin/Virtualmin
update_webmin_virtualmin() {
    log "INFO" "Iniciando actualización de Webmin/Virtualmin..."
    
    # Verificar si Webmin está instalado
    if [ ! -d "/etc/webmin" ]; then
        log "WARNING" "Webmin no está instalado. Omitiendo actualización."
        return 1
    fi
    
    if [ "$DRY_RUN" = false ]; then
        # Actualizar Webmin
        if [ -f "/usr/share/webmin/update.pl" ]; then
            cd /usr/share/webmin
            ./update.pl
            log "SUCCESS" "Webmin actualizado"
        elif [ -f "/usr/libexec/webmin/update.pl" ]; then
            cd /usr/libexec/webmin
            ./update.pl
            log "SUCCESS" "Webmin actualizado"
        else
            log "ERROR" "No se encontró el script de actualización de Webmin"
        fi
        
        # Actualizar Virtualmin si está instalado
        if [ -d "/etc/webmin/virtual-server" ]; then
            if [ -f "/usr/sbin/virtualmin" ]; then
                /usr/sbin/virtualmin upgrade-virtualmin
                log "SUCCESS" "Virtualmin actualizado"
            else
                log "ERROR" "No se encontró el comando virtualmin"
            fi
        fi
    else
        log "INFO" "[DRY-RUN] Se actualizaría Webmin/Virtualmin"
    fi
    
    return 0
}

# Función para generar un informe de seguridad
generate_security_report() {
    log "INFO" "Generando informe de seguridad..."
    
    # Definir archivo de informe
    REPORT_FILE="/root/security_report_$(date +%Y%m%d_%H%M%S).txt"
    
    if [ "$DRY_RUN" = false ]; then
        # Crear archivo de informe
        echo "==========================================================" > "$REPORT_FILE"
        echo "          INFORME DE SEGURIDAD WEBMIN/VIRTUALMIN          " >> "$REPORT_FILE"
        echo "                $(date +"%Y-%m-%d %H:%M:%S")                " >> "$REPORT_FILE"
        echo "==========================================================" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        
        # Información del sistema
        echo "INFORMACIÓN DEL SISTEMA" >> "$REPORT_FILE"
        echo "---------------------" >> "$REPORT_FILE"
        echo "Sistema operativo: $(uname -a)" >> "$REPORT_FILE"
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            echo "Distribución: $PRETTY_NAME" >> "$REPORT_FILE"
        fi
        echo "Kernel: $(uname -r)" >> "$REPORT_FILE"
        echo "Arquitectura: $(uname -m)" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        
        # Información de Webmin/Virtualmin
        echo "INFORMACIÓN DE WEBMIN/VIRTUALMIN" >> "$REPORT_FILE"
        echo "------------------------------" >> "$REPORT_FILE"
        if [ -f "/etc/webmin/version" ]; then
            echo "Versión de Webmin: $(cat /etc/webmin/version)" >> "$REPORT_FILE"
        fi
        if [ -f "/etc/webmin/virtual-server/version" ]; then
            echo "Versión de Virtualmin: $(cat /etc/webmin/virtual-server/version)" >> "$REPORT_FILE"
        fi
        echo "" >> "$REPORT_FILE"
        
        # Configuración SSL
        echo "CONFIGURACIÓN SSL" >> "$REPORT_FILE"
        echo "----------------" >> "$REPORT_FILE"
        if [ -f "/etc/webmin/miniserv.conf" ]; then
            if grep -q "^ssl=1" /etc/webmin/miniserv.conf; then
                echo "SSL habilitado: Sí" >> "$REPORT_FILE"
            else
                echo "SSL habilitado: No (INSEGURO)" >> "$REPORT_FILE"
            fi
            
            if grep -q "^ssl_protocols=" /etc/webmin/miniserv.conf; then
                echo "Protocolos SSL: $(grep "^ssl_protocols=" /etc/webmin/miniserv.conf | cut -d= -f2)" >> "$REPORT_FILE"
            else
                echo "Protocolos SSL: No configurados (INSEGURO)" >> "$REPORT_FILE"
            fi
        fi
        echo "" >> "$REPORT_FILE"
        
        # Puertos abiertos
        echo "PUERTOS ABIERTOS" >> "$REPORT_FILE"
        echo "---------------" >> "$REPORT_FILE"
        if command -v netstat &> /dev/null; then
            netstat -tuln | grep "LISTEN" >> "$REPORT_FILE"
        elif command -v ss &> /dev/null; then
            ss -tuln | grep "LISTEN" >> "$REPORT_FILE"
        fi
        echo "" >> "$REPORT_FILE"
        
        # Configuración del firewall
        echo "CONFIGURACIÓN DEL FIREWALL" >> "$REPORT_FILE"
        echo "-------------------------" >> "$REPORT_FILE"
        if command -v ufw &> /dev/null; then
            echo "Firewall: UFW" >> "$REPORT_FILE"
            ufw status >> "$REPORT_FILE"
        elif command -v firewall-cmd &> /dev/null; then
            echo "Firewall: firewalld" >> "$REPORT_FILE"
            firewall-cmd --list-all >> "$REPORT_FILE"
        elif command -v iptables &> /dev/null; then
            echo "Firewall: iptables" >> "$REPORT_FILE"
            iptables -L -n >> "$REPORT_FILE"
        elif command -v pfctl &> /dev/null; then
            echo "Firewall: pf" >> "$REPORT_FILE"
            pfctl -s rules >> "$REPORT_FILE"
        else
            echo "No se encontró ningún firewall configurado (INSEGURO)" >> "$REPORT_FILE"
        fi
        echo "" >> "$REPORT_FILE"
        
        # Servicios activos
        echo "SERVICIOS ACTIVOS" >> "$REPORT_FILE"
        echo "----------------" >> "$REPORT_FILE"
        if command -v systemctl &> /dev/null; then
            systemctl list-units --type=service --state=running | grep -E "webmin|apache|nginx|mysql|mariadb|postgresql|ssh|fail2ban" >> "$REPORT_FILE"
        elif command -v service &> /dev/null; then
            service --status-all | grep -E "webmin|apache|nginx|mysql|mariadb|postgresql|ssh|fail2ban" >> "$REPORT_FILE"
        fi
        echo "" >> "$REPORT_FILE"
        
        # Actualizaciones pendientes
        echo "ACTUALIZACIONES PENDIENTES" >> "$REPORT_FILE"
        echo "------------------------" >> "$REPORT_FILE"
        case "$OS" in
            "ubuntu"|"debian")
                apt-get update -qq &>/dev/null
                apt list --upgradable 2>/dev/null >> "$REPORT_FILE"
                ;;
            "rhel"|"centos"|"fedora")
                if command -v dnf &> /dev/null; then
                    dnf check-update -q 2>/dev/null >> "$REPORT_FILE"
                else
                    yum check-update -q 2>/dev/null >> "$REPORT_FILE"
                fi
                ;;
        esac
        echo "" >> "$REPORT_FILE"
        
        # Problemas de seguridad detectados
        echo "PROBLEMAS DE SEGURIDAD DETECTADOS" >> "$REPORT_FILE"
        echo "-------------------------------" >> "$REPORT_FILE"
        
        # Verificar SSL
        if [ -f "/etc/webmin/miniserv.conf" ] && ! grep -q "^ssl=1" /etc/webmin/miniserv.conf; then
            echo "[CRÍTICO] SSL no está habilitado en Webmin" >> "$REPORT_FILE"
        fi
        
        # Verificar protocolos SSL
        if [ -f "/etc/webmin/miniserv.conf" ] && ! grep -q "^ssl_protocols=TLSv1.2\+" /etc/webmin/miniserv.conf; then
            echo "[CRÍTICO] Protocolos SSL inseguros en Webmin" >> "$REPORT_FILE"
        fi
        
        # Verificar firewall
        if ! command -v ufw &> /dev/null && ! command -v firewall-cmd &> /dev/null && ! command -v iptables &> /dev/null && ! command -v pfctl &> /dev/null; then
            echo "[CRÍTICO] No se encontró ningún firewall instalado" >> "$REPORT_FILE"
        fi
        
        # Verificar fail2ban
        if ! command -v fail2ban-client &> /dev/null; then
            echo "[CRÍTICO] fail2ban no está instalado" >> "$REPORT_FILE"
        fi
        
        # Verificar permisos de archivos críticos
        if [ -f "/etc/webmin/miniserv.pem" ] && [ "$(stat -c "%a" "/etc/webmin/miniserv.pem" 2>/dev/null || stat -f "%Lp" "/etc/webmin/miniserv.pem" 2>/dev/null)" != "400" ]; then
            echo "[CRÍTICO] Permisos incorrectos en /etc/webmin/miniserv.pem" >> "$REPORT_FILE"
        fi
        
        if [ -f "/etc/webmin/miniserv.key" ] && [ "$(stat -c "%a" "/etc/webmin/miniserv.key" 2>/dev/null || stat -f "%Lp" "/etc/webmin/miniserv.key" 2>/dev/null)" != "400" ]; then
            echo "[CRÍTICO] Permisos incorrectos en /etc/webmin/miniserv.key" >> "$REPORT_FILE"
        fi
        
        if [ -f "/etc/ssh/sshd_config" ] && [ "$(stat -c "%a" "/etc/ssh/sshd_config" 2>/dev/null || stat -f "%Lp" "/etc/ssh/sshd_config" 2>/dev/null)" != "600" ]; then
            echo "[CRÍTICO] Permisos incorrectos en /etc/ssh/sshd_config" >> "$REPORT_FILE"
        fi
        
        # Verificar configuración SSH
        if [ -f "/etc/ssh/sshd_config" ]; then
            if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config; then
                echo "[CRÍTICO] Inicio de sesión como root permitido en SSH" >> "$REPORT_FILE"
            fi
            
            if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
                echo "[ADVERTENCIA] Autenticación por contraseña permitida en SSH" >> "$REPORT_FILE"
            fi
            
            if grep -q "^Protocol 1" /etc/ssh/sshd_config; then
                echo "[CRÍTICO] Protocolo SSH 1 habilitado (inseguro)" >> "$REPORT_FILE"
            fi
        fi
        
        log "SUCCESS" "Informe de seguridad generado: $REPORT_FILE"
        
        # Mostrar el informe
        if [ "$VERBOSE" = true ]; then
            cat "$REPORT_FILE"
        else
            echo "Informe de seguridad generado: $REPORT_FILE"
            echo "Ejecute 'cat $REPORT_FILE' para ver el informe completo."
        fi
    else
        log "INFO" "[DRY-RUN] Se generaría un informe de seguridad"
    fi
    
    return 0
}

# Función para mostrar el menú de ayuda
show_help() {
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  -h, --help              Muestra esta ayuda"
    echo "  -d, --dry-run           Modo simulación (no realiza cambios)"
    echo "  -v, --verbose           Modo detallado"
    echo "  -a, --all               Corregir todos los problemas de seguridad"
    echo "  -w, --webmin            Corregir solo problemas de Webmin"
    echo "  -s, --ssh               Corregir solo problemas de SSH"
    echo "  -f, --firewall          Corregir solo problemas de firewall"
    echo "  -p, --permissions       Corregir solo permisos de archivos"
    echo "  -b, --fail2ban          Instalar y configurar fail2ban"
    echo "  -u, --update            Actualizar el sistema y Webmin/Virtualmin"
    echo "  -r, --report            Generar informe de seguridad"
    echo ""
    echo "Ejemplos:"
    echo "  $0 --all                Corregir todos los problemas de seguridad"
    echo "  $0 --dry-run --all      Simular corrección de todos los problemas"
    echo "  $0 --webmin --ssh       Corregir problemas de Webmin y SSH"
    echo "  $0 --report             Generar informe de seguridad"
    echo ""
}

# Función principal
main() {
    # Verificar si se ejecuta como root
    if [ "$(id -u)" -ne 0 ] && [ "$DRY_RUN" = false ]; then
        echo "Este script debe ejecutarse como root"
        echo "Intente: sudo $0 $*"
        exit 1
    fi
    
    # Mostrar banner
    show_banner
    
    # Procesar argumentos
    if [ $# -eq 0 ]; then
        # Mostrar menú interactivo si no hay argumentos
        while true; do
            echo ""
            echo "Seleccione una opción:"
            echo "1) Corregir todos los problemas de seguridad"
            echo "2) Corregir problemas de Webmin"
            echo "3) Corregir problemas de servidor web (Apache/Nginx)"
            echo "4) Corregir problemas de base de datos (MySQL/MariaDB)"
            echo "5) Corregir problemas de SSH"
            echo "6) Corregir problemas de firewall"
            echo "7) Corregir permisos de archivos críticos"
            echo "8) Instalar y configurar fail2ban"
            echo "9) Actualizar sistema y Webmin/Virtualmin"
            echo "10) Generar informe de seguridad"
            echo "11) Modo simulación (activar/desactivar)"
            echo "12) Modo detallado (activar/desactivar)"
            echo "13) Ayuda"
            echo "0) Salir"
            echo ""
            read -p "Opción: " option
            
            case "$option" in
                1)
                    fix_webmin_security
                    if command -v apache2 &> /dev/null || command -v httpd &> /dev/null; then
                        fix_apache_security
                    fi
                    if command -v nginx &> /dev/null; then
                        fix_nginx_security
                    fi
                    if command -v mysql &> /dev/null; then
                        fix_mysql_security
                    fi
                    fix_ssh_security
                    fix_firewall_security
                    fix_file_permissions
                    install_configure_fail2ban
                    update_system
                    update_webmin_virtualmin
                    generate_security_report
                    ;;
                2)
                    fix_webmin_security
                    ;;
                3)
                    if command -v apache2 &> /dev/null || command -v httpd &> /dev/null; then
                        fix_apache_security
                    fi
                    if command -v nginx &> /dev/null; then
                        fix_nginx_security
                    fi
                    ;;
                4)
                    if command -v mysql &> /dev/null; then
                        fix_mysql_security
                    fi
                    ;;
                5)
                    fix_ssh_security
                    ;;
                6)
                    fix_firewall_security
                    ;;
                7)
                    fix_file_permissions
                    ;;
                8)
                    install_configure_fail2ban
                    ;;
                9)
                    update_system
                    update_webmin_virtualmin
                    ;;
                10)
                    generate_security_report
                    ;;
                11)
                    if [ "$DRY_RUN" = false ]; then
                        DRY_RUN=true
                        log "INFO" "Modo simulación activado"
                    else
                        DRY_RUN=false
                        log "INFO" "Modo simulación desactivado"
                    fi
                    ;;
                12)
                    if [ "$VERBOSE" = false ]; then
                        VERBOSE=true
                        log "INFO" "Modo detallado activado"
                    else
                        VERBOSE=false
                        log "INFO" "Modo detallado desactivado"
                    fi
                    ;;
                13)
                    show_help
                    ;;
                0)
                    log "INFO" "Saliendo..."
                    exit 0
                    ;;
                *)
                    log "ERROR" "Opción inválida"
                    ;;
            esac
        done
    else
        # Procesar argumentos de línea de comandos
        while [ $# -gt 0 ]; do
            case "$1" in
                -h|--help)
                    show_help
                    exit 0
                    ;;
                -d|--dry-run)
                    DRY_RUN=true
                    log "INFO" "Modo simulación activado"
                    ;;
                -v|--verbose)
                    VERBOSE=true
                    log "INFO" "Modo detallado activado"
                    ;;
                -a|--all)
                    FIX_ALL=true
                    ;;
                -w|--webmin)
                    fix_webmin_security
                    ;;
                -s|--ssh)
                    fix_ssh_security
                    ;;
                -f|--firewall)
                    fix_firewall_security
                    ;;
                -p|--permissions)
                    fix_file_permissions
                    ;;
                -b|--fail2ban)
                    install_configure_fail2ban
                    ;;
                -u|--update)
                    update_system
                    update_webmin_virtualmin
                    ;;
                -r|--report)
                    generate_security_report
                    ;;
                *)
                    log "ERROR" "Opción desconocida: $1"
                    show_help
                    exit 1
                    ;;
            esac
            shift
        done
        
        # Si se especificó --all, ejecutar todas las correcciones
        if [ "$FIX_ALL" = true ]; then
            fix_webmin_security
            if command -v apache2 &> /dev/null || command -v httpd &> /dev/null; then
                fix_apache_security
            fi
            if command -v nginx &> /dev/null; then
                fix_nginx_security
            fi
            if command -v mysql &> /dev/null; then
                fix_mysql_security
            fi
            fix_ssh_security
            fix_firewall_security
            fix_file_permissions
            install_configure_fail2ban
            update_system
            update_webmin_virtualmin
            generate_security_report
        fi
    fi
    
    return 0
}

# Ejecutar la función principal
main "$@"

# Función para corregir problemas de seguridad en Webmin
fix_webmin_security() {
    log "INFO" "Iniciando corrección de seguridad para Webmin..."
    
    # Verificar si Webmin está instalado
    if [ ! -d "/etc/webmin" ]; then
        log "WARNING" "Webmin no está instalado. Omitiendo correcciones de Webmin."
        return 1
    fi
    
    # Verificar y corregir la configuración SSL
    if [ -f "/etc/webmin/miniserv.conf" ]; then
        backup_file "/etc/webmin/miniserv.conf"
        
        # Habilitar SSL si no está habilitado
        if ! grep -q "^ssl=1" /etc/webmin/miniserv.conf; then
            if [ "$DRY_RUN" = false ]; then
                sed -i 's/ssl=0/ssl=1/g' /etc/webmin/miniserv.conf
                if ! grep -q "^ssl=" /etc/webmin/miniserv.conf; then
                    echo "ssl=1" >> /etc/webmin/miniserv.conf
                fi
                log "SUCCESS" "SSL habilitado en Webmin"
            else
                log "INFO" "[DRY-RUN] Se habilitaría SSL en Webmin"
            fi
        else
            log "INFO" "SSL ya está habilitado en Webmin"
        fi
        
        # Configurar protocolos SSL seguros
        if ! grep -q "^ssl_protocols=" /etc/webmin/miniserv.conf; then
            if [ "$DRY_RUN" = false ]; then
                echo "ssl_protocols=TLSv1.2+" >> /etc/webmin/miniserv.conf
                log "SUCCESS" "Protocolos SSL seguros configurados en Webmin"
            else
                log "INFO" "[DRY-RUN] Se configurarían protocolos SSL seguros en Webmin"
            fi
        else
            if [ "$DRY_RUN" = false ]; then
                sed -i 's/^ssl_protocols=.*/ssl_protocols=TLSv1.2+/g' /etc/webmin/miniserv.conf
                log "SUCCESS" "Protocolos SSL seguros actualizados en Webmin"
            else
                log "INFO" "[DRY-RUN] Se actualizarían protocolos SSL seguros en Webmin"
            fi
        fi
        
        # Configurar cifrados SSL seguros
        if ! grep -q "^ssl_ciphers=" /etc/webmin/miniserv.conf; then
            if [ "$DRY_RUN" = false ]; then
                echo "ssl_ciphers=ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384" >> /etc/webmin/miniserv.conf
                log "SUCCESS" "Cifrados SSL seguros configurados en Webmin"
            else
                log "INFO" "[DRY-RUN] Se configurarían cifrados SSL seguros en Webmin"
            fi
        else
            if [ "$DRY_RUN" = false ]; then
                sed -i 's/^ssl_ciphers=.*/ssl_ciphers=ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384/g' /etc/webmin/miniserv.conf
                log "SUCCESS" "Cifrados SSL seguros actualizados en Webmin"
            else
                log "INFO" "[DRY-RUN] Se actualizarían cifrados SSL seguros en Webmin"
            fi
        fi
        
        # Configurar tiempo de sesión
        if ! grep -q "^session_timeout=" /etc/webmin/miniserv.conf; then
            if [ "$DRY_RUN" = false ]; then
                echo "session_timeout=60" >> /etc/webmin/miniserv.conf
                log "SUCCESS" "Tiempo de sesión configurado en Webmin (60 minutos)"
            else
                log "INFO" "[DRY-RUN] Se configuraría tiempo de sesión en Webmin (60 minutos)"
            fi
        else
            current_timeout=$(grep "^session_timeout=" /etc/webmin/miniserv.conf | cut -d= -f2)
            if [ "$current_timeout" -gt 60 ]; then
                if [ "$DRY_RUN" = false ]; then
                    sed -i 's/^session_timeout=.*/session_timeout=60/g' /etc/webmin/miniserv.conf
                    log "SUCCESS" "Tiempo de sesión actualizado en Webmin (60 minutos)"
                else
                    log "INFO" "[DRY-RUN] Se actualizaría tiempo de sesión en Webmin (60 minutos)"
                fi
            else
                log "INFO" "Tiempo de sesión en Webmin ya es seguro ($current_timeout minutos)"
            fi
        fi
        
        # Configurar intentos de inicio de sesión
        if ! grep -q "^passdelay=" /etc/webmin/miniserv.conf; then
            if [ "$DRY_RUN" = false ]; then
                echo "passdelay=3" >> /etc/webmin/miniserv.conf
                log "SUCCESS" "Retraso de contraseña configurado en Webmin (3 segundos)"
            else
                log "INFO" "[DRY-RUN] Se configuraría retraso de contraseña en Webmin (3 segundos)"
            fi
        fi
        
        # Configurar bloqueo de IP tras intentos fallidos
        if ! grep -q "^blockhost_failures=" /etc/webmin/miniserv.conf; then
            if [ "$DRY_RUN" = false ]; then
                echo "blockhost_failures=5" >> /etc/webmin/miniserv.conf
                echo "blockhost_time=60" >> /etc/webmin/miniserv.conf
                log "SUCCESS" "Bloqueo de IP configurado en Webmin (5 intentos, 60 minutos)"
            else
                log "INFO" "[DRY-RUN] Se configuraría bloqueo de IP en Webmin (5 intentos, 60 minutos)"
            fi
        fi
        
        # Configurar registro de accesos
        if ! grep -q "^logoutput=" /etc/webmin/miniserv.conf; then
            if [ "$DRY_RUN" = false ]; then
                echo "logoutput=/var/log/webmin/miniserv.log" >> /etc/webmin/miniserv.conf
                log "SUCCESS" "Registro de accesos configurado en Webmin"
            else
                log "INFO" "[DRY-RUN] Se configuraría registro de accesos en Webmin"
            fi
        fi
        
        # Reiniciar Webmin si no estamos en modo dry-run
        if [ "$DRY_RUN" = false ]; then
            if service_is_active "webmin"; then
                if command -v systemctl &> /dev/null; then
                    systemctl restart webmin
                elif command -v service &> /dev/null; then
                    service webmin restart
                elif [ -f "/etc/init.d/webmin" ]; then
                    /etc/init.d/webmin restart
                fi
                log "SUCCESS" "Webmin reiniciado con la nueva configuración de seguridad"
            fi
        else
            log "INFO" "[DRY-RUN] Se reiniciaría Webmin con la nueva configuración"
        fi
    else
        log "ERROR" "No se encontró el archivo de configuración de Webmin"
        return 1
    fi
    
    return 0
}

# Función para corregir problemas de seguridad en Apache
fix_apache_security() {
    log "INFO" "Iniciando corrección de seguridad para Apache..."
    
    # Verificar si Apache está instalado
    if command -v apache2 &> /dev/null; then
        APACHE_CMD="apache2"
        if [ -d "/etc/apache2" ]; then
            APACHE_CONF_DIR="/etc/apache2"
            APACHE_SECURITY_CONF="$APACHE_CONF_DIR/conf-available/security.conf"
            APACHE_SSL_CONF="$APACHE_CONF_DIR/mods-available/ssl.conf"
        fi
    elif command -v httpd &> /dev/null; then
        APACHE_CMD="httpd"
        if [ -d "/etc/httpd" ]; then
            APACHE_CONF_DIR="/etc/httpd"
            APACHE_SECURITY_CONF="$APACHE_CONF_DIR/conf.d/security.conf"
            APACHE_SSL_CONF="$APACHE_CONF_DIR/conf.d/ssl.conf"
        fi
    else
        log "WARNING" "Apache no está instalado. Omitiendo correcciones de Apache."
        return 1
    fi
    
    # Verificar si existe el directorio de configuración
    if [ -z "$APACHE_CONF_DIR" ] || [ ! -d "$APACHE_CONF_DIR" ]; then
        log "ERROR" "No se encontró el directorio de configuración de Apache"
        return 1
    fi
    
    # Crear archivo de seguridad si no existe
    if [ ! -f "$APACHE_SECURITY_CONF" ]; then
        if [ "$DRY_RUN" = false ]; then
            mkdir -p "$(dirname "$APACHE_SECURITY_CONF")"
            touch "$APACHE_SECURITY_CONF"
            log "INFO" "Creado archivo de configuración de seguridad para Apache"
        else
            log "INFO" "[DRY-RUN] Se crearía archivo de configuración de seguridad para Apache"
        fi
    else
        backup_file "$APACHE_SECURITY_CONF"
    fi
    
    # Configurar opciones de seguridad
    if [ -f "$APACHE_SECURITY_CONF" ]; then
        if [ "$DRY_RUN" = false ]; then
            # Configurar cabeceras de seguridad
            cat > "$APACHE_SECURITY_CONF" << EOF
# Configuración de seguridad para Apache

# Ocultar versión y sistema operativo
ServerTokens Prod
ServerSignature Off

# Protección XSS
<IfModule mod_headers.c>
    Header set X-XSS-Protection "1; mode=block"
    Header set X-Content-Type-Options "nosniff"
    Header set X-Frame-Options "SAMEORIGIN"
    Header set Content-Security-Policy "default-src 'self';"
    Header set Referrer-Policy "strict-origin-when-cross-origin"
    Header always unset X-Powered-By
</IfModule>

# Deshabilitar listado de directorios
<Directory />
    Options -Indexes
</Directory>

# Limitar métodos HTTP
<Location "/">
    <LimitExcept GET POST HEAD>
        deny from all
    </LimitExcept>
</Location>

# Protección contra ataques de clickjacking
<IfModule mod_headers.c>
    Header always append X-Frame-Options SAMEORIGIN
</IfModule>

# Deshabilitar TRACE
TraceEnable Off

# Configuración de cookies seguras
<IfModule mod_headers.c>
    Header edit Set-Cookie ^(.*)$ $1;HttpOnly;Secure
</IfModule>

# Protección contra ataques de tipo MIME
<IfModule mod_mime.c>
    AddType text/html .html .htm
    AddType text/css .css
    AddType application/javascript .js
</IfModule>

# Limitar tamaño de solicitudes
<IfModule mod_reqtimeout.c>
    RequestReadTimeout header=20-40,MinRate=500 body=20,MinRate=500
</IfModule>

# Limitar tamaño de carga de archivos
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{REQUEST_METHOD} ^(PUT|POST)$ [NC]
    RewriteCond %{HTTP:Content-Length} >10485760
    RewriteRule .* - [F,L]
</IfModule>

# Protección contra ataques DoS
<IfModule mod_qos.c>
    QS_ClientEntries 100
    QS_SrvMaxConnPerIP 50
    MaxClients 256
    QS_SrvMaxConnClose 256
</IfModule>

# Protección contra ataques de inyección de cabeceras HTTP
<IfModule mod_headers.c>
    Header unset Proxy
</IfModule>
EOF
            log "SUCCESS" "Configuración de seguridad de Apache actualizada"
        else
            log "INFO" "[DRY-RUN] Se actualizaría la configuración de seguridad de Apache"
        fi
    fi
    
    # Configurar SSL si está habilitado
    if [ "$APACHE_CMD" = "apache2" ] && [ -f "$APACHE_CONF_DIR/mods-enabled/ssl.conf" ] || \
       [ "$APACHE_CMD" = "httpd" ] && [ -f "$APACHE_SSL_CONF" ]; then
        
        if [ -f "$APACHE_SSL_CONF" ]; then
            backup_file "$APACHE_SSL_CONF"
            
            if [ "$DRY_RUN" = false ]; then
                # Configurar SSL seguro
                cat > "$APACHE_SSL_CONF" << EOF
<IfModule mod_ssl.c>
    # Configuración SSL segura
    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
    SSLHonorCipherOrder on
    SSLCompression off
    SSLSessionTickets off
    SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
    SSLOpenSSLConfCmd Curves X25519:secp521r1:secp384r1:prime256v1
    
    # OCSP Stapling
    SSLUseStapling on
    SSLStaplingCache "shmcb:logs/stapling-cache(150000)"
    SSLStaplingResponseMaxAge 900
    
    # HSTS (15768000 segundos = 6 meses)
    <IfModule mod_headers.c>
        Header always set Strict-Transport-Security "max-age=15768000; includeSubDomains; preload"
    </IfModule>
</IfModule>
EOF
                log "SUCCESS" "Configuración SSL de Apache actualizada"
            else
                log "INFO" "[DRY-RUN] Se actualizaría la configuración SSL de Apache"
            fi
        fi
    fi
    
    # Habilitar módulos de seguridad
    if [ "$APACHE_CMD" = "apache2" ] && command -v a2enmod &> /dev/null; then
        SECURITY_MODULES=("headers" "ssl" "rewrite")
        
        for module in "${SECURITY_MODULES[@]}"; do
            if [ -f "$APACHE_CONF_DIR/mods-available/$module.load" ] && [ ! -f "$APACHE_CONF_DIR/mods-enabled/$module.load" ]; then
                if [ "$DRY_RUN" = false ]; then
                    a2enmod "$module" > /dev/null 2>&1
                    log "SUCCESS" "Módulo $module habilitado en Apache"
                else
                    log "INFO" "[DRY-RUN] Se habilitaría el módulo $module en Apache"
                fi
            fi
        done
        
        # Habilitar configuración de seguridad
        if [ -f "$APACHE_SECURITY_CONF" ] && [ ! -f "$APACHE_CONF_DIR/conf-enabled/security.conf" ]; then
            if [ "$DRY_RUN" = false ]; then
                a2enconf "security" > /dev/null 2>&1
                log "SUCCESS" "Configuración de seguridad habilitada en Apache"
            else
                log "INFO" "[DRY-RUN] Se habilitaría la configuración de seguridad en Apache"
            fi
        fi
    fi
    
    # Reiniciar Apache si no estamos en modo dry-run
    if [ "$DRY_RUN" = false ]; then
        if service_is_active "$APACHE_CMD"; then
            if command -v systemctl &> /dev/null; then
                systemctl restart "$APACHE_CMD"
            elif command -v service &> /dev/null; then
                service "$APACHE_CMD" restart
            elif [ -f "/etc/init.d/$APACHE_CMD" ]; then
                /etc/init.d/"$APACHE_CMD" restart
            fi
            log "SUCCESS" "Apache reiniciado con la nueva configuración de seguridad"
        fi
    else
        log "INFO" "[DRY-RUN] Se reiniciaría Apache con la nueva configuración"
    fi
    
    return 0
}

# Función para corregir problemas de seguridad en Nginx
fix_nginx_security() {
    log "INFO" "Iniciando corrección de seguridad para Nginx..."
    
    # Verificar si Nginx está instalado
    if ! command -v nginx &> /dev/null; then
        log "WARNING" "Nginx no está instalado. Omitiendo correcciones de Nginx."
        return 1
    fi
    
    # Verificar directorio de configuración
    if [ -d "/etc/nginx" ]; then
        NGINX_CONF_DIR="/etc/nginx"
        NGINX_SECURITY_CONF="$NGINX_CONF_DIR/conf.d/security.conf"
    else
        log "ERROR" "No se encontró el directorio de configuración de Nginx"
        return 1
    fi
    
    # Crear archivo de seguridad si no existe
    if [ ! -f "$NGINX_SECURITY_CONF" ]; then
        if [ "$DRY_RUN" = false ]; then
            mkdir -p "$(dirname "$NGINX_SECURITY_CONF")"
            touch "$NGINX_SECURITY_CONF"
            log "INFO" "Creado archivo de configuración de seguridad para Nginx"
        else
            log "INFO" "[DRY-RUN] Se crearía archivo de configuración de seguridad para Nginx"
        fi
    else
        backup_file "$NGINX_SECURITY_CONF"
    fi
    
    # Configurar opciones de seguridad
    if [ -f "$NGINX_SECURITY_CONF" ]; then
        if [ "$DRY_RUN" = false ]; then
            # Configurar cabeceras de seguridad
            cat > "$NGINX_SECURITY_CONF" << EOF
# Configuración de seguridad para Nginx

# Ocultar versión
server_tokens off;

# Tamaño máximo del cuerpo de la solicitud
client_max_body_size 10m;

# Timeouts
client_body_timeout 10s;
client_header_timeout 10s;
keepalive_timeout 65s;
send_timeout 10s;

# Protección contra ataques de buffer overflow
client_body_buffer_size 128k;
client_header_buffer_size 1k;
large_client_header_buffers 4 4k;

# Limitar métodos HTTP
if (\$request_method !~ ^(GET|POST|HEAD)\$) {
    return 444;
}

# Cabeceras de seguridad
add_header X-XSS-Protection "1; mode=block" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header Content-Security-Policy "default-src 'self';" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload" always;

# Deshabilitar acceso a archivos ocultos
location ~ /\. {
    deny all;
    access_log off;
    log_not_found off;
}

# Deshabilitar acceso a archivos de respaldo
location ~ ~\$ {
    deny all;
    access_log off;
    log_not_found off;
}

# Protección contra ataques de inyección de PHP
location ~ \.(php|phtml|php3|php4|php5|php7)\$ {
    fastcgi_param HTTP_PROXY "";
}

# Configuración SSL
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
ssl_ecdh_curve secp384r1;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 1d;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
EOF
            log "SUCCESS" "Configuración de seguridad de Nginx actualizada"
        else
            log "INFO" "[DRY-RUN] Se actualizaría la configuración de seguridad de Nginx"
        fi
    fi
    
    # Verificar y corregir la configuración principal de Nginx
    if [ -f "$NGINX_CONF_DIR/nginx.conf" ]; then
        backup_file "$NGINX_CONF_DIR/nginx.conf"
        
        # Incluir el archivo de seguridad en la configuración principal
        if ! grep -q "include /etc/nginx/conf.d/security.conf" "$NGINX_CONF_DIR/nginx.conf"; then
            if [ "$DRY_RUN" = false ]; then
                # Buscar la sección http
                if grep -q "^http {" "$NGINX_CONF_DIR/nginx.conf"; then
                    # Insertar después de la línea http {
                    sed -i '/^http {/a \    include /etc/nginx/conf.d/security.conf;' "$NGINX_CONF_DIR/nginx.conf"
                    log "SUCCESS" "Archivo de seguridad incluido en la configuración principal de Nginx"
                else
                    log "WARNING" "No se pudo encontrar la sección http en la configuración de Nginx"
                fi
            else
                log "INFO" "[DRY-RUN] Se incluiría el archivo de seguridad en la configuración principal de Nginx"
            fi
        fi
    fi
    
    # Reiniciar Nginx si no estamos en modo dry-run
    if [ "$DRY_RUN" = false ]; then
        if service_is_active "nginx"; then
            if command -v systemctl &> /dev/null; then
                systemctl restart nginx
            elif command -v service &> /dev/null; then
                service nginx restart
            elif [ -f "/etc/init.d/nginx" ]; then
                /etc/init.d/nginx restart
            fi
            log "SUCCESS" "Nginx reiniciado con la nueva configuración de seguridad"
        fi
    else
        log "INFO" "[DRY-RUN] Se reiniciaría Nginx con la nueva configuración"
    fi
    
    return 0
}

# Función para corregir problemas de seguridad en MySQL/MariaDB
fix_mysql_security() {
    log "INFO" "Iniciando corrección de seguridad para MySQL/MariaDB..."
    
    # Verificar si MySQL/MariaDB está instalado
    if ! command -v mysql &> /dev/null; then
        log "WARNING" "MySQL/MariaDB no está instalado. Omitiendo correcciones de MySQL/MariaDB."
        return 1
    fi
    
    # Verificar directorio de configuración
    if [ -d "/etc/mysql" ]; then
        MYSQL_CONF_DIR="/etc/mysql"
        MYSQL_CONF_FILE="$MYSQL_CONF_DIR/my.cnf"
    elif [ -d "/etc/my.cnf.d" ]; then
        MYSQL_CONF_DIR="/etc/my.cnf.d"
        MYSQL_CONF_FILE="/etc/my.cnf"
    else
        log "ERROR" "No se encontró el directorio de configuración de MySQL/MariaDB"
        return 1
    fi
    
    # Crear archivo de seguridad
    MYSQL_SECURITY_CONF="$MYSQL_CONF_DIR/security.cnf"
    
    if [ ! -f "$MYSQL_SECURITY_CONF" ]; then
        if [ "$DRY_RUN" = false ]; then
            mkdir -p "$(dirname "$MYSQL_SECURITY_CONF")"
            touch "$MYSQL_SECURITY_CONF"
            log "INFO" "Creado archivo de configuración de seguridad para MySQL/MariaDB"
        else
            log "INFO" "[DRY-RUN] Se crearía archivo de configuración de seguridad para MySQL/MariaDB"
        fi
    else
        backup_file "$MYSQL_SECURITY_CONF"
    fi
    
    # Configurar opciones de seguridad
    if [ -f "$MYSQL_SECURITY_CONF" ]; then
        if [ "$DRY_RUN" = false ]; then
            # Configurar opciones de seguridad
            cat > "$MYSQL_SECURITY_CONF" << EOF
[mysqld]
# Seguridad básica
sql_mode=STRICT_ALL_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION

# Deshabilitar carga local de archivos
local_infile=0

# Limitar acceso a archivos del sistema
secure_file_priv=/var/lib/mysql-files

# Autenticación segura
default_authentication_plugin=mysql_native_password

# Limitar conexiones y consultas
max_connections=100
max_connect_errors=10
wait_timeout=600
interactive_timeout=600
max_allowed_packet=16M

# Registro de consultas lentas
slow_query_log=1
slow_query_log_file=/var/log/mysql/mysql-slow.log
long_query_time=2

# Registro de errores
log_error=/var/log/mysql/error.log

# Deshabilitar funcionalidades peligrosas
skip_symbolic_links=1

# Configuración SSL
ssl=1
ssl_ca=/etc/mysql/ca.pem
ssl_cert=/etc/mysql/server-cert.pem
ssl_key=/etc/mysql/server-key.pem
EOF
            log "SUCCESS" "Configuración de seguridad de MySQL/MariaDB actualizada"
        else
            log "INFO" "[DRY-RUN] Se actualizaría la configuración de seguridad de MySQL/MariaDB"
        fi
    fi
    
    # Verificar y corregir la configuración principal
    if [ -f "$MYSQL_CONF_FILE" ]; then
        backup_file "$MYSQL_CONF_FILE"
        
        # Incluir el archivo de seguridad en la configuración principal
        if ! grep -q "!includedir $MYSQL_CONF_DIR" "$MYSQL_CONF_FILE" && ! grep -q "!include $MYSQL_SECURITY_CONF" "$MYSQL_CONF_FILE"; then
            if [ "$DRY_RUN" = false ]; then
                echo "!include $MYSQL_SECURITY_CONF" >> "$MYSQL_CONF_FILE"
                log "SUCCESS" "Archivo de seguridad incluido en la configuración principal de MySQL/MariaDB"
            else
                log "INFO" "[DRY-RUN] Se incluiría el archivo de seguridad en la configuración principal de MySQL/MariaDB"
            fi
        fi
    fi
    
    # Reiniciar MySQL/MariaDB si no estamos en modo dry-run
    if [ "$DRY_RUN" = false ]; then
        if service_is_active "mysql" || service_is_active "mariadb"; then
            if service_is_active "mysql"; then
                SERVICE_NAME="mysql"
            else
                SERVICE_NAME="mariadb"
            fi
            
            if command -v systemctl &> /dev/null; then
                systemctl restart "$SERVICE_NAME"
            elif command -v service &> /dev/null; then
                service "$SERVICE_NAME" restart
            elif [ -f "/etc/init.d/$SERVICE_NAME" ]; then
                /etc/init.d/"$SERVICE_NAME" restart
            fi
            log "SUCCESS" "MySQL/MariaDB reiniciado con la nueva configuración de seguridad"
        fi
    else
        log "INFO" "[DRY-RUN] Se reiniciaría MySQL/MariaDB con la nueva configuración"
    fi
    
    return 0
}

# Función para corregir problemas de seguridad en SSH
fix_ssh_security() {
    log "INFO" "Iniciando corrección de seguridad para SSH..."
    
    # Verificar si SSH está instalado
    if ! command -v ssh &> /dev/null; then
        log "WARNING" "SSH no está instalado. Omitiendo correcciones de SSH."
        return 1
    fi
    
    # Verificar archivo de configuración
    SSH_CONF_FILE="/etc/ssh/sshd_config"
    
    if [ ! -f "$SSH_CONF_FILE" ]; then
        log "ERROR" "No se encontró el archivo de configuración de SSH"
        return 1
    fi
    
    # Hacer copia de seguridad del archivo de configuración
    backup_file "$SSH_CONF_FILE"
    
    # Configurar opciones de seguridad
    if [ "$DRY_RUN" = false ]; then
        # Deshabilitar inicio de sesión como root
        if grep -q "^PermitRootLogin" "$SSH_CONF_FILE"; then
            sed -i 's/^PermitRootLogin.*/PermitRootLogin no/g' "$SSH_CONF_FILE"
        else
            echo "PermitRootLogin no" >> "$SSH_CONF_FILE"
        fi
        log "SUCCESS" "Inicio de sesión como root deshabilitado en SSH"
        
        # Deshabilitar autenticación por contraseña
        if grep -q "^PasswordAuthentication" "$SSH_CONF_FILE"; then
            sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/g' "$SSH_CONF_FILE"
        else
            echo "PasswordAuthentication no" >> "$SSH_CONF_FILE"
        fi
        log "SUCCESS" "Autenticación por contraseña deshabilitada en SSH"
        
        # Configurar versión del protocolo
        if grep -q "^Protocol" "$SSH_CONF_FILE"; then
            sed -i 's/^Protocol.*/Protocol 2/g' "$SSH_CONF_FILE"
        else
            echo "Protocol 2" >> "$SSH_CONF_FILE"
        fi
        log "SUCCESS" "Protocolo SSH configurado a versión 2"
        
        # Configurar algoritmos de cifrado
        if grep -q "^Ciphers" "$SSH_CONF_FILE"; then
            sed -i 's/^Ciphers.*/Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr/g' "$SSH_CONF_FILE"
        else
            echo "Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr" >> "$SSH_CONF_FILE"
        fi
        log "SUCCESS" "Algoritmos de cifrado seguros configurados en SSH"
        
        # Configurar algoritmos de intercambio de claves
        if grep -q "^KexAlgorithms" "$SSH_CONF_FILE"; then
            sed -i 's/^KexAlgorithms.*/KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256/g' "$SSH_CONF_FILE"
        else
            echo "KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256" >> "$SSH_CONF_FILE"
        fi
        log "SUCCESS" "Algoritmos de intercambio de claves seguros configurados en SSH"
        
        # Configurar algoritmos MAC
        if grep -q "^MACs" "$SSH_CONF_FILE"; then
            sed -i 's/^MACs.*/MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com/g' "$SSH_CONF_FILE"
        else
            echo "MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com" >> "$SSH_CONF_FILE"
        fi
        log "SUCCESS" "Algoritmos MAC seguros configurados en SSH"
        
        # Configurar tiempo de inactividad
        if grep -q "^ClientAliveInterval" "$SSH_CONF_FILE"; then
            sed -i 's/^ClientAliveInterval.*/ClientAliveInterval 300/g' "$SSH_CONF_FILE"
        else
            echo "ClientAliveInterval 300" >> "$SSH_CONF_FILE"
        fi
        
        if grep -q "^ClientAliveCountMax" "$SSH_CONF_FILE"; then
            sed -i 's/^ClientAliveCountMax.*/ClientAliveCountMax 2/g' "$SSH_CONF_FILE"
        else
            echo "ClientAliveCountMax 2" >> "$SSH_CONF_FILE"
        fi
        log "SUCCESS" "Tiempo de inactividad configurado en SSH (300 segundos)"
        
        # Limitar intentos de inicio de sesión
        if grep -q "^MaxAuthTries" "$SSH_CONF_FILE"; then
            sed -i 's/^MaxAuthTries.*/MaxAuthTries 3/g' "$SSH_CONF_FILE"
        else
            echo "MaxAuthTries 3" >> "$SSH_CONF_FILE"
        fi
        log "SUCCESS" "Intentos de inicio de sesión limitados en SSH (3 intentos)"
        
        # Deshabilitar reenvío X11
        if grep -q "^X11Forwarding" "$SSH_CONF_FILE"; then
            sed -i 's/^X11Forwarding.*/X11Forwarding no/g' "$SSH_CONF_FILE"
        else
            echo "X11Forwarding no" >> "$SSH_CONF_FILE"
        fi
        log "SUCCESS" "Reenvío X11 deshabilitado en SSH"
        
        # Deshabilitar reenvío de agente
        if grep -q "^AllowAgentForwarding" "$SSH_CONF_FILE"; then
            sed -i 's/^AllowAgentForwarding.*/AllowAgentForwarding no/g' "$SSH_CONF_FILE"
        else
            echo "AllowAgentForwarding no" >> "$SSH_CONF_FILE"
        fi
        log "SUCCESS" "Reenvío de agente deshabilitado en SSH"
        
        # Deshabilitar inicio de sesión vacío
        if grep -q "^PermitEmptyPasswords" "$SSH_CONF_FILE"; then
            sed -i 's/^PermitEmptyPasswords.*/PermitEmptyPasswords no/g' "$SSH_CONF_FILE"
        else
            echo "PermitEmptyPasswords no" >> "$SSH_CONF_FILE"
        fi
        log "SUCCESS" "Inicio de sesión con contraseña vacía deshabilitado en SSH"
        
        # Configurar banner
        if grep -q "^Banner" "$SSH_CONF_FILE"; then
            sed -i 's/^Banner.*/Banner \/etc\/ssh\/banner/g' "$SSH_CONF_FILE"
        else
            echo "Banner /etc/ssh/banner" >> "$SSH_CONF_FILE"
        fi
        
        # Crear archivo de banner
        if [ ! -f "/etc/ssh/banner" ]; then
            cat > "/etc/ssh/banner" << EOF
***************************************************************************
*                                                                         *
*                      ACCESO RESTRINGIDO                                 *
*                                                                         *
* Este sistema es para uso exclusivo de usuarios autorizados.             *
* Todas las actividades son monitoreadas y registradas.                   *
* El acceso no autorizado está prohibido y será procesado legalmente.     *
*                                                                         *
***************************************************************************
EOF
            log "SUCCESS" "Banner de SSH creado"
        fi
    else
        log "INFO" "[DRY-RUN] Se actualizaría la configuración de seguridad de SSH"
    fi
    
    # Reiniciar SSH si no estamos en modo dry-run
    if [ "$DRY_RUN" = false ]; then
        if service_is_active "sshd" || service_is_active "ssh"; then
            if service_is_active "sshd"; then
                SERVICE_NAME="sshd"
            else
                SERVICE_NAME="ssh"
            fi
            
            if command -v systemctl &> /dev/null; then
                systemctl restart "$SERVICE_NAME"
            elif command -v service &> /dev/null; then
                service "$SERVICE_NAME" restart
            elif [ -f "/etc/init.d/$SERVICE_NAME" ]; then
                /etc/init.d/"$SERVICE_NAME" restart
            fi
            log "SUCCESS" "SSH reiniciado con la nueva configuración de seguridad"
        fi
    else
        log "INFO" "[DRY-RUN] Se reiniciaría SSH con la nueva configuración"
    fi
    
    return 0
}

# Función para corregir problemas de seguridad en el firewall
fix_firewall_security() {
    log "INFO" "Iniciando corrección de seguridad para el firewall..."
    
    # Detectar el firewall instalado
    FIREWALL_TYPE="none"
    
    if command -v ufw &> /dev/null; then
        FIREWALL_TYPE="ufw"
    elif command -v firewall-cmd &> /dev/null; then
        FIREWALL_TYPE="firewalld"
    elif command -v iptables &> /dev/null; then
        FIREWALL_TYPE="iptables"
    elif command -v pfctl &> /dev/null; then
        FIREWALL_TYPE="pf"
    fi
    
    if [ "$FIREWALL_TYPE" = "none" ]; then
        log "WARNING" "No se encontró ningún firewall instalado"
        return 1
    fi
    
    log "INFO" "Firewall detectado: $FIREWALL_TYPE"
    
    # Configurar reglas según el tipo de firewall
    case "$FIREWALL_TYPE" in
        "ufw")
            if [ "$DRY_RUN" = false ]; then
                # Habilitar UFW si no está activo
                if ! ufw status | grep -q "Status: active"; then
                    ufw --force enable
                    log "SUCCESS" "UFW habilitado"
                fi
                
                # Configurar política por defecto
                ufw default deny incoming
                ufw default allow outgoing
                log "SUCCESS" "Política por defecto configurada en UFW"
                
                # Permitir SSH
                ufw allow 22/tcp
                log "SUCCESS" "Puerto SSH (22) permitido en UFW"
                
                # Permitir Webmin
                ufw allow 10000/tcp
                log "SUCCESS" "Puerto Webmin (10000) permitido en UFW"
                
                # Permitir HTTP/HTTPS
                ufw allow 80/tcp
                ufw allow 443/tcp
                log "SUCCESS" "Puertos HTTP/HTTPS permitidos en UFW"
                
                # Permitir correo electrónico si es necesario
                if service_is_installed "postfix" || service_is_installed "dovecot"; then
                    ufw allow 25/tcp
                    ufw allow 465/tcp
                    ufw allow 587/tcp
                    ufw allow 110/tcp
                    ufw allow 995/tcp
                    ufw allow 143/tcp
                    ufw allow 993/tcp
                    log "SUCCESS" "Puertos de correo electrónico permitidos en UFW"
                fi
                
                # Limitar intentos de conexión SSH
                ufw limit 22/tcp
                log "SUCCESS" "Limitación de intentos de conexión SSH configurada en UFW"
            else
                log "INFO" "[DRY-RUN] Se configurarían reglas de seguridad en UFW"
            fi
            ;;
        "firewalld")
            if [ "$DRY_RUN" = false ]; then
                # Habilitar firewalld si no está activo
                if ! firewall-cmd --state | grep -q "running"; then
                    systemctl enable --now firewalld
                    log "SUCCESS" "firewalld habilitado"
                fi
                
                # Configurar zona por defecto
                firewall-cmd --set-default-zone=public
                
                # Permitir servicios
                firewall-cmd --permanent --zone=public --add-service=ssh
                firewall-cmd --permanent --zone=public --add-service=http
                firewall-cmd --permanent --zone=public --add-service=https
                
                # Permitir Webmin
                firewall-cmd --permanent --zone=public --add-port=10000/tcp
                
                # Permitir correo electrónico si es necesario
                if service_is_installed "postfix" || service_is_installed "dovecot"; then
                    firewall-cmd --permanent --zone=public --add-service=smtp
                    firewall-cmd --permanent --zone=public --add-port=465/tcp
                    firewall-cmd --permanent --zone=public --add-port=587/tcp
                    firewall-cmd --permanent --zone=public --add-service=pop3
                    firewall-cmd --permanent --zone=public --add-port=995/tcp
                    firewall-cmd --permanent --zone=public --add-service=imap
                    firewall-cmd --permanent --zone=public --add-port=993/tcp
                    log "SUCCESS" "Puertos de correo electrónico permitidos en firewalld"
                fi
                
                # Recargar configuración
                firewall-cmd --reload
                log "SUCCESS" "Configuración de firewalld recargada"
            else
                log "INFO" "[DRY-RUN] Se configurarían reglas de seguridad en firewalld"
            fi
            ;;
        "iptables")
            if [ "$DRY_RUN" = false ]; then
                # Limpiar reglas existentes
                iptables -F
                iptables -X
                iptables -t nat -F
                iptables -t nat -X
                iptables -t mangle -F
                iptables -t mangle -X
                log "INFO" "Reglas de iptables limpiadas"
                
                # Configurar política por defecto
                iptables -P INPUT DROP
                iptables -P FORWARD DROP
                iptables -P OUTPUT ACCEPT
                log "SUCCESS" "Política por defecto configurada en iptables"
                
                # Permitir tráfico loopback
                iptables -A INPUT -i lo -j ACCEPT
                iptables -A OUTPUT -o lo -j ACCEPT
                
                # Permitir conexiones establecidas
                iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
                
                # Permitir SSH
                iptables -A INPUT -p tcp --dport 22 -j ACCEPT
                log "SUCCESS" "Puerto SSH (22) permitido en iptables"
                
                # Permitir Webmin
                iptables -A INPUT -p tcp --dport 10000 -j ACCEPT
                log "SUCCESS" "Puerto Webmin (10000) permitido en iptables"
                
                # Permitir HTTP/HTTPS
                iptables -A INPUT -p tcp --dport 80 -j ACCEPT
                iptables -A INPUT -p tcp --dport 443 -j ACCEPT
                log "SUCCESS" "Puertos HTTP/HTTPS permitidos en iptables"
                
                # Permitir correo electrónico si es necesario
                if service_is_installed "postfix" || service_is_installed "dovecot"; then
                    iptables -A INPUT -p tcp --dport 25 -j ACCEPT
                    iptables -A INPUT -p tcp --dport 465 -j ACCEPT
                    iptables -A INPUT -p tcp --dport 587 -j ACCEPT
                    iptables -A INPUT -p tcp --dport 110 -j ACCEPT
                    iptables -A INPUT -p tcp --dport 995 -j ACCEPT
                    iptables -A INPUT -p tcp --dport 143 -j ACCEPT
                    iptables -A INPUT -p tcp --dport 993 -j ACCEPT
                    log "SUCCESS" "Puertos de correo electrónico permitidos en iptables"
                fi
                
                # Protección contra ataques
                iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
                iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
                iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
                iptables -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
                iptables -A INPUT -p tcp --tcp-flags ACK,FIN FIN -j DROP
                iptables -A INPUT -p tcp --tcp-flags ACK,URG URG -j DROP
                log "SUCCESS" "Protección contra ataques configurada en iptables"
                
                # Limitar intentos de conexión SSH
                iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set
                iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
                log "SUCCESS" "Limitación de intentos de conexión SSH configurada en iptables"
                
                # Guardar reglas
                if [ -d "/etc/iptables" ]; then
                    iptables-save > /etc/iptables/rules.v4
                elif [ -d "/etc/sysconfig" ]; then
                    iptables-save > /etc/sysconfig/iptables
                else
                    iptables-save > /etc/iptables.rules
                fi
                log "SUCCESS" "Reglas de iptables guardadas"
            else
                log "INFO" "[DRY-RUN] Se configurarían reglas de seguridad en iptables"
            fi
            ;;
        "pf")
            if [ "$DRY_RUN" = false ]; then
                # Crear archivo de reglas
                PF_CONF="/etc/pf.conf"
                
                if [ -f "$PF_CONF" ]; then
                    backup_file "$PF_CONF"
                fi
                
                cat > "$PF_CONF" << EOF
# Reglas de firewall pf para Webmin/Virtualmin

# Definir interfaces
set skip on lo0

# Opciones
set block-policy drop
set fingerprints "/etc/pf.os"

# Normalización
scrub in all

# Bloquear por defecto
block all

# Permitir tráfico saliente
pass out quick keep state

# Permitir SSH
pass in proto tcp to any port 22 flags S/SA keep state

# Permitir Webmin
pass in proto tcp to any port 10000 flags S/SA keep state

# Permitir HTTP/HTTPS
pass in proto tcp to any port { 80 443 } flags S/SA keep state

# Permitir correo electrónico
pass in proto tcp to any port { 25 465 587 110 995 143 993 } flags S/SA keep state

# Protección contra ataques
block in quick from urpf-failed
block in quick from any to 255.255.255.255
block in quick from any to 127.0.0.0/8
EOF
                
                # Habilitar pf
                pfctl -e
                
                # Cargar reglas
                pfctl -f "$PF_CONF"
                log "SUCCESS" "Reglas de pf configuradas y cargadas"
            else
                log "INFO" "[DRY-RUN] Se configurarían reglas de seguridad en pf"
            fi
            ;;
    esac
    
    return 0
}

# Función para corregir permisos de archivos críticos
fix_file_permissions() {
    log "INFO" "Iniciando corrección de permisos de archivos críticos..."
    
    # Lista de archivos y directorios críticos con sus permisos recomendados
    declare -A CRITICAL_FILES
    
    # Archivos de configuración de Webmin
    CRITICAL_FILES["/etc/webmin"]="750"
    CRITICAL_FILES["/etc/webmin/miniserv.conf"]="640"
    CRITICAL_FILES["/etc/webmin/miniserv.pem"]="400"
    CRITICAL_FILES["/etc/webmin/miniserv.key"]="400"
    
    # Archivos de configuración de Virtualmin
    if [ -d "/etc/webmin/virtual-server" ]; then
        CRITICAL_FILES["/etc/webmin/virtual-server"]="750"
        CRITICAL_FILES["/etc/webmin/virtual-server/domains"]="640"
    fi
    
    # Archivos de configuración del servidor web
    if [ -d "/etc/apache2" ]; then
        CRITICAL_FILES["/etc/apache2"]="750"
        CRITICAL_FILES["/etc/apache2/apache2.conf"]="640"
        CRITICAL_FILES["/etc/apache2/sites-available"]="750"
        CRITICAL_FILES["/etc/apache2/ssl"]="700"
    elif [ -d "/etc/httpd" ]; then
        CRITICAL_FILES["/etc/httpd"]="750"
        CRITICAL_FILES["/etc/httpd/conf/httpd.conf"]="640"
        CRITICAL_FILES["/etc/httpd/conf.d"]="750"
    fi
    
    if [ -d "/etc/nginx" ]; then
        CRITICAL_FILES["/etc/nginx"]="750"
        CRITICAL_FILES["/etc/nginx/nginx.conf"]="640"
        CRITICAL_FILES["/etc/nginx/conf.d"]="750"
    fi
    
    # Archivos de configuración de base de datos
    if [ -d "/etc/mysql" ]; then
        CRITICAL_FILES["/etc/mysql"]="750"
        CRITICAL_FILES["/etc/mysql/my.cnf"]="640"
    fi
    
    # Archivos de configuración de SSH
    CRITICAL_FILES["/etc/ssh"]="755"
    CRITICAL_FILES["/etc/ssh/sshd_config"]="600"
    CRITICAL_FILES["/etc/ssh/ssh_host_rsa_key"]="600"
    CRITICAL_FILES["/etc/ssh/ssh_host_dsa_key"]="600"
    CRITICAL_FILES["/etc/ssh/ssh_host_ecdsa_key"]="600"
    CRITICAL_FILES["/etc/ssh/ssh_host_ed25519_key"]="600"
    
    # Archivos de contraseñas y grupos
    CRITICAL_FILES["/etc/passwd"]="644"
    CRITICAL_FILES["/etc/shadow"]="640"
    CRITICAL_FILES["/etc/group"]="644"
    CRITICAL_FILES["/etc/gshadow"]="640"
    
    # Archivos de configuración de firewall
    if [ -d "/etc/ufw" ]; then
        CRITICAL_FILES["/etc/ufw"]="750"
        CRITICAL_FILES["/etc/ufw/ufw.conf"]="640"
    fi
    
    if [ -d "/etc/firewalld" ]; then
        CRITICAL_FILES["/etc/firewalld"]="750"
        CRITICAL_FILES["/etc/firewalld/firewalld.conf"]="640"
    fi
    
    # Corregir permisos
    for file in "${!CRITICAL_FILES[@]}"; do
        if [ -e "$file" ]; then
            current_perm=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%Lp" "$file" 2>/dev/null)
            required_perm="${CRITICAL_FILES[$file]}"
            
            if [ "$current_perm" != "$required_perm" ]; then
                if [ "$DRY_RUN" = false ]; then
                    chmod "$required_perm" "$file"
                    log "SUCCESS" "Permisos de $file corregidos: $current_perm -> $required_perm"
                else
                    log "INFO" "[DRY-RUN] Se corregirían permisos de $file: $current_perm -> $required_perm"
                fi
            else
                log "INFO" "Permisos de $file ya son correctos: $current_perm"
            fi
        fi
    done
    
    return 0
}

# Función para instalar y configurar fail2ban
install_configure_fail2ban() {
    log "INFO" "Iniciando instalación y configuración de fail2ban..."
    
    # Verificar si fail2ban está instalado
    if ! command -v fail2ban-client &> /dev/null; then
        if [ "$DRY_RUN" = false ]; then
            # Detectar el sistema operativo
            detect_os
            
            # Instalar fail2ban según el sistema operativo
            case "$OS" in
                "ubuntu"|"debian")
                    apt-get update
                    apt-get install -y fail2ban
                    ;;
                "rhel"|"centos"|"fedora")
                    if command -v dnf &> /dev/null; then
                        dnf install -y epel-release
                        dnf install -y fail2ban
                    else
                        yum install -y epel-release
                        yum install -y fail2ban
                    fi
                    ;;
                *)
                    log "ERROR" "No se pudo instalar fail2ban: Sistema operativo no soportado"
                    return 1
                    ;;
            esac
            
            log "SUCCESS" "fail2ban instalado"
        else
            log "INFO" "[DRY-RUN] Se instalaría fail2ban"
        fi
    else
        log "INFO" "fail2ban ya está instalado"
    fi
    
    # Configurar fail2ban
    if [ -d "/etc/fail2ban" ]; then
        # Crear archivo de configuración local
        FAIL2BAN_LOCAL="/etc/fail2ban/jail.local"
        
        if [ -f "$FAIL2BAN_LOCAL" ]; then
            backup_file "$FAIL2BAN_LOCAL"
        fi
        
        if [ "$DRY_RUN" = false ]; then
            cat > "$FAIL2BAN_LOCAL" << EOF
[DEFAULT]
# Tiempo de baneo (en segundos)
bantime = 3600

# Tiempo de búsqueda (en segundos)
findtime = 600

# Número de intentos fallidos antes del baneo
maxretry = 3

# Ignorar IPs locales
ignoreip = 127.0.0.1/8 ::1

# Acción a realizar
banaction = iptables-multiport

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log

[webmin-auth]
enabled = true
port = 10000
filter = webmin-auth
logpath = /var/log/auth.log

[apache-auth]
enabled = true
port = http,https
filter = apache-auth
logpath = /var/log/apache2/error.log

[nginx-http-auth]
enabled = true
port = http,https
filter = nginx-http-auth
logpath = /var/log/nginx/error.log

[postfix]
enabled = true
port = smtp,submission,smtps
filter = postfix
logpath = /var/log/mail.log

[dovecot]
enabled = true
port = pop3,pop3s,imap,imaps
filter = dovecot
logpath = /var/log/mail.log
EOF
            
            # Crear filtro para Webmin si no existe
            WEBMIN_FILTER="/etc/fail2ban/filter.d/webmin-auth.conf"
            
            if [ ! -f "$WEBMIN_FILTER" ]; then
                cat > "$WEBMIN_FILTER" << EOF
[Definition]
failregex = webmin\[\d+\]: Invalid login as .+ from <HOST>
ignoreregex =
EOF
            fi
            
            # Reiniciar fail2ban
            if service_is_active "fail2ban"; then
                if command -v systemctl &> /dev/null; then
                    systemctl restart fail2ban
                elif command -v service &> /dev/null; then
                    service fail2ban restart
                elif [ -f "/etc/init.d/fail2ban" ]; then
                    /etc/init.d/fail2ban restart
                fi
            else
                if command -v systemctl &> /dev/null; then
                    systemctl enable --now fail2ban
                elif command -v service &> /dev/null; then
                    service fail2ban start
                elif [ -f "/etc/init.d/fail2ban" ]; then
                    /etc/init.d/fail2ban start
                fi
            fi
            
            log "SUCCESS" "fail2ban configurado y reiniciado"
        else
            log "INFO" "[DRY-RUN] Se configuraría fail2ban"
        fi
    fi
    
    return 0
}
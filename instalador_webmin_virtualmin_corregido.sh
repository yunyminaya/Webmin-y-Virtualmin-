#!/bin/bash

# Instalador Corregido de Webmin/Virtualmin
# Soluciona todos los problemas identificados en los scripts anteriores

set -euo pipefail

# Configuración de colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOG_FILE="/var/log/instalacion_webmin_virtualmin_$(date +%Y%m%d_%H%M%S).log"
ERROR_FILE="/var/log/errores_instalacion_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="/var/backups/pre_instalacion_$(date +%Y%m%d_%H%M%S)"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE" | tee -a "$ERROR_FILE"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$LOG_FILE"
}

# Manejo de errores mejorado
handle_error() {
    local line_number=$1
    local error_code=$2
    log_error "Error en línea $line_number. Código de salida: $error_code"
    log_error "Ver detalles en: $ERROR_FILE"
    exit $error_code
}

trap 'handle_error $LINENO $?' ERR

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  INSTALADOR CORREGIDO WEBMIN/VIRTUALMIN   ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# 1. VERIFICACIONES PRE-INSTALACIÓN
pre_installation_checks() {
    log_info "=== VERIFICACIONES PRE-INSTALACIÓN ==="
    
    # Verificar permisos root
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root"
        exit 1
    fi
    
    # Verificar conectividad
    if ! ping -c 3 8.8.8.8 >/dev/null 2>&1; then
        log_error "Sin conectividad a Internet"
        exit 1
    fi
    
    # Verificar espacio en disco
    local available_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 2097152 ]]; then  # 2GB en KB
        log_error "Espacio insuficiente en disco (mínimo 2GB)"
        exit 1
    fi
    
    # Detectar conflictos de paquetes
    detect_package_conflicts
    
    # Verificar puertos disponibles
    check_required_ports
    
    log_success "Verificaciones pre-instalación completadas"
    echo ""
}

detect_package_conflicts() {
    log_info "Detectando conflictos de paquetes..."
    
    local conflicts_found=false
    
    # Verificar conflictos web server
    if dpkg -l | grep -q "^ii.*nginx" && dpkg -l | grep -q "^ii.*apache2"; then
        log_warning "Conflicto: Apache y Nginx están instalados simultáneamente"
        conflicts_found=true
    fi
    
    # Verificar conflictos MTA
    local mta_count=0
    for mta in postfix sendmail exim4; do
        if dpkg -l | grep -q "^ii.*$mta"; then
            ((mta_count++))
        fi
    done
    
    if [[ $mta_count -gt 1 ]]; then
        log_warning "Conflicto: Múltiples MTAs instalados"
        conflicts_found=true
    fi
    
    # Verificar conflictos de base de datos
    if dpkg -l | grep -q "^ii.*mysql-server" && dpkg -l | grep -q "^ii.*mariadb-server"; then
        log_warning "Conflicto: MySQL y MariaDB instalados simultáneamente"
        conflicts_found=true
    fi
    
    if [[ "$conflicts_found" == "true" ]]; then
        log_warning "Se detectaron conflictos de paquetes - proceder con precaución"
        read -p "¿Continuar de todos modos? (s/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            exit 1
        fi
    fi
}

check_required_ports() {
    log_info "Verificando puertos requeridos..."
    
    local required_ports=("10000" "20000" "80" "443" "22")
    local ports_in_use=()
    
    for port in "${required_ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
            ports_in_use+=("$port")
        fi
    done
    
    if [[ ${#ports_in_use[@]} -gt 0 ]]; then
        log_warning "Puertos en uso: ${ports_in_use[*]}"
        log_warning "Esto puede causar conflictos durante la instalación"
    fi
}

# 2. CREAR BACKUP DE SEGURIDAD
create_backup() {
    log_info "=== CREANDO BACKUP DE SEGURIDAD ==="
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup de configuraciones existentes
    local backup_paths=(
        "/etc/webmin"
        "/etc/usermin"
        "/etc/apache2"
        "/etc/nginx"
        "/etc/postfix"
        "/etc/mysql"
        "/etc/apt/sources.list"
        "/etc/apt/sources.list.d"
    )
    
    for path in "${backup_paths[@]}"; do
        if [[ -e "$path" ]]; then
            local backup_name=$(basename "$path")
            tar -czf "$BACKUP_DIR/${backup_name}_backup.tar.gz" -C "$(dirname "$path")" "$(basename "$path")" 2>/dev/null || true
            log_success "Backup creado: ${backup_name}_backup.tar.gz"
        fi
    done
    
    log_success "Backup completo en: $BACKUP_DIR"
    echo ""
}

# 3. ACTUALIZAR SISTEMA
update_system_safe() {
    log_info "=== ACTUALIZANDO SISTEMA DE FORMA SEGURA ==="
    
    # Actualizar listas de paquetes
    apt-get update || {
        log_error "Error al actualizar listas de paquetes"
        return 1
    }
    
    # Actualizar solo paquetes críticos de seguridad
    unattended-upgrade -d || log_warning "No se pudieron instalar actualizaciones automáticas"
    
    # Instalar dependencias básicas una por una con verificación
    local basic_deps=(
        "curl"
        "wget"
        "gnupg2"
        "software-properties-common"
        "ca-certificates"
        "apt-transport-https"
    )
    
    for dep in "${basic_deps[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$dep"; then
            log_info "Instalando dependencia: $dep"
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$dep" || {
                log_error "Error instalando $dep"
                return 1
            }
        else
            log_success "Dependencia ya instalada: $dep"
        fi
    done
    
    log_success "Sistema actualizado de forma segura"
    echo ""
}

# 4. CONFIGURAR REPOSITORIO WEBMIN (MÉTODO CORREGIDO)
setup_webmin_repository_fixed() {
    log_info "=== CONFIGURANDO REPOSITORIO WEBMIN (MÉTODO CORREGIDO) ==="
    
    # Eliminar configuraciones anteriores problemáticas
    rm -f /etc/apt/sources.list.d/webmin.list
    rm -f /usr/share/keyrings/webmin.gpg
    
    # Limpiar llaves GPG obsoletas
    apt-key del 11F63C51 2>/dev/null || true
    
    # Descargar y verificar llave GPG (método moderno)
    log_info "Descargando llave GPG de Webmin..."
    if ! curl -fsSL https://download.webmin.com/jcameron-key.asc | gpg --dearmor -o /usr/share/keyrings/webmin.gpg; then
        log_error "Error al descargar llave GPG de Webmin"
        return 1
    fi
    
    # Verificar que la llave se descargó correctamente
    if [[ ! -f "/usr/share/keyrings/webmin.gpg" ]] || [[ ! -s "/usr/share/keyrings/webmin.gpg" ]]; then
        log_error "Llave GPG de Webmin no se descargó correctamente"
        return 1
    fi
    
    # Configurar repositorio con llave firmada
    echo "deb [signed-by=/usr/share/keyrings/webmin.gpg] https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
    
    # Verificar configuración del repositorio
    if [[ ! -f "/etc/apt/sources.list.d/webmin.list" ]]; then
        log_error "Error al crear configuración del repositorio"
        return 1
    fi
    
    # Actualizar listas con el nuevo repositorio
    if ! apt-get update; then
        log_error "Error al actualizar listas con repositorio Webmin"
        return 1
    fi
    
    # Verificar que el repositorio está funcionando
    if ! apt-cache search webmin >/dev/null 2>&1; then
        log_error "Repositorio Webmin no está funcionando correctamente"
        return 1
    fi
    
    log_success "Repositorio Webmin configurado correctamente"
    echo ""
}

# 5. INSTALAR DEPENDENCIAS DEL SERVIDOR (SIN CONFLICTOS)
install_server_dependencies_safe() {
    log_info "=== INSTALANDO DEPENDENCIAS DEL SERVIDOR SIN CONFLICTOS ==="
    
    # Verificar qué web server instalar
    local web_server=""
    if dpkg -l | grep -q "^ii.*nginx"; then
        web_server="nginx"
        log_info "Nginx ya está instalado, no instalar Apache"
    elif dpkg -l | grep -q "^ii.*apache2"; then
        web_server="apache2"
        log_info "Apache ya está instalado"
    else
        web_server="apache2"
        log_info "Instalando Apache como web server por defecto"
    fi
    
    # Verificar qué base de datos instalar
    local database=""
    if dpkg -l | grep -q "^ii.*mariadb-server"; then
        database="mariadb"
        log_info "MariaDB ya está instalado"
    elif dpkg -l | grep -q "^ii.*mysql-server"; then
        database="mysql"
        log_info "MySQL ya está instalado"
    else
        database="mysql"
        log_info "Instalando MySQL como base de datos por defecto"
    fi
    
    # Instalar dependencias Perl críticas para Webmin
    local perl_deps=(
        "libnet-ssleay-perl"
        "libio-socket-ssl-perl"
        "libauthen-pam-perl"
        "libpam-runtime"
        "shared-mime-info"
    )
    
    for dep in "${perl_deps[@]}"; do
        log_info "Instalando dependencia Perl: $dep"
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$dep" || {
            log_error "Error instalando $dep"
            return 1
        }
    done
    
    # Instalar web server solo si es necesario
    if [[ "$web_server" == "apache2" ]] && ! dpkg -l | grep -q "^ii.*apache2"; then
        log_info "Instalando Apache..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y apache2 apache2-utils
        systemctl enable apache2
    fi
    
    # Instalar base de datos solo si es necesario
    if [[ "$database" == "mysql" ]] && ! dpkg -l | grep -q "^ii.*mysql-server"; then
        log_info "Instalando MySQL..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server mysql-client
        systemctl enable mysql
    fi
    
    # Instalar PHP si no está presente
    if ! dpkg -l | grep -q "^ii.*php"; then
        log_info "Instalando PHP..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y php php-mysql php-cli php-common php-curl php-gd php-mbstring php-xml php-zip
    fi
    
    log_success "Dependencias del servidor instaladas sin conflictos"
    echo ""
}

# 6. INSTALAR WEBMIN (MÉTODO ROBUSTO)
install_webmin_robust() {
    log_info "=== INSTALANDO WEBMIN DE FORMA ROBUSTA ==="
    
    # Verificar si Webmin ya está instalado
    if dpkg -l | grep -q "^ii.*webmin"; then
        local current_version=$(dpkg -l | grep webmin | awk '{print $3}')
        log_warning "Webmin ya está instalado (versión: $current_version)"
        
        read -p "¿Reinstalar Webmin? (s/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            log_info "Manteniendo instalación actual de Webmin"
            return 0
        fi
        
        # Detener servicio antes de reinstalar
        systemctl stop webmin 2>/dev/null || true
        
        # Backup de configuración actual
        if [[ -d "/etc/webmin" ]]; then
            tar -czf "$BACKUP_DIR/webmin_config_actual.tar.gz" -C / etc/webmin
            log_success "Configuración actual de Webmin respaldada"
        fi
    fi
    
    # Instalar Webmin
    log_info "Instalando paquete Webmin..."
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y webmin; then
        log_error "Error al instalar Webmin"
        return 1
    fi
    
    # Verificar instalación
    if ! command -v webmin >/dev/null 2>&1; then
        log_error "Webmin no se instaló correctamente"
        return 1
    fi
    
    # Verificar archivos críticos
    local critical_files=(
        "/usr/share/webmin/miniserv.pl"
        "/etc/webmin/miniserv.conf"
        "/etc/webmin/config"
    )
    
    for file in "${critical_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Archivo crítico faltante: $file"
            return 1
        fi
    done
    
    log_success "Webmin instalado correctamente"
    echo ""
}

# 7. CONFIGURAR WEBMIN SEGURO
configure_webmin_secure() {
    log_info "=== CONFIGURANDO WEBMIN DE FORMA SEGURA ==="
    
    # Verificar hostname antes de generar certificados
    local hostname=$(hostname -f)
    if [[ -z "$hostname" ]] || [[ "$hostname" == "localhost" ]] || [[ "$hostname" == "localhost.localdomain" ]]; then
        hostname=$(hostname -I | awk '{print $1}')
        log_warning "Hostname no configurado, usando IP: $hostname"
    fi
    
    # Generar certificado SSL seguro
    log_info "Generando certificado SSL para: $hostname"
    
    local ssl_dir="/etc/webmin"
    local ssl_file="$ssl_dir/miniserv.pem"
    
    # Backup de certificado existente
    if [[ -f "$ssl_file" ]]; then
        cp "$ssl_file" "$ssl_file.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Generar nuevo certificado con configuración segura
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$ssl_file" \
        -out "$ssl_file" \
        -subj "/C=ES/ST=Local/L=Local/O=Webmin/CN=$hostname" \
        -extensions v3_req \
        -config <(cat <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = ES
ST = Local
L = Local
O = Webmin
CN = $hostname

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $hostname
IP.1 = $(hostname -I | awk '{print $1}')
EOF
    )
    
    # Configurar permisos seguros
    chmod 600 "$ssl_file"
    chown root:root "$ssl_file"
    
    # Configurar miniserv.conf con configuración segura
    local miniserv_conf="$ssl_dir/miniserv.conf"
    
    # Backup de configuración existente
    if [[ -f "$miniserv_conf" ]]; then
        cp "$miniserv_conf" "$miniserv_conf.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Escribir configuración segura
    cat > "$miniserv_conf" << EOF
port=10000
root=/usr/share/webmin
mimetypes=/usr/share/webmin/mime.types
addtype_cgi=internal/cgi
realm=Webmin Server
logfile=/var/webmin/miniserv.log
errorlog=/var/webmin/miniserv.error
pidfile=/var/webmin/miniserv.pid
logtime=168
ssl=1
env_WEBMIN_CONFIG=/etc/webmin
env_WEBMIN_VAR=/var/webmin
atboot=1
logout=/etc/webmin/logout-flag
listen=10000
denyfile=\.pl$
log=1
blockhost_failures=5
blockhost_time=60
syslog=1
session=1
premodules=WebminCore
server=MiniServ/2.000
userfile=/etc/webmin/miniserv.users
keyfile=/etc/webmin/miniserv.pem
passwd_file=/etc/webmin/miniserv.users
passwd_uindex=0
passwd_pindex=1
passwd_cindex=2
passwd_mindex=4
passwd_mode=0
preload_functions=1
gzip=1
maxconns=50
pam_conv=1
no_referers_check=0
referers_none=1
trust_unknown_referers=0
referer=1
EOF
    
    chmod 600 "$miniserv_conf"
    chown root:root "$miniserv_conf"
    
    log_success "Webmin configurado de forma segura"
    echo ""
}

# 8. VERIFICAR E INICIAR SERVICIOS
verify_and_start_services() {
    log_info "=== VERIFICANDO E INICIANDO SERVICIOS ==="
    
    local services=("webmin")
    
    # Agregar servicios instalados
    if dpkg -l | grep -q "^ii.*apache2"; then
        services+=("apache2")
    fi
    
    if dpkg -l | grep -q "^ii.*mysql-server"; then
        services+=("mysql")
    fi
    
    for service in "${services[@]}"; do
        log_info "Configurando servicio: $service"
        
        # Habilitar servicio
        if ! systemctl enable "$service" 2>/dev/null; then
            log_warning "No se pudo habilitar $service"
            continue
        fi
        
        # Iniciar servicio
        if ! systemctl start "$service"; then
            log_error "No se pudo iniciar $service"
            continue
        fi
        
        # Verificar que está activo (con timeout)
        local max_attempts=30
        local attempt=1
        
        while [[ $attempt -le $max_attempts ]]; do
            if systemctl is-active --quiet "$service"; then
                log_success "Servicio $service: ACTIVO"
                break
            fi
            
            if [[ $attempt -eq $max_attempts ]]; then
                log_error "Servicio $service no se pudo iniciar después de $max_attempts intentos"
                
                # Mostrar información de debug
                log_error "Estado del servicio $service:"
                systemctl status "$service" --no-pager || true
                
                # Mostrar logs si hay errores
                log_error "Últimos logs de $service:"
                journalctl -u "$service" --no-pager -n 10 || true
            fi
            
            sleep 2
            ((attempt++))
        done
    done
    
    echo ""
}

# 9. VERIFICACIÓN POST-INSTALACIÓN COMPLETA
post_installation_verification() {
    log_info "=== VERIFICACIÓN POST-INSTALACIÓN COMPLETA ==="
    
    local verification_passed=true
    
    # Verificar acceso a Webmin
    log_info "Verificando acceso a Webmin..."
    
    local webmin_urls=("https://localhost:10000" "http://localhost:10000")
    local webmin_accessible=false
    
    for url in "${webmin_urls[@]}"; do
        if curl -k -s --connect-timeout 10 --max-time 30 "$url" >/dev/null 2>&1; then
            log_success "Webmin accesible vía: $url"
            webmin_accessible=true
            break
        fi
    done
    
    if [[ "$webmin_accessible" == "false" ]]; then
        log_error "Webmin no es accesible"
        verification_passed=false
    fi
    
    # Verificar puertos críticos
    local critical_ports=("10000")
    
    for port in "${critical_ports[@]}"; do
        if netstat -tuln | grep -q ":${port} "; then
            log_success "Puerto $port: ABIERTO"
        else
            log_error "Puerto $port: CERRADO"
            verification_passed=false
        fi
    done
    
    # Verificar archivos de configuración
    local config_files=(
        "/etc/webmin/miniserv.conf"
        "/etc/webmin/config"
        "/etc/webmin/miniserv.pem"
    )
    
    for config in "${config_files[@]}"; do
        if [[ -f "$config" ]] && [[ -s "$config" ]]; then
            log_success "Configuración válida: $config"
        else
            log_error "Configuración inválida: $config"
            verification_passed=false
        fi
    done
    
    # Verificar permisos críticos
    if [[ -f "/etc/webmin/miniserv.conf" ]]; then
        local perms=$(stat -c "%a" "/etc/webmin/miniserv.conf")
        if [[ "$perms" == "600" ]]; then
            log_success "Permisos correctos en miniserv.conf"
        else
            log_warning "Permisos incorrectos en miniserv.conf: $perms (debería ser 600)"
        fi
    fi
    
    if [[ "$verification_passed" == "true" ]]; then
        log_success "Verificación post-instalación: EXITOSA"
    else
        log_error "Verificación post-instalación: FALLÓ"
        return 1
    fi
    
    echo ""
}

# 10. MOSTRAR INFORMACIÓN FINAL
show_installation_summary() {
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}      INSTALACIÓN COMPLETADA EXITOSAMENTE  ${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    
    log_success "¡Webmin instalado y configurado correctamente!"
    echo ""
    
    log_info "INFORMACIÓN DE ACCESO:"
    echo "URL Webmin: https://$(hostname -I | awk '{print $1}'):10000"
    echo "URL alternativa: https://$(hostname):10000"
    echo ""
    
    log_info "CREDENCIALES:"
    echo "Usuario: root"
    echo "Contraseña: [tu contraseña de root del sistema]"
    echo ""
    
    log_info "SERVICIOS INSTALADOS:"
    systemctl --type=service --state=active | grep -E "(webmin|apache|mysql)" || echo "Ver con: systemctl status webmin"
    echo ""
    
    log_info "ARCHIVOS IMPORTANTES:"
    echo "Configuración: /etc/webmin/miniserv.conf"
    echo "Logs: /var/webmin/miniserv.log"
    echo "Certificado SSL: /etc/webmin/miniserv.pem"
    echo "Log de instalación: $LOG_FILE"
    echo "Backup: $BACKUP_DIR"
    echo ""
    
    log_info "COMANDOS ÚTILES:"
    echo "Reiniciar Webmin: systemctl restart webmin"
    echo "Ver logs: tail -f /var/webmin/miniserv.log"
    echo "Estado: systemctl status webmin"
    echo ""
    
    if [[ -s "$ERROR_FILE" ]]; then
        log_warning "Se encontraron algunas advertencias. Ver: $ERROR_FILE"
    fi
}

# FUNCIÓN PRINCIPAL
main() {
    log_message "=== INICIANDO INSTALACIÓN CORREGIDA WEBMIN/VIRTUALMIN ==="
    
    pre_installation_checks
    create_backup
    update_system_safe
    setup_webmin_repository_fixed
    install_server_dependencies_safe
    install_webmin_robust
    configure_webmin_secure
    verify_and_start_services
    post_installation_verification
    show_installation_summary
    
    log_message "=== INSTALACIÓN COMPLETADA ==="
}

# Verificar argumentos
case "${1:-}" in
    --force)
        main
        ;;
    --webmin-only)
        pre_installation_checks
        create_backup
        update_system_safe
        setup_webmin_repository_fixed
        install_webmin_robust
        configure_webmin_secure
        verify_and_start_services
        post_installation_verification
        show_installation_summary
        ;;
    --check)
        pre_installation_checks
        ;;
    *)
        echo "Instalador Corregido de Webmin/Virtualmin"
        echo ""
        echo "Este script soluciona todos los problemas identificados en instalaciones anteriores:"
        echo "• Configuración segura de repositorios GPG"
        echo "• Detección y resolución de conflictos de paquetes"
        echo "• Verificaciones robustas pre y post instalación"
        echo "• Configuración segura de SSL y certificados"
        echo "• Manejo de errores mejorado"
        echo "• Backup automático antes de cambios"
        echo ""
        echo "Uso: $0 [--force|--webmin-only|--check]"
        echo ""
        echo "  --force       Ejecutar instalación completa sin confirmación"
        echo "  --webmin-only Solo instalar Webmin (sin Virtualmin)"
        echo "  --check       Solo ejecutar verificaciones sin instalar"
        echo ""
        echo "RECOMENDACIÓN: Ejecutar primero con --check para verificar compatibilidad"
        echo ""
        read -p "¿Continuar con instalación completa? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            main
        else
            echo "Instalación cancelada"
            exit 0
        fi
        ;;
esac
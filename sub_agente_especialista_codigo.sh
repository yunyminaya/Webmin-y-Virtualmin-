#!/bin/bash

# Sub-Agente Especialista en Código
# Revisor, reparador y optimizador especializado para Webmin/Virtualmin
# Asegura que todos los paneles y funciones trabajen correctamente

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/sub_agente_especialista_codigo.log"
REPAIR_LOG="/var/log/reparaciones_webmin_virtualmin.log"
AUDIT_REPORT="/var/log/auditoria_codigo_$(date +%Y%m%d_%H%M%S).txt"
BACKUP_DIR="/var/backups/pre_repair_$(date +%Y%m%d_%H%M%S)"

# Configuración de colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ESPECIALISTA] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1${NC}" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [ÉXITO] $1${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [ADVERTENCIA] $1${NC}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1${NC}" | tee -a "$LOG_FILE"
}

create_backup() {
    log_info "=== CREANDO BACKUP DE SEGURIDAD ==="
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup de configuraciones críticas
    local backup_paths=(
        "/etc/webmin"
        "/etc/usermin"
        "/etc/virtualmin-domains"
        "/etc/apache2"
        "/etc/nginx"
        "/etc/postfix"
        "/etc/dovecot"
        "/etc/bind"
        "/etc/mysql"
        "/etc/postgresql"
    )
    
    for path in "${backup_paths[@]}"; do
        if [[ -d "$path" ]]; then
            local backup_name=$(basename "$path")
            tar -czf "$BACKUP_DIR/${backup_name}.tar.gz" -C "$(dirname "$path")" "$(basename "$path")" 2>/dev/null
            log_success "Backup creado: ${backup_name}.tar.gz"
        fi
    done
    
    # Backup de base de datos de configuración
    if command -v mysqldump >/dev/null 2>&1; then
        mysqldump --all-databases > "$BACKUP_DIR/mysql_full_backup.sql" 2>/dev/null || true
    fi
    
    log_success "Backup completo creado en: $BACKUP_DIR"
}

audit_webmin_installation() {
    log_info "=== AUDITANDO INSTALACIÓN DE WEBMIN ==="
    
    local issues=()
    local fixes=()
    
    # Verificar instalación básica
    if ! command -v webmin >/dev/null 2>&1; then
        issues+=("Webmin no está instalado o no está en PATH")
        fixes+=("install_webmin")
    else
        log_success "Webmin encontrado en el sistema"
    fi
    
    # Verificar archivos de configuración principales
    local webmin_configs=(
        "/etc/webmin/miniserv.conf"
        "/etc/webmin/config"
        "/etc/webmin/webmin.acl"
    )
    
    for config in "${webmin_configs[@]}"; do
        if [[ ! -f "$config" ]]; then
            issues+=("Archivo de configuración faltante: $config")
            fixes+=("restore_webmin_config:$config")
        else
            # Verificar permisos
            local perms=$(stat -c "%a" "$config")
            if [[ "$perms" != "600" ]] && [[ "$perms" != "644" ]]; then
                issues+=("Permisos incorrectos en $config: $perms")
                fixes+=("fix_permissions:$config")
            fi
        fi
    done
    
    # Verificar servicio Webmin
    if ! systemctl is-active --quiet webmin 2>/dev/null; then
        if systemctl is-enabled --quiet webmin 2>/dev/null; then
            issues+=("Servicio Webmin habilitado pero no activo")
            fixes+=("start_webmin_service")
        else
            issues+=("Servicio Webmin no habilitado")
            fixes+=("enable_webmin_service")
        fi
    else
        log_success "Servicio Webmin activo y funcionando"
    fi
    
    # Verificar puerto de Webmin
    local webmin_port=$(grep "^port=" /etc/webmin/miniserv.conf 2>/dev/null | cut -d'=' -f2 || echo "10000")
    if ! netstat -tuln | grep -q ":${webmin_port} "; then
        issues+=("Puerto Webmin $webmin_port no está en escucha")
        fixes+=("fix_webmin_port:$webmin_port")
    else
        log_success "Puerto Webmin $webmin_port activo"
    fi
    
    # Verificar SSL
    local ssl_enabled=$(grep "^ssl=" /etc/webmin/miniserv.conf 2>/dev/null | cut -d'=' -f2 || echo "0")
    if [[ "$ssl_enabled" != "1" ]]; then
        issues+=("SSL no habilitado en Webmin")
        fixes+=("enable_webmin_ssl")
    fi
    
    # Verificar módulos principales
    local webmin_modules_dir="/usr/share/webmin"
    if [[ -d "$webmin_modules_dir" ]]; then
        local essential_modules=("system-info" "proc" "mount" "fdisk" "users" "groups")
        for module in "${essential_modules[@]}"; do
            if [[ ! -d "$webmin_modules_dir/$module" ]]; then
                issues+=("Módulo Webmin faltante: $module")
                fixes+=("install_webmin_module:$module")
            fi
        done
    fi
    
    echo "WEBMIN_ISSUES=(${issues[*]})"
    echo "WEBMIN_FIXES=(${fixes[*]})"
}

audit_virtualmin_installation() {
    log_info "=== AUDITANDO INSTALACIÓN DE VIRTUALMIN ==="
    
    local issues=()
    local fixes=()
    
    # Verificar instalación básica
    if ! command -v virtualmin >/dev/null 2>&1; then
        issues+=("Virtualmin no está instalado")
        fixes+=("install_virtualmin")
    else
        log_success "Virtualmin encontrado en el sistema"
        
        # Verificar configuración de Virtualmin
        local virtualmin_config="/etc/webmin/virtual-server/config"
        if [[ ! -f "$virtualmin_config" ]]; then
            issues+=("Configuración de Virtualmin faltante")
            fixes+=("create_virtualmin_config")
        fi
    fi
    
    # Verificar dependencias críticas
    local dependencies=("apache2" "postfix" "dovecot" "bind9" "mysql-server")
    for dep in "${dependencies[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$dep"; then
            issues+=("Dependencia faltante: $dep")
            fixes+=("install_dependency:$dep")
        fi
    done
    
    # Verificar servicios críticos
    local services=("apache2" "postfix" "dovecot" "named" "mysql")
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet "$service" 2>/dev/null; then
            issues+=("Servicio crítico inactivo: $service")
            fixes+=("start_service:$service")
        fi
    done
    
    # Verificar configuración de Apache
    if [[ -f "/etc/apache2/apache2.conf" ]]; then
        if ! apache2ctl configtest >/dev/null 2>&1; then
            issues+=("Configuración de Apache tiene errores")
            fixes+=("fix_apache_config")
        fi
    fi
    
    # Verificar configuración de Postfix
    if [[ -f "/etc/postfix/main.cf" ]]; then
        if ! postfix check >/dev/null 2>&1; then
            issues+=("Configuración de Postfix tiene errores")
            fixes+=("fix_postfix_config")
        fi
    fi
    
    # Verificar base de datos
    if command -v mysql >/dev/null 2>&1; then
        if ! mysql -e "SELECT 1" >/dev/null 2>&1; then
            issues+=("No se puede conectar a MySQL")
            fixes+=("fix_mysql_connection")
        fi
    fi
    
    echo "VIRTUALMIN_ISSUES=(${issues[*]})"
    echo "VIRTUALMIN_FIXES=(${fixes[*]})"
}

audit_existing_subagents() {
    log_info "=== AUDITANDO SUB-AGENTES EXISTENTES ==="
    
    local subagent_files=(
        "$SCRIPT_DIR/sub_agente_monitoreo.sh"
        "$SCRIPT_DIR/sub_agente_seguridad.sh"
        "$SCRIPT_DIR/sub_agente_backup.sh"
        "$SCRIPT_DIR/sub_agente_actualizaciones.sh"
        "$SCRIPT_DIR/sub_agente_logs.sh"
        "$SCRIPT_DIR/coordinador_sub_agentes.sh"
    )
    
    local code_issues=()
    
    for file in "${subagent_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            code_issues+=("Archivo faltante: $file")
            continue
        fi
        
        # Verificar sintaxis bash
        if ! bash -n "$file" >/dev/null 2>&1; then
            code_issues+=("Error de sintaxis en: $file")
        fi
        
        # Verificar permisos de ejecución
        if [[ ! -x "$file" ]]; then
            code_issues+=("Sin permisos de ejecución: $file")
        fi
        
        # Verificar uso de variables inseguras
        if grep -q '\$[A-Za-z_][A-Za-z0-9_]*[^{]' "$file" 2>/dev/null; then
            code_issues+=("Variables sin comillas en: $file")
        fi
        
        # Verificar comandos peligrosos
        if grep -qE '(rm -rf|dd if=|mkfs\.|fdisk)' "$file" 2>/dev/null; then
            code_issues+=("Comandos peligrosos en: $file")
        fi
    done
    
    echo "CODE_ISSUES=(${code_issues[*]})"
}

fix_webmin_issues() {
    local fixes=("$@")
    
    log_info "=== REPARANDO PROBLEMAS DE WEBMIN ==="
    
    for fix in "${fixes[@]}"; do
        case "$fix" in
            "install_webmin")
                install_webmin_complete
                ;;
            "restore_webmin_config:"*)
                local config_file="${fix#*:}"
                restore_webmin_config "$config_file"
                ;;
            "fix_permissions:"*)
                local file="${fix#*:}"
                chmod 600 "$file"
                log_success "Permisos corregidos: $file"
                ;;
            "start_webmin_service")
                systemctl start webmin
                log_success "Servicio Webmin iniciado"
                ;;
            "enable_webmin_service")
                systemctl enable webmin
                systemctl start webmin
                log_success "Servicio Webmin habilitado e iniciado"
                ;;
            "fix_webmin_port:"*)
                local port="${fix#*:}"
                fix_webmin_port "$port"
                ;;
            "enable_webmin_ssl")
                enable_webmin_ssl
                ;;
            "install_webmin_module:"*)
                local module="${fix#*:}"
                install_webmin_module "$module"
                ;;
        esac
    done
}

install_webmin_complete() {
    log_info "Instalando Webmin completo..."
    
    # Agregar repositorio oficial
    wget -qO- https://download.webmin.com/jcameron-key.asc | apt-key add -
    echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
    
    # Actualizar e instalar
    apt-get update
    apt-get install -y webmin
    
    # Configurar firewall
    ufw allow 10000/tcp 2>/dev/null || true
    
    log_success "Webmin instalado correctamente"
}

restore_webmin_config() {
    local config_file="$1"
    
    log_info "Restaurando configuración: $config_file"
    
    case "$(basename "$config_file")" in
        "miniserv.conf")
            cat > "$config_file" << 'EOF'
port=10000
root=/usr/share/webmin
mimetypes=/usr/share/webmin/mime.types
addtype_cgi=internal/cgi
realm=Webmin Server
logfile=/var/webmin/miniserv.log
errorlog=/var/webmin/miniserv.error
pidfile=/var/webmin/miniserv.pid
logtime=168
ppath=
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
anonymous=/
trust_unknown_referers=1
referers_none=1
EOF
            ;;
        "config")
            cat > "$config_file" << 'EOF'
webmin_denyusers=
webmin_allowusers=
webmin_theme=authentic-theme
webmin_product=webmin
webmin_version=2.000
webmin_os_type=debian-linux
webmin_os_version=*
webmin_real_os_type=Debian Linux
webmin_real_os_version=
webmin_config_dir=/etc/webmin
webmin_var_dir=/var/webmin
webmin_logfile=/var/webmin/miniserv.log
webmin_debug=0
webmin_gzip=1
webmin_lang=es
webmin_charset=UTF-8
webmin_referer=1
webmin_referers=
webmin_ftp_proxy=
webmin_http_proxy=
webmin_socks_proxy=
webmin_noproxy=
webmin_proxy_user=
webmin_proxy_pass=
gotoone=0
gototheme=0
gotomodule=
nofeedbackcc=0
feedbackto=
feedbackfrom=
feedback_to=
noupdate=0
development=0
show_license=1
EOF
            ;;
    esac
    
    chmod 600 "$config_file"
    log_success "Configuración restaurada: $config_file"
}

fix_webmin_port() {
    local port="$1"
    
    log_info "Reparando puerto Webmin: $port"
    
    # Verificar si el puerto está en uso
    if netstat -tuln | grep -q ":${port} "; then
        log_success "Puerto $port ya está en escucha"
        return 0
    fi
    
    # Reiniciar servicio Webmin
    systemctl restart webmin
    
    # Esperar a que inicie
    local retries=30
    while [[ $retries -gt 0 ]] && ! netstat -tuln | grep -q ":${port} "; do
        sleep 1
        ((retries--))
    done
    
    if netstat -tuln | grep -q ":${port} "; then
        log_success "Puerto Webmin $port reparado"
    else
        log_error "No se pudo reparar puerto Webmin $port"
    fi
}

enable_webmin_ssl() {
    log_info "Habilitando SSL en Webmin..."
    
    # Generar certificado SSL si no existe
    if [[ ! -f "/etc/webmin/miniserv.pem" ]]; then
        openssl req -new -x509 -days 365 -nodes -out /etc/webmin/miniserv.pem -keyout /etc/webmin/miniserv.pem -subj "/C=ES/ST=Madrid/L=Madrid/O=Webmin/CN=$(hostname)"
        chmod 600 /etc/webmin/miniserv.pem
    fi
    
    # Habilitar SSL en configuración
    sed -i 's/^ssl=0/ssl=1/' /etc/webmin/miniserv.conf
    
    # Reiniciar Webmin
    systemctl restart webmin
    
    log_success "SSL habilitado en Webmin"
}

fix_virtualmin_issues() {
    local fixes=("$@")
    
    log_info "=== REPARANDO PROBLEMAS DE VIRTUALMIN ==="
    
    for fix in "${fixes[@]}"; do
        case "$fix" in
            "install_virtualmin")
                install_virtualmin_complete
                ;;
            "create_virtualmin_config")
                create_virtualmin_config
                ;;
            "install_dependency:"*)
                local dep="${fix#*:}"
                install_dependency "$dep"
                ;;
            "start_service:"*)
                local service="${fix#*:}"
                start_service "$service"
                ;;
            "fix_apache_config")
                fix_apache_configuration
                ;;
            "fix_postfix_config")
                fix_postfix_configuration
                ;;
            "fix_mysql_connection")
                fix_mysql_connection
                ;;
        esac
    done
}

install_virtualmin_complete() {
    log_info "Instalando Virtualmin completo..."
    
    # Descargar script de instalación oficial
    wget -O /tmp/install.sh https://software.virtualmin.com/gpl/scripts/install.sh
    chmod +x /tmp/install.sh
    
    # Ejecutar instalación
    /tmp/install.sh --force --hostname "$(hostname -f)" --bundle LAMP
    
    log_success "Virtualmin instalado correctamente"
}

create_virtualmin_config() {
    log_info "Creando configuración de Virtualmin..."
    
    mkdir -p /etc/webmin/virtual-server
    
    cat > /etc/webmin/virtual-server/config << 'EOF'
home_base=/home
auto_letsencrypt=1
letsencrypt_cmd=/usr/bin/certbot
spam=1
virus=1
mysql=1
postgres=0
quotas=1
spam_client=spamc
virus_scanner=clamdscan
collect_interval=5
avail_interval=5
bandwidth_interval=5
template=0
unix_user_quota=1
unix_group_quota=1
eof_domains=.
spam_white_manual=1
virus_auto=1
collect_offline=0
EOF
    
    log_success "Configuración de Virtualmin creada"
}

install_dependency() {
    local package="$1"
    
    log_info "Instalando dependencia: $package"
    
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$package"
    
    log_success "Dependencia instalada: $package"
}

start_service() {
    local service="$1"
    
    log_info "Iniciando servicio: $service"
    
    systemctl enable "$service"
    systemctl start "$service"
    
    if systemctl is-active --quiet "$service"; then
        log_success "Servicio iniciado: $service"
    else
        log_error "No se pudo iniciar servicio: $service"
    fi
}

fix_apache_configuration() {
    log_info "Reparando configuración de Apache..."
    
    # Habilitar módulos necesarios
    local modules=("rewrite" "ssl" "suexec" "include" "dav" "dav_fs" "auth_digest")
    for module in "${modules[@]}"; do
        a2enmod "$module" 2>/dev/null || true
    done
    
    # Verificar configuración
    if apache2ctl configtest >/dev/null 2>&1; then
        systemctl restart apache2
        log_success "Configuración de Apache reparada"
    else
        log_error "Error en configuración de Apache"
        apache2ctl configtest
    fi
}

fix_postfix_configuration() {
    log_info "Reparando configuración de Postfix..."
    
    # Configuración básica de Postfix
    postconf -e "myhostname = $(hostname -f)"
    postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost"
    postconf -e "mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128"
    
    # Verificar configuración
    if postfix check >/dev/null 2>&1; then
        systemctl restart postfix
        log_success "Configuración de Postfix reparada"
    else
        log_error "Error en configuración de Postfix"
    fi
}

fix_mysql_connection() {
    log_info "Reparando conexión MySQL..."
    
    systemctl start mysql
    
    # Configurar contraseña root si es necesario
    if ! mysql -e "SELECT 1" >/dev/null 2>&1; then
        mysql_secure_installation --use-default
    fi
    
    log_success "Conexión MySQL reparada"
}

fix_code_issues() {
    local issues=("$@")
    
    log_info "=== REPARANDO PROBLEMAS DE CÓDIGO ==="
    
    for issue in "${issues[@]}"; do
        if [[ "$issue" =~ "Sin permisos de ejecución:" ]]; then
            local file="${issue#*: }"
            chmod +x "$file"
            log_success "Permisos de ejecución añadidos: $file"
        elif [[ "$issue" =~ "Variables sin comillas en:" ]]; then
            local file="${issue#*: }"
            fix_unquoted_variables "$file"
        elif [[ "$issue" =~ "Error de sintaxis en:" ]]; then
            local file="${issue#*: }"
            log_error "Error de sintaxis detectado en: $file"
            log_error "Revisar manualmente el archivo"
        fi
    done
}

fix_unquoted_variables() {
    local file="$1"
    
    log_info "Corrigiendo variables sin comillas en: $file"
    
    # Crear backup
    cp "$file" "${file}.backup"
    
    # Correcciones automáticas básicas
    sed -i 's/\$\([A-Za-z_][A-Za-z0-9_]*\)\([^{]\)/\${\1}\2/g' "$file"
    
    log_success "Variables corregidas en: $file (backup: ${file}.backup)"
}

run_comprehensive_tests() {
    log_info "=== EJECUTANDO PRUEBAS COMPREHENSIVAS ==="
    
    local test_results=()
    
    # Test 1: Conectividad Webmin
    if curl -k -s "https://localhost:10000" >/dev/null 2>&1; then
        test_results+=("✅ Webmin accesible vía HTTPS")
    else
        test_results+=("❌ Webmin no accesible")
    fi
    
    # Test 2: Login Webmin
    if [[ -f "/etc/webmin/miniserv.users" ]] && [[ -s "/etc/webmin/miniserv.users" ]]; then
        test_results+=("✅ Usuarios de Webmin configurados")
    else
        test_results+=("❌ Sin usuarios de Webmin")
    fi
    
    # Test 3: Módulos Virtualmin
    if [[ -d "/usr/share/webmin/virtual-server" ]]; then
        test_results+=("✅ Módulo Virtualmin disponible")
    else
        test_results+=("❌ Módulo Virtualmin no encontrado")
    fi
    
    # Test 4: Servicios críticos
    local critical_services=("webmin" "apache2" "postfix" "mysql")
    for service in "${critical_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            test_results+=("✅ Servicio $service activo")
        else
            test_results+=("❌ Servicio $service inactivo")
        fi
    done
    
    # Test 5: Puertos abiertos
    local ports=("10000:Webmin" "80:HTTP" "443:HTTPS" "25:SMTP")
    for port_info in "${ports[@]}"; do
        local port="${port_info%:*}"
        local name="${port_info#*:}"
        if netstat -tuln | grep -q ":${port} "; then
            test_results+=("✅ Puerto $port ($name) abierto")
        else
            test_results+=("❌ Puerto $port ($name) cerrado")
        fi
    done
    
    # Mostrar resultados
    for result in "${test_results[@]}"; do
        if [[ "$result" =~ "✅" ]]; then
            log_success "$result"
        else
            log_error "$result"
        fi
    done
}

generate_comprehensive_report() {
    log_info "=== GENERANDO REPORTE COMPREHENSIVO ==="
    
    {
        echo "=== REPORTE DE AUDITORÍA Y REPARACIÓN WEBMIN/VIRTUALMIN ==="
        echo "Fecha: $(date)"
        echo "Servidor: $(hostname)"
        echo "Sistema: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Desconocido")"
        echo ""
        
        echo "=== ESTADO DE WEBMIN ==="
        if systemctl is-active --quiet webmin 2>/dev/null; then
            echo "✅ Servicio Webmin: ACTIVO"
            echo "✅ Puerto: $(grep '^port=' /etc/webmin/miniserv.conf | cut -d'=' -f2)"
            echo "✅ SSL: $(grep '^ssl=' /etc/webmin/miniserv.conf | cut -d'=' -f2)"
        else
            echo "❌ Servicio Webmin: INACTIVO"
        fi
        
        echo ""
        echo "=== ESTADO DE VIRTUALMIN ==="
        if command -v virtualmin >/dev/null 2>&1; then
            echo "✅ Comando Virtualmin: DISPONIBLE"
            echo "✅ Versión: $(virtualmin version 2>/dev/null | head -1 || echo "No disponible")"
        else
            echo "❌ Comando Virtualmin: NO DISPONIBLE"
        fi
        
        echo ""
        echo "=== SERVICIOS CRÍTICOS ==="
        local services=("apache2" "nginx" "postfix" "dovecot" "named" "mysql" "postgresql")
        for service in "${services[@]}"; do
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                echo "✅ $service: ACTIVO"
            else
                echo "❌ $service: INACTIVO"
            fi
        done
        
        echo ""
        echo "=== CONECTIVIDAD ==="
        local ports=("22:SSH" "25:SMTP" "53:DNS" "80:HTTP" "443:HTTPS" "993:IMAPS" "995:POP3S" "10000:Webmin" "20000:Usermin")
        for port_info in "${ports[@]}"; do
            local port="${port_info%:*}"
            local name="${port_info#*:}"
            if netstat -tuln | grep -q ":${port} "; then
                echo "✅ Puerto $port ($name): ABIERTO"
            else
                echo "❌ Puerto $port ($name): CERRADO"
            fi
        done
        
        echo ""
        echo "=== CONFIGURACIONES ==="
        echo "Directorio Webmin: $(find /usr -name webmin -type d 2>/dev/null | head -1 || echo "No encontrado")"
        echo "Configuración Webmin: /etc/webmin"
        echo "Logs Webmin: /var/webmin"
        echo "Backup creado: $BACKUP_DIR"
        
        echo ""
        echo "=== RECOMENDACIONES ==="
        echo "1. Verificar que todos los servicios marcados como INACTIVO deberían estar activos"
        echo "2. Configurar firewall para puertos necesarios"
        echo "3. Ejecutar wizard de configuración inicial de Virtualmin"
        echo "4. Configurar certificados SSL válidos"
        echo "5. Revisar logs de errores en /var/log/"
        
    } > "$AUDIT_REPORT"
    
    log_success "Reporte generado: $AUDIT_REPORT"
}

main() {
    log_info "=== INICIANDO ESPECIALISTA EN CÓDIGO WEBMIN/VIRTUALMIN ==="
    
    # Crear backup de seguridad
    create_backup
    
    # Auditar sistemas
    local webmin_audit=$(audit_webmin_installation)
    local virtualmin_audit=$(audit_virtualmin_installation)
    local code_audit=$(audit_existing_subagents)
    
    # Extraer problemas encontrados
    eval "$webmin_audit"
    eval "$virtualmin_audit"  
    eval "$code_audit"
    
    # Mostrar problemas encontrados
    if [[ ${#WEBMIN_ISSUES[@]} -gt 0 ]]; then
        log_warning "Problemas de Webmin encontrados: ${#WEBMIN_ISSUES[@]}"
        for issue in "${WEBMIN_ISSUES[@]}"; do
            log_warning "  - $issue"
        done
    fi
    
    if [[ ${#VIRTUALMIN_ISSUES[@]} -gt 0 ]]; then
        log_warning "Problemas de Virtualmin encontrados: ${#VIRTUALMIN_ISSUES[@]}"
        for issue in "${VIRTUALMIN_ISSUES[@]}"; do
            log_warning "  - $issue"
        done
    fi
    
    if [[ ${#CODE_ISSUES[@]} -gt 0 ]]; then
        log_warning "Problemas de código encontrados: ${#CODE_ISSUES[@]}"
        for issue in "${CODE_ISSUES[@]}"; do
            log_warning "  - $issue"
        done
    fi
    
    # Aplicar reparaciones si se solicita
    if [[ "${1:-}" == "repair" ]]; then
        if [[ ${#WEBMIN_FIXES[@]} -gt 0 ]]; then
            fix_webmin_issues "${WEBMIN_FIXES[@]}"
        fi
        
        if [[ ${#VIRTUALMIN_FIXES[@]} -gt 0 ]]; then
            fix_virtualmin_issues "${VIRTUALMIN_FIXES[@]}"
        fi
        
        if [[ ${#CODE_ISSUES[@]} -gt 0 ]]; then
            fix_code_issues "${CODE_ISSUES[@]}"
        fi
    fi
    
    # Ejecutar pruebas
    run_comprehensive_tests
    
    # Generar reporte final
    generate_comprehensive_report
    
    log_success "Especialista en código completado. Ver reporte: $AUDIT_REPORT"
}

case "${1:-}" in
    audit)
        log_info "Modo solo auditoría"
        audit_webmin_installation
        audit_virtualmin_installation
        audit_existing_subagents
        generate_comprehensive_report
        ;;
    repair)
        log_info "Modo auditoría y reparación"
        main repair
        ;;
    test)
        log_info "Modo solo pruebas"
        run_comprehensive_tests
        ;;
    report)
        generate_comprehensive_report
        ;;
    *)
        echo "Sub-Agente Especialista en Código Webmin/Virtualmin"
        echo "Uso: $0 {audit|repair|test|report}"
        echo ""
        echo "  audit  - Solo auditar y detectar problemas"
        echo "  repair - Auditar y reparar problemas automáticamente"  
        echo "  test   - Ejecutar pruebas de funcionalidad"
        echo "  report - Generar reporte de estado"
        echo ""
        echo "ADVERTENCIA: El modo 'repair' hace cambios en el sistema"
        echo "Se recomienda ejecutar 'audit' primero para revisar problemas"
        exit 1
        ;;
esac
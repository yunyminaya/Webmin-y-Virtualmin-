#!/bin/bash

# Script de instalación y configuración de ModSecurity WAF para Virtualmin Enterprise
# Este script instala y configura ModSecurity con reglas OWASP

set -e

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de configuración
MODSECURITY_VERSION="2.9.7"
OWASP_CRS_VERSION="3.3.2"
INSTALL_DIR="/opt/virtualmin-enterprise"
LOG_FILE="/var/log/virtualmin-enterprise-modsecurity.log"
MODSECURITY_DIR="/etc/modsecurity"
OWASP_CRS_DIR="/etc/modsecurity/crs"

# Función para imprimir mensajes con colores
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Función para registrar mensajes en el log
log_message() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Función para verificar si el script se ejecuta como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_message $RED "Este script debe ejecutarse como root" >&2
        exit 1
    fi
}

# Función para detectar distribución del sistema operativo
detect_distribution() {
    if [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "redhat"
    else
        echo "unknown"
    fi
}

# Función para detectar servidor web
detect_web_server() {
    if systemctl is-active --quiet apache2; then
        echo "apache"
    elif systemctl is-active --quiet nginx; then
        echo "nginx"
    elif systemctl is-active --quiet httpd; then
        echo "apache"
    else
        echo "unknown"
    fi
}

# Función para instalar dependencias
install_dependencies() {
    log_message "Instalando dependencias"
    
    local distribution=$(detect_distribution)
    
    case $distribution in
        "debian")
            apt-get update
            apt-get install -y \
                build-essential \
                libxml2-dev \
                libpcre3-dev \
                libyajl-dev \
                libgeoip-dev \
                libssl-dev \
                zlib1g-dev \
                libcurl4-openssl-dev \
                apache2-dev \
                libapache2-mod-modsecurity \
                git \
                wget \
                unzip
            ;;
        "redhat")
            yum update -y
            yum groupinstall -y "Development Tools"
            yum install -y \
                libxml2-devel \
                pcre-devel \
                yajl-devel \
                GeoIP-devel \
                openssl-devel \
                zlib-devel \
                libcurl-devel \
                httpd-devel \
                mod_security \
                git \
                wget \
                unzip
            ;;
        *)
            print_message $RED "Distribución no soportada"
            exit 1
            ;;
    esac
    
    log_message "Dependencias instaladas"
}

# Función para instalar ModSecurity
install_modsecurity() {
    log_message "Instalando ModSecurity"
    
    local distribution=$(detect_distribution)
    
    case $distribution in
        "debian")
            # ModSecurity ya se instaló como dependencia
            log_message "ModSecurity instalado desde repositorios"
            ;;
        "redhat")
            # ModSecurity ya se instaló como dependencia
            log_message "ModSecurity instalado desde repositorios"
            ;;
    esac
    
    # Verificar instalación
    if [ -f "/etc/modsecurity/modsecurity.conf-recommended" ] || [ -f "/etc/modsecurity/modsecurity.conf" ]; then
        log_message "ModSecurity instalado correctamente"
        print_message $GREEN "ModSecurity instalado correctamente"
    else
        log_message "ERROR: Falló la instalación de ModSecurity"
        print_message $RED "ERROR: Falló la instalación de ModSecurity"
        exit 1
    fi
}

# Función para configurar ModSecurity
configure_modsecurity() {
    log_message "Configurando ModSecurity"
    
    # Crear directorio de configuración si no existe
    mkdir -p "$MODSECURITY_DIR"
    
    # Copiar archivo de configuración recomendado
    if [ -f "/etc/modsecurity/modsecurity.conf-recommended" ]; then
        cp "/etc/modsecurity/modsecurity.conf-recommended" "$MODSECURITY_DIR/modsecurity.conf"
    elif [ -f "/etc/modsecurity/modsecurity.conf" ]; then
        cp "/etc/modsecurity/modsecurity.conf" "$MODSECURITY_DIR/modsecurity.conf"
    else
        log_message "ERROR: No se encontró archivo de configuración de ModSecurity"
        print_message $RED "ERROR: No se encontró archivo de configuración de ModSecurity"
        exit 1
    fi
    
    # Configurar ModSecurity
    sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' "$MODSECURITY_DIR/modsecurity.conf"
    sed -i 's/SecRequestBodyAccess Off/SecRequestBodyAccess On/' "$MODSECURITY_DIR/modsecurity.conf"
    sed -i 's/SecResponseBodyAccess Off/SecResponseBodyAccess On/' "$MODSECURITY_DIR/modsecurity.conf"
    
    # Configurar directorio de logs
    sed -i "s|SecAuditLog /var/log/modsec_audit.log|SecAuditLog $INSTALL_DIR/logs/modsec_audit.log|" "$MODSECURITY_DIR/modsecurity.conf"
    
    # Crear directorio de logs
    mkdir -p "$INSTALL_DIR/logs"
    
    # Configurar formato de logs
    cat >> "$MODSECURITY_DIR/modsecurity.conf" << 'EOF'

# Configuración adicional para Virtualmin Enterprise

# Habilitar colección de datos de auditoría
SecAuditEngine RelevantOnly
SecAuditLogRelevantStatus "^(?:5|4(?!04))"
SecAuditLogParts ABIJDEFHZ
SecAuditLogType Serial
SecAuditLog /opt/virtualmin-enterprise/logs/modsec_audit.log

# Configurar directorio de datos
SecDataDir /opt/virtualmin-enterprise/data/modsecurity

# Habilitar detección de anomalías
SecRuleEngine On
SecRequestBodyAccess On
SecResponseBodyAccess On
SecRequestBodyLimit 13107200
SecRequestBodyNoFilesLimit 131072
SecRequestBodyInMemoryLimit 131072
SecRequestBodyLimitAction Reject

# Configurar reglas de seguridad básicas
SecRule REQUEST_HEADERS:User-Agent "^(.*)$" "id:100000,phase:1,log,pass,t:none,t:lowercase,capture,setvar:tx.ua=%{matched.1}"
SecRule REQUEST_HEADERS:Referer "^(.*)$" "id:100001,phase:1,log,pass,t:none,t:lowercase,capture,setvar:tx.referer=%{matched.1}"

# Protección contra ataques comunes
SecRule ARGS "@detectSQLi" \
    "id:100002,phase:2,block,msg:'SQL Injection Attack Detected',logdata:'Matched Data: %{MATCHED_VAR} found within %{MATCHED_VAR_NAME}',tag:'application-multi',tag:'language-multi',tag:'platform-multi',tag:'attack-sqli'"

SecRule ARGS "@detectXSS" \
    "id:100003,phase:2,block,msg:'XSS Attack Detected',logdata:'Matched Data: %{MATCHED_VAR} found within %{MATCHED_VAR_NAME}',tag:'application-multi',tag:'language-multi',tag:'platform-multi',tag:'attack-xss'"

# Protección contra inyección de código
SecRule ARGS "@detectCommandInjection" \
    "id:100004,phase:2,block,msg:'Command Injection Attack Detected',logdata:'Matched Data: %{MATCHED_VAR} found within %{MATCHED_VAR_NAME}',tag:'application-multi',tag:'language-multi',tag:'platform-multi',tag:'attack-injection'"

EOF
    
    # Crear directorio de datos
    mkdir -p "$INSTALL_DIR/data/modsecurity"
    
    log_message "ModSecurity configurado"
    print_message $GREEN "ModSecurity configurado"
}

# Función para descargar e instalar OWASP CRS
install_owasp_crs() {
    log_message "Instalando OWASP CRS"
    
    # Crear directorio para CRS
    mkdir -p "$OWASP_CRS_DIR"
    
    # Descargar OWASP CRS
    cd /tmp
    wget -q "https://github.com/coreruleset/coreruleset/archive/v$OWASP_CRS_VERSION.tar.gz"
    tar -xzf "v$OWASP_CRS_VERSION.tar.gz"
    
    # Copiar archivos de CRS
    cp -r "coreruleset-$OWASP_CRS_VERSION/rules" "$OWASP_CRS_DIR/"
    cp -r "coreruleset-$OWASP_CRS_VERSION/util" "$OWASP_CRS_DIR/"
    
    # Configurar CRS
    cp "$OWASP_CRS_DIR/rules/crs-setup.conf.example" "$OWASP_CRS_DIR/crs-setup.conf"
    
    # Configurar CRS
    sed -i 's/SecDefaultAction "phase:1,log,auditlog,pass"/SecDefaultAction "phase:1,log,auditlog,pass,t:none,t:lowercase"/' "$OWASP_CRS_DIR/crs-setup.conf"
    sed -i 's/# SecAction "id:900000, phase:1, nolog, pass, t:none, setvar:tx.critical_anomaly_score=5"/SecAction "id:900000, phase:1, nolog, pass, t:none, setvar:tx.critical_anomaly_score=5"/' "$OWASP_CRS_DIR/crs-setup.conf"
    sed -i 's/# SecAction "id:900001, phase:1, nolog, pass, t:none, setvar:tx.error_anomaly_score=4"/SecAction "id:900001, phase:1, nolog, pass, t:none, setvar:tx.error_anomaly_score=4"/' "$OWASP_CRS_DIR/crs-setup.conf"
    sed -i 's/# SecAction "id:900002, phase:1, nolog, pass, t:none, setvar:tx.warning_anomaly_score=3"/SecAction "id:900002, phase:1, nolog, pass, t:none, setvar:tx.warning_anomaly_score=3"/' "$OWASP_CRS_DIR/crs-setup.conf"
    sed -i 's/# SecAction "id:900003, phase:1, nolog, pass, t:none, setvar:tx.notice_anomaly_score=2"/SecAction "id:900003, phase:1, nolog, pass, t:none, setvar:tx.notice_anomaly_score=2"/' "$OWASP_CRS_DIR/crs-setup.conf")
    
    # Limpiar archivos temporales
    rm -rf "v$OWASP_CRS_VERSION.tar.gz" "coreruleset-$OWASP_CRS_VERSION"
    
    log_message "OWASP CRS instalado"
    print_message $GREEN "OWASP CRS instalado"
}

# Función para integrar ModSecurity con Apache
integrate_with_apache() {
    log_message "Integrando ModSecurity con Apache"
    
    local distribution=$(detect_distribution)
    
    case $distribution in
        "debian")
            # Habilitar módulo ModSecurity
            a2enmod security2 >> "$LOG_FILE" 2>&1
            
            # Crear archivo de configuración para Apache
            cat > "/etc/apache2/conf-available/modsecurity.conf" << EOF
# Configuración de ModSecurity para Apache

<IfModule security2_module>
    # Incluir configuración de ModSecurity
    Include $MODSECURITY_DIR/modsecurity.conf
    
    # Incluir configuración de OWASP CRS
    Include $OWASP_CRS_DIR/crs-setup.conf
    Include $OWASP_CRS_DIR/rules/*.conf
    
    # Excluir reglas problemáticas para Virtualmin
    SecRuleRemoveById 949110  # Posible falso positivo con Virtualmin
    SecRuleRemoveById 980130  # Posible falso positivo con Virtualmin
</IfModule>
EOF
            
            # Habilitar configuración
            a2enconf modsecurity >> "$LOG_FILE" 2>&1
            
            # Reiniciar Apache
            systemctl restart apache2 >> "$LOG_FILE" 2>&1
            ;;
        "redhat")
            # Crear archivo de configuración para Apache
            cat > "/etc/httpd/conf.d/modsecurity.conf" << EOF
# Configuración de ModSecurity para Apache

<IfModule mod_security2.c>
    # Incluir configuración de ModSecurity
    Include $MODSECURITY_DIR/modsecurity.conf
    
    # Incluir configuración de OWASP CRS
    Include $OWASP_CRS_DIR/crs-setup.conf
    Include $OWASP_CRS_DIR/rules/*.conf
    
    # Excluir reglas problemáticas para Virtualmin
    SecRuleRemoveById 949110  # Posible falso positivo con Virtualmin
    SecRuleRemoveById 980130  # Posible falso positivo con Virtualmin
</IfModule>
EOF
            
            # Reiniciar Apache
            systemctl restart httpd >> "$LOG_FILE" 2>&1
            ;;
    esac
    
    log_message "ModSecurity integrado con Apache"
    print_message $GREEN "ModSecurity integrado con Apache"
}

# Función para integrar ModSecurity con Nginx
integrate_with_nginx() {
    log_message "Integrando ModSecurity con Nginx"
    
    # Verificar si ModSecurity para Nginx está disponible
    if ! dpkg -l | grep -q "nginx-mod-security" && ! rpm -qa | grep -q "nginx-mod-security"; then
        log_message "Instalando ModSecurity para Nginx"
        
        local distribution=$(detect_distribution)
        
        case $distribution in
            "debian")
                apt-get install -y nginx-mod-security >> "$LOG_FILE" 2>&1
                ;;
            "redhat")
                yum install -y nginx-mod-security >> "$LOG_FILE" 2>&1
                ;;
        esac
    fi
    
    # Crear archivo de configuración para Nginx
    cat > "/etc/nginx/modsecurity.conf" << EOF
# Configuración de ModSecurity para Nginx

# Incluir configuración de ModSecurity
Include $MODSECURITY_DIR/modsecurity.conf

# Incluir configuración de OWASP CRS
Include $OWASP_CRS_DIR/crs-setup.conf
Include $OWASP_CRS_DIR/rules/*.conf

# Excluir reglas problemáticas para Virtualmin
SecRuleRemoveById 949110  # Posible falso positivo con Virtualmin
SecRuleRemoveById 980130  # Posible falso positivo con Virtualmin
EOF
    
    # Modificar configuración principal de Nginx
    if [ -f "/etc/nginx/nginx.conf" ]; then
        # Añadir configuración de ModSecurity al bloque http
        sed -i '/http {/a\\n    # ModSecurity\n    modsecurity on;\n    modsecurity_rules_file /etc/nginx/modsecurity.conf;' "/etc/nginx/nginx.conf"
    fi
    
    # Reiniciar Nginx
    systemctl restart nginx >> "$LOG_FILE" 2>&1
    
    log_message "ModSecurity integrado con Nginx"
    print_message $GREEN "ModSecurity integrado con Nginx"
}

# Función para crear script de gestión de ModSecurity
create_management_script() {
    log_message "Creando script de gestión de ModSecurity"
    
    cat > "$INSTALL_DIR/scripts/manage_modsecurity.sh" << 'EOF'
#!/bin/bash

# Script de gestión de ModSecurity para Virtualmin Enterprise

MODSECURITY_DIR="/etc/modsecurity"
OWASP_CRS_DIR="/etc/modsecurity/crs"
LOG_FILE="/var/log/virtualmin-enterprise-modsecurity.log"

# Función para registrar mensajes
log_message() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Función para verificar estado de ModSecurity
check_status() {
    echo "Verificando estado de ModSecurity..."
    
    local web_server=$(detect_web_server)
    
    case $web_server in
        "apache")
            if apachectl -M | grep -q "security2_module"; then
                echo "✓ ModSecurity está habilitado en Apache"
            else
                echo "✗ ModSecurity no está habilitado en Apache"
            fi
            ;;
        "nginx")
            if nginx -V 2>&1 | grep -q "modsecurity"; then
                echo "✓ ModSecurity está habilitado en Nginx"
            else
                echo "✗ ModSecurity no está habilitado en Nginx"
            fi
            ;;
        *)
            echo "✗ No se pudo detectar el servidor web"
            ;;
    esac
    
    # Verificar estado del motor de reglas
    if grep -q "SecRuleEngine On" "$MODSECURITY_DIR/modsecurity.conf"; then
        echo "✓ Motor de reglas de ModSecurity está habilitado"
    else
        echo "✗ Motor de reglas de ModSecurity no está habilitado"
    fi
    
    # Verificar logs recientes
    local recent_logs=$(tail -n 10 "$INSTALL_DIR/logs/modsec_audit.log" 2>/dev/null | wc -l)
    echo "Logs recientes: $recent_logs"
}

# Función para habilitar ModSecurity
enable_modsecurity() {
    echo "Habilitando ModSecurity..."
    
    sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' "$MODSECURITY_DIR/modsecurity.conf"
    
    local web_server=$(detect_web_server)
    
    case $web_server in
        "apache")
            systemctl restart apache2 >> "$LOG_FILE" 2>&1
            ;;
        "nginx")
            systemctl restart nginx >> "$LOG_FILE" 2>&1
            ;;
    esac
    
    echo "ModSecurity habilitado"
    log_message "ModSecurity habilitado"
}

# Función para deshabilitar ModSecurity
disable_modsecurity() {
    echo "Deshabilitando ModSecurity..."
    
    sed -i 's/SecRuleEngine On/SecRuleEngine DetectionOnly/' "$MODSECURITY_DIR/modsecurity.conf"
    
    local web_server=$(detect_web_server)
    
    case $web_server in
        "apache")
            systemctl restart apache2 >> "$LOG_FILE" 2>&1
            ;;
        "nginx")
            systemctl restart nginx >> "$LOG_FILE" 2>&1
            ;;
    esac
    
    echo "ModSecurity deshabilitado"
    log_message "ModSecurity deshabilitado"
}

# Función para actualizar OWASP CRS
update_crs() {
    echo "Actualizando OWASP CRS..."
    
    # Obtener versión actual
    local current_version=$(grep "CORERULESET_VERSION" "$OWASP_CRS_DIR/rules/REQUEST-942-APPLICATION-ATTACK-SQLI.conf" | head -1 | cut -d'=' -f2 | tr -d ' ')
    
    # Obtener última versión disponible
    local latest_version=$(curl -s https://api.github.com/repos/coreruleset/coreruleset/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4 | tr -d 'v')
    
    if [ "$current_version" = "$latest_version" ]; then
        echo "OWASP CRS ya está actualizado (versión $current_version)"
        return
    fi
    
    echo "Actualizando OWASP CRS de la versión $current_version a la $latest_version..."
    
    # Descargar y actualizar CRS
    cd /tmp
    wget -q "https://github.com/coreruleset/coreruleset/archive/v$latest_version.tar.gz"
    tar -xzf "v$latest_version.tar.gz"
    
    # Hacer backup de la configuración actual
    cp "$OWASP_CRS_DIR/crs-setup.conf" "$OWASP_CRS_DIR/crs-setup.conf.backup"
    
    # Actualizar archivos de CRS
    rm -rf "$OWASP_CRS_DIR/rules"
    cp -r "coreruleset-$latest_version/rules" "$OWASP_CRS_DIR/"
    
    # Restaurar configuración personalizada
    if [ -f "$OWASP_CRS_DIR/crs-setup.conf.backup" ]; then
        cp "$OWASP_CRS_DIR/crs-setup.conf.backup" "$OWASP_CRS_DIR/crs-setup.conf"
    else
        cp "$OWASP_CRS_DIR/rules/crs-setup.conf.example" "$OWASP_CRS_DIR/crs-setup.conf"
    fi
    
    # Limpiar archivos temporales
    rm -rf "v$latest_version.tar.gz" "coreruleset-$latest_version"
    
    # Reiniciar servidor web
    local web_server=$(detect_web_server)
    
    case $web_server in
        "apache")
            systemctl restart apache2 >> "$LOG_FILE" 2>&1
            ;;
        "nginx")
            systemctl restart nginx >> "$LOG_FILE" 2>&1
            ;;
    esac
    
    echo "OWASP CRS actualizado a la versión $latest_version"
    log_message "OWASP CRS actualizado a la versión $latest_version"
}

# Función para ver logs de ModSecurity
view_logs() {
    local lines=${1:-50}
    
    echo "Mostrando últimas $lines líneas de logs de ModSecurity..."
    tail -n "$lines" "$INSTALL_DIR/logs/modsec_audit.log"
}

# Función para excluir regla
exclude_rule() {
    local rule_id=$1
    
    if [ -z "$rule_id" ]; then
        echo "Error: Se requiere ID de regla"
        return 1
    fi
    
    echo "Excluyendo regla $rule_id..."
    
    # Añadir regla de exclusión al archivo de configuración
    echo "SecRuleRemoveById $rule_id  # Excluida manualmente" >> "$MODSECURITY_DIR/modsecurity.conf"
    
    # Reiniciar servidor web
    local web_server=$(detect_web_server)
    
    case $web_server in
        "apache")
            systemctl restart apache2 >> "$LOG_FILE" 2>&1
            ;;
        "nginx")
            systemctl restart nginx >> "$LOG_FILE" 2>&1
            ;;
    esac
    
    echo "Regla $rule_id excluida"
    log_message "Regla $rule_id excluida"
}

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [OPCIÓN] [ARGUMENTOS]"
    echo ""
    echo "Opciones:"
    echo "  check_status              Verificar estado de ModSecurity"
    echo "  enable                    Habilitar ModSecurity"
    echo "  disable                   Deshabilitar ModSecurity"
    echo "  update_crs                Actualizar OWASP CRS"
    echo "  view_logs [LÍNEAS]        Ver logs de ModSecurity (por defecto: 50)"
    echo "  exclude_rule [ID]         Excluir regla por ID"
    echo "  show_help                 Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 check_status"
    echo "  $0 enable"
    echo "  $0 disable"
    echo "  $0 update_crs"
    echo "  $0 view_logs 100"
    echo "  $0 exclude_rule 949110"
}

# Función para detectar servidor web
detect_web_server() {
    if systemctl is-active --quiet apache2; then
        echo "apache"
    elif systemctl is-active --quiet nginx; then
        echo "nginx"
    elif systemctl is-active --quiet httpd; then
        echo "apache"
    else
        echo "unknown"
    fi
}

# Procesar argumentos
case "$1" in
    "check_status")
        check_status
        ;;
    "enable")
        enable_modsecurity
        ;;
    "disable")
        disable_modsecurity
        ;;
    "update_crs")
        update_crs
        ;;
    "view_logs")
        view_logs "$2"
        ;;
    "exclude_rule")
        if [ -z "$2" ]; then
            echo "Error: Se requiere ID de regla"
            show_help
            exit 1
        fi
        exclude_rule "$2"
        ;;
    "show_help"|*)
        show_help
        ;;
esac
EOF
    
    # Hacer ejecutable el script
    chmod +x "$INSTALL_DIR/scripts/manage_modsecurity.sh"
    
    log_message "Script de gestión de ModSecurity creado"
    print_message $GREEN "Script de gestión de ModSecurity creado"
}

# Función principal
main() {
    print_message $GREEN "Iniciando instalación y configuración de ModSecurity WAF..."
    log_message "Iniciando instalación y configuración de ModSecurity WAF"
    
    check_root
    install_dependencies
    install_modsecurity
    configure_modsecurity
    install_owasp_crs
    
    # Detectar servidor web y configurar integración
    local web_server=$(detect_web_server)
    
    case $web_server in
        "apache")
            integrate_with_apache
            ;;
        "nginx")
            integrate_with_nginx
            ;;
        "unknown")
            print_message $YELLOW "No se pudo detectar el servidor web. Configure la integración manualmente."
            ;;
    esac
    
    # Crear script de gestión
    create_management_script
    
    print_message $GREEN "Instalación y configuración de ModSecurity WAF completada"
    log_message "Instalación y configuración de ModSecurity WAF completada"
    
    print_message $BLUE "Información de configuración:"
    print_message $BLUE "- Archivo de configuración: $MODSECURITY_DIR/modsecurity.conf"
    print_message $BLUE "- Directorio de OWASP CRS: $OWASP_CRS_DIR"
    print_message $BLUE "- Logs: $INSTALL_DIR/logs/modsec_audit.log"
    print_message $BLUE "- Script de gestión: $INSTALL_DIR/scripts/manage_modsecurity.sh"
    print_message $YELLOW "Ejecute '$INSTALL_DIR/scripts/manage_modsecurity.sh show_help' para ver las opciones de gestión"
}

# Ejecutar función principal
main "$@"
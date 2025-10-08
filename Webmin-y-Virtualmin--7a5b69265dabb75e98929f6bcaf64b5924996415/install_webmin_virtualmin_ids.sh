#!/bin/bash

# ============================================================================
# SISTEMA DE DETECCIÓN Y PREVENCIÓN DE INTRUSIONES (IDS/IPS)
# PARA WEBMIN Y VIRTUALMIN
# ============================================================================
# Configura fail2ban con reglas específicas para Webmin/Virtualmin
# Incluye detección de ataques específicos a paneles de control
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IDS_DIR="/etc/webmin-virtualmin-ids"
LOG_FILE="$IDS_DIR/logs/ids_setup.log"

# Función de logging
log_ids() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    mkdir -p "$(dirname "$LOG_FILE")"

    case "$level" in
        "SUCCESS") echo -e "${GREEN}✅ [$timestamp] IDS:${NC} $message" ;;
        "INFO")    echo -e "${BLUE}💎 [$timestamp] IDS:${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}⚠️ [$timestamp] IDS:${NC} $message" ;;
        "ERROR")   echo -e "${RED}❌ [$timestamp] IDS:${NC} $message" ;;
        *)         echo -e "${PURPLE}🔥 [$timestamp] IDS:${NC} $message" ;;
    esac

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Verificar si fail2ban está instalado
check_fail2ban() {
    if ! command -v fail2ban-server >/dev/null 2>&1; then
        log_ids "INFO" "Instalando fail2ban..."
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y fail2ban
        elif command -v yum >/dev/null 2>&1; then
            yum install -y fail2ban
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y fail2ban
        else
            log_ids "ERROR" "No se pudo instalar fail2ban - gestor de paquetes no reconocido"
            exit 1
        fi
    fi

    log_ids "SUCCESS" "Fail2ban está disponible"
}

# Crear directorio de configuración IDS
create_ids_directory() {
    log_ids "INFO" "Creando directorio de configuración IDS..."

    mkdir -p "$IDS_DIR"
    mkdir -p "$IDS_DIR/filters"
    mkdir -p "$IDS_DIR/logs"
    mkdir -p "$IDS_DIR/rules"

    log_ids "SUCCESS" "Directorio IDS creado: $IDS_DIR"
}

# Crear filtros personalizados para Webmin/Virtualmin
create_webmin_filters() {
    log_ids "INFO" "Creando filtros personalizados para Webmin/Virtualmin..."

    # Filtro para ataques a Webmin (puerto 10000)
    cat > /etc/fail2ban/filter.d/webmin-auth.conf << 'EOF'
[Definition]
failregex = ^.*webmin.*Failed login from <HOST>.*$
            ^.*webmin.*Invalid login from <HOST>.*$
            ^.*webmin.*Authentication failure from <HOST>.*$
            ^.*webmin.*Bad request from <HOST>.*$
ignoreregex =
EOF

    # Filtro para ataques a Virtualmin
    cat > /etc/fail2ban/filter.d/virtualmin-auth.conf << 'EOF'
[Definition]
failregex = ^.*virtualmin.*Failed login from <HOST>.*$
            ^.*virtualmin.*Invalid login from <HOST>.*$
            ^.*virtualmin.*Authentication failure from <HOST>.*$
            ^.*usermin.*Failed login from <HOST>.*$
ignoreregex =
EOF

    # Filtro para ataques SQL injection en paneles
    cat > /etc/fail2ban/filter.d/webmin-sql-injection.conf << 'EOF'
[Definition]
failregex = ^.*<HOST>.*(union.*select|select.*from|insert.*into|update.*set|delete.*from).*$
            ^.*<HOST>.*(\%27|\%22|\%3B|\%3D|\%2D|\%2F|\%5C).*$
            ^.*<HOST>.*(script|javascript|vbscript|onload|onerror).*$
ignoreregex = ^.*<HOST>.*(google|bing|yahoo|baidu).*$
EOF

    # Filtro para ataques XSS en paneles
    cat > /etc/fail2ban/filter.d/webmin-xss.conf << 'EOF'
[Definition]
failregex = ^.*<HOST>.*(<script|<iframe|<object|<embed).*$
            ^.*<HOST>.*(javascript:|vbscript:|data:).*$
            ^.*<HOST>.*(on\w+\s*=).*$
ignoreregex = ^.*<HOST>.*(google|bing|yahoo).*$
EOF

    # Filtro para brute force en paneles
    cat > /etc/fail2ban/filter.d/webmin-bruteforce.conf << 'EOF'
[Definition]
failregex = ^.*<HOST>.*POST.*/session_login.cgi.*$
            ^.*<HOST>.*POST.*/virtual-server/remote.cgi.*$
            ^.*<HOST>.*POST.*/mail/save_autoreply.cgi.*$
            ^.*<HOST>.*Failed password for.*<HOST>.*$
maxretry = 5
ignoreregex =
EOF

    # Filtro para ataques a API de Webmin
    cat > /etc/fail2ban/filter.d/webmin-api.conf << 'EOF'
[Definition]
failregex = ^.*<HOST>.*GET.*/webmin/api/.*HTTP/[0-9.]+" 401.*$
            ^.*<HOST>.*POST.*/webmin/api/.*HTTP/[0-9.]+" 401.*$
            ^.*<HOST>.*GET.*/virtual-server/api/.*HTTP/[0-9.]+" 401.*$
ignoreregex =
EOF

    log_ids "SUCCESS" "Filtros personalizados creados"
}

# Configurar jails específicas para Webmin/Virtualmin
configure_webmin_jails() {
    log_ids "INFO" "Configurando jails específicas para Webmin/Virtualmin..."

    # Backup de configuración existente
    cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

    # Configuración principal
    cat >> /etc/fail2ban/jail.local << 'EOF'

# ===== CONFIGURACIÓN ESPECÍFICA PARA WEBMIN/VIRTUALMIN =====

[webmin-auth]
enabled = true
port = 10000
filter = webmin-auth
logpath = /var/webmin/miniserv.log
maxretry = 3
findtime = 600
bantime = 3600
action = %(action_mwl)s

[virtualmin-auth]
enabled = true
port = 10000
filter = virtualmin-auth
logpath = /var/webmin/miniserv.log
maxretry = 3
findtime = 600
bantime = 3600
action = %(action_mwl)s

[webmin-sql-injection]
enabled = true
port = 10000
filter = webmin-sql-injection
logpath = /var/webmin/miniserv.log
maxretry = 2
findtime = 300
bantime = 7200
action = %(action_mwl)s

[webmin-xss]
enabled = true
port = 10000
filter = webmin-xss
logpath = /var/webmin/miniserv.log
maxretry = 2
findtime = 300
bantime = 7200
action = %(action_mwl)s

[webmin-bruteforce]
enabled = true
port = 10000
filter = webmin-bruteforce
logpath = /var/webmin/miniserv.log
maxretry = 5
findtime = 600
bantime = 3600
action = %(action_mwl)s

[webmin-api]
enabled = true
port = 10000
filter = webmin-api
logpath = /var/webmin/miniserv.log
maxretry = 3
findtime = 300
bantime = 1800
action = %(action_mwl)s

# Protección adicional para Virtualmin
[virtualmin-dns]
enabled = true
port = 53
protocol = udp
filter = named-refused
logpath = /var/log/named/query.log
maxretry = 10
findtime = 300
bantime = 3600

[virtualmin-mail]
enabled = true
port = smtp,pop3,imap
filter = postfix
logpath = /var/log/mail.log
maxretry = 5
findtime = 600
bantime = 3600

EOF

    log_ids "SUCCESS" "Jails específicas configuradas"
}

# Configurar acciones personalizadas
configure_custom_actions() {
    log_ids "INFO" "Configurando acciones personalizadas..."

    # Acción para notificar ataques a Webmin
    cat > /etc/fail2ban/action.d/webmin-notify.conf << 'EOF'
[Definition]
actionstart =
actionstop =
actioncheck =
actionban = echo "ATAQUE DETECTADO A WEBMIN - IP BLOQUEADA: <ip>" | mail -s "Webmin Security Alert" root
actionunban =
EOF

    # Acción para bloquear con ipset (más eficiente)
    cat > /etc/fail2ban/action.d/webmin-ipset.conf << 'EOF'
[Definition]
actionstart = ipset create webmin_attackers hash:ip timeout 3600 maxelem 100000
actionstop = ipset flush webmin_attackers
actioncheck =
actionban = ipset add webmin_attackers <ip>
actionunban = ipset del webmin_attackers <ip>
EOF

    log_ids "SUCCESS" "Acciones personalizadas configuradas"
}

# Configurar monitoreo de logs adicionales
configure_log_monitoring() {
    log_ids "INFO" "Configurando monitoreo de logs adicionales..."

    # Monitoreo de logs de Apache para Virtualmin
    if [[ -f /etc/apache2/apache2.conf ]]; then
        cat >> /etc/fail2ban/jail.local << 'EOF'

[apache-webmin]
enabled = true
port = http,https
filter = apache-auth
logpath = /var/log/apache2/*access.log
maxretry = 3
findtime = 600
bantime = 3600

EOF
    fi

    # Monitoreo de logs de Nginx si existe
    if [[ -f /etc/nginx/nginx.conf ]]; then
        cat >> /etc/fail2ban/jail.local << 'EOF'

[nginx-webmin]
enabled = true
port = http,https
filter = nginx-http-auth
logpath = /var/log/nginx/*access.log
maxretry = 3
findtime = 600
bantime = 3600

EOF
    fi

    log_ids "SUCCESS" "Monitoreo de logs adicionales configurado"
}

# Crear script de monitoreo personalizado
create_monitoring_script() {
    log_ids "INFO" "Creando script de monitoreo personalizado..."

    cat > "$IDS_DIR/monitor_webmin_attacks.sh" << 'EOF'
#!/bin/bash

# Script de monitoreo personalizado para ataques a Webmin/Virtualmin
IDS_DIR="/etc/webmin-virtualmin-ids"
LOG_FILE="$IDS_DIR/logs/attack_monitor.log"

# Función de logging
log_attack() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$LOG_FILE"
    echo -e "\033[0;31m[$timestamp ATTACK]\033[0m $message"
}

# Verificar ataques a Webmin
check_webmin_attacks() {
    local webmin_log="/var/webmin/miniserv.log"

    if [[ -f "$webmin_log" ]]; then
        # Detectar intentos de login fallidos
        local failed_logins=$(grep "Failed login" "$webmin_log" | wc -l 2>/dev/null || echo "0")

        if [[ $failed_logins -gt 10 ]]; then
            log_attack "ATAQUES DE FUERZA BRUTA A WEBMIN DETECTADOS: $failed_logins intentos"
        fi

        # Detectar patrones SQL injection
        local sql_injections=$(grep -E "(union.*select|select.*from|insert.*into)" "$webmin_log" | wc -l 2>/dev/null || echo "0")

        if [[ $sql_injections -gt 0 ]]; then
            log_attack "ATAQUES SQL INJECTION DETECTADOS: $sql_injections intentos"
        fi

        # Detectar patrones XSS
        local xss_attacks=$(grep -E "(<script|<iframe|<object)" "$webmin_log" | wc -l 2>/dev/null || echo "0")

        if [[ $xss_attacks -gt 0 ]]; then
            log_attack "ATAQUES XSS DETECTADOS: $xss_attacks intentos"
        fi
    fi
}

# Verificar estado de fail2ban
check_fail2ban_status() {
    if systemctl is-active --quiet fail2ban; then
        local banned_ips=$(fail2ban-client status | grep "Total banned:" | awk '{print $4}' 2>/dev/null || echo "0")
        echo "Fail2Ban activo - IPs bloqueadas: $banned_ips"
    else
        log_attack "FAIL2BAN NO ESTÁ EJECUTÁNDOSE"
    fi
}

# Función principal
main() {
    mkdir -p "$IDS_DIR/logs"

    check_webmin_attacks
    check_fail2ban_status
}

# Ejecutar cada 5 minutos
main
EOF

    chmod +x "$IDS_DIR/monitor_webmin_attacks.sh"

    # Crear cron job para monitoreo
    cat > /etc/cron.d/webmin-ids-monitor << 'EOF'
*/5 * * * * root /etc/webmin-virtualmin-ids/monitor_webmin_attacks.sh
EOF

    log_ids "SUCCESS" "Script de monitoreo personalizado creado"
}

# Reiniciar servicios
restart_services() {
    log_ids "INFO" "Reiniciando servicios..."

    systemctl restart fail2ban 2>/dev/null || service fail2ban restart 2>/dev/null || true

    # Recargar configuración
    fail2ban-client reload 2>/dev/null || true

    log_ids "SUCCESS" "Servicios reiniciados"
}

# Mostrar resumen
show_summary() {
    echo
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${GREEN}🛡️ IDS/IPS PARA WEBMIN/VIRTUALMIN CONFIGURADO${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo
    echo -e "${GREEN}🚀 PROTECCIONES ACTIVAS:${NC}"
    echo -e "${CYAN}   🔐 Autenticación Webmin/Virtualmin${NC}"
    echo -e "${CYAN}   💉 Detección SQL Injection${NC}"
    echo -e "${CYAN}   🕷️ Detección XSS${NC}"
    echo -e "${CYAN}   🔨 Protección contra fuerza bruta${NC}"
    echo -e "${CYAN}   📡 Protección API${NC}"
    echo -e "${CYAN}   📧 Alertas por email${NC}"
    echo
    echo -e "${YELLOW}🛠️ COMANDOS DE MONITOREO:${NC}"
    echo -e "${BLUE}   📊 Estado: fail2ban-client status${NC}"
    echo -e "${BLUE}   🚫 IPs bloqueadas: fail2ban-client status webmin-auth${NC}"
    echo -e "${BLUE}   📝 Logs: tail -f $LOG_FILE${NC}"
    echo -e "${BLUE}   🔍 Monitoreo: tail -f $IDS_DIR/logs/attack_monitor.log${NC}"
    echo
    echo -e "${BLUE}============================================================================${NC}"
}

# Función principal
main() {
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${PURPLE}🛡️ CONFIGURANDO IDS/IPS PARA WEBMIN/VIRTUALMIN${NC}"
    echo -e "${BLUE}============================================================================${NC}"

    # Verificar permisos de root
    if [[ $EUID -ne 0 ]]; then
        log_ids "ERROR" "Este script debe ejecutarse como root"
        exit 1
    fi

    # Ejecutar configuraciones
    check_fail2ban
    create_ids_directory
    create_webmin_filters
    configure_webmin_jails
    configure_custom_actions
    configure_log_monitoring
    create_monitoring_script
    restart_services

    # Mostrar resumen
    show_summary

    log_ids "SUCCESS" "¡IDS/IPS para Webmin/Virtualmin configurado exitosamente!"
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
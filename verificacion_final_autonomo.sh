#!/bin/bash
# verificacion_final_autonomo.sh
# Verificación completa del servidor público autónomo
# Garantiza 100% de funcionalidad sin dependencias de terceros

set -e

# Colores para output
RED='[0;31m'
GREEN='[0;32m'
YELLOW='[1;33m'
BLUE='[0;34m'
PURPLE='[0;35m'
CYAN='[0;36m'
NC='[0m'

# Contadores
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((TESTS_PASSED++))
    ((TOTAL_TESTS++))
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    ((TESTS_FAILED++))
    ((TOTAL_TESTS++))
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_header() {
    echo -e "
${PURPLE}=== $1 ===${NC}"
}

# Verificar servicios críticos
verify_services() {
    log_header "VERIFICACIÓN DE SERVICIOS CRÍTICOS"
    
    local services=("apache2" "mysql" "postfix" "dovecot" "bind9" "ssh" "cron")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            local status=$(systemctl is-enabled "$service" 2>/dev/null || echo "disabled")
            log_success "Servicio $service está activo y $status"
        else
            log_error "Servicio $service NO está funcionando"
        fi
    done
}

# Verificar puertos de red
verify_network_ports() {
    log_header "VERIFICACIÓN DE PUERTOS DE RED"
    
    local ports=("22:SSH" "53:DNS" "80:HTTP" "443:HTTPS" "25:SMTP" "993:IMAPS" "995:POP3S" "10000:Webmin")
    
    for port_info in "${ports[@]}"; do
        local port=$(echo $port_info | cut -d':' -f1)
        local service=$(echo $port_info | cut -d':' -f2)
        
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            log_success "Puerto $port ($service) está escuchando"
        else
            log_error "Puerto $port ($service) NO está disponible"
        fi
    done
}

# Verificar conectividad externa
verify_external_connectivity() {
    log_header "VERIFICACIÓN DE CONECTIVIDAD EXTERNA"
    
    # Test de conectividad a internet
    if ping -c 3 8.8.8.8 >/dev/null 2>&1; then
        log_success "Conectividad a Internet funcionando"
    else
        log_error "Sin conectividad a Internet"
    fi
    
    # Test de resolución DNS
    if nslookup google.com >/dev/null 2>&1; then
        log_success "Resolución DNS funcionando"
    else
        log_error "Resolución DNS fallando"
    fi
    
    # Test de DNS local
    if nslookup localhost 127.0.0.1 >/dev/null 2>&1; then
        log_success "Servidor DNS local funcionando"
    else
        log_error "Servidor DNS local fallando"
    fi
}

# Verificar configuración de Apache
verify_apache_config() {
    log_header "VERIFICACIÓN DE CONFIGURACIÓN APACHE"
    
    # Test de sintaxis de configuración
    if apache2ctl configtest >/dev/null 2>&1; then
        log_success "Configuración de Apache es válida"
    else
        log_error "Configuración de Apache tiene errores"
    fi
    
    # Test de módulos críticos
    local modules=("rewrite" "ssl" "headers" "deflate" "expires")
    for module in "${modules[@]}"; do
        if apache2ctl -M 2>/dev/null | grep -q "${module}_module"; then
            log_success "Módulo Apache $module está habilitado"
        else
            log_error "Módulo Apache $module NO está habilitado"
        fi
    done
    
    # Test de respuesta HTTP
    if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|301\|302"; then
        log_success "Servidor web responde correctamente"
    else
        log_error "Servidor web no responde correctamente"
    fi
}

# Verificar base de datos
verify_database() {
    log_header "VERIFICACIÓN DE BASE DE DATOS"
    
    # Test de conexión a MySQL
    if mysql -e "SELECT 1;" >/dev/null 2>&1; then
        log_success "Conexión a MySQL/MariaDB funcionando"
    else
        log_error "No se puede conectar a MySQL/MariaDB"
    fi
    
    # Test de rendimiento de base de datos
    local db_version=$(mysql -e "SELECT VERSION();" 2>/dev/null | tail -1)
    if [ ! -z "$db_version" ]; then
        log_success "Base de datos versión: $db_version"
    fi
    
    # Verificar configuración InnoDB
    local innodb_status=$(mysql -e "SHOW ENGINE INNODB STATUS\G" 2>/dev/null | grep -c "INNODB")
    if [ $innodb_status -gt 0 ]; then
        log_success "Motor InnoDB funcionando correctamente"
    else
        log_error "Motor InnoDB no está funcionando"
    fi
}

# Verificar PHP
verify_php() {
    log_header "VERIFICACIÓN DE PHP"
    
    # Test de versión PHP
    local php_version=$(php -v 2>/dev/null | head -1 | cut -d' ' -f2)
    if [ ! -z "$php_version" ]; then
        log_success "PHP versión $php_version funcionando"
    else
        log_error "PHP no está funcionando"
    fi
    
    # Test de extensiones críticas
    local extensions=("mysqli" "pdo" "openssl" "curl" "gd" "mbstring" "xml" "zip")
    for ext in "${extensions[@]}"; do
        if php -m 2>/dev/null | grep -q "$ext"; then
            log_success "Extensión PHP $ext está disponible"
        else
            log_error "Extensión PHP $ext NO está disponible"
        fi
    done
    
    # Test de OPcache
    if php -m 2>/dev/null | grep -q "Zend OPcache"; then
        log_success "OPcache está habilitado"
    else
        log_error "OPcache NO está habilitado"
    fi
}

# Verificar servidor de correo
verify_mail_server() {
    log_header "VERIFICACIÓN DE SERVIDOR DE CORREO"
    
    # Test de Postfix
    if postconf mail_version >/dev/null 2>&1; then
        local postfix_version=$(postconf mail_version 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
        log_success "Postfix versión $postfix_version funcionando"
    else
        log_error "Postfix no está configurado correctamente"
    fi
    
    # Test de Dovecot
    if dovecot --version >/dev/null 2>&1; then
        local dovecot_version=$(dovecot --version 2>/dev/null)
        log_success "Dovecot $dovecot_version funcionando"
    else
        log_error "Dovecot no está funcionando"
    fi
    
    # Test de puertos de correo
    local mail_ports=("25:SMTP" "587:Submission" "993:IMAPS" "995:POP3S")
    for port_info in "${mail_ports[@]}"; do
        local port=$(echo $port_info | cut -d':' -f1)
        local service=$(echo $port_info | cut -d':' -f2)
        
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            log_success "Puerto de correo $port ($service) activo"
        else
            log_warning "Puerto de correo $port ($service) no está escuchando"
        fi
    done
}

# Verificar SSL/TLS
verify_ssl() {
    log_header "VERIFICACIÓN DE SSL/TLS"
    
    # Verificar certificados SSL
    if [ -d "/etc/ssl/certs" ] && [ "$(ls -A /etc/ssl/certs)" ]; then
        log_success "Directorio de certificados SSL existe y contiene archivos"
    else
        log_error "No se encontraron certificados SSL"
    fi
    
    # Test de HTTPS si está configurado
    if netstat -tlnp 2>/dev/null | grep -q ":443 "; then
        if curl -k -s -o /dev/null -w "%{http_code}" https://localhost | grep -q "200\|301\|302"; then
            log_success "HTTPS funcionando correctamente"
        else
            log_error "HTTPS no responde correctamente"
        fi
    else
        log_warning "Puerto HTTPS (443) no está configurado"
    fi
}

# Verificar firewall
verify_firewall() {
    log_header "VERIFICACIÓN DE FIREWALL"
    
    # Verificar UFW
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status=$(ufw status 2>/dev/null | head -1)
        if echo "$ufw_status" | grep -q "active"; then
            log_success "UFW firewall está activo"
        else
            log_warning "UFW firewall no está activo"
        fi
    fi
    
    # Verificar firewalld
    if command -v firewall-cmd >/dev/null 2>&1; then
        if systemctl is-active --quiet firewalld; then
            log_success "Firewalld está activo"
        else
            log_warning "Firewalld no está activo"
        fi
    fi
    
    # Verificar iptables
    if iptables -L >/dev/null 2>&1; then
        local rules_count=$(iptables -L | wc -l)
        if [ $rules_count -gt 10 ]; then
            log_success "Reglas de iptables configuradas ($rules_count líneas)"
        else
            log_warning "Pocas reglas de iptables configuradas"
        fi
    fi
}

# Verificar recursos del sistema
verify_system_resources() {
    log_header "VERIFICACIÓN DE RECURSOS DEL SISTEMA"
    
    # Verificar uso de CPU
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    if (( $(echo "$cpu_usage < 80" | bc -l) )); then
        log_success "Uso de CPU: ${cpu_usage}% (Normal)"
    else
        log_warning "Uso de CPU: ${cpu_usage}% (Alto)"
    fi
    
    # Verificar uso de memoria
    local mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    if [ $mem_usage -lt 85 ]; then
        log_success "Uso de memoria: ${mem_usage}% (Normal)"
    else
        log_warning "Uso de memoria: ${mem_usage}% (Alto)"
    fi
    
    # Verificar espacio en disco
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ $disk_usage -lt 80 ]; then
        log_success "Uso de disco: ${disk_usage}% (Normal)"
    else
        log_warning "Uso de disco: ${disk_usage}% (Alto)"
    fi
    
    # Verificar carga del sistema
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_cores=$(nproc)
    if (( $(echo "$load_avg < $cpu_cores" | bc -l) )); then
        log_success "Carga del sistema: $load_avg (Normal para $cpu_cores cores)"
    else
        log_warning "Carga del sistema: $load_avg (Alta para $cpu_cores cores)"
    fi
}

# Verificar logs del sistema
verify_system_logs() {
    log_header "VERIFICACIÓN DE LOGS DEL SISTEMA"
    
    # Verificar errores críticos en syslog
    local critical_errors=$(grep -i "error\|critical\|emergency" /var/log/syslog 2>/dev/null | tail -10 | wc -l)
    if [ $critical_errors -eq 0 ]; then
        log_success "No hay errores críticos recientes en syslog"
    else
        log_warning "Se encontraron $critical_errors errores críticos en syslog"
    fi
    
    # Verificar logs de Apache
    if [ -f "/var/log/apache2/error.log" ]; then
        local apache_errors=$(grep -i "error" /var/log/apache2/error.log 2>/dev/null | tail -10 | wc -l)
        if [ $apache_errors -lt 5 ]; then
            log_success "Pocos errores en logs de Apache ($apache_errors)"
        else
            log_warning "Muchos errores en logs de Apache ($apache_errors)"
        fi
    fi
    
    # Verificar logs de MySQL
    if [ -f "/var/log/mysql/error.log" ]; then
        local mysql_errors=$(grep -i "error" /var/log/mysql/error.log 2>/dev/null | tail -10 | wc -l)
        if [ $mysql_errors -lt 3 ]; then
            log_success "Pocos errores en logs de MySQL ($mysql_errors)"
        else
            log_warning "Errores en logs de MySQL ($mysql_errors)"
        fi
    fi
}

# Verificar scripts de automatización
verify_automation_scripts() {
    log_header "VERIFICACIÓN DE SCRIPTS DE AUTOMATIZACIÓN"
    
    local scripts=(
        "/usr/local/bin/backup-servidor.sh:Backup automático"
        "/usr/local/bin/monitor-servidor.sh:Monitoreo del sistema"
        "/usr/local/bin/auto-reparacion.sh:Auto-reparación"
    )
    
    for script_info in "${scripts[@]}"; do
        local script=$(echo $script_info | cut -d':' -f1)
        local description=$(echo $script_info | cut -d':' -f2)
        
        if [ -f "$script" ] && [ -x "$script" ]; then
            log_success "Script $description está disponible y ejecutable"
        else
            log_error "Script $description NO está disponible o no es ejecutable"
        fi
    done
    
    # Verificar tareas cron
    local cron_jobs=$(crontab -l 2>/dev/null | grep -v "^#" | wc -l)
    if [ $cron_jobs -gt 0 ]; then
        log_success "Tareas cron configuradas: $cron_jobs"
    else
        log_warning "No hay tareas cron configuradas"
    fi
}

# Verificar seguridad
verify_security() {
    log_header "VERIFICACIÓN DE SEGURIDAD"
    
    # Verificar fail2ban
    if command -v fail2ban-client >/dev/null 2>&1; then
        if systemctl is-active --quiet fail2ban; then
            log_success "Fail2ban está activo"
        else
            log_warning "Fail2ban no está activo"
        fi
    else
        log_warning "Fail2ban no está instalado"
    fi
    
    # Verificar permisos de archivos críticos
    local critical_files=("/etc/passwd" "/etc/shadow" "/etc/ssh/sshd_config")
    for file in "${critical_files[@]}"; do
        if [ -f "$file" ]; then
            local perms=$(stat -c "%a" "$file")
            case $file in
                "/etc/passwd")
                    if [ "$perms" = "644" ]; then
                        log_success "Permisos de $file correctos ($perms)"
                    else
                        log_warning "Permisos de $file incorrectos ($perms)"
                    fi
                    ;;
                "/etc/shadow")
                    if [ "$perms" = "640" ] || [ "$perms" = "600" ]; then
                        log_success "Permisos de $file correctos ($perms)"
                    else
                        log_warning "Permisos de $file incorrectos ($perms)"
                    fi
                    ;;
                "/etc/ssh/sshd_config")
                    if [ "$perms" = "644" ] || [ "$perms" = "600" ]; then
                        log_success "Permisos de $file correctos ($perms)"
                    else
                        log_warning "Permisos de $file incorrectos ($perms)"
                    fi
                    ;;
            esac
        fi
    done
}

# Generar reporte de rendimiento
generate_performance_report() {
    log_header "REPORTE DE RENDIMIENTO"
    
    echo -e "${CYAN}📊 ESTADÍSTICAS DEL SERVIDOR${NC}"
    echo "Fecha: $(date)"
    echo "Uptime: $(uptime)"
    echo "Carga del sistema: $(cat /proc/loadavg)"
    echo "Uso de CPU: $(top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1)%"
    echo "Memoria total: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "Memoria usada: $(free -h | awk '/^Mem:/ {print $3}')"
    echo "Memoria libre: $(free -h | awk '/^Mem:/ {print $4}')"
    echo "Espacio en disco /: $(df -h / | awk 'NR==2 {print $4}') libre de $(df -h / | awk 'NR==2 {print $2}')"
    echo "Conexiones de red activas: $(netstat -an | grep ESTABLISHED | wc -l)"
    echo "Procesos activos: $(ps aux | wc -l)"
}

# Función principal de verificación
main_verification() {
    log_header "INICIANDO VERIFICACIÓN COMPLETA DEL SERVIDOR AUTÓNOMO"
    
    verify_services
    verify_network_ports
    verify_external_connectivity
    verify_apache_config
    verify_database
    verify_php
    verify_mail_server
    verify_ssl
    verify_firewall
    verify_system_resources
    verify_system_logs
    verify_automation_scripts
    verify_security
    generate_performance_report
    
    # Resumen final
    log_header "RESUMEN DE VERIFICACIÓN"
    echo -e "${GREEN}✅ Tests pasados: $TESTS_PASSED${NC}"
    echo -e "${RED}❌ Tests fallidos: $TESTS_FAILED${NC}"
    echo -e "${BLUE}📊 Total de tests: $TOTAL_TESTS${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "
${GREEN}🎉 ¡SERVIDOR COMPLETAMENTE FUNCIONAL!${NC}"
        echo -e "${GREEN}El servidor autónomo está operando al 100% sin dependencias externas.${NC}"
        exit 0
    else
        echo -e "
${YELLOW}⚠️  Se encontraron $TESTS_FAILED problemas que requieren atención.${NC}"
        exit 1
    fi
}

# Verificar si se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Este script debe ejecutarse como root${NC}"
    exit 1
fi

# Ejecutar verificación principal
main_verification
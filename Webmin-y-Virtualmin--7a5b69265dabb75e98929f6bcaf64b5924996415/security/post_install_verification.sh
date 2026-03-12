#!/bin/bash

# Script de Verificación Post-Instalación Segura
# Versión: 1.0.0
# Verifica que la instalación se realizó correctamente y de forma segura

set -euo pipefail

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFICATION_REPORT="/var/log/webmin_post_install_verification_$(date +%Y%m%d_%H%M%S).json"
SECURITY_SCORE=0
MAX_SCORE=100

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log_verification() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [VERIFICATION] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
    echo "{\"category\": \"error\", \"message\": \"$1\", \"timestamp\": \"$(date -Iseconds)\"}" >> "$VERIFICATION_REPORT"
}

log_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
    echo "{\"category\": \"warning\", \"message\": \"$1\", \"timestamp\": \"$(date -Iseconds)\"}" >> "$VERIFICATION_REPORT"
}

log_success() {
    echo -e "${GREEN}[OK] $1${NC}"
    echo "{\"category\": \"success\", \"message\": \"$1\", \"timestamp\": \"$(date -Iseconds)\"}" >> "$VERIFICATION_REPORT"
}

log_info() {
    echo -e "${CYAN}[INFO] $1${NC}"
    echo "{\"category\": \"info\", \"message\": \"$1\", \"timestamp\": \"$(date -Iseconds)\"}" >> "$VERIFICATION_REPORT"
}

# Inicializar reporte
init_verification_report() {
    cat > "$VERIFICATION_REPORT" << EOF
{
  "verification_session": {
    "start_time": "$(date -Iseconds)",
    "verifier_version": "1.0.0",
    "hostname": "$(hostname)",
    "user": "$(whoami)"
  },
  "verifications": []
EOF
}

# Finalizar reporte
finalize_verification_report() {
    local grade="F"
    if [[ $SECURITY_SCORE -ge 90 ]]; then
        grade="A"
    elif [[ $SECURITY_SCORE -ge 80 ]]; then
        grade="B"
    elif [[ $SECURITY_SCORE -ge 70 ]]; then
        grade="C"
    elif [[ $SECURITY_SCORE -ge 60 ]]; then
        grade="D"
    fi
    
    cat >> "$VERIFICATION_REPORT" << EOF
  },
  "summary": {
    "end_time": "$(date -Iseconds)",
    "security_score": $SECURITY_SCORE,
    "max_score": $MAX_SCORE,
    "grade": "$grade",
    "status": "$([ $SECURITY_SCORE -ge 70 ] && echo "PASSED" || echo "FAILED")"
  }
}
EOF
    
    log_verification "Reporte de verificación guardado en: $VERIFICATION_REPORT"
}

# Función para añadir puntos al score de seguridad
add_security_points() {
    local points=$1
    SECURITY_SCORE=$((SECURITY_SCORE + points))
    log_verification "Puntos de seguridad añadidos: +$points (Total: $SECURITY_SCORE/$MAX_SCORE)"
}

# Verificar instalación de Webmin/Virtualmin
verify_webmin_installation() {
    log_verification "Verificando instalación de Webmin/Virtualmin..."
    
    local webmin_score=0
    
    # Verificar archivos de configuración
    if [[ -f "/etc/webmin/config" ]]; then
        log_success "Archivo de configuración de Webmin encontrado"
        ((webmin_score += 10))
    else
        log_error "Archivo de configuración de Webmin no encontrado"
    fi
    
    if [[ -f "/etc/webmin/miniserv.conf" ]]; then
        log_success "Archivo de configuración miniserv encontrado"
        ((webmin_score += 10))
    else
        log_error "Archivo de configuración miniserv no encontrado"
    fi
    
    # Verificar servicio activo
    if systemctl is-active --quiet webmin; then
        log_success "Servicio Webmin activo"
        ((webmin_score += 15))
    else
        log_error "Servicio Webmin no está activo"
    fi
    
    # Verificar configuración SSL
    if [[ -f "/etc/webmin/miniserv.conf" ]] && grep -q "^ssl=1" /etc/webmin/miniserv.conf; then
        log_success "SSL habilitado en Webmin"
        ((webmin_score += 15))
    else
        log_error "SSL no habilitado en Webmin"
    fi
    
    # Verificar HSTS
    if [[ -f "/etc/webmin/miniserv.conf" ]] && grep -q "^ssl_hsts=1" /etc/webmin/miniserv.conf; then
        log_success "HSTS habilitado en Webmin"
        ((webmin_score += 10))
    else
        log_warning "HSTS no habilitado en Webmin"
    fi
    
    # Verificar puerto
    local webmin_port
    webmin_port=$(grep "^port=" /etc/webmin/miniserv.conf 2>/dev/null | cut -d= -f2 || echo "10000")
    if [[ "$webmin_port" != "10000" ]]; then
        log_success "Puerto de Webmin modificado: $webmin_port"
        ((webmin_score += 5))
    else
        log_info "Puerto de Webmin por defecto: $webmin_port"
    fi
    
    # Verificar autenticación
    if grep -q "^passwd_mode=" /etc/webmin/config 2>/dev/null; then
        local passwd_mode
        passwd_mode=$(grep "^passwd_mode=" /etc/webmin/config | cut -d= -f2)
        if [[ "$passwd_mode" == "2" ]]; then
            log_success "Autenticación PAM configurada en Webmin"
            ((webmin_score += 10))
        fi
    fi
    
    add_security_points $webmin_score
}

# Verificar configuración de base de datos
verify_database_security() {
    log_verification "Verificando configuración de base de datos..."
    
    local db_score=0
    
    # Verificar MySQL/MariaDB
    if [[ -f "/etc/mysql/my.cnf" ]]; then
        # Verificar bind-address
        local bind_address
        bind_address=$(grep "^bind-address" /etc/mysql/my.cnf 2>/dev/null | cut -d= -f2 | tr -d ' ' || echo "")
        if [[ "$bind_address" == "127.0.0.1" || "$bind_address" == "::1" ]]; then
            log_success "Base de datos configurada para acceso local"
            ((db_score += 10))
        else
            log_warning "Base de datos accesible desde red: $bind_address"
            ((db_score += 5))
        fi
        
        # Verificar SSL
        if grep -q "^require_secure_transport" /etc/mysql/my.cnf 2>/dev/null; then
            log_success "SSL requerido en base de datos"
            ((db_score += 15))
        else
            log_warning "SSL no requerido en base de datos"
        fi
        
        # Verificar logging
        if grep -q "^slow_query_log.*=.*ON" /etc/mysql/my.cnf 2>/dev/null; then
            log_success "Logging de consultas lentas habilitado"
            ((db_score += 10))
        fi
    fi
    
    # Verificar servicio activo
    if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mariadb 2>/dev/null; then
        log_success "Servicio de base de datos activo"
        ((db_score += 10))
    else
        log_error "Servicio de base de datos no activo"
    fi
    
    add_security_points $db_score
}

# Verificar configuración SSL/TLS
verify_ssl_configuration() {
    log_verification "Verificando configuración SSL/TLS..."
    
    local ssl_score=0
    
    # Verificar certificados Let's Encrypt
    if [[ -d "/etc/letsencrypt/live" ]]; then
        local cert_count
        cert_count=$(find /etc/letsencrypt/live -name "*.pem" -type f | wc -l)
        if [[ $cert_count -gt 0 ]]; then
            log_success "Certificados SSL encontrados: $cert_count"
            ((ssl_score += 15))
            
            # Verificar validez de certificados
            local valid_certs=0
            find /etc/letsencrypt/live -name "cert.pem" -type f | while read -r cert; do
                if openssl x509 -in "$cert" -noout -checkend 86400 2>/dev/null; then
                    ((valid_certs++))
                fi
            done
            
            if [[ $valid_certs -gt 0 ]]; then
                log_success "Certificados válidos encontrados: $valid_certs"
                ((ssl_score += 10))
            else
                log_warning "No se encontraron certificados válidos"
            fi
        fi
    else
        log_warning "Directorio Let's Encrypt no encontrado"
    fi
    
    # Verificar configuración SSL en Apache
    if [[ -f "/etc/apache2/sites-available/default-ssl.conf" ]] || [[ -f "/etc/apache2/sites-available/ssl.conf" ]]; then
        log_success "Configuración SSL de Apache encontrada"
        ((ssl_score += 10))
    fi
    
    # Verificar configuración SSL en Nginx
    if [[ -f "/etc/nginx/sites-available/default" ]] && grep -q "ssl_certificate" /etc/nginx/sites-available/default; then
        log_success "Configuración SSL de Nginx encontrada"
        ((ssl_score += 10))
    fi
    
    add_security_points $ssl_score
}

# Verificar configuración de firewall
verify_firewall_security() {
    log_verification "Verificando configuración de firewall..."
    
    local firewall_score=0
    
    # Verificar UFW
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            log_success "UFW activo"
            ((firewall_score += 20))
            
            # Verificar reglas
            if ufw status | grep -q "10000/tcp"; then
                log_warning "Webmin accesible desde cualquier IP"
                ((firewall_score += 5))
            fi
            
            if ufw status | grep -q "22/tcp"; then
                log_success "SSH permitido en UFW"
                ((firewall_score += 5))
            fi
        else
            log_error "UFW no está activo"
        fi
    fi
    
    # Verificar firewalld
    if command -v firewall-cmd &> /dev/null; then
        if firewall-cmd --state &> /dev/null; then
            log_success "firewalld activo"
            ((firewall_score += 20))
            
            # Verificar zona por defecto
            local default_zone
            default_zone=$(firewall-cmd --get-default-zone)
            if [[ "$default_zone" == "drop" || "$default_zone" == "public" ]]; then
                log_success "Zona por defecto segura: $default_zone"
                ((firewall_score += 10))
            else
                log_warning "Zona por defecto insegura: $default_zone"
            fi
        else
            log_error "firewalld no está activo"
        fi
    fi
    
    add_security_points $firewall_score
}

# Verificar configuración de monitoreo
verify_monitoring_security() {
    log_verification "Verificando configuración de monitoreo..."
    
    local monitoring_score=0
    
    # Verificar Fail2Ban
    if systemctl is-active --quiet fail2ban; then
        log_success "Fail2Ban activo"
        ((monitoring_score += 15))
        
        # Verificar jails
        if fail2ban-client status | grep -q "ssh"; then
            log_success "Jail SSH configurado en Fail2Ban"
            ((monitoring_score += 5))
        fi
        
        if fail2ban-client status | grep -q "webmin"; then
            log_success "Jail Webmin configurado en Fail2Ban"
            ((monitoring_score += 5))
        fi
    else
        log_error "Fail2Ban no está activo"
    fi
    
    # Verificar auditoría
    if systemctl is-active --quiet auditd; then
        log_success "Auditoría del sistema activa"
        ((monitoring_score += 10))
    else
        log_warning "Auditoría del sistema no activa"
    fi
    
    # Verificar AIDE
    if command -v aide &> /dev/null; then
        if [[ -f "/var/lib/aide/aide.db" ]]; then
            log_success "Base de datos AIDE encontrada"
            ((monitoring_score += 10))
        else
            log_warning "Base de datos AIDE no encontrada"
        fi
    else
        log_warning "AIDE no instalado"
    fi
    
    # Verificar logs
    local log_dirs=(
        "/var/log/webmin"
        "/var/log/audit"
        "/var/log/fail2ban"
    )
    
    for dir in "${log_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local perms
            perms=$(stat -c "%a" "$dir" 2>/dev/null || stat -f "%A" "$dir" 2>/dev/null)
            if [[ "$perms" == "755" || "$perms" == "750" ]]; then
                log_success "Directorio de logs con permisos adecuados: $dir"
                ((monitoring_score += 3))
            fi
        fi
    done
    
    add_security_points $monitoring_score
}

# Verificar configuración de backup
verify_backup_security() {
    log_verification "Verificando configuración de backup..."
    
    local backup_score=0
    
    # Verificar scripts de backup
    local backup_scripts=(
        "/opt/webmin-backups/backup_secure.sh"
        "/opt/enterprise_backups/backup.sh"
    )
    
    for script in "${backup_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            log_success "Script de backup encontrado: $script"
            ((backup_score += 10))
            
            # Verificar permisos
            local perms
            perms=$(stat -c "%a" "$script" 2>/dev/null || stat -f "%A" "$script" 2>/dev/null)
            if [[ "$perms" == "700" || "$perms" == "755" ]]; then
                log_success "Script de backup con permisos adecuados"
                ((backup_score += 5))
            fi
        fi
    done
    
    # Verificar cron de backup
    if crontab -l 2>/dev/null | grep -q "backup"; then
        log_success "Backup programado en cron"
        ((backup_score += 15))
    else
        log_warning "Backup no programado en cron"
    fi
    
    # Verificar directorios de backup
    local backup_dirs=(
        "/opt/webmin-backups"
        "/opt/enterprise_backups"
    )
    
    for dir in "${backup_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local perms
            perms=$(stat -c "%a" "$dir" 2>/dev/null || stat -f "%A" "$dir" 2>/dev/null)
            if [[ "$perms" == "750" || "$perms" == "700" ]]; then
                log_success "Directorio de backup con permisos adecuados: $dir"
                ((backup_score += 5))
            fi
        fi
    done
    
    add_security_points $backup_score
}

# Verificar configuración de secretos
verify_secrets_management() {
    log_verification "Verificando gestión de secretos..."
    
    local secrets_score=0
    
    # Verificar gestor de secretos
    if [[ -f "/opt/webmin-security/secret_manager.sh" ]]; then
        log_success "Gestor de secretos encontrado"
        ((secrets_score += 15))
        
        # Verificar clave maestra
        if [[ -f "/opt/webmin-security/keys/master.key" ]]; then
            log_success "Clave maestra de secretos encontrada"
            ((secrets_score += 15))
            
            # Verificar permisos
            local perms
            perms=$(stat -c "%a" "/opt/webmin-security/keys/master.key" 2>/dev/null)
            if [[ "$perms" == "600" ]]; then
                log_success "Clave maestra con permisos adecuados"
                ((secrets_score += 10))
            else
                log_warning "Clave maestra con permisos inseguros: $perms"
            fi
        else
            log_warning "Clave maestra de secretos no encontrada"
        fi
    else
        log_error "Gestor de secretos no encontrado"
    fi
    
    # Verificar directorios seguros
    local secure_dirs=(
        "/opt/webmin-security/secrets"
        "/opt/webmin-security/config"
        "/opt/webmin-security/keys"
    )
    
    for dir in "${secure_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local perms
            perms=$(stat -c "%a" "$dir" 2>/dev/null || stat -f "%A" "$dir" 2>/dev/null)
            if [[ "$perms" == "700" || "$perms" == "750" ]]; then
                log_success "Directorio seguro con permisos adecuados: $dir"
                ((secrets_score += 5))
            else
                log_warning "Directorio seguro con permisos inseguros: $dir ($perms)"
            fi
        fi
    done
    
    add_security_points $secrets_score
}

# Verificar configuración del sistema
verify_system_security() {
    log_verification "Verificando configuración del sistema..."
    
    local system_score=0
    
    # Verificar usuarios sin contraseña
    local users_no_passwd
    users_no_passwd=$(awk -F: '($2 == "" || $2 == "*" || $2 == "!") && $1 != "nobody" { print $1 }' /etc/shadow 2>/dev/null || true)
    if [[ -z "$users_no_passwd" ]]; then
        log_success "No se detectaron usuarios sin contraseña"
        ((system_score += 15))
    else
        log_error "Usuarios sin contraseña detectados: $users_no_passwd"
    fi
    
    # Verificar usuarios con UID 0
    local root_users
    root_users=$(awk -F: '($3 == 0) { print $1 }' /etc/passwd 2>/dev/null || true)
    if [[ $(echo "$root_users" | wc -w) -eq 1 ]]; then
        log_success "Solo un usuario con UID 0: $root_users"
        ((system_score += 10))
    else
        log_warning "Múltiples usuarios con UID 0: $root_users"
    fi
    
    # Verificar configuración SSH
    if [[ -f "/etc/ssh/sshd_config" ]]; then
        if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
            log_success "Login root deshabilitado en SSH"
            ((system_score += 15))
        else
            log_warning "Login root permitido en SSH"
        fi
        
        if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
            log_success "Autenticación por contraseña deshabilitada en SSH"
            ((system_score += 10))
        else
            log_warning "Autenticación por contraseña habilitada en SSH"
        fi
        
        if grep -q "^Protocol 2" /etc/ssh/sshd_config; then
            log_success "Protocolo SSH 2 configurado"
            ((system_score += 5))
        fi
    fi
    
    # Verificar parámetros del kernel
    local sysctl_params=(
        "net.ipv4.tcp_syncookies=1"
        "net.ipv4.conf.all.send_redirects=0"
        "net.ipv4.conf.all.accept_redirects=0"
        "kernel.randomize_va_space=2"
    )
    
    for param in "${sysctl_params[@]}"; do
        local key="${param%=*}"
        local expected_value="${param#*=}"
        local current_value
        current_value=$(sysctl -n "$key" 2>/dev/null || echo "")
        
        if [[ "$current_value" == "$expected_value" ]]; then
            log_success "Parámetro seguro configurado: $key"
            ((system_score += 3))
        else
            log_warning "Parámetro inseguro: $key=$current_value (esperado: $expected_value)"
        fi
    done
    
    add_security_points $system_score
}

# Verificar configuración de red
verify_network_security() {
    log_verification "Verificando configuración de red..."
    
    local network_score=0
    
    # Verificar servicios innecesarios
    local unnecessary_services=(
        "telnet"
        "rsh"
        "rlogin"
        "ftp"
    )
    
    for service in "${unnecessary_services[@]}"; do
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            log_error "Servicio innecesario habilitado: $service"
        else
            log_success "Servicio innecesario deshabilitado: $service"
            ((network_score += 5))
        fi
    done
    
    # Verificar puertos abiertos
    if command -v netstat &> /dev/null; then
        local open_ports
        open_ports=$(netstat -tuln 2>/dev/null | grep LISTEN | wc -l)
        if [[ $open_ports -lt 10 ]]; then
            log_success "Puertos abiertos limitados: $open_ports"
            ((network_score += 10))
        else
            log_warning "Muchos puertos abiertos: $open_ports"
        fi
    fi
    
    # Verificar sticky bits
    local sticky_dirs=(
        "/tmp"
        "/var/tmp"
    )
    
    for dir in "${sticky_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local perms
            perms=$(stat -c "%a" "$dir" 2>/dev/null || stat -f "%A" "$dir" 2>/dev/null)
            if [[ "$perms" == "1777" ]]; then
                log_success "Sticky bit configurado en $dir"
                ((network_score += 5))
            else
                log_warning "Sticky bit no configurado en $dir: $perms"
            fi
        fi
    done
    
    add_security_points $network_score
}

# Generar reporte final
generate_final_report() {
    echo
    echo "========================================"
    echo -e "${PURPLE}REPORTE FINAL DE VERIFICACIÓN${NC}"
    echo "========================================"
    echo
    
    # Calcular calificación
    local grade="F"
    local status="FAILED"
    if [[ $SECURITY_SCORE -ge 90 ]]; then
        grade="A"
        status="EXCELLENTE"
    elif [[ $SECURITY_SCORE -ge 80 ]]; then
        grade="B"
        status="BUENO"
    elif [[ $SECURITY_SCORE -ge 70 ]]; then
        grade="C"
        status="ACEPTABLE"
    elif [[ $SECURITY_SCORE -ge 60 ]]; then
        grade="D"
        status="MEJORABLE"
    fi
    
    if [[ $SECURITY_SCORE -ge 70 ]]; then
        echo -e "${GREEN}✅ VERIFICACIÓN APROBADA${NC}"
    else
        echo -e "${RED}❌ VERIFICACIÓN FALLIDA${NC}"
    fi
    
    echo
    echo -e "${CYAN}Puntuación de Seguridad: $SECURITY_SCORE/$MAX_SCORE${NC}"
    echo -e "${CYAN}Calificación: $grade${NC}"
    echo -e "${CYAN}Estado: $status${NC}"
    echo
    
    # Mostrar resumen por categorías
    echo "========================================"
    echo -e "${YELLOW}RESUMEN POR CATEGORÍAS${NC}"
    echo "========================================"
    
    # Extraer y mostrar resultados del reporte
    echo -e "${BLUE}Componentes Verificados:${NC}"
    
    local categories=(
        "Webmin/Virtualmin"
        "Base de Datos"
        "SSL/TLS"
        "Firewall"
        "Monitoreo"
        "Backup"
        "Gestión de Secretos"
        "Sistema"
        "Red"
    )
    
    for category in "${categories[@]}"; do
        echo -e "  • $category"
    done
    
    echo
    echo "========================================"
    echo -e "${YELLOW}RECOMENDACIONES${NC}"
    echo "========================================"
    
    if [[ $SECURITY_SCORE -lt 100 ]]; then
        echo "Para mejorar la seguridad:"
        echo "1. Configure autenticación de dos factores donde sea posible"
        echo "2. Restrinja el acceso SSH a rangos IP específicos"
        echo "3. Habilite monitoreo continuo y alertas en tiempo real"
        echo "4. Realice auditorías de seguridad periódicas"
        echo "5. Mantenga actualizado el sistema y todos los componentes"
        echo "6. Implemente políticas de rotación de claves"
        echo "7. Configure backup offsite con encriptación"
        echo "8. Revise regularmente los logs de seguridad"
    fi
    
    echo
    echo "Reporte detallado guardado en: $VERIFICATION_REPORT"
    echo "========================================"
}

# Función principal
main() {
    echo "========================================"
    echo "  VERIFICACIÓN POST-INSTALACIÓN SEGURA"
    echo "  Webmin/Virtualmin Enterprise"
    echo "========================================"
    echo
    
    # Verificar privilegios
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root"
        exit 1
    fi
    
    # Inicializar reporte
    init_verification_report
    
    # Ejecutar verificaciones
    verify_webmin_installation
    verify_database_security
    verify_ssl_configuration
    verify_firewall_security
    verify_monitoring_security
    verify_backup_security
    verify_secrets_management
    verify_system_security
    verify_network_security
    
    # Finalizar reporte y mostrar resultados
    finalize_verification_report
    generate_final_report
    
    # Código de salida
    if [[ $SECURITY_SCORE -ge 70 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Ejecutar verificación
main "$@"
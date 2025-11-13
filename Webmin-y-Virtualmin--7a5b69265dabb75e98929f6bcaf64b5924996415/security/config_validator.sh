#!/bin/bash

# Validador de Configuración Segura para Despliegue
# Versión: 1.0.0
# Valida configuraciones antes del despliegue en producción

set -euo pipefail

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATION_REPORT="/tmp/config_validation_$(date +%Y%m%d_%H%M%S).json"
ERROR_COUNT=0
WARNING_COUNT=0

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging
log_validation() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [VALIDATION] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
    ((ERROR_COUNT++))
    echo "{\"type\": \"error\", \"message\": \"$1\", \"timestamp\": \"$(date -Iseconds)\"}" >> "$VALIDATION_REPORT"
}

log_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
    ((WARNING_COUNT++))
    echo "{\"type\": \"warning\", \"message\": \"$1\", \"timestamp\": \"$(date -Iseconds)\"}" >> "$VALIDATION_REPORT"
}

log_success() {
    echo -e "${GREEN}[OK] $1${NC}"
    echo "{\"type\": \"success\", \"message\": \"$1\", \"timestamp\": \"$(date -Iseconds)\"}" >> "$VALIDATION_REPORT"
}

# Inicializar reporte
init_validation_report() {
    cat > "$VALIDATION_REPORT" << EOF
{
  "validation_session": {
    "start_time": "$(date -Iseconds)",
    "validator_version": "1.0.0",
    "hostname": "$(hostname)",
    "user": "$(whoami)"
  },
  "validations": []
EOF
}

# Finalizar reporte
finalize_validation_report() {
    local status="FAILED"
    if [[ $ERROR_COUNT -eq 0 ]]; then
        status="PASSED"
    fi
    
    cat >> "$VALIDATION_REPORT" << EOF
  },
  "summary": {
    "end_time": "$(date -Iseconds)",
    "total_errors": $ERROR_COUNT,
    "total_warnings": $WARNING_COUNT,
    "status": "$status"
  }
}
EOF
    
    log_validation "Reporte de validación guardado en: $VALIDATION_REPORT"
}

# Validar archivos de configuración
validate_config_files() {
    log_validation "Validando archivos de configuración..."
    
    local config_files=(
        "/etc/webmin/config"
        "/etc/webmin/miniserv.conf"
        "/etc/virtualmin/config"
        "/etc/mysql/my.cnf"
        "/etc/apache2/apache2.conf"
        "/etc/nginx/nginx.conf"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            # Verificar permisos
            local perms
            perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%A" "$file" 2>/dev/null)
            
            case "$file" in
                */webmin/config|*/webmin/miniserv.conf|*/virtualmin/config)
                    if [[ "$perms" != "600" && "$perms" != "640" ]]; then
                        log_warning "Permisos inseguros en $file: $perms (recomendado: 600/640)"
                    else
                        log_success "Permisos correctos en $file: $perms"
                    fi
                    ;;
                */mysql/my.cnf)
                    if [[ "$perms" != "600" ]]; then
                        log_warning "Permisos inseguros en $file: $perms (recomendado: 600)"
                    else
                        log_success "Permisos correctos en $file: $perms"
                    fi
                    ;;
            esac
            
            # Buscar valores hardcoded
            if grep -q -E "(password|secret|key|token)\s*=\s*['\"][^'\"]*['\"]" "$file" 2>/dev/null; then
                log_error "Valores hardcoded detectados en $file"
            else
                log_success "No se detectaron valores hardcoded en $file"
            fi
        else
            log_warning "Archivo de configuración no encontrado: $file"
        fi
    done
}

# Validar variables de entorno
validate_environment_variables() {
    log_validation "Validando variables de entorno..."
    
    # Variables requeridas para producción
    local required_vars=(
        "DEPLOYMENT_ENV"
        "SERVER_ROLE"
        "BACKUP_LOCATION"
    )
    
    # Variables sensibles que deben estar encriptadas
    local sensitive_vars=(
        "DB_PASSWORD"
        "AWS_SECRET_ACCESS_KEY"
        "VIRTUALMIN_LICENSE_KEY"
        "GRAFANA_ADMIN_PASSWORD"
        "SMTP_PASSWORD"
    )
    
    # Verificar variables requeridas
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Variable de entorno requerida no definida: $var"
        else
            log_success "Variable de entorno definida: $var"
        fi
    done
    
    # Verificar variables sensibles
    for var in "${sensitive_vars[@]}"; do
        local value="${!var:-}"
        if [[ -n "$value" ]]; then
            # Verificar si parece estar encriptado (base64)
            if echo "$value" | base64 -d 2>/dev/null | grep -q .; then
                log_success "Variable sensible $var parece estar encriptada"
            else
                log_warning "Variable sensible $var parece estar en texto plano"
            fi
        fi
    done
}

# Validar configuración SSL/TLS
validate_ssl_configuration() {
    log_validation "Validando configuración SSL/TLS..."
    
    # Verificar certificados SSL
    local cert_paths=(
        "/etc/letsencrypt/live/"
        "/etc/ssl/certs/"
        "/etc/webmin/miniserv.pem"
    )
    
    for path in "${cert_paths[@]}"; do
        if [[ -d "$path" ]]; then
            # Buscar certificados .pem
            find "$path" -name "*.pem" -type f | while read -r cert; do
                # Verificar validez del certificado
                if openssl x509 -in "$cert" -noout -checkend 86400 2>/dev/null; then
                    log_success "Certificado válido: $cert"
                else
                    log_error "Certificado inválido o expirando pronto: $cert"
                fi
                
                # Verificar permisos
                local perms
                perms=$(stat -c "%a" "$cert" 2>/dev/null || stat -f "%A" "$cert" 2>/dev/null)
                if [[ "$perms" != "600" && "$perms" != "644" ]]; then
                    log_warning "Permisos inseguros en certificado $cert: $perms"
                fi
            done
        fi
    done
    
    # Verificar configuración SSL en Webmin
    if [[ -f "/etc/webmin/miniserv.conf" ]]; then
        if grep -q "^ssl=1" /etc/webmin/miniserv.conf; then
            log_success "SSL habilitado en Webmin"
        else
            log_error "SSL no habilitado en Webmin"
        fi
        
        if grep -q "^ssl_hsts=1" /etc/webmin/miniserv.conf; then
            log_success "HSTS habilitado en Webmin"
        else
            log_warning "HSTS no habilitado en Webmin"
        fi
    fi
}

# Validar configuración de base de datos
validate_database_configuration() {
    log_validation "Validando configuración de base de datos..."
    
    # Verificar configuración MySQL/MariaDB
    if [[ -f "/etc/mysql/my.cnf" ]]; then
        # Verificar bind-address
        local bind_address
        bind_address=$(grep "^bind-address" /etc/mysql/my.cnf | cut -d= -f2 | tr -d ' ')
        if [[ "$bind_address" == "127.0.0.1" || "$bind_address" == "::1" ]]; then
            log_success "Base de datos configurada para acceso local solamente"
        else
            log_warning "Base de datos accesible desde red: $bind_address"
        fi
        
        # Verificar configuración SSL
        if grep -q "^require_secure_transport" /etc/mysql/my.cnf; then
            log_success "Requerimiento SSL habilitado en base de datos"
        else
            log_warning "Requerimiento SSL no habilitado en base de datos"
        fi
        
        # Verificar logging de consultas lentas
        if grep -q "^slow_query_log.*=.*ON" /etc/mysql/my.cnf; then
            log_success "Logging de consultas lentas habilitado"
        else
            log_warning "Logging de consultas lentas no habilitado"
        fi
    fi
}

# Validar configuración de firewall
validate_firewall_configuration() {
    log_validation "Validando configuración de firewall..."
    
    # Verificar UFW
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            log_success "UFW está activo"
            
            # Verificar reglas críticas
            if ufw status | grep -q "10000/tcp"; then
                log_warning "Webmin accesible desde cualquier IP en UFW"
            fi
            
            if ufw status | grep -q "22/tcp"; then
                log_success "SSH permitido en UFW"
            fi
        else
            log_error "UFW no está activo"
        fi
    fi
    
    # Verificar firewalld
    if command -v firewall-cmd &> /dev/null; then
        if firewall-cmd --state &> /dev/null; then
            log_success "firewalld está activo"
            
            # Verificar zona por defecto
            local default_zone
            default_zone=$(firewall-cmd --get-default-zone)
            if [[ "$default_zone" == "drop" || "$default_zone" == "public" ]]; then
                log_success "Zona por defecto segura: $default_zone"
            else
                log_warning "Zona por defecto potencialmente insegura: $default_zone"
            fi
        else
            log_error "firewalld no está activo"
        fi
    fi
}

# Validar configuración de backup
validate_backup_configuration() {
    log_validation "Validando configuración de backup..."
    
    # Verificar scripts de backup
    local backup_scripts=(
        "/opt/webmin-backups/backup_secure.sh"
        "/opt/enterprise_backups/backup.sh"
        "/etc/cron.daily/backup"
    )
    
    local backup_found=false
    for script in "${backup_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            backup_found=true
            # Verificar permisos
            local perms
            perms=$(stat -c "%a" "$script" 2>/dev/null || stat -f "%A" "$script" 2>/dev/null)
            if [[ "$perms" == "700" || "$perms" == "755" ]]; then
                log_success "Script de backup encontrado con permisos adecuados: $script"
            else
                log_warning "Script de backup con permisos inusuales: $script ($perms)"
            fi
        fi
    done
    
    if [[ "$backup_found" == false ]]; then
        log_error "No se encontraron scripts de backup configurados"
    fi
    
    # Verificar configuración de cron
    if crontab -l 2>/dev/null | grep -q "backup"; then
        log_success "Backup programado en cron"
    else
        log_warning "Backup no programado en cron"
    fi
}

# Validar configuración de monitoreo
validate_monitoring_configuration() {
    log_validation "Validando configuración de monitoreo..."
    
    # Verificar servicios de monitoreo
    local monitoring_services=(
        "fail2ban"
        "auditd"
        "aide"
    )
    
    for service in "${monitoring_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_success "Servicio de monitoreo activo: $service"
        elif command -v "$service" &> /dev/null; then
            log_warning "Servicio de monitoreo instalado pero inactivo: $service"
        else
            log_warning "Servicio de monitoreo no instalado: $service"
        fi
    done
    
    # Verificar logs
    local log_dirs=(
        "/var/log/webmin"
        "/var/log/virtualmin"
        "/opt/webmin-logs"
    )
    
    for dir in "${log_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local perms
            perms=$(stat -c "%a" "$dir" 2>/dev/null || stat -f "%A" "$dir" 2>/dev/null)
            if [[ "$perms" == "755" || "$perms" == "750" ]]; then
                log_success "Directorio de logs con permisos adecuados: $dir"
            else
                log_warning "Directorio de logs con permisos inusuales: $dir ($perms)"
            fi
        fi
    done
}

# Validar seguridad de archivos y directorios
validate_file_security() {
    log_validation "Validando seguridad de archivos y directorios..."
    
    # Verificar archivos sensibles
    local sensitive_files=(
        "/etc/shadow"
        "/etc/gshadow"
        "/etc/passwd"
        "/etc/group"
        "/etc/ssh/sshd_config"
        "/root/.ssh/authorized_keys"
        "/root/.ssh/id_rsa"
    )
    
    for file in "${sensitive_files[@]}"; do
        if [[ -f "$file" ]]; then
            local perms
            perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%A" "$file" 2>/dev/null)
            
            case "$file" in
                /etc/shadow|/etc/gshadow)
                    if [[ "$perms" != "600" && "$perms" != "000" ]]; then
                        log_error "Permisos inseguros en $file: $perms"
                    else
                        log_success "Permisos correctos en $file: $perms"
                    fi
                    ;;
                /etc/passwd|/etc/group)
                    if [[ "$perms" != "644" ]]; then
                        log_warning "Permisos inusuales en $file: $perms (esperado: 644)"
                    else
                        log_success "Permisos correctos en $file: $perms"
                    fi
                    ;;
                /root/.ssh/*)
                    if [[ "$perms" != "600" ]]; then
                        log_error "Permisos inseguros en clave SSH: $file: $perms"
                    else
                        log_success "Permisos correctos en clave SSH: $file: $perms"
                    fi
                    ;;
            esac
        fi
    done
    
    # Verificar directorios con sticky bit
    local sticky_dirs=(
        "/tmp"
        "/var/tmp"
    )
    
    for dir in "${sticky_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local perms
            perms=$(stat -c "%a" "$dir" 2>/dev/null || stat -f "%A" "$dir" 2>/dev/null)
            if [[ "$perms" == "1777" ]]; then
                log_success "Sticky bit configurado correctamente en $dir"
            else
                log_warning "Sticky bit no configurado en $dir: $perms"
            fi
        fi
    done
}

# Validar configuración de red
validate_network_configuration() {
    log_validation "Validando configuración de red..."
    
    # Verificar parámetros del kernel de red
    local sysctl_params=(
        "net.ipv4.ip_forward=0"
        "net.ipv4.conf.all.send_redirects=0"
        "net.ipv4.conf.all.accept_redirects=0"
        "net.ipv4.conf.all.accept_source_route=0"
        "net.ipv4.tcp_syncookies=1"
    )
    
    for param in "${sysctl_params[@]}"; do
        local key="${param%=*}"
        local expected_value="${param#*=}"
        local current_value
        current_value=$(sysctl -n "$key" 2>/dev/null || echo "")
        
        if [[ "$current_value" == "$expected_value" ]]; then
            log_success "Parámetro de red seguro: $key=$current_value"
        else
            log_warning "Parámetro de red inseguro: $key=$current_value (esperado: $expected_value)"
        fi
    done
    
    # Verificar servicios de red innecesarios
    local unnecessary_services=(
        "telnet"
        "rsh"
        "rlogin"
        "ftp"
    )
    
    for service in "${unnecessary_services[@]}"; do
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            log_error "Servicio de red innecesario habilitado: $service"
        elif command -v "$service" &> /dev/null; then
            log_warning "Servicio de red innecesario instalado: $service"
        else
            log_success "Servicio innecesario no instalado: $service"
        fi
    done
}

# Validar configuración de usuarios y permisos
validate_user_permissions() {
    log_validation "Validando configuración de usuarios y permisos..."
    
    # Verificar usuarios sin contraseña
    local users_no_passwd
    users_no_passwd=$(awk -F: '($2 == "" || $2 == "*" || $2 == "!") && $1 != "nobody" && $1 != "nfsnobody" { print $1 }' /etc/shadow 2>/dev/null || true)
    
    if [[ -n "$users_no_passwd" ]]; then
        log_error "Usuarios sin contraseña detectados: $users_no_passwd"
    else
        log_success "No se detectaron usuarios sin contraseña"
    fi
    
    # Verificar usuarios con UID 0 (root)
    local root_users
    root_users=$(awk -F: '($3 == 0) { print $1 }' /etc/passwd 2>/dev/null || true)
    
    if [[ $(echo "$root_users" | wc -w) -gt 1 ]]; then
        log_warning "Múltiples usuarios con UID 0: $root_users"
    else
        log_success "Solo un usuario con UID 0: $root_users"
    fi
    
    # Verificar sudoers
    if [[ -f "/etc/sudoers" ]]; then
        if grep -q "NOPASSWD" /etc/sudoers; then
            log_warning "Configuración NOPASSWD detectada en sudoers"
        else
            log_success "No se detectó configuración NOPASSWD en sudoers"
        fi
    fi
}

# Validar configuración de servicios críticos
validate_critical_services() {
    log_validation "Validando configuración de servicios críticos..."
    
    # Servicios que deben estar activos
    local required_services=(
        "webmin"
        "ssh"
    )
    
    for service in "${required_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_success "Servicio crítico activo: $service"
        else
            log_error "Servicio crítico inactivo: $service"
        fi
    done
    
    # Servicios que deben estar configurados correctamente
    if [[ -f "/etc/ssh/sshd_config" ]]; then
        # Verificar configuración SSH
        if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
            log_success "Login root deshabilitado en SSH"
        else
            log_warning "Login root permitido en SSH"
        fi
        
        if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
            log_success "Autenticación por contraseña deshabilitada en SSH"
        else
            log_warning "Autenticación por contraseña habilitada en SSH"
        fi
        
        if grep -q "^Protocol 2" /etc/ssh/sshd_config; then
            log_success "Protocolo SSH 2 configurado"
        else
            log_warning "Protocolo SSH 2 no explícitamente configurado"
        fi
    fi
}

# Generar reporte final
generate_final_report() {
    echo
    echo "========================================"
    echo -e "${PURPLE}REPORTE FINAL DE VALIDACIÓN${NC}"
    echo "========================================"
    echo
    
    if [[ $ERROR_COUNT -eq 0 ]]; then
        echo -e "${GREEN}✅ VALIDACIÓN EXITOSA${NC}"
        echo "No se encontraron errores críticos"
        if [[ $WARNING_COUNT -gt 0 ]]; then
            echo -e "${YELLOW}⚠️  Se encontraron $WARNING_COUNT advertencias${NC}"
        fi
    else
        echo -e "${RED}❌ VALIDACIÓN FALLIDA${NC}"
        echo -e "${RED}Se encontraron $ERROR_COUNT errores críticos${NC}"
        if [[ $WARNING_COUNT -gt 0 ]]; then
            echo -e "${YELLOW}Adicionalmente, $WARNING_COUNT advertencias${NC}"
        fi
        echo
        echo -e "${RED}NO PROSEGUIR CON EL DESPLIEGUE HASTA CORREGIR LOS ERRORES${NC}"
    fi
    
    echo
    echo "Reporte detallado guardado en: $VALIDATION_REPORT"
    echo
    
    # Mostrar resumen de problemas
    if [[ $ERROR_COUNT -gt 0 || $WARNING_COUNT -gt 0 ]]; then
        echo "========================================"
        echo -e "${YELLOW}RESUMEN DE PROBLEMAS ENCONTRADOS${NC}"
        echo "========================================"
        
        # Extraer y mostrar errores y advertencias del reporte
        grep -E '"type": "(error|warning)"' "$VALIDATION_REPORT" | while read -r line; do
            local type
            type=$(echo "$line" | grep -o '"type": "[^"]*"' | cut -d'"' -f4)
            local message
            message=$(echo "$line" | grep -o '"message": "[^"]*"' | cut -d'"' -f4)
            
            if [[ "$type" == "error" ]]; then
                echo -e "${RED}ERROR: $message${NC}"
            else
                echo -e "${YELLOW}ADVERTENCIA: $message${NC}"
            fi
        done
    fi
    
    echo "========================================"
}

# Función principal
main() {
    echo "========================================"
    echo "  VALIDADOR DE CONFIGURACIÓN SEGURA"
    echo "  Para Despliegue en Producción"
    echo "========================================"
    echo
    
    # Inicializar reporte
    init_validation_report
    
    # Ejecutar validaciones
    validate_config_files
    validate_environment_variables
    validate_ssl_configuration
    validate_database_configuration
    validate_firewall_configuration
    validate_backup_configuration
    validate_monitoring_configuration
    validate_file_security
    validate_network_configuration
    validate_user_permissions
    validate_critical_services
    
    # Finalizar reporte y mostrar resultados
    finalize_validation_report
    generate_final_report
    
    # Código de salida
    if [[ $ERROR_COUNT -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Ejecutar validación
main "$@"
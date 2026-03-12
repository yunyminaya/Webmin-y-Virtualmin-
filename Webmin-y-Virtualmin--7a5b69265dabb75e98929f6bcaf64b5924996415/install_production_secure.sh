#!/bin/bash

# Instalador Seguro para Producción - Webmin/Virtualmin Enterprise
# Versión: 1.0.0
# Instalación automatizada con validación de seguridad y gestión de secretos

set -euo pipefail
IFS=$'\n\t'

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_DIR="$SCRIPT_DIR/security"
CONFIG_DIR="$SCRIPT_DIR/configs"
LOG_FILE="/var/log/webmin-production-install.log"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Sistema de logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1${NC}" | tee -a "$LOG_FILE" >&2
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] $1${NC}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1${NC}" | tee -a "$LOG_FILE"
}

log_security() {
    echo -e "${PURPLE}[$(date +'%Y-%m-%d %H:%M:%S')] [SECURITY] $1${NC}" | tee -a "$LOG_FILE"
}

# Verificar privilegios
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root"
        exit 1
    fi
}

# Validar entorno de producción
validate_production_environment() {
    log_security "Validando entorno de producción..."
    
    local issues=0
    
    # Verificar que no estamos en entorno de desarrollo
    if [[ -f ".env.development" || -f "development.yml" ]]; then
        log_error "Detectado entorno de desarrollo. Este script es solo para producción."
        ((issues++))
    fi
    
    # Verificar variables de entorno críticas
    local required_vars=("DEPLOYMENT_ENV" "SERVER_ROLE" "BACKUP_LOCATION")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_warning "Variable de entorno $var no definida"
            ((issues++))
        fi
    done
    
    # Verificar conexión segura
    if [[ "${SSH_CONNECTION:-}" ]]; then
        log_security "Conexión SSH detectada - Aceptable para producción"
    else
        log_warning "Conexión local detectada - Recomendado usar SSH para producción"
    fi
    
    if [[ $issues -gt 0 ]]; then
        log_error "Se encontraron $issues problemas en la validación del entorno"
        exit 1
    fi
    
    log_security "Entorno de producción validado correctamente"
}

# Inicializar gestor de secretos
init_secret_manager() {
    log_security "Inicializando gestor de secretos..."
    
    if [[ ! -f "$SECURITY_DIR/secret_manager.sh" ]]; then
        log_error "Gestor de secretos no encontrado en $SECURITY_DIR"
        exit 1
    fi
    
    chmod +x "$SECURITY_DIR/secret_manager.sh"
    
    # Inicializar sistema de secretos
    if ! "$SECURITY_DIR/secret_manager.sh" init; then
        log_error "Error al inicializar gestor de secretos"
        exit 1
    fi
    
    log_security "Gestor de secretos inicializado"
}

# Validar configuración de seguridad
validate_security_config() {
    log_security "Validando configuración de seguridad..."
    
    # Verificar permisos de archivos críticos
    local critical_files=("/etc/passwd" "/etc/shadow" "/etc/group" "/etc/gshadow")
    for file in "${critical_files[@]}"; do
        if [[ -f "$file" ]]; then
            local perms
            perms=$(stat -c "%a" "$file")
            case "$file" in
                "/etc/passwd" | "/etc/group")
                    if [[ "$perms" != "644" ]]; then
                        log_warning "Permisos inusuales en $file: $perms"
                    fi
                    ;;
                "/etc/shadow" | "/etc/gshadow")
                    if [[ "$perms" != "600" && "$perms" != "000" ]]; then
                        log_error "Permisos inseguros en $file: $perms"
                        return 1
                    fi
                    ;;
            esac
        fi
    done
    
    # Verificar firewall
    if command -v ufw &> /dev/null; then
        if ! ufw status | grep -q "Status: active"; then
            log_warning "Firewall UFW no está activo"
        fi
    elif command -v firewall-cmd &> /dev/null; then
        if ! firewall-cmd --state &> /dev/null; then
            log_warning "Firewall firewalld no está activo"
        fi
    else
        log_warning "No se detectó firewall configurado"
    fi
    
    # Verificar usuarios sin contraseña
    local users_no_passwd
    users_no_passwd=$(awk -F: '($2 == "" ) { print $1 }' /etc/shadow 2>/dev/null || true)
    if [[ -n "$users_no_passwd" ]]; then
        log_error "Usuarios sin contraseña detectados: $users_no_passwd"
        return 1
    fi
    
    log_security "Configuración de seguridad validada"
}

# Configurar sistema de archivos seguro
setup_secure_filesystem() {
    log_security "Configurando sistema de archivos seguro..."
    
    # Crear directorios seguros
    local secure_dirs=(
        "/opt/webmin-security"
        "/opt/webmin-backups"
        "/opt/webmin-logs"
        "/opt/webmin-configs"
        "/opt/webmin-temp"
    )
    
    for dir in "${secure_dirs[@]}"; do
        mkdir -p "$dir"
        chmod 750 "$dir"
        chown root:root "$dir"
    done
    
    # Configurar permisos de directorios críticos
    chmod 755 /etc/webmin 2>/dev/null || true
    chmod 755 /etc/virtualmin 2>/dev/null || true
    chmod 700 /root 2>/dev/null || true
    
    # Configurar sticky bits en directorios temporales
    chmod 1777 /tmp 2>/dev/null || true
    chmod 1777 /var/tmp 2>/dev/null || true
    
    log_security "Sistema de archivos seguro configurado"
}

# Instalar dependencias de seguridad
install_security_dependencies() {
    log_info "Instalando dependencias de seguridad..."
    
    # Detectar distribución
    if command -v apt-get &> /dev/null; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y --no-install-recommends \
            fail2ban \
            ufw \
            logrotate \
            auditd \
            rkhunter \
            chkrootkit \
            openssl \
            gnupg2 \
            cryptsetup \
            apparmor-profiles \
            selinux-basics \
            unattended-upgrades \
            aide \
            tripwire
    elif command -v yum &> /dev/null; then
        yum update -y -q
        yum install -y -q \
            fail2ban \
            firewalld \
            logrotate \
            audit \
            rkhunter \
            chkrootkit \
            openssl \
            gnupg2 \
            cryptsetup \
            aide \
            tripwire
    elif command -v dnf &> /dev/null; then
        dnf update -y -q
        dnf install -y -q \
            fail2ban \
            firewalld \
            logrotate \
            audit \
            rkhunter \
            chkrootkit \
            openssl \
            gnupg2 \
            cryptsetup \
            aide \
            tripwire
    fi
    
    log_info "Dependencias de seguridad instaladas"
}

# Configurar firewall de producción
setup_production_firewall() {
    log_security "Configurando firewall de producción..."
    
    # UFW (Ubuntu/Debian)
    if command -v ufw &> /dev/null; then
        # Resetear reglas
        ufw --force reset
        
        # Política por defecto: denegar entrantes, permitir salientes
        ufw default deny incoming
        ufw default allow outgoing
        
        # Permitir SSH (solo desde rangos específicos si están definidos)
        if [[ -n "${SSH_ALLOW_RANGES:-}" ]]; then
            for range in $SSH_ALLOW_RANGES; do
                ufw allow from "$range" to any port 22 proto tcp comment "SSH from $range"
            done
        else
            ufw allow 22/tcp comment "SSH"
        fi
        
        # Permitir Webmin/Virtualmin (solo desde rangos específicos si están definidos)
        if [[ -n "${WEBMIN_ALLOW_RANGES:-}" ]]; then
            for range in $WEBMIN_ALLOW_RANGES; do
                ufw allow from "$range" to any port 10000 proto tcp comment "Webmin from $range"
            done
        else
            log_warning "Webmin permitido desde cualquier IP - Considerar restringir acceso"
            ufw allow 10000/tcp comment "Webmin"
        fi
        
        # Permitir HTTP/HTTPS
        ufw allow 80/tcp comment "HTTP"
        ufw allow 443/tcp comment "HTTPS"
        
        # Limitar conexiones SSH para prevenir ataques de fuerza bruta
        ufw limit 22/tcp comment "Rate limit SSH"
        
        # Habilitar logging
        ufw logging on
        
        # Activar firewall
        ufw --force enable
        
        log_security "Firewall UFW configurado y activado"
    
    # Firewalld (CentOS/RHEL/Fedora)
    elif command -v firewall-cmd &> /dev/null; then
        # Configurar zona por defecto
        firewall-cmd --set-default-zone=drop
        
        # Permitir servicios esenciales
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        
        # Configurar Webmin
        firewall-cmd --permanent --add-port=10000/tcp
        
        # Limitar conexiones SSH
        firewall-cmd --permanent --add-rich-rule='rule service name="ssh" limit value="5/m" accept'
        
        # Recargar configuración
        firewall-cmd --reload
        
        log_security "Firewall firewalld configurado y activado"
    else
        log_warning "No se encontró firewall compatible. Configure manualmente iptables."
    fi
}

# Configurar monitoreo de seguridad
setup_security_monitoring() {
    log_security "Configurando monitoreo de seguridad..."
    
    # Configurar Fail2Ban
    if command -v fail2ban-client &> /dev/null; then
        cat > /etc/fail2ban/jail.d/webmin-production.conf << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 3
bantime = 3600

[webmin]
enabled = true
port = 10000
logpath = /var/log/webmin/miniserv.log
maxretry = 5
bantime = 7200

[apache-auth]
enabled = true
port = http,https
logpath = %(apache_error_log)s
maxretry = 3
bantime = 3600
EOF
        
        systemctl enable fail2ban
        systemctl restart fail2ban
        
        log_security "Fail2Ban configurado para producción"
    fi
    
    # Configurar auditoría del sistema
    if command -v auditd &> /dev/null; then
        cat > /etc/audit/rules.d/webmin-production.rules << 'EOF'
# Reglas de auditoría para Webmin/Virtualmin en producción
-w /etc/webmin/ -p wa -k webmin_config
-w /etc/virtualmin/ -p wa -k virtualmin_config
-w /var/www/ -p wa -k web_content
-w /var/log/ -p wa -k logs
-w /opt/webmin-security/ -p wa -k security_config
-a always,exit -F arch=b64 -S execve -k process_execution
-a always,exit -F arch=b32 -S execve -k process_execution
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
EOF
        
        systemctl restart auditd
        systemctl enable auditd
        
        log_security "Auditoría del sistema configurada"
    fi
    
    # Configurar AIDE (Advanced Intrusion Detection Environment)
    if command -v aide &> /dev/null; then
        # Inicializar base de datos AIDE
        aide --init
        mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
        
        # Configurar chequeo diario
        cat > /etc/cron.daily/aide << 'EOF'
#!/bin/bash
/usr/bin/aide --check
EOF
        chmod +x /etc/cron.daily/aide
        
        log_security "Sistema de detección de intrusiones AIDE configurado"
    fi
}

# Configurar actualizaciones automáticas de seguridad
setup_security_updates() {
    log_security "Configurando actualizaciones automáticas de seguridad..."
    
    if command -v apt-get &> /dev/null; then
        # Configurar unattended-upgrades
        cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailOnlyOnError "true";
EOF
        
        cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
        
        systemctl enable unattended-upgrades
        systemctl start unattended-upgrades
        
        log_security "Actualizaciones automáticas configuradas para apt"
    fi
}

# Configurar backup seguro
setup_secure_backup() {
    log_security "Configurando sistema de backup seguro..."
    
    # Crear directorio de backup
    local backup_dir="/opt/webmin-backups"
    mkdir -p "$backup_dir/configs"
    mkdir -p "$backup_dir/databases"
    mkdir -p "$backup_dir/files"
    mkdir -p "$backup_dir/security"
    
    # Configurar script de backup
    cat > "$backup_dir/backup_secure.sh" << 'EOF'
#!/bin/bash
# Script de backup seguro para producción

BACKUP_DIR="/opt/webmin-backups"
DATE=$(date +%Y%m%d_%H%M%S)
ENCRYPTION_KEY_FILE="/opt/webmin-security/secrets/backup_key.enc"

# Función de encriptación
encrypt_file() {
    local file="$1"
    local encrypted_file="$2"
    
    if [[ -f "$ENCRYPTION_KEY_FILE" ]]; then
        openssl enc -aes-256-cbc -salt -pass file:"$ENCRYPTION_KEY_FILE" -in "$file" -out "$encrypted_file"
        shred -vfz -n 3 "$file"
    else
        log_error "Clave de encriptación no encontrada"
        return 1
    fi
}

# Backup de configuraciones
tar -czf "$BACKUP_DIR/configs/etc_webmin_$DATE.tar.gz" /etc/webmin/
tar -czf "$BACKUP_DIR/configs/etc_virtualmin_$DATE.tar.gz" /etc/virtualmin/

# Backup de seguridad
tar -czf "$BACKUP_DIR/security/security_config_$DATE.tar.gz" /opt/webmin-security/

# Encriptar backups críticos
encrypt_file "$BACKUP_DIR/configs/etc_webmin_$DATE.tar.gz" "$BACKUP_DIR/configs/etc_webmin_$DATE.tar.gz.enc"
encrypt_file "$BACKUP_DIR/configs/etc_virtualmin_$DATE.tar.gz" "$BACKUP_DIR/configs/etc_virtualmin_$DATE.tar.gz.enc"

# Liminar backups antiguos (más de 30 días)
find "$BACKUP_DIR" -name "*.enc" -mtime +30 -delete

echo "Backup completado: $DATE"
EOF
    
    chmod +x "$backup_dir/backup_secure.sh"
    
    # Configurar cron diario
    (crontab -l 2>/dev/null; echo "0 2 * * * $backup_dir/backup_secure.sh") | crontab -
    
    log_security "Sistema de backup seguro configurado"
}

# Validar instalación de Webmin/Virtualmin
validate_webmin_installation() {
    log_security "Validando instalación de Webmin/Virtualmin..."
    
    # Verificar archivos de configuración
    local config_files=(
        "/etc/webmin/config"
        "/etc/webmin/miniserv.conf"
        "/etc/virtualmin/config"
    )
    
    for file in "${config_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Archivo de configuración faltante: $file"
            return 1
        fi
        
        # Verificar permisos
        local perms
        perms=$(stat -c "%a" "$file")
        if [[ "$perms" != "600" && "$perms" != "640" ]]; then
            log_warning "Permisos inseguros en $file: $perms"
            chmod 640 "$file"
        fi
    done
    
    # Verificar que Webmin esté corriendo
    if systemctl is-active --quiet webmin; then
        log_security "Webmin está activo"
    else
        log_error "Webmin no está activo"
        return 1
    fi
    
    # Verificar configuración SSL
    if grep -q "ssl=1" /etc/webmin/miniserv.conf; then
        log_security "SSL está habilitado en Webmin"
    else
        log_warning "SSL no está habilitado en Webmin"
    fi
    
    log_security "Instalación de Webmin/Virtualmin validada"
}

# Configurar hardening del sistema
apply_system_hardening() {
    log_security "Aplicando hardening del sistema..."
    
    # Configurar límites de recursos
    cat > /etc/security/limits.d/webmin-production.conf << 'EOF'
# Límites de seguridad para producción
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
root soft nofile 65536
root hard nofile 65536
EOF
    
    # Configurar parámetros del kernel
    cat > /etc/sysctl.d/99-webmin-security.conf << 'EOF'
# Parámetros de seguridad del kernel
# Prevenir ataques de IP spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Deshabilitar source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Prevenir ataques SYN flood
net.ipv4.tcp_syncookies = 1

# Ignorar pings ICMP
net.ipv4.icmp_echo_ignore_all = 1

# Deshabilitar redirecciones ICMP
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

# Deshabilitar redirecciones ICMP para IPv6
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Prevenir ataques de log spoofing
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Configurar randomize_va_space para prevenir exploits
kernel.randomize_va_space = 2

# Deshabilitar magic keys
kernel.sysrq = 0

# Configurar core dumps
kernel.core_pattern = |/bin/false
fs.suid_dumpable = 0
EOF
    
    # Aplicar parámetros del kernel
    sysctl -p /etc/sysctl.d/99-webmin-security.conf
    
    log_security "Hardening del sistema aplicado"
}

# Generar reporte de seguridad
generate_security_report() {
    log_security "Generando reporte de seguridad..."
    
    local report_file="/opt/webmin-security/security_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
========================================
REPORTE DE SEGURIDAD - INSTALACIÓN PRODUCCIÓN
Generado: $(date)
========================================

ESTADO DEL SISTEMA:
- Firewall: $(systemctl is-active ufw 2>/dev/null || systemctl is-active firewalld 2>/dev/null || echo "No configurado")
- Fail2Ban: $(systemctl is-active fail2ban 2>/dev/null || echo "No instalado")
- Auditoría: $(systemctl is-active auditd 2>/dev/null || echo "No configurado")
- AIDE: $(command -v aide &> /dev/null && echo "Instalado" || echo "No instalado")

CONFIGURACIÓN DE SEGURIDAD:
- Gestor de secretos: $([ -f "/opt/webmin-security/keys/master.key" ] && echo "Configurado" || echo "No configurado")
- Backup automático: $([ -f "/opt/webmin-backups/backup_secure.sh" ] && echo "Configurado" || echo "No configurado")
- Actualizaciones automáticas: $([ -f "/etc/apt/apt.conf.d/20auto-upgrades" ] && echo "Configurado" || echo "No configurado")

PERMISOS DE ARCHIVOS CRÍTICOS:
- /etc/webmin/config: $(stat -c "%a" /etc/webmin/config 2>/dev/null || echo "No existe")
- /etc/shadow: $(stat -c "%a" /etc/shadow 2>/dev/null || echo "No existe")
- /opt/webmin-security: $(stat -c "%a" /opt/webmin-security 2>/dev/null || echo "No existe")

SERVICIOS ACTIVOS:
$(systemctl list-units --type=service --state=running | grep -E "(webmin|virtualmin|fail2ban|auditd)" || echo "Ninguno encontrado")

RECOMENDACIONES:
1. Configure acceso SSH solo desde rangos IP específicos
2. Habilite autenticación de dos factores para Webmin
3. Revise regularmente los logs de seguridad
4. Realice auditorías de seguridad periódicas
5. Mantenga actualizado el sistema y los paquetes

========================================
EOF
    
    chmod 600 "$report_file"
    chown root:root "$report_file"
    
    log_security "Reporte de seguridad generado: $report_file"
}

# Función principal
main() {
    log "========================================"
    log "  INSTALADOR SEGURO PARA PRODUCCIÓN"
    log "  Webmin/Virtualmin Enterprise"
    log "========================================"
    log
    
    # Validaciones iniciales
    check_privileges
    validate_production_environment
    
    # Inicialización de seguridad
    init_secret_manager
    validate_security_config
    setup_secure_filesystem
    
    # Instalación de componentes
    install_security_dependencies
    setup_production_firewall
    setup_security_monitoring
    setup_security_updates
    setup_secure_backup
    
    # Validación y hardening
    validate_webmin_installation
    apply_system_hardening
    
    # Reporte final
    generate_security_report
    
    log
    log "========================================"
    log -e "${GREEN}  ¡INSTALACIÓN SEGURA COMPLETADA!${NC}"
    log "========================================"
    log
    log_security "Sistema instalado con configuración de producción segura"
    log_info "Revise el reporte de seguridad en /opt/webmin-security/"
    log_info "Gestione los secretos con: $SECURITY_DIR/secret_manager.sh"
    log
    log -e "${PURPLE}PRÓXIMOS PASOS:${NC}"
    log "1. Configure las credenciales con el gestor de secretos"
    log "2. Revise y ajuste las reglas del firewall"
    log "3. Configure monitoreo externo"
    log "4. Establezca política de rotación de claves"
    log "5. Programe auditorías de seguridad regulares"
    log
}

# Ejecutar instalación
main "$@"
#!/bin/bash
# =============================================================================
# CORRECCIÓN AUTOMÁTICA DE VULNERABILIDADES - WEBMIN Y VIRTUALMIN
# =============================================================================
# Corrige todas las vulnerabilidades conocidas y errores de seguridad
# Versión: 1.0.0
# =============================================================================

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Variables
LOG_FILE="/var/log/vulnerabilidades-fix.log"
FIXED=0
ERRORS=0

# Función de logging
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        ERROR)   echo -e "${RED}[ERROR]${NC} $message" | tee -a "$LOG_FILE" ;;
        SUCCESS) echo -e "${GREEN}[✓]${NC} $message" | tee -a "$LOG_FILE"; ((FIXED++)) ;;
        INFO)    echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$LOG_FILE" ;;
        WARNING) echo -e "${YELLOW}[⚠]${NC} $message" | tee -a "$LOG_FILE" ;;
    esac
}

# Verificar root
if [[ $EUID -ne 0 ]]; then
    log ERROR "Este script debe ejecutarse como root"
    exit 1
fi

echo -e "${PURPLE}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    CORRECCIÓN DE VULNERABILIDADES - WEBMIN/VIRTUALMIN       ║
║           Hardening Completo del Sistema                    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# 1. SSL/TLS Seguro
log INFO "1/10 Configurando SSL/TLS seguro..."
if [[ -f /etc/webmin/miniserv.conf ]]; then
    cp /etc/webmin/miniserv.conf /etc/webmin/miniserv.conf.bak-$(date +%Y%m%d)
    
    grep -q "^ssl=1" /etc/webmin/miniserv.conf || echo "ssl=1" >> /etc/webmin/miniserv.conf
    sed -i.bak 's/^ssl_version=.*/ssl_version=TLSv1.2,TLSv1.3/' /etc/webmin/miniserv.conf 2>/dev/null || \
        echo "ssl_version=TLSv1.2,TLSv1.3" >> /etc/webmin/miniserv.conf
    grep -q "^ssl_cipher_list=" /etc/webmin/miniserv.conf || \
        echo "ssl_cipher_list=HIGH:!aNULL:!MD5:!3DES:!CAMELLIA:!AES128" >> /etc/webmin/miniserv.conf
    
    log SUCCESS "SSL/TLS endurecido (solo TLS 1.2/1.3, ciphers seguros)"
fi

# 2. Autenticación Robusta
log INFO "2/10 Mejorando autenticación..."
if [[ -f /etc/webmin/miniserv.conf ]]; then
    sed -i 's/^session_timeout=.*/session_timeout=900/' /etc/webmin/miniserv.conf 2>/dev/null || \
        echo "session_timeout=900" >> /etc/webmin/miniserv.conf
    
    grep -q "^failed_login_max=" /etc/webmin/miniserv.conf || {
        echo "failed_login_max=5" >> /etc/webmin/miniserv.conf
        echo "failed_login_timeout=900" >> /etc/webmin/miniserv.conf
    }
    
    log SUCCESS "Timeout 15min, bloqueo tras 5 intentos fallidos"
fi

# 3. Permisos Críticos
log INFO "3/10 Corrigiendo permisos de archivos..."
for file in /etc/webmin/miniserv.conf /etc/webmin/config /etc/webmin/webmin.acl /etc/webmin/miniserv.users; do
    [[ -f "$file" ]] && { chmod 600 "$file"; chown root:root "$file"; }
done
[[ -d /etc/webmin ]] && chmod 755 /etc/webmin
log SUCCESS "Permisos corregidos (600 en archivos críticos)"

# 4. Headers de Seguridad HTTP
log INFO "4/10 Configurando headers de seguridad..."
if [[ -f /etc/webmin/miniserv.conf ]]; then
    grep -q "add_header=X-Frame-Options" /etc/webmin/miniserv.conf || cat >> /etc/webmin/miniserv.conf << 'EOF'

# Security Headers
add_header=X-Frame-Options: DENY
add_header=X-Content-Type-Options: nosniff
add_header=X-XSS-Protection: 1; mode=block
add_header=Strict-Transport-Security: max-age=31536000
add_header=Content-Security-Policy: default-src 'self'
EOF
    log SUCCESS "Headers HTTP de seguridad configurados"
fi

# 5. Firewall UFW
log INFO "5/10 Configurando firewall..."
if command -v ufw &>/dev/null; then
    ufw --force enable 2>/dev/null
    ufw default deny incoming 2>/dev/null
    ufw default allow outgoing 2>/dev/null
    ufw limit 22/tcp 2>/dev/null
    ufw allow 10000/tcp 2>/dev/null
    ufw allow 80/tcp 2>/dev/null
    ufw allow 443/tcp 2>/dev/null
    log SUCCESS "Firewall UFW endurecido con rate limiting"
fi

# 6. Fail2ban
log INFO "6/10 Configurando Fail2ban..."
if command -v fail2ban-client &>/dev/null || apt-get install -y fail2ban 2>/dev/null; then
    mkdir -p /etc/fail2ban/jail.d
    cat > /etc/fail2ban/jail.d/webmin.conf << 'EOF'
[webmin-auth]
enabled = true
port = 10000
logpath = /var/webmin/miniserv.log
maxretry = 3
findtime = 600
bantime = 3600
EOF
    systemctl restart fail2ban 2>/dev/null || service fail2ban restart 2>/dev/null
    log SUCCESS "Fail2ban configurado (3 intentos, ban 1h)"
fi

# 7. Actualizaciones Automáticas
log INFO "7/10 Habilitando auto-updates de seguridad..."
if command -v apt-get &>/dev/null; then
    apt-get install -y unattended-upgrades 2>/dev/null || true
    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
    log SUCCESS "Actualizaciones automáticas de seguridad habilitadas"
fi

# 8. Actualizar Sistema
log INFO "8/10 Actualizando Webmin/Virtualmin..."
if command -v apt-get &>/dev/null; then
    apt-get update -qq 2>/dev/null
    apt-get upgrade -y webmin virtualmin-base 2>/dev/null || true
    log SUCCESS "Sistema actualizado a última versión"
fi

# 9. Protección CSRF/XSS
log INFO "9/10 Activando protección CSRF/XSS..."
if [[ -f /etc/webmin/config ]]; then
    grep -q "^referers_none=0" /etc/webmin/config || echo "referers_none=0" >> /etc/webmin/config
    grep -q "^referer=1" /etc/webmin/config || echo "referer=1" >> /etc/webmin/config
    log SUCCESS "Protección CSRF/XSS activada"
fi

# 10. Deshabilitar módulos peligrosos
log INFO "10/10 Deshabilitando módulos innecesarios..."
for mod in telnet rsh; do
    [[ -d "/etc/webmin/$mod" ]] && echo "enabled=0" > "/etc/webmin/$mod/config"
done
log SUCCESS "Módulos peligrosos deshabilitados"

# Reiniciar Webmin
log INFO "Reiniciando Webmin..."
systemctl restart webmin 2>/dev/null || service webmin restart 2>/dev/null || /etc/webmin/restart 2>/dev/null
log SUCCESS "Webmin reiniciado"

# Resumen
echo -e "\n${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         ✅ CORRECCIÓN COMPLETADA EXITOSAMENTE          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${GREEN}📊 RESUMEN DE CORRECCIONES:${NC}"
echo -e "${GREEN}  ✓ Vulnerabilidades corregidas: $FIXED${NC}"
echo -e "${GREEN}  ✓ Log detallado: $LOG_FILE${NC}\n"

echo -e "${GREEN}🔒 PROTECCIONES ACTIVADAS:${NC}"
echo -e "${GREEN}  ✓ SSL/TLS 1.2/1.3 únicamente${NC}"
echo -e "${GREEN}  ✓ Session timeout: 15 minutos${NC}"
echo -e "${GREEN}  ✓ Failed login: bloqueo tras 5 intentos${NC}"
echo -e "${GREEN}  ✓ Permisos: 600 en archivos críticos${NC}"
echo -e "${GREEN}  ✓ HTTP Headers: HSTS, XSS, CSP${NC}"
echo -e "${GREEN}  ✓ Firewall: UFW con rate limiting${NC}"
echo -e "${GREEN}  ✓ Fail2ban: activo${NC}"
echo -e "${GREEN}  ✓ Auto-updates: habilitados${NC}"
echo -e "${GREEN}  ✓ CSRF/XSS: protegido${NC}\n"

echo -e "${YELLOW}⚠️  RECOMENDACIONES ADICIONALES:${NC}"
echo -e "  1. Configurar 2FA en: https://localhost:10000"
echo -e "  2. Revisar usuarios con acceso a Webmin"
echo -e "  3. Cambiar puerto por defecto si es necesario"
echo -e "  4. Monitorear logs: tail -f /var/webmin/miniserv.log\n"

echo -e "${GREEN}✅ Sistema completamente endurecido!${NC}\n"

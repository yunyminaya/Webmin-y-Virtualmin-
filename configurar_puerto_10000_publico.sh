#!/bin/bash

# ============================================================================
# CONFIGURADOR DEL PUERTO 10000 PARA ACCESO PÚBLICO
# ============================================================================
# Descripción: Script para configurar Webmin/Virtualmin para acceso público
# Autor: Sistema Webmin/Virtualmin
# Versión: 1.0
# ============================================================================

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función de logging
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "SUCCESS")
            echo -e "${GREEN}[✓]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[✗]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[⚠]${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}[ℹ]${NC} $message"
            ;;
        *)
            echo "[$timestamp] $message"
            ;;
    esac
}

# Verificar si se ejecuta como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Este script debe ejecutarse como root"
        exit 1
    fi
}

# Verificar si Webmin está instalado
check_webmin() {
    if [[ ! -f "/etc/webmin/miniserv.conf" ]]; then
        log "ERROR" "Webmin no está instalado o no se encuentra la configuración"
        exit 1
    fi
    log "SUCCESS" "Webmin detectado correctamente"
}

# Crear backup de configuración
backup_config() {
    local config_file="/etc/webmin/miniserv.conf"
    local backup_file="${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if cp "$config_file" "$backup_file"; then
        log "SUCCESS" "Backup creado: $backup_file"
    else
        log "ERROR" "No se pudo crear backup de la configuración"
        exit 1
    fi
}

# Detectar firewall disponible
detect_firewall() {
    if command -v ufw >/dev/null 2>&1; then
        echo "ufw"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        echo "firewalld"
    elif command -v iptables >/dev/null 2>&1; then
        echo "iptables"
    else
        echo "none"
    fi
}

# Configurar firewall
configure_firewall() {
    local firewall_type=$(detect_firewall)
    
    case "$firewall_type" in
        "ufw")
            log "INFO" "Configurando UFW..."
            ufw --force enable >/dev/null 2>&1
            ufw allow 10000/tcp >/dev/null 2>&1
            ufw allow 22/tcp >/dev/null 2>&1  # SSH por seguridad
            log "SUCCESS" "UFW configurado - Puerto 10000 permitido"
            ;;
        "firewalld")
            log "INFO" "Configurando firewalld..."
            systemctl enable firewalld >/dev/null 2>&1
            systemctl start firewalld >/dev/null 2>&1
            firewall-cmd --permanent --add-port=10000/tcp >/dev/null 2>&1
            firewall-cmd --permanent --add-port=22/tcp >/dev/null 2>&1  # SSH por seguridad
            firewall-cmd --reload >/dev/null 2>&1
            log "SUCCESS" "firewalld configurado - Puerto 10000 permitido"
            ;;
        "iptables")
            log "INFO" "Configurando iptables..."
            iptables -A INPUT -p tcp --dport 10000 -j ACCEPT
            iptables -A INPUT -p tcp --dport 22 -j ACCEPT  # SSH por seguridad
            # Intentar guardar reglas
            if command -v iptables-save >/dev/null 2>&1; then
                iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
            fi
            log "SUCCESS" "iptables configurado - Puerto 10000 permitido"
            ;;
        "none")
            log "WARNING" "No se detectó firewall - Configuración insegura"
            log "WARNING" "Se recomienda instalar y configurar UFW o firewalld"
            ;;
    esac
}

# Configurar Webmin para acceso público
configure_webmin_public() {
    local config_file="/etc/webmin/miniserv.conf"
    
    log "INFO" "Configurando Webmin para acceso público..."
    
    # Configurar bind para acceso público
    if grep -q "^bind=" "$config_file"; then
        sed -i 's/^bind=.*/bind=0.0.0.0/' "$config_file"
    else
        echo "bind=0.0.0.0" >> "$config_file"
    fi
    
    # Configurar puerto
    if grep -q "^port=" "$config_file"; then
        sed -i 's/^port=.*/port=10000/' "$config_file"
    else
        echo "port=10000" >> "$config_file"
    fi
    
    # Configurar listen
    if grep -q "^listen=" "$config_file"; then
        sed -i 's/^listen=.*/listen=10000/' "$config_file"
    else
        echo "listen=10000" >> "$config_file"
    fi
    
    # Habilitar SSL
    if grep -q "^ssl=" "$config_file"; then
        sed -i 's/^ssl=.*/ssl=1/' "$config_file"
    else
        echo "ssl=1" >> "$config_file"
    fi
    
    # Configuraciones de seguridad SSL
    local ssl_configs=(
        "ssl_redirect=1"
        "no_ssl2=1"
        "no_ssl3=1"
        "no_tls1=1"
        "no_tls1_1=1"
        "session=1"
        "session_timeout=1800"
    )
    
    for config in "${ssl_configs[@]}"; do
        local key=$(echo "$config" | cut -d'=' -f1)
        if grep -q "^${key}=" "$config_file"; then
            sed -i "s/^${key}=.*/${config}/" "$config_file"
        else
            echo "$config" >> "$config_file"
        fi
    done
    
    log "SUCCESS" "Configuración de Webmin actualizada"
}

# Generar certificado SSL si no existe
generate_ssl_cert() {
    local cert_file="/etc/webmin/miniserv.pem"
    
    if [[ ! -f "$cert_file" ]] || [[ ! -s "$cert_file" ]]; then
        log "INFO" "Generando certificado SSL autofirmado..."
        
        local hostname=$(hostname -f 2>/dev/null || hostname)
        
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$cert_file" \
            -out "$cert_file" \
            -subj "/C=ES/ST=Madrid/L=Madrid/O=Webmin/CN=${hostname}" \
            >/dev/null 2>&1
        
        chmod 600 "$cert_file"
        log "SUCCESS" "Certificado SSL generado: $cert_file"
    else
        log "SUCCESS" "Certificado SSL ya existe: $cert_file"
    fi
}

# Reiniciar servicios
restart_services() {
    log "INFO" "Reiniciando servicios..."
    
    if systemctl restart webmin >/dev/null 2>&1; then
        log "SUCCESS" "Webmin reiniciado correctamente"
    else
        log "ERROR" "Error al reiniciar Webmin"
        return 1
    fi
    
    # Reiniciar Usermin si existe
    if systemctl is-active usermin >/dev/null 2>&1; then
        systemctl restart usermin >/dev/null 2>&1
        log "SUCCESS" "Usermin reiniciado correctamente"
    fi
    
    # Esperar a que los servicios inicien
    sleep 3
}

# Verificar configuración
verify_configuration() {
    log "INFO" "Verificando configuración..."
    
    # Verificar puerto en escucha
    local port_check=false
    
    if command -v ss >/dev/null 2>&1; then
        if ss -tlnp | grep -q ":10000.*0.0.0.0"; then
            port_check=true
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -tlnp | grep -q ":10000.*0.0.0.0"; then
            port_check=true
        fi
    fi
    
    if $port_check; then
        log "SUCCESS" "Puerto 10000 escuchando en todas las interfaces (0.0.0.0)"
    else
        log "ERROR" "Puerto 10000 no está escuchando correctamente"
        return 1
    fi
    
    # Verificar acceso HTTPS
    if command -v curl >/dev/null 2>&1; then
        if curl -k -s --connect-timeout 5 "https://localhost:10000" >/dev/null 2>&1; then
            log "SUCCESS" "Acceso HTTPS verificado"
        else
            log "WARNING" "No se pudo verificar acceso HTTPS"
        fi
    fi
}

# Mostrar información de acceso
show_access_info() {
    local server_ip
    
    # Intentar obtener IP del servidor
    if command -v hostname >/dev/null 2>&1; then
        server_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "TU-IP-SERVIDOR")
    else
        server_ip="TU-IP-SERVIDOR"
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "🎉 CONFIGURACIÓN COMPLETADA EXITOSAMENTE"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "📍 URLS DE ACCESO:"
    echo "   • Webmin:     https://${server_ip}:10000"
    echo "   • Virtualmin: https://${server_ip}:10000/virtual-server/"
    echo ""
    echo "🔐 ACCESO LOCAL (alternativo):"
    echo "   • Webmin:     https://localhost:10000"
    echo "   • Virtualmin: https://localhost:10000/virtual-server/"
    echo ""
    echo "⚠️  NOTAS IMPORTANTES:"
    echo "   • Use las credenciales de root del sistema"
    echo "   • El certificado SSL es autofirmado (aceptar en navegador)"
    echo "   • Firewall configurado para permitir puerto 10000"
    echo "   • Configuración respaldada automáticamente"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
}

# Función principal
main() {
    echo "🚀 CONFIGURADOR DEL PUERTO 10000 PARA ACCESO PÚBLICO"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    # Verificaciones iniciales
    check_root
    check_webmin
    
    # Crear backup
    backup_config
    
    # Configurar firewall
    configure_firewall
    
    # Configurar Webmin
    configure_webmin_public
    
    # Generar certificado SSL
    generate_ssl_cert
    
    # Reiniciar servicios
    restart_services
    
    # Verificar configuración
    verify_configuration
    
    # Mostrar información de acceso
    show_access_info
    
    log "SUCCESS" "¡Configuración completada exitosamente!"
}

# Ejecutar función principal
main "$@"
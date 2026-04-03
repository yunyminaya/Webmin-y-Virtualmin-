#!/bin/bash

# =============================================================================
# SCRIPT DE VALIDACIÓN COMPLETA - WEBMIN/VIRTUALMIN
# Verifica que todos los componentes estén instalados y funcionando correctamente
# Uso: ./validate_installation.sh
# =============================================================================

set -euo pipefail

# Configuración de colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables globales
VALIDATION_LOG="/tmp/installation_validation_$(date +%Y%m%d_%H%M%S).log"
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

# Función de logging
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")  echo -e "${BLUE}[INFO]${NC}  $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC}  $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        "PASS") echo -e "${GREEN}✓${NC} $message" ;;
        "FAIL") echo -e "${RED}✗${NC} $message" ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$VALIDATION_LOG"
}

# Función para contar checks
count_check() {
    local result="$1"
    ((TOTAL_CHECKS++))
    
    case "$result" in
        "PASS") ((PASSED_CHECKS++)) ;;
        "FAIL") ((FAILED_CHECKS++)) ;;
        "WARN") ((WARNINGS++)) ;;
    esac
}

# Validar sistema operativo
validate_os() {
    log "INFO" "Validando sistema operativo..."
    
    if [[ ! -f /etc/os-release ]]; then
        log "FAIL" "No se puede determinar el sistema operativo"
        count_check "FAIL"
        return 1
    fi
    
    # shellcheck disable=SC1091
    source /etc/os-release
    
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        log "FAIL" "Sistema operativo no soportado: $ID"
        count_check "FAIL"
        return 1
    fi
    
    log "PASS" "Sistema operativo compatible: $PRETTY_NAME"
    count_check "PASS"
    return 0
}

# Validar recursos del sistema
validate_system_resources() {
    log "INFO" "Validando recursos del sistema..."
    
    # Verificar RAM
    local total_ram_gb
    total_ram_gb=$(free -g | awk 'NR==2{print $2}')
    if [[ $total_ram_gb -lt 2 ]]; then
        log "WARN" "RAM baja: ${total_ram_gb}GB (recomendado: 2GB+)"
        count_check "WARN"
    else
        log "PASS" "RAM suficiente: ${total_ram_gb}GB"
        count_check "PASS"
    fi
    
    # Verificar espacio en disco
    local available_disk_gb
    available_disk_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $available_disk_gb -lt 10 ]]; then
        log "FAIL" "Espacio en disco insuficiente: ${available_disk_gb}GB"
        count_check "FAIL"
    else
        log "PASS" "Espacio en disco suficiente: ${available_disk_gb}GB"
        count_check "PASS"
    fi
    
    # Verificar CPU cores
    local cpu_cores
    cpu_cores=$(nproc)
    if [[ $cpu_cores -lt 2 ]]; then
        log "WARN" "Pocos cores de CPU: ${cpu_cores} (recomendado: 2+)"
        count_check "WARN"
    else
        log "PASS" "Cores de CPU suficientes: ${cpu_cores}"
        count_check "PASS"
    fi
}

# Validar conectividad de red
validate_network() {
    log "INFO" "Validando conectividad de red..."
    
    # Verificar conexión a internet
    if ! ping -c 1 google.com &> /dev/null; then
        log "FAIL" "No hay conexión a internet"
        count_check "FAIL"
    else
        log "PASS" "Conexión a internet funcional"
        count_check "PASS"
    fi
    
    # Verificar resolución DNS
    if ! nslookup google.com &> /dev/null; then
        log "WARN" "Problemas de resolución DNS"
        count_check "WARN"
    else
        log "PASS" "Resolución DNS funcional"
        count_check "PASS"
    fi
    
    # Verificar puertos abiertos
    local ports=("22" "80" "443" "10000")
    for port in "${ports[@]}"; do
        if netstat -tlnp | grep -q ":$port "; then
            log "PASS" "Puerto $port está abierto"
            count_check "PASS"
        else
            log "FAIL" "Puerto $port no está abierto"
            count_check "FAIL"
        fi
    done
}

# Validar servicios del sistema
validate_system_services() {
    log "INFO" "Validando servicios del sistema..."
    
    local services=("webmin" "fail2ban")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log "PASS" "Servicio $service está activo"
            count_check "PASS"
        else
            log "FAIL" "Servicio $service no está activo"
            count_check "FAIL"
        fi
    done
    
    # Verificar si Apache/Nginx está activo
    if systemctl is-active --quiet apache2 || systemctl is-active --quiet nginx; then
        log "PASS" "Servidor web activo"
        count_check "PASS"
    else
        log "WARN" "Servidor web no detectado"
        count_check "WARN"
    fi
}

# Validar Webmin
validate_webmin() {
    log "INFO" "Validando instalación de Webmin..."
    
    # Verificar archivos de Webmin
    local webmin_files=("/etc/webmin" "/usr/share/webmin" "/etc/webmin/miniserv.conf")
    for file in "${webmin_files[@]}"; do
        if [[ -e "$file" ]]; then
            log "PASS" "Archivo de Webmin encontrado: $file"
            count_check "PASS"
        else
            log "FAIL" "Archivo de Webmin no encontrado: $file"
            count_check "FAIL"
        fi
    done
    
    # Verificar configuración SSL
    if grep -q "ssl=1" /etc/webmin/miniserv.conf; then
        log "PASS" "SSL configurado en Webmin"
        count_check "PASS"
    else
        log "WARN" "SSL no configurado en Webmin"
        count_check "WARN"
    fi
    
    # Verificar acceso remoto
    if grep -q "allow=0.0.0.0" /etc/webmin/miniserv.conf; then
        log "PASS" "Acceso remoto configurado en Webmin"
        count_check "PASS"
    else
        log "WARN" "Acceso remoto limitado en Webmin"
        count_check "WARN"
    fi
    
    # Verificar respuesta HTTP
    local webmin_url="https://localhost:10000"
    if curl -k -s --connect-timeout 5 "$webmin_url" > /dev/null; then
        log "PASS" "Webmin responde en $webmin_url"
        count_check "PASS"
    else
        log "FAIL" "Webmin no responde en $webmin_url"
        count_check "FAIL"
    fi
}

# Validar Virtualmin
validate_virtualmin() {
    log "INFO" "Validando instalación de Virtualmin..."
    local runtime_dir=""
    local runtime_files=()
    
    # Verificar archivos de Virtualmin
    local virtualmin_files=("/usr/share/webmin/virtual-server" "/usr/libexec/webmin/virtual-server" "/etc/webmin/virtual-server")
    for file in "${virtualmin_files[@]}"; do
        if [[ -e "$file" ]]; then
            log "PASS" "Módulo de Virtualmin encontrado: $file"
            count_check "PASS"
        else
            log "FAIL" "Módulo de Virtualmin no encontrado: $file"
            count_check "FAIL"
        fi
    done
    
    # Verificar configuración de Virtualmin
    if [[ -f /etc/webmin/virtual-server/config ]]; then
        log "PASS" "Configuración de Virtualmin encontrada"
        count_check "PASS"
    else
        log "WARN" "Configuración de Virtualmin no encontrada"
        count_check "WARN"
    fi

    if [[ -d /usr/share/webmin/virtual-server ]]; then
        runtime_dir="/usr/share/webmin/virtual-server"
    elif [[ -d /usr/libexec/webmin/virtual-server ]]; then
        runtime_dir="/usr/libexec/webmin/virtual-server"
    fi

    if [[ -n "$runtime_dir" ]]; then
        runtime_files=(
            "$runtime_dir/pro/connectivity.cgi"
            "$runtime_dir/pro/maillog.cgi"
            "$runtime_dir/pro/edit_html.cgi"
            "$runtime_dir/pro/list_bkeys.cgi"
            "$runtime_dir/remotedns.cgi"
        )

        for file in "${runtime_files[@]}"; do
            if [[ -f "$file" ]]; then
                log "PASS" "Overlay runtime Pro encontrado: $file"
                count_check "PASS"
            else
                log "FAIL" "Overlay runtime Pro faltante: $file"
                count_check "FAIL"
            fi
        done
    else
        log "FAIL" "No se pudo detectar el directorio runtime de Virtualmin"
        count_check "FAIL"
    fi

    if systemctl is-enabled --quiet virtualmin-pro-repo-update.timer 2>/dev/null; then
        log "PASS" "Timer de actualización del repositorio habilitado"
        count_check "PASS"
    else
        log "WARN" "Timer de actualización del repositorio no habilitado"
        count_check "WARN"
    fi
}

# Validar seguridad
validate_security() {
    log "INFO" "Validando configuración de seguridad..."
    
    # Verificar firewall
    if ufw status | grep -q "Status: active"; then
        log "PASS" "Firewall UFW está activo"
        count_check "PASS"
    else
        log "FAIL" "Firewall UFW no está activo"
        count_check "FAIL"
    fi
    
    # Verificar reglas de firewall
    local firewall_rules=("22" "80" "443" "10000")
    for port in "${firewall_rules[@]}"; do
        if ufw status | grep -q "$port"; then
            log "PASS" "Regla de firewall para puerto $port encontrada"
            count_check "PASS"
        else
            log "WARN" "Regla de firewall para puerto $port no encontrada"
            count_check "WARN"
        fi
    done
    
    # Verificar Fail2Ban
    if systemctl is-active --quiet fail2ban; then
        log "PASS" "Fail2Ban está activo"
        count_check "PASS"
    else
        log "FAIL" "Fail2Ban no está activo"
        count_check "FAIL"
    fi
    
    # Verificar configuración de Fail2Ban
    if [[ -f /etc/fail2ban/jail.d/webmin-production.local || -f /etc/fail2ban/jail.local ]]; then
        log "PASS" "Configuración de Fail2Ban encontrada"
        count_check "PASS"
    else
        log "WARN" "Configuración de Fail2Ban no encontrada"
        count_check "WARN"
    fi
    
    # Verificar parámetros de kernel seguros
    if sysctl net.ipv4.tcp_syncookies | grep -q "= 1"; then
        log "PASS" "Protección SYN cookies activa"
        count_check "PASS"
    else
        log "WARN" "Protección SYN cookies no activa"
        count_check "WARN"
    fi
}

# Validar módulos adicionales
validate_additional_modules() {
    log "INFO" "Validando módulos adicionales..."
    
    # Verificar sistema de backup
    if [[ -d /opt/intelligent_backup_system ]]; then
        log "PASS" "Sistema de backup inteligente encontrado"
        count_check "PASS"
        
        # Verificar dependencias de Python
        if pip3 list | grep -q "cryptography"; then
            log "PASS" "Dependencias de backup instaladas"
            count_check "PASS"
        else
            log "WARN" "Dependencias de backup no encontradas"
            count_check "WARN"
        fi
    else
        log "WARN" "Sistema de backup inteligente no encontrado"
        count_check "WARN"
    fi
    
    # Verificar sistema de monitoreo
    if [[ -f /etc/systemd/system/webmin-monitor.service ]]; then
        log "PASS" "Servicio de monitoreo encontrado"
        count_check "PASS"
        
        if systemctl is-active --quiet webmin-monitor; then
            log "PASS" "Servicio de monitoreo activo"
            count_check "PASS"
        else
            log "WARN" "Servicio de monitoreo no activo"
            count_check "WARN"
        fi
    else
        log "WARN" "Servicio de monitoreo no encontrado"
        count_check "WARN"
    fi
    
    # Verificar firewall inteligente
    if [[ -f /opt/intelligent_firewall/config ]]; then
        log "PASS" "Firewall inteligente encontrado"
        count_check "PASS"
    else
        log "WARN" "Firewall inteligente no encontrado"
        count_check "WARN"
    fi
}

# Validar configuración de base de datos
validate_database() {
    log "INFO" "Validando configuración de base de datos..."
    
    # Verificar MySQL/MariaDB
    if systemctl is-active --quiet mysql || systemctl is-active --quiet mariadb; then
        log "PASS" "Servidor de base de datos activo"
        count_check "PASS"
        
        # Verificar si se puede conectar
        if mysql -e "SELECT 1;" &> /dev/null; then
            log "PASS" "Conexión a base de datos funcional"
            count_check "PASS"
        else
            log "WARN" "Problemas de conexión a base de datos"
            count_check "WARN"
        fi
    else
        log "WARN" "Servidor de base de datos no activo"
        count_check "WARN"
    fi
}

# Validar configuración SSL
validate_ssl() {
    log "INFO" "Validando configuración SSL..."
    
    # Verificar certificado SSL de Webmin
    if [[ -f /etc/webmin/miniserv.pem ]]; then
        log "PASS" "Certificado SSL de Webmin encontrado"
        count_check "PASS"
        
        # Verificar validez del certificado
        if openssl x509 -in /etc/webmin/miniserv.pem -noout -checkend 86400 &> /dev/null; then
            log "PASS" "Certificado SSL válido"
            count_check "PASS"
        else
            log "WARN" "Certificado SSL expirado o inválido"
            count_check "WARN"
        fi
    else
        log "WARN" "Certificado SSL de Webmin no encontrado"
        count_check "WARN"
    fi
    
    # Verificar Let's Encrypt si está instalado
    if command -v certbot &> /dev/null; then
        log "PASS" "Let's Encrypt (certbot) instalado"
        count_check "PASS"
    else
        log "WARN" "Let's Encrypt (certbot) no instalado"
        count_check "WARN"
    fi
}

# Validar configuración de usuarios
validate_users() {
    log "INFO" "Validando configuración de usuarios..."
    
    # Verificar usuario webminadmin
    if id "webminadmin" &> /dev/null; then
        log "PASS" "Usuario webminadmin encontrado"
        count_check "PASS"
        
        # Verificar si está en el grupo sudo
        if groups webminadmin | grep -q "sudo"; then
            log "PASS" "Usuario webminadmin en grupo sudo"
            count_check "PASS"
        else
            log "WARN" "Usuario webminadmin no en grupo sudo"
            count_check "WARN"
        fi
    else
        log "WARN" "Usuario webminadmin no encontrado"
        count_check "WARN"
    fi
    
    # Verificar usuario root
    if id "root" &> /dev/null; then
        log "PASS" "Usuario root encontrado"
        count_check "PASS"
    else
        log "FAIL" "Usuario root no encontrado"
        count_check "FAIL"
    fi
}

# Generar reporte final
generate_final_report() {
    log "INFO" "Generando reporte final de validación..."
    
    local success_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    local report_file="/root/webmin_validation_report.txt"
    
    cat > "$report_file" << EOF
===============================================
REPORTE DE VALIDACIÓN - WEBMIN/VIRTUALMIN
===============================================
Fecha: $(date)
Servidor: $(hostname)
IP: $(hostname -I | awk '{print $1}')

RESUMEN DE VALIDACIÓN:
---------------------
Total de checks: $TOTAL_CHECKS
Checks pasados: $PASSED_CHECKS
Checks fallidos: $FAILED_CHECKS
Advertencias: $WARNINGS
Tasa de éxito: ${success_rate}%

ESTADO DE COMPONENTES:
---------------------
Sistema Operativo: $(validate_os &>/dev/null && echo "✅ OK" || echo "❌ ERROR")
Recursos del Sistema: ${PASSED_CHECKS}/$TOTAL_CHECKS checks pasados
Conectividad de Red: ${PASSED_CHECKS}/$TOTAL_CHECKS checks pasados
Servicios del Sistema: ${PASSED_CHECKS}/$TOTAL_CHECKS checks pasados
Webmin: ${PASSED_CHECKS}/$TOTAL_CHECKS checks pasados
Virtualmin: ${PASSED_CHECKS}/$TOTAL_CHECKS checks pasados
Seguridad: ${PASSED_CHECKS}/$TOTAL_CHECKS checks pasados
Módulos Adicionales: ${PASSED_CHECKS}/$TOTAL_CHECKS checks pasados
Base de Datos: ${PASSED_CHECKS}/$TOTAL_CHECKS checks pasados
Configuración SSL: ${PASSED_CHECKS}/$TOTAL_CHECKS checks pasados
Configuración de Usuarios: ${PASSED_CHECKS}/$TOTAL_CHECKS checks pasados

ACCESO WEBMIN:
--------------
URL: https://$(hostname -I | awk '{print $1}'):10000
Estado: $(curl -k -s --connect-timeout 5 "https://localhost:10000" &> /dev/null && echo "✅ Activo" || echo "❌ Inactivo")

RECOMENDACIONES:
---------------
EOF

    if [[ $success_rate -ge 90 ]]; then
        echo "✅ Sistema instalado correctamente" >> "$report_file"
        echo "   La validación fue exitosa con una tasa de éxito del ${success_rate}%" >> "$report_file"
    elif [[ $success_rate -ge 70 ]]; then
        echo "⚠️  Sistema instalado con advertencias" >> "$report_file"
        echo "   Se recomienda revisar los componentes con advertencias" >> "$report_file"
    else
        echo "❌ Sistema con problemas críticos" >> "$report_file"
        echo "   Se requiere intervención para corregir los errores" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

LOG COMPLETO DE VALIDACIÓN:
--------------------------
$VALIDATION_LOG

===============================================
EOF
    
    log "SUCCESS" "Reporte generado en: $report_file"
}

# Función principal de validación
main() {
    log "INFO" "Iniciando validación completa de Webmin/Virtualmin..."
    log "INFO" "Log de validación: $VALIDATION_LOG"
    
    # Ejecutar todas las validaciones
    validate_os
    validate_system_resources
    validate_network
    validate_system_services
    validate_webmin
    validate_virtualmin
    validate_security
    validate_additional_modules
    validate_database
    validate_ssl
    validate_users
    
    # Generar reporte final
    generate_final_report
    
    # Mostrar resumen
    echo ""
    echo "=================================================================="
    echo "📊 RESUMEN DE VALIDACIÓN"
    echo "=================================================================="
    echo ""
    echo "Total de checks: $TOTAL_CHECKS"
    echo "✅ Pasados: $PASSED_CHECKS"
    echo "❌ Fallidos: $FAILED_CHECKS"
    echo "⚠️  Advertencias: $WARNINGS"
    echo ""
    
    local success_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    echo "Tasa de éxito: ${success_rate}%"
    echo ""
    
    if [[ $success_rate -ge 90 ]]; then
        echo "🎉 VALIDACIÓN EXITOSA"
        echo "   Sistema instalado correctamente"
        exit 0
    elif [[ $success_rate -ge 70 ]]; then
        echo "⚠️  VALIDACIÓN CON ADVERTENCIAS"
        echo "   Se recomienda revisar los componentes con advertencias"
        exit 1
    else
        echo "❌ VALIDACIÓN CON ERRORES"
        echo "   Se requiere intervención para corregir los problemas"
        exit 2
    fi
}

# Ejecutar función principal
main "$@"

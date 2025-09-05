#!/bin/bash

# Script de Verificación de Seguridad Completa para Producción
# Sistema de Túneles Automáticos Mejorado v3.0
# Verifica que todas las protecciones estén activas y funcionando

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -eo pipefail

# Configuración
SECURITY_LOG="/tmp/security_verification_$(date +%Y%m%d_%H%M%S).log"
CONFIG_DIR="/etc/auto-tunnel"
LOG_DIR="/var/log/auto-tunnel"
SECURITY_DIR="$LOG_DIR/security"

# Colores para output
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Contadores
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Función de logging
log_security_check() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$SECURITY_LOG"
    
    case "$level" in
        "PASS")
            echo -e "${GREEN}✅ PASS${NC}: $message"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            ;;
        "FAIL")
            echo -e "${RED}❌ FAIL${NC}: $message"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            ;;
        "WARN")
            echo -e "${YELLOW}⚠️  WARN${NC}: $message"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  INFO${NC}: $message"
            ;;
    esac
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
}

# Función para verificar un comando
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
    
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
    
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Fin de función duplicada

# Función para verificar un archivo
check_file() {
    local description="$1"
    local file_path="$2"
    local required="${3:-true}"
    
    if [[ -f "$file_path" ]]; then
        log_security_check "PASS" "$description: $file_path existe"
        return 0
    else
        if [[ "$required" == "true" ]]; then
            log_security_check "FAIL" "$description: $file_path no existe"
        else
            log_security_check "WARN" "$description: $file_path no existe (opcional)"
        fi
        return 1
    fi
}

# Función para verificar un servicio
check_service() {
    local description="$1"
    local service_name="$2"
    local required="${3:-true}"
    
    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        log_security_check "PASS" "$description: Servicio $service_name activo"
        return 0
    else
        if [[ "$required" == "true" ]]; then
            log_security_check "FAIL" "$description: Servicio $service_name inactivo"
        else
            log_security_check "WARN" "$description: Servicio $service_name inactivo (opcional)"
        fi
        return 1
    fi
}

# Función para verificar un puerto
check_port() {
    local description="$1"
    local port="$2"
    local should_be_open="${3:-true}"
    
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        if [[ "$should_be_open" == "true" ]]; then
            log_security_check "PASS" "$description: Puerto $port abierto"
        else
            log_security_check "FAIL" "$description: Puerto $port abierto (debería estar cerrado)"
        fi
        return 0
    else
        if [[ "$should_be_open" == "true" ]]; then
            log_security_check "FAIL" "$description: Puerto $port cerrado"
        else
            log_security_check "PASS" "$description: Puerto $port cerrado (correcto)"
        fi
        return 1
    fi
}

# Banner de inicio
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "🔐 VERIFICACIÓN COMPLETA DE SEGURIDAD PARA PRODUCCIÓN"
echo "   Sistema de Túneles Automáticos Mejorado v3.0"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo
echo "📋 Iniciando verificación de seguridad completa..."
echo "📄 Log de verificación: $SECURITY_LOG"
echo

# SECCIÓN 1: Verificar archivos de configuración de seguridad
echo -e "${CYAN}🔧 SECCIÓN 1: Archivos de Configuración de Seguridad${NC}"
echo "───────────────────────────────────────────────────────────────────────────────"

check_file "Script de seguridad avanzada" "/Users/yunyminaya/Wedmin Y Virtualmin/seguridad_avanzada_tunnel.sh"
check_file "Script de alta disponibilidad" "/Users/yunyminaya/Wedmin Y Virtualmin/alta_disponibilidad_tunnel.sh"
check_file "Script de implementación seguridad macOS" "/Users/yunyminaya/Wedmin Y Virtualmin/implementar_seguridad_pro_macos.sh"
check_file "Script de verificación completa" "/Users/yunyminaya/Wedmin Y Virtualmin/verificar_funcionamiento_completo_ubuntu_debian.sh"
check_file "Reporte de seguridad" "/Users/yunyminaya/Wedmin Y Virtualmin/REPORTE_SEGURIDAD_COMPLETA_PRODUCCION.md"

echo

# SECCIÓN 2: Verificar herramientas de seguridad
echo -e "${CYAN}🛠️ SECCIÓN 2: Herramientas de Seguridad${NC}"
echo "───────────────────────────────────────────────────────────────────────────────"

check_command "OpenSSL disponible" "command -v openssl"
check_command "Curl disponible" "command -v curl"
check_command "Wget disponible" "command -v wget"
check_command "Netstat disponible" "command -v netstat"
check_command "Iptables disponible" "command -v iptables" "false"  # Opcional en macOS
check_command "Fail2ban disponible" "command -v fail2ban-client" "false"  # Opcional
check_command "Systemctl disponible" "command -v systemctl" "false"  # Opcional en macOS

echo

# SECCIÓN 3: Verificar configuraciones SSL/TLS
echo -e "${CYAN}🔐 SECCIÓN 3: Configuraciones SSL/TLS${NC}"
echo "───────────────────────────────────────────────────────────────────────────────"

# Verificar OpenSSL
if command -v openssl >/dev/null 2>&1; then
    openssl_version=$(openssl version | awk '{print $2}')
    log_security_check "PASS" "OpenSSL versión: $openssl_version"
    
    # Verificar certificados SSL
    if [[ -f "$HOME/.ssl/webmin/webmin.crt" ]]; then
        if openssl x509 -in "$HOME/.ssl/webmin/webmin.crt" -noout -checkend 0 2>/dev/null; then
            log_security_check "PASS" "Certificado SSL Webmin válido"
        else
            log_security_check "FAIL" "Certificado SSL Webmin expirado o inválido"
        fi
    else
        log_security_check "WARN" "Certificado SSL Webmin no encontrado"
    fi
else
    log_security_check "FAIL" "OpenSSL no disponible"
fi

echo

# SECCIÓN 4: Verificar firewall y protecciones de red
echo -e "${CYAN}🛡️ SECCIÓN 4: Firewall y Protecciones de Red${NC}"
echo "───────────────────────────────────────────────────────────────────────────────"

# Verificar firewall de macOS
if command -v /usr/libexec/ApplicationFirewall/socketfilterfw >/dev/null 2>&1; then
    firewall_status=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "unknown")
    if [[ "$firewall_status" == "Firewall is enabled" ]]; then
        log_security_check "PASS" "Firewall de macOS habilitado"
    else
        log_security_check "WARN" "Firewall de macOS deshabilitado"
    fi
else
    log_security_check "WARN" "Firewall de macOS no disponible"
fi

# Verificar iptables (Linux)
if command -v iptables >/dev/null 2>&1; then
    if iptables -L >/dev/null 2>&1; then
        log_security_check "PASS" "Iptables configurado"
        
        # Verificar reglas específicas
        if iptables -L | grep -q "DROP"; then
            log_security_check "PASS" "Reglas de bloqueo iptables activas"
        else
            log_security_check "WARN" "No se encontraron reglas de bloqueo en iptables"
        fi
    else
        log_security_check "FAIL" "Iptables no accesible"
    fi
else
    log_security_check "INFO" "Iptables no disponible (normal en macOS)"
fi

echo

# SECCIÓN 5: Verificar servicios de seguridad
echo -e "${CYAN}🚀 SECCIÓN 5: Servicios de Seguridad${NC}"
echo "───────────────────────────────────────────────────────────────────────────────"

# Verificar fail2ban
check_service "Fail2ban" "fail2ban" "false"

# Verificar servicios personalizados
check_service "Monitor de ataques" "attack-monitor" "false"
check_service "Honeypot SSH" "ssh-honeypot" "false"
check_service "Monitor HA" "ha-tunnel-monitor" "false"

echo

# SECCIÓN 6: Verificar puertos críticos
echo -e "${CYAN}🔌 SECCIÓN 6: Puertos Críticos${NC}"
echo "───────────────────────────────────────────────────────────────────────────────"

check_port "SSH" "22" "true"
check_port "HTTP" "80" "false"  # Opcional
check_port "HTTPS" "443" "false"  # Opcional
check_port "Webmin" "10000" "false"  # Opcional
check_port "Usermin" "20000" "false"  # Opcional
check_port "Honeypot SSH" "2222" "false"  # Opcional

echo

# SECCIÓN 7: Verificar logs de seguridad
echo -e "${CYAN}📋 SECCIÓN 7: Logs de Seguridad${NC}"
echo "───────────────────────────────────────────────────────────────────────────────"

# Verificar estructura de logs
if [[ -d "$HOME/.security/logs" ]]; then
    log_security_check "PASS" "Directorio de logs de seguridad existe"
    
    # Verificar archivos de log específicos
    if [[ -f "$HOME/.security/logs/security_monitor.log" ]]; then
        log_security_check "PASS" "Log de monitoreo de seguridad existe"
    else
        log_security_check "WARN" "Log de monitoreo de seguridad no existe"
    fi
    
    if [[ -f "$HOME/.security/logs/alerts.log" ]]; then
        log_security_check "PASS" "Log de alertas existe"
    else
        log_security_check "WARN" "Log de alertas no existe"
    fi
else
    log_security_check "WARN" "Directorio de logs de seguridad no existe"
fi

echo

# SECCIÓN 8: Verificar configuraciones del sistema
echo -e "${CYAN}⚙️ SECCIÓN 8: Configuraciones del Sistema${NC}"
echo "───────────────────────────────────────────────────────────────────────────────"

# Verificar Gatekeeper (macOS)
if command -v spctl >/dev/null 2>&1; then
    gatekeeper_status=$(spctl --status 2>/dev/null || echo "unknown")
    if [[ "$gatekeeper_status" == "assessments enabled" ]]; then
        log_security_check "PASS" "Gatekeeper habilitado"
    else
        log_security_check "WARN" "Gatekeeper deshabilitado"
    fi
else
    log_security_check "INFO" "Gatekeeper no disponible"
fi

# Verificar SIP (System Integrity Protection)
if command -v csrutil >/dev/null 2>&1; then
    if csrutil status | grep -q "enabled"; then
        log_security_check "PASS" "SIP (System Integrity Protection) habilitado"
    else
        log_security_check "WARN" "SIP (System Integrity Protection) deshabilitado"
    fi
else
    log_security_check "INFO" "SIP no disponible"
fi

# Verificar FileVault
if command -v fdesetup >/dev/null 2>&1; then
    if fdesetup status | grep -q "FileVault is On"; then
        log_security_check "PASS" "FileVault habilitado"
    else
        log_security_check "WARN" "FileVault deshabilitado"
    fi
else
    log_security_check "INFO" "FileVault no disponible"
fi

echo

# SECCIÓN 9: Verificar conectividad y túneles
echo -e "${CYAN}🌐 SECCIÓN 9: Conectividad y Túneles${NC}"
echo "───────────────────────────────────────────────────────────────────────────────"

# Verificar conectividad a internet
if curl -s --max-time 10 https://www.google.com >/dev/null 2>&1; then
    log_security_check "PASS" "Conectividad a internet disponible"
else
    log_security_check "FAIL" "Sin conectividad a internet"
fi

# Verificar DNS
if nslookup google.com >/dev/null 2>&1; then
    log_security_check "PASS" "Resolución DNS funcionando"
else
    log_security_check "FAIL" "Resolución DNS no funciona"
fi

echo

# SECCIÓN 10: Verificar integridad de archivos críticos
echo -e "${CYAN}🔍 SECCIÓN 10: Integridad de Archivos Críticos${NC}"
echo "───────────────────────────────────────────────────────────────────────────────"

# Verificar que los scripts no tienen contenido malicioso
scripts_to_check=(
    "/Users/yunyminaya/Wedmin Y Virtualmin/seguridad_avanzada_tunnel.sh"
    "/Users/yunyminaya/Wedmin Y Virtualmin/alta_disponibilidad_tunnel.sh"
    "/Users/yunyminaya/Wedmin Y Virtualmin/verificar_tunel_automatico_mejorado.sh"
)

for script in "${scripts_to_check[@]}"; do
    if [[ -f "$script" ]]; then
        # Verificar que no contenga comandos peligrosos
        if grep -q "rm -rf /" "$script" 2>/dev/null; then
            log_security_check "FAIL" "Script $script contiene comandos peligrosos"
        else
            log_security_check "PASS" "Script $script sin comandos peligrosos detectados"
        fi
        
        # Verificar permisos
        if [[ -x "$script" ]]; then
            log_security_check "PASS" "Script $script tiene permisos de ejecución"
        else
            log_security_check "WARN" "Script $script no tiene permisos de ejecución"
        fi
    else
        log_security_check "FAIL" "Script $script no encontrado"
    fi
done

echo

# SECCIÓN 11: Pruebas de penetración básicas
echo -e "${CYAN}🎯 SECCIÓN 11: Pruebas de Penetración Básicas${NC}"
echo "───────────────────────────────────────────────────────────────────────────────"

# Verificar que no hay contraseñas hardcodeadas
if grep -r "password=" /Users/yunyminaya/Wedmin\ Y\ Virtualmin/ 2>/dev/null | grep -v "#" | head -1 >/dev/null; then
    log_security_check "WARN" "Posibles contraseñas hardcodeadas encontradas"
else
    log_security_check "PASS" "No se encontraron contraseñas hardcodeadas"
fi

# Verificar que no hay API keys expuestas
if grep -r "api_key\|apikey\|api-key" /Users/yunyminaya/Wedmin\ Y\ Virtualmin/ 2>/dev/null | grep -v "#" | head -1 >/dev/null; then
    log_security_check "WARN" "Posibles API keys expuestas encontradas"
else
    log_security_check "PASS" "No se encontraron API keys expuestas"
fi

# Verificar que no hay tokens expuestos
if grep -r "token=" /Users/yunyminaya/Wedmin\ Y\ Virtualmin/ 2>/dev/null | grep -v "#" | head -1 >/dev/null; then
    log_security_check "WARN" "Posibles tokens expuestos encontrados"
else
    log_security_check "PASS" "No se encontraron tokens expuestos"
fi

echo

# RESUMEN FINAL
echo "═══════════════════════════════════════════════════════════════════════════════"
echo -e "${PURPLE}📊 RESUMEN DE VERIFICACIÓN DE SEGURIDAD${NC}"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo
echo -e "${GREEN}✅ Verificaciones PASADAS: $PASSED_CHECKS${NC}"
echo -e "${RED}❌ Verificaciones FALLIDAS: $FAILED_CHECKS${NC}"
echo -e "${YELLOW}⚠️  Verificaciones con ADVERTENCIA: $WARNING_CHECKS${NC}"
echo -e "${BLUE}📊 Total de verificaciones: $TOTAL_CHECKS${NC}"
echo

# Calcular porcentaje de éxito
if [[ $TOTAL_CHECKS -gt 0 ]]; then
    success_rate=$(echo "scale=2; ($PASSED_CHECKS * 100) / $TOTAL_CHECKS" | bc)
    echo -e "${CYAN}📈 Tasa de éxito: ${success_rate}%${NC}"
else
    echo -e "${RED}❌ No se ejecutaron verificaciones${NC}"
    exit 1
fi

echo

# Determinar nivel de seguridad
if [[ $FAILED_CHECKS -eq 0 ]] && [[ $WARNING_CHECKS -le 5 ]]; then
    echo -e "${GREEN}🛡️ NIVEL DE SEGURIDAD: MÁXIMO${NC}"
    echo -e "${GREEN}✅ SISTEMA 100% LISTO PARA PRODUCCIÓN${NC}"
    security_level="MÁXIMO"
elif [[ $FAILED_CHECKS -le 2 ]] && [[ $WARNING_CHECKS -le 10 ]]; then
    echo -e "${YELLOW}🛡️ NIVEL DE SEGURIDAD: ALTO${NC}"
    echo -e "${YELLOW}⚠️ SISTEMA CASI LISTO PARA PRODUCCIÓN${NC}"
    security_level="ALTO"
elif [[ $FAILED_CHECKS -le 5 ]] && [[ $WARNING_CHECKS -le 15 ]]; then
    echo -e "${YELLOW}🛡️ NIVEL DE SEGURIDAD: MEDIO${NC}"
    echo -e "${YELLOW}⚠️ REQUIERE MEJORAS ANTES DE PRODUCCIÓN${NC}"
    security_level="MEDIO"
else
    echo -e "${RED}🛡️ NIVEL DE SEGURIDAD: BAJO${NC}"
    echo -e "${RED}❌ NO LISTO PARA PRODUCCIÓN${NC}"
    security_level="BAJO"
fi

echo
echo "═══════════════════════════════════════════════════════════════════════════════"
echo -e "${BLUE}📄 Log completo guardado en: $SECURITY_LOG${NC}"
echo -e "${BLUE}📅 Fecha de verificación: $(date +'%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${BLUE}🔐 Nivel de seguridad determinado: $security_level${NC}"
echo "═══════════════════════════════════════════════════════════════════════════════"

# Guardar resumen en archivo
cat > "/tmp/security_summary_$(date +%Y%m%d_%H%M%S).txt" << EOF
RESUMEN DE VERIFICACIÓN DE SEGURIDAD
====================================
Fecha: $(date +'%Y-%m-%d %H:%M:%S')
Sistema: Sistema de Túneles Automáticos Mejorado v3.0

Resultados:
- Verificaciones PASADAS: $PASSED_CHECKS
- Verificaciones FALLIDAS: $FAILED_CHECKS
- Verificaciones con ADVERTENCIA: $WARNING_CHECKS
- Total de verificaciones: $TOTAL_CHECKS
- Tasa de éxito: ${success_rate}%
- Nivel de seguridad: $security_level

Log completo: $SECURITY_LOG
EOF

echo
echo -e "${GREEN}🎉 Verificación de seguridad completada exitosamente${NC}"

# Código de salida basado en el nivel de seguridad
if [[ "$security_level" == "MÁXIMO" ]]; then
    exit 0
elif [[ "$security_level" == "ALTO" ]]; then
    exit 1
elif [[ "$security_level" == "MEDIO" ]]; then
    exit 2
else
    exit 3
fi

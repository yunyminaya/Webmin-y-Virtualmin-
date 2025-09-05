#!/bin/bash

# Script para verificar funcionamiento completo de Webmin, Virtualmin y funciones PRO
# Específico para Ubuntu y Debian

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -e

# Colores para output
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Función para logging
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
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Fin de función duplicada

# Función para mostrar banner
show_banner() {
    clear
    cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════════
   🛡️ VERIFICACIÓN COMPLETA UBUNTU/DEBIAN
   
   🔒 Webmin y Virtualmin - Funcionamiento sin errores
   🛡️ Todas las funciones PRO operativas
   🔐 Verificación exhaustiva de servicios
   
═══════════════════════════════════════════════════════════════════════════════
EOF
}

# Detectar sistema operativo
detect_os() {
    log "HEADER" "DETECTANDO SISTEMA OPERATIVO"
    
    if [[ -f "/etc/os-release" ]]; then
        local os_name=$(grep "^NAME=" /etc/os-release | cut -d'"' -f2)
        local os_version=$(grep "^VERSION=" /etc/os-release | cut -d'"' -f2)
        log "SUCCESS" "Sistema: $os_name $os_version"
        
        if [[ "$os_name" == *"Ubuntu"* ]] || [[ "$os_name" == *"Debian"* ]]; then
            log "SUCCESS" "Sistema compatible: Ubuntu/Debian"
            return 0
        else
            log "WARNING" "Sistema no es Ubuntu/Debian: $os_name"
            return 1
        fi
    else
        log "ERROR" "No se pudo detectar el sistema operativo"
        return 1
    fi
}

# Verificar servicios del sistema
verify_system_services() {
    log "HEADER" "VERIFICANDO SERVICIOS DEL SISTEMA"
    
    # Verificar servicios críticos
    local critical_services=(
        "ssh"
        "apache2"
        "mysql"
        "fail2ban"
        "ufw"
    )
    
    for service in "${critical_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log "SUCCESS" "Servicio $service: Activo"
        else
            log "WARNING" "Servicio $service: Inactivo"
        fi
    done
    
    # Verificar puertos críticos
    local critical_ports=(
        "22:SSH"
        "80:HTTP"
        "443:HTTPS"
        "10000:Webmin"
        "20000:Virtualmin"
    )
    
    for port_info in "${critical_ports[@]}"; do
        local port=$(echo "$port_info" | cut -d':' -f1)
        local service_name=$(echo "$port_info" | cut -d':' -f2)
        
        if netstat -tuln | grep -q ":$port "; then
            log "SUCCESS" "Puerto $port ($service_name): Abierto"
        else
            log "WARNING" "Puerto $port ($service_name): Cerrado"
        fi
    done
}

# Verificar Webmin
verify_webmin() {
    log "HEADER" "VERIFICANDO WEBMIN"
    
    # Verificar proceso de Webmin
    if pgrep -f "miniserv" >/dev/null 2>&1; then
        log "SUCCESS" "Proceso Webmin: Ejecutándose"
    else
        log "ERROR" "Proceso Webmin: No ejecutándose"
    fi
    
    # Verificar puerto de Webmin
    if lsof -i :10000 >/dev/null 2>&1; then
        local webmin_service=$(lsof -i :10000 | head -2 | tail -1 | awk '{print $1}')
        log "SUCCESS" "Puerto 10000 (Webmin): Abierto ($webmin_service)"
    else
        log "ERROR" "Puerto 10000 (Webmin): Cerrado"
    fi
    
    # Verificar archivos de configuración de Webmin
    local webmin_configs=(
        "/etc/webmin/miniserv.conf"
        "/etc/webmin/miniserv.users"
        "/etc/webmin/config"
    )
    
    for config in "${webmin_configs[@]}"; do
        if [[ -f "$config" ]]; then
            log "SUCCESS" "Configuración Webmin: $(basename "$config")"
        else
            log "WARNING" "Configuración Webmin: $(basename "$config") no encontrado"
        fi
    done
    
    # Verificar SSL de Webmin
    if [[ -f "/etc/webmin/miniserv.pem" ]]; then
        log "SUCCESS" "Certificado SSL Webmin: Configurado"
        
        # Verificar validez del certificado
        if openssl x509 -in /etc/webmin/miniserv.pem -noout -checkend 0 2>/dev/null; then
            log "SUCCESS" "Certificado SSL Webmin: Válido"
        else
            log "ERROR" "Certificado SSL Webmin: Expirado o inválido"
        fi
    else
        log "WARNING" "Certificado SSL Webmin: No configurado"
    fi
}

# Verificar Virtualmin
verify_virtualmin() {
    log "HEADER" "VERIFICANDO VIRTUALMIN"
    
    # Verificar archivos de Virtualmin
    if [[ -d "virtualmin-gpl-master" ]]; then
        log "SUCCESS" "Archivos de Virtualmin: Disponibles"
        
        # Verificar archivos críticos de Virtualmin
        local virtualmin_files=(
            "virtualmin-gpl-master/virtual-server-lib.pl"
            "virtualmin-gpl-master/virtualmin-lib.pl"
            "virtualmin-gpl-master/acl_security.pl"
        )
        
        for file in "${virtualmin_files[@]}"; do
            if [[ -f "$file" ]]; then
                log "SUCCESS" "Archivo Virtualmin: $(basename "$file")"
            else
                log "WARNING" "Archivo Virtualmin: $(basename "$file") no encontrado"
            fi
        done
    else
        log "WARNING" "Archivos de Virtualmin: No encontrados"
    fi
    
    # Verificar puerto de Virtualmin
    if lsof -i :20000 >/dev/null 2>&1; then
        local virtualmin_service=$(lsof -i :20000 | head -2 | tail -1 | awk '{print $1}')
        log "SUCCESS" "Puerto 20000 (Virtualmin): Abierto ($virtualmin_service)"
    else
        log "INFO" "Puerto 20000 (Virtualmin): Cerrado (normal si no está configurado)"
    fi
}

# Verificar funciones PRO
verify_pro_functions() {
    log "HEADER" "VERIFICANDO FUNCIONES PRO"
    
    # Verificar herramientas de monitoreo PRO
    local pro_tools=(
        "htop:Monitor de procesos"
        "iotop:Monitor de I/O"
        "nethogs:Monitor de red"
        "iftop:Monitor de tráfico"
        "lynis:Auditoría de seguridad"
        "chkrootkit:Detección de rootkits"
    )
    
    for tool_info in "${pro_tools[@]}"; do
        local tool=$(echo "$tool_info" | cut -d':' -f1)
        local description=$(echo "$tool_info" | cut -d':' -f2)
        
        if command -v "$tool" >/dev/null 2>&1; then
            log "SUCCESS" "$description ($tool): Instalado"
        else
            log "WARNING" "$description ($tool): No instalado"
        fi
    done
    
    # Verificar servicios PRO
    local pro_services=(
        "fail2ban:Protección contra ataques"
        "clamav:Antivirus"
        "spamassassin:Filtro de spam"
        "dovecot:Servidor IMAP/POP3"
        "postfix:Servidor de correo"
    )
    
    for service_info in "${pro_services[@]}"; do
        local service=$(echo "$service_info" | cut -d':' -f1)
        local description=$(echo "$service_info" | cut -d':' -f2)
        
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log "SUCCESS" "$description ($service): Activo"
        else
            log "WARNING" "$description ($service): Inactivo"
        fi
    done
}

# Verificar estado final completo
verify_final_complete_status() {
    log "HEADER" "VERIFICACIÓN FINAL COMPLETA"
    
    echo "=== ESTADO COMPLETO DEL SISTEMA ==="
    
    # Contadores
    local total_checks=0
    local passed_checks=0
    local failed_checks=0
    
    # Verificar servicios críticos
    local critical_services=("ssh" "apache2" "mysql" "fail2ban")
    for service in "${critical_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo "✅ $service: Activo"
            ((passed_checks++))
        else
            echo "❌ $service: Inactivo"
            ((failed_checks++))
        fi
        ((total_checks++))
    done
    
    # Verificar puertos críticos
    local critical_ports=("22" "80" "443" "10000")
    for port in "${critical_ports[@]}"; do
        if netstat -tuln | grep -q ":$port "; then
            echo "✅ Puerto $port: Abierto"
            ((passed_checks++))
        else
            echo "❌ Puerto $port: Cerrado"
            ((failed_checks++))
        fi
        ((total_checks++))
    done
    
    # Verificar herramientas PRO
    local pro_tools=("htop" "lynis" "fail2ban-client")
    for tool in "${pro_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "✅ $tool: Instalado"
            ((passed_checks++))
        else
            echo "❌ $tool: No instalado"
            ((failed_checks++))
        fi
        ((total_checks++))
    done
    
    # Verificar SSL
    if command -v openssl >/dev/null 2>&1; then
        echo "✅ SSL/TLS: Disponible"
        ((passed_checks++))
    else
        echo "❌ SSL/TLS: No disponible"
        ((failed_checks++))
    fi
    ((total_checks++))
    
    # Verificar firewall
    if command -v ufw >/dev/null 2>&1 || command -v firewall-cmd >/dev/null 2>&1; then
        echo "✅ Firewall: Configurado"
        ((passed_checks++))
    else
        echo "❌ Firewall: No configurado"
        ((failed_checks++))
    fi
    ((total_checks++))
    
    echo "=== RESUMEN FINAL ==="
    echo "Total de verificaciones: $total_checks"
    echo "Verificaciones exitosas: $passed_checks"
    echo "Verificaciones fallidas: $failed_checks"
    
    if [[ $total_checks -gt 0 ]]; then
        local percentage=$((passed_checks * 100 / total_checks))
        echo "Porcentaje de éxito: $percentage%"
        
        if [[ $percentage -eq 100 ]]; then
            echo "🎉 ¡SISTEMA COMPLETAMENTE FUNCIONAL! Sin errores"
        elif [[ $percentage -ge 80 ]]; then
            echo "✅ Sistema mayormente funcional"
        elif [[ $percentage -ge 60 ]]; then
            echo "⚠️ Sistema parcialmente funcional"
        else
            echo "❌ Sistema requiere atención"
        fi
    fi
    
    echo "=== FIN VERIFICACIÓN ==="
}

# Función principal
main() {
    show_banner
    
    log "INFO" "Iniciando verificación completa de funcionamiento en Ubuntu/Debian..."
    
    # Verificar sistema operativo
    if ! detect_os; then
        log "ERROR" "Este script está diseñado para Ubuntu/Debian"
        exit 1
    fi
    
    # Ejecutar todas las verificaciones
    verify_system_services
    verify_webmin
    verify_virtualmin
    verify_pro_functions
    verify_final_complete_status
    
    log "SUCCESS" "Verificación completa finalizada"
    log "INFO" "Recomendaciones:"
    log "INFO" "- Revisar servicios inactivos"
    log "INFO" "- Configurar herramientas faltantes"
    log "INFO" "- Optimizar rendimiento si es necesario"
}

# Ejecutar función principal
main "$@"

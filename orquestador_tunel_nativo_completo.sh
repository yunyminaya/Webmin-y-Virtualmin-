#!/bin/bash

# Orquestador Túnel Nativo Completo
# Sistema maestro de gestión para todos los componentes del túnel nativo
# SIN TERCEROS - 100% Nativo con seguridad profesional

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/orquestador_tunel_nativo_completo.log"
MASTER_CONFIG="/etc/webmin/orquestador_tunel_config.conf"
INSTALLATION_STATUS="/var/lib/webmin/installation_status.json"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ORQUESTADOR-TUNEL] $1" | tee -a "$LOG_FILE"
}

load_master_config() {
    if [ ! -f "$MASTER_CONFIG" ]; then
        cat > "$MASTER_CONFIG" << 'EOF'
# Configuración Maestra Túnel Nativo Completo
SYSTEM_NAME="Túnel Nativo Webmin/Virtualmin"
VERSION="1.0.0"
INSTALLATION_MODE="complete"

# Componentes del sistema
TUNNEL_COMPONENT=true
IP_PUBLIC_COMPONENT=true
SECURITY_COMPONENT=true
DEDUP_COMPONENT=true
PERSISTENCE_COMPONENT=true

# Configuración de red
WEBMIN_PORT=10000
HTTP_PORT=80
HTTPS_PORT=443
SSH_PORT=22

# Configuración de seguridad
SECURITY_LEVEL="maximum"
ENCRYPTION_ENABLED=true
INTRUSION_DETECTION=true
ACCESS_CONTROL_STRICT=true

# Configuración de persistencia
AUTO_RECOVERY=true
HEALTH_MONITORING=true
REDUNDANCY_ENABLED=true
BACKUP_ENABLED=true

# Configuración de logs
DETAILED_LOGGING=true
LOG_ROTATION=true
ALERT_SYSTEM=true
EOF
    fi
    source "$MASTER_CONFIG"
}

verify_prerequisites() {
    log_message "=== VERIFICANDO PRERREQUISITOS ==="
    
    local missing_deps=()
    local required_commands=("ssh" "systemctl" "iptables" "curl" "jq")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_message "⚠️  Instalando dependencias faltantes: ${missing_deps[*]}"
        apt-get update
        
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                "jq") apt-get install -y jq ;;
                "curl") apt-get install -y curl ;;
                "ssh") apt-get install -y openssh-server openssh-client ;;
                "systemctl") log_message "❌ systemd requerido pero no disponible" ; return 1 ;;
                "iptables") apt-get install -y iptables iptables-persistent ;;
            esac
        done
    fi
    
    # Verificar Webmin/Virtualmin
    if [ ! -d "/usr/share/webmin" ]; then
        log_message "❌ Webmin no encontrado - Instalar primero"
        return 1
    fi
    
    log_message "✅ Prerrequisitos verificados"
    return 0
}

install_complete_system() {
    log_message "=== INSTALACIÓN COMPLETA DEL SISTEMA ==="
    
    local installation_start=$(date +%s)
    local components_installed=0
    local components_failed=0
    
    # Actualizar estado de instalación
    update_installation_status "starting" "Iniciando instalación completa"
    
    # 1. Componente: Túnel Nativo Automático
    if [ "$TUNNEL_COMPONENT" = "true" ]; then
        log_message "🚀 Instalando componente: Túnel Nativo Automático"
        if "$SCRIPT_DIR/sub_agente_tunel_nativo_automatico.sh" auto; then
            ((components_installed++))
            update_installation_status "progress" "Túnel nativo instalado"
        else
            ((components_failed++))
            log_message "❌ Error en instalación: Túnel Nativo"
        fi
    fi
    
    # 2. Componente: IP Pública Nativa
    if [ "$IP_PUBLIC_COMPONENT" = "true" ]; then
        log_message "🌐 Instalando componente: IP Pública Nativa"
        if "$SCRIPT_DIR/sub_agente_ip_publica_nativa.sh" auto; then
            ((components_installed++))
            update_installation_status "progress" "IP pública nativa configurada"
        else
            ((components_failed++))
            log_message "❌ Error en instalación: IP Pública Nativa"
        fi
    fi
    
    # 3. Componente: Seguridad Túnel Nativo
    if [ "$SECURITY_COMPONENT" = "true" ]; then
        log_message "🔒 Instalando componente: Seguridad Túnel Nativo"
        if "$SCRIPT_DIR/sub_agente_seguridad_tunel_nativo.sh" full; then
            ((components_installed++))
            update_installation_status "progress" "Seguridad avanzada configurada"
        else
            ((components_failed++))
            log_message "❌ Error en instalación: Seguridad Túnel"
        fi
    fi
    
    # 4. Componente: Eliminador de Duplicados
    if [ "$DEDUP_COMPONENT" = "true" ]; then
        log_message "🧹 Instalando componente: Eliminador de Duplicados"
        if "$SCRIPT_DIR/sub_agente_eliminar_duplicados_webmin_virtualmin.sh" full; then
            ((components_installed++))
            update_installation_status "progress" "Duplicados eliminados"
        else
            ((components_failed++))
            log_message "❌ Error en instalación: Eliminador de Duplicados"
        fi
    fi
    
    # 5. Componente: Sistema Persistente
    if [ "$PERSISTENCE_COMPONENT" = "true" ]; then
        log_message "♾️  Instalando componente: Sistema Túnel Persistente"
        if "$SCRIPT_DIR/sistema_tunel_persistente_seguro.sh" install; then
            ((components_installed++))
            update_installation_status "progress" "Sistema persistente configurado"
        else
            ((components_failed++))
            log_message "❌ Error en instalación: Sistema Persistente"
        fi
    fi
    
    local installation_end=$(date +%s)
    local installation_time=$((installation_end - installation_start))
    
    # Resultado final
    if [ "$components_failed" -eq 0 ]; then
        log_message "🎉 INSTALACIÓN COMPLETA EXITOSA"
        log_message "✅ Componentes instalados: $components_installed"
        log_message "⏱️  Tiempo total: ${installation_time}s"
        update_installation_status "completed" "Sistema completo instalado exitosamente"
        
        # Iniciar servicios
        start_all_services
        
        # Verificación final
        verify_complete_system
        
        return 0
    else
        log_message "❌ INSTALACIÓN CON ERRORES"
        log_message "✅ Componentes exitosos: $components_installed"
        log_message "❌ Componentes fallidos: $components_failed"
        update_installation_status "failed" "Instalación completada con errores"
        return 1
    fi
}

update_installation_status() {
    local status="$1"
    local message="$2"
    
    cat > "$INSTALLATION_STATUS" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "status": "$status",
    "message": "$message",
    "components": {
        "tunnel_nativo": $([ -f "/etc/systemd/system/tunnel-nativo.service" ] && echo "true" || echo "false"),
        "ip_publica": $([ -f "/var/lib/webmin/ip_publica_nativa_status.json" ] && echo "true" || echo "false"),
        "security": $([ -f "/etc/systemd/system/tunnel-intrusion-detection.service" ] && echo "true" || echo "false"),
        "deduplicator": $([ -f "/usr/share/webmin/lib/webmin-virtualmin-common.pl" ] && echo "true" || echo "false"),
        "persistence": $([ -f "/etc/systemd/system/tunel-persistente.service" ] && echo "true" || echo "false")
    },
    "services_status": {
        "webmin": "$(systemctl is-active webmin 2>/dev/null || echo 'inactive')",
        "tunnel_nativo": "$(systemctl is-active tunnel-nativo 2>/dev/null || echo 'inactive')",
        "tunnel_persistent": "$(systemctl is-active tunel-persistente 2>/dev/null || echo 'inactive')",
        "nginx": "$(systemctl is-active nginx 2>/dev/null || echo 'inactive')"
    }
}
EOF
}

start_all_services() {
    log_message "=== INICIANDO TODOS LOS SERVICIOS ==="
    
    local services=(
        "tunnel-nativo"
        "tunnel-nativo-monitor"
        "tunel-persistente"
        "tunel-watchdog"
        "tunnel-intrusion-detection"
        "nat-keepalive"
    )
    
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "$service"; then
            log_message "▶️  Iniciando servicio: $service"
            if systemctl start "$service" 2>/dev/null; then
                log_message "✅ Servicio iniciado: $service"
            else
                log_message "⚠️  Error al iniciar: $service"
            fi
        fi
    done
    
    # Iniciar servicios de reenvío
    systemctl start tunnel-forward-webmin tunnel-forward-http tunnel-forward-https 2>/dev/null || true
    
    log_message "✓ Todos los servicios iniciados"
}

stop_all_services() {
    log_message "=== DETENIENDO TODOS LOS SERVICIOS ==="
    
    local services=(
        "tunel-watchdog"
        "tunel-persistente"
        "tunnel-intrusion-detection"
        "tunnel-nativo-monitor"
        "tunnel-nativo"
        "tunnel-forward-webmin"
        "tunnel-forward-http"
        "tunnel-forward-https"
        "nat-keepalive"
    )
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_message "⏹️  Deteniendo servicio: $service"
            systemctl stop "$service" 2>/dev/null || true
        fi
    done
    
    log_message "✓ Todos los servicios detenidos"
}

verify_complete_system() {
    log_message "=== VERIFICACIÓN COMPLETA DEL SISTEMA ==="
    
    local verification_report="/var/log/verificacion_sistema_completo_$(date +%Y%m%d_%H%M%S).txt"
    local system_score=0
    local max_score=20
    
    {
        echo "==========================================="
        echo "VERIFICACIÓN SISTEMA TÚNEL NATIVO COMPLETO"
        echo "==========================================="
        echo "Fecha: $(date)"
        echo ""
        
        echo "=== VERIFICACIÓN DE COMPONENTES ==="
        
        # Verificar túnel nativo
        if systemctl is-active --quiet tunnel-nativo; then
            echo "✅ Túnel Nativo: ACTIVO"
            ((system_score += 4))
        else
            echo "❌ Túnel Nativo: INACTIVO"
        fi
        
        # Verificar IP pública
        if [ -f "/var/lib/webmin/ip_publica_nativa_status.json" ]; then
            local ip_status=$(jq -r '.public_ip' "/var/lib/webmin/ip_publica_nativa_status.json" 2>/dev/null)
            if [[ "$ip_status" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "✅ IP Pública: $ip_status"
                ((system_score += 4))
            else
                echo "❌ IP Pública: NO DETECTADA"
            fi
        else
            echo "❌ IP Pública: NO CONFIGURADA"
        fi
        
        # Verificar seguridad
        if systemctl is-active --quiet tunnel-intrusion-detection; then
            echo "✅ Seguridad: ACTIVA"
            ((system_score += 4))
        else
            echo "❌ Seguridad: INACTIVA"
        fi
        
        # Verificar persistencia
        if systemctl is-active --quiet tunel-persistente; then
            echo "✅ Persistencia: ACTIVA"
            ((system_score += 4))
        else
            echo "❌ Persistencia: INACTIVA"
        fi
        
        # Verificar eliminación de duplicados
        if [ -f "/usr/share/webmin/lib/webmin-virtualmin-common.pl" ]; then
            echo "✅ Deduplicación: COMPLETADA"
            ((system_score += 4))
        else
            echo "❌ Deduplicación: NO COMPLETADA"
        fi
        
        echo ""
        echo "=== VERIFICACIÓN DE ACCESIBILIDAD ==="
        
        # Verificar Webmin
        if curl -s -k -I "https://localhost:10000" --connect-timeout 10 | grep -q "HTTP"; then
            echo "✅ Webmin: ACCESIBLE (https://localhost:10000)"
        else
            echo "❌ Webmin: NO ACCESIBLE"
        fi
        
        # Verificar servidores virtuales
        if command -v virtualmin &> /dev/null; then
            local virtual_domains=$(virtualmin list-domains --multiline 2>/dev/null | grep "^Domain name:" | wc -l)
            echo "📊 Servidores Virtuales: $virtual_domains configurados"
        fi
        
        echo ""
        echo "=== ESTADÍSTICAS DEL SISTEMA ==="
        echo "Puntuación del Sistema: $system_score/$max_score ($(( (system_score * 100) / max_score ))%)"
        echo "Tiempo de funcionamiento: $(uptime -p)"
        echo "Memoria utilizada: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
        echo "Espacio en disco: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 " usado)"}')"
        
        echo ""
        echo "=== ESTADO DE SERVICIOS CRÍTICOS ==="
        local critical_services=("webmin" "nginx" "apache2" "mysql" "tunnel-nativo" "tunel-persistente")
        
        for service in "${critical_services[@]}"; do
            local status=$(systemctl is-active "$service" 2>/dev/null || echo "no-installed")
            case "$status" in
                "active") echo "🟢 $service: ACTIVO" ;;
                "inactive") echo "🔴 $service: INACTIVO" ;;
                "failed") echo "🔴 $service: FALLIDO" ;;
                *) echo "⚪ $service: NO INSTALADO" ;;
            esac
        done
        
        echo ""
        echo "=== SEGURIDAD Y RENDIMIENTO ==="
        echo "Conexiones activas: $(netstat -an | grep -E ':80|:443|:10000' | grep ESTABLISHED | wc -l)"
        echo "IPs bloqueadas: $([ -f "/etc/tunnel-native/blocked_ips.list" ] && wc -l < /etc/tunnel-native/blocked_ips.list || echo "0")"
        echo "Certificados SSL: $([ -f "/etc/ssl/certs/tunnel-native.crt" ] && echo "CONFIGURADOS" || echo "NO CONFIGURADOS")"
        echo "Firewall: $(ufw status | grep -q "Status: active" && echo "ACTIVO" || echo "INACTIVO")"
        
        echo ""
        echo "=== RECOMENDACIONES ==="
        if [ "$system_score" -eq "$max_score" ]; then
            echo "🎉 Sistema perfectamente configurado"
            echo "✅ Todos los componentes funcionan correctamente"
            echo "✅ Sistema listo para producción"
        elif [ "$system_score" -ge $((max_score * 80 / 100)) ]; then
            echo "🟢 Sistema bien configurado"
            echo "⚠️  Algunos componentes menores necesitan atención"
        elif [ "$system_score" -ge $((max_score * 60 / 100)) ]; then
            echo "🟡 Sistema parcialmente funcional"
            echo "⚠️  Varios componentes necesitan reparación"
        else
            echo "🔴 Sistema con problemas graves"
            echo "❌ Requiere reinstalación o reparación mayor"
        fi
        
    } > "$verification_report"
    
    log_message "📋 Reporte de verificación: $verification_report"
    cat "$verification_report"
    
    return $([ "$system_score" -ge $((max_score * 60 / 100)) ] && echo 0 || echo 1)
}

create_unified_management_interface() {
    log_message "=== CREANDO INTERFAZ UNIFICADA DE GESTIÓN ==="
    
    cat > "$SCRIPT_DIR/gestion_tunel_unificada.sh" << 'EOF'
#!/bin/bash

# Interfaz Unificada de Gestión - Túnel Nativo Completo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_system_status() {
    echo "==========================================="
    echo "🌐 ESTADO SISTEMA TÚNEL NATIVO COMPLETO"
    echo "==========================================="
    echo ""
    
    # Estado general
    if curl -s -k -I "https://localhost:10000" | grep -q "HTTP"; then
        echo "🟢 SISTEMA: OPERATIVO"
    else
        echo "🔴 SISTEMA: PROBLEMAS DETECTADOS"
    fi
    
    # IP Pública
    if [ -f "/var/lib/webmin/ip_publica_nativa_status.json" ]; then
        local public_ip=$(jq -r '.public_ip' "/var/lib/webmin/ip_publica_nativa_status.json" 2>/dev/null)
        echo "🌍 IP PÚBLICA: ${public_ip:-NO DETECTADA}"
    fi
    
    # Servicios
    echo ""
    echo "=== SERVICIOS ==="
    local services=("tunnel-nativo" "tunel-persistente" "webmin" "nginx")
    for service in "${services[@]}"; do
        local status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
        case "$status" in
            "active") echo "🟢 $service" ;;
            *) echo "🔴 $service" ;;
        esac
    done
    
    # Conectividad
    echo ""
    echo "=== CONECTIVIDAD ==="
    echo "🌐 Webmin: $(curl -s -I "https://localhost:10000" --connect-timeout 5 | head -1 | cut -d' ' -f2 || echo "NO ACCESIBLE")"
    echo "🌍 Internet: $(ping -c 1 8.8.8.8 >/dev/null 2>&1 && echo "OK" || echo "ERROR")"
    
    # URLs de acceso
    if [ -f "/var/lib/webmin/ip_publica_nativa_status.json" ]; then
        local public_ip=$(jq -r '.public_ip' "/var/lib/webmin/ip_publica_nativa_status.json" 2>/dev/null)
        if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo ""
            echo "=== URLS DE ACCESO ==="
            echo "🔗 Webmin Externo: https://$public_ip:10000"
            echo "🔗 Webmin Local: https://localhost:10000"
            echo "🔗 Web HTTP: http://$public_ip"
            echo "🔗 Web HTTPS: https://$public_ip"
        fi
    fi
}

manage_services() {
    local action="$1"
    
    case "$action" in
        "start")
            echo "▶️  Iniciando todos los servicios..."
            "$SCRIPT_DIR/orquestador_tunel_nativo_completo.sh" start
            ;;
        "stop")
            echo "⏹️  Deteniendo todos los servicios..."
            "$SCRIPT_DIR/orquestador_tunel_nativo_completo.sh" stop
            ;;
        "restart")
            echo "🔄 Reiniciando todos los servicios..."
            "$SCRIPT_DIR/orquestador_tunel_nativo_completo.sh" restart
            ;;
        "status")
            show_system_status
            ;;
    esac
}

repair_system() {
    echo "🔧 INICIANDO REPARACIÓN DEL SISTEMA"
    echo ""
    
    # Reparación por componentes
    echo "1️⃣  Reparando túnel nativo..."
    "$SCRIPT_DIR/sub_agente_tunel_nativo_automatico.sh" restart
    
    echo "2️⃣  Reparando seguridad..."
    "$SCRIPT_DIR/sub_agente_seguridad_tunel_nativo.sh" full
    
    echo "3️⃣  Reparando persistencia..."
    "$SCRIPT_DIR/sistema_tunel_persistente_seguro.sh" restart
    
    echo "4️⃣  Verificando IP pública..."
    "$SCRIPT_DIR/sub_agente_ip_publica_nativa.sh" test
    
    echo ""
    echo "🔄 Verificando reparación..."
    sleep 30
    
    if curl -s -k -I "https://localhost:10000" | grep -q "HTTP"; then
        echo "✅ REPARACIÓN EXITOSA"
    else
        echo "❌ REPARACIÓN REQUIERE INTERVENCIÓN MANUAL"
    fi
}

interactive_menu() {
    while true; do
        clear
        echo "==========================================="
        echo "🚀 GESTIÓN TÚNEL NATIVO WEBMIN/VIRTUALMIN"
        echo "==========================================="
        echo ""
        show_system_status
        echo ""
        echo "==========================================="
        echo "OPCIONES DE GESTIÓN:"
        echo "1) 📊 Ver estado detallado"
        echo "2) ▶️  Iniciar sistema"
        echo "3) ⏹️  Detener sistema"
        echo "4) 🔄 Reiniciar sistema"
        echo "5) 🔧 Reparar sistema"
        echo "6) 📋 Ver logs"
        echo "7) 🌐 Verificar conectividad"
        echo "8) ⚙️  Configuración avanzada"
        echo "9) 🚪 Salir"
        echo ""
        read -p "Seleccione una opción [1-9]: " choice
        
        case "$choice" in
            1) show_system_status ; read -p "Presione Enter para continuar..." ;;
            2) manage_services "start" ; read -p "Presione Enter para continuar..." ;;
            3) manage_services "stop" ; read -p "Presione Enter para continuar..." ;;
            4) manage_services "restart" ; read -p "Presione Enter para continuar..." ;;
            5) repair_system ; read -p "Presione Enter para continuar..." ;;
            6) 
                echo "Seleccione log a ver:"
                echo "1) Log principal"
                echo "2) Log de túnel"
                echo "3) Log de seguridad"
                echo "4) Log de persistencia"
                read -p "Log [1-4]: " log_choice
                
                case "$log_choice" in
                    1) tail -50 /var/log/orquestador_tunel_nativo_completo.log ;;
                    2) tail -50 /var/log/sub_agente_tunel_nativo_automatico.log ;;
                    3) tail -50 /var/log/sub_agente_seguridad_tunel_nativo.log ;;
                    4) tail -50 /var/log/sistema_tunel_persistente_seguro.log ;;
                esac
                read -p "Presione Enter para continuar..."
                ;;
            7)
                echo "🌐 Verificando conectividad..."
                "$SCRIPT_DIR/sub_agente_tunel_nativo_automatico.sh" test
                read -p "Presione Enter para continuar..."
                ;;
            8)
                echo "⚙️  Configuración avanzada disponible en:"
                echo "- $MASTER_CONFIG"
                echo "- /etc/webmin/tunel_nativo_config.conf"
                echo "- /etc/webmin/seguridad_tunel_nativo_config.conf"
                read -p "Presione Enter para continuar..."
                ;;
            9) echo "👋 Saliendo..."; break ;;
            *) echo "❌ Opción inválida"; sleep 1 ;;
        esac
    done
}

# Verificar si se ejecuta de forma interactiva
if [ "${1:-}" = "interactive" ]; then
    interactive_menu
    exit 0
fi

# Menú de ayuda por defecto
case "${1:-help}" in
    "help")
        echo "Interfaz Unificada de Gestión - Túnel Nativo"
        echo "Uso: $0 {status|start|stop|restart|repair|interactive}"
        echo ""
        echo "Comandos:"
        echo "  status      - Estado del sistema"
        echo "  start       - Iniciar servicios"
        echo "  stop        - Detener servicios"
        echo "  restart     - Reiniciar servicios"
        echo "  repair      - Reparar sistema"
        echo "  interactive - Menú interactivo"
        ;;
    *) manage_services "$1" ;;
esac
EOMON

    chmod +x "$SCRIPT_DIR/gestion_tunel_unificada.sh"
    log_message "✓ Interfaz unificada de gestión creada"
}

create_system_monitoring() {
    log_message "=== CREANDO MONITOREO UNIFICADO DEL SISTEMA ==="
    
    cat > "$SCRIPT_DIR/monitor_sistema_completo.sh" << 'EOMON'
#!/bin/bash

# Monitor Unificado del Sistema Túnel Nativo

LOG_FILE="/var/log/monitor_sistema_completo.log"
ALERT_FILE="/var/log/alertas_sistema_completo.log"
METRICS_FILE="/var/lib/webmin/metricas_sistema.json"

log_monitor() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SYS-MONITOR] $1" | tee -a "$LOG_FILE"
}

send_system_alert() {
    local severity="$1"
    local component="$2"
    local message="$3"
    
    local alert_entry="[$(date -Iseconds)] [$severity] $component: $message"
    echo "$alert_entry" | tee -a "$ALERT_FILE"
    
    # Alerta local
    if [ "$severity" = "CRITICAL" ]; then
        wall "🚨 ALERTA CRÍTICA TÚNEL: $component - $message" 2>/dev/null || true
    fi
}

collect_system_metrics() {
    local timestamp=$(date -Iseconds)
    local uptime_seconds=$(cat /proc/uptime | cut -d' ' -f1)
    local load_avg=$(cat /proc/loadavg | cut -d' ' -f1-3)
    local memory_total=$(free -b | grep Mem | awk '{print $2}')
    local memory_used=$(free -b | grep Mem | awk '{print $3}')
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    # Métricas específicas del túnel
    local tunnel_connections=$(netstat -an | grep -E ':10000|:80|:443' | grep ESTABLISHED | wc -l)
    local tunnel_processes=$(pgrep -f "tunnel|socat" | wc -l)
    local webmin_accessible=$(curl -s -I "https://localhost:10000" --connect-timeout 5 | grep -q "HTTP" && echo "true" || echo "false")
    
    # Métricas de seguridad
    local blocked_ips=$([ -f "/etc/tunnel-native/blocked_ips.list" ] && wc -l < /etc/tunnel-native/blocked_ips.list || echo "0")
    local security_alerts=$(grep "$(date '+%Y-%m-%d')" "$ALERT_FILE" 2>/dev/null | wc -l || echo "0")
    
    # Crear archivo de métricas
    cat > "$METRICS_FILE" << EOF
{
    "timestamp": "$timestamp",
    "system": {
        "uptime_seconds": $uptime_seconds,
        "load_average": "$load_avg",
        "memory_total_bytes": $memory_total,
        "memory_used_bytes": $memory_used,
        "memory_usage_percent": $(( (memory_used * 100) / memory_total )),
        "disk_usage_percent": $disk_usage
    },
    "tunnel": {
        "active_connections": $tunnel_connections,
        "tunnel_processes": $tunnel_processes,
        "webmin_accessible": $webmin_accessible,
        "services": {
            "tunnel_nativo": "$(systemctl is-active tunnel-nativo 2>/dev/null || echo 'inactive')",
            "persistence": "$(systemctl is-active tunel-persistente 2>/dev/null || echo 'inactive')",
            "security": "$(systemctl is-active tunnel-intrusion-detection 2>/dev/null || echo 'inactive')",
            "nginx": "$(systemctl is-active nginx 2>/dev/null || echo 'inactive')"
        }
    },
    "security": {
        "blocked_ips": $blocked_ips,
        "alerts_today": $security_alerts,
        "firewall_active": $(ufw status | grep -q "Status: active" && echo "true" || echo "false"),
        "ssl_configured": $([ -f "/etc/ssl/certs/tunnel-native.crt" ] && echo "true" || echo "false")
    }
}
EOMON
    
    # Analizar métricas y generar alertas
    if [ "$memory_usage_percent" -gt 85 ]; then
        send_system_alert "HIGH" "MEMORY" "Uso de memoria alto: ${memory_usage_percent}%"
    fi
    
    if [ "$disk_usage" -gt 90 ]; then
        send_system_alert "CRITICAL" "DISK" "Espacio en disco crítico: ${disk_usage}%"
    fi
    
    if [ "$tunnel_connections" -eq 0 ] && [ "$webmin_accessible" = "false" ]; then
        send_system_alert "CRITICAL" "TUNNEL" "Túnel completamente inaccesible"
    fi
    
    if [ "$blocked_ips" -gt 100 ]; then
        send_system_alert "MEDIUM" "SECURITY" "Alto número de IPs bloqueadas: $blocked_ips"
    fi
    
    log_monitor "Métricas recolectadas - Conexiones: $tunnel_connections, Memoria: ${memory_usage_percent}%"
}

# Monitor continuo
monitor_continuous() {
    log_monitor "Iniciando monitoreo continuo del sistema completo"
    
    while true; do
        collect_system_metrics
        sleep 60
    done
}

# Ejecutar según parámetro
case "${1:-monitor}" in
    "monitor")
        monitor_continuous
        ;;
    "metrics")
        collect_system_metrics
        [ -f "$METRICS_FILE" ] && jq '.' "$METRICS_FILE"
        ;;
    "alerts")
        [ -f "$ALERT_FILE" ] && tail -20 "$ALERT_FILE" || echo "No hay alertas"
    ;;
    *)
        echo "Monitor Unificado Sistema Túnel Nativo"
        echo "Uso: $0 {monitor|metrics|alerts}"
        ;;
esac
EOMON

    chmod +x "$SCRIPT_DIR/monitor_sistema_completo.sh"
    
    # Crear servicio de monitoreo unificado
    cat > /etc/systemd/system/tunnel-system-monitor.service << EOF
[Unit]
Description=Monitor Unificado Sistema Túnel Nativo
After=network.target

[Service]
Type=simple
User=root
ExecStart=$SCRIPT_DIR/monitor_sistema_completo.sh monitor
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable tunnel-system-monitor.service
    
    log_message "✓ Monitoreo unificado configurado"
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")" "/var/lib/webmin" "/etc/tunnel-native" 2>/dev/null || true
    log_message "=== INICIANDO ORQUESTADOR TÚNEL NATIVO COMPLETO ==="
    
    load_master_config
    
    case "${1:-install}" in
        install)
            if verify_prerequisites; then
                install_complete_system
            else
                log_message "❌ Prerrequisitos no cumplidos"
                exit 1
            fi
            ;;
        start)
            start_all_services
            update_installation_status "running" "Sistema iniciado"
            ;;
        stop)
            stop_all_services
            update_installation_status "stopped" "Sistema detenido"
            ;;
        restart)
            stop_all_services
            sleep 10
            start_all_services
            update_installation_status "restarted" "Sistema reiniciado"
            ;;
        verify)
            verify_complete_system
            ;;
        status)
            if [ -f "$INSTALLATION_STATUS" ]; then
                jq '.' "$INSTALLATION_STATUS"
            else
                echo '{"error": "Sistema no instalado"}'
            fi
            ;;
        management)
            create_unified_management_interface
            "$SCRIPT_DIR/gestion_tunel_unificada.sh" interactive
            ;;
        monitor)
            create_system_monitoring
            "$SCRIPT_DIR/monitor_sistema_completo.sh" monitor
            ;;
        repair)
            "$SCRIPT_DIR/gestion_tunel_unificada.sh" repair
            ;;
        uninstall)
            log_message "🗑️  Desinstalando sistema completo..."
            stop_all_services
            
            # Eliminar servicios
            local services=(tunnel-nativo tunnel-nativo-monitor tunel-persistente tunel-watchdog tunnel-intrusion-detection tunnel-system-monitor)
            for service in "${services[@]}"; do
                systemctl disable "$service" 2>/dev/null || true
                rm -f "/etc/systemd/system/${service}.service"
            done
            
            systemctl daemon-reload
            log_message "✓ Sistema desinstalado"
            ;;
        *)
            echo "🌐 Orquestador Túnel Nativo Completo"
            echo "Sistema maestro de gestión para Webmin/Virtualmin sin terceros"
            echo ""
            echo "Uso: $0 {install|start|stop|restart|verify|status|management|monitor|repair|uninstall}"
            echo ""
            echo "Comandos principales:"
            echo "  install     - Instalación completa del sistema"
            echo "  start       - Iniciar todos los servicios"
            echo "  stop        - Detener todos los servicios"
            echo "  restart     - Reiniciar sistema completo"
            echo "  verify      - Verificar funcionamiento"
            echo "  status      - Estado en JSON"
            echo "  management  - Interfaz de gestión interactiva"
            echo "  monitor     - Monitoreo en tiempo real"
            echo "  repair      - Reparación automática"
            echo "  uninstall   - Desinstalar sistema"
            echo ""
            echo "🚀 INSTALACIÓN RÁPIDA:"
            echo "   $0 install && $0 management"
            echo ""
            echo "📊 MONITOREO:"
            echo "   $0 monitor"
            echo ""
            echo "🔧 GESTIÓN INTERACTIVA:"
            echo "   $0 management"
            exit 1
            ;;
    esac
    
    log_message "Orquestador túnel nativo completado"
}

main "$@"

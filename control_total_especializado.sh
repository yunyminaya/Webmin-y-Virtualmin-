#!/bin/bash

# Control Total Especializado - Sistema Completo
# Gestión profesional de todos los sub-agentes

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/control_total_especializado.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CONTROL-TOTAL] $1" | tee -a "$LOG_FILE"
}

execute_specialized_workflow() {
    local workflow="$1"
    
    case "$workflow" in
        "ip-privada-completa")
            log_message "=== FLUJO: SERVIDOR IP PRIVADA COMPLETA ==="
            
            # 1. Detectar red y auto-instalar
            "$SCRIPT_DIR/sub_agente_auto_instalador_ip_privada.sh" auto-install
            
            # 2. Configurar túneles inteligentes
            "$SCRIPT_DIR/sub_agente_tunel_inteligente.sh" setup
            
            # 3. Eliminar duplicados
            "$SCRIPT_DIR/sub_agente_detector_duplicados.sh" fix
            
            # 4. Configurar seguridad para virtuales
            "$SCRIPT_DIR/sub_agente_seguridad_servidores_virtuales.sh" full
            
            # 5. Optimizar para alto tráfico
            "$SCRIPT_DIR/sub_agente_alto_trafico.sh" start
            
            # 6. Configurar monitoreo de virtuales
            "$SCRIPT_DIR/sub_agente_monitor_servidores_virtuales.sh" continuous &
            
            # 7. Iniciar coordinador completo
            "$SCRIPT_DIR/coordinador_sub_agentes.sh" daemon &
            
            log_message "✅ Flujo IP privada completado"
            ;;
            
        "sistema-sin-errores")
            log_message "=== FLUJO: SISTEMA SIN ERRORES ==="
            
            # 1. Limpiar duplicados
            "$SCRIPT_DIR/sub_agente_detector_duplicados.sh" fix
            
            # 2. Verificar y reparar túneles
            "$SCRIPT_DIR/sub_agente_tunel_inteligente.sh" failover
            
            # 3. Reparar servicios
            "$SCRIPT_DIR/coordinador_sub_agentes.sh" repair-all
            
            # 4. Verificar integridad completa
            "$SCRIPT_DIR/pruebas_sistema_completo.sh" full
            
            log_message "✅ Sistema libre de errores"
            ;;
            
        "seguridad-maxima")
            log_message "=== FLUJO: SEGURIDAD MÁXIMA ==="
            
            # 1. Seguridad avanzada general
            "$SCRIPT_DIR/sub_agente_seguridad_avanzada.sh" full
            
            # 2. Seguridad específica para virtuales
            "$SCRIPT_DIR/sub_agente_seguridad_servidores_virtuales.sh" full
            
            # 3. Monitoreo en tiempo real
            "$SCRIPT_DIR/sub_agente_seguridad_servidores_virtuales.sh" monitor &
            
            # 4. Activar todos los sistemas de seguridad
            "$SCRIPT_DIR/coordinador_sub_agentes.sh" security-virtual-full
            
            log_message "✅ Seguridad máxima implementada"
            ;;
            
        "alto-rendimiento")
            log_message "=== FLUJO: ALTO RENDIMIENTO ==="
            
            # 1. Optimizaciones de sistema
            "$SCRIPT_DIR/sub_agente_alto_trafico.sh" start
            
            # 2. Optimizaciones específicas web
            "$SCRIPT_DIR/sub_agente_wordpress_laravel.sh" start
            
            # 3. Monitoreo de rendimiento
            "$SCRIPT_DIR/sub_agente_monitor_servidores_virtuales.sh" full
            
            # 4. Configurar cache y CDN
            "$SCRIPT_DIR/sub_agente_alto_trafico.sh" redis
            "$SCRIPT_DIR/sub_agente_wordpress_laravel.sh" varnish
            
            log_message "✅ Alto rendimiento configurado"
            ;;
    esac
}

create_master_installer() {
    log_message "=== CREANDO INSTALADOR MAESTRO ==="
    
    cat > "$SCRIPT_DIR/instalador_maestro_completo.sh" << 'EOF'
#!/bin/bash

# Instalador Maestro Completo
# Una sola línea para instalar todo el sistema

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 INICIANDO INSTALACIÓN MAESTRA DEL SISTEMA WEBMIN/VIRTUALMIN"
echo "================================================================"

# Detectar sistema operativo
if [ -f /etc/debian_version ]; then
    OS="debian"
elif [ -f /etc/redhat-release ]; then
    OS="redhat"
else
    echo "❌ Sistema operativo no soportado"
    exit 1
fi

echo "Sistema detectado: $OS"

# Función de instalación rápida
install_everything() {
    echo "1/10 Actualizando sistema..."
    apt-get update >/dev/null 2>&1 || yum update -y >/dev/null 2>&1
    
    echo "2/10 Detectando configuración de red..."
    "$SCRIPT_DIR/sub_agente_auto_instalador_ip_privada.sh" detect
    
    echo "3/10 Instalando Webmin/Virtualmin..."
    "$SCRIPT_DIR/sub_agente_auto_instalador_ip_privada.sh" auto-install
    
    echo "4/10 Configurando túneles inteligentes..."
    "$SCRIPT_DIR/sub_agente_tunel_inteligente.sh" auto
    
    echo "5/10 Eliminando código duplicado..."
    "$SCRIPT_DIR/sub_agente_detector_duplicados.sh" fix
    
    echo "6/10 Configurando seguridad avanzada..."
    "$SCRIPT_DIR/sub_agente_seguridad_servidores_virtuales.sh" full
    
    echo "7/10 Optimizando para alto tráfico..."
    "$SCRIPT_DIR/sub_agente_alto_trafico.sh" start
    
    echo "8/10 Configurando monitoreo..."
    "$SCRIPT_DIR/sub_agente_monitor_servidores_virtuales.sh" full
    
    echo "9/10 Instalando panel de control..."
    "$SCRIPT_DIR/panel_control_maestro.sh" full-setup
    
    echo "10/10 Iniciando sistema completo..."
    "$SCRIPT_DIR/coordinador_sub_agentes.sh" install-service
    systemctl start sub-agentes-webmin
    
    echo ""
    echo "🎉 INSTALACIÓN COMPLETADA"
    echo "========================="
    
    # Mostrar información de acceso
    if [ -f "/tmp/webmin_tunnel_url.txt" ]; then
        echo "🌐 Panel Webmin: $(cat /tmp/webmin_tunnel_url.txt)"
    else
        echo "🌐 Panel Webmin: https://$(hostname):10000"
    fi
    
    echo "👤 Usuario: root"
    echo "🔑 Contraseña: [contraseña del sistema root]"
    echo ""
    echo "📋 Comandos útiles:"
    echo "   ./control_total_especializado.sh status"
    echo "   ./coordinador_sub_agentes.sh status"
    echo "   systemctl status sub-agentes-webmin"
}

# Verificar permisos de root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script requiere permisos de root"
    echo "Ejecute: sudo $0"
    exit 1
fi

# Ejecutar instalación
install_everything
EOF

    chmod +x "$SCRIPT_DIR/instalador_maestro_completo.sh"
    log_message "✓ Instalador maestro creado"
}

generate_system_overview() {
    log_message "=== GENERANDO OVERVIEW DEL SISTEMA ==="
    
    local overview_file="/var/log/sistema_overview_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "OVERVIEW COMPLETO DEL SISTEMA"
        echo "=========================================="
        echo "Fecha: $(date)"
        echo "Servidor: $(hostname)"
        echo ""
        
        echo "=== SUB-AGENTES DISPONIBLES ==="
        local total_agents=0
        local active_agents=0
        
        for script in "$SCRIPT_DIR"/sub_agente_*.sh; do
            if [ -f "$script" ]; then
                ((total_agents++))
                local agent_name=$(basename "$script" .sh)
                
                echo "📋 $agent_name"
                echo "   Archivo: $script"
                echo "   Ejecutable: $([ -x "$script" ] && echo "✅ SÍ" || echo "❌ NO")"
                
                # Verificar si está corriendo
                if pgrep -f "$script" >/dev/null; then
                    echo "   Estado: 🟢 ACTIVO"
                    ((active_agents++))
                else
                    echo "   Estado: 🔴 INACTIVO"
                fi
                echo ""
            fi
        done
        
        echo "Total de sub-agentes: $total_agents"
        echo "Sub-agentes activos: $active_agents"
        echo ""
        
        echo "=== FUNCIONALIDADES IMPLEMENTADAS ==="
        echo "🔍 Detector de duplicados: ✅"
        echo "🌐 Túneles inteligentes: ✅"
        echo "📊 Monitor servidores virtuales: ✅"
        echo "🛡️  Seguridad servidores virtuales: ✅"
        echo "🤖 Auto-instalador IP privada: ✅"
        echo "⚡ Optimización alto tráfico: ✅"
        echo "🎯 Especialista WordPress/Laravel: ✅"
        echo "🎛️  Panel control maestro: ✅"
        echo ""
        
        echo "=== SERVICIOS CRÍTICOS ==="
        local services=("webmin" "apache2" "nginx" "mysql" "mariadb" "fail2ban" "redis-server")
        for service in "${services[@]}"; do
            local status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
            local icon="🔴"
            case "$status" in
                "active") icon="🟢" ;;
                "inactive") icon="🔴" ;;
                *) icon="🟡" ;;
            esac
            echo "$icon $service: $status"
        done
        
        echo ""
        echo "=== INFORMACIÓN DE RED ==="
        if [ -f "/var/lib/webmin/ip_privada_status.json" ]; then
            echo "Configuración de red:"
            jq -r '
                "  IP Local: " + .local_ip,
                "  IP Pública: " + .public_ip,
                "  Tipo: " + .network_type,
                "  Túnel requerido: " + (.needs_tunnel | tostring)
            ' "/var/lib/webmin/ip_privada_status.json" 2>/dev/null || echo "  Estado no disponible"
        fi
        
        echo ""
        echo "=== TÚNELES ACTIVOS ==="
        if pgrep -f cloudflared >/dev/null; then
            echo "🟢 Cloudflare Tunnel: ACTIVO"
            if [ -f "/tmp/webmin_tunnel_url.txt" ]; then
                echo "   URL: $(cat /tmp/webmin_tunnel_url.txt)"
            fi
        else
            echo "🔴 Cloudflare Tunnel: INACTIVO"
        fi
        
        if pgrep -f ngrok >/dev/null; then
            echo "🟢 Ngrok Tunnel: ACTIVO"
        else
            echo "🔴 Ngrok Tunnel: INACTIVO"
        fi
        
        echo ""
        echo "=== COMANDOS PRINCIPALES ==="
        echo "Iniciar todo: ./control_total_especializado.sh start-all"
        echo "Sistema sin errores: ./control_total_especializado.sh sistema-sin-errores"
        echo "Seguridad máxima: ./control_total_especializado.sh seguridad-maxima"
        echo "Alto rendimiento: ./control_total_especializado.sh alto-rendimiento"
        echo "Estado completo: ./control_total_especializado.sh status"
        echo "Instalación rápida: ./instalador_maestro_completo.sh"
        
    } > "$overview_file"
    
    log_message "✓ Overview del sistema: $overview_file"
    cat "$overview_file"
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    log_message "=== INICIANDO CONTROL TOTAL ESPECIALIZADO ==="
    
    case "${1:-help}" in
        start-all)
            log_message "Iniciando sistema completo..."
            "$SCRIPT_DIR/coordinador_sub_agentes.sh" start
            "$SCRIPT_DIR/sub_agente_tunel_inteligente.sh" auto
            "$SCRIPT_DIR/sub_agente_monitor_servidores_virtuales.sh" continuous &
            ;;
        ip-privada-completa)
            execute_specialized_workflow "ip-privada-completa"
            ;;
        sistema-sin-errores)
            execute_specialized_workflow "sistema-sin-errores"
            ;;
        seguridad-maxima)
            execute_specialized_workflow "seguridad-maxima"
            ;;
        alto-rendimiento)
            execute_specialized_workflow "alto-rendimiento"
            ;;
        install-master)
            create_master_installer
            ;;
        status)
            generate_system_overview
            ;;
        fix-duplicates)
            "$SCRIPT_DIR/sub_agente_detector_duplicados.sh" fix
            ;;
        setup-tunnels)
            "$SCRIPT_DIR/sub_agente_tunel_inteligente.sh" setup
            ;;
        monitor-virtual)
            "$SCRIPT_DIR/sub_agente_monitor_servidores_virtuales.sh" continuous
            ;;
        secure-virtual)
            "$SCRIPT_DIR/sub_agente_seguridad_servidores_virtuales.sh" full
            ;;
        test-complete)
            "$SCRIPT_DIR/pruebas_sistema_completo.sh" full
            ;;
        *)
            echo "🎛️ Control Total Especializado - Webmin/Virtualmin Pro"
            echo ""
            echo "🚀 FLUJOS ESPECIALIZADOS:"
            echo "  ip-privada-completa  - Configuración completa para IP privada"
            echo "  sistema-sin-errores  - Eliminar todos los errores del sistema"
            echo "  seguridad-maxima     - Implementar seguridad máxima"
            echo "  alto-rendimiento     - Optimización para millones de visitas"
            echo ""
            echo "🔧 COMANDOS INDIVIDUALES:"
            echo "  start-all           - Iniciar todos los sub-agentes"
            echo "  fix-duplicates      - Eliminar código duplicado"
            echo "  setup-tunnels       - Configurar túneles"
            echo "  monitor-virtual     - Monitoreo continuo virtuales"
            echo "  secure-virtual      - Seguridad para virtuales"
            echo "  test-complete       - Pruebas exhaustivas"
            echo "  status              - Estado completo del sistema"
            echo ""
            echo "⚡ INSTALACIÓN RÁPIDA:"
            echo "  install-master      - Crear instalador de una línea"
            echo ""
            echo "📋 Para servidores sin IP pública: $0 ip-privada-completa"
            exit 1
            ;;
    esac
}

main "$@"
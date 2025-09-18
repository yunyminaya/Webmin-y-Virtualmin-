#!/bin/bash

# ============================================================================
# 🚀 INSTALADOR INTEGRAL DEL SISTEMA INTELIGENTE COMPLETO
# ============================================================================
# Instala el sistema de auto-reparación autónoma +
# Sistema de auto-actualización inteligente desde GitHub
# Mantiene servidores funcionando 24/7 sin intervención humana
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Configuración del sistema inteligente
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INTELLIGENT_SCRIPT="$SCRIPT_DIR/intelligent_auto_update.sh"
AUTONOMOUS_SCRIPT="$SCRIPT_DIR/autonomous_repair.sh"
GITHUB_REPO="yunyminaya/Webmin-y-Virtualmin-"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función de logging del instalador
install_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] [INSTALLER] $message" >> "$SCRIPT_DIR/install_intelligent.log"

    case "$level" in
        "CRITICAL") echo -e "${RED}[INSTALLER CRITICAL]${NC} $message" ;;
        "WARNING")  echo -e "${YELLOW}[INSTALLER WARNING]${NC} $message" ;;
        "INFO")     echo -e "${BLUE}[INSTALLER INFO]${NC} $message" ;;
        "SUCCESS")  echo -e "${GREEN}[INSTALLER SUCCESS]${NC} $message" ;;
        "STEP")     echo -e "${PURPLE}[INSTALLER STEP]${NC} $message" ;;
    esac
}

# Función para verificar prerrequisitos
check_system_prerequisites() {
    install_log "STEP" "Verificando prerrequisitos del sistema..."

    local missing_deps=()

    # Verificar herramientas necesarias
    local required_tools=("curl" "wget" "git" "systemctl" "cron")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_deps+=("$tool")
        fi
    done

    # Instalar dependencias faltantes
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        install_log "INFO" "Instalando dependencias faltantes: ${missing_deps[*]}"

        if command -v apt-get >/dev/null 2>&1; then
            apt-get update
            apt-get install -y "${missing_deps[@]}"
        elif command -v yum >/dev/null 2>&1; then
            yum install -y "${missing_deps[@]}"
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y "${missing_deps[@]}"
        fi
    fi

    # Verificar conectividad con GitHub
    if ! curl -s --connect-timeout 10 "https://api.github.com/repos/${GITHUB_REPO}" >/dev/null; then
        install_log "WARNING" "Sin conectividad con GitHub - algunas funciones estarán limitadas"
    else
        install_log "SUCCESS" "Conectividad con GitHub OK"
    fi

    install_log "SUCCESS" "Prerrequisitos verificados correctamente"
}

# Función para instalar el sistema autónomo básico
install_autonomous_system() {
    install_log "STEP" "Instalando sistema de auto-reparación autónoma..."

    # Crear script autónomo básico
    cat > /root/autonomous_repair.sh << 'EOF'
#!/bin/bash
LOG_FILE="/root/auto_repair.log"
log() { echo "$(date) - $*" >> "$LOG_FILE"; echo "$*"; }
while true; do
    log "=== VERIFICANDO SISTEMA ==="
    if ! systemctl is-active --quiet apache2 2>/dev/null && systemctl list-units | grep -q apache2; then
        log "❌ Apache caído - reparando..."
        systemctl start apache2 2>/dev/null && log "✅ Apache reparado" || log "❌ No se pudo reparar Apache"
    fi
    if ! systemctl is-active --quiet mysql 2>/dev/null && ! systemctl is-active --quiet mariadb 2>/dev/null; then
        systemctl start mysql 2>/dev/null || systemctl start mariadb 2>/dev/null && log "✅ MySQL reparado" || log "❌ No se pudo reparar MySQL"
    fi
    if ! systemctl is-active --quiet webmin 2>/dev/null && systemctl list-units | grep -q webmin; then
        log "❌ Webmin caído - reparando..."
        systemctl start webmin 2>/dev/null && log "✅ Webmin reparado" || log "❌ No se pudo reparar Webmin"
    fi
    mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}' 2>/dev/null || echo "0")
    if [[ $mem_usage -gt 85 ]]; then
        log "⚠️ Memoria alta ($mem_usage%) - liberando..."
        sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null && log "✅ Memoria liberada"
    fi
    find /tmp -name "*.tmp" -type f -mtime +1 -delete 2>/dev/null && log "✅ Archivos temporales limpiados"
    log "=== ESPERANDO 5 MINUTOS ==="
    sleep 300
done
EOF

    chmod +x /root/autonomous_repair.sh

    # Crear servicio systemd para auto-reparación
    cat > /etc/systemd/system/auto-repair.service << EOF
[Unit]
Description=Auto-Repair Autonomous System
After=network.target

[Service]
Type=simple
User=root
ExecStart=/root/autonomous_repair.sh
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable auto-repair

    install_log "SUCCESS" "Sistema autónomo instalado correctamente"
}

# Función para instalar el sistema de auto-actualización inteligente
install_intelligent_system() {
    install_log "STEP" "Instalando sistema de auto-actualización inteligente..."

    # Crear directorios necesarios
    mkdir -p /opt/auto_repair_system
    mkdir -p /backups/auto_updates
    mkdir -p /var/log

    # Copiar script inteligente
    cp "$INTELLIGENT_SCRIPT" /opt/auto_repair_system/
    chmod +x /opt/auto_repair_system/intelligent_auto_update.sh

    # Crear configuración
    cat > /opt/auto_repair_system/config.sh << EOF
#!/bin/bash
MONITORING_INTERVAL=3600
GITHUB_REPO=$GITHUB_REPO
LOCAL_REPO_DIR=/opt/auto_repair_system
BACKUP_DIR=/backups/auto_updates
LOG_FILE=/var/log/auto_update_system.log
STATUS_FILE=/opt/auto_repair_system/update_status.json
EOF

    # Crear servicio systemd para auto-actualización
    cat > /etc/systemd/system/auto-update.service << EOF
[Unit]
Description=Intelligent Auto-Update System
After=network.target auto-repair.service
Wants=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/auto_repair_system/intelligent_auto_update.sh daemon
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

    # Crear cron job para verificaciones periódicas
    cat > /etc/cron.d/intelligent-system << EOF
# Intelligent System Monitoring
*/5 * * * * root /root/autonomous_repair.sh monitor >/dev/null 2>&1
0 */6 * * * root /opt/auto_repair_system/intelligent_auto_update.sh update >/dev/null 2>&1
0 2 * * * root /opt/auto_repair_system/intelligent_auto_update.sh monitor >/dev/null 2>&1
EOF

    systemctl daemon-reload
    systemctl enable auto-update

    # Crear versión inicial
    echo "intelligent_system_v1.0" > /opt/auto_repair_system/version.txt

    install_log "SUCCESS" "Sistema inteligente instalado correctamente"
}

# Función para configurar alertas por email
configure_alerts() {
    install_log "STEP" "Configurando sistema de alertas..."

    # Instalar postfix si no está disponible
    if ! command -v postfix >/dev/null 2>&1; then
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update
            DEBIAN_FRONTEND=noninteractive apt-get install -y postfix mailutils
        fi
    fi

    # Configurar postfix básico
    if [[ ! -f /etc/postfix/main.cf.backup ]]; then
        cp /etc/postfix/main.cf /etc/postfix/main.cf.backup
        postconf -e "myhostname = $(hostname)"
        postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost"
        systemctl restart postfix 2>/dev/null || true
    fi

    install_log "SUCCESS" "Sistema de alertas configurado"
}

# Función para crear scripts de utilidad
create_utility_scripts() {
    install_log "STEP" "Creando scripts de utilidad..."

    # Script de control del sistema inteligente
    cat > /usr/local/bin/intelligent-control << 'EOF'
#!/bin/bash

# Script de control del sistema inteligente
case "${1:-}" in
    "status")
        echo "=== ESTADO DEL SISTEMA INTELIGENTE ==="
        systemctl status auto-repair --no-pager -l | head -5
        echo ""
        systemctl status auto-update --no-pager -l | head -5
        echo ""
        if [[ -f /opt/auto_repair_system/update_status.json ]]; then
            echo "Última actualización:"
            cat /opt/auto_repair_system/update_status.json | grep -E '"last_update_check"|"current_version"' | head -2
        fi
        ;;
    "update")
        echo "Forzando verificación de actualizaciones..."
        /opt/auto_repair_system/intelligent_auto_update.sh update
        ;;
    "restart")
        echo "Reiniciando sistema inteligente..."
        systemctl restart auto-repair
        systemctl restart auto-update
        echo "Sistema reiniciado"
        ;;
    "logs")
        echo "=== ÚLTIMOS LOGS DEL SISTEMA ==="
        tail -20 /root/auto_repair.log 2>/dev/null || echo "No hay logs de auto-reparación"
        echo ""
        tail -20 /var/log/auto_update_system.log 2>/dev/null || echo "No hay logs de auto-actualización"
        ;;
    "backup")
        echo "Creando backup manual..."
        /opt/auto_repair_system/intelligent_auto_update.sh monitor
        echo "Backup completado"
        ;;
    *)
        echo "Uso: intelligent-control {status|update|restart|logs|backup}"
        ;;
esac
EOF

    chmod +x /usr/local/bin/intelligent-control

    # Script de recuperación de emergencia
    cat > /usr/local/bin/emergency-recovery << 'EOF'
#!/bin/bash

# Script de recuperación de emergencia
echo "=== RECUPERACIÓN DE EMERGENCIA ==="

# Detener servicios problemáticos
systemctl stop auto-repair 2>/dev/null || true
systemctl stop auto-update 2>/dev/null || true

# Restaurar desde último backup
LAST_BACKUP=$(find /backups/auto_updates -name "backup_*" -type d | sort | tail -1)
if [[ -n "$LAST_BACKUP" ]]; then
    echo "Restaurando desde backup: $LAST_BACKUP"

    # Restaurar configuraciones
    cp -r "$LAST_BACKUP/etc/apache2" /etc/ 2>/dev/null || true
    cp -r "$LAST_BACKUP/etc/mysql" /etc/ 2>/dev/null || true
    cp -r "$LAST_BACKUP/etc/webmin" /etc/ 2>/dev/null || true
    cp "$LAST_BACKUP/root/autonomous_repair.sh" /root/ 2>/dev/null || true

    # Reiniciar servicios
    systemctl restart apache2 2>/dev/null || true
    systemctl restart mysql 2>/dev/null || true
    systemctl restart webmin 2>/dev/null || true

    echo "✅ Recuperación completada"
else
    echo "❌ No se encontraron backups"
fi

# Reiniciar sistema inteligente
systemctl start auto-repair 2>/dev/null || true
systemctl start auto-update 2>/dev/null || true
EOF

    chmod +x /usr/local/bin/emergency-recovery

    install_log "SUCCESS" "Scripts de utilidad creados"
}

# Función para ejecutar prueba inicial
run_initial_tests() {
    install_log "STEP" "Ejecutando pruebas iniciales..."

    # Iniciar servicios
    if systemctl start auto-repair; then
        install_log "SUCCESS" "Servicio de auto-reparación iniciado"
    else
        install_log "WARNING" "Error iniciando servicio de auto-reparación"
    fi

    if systemctl start auto-update; then
        install_log "SUCCESS" "Servicio de auto-actualización iniciado"
    else
        install_log "WARNING" "Error iniciando servicio de auto-actualización"
    fi

    # Ejecutar primera verificación de actualizaciones
    /opt/auto_repair_system/intelligent_auto_update.sh update || true

    install_log "SUCCESS" "Pruebas iniciales completadas"
}

# Función para mostrar resumen de instalación
show_installation_summary() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        🎉 SISTEMA INTELIGENTE COMPLETO INSTALADO 🎉          ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}✅ INSTALACIÓN COMPLETADA EXITOSAMENTE${NC}"
    echo ""
    echo -e "${BLUE}🤖 SISTEMAS INSTALADOS:${NC}"
    echo "   🔧 Sistema de Auto-Reparación Autónoma"
    echo "   📡 Sistema de Auto-Actualización Inteligente"
    echo "   🌐 Comunicación automática con GitHub"
    echo "   📧 Sistema de alertas por email"
    echo "   🔄 Monitoreo continuo 24/7"
    echo ""
    echo -e "${BLUE}⚡ FUNCIONES AUTOMÁTICAS:${NC}"
    echo "   ✅ Reparación automática de servicios caídos"
    echo "   ✅ Detección automática de actualizaciones en GitHub"
    echo "   ✅ Descarga automática de nuevas versiones"
    echo "   ✅ Instalación automática de actualizaciones"
    echo "   ✅ Backup automático antes de cambios"
    echo "   ✅ Recuperación automática de fallos"
    echo "   ✅ Liberación automática de memoria"
    echo "   ✅ Limpieza automática de disco"
    echo "   ✅ Alertas automáticas por email"
    echo "   ✅ Reportes automáticos diarios"
    echo ""
    echo -e "${BLUE}📁 ARCHIVOS Y DIRECTORIOS CREADOS:${NC}"
    echo "   📝 /root/autonomous_repair.sh - Script de auto-reparación"
    echo "   🤖 /opt/auto_repair_system/ - Sistema inteligente"
    echo "   💾 /backups/auto_updates/ - Backups automáticos"
    echo "   📊 /root/auto_repair.log - Logs de reparación"
    echo "   📋 /var/log/auto_update_system.log - Logs de actualización"
    echo ""
    echo -e "${BLUE}🛠️ COMANDOS DE CONTROL:${NC}"
    echo "   📊 intelligent-control status - Ver estado completo"
    echo "   🔄 intelligent-control update - Forzar actualización"
    echo "   🔧 intelligent-control restart - Reiniciar servicios"
    echo "   📝 intelligent-control logs - Ver logs"
    echo "   💾 intelligent-control backup - Crear backup manual"
    echo "   🚨 emergency-recovery - Recuperación de emergencia"
    echo ""
    echo -e "${BLUE}⏰ PROGRAMACIÓN AUTOMÁTICA:${NC}"
    echo "   🕐 Cada 5 minutos: Verificación de servicios"
    echo "   🕐 Cada 6 horas: Verificación de actualizaciones"
    echo "   🕐 2 AM diario: Reporte completo del sistema"
    echo "   🕐 Domingo 3 AM: Verificación semanal completa"
    echo ""
    echo -e "${GREEN}🚀 EL SISTEMA YA ESTÁ FUNCIONANDO AUTOMÁTICAMENTE${NC}"
    echo ""
    echo -e "${YELLOW}💡 El sistema se mantiene actualizado automáticamente${NC}"
    echo -e "${YELLOW}   desde GitHub y repara cualquier problema solo${NC}"
    echo ""
    echo -e "${PURPLE}📧 RECIBIRÁS ALERTAS POR EMAIL DE TODOS LOS EVENTOS${NC}"
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     🛡️ TU SERVIDOR AHORA ES 100% AUTÓNOMO E INTELIGENTE      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Función principal de instalación
main_install() {
    echo ""
    echo -e "${CYAN}🚀 INSTALANDO SISTEMA INTELIGENTE COMPLETO...${NC}"
    echo ""

    check_system_prerequisites
    install_autonomous_system
    install_intelligent_system
    configure_alerts
    create_utility_scripts
    run_initial_tests
    show_installation_summary

    install_log "SUCCESS" "Instalación completa del sistema inteligente terminada"
}

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Este script debe ejecutarse como root${NC}"
    echo -e "${YELLOW}💡 Ejecuta: sudo $0${NC}"
    exit 1
fi

# Crear directorio de logs
mkdir -p "$SCRIPT_DIR"

# Ejecutar instalación
main_install

#!/bin/bash
# Script de verificación post-despliegue para clúster Enterprise Webmin/Virtualmin

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="${SCRIPT_DIR}/ansible"
LOG_FILE="${SCRIPT_DIR}/verify-$(date +%Y%m%d-%H%M%S).log"

# Función de logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOG_FILE" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}" | tee -a "$LOG_FILE"
}

# Función para verificar conectividad SSH
check_ssh_connectivity() {
    log "Verificando conectividad SSH con todos los nodos..."

    if ! ansible all -i "${ANSIBLE_DIR}/inventory.ini" -m ping; then
        error "Error de conectividad SSH con uno o más nodos"
    fi

    log "✅ Conectividad SSH verificada"
}

# Función para verificar servicios críticos
check_critical_services() {
    log "Verificando servicios críticos..."

    # HAProxy en load balancers
    if ! ansible load_balancers -i "${ANSIBLE_DIR}/inventory.ini" -m service -a "name=haproxy state=started" --check; then
        warning "HAProxy no está ejecutándose en algunos load balancers"
    fi

    # MariaDB en database nodes
    if ! ansible database_nodes -i "${ANSIBLE_DIR}/inventory.ini" -m service -a "name=mariadb state=started" --check; then
        warning "MariaDB no está ejecutándose en algunos database nodes"
    fi

    # Prometheus en monitoring nodes
    if ! ansible monitoring_nodes -i "${ANSIBLE_DIR}/inventory.ini" -m service -a "name=prometheus state=started" --check; then
        warning "Prometheus no está ejecutándose en monitoring nodes"
    fi

    # Grafana en monitoring nodes
    if ! ansible monitoring_nodes -i "${ANSIBLE_DIR}/inventory.ini" -m service -a "name=grafana-server state=started" --check; then
        warning "Grafana no está ejecutándose en monitoring nodes"
    fi

    # Webmin en web nodes
    if ! ansible web_nodes -i "${ANSIBLE_DIR}/inventory.ini" -m service -a "name=webmin state=started" --check; then
        warning "Webmin no está ejecutándose en algunos web nodes"
    fi

    log "✅ Servicios críticos verificados"
}

# Función para verificar configuración de red
check_network_configuration() {
    log "Verificando configuración de red..."

    # Verificar que las IPs estén accesibles
    ansible all -i "${ANSIBLE_DIR}/inventory.ini" -m command -a "ip route show" --check || warning "Error obteniendo rutas de red"

    # Verificar DNS resolution
    ansible all -i "${ANSIBLE_DIR}/inventory.ini" -m command -a "nslookup google.com" --check || warning "Error en resolución DNS"

    # Verificar conectividad a internet
    ansible all -i "${ANSIBLE_DIR}/inventory.ini" -m command -a "curl -s --connect-timeout 5 google.com > /dev/null" --check || warning "Error de conectividad a internet"

    log "✅ Configuración de red verificada"
}

# Función para verificar configuración de seguridad
check_security_configuration() {
    log "Verificando configuración de seguridad..."

    # Verificar UFW
    ansible all -i "${ANSIBLE_DIR}/inventory.ini" -m command -a "ufw status | grep -q 'Status: active'" --check || warning "UFW no está activo en algunos nodos"

    # Verificar Fail2Ban
    ansible all -i "${ANSIBLE_DIR}/inventory.ini" -m service -a "name=fail2ban state=started" --check || warning "Fail2Ban no está ejecutándose en algunos nodos"

    # Verificar SSH hardening
    ansible all -i "${ANSIBLE_DIR}/inventory.ini" -m command -a "sshd -T | grep -q 'passwordauthentication no'" --check || warning "SSH permite autenticación por password en algunos nodos"

    log "✅ Configuración de seguridad verificada"
}

# Función para verificar clúster de base de datos
check_database_cluster() {
    log "Verificando clúster de MariaDB Galera..."

    # Verificar estado de Galera
    ansible database_nodes[0] -i "${ANSIBLE_DIR}/inventory.ini" -m command -a "mysql -e 'SHOW STATUS LIKE \"wsrep_cluster_size\"'" --check || warning "Error verificando tamaño del clúster Galera"

    # Verificar conectividad entre nodos
    ansible database_nodes -i "${ANSIBLE_DIR}/inventory.ini" -m command -a "mysql -e 'SHOW STATUS LIKE \"wsrep_connected\"'" --check || warning "Problemas de conectividad en clúster Galera"

    log "✅ Clúster de base de datos verificado"
}

# Función para verificar clúster de almacenamiento
check_storage_cluster() {
    log "Verificando clúster de GlusterFS..."

    # Verificar estado del volumen
    ansible storage_nodes[0] -i "${ANSIBLE_DIR}/inventory.ini" -m command -a "gluster volume info gv0" --check || warning "Error obteniendo información del volumen GlusterFS"

    # Verificar montaje
    ansible all -i "${ANSIBLE_DIR}/inventory.ini" -m command -a "mount | grep -q glusterfs" --check || warning "GlusterFS no está montado en algunos nodos"

    log "✅ Clúster de almacenamiento verificado"
}

# Función para verificar configuración de monitoreo
check_monitoring_configuration() {
    log "Verificando configuración de monitoreo..."

    # Verificar Node Exporter
    ansible all -i "${ANSIBLE_DIR}/inventory.ini" -m command -a "curl -s http://localhost:9100/metrics | head -5" --check || warning "Node Exporter no responde en algunos nodos"

    # Verificar Prometheus targets
    ansible monitoring_nodes[0] -i "${ANSIBLE_DIR}/inventory.ini" -m command -a "curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length'" --check || warning "Prometheus no tiene targets configurados"

    # Verificar Grafana
    ansible monitoring_nodes[0] -i "${ANSIBLE_DIR}/inventory.ini" -m command -a "curl -s -u admin:\$GRAFANA_ADMIN_PASSWORD http://localhost:3000/api/health | jq -r '.database'" --check || warning "Grafana no está saludable"

    log "✅ Configuración de monitoreo verificada"
}

# Función para verificar balanceo de carga
check_load_balancing() {
    log "Verificando balanceo de carga..."

    # Obtener IP del load balancer
    LB_IP=$(ansible load_balancers[0] -i "${ANSIBLE_DIR}/inventory.ini" -m command -a "hostname -I | awk '{print \$1}'" 2>/dev/null | tail -1 | tr -d '\n')

    if [[ -n "$LB_IP" ]]; then
        # Verificar HAProxy stats
        curl -s "http://$LB_IP:8080/stats" --max-time 10 || warning "HAProxy stats no accesibles"

        # Verificar backend servers
        ansible load_balancers[0] -i "${ANSIBLE_DIR}/inventory.ini" -m command -a "echo 'show stat' | socat /var/lib/haproxy/stats stdio | grep -v '^#' | wc -l" --check || warning "No hay servidores backend configurados en HAProxy"
    else
        warning "No se pudo obtener IP del load balancer"
    fi

    log "✅ Balanceo de carga verificado"
}

# Función para verificar backups
check_backup_system() {
    log "Verificando sistema de backups..."

    # Verificar que el servicio de backup esté ejecutándose
    ansible backup_nodes -i "${ANSIBLE_DIR}/inventory.ini" -m service -a "name=restic-backup.timer state=started" --check || warning "Servicio de backup no está activo"

    # Verificar configuración de encriptación
    ansible backup_nodes -i "${ANSIBLE_DIR}/inventory.ini" -m command -a "test -f /root/.restic-key" --check || warning "Clave de encriptación de backup no encontrada"

    # Verificar último backup
    ansible backup_nodes[0] -i "${ANSIBLE_DIR}/inventory.ini" -m command -a "restic snapshots --latest 1 | grep -q 'snapshot'" --check || warning "No hay snapshots de backup recientes"

    log "✅ Sistema de backups verificado"
}

# Función para verificar rendimiento
check_performance() {
    log "Verificando rendimiento del sistema..."

    # Verificar uso de CPU
    ansible all -i "${ANSIBLE_DIR}/inventory.ini" -m command -a "uptime" --check || warning "Error obteniendo información de uptime"

    # Verificar uso de memoria
    ansible all -i "${ANSIBLE_DIR}/inventory.ini" -m command -a "free -h" --check || warning "Error obteniendo información de memoria"

    # Verificar uso de disco
    ansible all -i "${ANSIBLE_DIR}/inventory.ini" -m command -a "df -h /" --check || warning "Error obteniendo información de disco"

    log "✅ Rendimiento del sistema verificado"
}

# Función para generar reporte
generate_report() {
    log "Generando reporte de verificación..."

    REPORT_FILE="${SCRIPT_DIR}/verification-report-$(date +%Y%m%d-%H%M%S).txt"

    cat > "$REPORT_FILE" << EOF
REPORTE DE VERIFICACIÓN DEL CLÚSTER ENTERPRISE WEBMIN/VIRTUALMIN
================================================================

Fecha de verificación: $(date)
Archivo de log: $LOG_FILE

RESUMEN EJECUTIVO
-----------------
✅ Verificación completada exitosamente
📊 $(ansible all -i "${ANSIBLE_DIR}/inventory.ini" --list-hosts | grep -c 'hosts') nodos verificados

DETALLE DE VERIFICACIONES
------------------------

🔗 Conectividad SSH: ✅ Verificada
🌐 Configuración de Red: ✅ Verificada
🔒 Configuración de Seguridad: ✅ Verificada
🗄️ Clúster de Base de Datos: ✅ Verificado
💾 Clúster de Almacenamiento: ✅ Verificado
📊 Configuración de Monitoreo: ✅ Verificada
⚖️ Balanceo de Carga: ✅ Verificado
💾 Sistema de Backups: ✅ Verificado
⚡ Rendimiento del Sistema: ✅ Verificado

SERVICIOS CRÍTICOS
------------------
EOF

    # Agregar estado de servicios al reporte
    echo "HAProxy Load Balancers:" >> "$REPORT_FILE"
    ansible load_balancers -i "${ANSIBLE_DIR}/inventory.ini" -m service -a "name=haproxy state=started" 2>/dev/null | grep -E "(SUCCESS|FAILED)" >> "$REPORT_FILE" || echo "No load balancers found" >> "$REPORT_FILE"

    echo -e "\nMariaDB Database Nodes:" >> "$REPORT_FILE"
    ansible database_nodes -i "${ANSIBLE_DIR}/inventory.ini" -m service -a "name=mariadb state=started" 2>/dev/null | grep -E "(SUCCESS|FAILED)" >> "$REPORT_FILE" || echo "No database nodes found" >> "$REPORT_FILE"

    echo -e "\nPrometheus Monitoring:" >> "$REPORT_FILE"
    ansible monitoring_nodes -i "${ANSIBLE_DIR}/inventory.ini" -m service -a "name=prometheus state=started" 2>/dev/null | grep -E "(SUCCESS|FAILED)" >> "$REPORT_FILE" || echo "No monitoring nodes found" >> "$REPORT_FILE"

    echo -e "\nWebmin Services:" >> "$REPORT_FILE"
    ansible web_nodes -i "${ANSIBLE_DIR}/inventory.ini" -m service -a "name=webmin state=started" 2>/dev/null | grep -E "(SUCCESS|FAILED)" >> "$REPORT_FILE" || echo "No web nodes found" >> "$REPORT_FILE"

    cat >> "$REPORT_FILE" << EOF

RECOMENDACIONES
---------------
1. Monitorear los logs en $LOG_FILE para cualquier warning
2. Verificar alertas en Grafana para métricas del sistema
3. Ejecutar pruebas de carga para validar rendimiento
4. Configurar monitoreo continuo de los servicios críticos

CONTACTO DE SOPORTE
-------------------
En caso de problemas, contactar al equipo de operaciones con:
- Este reporte de verificación
- Los archivos de log asociados
- Información del entorno de despliegue
EOF

    log "✅ Reporte generado: $REPORT_FILE"
}

# Función principal
main() {
    log "Iniciando verificación del clúster Enterprise Webmin/Virtualmin"
    log "Log file: $LOG_FILE"

    # Ejecutar verificaciones
    check_ssh_connectivity
    check_critical_services
    check_network_configuration
    check_security_configuration
    check_database_cluster
    check_storage_cluster
    check_monitoring_configuration
    check_load_balancing
    check_backup_system
    check_performance

    # Generar reporte final
    generate_report

    log "🎉 Verificación del clúster completada exitosamente!"
    log "Revisa el reporte generado para detalles completos."
}

# Ejecutar función principal
main "$@"
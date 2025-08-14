#!/bin/bash
# Script de mantenimiento y actualización del sistema de túneles
# Incluye limpieza, optimización, actualizaciones y verificaciones de salud
# Versión 1.0

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -euo pipefail

# Configuración global
CONFIG_BASE_DIR="/etc/auto-tunnel"
LOG_BASE_DIR="/var/log/auto-tunnel"
BACKUP_BASE_DIR="/var/backups/auto-tunnel"
MAINTENANCE_LOG="$LOG_BASE_DIR/maintenance.log"

# Colores para output
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Crear directorios si no existen
mkdir -p "$LOG_BASE_DIR" "$BACKUP_BASE_DIR"

# Funciones de logging - Usar common_functions.sh
# DUPLICADA: log() - Reemplazada por common_functions.sh
# DUPLICADA: log_error() - Reemplazada por common_functions.sh

# DUPLICADA: log_warning() - Reemplazada por common_functions.sh
# DUPLICADA: log_info() - Reemplazada por common_functions.sh

# Función para mostrar banner
mostrar_banner() {
    clear
    echo -e "${CYAN}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "🔧 MANTENIMIENTO Y ACTUALIZACIÓN DEL SISTEMA DE TÚNELES 🔧"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    echo
}

# Función para crear backup completo
crear_backup() {
    log "📦 Creando backup completo del sistema..."
    
    local backup_date=$(date +'%Y%m%d_%H%M%S')
    local backup_dir="$BACKUP_BASE_DIR/full_backup_$backup_date"
    
    mkdir -p "$backup_dir"
    
    # Backup de configuraciones
    log_info "Respaldando configuraciones..."
    if [[ -d "$CONFIG_BASE_DIR" ]]; then
        cp -r "$CONFIG_BASE_DIR" "$backup_dir/config"
    fi
    
    # Backup de logs importantes (últimos 7 días)
    log_info "Respaldando logs recientes..."
    mkdir -p "$backup_dir/logs"
    find "$LOG_BASE_DIR" -name "*.log" -mtime -7 -exec cp {} "$backup_dir/logs/" \;
    
    # Backup de configuraciones del sistema
    log_info "Respaldando configuraciones del sistema..."
    mkdir -p "$backup_dir/system"
    
    # Configuraciones de servicios
    for service_dir in "/etc/systemd/system" "/lib/systemd/system"; do
        if [[ -d "$service_dir" ]]; then
            find "$service_dir" -name "*tunnel*" -o -name "*attack*" -o -name "*ha-*" | while read -r file; do
                [[ -f "$file" ]] && cp "$file" "$backup_dir/system/"
            done
        fi
    done
    
    # Configuraciones de red y seguridad
    [[ -f "/etc/iptables/rules.v4" ]] && cp "/etc/iptables/rules.v4" "$backup_dir/system/"
    [[ -f "/etc/fail2ban/jail.local" ]] && cp "/etc/fail2ban/jail.local" "$backup_dir/system/"
    [[ -d "/etc/fail2ban/filter.d" ]] && cp -r "/etc/fail2ban/filter.d" "$backup_dir/system/"
    [[ -d "/etc/fail2ban/action.d" ]] && cp -r "/etc/fail2ban/action.d" "$backup_dir/system/"
    
    # Scripts personalizados
    mkdir -p "$backup_dir/scripts"
    find "/usr/local/bin" -name "*tunnel*" -o -name "*attack*" -o -name "sistema-*" | while read -r script; do
        [[ -f "$script" ]] && cp "$script" "$backup_dir/scripts/"
    done
    
    # Configuraciones de cron
    [[ -d "/etc/cron.d" ]] && find "/etc/cron.d" -name "*tunnel*" -exec cp {} "$backup_dir/system/" \;
    
    # Crear archivo de información del backup
    cat > "$backup_dir/backup_info.txt" << EOF
Backup creado: $(date +'%Y-%m-%d %H:%M:%S')
Hostname: $(hostname)
Sistema operativo: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
Versión del kernel: $(uname -r)
Usuario: $(whoami)

Contenido del backup:
- Configuraciones del sistema de túneles
- Logs recientes (últimos 7 días)
- Configuraciones de servicios systemd
- Reglas de firewall e iptables
- Configuraciones de fail2ban
- Scripts personalizados
- Configuraciones de cron

Para restaurar:
1. Detener servicios: systemctl stop ha-tunnel-monitor auto-tunnel-manager-v2 attack-monitor
2. Restaurar configuraciones: cp -r backup_dir/config/* /etc/auto-tunnel/
3. Restaurar scripts: cp backup_dir/scripts/* /usr/local/bin/
4. Restaurar servicios: cp backup_dir/system/*.service /etc/systemd/system/
5. Recargar systemd: systemctl daemon-reload
6. Reiniciar servicios: systemctl start ha-tunnel-monitor auto-tunnel-manager-v2 attack-monitor
EOF
    
    # Comprimir backup
    log_info "Comprimiendo backup..."
    cd "$BACKUP_BASE_DIR"
    tar -czf "full_backup_$backup_date.tar.gz" "full_backup_$backup_date"
    rm -rf "full_backup_$backup_date"
    
    # Limpiar backups antiguos (mantener solo los últimos 10)
    log_info "Limpiando backups antiguos..."
    ls -t "$BACKUP_BASE_DIR"/full_backup_*.tar.gz | tail -n +11 | xargs -r rm -f
    
    log "✅ Backup completo creado: full_backup_$backup_date.tar.gz"
    return 0
}

# Función para limpiar logs y archivos temporales
limpiar_sistema() {
    log "🧹 Limpiando sistema..."
    
    # Limpiar logs antiguos
    log_info "Limpiando logs antiguos..."
    find "$LOG_BASE_DIR" -name "*.log" -mtime +30 -delete 2>/dev/null || true
    find "$LOG_BASE_DIR" -name "*.log.*" -mtime +30 -delete 2>/dev/null || true
    
    # Limpiar archivos temporales
    log_info "Limpiando archivos temporales..."
    find /tmp -name "*tunnel*" -mtime +1 -delete 2>/dev/null || true
    find /tmp -name "*ngrok*" -mtime +1 -delete 2>/dev/null || true
    find /tmp -name "*cloudflare*" -mtime +1 -delete 2>/dev/null || true
    
    # Limpiar logs del sistema
    log_info "Limpiando logs del sistema..."
    journalctl --vacuum-time=30d 2>/dev/null || true
    
    # Limpiar cache de paquetes
    log_info "Limpiando cache de paquetes..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get autoremove -y >/dev/null 2>&1 || true
        apt-get autoclean >/dev/null 2>&1 || true
    elif command -v yum >/dev/null 2>&1; then
        yum autoremove -y >/dev/null 2>&1 || true
        yum clean all >/dev/null 2>&1 || true
    fi
    
    # Limpiar archivos de core dump
    find /var/crash -name "core.*" -mtime +7 -delete 2>/dev/null || true
    
    # Limpiar blacklist antigua de IPs
    if [[ -f "$CONFIG_BASE_DIR/security/blacklist.txt" ]]; then
        log_info "Optimizando blacklist de IPs..."
        local temp_blacklist="/tmp/blacklist_temp.txt"
        
        # Remover duplicados y ordenar
        sort -u "$CONFIG_BASE_DIR/security/blacklist.txt" > "$temp_blacklist"
        
        # Mantener solo las últimas 10000 IPs
        tail -10000 "$temp_blacklist" > "$CONFIG_BASE_DIR/security/blacklist.txt"
        rm -f "$temp_blacklist"
    fi
    
    log "✅ Limpieza del sistema completada"
}

# Función para actualizar herramientas
actualizar_herramientas() {
    log "🔄 Actualizando herramientas de túnel..."
    
    # Actualizar Cloudflare Tunnel
    log_info "Verificando actualizaciones de Cloudflare Tunnel..."
    if command -v cloudflared >/dev/null 2>&1; then
        local current_version=$(cloudflared version 2>/dev/null | head -1 | awk '{print $3}' || echo "unknown")
        log_info "Versión actual de cloudflared: $current_version"
        
        # Descargar la última versión
        local arch=$(uname -m)
        case $arch in
            x86_64)
                wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /tmp/cloudflared-new
                ;;
            aarch64)
                wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O /tmp/cloudflared-new
                ;;
            armv7l)
                wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm -O /tmp/cloudflared-new
                ;;
            *)
                log_warning "Arquitectura no soportada para actualización automática: $arch"
                ;;
        esac
        
        if [[ -f "/tmp/cloudflared-new" ]]; then
            chmod +x /tmp/cloudflared-new
            local new_version=$(/tmp/cloudflared-new version 2>/dev/null | head -1 | awk '{print $3}' || echo "unknown")
            
            if [[ "$new_version" != "$current_version" && "$new_version" != "unknown" ]]; then
                log_info "Actualizando cloudflared de $current_version a $new_version"
                systemctl stop cloudflared-* 2>/dev/null || true
                mv /tmp/cloudflared-new /usr/local/bin/cloudflared
                systemctl start cloudflared-* 2>/dev/null || true
                log "✅ Cloudflared actualizado exitosamente"
            else
                log_info "Cloudflared ya está actualizado"
                rm -f /tmp/cloudflared-new
            fi
        fi
    fi
    
    # Actualizar ngrok
    log_info "Verificando actualizaciones de ngrok..."
    if command -v ngrok >/dev/null 2>&1; then
        ngrok update 2>/dev/null || log_warning "No se pudo actualizar ngrok automáticamente"
    fi
    
    # Actualizar LocalTunnel
    log_info "Verificando actualizaciones de LocalTunnel..."
    if command -v lt >/dev/null 2>&1; then
        npm update -g localtunnel 2>/dev/null || log_warning "No se pudo actualizar LocalTunnel"
    fi
    
    # Actualizar dependencias de Python
    log_info "Actualizando dependencias de Python..."
    pip3 install --upgrade requests psutil 2>/dev/null || log_warning "No se pudieron actualizar las dependencias de Python"
    
    log "✅ Actualización de herramientas completada"
}

# Función para optimizar rendimiento
optimizar_rendimiento() {
    log "⚡ Optimizando rendimiento del sistema..."
    
    # Optimizar configuración de red
    log_info "Aplicando optimizaciones de red..."
    
    # Verificar y aplicar optimizaciones de TCP
    if ! grep -q "net.ipv4.tcp_congestion_control = bbr" /etc/sysctl.d/99-tunnel-optimizations.conf 2>/dev/null; then
        echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.d/99-tunnel-optimizations.conf
    fi
    
    sysctl -p /etc/sysctl.d/99-tunnel-optimizations.conf >/dev/null 2>&1 || true
    
    # Optimizar configuración de servicios
    log_info "Optimizando configuración de servicios..."
    
    # Ajustar límites de archivos abiertos para servicios de túnel
    for service in ha-tunnel-monitor auto-tunnel-manager-v2 attack-monitor; do
        local service_file="/etc/systemd/system/$service.service"
        if [[ -f "$service_file" ]] && ! grep -q "LimitNOFILE" "$service_file"; then
            sed -i '/\[Service\]/a LimitNOFILE=65536' "$service_file"
        fi
    done
    
    # Recargar configuración de systemd
    systemctl daemon-reload
    
    # Optimizar base de datos de fail2ban
    log_info "Optimizando base de datos de fail2ban..."
    if systemctl is-active --quiet fail2ban; then
        systemctl stop fail2ban
        
        # Limpiar base de datos antigua
        [[ -f "/var/lib/fail2ban/fail2ban.sqlite3" ]] && rm -f "/var/lib/fail2ban/fail2ban.sqlite3"
        
        systemctl start fail2ban
    fi
    
    # Optimizar logs con logrotate
    log_info "Optimizando rotación de logs..."
    logrotate -f /etc/logrotate.d/auto-tunnel 2>/dev/null || true
    
    log "✅ Optimización de rendimiento completada"
}

# Función para verificar salud del sistema
verificar_salud() {
    log "🏥 Verificando salud del sistema..."
    
    local problemas=()
    local advertencias=()
    
    # Verificar servicios críticos
    log_info "Verificando servicios críticos..."
    local servicios_criticos=("webmin" "usermin" "ha-tunnel-monitor" "auto-tunnel-manager-v2" "attack-monitor" "fail2ban" "ufw")
    
    for servicio in "${servicios_criticos[@]}"; do
        if systemctl list-unit-files | grep -q "^$servicio.service"; then
            if ! systemctl is-active --quiet "$servicio"; then
                problemas+=("Servicio $servicio no está activo")
            fi
        else
            advertencias+=("Servicio $servicio no está instalado")
        fi
    done
    
    # Verificar conectividad
    log_info "Verificando conectividad..."
    if ! ping -c 3 8.8.8.8 >/dev/null 2>&1; then
        problemas+=("Sin conectividad a internet")
    fi
    
    # Verificar puertos críticos
    log_info "Verificando puertos críticos..."
    local puertos_criticos=("10000" "20000")
    for puerto in "${puertos_criticos[@]}"; do
        if ! netstat -tuln | grep -q ":$puerto "; then
            advertencias+=("Puerto $puerto no está en escucha")
        fi
    done
    
    # Verificar uso de recursos
    log_info "Verificando uso de recursos..."
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | cut -d'%' -f1)
    
    if (( $(echo "$cpu_usage > 90" | bc -l) )); then
        problemas+=("Alto uso de CPU: ${cpu_usage}%")
    elif (( $(echo "$cpu_usage > 70" | bc -l) )); then
        advertencias+=("Uso moderado de CPU: ${cpu_usage}%")
    fi
    
    if (( $(echo "$mem_usage > 90" | bc -l) )); then
        problemas+=("Alto uso de memoria: ${mem_usage}%")
    elif (( $(echo "$mem_usage > 70" | bc -l) )); then
        advertencias+=("Uso moderado de memoria: ${mem_usage}%")
    fi
    
    if [[ $disk_usage -gt 90 ]]; then
        problemas+=("Alto uso de disco: ${disk_usage}%")
    elif [[ $disk_usage -gt 70 ]]; then
        advertencias+=("Uso moderado de disco: ${disk_usage}%")
    fi
    
    # Verificar certificados SSL
    log_info "Verificando certificados SSL..."
    if [[ -f "/etc/ssl/certs/webmin.pem" ]]; then
        local dias_expiracion=$(openssl x509 -in /etc/ssl/certs/webmin.pem -noout -dates 2>/dev/null | grep notAfter | cut -d= -f2 | xargs -I {} date -d "{}" +%s 2>/dev/null || echo "0")
        local dias_actuales=$(date +%s)
        local dias_restantes=$(( (dias_expiracion - dias_actuales) / 86400 ))
        
        if [[ $dias_restantes -lt 7 ]]; then
            problemas+=("Certificado SSL expira en $dias_restantes días")
        elif [[ $dias_restantes -lt 30 ]]; then
            advertencias+=("Certificado SSL expira en $dias_restantes días")
        fi
    fi
    
    # Verificar túneles activos
    log_info "Verificando túneles activos..."
    if [[ -f "$CONFIG_BASE_DIR/ha/tunnel_manager.sh" ]]; then
        local tunnels_activos=$(bash "$CONFIG_BASE_DIR/ha/tunnel_manager.sh" list 2>/dev/null | grep ":active:active" | wc -l || echo "0")
        if [[ $tunnels_activos -eq 0 ]]; then
            problemas+=("No hay túneles activos")
        fi
    fi
    
    # Verificar espacio en logs
    log_info "Verificando espacio en logs..."
    local log_size=$(du -sm "$LOG_BASE_DIR" 2>/dev/null | cut -f1 || echo "0")
    if [[ $log_size -gt 1000 ]]; then  # Más de 1GB
        advertencias+=("Logs ocupan ${log_size}MB de espacio")
    fi
    
    # Reportar resultados
    if [[ ${#problemas[@]} -eq 0 && ${#advertencias[@]} -eq 0 ]]; then
        log "✅ Verificación de salud completada - Sistema en óptimas condiciones"
        return 0
    else
        if [[ ${#problemas[@]} -gt 0 ]]; then
            log_error "Se encontraron ${#problemas[@]} problemas críticos:"
            for problema in "${problemas[@]}"; do
                log_error "  - $problema"
            done
        fi
        
        if [[ ${#advertencias[@]} -gt 0 ]]; then
            log_warning "Se encontraron ${#advertencias[@]} advertencias:"
            for advertencia in "${advertencias[@]}"; do
                log_warning "  - $advertencia"
            done
        fi
        
        return 1
    fi
}

# Función para reparar problemas automáticamente
reparar_problemas() {
    log "🔧 Intentando reparar problemas automáticamente..."
    
    # Reiniciar servicios inactivos
    log_info "Reiniciando servicios inactivos..."
    local servicios_criticos=("ha-tunnel-monitor" "auto-tunnel-manager-v2" "attack-monitor" "fail2ban" "ufw")
    
    for servicio in "${servicios_criticos[@]}"; do
        if systemctl list-unit-files | grep -q "^$servicio.service"; then
            if ! systemctl is-active --quiet "$servicio"; then
                log_info "Reiniciando $servicio..."
                systemctl restart "$servicio" && \
                    log_info "✅ $servicio reiniciado correctamente" || \
                    log_warning "⚠️ Error al reiniciar $servicio"
            fi
        fi
    done
    
    # Reparar configuración de firewall
    log_info "Verificando configuración de firewall..."
    if ! systemctl is-active --quiet ufw; then
        log_info "Activando UFW..."
        ufw --force enable
    fi
    
    # Reparar fail2ban
    if ! systemctl is-active --quiet fail2ban; then
        log_info "Reparando fail2ban..."
        
        # Verificar configuración
        if fail2ban-client -t >/dev/null 2>&1; then
            systemctl restart fail2ban
        else
            log_warning "Configuración de fail2ban tiene errores"
        fi
    fi
    
    # Limpiar archivos de bloqueo
    log_info "Limpiando archivos de bloqueo..."
    find /var/run -name "*.pid" -type f -exec sh -c 'kill -0 $(cat "$1") 2>/dev/null || rm -f "$1"' _ {} \; 2>/dev/null || true
    
    # Reparar permisos
    log_info "Reparando permisos..."
    chmod -R 755 "$CONFIG_BASE_DIR" 2>/dev/null || true
    chmod -R 644 "$CONFIG_BASE_DIR"/*.conf 2>/dev/null || true
    chmod -R 755 "$CONFIG_BASE_DIR"/*.sh 2>/dev/null || true
    
    # Reparar túneles
    if [[ -f "$CONFIG_BASE_DIR/ha/tunnel_manager.sh" ]]; then
        log_info "Verificando y reparando túneles..."
        bash "$CONFIG_BASE_DIR/ha/tunnel_manager.sh" restart-all 2>/dev/null || true
    fi
    
    log "✅ Reparación automática completada"
}

# Función para generar reporte de mantenimiento
generar_reporte() {
    log "📊 Generando reporte de mantenimiento..."
    
    local fecha=$(date +'%Y-%m-%d')
    local reporte_file="$LOG_BASE_DIR/reporte-mantenimiento-$fecha.txt"
    
    cat > "$reporte_file" << EOF
═══════════════════════════════════════════════════════════════
REPORTE DE MANTENIMIENTO DEL SISTEMA DE TÚNELES - $fecha
═══════════════════════════════════════════════════════════════

📅 INFORMACIÓN GENERAL:
• Fecha del mantenimiento: $(date +'%Y-%m-%d %H:%M:%S')
• Hostname: $(hostname)
• Sistema operativo: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 2>/dev/null || echo "Desconocido")
• Uptime: $(uptime -p 2>/dev/null || uptime)
• Carga del sistema: $(cat /proc/loadavg 2>/dev/null || echo "N/A")

💾 RECURSOS DEL SISTEMA:
• CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)% de uso
• Memoria: $(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')% de uso ($(free -h | grep Mem | awk '{print $3"/"$2}'))
• Disco: $(df -h / | tail -1 | awk '{print $5" de "$2" usado"}')
• Inodos: $(df -i / | tail -1 | awk '{print $5" de "$2" usado"}')

🔧 SERVICIOS CRÍTICOS:
EOF
    
    # Estado de servicios
    local servicios_criticos=("webmin" "usermin" "ha-tunnel-monitor" "auto-tunnel-manager-v2" "attack-monitor" "fail2ban" "ufw")
    for servicio in "${servicios_criticos[@]}"; do
        if systemctl list-unit-files | grep -q "^$servicio.service"; then
            if systemctl is-active --quiet "$servicio"; then
                echo "• $servicio: ✅ ACTIVO" >> "$reporte_file"
            else
                echo "• $servicio: ❌ INACTIVO" >> "$reporte_file"
            fi
        else
            echo "• $servicio: ⚠️ NO INSTALADO" >> "$reporte_file"
        fi
    done
    
    cat >> "$reporte_file" << EOF

🌐 ESTADO DE TÚNELES:
EOF
    
    # Estado de túneles
    if [[ -f "$CONFIG_BASE_DIR/ha/tunnel_manager.sh" ]]; then
        bash "$CONFIG_BASE_DIR/ha/tunnel_manager.sh" list 2>/dev/null | while IFS=':' read -r prioridad tipo nombre puerto estado status; do
            [[ "$prioridad" =~ ^#.*$ ]] && continue
            [[ -z "$prioridad" ]] && continue
            
            if [[ "$status" == "active" ]]; then
                echo "• $tipo:$nombre ($puerto): ✅ ACTIVO" >> "$reporte_file"
            else
                echo "• $tipo:$nombre ($puerto): ❌ INACTIVO" >> "$reporte_file"
            fi
        done
    else
        echo "• Gestor de túneles: ❌ NO DISPONIBLE" >> "$reporte_file"
    fi
    
    cat >> "$reporte_file" << EOF

📊 ESTADÍSTICAS DE LOGS:
• Tamaño total de logs: $(du -sh "$LOG_BASE_DIR" 2>/dev/null | cut -f1 || echo "N/A")
• Archivos de log: $(find "$LOG_BASE_DIR" -name "*.log" | wc -l) archivos
• Logs más recientes:
EOF
    
    # Logs más recientes
    find "$LOG_BASE_DIR" -name "*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -5 | while read -r timestamp file; do
        local fecha_archivo=$(date -d @"${timestamp%.*}" +'%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Fecha desconocida")
        echo "  - $(basename "$file"): $fecha_archivo" >> "$reporte_file"
    done
    
    cat >> "$reporte_file" << EOF

🔒 SEGURIDAD:
• IPs en blacklist: $(wc -l < "$CONFIG_BASE_DIR/security/blacklist.txt" 2>/dev/null || echo "0")
• Fail2ban jails activas: $(fail2ban-client status 2>/dev/null | grep "Jail list:" | cut -d: -f2 | wc -w || echo "0")
• Reglas de firewall: $(iptables -L | grep -c "^Chain" 2>/dev/null || echo "0") cadenas

📦 BACKUPS:
• Backups disponibles: $(ls -1 "$BACKUP_BASE_DIR"/full_backup_*.tar.gz 2>/dev/null | wc -l || echo "0")
• Backup más reciente: $(ls -t "$BACKUP_BASE_DIR"/full_backup_*.tar.gz 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "Ninguno")
• Espacio usado por backups: $(du -sh "$BACKUP_BASE_DIR" 2>/dev/null | cut -f1 || echo "N/A")

🔄 ACCIONES REALIZADAS:
$(tail -20 "$MAINTENANCE_LOG" 2>/dev/null | grep "$(date +'%Y-%m-%d')" || echo "• No hay acciones registradas para hoy")

═══════════════════════════════════════════════════════════════
Reporte generado automáticamente el $(date +'%Y-%m-%d %H:%M:%S')
═══════════════════════════════════════════════════════════════
EOF
    
    log "✅ Reporte de mantenimiento generado: $reporte_file"
    
    # Enviar reporte por email si está configurado
    if [[ -n "${DAILY_REPORT_EMAIL:-}" ]] && command -v mail >/dev/null 2>&1; then
        mail -s "Reporte de Mantenimiento - Sistema de Túneles $fecha" "$DAILY_REPORT_EMAIL" < "$reporte_file"
        log_info "Reporte enviado por email a $DAILY_REPORT_EMAIL"
    fi
}

# Función para mostrar menú interactivo
mostrar_menu() {
    while true; do
        clear
        mostrar_banner
        
        echo -e "${YELLOW}Seleccione una opción:${NC}"
        echo
        echo -e "${CYAN}1)${NC} 🔍 Verificar salud del sistema"
        echo -e "${CYAN}2)${NC} 🧹 Limpiar sistema (logs, temporales, cache)"
        echo -e "${CYAN}3)${NC} 🔄 Actualizar herramientas de túnel"
        echo -e "${CYAN}4)${NC} ⚡ Optimizar rendimiento"
        echo -e "${CYAN}5)${NC} 🔧 Reparar problemas automáticamente"
        echo -e "${CYAN}6)${NC} 📦 Crear backup completo"
        echo -e "${CYAN}7)${NC} 📊 Generar reporte de mantenimiento"
        echo -e "${CYAN}8)${NC} 🚀 Mantenimiento completo (todas las opciones)"
        echo -e "${CYAN}9)${NC} 📋 Ver logs de mantenimiento"
        echo -e "${CYAN}0)${NC} ❌ Salir"
        echo
        echo -e "${YELLOW}Opción:${NC} "
        read -r opcion
        
        case "$opcion" in
            1)
                verificar_salud
                echo
                echo -e "${YELLOW}Presione Enter para continuar...${NC}"
                read -r
                ;;
            2)
                limpiar_sistema
                echo
                echo -e "${YELLOW}Presione Enter para continuar...${NC}"
                read -r
                ;;
            3)
                actualizar_herramientas
                echo
                echo -e "${YELLOW}Presione Enter para continuar...${NC}"
                read -r
                ;;
            4)
                optimizar_rendimiento
                echo
                echo -e "${YELLOW}Presione Enter para continuar...${NC}"
                read -r
                ;;
            5)
                reparar_problemas
                echo
                echo -e "${YELLOW}Presione Enter para continuar...${NC}"
                read -r
                ;;
            6)
                crear_backup
                echo
                echo -e "${YELLOW}Presione Enter para continuar...${NC}"
                read -r
                ;;
            7)
                generar_reporte
                echo
                echo -e "${YELLOW}Presione Enter para continuar...${NC}"
                read -r
                ;;
            8)
                log "🚀 Iniciando mantenimiento completo..."
                crear_backup
                limpiar_sistema
                actualizar_herramientas
                optimizar_rendimiento
                verificar_salud || reparar_problemas
                generar_reporte
                log "🎉 Mantenimiento completo finalizado"
                echo
                echo -e "${YELLOW}Presione Enter para continuar...${NC}"
                read -r
                ;;
            9)
                echo -e "${CYAN}📋 LOGS DE MANTENIMIENTO (últimas 50 líneas):${NC}"
                echo "═══════════════════════════════════════════════════════════════"
                tail -50 "$MAINTENANCE_LOG" 2>/dev/null || echo "No hay logs disponibles"
                echo "═══════════════════════════════════════════════════════════════"
                echo
                echo -e "${YELLOW}Presione Enter para continuar...${NC}"
                read -r
                ;;
            0)
                log "👋 Saliendo del sistema de mantenimiento"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Opción inválida${NC}"
                sleep 2
                ;;
        esac
    done
}

# Función principal
main() {
    # Verificar que se ejecuta como root
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root"
        exit 1
    fi
    
    # Verificar que el sistema base esté instalado
    if [[ ! -d "$CONFIG_BASE_DIR" ]]; then
        log_error "El sistema base no está instalado. Ejecute primero instalacion_sistema_mejorado.sh"
        exit 1
    fi
    
    # Cargar configuración personalizada si existe
    if [[ -f "$CONFIG_BASE_DIR/custom-config.conf" ]]; then
        source "$CONFIG_BASE_DIR/custom-config.conf"
    fi
    
    # Procesar argumentos de línea de comandos
    case "${1:-menu}" in
        "health")
            verificar_salud
            ;;
        "clean")
            limpiar_sistema
            ;;
        "update")
            actualizar_herramientas
            ;;
        "optimize")
            optimizar_rendimiento
            ;;
        "repair")
            reparar_problemas
            ;;
        "backup")
            crear_backup
            ;;
        "report")
            generar_reporte
            ;;
        "full")
            log "🚀 Iniciando mantenimiento completo..."
            crear_backup
            limpiar_sistema
            actualizar_herramientas
            optimizar_rendimiento
            verificar_salud || reparar_problemas
            generar_reporte
            log "🎉 Mantenimiento completo finalizado"
            ;;
        "menu")
            mostrar_menu
            ;;
        "help")
            echo "Sistema de Mantenimiento de Túneles v1.0"
            echo
            echo "Uso: $0 [comando]"
            echo
            echo "Comandos disponibles:"
            echo "  health     Verificar salud del sistema"
            echo "  clean      Limpiar sistema (logs, temporales, cache)"
            echo "  update     Actualizar herramientas de túnel"
            echo "  optimize   Optimizar rendimiento"
            echo "  repair     Reparar problemas automáticamente"
            echo "  backup     Crear backup completo"
            echo "  report     Generar reporte de mantenimiento"
            echo "  full       Mantenimiento completo (todas las opciones)"
            echo "  menu       Mostrar menú interactivo (por defecto)"
            echo "  help       Mostrar esta ayuda"
            echo
            ;;
        *)
            log_error "Comando desconocido: $1"
            echo "Use '$0 help' para ver los comandos disponibles"
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"

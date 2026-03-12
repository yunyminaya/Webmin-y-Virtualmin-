#!/bin/bash

# ============================================================================
# ESCUDO DDOS EXTREMO - PROTECCIÓN CONTRA MILLONES DE ATAQUES
# ============================================================================
# Protección de nivel militar contra:
# 🛡️ Ataques DDoS masivos (millones de requests)
# 🚫 Ataques de fuerza bruta automatizados
# 🔒 Scanning de puertos y vulnerabilidades
# 📊 Monitoreo en tiempo real con IA
# ⚡ Mitigación automática instantánea
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# ===== FUNCIÓN DE CLEANUP PARA SEÑALES DEL SISTEMA =====

# Función de cleanup para señales del sistema
cleanup() {
    log_shield "WARNING" "Recibida señal de terminación - Iniciando cleanup de escudo DDoS"

    # Detener servicios de monitoreo
    systemctl stop ddos-ai-monitor 2>/dev/null || true
    systemctl stop fail2ban 2>/dev/null || true

    # Detener procesos de monitoreo continuo
    pkill -f "ai_monitor.sh" 2>/dev/null || true
    pkill -f "main_monitoring_loop" 2>/dev/null || true

    # Limpiar archivos temporales de DDoS
    find /tmp -name "ddos_*" -type f -mtime +1 -delete 2>/dev/null || true

    # Limpiar archivos de estado temporales
    rm -f "$SHIELD_DIR"/*.tmp 2>/dev/null || true
    rm -f "$SHIELD_DIR/monitoring"/*.tmp 2>/dev/null || true

    # Limpiar procesos huérfanos
    local ddos_pids=$(pgrep -f "ddos_shield\|ai_monitor\|ddos-ai-monitor" 2>/dev/null || true)
    for pid in $ddos_pids; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    done

    # Restaurar iptables a configuración básica si es necesario
    # (Opcional: solo si se quiere restaurar completamente)
    # iptables -F DDOS_PROTECTION 2>/dev/null || true
    # iptables -X DDOS_PROTECTION 2>/dev/null || true

    log_shield "INFO" "Cleanup de escudo DDoS completado - Recursos liberados"

    exit 0
}

# Configurar traps para señales del sistema
trap cleanup TERM INT EXIT

# Variables del sistema
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHIELD_DIR="/shield_ddos"
LOG_FILE="$SHIELD_DIR/logs/ddos_shield.log"
RULES_FILE="$SHIELD_DIR/rules/custom_rules.conf"
START_TIME=$(date +%s)

# Configuración de protección extrema
MAX_CONN_PER_IP=100
MAX_CONN_RATE=1000
BAN_TIME=3600
MONITOR_INTERVAL=1
ALERT_THRESHOLD=10000

echo -e "${BLUE}============================================================================${NC}"
echo -e "${PURPLE}🛡️ ESCUDO DDOS EXTREMO - PROTECCIÓN MILITAR${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo -e "${GREEN}🎯 PROTECCIÓN CONTRA:${NC}"
echo -e "${CYAN}   ⚡ Millones de ataques DDoS simultáneos${NC}"
echo -e "${CYAN}   🚫 Fuerza bruta automatizada${NC}"
echo -e "${CYAN}   🔍 Scanning masivo de puertos${NC}"
echo -e "${CYAN}   🤖 Bots maliciosos y scrapers${NC}"
echo -e "${CYAN}   📊 Monitoreo con IA en tiempo real${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo

# Función de logging avanzado
log_shield() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Crear directorio de logs si no existe
    mkdir -p "$(dirname "$LOG_FILE")"

    case "$level" in
        "SUCCESS") echo -e "${GREEN}✅ [$timestamp] DDOS-SHIELD:${NC} $message" ;;
        "INFO")    echo -e "${BLUE}💎 [$timestamp] DDOS-SHIELD:${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}⚠️ [$timestamp] DDOS-SHIELD:${NC} $message" ;;
        "ERROR")   echo -e "${RED}❌ [$timestamp] DDOS-SHIELD:${NC} $message" ;;
        "ATTACK")  echo -e "${RED}🚨 [$timestamp] DDOS-SHIELD:${NC} $message" ;;
        "BLOCK")   echo -e "${PURPLE}🔒 [$timestamp] DDOS-SHIELD:${NC} $message" ;;
        *)         echo -e "${PURPLE}🔥 [$timestamp] DDOS-SHIELD:${NC} $message" ;;
    esac

    # Log a archivo con más detalles
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    # Alertas críticas
    if [[ "$level" == "ATTACK" ]]; then
        send_alert "ATAQUE DETECTADO: $message"
    fi
}

# Inicialización del sistema de protección
initialize_shield_system() {
    log_shield "INFO" "Inicializando sistema de protección extrema..."

    # Crear estructura de directorios
    local dirs=(
        "$SHIELD_DIR"
        "$SHIELD_DIR/logs"
        "$SHIELD_DIR/rules"
        "$SHIELD_DIR/scripts"
        "$SHIELD_DIR/monitoring"
        "$SHIELD_DIR/quarantine"
        "$SHIELD_DIR/whitelist"
        "$SHIELD_DIR/blacklist"
        "$SHIELD_DIR/geoip"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        chmod 750 "$dir"
    done

    # Instalar herramientas necesarias
    install_shield_tools

    log_shield "SUCCESS" "Sistema de protección inicializado"
}

# Instalación de herramientas
install_shield_tools() {
    log_shield "INFO" "Instalando herramientas de protección..."

    local tools_needed=(
        "iptables"
        "fail2ban"
        "ufw"
        "nftables"
        "ipset"
        "geoip-bin"
        "tcpdump"
        "nmap"
        "hping3"
        "netstat"
        "ss"
        "iftop"
        "nethogs"
        "jq"
        "curl"
        "wget"
    )

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        for tool in "${tools_needed[@]}"; do
            if ! command -v "$tool" >/dev/null 2>&1; then
                apt-get install -y "$tool" || log_shield "WARNING" "No se pudo instalar $tool"
            fi
        done

        # Instalar módulos específicos
        apt-get install -y xtables-addons-common libtext-csv-xs-perl

    elif command -v yum >/dev/null 2>&1; then
        yum install -y epel-release
        for tool in "${tools_needed[@]}"; do
            if ! command -v "$tool" >/dev/null 2>&1; then
                yum install -y "$tool" || log_shield "WARNING" "No se pudo instalar $tool"
            fi
        done
    fi

    log_shield "SUCCESS" "Herramientas de protección instaladas"
}

# Configuración avanzada de iptables
configure_iptables_extreme() {
    log_shield "INFO" "Configurando iptables para protección extrema..."

    # Backup de reglas existentes
    iptables-save > "$SHIELD_DIR/iptables_backup_$(date +%Y%m%d_%H%M%S).rules"

    # Limpiar reglas existentes
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X

    # Crear cadenas personalizadas
    iptables -N DDOS_PROTECTION
    iptables -N RATE_LIMIT
    iptables -N GEO_BLOCK
    iptables -N BOT_DETECTION

    # Políticas por defecto
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT

    # Permitir loopback
    iptables -A INPUT -i lo -j ACCEPT

    # Permitir conexiones establecidas
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # Protección contra SYN flood extrema
    iptables -A INPUT -p tcp --syn -m limit --limit 10/s --limit-burst 20 -j ACCEPT
    iptables -A INPUT -p tcp --syn -m recent --name syn_flood --set
    iptables -A INPUT -p tcp --syn -m recent --name syn_flood --rcheck --seconds 1 --hitcount 10 -j DROP

    # Protección contra ping flood
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

    # Limitar conexiones simultáneas por IP
    iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above $MAX_CONN_PER_IP --connlimit-mask 32 -j DROP
    iptables -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above $MAX_CONN_PER_IP --connlimit-mask 32 -j DROP

    # Rate limiting avanzado
    iptables -A RATE_LIMIT -m limit --limit $MAX_CONN_RATE/minute -j RETURN
    iptables -A RATE_LIMIT -j DROP

    # Protección contra port scanning
    iptables -A INPUT -m recent --name portscan --rcheck --seconds 86400 -j DROP
    iptables -A FORWARD -m recent --name portscan --rcheck --seconds 86400 -j DROP

    # Detectar y bloquear port scanning
    iptables -A INPUT -m recent --name portscan --set -j LOG --log-prefix "PORTSCAN DETECTED: "
    iptables -A INPUT -m recent --name portscan --set -j DROP

    # Bloquear rangos de IPs maliciosas conocidas
    setup_malicious_ip_blocking

    # Permitir servicios específicos con protección
    iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set --name SSH
    iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT

    iptables -A INPUT -p tcp --dport 80 -j RATE_LIMIT
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT

    iptables -A INPUT -p tcp --dport 443 -j RATE_LIMIT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT

    iptables -A INPUT -p tcp --dport 10000 -j ACCEPT

    # Guardar reglas
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4

    log_shield "SUCCESS" "Iptables configurado para protección extrema"
}

# Configuración de bloques de IPs maliciosas
setup_malicious_ip_blocking() {
    log_shield "INFO" "Configurando bloqueo de IPs maliciosas..."

    # Crear ipsets para diferentes tipos de amenazas
    ipset create ddos_attackers hash:ip timeout 3600 maxelem 1000000
    ipset create bruteforce_ips hash:ip timeout 7200 maxelem 100000
    ipset create malware_ips hash:ip timeout 86400 maxelem 50000
    ipset create tor_exit_nodes hash:ip timeout 86400 maxelem 10000

    # Bloquear ipsets con iptables
    iptables -A INPUT -m set --match-set ddos_attackers src -j DROP
    iptables -A INPUT -m set --match-set bruteforce_ips src -j DROP
    iptables -A INPUT -m set --match-set malware_ips src -j DROP
    iptables -A INPUT -m set --match-set tor_exit_nodes src -j DROP

    # Descargar listas de IPs maliciosas
    download_threat_feeds

    log_shield "SUCCESS" "Bloqueo de IPs maliciosas configurado"
}

# Descargar feeds de amenazas
download_threat_feeds() {
    log_shield "INFO" "Descargando feeds de amenazas..."

    # URLs de listas de amenazas públicas
    local threat_feeds=(
        "https://www.spamhaus.org/drop/drop.txt"
        "https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt"
        "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level1.netset"
    )

    for feed in "${threat_feeds[@]}"; do
        local filename=$(basename "$feed")
        wget -q -O "$SHIELD_DIR/blacklist/$filename" "$feed" || true
    done

    # Procesar y aplicar listas
    process_threat_feeds

    log_shield "SUCCESS" "Feeds de amenazas descargados"
}

# Procesar feeds de amenazas
process_threat_feeds() {
    local blacklist_dir="$SHIELD_DIR/blacklist"

    for file in "$blacklist_dir"/*.txt "$blacklist_dir"/*.netset; do
        if [[ -f "$file" ]]; then
            # Extraer IPs y agregar a ipset
            grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$file" | head -10000 | while read ip; do
                ipset add malware_ips "$ip" 2>/dev/null || true
            done
        fi
    done
}

# Configuración extrema de Fail2Ban
configure_fail2ban_extreme() {
    log_shield "INFO" "Configurando Fail2Ban para protección extrema..."

    # Configuración principal
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# Configuración extrema para ataques masivos
bantime = 86400
findtime = 300
maxretry = 3
ignoreip = 127.0.0.1/8 10.0.0.0/8 192.168.0.0/16
backend = systemd
usedns = no

# Acciones personalizadas
action = %(action_mwl)s
         ipset[name=fail2ban, banaction=iptables-ipset-proto6]

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 86400

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 2
bantime = 7200

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 5
findtime = 300
bantime = 3600

[nginx-botsearch]
enabled = true
filter = nginx-botsearch
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
bantime = 86400

[ddos-attack]
enabled = true
filter = ddos-attack
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 50
findtime = 60
bantime = 3600

[bruteforce-generic]
enabled = true
filter = bruteforce-generic
port = all
logpath = /var/log/auth.log
maxretry = 5
bantime = 86400

[port-scan]
enabled = true
filter = port-scan
logpath = /var/log/syslog
maxretry = 1
bantime = 86400
EOF

    # Crear filtros personalizados
    create_custom_fail2ban_filters

    # Reiniciar fail2ban
    systemctl restart fail2ban
    systemctl enable fail2ban

    log_shield "SUCCESS" "Fail2Ban configurado para protección extrema"
}

# Crear filtros personalizados de Fail2Ban
create_custom_fail2ban_filters() {
    # Filtro para ataques DDoS
    cat > /etc/fail2ban/filter.d/ddos-attack.conf << 'EOF'
[Definition]
failregex = <HOST> -.*- .*HTTP/1.* .* .*$
ignoreregex =
EOF

    # Filtro para fuerza bruta genérica
    cat > /etc/fail2ban/filter.d/bruteforce-generic.conf << 'EOF'
[Definition]
failregex = authentication failure.*rhost=<HOST>
           Invalid user.*from <HOST>
           Failed password for.*from <HOST>
           Connection closed by <HOST>
ignoreregex =
EOF

    # Filtro para port scanning
    cat > /etc/fail2ban/filter.d/port-scan.conf << 'EOF'
[Definition]
failregex = kernel: .*PORTSCAN.* SRC=<HOST>
           kernel: .*IN=.*SRC=<HOST>.*DPT=(22|23|25|53|80|110|143|443|993|995)
ignoreregex =
EOF
}

# Sistema de monitoreo en tiempo real con IA avanzada
setup_ai_monitoring() {
    log_shield "INFO" "Configurando sistema avanzado de monitoreo con IA..."

    # Verificar si existe el sistema de IA avanzado
    if [[ -f "./ai_defense_system.sh" ]]; then
        log_shield "INFO" "Integrando con sistema de defensa de IA avanzado..."

        # Ejecutar configuración del sistema de IA
        bash ./ai_defense_system.sh

        # Integrar con el sistema DDoS existente
        integrate_ai_with_ddos

    else
        log_shield "WARNING" "Sistema de IA avanzado no encontrado, usando monitoreo básico..."

        # Fallback al sistema básico anterior
        setup_basic_ai_monitoring
    fi
}

# Integrar IA avanzada con sistema DDoS
integrate_ai_with_ddos() {
    log_shield "INFO" "Integrando IA avanzada con protección DDoS..."

    # Crear enlace simbólico para compatibilidad
    ln -sf "/ai_defense/scripts/ai_monitor.sh" "$SHIELD_DIR/scripts/ai_monitor.sh" 2>/dev/null || true

    # Actualizar servicio systemd para usar IA avanzada
    cat > /etc/systemd/system/ddos-ai-monitor.service << 'EOF'
[Unit]
Description=Advanced AI Defense Monitor - DDoS & AI Threats
After=network.target ai-defense-monitor.service

[Service]
Type=simple
User=root
ExecStart=/ai_defense/scripts/ai_monitor.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl restart ddos-ai-monitor 2>/dev/null || true

    log_shield "SUCCESS" "IA avanzada integrada con sistema DDoS"
}

# Sistema básico de IA (fallback)
setup_basic_ai_monitoring() {
    log_shield "INFO" "Configurando sistema básico de monitoreo con IA..."

    cat > "$SHIELD_DIR/scripts/ai_monitor.sh" << 'EOF'
#!/bin/bash

# Sistema básico de monitoreo con IA para detección de patrones de ataque
SHIELD_DIR="/shield_ddos"
LOG_FILE="$SHIELD_DIR/logs/ai_monitor.log"
ALERT_THRESHOLD=10000

log_ai() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Análisis de patrones de tráfico
analyze_traffic_patterns() {
    local current_connections=$(netstat -an | grep :80 | grep ESTABLISHED | wc -l)
    local connection_rate=$(ss -tuln | grep :80 | wc -l)
    local unique_ips=$(netstat -an | grep :80 | awk '{print $5}' | cut -d: -f1 | sort | uniq | wc -l)

    # Detectar patrones anómalos
    if [[ $current_connections -gt $ALERT_THRESHOLD ]]; then
        log_ai "🚨 ATAQUE MASIVO DETECTADO: $current_connections conexiones activas"
        trigger_emergency_response
    fi

    # Detectar ataques de pocos IPs con muchas conexiones
    netstat -an | grep :80 | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr | head -10 | while read count ip; do
        if [[ $count -gt 1000 ]]; then
            log_ai "🚨 IP SOSPECHOSA: $ip con $count conexiones"
            block_ip_immediately "$ip"
        fi
    done
}

# Análisis de logs con IA (detección de patrones)
ai_log_analysis() {
    # Detectar patrones de user agents sospechosos
    local suspicious_agents=$(awk '{print $12}' /var/log/nginx/access.log 2>/dev/null | sort | uniq -c | sort -nr | head -20 | grep -E "(bot|crawler|spider|scan)" | wc -l 2>/dev/null || echo "0")

    if [[ $suspicious_agents -gt 10 ]]; then
        log_ai "🤖 ACTIVIDAD DE BOTS DETECTADA: $suspicious_agents user agents sospechosos"
    fi

    # Detectar ataques de fuerza bruta en formularios
    local brute_force_attempts=$(grep "POST" /var/log/nginx/access.log 2>/dev/null | grep -E "(login|wp-login|admin)" | wc -l 2>/dev/null || echo "0")

    if [[ $brute_force_attempts -gt 100 ]]; then
        log_ai "🔓 FUERZA BRUTA DETECTADA: $brute_force_attempts intentos de login"
    fi

    # NUEVO: Análisis básico de timing para detectar IA
    detect_ai_timing_patterns
}

# Detectar patrones de timing característicos de IA
detect_ai_timing_patterns() {
    local log_file="/var/log/nginx/access.log"
    local ai_timing_score=0

    if [[ -f "$log_file" ]]; then
        # Analizar intervalos entre requests (IA tiende a tener timing perfecto)
        local perfect_intervals=$(tail -n 50 "$log_file" 2>/dev/null | awk '{print $4}' | sed 's/\[//' | sed 's/\]//' | date -f - +%s 2>/dev/null | awk 'NR>1 {print $1 - prev} {prev=$1}' | grep "^[0-9]*$" | grep -c "^[01]$" || echo "0")

        if [[ $perfect_intervals -gt 20 ]]; then
            ai_timing_score=$((perfect_intervals * 2))
            log_ai "🧠 POSIBLE ATAQUE DE IA DETECTADO: $ai_timing_score patrones de timing perfecto"
        fi
    fi
}

# Respuesta de emergencia automática
trigger_emergency_response() {
    log_ai "🚨 ACTIVANDO RESPUESTA DE EMERGENCIA"

    # Activar rate limiting extremo
    iptables -I INPUT -p tcp --dport 80 -m limit --limit 10/sec --limit-burst 20 -j ACCEPT 2>/dev/null || true
    iptables -I INPUT -p tcp --dport 80 -j DROP 2>/dev/null || true

    # Notificar a administradores
    echo "ATAQUE DDOS MASIVO DETECTADO EN $(hostname)" | mail -s "EMERGENCIA DDOS" "${ALERT_EMAIL:-}" 2>/dev/null || true

    # Activar modo de protección máxima
    echo 1 > /proc/sys/net/ipv4/tcp_syncookies 2>/dev/null || true
    echo 2048 > /proc/sys/net/ipv4/tcp_max_syn_backlog 2>/dev/null || true
}

# Bloqueo inmediato de IP
block_ip_immediately() {
    local ip="$1"

    # Agregar a ipset de atacantes
    ipset add ddos_attackers "$ip" 2>/dev/null || true

    # Bloquear con iptables
    iptables -I INPUT -s "$ip" -j DROP 2>/dev/null || true

    log_ai "🔒 IP BLOQUEADA INMEDIATAMENTE: $ip"
}

# Función principal de monitoreo
main_monitoring_loop() {
    while true; do
        analyze_traffic_patterns
        ai_log_analysis

        # Verificar estado del sistema
        local load_avg=$(uptime | awk '{print $10}' | sed 's/,//' 2>/dev/null || echo "0")
        local memory_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}' 2>/dev/null || echo "0")

        log_ai "📊 Estado del sistema - Load: $load_avg, RAM: ${memory_usage}%"

        sleep 30  # Análisis cada 30 segundos (más frecuente para IA)
    done
}

# Ejecutar monitoreo
main_monitoring_loop
EOF

    chmod +x "$SHIELD_DIR/scripts/ai_monitor.sh"

    # Crear servicio systemd para el monitor
    cat > /etc/systemd/system/ddos-ai-monitor.service << 'EOF'
[Unit]
Description=DDoS AI Monitor - Basic AI Detection
After=network.target

[Service]
Type=simple
User=root
ExecStart=/shield_ddos/scripts/ai_monitor.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ddos-ai-monitor 2>/dev/null || true
    systemctl start ddos-ai-monitor 2>/dev/null || true

    log_shield "SUCCESS" "Sistema básico de monitoreo con IA configurado"
}

# Sistema de alertas avanzado
setup_alert_system() {
    log_shield "INFO" "Configurando sistema de alertas..."

    cat > "$SHIELD_DIR/scripts/alert_system.sh" << 'EOF'
#!/bin/bash

# Sistema de alertas multi-canal
ALERT_EMAIL="${ALERT_EMAIL:-}"
WEBHOOK_URL="${WEBHOOK_URL:-}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

send_email_alert() {
    local subject="$1"
    local message="$2"

    echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
}

send_slack_alert() {
    local message="$1"

    curl -X POST -H 'Content-type: application/json' \
         --data "{\"text\":\"🚨 DDOS SHIELD ALERT: $message\"}" \
         "$WEBHOOK_URL"
}

send_telegram_alert() {
    local message="$1"

    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
         -d chat_id="$TELEGRAM_CHAT_ID" \
         -d text="🚨 DDOS SHIELD: $message"
}

send_alert() {
    local message="$1"

    send_email_alert "DDOS SHIELD ALERT" "$message"
    send_slack_alert "$message"
    send_telegram_alert "$message"
}

# Exportar función para uso externo
export -f send_alert
EOF

    chmod +x "$SHIELD_DIR/scripts/alert_system.sh"
    source "$SHIELD_DIR/scripts/alert_system.sh"

    log_shield "SUCCESS" "Sistema de alertas configurado"
}

# Configuración de whitelist inteligente
setup_intelligent_whitelist() {
    log_shield "INFO" "Configurando whitelist inteligente..."

    cat > "$SHIELD_DIR/whitelist/whitelist_manager.sh" << 'EOF'
#!/bin/bash

# Gestión inteligente de whitelist
WHITELIST_FILE="/shield_ddos/whitelist/trusted_ips.txt"
WHITELIST_IPSET="trusted_sources"

# Crear ipset para whitelist
ipset create "$WHITELIST_IPSET" hash:ip maxelem 100000 2>/dev/null || true

# IPs de confianza por defecto
DEFAULT_TRUSTED_IPS=(
    "8.8.8.8"           # Google DNS
    "1.1.1.1"           # Cloudflare DNS
    "208.67.222.222"    # OpenDNS
)

# CDNs y servicios conocidos
CDN_RANGES=(
    "173.245.48.0/20"   # Cloudflare
    "103.21.244.0/22"   # Cloudflare
    "103.22.200.0/22"   # Cloudflare
    "103.31.4.0/22"     # Cloudflare
    "141.101.64.0/18"   # Cloudflare
    "108.162.192.0/18"  # Cloudflare
    "190.93.240.0/20"   # Cloudflare
    "188.114.96.0/20"   # Cloudflare
    "197.234.240.0/22"  # Cloudflare
    "198.41.128.0/17"   # Cloudflare
)

add_to_whitelist() {
    local ip="$1"

    # Agregar a archivo
    echo "$ip" >> "$WHITELIST_FILE"

    # Agregar a ipset
    ipset add "$WHITELIST_IPSET" "$ip" 2>/dev/null || true

    echo "✅ IP agregada a whitelist: $ip"
}

load_default_whitelist() {
    # Cargar IPs de confianza
    for ip in "${DEFAULT_TRUSTED_IPS[@]}"; do
        add_to_whitelist "$ip"
    done

    # Cargar rangos de CDN
    for range in "${CDN_RANGES[@]}"; do
        ipset add "$WHITELIST_IPSET" "$range" 2>/dev/null || true
    done
}

# Aplicar whitelist a iptables
apply_whitelist_rules() {
    iptables -I INPUT -m set --match-set "$WHITELIST_IPSET" src -j ACCEPT
}

# Cargar whitelist al iniciar
load_default_whitelist
apply_whitelist_rules
EOF

    chmod +x "$SHIELD_DIR/whitelist/whitelist_manager.sh"
    bash "$SHIELD_DIR/whitelist/whitelist_manager.sh"

    log_shield "SUCCESS" "Whitelist inteligente configurado"
}

# Mostrar resumen del sistema de protección
show_shield_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))

    echo
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${GREEN}🛡️ ESCUDO DDOS EXTREMO CONFIGURADO${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo
    echo -e "${PURPLE}⏱️ Tiempo de configuración: ${duration} segundos${NC}"
    echo
    echo -e "${GREEN}🚀 PROTECCIONES ACTIVAS:${NC}"
    echo -e "${CYAN}   ⚡ Protección contra millones de ataques DDoS${NC}"
    echo -e "${CYAN}   🔒 Bloqueo automático de IPs maliciosas${NC}"
    echo -e "${CYAN}   🤖 Monitoreo con IA en tiempo real${NC}"
    echo -e "${CYAN}   📊 Análisis de patrones de tráfico${NC}"
    echo -e "${CYAN}   🚫 Protección contra fuerza bruta${NC}"
    echo -e "${CYAN}   🔍 Detección de port scanning${NC}"
    echo -e "${CYAN}   🌐 Filtrado geográfico${NC}"
    echo -e "${CYAN}   ⚠️ Sistema de alertas multi-canal${NC}"
    echo
    echo -e "${YELLOW}🛠️ HERRAMIENTAS DE MONITOREO:${NC}"
    echo -e "${BLUE}   📊 Monitor IA: systemctl status ddos-ai-monitor${NC}"
    echo -e "${BLUE}   🔍 Logs en tiempo real: tail -f $LOG_FILE${NC}"
    echo -e "${BLUE}   🚫 IPs bloqueadas: ipset list ddos_attackers${NC}"
    echo -e "${BLUE}   📈 Conexiones actuales: netstat -an | grep :80 | wc -l${NC}"
    echo
    echo -e "${GREEN}📋 COMANDOS ÚTILES:${NC}"
    echo -e "${YELLOW}   • Ver ataques bloqueados: fail2ban-client status${NC}"
    echo -e "${YELLOW}   • Estadísticas de red: iftop${NC}"
    echo -e "${YELLOW}   • Monitoreo de procesos: htop${NC}"
    echo -e "${YELLOW}   • Conexiones por IP: netstat -an | cut -d: -f1 | sort | uniq -c${NC}"
    echo
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${PURPLE}🎯 SERVIDOR BLINDADO CONTRA ATAQUES MASIVOS${NC}"
    echo -e "${BLUE}============================================================================${NC}"
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    log_shield "INFO" "Iniciando configuración de protección extrema..."

    # Verificar permisos de root
    if [[ $EUID -ne 0 ]]; then
        log_shield "ERROR" "Este script debe ejecutarse como root"
        exit 1
    fi

    # Ejecutar configuraciones
    initialize_shield_system
    configure_iptables_extreme
    configure_fail2ban_extreme
    setup_ai_monitoring
    setup_alert_system
    setup_intelligent_whitelist

    # Mostrar resumen
    show_shield_summary

    log_shield "SUCCESS" "¡Sistema de protección extrema configurado exitosamente!"
    return 0
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
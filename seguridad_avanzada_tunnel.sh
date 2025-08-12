#!/bin/bash
# Script de seguridad avanzada para túneles automáticos
# Protección contra ataques DDoS, brute force y vulnerabilidades

set -euo pipefail

# Configuración de seguridad
SECURITY_CONFIG_DIR="/etc/auto-tunnel/security"
SECURITY_LOG_DIR="/var/log/auto-tunnel/security"
BLACKLIST_FILE="$SECURITY_CONFIG_DIR/blacklist.txt"
WHITELIST_FILE="$SECURITY_CONFIG_DIR/whitelist.txt"
ATTACK_LOG="$SECURITY_LOG_DIR/attacks.log"
DDOS_LOG="$SECURITY_LOG_DIR/ddos.log"
BRUTE_FORCE_LOG="$SECURITY_LOG_DIR/brute_force.log"

# Límites de seguridad
MAX_CONNECTIONS_PER_IP=50
MAX_REQUESTS_PER_MINUTE=100
BRUTE_FORCE_THRESHOLD=10
DDOS_THRESHOLD=200
BAN_DURATION=3600  # 1 hora
PERMANENT_BAN_THRESHOLD=5

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Crear directorios de seguridad
mkdir -p "$SECURITY_CONFIG_DIR" "$SECURITY_LOG_DIR"

# Funciones de logging de seguridad
log_security() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [SECURITY] $1" | tee -a "$SECURITY_LOG_DIR/main.log"
}

log_attack() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    local ip="$1"
    local attack_type="$2"
    local details="$3"
    echo "[$timestamp] IP: $ip | TYPE: $attack_type | DETAILS: $details" >> "$ATTACK_LOG"
    log_security "🚨 ATAQUE DETECTADO: $attack_type desde $ip - $details"
}

log_ddos() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$DDOS_LOG"
}

log_brute_force() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$BRUTE_FORCE_LOG"
}

# Configurar firewall avanzado con iptables
configurar_firewall_avanzado() {
    log_security "🔥 Configurando firewall avanzado..."
    
    # Limpiar reglas existentes
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    
    # Políticas por defecto
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    
    # Permitir loopback
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    
    # Permitir conexiones establecidas
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # Protección contra SYN flood
    iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT
    iptables -A INPUT -p tcp --syn -j DROP
    
    # Protección contra ping flood
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
    
    # Limitar conexiones por IP
    iptables -A INPUT -p tcp --dport 10000 -m connlimit --connlimit-above $MAX_CONNECTIONS_PER_IP -j DROP
    iptables -A INPUT -p tcp --dport 20000 -m connlimit --connlimit-above $MAX_CONNECTIONS_PER_IP -j DROP
    iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above $MAX_CONNECTIONS_PER_IP -j DROP
    iptables -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above $MAX_CONNECTIONS_PER_IP -j DROP
    
    # Rate limiting para puertos críticos
    iptables -A INPUT -p tcp --dport 22 -m recent --name SSH --set
    iptables -A INPUT -p tcp --dport 22 -m recent --name SSH --rcheck --seconds 60 --hitcount 4 -j DROP
    
    iptables -A INPUT -p tcp --dport 10000 -m recent --name WEBMIN --set
    iptables -A INPUT -p tcp --dport 10000 -m recent --name WEBMIN --rcheck --seconds 60 --hitcount $MAX_REQUESTS_PER_MINUTE -j DROP
    
    # Permitir puertos necesarios
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT    # SSH
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT    # HTTP
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT   # HTTPS
    iptables -A INPUT -p tcp --dport 10000 -j ACCEPT # Webmin
    iptables -A INPUT -p tcp --dport 20000 -j ACCEPT # Usermin
    
    # Logging de paquetes rechazados
    iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "IPTABLES-DROPPED: "
    
    # Guardar reglas
    iptables-save > /etc/iptables/rules.v4
    
    log_security "✅ Firewall avanzado configurado"
}

# Configurar fail2ban avanzado
configurar_fail2ban_avanzado() {
    log_security "🛡️ Configurando fail2ban avanzado..."
    
    # Instalar fail2ban si no está presente
    if ! command -v fail2ban-server >/dev/null 2>&1; then
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y fail2ban
        elif command -v yum >/dev/null 2>&1; then
            yum install -y fail2ban
        fi
    fi
    
    # Configuración personalizada de fail2ban
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = $BAN_DURATION
findtime = 600
maxretry = $BRUTE_FORCE_THRESHOLD
backend = systemd
banaction = iptables-multiport
banaction_allports = iptables-allports
action = %(action_mwl)s

# SSH
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200

# Webmin
[webmin-auth]
enabled = true
port = 10000
logpath = /var/webmin/miniserv.log
failregex = ^.*authentication failure.*from <HOST>.*$
maxretry = 5
bantime = 3600

# Apache/Nginx
[apache-auth]
enabled = true
port = http,https
logpath = /var/log/apache2/error.log
failregex = ^.*client <HOST>.*authentication failure.*$

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
failregex = ^.*client: <HOST>.*user .* was not found.*$
            ^.*client: <HOST>.*user .* password mismatch.*$

# DDoS protection
[http-get-dos]
enabled = true
port = http,https
filter = http-get-dos
logpath = /var/log/apache2/access.log
          /var/log/nginx/access.log
maxretry = $DDOS_THRESHOLD
findtime = 300
bantime = 1800
action = iptables[name=HTTP, port=http, protocol=tcp]
         iptables[name=HTTPS, port=https, protocol=tcp]
EOF
    
    # Filtro personalizado para DDoS
    cat > /etc/fail2ban/filter.d/http-get-dos.conf << EOF
[Definition]
failregex = ^<HOST> -.*\"(GET|POST).*
ignoreregex =
EOF
    
    # Acción personalizada para baneos permanentes
    cat > /etc/fail2ban/action.d/iptables-permanent.conf << EOF
[Definition]
actionstart = iptables -N f2b-<name>
              iptables -A f2b-<name> -j RETURN
              iptables -I <chain> -p <protocol> --dport <port> -j f2b-<name>

actionstop = iptables -D <chain> -p <protocol> --dport <port> -j f2b-<name>
             iptables -F f2b-<name>
             iptables -X f2b-<name>

actioncheck = iptables -n -L <chain> | grep -q 'f2b-<name>[ \t]'

actionban = iptables -I f2b-<name> 1 -s <ip> -j DROP
            echo "<ip>" >> $BLACKLIST_FILE

actionunban = iptables -D f2b-<name> -s <ip> -j DROP
              sed -i '/<ip>/d' $BLACKLIST_FILE

[Init]
name = default
protocol = tcp
chain = INPUT
port = ssh
EOF
    
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    log_security "✅ Fail2ban avanzado configurado"
}

# Monitor de ataques en tiempo real
monitor_ataques_tiempo_real() {
    log_security "👁️ Iniciando monitor de ataques en tiempo real..."
    
    # Script de monitoreo
    cat > /usr/local/bin/attack-monitor.sh << 'EOF'
#!/bin/bash
SECURITY_LOG_DIR="/var/log/auto-tunnel/security"
BLACKLIST_FILE="/etc/auto-tunnel/security/blacklist.txt"
ATTACK_LOG="$SECURITY_LOG_DIR/attacks.log"
DDOS_THRESHOLD=200
BRUTE_FORCE_THRESHOLD=10

log_attack() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    local ip="$1"
    local attack_type="$2"
    local details="$3"
    echo "[$timestamp] IP: $ip | TYPE: $attack_type | DETAILS: $details" >> "$ATTACK_LOG"
}

check_ddos_attack() {
    # Verificar conexiones por IP
    netstat -tn | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr | while read count ip; do
        if [[ $count -gt $DDOS_THRESHOLD ]] && [[ "$ip" != "127.0.0.1" ]] && [[ "$ip" != "" ]]; then
            log_attack "$ip" "DDOS" "$count conexiones simultáneas"
            # Banear IP inmediatamente
            iptables -I INPUT -s "$ip" -j DROP
            echo "$ip" >> "$BLACKLIST_FILE"
            # Notificar
            curl -X POST "${WEBHOOK_URL:-}" \
                -H "Content-Type: application/json" \
                -d "{\"alert\":\"DDoS Attack\",\"ip\":\"$ip\",\"connections\":$count}" \
                --max-time 5 --silent || true
        fi
    done
}

check_brute_force() {
    # Verificar intentos de login fallidos
    local failed_attempts=$(grep "authentication failure" /var/log/auth.log | tail -100 | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr)
    
    echo "$failed_attempts" | while read count ip; do
        if [[ $count -gt $BRUTE_FORCE_THRESHOLD ]]; then
            log_attack "$ip" "BRUTE_FORCE" "$count intentos fallidos"
            fail2ban-client set sshd banip "$ip"
        fi
    done
}

check_port_scan() {
    # Verificar escaneos de puertos
    local port_scans=$(grep "IPTABLES-DROPPED" /var/log/syslog | tail -100 | awk '{print $NF}' | cut -d= -f2 | sort | uniq -c | sort -nr)
    
    echo "$port_scans" | while read count ip; do
        if [[ $count -gt 20 ]]; then
            log_attack "$ip" "PORT_SCAN" "$count paquetes rechazados"
            iptables -I INPUT -s "$ip" -j DROP
            echo "$ip" >> "$BLACKLIST_FILE"
        fi
    done
}

# Bucle principal de monitoreo
while true; do
    check_ddos_attack
    check_brute_force
    check_port_scan
    sleep 30
done
EOF
    
    chmod +x /usr/local/bin/attack-monitor.sh
    
    # Crear servicio systemd para el monitor
    cat > /etc/systemd/system/attack-monitor.service << EOF
[Unit]
Description=Real-time Attack Monitor
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/attack-monitor.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable attack-monitor
    systemctl start attack-monitor
    
    log_security "✅ Monitor de ataques en tiempo real activado"
}

# Configurar sistema de alertas inteligentes
configurar_alertas_inteligentes() {
    log_security "🔔 Configurando sistema de alertas inteligentes..."
    
    # Script de análisis de patrones
    cat > /usr/local/bin/intelligent-alerts.sh << 'EOF'
#!/bin/bash
SECURITY_LOG_DIR="/var/log/auto-tunnel/security"
ATTACK_LOG="$SECURITY_LOG_DIR/attacks.log"
ALERT_THRESHOLD_FILE="/etc/auto-tunnel/security/alert_thresholds.conf"

# Cargar configuración de umbrales
source "$ALERT_THRESHOLD_FILE" 2>/dev/null || {
    # Valores por defecto
    CRITICAL_ATTACKS_PER_HOUR=10
    SUSPICIOUS_IPS_THRESHOLD=5
    GEOGRAPHIC_ANOMALY_THRESHOLD=3
}

analyze_attack_patterns() {
    local last_hour=$(date -d '1 hour ago' +'%Y-%m-%d %H:%M:%S')
    local attacks_last_hour=$(awk -v since="$last_hour" '$0 >= since' "$ATTACK_LOG" | wc -l)
    
    if [[ $attacks_last_hour -gt $CRITICAL_ATTACKS_PER_HOUR ]]; then
        send_critical_alert "CRÍTICO: $attacks_last_hour ataques en la última hora"
    fi
    
    # Análisis de IPs sospechosas
    local unique_attackers=$(awk '{print $4}' "$ATTACK_LOG" | tail -100 | sort | uniq | wc -l)
    if [[ $unique_attackers -gt $SUSPICIOUS_IPS_THRESHOLD ]]; then
        send_warning_alert "ADVERTENCIA: $unique_attackers IPs diferentes atacando"
    fi
}

analyze_geographic_patterns() {
    # Análisis geográfico de ataques (requiere geoip)
    if command -v geoiplookup >/dev/null 2>&1; then
        local countries=$(awk '{print $4}' "$ATTACK_LOG" | tail -50 | while read ip; do
            geoiplookup "$ip" | cut -d: -f2 | cut -d, -f1
        done | sort | uniq -c | sort -nr)
        
        local top_country_attacks=$(echo "$countries" | head -1 | awk '{print $1}')
        if [[ $top_country_attacks -gt $GEOGRAPHIC_ANOMALY_THRESHOLD ]]; then
            local country=$(echo "$countries" | head -1 | awk '{$1=""; print $0}' | sed 's/^ //')
            send_info_alert "INFO: Concentración de ataques desde $country ($top_country_attacks ataques)"
        fi
    fi
}

send_critical_alert() {
    local message="$1"
    echo "[$(date)] CRITICAL: $message" >> "$SECURITY_LOG_DIR/critical_alerts.log"
    
    # Email crítico
    if [[ -n "${CRITICAL_EMAIL:-}" ]]; then
        echo "$message" | mail -s "🚨 ALERTA CRÍTICA DE SEGURIDAD" "$CRITICAL_EMAIL"
    fi
    
    # Webhook crítico
    if [[ -n "${CRITICAL_WEBHOOK:-}" ]]; then
        curl -X POST "$CRITICAL_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"level\":\"critical\",\"message\":\"$message\",\"timestamp\":\"$(date -Iseconds)\"}" \
            --max-time 10 || true
    fi
}

send_warning_alert() {
    local message="$1"
    echo "[$(date)] WARNING: $message" >> "$SECURITY_LOG_DIR/warning_alerts.log"
    
    if [[ -n "${WARNING_WEBHOOK:-}" ]]; then
        curl -X POST "$WARNING_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"level\":\"warning\",\"message\":\"$message\",\"timestamp\":\"$(date -Iseconds)\"}" \
            --max-time 10 || true
    fi
}

send_info_alert() {
    local message="$1"
    echo "[$(date)] INFO: $message" >> "$SECURITY_LOG_DIR/info_alerts.log"
}

# Ejecutar análisis
analyze_attack_patterns
analyze_geographic_patterns
EOF
    
    chmod +x /usr/local/bin/intelligent-alerts.sh
    
    # Configurar cron para ejecutar cada 15 minutos
    echo "*/15 * * * * root /usr/local/bin/intelligent-alerts.sh" >> /etc/crontab
    
    log_security "✅ Sistema de alertas inteligentes configurado"
}

# Configurar honeypots para detectar atacantes
configurar_honeypots() {
    log_security "🍯 Configurando honeypots para detección de atacantes..."
    
    # Honeypot SSH falso
    cat > /usr/local/bin/ssh-honeypot.py << 'EOF'
#!/usr/bin/env python3
import socket
import threading
import datetime
import logging

# Configurar logging
logging.basicConfig(
    filename='/var/log/auto-tunnel/security/honeypot.log',
    level=logging.INFO,
    format='%(asctime)s - %(message)s'
)

def handle_connection(conn, addr):
    try:
        conn.send(b"SSH-2.0-OpenSSH_7.4\r\n")
        data = conn.recv(1024)
        logging.info(f"Honeypot SSH connection from {addr[0]}:{addr[1]} - Data: {data.decode('utf-8', errors='ignore')}")
        
        # Simular proceso de autenticación
        conn.send(b"Password: ")
        password = conn.recv(1024)
        password_length = len(password.decode('utf-8', errors='ignore').strip())
        logging.info(f"Honeypot SSH login attempt from {addr[0]} - Password length: {password_length} chars")
        
        # Banear IP automáticamente
        import subprocess
        subprocess.run(["iptables", "-I", "INPUT", "-s", addr[0], "-j", "DROP"])
        
        with open("/etc/auto-tunnel/security/blacklist.txt", "a") as f:
            f.write(f"{addr[0]}\n")
            
    except Exception as e:
        logging.error(f"Error in honeypot: {e}")
    finally:
        conn.close()

def start_honeypot(port):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(('0.0.0.0', port))
    sock.listen(5)
    
    logging.info(f"SSH Honeypot started on port {port}")
    
    while True:
        conn, addr = sock.accept()
        thread = threading.Thread(target=handle_connection, args=(conn, addr))
        thread.daemon = True
        thread.start()

if __name__ == "__main__":
    start_honeypot(2222)  # Puerto alternativo para SSH
EOF
    
    chmod +x /usr/local/bin/ssh-honeypot.py
    
    # Servicio para el honeypot
    cat > /etc/systemd/system/ssh-honeypot.service << EOF
[Unit]
Description=SSH Honeypot
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/ssh-honeypot.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable ssh-honeypot
    systemctl start ssh-honeypot
    
    log_security "✅ Honeypots configurados"
}

# Función principal de configuración de seguridad
main_seguridad() {
    log_security "🔐 Iniciando configuración de seguridad avanzada..."
    
    # Crear archivos de configuración iniciales
    touch "$BLACKLIST_FILE" "$WHITELIST_FILE"
    
    # Configurar componentes de seguridad
    configurar_firewall_avanzado
    configurar_fail2ban_avanzado
    monitor_ataques_tiempo_real
    configurar_alertas_inteligentes
    configurar_honeypots
    
    # Crear script de limpieza automática
    cat > /usr/local/bin/security-cleanup.sh << 'EOF'
#!/bin/bash
# Limpieza automática de logs y listas negras

SECURITY_LOG_DIR="/var/log/auto-tunnel/security"
BLACKLIST_FILE="/etc/auto-tunnel/security/blacklist.txt"

# Rotar logs grandes
find "$SECURITY_LOG_DIR" -name "*.log" -size +100M -exec logrotate -f {} \;

# Limpiar IPs de la blacklist después de 24 horas
if [[ -f "$BLACKLIST_FILE" ]]; then
    # Crear backup
    cp "$BLACKLIST_FILE" "${BLACKLIST_FILE}.backup"
    
    # Remover IPs antiguas (esto es un ejemplo simplificado)
    # En producción, se debería implementar un sistema más sofisticado
    tail -1000 "$BLACKLIST_FILE" > "${BLACKLIST_FILE}.tmp"
    mv "${BLACKLIST_FILE}.tmp" "$BLACKLIST_FILE"
fi

# Optimizar reglas de iptables
iptables-save | awk '/^-A/ && !seen[$0]++' | iptables-restore
EOF
    
    chmod +x /usr/local/bin/security-cleanup.sh
    
    # Programar limpieza diaria
    echo "0 2 * * * root /usr/local/bin/security-cleanup.sh" >> /etc/crontab
    
    log_security "🎉 Configuración de seguridad avanzada completada"
    mostrar_resumen_seguridad
}

# Mostrar resumen de seguridad
mostrar_resumen_seguridad() {
    echo
    echo "═══════════════════════════════════════════════════════════════"
    echo "🔐 SISTEMA DE SEGURIDAD AVANZADA - CONFIGURACIÓN COMPLETADA"
    echo "═══════════════════════════════════════════════════════════════"
    echo
    echo "🛡️ Componentes de seguridad activados:"
    echo "   • ✅ Firewall avanzado con iptables"
    echo "   • ✅ Fail2ban con reglas personalizadas"
    echo "   • ✅ Monitor de ataques en tiempo real"
    echo "   • ✅ Sistema de alertas inteligentes"
    echo "   • ✅ Honeypots para detección de atacantes"
    echo "   • ✅ Protección contra DDoS y brute force"
    echo
    echo "📁 Archivos de configuración:"
    echo "   • Blacklist: $BLACKLIST_FILE"
    echo "   • Whitelist: $WHITELIST_FILE"
    echo "   • Logs de ataques: $ATTACK_LOG"
    echo "   • Logs de DDoS: $DDOS_LOG"
    echo "   • Logs de brute force: $BRUTE_FORCE_LOG"
    echo
    echo "🚀 Servicios de seguridad:"
    echo "   • attack-monitor.service (Monitor en tiempo real)"
    echo "   • ssh-honeypot.service (Honeypot SSH)"
    echo "   • fail2ban.service (Protección contra brute force)"
    echo
    echo "📊 Comandos útiles:"
    echo "   • fail2ban-client status"
    echo "   • iptables -L -n"
    echo "   • tail -f $ATTACK_LOG"
    echo "   • systemctl status attack-monitor"
    echo
    echo "⚡ Límites de seguridad configurados:"
    echo "   • Máx. conexiones por IP: $MAX_CONNECTIONS_PER_IP"
    echo "   • Máx. requests por minuto: $MAX_REQUESTS_PER_MINUTE"
    echo "   • Umbral brute force: $BRUTE_FORCE_THRESHOLD"
    echo "   • Umbral DDoS: $DDOS_THRESHOLD"
    echo "   • Duración de baneo: $BAN_DURATION segundos"
    echo
    echo "═══════════════════════════════════════════════════════════════"
}

# Manejo de argumentos
case "${1:-main}" in
    "main")
        main_seguridad
        ;;
    "firewall")
        configurar_firewall_avanzado
        ;;
    "fail2ban")
        configurar_fail2ban_avanzado
        ;;
    "monitor")
        monitor_ataques_tiempo_real
        ;;
    "alerts")
        configurar_alertas_inteligentes
        ;;
    "honeypots")
        configurar_honeypots
        ;;
    "cleanup")
        /usr/local/bin/security-cleanup.sh
        ;;
    *)
        echo "Uso: $0 [main|firewall|fail2ban|monitor|alerts|honeypots|cleanup]"
        exit 1
        ;;
esac
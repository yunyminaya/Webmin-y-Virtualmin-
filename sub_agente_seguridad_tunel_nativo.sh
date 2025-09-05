#!/bin/bash

# Sub-Agente Seguridad Túnel Nativo
# Seguridad avanzada para túnel nativo sin terceros

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/sub_agente_seguridad_tunel_nativo.log"
CONFIG_FILE="/etc/webmin/seguridad_tunel_nativo_config.conf"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SEG-TUNEL-NATIVO] $1" | tee -a "$LOG_FILE"
}

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configuración Seguridad Túnel Nativo
ENCRYPTION_ENABLED=true
KEY_ROTATION_ENABLED=true
ACCESS_CONTROL_STRICT=true
INTRUSION_DETECTION=true
TRAFFIC_ANALYSIS=true
AUTO_BLOCK_SUSPICIOUS=true
WHITELIST_ENABLED=true
MAX_CONNECTIONS_PER_IP=5
RATE_LIMITING=true
AUDIT_LOGGING=true
EOF
    fi
    source "$CONFIG_FILE"
}

setup_tunnel_encryption() {
    log_message "=== CONFIGURANDO CIFRADO DEL TÚNEL ==="
    
    # Generar certificados propios para el túnel
    local cert_dir="/etc/ssl/tunnel-native"
    mkdir -p "$cert_dir"
    
    # Generar CA propia
    if [ ! -f "$cert_dir/ca.key" ]; then
        openssl genrsa -out "$cert_dir/ca.key" 4096
        openssl req -new -x509 -days 3650 -key "$cert_dir/ca.key" -out "$cert_dir/ca.crt" \
            -subj "/C=ES/ST=State/L=City/O=TunnelNative/CN=TunnelCA"
        
        log_message "✓ CA propia generada"
    fi
    
    # Generar certificado del servidor
    if [ ! -f "$cert_dir/server.key" ]; then
        openssl genrsa -out "$cert_dir/server.key" 2048
        openssl req -new -key "$cert_dir/server.key" -out "$cert_dir/server.csr" \
            -subj "/C=ES/ST=State/L=City/O=TunnelNative/CN=$(hostname)"
        openssl x509 -req -in "$cert_dir/server.csr" -CA "$cert_dir/ca.crt" -CAkey "$cert_dir/ca.key" \
            -CAcreateserial -out "$cert_dir/server.crt" -days 365
        
        log_message "✓ Certificado del servidor generado"
    fi
    
    # Configurar cifrado en SSH
    cat >> /etc/ssh/sshd_config.d/tunnel-encryption.conf << 'EOF'
# Cifrado Avanzado para Túnel Nativo
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group16-sha512

# Configuración específica para túnel
Match User tunnel-native
    Ciphers chacha20-poly1305@openssh.com
    MACs hmac-sha2-256-etm@openssh.com
    KexAlgorithms curve25519-sha256@libssh.org
    PubkeyAuthentication yes
    PasswordAuthentication no
    ChallengeResponseAuthentication no
    UsePAM no
EOF

    systemctl restart sshd
    log_message "✓ Cifrado del túnel configurado"
}

setup_access_control() {
    log_message "=== CONFIGURANDO CONTROL DE ACCESO ESTRICTO ==="
    
    # Crear lista blanca de IPs
    cat > /etc/tunnel-native/whitelist.conf << 'EOF'
# Lista Blanca IPs para Túnel Nativo
# Formato: IP_ADDRESS DESCRIPTION
127.0.0.1 localhost
10.0.0.0/8 private_network_a
172.16.0.0/12 private_network_b
192.168.0.0/16 private_network_c
EOF
    
    # Script de verificación de acceso
    cat > "$SCRIPT_DIR/verify_access.sh" << 'EOF'
#!/bin/bash

# Verificación de Acceso para Túnel Nativo

WHITELIST="/etc/tunnel-native/whitelist.conf"
LOG_FILE="/var/log/tunnel_access_control.log"

log_access() {
    echo "[$(date -Iseconds)] $1" >> "$LOG_FILE"
}

check_ip_whitelist() {
    local client_ip="$1"
    
    if [ ! -f "$WHITELIST" ]; then
        log_access "ALLOW: $client_ip (no whitelist configured)"
        return 0
    fi
    
    # Verificar IP exacta
    if grep -q "^$client_ip " "$WHITELIST"; then
        log_access "ALLOW: $client_ip (exact match)"
        return 0
    fi
    
    # Verificar redes
    while read line; do
        if [[ "$line" =~ ^[0-9] ]] && [[ "$line" != *"#"* ]]; then
            local network=$(echo "$line" | awk '{print $1}')
            if [[ "$network" == *"/"* ]]; then
                # Verificar si IP está en la red
                if ipcalc -c "$network" "$client_ip" 2>/dev/null; then
                    log_access "ALLOW: $client_ip (network match: $network)"
                    return 0
                fi
            fi
        fi
    done < "$WHITELIST"
    
    log_access "DENY: $client_ip (not in whitelist)"
    return 1
}

# Verificar IP del cliente
CLIENT_IP="${SSH_CLIENT%% *}"
if [ -n "$CLIENT_IP" ]; then
    check_ip_whitelist "$CLIENT_IP"
else
    log_access "DENY: no client IP detected"
    exit 1
fi
EOF

    chmod +x "$SCRIPT_DIR/verify_access.sh"
    
    # Configurar verificación automática en SSH
    cat >> /etc/ssh/sshd_config.d/tunnel-access-control.conf << EOF
# Control de Acceso para Túnel Nativo
Match User tunnel-native
    ForceCommand $SCRIPT_DIR/verify_access.sh && /bin/false
    PermitOpen localhost:10000 localhost:80 localhost:443
    AllowTcpForwarding local
EOF

    systemctl restart sshd
    log_message "✓ Control de acceso estricto configurado"
}

setup_intrusion_detection() {
    log_message "=== CONFIGURANDO DETECCIÓN DE INTRUSIONES ==="
    
    # Monitor de conexiones sospechosas
    cat > "$SCRIPT_DIR/monitor_intrusion_tunel.sh" << 'EOF'
#!/bin/bash

# Monitor de Intrusiones para Túnel Nativo

LOG_FILE="/var/log/monitor_intrusion_tunel.log"
BLOCKED_IPS_FILE="/etc/tunnel-native/blocked_ips.list"

log_intrusion() {
    local event_type="$1"
    local source_ip="$2"
    local details="$3"
    
    echo "[$(date -Iseconds)] INTRUSION: $event_type from $source_ip - $details" | tee -a "$LOG_FILE"
    
    # Bloquear IP automáticamente
    block_ip "$source_ip" "$event_type"
}

block_ip() {
    local ip="$1"
    local reason="$2"
    
    # Agregar a lista de bloqueados
    echo "$ip $reason $(date -Iseconds)" >> "$BLOCKED_IPS_FILE"
    
    # Bloquear en iptables
    iptables -A INPUT -s "$ip" -j DROP
    
    # Bloquear en SSH
    echo "DenyUsers *@$ip" >> /etc/ssh/sshd_config.d/tunnel-blocked-ips.conf
    
    log_intrusion "IP_BLOCKED" "$ip" "$reason"
}

monitor_ssh_attempts() {
    # Monitor intentos SSH sospechosos
    tail -f /var/log/auth.log | while read line; do
        # Detectar ataques de fuerza bruta
        if echo "$line" | grep -q "Failed password"; then
            local ip=$(echo "$line" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+')
            local failed_count=$(grep "Failed password.*$ip" /var/log/auth.log | wc -l)
            
            if [ "$failed_count" -gt 3 ]; then
                log_intrusion "SSH_BRUTE_FORCE" "$ip" "Failed attempts: $failed_count"
            fi
        fi
        
        # Detectar intentos de escalación de privilegios
        if echo "$line" | grep -q "sudo.*FAILED"; then
            local ip=$(echo "$line" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+')
            log_intrusion "PRIVILEGE_ESCALATION" "$ip" "Failed sudo attempt"
        fi
    done &
}

monitor_network_traffic() {
    # Monitor tráfico de red sospechoso
    if command -v tcpdump &> /dev/null; then
        tcpdump -i any -nn -l port 10000 or port 80 or port 443 | while read line; do
            # Detectar escaneo de puertos
            if echo "$line" | grep -q "SYN.*FIN\|SYN.*RST\|SYN.*URG"; then
                local ip=$(echo "$line" | awk '{print $3}' | cut -d. -f1-4)
                log_intrusion "PORT_SCAN" "$ip" "TCP flag manipulation"
            fi
            
            # Detectar volumen anormal
            local ip=$(echo "$line" | awk '{print $3}' | cut -d: -f1)
            local current_minute=$(date +%Y%m%d%H%M)
            local connections_this_minute=$(grep "$ip.*$current_minute" "$LOG_FILE" | wc -l)
            
            if [ "$connections_this_minute" -gt 50 ]; then
                log_intrusion "HIGH_VOLUME" "$ip" "Connections: $connections_this_minute/minute"
            fi
        done &
    fi
}

# Iniciar monitores
monitor_ssh_attempts
monitor_network_traffic

# Mantener corriendo
wait
EOF

    chmod +x "$SCRIPT_DIR/monitor_intrusion_tunel.sh"
    
    # Crear servicio de detección de intrusiones
    cat > /etc/systemd/system/tunnel-intrusion-detection.service << EOF
[Unit]
Description=Detección de Intrusiones Túnel Nativo
After=network.target

[Service]
Type=simple
User=root
ExecStart=$SCRIPT_DIR/monitor_intrusion_tunel.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable tunnel-intrusion-detection.service
    
    log_message "✓ Detección de intrusiones configurada"
}

create_tunnel_audit_system() {
    log_message "=== CONFIGURANDO SISTEMA DE AUDITORÍA ==="
    
    # Configurar auditd para túnel
    if ! command -v auditctl &> /dev/null; then
        apt-get update && apt-get install -y auditd
    fi
    
    cat > /etc/audit/rules.d/tunnel-native.rules << 'EOF'
# Reglas de Auditoría para Túnel Nativo

# Monitorear accesos a archivos de configuración del túnel
-w /etc/ssh/sshd_config.d/ -p wa -k tunnel_config_change
-w /etc/tunnel-native/ -p wa -k tunnel_config_change
-w /etc/systemd/network/ -p wa -k tunnel_network_change

# Monitorear comandos de red
-a always,exit -F arch=b64 -S socket -S connect -S bind -k tunnel_network_activity
-a always,exit -F arch=b32 -S socket -S connect -S bind -k tunnel_network_activity

# Monitorear cambios en iptables
-w /etc/iptables/ -p wa -k tunnel_firewall_change
-a always,exit -F path=/sbin/iptables -F perm=x -k tunnel_firewall_change

# Monitorear servicios del túnel
-w /etc/systemd/system/tunnel-nativo.service -p wa -k tunnel_service_change
-w /etc/systemd/system/tunnel-forward-*.service -p wa -k tunnel_service_change

# Monitorear procesos sospechosos
-a always,exit -F arch=b64 -S execve -F exe=/usr/bin/ssh -k tunnel_ssh_execution
-a always,exit -F arch=b64 -S execve -F exe=/usr/bin/socat -k tunnel_socat_execution
EOF

    systemctl restart auditd
    
    log_message "✓ Sistema de auditoría configurado"
}

setup_rate_limiting() {
    log_message "=== CONFIGURANDO RATE LIMITING AVANZADO ==="
    
    # Configurar iptables con rate limiting específico
    cat > /etc/iptables/tunnel-rate-limiting.rules << 'EOF'
#!/bin/bash

# Rate Limiting Avanzado para Túnel Nativo

# Rate limiting por puerto
iptables -A INPUT -p tcp --dport 10000 -m recent --set --name WEBMIN_CLIENTS
iptables -A INPUT -p tcp --dport 10000 -m recent --update --seconds 60 --hitcount 10 --name WEBMIN_CLIENTS -j DROP

iptables -A INPUT -p tcp --dport 80 -m recent --set --name HTTP_CLIENTS
iptables -A INPUT -p tcp --dport 80 -m recent --update --seconds 60 --hitcount 30 --name HTTP_CLIENTS -j DROP

iptables -A INPUT -p tcp --dport 443 -m recent --set --name HTTPS_CLIENTS
iptables -A INPUT -p tcp --dport 443 -m recent --update --seconds 60 --hitcount 30 --name HTTPS_CLIENTS -j DROP

# Rate limiting SSH específico para túnel
iptables -A INPUT -p tcp --dport 22 -m recent --set --name SSH_TUNNEL
iptables -A INPUT -p tcp --dport 22 -m recent --update --seconds 300 --hitcount 5 --name SSH_TUNNEL -j DROP

# Limitar conexiones concurrentes por IP
iptables -A INPUT -p tcp --dport 10000 -m connlimit --connlimit-above 3 --connlimit-mask 32 -j REJECT
iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above 10 --connlimit-mask 32 -j REJECT
iptables -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above 10 --connlimit-mask 32 -j REJECT

# Log de rate limiting
iptables -A INPUT -m recent --update --seconds 60 --hitcount 50 --name RATE_LIMITED -j LOG --log-prefix "RATE-LIMITED: "
iptables -A INPUT -m recent --update --seconds 60 --hitcount 50 --name RATE_LIMITED -j DROP
EOF

    chmod +x /etc/iptables/tunnel-rate-limiting.rules
    /etc/iptables/tunnel-rate-limiting.rules
    
    log_message "✓ Rate limiting configurado"
}

create_security_monitor() {
    log_message "=== CREANDO MONITOR DE SEGURIDAD ==="
    
    cat > "$SCRIPT_DIR/monitor_seguridad_tunel.sh" << 'EOF'
#!/bin/bash

# Monitor de Seguridad Túnel Nativo

LOG_FILE="/var/log/monitor_seguridad_tunel.log"
ALERT_FILE="/var/log/alertas_seguridad_tunel.log"

log_security_event() {
    local severity="$1"
    local event="$2"
    local details="$3"
    
    local timestamp=$(date -Iseconds)
    echo "[$timestamp] [$severity] $event: $details" | tee -a "$LOG_FILE"
    
    if [ "$severity" = "CRITICAL" ] || [ "$severity" = "HIGH" ]; then
        echo "[$timestamp] $event: $details" >> "$ALERT_FILE"
    fi
}

analyze_tunnel_logs() {
    log_security_event "INFO" "ANALYSIS_START" "Iniciando análisis de logs del túnel"
    
    # Analizar logs SSH
    if [ -f "/var/log/auth.log" ]; then
        # Intentos de login fallidos en la última hora
        local failed_logins=$(grep "$(date '+%b %d %H')" /var/log/auth.log | grep "Failed password" | wc -l)
        if [ "$failed_logins" -gt 10 ]; then
            log_security_event "HIGH" "BRUTE_FORCE" "$failed_logins intentos fallidos en la última hora"
        fi
        
        # Nuevas claves SSH
        local new_keys=$(grep "$(date '+%b %d')" /var/log/auth.log | grep "Accepted publickey" | wc -l)
        if [ "$new_keys" -gt 0 ]; then
            log_security_event "MEDIUM" "NEW_SSH_KEYS" "$new_keys nuevas autenticaciones por clave"
        fi
    fi
    
    # Analizar logs de red
    if [ -f "/var/log/syslog" ]; then
        # Conexiones bloqueadas por iptables
        local blocked_connections=$(grep "$(date '+%b %d %H')" /var/log/syslog | grep "IPTABLES-DROPPED" | wc -l)
        if [ "$blocked_connections" -gt 50 ]; then
            log_security_event "HIGH" "HIGH_BLOCKED_TRAFFIC" "$blocked_connections conexiones bloqueadas en la última hora"
        fi
    fi
    
    # Analizar logs del túnel específicos
    if [ -f "/var/log/tunnel_access.log" ]; then
        # IPs con muchas conexiones
        local top_ips=$(tail -1000 /var/log/tunnel_access.log | awk '{print $1}' | sort | uniq -c | sort -nr | head -5)
        echo "$top_ips" | while read count ip; do
            if [ "$count" -gt 100 ]; then
                log_security_event "MEDIUM" "HIGH_CONNECTION_COUNT" "IP $ip: $count conexiones"
            fi
        done
    fi
}

check_tunnel_integrity() {
    log_security_event "INFO" "INTEGRITY_CHECK" "Verificando integridad del túnel"
    
    # Verificar certificados
    local cert_dir="/etc/ssl/tunnel-native"
    if [ -f "$cert_dir/server.crt" ]; then
        local cert_expiry=$(openssl x509 -enddate -noout -in "$cert_dir/server.crt" | cut -d= -f2)
        local expiry_timestamp=$(date -d "$cert_expiry" +%s)
        local current_timestamp=$(date +%s)
        local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
        
        if [ "$days_until_expiry" -lt 30 ]; then
            log_security_event "HIGH" "CERT_EXPIRING" "Certificado expira en $days_until_expiry días"
        fi
    fi
    
    # Verificar configuración SSH
    if ! sshd -t 2>/dev/null; then
        log_security_event "CRITICAL" "SSH_CONFIG_ERROR" "Configuración SSH inválida"
    fi
    
    # Verificar servicios del túnel
    local services=("tunnel-nativo" "tunnel-forward-webmin" "tunnel-intrusion-detection")
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet "$service" 2>/dev/null; then
            log_security_event "HIGH" "SERVICE_DOWN" "Servicio $service inactivo"
        fi
    done
}

generate_security_report() {
    local report_file="/var/log/seguridad_tunel_reporte_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "REPORTE DE SEGURIDAD - TÚNEL NATIVO"
        echo "=========================================="
        echo "Fecha: $(date)"
        echo ""
        
        echo "=== ESTADO DE SEGURIDAD ==="
        echo "Cifrado: $([ -f "/etc/ssl/tunnel-native/server.crt" ] && echo "✅ ACTIVO" || echo "❌ INACTIVO")"
        echo "Control de Acceso: $([ -f "/etc/tunnel-native/whitelist.conf" ] && echo "✅ ACTIVO" || echo "❌ INACTIVO")"
        echo "Detección Intrusiones: $(systemctl is-active tunnel-intrusion-detection 2>/dev/null || echo "❌ INACTIVO")"
        echo "Rate Limiting: $(iptables -L | grep -q "recent" && echo "✅ ACTIVO" || echo "❌ INACTIVO")"
        echo "Auditoría: $(systemctl is-active auditd 2>/dev/null || echo "❌ INACTIVO")"
        
        echo ""
        echo "=== IPS BLOQUEADAS (ÚLTIMAS 24H) ==="
        if [ -f "$BLOCKED_IPS_FILE" ]; then
            grep "$(date '+%Y-%m-%d')" "$BLOCKED_IPS_FILE" | tail -10
        else
            echo "No hay IPs bloqueadas"
        fi
        
        echo ""
        echo "=== EVENTOS DE SEGURIDAD (ÚLTIMAS 24H) ==="
        if [ -f "$LOG_FILE" ]; then
            grep "$(date '+%Y-%m-%d')" "$LOG_FILE" | grep -E "CRITICAL|HIGH" | tail -10
        else
            echo "No hay eventos críticos"
        fi
        
        echo ""
        echo "=== ESTADÍSTICAS DE ACCESO ==="
        echo "Conexiones SSH túnel: $(grep "tunnel-native" /var/log/auth.log | grep "$(date '+%b %d')" | wc -l)"
        echo "Conexiones Webmin: $(grep ":10000" /var/log/nginx/access.log 2>/dev/null | grep "$(date '+%d/%b/%Y')" | wc -l || echo "0")"
        echo "Ataques bloqueados: $(grep "$(date '+%Y-%m-%d')" "$ALERT_FILE" 2>/dev/null | wc -l || echo "0")"
        
    } > "$report_file"
    
    log_security_event "INFO" "REPORT_GENERATED" "$report_file"
    echo "$report_file"
}

# Monitor continuo
monitor_continuous() {
    while true; do
        analyze_tunnel_logs
        check_tunnel_integrity
        sleep 300  # Cada 5 minutos
    done
}

# Ejecutar según parámetro
case "${1:-monitor}" in
    monitor)
        monitor_continuous
        ;;
    report)
        generate_security_report
        ;;
    *)
        echo "Monitor de Seguridad Túnel Nativo"
        echo "Uso: $0 {monitor|report}"
        ;;
esac
EOF

    chmod +x "$SCRIPT_DIR/monitor_seguridad_tunel.sh"
    log_message "✓ Monitor de seguridad creado"
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")" "/etc/tunnel-native" 2>/dev/null || true
    log_message "=== INICIANDO SEGURIDAD TÚNEL NATIVO ==="
    
    load_config
    
    case "${1:-full}" in
        full)
            setup_tunnel_encryption
            setup_access_control
            setup_intrusion_detection
            create_tunnel_audit_system
            setup_rate_limiting
            create_security_monitor
            ;;
        encryption)
            setup_tunnel_encryption
            ;;
        access-control)
            setup_access_control
            ;;
        intrusion)
            setup_intrusion_detection
            ;;
        audit)
            create_tunnel_audit_system
            ;;
        rate-limiting)
            setup_rate_limiting
            ;;
        monitor)
            "$SCRIPT_DIR/monitor_seguridad_tunel.sh" monitor
            ;;
        report)
            "$SCRIPT_DIR/monitor_seguridad_tunel.sh" report
            ;;
        *)
            echo "Sub-Agente Seguridad Túnel Nativo"
            echo "Uso: $0 {full|encryption|access-control|intrusion|audit|rate-limiting|monitor|report}"
            echo ""
            echo "Comandos:"
            echo "  full           - Configuración completa de seguridad"
            echo "  encryption     - Configurar cifrado"
            echo "  access-control - Control de acceso estricto"
            echo "  intrusion      - Detección de intrusiones"
            echo "  audit          - Sistema de auditoría"
            echo "  rate-limiting  - Limitación de velocidad"
            echo "  monitor        - Monitoreo continuo"
            echo "  report         - Generar reporte de seguridad"
            exit 1
            ;;
    esac
    
    log_message "Seguridad túnel nativo completada"
}

main "$@"
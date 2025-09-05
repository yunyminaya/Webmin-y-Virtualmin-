#!/bin/bash

# Sub-Agente Seguridad de Servidores Virtuales
# Protección avanzada contra todo tipo de ataques

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/sub_agente_seguridad_servidores_virtuales.log"
SECURITY_STATUS_FILE="/var/lib/webmin/security_virtual_status.json"
CONFIG_FILE="/etc/webmin/security_virtual_config.conf"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SEG-VIRTUAL] $1" | tee -a "$LOG_FILE"
}

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configuración Seguridad Servidores Virtuales
DDOS_PROTECTION=true
WAF_ENABLED=true
BRUTE_FORCE_PROTECTION=true
MALWARE_SCANNING=true
LOG_ANALYSIS=true
ISOLATION_ENABLED=true
RESOURCE_LIMITS=true
AUTO_QUARANTINE=true
REAL_TIME_MONITORING=true
VULNERABILITY_SCANNING=true
INTRUSION_DETECTION=true
BOT_PROTECTION=true
EOF
    fi
    source "$CONFIG_FILE"
}

setup_ddos_protection() {
    log_message "=== CONFIGURANDO PROTECCIÓN DDOS ==="
    
    # Configuración iptables avanzada para DDoS
    cat > /etc/iptables/ddos-protection.rules << 'EOF'
#!/bin/bash

# Protección DDoS avanzada

# Limpiar reglas existentes
iptables -F
iptables -X

# Políticas por defecto
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Permitir loopback
iptables -A INPUT -i lo -j ACCEPT

# Permitir conexiones establecidas
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Protección SYN flood
iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT
iptables -A INPUT -p tcp --syn -j DROP

# Protección ping flood
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

# Limitar conexiones HTTP
iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -m limit --limit 20/minute --limit-burst 5 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -m limit --limit 20/minute --limit-burst 5 -j ACCEPT

# Limitar conexiones SSH
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set --name SSH
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Limitar conexiones Webmin
iptables -A INPUT -p tcp --dport 10000 -m conntrack --ctstate NEW -m limit --limit 10/minute --limit-burst 3 -j ACCEPT

# Bloquear direcciones privadas desde internet (anti-spoofing)
iptables -A INPUT -s 10.0.0.0/8 -j DROP
iptables -A INPUT -s 172.16.0.0/12 -j DROP
iptables -A INPUT -s 192.168.0.0/16 -j DROP

# Log de paquetes bloqueados
iptables -A INPUT -j LOG --log-prefix "IPTABLES-DROPPED: " --log-level 4
iptables -A INPUT -j DROP
EOF

    chmod +x /etc/iptables/ddos-protection.rules
    /etc/iptables/ddos-protection.rules
    
    # Hacer persistente
    iptables-save > /etc/iptables/rules.v4
    
    log_message "✓ Protección DDoS configurada"
}

setup_waf_protection() {
    log_message "=== CONFIGURANDO WAF (WEB APPLICATION FIREWALL) ==="
    
    # ModSecurity para Apache
    if systemctl is-active --quiet apache2; then
        apt-get update && apt-get install -y libapache2-mod-security2 modsecurity-crs
        
        cat > /etc/apache2/conf-available/security2.conf << 'EOF'
# ModSecurity Configuration
<IfModule mod_security2.c>
    SecRuleEngine On
    SecRequestBodyAccess On
    SecRule REQUEST_HEADERS:Content-Type "text/xml" \
         "id:'200000',phase:1,t:none,t:lowercase,pass,nolog,ctl:requestBodyProcessor=XML"
    SecRequestBodyLimit 13107200
    SecRequestBodyNoFilesLimit 131072
    SecRequestBodyInMemoryLimit 131072
    SecRequestBodyLimitAction Reject
    SecRule REQBODY_ERROR "!@eq 0" \
    "id:'200001', phase:2,t:none,log,deny,status:400,msg:'Failed to parse request body.',logdata:'Error %{REQBODY_ERROR_MSG}',severity:2"
    SecRule MULTIPART_STRICT_ERROR "!@eq 0" \
    "id:'200002',phase:2,t:none,log,deny,status:400, \
    msg:'Multipart request body failed strict validation: \
    PE %{REQBODY_PROCESSOR_ERROR}, \
    BQ %{MULTIPART_BOUNDARY_QUOTED}, \
    BW %{MULTIPART_BOUNDARY_WHITESPACE}, \
    DB %{MULTIPART_DATA_BEFORE}, \
    DA %{MULTIPART_DATA_AFTER}, \
    HF %{MULTIPART_HEADER_FOLDING}, \
    LF %{MULTIPART_LF_LINE}, \
    SM %{MULTIPART_MISSING_SEMICOLON}, \
    IQ %{MULTIPART_INVALID_QUOTING}, \
    IP %{MULTIPART_INVALID_PART}, \
    IH %{MULTIPART_INVALID_HEADER_FOLDING}, \
    FL %{MULTIPART_FILE_LIMIT_EXCEEDED}'"

    SecRule MULTIPART_UNMATCHED_BOUNDARY "!@eq 0" \
    "id:'200003',phase:2,t:none,log,deny,status:44"
    SecPcreMatchLimit 1000
    SecPcreMatchLimitRecursion 1000
    SecRule TX:/^MSC_/ "!@streq 0" \
            "id:'200004',phase:2,t:none,deny,msg:'ModSecurity internal error flagged: %{MATCHED_VAR_NAME}'"
    SecResponseBodyAccess On
    SecResponseBodyMimeType text/plain text/html text/xml
    SecResponseBodyLimit 524288
    SecResponseBodyLimitAction ProcessPartial
    SecTmpDir /tmp/
    SecDataDir /tmp/
    SecAuditEngine RelevantOnly
    SecAuditLogRelevantStatus "^(?:5|4(?!04))"
    SecAuditLogParts ABDEFHIJZ
    SecAuditLogType Serial
    SecAuditLog /var/log/apache2/modsec_audit.log
    SecArgumentSeparator &
    SecCookieFormat 0
    SecUnicodeMapFile unicode.mapping 20127
    SecStatusEngine On
    Include /usr/share/modsecurity-crs/owasp-crs.conf
    Include /usr/share/modsecurity-crs/rules/*.conf
</IfModule>
EOF

        a2enmod security2
        a2enconf security2
        systemctl reload apache2
        
        log_message "✓ ModSecurity WAF configurado para Apache"
    fi
    
    # Nginx WAF con Naxsi
    if systemctl is-active --quiet nginx; then
        apt-get install -y nginx-module-naxsi || true
        
        cat > /etc/nginx/conf.d/waf-protection.conf << 'EOF'
# WAF Protection for Nginx

# Rate limiting
limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=general:10m rate=30r/s;

# Connection limiting
limit_conn_zone $binary_remote_addr zone=addr:10m;

server {
    # General rate limiting
    limit_req zone=general burst=20 nodelay;
    limit_conn addr 10;
    
    # Block common attack patterns
    location ~* \.(php|pl|py|jsp|asp|sh|cgi)$ {
        if ($request_uri ~* "(\.\./|\.\.\\|%2e%2e)") { return 403; }
        if ($request_uri ~* "(union|select|insert|drop|delete|update|concat)") { return 403; }
        if ($request_uri ~* "(script|javascript|vbscript|onload|onerror)") { return 403; }
    }
    
    # Protect admin areas
    location ~* /(wp-admin|admin|administrator|cpanel|webmail) {
        limit_req zone=login burst=3 nodelay;
        allow 127.0.0.1;
        # Add your trusted IPs here
        # allow YOUR_IP;
        deny all;
    }
    
    # Block SQL injection attempts
    if ($args ~* "(\.|%2e)(\.|%2e)") { return 403; }
    if ($args ~* "(union|select|insert|drop|delete|update|concat|script)") { return 403; }
    
    # Block XSS attempts
    if ($args ~* "(<|%3c).*script.*(>|%3e)") { return 403; }
    if ($args ~* "(javascript|vbscript|onload|onerror|onclick)") { return 403; }
    
    # Block file inclusion attempts
    if ($args ~* "(\.\./|\.\.\\|%2e%2e)") { return 403; }
    if ($args ~* "(php://|file://|ftp://|http://)") { return 403; }
}
EOF

        systemctl reload nginx
        log_message "✓ WAF configurado para Nginx"
    fi
}

setup_malware_scanning() {
    log_message "=== CONFIGURANDO ESCANEO DE MALWARE ==="
    
    # Instalar ClamAV
    if ! command -v clamscan &> /dev/null; then
        apt-get update && apt-get install -y clamav clamav-daemon clamav-freshclam
    fi
    
    # Actualizar definiciones
    systemctl stop clamav-freshclam
    freshclam
    systemctl start clamav-freshclam
    systemctl start clamav-daemon
    
    # Configurar escaneo automático
    cat > /etc/cron.daily/malware-scan << 'EOF'
#!/bin/bash

# Escaneo diario de malware en servidores virtuales

LOG_FILE="/var/log/malware_scan_$(date +%Y%m%d).log"

echo "=== ESCANEO DE MALWARE - $(date) ===" > "$LOG_FILE"

# Escanear directorios web
SCAN_DIRS=("/var/www" "/home/*/public_html")

for dir_pattern in "${SCAN_DIRS[@]}"; do
    for dir in $dir_pattern; do
        if [ -d "$dir" ]; then
            echo "Escaneando: $dir" | tee -a "$LOG_FILE"
            clamscan -r --infected --remove "$dir" >> "$LOG_FILE" 2>&1
        fi
    done
done

# Escanear uploads
find /var/www /home/*/public_html -name "uploads" -type d 2>/dev/null | while read upload_dir; do
    echo "Escaneando uploads: $upload_dir" | tee -a "$LOG_FILE"
    clamscan -r --infected --remove "$upload_dir" >> "$LOG_FILE" 2>&1
done

# Resumen
INFECTED=$(grep "FOUND" "$LOG_FILE" | wc -l)
if [ "$INFECTED" -gt 0 ]; then
    echo "⚠️  MALWARE ENCONTRADO: $INFECTED archivos infectados" | tee -a "$LOG_FILE"
    echo "[$(date -Iseconds)] MALWARE: $INFECTED archivos infectados" >> "/var/log/alertas_criticas_seguridad.log"
else
    echo "✅ No se encontró malware" | tee -a "$LOG_FILE"
fi
EOF

    chmod +x /etc/cron.daily/malware-scan
    
    log_message "✓ Escaneo de malware configurado"
}

setup_virtual_isolation() {
    log_message "=== CONFIGURANDO AISLAMIENTO DE SERVIDORES VIRTUALES ==="
    
    # Configurar límites por usuario/dominio
    cat > /etc/security/limits.d/virtual-servers.conf << 'EOF'
# Límites para servidores virtuales

# Límites generales para usuarios web
@www-data soft nofile 2048
@www-data hard nofile 4096
@www-data soft nproc 512
@www-data hard nproc 1024

# Límites para usuarios de dominios
* soft as 1048576        # 1GB virtual memory
* hard as 2097152        # 2GB virtual memory
* soft cpu 300           # 5 minutos CPU
* hard cpu 600           # 10 minutos CPU
* soft fsize 1048576     # 1GB file size
* hard fsize 2097152     # 2GB file size
EOF

    # Configurar systemd para limitación de recursos
    mkdir -p /etc/systemd/system/apache2.service.d
    cat > /etc/systemd/system/apache2.service.d/limits.conf << 'EOF'
[Service]
LimitNOFILE=65536
LimitNPROC=4096
LimitAS=2G
MemoryAccounting=yes
MemoryLimit=2G
CPUAccounting=yes
CPUQuota=80%
EOF

    systemctl daemon-reload
    systemctl restart apache2
    
    log_message "✓ Aislamiento de recursos configurado"
}

setup_real_time_monitoring() {
    log_message "=== CONFIGURANDO MONITOREO EN TIEMPO REAL ==="
    
    cat > "$SCRIPT_DIR/monitor_tiempo_real.sh" << 'EOF'
#!/bin/bash

# Monitor en Tiempo Real de Ataques

LOG_FILE="/var/log/monitor_tiempo_real.log"
ATTACK_LOG="/var/log/ataques_detectados.log"

log_attack() {
    local attack_type="$1"
    local source_ip="$2"
    local details="$3"
    
    echo "[$(date -Iseconds)] ATAQUE: $attack_type desde $source_ip - $details" | tee -a "$ATTACK_LOG"
    
    # Bloquear IP inmediatamente
    iptables -A INPUT -s "$source_ip" -j DROP
    
    # Notificar
    echo "IP $source_ip bloqueada por $attack_type" >> "/var/log/ips_bloqueadas.log"
}

monitor_access_logs() {
    # Monitor Apache
    if [ -f "/var/log/apache2/access.log" ]; then
        tail -f /var/log/apache2/access.log | while read line; do
            local ip=$(echo "$line" | awk '{print $1}')
            local request=$(echo "$line" | awk '{print $7}')
            local user_agent=$(echo "$line" | grep -o '"[^"]*"$' | tr -d '"')
            
            # Detectar ataques SQL injection
            if echo "$request" | grep -qiE "(union|select|insert|drop|delete|update|script|javascript)"; then
                log_attack "SQL_INJECTION" "$ip" "$request"
            fi
            
            # Detectar ataques XSS
            if echo "$request" | grep -qiE "(<script|javascript:|onload=|onerror=)"; then
                log_attack "XSS_ATTEMPT" "$ip" "$request"
            fi
            
            # Detectar escaneo de vulnerabilidades
            if echo "$user_agent" | grep -qiE "(sqlmap|nikto|nmap|masscan|zap|burp)"; then
                log_attack "VULN_SCAN" "$ip" "$user_agent"
            fi
            
            # Detectar directory traversal
            if echo "$request" | grep -qE "(\.\./|\.\.\\|%2e%2e)"; then
                log_attack "DIR_TRAVERSAL" "$ip" "$request"
            fi
            
            # Detectar exceso de requests (DDoS)
            local request_count=$(grep "$ip" /var/log/apache2/access.log | grep "$(date '+%d/%b/%Y:%H:%M')" | wc -l)
            if [ "$request_count" -gt 100 ]; then
                log_attack "DDOS_ATTEMPT" "$ip" "Requests: $request_count/minute"
            fi
        done &
    fi
    
    # Monitor auth.log para SSH
    if [ -f "/var/log/auth.log" ]; then
        tail -f /var/log/auth.log | while read line; do
            if echo "$line" | grep -q "Failed password"; then
                local ip=$(echo "$line" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+')
                local failed_count=$(grep "Failed password.*$ip" /var/log/auth.log | wc -l)
                
                if [ "$failed_count" -gt 5 ]; then
                    log_attack "SSH_BRUTE_FORCE" "$ip" "Failed attempts: $failed_count"
                fi
            fi
        done &
    fi
}

# Iniciar monitoreo
monitor_access_logs
EOF

    chmod +x "$SCRIPT_DIR/monitor_tiempo_real.sh"
    
    # Crear servicio para monitoreo en tiempo real
    cat > /etc/systemd/system/monitor-tiempo-real.service << EOF
[Unit]
Description=Monitor de Ataques en Tiempo Real
After=network.target

[Service]
Type=simple
User=root
ExecStart=$SCRIPT_DIR/monitor_tiempo_real.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable monitor-tiempo-real.service
    
    log_message "✓ Monitoreo en tiempo real configurado"
}

setup_bot_protection() {
    log_message "=== CONFIGURANDO PROTECCIÓN CONTRA BOTS ==="
    
    # Lista de User-Agents maliciosos
    cat > /etc/apache2/conf-available/bot-protection.conf << 'EOF'
# Protección contra bots maliciosos

<RequireAll>
    # Bloquear bots conocidos
    SetEnvIfNoCase User-Agent "^ahrefs" bad_bot
    SetEnvIfNoCase User-Agent "^alexibot" bad_bot
    SetEnvIfNoCase User-Agent "^asterias" bad_bot
    SetEnvIfNoCase User-Agent "^attach" bad_bot
    SetEnvIfNoCase User-Agent "^backdoorbot" bad_bot
    SetEnvIfNoCase User-Agent "^bandido" bad_bot
    SetEnvIfNoCase User-Agent "^botalot" bad_bot
    SetEnvIfNoCase User-Agent "^built with" bad_bot
    SetEnvIfNoCase User-Agent "^bumble" bad_bot
    SetEnvIfNoCase User-Agent "^collect" bad_bot
    SetEnvIfNoCase User-Agent "^cosmos" bad_bot
    SetEnvIfNoCase User-Agent "^crescent" bad_bot
    SetEnvIfNoCase User-Agent "^curl" bad_bot
    SetEnvIfNoCase User-Agent "^disco" bad_bot
    SetEnvIfNoCase User-Agent "^download" bad_bot
    SetEnvIfNoCase User-Agent "^extract" bad_bot
    SetEnvIfNoCase User-Agent "^harvest" bad_bot
    SetEnvIfNoCase User-Agent "^httrack" bad_bot
    SetEnvIfNoCase User-Agent "^ia_archiver" bad_bot
    SetEnvIfNoCase User-Agent "^kmccrew" bad_bot
    SetEnvIfNoCase User-Agent "^libwww" bad_bot
    SetEnvIfNoCase User-Agent "^mass" bad_bot
    SetEnvIfNoCase User-Agent "^mister" bad_bot
    SetEnvIfNoCase User-Agent "^nikto" bad_bot
    SetEnvIfNoCase User-Agent "^nutch" bad_bot
    SetEnvIfNoCase User-Agent "^pagegrabber" bad_bot
    SetEnvIfNoCase User-Agent "^planetwork" bad_bot
    SetEnvIfNoCase User-Agent "^postrank" bad_bot
    SetEnvIfNoCase User-Agent "^python" bad_bot
    SetEnvIfNoCase User-Agent "^scan" bad_bot
    SetEnvIfNoCase User-Agent "^skipper" bad_bot
    SetEnvIfNoCase User-Agent "^spider" bad_bot
    SetEnvIfNoCase User-Agent "^sucker" bad_bot
    SetEnvIfNoCase User-Agent "^turnit" bad_bot
    SetEnvIfNoCase User-Agent "^vikspider" bad_bot
    SetEnvIfNoCase User-Agent "^wget" bad_bot
    SetEnvIfNoCase User-Agent "^winhttp" bad_bot
    SetEnvIfNoCase User-Agent "^xxxyy" bad_bot
    SetEnvIfNoCase User-Agent "^zmeu" bad_bot
    
    # Bloquear requests vacíos o sospechosos
    SetEnvIfNoCase User-Agent "^$" bad_bot
    SetEnvIfNoCase User-Agent "^ *$" bad_bot
    
    Require not env bad_bot
</RequireAll>

# Challenge para bots sospechosos
<LocationMatch "/(wp-admin|admin|administrator)">
    # Requiere JavaScript habilitado
    SetEnvIf User-Agent "bot|crawler|spider|scraper" bot_detected
    
    <RequireAll>
        Require not env bot_detected
        # Agregar verificación de JavaScript aquí
    </RequireAll>
</LocationMatch>
EOF

    a2enconf bot-protection
    systemctl reload apache2
    
    log_message "✓ Protección contra bots configurada"
}

setup_vulnerability_scanning() {
    log_message "=== CONFIGURANDO ESCANEO DE VULNERABILIDADES ==="
    
    # Instalar Nikto para escaneo web
    if ! command -v nikto &> /dev/null; then
        apt-get update && apt-get install -y nikto
    fi
    
    # Crear script de escaneo automático
    cat > "$SCRIPT_DIR/scan_vulnerabilidades.sh" << 'EOF'
#!/bin/bash

# Escaneo automático de vulnerabilidades

LOG_FILE="/var/log/vulnerability_scan_$(date +%Y%m%d).log"

echo "=== ESCANEO DE VULNERABILIDADES - $(date) ===" > "$LOG_FILE"

# Obtener dominios locales
get_local_domains() {
    {
        # Desde Virtualmin
        virtualmin list-domains 2>/dev/null | grep "^Domain:" | awk '{print $2}'
        
        # Desde Apache
        grep -h "ServerName" /etc/apache2/sites-enabled/*.conf 2>/dev/null | awk '{print $2}'
        
        # Desde Nginx
        grep -h "server_name" /etc/nginx/sites-enabled/* 2>/dev/null | awk '{print $2}' | sed 's/;//g'
        
    } | sort | uniq | grep -E "^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
}

# Escanear cada dominio
get_local_domains | while read domain; do
    echo "Escaneando: $domain" | tee -a "$LOG_FILE"
    
    # Nikto scan
    nikto -h "http://$domain" -o "/tmp/nikto_${domain}.txt" -Format txt 2>/dev/null
    
    # Buscar vulnerabilidades críticas
    if grep -qE "(CRITICAL|HIGH)" "/tmp/nikto_${domain}.txt" 2>/dev/null; then
        echo "⚠️  VULNERABILIDADES CRÍTICAS encontradas en $domain" | tee -a "$LOG_FILE"
        echo "[$(date -Iseconds)] VULN_CRITICAL: $domain" >> "/var/log/alertas_criticas_seguridad.log"
    fi
    
    # WordPress specific
    if curl -s "http://$domain" | grep -q "wp-content"; then
        # WPScan si está disponible
        if command -v wpscan &> /dev/null; then
            wpscan --url "http://$domain" --enumerate u,p,t --format json > "/tmp/wpscan_${domain}.json" 2>/dev/null || true
        fi
    fi
    
    rm -f "/tmp/nikto_${domain}.txt" "/tmp/wpscan_${domain}.json"
done

echo "Escaneo de vulnerabilidades completado" | tee -a "$LOG_FILE"
EOF

    chmod +x "$SCRIPT_DIR/scan_vulnerabilidades.sh"
    
    # Programar escaneo semanal
    (crontab -l 2>/dev/null; echo "0 2 * * 0 $SCRIPT_DIR/scan_vulnerabilidades.sh") | crontab -
    
    log_message "✓ Escaneo de vulnerabilidades programado"
}

auto_quarantine_threats() {
    log_message "=== CONFIGURANDO CUARENTENA AUTOMÁTICA ==="
    
    cat > "$SCRIPT_DIR/auto_quarantine.sh" << 'EOF'
#!/bin/bash

# Cuarentena automática de amenazas

QUARANTINE_DIR="/var/quarantine"
LOG_FILE="/var/log/auto_quarantine.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [QUARANTINE] $1" | tee -a "$LOG_FILE"
}

quarantine_file() {
    local file="$1"
    local reason="$2"
    
    if [ -f "$file" ]; then
        mkdir -p "$QUARANTINE_DIR/$(dirname "$file")"
        mv "$file" "$QUARANTINE_DIR/$file.$(date +%Y%m%d_%H%M%S)"
        
        log_message "Archivo en cuarentena: $file (Razón: $reason)"
        echo "[$(date -Iseconds)] QUARANTINE: $file - $reason" >> "/var/log/alertas_criticas_seguridad.log"
    fi
}

scan_suspicious_files() {
    # Buscar archivos PHP sospechosos
    find /var/www /home/*/public_html -name "*.php" -type f 2>/dev/null | while read php_file; do
        if grep -qE "(eval|base64_decode|shell_exec|system|exec|passthru)" "$php_file" 2>/dev/null; then
            if grep -qE "(malware|backdoor|c99|r57|wso)" "$php_file" 2>/dev/null; then
                quarantine_file "$php_file" "POSSIBLE_BACKDOOR"
            fi
        fi
    done
    
    # Buscar archivos con permisos sospechosos
    find /var/www /home/*/public_html -type f -perm /002 2>/dev/null | while read writable_file; do
        if echo "$writable_file" | grep -qE "\.(php|pl|py|cgi)$"; then
            quarantine_file "$writable_file" "WORLD_WRITABLE_SCRIPT"
        fi
    done
    
    # Buscar archivos con nombres sospechosos
    find /var/www /home/*/public_html -type f 2>/dev/null | grep -E "(shell|hack|backdoor|c99|r57|wso|bypass)" | while read suspicious_file; do
        quarantine_file "$suspicious_file" "SUSPICIOUS_FILENAME"
    done
}

# Ejecutar escaneo
scan_suspicious_files
EOF

    chmod +x "$SCRIPT_DIR/auto_quarantine.sh"
    
    # Programar ejecución cada hora
    (crontab -l 2>/dev/null; echo "0 * * * * $SCRIPT_DIR/auto_quarantine.sh") | crontab -
    
    log_message "✓ Cuarentena automática configurada"
}

generate_security_report() {
    log_message "=== GENERANDO REPORTE DE SEGURIDAD ==="
    
    local security_report="/var/log/seguridad_virtual_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "REPORTE DE SEGURIDAD - SERVIDORES VIRTUALES"
        echo "=========================================="
        echo "Fecha: $(date)"
        echo "Servidor: $(hostname)"
        echo ""
        
        echo "=== ESTADO DE PROTECCIONES ==="
        echo "DDoS Protection: $([ "$DDOS_PROTECTION" = "true" ] && echo "✅ ACTIVO" || echo "❌ INACTIVO")"
        echo "WAF Protection: $([ "$WAF_ENABLED" = "true" ] && echo "✅ ACTIVO" || echo "❌ INACTIVO")"
        echo "Malware Scanning: $([ "$MALWARE_SCANNING" = "true" ] && echo "✅ ACTIVO" || echo "❌ INACTIVO")"
        echo "Real-time Monitoring: $([ "$REAL_TIME_MONITORING" = "true" ] && echo "✅ ACTIVO" || echo "❌ INACTIVO")"
        echo "Bot Protection: $([ "$BOT_PROTECTION" = "true" ] && echo "✅ ACTIVO" || echo "❌ INACTIVO")"
        
        echo ""
        echo "=== ESTADÍSTICAS DE ATAQUES (ÚLTIMAS 24H) ==="
        if [ -f "/var/log/ataques_detectados.log" ]; then
            local attacks_24h=$(grep "$(date '+%Y-%m-%d')" /var/log/ataques_detectados.log | wc -l)
            echo "Ataques detectados: $attacks_24h"
            
            echo ""
            echo "Tipos de ataques más frecuentes:"
            grep "$(date '+%Y-%m-%d')" /var/log/ataques_detectados.log | awk '{print $3}' | sort | uniq -c | sort -nr | head -5
            
            echo ""
            echo "IPs más agresivas:"
            grep "$(date '+%Y-%m-%d')" /var/log/ataques_detectados.log | awk '{print $5}' | sort | uniq -c | sort -nr | head -5
        else
            echo "No hay registro de ataques detectados"
        fi
        
        echo ""
        echo "=== IPs ACTUALMENTE BLOQUEADAS ==="
        iptables -L INPUT | grep DROP | awk '{print $4}' | grep -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | head -10
        
        echo ""
        echo "=== ARCHIVOS EN CUARENTENA ==="
        if [ -d "/var/quarantine" ]; then
            find /var/quarantine -type f | wc -l | awk '{print "Total: " $1 " archivos"}'
            find /var/quarantine -name "*.php" | head -5
        else
            echo "No hay archivos en cuarentena"
        fi
        
        echo ""
        echo "=== ÚLTIMA VERIFICACIÓN DE MALWARE ==="
        if [ -f "/var/log/malware_scan_$(date +%Y%m%d).log" ]; then
            tail -5 "/var/log/malware_scan_$(date +%Y%m%d).log"
        else
            echo "No se ha ejecutado escaneo de malware hoy"
        fi
        
        echo ""
        echo "=== RECOMENDACIONES ==="
        if [ "$attacks_24h" -gt 100 ]; then
            echo "🔴 Alto volumen de ataques - Considerar CDN adicional"
        elif [ "$attacks_24h" -gt 50 ]; then
            echo "🟡 Volumen moderado de ataques - Monitoreo continuo"
        else
            echo "🟢 Volumen normal de ataques - Sistema seguro"
        fi
        
    } > "$security_report"
    
    log_message "✓ Reporte de seguridad: $security_report"
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")" "/var/lib/webmin" "/var/quarantine" 2>/dev/null || true
    log_message "=== INICIANDO SEGURIDAD DE SERVIDORES VIRTUALES ==="
    
    load_config
    
    case "${1:-full}" in
        full)
            setup_ddos_protection
            setup_waf_protection
            setup_malware_scanning
            setup_virtual_isolation
            setup_real_time_monitoring
            setup_bot_protection
            setup_vulnerability_scanning
            auto_quarantine_threats
            generate_security_report
            ;;
        ddos)
            setup_ddos_protection
            ;;
        waf)
            setup_waf_protection
            ;;
        malware)
            setup_malware_scanning
            ;;
        isolation)
            setup_virtual_isolation
            ;;
        monitor)
            setup_real_time_monitoring
            "$SCRIPT_DIR/monitor_tiempo_real.sh" &
            ;;
        bots)
            setup_bot_protection
            ;;
        vulnerabilities)
            setup_vulnerability_scanning
            "$SCRIPT_DIR/scan_vulnerabilidades.sh"
            ;;
        quarantine)
            auto_quarantine_threats
            "$SCRIPT_DIR/auto_quarantine.sh"
            ;;
        report)
            generate_security_report
            cat "$security_report" 2>/dev/null || echo "No hay reporte disponible"
            ;;
        *)
            echo "Sub-Agente Seguridad de Servidores Virtuales"
            echo "Uso: $0 {full|ddos|waf|malware|isolation|monitor|bots|vulnerabilities|quarantine|report}"
            echo ""
            echo "Comandos:"
            echo "  full            - Configuración completa de seguridad"
            echo "  ddos            - Protección DDoS"
            echo "  waf             - Web Application Firewall"
            echo "  malware         - Escaneo de malware"
            echo "  isolation       - Aislamiento de recursos"
            echo "  monitor         - Monitoreo en tiempo real"
            echo "  bots            - Protección contra bots"
            echo "  vulnerabilities - Escaneo de vulnerabilidades"
            echo "  quarantine      - Cuarentena automática"
            echo "  report          - Reporte de seguridad"
            exit 1
            ;;
    esac
    
    log_message "Seguridad de servidores virtuales completada"
}

main "$@"
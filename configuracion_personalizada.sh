#!/bin/bash
# Script de configuración personalizada post-instalación
# Permite configurar notificaciones, túneles específicos y optimizaciones
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
CONFIG_FILE="$CONFIG_BASE_DIR/custom-config.conf"

# Colores para output
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Funciones de logging
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

# Función para mostrar banner
mostrar_banner() {
    clear
    echo -e "${CYAN}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "⚙️  CONFIGURACIÓN PERSONALIZADA DEL SISTEMA DE TÚNELES ⚙️"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    echo
}

# Función para leer input del usuario
read_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [[ -n "$default" ]]; then
        echo -e "${YELLOW}$prompt${NC} ${BLUE}[default: $default]${NC}: "
    else
        echo -e "${YELLOW}$prompt${NC}: "
    fi
    
    read -r input
    if [[ -z "$input" && -n "$default" ]]; then
        input="$default"
    fi
    
    eval "$var_name='$input'"
}

# Función para confirmar acción
confirm() {
    local prompt="$1"
    echo -e "${YELLOW}$prompt${NC} ${BLUE}[y/N]${NC}: "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Configurar notificaciones por email
configurar_email() {
    echo -e "${CYAN}📧 CONFIGURACIÓN DE NOTIFICACIONES POR EMAIL${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo
    
    if confirm "¿Desea configurar notificaciones por email?"; then
        read_input "Email para notificaciones generales" "" "NOTIFICATION_EMAIL"
        read_input "Email para alertas críticas" "$NOTIFICATION_EMAIL" "CRITICAL_EMAIL"
        read_input "Email para reportes diarios" "$NOTIFICATION_EMAIL" "DAILY_REPORT_EMAIL"
        
        # Configurar servidor SMTP si es necesario
        if confirm "¿Desea configurar un servidor SMTP personalizado?"; then
            read_input "Servidor SMTP" "localhost" "SMTP_SERVER"
            read_input "Puerto SMTP" "587" "SMTP_PORT"
            read_input "Usuario SMTP" "" "SMTP_USER"
            read_input "Contraseña SMTP" "" "SMTP_PASS"
            
            # Configurar postfix/sendmail
            log_info "Configurando servidor de correo..."
            
            # Instalar postfix si no está instalado
            if ! command -v postfix >/dev/null 2>&1; then
                if command -v apt-get >/dev/null 2>&1; then
                    apt-get install -y postfix mailutils
                elif command -v yum >/dev/null 2>&1; then
                    yum install -y postfix mailx
                fi
            fi
            
            # Configurar postfix para relay SMTP
            cat > /etc/postfix/main.cf << EOF
# Configuración básica de Postfix para relay SMTP
myhostname = $(hostname -f)
mydomain = $(hostname -d)
myorigin = \$mydomain
inet_interfaces = loopback-only
mydestination = \$myhostname, localhost.\$mydomain, localhost
relayhost = [$SMTP_SERVER]:$SMTP_PORT
smtp_use_tls = yes
smtp_sasl_auth_enable = yes
smtp_sasl_security_options = noanonymous
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
EOF
            
            # Configurar credenciales SMTP
            echo "[$SMTP_SERVER]:$SMTP_PORT $SMTP_USER:$SMTP_PASS" > /etc/postfix/sasl_passwd
            chmod 600 /etc/postfix/sasl_passwd
            postmap /etc/postfix/sasl_passwd
            
            # Reiniciar postfix
            systemctl restart postfix
            systemctl enable postfix
        fi
        
        # Guardar configuración de email
        cat >> "$CONFIG_FILE" << EOF

# Configuración de Email
NOTIFICATION_EMAIL="$NOTIFICATION_EMAIL"
CRITICAL_EMAIL="$CRITICAL_EMAIL"
DAILY_REPORT_EMAIL="$DAILY_REPORT_EMAIL"
EOF
        
        if [[ -n "${SMTP_SERVER:-}" ]]; then
            cat >> "$CONFIG_FILE" << EOF
SMTP_SERVER="$SMTP_SERVER"
SMTP_PORT="$SMTP_PORT"
SMTP_USER="$SMTP_USER"
EOF
        fi
        
        # Probar envío de email
        if confirm "¿Desea probar el envío de email?"; then
            echo "Probando envío de email de prueba..." | mail -s "Prueba - Sistema de Túneles" "$NOTIFICATION_EMAIL" && \
                log "✅ Email de prueba enviado correctamente" || \
                log_warning "⚠️ Error al enviar email de prueba"
        fi
        
        log "✅ Configuración de email completada"
    fi
    echo
}

# Configurar webhooks
configurar_webhooks() {
    echo -e "${CYAN}🔗 CONFIGURACIÓN DE WEBHOOKS${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo
    
    if confirm "¿Desea configurar webhooks para notificaciones?"; then
        read_input "URL del webhook general" "" "WEBHOOK_URL"
        read_input "URL del webhook para alertas críticas" "$WEBHOOK_URL" "CRITICAL_WEBHOOK"
        read_input "URL del webhook para alta disponibilidad" "$WEBHOOK_URL" "HA_WEBHOOK_URL"
        
        # Configurar Slack si es necesario
        if confirm "¿Desea configurar integración específica con Slack?"; then
            read_input "URL del webhook de Slack" "" "SLACK_WEBHOOK_URL"
            read_input "Canal de Slack para notificaciones" "#general" "SLACK_CHANNEL"
            read_input "Nombre del bot" "TunnelBot" "SLACK_BOT_NAME"
            
            cat >> "$CONFIG_FILE" << EOF

# Configuración de Slack
SLACK_WEBHOOK_URL="$SLACK_WEBHOOK_URL"
SLACK_CHANNEL="$SLACK_CHANNEL"
SLACK_BOT_NAME="$SLACK_BOT_NAME"
EOF
        fi
        
        # Guardar configuración de webhooks
        cat >> "$CONFIG_FILE" << EOF

# Configuración de Webhooks
WEBHOOK_URL="$WEBHOOK_URL"
CRITICAL_WEBHOOK="$CRITICAL_WEBHOOK"
HA_WEBHOOK_URL="$HA_WEBHOOK_URL"
EOF
        
        # Probar webhook
        if confirm "¿Desea probar el webhook?"; then
            local test_payload='{"text":"🧪 Prueba de webhook - Sistema de Túneles funcionando correctamente"}'
            if curl -X POST -H 'Content-type: application/json' --data "$test_payload" "$WEBHOOK_URL" >/dev/null 2>&1; then
                log "✅ Webhook probado correctamente"
            else
                log_warning "⚠️ Error al probar webhook"
            fi
        fi
        
        log "✅ Configuración de webhooks completada"
    fi
    echo
}

# Configurar túneles específicos
configurar_tunnels() {
    echo -e "${CYAN}🌐 CONFIGURACIÓN DE TÚNELES ESPECÍFICOS${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo
    
    # Configurar Cloudflare Tunnel
    if confirm "¿Desea configurar Cloudflare Tunnel con token personalizado?"; then
        read_input "Token de Cloudflare Tunnel" "" "CLOUDFLARE_TOKEN"
        read_input "Dominio personalizado (opcional)" "" "CLOUDFLARE_DOMAIN"
        
        if [[ -n "$CLOUDFLARE_TOKEN" ]]; then
            # Configurar túnel con token
            mkdir -p "$CONFIG_BASE_DIR/cloudflare"
            echo "$CLOUDFLARE_TOKEN" > "$CONFIG_BASE_DIR/cloudflare/token"
            chmod 600 "$CONFIG_BASE_DIR/cloudflare/token"
            
            # Crear configuración específica
            cat > "$CONFIG_BASE_DIR/cloudflare/config.yml" << EOF
tunnel: $(echo "$CLOUDFLARE_TOKEN" | cut -d. -f1)
credentials-file: $CONFIG_BASE_DIR/cloudflare/token

ingress:
  - hostname: webmin.${CLOUDFLARE_DOMAIN:-example.com}
    service: https://localhost:10000
    originRequest:
      noTLSVerify: true
  - hostname: usermin.${CLOUDFLARE_DOMAIN:-example.com}
    service: https://localhost:20000
    originRequest:
      noTLSVerify: true
  - hostname: ${CLOUDFLARE_DOMAIN:-example.com}
    service: https://localhost:443
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF
            
            cat >> "$CONFIG_FILE" << EOF

# Configuración de Cloudflare
CLOUDFLARE_TOKEN="$CLOUDFLARE_TOKEN"
CLOUDFLARE_DOMAIN="$CLOUDFLARE_DOMAIN"
EOF
            
            log "✅ Cloudflare Tunnel configurado"
        fi
    fi
    
    # Configurar ngrok
    if confirm "¿Desea configurar ngrok con token personalizado?"; then
        read_input "Token de ngrok" "" "NGROK_TOKEN"
        
        if [[ -n "$NGROK_TOKEN" ]]; then
            # Configurar ngrok con token
            ngrok authtoken "$NGROK_TOKEN"
            
            # Crear configuración personalizada
            mkdir -p "$HOME/.ngrok2"
            cat > "$HOME/.ngrok2/ngrok.yml" << EOF
authtoken: $NGROK_TOKEN
version: "2"
tunnels:
  webmin:
    proto: http
    addr: 10000
    bind_tls: true
  usermin:
    proto: http
    addr: 20000
    bind_tls: true
  web:
    proto: http
    addr: 80
    bind_tls: true
  web-ssl:
    proto: http
    addr: 443
    bind_tls: true
EOF
            
            cat >> "$CONFIG_FILE" << EOF

# Configuración de ngrok
NGROK_TOKEN="$NGROK_TOKEN"
EOF
            
            log "✅ ngrok configurado"
        fi
    fi
    
    echo
}

# Configurar optimizaciones de rendimiento
configurar_optimizaciones() {
    echo -e "${CYAN}⚡ CONFIGURACIÓN DE OPTIMIZACIONES${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo
    
    # Configurar límites de recursos
    if confirm "¿Desea configurar límites de recursos personalizados?"; then
        read_input "Límite de CPU para alertas (%)" "80" "CPU_ALERT_THRESHOLD"
        read_input "Límite de memoria para alertas (%)" "85" "MEMORY_ALERT_THRESHOLD"
        read_input "Límite de disco para alertas (%)" "90" "DISK_ALERT_THRESHOLD"
        read_input "Intervalo de monitoreo (segundos)" "30" "MONITOR_INTERVAL"
        
        cat >> "$CONFIG_FILE" << EOF

# Configuración de Rendimiento
CPU_ALERT_THRESHOLD="$CPU_ALERT_THRESHOLD"
MEMORY_ALERT_THRESHOLD="$MEMORY_ALERT_THRESHOLD"
DISK_ALERT_THRESHOLD="$DISK_ALERT_THRESHOLD"
MONITOR_INTERVAL="$MONITOR_INTERVAL"
EOF
        
        log "✅ Límites de recursos configurados"
    fi
    
    # Configurar optimizaciones de red
    if confirm "¿Desea aplicar optimizaciones de red avanzadas?"; then
        log_info "Aplicando optimizaciones de red..."
        
        # Optimizaciones adicionales de TCP
        cat >> /etc/sysctl.d/99-tunnel-optimizations.conf << EOF

# Optimizaciones adicionales personalizadas
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.core.default_qdisc = fq
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_low_latency = 1
EOF
        
        sysctl -p /etc/sysctl.d/99-tunnel-optimizations.conf
        
        log "✅ Optimizaciones de red aplicadas"
    fi
    
    # Configurar compresión de logs
    if confirm "¿Desea habilitar compresión avanzada de logs?"; then
        # Configurar logrotate con compresión mejorada
        cat > /etc/logrotate.d/auto-tunnel-advanced << EOF
$LOG_BASE_DIR/*.log {
    daily
    missingok
    rotate 60
    compress
    delaycompress
    notifempty
    create 644 root root
    compresscmd /usr/bin/xz
    compressext .xz
    compressoptions -9
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF
        
        log "✅ Compresión avanzada de logs configurada"
    fi
    
    echo
}

# Configurar seguridad personalizada
configurar_seguridad() {
    echo -e "${CYAN}🔒 CONFIGURACIÓN DE SEGURIDAD PERSONALIZADA${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo
    
    # Configurar whitelist de IPs
    if confirm "¿Desea configurar una whitelist de IPs confiables?"; then
        echo "Ingrese las IPs confiables (una por línea, línea vacía para terminar):"
        local whitelist_file="$CONFIG_BASE_DIR/security/whitelist.txt"
        > "$whitelist_file"  # Limpiar archivo
        
        while true; do
            read -r ip
            if [[ -z "$ip" ]]; then
                break
            fi
            
            # Validar formato de IP
            if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$ ]]; then
                echo "$ip" >> "$whitelist_file"
                log_info "IP agregada: $ip"
            else
                log_warning "Formato de IP inválido: $ip"
            fi
        done
        
        # Aplicar whitelist al firewall
        if [[ -s "$whitelist_file" ]]; then
            log_info "Aplicando whitelist al firewall..."
            while read -r ip; do
                iptables -I INPUT 1 -s "$ip" -j ACCEPT
            done < "$whitelist_file"
            
            # Guardar reglas
            if command -v iptables-save >/dev/null 2>&1; then
                iptables-save > /etc/iptables/rules.v4
            fi
        fi
        
        log "✅ Whitelist de IPs configurada"
    fi
    
    # Configurar límites de conexión personalizados
    if confirm "¿Desea configurar límites de conexión personalizados?"; then
        read_input "Máximo de conexiones simultáneas por IP" "50" "MAX_CONN_PER_IP"
        read_input "Máximo de conexiones nuevas por minuto por IP" "20" "MAX_NEW_CONN_PER_MIN"
        read_input "Tiempo de ban temporal (minutos)" "60" "TEMP_BAN_TIME"
        
        cat >> "$CONFIG_FILE" << EOF

# Configuración de Seguridad
MAX_CONN_PER_IP="$MAX_CONN_PER_IP"
MAX_NEW_CONN_PER_MIN="$MAX_NEW_CONN_PER_MIN"
TEMP_BAN_TIME="$TEMP_BAN_TIME"
EOF
        
        # Aplicar reglas de iptables personalizadas
        log_info "Aplicando reglas de seguridad personalizadas..."
        
        # Límite de conexiones simultáneas
        iptables -A INPUT -p tcp --dport 10000 -m connlimit --connlimit-above "$MAX_CONN_PER_IP" -j DROP
        iptables -A INPUT -p tcp --dport 20000 -m connlimit --connlimit-above "$MAX_CONN_PER_IP" -j DROP
        
        # Límite de conexiones nuevas
        iptables -A INPUT -p tcp --dport 10000 -m recent --set --name webmin_limit
        iptables -A INPUT -p tcp --dport 10000 -m recent --update --seconds 60 --hitcount "$MAX_NEW_CONN_PER_MIN" --name webmin_limit -j DROP
        
        iptables -A INPUT -p tcp --dport 20000 -m recent --set --name usermin_limit
        iptables -A INPUT -p tcp --dport 20000 -m recent --update --seconds 60 --hitcount "$MAX_NEW_CONN_PER_MIN" --name usermin_limit -j DROP
        
        # Guardar reglas
        if command -v iptables-save >/dev/null 2>&1; then
            iptables-save > /etc/iptables/rules.v4
        fi
        
        log "✅ Límites de conexión personalizados aplicados"
    fi
    
    echo
}

# Configurar monitoreo personalizado
configurar_monitoreo() {
    echo -e "${CYAN}📊 CONFIGURACIÓN DE MONITOREO PERSONALIZADO${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo
    
    # Configurar servicios adicionales para monitorear
    if confirm "¿Desea agregar servicios adicionales para monitorear?"; then
        echo "Ingrese los nombres de servicios adicionales (uno por línea, línea vacía para terminar):"
        local services_file="$CONFIG_BASE_DIR/custom-services.txt"
        > "$services_file"  # Limpiar archivo
        
        while true; do
            read -r service
            if [[ -z "$service" ]]; then
                break
            fi
            
            # Verificar si el servicio existe
            if systemctl list-unit-files | grep -q "^$service.service"; then
                echo "$service" >> "$services_file"
                log_info "Servicio agregado: $service"
            else
                log_warning "Servicio no encontrado: $service"
            fi
        done
        
        log "✅ Servicios adicionales configurados"
    fi
    
    # Configurar URLs adicionales para monitorear
    if confirm "¿Desea agregar URLs adicionales para monitorear?"; then
        echo "Ingrese las URLs adicionales (una por línea, línea vacía para terminar):"
        local urls_file="$CONFIG_BASE_DIR/custom-urls.txt"
        > "$urls_file"  # Limpiar archivo
        
        while true; do
            read -r url
            if [[ -z "$url" ]]; then
                break
            fi
            
            # Validar formato de URL básico
            if [[ $url =~ ^https?:// ]]; then
                echo "$url" >> "$urls_file"
                log_info "URL agregada: $url"
            else
                log_warning "Formato de URL inválido: $url"
            fi
        done
        
        log "✅ URLs adicionales configuradas"
    fi
    
    # Configurar frecuencia de reportes
    if confirm "¿Desea personalizar la frecuencia de reportes?"; then
        echo "Seleccione la frecuencia de reportes diarios:"
        echo "1) Diario (6:00 AM)"
        echo "2) Cada 12 horas (6:00 AM y 6:00 PM)"
        echo "3) Cada 6 horas"
        echo "4) Personalizado"
        
        read -r freq_choice
        
        case "$freq_choice" in
            "1")
                REPORT_CRON="0 6 * * *"
                ;;
            "2")
                REPORT_CRON="0 6,18 * * *"
                ;;
            "3")
                REPORT_CRON="0 */6 * * *"
                ;;
            "4")
                read_input "Expresión cron personalizada" "0 6 * * *" "REPORT_CRON"
                ;;
            *)
                REPORT_CRON="0 6 * * *"
                ;;
        esac
        
        # Actualizar cron
        cat > /etc/cron.d/sistema-tunnel-monitoreo-custom << EOF
# Monitoreo personalizado del sistema de túneles
*/5 * * * * root /usr/local/bin/sistema-monitoreo-integral.sh monitor
$REPORT_CRON root /usr/local/bin/sistema-monitoreo-integral.sh reporte
EOF
        
        cat >> "$CONFIG_FILE" << EOF

# Configuración de Monitoreo
REPORT_CRON="$REPORT_CRON"
EOF
        
        log "✅ Frecuencia de reportes personalizada configurada"
    fi
    
    echo
}

# Aplicar configuración
aplicar_configuracion() {
    echo -e "${CYAN}🔧 APLICANDO CONFIGURACIÓN${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo
    
    log_info "Aplicando configuración personalizada..."
    
    # Cargar configuración en variables de entorno del sistema
    if [[ -f "$CONFIG_FILE" ]]; then
        # Crear archivo de variables de entorno
        cat > /etc/environment.d/auto-tunnel.conf << EOF
# Variables de entorno del sistema de túneles
$(grep -v '^#' "$CONFIG_FILE" | grep '=')
EOF
        
        # Cargar en el perfil del sistema
        cat > /etc/profile.d/auto-tunnel-env.sh << EOF
#!/bin/bash
# Variables de entorno del sistema de túneles
$(grep -v '^#' "$CONFIG_FILE" | grep '=')
export $(grep -v '^#' "$CONFIG_FILE" | grep '=' | cut -d= -f1 | tr '\n' ' ')
EOF
        
        chmod +x /etc/profile.d/auto-tunnel-env.sh
        
        log "✅ Variables de entorno configuradas"
    fi
    
    # Reiniciar servicios para aplicar cambios
    log_info "Reiniciando servicios..."
    
    local servicios=("ha-tunnel-monitor" "auto-tunnel-manager-v2" "attack-monitor")
    for servicio in "${servicios[@]}"; do
        if systemctl list-unit-files | grep -q "^$servicio.service"; then
            systemctl restart "$servicio" && \
                log_info "✅ $servicio reiniciado" || \
                log_warning "⚠️ Error al reiniciar $servicio"
        fi
    done
    
    # Recargar configuración de cron
    systemctl reload cron 2>/dev/null || systemctl reload crond 2>/dev/null || true
    
    log "✅ Configuración aplicada correctamente"
    echo
}

# Mostrar resumen de configuración
mostrar_resumen() {
    echo -e "${GREEN}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "🎉 CONFIGURACIÓN PERSONALIZADA COMPLETADA 🎉"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    echo
    
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "${BOLD}📋 CONFIGURACIÓN APLICADA:${NC}"
        echo
        
        # Mostrar configuración de forma legible
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ ]] && continue
            [[ -z "$key" ]] && continue
            
            # Ocultar valores sensibles
            if [[ "$key" =~ (TOKEN|PASS|SECRET) ]]; then
                value="***OCULTO***"
            fi
            
            echo -e "   ${CYAN}$key${NC}: $value"
        done < "$CONFIG_FILE"
        
        echo
    fi
    
    echo -e "${YELLOW}🔧 COMANDOS ÚTILES:${NC}"
    echo "   • tunnel-admin status      # Ver estado del sistema"
    echo "   • tunnel-admin diagnostics # Ejecutar diagnósticos"
    echo "   • source /etc/profile.d/auto-tunnel-env.sh  # Cargar variables"
    echo
    
    echo -e "${YELLOW}📁 ARCHIVOS DE CONFIGURACIÓN:${NC}"
    echo "   • Configuración personalizada: $CONFIG_FILE"
    echo "   • Variables de entorno: /etc/profile.d/auto-tunnel-env.sh"
    echo "   • Documentación: $CONFIG_BASE_DIR/README.md"
    echo
    
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}🎯 La configuración personalizada está lista y aplicada.${NC}"
    echo -e "${BOLD}🔄 Los servicios han sido reiniciados con la nueva configuración.${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo
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
    
    # Mostrar banner
    mostrar_banner
    
    # Crear archivo de configuración
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" << EOF
# Configuración personalizada del sistema de túneles
# Generado el $(date +'%Y-%m-%d %H:%M:%S')
EOF
    
    # Ejecutar configuraciones
    configurar_email
    configurar_webhooks
    configurar_tunnels
    configurar_optimizaciones
    configurar_seguridad
    configurar_monitoreo
    
    # Aplicar configuración
    aplicar_configuracion
    
    # Mostrar resumen
    mostrar_resumen
    
    log "🎉 Configuración personalizada completada exitosamente"
}

# Ejecutar función principal
main "$@"

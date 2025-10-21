#!/bin/bash

# Script de configuración avanzada de firewall para Virtualmin Enterprise
# Este script configura iptables/ufw con reglas de seguridad personalizadas

set -e

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de configuración
LOG_FILE="/var/log/virtualmin-enterprise-firewall.log"
CONFIG_DIR="/opt/virtualmin-enterprise/config/firewall"
RULES_FILE="$CONFIG_DIR/firewall-rules.sh"

# Puertos permitidos
ALLOWED_TCP_PORTS="22,80,443,10000"  # SSH, HTTP, HTTPS, Webmin
ALLOWED_UDP_PORTS="53,123"  # DNS, NTP

# Función para imprimir mensajes con colores
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Función para registrar mensajes en el log
log_message() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Función para verificar si el script se ejecuta como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_message $RED "Este script debe ejecutarse como root" >&2
        exit 1
    fi
}

# Función para crear directorios necesarios
create_directories() {
    print_message $BLUE "Creando directorios necesarios..."
    log_message "Creando directorios necesarios"
    
    mkdir -p "$CONFIG_DIR"
    
    print_message $GREEN "Directorios creados exitosamente"
    log_message "Directorios creados exitosamente"
}

# Función para configurar firewall con ufw (Ubuntu/Debian)
configure_ufw() {
    print_message $BLUE "Configurando firewall con ufw..."
    log_message "Configurando firewall con ufw"
    
    # Resetear reglas existentes
    ufw --force reset >> "$LOG_FILE" 2>&1
    
    # Configurar políticas por defecto
    ufw default deny incoming >> "$LOG_FILE" 2>&1
    ufw default allow outgoing >> "$LOG_FILE" 2>&1
    
    # Permitir conexiones locales
    ufw allow from 127.0.0.1 >> "$LOG_FILE" 2>&1
    
    # Permitir puertos TCP específicos
    IFS=',' read -ra PORTS <<< "$ALLOWED_TCP_PORTS"
    for port in "${PORTS[@]}"; do
        ufw allow "$port"/tcp >> "$LOG_FILE" 2>&1
        log_message "Puerto TCP $port permitido"
    done
    
    # Permitir puertos UDP específicos
    IFS=',' read -ra PORTS <<< "$ALLOWED_UDP_PORTS"
    for port in "${PORTS[@]}"; do
        ufw allow "$port"/udp >> "$LOG_FILE" 2>&1
        log_message "Puerto UDP $port permitido"
    done
    
    # Habilitar firewall
    ufw --force enable >> "$LOG_FILE" 2>&1
    
    print_message $GREEN "Firewall ufw configurado exitosamente"
    log_message "Firewall ufw configurado exitosamente"
}

# Función para configurar firewall con iptables
configure_iptables() {
    print_message $BLUE "Configurando firewall con iptables..."
    log_message "Configurando firewall con iptables"
    
    # Crear script de reglas de iptables
    cat > "$RULES_FILE" << 'EOF'
#!/bin/bash

# Script de reglas de iptables para Virtualmin Enterprise

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

# Permitir tráfico local
iptables -A INPUT -i lo -j ACCEPT

# Permitir conexiones establecidas y relacionadas
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Permitir ICMP (ping)
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# Permitir puertos TCP específicos
EOF
    
    # Añadir reglas para puertos TCP
    IFS=',' read -ra PORTS <<< "$ALLOWED_TCP_PORTS"
    for port in "${PORTS[@]}"; do
        echo "iptables -A INPUT -p tcp --dport $port -j ACCEPT" >> "$RULES_FILE"
        log_message "Regla añadida para puerto TCP $port"
    done
    
    # Añadir reglas para puertos UDP
    IFS=',' read -ra PORTS <<< "$ALLOWED_UDP_PORTS"
    for port in "${PORTS[@]}"; do
        echo "iptables -A INPUT -p udp --dport $port -j ACCEPT" >> "$RULES_FILE"
        log_message "Regla añadida para puerto UDP $port"
    done
    
    # Añadir protección contra ataques comunes
    cat >> "$RULES_FILE" << 'EOF'

# Protección contra ataques de syn-flood
iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT

# Protección contra escaneo de puertos
iptables -A INPUT -m recent --name portscan --rcheck --seconds 86400 -j DROP
iptables -A INPUT -m recent --name portscan --set -j LOG --log-prefix "Portscan:"
iptables -A INPUT -m recent --name portscan --set -j DROP

# Protección contra ataques de fuerza bruta SSH
iptables -A INPUT -p tcp --dport 22 -m recent --name ssh_brute --rcheck --seconds 60 --hitcount 4 -j DROP
iptables -A INPUT -p tcp --dport 22 -m recent --name ssh_brute --set

# Protección contra ataques de inundación de ping
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 1 -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

# Registrar paquetes descartados
iptables -A INPUT -j LOG --log-prefix "INPUT-DROPPED: " --log-level 4
iptables -A FORWARD -j LOG --log-prefix "FORWARD-DROPPED: " --log-level 4

EOF
    
    # Hacer ejecutable el script
    chmod +x "$RULES_FILE"
    
    # Ejecutar script de reglas
    bash "$RULES_FILE" >> "$LOG_FILE" 2>&1
    
    # Guardar reglas para que persistan después del reinicio
    if command -v iptables-save &> /dev/null; then
        if [ -d /etc/iptables ]; then
            iptables-save > /etc/iptables/rules.v4
        else
            mkdir -p /etc/iptables
            iptables-save > /etc/iptables/rules.v4
        fi
    fi
    
    print_message $GREEN "Firewall iptables configurado exitosamente"
    log_message "Firewall iptables configurado exitosamente"
}

# Función para configurar firewall con firewalld (RHEL/CentOS)
configure_firewalld() {
    print_message $BLUE "Configurando firewall con firewalld..."
    log_message "Configurando firewall con firewalld"
    
    # Iniciar y habilitar firewalld
    systemctl start firewalld >> "$LOG_FILE" 2>&1
    systemctl enable firewalld >> "$LOG_FILE" 2>&1
    
    # Configurar zona por defecto
    firewall-cmd --set-default-zone=public >> "$LOG_FILE" 2>&1
    
    # Permitir puertos TCP específicos
    IFS=',' read -ra PORTS <<< "$ALLOWED_TCP_PORTS"
    for port in "${PORTS[@]}"; do
        firewall-cmd --permanent --add-port="$port"/tcp >> "$LOG_FILE" 2>&1
        log_message "Puerto TCP $port permitido"
    done
    
    # Permitir puertos UDP específicos
    IFS=',' read -ra PORTS <<< "$ALLOWED_UDP_PORTS"
    for port in "${PORTS[@]}"; do
        firewall-cmd --permanent --add-port="$port"/udp >> "$LOG_FILE" 2>&1
        log_message "Puerto UDP $port permitido"
    done
    
    # Recargar firewall
    firewall-cmd --reload >> "$LOG_FILE" 2>&1
    
    print_message $GREEN "Firewall firewalld configurado exitosamente"
    log_message "Firewall firewalld configurado exitosamente"
}

# Función para configurar reglas de seguridad adicionales
configure_security_rules() {
    print_message $BLUE "Configurando reglas de seguridad adicionales..."
    log_message "Configurando reglas de seguridad adicionales"
    
    # Crear script de reglas de seguridad adicionales
    cat > "$CONFIG_DIR/security-rules.sh" << 'EOF'
#!/bin/bash

# Reglas de seguridad adicionales para Virtualmin Enterprise

# Función para bloquear dirección IP
block_ip() {
    local ip=$1
    local reason=$2
    
    if command -v ufw &> /dev/null; then
        ufw deny from "$ip" comment "$reason"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$ip' reject"
        firewall-cmd --reload
    else
        iptables -A INPUT -s "$ip" -j DROP
        iptables-save > /etc/iptables/rules.v4
    fi
    
    echo "IP $ip bloqueada: $reason"
}

# Función para permitir dirección IP
allow_ip() {
    local ip=$1
    local reason=$2
    
    if command -v ufw &> /dev/null; then
        ufw allow from "$ip" comment "$reason"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$ip' accept"
        firewall-cmd --reload
    else
        iptables -A INPUT -s "$ip" -j ACCEPT
        iptables-save > /etc/iptables/rules.v4
    fi
    
    echo "IP $ip permitida: $reason"
}

# Función para listar IPs bloqueadas
list_blocked_ips() {
    if command -v ufw &> /dev/null; then
        ufw status numbered | grep DENY
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --list-all | grep reject
    else
        iptables -L INPUT -n | grep DROP
    fi
}

# Función para desbloquear dirección IP
unblock_ip() {
    local ip=$1
    
    if command -v ufw &> /dev/null; then
        ufw delete deny from "$ip"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --remove-rich-rule="rule family='ipv4' source address='$ip' reject"
        firewall-cmd --reload
    else
        iptables -D INPUT -s "$ip" -j DROP
        iptables-save > /etc/iptables/rules.v4
    fi
    
    echo "IP $ip desbloqueada"
}

# Función para configurar protección contra ataques DDoS
configure_ddos_protection() {
    echo "Configurando protección contra ataques DDoS..."
    
    # Limitar conexiones SSH
    if command -v ufw &> /dev/null; then
        ufw limit ssh/tcp
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-rich-rule="rule service name='ssh' limit value='4/m' accept"
        firewall-cmd --reload
    else
        iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set
        iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 30 --hitcount 4 -j DROP
        iptables-save > /etc/iptables/rules.v4
    fi
    
    echo "Protección contra ataques DDoS configurada"
}

# Función para configurar protección contra escaneo de puertos
configure_portscan_protection() {
    echo "Configurando protección contra escaneo de puertos..."
    
    if command -v ufw &> /dev/null; then
        # ufw ya tiene protección básica contra escaneo de puertos
        echo "Protección contra escaneo de puertos ya configurada con ufw"
    elif command -v firewall-cmd &> /dev/null; then
        # firewalld ya tiene protección básica contra escaneo de puertos
        echo "Protección contra escaneo de puertos ya configurada con firewalld"
    else
        # Configurar protección con iptables
        iptables -N port-scanning
        iptables -A port-scanning -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/s --limit-burst 2 -j RETURN
        iptables -A port-scanning -j DROP
        iptables -A INPUT -p tcp -j port-scanning
        iptables-save > /etc/iptables/rules.v4
    fi
    
    echo "Protección contra escaneo de puertos configurada"
}

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [OPCIÓN] [ARGUMENTOS]"
    echo ""
    echo "Opciones:"
    echo "  block_ip <IP> <RAZÓN>     Bloquear dirección IP"
    echo "  allow_ip <IP> <RAZÓN>     Permitir dirección IP"
    echo "  unblock_ip <IP>           Desbloquear dirección IP"
    echo "  list_blocked_ips          Listar IPs bloqueadas"
    echo "  configure_ddos_protection Configurar protección contra DDoS"
    echo "  configure_portscan_protection  Configurar protección contra escaneo de puertos"
    echo "  show_help                 Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 block_ip 192.168.1.100 'Ataque de fuerza bruta'"
    echo "  $0 allow_ip 192.168.1.200 'IP de administrador'"
    echo "  $0 unblock_ip 192.168.1.100"
    echo "  $0 list_blocked_ips"
    echo "  $0 configure_ddos_protection"
    echo "  $0 configure_portscan_protection"
}

# Procesar argumentos
case "$1" in
    "block_ip")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Error: Se requieren IP y razón"
            show_help
            exit 1
        fi
        block_ip "$2" "$3"
        ;;
    "allow_ip")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Error: Se requieren IP y razón"
            show_help
            exit 1
        fi
        allow_ip "$2" "$3"
        ;;
    "unblock_ip")
        if [ -z "$2" ]; then
            echo "Error: Se requiere IP"
            show_help
            exit 1
        fi
        unblock_ip "$2"
        ;;
    "list_blocked_ips")
        list_blocked_ips
        ;;
    "configure_ddos_protection")
        configure_ddos_protection
        ;;
    "configure_portscan_protection")
        configure_portscan_protection
        ;;
    "show_help"|*)
        show_help
        ;;
esac
EOF
    
    # Hacer ejecutable el script
    chmod +x "$CONFIG_DIR/security-rules.sh"
    
    # Configurar protección contra ataques DDoS
    bash "$CONFIG_DIR/security-rules.sh" configure_ddos_protection >> "$LOG_FILE" 2>&1
    
    # Configurar protección contra escaneo de puertos
    bash "$CONFIG_DIR/security-rules.sh" configure_portscan_protection >> "$LOG_FILE" 2>&1
    
    print_message $GREEN "Reglas de seguridad adicionales configuradas"
    log_message "Reglas de seguridad adicionales configuradas"
}

# Función para configurar monitoreo de firewall
configure_firewall_monitoring() {
    print_message $BLUE "Configurando monitoreo de firewall..."
    log_message "Configurando monitoreo de firewall"
    
    # Crear script de monitoreo
    cat > "$CONFIG_DIR/monitor-firewall.sh" << 'EOF'
#!/bin/bash

# Script de monitoreo de firewall para Virtualmin Enterprise

LOG_FILE="/var/log/virtualmin-enterprise-firewall-monitor.log"
ALERT_THRESHOLD=100  # Umbral de alerta de paquetes descartados

# Función para registrar mensajes
log_message() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Función para obtener estadísticas de firewall
get_firewall_stats() {
    if command -v ufw &> /dev/null; then
        # Obtener estadísticas de ufw
        ufw status verbose | grep -E "( packets| bytes)"
    elif command -v firewall-cmd &> /dev/null; then
        # Obtener estadísticas de firewalld
        firewall-cmd --get-all-zones
    else
        # Obtener estadísticas de iptables
        iptables -L -n -v | head -20
    fi
}

# Función para verificar intentos de conexión bloqueados
check_blocked_attempts() {
    local blocked_count=0
    
    # Verificar logs de firewall
    if [ -f /var/log/ufw.log ]; then
        blocked_count=$(grep "UFW BLOCK" /var/log/ufw.log | wc -l)
    elif [ -f /var/log/messages ]; then
        blocked_count=$(grep "INPUT-DROPPED" /var/log/messages | wc -l)
    elif [ -f /var/log/kern.log ]; then
        blocked_count=$(grep "INPUT-DROPPED" /var/log/kern.log | wc -l)
    fi
    
    echo "$blocked_count"
}

# Función para generar informe de firewall
generate_firewall_report() {
    local report_file="/opt/virtualmin-enterprise/backups/firewall-report-$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
Informe de Firewall de Virtualmin Enterprise
============================================
Fecha: $(date)
Servidor: $(hostname)
IP: $(hostname -I | awk '{print $1}')

Estadísticas de Firewall:
EOF
    
    # Añadir estadísticas de firewall
    get_firewall_stats >> "$report_file"
    
    echo "" >> "$report_file"
    echo "Intentos de conexión bloqueados:" >> "$report_file"
    echo "$(check_blocked_attempts)" >> "$report_file"
    
    # Añadir top 10 IPs bloqueadas
    echo "" >> "$report_file"
    echo "Top 10 IPs bloqueadas:" >> "$report_file"
    
    if [ -f /var/log/ufw.log ]; then
        grep "UFW BLOCK" /var/log/ufw.log | awk '{print $8}' | sort | uniq -c | sort -nr | head -10 >> "$report_file"
    elif [ -f /var/log/messages ]; then
        grep "INPUT-DROPPED" /var/log/messages | awk '{print $9}' | sort | uniq -c | sort -nr | head -10 >> "$report_file"
    fi
    
    log_message "Informe de firewall generado: $report_file"
}

# Función principal
main() {
    log_message "Iniciando monitoreo de firewall"
    
    # Obtener estadísticas de firewall
    log_message "Estadísticas de firewall:"
    get_firewall_stats >> "$LOG_FILE" 2>&1
    
    # Verificar intentos de conexión bloqueados
    local blocked_count=$(check_blocked_attempts)
    log_message "Intentos de conexión bloqueados: $blocked_count"
    
    # Generar alerta si supera el umbral
    if [ "$blocked_count" -gt "$ALERT_THRESHOLD" ]; then
        log_message "ALERTA: Alto número de intentos de conexión bloqueados: $blocked_count"
        # Aquí se puede agregar código para enviar alerta por email, Telegram, etc.
    fi
    
    # Generar informe de firewall
    generate_firewall_report
    
    log_message "Monitoreo de firewall completado"
}

# Ejecutar función principal
main "$@"
EOF
    
    # Hacer ejecutable el script
    chmod +x "$CONFIG_DIR/monitor-firewall.sh"
    
    # Configurar tarea cron para monitoreo diario
    local cron_entry="0 6 * * * $CONFIG_DIR/monitor-firewall.sh >> $LOG_FILE 2>&1"
    
    # Verificar si la tarea ya existe
    if ! crontab -l 2>/dev/null | grep -q "monitor-firewall.sh"; then
        # Agregar tarea cron
        (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
        log_message "Tarea cron configurada para monitoreo diario de firewall"
    fi
    
    print_message $GREEN "Monitoreo de firewall configurado"
    log_message "Monitoreo de firewall configurado"
}

# Función principal
main() {
    print_message $GREEN "Iniciando configuración avanzada de firewall..."
    log_message "Iniciando configuración avanzada de firewall"
    
    check_root
    create_directories
    
    # Determinar qué sistema de firewall está disponible
    if command -v ufw &> /dev/null; then
        configure_ufw
    elif command -v firewall-cmd &> /dev/null; then
        configure_firewalld
    else
        configure_iptables
    fi
    
    # Configurar reglas de seguridad adicionales
    configure_security_rules
    
    # Configurar monitoreo de firewall
    configure_firewall_monitoring
    
    print_message $GREEN "Configuración avanzada de firewall completada"
    log_message "Configuración avanzada de firewall completada"
    
    print_message $BLUE "Scripts de gestión de firewall:"
    print_message $BLUE "- Reglas de seguridad: $CONFIG_DIR/security-rules.sh"
    print_message $BLUE "- Monitoreo: $CONFIG_DIR/monitor-firewall.sh"
    print_message $YELLOW "Ejecute '$CONFIG_DIR/security-rules.sh show_help' para ver las opciones disponibles"
}

# Ejecutar función principal
main "$@"
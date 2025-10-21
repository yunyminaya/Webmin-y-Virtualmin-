#!/bin/bash

# Script de instalación y configuración de Snort IDS/IPS para Virtualmin Enterprise
# Este script instala y configura Snort con reglas de detección

set -e

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de configuración
SNORT_VERSION="2.9.17"
DAQ_VERSION="2.0.7"
INSTALL_DIR="/opt/virtualmin-enterprise"
LOG_FILE="/var/log/virtualmin-enterprise-snort.log"
SNORT_DIR="/etc/snort"
SNORT_RULES_DIR="/etc/snort/rules"
SNORT_LOG_DIR="/var/log/snort"

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

# Función para detectar distribución del sistema operativo
detect_distribution() {
    if [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "redhat"
    else
        echo "unknown"
    fi
}

# Función para instalar dependencias
install_dependencies() {
    log_message "Instalando dependencias"
    
    local distribution=$(detect_distribution)
    
    case $distribution in
        "debian")
            apt-get update
            apt-get install -y \
                build-essential \
                libpcap-dev \
                libpcre3-dev \
                libdumbnet-dev \
                zlib1g-dev \
                libdaq-dev \
                bison \
                flex \
                wget \
                git \
                unzip \
                libnghttp2-dev \
                libssl-dev \
                pkg-config \
                autotools-dev \
                autoconf \
                automake \
                libtool \
                libluajit-5.1-dev \
                libpcap0.8-dev \
                libnl-3-dev \
                libnl-genl-3-dev \
                libnetfilter-queue-dev \
                libmnl-dev
            ;;
        "redhat")
            yum update -y
            yum groupinstall -y "Development Tools"
            yum install -y \
                libpcap-devel \
                pcre-devel \
                libdnet-devel \
                zlib-devel \
                daq-devel \
                bison \
                flex \
                wget \
                git \
                unzip \
                nghttp2-devel \
                openssl-devel \
                pkgconfig \
                autoconf \
                automake \
                libtool \
                luajit-devel \
                libnl3-devel \
                libnetfilter_queue-devel \
                libmnl-devel
            ;;
        *)
            print_message $RED "Distribución no soportada"
            exit 1
            ;;
    esac
    
    log_message "Dependencias instaladas"
}

# Función para instalar DAQ
install_daq() {
    log_message "Instalando DAQ"
    
    # Descargar DAQ
    cd /tmp
    wget -q "https://www.snort.org/downloads/snort/daq-$DAQ_VERSION.tar.gz"
    tar -xzf "daq-$DAQ_VERSION.tar.gz"
    cd "daq-$DAQ_VERSION"
    
    # Compilar e instalar DAQ
    ./bootstrap >> "$LOG_FILE" 2>&1
    ./configure --prefix=/usr >> "$LOG_FILE" 2>&1
    make >> "$LOG_FILE" 2>&1
    make install >> "$LOG_FILE" 2>&1
    
    # Limpiar archivos temporales
    cd /
    rm -rf "/tmp/daq-$DAQ_VERSION" "/tmp/daq-$DAQ_VERSION.tar.gz"
    
    log_message "DAQ instalado"
}

# Función para instalar Snort
install_snort() {
    log_message "Instalando Snort"
    
    # Descargar Snort
    cd /tmp
    wget -q "https://www.snort.org/downloads/snort/snort-$SNORT_VERSION.tar.gz"
    tar -xzf "snort-$SNORT_VERSION.tar.gz"
    cd "snort-$SNORT_VERSION"
    
    # Compilar e instalar Snort
    ./configure --prefix=/usr --enable-sourcefire >> "$LOG_FILE" 2>&1
    make >> "$LOG_FILE" 2>&1
    make install >> "$LOG_FILE" 2>&1
    
    # Limpiar archivos temporales
    cd /
    rm -rf "/tmp/snort-$SNORT_VERSION" "/tmp/snort-$SNORT_VERSION.tar.gz"
    
    log_message "Snort instalado"
}

# Función para configurar Snort
configure_snort() {
    log_message "Configurando Snort"
    
    # Crear directorios necesarios
    mkdir -p "$SNORT_DIR"
    mkdir -p "$SNORT_RULES_DIR"
    mkdir -p "$SNORT_LOG_DIR"
    mkdir -p "$SNORT_DIR/lib"
    mkdir -p "$SNORT_DIR/dynamic_preproc"
    mkdir -p "$SNORT_DIR/dynamicrules"
    
    # Crear usuario y grupo snort
    if ! id -u snort &>/dev/null; then
        useradd -r -s /sbin/nologin snort >> "$LOG_FILE" 2>&1
    fi
    
    # Descargar configuración de Snort
    cd /tmp
    wget -q "https://www.snort.org/downloads/snort/snort.conf.tar.gz"
    tar -xzf "snort.conf.tar.gz"
    
    # Copiar archivos de configuración
    cp etc/*.conf "$SNORT_DIR/"
    cp etc/*.map "$SNORT_DIR/"
    cp etc/*.dtd "$SNORT_DIR/"
    
    # Modificar configuración de Snort
    sed -i "s|HOME_NET any|HOME_NET $(hostname -I | awk '{print $1}')/24|" "$SNORT_DIR/snort.conf"
    sed -i "s|EXTERNAL_NET any|EXTERNAL_NET !\$HOME_NET|" "$SNORT_DIR/snort.conf"
    sed -i "s|RULE_PATH ../rules|RULE_PATH $SNORT_RULES_DIR|" "$SNORT_DIR/snort.conf"
    sed -i "s|SO_RULE_PATH ../so_rules|SO_RULE_PATH $SNORT_DIR/so_rules|" "$SNORT_DIR/snort.conf"
    sed -i "s|PREPROC_RULE_PATH ../preproc_rules|PREPROC_RULE_PATH $SNORT_DIR/preproc_rules|" "$SNORT_DIR/snort.conf"
    sed -i "s|WHITE_LIST_PATH ../lists|WHITE_LIST_PATH $SNORT_DIR/lists|" "$SNORT_DIR/snort.conf"
    sed -i "s|BLACK_LIST_PATH ../lists|BLACK_LIST_PATH $SNORT_DIR/lists|" "$SNORT_DIR/snort.conf"
    
    # Configurar directorio de logs
    sed -i "s|logdir /var/log/snort|logdir $SNORT_LOG_DIR|" "$SNORT_DIR/snort.conf"
    
    # Habilitar reglas de detección
    sed -i 's|# include $RULE_PATH|# include $RULE_PATH|' "$SNORT_DIR/snort.conf"
    
    # Cambiar permisos
    chown -R snort:snort "$SNORT_DIR"
    chown -R snort:snort "$SNORT_LOG_DIR"
    
    # Limpiar archivos temporales
    rm -rf /tmp/etc /tmp/snort.conf.tar.gz
    
    log_message "Snort configurado"
}

# Función para descargar e instalar reglas de Snort
install_snort_rules() {
    log_message "Instalando reglas de Snort"
    
    # Descargar reglas comunitarias
    cd /tmp
    wget -q "https://www.snort.org/downloads/community/community-rules.tar.gz"
    tar -xzf "community-rules.tar.gz"
    
    # Copiar reglas
    cp -r rules/* "$SNORT_RULES_DIR/"
    
    # Descargar reglas locales
    cat > "$SNORT_RULES_DIR/local.rules" << 'EOF'
# Reglas locales para Virtualmin Enterprise

# Alerta sobre intentos de acceso a Webmin desde IPs no autorizadas
alert tcp any any -> $HOME_NET 10000 (msg:"WEBMIN Access from External IP"; flow:to_server,established; sid:1000001; rev:1;)

# Alerta sobre intentos de acceso SSH con demasiados fallos
alert tcp any any -> $HOME_NET 22 (msg:"SSH Brute Force Attempt"; flags:S; threshold:type both, track by_src, count 5, seconds 60; sid:1000002; rev:1;)

# Alerta sobre escaneo de puertos
alert ip any any -> $HOME_NET any (msg:"Port Scan Detected"; ip_proto:tcp; flags:S; threshold:type both, track by_src, count 20, seconds 10; sid:1000003; rev:1;)

# Alerta sobre ataques de inyección SQL
alert tcp any any -> $HOME_NET 80 (msg:"SQL Injection Attempt"; content:"UNION"; nocase; sid:1000004; rev:1;)

# Alerta sobre ataques XSS
alert tcp any any -> $HOME_NET 80 (msg:"XSS Attempt"; content:"<script>"; nocase; sid:1000005; rev:1;)

# Alerta sobre solicitudes sospechosas a Virtualmin
alert tcp any any -> $HOME_NET 10000 (msg:"Virtualmin Suspicious Request"; content:"passwd"; nocase; sid:1000006; rev:1;)
EOF
    
    # Cambiar permisos
    chown -R snort:snort "$SNORT_RULES_DIR"
    
    # Limpiar archivos temporales
    rm -rf /tmp/rules /tmp/community-rules.tar.gz
    
    log_message "Reglas de Snort instaladas"
}

# Función para configurar Snort como IDS
configure_snort_ids() {
    log_message "Configurando Snort como IDS"
    
    # Crear servicio systemd para Snort en modo IDS
    cat > "/etc/systemd/system/snort-ids.service" << EOF
[Unit]
Description=Snort Intrusion Detection System
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/snort -c $SNORT_DIR/snort.conf -i $(ip route | grep default | awk '{print $5}') -D
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
User=snort
Group=snort

[Install]
WantedBy=multi-user.target
EOF
    
    # Habilitar y iniciar servicio
    systemctl daemon-reload >> "$LOG_FILE" 2>&1
    systemctl enable snort-ids >> "$LOG_FILE" 2>&1
    systemctl start snort-ids >> "$LOG_FILE" 2>&1
    
    log_message "Snort configurado como IDS"
    print_message $GREEN "Snort configurado como IDS"
}

# Función para configurar Snort como IPS
configure_snort_ips() {
    log_message "Configurando Snort como IPS"
    
    # Habilitar modo inline en configuración de Snort
    sed -i 's|# config policy_mode: config|config policy_mode: inline|' "$SNORT_DIR/snort.conf"
    
    # Crear servicio systemd para Snort en modo IPS
    cat > "/etc/systemd/system/snort-ips.service" << EOF
[Unit]
Description=Snort Intrusion Prevention System
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/snort -c $SNORT_DIR/snort.conf -Q --daq nfq -i $(ip route | grep default | awk '{print $5}') -D
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
User=snort
Group=snort

[Install]
WantedBy=multi-user.target
EOF
    
    # Habilitar servicio
    systemctl daemon-reload >> "$LOG_FILE" 2>&1
    systemctl enable snort-ips >> "$LOG_FILE" 2>&1
    
    log_message "Snort configurado como IPS"
    print_message $GREEN "Snort configurado como IPS"
    print_message $YELLOW "IMPORTANTE: Para activar el modo IPS, ejecute: systemctl start snort-ips"
}

# Función para crear script de gestión de Snort
create_management_script() {
    log_message "Creando script de gestión de Snort"
    
    cat > "$INSTALL_DIR/scripts/manage_snort.sh" << 'EOF'
#!/bin/bash

# Script de gestión de Snort IDS/IPS para Virtualmin Enterprise

SNORT_DIR="/etc/snort"
SNORT_LOG_DIR="/var/log/snort"
LOG_FILE="/var/log/virtualmin-enterprise-snort.log"

# Función para registrar mensajes
log_message() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Función para verificar estado de Snort
check_status() {
    echo "Verificando estado de Snort..."
    
    # Verificar servicios
    if systemctl is-active --quiet snort-ids; then
        echo "✓ Snort IDS está activo"
    else
        echo "✗ Snort IDS no está activo"
    fi
    
    if systemctl is-active --quiet snort-ips; then
        echo "✓ Snort IPS está activo"
    else
        echo "✗ Snort IPS no está activo"
    fi
    
    # Verificar proceso
    if pgrep -x snort > /dev/null; then
        echo "✓ Proceso de Snort está ejecutándose"
    else
        echo "✗ Proceso de Snort no está ejecutándose"
    fi
    
    # Verificar configuración
    if snort -T -c "$SNORT_DIR/snort.conf" >> "$LOG_FILE" 2>&1; then
        echo "✓ Configuración de Snort es válida"
    else
        echo "✗ Configuración de Snort tiene errores"
    fi
}

# Función para iniciar Snort IDS
start_ids() {
    echo "Iniciando Snort IDS..."
    
    systemctl start snort-ids >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        echo "Snort IDS iniciado"
        log_message "Snort IDS iniciado"
    else
        echo "Error al iniciar Snort IDS"
        log_message "Error al iniciar Snort IDS"
    fi
}

# Función para detener Snort IDS
stop_ids() {
    echo "Deteniendo Snort IDS..."
    
    systemctl stop snort-ids >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        echo "Snort IDS detenido"
        log_message "Snort IDS detenido"
    else
        echo "Error al detener Snort IDS"
        log_message "Error al detener Snort IDS"
    fi
}

# Función para reiniciar Snort IDS
restart_ids() {
    echo "Reiniciando Snort IDS..."
    
    systemctl restart snort-ids >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        echo "Snort IDS reiniciado"
        log_message "Snort IDS reiniciado"
    else
        echo "Error al reiniciar Snort IDS"
        log_message "Error al reiniciar Snort IDS"
    fi
}

# Función para iniciar Snort IPS
start_ips() {
    echo "Iniciando Snort IPS..."
    
    systemctl start snort-ips >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        echo "Snort IPS iniciado"
        log_message "Snort IPS iniciado"
    else
        echo "Error al iniciar Snort IPS"
        log_message "Error al iniciar Snort IPS"
    fi
}

# Función para detener Snort IPS
stop_ips() {
    echo "Deteniendo Snort IPS..."
    
    systemctl stop snort-ips >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        echo "Snort IPS detenido"
        log_message "Snort IPS detenido"
    else
        echo "Error al detener Snort IPS"
        log_message "Error al detener Snort IPS"
    fi
}

# Función para reiniciar Snort IPS
restart_ips() {
    echo "Reiniciando Snort IPS..."
    
    systemctl restart snort-ips >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        echo "Snort IPS reiniciado"
        log_message "Snort IPS reiniciado"
    else
        echo "Error al reiniciar Snort IPS"
        log_message "Error al reiniciar Snort IPS"
    fi
}

# Función para actualizar reglas de Snort
update_rules() {
    echo "Actualizando reglas de Snort..."
    
    # Hacer backup de reglas actuales
    cp -r "$SNORT_DIR/rules" "$SNORT_DIR/rules.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Descargar reglas actualizadas
    cd /tmp
    wget -q "https://www.snort.org/downloads/community/community-rules.tar.gz"
    tar -xzf "community-rules.tar.gz"
    
    # Copiar nuevas reglas
    cp -r rules/* "$SNORT_DIR/rules/"
    
    # Cambiar permisos
    chown -R snort:snort "$SNORT_DIR/rules"
    
    # Reiniciar Snort
    if systemctl is-active --quiet snort-ids; then
        restart_ids
    fi
    
    if systemctl is-active --quiet snort-ips; then
        restart_ips
    fi
    
    # Limpiar archivos temporales
    rm -rf /tmp/rules /tmp/community-rules.tar.gz
    
    echo "Reglas de Snort actualizadas"
    log_message "Reglas de Snort actualizadas"
}

# Función para ver alertas de Snort
view_alerts() {
    local lines=${1:-50}
    
    echo "Mostrando últimas $lines alertas de Snort..."
    
    if [ -f "$SNORT_LOG_DIR/alert" ]; then
        tail -n "$lines" "$SNORT_LOG_DIR/alert"
    else
        echo "No hay archivo de alertas de Snort"
    fi
}

# Función para añadir regla local
add_local_rule() {
    local rule=$1
    
    if [ -z "$rule" ]; then
        echo "Error: Se requiere regla"
        return 1
    fi
    
    echo "Añadiendo regla local: $rule"
    
    # Añadir regla al archivo de reglas locales
    echo "$rule" >> "$SNORT_DIR/rules/local.rules"
    
    # Reiniciar Snort
    if systemctl is-active --quiet snort-ids; then
        restart_ids
    fi
    
    if systemctl is-active --quiet snort-ips; then
        restart_ips
    fi
    
    echo "Regla añadida y Snort reiniciado"
    log_message "Regla añadida: $rule"
}

# Función para eliminar regla local
remove_local_rule() {
    local sid=$1
    
    if [ -z "$sid" ]; then
        echo "Error: Se requiere SID de regla"
        return 1
    fi
    
    echo "Eliminando regla local con SID: $sid"
    
    # Eliminar regla del archivo de reglas locales
    grep -v "sid:$sid" "$SNORT_DIR/rules/local.rules" > "$SNORT_DIR/rules/local.rules.tmp"
    mv "$SNORT_DIR/rules/local.rules.tmp" "$SNORT_DIR/rules/local.rules"
    
    # Reiniciar Snort
    if systemctl is-active --quiet snort-ids; then
        restart_ids
    fi
    
    if systemctl is-active --quiet snort-ips; then
        restart_ips
    fi
    
    echo "Regla eliminada y Snort reiniciado"
    log_message "Regla eliminada: $sid"
}

# Función para generar informe de alertas
generate_alert_report() {
    local report_file="/opt/virtualmin-enterprise/backups/snort-report-$(date +%Y%m%d_%H%M%S).txt"
    
    echo "Generando informe de alertas de Snort..."
    
    cat > "$report_file" << EOF
Informe de Alertas de Snort IDS/IPS
=======================================
Fecha: $(date)
Servidor: $(hostname)
IP: $(hostname -I | awk '{print $1}')

Resumen de Alertas:
EOF
    
    # Contar alertas por tipo
    if [ -f "$SNORT_LOG_DIR/alert" ]; then
        echo "Total de alertas: $(grep -c "\[\*\*\]" "$SNORT_LOG_DIR/alert")" >> "$report_file"
        echo "" >> "$report_file"
        
        echo "Alertas por tipo:" >> "$report_file"
        grep -o '\[\*\*\] [^[]*' "$SNORT_LOG_DIR/alert" | sort | uniq -c | sort -nr >> "$report_file"
        echo "" >> "$report_file"
        
        echo "Alertas por IP de origen:" >> "$report_file"
        grep -o '{[^}]*}' "$SNORT_LOG_DIR/alert" | sort | uniq -c | sort -nr | head -10 >> "$report_file"
        echo "" >> "$report_file"
        
        echo "Últimas 20 alertas:" >> "$report_file"
        tail -n 20 "$SNORT_LOG_DIR/alert" >> "$report_file"
    else
        echo "No hay archivo de alertas" >> "$report_file"
    fi
    
    log_message "Informe de alertas de Snort generado: $report_file"
    echo "Informe de alertas de Snort generado: $report_file"
}

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [OPCIÓN] [ARGUMENTOS]"
    echo ""
    echo "Opciones:"
    echo "  check_status                Verificar estado de Snort"
    echo "  start_ids                   Iniciar Snort IDS"
    echo "  stop_ids                    Detener Snort IDS"
    echo "  restart_ids                 Reiniciar Snort IDS"
    echo "  start_ips                   Iniciar Snort IPS"
    echo "  stop_ips                    Detener Snort IPS"
    echo "  restart_ips                 Reiniciar Snort IPS"
    echo "  update_rules                Actualizar reglas de Snort"
    echo "  view_alerts [LÍNEAS]       Ver alertas de Snort (por defecto: 50)"
    echo "  add_local_rule [REGLA]      Añadir regla local"
    echo "  remove_local_rule [SID]     Eliminar regla local por SID"
    echo "  generate_alert_report       Generar informe de alertas"
    echo "  show_help                   Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 check_status"
    echo "  $0 start_ids"
    echo "  $0 stop_ids"
    echo "  $0 restart_ids"
    echo "  $0 start_ips"
    echo "  $0 stop_ips"
    echo "  $0 restart_ips"
    echo "  $0 update_rules"
    echo "  $0 view_alerts 100"
    echo "  $0 add_local_rule 'alert tcp any any -> \$HOME_NET 80 (msg:\"Test Rule\"; sid:2000001; rev:1;)'"
    echo "  $0 remove_local_rule 2000001"
    echo "  $0 generate_alert_report"
}

# Procesar argumentos
case "$1" in
    "check_status")
        check_status
        ;;
    "start_ids")
        start_ids
        ;;
    "stop_ids")
        stop_ids
        ;;
    "restart_ids")
        restart_ids
        ;;
    "start_ips")
        start_ips
        ;;
    "stop_ips")
        stop_ips
        ;;
    "restart_ips")
        restart_ips
        ;;
    "update_rules")
        update_rules
        ;;
    "view_alerts")
        view_alerts "$2"
        ;;
    "add_local_rule")
        if [ -z "$2" ]; then
            echo "Error: Se requiere regla"
            show_help
            exit 1
        fi
        add_local_rule "$2"
        ;;
    "remove_local_rule")
        if [ -z "$2" ]; then
            echo "Error: Se requiere SID de regla"
            show_help
            exit 1
        fi
        remove_local_rule "$2"
        ;;
    "generate_alert_report")
        generate_alert_report
        ;;
    "show_help"|*)
        show_help
        ;;
esac
EOF
    
    # Hacer ejecutable el script
    chmod +x "$INSTALL_DIR/scripts/manage_snort.sh"
    
    log_message "Script de gestión de Snort creado"
    print_message $GREEN "Script de gestión de Snort creado"
}

# Función principal
main() {
    print_message $GREEN "Iniciando instalación y configuración de Snort IDS/IPS..."
    log_message "Iniciando instalación y configuración de Snort IDS/IPS"
    
    check_root
    install_dependencies
    install_daq
    install_snort
    configure_snort
    install_snort_rules
    configure_snort_ids
    configure_snort_ips
    create_management_script
    
    print_message $GREEN "Instalación y configuración de Snort IDS/IPS completada"
    log_message "Instalación y configuración de Snort IDS/IPS completada"
    
    print_message $BLUE "Información de configuración:"
    print_message $BLUE "- Archivo de configuración: $SNORT_DIR/snort.conf"
    print_message $BLUE "- Directorio de reglas: $SNORT_RULES_DIR"
    print_message $BLUE "- Logs: $SNORT_LOG_DIR"
    print_message $BLUE "- Script de gestión: $INSTALL_DIR/scripts/manage_snort.sh"
    print_message $YELLOW "Snort IDS está activo. Para activar Snort IPS, ejecute:"
    print_message $YELLOW "systemctl start snort-ips"
    print_message $YELLOW "Ejecute '$INSTALL_DIR/scripts/manage_snort.sh show_help' para ver las opciones de gestión"
}

# Ejecutar función principal
main "$@"
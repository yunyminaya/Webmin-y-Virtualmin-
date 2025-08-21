#!/bin/bash
# 🔧 TÚNEL NATIVO SIN DEPENDENCIAS DE TERCEROS
# Script profesional para exponer el panel Webmin/Virtualmin automáticamente sin servicios externos

set -euo pipefail

# Verificar permisos de root
if [[ $EUID -ne 0 ]]; then
    echo "Este script debe ejecutarse como root o con sudo" >&2
    exit 1
fi

LOG_FILE="/var/log/tunel-nativo.log"
CONFIG_DIR="/etc/tunel-nativo"
SERVICE_NAME="tunel-nativo"
TUNNEL_PORT_START=8080
WEBMIN_PORT=10000

log() {
    local level="$1"
    local msg="$2"
    echo "[$(date '+%F %T')] [$level] $msg" | tee -a "$LOG_FILE"
}

install_deps() {
    # Socat para túneles
    if ! command -v socat >/dev/null 2>&1; then
        log INFO "Instalando socat..."
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y socat
        elif command -v yum >/dev/null 2>&1; then
            yum install -y socat
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y socat
        else
            log ERROR "No se pudo instalar socat"
            exit 1
        fi
    fi
    # Fail2ban para protección contra ataques
    if ! command -v fail2ban-server >/dev/null 2>&1; then
        log INFO "Instalando fail2ban..."
        if command -v apt-get >/dev/null 2>&1; then
            apt-get install -y fail2ban
        elif command -v yum >/dev/null 2>&1; then
            yum install -y fail2ban
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y fail2ban
        fi
    fi
    # UFW o firewalld para firewall
    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y ufw
        ufw allow 80
        ufw allow 443
        ufw allow 10000
        # Asegurar no perder acceso SSH
        ufw allow 22
        ufw enable
    elif command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
        if command -v firewall-cmd >/dev/null 2>&1; then
            firewall-cmd --permanent --add-port=80/tcp
            firewall-cmd --permanent --add-port=443/tcp
            firewall-cmd --permanent --add-port=10000/tcp
            firewall-cmd --reload
        fi
    fi
}

create_http_tunnel() {
    local local_port=$1
    local tunnel_port=$2
    local service_name=$3

    log INFO "Creando túnel HTTP nativo para $service_name"

    cat > "$CONFIG_DIR/http_tunnel_${service_name}.sh" << EOF
#!/bin/bash
TUNNEL_PID_FILE="/var/run/http_tunnel_${service_name}.pid"
LOG_FILE="/var/log/http_tunnel_${service_name}.log"

start_tunnel() {
    if [[ -f "\$TUNNEL_PID_FILE" ]] && kill -0 \$(cat "\$TUNNEL_PID_FILE") 2>/dev/null; then
        echo "Túnel HTTP $service_name ya está ejecutándose"
        return 0
    fi
    echo "Iniciando túnel HTTP $service_name en puerto $tunnel_port..."
    socat TCP-LISTEN:$tunnel_port,fork,reuseaddr TCP:localhost:$local_port &
    echo \$! > "\$TUNNEL_PID_FILE"
    echo "Túnel HTTP $service_name iniciado con PID \$(cat \$TUNNEL_PID_FILE)"
    echo "Acceso disponible en: http://\$(hostname -I | awk '{print \$1}'):$tunnel_port"
}

stop_tunnel() {
    if [[ -f "\$TUNNEL_PID_FILE" ]]; then
        local pid=\$(cat "\$TUNNEL_PID_FILE")
        if kill -0 "\$pid" 2>/dev/null; then
            kill "\$pid"
            echo "Túnel HTTP $service_name detenido"
        fi
        rm -f "\$TUNNEL_PID_FILE"
    fi
}

case "\$1" in
    start) start_tunnel ;;
    stop) stop_tunnel ;;
    restart) stop_tunnel; sleep 2; start_tunnel ;;
    status)
        if [[ -f "\$TUNNEL_PID_FILE" ]] && kill -0 \$(cat "\$TUNNEL_PID_FILE") 2>/dev/null; then
            echo "Túnel HTTP $service_name está ejecutándose en puerto $tunnel_port"
        else
            echo "Túnel HTTP $service_name no está ejecutándose"
        fi
        ;;
    *) echo "Uso: \$0 {start|stop|restart|status}" ;;
esac
EOF

    chmod +x "$CONFIG_DIR/http_tunnel_${service_name}.sh"
    log INFO "Túnel HTTP creado: puerto $local_port -> $tunnel_port"
}

# Protección empresarial y escalabilidad
setup_enterprise_security() {
    # Fail2ban para Webmin/Virtualmin
    local jail_conf="/etc/fail2ban/jail.d/webmin.conf"
    cat > "$jail_conf" <<EOF
[webmin]
enabled = true
port    = 10000
filter  = webmin-auth
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
EOF

    local filter_conf="/etc/fail2ban/filter.d/webmin-auth.conf"
    cat > "$filter_conf" <<EOF
[Definition]
failregex = Authentication failed for user .*
ignoreregex =
EOF

    # Reiniciar fail2ban
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart fail2ban
    elif command -v service >/dev/null 2>&1; then
        service fail2ban restart
    fi

    # Limitar conexiones simultáneas y mitigar DDoS
    if command -v iptables >/dev/null 2>&1; then
        iptables -C INPUT -p tcp --syn --dport 10000 -m connlimit --connlimit-above 50 -j REJECT 2>/dev/null || \
        iptables -A INPUT -p tcp --syn --dport 10000 -m connlimit --connlimit-above 50 -j REJECT

        iptables -C INPUT -p tcp --dport 10000 -m state --state NEW -m recent --set 2>/dev/null || \
        iptables -A INPUT -p tcp --dport 10000 -m state --state NEW -m recent --set

        iptables -C INPUT -p tcp --dport 10000 -m state --state NEW -m recent --update --seconds 60 --hitcount 20 -j DROP 2>/dev/null || \
        iptables -A INPUT -p tcp --dport 10000 -m state --state NEW -m recent --update --seconds 60 --hitcount 20 -j DROP

        iptables -C INPUT -p tcp --dport 80 -m connlimit --connlimit-above 200 -j REJECT 2>/dev/null || \
        iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above 200 -j REJECT

        iptables -C INPUT -p tcp --dport 443 -m connlimit --connlimit-above 200 -j REJECT 2>/dev/null || \
        iptables -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above 200 -j REJECT
    fi

    # Instalar y configurar HAProxy para balanceo y alta concurrencia
    if ! command -v haproxy >/dev/null 2>&1; then
        if command -v apt-get >/dev/null 2>&1; then
            apt-get install -y haproxy
        elif command -v yum >/dev/null 2>&1; then
            yum install -y haproxy
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y haproxy
        fi
    fi

    # Configuración básica de HAProxy para Webmin/Virtualmin y HTTP/HTTPS
    local haproxy_cfg="/etc/haproxy/haproxy.cfg"
    # Backup previo si existe
    if [[ -f "$haproxy_cfg" ]]; then
        cp "$haproxy_cfg" "${haproxy_cfg}.bak.$(date +%F-%T)"
    fi
    cat > "$haproxy_cfg" <<EOF
global
    maxconn 100000
    log /dev/log local0
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    timeout connect 10s
    timeout client  1m
    timeout server  1m
    maxconn 100000

frontend webmin
    bind *:10000
    default_backend webmin_servers

frontend http
    bind *:80
    default_backend http_servers

frontend https
    bind *:443
    default_backend https_servers

backend webmin_servers
    balance roundrobin
    server webmin1 127.0.0.1:10000 check

backend http_servers
    balance roundrobin
    server http1 127.0.0.1:80 check

backend https_servers
    balance roundrobin
    server https1 127.0.0.1:443 check
EOF

    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart haproxy
        systemctl enable haproxy
    elif command -v service >/dev/null 2>&1; then
        service haproxy restart
    fi
}

setup_automatic_tunnels() {
    log INFO "Configurando túneles automáticos..."
    # Detectar puerto real de Webmin/Virtualmin desde miniserv.conf si existe
    local conf_port="$WEBMIN_PORT"
    if [[ -f "/etc/webmin/miniserv.conf" ]]; then
        conf_port=$(grep -E "^port=" /etc/webmin/miniserv.conf | cut -d= -f2)
        if [[ -n "$conf_port" ]]; then
            WEBMIN_PORT="$conf_port"
        fi
    fi
    create_http_tunnel "$WEBMIN_PORT" "$WEBMIN_PORT" "webmin"
    # Túneles para HTTP y HTTPS
    create_http_tunnel 80 80 "http"
    create_http_tunnel 443 443 "https"
}

create_service() {
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS launchctl
        cat > /Library/LaunchDaemons/com.tunel.nativo.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.tunel.nativo</string>
    <key>ProgramArguments</key>
    <array>
        <string>$CONFIG_DIR/start_all_tunnels.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/tunel-nativo.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/tunel-nativo.log</string>
</dict>
</plist>
EOF
        chmod 644 /Library/LaunchDaemons/com.tunel.nativo.plist
        log INFO "Servicio launchctl creado: com.tunel.nativo"
    else
        # Linux systemd
        cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=Túneles nativos para exponer panel Webmin/Virtualmin
After=network.target

[Service]
Type=simple
ExecStart=$CONFIG_DIR/start_all_tunnels.sh
ExecStop=$CONFIG_DIR/stop_all_tunnels.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF
        log INFO "Servicio systemd creado: $SERVICE_NAME"
    fi
}

create_control_scripts() {
    cat > "$CONFIG_DIR/start_all_tunnels.sh" << 'EOF'
#!/bin/bash
for script in /etc/tunel-nativo/http_tunnel_*.sh; do
    if [[ -f "$script" ]]; then
        bash "$script" start
    fi
done
EOF

    cat > "$CONFIG_DIR/stop_all_tunnels.sh" << 'EOF'
#!/bin/bash
for script in /etc/tunel-nativo/http_tunnel_*.sh; do
    if [[ -f "$script" ]]; then
        bash "$script" stop
    fi
done
EOF

    chmod +x "$CONFIG_DIR/start_all_tunnels.sh" "$CONFIG_DIR/stop_all_tunnels.sh"
}

install() {
    sudo mkdir -p "$CONFIG_DIR" /var/log
    install_deps
    setup_automatic_tunnels
    create_control_scripts
    create_service
    setup_enterprise_security
    if [[ "$(uname)" == "Darwin" ]]; then
        launchctl load /Library/LaunchDaemons/com.tunel.nativo.plist
        log INFO "Túnel nativo instalado y servicio iniciado (launchctl)."
    else
        systemctl daemon-reload
        systemctl enable --now $SERVICE_NAME
        log INFO "Túnel nativo instalado y servicio iniciado (systemd)."
    fi
}

status() {
    if [[ "$(uname)" == "Darwin" ]]; then
        launchctl list | grep tunel.nativo && echo "Servicio activo (launchctl)" || echo "Servicio no activo"
    else
        systemctl status $SERVICE_NAME
    fi
}

case "${1:-}" in
    --install)
        install
        ;;
    --status)
        status
        ;;
    --uninstall)
        if [[ "$(uname)" == "Darwin" ]]; then
            launchctl unload /Library/LaunchDaemons/com.tunel.nativo.plist || true
            rm -f /Library/LaunchDaemons/com.tunel.nativo.plist
            rm -rf "$CONFIG_DIR"
            log INFO "Túnel nativo desinstalado (launchctl)."
        else
            systemctl stop $SERVICE_NAME || true
            systemctl disable $SERVICE_NAME || true
            rm -f /etc/systemd/system/$SERVICE_NAME.service
            rm -rf "$CONFIG_DIR"
            systemctl daemon-reload
            log INFO "Túnel nativo desinstalado (systemd)."
        fi
        ;;
    *)
        echo "Uso: $0 --install | --status | --uninstall"
        ;;
esac

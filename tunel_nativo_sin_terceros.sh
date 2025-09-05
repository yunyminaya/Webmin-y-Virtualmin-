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

# Flags de seguridad (por defecto, conservadores)
WITH_FIREWALL=0           # --with-firewall
WITH_HAPROXY=0            # --with-haproxy (no modifica config salvo confirmación explícita)
ALLOW_HAPROXY_OVERWRITE=0 # --allow-haproxy-overwrite (peligroso)
WITH_TUNNELS_HTTP=0       # --http-tunnels (crea 80/443 solo si libres)
NON_INTERACTIVE=0         # --yes (no preguntar)
WITH_IPTABLES_LIMIT=0     # --with-iptables-rate-limit (no persistente)

usage() {
    cat <<EOF
Uso: $0 [--install|--status|--uninstall] [opciones]

Opciones de instalación seguras:
  --with-firewall              Configurar firewall (UFW/firewalld) con confirmación
  --with-haproxy               Instalar HAProxy (sin tocar configuración por defecto)
  --allow-haproxy-overwrite    PERMITIR sobreescribir /etc/haproxy/haproxy.cfg (riesgoso)
  --http-tunnels               Crear túneles para 80/443 además de Webmin (si puertos libres)
  --with-iptables-rate-limit   Añadir límites con iptables (no persistente)
  --yes                        No preguntar (modo no interactivo)

Comandos:
  --install    Instala dependencias y servicio
  --status     Muestra el estado del servicio
  --uninstall  Desinstala el servicio y archivos
EOF
}

log() {
    local level="$1"
    local msg="$2"
    echo "[$(date '+%F %T')] [$level] $msg" | tee -a "$LOG_FILE"
}

# IP primaria portable (Linux/macOS)
get_primary_ip() {
    # Linux
    if command -v ip >/dev/null 2>&1; then
        ip route get 1 2>/dev/null | awk '{print $7; exit}'
        return
    fi
    # macOS
    for iface in en0 en1; do
        if command -v ipconfig >/dev/null 2>&1; then
            ipconfig getifaddr "$iface" 2>/dev/null && return || true
        fi
    done
    # Fallback
    hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1"
}

# Verificar si el puerto está libre
port_free() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        ! ss -ltn | awk '{print $4}' | grep -q ":$port$"
    elif command -v netstat >/dev/null 2>&1; then
        ! netstat -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$port$"
    else
        return 0
    fi
}

# Listar IPv4 locales (scope global)
list_ipv4_addrs() {
    if command -v ip >/dev/null 2>&1; then
        ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1
    else
        ifconfig 2>/dev/null | awk '/inet /{print $2}'
    fi
}

# ¿La IP es privada/reservada?
is_private_ipv4() {
    local ip="$1"
    [[ "$ip" =~ ^10\. ]] && return 0
    [[ "$ip" =~ ^127\. ]] && return 0
    [[ "$ip" =~ ^169\.254\. ]] && return 0
    [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] && return 0
    [[ "$ip" =~ ^192\.168\. ]] && return 0
    [[ "$ip" =~ ^100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\. ]] && return 0
    return 1
}

# ¿Existe alguna IP pública local?
has_public_ip() {
    local any_public=1
    while IFS= read -r ip; do
        [[ -z "$ip" ]] && continue
        if ! is_private_ipv4 "$ip"; then
            any_public=0
            break
        fi
    done < <(list_ipv4_addrs)
    return $any_public
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
    # Firewall opcional (confirmado por bandera)
    if [[ "$WITH_FIREWALL" -eq 1 ]]; then
        if command -v apt-get >/dev/null 2>&1; then
            apt-get install -y ufw
            ufw allow 22 || true
            ufw allow 10000/tcp || true
            if [[ "$WITH_TUNNELS_HTTP" -eq 1 ]]; then
                ufw allow 80/tcp || true
                ufw allow 443/tcp || true
            fi
            if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
                ufw --force enable
            else
                read -r -p "Habilitar UFW ahora? [y/N]: " ans
                [[ "$ans" =~ ^[Yy]$ ]] && ufw enable || log INFO "UFW no habilitado"
            fi
            # Límite básico opcional
            ufw limit 10000/tcp || true
        elif command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
            if command -v firewall-cmd >/dev/null 2>&1; then
                systemctl enable firewalld || true
                systemctl start firewalld || true
                firewall-cmd --permanent --add-service=ssh || true
                firewall-cmd --permanent --add-port=10000/tcp || true
                if [[ "$WITH_TUNNELS_HTTP" -eq 1 ]]; then
                    firewall-cmd --permanent --add-service=http || true
                    firewall-cmd --permanent --add-service=https || true
                fi
                firewall-cmd --reload || true
            fi
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
    if ! port_free "$tunnel_port"; then
        echo "Puerto $tunnel_port ya está en uso. Omitiendo túnel $service_name."
        return 0
    fi
    echo "Iniciando túnel HTTP $service_name en puerto $tunnel_port..."
    socat TCP-LISTEN:$tunnel_port,fork,reuseaddr TCP:localhost:$local_port &
    echo \$! > "\$TUNNEL_PID_FILE"
    echo "Túnel HTTP $service_name iniciado con PID \$(cat \$TUNNEL_PID_FILE)"
    # Detección de IP local portable
    get_ip() {
        if command -v ip >/dev/null 2>&1; then
            ip route get 1 2>/dev/null | awk '{print $7; exit}'
            return
        fi
        for iface in en0 en1; do
            if command -v ipconfig >/dev/null 2>&1; then
                ipconfig getifaddr "$iface" 2>/dev/null && return || true
            fi
        done
        hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1"
    }
    echo "Acceso disponible en: http://\$(get_ip):$tunnel_port"
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
    # Fail2ban para Webmin/Virtualmin (miniserv.log)
    local jail_conf="/etc/fail2ban/jail.d/webmin.conf"
    local filter_conf="/etc/fail2ban/filter.d/webmin-auth.conf"
    local miniserv_log="/var/webmin/miniserv.log"

    if [[ -f "$miniserv_log" ]] || [[ -d "/var/webmin" ]]; then
cat > "$jail_conf" <<EOF
[webmin]
enabled = true
port    = 10000
filter  = webmin-auth
logpath = $miniserv_log
maxretry = 5
bantime = 3600
EOF

cat > "$filter_conf" <<'EOF'
[Definition]
# Patrones comunes de miniserv.log
failregex = ^.*Failed (?:password|login) .* from <HOST>.*$
            ^.*Authentication failed for user .* from <HOST>.*$
ignoreregex =
EOF
    else
        log INFO "No se encontró miniserv.log; omitiendo jail Webmin (fail2ban)"
    fi

    # Reiniciar fail2ban si instalado
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart fail2ban || true
    elif command -v service >/dev/null 2>&1; then
        service fail2ban restart || true
    fi

    # Límites iptables opcionales (no persistentes)
    if [[ "$WITH_IPTABLES_LIMIT" -eq 1 ]] && command -v iptables >/dev/null 2>&1; then
        iptables -C INPUT -p tcp --syn --dport 10000 -m connlimit --connlimit-above 50 -j REJECT 2>/dev/null || \
        iptables -A INPUT -p tcp --syn --dport 10000 -m connlimit --connlimit-above 50 -j REJECT

        iptables -C INPUT -p tcp --dport 10000 -m state --state NEW -m recent --set 2>/dev/null || \
        iptables -A INPUT -p tcp --dport 10000 -m state --state NEW -m recent --set

        iptables -C INPUT -p tcp --dport 10000 -m state --state NEW -m recent --update --seconds 60 --hitcount 20 -j DROP 2>/dev/null || \
        iptables -A INPUT -p tcp --dport 10000 -m state --state NEW -m recent --update --seconds 60 --hitcount 20 -j DROP

        log INFO "Reglas iptables añadidas (no persistentes)"
    fi

    # HAProxy opcional, protegido
    if [[ "$WITH_HAPROXY" -eq 1 ]]; then
        if ! command -v haproxy >/dev/null 2>&1; then
            if command -v apt-get >/dev/null 2>&1; then
                apt-get install -y haproxy
            elif command -v yum >/dev/null 2>&1; then
                yum install -y haproxy
            elif command -v dnf >/dev/null 2>&1; then
                dnf install -y haproxy
            fi
        fi

        if [[ "$ALLOW_HAPROXY_OVERWRITE" -eq 1 ]]; then
            local haproxy_cfg="/etc/haproxy/haproxy.cfg"
            if [[ -f "$haproxy_cfg" ]]; then
                cp "$haproxy_cfg" "${haproxy_cfg}.bak.$(date +%F-%T)"
            fi

            # Evitar colisión de puertos
            for p in 80 443 10000; do
                if ! port_free "$p"; then
                    log ERROR "Puerto $p ocupado. No se puede configurar HAProxy (overwrite)."
                    return 0
                fi
            done

cat > "$haproxy_cfg" <<'EOF'
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
                systemctl restart haproxy || true
                systemctl enable haproxy || true
            else
                service haproxy restart || true
            fi
            log INFO "HAProxy configurado (overwrite explícito)"
        else
            log INFO "HAProxy instalado. No se modifica haproxy.cfg (use --allow-haproxy-overwrite bajo su criterio)."
        fi
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
    # Solo Webmin por defecto
    create_http_tunnel "$WEBMIN_PORT" "$WEBMIN_PORT" "webmin"
    # Túneles para HTTP y HTTPS (opcionales y solo si puertos libres)
    if [[ "$WITH_TUNNELS_HTTP" -eq 1 ]]; then
        create_http_tunnel 80 80 "http"
        create_http_tunnel 443 443 "https"
    fi
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
    mkdir -p "$CONFIG_DIR" /var/log
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

parse_args() {
    # Parsea flags adicionales además del comando
    for a in "$@"; do
        case "$a" in
            --with-firewall) WITH_FIREWALL=1 ;;
            --with-haproxy) WITH_HAPROXY=1 ;;
            --allow-haproxy-overwrite) ALLOW_HAPROXY_OVERWRITE=1 ;;
            --http-tunnels) WITH_TUNNELS_HTTP=1 ;;
            --with-iptables-rate-limit) WITH_IPTABLES_LIMIT=1 ;;
            --yes|-y) NON_INTERACTIVE=1 ;;
        esac
    done
}

cmd="${1:-}"
shift || true
parse_args "$@"

# Instalación automática si no hay IP pública y no se pasó comando
if [[ -z "$cmd" ]]; then
    if ! has_public_ip; then
        log INFO "No se detectó IP pública. Ejecutando instalación automática con configuración segura."
        cmd="--install"
    else
        usage
        exit 0
    fi
fi

case "$cmd" in
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
        usage
        ;;
esac

#!/bin/bash

# Configuración avanzada
TUNNEL_PORT=2222
REMOTE_USER="tunneluser"
REMOTE_HOST="tunnel.webmin-expert.com"
KEY_FILE="/etc/tunnel/key_rsa"
LOG_FILE="/var/log/ip_tunnel.log"
WATCHDOG_INTERVAL=60  # Segundos
ALERT_EMAIL="admin@example.com"

# Funciones mejoradas
get_public_ip() {
    ip=$(curl -s --max-time 3 api.ipify.org || \
         curl -s --max-time 3 ifconfig.me || \
         curl -s --max-time 3 icanhazip.com)
    echo "$ip"
}

# Verificar estado del túnel
check_tunnel_health() {
    # Verificar si el proceso SSH está activo
    if ! pgrep -f "ssh.*$TUNNEL_PORT" >/dev/null; then
        return 1
    fi
    
    # Verificar conectividad a través del túnel
    if ssh -p $TUNNEL_PORT $REMOTE_USER@localhost true 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Enviar alerta
send_alert() {
    local message="$1"
    echo "$message" | mail -s "Tunnel Alert" "$ALERT_EMAIL"
    logger -t ip-tunnel "ALERTA: $message"
}

# Restablecer túnel
restart_tunnel() {
    # Matar procesos existentes
    pkill -f "ssh.*$TUNNEL_PORT"
    
    # Iniciar nuevo túnel
    ssh -o "ExitOnForwardFailure=yes" \
        -o "ServerAliveInterval=60" \
        -o "ServerAliveCountMax=3" \
        -i "$KEY_FILE" \
        -N -R $TUNNEL_PORT:localhost:22 \
        "$REMOTE_USER@$REMOTE_HOST" &>> "$LOG_FILE" &
    
    sleep 2
    if check_tunnel_health; then
        logger -t ip-tunnel "Túnel restablecido exitosamente"
    else
        logger -t ip-tunnel "Error al restablecer túnel"
        send_alert "Fallo crítico en túnel IP. No se pudo restablecer"
    fi
}

# Modo watchdog
watchdog_mode() {
    while true; do
        if check_tunnel_health; then
            echo "[$(date)] Túnel activo y saludable" >> "$LOG_FILE"
        else
            echo "[$(date)] Túnel inactivo. Restableciendo..." >> "$LOG_FILE"
            send_alert "Túnel inactivo. Intentando restablecer"
            restart_tunnel
        fi
        sleep $WATCHDOG_INTERVAL
    done
}

# Configurar túnel SSH
setup_ssh_tunnel() {
    local public_ip=$(get_public_ip)
    
    echo "Configurando túnel SSH para IP: $public_ip"
    
    # Comando para crear túnel inverso
    ssh -fN -R $TUNNEL_PORT:localhost:$LOCAL_SSH_PORT $REMOTE_USER@$REMOTE_HOST -p $REMOTE_SSH_PORT
    
    # Verificar estado
    if [ $? -eq 0 ]; then
        echo "Túnel establecido exitosamente"
        echo "Acceso remoto: ssh -p $TUNNEL_PORT localhost@$REMOTE_HOST"
    else
        echo "Error al establecer el túnel"
        exit 1
    fi
}

# Configurar servicio persistente
setup_persistent_service() {
    echo "Creando servicio persistente..."
    
    # Crear archivo de servicio systemd
    cat <<EOF | sudo tee /etc/systemd/system/ip-tunnel.service > /dev/null
[Unit]
Description=Public IP Tunnel Service
After=network.target

[Service]
User=root
ExecStart=/usr/bin/bash -c "service_mode"
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

    # Recargar e iniciar servicio
    sudo systemctl daemon-reload
    sudo systemctl enable ip-tunnel.service
    sudo systemctl start ip-tunnel.service
}

# Modo servicio (para systemd)
service_mode() {
    # Iniciar túnel inicial
    restart_tunnel
    
    # Iniciar watchdog
    watchdog_mode &
    
    # Mantener servicio activo
    while true; do
        sleep 3600
    done
}

# Función principal
main() {
    setup_ssh_tunnel
    setup_persistent_service
}

# Ejecutar
main

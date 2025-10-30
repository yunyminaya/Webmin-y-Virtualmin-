#!/bin/bash

# Tunnel Automation Script
# Version: 1.0

# Configuración
TUNNEL_PORT=2222
REMOTE_USER="tunneluser"
REMOTE_HOST="tunnel.example.com"
REMOTE_SSH_PORT=22
LOCAL_SSH_PORT=22

# Obtener IP pública
get_public_ip() {
    curl -s ifconfig.me
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
ExecStart=/usr/bin/ssh -N -R $TUNNEL_PORT:localhost:$LOCAL_SSH_PORT $REMOTE_USER@$REMOTE_HOST -p $REMOTE_SSH_PORT
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

# Función principal
main() {
    setup_ssh_tunnel
    setup_persistent_service
}

# Ejecutar
main

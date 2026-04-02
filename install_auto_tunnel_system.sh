#!/bin/bash
set -euo pipefail

echo "[SECURITY] Automatic public tunnel installation is disabled."
echo "[SECURITY] Removing previously installed tunnel services if present."

for svc in auto-tunnel.service localtunnel.service ip-tunnel.service; do
    systemctl disable --now "$svc" 2>/dev/null || true
done

rm -f /etc/systemd/system/auto-tunnel.service \
      /etc/systemd/system/localtunnel.service \
      /etc/systemd/system/ip-tunnel.service \
      /usr/lib/cgi-bin/tunnel_status.cgi \
      /usr/local/bin/auto_tunnel_system.sh \
      /usr/local/bin/auto-tunnel \
      /usr/local/bin/start-localtunnel.sh \
      /var/localtunnel_url.txt \
      /var/run/localtunnel.pid \
      /var/run/ssh_tunnel.pid \
      /var/run/tunnel_monitor.pid

systemctl daemon-reload 2>/dev/null || true

echo "[SECURITY] Tunnel components disabled and cleaned up."

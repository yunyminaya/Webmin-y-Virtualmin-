#!/bin/bash

# ============================================================================
# 🚀 INSTALADOR ULTRA-SIMPLE DEL SISTEMA AUTÓNOMO
# ============================================================================

set -euo pipefail

echo "🚀 INSTALANDO SISTEMA DE AUTO-REPARACIÓN AUTÓNOMA..."

# Crear script principal simplificado
cat > /root/autonomous_repair.sh << 'EOF'
#!/bin/bash

# Script autónomo simplificado
LOG_FILE="/root/auto_repair.log"

log() {
    echo "$(date) - $*" >> "$LOG_FILE"
    echo "$*"
}

while true; do
    log "=== VERIFICANDO SISTEMA ==="

    # Verificar Apache
    if ! systemctl is-active --quiet apache2 2>/dev/null && systemctl list-units | grep -q apache2; then
        log "❌ Apache inactivo - intentando reparar..."
        systemctl start apache2 2>/dev/null && log "✅ Apache reparado" || log "❌ No se pudo reparar Apache"
    fi

    # Verificar MySQL
    if ! systemctl is-active --quiet mysql 2>/dev/null && ! systemctl is-active --quiet mariadb 2>/dev/null; then
        for service in mysql mariadb; do
            if systemctl list-units | grep -q "$service"; then
                log "❌ $service inactivo - intentando reparar..."
                systemctl start "$service" 2>/dev/null && log "✅ $service reparado" || log "❌ No se pudo reparar $service"
                break
            fi
        done
    fi

    # Verificar Webmin
    if ! systemctl is-active --quiet webmin 2>/dev/null && systemctl list-units | grep -q webmin; then
        log "❌ Webmin inactivo - intentando reparar..."
        systemctl start webmin 2>/dev/null && log "✅ Webmin reparado" || log "❌ No se pudo reparar Webmin"
    fi

    # Liberar memoria si es necesaria
    mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}' 2>/dev/null || echo "0")
    if [[ $mem_usage -gt 85 ]]; then
        log "⚠️ Memoria alta ($mem_usage%) - liberando..."
        sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null && log "✅ Memoria liberada" || log "❌ Error liberando memoria"
    fi

    # Limpiar archivos temporales
    find /tmp -name "*.tmp" -type f -mtime +1 -delete 2>/dev/null && log "✅ Archivos temporales limpiados" || true

    log "=== ESPERANDO 5 MINUTOS ==="
    sleep 300
done
EOF

chmod +x /root/autonomous_repair.sh

# Crear servicio systemd
cat > /etc/systemd/system/auto-repair.service << EOF
[Unit]
Description=Auto-Repair Autonomous System
After=network.target

[Service]
Type=simple
User=root
ExecStart=/root/autonomous_repair.sh
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Crear cron job
cat > /etc/cron.d/auto-repair << EOF
*/5 * * * * root /root/autonomous_repair.sh monitor >/dev/null 2>&1
EOF

# Recargar y habilitar
systemctl daemon-reload
systemctl enable auto-repair
systemctl start auto-repair

echo ""
echo "🎉 ¡SISTEMA AUTÓNOMO INSTALADO!"
echo ""
echo "✅ El sistema ahora:"
echo "   • Verifica servicios cada 5 minutos"
echo "   • Repara Apache, MySQL y Webmin automáticamente"
echo "   • Libera memoria cuando está alta"
echo "   • Limpia archivos temporales"
echo "   • Funciona 24/7 sin intervención"
echo ""
echo "📊 Ver estado: systemctl status auto-repair"
echo "📋 Ver logs: tail -f /root/auto_repair.log"
echo ""
echo "🛡️ ¡TU VPS AHORA SE AUTO-REPARA SOLA!"

#!/bin/bash

# Ejemplos de Uso del Sistema de Monitoreo Avanzado
# Demostración completa de todas las funcionalidades

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "  EJEMPLOS DE USO - SISTEMA DE MONITOREO"
echo "  Webmin & Virtualmin Enterprise"
echo "=========================================="
echo

# Función para ejecutar comandos con verificación
run_cmd() {
    local cmd="$1"
    local desc="$2"

    echo "🔧 $desc..."
    echo "Comando: $cmd"
    echo

    if eval "$cmd"; then
        echo "✅ $desc - COMPLETADO"
    else
        echo "❌ $desc - ERROR"
        return 1
    fi
    echo
}

# Función para mostrar información
show_info() {
    echo "ℹ️  $1"
    echo
}

# Función para mostrar código
show_code() {
    echo "💻 Código:"
    echo "$1"
    echo
}

echo "Este script demuestra el uso completo del Sistema de Monitoreo Avanzado."
echo "Asegúrate de tener instaladas todas las dependencias antes de ejecutar."
echo

# 1. Instalación del sistema
echo "1️⃣ INSTALACIÓN DEL SISTEMA"
echo "=========================="

show_info "Para instalar el sistema completo, ejecuta:"
show_code "sudo ./install_advanced_monitoring.sh"

show_info "Esto instalará todas las dependencias, configurará Apache, creará servicios systemd y configurará backups automáticos."

# 2. Configuración inicial
echo "2️⃣ CONFIGURACIÓN INICIAL"
echo "========================"

show_info "Después de la instalación, configura el sistema:"
show_code "sudo ./advanced_monitoring.sh --setup"

show_info "Esto creará la base de datos, directorios necesarios y configurará el dashboard web."

# 3. Configuración de alertas
echo "3️⃣ CONFIGURACIÓN DE ALERTAS"
echo "==========================="

show_info "Configura las alertas editando el archivo de configuración:"
show_code "sudo nano /etc/advanced_monitoring/config.sh"

echo "Contenido típico del archivo de configuración:"
cat << 'EOF'

# Configuración del Sistema de Monitoreo Avanzado
MONITOR_INTERVAL=30
ENABLE_EMAIL_ALERTS=true
EMAIL_RECIPIENT="admin@tu-dominio.com"
ENABLE_TELEGRAM_ALERTS=false
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
CPU_WARNING=80
CPU_CRITICAL=95
MEM_WARNING=85
MEM_CRITICAL=95
DISK_WARNING=85
DISK_CRITICAL=95
ANOMALY_DETECTION=true
HISTORICAL_DATA=true
ANOMALY_THRESHOLD=2.0

EOF

# 4. Inicio del servicio
echo "4️⃣ INICIO DEL SERVICIO"
echo "======================"

show_info "Iniciar el servicio de monitoreo:"
show_code "sudo systemctl enable --now advanced-monitoring"

show_info "Verificar que el servicio está ejecutando:"
show_code "sudo systemctl status advanced-monitoring"

show_info "Ver logs del servicio:"
show_code "sudo journalctl -u advanced-monitoring -f"

# 5. Acceso al dashboard
echo "5️⃣ ACCESO AL DASHBOARD"
echo "======================"

show_info "El dashboard web estará disponible en:"
show_code "http://tu-servidor/monitoring/"

show_info "Secciones del dashboard:"
echo "• Vista General: CPU, Memoria, Disco, Red"
echo "• Performance: Gráficos detallados y métricas técnicas"
echo "• Servicios: Estado de servicios y métricas Virtualmin"
echo "• Alertas: Historial de alertas y notificaciones"

# 6. Monitoreo manual
echo "6️⃣ MONITOREO MANUAL"
echo "==================="

show_info "Ejecutar una verificación manual única:"
run_cmd "$SCRIPT_DIR/advanced_monitoring.sh" "Monitoreo manual único"

show_info "Ejecutar monitoreo continuo (Ctrl+C para detener):"
show_code "$SCRIPT_DIR/advanced_monitoring.sh --continuous"

show_info "Monitoreo continuo con intervalo personalizado:"
show_code "$SCRIPT_DIR/advanced_monitoring.sh -c -i 60"

# 7. Consultas a la base de datos
echo "7️⃣ CONSULTAS A LA BASE DE DATOS"
echo "==============================="

show_info "Conectar a la base de datos SQLite:"
show_code "sqlite3 /var/lib/advanced_monitoring/metrics.db"

echo "Consultas útiles:"
echo

echo "📊 Ver métricas recientes:"
show_code "SELECT timestamp, metric_type, metric_name, value, unit FROM metrics ORDER BY timestamp DESC LIMIT 10;"

echo "🚨 Ver alertas activas:"
show_code "SELECT timestamp, alert_type, severity, message FROM alerts WHERE resolved = 0 ORDER BY timestamp DESC;"

echo "🤖 Ver anomalías recientes:"
show_code "SELECT timestamp, metric_name, expected_value, actual_value, deviation FROM anomalies ORDER BY timestamp DESC LIMIT 5;"

echo "📈 Uso de CPU en las últimas 24 horas:"
show_code "SELECT strftime('%H:%M', timestamp) as time, value FROM metrics WHERE metric_name = 'cpu_total' AND timestamp >= datetime('now', '-1 day') ORDER BY timestamp;"

# 8. Gestión de alertas
echo "8️⃣ GESTIÓN DE ALERTAS"
echo "====================="

show_info "Marcar una alerta como resuelta:"
show_code "sqlite3 /var/lib/advanced_monitoring/metrics.db 'UPDATE alerts SET resolved = 1 WHERE id = X;'"

show_info "Eliminar alertas antiguas:"
show_code "sqlite3 /var/lib/advanced_monitoring/metrics.db \"DELETE FROM alerts WHERE timestamp < datetime('now', '-30 days') AND resolved = 1;\""

# 9. Backup y mantenimiento
echo "9️⃣ BACKUP Y MANTENIMIENTO"
echo "========================="

show_info "Backup manual de datos:"
run_cmd "$SCRIPT_DIR/backup_monitoring_data.sh" "Crear backup manual"

show_info "Mantenimiento del sistema:"
run_cmd "$SCRIPT_DIR/maintenance_monitoring.sh" "Ejecutar mantenimiento"

show_info "Ver backups existentes:"
show_code "ls -la /var/backups/monitoring/"

# 10. Integración con scripts existentes
echo "1️⃣0️⃣ INTEGRACIÓN CON SCRIPTS EXISTENTES"
echo "====================================="

show_info "Usar el sistema avanzado desde monitor_sistema.sh:"
show_code "$SCRIPT_DIR/monitor_sistema.sh --advanced"

show_info "Configurar monitor_sistema.sh para usar avanzado por defecto:"
show_code "echo 'USE_ADVANCED=true' >> /etc/advanced_monitoring/config.sh"

# 11. Solución de problemas
echo "1️⃣1️⃣ SOLUCIÓN DE PROBLEMAS"
echo "=========================="

show_info "Verificar instalación:"
show_code "ls -la /etc/advanced_monitoring/
ls -la /var/lib/advanced_monitoring/
ls -la /var/log/advanced_monitoring/
ls -la /var/www/html/monitoring/"

show_info "Verificar servicios:"
show_code "systemctl list-units | grep monitoring"

show_info "Probar conectividad del dashboard:"
show_code "curl -I http://localhost/monitoring/"

show_info "Verificar base de datos:"
show_code "sqlite3 /var/lib/advanced_monitoring/metrics.db '.tables'
sqlite3 /var/lib/advanced_monitoring/metrics.db 'SELECT COUNT(*) FROM metrics;'"

# 12. Configuración avanzada
echo "1️⃣2️⃣ CONFIGURACIÓN AVANZADA"
echo "==========================="

show_info "Configurar umbrales personalizados:"
cat << 'EOF'
# Umbrales agresivos para servidores críticos
CPU_WARNING=70
CPU_CRITICAL=85
MEM_WARNING=75
MEM_CRITICAL=90

# Umbrales relajados para desarrollo
CPU_WARNING=90
CPU_CRITICAL=98
MEM_WARNING=95
MEM_CRITICAL=99
EOF

show_info "Configurar detección de anomalías:"
cat << 'EOF'
# Alta sensibilidad
ANOMALY_THRESHOLD=1.5

# Baja sensibilidad (menos falsos positivos)
ANOMALY_THRESHOLD=2.5
EOF

# 13. Monitoreo de ejemplo
echo "1️⃣3️⃣ EJEMPLO DE MONITOREO EN ACCIÓN"
echo "==================================="

show_info "Vamos a ejecutar un monitoreo de ejemplo para ver el sistema en funcionamiento:"

if [[ -x "$SCRIPT_DIR/advanced_monitoring.sh" ]]; then
    echo "Ejecutando monitoreo de ejemplo..."
    echo

    # Ejecutar monitoreo básico
    timeout 10s "$SCRIPT_DIR/advanced_monitoring.sh" 2>/dev/null || true

    echo
    echo "✅ Monitoreo de ejemplo completado"
    echo

    # Mostrar algunas métricas recopiladas
    echo "📊 Métricas recopiladas recientemente:"
    sqlite3 /var/lib/advanced_monitoring/metrics.db "SELECT datetime(timestamp, 'localtime') as local_time, metric_type, metric_name, printf('%.2f', value) as value, unit FROM metrics ORDER BY timestamp DESC LIMIT 15;" 2>/dev/null || echo "No se pudieron obtener métricas (base de datos no inicializada)"

else
    echo "❌ Script de monitoreo avanzado no encontrado. Ejecuta primero la instalación."
fi

echo
echo "=========================================="
echo "  ✅ DEMOSTRACIÓN COMPLETADA"
echo "=========================================="
echo
echo "El Sistema de Monitoreo Avanzado está listo para usar."
echo
echo "📖 Para más información detallada, consulta:"
echo "   • ADVANCED_MONITORING_README.md"
echo "   • /etc/advanced_monitoring/config.sh"
echo "   • http://tu-servidor/monitoring/"
echo
echo "🔧 Próximos pasos recomendados:"
echo "   1. Configurar alertas por email y Telegram"
echo "   2. Ajustar umbrales según tu infraestructura"
echo "   3. Configurar backups y monitoreo del propio sistema"
echo "   4. Explorar el dashboard web y personalizarlo"
echo
echo "¡Gracias por usar el Sistema de Monitoreo Avanzado!"
echo
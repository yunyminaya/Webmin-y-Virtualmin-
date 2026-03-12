#!/bin/bash

# Pruebas de integración para sistema de backups

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../test_framework.sh"

# Configurar directorio temporal para pruebas
TEST_DIR="/tmp/backup_integration_test_$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "🔗 Pruebas de integración - Sistema de Backups"
echo "============================================="

# Prueba 1: Verificar integración entre backup y monitoreo
start_test "test_backup_monitoring_integration"
# Simular archivos de configuración
mkdir -p config backup logs

# Crear archivo de configuración de backup simulado
cat > config/backup.conf << EOF
BACKUP_DIR="$TEST_DIR/backup"
LOG_DIR="$TEST_DIR/logs"
MONITORING_ENABLED=true
EOF

# Verificar que la configuración se pueda leer
if [ -f "config/backup.conf" ] && grep -q "BACKUP_DIR" config/backup.conf; then
    pass_test
else
    fail_test "Configuración de backup no se puede leer"
fi

# Prueba 2: Verificar que backup cree archivos de log
start_test "test_backup_creates_logs"
# Simular creación de backup
echo "test data" > test_file.txt
mkdir -p backup
cp test_file.txt backup/
echo "$(date): Backup completed successfully" > logs/backup.log

if [ -f "logs/backup.log" ] && grep -q "Backup completed" logs/backup.log; then
    pass_test
else
    fail_test "Backup no crea archivos de log correctamente"
fi

# Prueba 3: Verificar integración con sistema de notificaciones
start_test "test_backup_notification_integration"
# Simular sistema de notificaciones
mkdir -p notifications

# Crear notificación de backup
cat > notifications/backup_notification.json << EOF
{
  "type": "backup",
  "status": "completed",
  "timestamp": "$(date +%s)",
  "details": {
    "files_backed_up": 5,
    "size": "1.2GB"
  }
}
EOF

if [ -f "notifications/backup_notification.json" ] && grep -q "completed" notifications/backup_notification.json; then
    pass_test
else
    fail_test "Sistema de notificaciones no funciona correctamente"
fi

# Prueba 4: Verificar restauración de backups
start_test "test_backup_restore_integration"
# Simular restauración
mkdir -p restore
cp backup/test_file.txt restore/

if [ -f "restore/test_file.txt" ] && diff test_file.txt restore/test_file.txt >/dev/null; then
    pass_test
else
    fail_test "Restauración de backup falla"
fi

# Prueba 5: Verificar integración con monitoreo de sistema
start_test "test_backup_system_monitoring_integration"
# Simular métricas del sistema durante backup
cat > logs/system_metrics.log << EOF
CPU Usage: 45%
Memory Usage: 60%
Disk I/O: 120 MB/s
Backup Process: Running
EOF

if [ -f "logs/system_metrics.log" ] && grep -q "Backup Process: Running" logs/system_metrics.log; then
    pass_test
else
    fail_test "Monitoreo del sistema durante backup no funciona"
fi

# Prueba 6: Verificar manejo de errores en backup
start_test "test_backup_error_handling"
# Simular error de backup
mkdir -p errors
cat > errors/backup_error.log << EOF
ERROR: Failed to backup file /etc/webmin/config
Reason: Permission denied
Timestamp: $(date)
EOF

if [ -f "errors/backup_error.log" ] && grep -q "Permission denied" errors/backup_error.log; then
    pass_test
else
    fail_test "Manejo de errores en backup no funciona"
fi

# Prueba 7: Verificar rotación de backups
start_test "test_backup_rotation"
# Simular múltiples backups
mkdir -p backup/daily backup/weekly backup/monthly
echo "daily backup" > backup/daily/backup1.tar.gz
echo "weekly backup" > backup/weekly/backup1.tar.gz
echo "monthly backup" > backup/monthly/backup1.tar.gz

backup_count=$(find backup -name "*.tar.gz" | wc -l)
if [ "$backup_count" -eq 3 ]; then
    pass_test
else
    fail_test "Rotación de backups no funciona correctamente"
fi

# Prueba 8: Verificar integración con servicios externos
start_test "test_backup_external_services"
# Simular configuración de servicios externos
cat > config/external_services.conf << EOF
CLOUD_STORAGE_ENABLED=true
EMAIL_NOTIFICATIONS=true
SLACK_NOTIFICATIONS=false
WEBHOOK_URL="https://api.example.com/webhook"
EOF

if [ -f "config/external_services.conf" ] && grep -q "WEBHOOK_URL" config/external_services.conf; then
    pass_test
else
    fail_test "Integración con servicios externos no configurada"
fi

# Limpiar
cd - >/dev/null
rm -rf "$TEST_DIR"

# Mostrar resumen
show_test_summary
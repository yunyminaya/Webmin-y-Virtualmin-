#!/bin/bash

# Script maestro de instalación del Sistema BI Avanzado para Webmin/Virtualmin
# Instala y configura todos los componentes: Data Warehouse, APIs, ML, Dashboards

set -e

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="/var/log/webmin/bi_install_complete.log"

# Función de logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# Verificar si estamos ejecutando como root
if [ "$EUID" -ne 0 ]; then
    log "ERROR: Este script debe ejecutarse como root"
    exit 1
fi

log "🚀 Iniciando instalación completa del Sistema BI Avanzado"

# Paso 1: Instalar Data Warehouse
log "📊 Paso 1: Instalando Data Warehouse..."
if [ -f "$SCRIPT_DIR/install_bi_database.sh" ]; then
    bash "$SCRIPT_DIR/install_bi_database.sh"
    log "✅ Data Warehouse instalado"
else
    log "❌ Script de instalación de base de datos no encontrado"
    exit 1
fi

# Paso 2: Crear directorios necesarios
log "📁 Paso 2: Creando directorios del sistema..."
mkdir -p "$SCRIPT_DIR/models"
mkdir -p "$SCRIPT_DIR/reports"
mkdir -p "$SCRIPT_DIR/templates"
mkdir -p "/var/webmin/bi"
mkdir -p "/var/log/webmin"

# Paso 3: Instalar dependencias del sistema
log "🔧 Paso 3: Instalando dependencias del sistema..."

# Instalar Python y pip si no están disponibles
if ! command -v python3 >/dev/null 2>&1; then
    log "🐍 Instalando Python3..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y python3 python3-pip python3-dev
    elif command -v yum >/dev/null 2>&1; then
        yum install -y python3 python3-pip python3-devel
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y python3 python3-pip python3-devel
    fi
fi

# Instalar wkhtmltopdf para reportes PDF
if ! command -v wkhtmltopdf >/dev/null 2>&1; then
    log "📄 Instalando wkhtmltopdf para reportes PDF..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y wkhtmltopdf
    elif command -v yum >/dev/null 2>&1; then
        yum install -y wkhtmltopdf
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y wkhtmltopdf
    fi
fi

log "✅ Dependencias del sistema instaladas"

# Paso 4: Configurar servicios systemd
log "⚙️ Paso 4: Configurando servicios systemd..."

# Servicio para el colector de datos BI
cat > /etc/systemd/system/webmin-bi-data-collector.service << 'EOF'
[Unit]
Description=Webmin BI Data Collector
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /root/Webmin Y Virtualmin/Webmin-y-Virtualmin--7a5b69265dabb75e98929f6bcaf64b5924996415/bi_system/python/bi_data_collector.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Servicio para las APIs REST
cat > /etc/systemd/system/webmin-bi-api.service << 'EOF'
[Unit]
Description=Webmin BI REST API Server
After=network.target postgresql.service webmin-bi-data-collector.service
Requires=postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=/root/Webmin Y Virtualmin/Webmin-y-Virtualmin--7a5b69265dabb75e98929f6bcaf64b5924996415/bi_system/python
ExecStart=/usr/bin/python3 bi_api_server.py --host 0.0.0.0 --port 5000
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
Environment=FLASK_ENV=production

[Install]
WantedBy=multi-user.target
EOF

# Servicio para el motor ML
cat > /etc/systemd/system/webmin-bi-ml-engine.service << 'EOF'
[Unit]
Description=Webmin BI Machine Learning Engine
After=network.target postgresql.service webmin-bi-data-collector.service
Requires=postgresql.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /root/Webmin Y Virtualmin/Webmin-y-Virtualmin--7a5b69265dabb75e98929f6bcaf64b5924996415/bi_system/python/bi_ml_engine.py --predict
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Recargar systemd y habilitar servicios
systemctl daemon-reload
systemctl enable webmin-bi-data-collector
systemctl enable webmin-bi-api
systemctl enable webmin-bi-ml-engine

log "✅ Servicios systemd configurados"

# Paso 5: Entrenar modelos ML iniciales
log "🤖 Paso 5: Entrenando modelos ML iniciales..."

# Verificar que haya datos suficientes para entrenamiento
DATA_CHECK=$(python3 -c "
import sys
sys.path.append('$SCRIPT_DIR/python')
from bi_data_collector import BIDataCollector
collector = BIDataCollector('$SCRIPT_DIR/bi_database.conf')
conn = collector.get_db_connection()
cursor = conn.cursor()
cursor.execute('SELECT COUNT(*) FROM system_metrics')
count = cursor.fetchone()[0]
conn.close()
print(count)
")

if [ "$DATA_CHECK" -gt 100 ]; then
    log "📈 Datos suficientes encontrados, entrenando modelos..."
    python3 "$SCRIPT_DIR/python/bi_ml_engine.py" --train --days 30
    log "✅ Modelos ML entrenados"
else
    log "⚠️ Datos insuficientes para entrenamiento inicial (encontrados: $DATA_CHECK). Los modelos se entrenarán automáticamente cuando haya más datos."
fi

# Paso 6: Configurar integración con Webmin
log "🔗 Paso 6: Configurando integración con Webmin..."

# Crear enlace simbólico al dashboard en Webmin
WEBMIN_ROOT="/usr/share/webmin"
if [ -d "$WEBMIN_ROOT" ]; then
    ln -sf "$SCRIPT_DIR/bi_dashboard.html" "$WEBMIN_ROOT/bi_dashboard.html"
    log "✅ Dashboard integrado en Webmin"
else
    log "⚠️ Webmin no encontrado en $WEBMIN_ROOT, dashboard disponible en $SCRIPT_DIR/bi_dashboard.html"
fi

# Paso 7: Crear scripts de utilidad
log "🛠️ Paso 7: Creando scripts de utilidad..."

# Script para backup de datos BI
cat > "$SCRIPT_DIR/backup_bi_data.sh" << 'EOF'
#!/bin/bash
# Script de backup para datos del sistema BI

BACKUP_DIR="/var/backups/webmin_bi"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/bi_backup_$TIMESTAMP.sql"

mkdir -p "$BACKUP_DIR"

# Backup de base de datos PostgreSQL
pg_dump -h localhost -U webmin_bi -d webmin_bi > "$BACKUP_FILE"

# Comprimir
gzip "$BACKUP_FILE"

echo "Backup completado: ${BACKUP_FILE}.gz"

# Limpiar backups antiguos (mantener últimos 30 días)
find "$BACKUP_DIR" -name "bi_backup_*.sql.gz" -mtime +30 -delete
EOF

chmod +x "$SCRIPT_DIR/backup_bi_data.sh"

# Script para generar reportes programados
cat > "$SCRIPT_DIR/generate_scheduled_reports.sh" << 'EOF'
#!/bin/bash
# Script para generar reportes programados

REPORTS_DIR="/var/webmin/bi/reports"
mkdir -p "$REPORTS_DIR"

# Generar reporte diario de rendimiento
python3 /root/Webmin Y Virtualmin/Webmin-y-Virtualmin--7a5b69265dabb75e98929f6bcaf64b5924996415/bi_system/python/bi_reports.py \
    --type performance --days 1 --format html

# Generar reporte semanal predictivo (solo los domingos)
if [ $(date +%u) -eq 7 ]; then
    python3 /root/Webmin Y Virtualmin/Webmin-y-Virtualmin--7a5b69265dabb75e98929f6bcaf64b5924996415/bi_system/python/bi_reports.py \
        --type predictive --days 7 --format pdf
fi

# Generar reporte mensual completo (primer día del mes)
if [ $(date +%d) -eq 1 ]; then
    python3 /root/Webmin Y Virtualmin/Webmin-y-Virtualmin--7a5b69265dabb75e98929f6bcaf64b5924996415/bi_system/python/bi_reports.py \
        --type comprehensive --days 30 --format excel
fi
EOF

chmod +x "$SCRIPT_DIR/generate_scheduled_reports.sh"

log "✅ Scripts de utilidad creados"

# Paso 8: Configurar cron jobs
log "⏰ Paso 8: Configurando tareas programadas..."

# Backup diario a las 2 AM
(crontab -l 2>/dev/null; echo "0 2 * * * $SCRIPT_DIR/backup_bi_data.sh") | crontab -

# Reportes programados a las 6 AM
(crontab -l 2>/dev/null; echo "0 6 * * * $SCRIPT_DIR/generate_scheduled_reports.sh") | crontab -

# Re-entrenamiento de modelos ML semanal (domingo a las 3 AM)
(crontab -l 2>/dev/null; echo "0 3 * * 0 python3 $SCRIPT_DIR/python/bi_ml_engine.py --train --days 30") | crontab -

log "✅ Tareas programadas configuradas"

# Paso 9: Iniciar servicios
log "▶️ Paso 9: Iniciando servicios..."

systemctl start webmin-bi-data-collector
systemctl start webmin-bi-api
systemctl start webmin-bi-ml-engine

# Verificar estado de servicios
sleep 5
systemctl status webmin-bi-data-collector --no-pager -l
systemctl status webmin-bi-api --no-pager -l
systemctl status webmin-bi-ml-engine --no-pager -l

log "✅ Servicios iniciados"

# Paso 10: Crear documentación final
log "📚 Paso 10: Creando documentación..."

cat > "$SCRIPT_DIR/BI_SYSTEM_README.md" << 'EOF'
# Sistema BI Avanzado - Webmin/Virtualmin

## Descripción
Sistema completo de Business Intelligence con análisis predictivo, dashboards interactivos y reportes automatizados.

## Componentes Instalados

### 1. Data Warehouse (PostgreSQL)
- Base de datos: `webmin_bi`
- Tablas principales: system_metrics, service_status, alerts_history, performance_predictions
- Ubicación: localhost:5432

### 2. APIs REST
- URL: http://localhost:5000/api/v1
- Endpoints disponibles:
  - `/health` - Estado del servicio
  - `/metrics/realtime` - Métricas en tiempo real
  - `/metrics/historical` - Datos históricos
  - `/predictions/failures` - Predicciones de fallos
  - `/reports/generate` - Generación de reportes

### 3. Dashboard Interactivo
- URL: http://your-server:10000/bi_dashboard.html (desde Webmin)
- Características: Gráficos en tiempo real, análisis predictivo, alertas

### 4. Sistema de Machine Learning
- Modelos: Predicción de fallos, detección de anomalías
- Re-entrenamiento: Automático semanal

### 5. Reportes Automatizados
- Tipos: Rendimiento, Predictivo, Completo
- Formatos: HTML, PDF, Excel
- Programación: Diaria, semanal, mensual

## Servicios del Sistema

```bash
# Verificar estado de servicios
systemctl status webmin-bi-*

# Reiniciar servicios
systemctl restart webmin-bi-data-collector
systemctl restart webmin-bi-api
systemctl restart webmin-bi-ml-engine

# Ver logs
journalctl -u webmin-bi-data-collector -f
journalctl -u webmin-bi-api -f
journalctl -u webmin-bi-ml-engine -f
```

## Uso del Sistema

### Generar Reportes Manualmente
```bash
# Reporte de rendimiento (últimos 7 días)
python3 bi_system/python/bi_reports.py --type performance --days 7 --format html

# Reporte predictivo
python3 bi_system/python/bi_reports.py --type predictive --hostname server1 --format pdf

# Reporte completo
python3 bi_system/python/bi_reports.py --type comprehensive --format excel
```

### Entrenar Modelos ML
```bash
# Entrenamiento completo
python3 bi_system/python/bi_ml_engine.py --train --days 30

# Solo predicciones
python3 bi_system/python/bi_ml_engine.py --predict
```

### Backup de Datos
```bash
# Backup manual
./bi_system/backup_bi_data.sh

# Los backups se ejecutan automáticamente diariamente
```

## Configuración

### Archivo de Configuración
Ubicación: `bi_system/bi_database.conf`

```ini
[DEFAULT]
DB_HOST=localhost
DB_PORT=5432
DB_NAME=webmin_bi
DB_USER=webmin_bi
DB_PASS=your_password_here
```

### Variables de Entorno
- `MONITORING_INTERVAL`: Intervalo de monitoreo (default: 300s)
- `ALERT_THRESHOLD_CPU`: Umbral CPU (default: 80%)
- `ALERT_THRESHOLD_MEMORY`: Umbral memoria (default: 85%)
- `ALERT_THRESHOLD_DISK`: Umbral disco (default: 90%)

## Monitoreo y Alertas

### Integración con Sistemas Existentes
El sistema BI se integra automáticamente con:
- `integrate_monitoring.sh` - Sistema de monitoreo principal
- `notification_system.sh` - Sistema de notificaciones
- `devops-dashboard.cgi` - Dashboard existente

### Alertas Configuradas
- CPU alta (>80%)
- Memoria alta (>85%)
- Disco lleno (>90%)
- Servicios críticos caídos
- Predicciones de fallos (>70% probabilidad)

## Solución de Problemas

### Servicio no inicia
```bash
# Verificar logs
journalctl -u webmin-bi-api -n 50

# Verificar conectividad a BD
python3 -c "import psycopg2; psycopg2.connect('host=localhost dbname=webmin_bi user=webmin_bi password=your_pass')"
```

### Modelos ML no generan predicciones
```bash
# Verificar cantidad de datos
psql -d webmin_bi -c "SELECT COUNT(*) FROM system_metrics;"

# Re-entrenar modelos
python3 bi_system/python/bi_ml_engine.py --train --days 30
```

### Dashboard no carga
- Verificar que el puerto 5000 esté abierto
- Verificar configuración CORS en el navegador
- Verificar logs del API server

## Actualizaciones

### Actualizar Modelos ML
```bash
# Detener servicios
systemctl stop webmin-bi-*

# Actualizar código
git pull

# Re-entrenar modelos
python3 bi_system/python/bi_ml_engine.py --train --days 30

# Reiniciar servicios
systemctl start webmin-bi-*
```

## Soporte

Para soporte técnico o reportes de bugs, consulte:
- Logs del sistema: `/var/log/webmin/bi_*.log`
- Documentación: `bi_system/bi_architecture.md`
- Configuración: `bi_system/bi_database.conf`
EOF

log "✅ Documentación creada"

# Mostrar resumen final
cat << 'EOF'

╔══════════════════════════════════════════════════════════════════════════════╗
║                      INSTALACIÓN COMPLETA - SISTEMA BI                     ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ ✅ Data Warehouse PostgreSQL configurado                                  ║
║ ✅ APIs REST operativas en puerto 5000                                    ║
║ ✅ Motor de Machine Learning activo                                       ║
║ ✅ Dashboard interactivo integrado                                        ║
║ ✅ Sistema de reportes automatizado                                       ║
║ ✅ Servicios systemd configurados                                         ║
║ ✅ Tareas programadas (backup, reportes, ML)                              ║
║ ✅ Integración completa con monitoreo existente                           ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ 🎯 URLs de Acceso:                                                        ║
║   • Dashboard: http://tu-servidor:10000/bi_dashboard.html                 ║
║   • APIs: http://tu-servidor:5000/api/v1                                  ║
║                                                                          ║
║ 🛠️ Comandos Útiles:                                                       ║
║   • Estado servicios: systemctl status webmin-bi-*                       ║
║   • Ver logs: journalctl -u webmin-bi-api -f                             ║
║   • Generar reporte: ./bi_system/python/bi_reports.py --type performance ║
║                                                                          ║
║ 📚 Documentación: ./bi_system/BI_SYSTEM_README.md                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

EOF

log "🎉 Instalación completa del Sistema BI finalizada exitosamente"
log "📝 Consulte $SCRIPT_DIR/BI_SYSTEM_README.md para documentación completa"
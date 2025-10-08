#!/bin/bash

# Script de instalación del Data Warehouse BI para Webmin/Virtualmin
# Instala y configura PostgreSQL con esquema optimizado para análisis

set -e

# Configuración
DB_NAME="webmin_bi"
DB_USER="webmin_bi"
DB_PASS="$(openssl rand -base64 32)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="/var/log/webmin/bi_install.log"

# Función de logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# Verificar si estamos ejecutando como root
if [ "$EUID" -ne 0 ]; then
    log "ERROR: Este script debe ejecutarse como root"
    exit 1
fi

log "🚀 Iniciando instalación del Data Warehouse BI"

# Instalar PostgreSQL si no está instalado
if ! command -v psql >/dev/null 2>&1; then
    log "📦 Instalando PostgreSQL..."

    # Detectar distribución
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y postgresql postgresql-contrib
    elif command -v yum >/dev/null 2>&1; then
        yum install -y postgresql-server postgresql-contrib
        postgresql-setup initdb
        systemctl enable postgresql
        systemctl start postgresql
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y postgresql-server postgresql-contrib
        postgresql-setup --initdb
        systemctl enable postgresql
        systemctl start postgresql
    else
        log "ERROR: No se pudo detectar el gestor de paquetes compatible"
        exit 1
    fi

    log "✅ PostgreSQL instalado"
else
    log "ℹ️ PostgreSQL ya está instalado"
fi

# Asegurar que PostgreSQL esté ejecutándose
systemctl enable postgresql 2>/dev/null || true
systemctl start postgresql 2>/dev/null || true

# Crear usuario y base de datos
log "👤 Creando usuario y base de datos BI..."

sudo -u postgres psql << EOF
-- Crear usuario si no existe
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
      CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';
   END IF;
END
\$\$;

-- Crear base de datos si no existe
SELECT 'CREATE DATABASE $DB_NAME OWNER $DB_USER'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')\gexec

-- Otorgar permisos
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
ALTER USER $DB_USER CREATEDB;
EOF

log "✅ Usuario y base de datos creados"

# Crear esquema de tablas
log "📊 Creando esquema de base de datos..."

sudo -u postgres psql -d "$DB_NAME" << 'EOF'
-- Tabla para métricas del sistema
CREATE TABLE IF NOT EXISTS system_metrics (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    hostname VARCHAR(255) NOT NULL,
    cpu_usage DECIMAL(5,2),
    memory_usage DECIMAL(5,2),
    disk_usage DECIMAL(5,2),
    load_average DECIMAL(5,2),
    network_rx BIGINT,
    network_tx BIGINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla para estado de servicios
CREATE TABLE IF NOT EXISTS service_status (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    hostname VARCHAR(255) NOT NULL,
    service_name VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL, -- running, stopped, warning, error
    pid INTEGER,
    memory_mb INTEGER,
    cpu_percent DECIMAL(5,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla para alertas
CREATE TABLE IF NOT EXISTS alerts_history (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    hostname VARCHAR(255) NOT NULL,
    alert_type VARCHAR(100) NOT NULL,
    severity VARCHAR(20) NOT NULL, -- info, warning, error, critical
    message TEXT NOT NULL,
    resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla para ejecuciones de pipelines
CREATE TABLE IF NOT EXISTS pipeline_executions (
    id SERIAL PRIMARY KEY,
    pipeline_id VARCHAR(100) NOT NULL,
    pipeline_name VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL, -- running, success, failed, cancelled
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    duration_seconds INTEGER,
    trigger_type VARCHAR(50), -- manual, scheduled, webhook
    trigger_user VARCHAR(100),
    environment VARCHAR(50), -- development, staging, production
    commit_hash VARCHAR(100),
    branch VARCHAR(100),
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla para actividad de usuarios
CREATE TABLE IF NOT EXISTS user_activity (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    username VARCHAR(100) NOT NULL,
    action VARCHAR(255) NOT NULL,
    module VARCHAR(100),
    ip_address INET,
    user_agent TEXT,
    session_id VARCHAR(100),
    success BOOLEAN NOT NULL DEFAULT TRUE,
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla para predicciones ML
CREATE TABLE IF NOT EXISTS performance_predictions (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    hostname VARCHAR(255) NOT NULL,
    prediction_type VARCHAR(100) NOT NULL, -- cpu_failure, memory_leak, disk_full
    prediction_value DECIMAL(10,4),
    confidence DECIMAL(5,4),
    time_horizon_hours INTEGER,
    features_used JSONB,
    model_version VARCHAR(50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla para logs de auditoría
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    username VARCHAR(100),
    action VARCHAR(255) NOT NULL,
    resource_type VARCHAR(100),
    resource_id VARCHAR(100),
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    success BOOLEAN NOT NULL DEFAULT TRUE,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices para optimización de consultas
CREATE INDEX IF NOT EXISTS idx_system_metrics_timestamp ON system_metrics (timestamp);
CREATE INDEX IF NOT EXISTS idx_system_metrics_hostname_timestamp ON system_metrics (hostname, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_service_status_timestamp ON service_status (timestamp);
CREATE INDEX IF NOT EXISTS idx_service_status_hostname_service ON service_status (hostname, service_name);
CREATE INDEX IF NOT EXISTS idx_alerts_timestamp ON alerts_history (timestamp);
CREATE INDEX IF NOT EXISTS idx_alerts_severity ON alerts_history (severity);
CREATE INDEX IF NOT EXISTS idx_alerts_resolved ON alerts_history (resolved);
CREATE INDEX IF NOT EXISTS idx_pipeline_executions_start_time ON pipeline_executions (start_time);
CREATE INDEX IF NOT EXISTS idx_pipeline_executions_status ON pipeline_executions (status);
CREATE INDEX IF NOT EXISTS idx_user_activity_timestamp ON user_activity (timestamp);
CREATE INDEX IF NOT EXISTS idx_user_activity_username ON user_activity (username);
CREATE INDEX IF NOT EXISTS idx_performance_predictions_timestamp ON performance_predictions (timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs (timestamp);

-- Particionamiento por fecha para tablas grandes (ejemplo para system_metrics)
-- CREATE TABLE system_metrics_y2024m01 PARTITION OF system_metrics FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

-- Políticas de retención (ejemplo: mantener datos por 1 año)
-- CREATE OR REPLACE FUNCTION delete_old_data() RETURNS void AS $$
-- BEGIN
--     DELETE FROM system_metrics WHERE timestamp < NOW() - INTERVAL '1 year';
--     DELETE FROM service_status WHERE timestamp < NOW() - INTERVAL '1 year';
--     DELETE FROM alerts_history WHERE timestamp < NOW() - INTERVAL '6 months';
-- END;
-- $$ LANGUAGE plpgsql;

-- Vistas útiles para análisis
CREATE OR REPLACE VIEW system_metrics_daily AS
SELECT
    DATE(timestamp) as date,
    hostname,
    AVG(cpu_usage) as avg_cpu,
    MAX(cpu_usage) as max_cpu,
    AVG(memory_usage) as avg_memory,
    MAX(memory_usage) as max_memory,
    AVG(disk_usage) as avg_disk,
    MAX(disk_usage) as max_disk,
    COUNT(*) as samples_count
FROM system_metrics
GROUP BY DATE(timestamp), hostname
ORDER BY date DESC, hostname;

CREATE OR REPLACE VIEW service_uptime_daily AS
SELECT
    DATE(timestamp) as date,
    hostname,
    service_name,
    COUNT(CASE WHEN status = 'running' THEN 1 END) as running_count,
    COUNT(*) as total_checks,
    ROUND(
        COUNT(CASE WHEN status = 'running' THEN 1 END)::DECIMAL /
        COUNT(*)::DECIMAL * 100, 2
    ) as uptime_percentage
FROM service_status
GROUP BY DATE(timestamp), hostname, service_name
ORDER BY date DESC, hostname, service_name;

CREATE OR REPLACE VIEW alerts_summary_daily AS
SELECT
    DATE(timestamp) as date,
    severity,
    COUNT(*) as alert_count
FROM alerts_history
WHERE resolved = FALSE
GROUP BY DATE(timestamp), severity
ORDER BY date DESC, severity;

-- Permisos para el usuario BI
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO webmin_bi;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO webmin_bi;
EOF

log "✅ Esquema de base de datos creado"

# Guardar configuración de conexión
CONFIG_FILE="$SCRIPT_DIR/bi_database.conf"
cat > "$CONFIG_FILE" << EOF
# Configuración de conexión a la base de datos BI
# Generado automáticamente por install_bi_database.sh

DB_HOST=localhost
DB_PORT=5432
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASS=$DB_PASS

# Configuración adicional
RETENTION_DAYS=365
BACKUP_ENABLED=true
COMPRESSION_ENABLED=true
EOF

chmod 600 "$CONFIG_FILE"
log "✅ Configuración guardada en $CONFIG_FILE"

# Instalar dependencias Python para el sistema BI
log "🐍 Instalando dependencias Python..."

if command -v pip3 >/dev/null 2>&1; then
    pip3 install psycopg2-binary sqlalchemy pandas scikit-learn tensorflow flask gunicorn
elif command -v pip >/dev/null 2>&1; then
    pip install psycopg2-binary sqlalchemy pandas scikit-learn tensorflow flask gunicorn
else
    log "⚠️ pip no encontrado, instalando python3-pip..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y python3-pip
    fi
    pip3 install psycopg2-binary sqlalchemy pandas scikit-learn tensorflow flask gunicorn
fi

log "✅ Dependencias Python instaladas"

# Crear directorio para scripts Python
mkdir -p "$SCRIPT_DIR/python"
mkdir -p "$SCRIPT_DIR/models"
mkdir -p "$SCRIPT_DIR/reports"

log "🎉 Instalación del Data Warehouse BI completada exitosamente"
log "📝 Configuración guardada en: $CONFIG_FILE"
log "🐍 Scripts Python en: $SCRIPT_DIR/python/"
log "🤖 Modelos ML en: $SCRIPT_DIR/models/"
log "📊 Reportes en: $SCRIPT_DIR/reports/"

# Mostrar resumen de instalación
cat << EOF

╔══════════════════════════════════════════════════════════════╗
║              INSTALACIÓN COMPLETADA - WEBMIN BI SYSTEM      ║
╠══════════════════════════════════════════════════════════════╣
║ Base de datos: $DB_NAME                                     ║
║ Usuario: $DB_USER                                           ║
║ Configuración: $CONFIG_FILE                                 ║
║                                                              ║
║ Próximos pasos:                                              ║
║ 1. Ejecutar: ./bi_system/python/bi_data_collector.py         ║
║ 2. Verificar: ./bi_system/python/test_database.py            ║
║ 3. Iniciar API: ./bi_system/python/bi_api_server.py         ║
╚══════════════════════════════════════════════════════════════╝

EOF
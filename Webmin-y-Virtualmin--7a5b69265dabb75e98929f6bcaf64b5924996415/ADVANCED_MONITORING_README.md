# Sistema de Monitoreo Avanzado para Webmin y Virtualmin

## 📊 Descripción General

El Sistema de Monitoreo Avanzado es una solución enterprise-grade completa para monitorear servidores Webmin y Virtualmin en tiempo real. Proporciona métricas detalladas, alertas inteligentes, dashboards interactivos y análisis predictivo.

## ✨ Características Principales

### 🔍 Monitoreo en Tiempo Real
- **CPU**: Uso total y por núcleo, load average
- **Memoria**: RAM, swap, memoria disponible
- **Disco**: Uso por partición, I/O, espacio total/usado
- **Red**: Tráfico RX/TX, conexiones activas, interfaces
- **Servicios**: Estado de servicios críticos (Webmin, Apache, MySQL, etc.)

### 🚨 Sistema de Alertas Inteligente
- **Alertas por Email**: Notificaciones automáticas por correo
- **Alertas por Telegram**: Mensajes instantáneos a bots/canales
- **Umbrales Configurables**: CPU, memoria, disco personalizables
- **Escalado de Severidad**: Warning, Critical, Info

### 📈 Dashboards Web Interactivos
- **Gráficos en Tiempo Real**: Charts.js con actualización automática
- **Múltiples Vistas**: Overview, Performance, Services, Alerts
- **Responsive Design**: Compatible con móviles y tablets
- **Datos Históricos**: Tendencias de 24 horas

### 🗄️ Almacenamiento Histórico
- **Base de Datos SQLite**: Almacenamiento eficiente y rápido
- **Métricas Históricas**: Datos de hasta 90 días
- **Consultas Avanzadas**: Análisis de tendencias y patrones
- **Backup Automático**: Respaldos diarios con rotación

### 🤖 Detección de Anomalías
- **Machine Learning Básico**: Algoritmos estadísticos
- **Detección Automática**: Z-score y desviación estándar
- **Alertas Predictivas**: Identificación de tendencias anómalas
- **Confianza Configurable**: Umbrales de detección ajustables

## 🏗️ Arquitectura del Sistema

```
advanced_monitoring.sh (Script Principal)
├── monitor_cpu()          # Monitoreo de CPU
├── monitor_memory()       # Monitoreo de memoria
├── monitor_disk()         # Monitoreo de disco
├── monitor_network()      # Monitoreo de red
├── monitor_services()     # Monitoreo de servicios
├── monitor_virtualmin()   # Monitoreo específico Virtualmin
├── detect_anomalies()     # Detección de anomalías
├── send_email_alert()     # Alertas por email
├── send_telegram_alert()  # Alertas por Telegram
├── generate_dashboard()   # Generador de dashboard
└── generate_json_data()   # Datos para gráficos

Base de Datos (SQLite)
├── metrics              # Métricas históricas
├── alerts               # Historial de alertas
└── anomalies            # Anomalías detectadas

Dashboard Web
├── index.html           # Dashboard principal
├── data.json            # Datos en tiempo real
└── API RESTful          # Endpoints para datos
```

## 📋 Requisitos del Sistema

### Dependencias del Sistema
- **Ubuntu/Debian**: `apt-get install sqlite3 python3 python3-pip apache2 php`
- **CentOS/RHEL**: `yum install sqlite python3 python3-pip httpd php`
- **macOS**: `brew install sqlite python3 apache2 php`

### Dependencias Python
```bash
pip3 install requests numpy pandas scikit-learn matplotlib
```

### Dependencias Node.js (Opcional)
```bash
npm install -g pm2 chart.js luxon
```

## 🚀 Instalación

### Instalación Automática
```bash
# Descargar e instalar
sudo ./install_advanced_monitoring.sh
```

### Instalación Manual
```bash
# 1. Instalar dependencias
sudo ./enterprise_monitoring_setup.sh

# 2. Configurar el sistema
sudo ./advanced_monitoring.sh --setup

# 3. Iniciar el servicio
sudo systemctl enable --now advanced-monitoring
```

## ⚙️ Configuración

### Archivo de Configuración Principal
Editar `/etc/advanced_monitoring/config.sh`:

```bash
# Intervalo de monitoreo (segundos)
MONITOR_INTERVAL=30

# Alertas por email
ENABLE_EMAIL_ALERTS=true
EMAIL_RECIPIENT="admin@tu-dominio.com"

# Alertas por Telegram
ENABLE_TELEGRAM_ALERTS=true
TELEGRAM_BOT_TOKEN="tu_bot_token_aqui"
TELEGRAM_CHAT_ID="tu_chat_id_aqui"

# Umbrales de alerta
CPU_WARNING=80
CPU_CRITICAL=95
MEM_WARNING=85
MEM_CRITICAL=95
DISK_WARNING=85
DISK_CRITICAL=95

# Características avanzadas
ANOMALY_DETECTION=true
HISTORICAL_DATA=true
ANOMALY_THRESHOLD=2.0
```

### Configuración de Email
Para alertas por email, configurar ssmtp:

```bash
sudo nano /etc/ssmtp/ssmtp.conf
```

```ini
root=postmaster
mailhub=smtp.gmail.com:587
AuthUser=tu-email@gmail.com
AuthPass=tu-app-password
UseSTARTTLS=YES
```

### Configuración de Telegram

1. **Crear un Bot**:
   - Ir a [@BotFather](https://t.me/botfather) en Telegram
   - Enviar `/newbot` y seguir las instrucciones
   - Guardar el token proporcionado

2. **Crear un Canal/Grupo**:
   - Crear un canal privado o grupo
   - Agregar el bot como administrador

3. **Obtener Chat ID**:
   - Enviar un mensaje al bot
   - Visitar `https://api.telegram.org/bot<TOKEN>/getUpdates`
   - Buscar el `"chat":{"id":XXXXX}`

4. **Configurar en el archivo**:
   ```bash
   TELEGRAM_BOT_TOKEN="tu_token_aqui"
   TELEGRAM_CHAT_ID="tu_chat_id_aqui"
   ```

## 📊 Uso del Sistema

### Comandos Básicos

```bash
# Monitoreo único
sudo ./advanced_monitoring.sh

# Monitoreo continuo
sudo ./advanced_monitoring.sh --continuous

# Monitoreo continuo con intervalo personalizado
sudo ./advanced_monitoring.sh -c -i 60

# Generar dashboard manualmente
sudo ./advanced_monitoring.sh --dashboard

# Configurar el sistema
sudo ./advanced_monitoring.sh --setup
```

### Gestión del Servicio

```bash
# Estado del servicio
sudo systemctl status advanced-monitoring

# Iniciar servicio
sudo systemctl start advanced-monitoring

# Detener servicio
sudo systemctl stop advanced-monitoring

# Reiniciar servicio
sudo systemctl restart advanced-monitoring

# Habilitar auto-inicio
sudo systemctl enable advanced-monitoring

# Ver logs del servicio
sudo journalctl -u advanced-monitoring -f
```

### Dashboard Web

Acceder al dashboard en: `http://tu-servidor/monitoring/`

**Secciones del Dashboard**:
- **Vista General**: CPU, Memoria, Disco, Red
- **Performance**: Detalles técnicos y gráficos avanzados
- **Servicios**: Estado de servicios y métricas Virtualmin
- **Alertas**: Historial de alertas y notificaciones

### Consultas a la Base de Datos

```bash
# Conectar a la base de datos
sqlite3 /var/lib/advanced_monitoring/metrics.db

# Ver métricas recientes
SELECT * FROM metrics ORDER BY timestamp DESC LIMIT 10;

# Ver alertas activas
SELECT * FROM alerts WHERE resolved = 0;

# Ver anomalías recientes
SELECT * FROM anomalies ORDER BY timestamp DESC LIMIT 10;

# Uso de CPU en las últimas 24 horas
SELECT strftime('%H:%M', timestamp) as time, value
FROM metrics
WHERE metric_name = 'cpu_total'
AND timestamp >= datetime('now', '-1 day')
ORDER BY timestamp;
```

## 🔧 API REST (Próximamente)

El sistema incluirá endpoints RESTful para integración con otras herramientas:

```
GET  /api/metrics/current          # Métricas actuales
GET  /api/metrics/history/:metric  # Historial de métricas
GET  /api/alerts/active            # Alertas activas
POST /api/alerts/:id/resolve       # Resolver alerta
GET  /api/anomalies/recent         # Anomalías recientes
```

## 📈 Métricas Monitoreadas

### CPU
- `cpu_total`: Uso total de CPU (%)
- `cpu_core_X`: Uso por núcleo individual (%)
- `cpu_load_1/5/15`: Load average 1/5/15 minutos

### Memoria
- `memory_total`: Memoria total (MB)
- `memory_used`: Memoria usada (MB)
- `memory_free`: Memoria libre (MB)
- `memory_available`: Memoria disponible (MB)
- `memory_usage_percent`: Uso de memoria (%)
- `memory_swap_total/used/usage`: Métricas de swap

### Disco
- `disk_/dev/sdX_total/used/usage`: Espacio por partición
- `disk_io_total`: I/O total (KB/s)

### Red
- `network_eth0_rx/tx`: Tráfico por interfaz (bytes)
- `network_total_rx/tx`: Tráfico total (bytes)
- `network_active_connections`: Conexiones activas

### Servicios
- `service_webmin/apache2/mysql/postfix/dovecot/sshd/named`: Estado (0=stopped, 1=running)

### Virtualmin
- `virtualmin_processes`: Procesos Webmin activos
- `virtualmin_connections`: Conexiones activas a Webmin
- `virtualmin_domains`: Número de dominios
- `virtualmin_mysql_connections`: Conexiones activas a MySQL

## 🚨 Sistema de Alertas

### Tipos de Alertas
- **CPU_CRITICAL**: Uso de CPU por encima del umbral crítico
- **MEMORY_CRITICAL**: Uso de memoria por encima del umbral crítico
- **DISK_CRITICAL**: Uso de disco por encima del umbral crítico
- **SERVICE_DOWN**: Servicio crítico detenido
- **ANOMALY_DETECTED**: Anomalía detectada en métricas

### Severidades
- **INFO**: Información general
- **WARNING**: Advertencia, requiere atención
- **CRITICAL**: Crítico, requiere acción inmediata

### Formato de Alertas por Email
```
Asunto: [CRITICAL] CPU_CRITICAL

🚨 ALERTA CRITICAL: CPU_CRITICAL
Uso de CPU crítico: 96.5% (umbral: 95%)
Timestamp: 2025-01-15 14:30:25

Servidor: tu-servidor.com
Sistema: Ubuntu 22.04 LTS
```

### Formato de Alertas por Telegram
```
🚨 ALERTA CRITICAL: CPU_CRITICAL
Uso de CPU crítico: 96.5% (umbral: 95%)
Timestamp: 2025-01-15 14:30:25
```

## 🤖 Detección de Anomalías

### Algoritmo Utilizado
- **Z-Score**: `(valor_actual - media) / desviación_estándar`
- **Umbral**: Configurable (default: 2.0)
- **Ventana**: Últimas 24 horas de datos

### Ejemplo de Detección
```bash
# Si el CPU normalmente usa 45% ± 10%
# Y repentinamente usa 85%
# Z-Score = (85 - 45) / 10 = 4.0 > 2.0
# → ANOMALÍA DETECTADA
```

### Configuración de Anomalías
```bash
# En config.sh
ANOMALY_DETECTION=true
ANOMALY_THRESHOLD=2.0  # Desviación estándar
```

## 🔄 Mantenimiento del Sistema

### Backup Automático
- **Frecuencia**: Diario a las 2:00 AM
- **Ubicación**: `/var/backups/monitoring/`
- **Retención**: 7 días
- **Contenido**: Configuración, base de datos, logs

### Limpieza Automática
- **Frecuencia**: Semanal los domingos a las 3:00 AM
- **Logs**: Mantener 30 días
- **Métricas**: Mantener 90 días
- **Alertas resueltas**: Mantener 90 días

### Optimización de Base de Datos
```bash
# Optimización manual
sudo ./maintenance_monitoring.sh
```

## 🐛 Solución de Problemas

### Servicio no inicia
```bash
# Verificar estado
sudo systemctl status advanced-monitoring

# Ver logs detallados
sudo journalctl -u advanced-monitoring -n 50

# Verificar permisos
ls -la /etc/advanced_monitoring/
ls -la /var/lib/advanced_monitoring/
```

### Dashboard no carga
```bash
# Verificar archivos web
ls -la /var/www/html/monitoring/

# Verificar permisos Apache
sudo apache2ctl configtest

# Verificar logs de Apache
sudo tail -f /var/log/apache2/error.log
```

### Alertas no se envían
```bash
# Probar email
echo "Test" | mail -s "Test Alert" admin@localhost

# Probar Telegram
curl "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$TELEGRAM_CHAT_ID&text=Test"

# Verificar configuración
cat /etc/advanced_monitoring/config.sh
```

### Base de datos corrupta
```bash
# Backup actual
cp /var/lib/advanced_monitoring/metrics.db /var/lib/advanced_monitoring/metrics.db.backup

# Recrear base de datos
sudo ./advanced_monitoring.sh --setup

# Restaurar desde backup si es necesario
```

## 📚 Integración con Scripts Existentes

### Con monitor_sistema.sh
```bash
# Usar sistema avanzado desde el script básico
./monitor_sistema.sh --advanced

# O configurar para usar avanzado por defecto
echo 'USE_ADVANCED=true' >> /etc/advanced_monitoring/config.sh
```

### Con enterprise_monitoring_setup.sh
El script de configuración enterprise ya instala las dependencias básicas necesarias para el sistema avanzado.

## 🔮 Roadmap y Mejoras Futuras

### Próximas Versiones
- **API RESTful completa**
- **Integración con Prometheus/Grafana**
- **Machine Learning avanzado**
- **Alertas predictivas**
- **Monitoreo distribuido**
- **Métricas personalizadas**
- **Integración con Nagios/Icinga**

### Mejoras Planeadas
- **Contenedores Docker**
- **Kubernetes integration**
- **Multi-tenancy**
- **High availability**
- **Custom plugins**
- **Mobile app**

## 📞 Soporte

### Documentación Adicional
- [Guía de Configuración Avanzada](docs/advanced_config.md)
- [API Reference](docs/api_reference.md)
- [Troubleshooting Guide](docs/troubleshooting.md)

### Comunidad
- **GitHub Issues**: Reportar bugs y solicitar features
- **Discussions**: Preguntas y soporte de la comunidad
- **Wiki**: Guías y tutoriales adicionales

### Soporte Empresarial
Para soporte prioritario y características enterprise adicionales, contactar al equipo de desarrollo.

## 📄 Licencia

Este proyecto está licenciado bajo la GNU General Public License v3.0.

## 🙏 Contribuciones

Las contribuciones son bienvenidas. Por favor, leer las guías de contribución antes de enviar pull requests.

---

**Desarrollado con ❤️ para la comunidad Webmin/Virtualmin**
# 🛡️ Sistema Completo de Detección y Prevención de Intrusiones (IDS/IPS)
## Para Webmin y Virtualmin

### 📋 Resumen Ejecutivo

Este sistema implementa una solución completa de seguridad para servidores Webmin/Virtualmin, proporcionando protección avanzada contra amenazas modernas incluyendo ataques de fuerza bruta, inyección SQL, XSS, DDoS y otras vulnerabilidades específicas de paneles de control.

---

## 🎯 Funcionalidades Implementadas

### 1. 🔐 **Detección de Autenticación Webmin/Virtualmin**
- **Monitoreo específico** de logs de Webmin (`/var/webmin/miniserv.log`)
- **Detección de intentos de login fallidos** con umbrales configurables
- **Protección contra fuerza bruta** en paneles de control
- **Bloqueo automático** de IPs sospechosas

### 2. 💉 **Prevención de Inyección SQL**
- **Patrones avanzados** de detección SQLi
- **Monitoreo en tiempo real** de requests HTTP
- **Bloqueo automático** de IPs con intentos maliciosos
- **Umbrales configurables** por severidad

### 3. 🕷️ **Protección contra XSS (Cross-Site Scripting)**
- **Detección de payloads XSS** en requests
- **Filtrado de scripts maliciosos** y iframes
- **Prevención de ataques de inyección** de código
- **Alertas automáticas** por detección

### 4. 🔨 **Sistema Anti-Fuerza Bruta**
- **Monitoreo de logs de autenticación** (`/var/log/auth.log`, `/var/log/secure`)
- **Detección de patrones de ataque** automatizados
- **Bloqueo progresivo** basado en frecuencia
- **Integración con fail2ban** para acciones avanzadas

### 5. 📡 **Protección de APIs y Endpoints**
- **Monitoreo de APIs Webmin/Virtualmin**
- **Detección de abuso de endpoints**
- **Rate limiting** automático
- **Logs detallados** de actividad sospechosa

### 6. 🚫 **Prevención DDoS**
- **Detección de ataques masivos** de denegación de servicio
- **Monitoreo de conexiones simultáneas**
- **Protección SYN flood** avanzada
- **Mitigación automática** con iptables

### 7. 📊 **Dashboard Web en Tiempo Real**
- **Interfaz moderna** con diseño Webmin/Virtualmin
- **Gráficos interactivos** de amenazas
- **Estadísticas en vivo** del sistema
- **Controles de emergencia** integrados

### 8. 🔔 **Sistema de Alertas Multi-Canal**
- **Email** - Notificaciones por correo
- **Telegram** - Alertas instantáneas
- **Slack** - Integración con equipos
- **Discord** - Webhooks personalizados
- **Pushover** - Notificaciones móviles

### 9. ⚙️ **Reglas Personalizables**
- **Gestor de reglas** completo
- **Umbrales configurables** por tipo de amenaza
- **Whitelist/Blacklist** de IPs
- **Importación/Exportación** de configuraciones
- **Validación automática** de reglas

### 10. 🤖 **Monitoreo Inteligente**
- **Análisis de patrones** de tráfico
- **Detección de anomalías** en tiempo real
- **Correlación de eventos** de seguridad
- **Reportes automáticos** de amenazas

---

## 🏗️ Arquitectura del Sistema

```
Webmin/Virtualmin IDS/IPS
├── 🔧 Sistema Maestro (webmin_virtualmin_ids_master.sh)
│   ├── Instalación completa
│   ├── Gestión unificada
│   └── Servicios systemd
├── 🛡️ Fail2Ban Avanzado (install_webmin_virtualmin_ids.sh)
│   ├── Reglas específicas Webmin/Virtualmin
│   ├── Filtros personalizados
│   └── Acciones automáticas
├── 👁️ Monitor Continuo (webmin_virtualmin_monitor.sh)
│   ├── Detección de patrones
│   ├── Análisis de logs
│   └── Bloqueo automático
├── 📢 Sistema de Alertas (alert_system.sh)
│   ├── Múltiples canales
│   ├── Configuración flexible
│   └── Templates personalizables
├── ⚙️ Gestor de Reglas (custom_rules_manager.sh)
│   ├── Reglas personalizables
│   ├── Umbrales dinámicos
│   └── Gestión de listas
└── 📊 Dashboard Web (ids_dashboard.html)
    ├── Visualización en tiempo real
    ├── Controles interactivos
    └── Reportes gráficos
```

---

## 📦 Instalación y Configuración

### Instalación Automática

```bash
# Descargar y ejecutar el instalador maestro
sudo bash webmin_virtualmin_ids_master.sh install
```

### Instalación Manual (Componentes Individuales)

```bash
# 1. Instalar fail2ban con reglas específicas
sudo bash install_webmin_virtualmin_ids.sh

# 2. Configurar sistema de alertas
sudo bash alert_system.sh init

# 3. Inicializar gestor de reglas
sudo bash custom_rules_manager.sh init

# 4. Iniciar monitoreo
sudo bash webmin_virtualmin_monitor.sh start
```

### Configuración Inicial

```bash
# Configurar alertas (recomendado)
sudo bash alert_system.sh config

# Personalizar reglas de detección
sudo bash custom_rules_manager.sh list

# Agregar regla personalizada (ejemplo)
sudo bash custom_rules_manager.sh add "Ataque Personalizado" "patron.*malicioso" 1 "block_ip,send_alert" 300 "HIGH"
```

---

## 🎮 Uso y Gestión

### Comandos Principales

```bash
# Estado del sistema
sudo bash webmin_virtualmin_ids_master.sh status

# Iniciar servicios
sudo bash webmin_virtualmin_ids_master.sh start

# Detener servicios
sudo bash webmin_virtualmin_ids_master.sh stop

# Ver logs en tiempo real
tail -f /etc/webmin-virtualmin-ids/logs/monitor.log

# Ver amenazas detectadas
tail -f /etc/webmin-virtualmin-ids/logs/alerts.log
```

### Gestión de Reglas

```bash
# Listar reglas activas
sudo bash custom_rules_manager.sh list

# Modificar umbral
sudo bash custom_rules_manager.sh threshold sql_injection_threshold 5

# Agregar IP a whitelist
sudo bash custom_rules_manager.sh whitelist 192.168.1.100

# Exportar configuración
sudo bash custom_rules_manager.sh export json reglas_backup.json
```

### Gestión de Alertas

```bash
# Configurar email
sudo bash alert_system.sh config

# Probar alertas
sudo bash alert_system.sh test email

# Enviar alerta manual
sudo bash alert_system.sh send "Prueba" "Mensaje de prueba" "LOW"
```

---

## 📊 Dashboard y Monitoreo

### Acceso al Dashboard

El dashboard está disponible en:
```
file:///etc/webmin-virtualmin-ids/ids_dashboard.html
```

### Métricas Disponibles

- **Estado del Sistema**: Activo/Inactivo
- **Amenazas Hoy**: Número total de detecciones
- **IPs Bloqueadas**: Contador de bloqueos automáticos
- **Conexiones Activas**: Tráfico actual
- **Uso de CPU/Memoria**: Rendimiento del sistema
- **Amenazas por Tipo**: Gráfico de distribución
- **Actividad de Red**: Tendencias de tráfico

### Controles de Emergencia

- **Verificación del Sistema**: Diagnóstico completo
- **Visualización de Logs**: Acceso a archivos de log
- **Gestión de Reglas**: Interfaz de configuración
- **Configuración de Alertas**: Panel de notificaciones
- **Parada de Emergencia**: Desactivación de protección

---

## 🔧 Configuración Avanzada

### Archivo de Configuración Principal

Ubicación: `/etc/webmin-virtualmin-ids/config/system.conf`

```ini
[SYSTEM]
name=Webmin/Virtualmin IDS/IPS
version=1.0.0
status=installed

[MONITORING]
enabled=true
interval=60
log_level=INFO

[ALERTS]
enabled=true
channels=email,telegram
min_level=MEDIUM
```

### Configuración de Alertas

Ubicación: `/etc/webmin-virtualmin-ids/alerts/alert_config.conf`

```bash
# Configuración de email
ALERT_EMAIL="admin@tu-servidor.com"
EMAIL_SUBJECT_PREFIX="[IDS-ALERT]"

# Configuración de Telegram
TELEGRAM_BOT_TOKEN="tu_bot_token"
TELEGRAM_CHAT_ID="tu_chat_id"

# Canales habilitados
ENABLED_CHANNELS="email,telegram"
MIN_ALERT_LEVEL="HIGH"
```

### Reglas Personalizadas

Ubicación: `/etc/webmin-virtualmin-ids/rules/custom_rules.conf`

```ini
[THRESHOLDS]
sql_injection_threshold=2
xss_threshold=2
bruteforce_threshold=5

[CUSTOM_RULES]
rule1_name=Ataque SQL Avanzado
rule1_pattern=union.*select.*information_schema
rule1_threshold=1
rule1_action=block_ip,send_alert,email_admin
rule1_ban_time=7200
rule1_alert_level=CRITICAL
```

---

## 📋 Logs y Reportes

### Ubicaciones de Logs

- **Log principal**: `/etc/webmin-virtualmin-ids/logs/master.log`
- **Log de monitoreo**: `/etc/webmin-virtualmin-ids/logs/monitor.log`
- **Log de alertas**: `/etc/webmin-virtualmin-ids/logs/alerts.log`
- **Base de amenazas**: `/etc/webmin-virtualmin-ids/threats.db`

### Formato de Logs

```
[2025-09-30 08:35:12] [INFO] MONITOR: Detección de SQL injection iniciada
[2025-09-30 08:35:15] [ALERT] MONITOR: SQL INJECTION DETECTADO - IP: 192.168.1.100
[2025-09-30 08:35:16] [SUCCESS] ALERTS: Email enviado a: admin@servidor.com
```

### Reportes Automáticos

Los reportes se generan automáticamente cada hora en:
`/etc/webmin-virtualmin-ids/reports/`

### Base de Datos de Amenazas

Formato CSV con campos:
- Timestamp
- IP
- Tipo de amenaza
- Severidad
- Detalles

---

## 🚨 Respuesta a Incidentes

### Protocolo de Respuesta

1. **Detección**: El sistema identifica la amenaza automáticamente
2. **Análisis**: Se registra en la base de datos de amenazas
3. **Bloqueo**: IP se bloquea según reglas configuradas
4. **Alerta**: Se envían notificaciones por canales configurados
5. **Registro**: Se guarda evidencia completa del incidente

### Niveles de Severidad

- **LOW**: Amenazas menores, logging básico
- **MEDIUM**: Amenazas moderadas, alertas estándar
- **HIGH**: Amenazas significativas, bloqueo automático
- **CRITICAL**: Amenazas críticas, respuesta inmediata

### Acciones Automáticas

- **block_ip**: Bloqueo con iptables/fail2ban
- **send_alert**: Envío de notificaciones
- **log_threat**: Registro detallado
- **email_admin**: Notificación específica al administrador

---

## 🔍 Solución de Problemas

### Verificación del Sistema

```bash
# Verificar servicios
sudo bash webmin_virtualmin_ids_master.sh status

# Verificar logs por errores
grep "ERROR" /etc/webmin-virtualmin-ids/logs/*.log

# Verificar configuración
sudo bash custom_rules_manager.sh validate
```

### Problemas Comunes

**Servicio no inicia:**
```bash
# Verificar estado de systemd
systemctl status webmin-ids-monitor

# Ver logs de systemd
journalctl -u webmin-ids-monitor -f
```

**Alertas no se envían:**
```bash
# Verificar configuración de alertas
sudo bash alert_system.sh config

# Probar envío
sudo bash alert_system.sh test
```

**Reglas no funcionan:**
```bash
# Validar reglas
sudo bash custom_rules_manager.sh validate

# Ver logs de reglas
tail -f /etc/webmin-virtualmin-ids/rules/custom_rules.log
```

---

## 📈 Rendimiento y Optimización

### Requisitos del Sistema

- **CPU**: Mínimo 1 core, recomendado 2+ cores
- **RAM**: Mínimo 512MB, recomendado 1GB+
- **Disco**: 100MB para logs y configuración
- **Red**: Conexión estable para alertas externas

### Optimizaciones

- **Intervalos de monitoreo**: Ajustables según carga
- **Umbrales de detección**: Configurables por recursos
- **Rotación de logs**: Automática para evitar crecimiento excesivo
- **Compresión**: Logs antiguos se comprimen automáticamente

### Monitoreo de Rendimiento

```bash
# Ver uso de recursos
top -p $(pgrep -f "webmin_virtualmin_monitor")

# Ver conexiones de red
netstat -tuln | grep :10000

# Ver estado de fail2ban
fail2ban-client status
```

---

## 🔄 Actualización y Mantenimiento

### Actualización del Sistema

```bash
# Descargar nueva versión
wget https://github.com/tu-repo/webmin-ids/new-version.zip

# Backup de configuración
sudo bash webmin_virtualmin_ids_master.sh backup

# Actualizar componentes
sudo bash webmin_virtualmin_ids_master.sh update
```

### Mantenimiento Programado

```bash
# Limpieza de logs antiguos
find /etc/webmin-virtualmin-ids/logs -name "*.log" -mtime +30 -delete

# Optimización de base de datos
sudo bash webmin_virtualmin_monitor.sh optimize

# Verificación de integridad
sudo bash webmin_virtualmin_ids_master.sh verify
```

---

## 🏆 Mejores Prácticas

### Configuración Inicial

1. **Configurar alertas** antes de activar protección
2. **Personalizar umbrales** según carga del servidor
3. **Crear whitelist** de IPs confiables
4. **Probar sistema** en modo seguro

### Monitoreo Continuo

1. **Revisar logs diariamente** las primeras semanas
2. **Ajustar umbrales** basados en falsos positivos
3. **Actualizar reglas** regularmente
4. **Monitorear rendimiento** del sistema

### Respuesta a Incidentes

1. **No desactivar protección** inmediatamente
2. **Documentar incidentes** para análisis posterior
3. **Revisar configuraciones** después de ataques
4. **Actualizar whitelist/blacklist** según sea necesario

---

## 📞 Soporte y Comunidad

### Recursos de Ayuda

- **Documentación completa**: Este archivo
- **Logs detallados**: Para diagnóstico de problemas
- **Comunidad**: Foros de Webmin/Virtualmin
- **Issues**: Reportar bugs en el repositorio

### Información de Debug

```bash
# Recopilar información de debug
sudo bash webmin_virtualmin_ids_master.sh debug > debug_info.txt

# Incluir en reportes de soporte:
# - Versión del sistema
# - Configuración actual
# - Logs relevantes
# - Descripción del problema
```

---

## 📄 Licencia y Créditos

### Licencia
Este sistema se distribuye bajo licencia MIT. Ver archivo LICENSE para detalles completos.

### Créditos
- **Desarrollado para**: Comunidad Webmin/Virtualmin
- **Tecnologías**: Bash, fail2ban, iptables, systemd
- **Inspiración**: Mejores prácticas de seguridad del sector

---

## 🎯 Conclusión

Este sistema IDS/IPS proporciona protección completa y avanzada para servidores Webmin/Virtualmin, combinando detección inteligente, respuesta automática y gestión flexible. La arquitectura modular permite personalización según necesidades específicas mientras mantiene facilidad de uso y rendimiento óptimo.

**¡Su servidor está ahora protegido contra las amenazas más avanzadas del panorama actual de ciberseguridad!**

---

*Última actualización: Septiembre 2025*
*Versión: 1.0.0*
*Compatibilidad: Webmin 1.9xx+, Virtualmin 6.x+* 
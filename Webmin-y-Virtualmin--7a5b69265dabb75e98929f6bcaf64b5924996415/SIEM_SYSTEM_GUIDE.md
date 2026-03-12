# SIEM System Guide - Security Information and Event Management

## Resumen Ejecutivo

Se ha implementado un sistema SIEM (Security Information and Event Management) completo para Webmin y Virtualmin que incluye agregación de logs de múltiples fuentes, correlación inteligente de eventos usando reglas y ML, alertas avanzadas con escalado automático, dashboard de seguridad en tiempo real, análisis forense con timeline, cumplimiento de estándares (PCI-DSS, GDPR, HIPAA), y reporting automático. El sistema está completamente integrado con todos los sistemas existentes de monitoreo, IDS/IPS, firewall y RBAC.

## Arquitectura del Sistema

### Componentes Principales

1. **Agregador de Logs** (`log_collector.sh`)
   - Recopila logs de múltiples fuentes cada 5 minutos
   - Normaliza eventos y los almacena en base de datos SQLite
   - Soporta logs de sistema, aplicación, seguridad y firewall

2. **Motor de Correlación** (`correlation_engine.sh` + `ml_anomaly_detector.py`)
   - Correlación basada en reglas predefinidas
   - Detección de anomalías usando Machine Learning (Isolation Forest)
   - Genera alertas automáticas basadas en patrones

3. **Sistema de Alertas** (`alert_manager.sh`)
   - Escalado automático de alertas basado en severidad y tiempo
   - Múltiples métodos de notificación (email, SMS, llamadas, pager)
   - Gestión de ciclo de vida de alertas

4. **Dashboard Web** (`index.cgi`)
   - Interfaz Webmin integrada
   - Visualización en tiempo real de métricas de seguridad
   - Gestión de alertas y reglas de correlación

5. **Análisis Forense** (`forensic_analyzer.sh`)
   - Generación de timelines interactivos
   - Búsqueda de indicadores de compromiso (IOC)
   - Exportación de datos forenses

6. **Verificación de Cumplimiento** (`compliance_checker.sh`)
   - Chequeos automáticos para PCI-DSS, GDPR, HIPAA
   - Reportes de cumplimiento con estado detallado
   - Alertas de no cumplimiento

7. **Sistema de Reportes** (`report_generator.sh`)
   - Reportes diarios, semanales y de cumplimiento
   - Envío automático por email
   - Limpieza automática de reportes antiguos

## Funcionalidades Implementadas

### 1. Agregación de Logs de Múltiples Fuentes

**Fuentes Soportadas:**
- Logs del sistema (`/var/log/syslog`, `/var/log/messages`)
- Logs de autenticación (`/var/log/auth.log`)
- Logs de Apache/Nginx (`access.log`, `error.log`)
- Logs de MySQL (`/var/log/mysql/error.log`)
- Logs de correo (`/var/log/mail.log`)
- Logs de Webmin/Virtualmin
- Logs del firewall inteligente
- Logs de IDS/IPS (Snort, Suricata)

**Características:**
- Recolección incremental con seguimiento de posición
- Parsing inteligente de diferentes formatos de log
- Normalización de eventos a estructura común
- Almacenamiento eficiente en base de datos

### 2. Correlación Inteligente de Eventos

**Reglas Predefinidas:**
- Intentos de login fallidos múltiples
- Ataques de fuerza bruta
- Acceso a archivos sensibles
- Indicadores de DDoS
- Escalada de privilegios

**Machine Learning:**
- Modelo de Isolation Forest para detección de anomalías
- Entrenamiento automático con datos históricos
- Detección de patrones inusuales en tiempo real

### 3. Sistema de Alertas Avanzado

**Niveles de Severidad:**
- Crítica: Requiere acción inmediata
- Alta: Acción en horas
- Media: Acción en días
- Baja: Monitoreo
- Info: Información

**Escalado Automático:**
- Basado en severidad y tiempo sin resolución
- Múltiples niveles de escalada
- Notificaciones progresivas

**Métodos de Notificación:**
- Email a administradores
- SMS a personal de seguridad
- Llamadas telefónicas para emergencias
- Alertas a sistemas de pager

### 4. Dashboard de Seguridad en Tiempo Real

**Métricas Principales:**
- Eventos de seguridad en las últimas 24 horas
- Alertas activas por severidad
- IPs bloqueadas
- Fuentes de eventos más activas

**Visualizaciones:**
- Gráficos de barras para distribución de eventos
- Tabla de alertas recientes
- Filtros por severidad, fuente y tiempo

**Gestión Interactiva:**
- Acuse de recibo y resolución de alertas
- Configuración de reglas de correlación
- Búsqueda y filtrado de eventos

### 5. Análisis Forense con Timeline

**Características:**
- Timelines interactivos en HTML
- Filtros por IP, usuario, tipo de evento
- Búsqueda de indicadores de compromiso
- Exportación de datos forenses en CSV

**Análisis de Patrones:**
- Detección automática de tipos de ataque
- Análisis de comportamiento de IPs sospechosas
- Correlación temporal de eventos

### 6. Cumplimiento de Estándares

**PCI-DSS (Payment Card Industry Data Security Standard):**
- Verificación de logs de acceso a datos de tarjetas
- Pruebas regulares de sistemas de seguridad
- Monitoreo continuo de cumplimiento

**GDPR (General Data Protection Regulation):**
- Notificación de brechas de datos en 72 horas
- Protección de datos por diseño
- Auditoría de acceso a datos personales

**HIPAA (Health Insurance Portability and Accountability Act):**
- Identificación única de usuarios
- Logs de auditoría para acceso a PHI
- Verificación de integridad de datos

### 7. Reporting Automático

**Tipos de Reporte:**
- Diario: Resumen de seguridad del día
- Semanal: Análisis semanal detallado
- Cumplimiento: Estado de cumplimiento por estándar
- Forense: Reportes de incidentes específicos

**Características:**
- Generación automática programada
- Envío por email a stakeholders
- Formatos HTML, PDF y JSON
- Retención configurable de reportes

## Integración con Sistemas Existentes

### Firewall Inteligente
- Recopilación automática de IPs bloqueadas
- Integración con reglas de correlación
- Sincronización de amenazas detectadas

### Sistemas de Monitoreo
- Incorporación de métricas de pro_monitoring
- Alertas integradas con monitoreo existente
- Dashboards unificados

### IDS/IPS
- Parsing de logs de Snort y Suricata
- Correlación con eventos de red
- Enriquecimiento de alertas con datos de IDS

### RBAC (Role-Based Access Control)
- Control de acceso basado en roles de Webmin
- Permisos granulares para diferentes funciones
- Auditoría de acciones administrativas

## Instalación y Configuración

### Requisitos del Sistema
- SQLite3
- Python 3 con pandas, scikit-learn
- Webmin/Virtualmin instalado
- Espacio en disco: mínimo 1GB para logs y base de datos

### Proceso de Instalación
```bash
# Ejecutar el instalador
sudo bash install_siem_system.sh

# El instalador automáticamente:
# - Verifica dependencias
# - Instala paquetes Python necesarios
# - Inicializa la base de datos
# - Instala el módulo Webmin
# - Configura trabajos cron
# - Integra con sistemas existentes
```

### Configuración Post-Instalación
1. Revisar `siem/siem_config.conf` para personalizar
2. Configurar destinatarios de email en alertas
3. Ajustar umbrales de reglas de correlación
4. Configurar integración con sistemas externos

## Uso del Sistema

### Interfaz Web
Acceder vía Webmin → Servidores → SIEM

**Pestañas principales:**
- **Dashboard**: Vista general y métricas
- **Alertas**: Gestión de alertas activas
- **Eventos**: Búsqueda y exploración de eventos
- **Reglas**: Configuración de correlación
- **Cumplimiento**: Estado de estándares
- **Reportes**: Generación y visualización
- **Forense**: Análisis de timelines

### Comandos de Línea
```bash
# Recolección manual de logs
siem/log_collector.sh

# Ejecución manual del motor de correlación
siem/correlation_engine.sh

# Resumen de alertas
siem/alert_manager.sh summary

# Verificación de cumplimiento
siem/compliance_checker.sh all

# Generar reporte diario
siem/report_generator.sh daily

# Análisis forense
siem/forensic_analyzer.sh timeline <IP> [usuario] [fecha_inicio] [fecha_fin]
```

## Monitoreo y Mantenimiento

### Trabajos Programados (Cron)
- Recolección de logs: cada 5 minutos
- Motor de correlación: cada 10 minutos
- Procesamiento de alertas: cada 5 minutos
- Verificación de cumplimiento: diaria a las 2 AM
- Reportes diarios: a las 6 AM
- Limpieza de datos antiguos: semanal

### Monitoreo del Sistema
- Logs del sistema: `/var/log/siem/`
- Base de datos: `siem/siem_events.db`
- Reportes: `siem/reports/`
- Timelines forenses: `siem/timelines/`

### Mantenimiento
- Respaldo regular de la base de datos
- Monitoreo del crecimiento de logs
- Actualización de modelos ML
- Revisión de reglas de correlación

## Rendimiento y Escalabilidad

### Optimizaciones
- Índices de base de datos para consultas rápidas
- Procesamiento incremental de logs
- Limpieza automática de datos antiguos
- Almacenamiento eficiente de eventos

### Límites y Recomendaciones
- Eventos por día: hasta 1 millón
- Retención de datos: configurable (por defecto 90 días)
- Tamaño de base de datos: monitorear crecimiento
- Recursos del sistema: CPU y memoria para ML

## Seguridad del Sistema SIEM

### Protección de Datos
- Encriptación de base de datos
- Control de acceso basado en roles
- Auditoría de acciones administrativas
- Protección contra manipulación de logs

### Integridad
- Checksums de archivos de configuración
- Validación de integridad de base de datos
- Monitoreo de cambios en reglas y configuraciones

## Resolución de Problemas

### Problemas Comunes
1. **Logs no se recopilan**: Verificar permisos y rutas
2. **Alertas no se generan**: Revisar reglas de correlación
3. **Dashboard no carga**: Verificar instalación de módulo Webmin
4. **ML no funciona**: Verificar instalación de dependencias Python

### Logs de Depuración
- Habilitar logging detallado en configuración
- Revisar `/var/log/siem/debug.log`
- Usar comandos manuales para testing

## Conclusión

El sistema SIEM implementado proporciona una solución completa y integrada para la gestión de seguridad de la información en entornos Webmin/Virtualmin. Combina capacidades avanzadas de recolección, análisis y respuesta a incidentes de seguridad con cumplimiento automático de estándares regulatorios y reporting comprehensivo.

Todas las funcionalidades solicitadas han sido implementadas y están completamente operativas, proporcionando una plataforma robusta para la ciberseguridad proactiva y el cumplimiento normativo.
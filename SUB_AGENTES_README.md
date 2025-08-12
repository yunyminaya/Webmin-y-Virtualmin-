# Sistema de Sub-Agentes para Webmin/Virtualmin

## 🚀 Descripción

Sistema completo de sub-agentes especializados para el monitoreo, seguridad, backup y mantenimiento automatizado de servidores Webmin/Virtualmin.

## 📋 Sub-Agentes Disponibles

### 1. **Sub-Agente de Monitoreo** (`sub_agente_monitoreo.sh`)
- ✅ Monitorea recursos del sistema (CPU, memoria, disco)
- ✅ Verifica estado de servicios críticos
- ✅ Comprueba conectividad de red
- ✅ Supervisa puertos abiertos
- ✅ Genera reportes de rendimiento

**Uso:**
```bash
./sub_agente_monitoreo.sh start     # Ejecutar una vez
./sub_agente_monitoreo.sh daemon    # Ejecutar continuamente
./sub_agente_monitoreo.sh report    # Solo generar reporte
```

### 2. **Sub-Agente de Seguridad** (`sub_agente_seguridad.sh`)
- 🔒 Analiza intentos de login fallidos
- 🔒 Detecta accesos root sospechosos
- 🔒 Verifica puertos abiertos no autorizados
- 🔒 Comprueba permisos de archivos críticos
- 🔒 Identifica procesos inusuales
- 🔒 Valida configuración de Webmin

**Uso:**
```bash
./sub_agente_seguridad.sh start     # Verificación completa
./sub_agente_seguridad.sh quick     # Verificación rápida
./sub_agente_seguridad.sh report    # Solo generar reporte
```

### 3. **Sub-Agente de Backup** (`sub_agente_backup.sh`)
- 💾 Backup de configuraciones Webmin/Virtualmin
- 💾 Backup de bases de datos (MySQL/PostgreSQL)
- 💾 Backup de sitios web y dominios
- 💾 Backup de configuraciones del sistema
- 💾 Rotación automática de backups antiguos
- 💾 Verificación de integridad

**Uso:**
```bash
./sub_agente_backup.sh start        # Backup completo
./sub_agente_backup.sh webmin       # Solo Webmin
./sub_agente_backup.sh databases    # Solo bases de datos
./sub_agente_backup.sh verify       # Verificar integridad
```

### 4. **Sub-Agente de Actualizaciones** (`sub_agente_actualizaciones.sh`)
- 🔄 Gestiona actualizaciones del sistema
- 🔄 Actualiza Webmin y Virtualmin
- 🔄 Renueva certificados SSL
- 🔄 Verifica actualizaciones del kernel
- 🔄 Valida servicios después de actualizar

**Uso:**
```bash
./sub_agente_actualizaciones.sh start          # Proceso completo
./sub_agente_actualizaciones.sh security-only  # Solo seguridad
./sub_agente_actualizaciones.sh ssl-only       # Solo SSL
./sub_agente_actualizaciones.sh check          # Solo verificar
```

### 5. **Sub-Agente de Logs** (`sub_agente_logs.sh`)
- 📊 Analiza logs del sistema y aplicaciones
- 📊 Detecta patrones de seguridad sospechosos
- 📊 Monitorea logs de Webmin/Virtualmin
- 📊 Analiza logs de bases de datos y web
- 📊 Rota logs antiguos automáticamente
- 📊 Genera estadísticas de logs

**Uso:**
```bash
./sub_agente_logs.sh start          # Análisis completo
./sub_agente_logs.sh security       # Solo seguridad
./sub_agente_logs.sh performance    # Solo rendimiento
./sub_agente_logs.sh rotate         # Solo rotar logs
```

## 🎛️ Coordinador Principal

### **Coordinador de Sub-Agentes** (`coordinador_sub_agentes.sh`)

El script principal que coordina y gestiona todos los sub-agentes.

**Comandos principales:**
```bash
# Ejecución única de todos los sub-agentes
./coordinador_sub_agentes.sh start

# Modo daemon (ejecución continua programada)
./coordinador_sub_agentes.sh daemon

# Detener daemon
./coordinador_sub_agentes.sh stop

# Reiniciar daemon
./coordinador_sub_agentes.sh restart

# Generar reporte de estado
./coordinador_sub_agentes.sh status

# Instalar como servicio systemd
./coordinador_sub_agentes.sh install-service

# Modo de prueba
./coordinador_sub_agentes.sh test
```

**Sub-agentes individuales:**
```bash
./coordinador_sub_agentes.sh monitoreo [modo]
./coordinador_sub_agentes.sh seguridad [modo]
./coordinador_sub_agentes.sh backup [modo]
./coordinador_sub_agentes.sh actualizaciones [modo]
./coordinador_sub_agentes.sh logs [modo]
```

## ⚙️ Configuración

El archivo de configuración se crea automáticamente en:
```
/etc/webmin/sub_agentes_config.conf
```

**Configuración por defecto:**
```bash
# Sub-agente de monitoreo
MONITOREO_ENABLED=true
MONITOREO_INTERVAL=300          # 5 minutos

# Sub-agente de seguridad
SEGURIDAD_ENABLED=true
SEGURIDAD_INTERVAL=1800         # 30 minutos

# Sub-agente de backup
BACKUP_ENABLED=true
BACKUP_INTERVAL=86400           # 24 horas

# Sub-agente de actualizaciones
ACTUALIZACIONES_ENABLED=true
ACTUALIZACIONES_INTERVAL=604800 # 7 días

# Sub-agente de logs
LOGS_ENABLED=true
LOGS_INTERVAL=3600              # 1 hora

# Configuración global
PARALLEL_EXECUTION=true
MAX_CONCURRENT_AGENTS=3
```

## 📁 Estructura de Archivos

```
/var/log/                           # Logs principales
├── coordinador_sub_agentes.log     # Log del coordinador
├── sub_agente_monitoreo.log        # Log de monitoreo
├── sub_agente_seguridad.log        # Log de seguridad
├── sub_agente_backup.log           # Log de backup
├── sub_agente_actualizaciones.log  # Log de actualizaciones
├── sub_agente_logs.log             # Log de análisis de logs
├── alertas_sistema.log             # Alertas del sistema
├── alertas_criticas_seguridad.log  # Alertas críticas
└── reporte_*.txt                   # Reportes generados

/var/backups/sistema/               # Directorio de backups
├── webmin/                         # Backups de Webmin
├── virtualmin/                     # Backups de Virtualmin
├── system/                         # Backups del sistema
├── databases/                      # Backups de bases de datos
├── websites/                       # Backups de sitios web
└── logs/                           # Backups de logs

/etc/webmin/                        # Configuración
└── sub_agentes_config.conf         # Archivo de configuración
```

## 🚀 Instalación Rápida

1. **Clonar o copiar los archivos:**
```bash
# Asegurar que todos los scripts son ejecutables
chmod +x *.sh
```

2. **Ejecutar prueba inicial:**
```bash
./coordinador_sub_agentes.sh test
```

3. **Instalar como servicio (opcional):**
```bash
sudo ./coordinador_sub_agentes.sh install-service
sudo systemctl start sub-agentes-webmin
sudo systemctl status sub-agentes-webmin
```

4. **Configurar ejecución manual:**
```bash
# Ejecutar todos los sub-agentes una vez
./coordinador_sub_agentes.sh start

# O iniciar modo daemon
./coordinador_sub_agentes.sh daemon &
```

## 📋 Ejemplos de Uso

### Monitoreo básico diario:
```bash
./coordinador_sub_agentes.sh monitoreo start
./coordinador_sub_agentes.sh seguridad quick
```

### Backup semanal completo:
```bash
./coordinador_sub_agentes.sh backup start
./coordinador_sub_agentes.sh backup verify
```

### Verificación de seguridad:
```bash
./coordinador_sub_agentes.sh seguridad start
./coordinador_sub_agentes.sh logs security
```

### Actualizaciones mensuales:
```bash
./coordinador_sub_agentes.sh actualizaciones check
./coordinador_sub_agentes.sh actualizaciones start
```

## 🔧 Personalización

Los sub-agentes pueden personalizarse editando:

- **Umbrales de alerta:** Modificar variables como `ALERT_THRESHOLD_CPU`
- **Directorios de backup:** Cambiar `BACKUP_BASE_DIR`
- **Intervalos de ejecución:** Ajustar en el archivo de configuración
- **Patrones de seguridad:** Agregar nuevos patrones en `security_patterns`

## 📞 Soporte

- **Logs:** Revisar `/var/log/coordinador_sub_agentes.log`
- **Estado:** Ejecutar `./coordinador_sub_agentes.sh status`
- **Reportes:** Los reportes se generan automáticamente en `/var/log/`

## ⚠️ Notas Importantes

- Se recomienda ejecutar como root para acceso completo
- Los backups se rotan automáticamente (30 días por defecto)
- Las alertas críticas se registran en logs separados
- El modo daemon usa recursos mínimos del sistema
- Compatible con Ubuntu/Debian y distribuciones derivadas

---

**¡Sistema de sub-agentes listo para usar! 🎉**
# 🛡️ Sistema de Auto-Defensa y Reparación - Virtualmin/Webmin

## 📋 Descripción

El **Sistema de Auto-Defensa** es una solución integral de seguridad que detecta automáticamente ataques, mal funcionamiento y problemas críticos en el servidor, activando reparaciones automáticas para mantener la estabilidad del sistema y la integridad de todos los servidores virtuales.

## 🎯 Características Principales

### 🔍 **Detección Inteligente de Amenazas**
- **Ataques de Fuerza Bruta**: Detecta intentos masivos de login fallidos
- **Conexiones Sospechosas**: Identifica IPs con conexiones anormales
- **Procesos Maliciosos**: Detecta procesos sospechosos en ejecución
- **Picos de Recursos**: Monitorea CPU, memoria y disco
- **Cambios en Archivos**: Alertas ante modificaciones críticas
- **Servidores Virtuales**: Verifica estado de dominios y servicios

### 🛡️ **Respuesta Automática**
- **Modo Defensa**: Activación automática ante amenazas detectadas
- **Bloqueo de IPs**: Firewall inteligente contra ataques
- **Eliminación de Procesos**: Terminación automática de amenazas
- **Reinicio de Servicios**: Recuperación automática de servicios críticos
- **Backup de Emergencia**: Creación automática de respaldos

### 🔧 **Reparación Completa**
- **Servidores Virtuales**: Reparación automática de configuraciones
- **Bases de Datos**: Verificación y reparación de BD
- **Servicios Web**: Reinicio automático de Apache/Nginx
- **Configuraciones**: Restauración de archivos críticos
- **Limpieza del Sistema**: Eliminación de archivos temporales

### 📊 **Interfaz Webmin**
- **Dashboard Completo**: Control visual del sistema de defensa
- **Botones de Emergencia**: Controles manuales para situaciones críticas
- **Monitoreo en Tiempo Real**: Estado actual del sistema
- **Logs Interactivos**: Historial completo de actividades
- **Estadísticas de Seguridad**: Métricas detalladas de amenazas

## 🚀 Instalación Rápida

```bash
# Hacer ejecutables los scripts
chmod +x install_defense.sh
chmod +x auto_defense.sh

# Instalar el sistema completo
sudo ./install_defense.sh install

# Verificar instalación
./install_defense.sh status
```

## 📖 Uso del Sistema

### 🔍 **Verificación Manual**
```bash
# Verificar estado actual
./auto_defense.sh status

# Verificación completa de seguridad
./auto_defense.sh check

# Ver dashboard web
open ./defense_dashboard.html
```

### 🛡️ **Activación Manual**
```bash
# Activar modo defensa
./auto_defense.sh defense

# Reparar servidores virtuales
./auto_defense.sh repair

# Iniciar monitoreo continuo
./auto_defense.sh start
```

### 📊 **Dashboard Web**
Abre `defense_dashboard.html` en tu navegador para acceder a:
- Estado del sistema de defensa
- Controles de emergencia
- Estadísticas de seguridad
- Logs de actividad
- Configuración avanzada

## ⚙️ Configuración Avanzada

### Variables de Entorno
```bash
# Intervalo de monitoreo (segundos)
export MONITOR_INTERVAL=300

# Umbrales de detección
export MAX_FAILED_LOGINS=10
export MAX_CONNECTIONS_PER_IP=50
export MAX_CPU_SPIKE=80
export MAX_MEMORY_SPIKE=85

# Directorios personalizados
export DEFENSE_LOG="./logs/auto_defense.log"
export ATTACK_LOG="./logs/attack_detection.log"
export VIRTUALMIN_BACKUP_DIR="./backups/virtualmin_auto"
```

### Personalización de Procesos Sospechosos
Edita la variable `SUSPICIOUS_PROCESSES` en `auto_defense.sh`:
```bash
SUSPICIOUS_PROCESSES=("nc" "ncat" "netcat" "socat" "telnet" "ftp" "ssh" "scp" "wget" "curl")
```

## 🔄 Servicio Automático

### Iniciar/Detener Servicio
```bash
# Iniciar servicio
sudo systemctl start virtualmin-defense

# Detener servicio
sudo systemctl stop virtualmin-defense

# Reiniciar servicio
sudo systemctl restart virtualmin-defense

# Estado del servicio
sudo systemctl status virtualmin-defense
```

### Logs del Servicio
```bash
# Ver logs en tiempo real
sudo journalctl -u virtualmin-defense -f

# Ver logs recientes
sudo journalctl -u virtualmin-defense -n 50
```

## 📋 Arquitectura del Sistema

```
Sistema de Auto-Defensa
├── 🔍 auto_defense.sh          # Núcleo del sistema
├── 🔧 auto_repair.sh           # Reparaciones generales
├── 🚨 auto_repair_critical.sh  # Reparaciones críticas
├── 📊 defense_dashboard.html   # Dashboard web
├── 🔧 install_defense.sh       # Instalador
├── 🗑️ uninstall_defense.sh     # Desinstalador
└── ⚙️ virtualmin-defense.service # Servicio systemd
```

### Componentes Principales

#### 1. **Módulo de Detección**
- `detect_brute_force()` - Ataques de fuerza bruta
- `detect_suspicious_connections()` - Conexiones sospechosas
- `detect_suspicious_processes()` - Procesos maliciosos
- `detect_resource_spikes()` - Picos de recursos
- `detect_file_changes()` - Cambios en archivos
- `detect_virtualmin_issues()` - Problemas en Virtualmin

#### 2. **Módulo de Defensa**
- `activate_defense_mode()` - Modo defensa completo
- `kill_suspicious_processes()` - Eliminación de amenazas
- `restart_critical_services()` - Reinicio de servicios
- `create_emergency_backup()` - Backup de emergencia

#### 3. **Módulo de Reparación**
- `repair_virtual_servers()` - Reparación de dominios
- `repair_critical_memory()` - Gestión de memoria
- `repair_critical_disk()` - Gestión de disco
- `repair_critical_processes()` - Gestión de procesos
- `repair_critical_network()` - Gestión de red

#### 4. **Módulo de Monitoreo**
- `continuous_monitoring()` - Monitoreo 24/7
- `generate_defense_dashboard()` - Dashboard dinámico
- Logging automático de todas las actividades

## 🛠️ Solución de Problemas

### Problema: Servicio no inicia
```bash
# Verificar estado
sudo systemctl status virtualmin-defense

# Ver logs
sudo journalctl -u virtualmin-defense -n 20

# Reiniciar manualmente
sudo systemctl restart virtualmin-defense
```

### Problema: Dashboard no carga
```bash
# Regenerar dashboard
./auto_defense.sh dashboard

# Verificar permisos
ls -la defense_dashboard.html
```

### Problema: Falsos positivos
```bash
# Ajustar umbrales en auto_defense.sh
MAX_FAILED_LOGINS=5      # Reducir sensibilidad
MAX_CONNECTIONS_PER_IP=20 # Reducir límite
```

## 📊 Logs y Monitoreo

### Archivos de Log
- `logs/auto_defense.log` - Actividades del sistema de defensa
- `logs/attack_detection.log` - Ataques detectados
- `logs/auto_repair.log` - Reparaciones realizadas
- `logs/defense_install.log` - Log de instalación

### Comandos de Monitoreo
```bash
# Ver logs en tiempo real
tail -f logs/auto_defense.log

# Contar ataques detectados
grep "ATAQUE" logs/attack_detection.log | wc -l

# Ver reparaciones realizadas
grep "REPARACIÓN" logs/auto_repair.log | tail -10
```

## 🔐 Seguridad del Sistema

### Medidas de Protección
- ✅ **Análisis de Procesos**: Detección de procesos maliciosos
- ✅ **Monitoreo de Conexiones**: Control de IPs sospechosas
- ✅ **Verificación de Archivos**: Alertas ante cambios críticos
- ✅ **Gestión de Recursos**: Control de picos de CPU/memoria
- ✅ **Backup Automático**: Respaldos ante emergencias
- ✅ **Firewall Inteligente**: Bloqueo automático de amenazas

### Configuración Segura
- 🔒 Ejecución como root para operaciones críticas
- 🔒 Permisos mínimos en archivos
- 🔒 Validación de todas las entradas
- 🔒 Logs detallados de todas las acciones
- 🔒 Backup automático antes de cambios

## 📈 Métricas y Estadísticas

### Dashboard Interactivo
El dashboard web muestra:
- Estado del sistema de defensa
- Número de ataques detectados
- Reparaciones realizadas
- Recursos del sistema
- Logs de actividad
- Controles de emergencia

### Estadísticas Disponibles
```bash
# Ver métricas actuales
./auto_defense.sh status

# Ver dashboard
open defense_dashboard.html
```

## 🆘 Emergencias

### Activación Manual de Defensa
```bash
# Desde el dashboard web
# O desde línea de comandos
./auto_defense.sh defense
```

### Recuperación de Emergencia
```bash
# Restaurar desde backup
./auto_defense.sh repair

# Ver logs de la emergencia
tail -50 logs/auto_defense.log
```

## 🗑️ Desinstalación

```bash
# Detener servicios
sudo systemctl stop virtualmin-defense

# Desinstalar completamente
./install_defense.sh uninstall

# Verificar desinstalación
./install_defense.sh status
```

## 📞 Soporte

### Logs de Diagnóstico
```bash
# Recopilar información de diagnóstico
./auto_defense.sh status > diagnostico.txt
tail -100 logs/auto_defense.log >> diagnostico.txt
tail -100 logs/attack_detection.log >> diagnostico.txt
```

### Información del Sistema
```bash
# Información para soporte
uname -a
lsb_release -a
systemctl status virtualmin-defense
```

---

## 🎯 Resumen Ejecutivo

El **Sistema de Auto-Defensa** proporciona **protección integral 24/7** contra ataques y mal funcionamiento, con:

- **Detección automática** de amenazas en tiempo real
- **Respuesta inmediata** ante ataques detectados
- **Reparación automática** de servidores virtuales
- **Interfaz web intuitiva** siguiendo el diseño de Webmin
- **Logs detallados** para auditoría y diagnóstico
- **Backup automático** para recuperación rápida

**¡Tu servidor ahora está protegido contra ataques y se repara automáticamente! 🛡️✨**

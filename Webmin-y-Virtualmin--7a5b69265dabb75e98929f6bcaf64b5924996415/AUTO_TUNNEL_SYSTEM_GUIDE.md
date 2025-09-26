# 🚇 Sistema de Túnel Automático 24/7

## Guía Completa de Instalación y Configuración

### 📋 Descripción General

El **Sistema de Túnel Automático** es una solución avanzada que garantiza la disponibilidad 24/7 de servidores virtuales al detectar automáticamente cuando una IP privada necesita convertirse en pública, creando túneles SSH reverse de forma automática y transparente.

### ✨ Características Principales

- **🔍 Detección Automática**: Identifica IPs privadas vs públicas en tiempo real
- **🚇 Túnel Inteligente**: Crea túneles SSH reverse automáticamente cuando es necesario
- **👁️ Monitoreo 24/7**: Vigilancia continua del estado del túnel y conectividad
- **🔄 Failover Automático**: Reconexión automática en caso de fallos
- **📊 Dashboard Web**: Interfaz visual para monitoreo en tiempo real
- **📧 Alertas Configurables**: Notificaciones por email, webhook, etc.
- **🔒 Seguridad Avanzada**: Configuración SSH hardening incluida

---

## 🚀 Instalación Automática

### Paso 1: Descargar e Instalar

```bash
# Clonar el repositorio
git clone https://github.com/yunyminaya/Webmin-y-Virtualmin-.git
cd Webmin-y-Virtualmin-

# Ejecutar el instalador automático
sudo bash install_auto_tunnel_system.sh install
```

### Paso 2: Configurar el Sistema

Edite el archivo de configuración:

```bash
sudo nano /etc/auto_tunnel_config.conf
```

**Configuración mínima requerida:**

```bash
# Configuración del servidor remoto para túnel SSH
TUNNEL_REMOTE_HOST="su-servidor-remoto.com"
TUNNEL_REMOTE_USER="tunnel_user"
TUNNEL_REMOTE_PORT="22"
TUNNEL_LOCAL_PORT="80"
TUNNEL_PORT="8080"
```

### Paso 3: Configurar el Servidor Remoto

En el servidor remoto donde apuntará el túnel:

```bash
# Crear usuario para túnel
sudo useradd -m -s /bin/bash tunnel_user
sudo mkdir -p /home/tunnel_user/.ssh
sudo chmod 700 /home/tunnel_user/.ssh

# Configurar SSH key-only (recomendado)
# Copie la clave pública generada en el servidor local
sudo nano /home/tunnel_user/.ssh/authorized_keys
# Pegue aquí la clave pública: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ...

sudo chown -R tunnel_user:tunnel_user /home/tunnel_user/.ssh
sudo chmod 600 /home/tunnel_user/.ssh/authorized_keys
```

### Paso 4: Iniciar el Servicio

```bash
# Iniciar el servicio
sudo systemctl start auto-tunnel

# Habilitar inicio automático
sudo systemctl enable auto-tunnel

# Verificar estado
sudo systemctl status auto-tunnel
```

---

## 📊 Dashboard de Monitoreo

### Acceso al Dashboard

Una vez instalado, acceda al dashboard web:

```
http://su-servidor/tunnel-monitor/
```

### Características del Dashboard

- **🔗 Estado de Conectividad**: Internet y red local
- **🌐 IP Externa**: Detección automática de IP pública/privada
- **🚇 Estado del Túnel**: Activo/Inactivo con PID
- **👁️ Monitor 24/7**: Estado del servicio de monitoreo
- **📈 Estadísticas**: Conexiones, failovers, alertas
- **📋 Logs en Tiempo Real**: Últimas 50 entradas de log
- **⚠️ Alertas Activas**: Problemas que requieren atención

### API JSON para Integraciones

```bash
curl http://su-servidor:8081/cgi-bin/tunnel_status.cgi
```

**Respuesta JSON:**
```json
{
  "internet": {"connected": true},
  "external_ip": "192.168.1.100",
  "ip_type": "private",
  "tunnel": {"active": true, "pid": 1234},
  "monitor": {"active": true, "pid": 5678},
  "stats": {"connections": 15, "failovers": 2, "alerts": 0},
  "logs": [...],
  "alerts": [...]
}
```

---

## ⚙️ Configuración Avanzada

### Archivo de Configuración Completo

```bash
# Archivo: /etc/auto_tunnel_config.conf

# === CONFIGURACIÓN BÁSICA ===
TUNNEL_REMOTE_HOST="tu-servidor-remoto.com"
TUNNEL_REMOTE_USER="tunnel_user"
TUNNEL_REMOTE_PORT="22"
TUNNEL_LOCAL_PORT="80"
TUNNEL_PORT="8080"

# === CONFIGURACIÓN DE MONITOREO ===
MONITOR_INTERVAL="60"          # Segundos entre verificaciones
ENABLE_AUTO_RESTART="true"     # Reinicio automático del servicio

# === CONFIGURACIÓN DE ALERTAS ===
ALERT_EMAIL="admin@tu-dominio.com"
ALERT_WEBHOOK="https://hooks.slack.com/services/..."

# === CONFIGURACIÓN AVANZADA ===
SSH_KEY_PATH="/root/.ssh/auto_tunnel_key"
LOG_LEVEL="INFO"               # DEBUG, INFO, WARNING, ERROR
MAX_RETRY_ATTEMPTS="5"         # Máximo número de reintentos
RETRY_DELAY="30"              # Segundos entre reintentos
```

### Configuración de SSH

El sistema configura automáticamente SSH hardening:

```bash
# Archivo: /etc/ssh/sshd_config (modificaciones automáticas)
PermitRootLogin yes
PasswordAuthentication yes
AllowTcpForwarding yes
GatewayPorts yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
```

### Configuración de Firewall

**UFW (Ubuntu/Debian):**
```bash
sudo ufw allow 22/tcp comment "SSH para túnel automático"
```

**Firewalld (CentOS/RHEL):**
```bash
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload
```

---

## 🛠️ Comandos de Gestión

### Comandos Básicos

```bash
# Ver estado del sistema
auto-tunnel status

# Iniciar servicio
auto-tunnel start

# Detener servicio
auto-tunnel stop

# Reiniciar servicio
auto-tunnel restart

# Ver logs
tail -f /var/log/auto_tunnel_system.log
```

### Comandos Avanzados

```bash
# Probar conectividad y configuración
auto-tunnel test

# Configurar parámetros
auto-tunnel configure

# Ver ayuda
auto-tunnel help
```

### Gestión del Servicio Systemd

```bash
# Ver estado detallado
sudo systemctl status auto-tunnel

# Ver logs del servicio
sudo journalctl -u auto-tunnel -f

# Reiniciar servicio
sudo systemctl restart auto-tunnel

# Deshabilitar inicio automático
sudo systemctl disable auto-tunnel
```

---

## 🔧 Solución de Problemas

### Problema: Túnel no se establece

**Síntomas:**
- Dashboard muestra "Túnel inactivo"
- Logs muestran errores de conexión SSH

**Solución:**
```bash
# Verificar configuración
cat /etc/auto_tunnel_config.conf

# Probar conexión manual
ssh -i /root/.ssh/auto_tunnel_key tunnel_user@remote-server

# Verificar clave SSH
ssh-keygen -l -f /root/.ssh/auto_tunnel_key.pub

# Revisar logs detallados
tail -50 /var/log/auto_tunnel_system.log
```

### Problema: Dashboard no carga

**Síntomas:**
- Error 404 al acceder al dashboard
- CGI no funciona

**Solución:**
```bash
# Verificar archivos
ls -la /var/www/html/tunnel-monitor/
ls -la /usr/lib/cgi-bin/tunnel_status.cgi

# Reiniciar servicios web
sudo systemctl restart apache2  # o nginx

# Verificar permisos
chmod +x /usr/lib/cgi-bin/tunnel_status.cgi
```

### Problema: Monitor no funciona

**Síntomas:**
- Monitor muestra "Detenido"
- No hay reconexión automática

**Solución:**
```bash
# Reiniciar el servicio completo
sudo systemctl restart auto-tunnel

# Verificar procesos
ps aux | grep tunnel

# Revisar logs de systemd
sudo journalctl -u auto-tunnel --no-pager | tail -20
```

### Problema: Alertas no se envían

**Síntomas:**
- Alertas configuradas pero no llegan

**Solución:**
```bash
# Verificar configuración de email
grep ALERT_EMAIL /etc/auto_tunnel_config.conf

# Probar envío manual (si está configurado)
echo "Test alert" | mail -s "Test" admin@tu-dominio.com

# Verificar webhook
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test alert"}' \
  YOUR_WEBHOOK_URL
```

---

## 📋 Logs y Monitoreo

### Archivos de Log

```bash
# Log principal del sistema
/var/log/auto_tunnel_system.log

# Log de instalación
/var/log/auto_tunnel_install.log

# Logs de systemd
journalctl -u auto-tunnel
```

### Interpretación de Logs

**Niveles de Log:**
- `DEBUG`: Información detallada para troubleshooting
- `INFO`: Eventos normales del sistema
- `WARNING`: Situaciones que requieren atención
- `ERROR`: Errores que impiden funcionamiento
- `SUCCESS`: Operaciones completadas exitosamente

**Mensajes Comunes:**
```
[INFO] IP privada detectada: 192.168.1.100 - Verificando túnel
[WARNING] Túnel inactivo - Intentando reconectar
[SUCCESS] Túnel SSH establecido exitosamente (PID: 1234)
[ERROR] Falló al establecer el túnel SSH
```

### Monitoreo con Scripts Personalizados

```bash
#!/bin/bash
# Script de monitoreo personalizado

TUNNEL_STATUS=$(auto-tunnel status | grep "Túnel SSH" | cut -d: -f2 | tr -d ' ')

if [[ "$TUNNEL_STATUS" != "Activo" ]]; then
    echo "ALERTA: Túnel inactivo" | mail -s "Alerta Túnel" admin@tu-dominio.com
fi
```

---

## 🔒 Seguridad

### Configuración SSH Segura

El sistema implementa automáticamente:

- **Autenticación por clave**: Solo claves SSH, sin contraseñas
- **Limitación de intentos**: Máximo 3 intentos de autenticación
- **Timeouts**: Conexiones inactivas se cierran automáticamente
- **Forwarding controlado**: Solo forwarding necesario para túneles

### Mejores Prácticas

1. **Usar claves SSH dedicadas**: No reutilizar claves existentes
2. **Configurar firewall**: Limitar acceso SSH a IPs específicas
3. **Monitorear logs**: Revisar logs regularmente para detectar anomalías
4. **Actualizar regularmente**: Mantener el sistema y dependencias actualizadas
5. **Backup de configuración**: Hacer backup de `/etc/auto_tunnel_config.conf`

### Configuración de Seguridad Adicional

```bash
# Archivo: /etc/ssh/sshd_config (configuración adicional recomendada)
# Agregar estas líneas para mayor seguridad:

# Deshabilitar autenticación por contraseña (solo claves)
PasswordAuthentication no

# Especificar usuarios permitidos
AllowUsers tunnel_user root

# Deshabilitar root login remoto
PermitRootLogin no

# Reiniciar SSH
sudo systemctl restart sshd
```

---

## 🔄 Actualizaciones y Mantenimiento

### Actualizar el Sistema

```bash
# Detener el servicio
sudo systemctl stop auto-tunnel

# Actualizar desde el repositorio
cd /path/to/repo
git pull origin main

# Reinstalar
sudo bash install_auto_tunnel_system.sh install

# Reiniciar servicio
sudo systemctl start auto-tunnel
```

### Backup de Configuración

```bash
# Backup automático
sudo cp /etc/auto_tunnel_config.conf /etc/auto_tunnel_config.conf.backup

# Backup manual
sudo tar -czf auto-tunnel-backup-$(date +%Y%m%d).tar.gz \
  /etc/auto_tunnel_config.conf \
  /var/log/auto_tunnel_system.log \
  /root/.ssh/auto_tunnel_key*
```

### Monitoreo de Recursos

```bash
# Verificar uso de recursos
ps aux | grep tunnel
top -p $(pgrep -f "auto_tunnel")

# Verificar conexiones de red
netstat -tlnp | grep :22
ss -tlnp | grep :22
```

---

## 🆘 Soporte y Troubleshooting

### Información para Reportar Problemas

Al reportar un problema, incluya:

1. **Versión del sistema**: `auto-tunnel --version`
2. **Logs relevantes**: Últimas 50 líneas de `/var/log/auto_tunnel_system.log`
3. **Configuración**: Contenido de `/etc/auto_tunnel_config.conf` (sin claves sensibles)
4. **Estado del sistema**: Output de `auto-tunnel status`
5. **Información del sistema**: `uname -a`, distribución, versión

### Comandos de Diagnóstico

```bash
# Diagnóstico completo
sudo bash /usr/local/bin/auto_tunnel_system.sh test

# Verificar conectividad de red
ping -c 4 8.8.8.8
curl -I https://api.ipify.org

# Verificar servicios
sudo systemctl status auto-tunnel
sudo systemctl status sshd

# Verificar configuración SSH
sudo sshd -T | grep -E "(permitrootlogin|passwordauthentication|allowtcpforwarding)"
```

---

## 📈 Rendimiento y Optimización

### Optimizaciones Recomendadas

1. **Intervalos de monitoreo**: Ajustar según necesidades (60s por defecto)
2. **Timeouts de conexión**: Configurar según latencia de red
3. **Límites de recursos**: Configurar límites de CPU/memoria en systemd
4. **Compresión SSH**: Habilitar compresión para enlaces lentos

### Configuración de Rendimiento

```bash
# Archivo: /etc/auto_tunnel_config.conf
MONITOR_INTERVAL="30"          # Verificación más frecuente
MAX_RETRY_ATTEMPTS="3"         # Menos reintentos
RETRY_DELAY="10"              # Reconexión más rápida
```

### Monitoreo de Rendimiento

```bash
# Verificar uso de CPU/memoria
pidstat -p $(pgrep -f "tunnel_monitor") 1 5

# Verificar conexiones SSH
ss -t | grep ssh

# Verificar logs por rendimiento
grep "reconectar\|falló\|establecido" /var/log/auto_tunnel_system.log | tail -10
```

---

## 🎯 Casos de Uso

### 1. Servidores en Redes Privadas
- **Escenario**: VPS en red privada que necesita acceso público
- **Solución**: Túnel automático mantiene disponibilidad 24/7

### 2. Desarrollo Local
- **Escenario**: Desarrollador que necesita exponer aplicación local
- **Solución**: Túnel automático para demos y testing

### 3. Backup de Servidores
- **Escenario**: Servidores sin IP pública para backups remotos
- **Solución**: Túnel automático garantiza conectividad

### 4. IoT y Dispositivos Edge
- **Escenario**: Dispositivos IoT detrás de NAT
- **Solución**: Túnel automático mantiene conectividad bidireccional

---

## 📝 Licencia y Contribución

### Licencia
Este sistema se distribuye bajo la **Licencia MIT**.

### Contribución
Para contribuir:

1. Fork el repositorio
2. Crear una rama para tu feature
3. Commit tus cambios
4. Push a la rama
5. Crear un Pull Request

### Reportar Bugs
- Usa el sistema de issues de GitHub
- Incluye logs y configuración
- Describe pasos para reproducir el problema

---

*Última actualización: $(date)*
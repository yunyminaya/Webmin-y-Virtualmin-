# Guía Completa del Optimizador del Sistema Ubuntu

## Overview

El Optimizador del Sistema Ubuntu es una solución integral diseñada para mejorar drásticamente la seguridad, rendimiento y funcionalidad de servidores Ubuntu con Webmin/Virtualmin. Este sistema automatiza la configuración de múltiples capas de seguridad y optimización.

## 🚀 Características Principales

### Seguridad Avanzada
- ✅ **Gestión Segura de Credenciales**: Sistema de cifrado AES-256 para almacenamiento seguro
- ✅ **Firewall Inteligente**: Protección dinámica con aprendizaje automático
- ✅ **Defensa con IA**: Detección de anomalías y patrones de ataque
- ✅ **SSL/TLS Automático**: Certificados gratuitos con renovación automática
- ✅ **Hardening del Sistema**: Configuración de seguridad enterprise-grade

### Monitoreo y Optimización
- ✅ **Monitoreo Avanzado**: Metrics en tiempo real con Prometheus
- ✅ **Optimización de Rendimiento**: Ajuste automático de parámetros del kernel
- ✅ **Gestión de Recursos**: Optimización de memoria y CPU
- ✅ **Alertas Inteligentes**: Notificaciones proactivas de problemas

### Respaldo y Recuperación
- ✅ **Respaldos Automatizados**: Sistema inteligente con retención configurable
- ✅ **Recuperación ante Desastres**: Estrategias completas de DR
- ✅ **Integridad de Datos**: Verificación automática de respaldos

### Integración con Cloud
- ✅ **Multi-Cloud**: Soporte para AWS, GCP, Azure
- ✅ **Balanceo de Carga**: Distribución inteligente de tráfico
- ✅ **Escalabilidad Automática**: Ajuste dinámico de recursos

## 📋 Requisitos del Sistema

### Mínimos
- Ubuntu 20.04 LTS o superior
- 2 GB RAM
- 20 GB espacio en disco
- Acceso root/sudo

### Recomendados
- Ubuntu 22.04 LTS
- 4 GB RAM o más
- 50 GB espacio en disco SSD
- Conexión a internet estable

## 🔧 Instalación

### Paso 1: Descargar el Sistema
```bash
# Clonar el repositorio
git clone https://github.com/tu-usuario/webmin-virtualmin-optimized.git
cd webmin-virtualmin-optimized

# O descargar directamente
wget https://github.com/tu-usuario/webmin-virtualmin-optimized/archive/main.zip
unzip main.zip
cd webmin-virtualmin-optimized-main
```

### Paso 2: Verificar Dependencias
```bash
# Verificar que se tiene Python 3.8+
python3 --version

# Verificar OpenSSL
openssl version

# Verificar espacio en disco
df -h
```

### Paso 3: Ejecutar Optimización
```bash
# Hacer ejecutable el script
chmod +x ubuntu_system_optimizer.sh

# Ejecutar como root
sudo ./ubuntu_system_optimizer.sh
```

## 📊 Componentes Instalados

### 1. Sistema de Gestión Segura de Credenciales
**Ubicación**: `/opt/webmin_credential_system/`

**Funcionalidades**:
- Cifrado AES-256 con derivación de clave HMAC-SHA256
- Salt único para cada instalación
- Validación de integridad de datos
- Permisos seguros (600/700)

**Uso básico**:
```bash
# Inicializar sistema
/opt/webmin_credential_system/secure_credentials_test.sh init

# Almacenar credencial
/opt/webmin_credential_system/secure_credentials_test.sh store "mysql" "admin" "password123"

# Recuperar credencial
/opt/webmin_credential_system/secure_credentials_test.sh retrieve "mysql"

# Listar servicios
/opt/webmin_credential_system/secure_credentials_test.sh list
```

### 2. Firewall Inteligente
**Ubicación**: `/opt/webmin_credential_system/intelligent-firewall/`

**Funcionalidades**:
- Detección de patrones anómalos
- Bloqueo dinámico de IPs maliciosas
- Aprendizaje automático de tráfico
- Integración conFail2Ban

**Configuración**:
```bash
# Verificar estado
systemctl status intelligent-firewall

# Ver reglas activas
perl /opt/webmin_credential_system/intelligent-firewall/smart_lists.pl

# Agregar IP segura
perl /opt/webmin_credential_system/intelligent-firewall/smart_lists.pl allow 192.168.1.100
```

### 3. Sistema de Defensa con IA
**Ubicación**: `/opt/webmin_credential_system/ai_defense_system.sh`

**Funcionalidades**:
- Análisis de patrones de tráfico
- Detección de anomalías con Machine Learning
- Respuesta automática a amenazas
- Reportes de seguridad

**Uso**:
```bash
# Analizar logs de Apache
/opt/webmin_credential_system/ai_defense_system.sh analyze_traffic_patterns /var/log/apache2/access.log

# Generar reporte de seguridad
/opt/webmin_credential_system/ai_defense_system.sh generate_security_report
```

### 4. Monitoreo Avanzado
**Componentes**:
- **Node Exporter**: Métricas del sistema (puerto 9100)
- **Prometheus**: Recolección de métricas
- **Grafana**: Visualización (opcional)

**Acceso**:
- Node Exporter: `http://IP-SERVIDOR:9100/metrics`
- Webmin Monitoring: Integrado en Webmin

### 5. Sistema SSL/TLS
**Ubicación**: `/opt/webmin_credential_system/advanced_ssl_manager.sh`

**Funcionalidades**:
- Certificados SSL gratuitos con Let's Encrypt
- Renovación automática
- Configuración para Apache/Nginx
- Monitoreo de expiración

**Uso**:
```bash
# Solicitar certificado para dominio
/opt/webmin_credential_system/advanced_ssl_manager.sh request_cert ejemplo.com

# Renovar certificados
/opt/webmin_credential_system/advanced_ssl_manager.sh renew_all

# Verificar estado
/opt/webmin_credential_system/advanced_ssl_manager.sh status
```

### 6. Sistema de Respaldos
**Ubicación**: `/opt/webmin_credential_system/backup_system.sh`

**Funcionalidades**:
- Respaldos incrementales diarios
- Retención configurable (7 días diarios, 4 semanas, 12 meses)
- Compresión y cifrado
- Verificación de integridad

**Configuración**:
```bash
# Ejecutar respaldo manual
/opt/webmin_credential_system/backup_system.sh

# Verificar últimos respaldos
ls -la /opt/backups/daily/

# Restaurar desde backup
tar -xzf /opt/backups/daily/webmin_backup_YYYYMMDD_HHMMSS.tar.gz -C /
```

## 🔒 Configuración de Seguridad

### Acceso a Webmin
- **URL**: `https://IP-SERVIDOR:10000`
- **Usuario**: root o usuario configurado
- **Recomendación**: Cambiar contraseña inmediatamente

### Configuración SSH
```bash
# Verificar configuración SSH
cat /etc/ssh/sshd_config | grep -E "PermitRootLogin|PasswordAuthentication"

# Reiniciar servicio SSH
systemctl restart sshd
```

### Reglas de Firewall
```bash
# Verificar estado de UFW
ufw status verbose

# Agregar nueva regla
ufw allow 8080/tcp

# Eliminar regla
ufw delete allow 8080/tcp
```

## 📈 Monitoreo y Mantenimiento

### Verificar Estado de Servicios
```bash
# Script para verificar todos los servicios
for service in webmin ssh ufw fail2ban node_exporter webmin-monitoring ai-defense intelligent-firewall; do
    echo "=== $service ==="
    systemctl is-active $service
    echo ""
done
```

### Logs Importantes
- **Optimización**: `/var/log/ubuntu_system_optimizer_*.log`
- **Webmin**: `/var/webmin/miniserv.log`
- **Firewall**: `/var/log/ufw.log`
- **Fail2Ban**: `/var/log/fail2ban.log`
- **AI Defense**: `/var/log/ai_defense.log`

### Mantenimiento Programado
El sistema configura automáticamente las siguientes tareas:

**Cron Jobs Configurados**:
```bash
# Respaldos diarios (2 AM)
0 2 * * * root /opt/webmin_credential_system/backup_system.sh

# Renovación SSL (3 AM)
0 3 * * * root certbot renew --quiet --post-hook "systemctl reload apache2 || systemctl reload nginx"

# Limpieza de logs (4 AM dominical)
0 4 * * 0 root find /var/log -name "*.log" -mtime +30 -delete
```

## 🚨 Solución de Problemas

### Problemas Comunes

#### 1. Webmin no inicia
```bash
# Verificar estado
systemctl status webmin

# Ver logs
journalctl -u webmin -f

# Reiniciar servicio
systemctl restart webmin
```

#### 2. Firewall bloqueando acceso
```bash
# Verificar reglas
ufw status verbose

# Deshabilitar temporalmente (para diagnóstico)
ufw disable

# Rehabilitar
ufw enable
```

#### 3. Certificados SSL no renovan
```bash
# Verificar configuración
cat /etc/cron.d/certbot-renewal

# Ejecutar manualmente
certbot renew --dry-run

# Verificar logs
tail -f /var/log/letsencrypt/letsencrypt.log
```

#### 4. Sistema de credenciales no funciona
```bash
# Verificar permisos
ls -la /opt/webmin_credential_system/

# Verificar OpenSSL
openssl version

# Probar manualmente
/opt/webmin_credential_system/secure_credentials_test.sh init
```

### Recuperación del Sistema
Si algo falla, puedes restaurar desde el backup creado durante la instalación:

```bash
# Listar backups disponibles
ls -la /opt/system_optimizer_backup_*/

# Restaurar configuración crítica
cp /opt/system_optimizer_backup_*/etc/ssh/sshd_config /etc/ssh/
cp /opt/system_optimizer_backup_*/etc/ufw/* /etc/ufw/

# Reiniciar servicios
systemctl restart sshd ufw webmin
```

## 📊 Métricas y Rendimiento

### Métricas Disponibles
- **CPU**: Uso por núcleo, load average
- **Memoria**: RAM, swap, caché
- **Disco**: I/O, espacio disponible
- **Red**: Tráfico por interfaz
- **Procesos**: Top procesos por recurso

### Optimizaciones Aplicadas
- **Kernel**: Parámetros TCP optimizados
- **Memoria**: Swappiness ajustado a 10%
- **Red**: BBR congestion control habilitado
- **Límites**: 65536 archivos por proceso

## 🔧 Personalización

### Configurar Dominios
```bash
# Agregar dominio para certificado SSL
/opt/webmin_credential_system/advanced_ssl_manager.sh request_cert midominio.com

# Configurar VirtualHost en Apache
cat > /etc/apache2/sites-available/midominio.com.conf << 'EOF'
<VirtualHost *:443>
    ServerName midominio.com
    DocumentRoot /var/www/midominio.com
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/midominio.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/midominio.com/privkey.pem
</VirtualHost>
EOF

a2ensite midominio.com
systemctl reload apache2
```

### Configurar Alertas
```bash
# Editar configuración de notificaciones
nano /opt/webmin_credential_system/config/alerts.conf

# Agregar correo electrónico
echo "admin@midominio.com" > /opt/webmin_credential_system/config/admin_email.txt
```

### Personalizar Firewall
```bash
# Editar reglas personalizadas
nano /opt/webmin_credential_system/intelligent-firewall/custom_rules.pl

# Recargar reglas
systemctl restart intelligent-firewall
```

## 📚 Referencias y Documentación Adicional

### Documentación de Componentes
- [Sistema de Credenciales Seguras](SECURE_CREDENTIALS_SYSTEM_GUIDE.md)
- [Firewall Inteligente](INTELLIGENT_FIREWALL_README.md)
- [Sistema SSL Avanzado](SISTEMA_SSL_AVANZADO_README.md)
- [Sistema SIEM](SIEM_SYSTEM_GUIDE.md)
- [Arquitectura Zero Trust](ZERO_TRUST_GUIDE.md)

### Comandos Útiles
```bash
# Verificar versión del optimizador
cat /opt/webmin_credential_system/VERSION

# Verificar estado general
/opt/webmin_credential_system/health_check.sh

# Generar reporte de seguridad
/opt/webmin_credential_system/security_audit.sh

# Actualizar sistema
/opt/webmin_credential_system/update_system.sh
```

## 🆘 Soporte y Asistencia

### Canales de Soporte
- **Documentación**: Consulta las guías específicas de cada componente
- **Logs**: Revisa los archivos de log en `/var/log/`
- **Community**: GitHub Issues y Discusiones
- **Emergency**: Utiliza el backup de restauración si es necesario

### Reporte de Problemas
Al reportar problemas, incluye:
1. Versión de Ubuntu (`lsb_release -a`)
2. Versión del optimizador
3. Logs relevantes
4. Pasos para reproducir el problema
5. Comandos ejecutados y su salida

---

**Nota**: Este sistema está diseñado para servidores production-ready. Siempre realiza pruebas en un entorno de desarrollo antes de implementar en producción.

**Aviso de Seguridad**: Mantén el sistema actualizado y revisa regularmente los logs de seguridad para detectar actividades sospechosas.
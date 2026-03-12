# Sistema Avanzado de Encriptación y Gestión de Certificados SSL/TLS

## Descripción General

Este sistema implementa una solución completa y avanzada para la gestión de certificados SSL/TLS en entornos Webmin/Virtualmin, proporcionando encriptación de extremo a extremo, automatización completa y monitoreo continuo.

## Funcionalidades Implementadas

### 1. Generación Automática de Certificados SSL/TLS con Let's Encrypt
- **Certbot Integration**: Configuración completa con Let's Encrypt
- **Soporte Multi-Dominio**: Generación automática para múltiples dominios
- **Validación Automática**: HTTP-01 challenge para validación automática
- **Script Principal**: `advanced_ssl_manager.sh generate`

### 2. Renovación Automática de Certificados
- **Cron Jobs**: Renovación diaria automática a las 2:00 AM
- **Servicio Systemd**: Monitoreo continuo cada hora
- **Recarga Automática**: Reinicio automático de servicios después de renovación
- **Archivos**: `ssl_renewal.cron`, `ssl_monitor.service`, `ssl_monitor.timer`

### 3. Gestión de Certificados Wildcard
- **DNS Challenge**: Soporte para certificados wildcard usando DNS-01
- **Configuración Manual**: Instrucciones para configuración DNS
- **Validación Automática**: Verificación de resolución DNS

### 4. Encriptación de Datos Sensibles en Reposo
- **AES-256-CBC**: Encriptación fuerte para archivos sensibles
- **Gestión de Claves**: Claves generadas dinámicamente
- **Almacenamiento Seguro**: Directorio dedicado `/etc/ssl/private/encrypted`
- **Comandos**: `encrypt <file>`, `decrypt <file>`

### 5. Encriptación de Datos en Tránsito
- **SSL/TLS Completo**: Configuración end-to-end
- **Protocolos Seguros**: TLS 1.2/1.3 únicamente
- **Cifrados Fuertes**: ECDHE con curvas elípticas
- **HSTS**: HTTP Strict Transport Security habilitado

### 6. Rotación Automática de Claves
- **Política de 90 días**: Rotación automática cada 3 meses
- **Backup de Claves**: Conservación de claves anteriores
- **Renovación de Certificados**: Regeneración automática post-rotación
- **Comando**: `rotate`

### 7. Validación Automática de Certificados
- **Monitoreo Continuo**: Verificación cada hora
- **Alertas de Expiración**: Notificaciones 30 días antes
- **Verificación de Integridad**: Validación de cadena de certificados
- **Comando**: `validate`

### 8. Dashboard Web para Monitoreo
- **Interfaz HTML5**: Dashboard responsive y moderno
- **API REST**: Endpoint JSON para datos de certificados
- **Actualización en Tiempo Real**: Refresco automático cada 5 minutos
- **Métricas Visuales**: Estados, fechas de expiración, días restantes
- **Ubicación**: `/var/www/html/ssl_dashboard/`

### 9. Integración con Apache
- **Configuración SSL Avanzada**: OCSP Stapling, Session Caching
- **Virtual Hosts SSL**: Configuración automática para HTTPS
- **Headers de Seguridad**: CSP, X-Frame-Options, etc.
- **Archivo**: `configs/apache/httpd.conf` modificado

### 10. Integración con Nginx
- **Configuración Completa**: SSL, compresión, seguridad
- **Load Balancing**: Soporte para múltiples backends
- **Rate Limiting**: Protección contra ataques
- **Archivo**: `nginx_ssl.conf`

### 11. Integración con Servicios del Sistema
- **MySQL/MariaDB**: SSL obligatorio para conexiones
- **Postfix**: Encriptación SMTP con STARTTLS
- **Dovecot**: IMAPS/POP3S seguro
- **Archivos**: `my.cnf`, `postfix_ssl.conf`, `dovecot_ssl.conf`

### 12. Integración con Webmin/Virtualmin
- **API de Virtualmin**: Gestión automática de dominios
- **Instalación de Certificados**: Integración directa con panel
- **Monitoreo de Estados**: Verificación de SSL por dominio
- **Script**: `virtualmin_ssl_integration.sh`

### 13. Sistema de Pruebas Exhaustivo
- **Validación Completa**: 7 suites de pruebas automatizadas
- **Verificación de Dependencias**: Certbot, OpenSSL, Virtualmin
- **Sintaxis de Scripts**: Validación bash
- **Configuraciones**: Verificación de archivos de configuración
- **Script**: `test_ssl_system.sh`

## Arquitectura del Sistema

```
Sistema SSL Avanzado
├── advanced_ssl_manager.sh (Script principal)
├── virtualmin_ssl_integration.sh (Integración Virtualmin)
├── test_ssl_system.sh (Sistema de pruebas)
├── ssl_renewal.cron (Tareas programadas)
├── ssl_monitor.service/.timer (Servicio systemd)
├── Configuraciones específicas:
│   ├── configs/apache/httpd.conf (Apache SSL)
│   ├── configs/mysql/my.cnf (MySQL SSL)
│   ├── nginx_ssl.conf (Nginx SSL)
│   ├── postfix_ssl.conf (Postfix SSL)
│   ├── dovecot_ssl.conf (Dovecot SSL)
│   └── ssl_dashboard_apache.conf (Dashboard Apache)
└── Dashboard web (/var/www/html/ssl_dashboard/)
    ├── index.html
    ├── api_certificates.sh
    └── CSS/JS para interfaz
```

## Instalación y Configuración

### 1. Instalación de Dependencias
```bash
# Instalar Certbot
sudo apt update && sudo apt install certbot  # Ubuntu/Debian
# o
brew install certbot  # macOS

# Instalar dependencias adicionales
sudo apt install openssl apache2 nginx mysql-server postfix dovecot
```

### 2. Configuración del Sistema
```bash
# Hacer ejecutables los scripts
chmod +x advanced_ssl_manager.sh
chmod +x virtualmin_ssl_integration.sh
chmod +x test_ssl_system.sh

# Copiar scripts a ubicación global
sudo cp advanced_ssl_manager.sh /usr/local/bin/
sudo cp virtualmin_ssl_integration.sh /usr/local/bin/

# Instalar cron jobs
sudo cp ssl_renewal.cron /etc/cron.d/ssl-renewal

# Instalar servicios systemd
sudo cp ssl_monitor.service /etc/systemd/system/
sudo cp ssl_monitor.timer /etc/systemd/system/
sudo systemctl enable ssl_monitor.timer
sudo systemctl start ssl_monitor.timer
```

### 3. Configuración de Servicios
```bash
# Apache
sudo cp configs/apache/httpd.conf /etc/apache2/
sudo a2enmod ssl headers rewrite
sudo systemctl reload apache2

# Nginx
sudo cp nginx_ssl.conf /etc/nginx/sites-available/ssl-site
sudo ln -s /etc/nginx/sites-available/ssl-site /etc/nginx/sites-enabled/
sudo systemctl reload nginx

# MySQL
sudo cp configs/mysql/my.cnf /etc/mysql/
sudo systemctl restart mysql

# Postfix
sudo cp postfix_ssl.conf /etc/postfix/
sudo systemctl reload postfix

# Dovecot
sudo cp dovecot_ssl.conf /etc/dovecot/
sudo systemctl reload dovecot
```

## Uso del Sistema

### Comandos Principales

```bash
# Generar certificados para todos los dominios
advanced_ssl_manager.sh generate

# Renovar certificados expirados
advanced_ssl_manager.sh renew

# Rotar claves de certificados
advanced_ssl_manager.sh rotate

# Validar estado de certificados
advanced_ssl_manager.sh validate

# Crear dashboard de monitoreo
advanced_ssl_manager.sh dashboard

# Encriptar archivo sensible
advanced_ssl_manager.sh encrypt /ruta/al/archivo.conf

# Desencriptar archivo
advanced_ssl_manager.sh decrypt /ruta/al/archivo.conf.enc
```

### Integración con Virtualmin

```bash
# Verificar estado SSL de dominios
virtualmin_ssl_integration.sh check

# Renovar certificados usando Virtualmin
virtualmin_ssl_integration.sh renew

# Instalar certificado en dominio específico
virtualmin_ssl_integration.sh install ejemplo.com

# Configurar SSL automático para nuevos dominios
virtualmin_ssl_integration.sh setup-auto

# Listar dominios con estado SSL
virtualmin_ssl_integration.sh list
```

### Ejecución de Pruebas

```bash
# Ejecutar suite completa de pruebas
./test_ssl_system.sh

# Ver resultados detallados
cat /tmp/ssl_system_test_results.txt

# Ver logs de pruebas
cat /tmp/ssl_system_test.log
```

## Dashboard Web

Accede al dashboard en: `https://tu-servidor/ssl-dashboard/`

### Características del Dashboard
- **Vista General**: Estado de todos los certificados
- **Alertas Visuales**: Indicadores de expiración próxima
- **Información Detallada**: Fechas, días restantes, estado
- **API JSON**: Endpoint `/ssl-dashboard/api/certificates`
- **Actualización Automática**: Refresco cada 5 minutos

## Monitoreo y Alertas

### Logs del Sistema
- **Principal**: `/var/log/advanced_ssl_manager.log`
- **Renovaciones**: `/var/log/ssl_renewal.log`
- **Rotaciones**: `/var/log/ssl_rotation.log`
- **Validaciones**: `/var/log/ssl_validation.log`
- **Pruebas**: `/tmp/ssl_system_test.log`

### Alertas Automáticas
- **Email**: Configurable en scripts
- **Logs**: Todos los eventos críticos se registran
- **Dashboard**: Indicadores visuales de problemas

## Seguridad Implementada

### Encriptación
- **AES-256-CBC**: Para datos en reposo
- **TLS 1.3**: Para datos en tránsito
- **ECDHE**: Intercambio de claves forward secrecy

### Políticas de Seguridad
- **HSTS**: Forzado HTTPS por 6 meses
- **CSP**: Content Security Policy
- **X-Frame-Options**: Prevención clickjacking
- **XSS Protection**: Filtros anti-XSS

### Gestión de Claves
- **Rotación Automática**: Cada 90 días
- **Backup Seguro**: Claves anteriores conservadas
- **Permisos Restringidos**: 600 para archivos de claves

## Mantenimiento

### Tareas Diarias
- Renovación automática de certificados (2:00 AM)
- Validación de expiraciones
- Monitoreo de servicios

### Tareas Semanales
- Rotación de claves (domingos 3:00 AM)
- Verificación de integridad
- Backup de configuraciones

### Tareas Mensuales
- Auditoría de logs
- Actualización de dependencias
- Revisión de políticas de seguridad

## Resolución de Problemas

### Problemas Comunes

1. **Certbot falla en renovación**
   ```bash
   # Verificar logs
   tail -f /var/log/letsencrypt/letsencrypt.log
   # Verificar conectividad
   curl -I http://tu-dominio/.well-known/acme-challenge/test
   ```

2. **Apache no carga configuración SSL**
   ```bash
   # Verificar sintaxis
   apachectl configtest
   # Verificar logs
   tail -f /var/log/apache2/error.log
   ```

3. **Dashboard no muestra datos**
   ```bash
   # Verificar permisos
   ls -la /var/www/html/ssl_dashboard/
   # Verificar API
   curl http://localhost/ssl-dashboard/api/certificates
   ```

### Comandos de Diagnóstico

```bash
# Verificar estado de servicios
systemctl status ssl_monitor.timer
systemctl status apache2
systemctl status nginx

# Verificar certificados
openssl x509 -in /etc/letsencrypt/live/tu-dominio/cert.pem -text -noout

# Verificar conectividad SSL
openssl s_client -connect tu-dominio:443 -servername tu-dominio
```

## Conclusión

Este sistema avanzado de encriptación y gestión de certificados proporciona una solución completa y automatizada para entornos Webmin/Virtualmin, asegurando:

- **Seguridad Máxima**: Encriptación end-to-end con algoritmos modernos
- **Automatización Completa**: Gestión sin intervención manual
- **Monitoreo Continuo**: Alertas y dashboards en tiempo real
- **Integración Total**: Compatibilidad con todos los servicios del sistema
- **Escalabilidad**: Soporte para múltiples dominios y servicios

El sistema está diseñado para entornos de producción, con énfasis en la seguridad, fiabilidad y facilidad de mantenimiento.
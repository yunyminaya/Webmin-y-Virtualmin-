# Guía de Instalación Segura para Producción
## Webmin/Virtualmin Enterprise - Sistema Completo

### 📋 Tabla de Contenidos

1. [Requisitos Previos](#requisitos-previos)
2. [Preparación del Entorno](#preparación-del-entorno)
3. [Instalación Segura](#instalación-segura)
4. [Configuración de Secretos](#configuración-de-secretos)
5. [Validación de Configuración](#validación-de-configuración)
6. [Verificación Post-Instalación](#verificación-post-instalación)
7. [Monitoreo y Mantenimiento](#monitoreo-y-mantenimiento)
8. [Solución de Problemas Comunes](#solución-de-problemas-comunes)

---

## 🔒 Requisitos Previos

### Requisitos del Sistema
- **Sistema Operativo**: Ubuntu 20.04+ / Debian 10+ / CentOS 8+ / RHEL 8+
- **Arquitectura**: x86_64 (amd64)
- **Memoria RAM**: Mínimo 4GB, recomendado 8GB+
- **Almacenamiento**: Mínimo 20GB libres, recomendado 50GB+
- **Red**: Conexión a internet estable

### Requisitos de Software
- **Shell**: Bash 4.0+
- **Python**: 3.6+ (para componentes opcionales)
- **OpenSSL**: 1.1.1+ (para gestión de certificados)
- **Git**: 2.0+ (para clonado del repositorio)

### Requisitos de Seguridad
- **Acceso Root**: Requerido para instalación
- **Firewall**: Configurado y activo
- **Usuarios**: Sin usuarios sin contraseña
- **Actualizaciones**: Sistema actualizado

---

## 🛠️ Preparación del Entorno

### 1. Clonar el Repositorio
```bash
# Clonar el repositorio seguro
git clone https://github.com/your-org/webmin-virtualmin-enterprise.git
cd webmin-virtualmin-enterprise

# Verificar integridad del repositorio
git fsck --full
```

### 2. Verificar Firma del Repositorio
```bash
# Verificar firma GPG (si está disponible)
git verify-commit HEAD

# O verificar checksum del release
sha256sum webmin-virtualmin-enterprise.tar.gz
```

### 3. Preparar Variables de Entorno
```bash
# Copiar plantilla de entorno seguro
cp .env.production.example .env

# Establecer permisos restrictivos
chmod 600 .env
chown root:root .env

# Agregar a .gitignore
echo ".env" >> .gitignore
echo "*.key" >> .gitignore
echo "*.pem" >> .gitignore
```

---

## 🚀 Instalación Segura

### 1. Ejecutar Instalador Seguro
```bash
# Dar permisos de ejecución
chmod +x install_production_secure.sh
chmod +x security/secret_manager.sh
chmod +x security/config_validator.sh

# Ejecutar instalación segura
sudo ./install_production_secure.sh
```

### 2. Configurar Variables Críticas
Antes de ejecutar la instalación, configure las siguientes variables en `.env`:

```bash
# Entorno
DEPLOYMENT_ENV=production
SERVER_ROLE=webmin_server

# Configuración de red
WEBMIN_PORT=10000
SSH_ALLOW_RANGES="192.168.1.0/24,10.0.0.0/8"
WEBMIN_ALLOW_RANGES="192.168.1.0/24"

# Dominio SSL
SSL_DOMAIN=your-domain.com
SSL_EMAIL=admin@your-domain.com
```

### 3. Configurar Gestor de Secretos
```bash
# Inicializar gestor de secretos
sudo ./security/secret_manager.sh init

# Almacenar credenciales críticas
sudo ./security/secret_manager.sh store db_password "TuPasswordSeguro123" "Contraseña de base de datos"
sudo ./security/secret_manager.sh store aws_secret_key "tu-aws-secret-key" "Clave secreta de AWS"
sudo ./security/secret_manager.sh store virtualmin_license "tu-licencia-virtualmin" "Licencia de Virtualmin"
```

---

## 🔐 Configuración de Secretos

### Gestión de Credenciales
El sistema incluye un gestor de secretos seguro con las siguientes características:

- **Encriptación AES-256-CBC** para todos los secretos
- **Control de acceso** con logging de auditoría
- **Rotación automática** de claves
- **Backup encriptado** de secretos

### Comandos del Gestor de Secretos
```bash
# Inicializar sistema
./security/secret_manager.sh init

# Almacenar secreto
./security/secret_manager.sh store <nombre> <valor> [descripción]

# Recuperar secreto
./security/secret_manager.sh retrieve <nombre>

# Listar secretos
./security/secret_manager.sh list

# Eliminar secreto
./security/secret_manager.sh delete <nombre>

# Rotar claves
./security/secret_manager.sh rotate

# Validar configuración
./security/secret_manager.sh validate
```

### Secretos Recomendados
Configure los siguientes secretos usando el gestor:

```bash
# Base de datos
./security/secret_manager.sh store db_password "ContraseñaSeguraDB" "Contraseña de base de datos MySQL/MariaDB"

# Webmin
./security/secret_manager.sh store webmin_admin_password "ContraseñaAdminWebmin" "Contraseña de administrador de Webmin"

# SSL/TLS
./security/secret_manager.sh store ssl_private_key "ClavePrivadaSSL" "Clave privada para certificados SSL"

# Backup
./security/secret_manager.sh store backup_encryption_key "ClaveEncriptacionBackup" "Clave para encriptar backups"

# AWS (si aplica)
./security/secret_manager.sh store aws_access_key "AWSAccessKey" "Clave de acceso AWS"
./security/secret_manager.sh store aws_secret_key "AWSSecretKey" "Clave secreta AWS"

# Notificaciones
./security/secret_manager.sh store smtp_password "ContraseñaSMTP" "Contraseña para servidor SMTP"
./security/secret_manager.sh store slack_webhook "WebhookSlack" "URL de webhook para Slack"
```

---

## ✅ Validación de Configuración

### Ejecutar Validación Pre-Despliegue
```bash
# Validar configuración antes del despliegue
sudo ./security/config_validator.sh
```

La validación verifica:
- **Archivos de configuración**: Permisos y valores hardcoded
- **Variables de entorno**: Completitud y encriptación
- **Configuración SSL/TLS**: Certificados válidos y configuración
- **Base de datos**: Configuración segura y acceso local
- **Firewall**: Reglas apropiadas y servicios activos
- **Backup**: Scripts configurados y programados
- **Monitoreo**: Servicios activos y logs configurados
- **Seguridad de archivos**: Permisos y directorios críticos
- **Red**: Parámetros del kernel y servicios innecesarios
- **Usuarios**: Configuración de usuarios y autenticación

### Criterios de Validación
- ✅ **Aprobado**: 90-100 puntos, sin errores críticos
- ⚠️ **Advertencia**: 70-89 puntos, algunas mejoras recomendadas
- ❌ **Fallido**: < 70 puntos o errores críticos presentes

---

## 🔍 Verificación Post-Instalación

### Ejecutar Verificación Completa
```bash
# Verificar instalación post-despliegue
sudo ./security/post_install_verification.sh
```

La verificación incluye:
- **Instalación Webmin/Virtualmin**: Servicios y configuración SSL
- **Base de datos**: Configuración segura y servicio activo
- **SSL/TLS**: Certificados válidos y configuración correcta
- **Firewall**: Reglas activas y servicios permitidos
- **Monitoreo**: Fail2Ban, auditoría y AIDE configurados
- **Backup**: Scripts activos y permisos correctos
- **Gestión de secretos**: Sistema configurado y claves seguras
- **Sistema**: Usuarios, permisos y parámetros del kernel
- **Red**: Servicios innecesarios deshabilitados y sticky bits

### Puntuación de Seguridad
La verificación genera una puntuación de seguridad (0-100):
- **90-100**: Excelente (A)
- **80-89**: Bueno (B)
- **70-79**: Aceptable (C)
- **60-69**: Mejorable (D)
- **< 60**: Fallido (F)

---

## 📊 Monitoreo y Mantenimiento

### Monitoreo Continuo
Configure los siguientes sistemas de monitoreo:

#### 1. Monitoreo de Seguridad
```bash
# Verificar estado de Fail2Ban
sudo fail2ban-client status

# Verificar logs de auditoría
sudo ausearch -ts recent

# Verificar estado de AIDE
sudo aide --check
```

#### 2. Monitoreo de Rendimiento
```bash
# Monitorear recursos del sistema
htop
iotop
nethogs

# Monitorear servicios Webmin
sudo systemctl status webmin
sudo journalctl -u webmin -f
```

#### 3. Monitoreo de Logs
```bash
# Logs de Webmin
tail -f /var/log/webmin/miniserv.log

# Logs de seguridad
tail -f /var/log/auth.log
tail -f /var/log/fail2ban.log

# Logs de auditoría
tail -f /var/log/audit/audit.log
```

### Mantenimiento Programado

#### 1. Actualizaciones de Seguridad
```bash
# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Actualizar Webmin/Virtualmin
sudo /usr/share/webmin/update.sh

# Actualizar certificados SSL
sudo certbot renew --dry-run
```

#### 2. Rotación de Secretos
```bash
# Rotar claves de encriptación (cada 90 días)
sudo ./security/secret_manager.sh rotate

# Rotar contraseñas de usuarios (cada 90 días)
sudo chage -M 90 username
```

#### 3. Verificación de Backups
```bash
# Verificar backups recientes
sudo /opt/webmin-backups/backup_secure.sh --verify

# Restaurar backup de prueba
sudo /opt/webmin-backups/backup_secure.sh --restore-test
```

---

## 🚨 Solución de Problemas Comunes

### Problemas de Instalación

#### Error: Permiso denegado
```bash
# Solución
sudo chmod +x install_production_secure.sh
sudo ./install_production_secure.sh
```

#### Error: Dependencias faltantes
```bash
# Solución
sudo apt update
sudo apt install -y curl wget gnupg2 software-properties-common
```

#### Error: Firewall bloqueando instalación
```bash
# Solución temporal
sudo ufw allow out 53,80,443,8080
# Revertir después de la instalación
sudo ufw delete allow out 53,80,443,8080
```

### Problemas de Configuración

#### Error: Certificado SSL inválido
```bash
# Verificar certificado
openssl x509 -in /etc/letsencrypt/live/domain.com/cert.pem -text -noout

# Renovar certificado
sudo certbot renew --cert-name domain.com
```

#### Error: Webmin no accesible
```bash
# Verificar servicio
sudo systemctl status webmin

# Verificar configuración de red
sudo netstat -tlnp | grep :10000

# Verificar firewall
sudo ufw status | grep 10000
```

### Problemas de Rendimiento

#### Error: Alto uso de memoria
```bash
# Identificar procesos
ps aux --sort=-%mem | head

# Optimizar MySQL
sudo mysql -e "SET GLOBAL innodb_buffer_pool_size = 1073741824;"
```

#### Error: Conexiones lentas
```bash
# Verificar consultas lentas
sudo mysql -e "SELECT * FROM mysql.slow_log ORDER BY start_time DESC LIMIT 10;"

# Optimizar configuración
sudo mysql -e "SET GLOBAL query_cache_size = 268435456;"
```

---

## 📚 Referencias Adicionales

### Documentación Oficial
- [Webmin Documentation](https://doxfer.webmin.com/)
- [Virtualmin Documentation](https://www.virtualmin.com/documentation/)
- [Security Best Practices](https://www.virtualmin.com/docs/security/)

### Guías de Seguridad
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework/)

### Herramientas Recomendadas
- **Escaneo de vulnerabilidades**: Nessus, OpenVAS
- **Monitoreo**: Prometheus, Grafana, ELK Stack
- **Backup**: Restic, BorgBackup
- **Auditoría**: Lynis, Chkrootkit

---

## 🔄 Proceso de Actualización

### Actualización del Sistema
1. **Backup completo** antes de actualizar
2. **Validar configuración** actual
3. **Ejecutar actualización** en modo mantenimiento
4. **Verificar funcionalidad** post-actualización
5. **Monitorear rendimiento** después de actualizar

### Actualización de Secretos
1. **Generar nuevas claves** de encriptación
2. **Re-encriptar secretos** existentes
3. **Actualizar aplicaciones** con nuevas claves
4. **Eliminar claves antiguas** de forma segura
5. **Documentar cambios** y actualizar documentación

---

## 📞 Soporte y Ayuda

### Canales de Soporte
- **Documentación**: `/usr/share/doc/webmin/`
- **Logs del sistema**: `/var/log/webmin/`
- **Foro comunitario**: [Webmin Forums](https://www.virtualmin.com/forums/)
- **Soporte empresarial**: [Enterprise Support](https://www.virtualmin.com/enterprise/)

### Reporte de Incidentes
Para reportar incidentes de seguridad:
1. **No modifique** el sistema afectado
2. **Documente** evidencia del incidente
3. **Aisle** el sistema si es necesario
4. **Reporte** a través de canales seguros
5. **Siga procedimientos** de respuesta a incidentes

---

## 📄 Checklist de Seguridad

### Pre-Instalación
- [ ] Sistema actualizado y parcheado
- [ ] Firewall configurado y activo
- [ ] Usuarios sin contraseña eliminados
- [ ] Servicios innecesarios deshabilitados
- [ ] Backup de configuración actual
- [ ] Variables de entorno preparadas

### Durante Instalación
- [ ] Instalador seguro ejecutado como root
- [ ] Configuración validada antes de despliegue
- [ ] Secretos configurados con gestor seguro
- [ ] SSL/TLS configurado correctamente
- [ ] Servicios verificados post-instalación

### Post-Instalación
- [ ] Verificación completa ejecutada
- [ ] Puntuación de seguridad ≥ 70
- [ ] Monitoreo configurado y activo
- [ ] Backups programados y verificados
- [ ] Documentación actualizada
- [ ] Equipo notificado del despliegue

---

## 🏷️ Licencia y Cumplimiento

### Licencia
Este software está distribuido bajo licencia empresarial. Consulte el archivo `LICENSE` para términos completos.

### Cumplimiento
- **GDPR**: Cumple con regulaciones de protección de datos
- **SOC 2**: Controles de seguridad implementados
- **ISO 27001**: Framework de seguridad de información
- **PCI DSS**: Estándar de seguridad de pagos (si aplica)

---

**Versión del documento**: 1.0.0  
**Última actualización**: $(date +%Y-%m-%d)  
**Próxima revisión**: $(date -d "+3 months" +%Y-%m-%d)

---

⚠️ **AVISO IMPORTANTE**: Este documento contiene información sensible. Distribúylo únicamente a personal autorizado y almacénelo de forma segura.
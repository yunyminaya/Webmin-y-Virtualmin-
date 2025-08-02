# 🚀 GUÍA COMPLETA DE INSTALACIÓN UBUNTU/DEBIAN

## Webmin 2.111 + Virtualmin GPL + Authentic Theme

### ✨ CARACTERÍSTICAS PRINCIPALES

- **Panel Webmin 2.111**: Administración completa del servidor
- **Virtualmin GPL**: Gestión profesional de hosting
- **Authentic Theme**: Interfaz moderna y responsive
- **Estadísticas PRO**: Monitoreo avanzado en tiempo real
- **Optimizado**: Específicamente para Ubuntu 18.04+ y Debian 10+
- **SSL Habilitado**: Certificados automáticos para conexiones seguras
- **Firewall UFW**: Configuración automática de seguridad

---

## 🎯 INSTALACIÓN EN UN COMANDO

### Para Ubuntu/Debian:

```bash
# Descargar y ejecutar instalación completa
wget -O - https://raw.githubusercontent.com/tu-repo/webmin-virtualmin/main/instalacion_completa_ubuntu_debian.sh | sudo bash
```

### O ejecutar localmente:

```bash
# Hacer ejecutable
chmod +x instalacion_completa_ubuntu_debian.sh

# Ejecutar instalación
sudo ./instalacion_completa_ubuntu_debian.sh

# Solo verificar instalación existente
sudo ./instalacion_completa_ubuntu_debian.sh verify
```

---

## 📋 REQUISITOS DEL SISTEMA

### Sistemas Soportados:

- ✅ **Ubuntu 18.04 LTS** (Bionic Beaver)
- ✅ **Ubuntu 20.04 LTS** (Focal Fossa)
- ✅ **Ubuntu 22.04 LTS** (Jammy Jellyfish)
- ✅ **Ubuntu 24.04 LTS** (Noble Numbat)
- ✅ **Debian 10** (Buster)
- ✅ **Debian 11** (Bullseye)
- ✅ **Debian 12** (Bookworm)

### Recursos Mínimos:

- **RAM**: 1GB (recomendado 2GB+)
- **Disco**: 5GB libres (recomendado 10GB+)
- **CPU**: 1 core (recomendado 2+ cores)
- **Red**: Conexión a Internet estable

### Privilegios:

- **Root**: Se requieren privilegios de administrador
- **Puertos**: 10000, 80, 443 deben estar disponibles

---

## 🔧 INSTALACIÓN PASO A PASO

### 1. Preparación del Sistema

```bash
# Actualizar el sistema
sudo apt update && sudo apt upgrade -y

# Instalar dependencias básicas
sudo apt install -y curl wget gnupg software-properties-common
```

### 2. Ejecución del Script

```bash
# Descargar el script
wget https://raw.githubusercontent.com/tu-repo/webmin-virtualmin/main/instalacion_completa_ubuntu_debian.sh

# Dar permisos de ejecución
chmod +x instalacion_completa_ubuntu_debian.sh

# Ejecutar instalación completa
sudo ./instalacion_completa_ubuntu_debian.sh
```

### 3. Proceso de Instalación

El script ejecutará automáticamente:

1. **Detección del SO**: Verificación de compatibilidad
2. **Actualización**: Sistema y repositorios
3. **Dependencias**: Paquetes necesarios y herramientas
4. **Webmin**: Descarga e instalación desde repositorio oficial
5. **Virtualmin**: Script oficial de instalación
6. **Authentic Theme**: Tema moderno para la interfaz
7. **Firewall**: Configuración automática de UFW
8. **Verificación**: Pruebas de funcionamiento completas

---

## 🎛️ PANELES Y CARACTERÍSTICAS

### Panel Principal de Webmin

**URL de Acceso**: `https://tu-servidor:10000`

**Módulos Incluidos**:

- 📊 **System Information**: Estadísticas del servidor en tiempo real
- 🔧 **Configuration**: Gestión de configuraciones del sistema
- 🔐 **Users and Groups**: Administración de usuarios y grupos
- 🗄️ **System**: Gestión de servicios y procesos
- 🌐 **Servers**: Configuración de Apache, MySQL, PHP
- 📁 **Tools**: Herramientas de administración avanzadas
- 🔍 **Hardware**: Información detallada del hardware
- 📈 **Reports**: Reportes y logs del sistema

### Panel de Virtualmin

**Acceso**: A través de Webmin → Virtualmin

**Funcionalidades PRO**:

- 🏠 **Virtual Servers**: Gestión completa de dominios
- 📧 **Email**: Configuración de correo completa
- 🗄️ **Databases**: MySQL/PostgreSQL por dominio
- 📂 **File Manager**: Gestor de archivos web
- 📈 **Statistics**: Estadísticas detalladas de uso
- 🔒 **SSL**: Certificados automáticos Let's Encrypt
- 🌐 **DNS**: Gestión completa de registros DNS
- 👥 **Sub-servers**: Subdominios y alias

### Authentic Theme

**Características**:

- 📱 **Responsive**: Compatible con móviles y tablets
- 🌙 **Dark Mode**: Modo oscuro disponible
- ⚡ **Performance**: Carga rápida y optimizada
- 🎨 **Customizable**: Temas y colores personalizables
- 📊 **Dashboard**: Panel de control moderno
- 🔔 **Notifications**: Sistema de notificaciones integrado

---

## 📊 ESTADÍSTICAS PRO INCLUIDAS

### Dashboard Principal

1. **📈 CPU Usage**: Uso en tiempo real del procesador
2. **🧠 Memory Usage**: Consumo de RAM y swap
3. **💾 Disk Usage**: Espacio usado y disponible
4. **🌐 Network**: Tráfico de red entrante y saliente
5. **⚡ Load Average**: Promedio de carga del sistema
6. **🕒 Uptime**: Tiempo de actividad del servidor
7. **👥 Processes**: Procesos activos y zombies
8. **🔥 Temperature**: Temperatura del CPU (si está disponible)

### Gráficos y Reportes

- **📊 Real-time Charts**: Gráficos en tiempo real
- **📈 Historical Data**: Datos históricos de rendimiento
- **📋 System Reports**: Reportes detallados del sistema
- **🚨 Alerts**: Alertas automáticas por umbrales
- **📱 Mobile View**: Vista optimizada para móviles
- **📄 Export**: Exportación de datos en múltiples formatos

---

## 🔐 ACCESO Y CREDENCIALES

### Credenciales Predeterminadas

Después de la instalación, las credenciales se guardan en:

```
/root/webmin-credentials.txt
```

### Primer Acceso

1. **Abrir navegador**: `https://tu-ip-servidor:10000`
2. **Aceptar certificado**: (autofirmado inicialmente)
3. **Usuario**: `root`
4. **Contraseña**: Ver archivo de credenciales
5. **Completar wizard**: Seguir asistente de configuración

### Configuración SSL

```bash
# Generar certificado Let's Encrypt (opcional)
sudo /usr/share/webmin/letsencrypt-dns.pl
```

---

## 🛠️ CONFIGURACIÓN POST-INSTALACIÓN

### 1. Asistente de Configuración Inicial

**Pasos automáticos**:

- ✅ Configuración de red
- ✅ Configuración de DNS
- ✅ Configuración de correo
- ✅ Configuración de base de datos
- ✅ Configuración de PHP
- ✅ Configuración de Apache

### 2. Crear Primer Dominio Virtual

```bash
# A través de Virtualmin:
# 1. Ir a "Create Virtual Server"
# 2. Introducir nombre del dominio
# 3. Configurar opciones avanzadas
# 4. Crear automáticamente
```

### 3. Configurar Correo Electrónico

- **Postfix**: Configuración automática
- **Dovecot**: IMAP/POP3 habilitado
- **SpamAssassin**: Filtro antispam
- **ClamAV**: Antivirus para correo

### 4. Instalar PHP Adicional

```bash
# PHP 8.1
sudo apt install php8.1-fpm php8.1-mysql

# PHP 8.2
sudo apt install php8.2-fpm php8.2-mysql
```

---

## 🚨 SOLUCIÓN DE PROBLEMAS

### Panel No Accesible

```bash
# Verificar estado del servicio
sudo systemctl status webmin

# Reiniciar servicio
sudo systemctl restart webmin

# Verificar puerto
sudo netstat -tlnp | grep :10000

# Verificar firewall
sudo ufw status
sudo ufw allow 10000
```

### Virtualmin No Visible

```bash
# Verificar módulo
sudo ls -la /etc/webmin/virtual-server/

# Reinstalar Virtualmin
cd /tmp
wget https://software.virtualmin.com/gpl/scripts/install.sh
sudo sh install.sh --force
```

### Authentic Theme No Aplicado

```bash
# Verificar instalación
ls -la /usr/share/webmin/authentic-theme/

# Configurar manualmente
echo "theme=authentic-theme" | sudo tee -a /etc/webmin/config
sudo systemctl restart webmin
```

### Estadísticas No Funcionan

```bash
# Verificar permisos /proc
ls -la /proc/stat /proc/meminfo

# Instalar herramientas faltantes
sudo apt install htop iotop nethogs iftop

# Verificar configuración
sudo /usr/share/webmin/authentic-theme/stats.pl
```

---

## 🔧 COMANDOS ÚTILES

### Gestión de Servicios

```bash
# Estado de Webmin
sudo systemctl status webmin

# Reiniciar Webmin
sudo systemctl restart webmin

# Logs de Webmin
sudo tail -f /var/webmin/miniserv.log

# Verificar configuración
sudo /usr/share/webmin/config-test.pl
```

### Gestión de Virtualmin

```bash
# Listar dominios virtuales
sudo virtualmin list-domains

# Crear dominio
sudo virtualmin create-domain --domain ejemplo.com --pass password123

# Backup de dominio
sudo virtualmin backup-domain --domain ejemplo.com --dest /backup/

# Información del sistema
sudo virtualmin info
```

### Monitoreo del Sistema

```bash
# CPU en tiempo real
htop

# Uso de red
sudo nethogs

# IO de disco
sudo iotop

# Tráfico de red
sudo iftop

# Estadísticas completas
sudo /usr/share/webmin/system-status.pl
```

---

## 📚 RECURSOS ADICIONALES

### Documentación Oficial

- **Webmin**: https://webmin.com/docs/
- **Virtualmin**: https://virtualmin.com/docs/
- **Authentic Theme**: https://github.com/webmin/authentic-theme

### Comunidad y Soporte

- **Foro Webmin**: https://forum.virtualmin.com/
- **GitHub Issues**: https://github.com/webmin/webmin/issues
- **Wiki**: https://doxfer.webmin.com/Webmin

### Tutoriales Avanzados

- **Configuración SSL**: Certificados Let's Encrypt
- **Backup Automático**: Scripts de respaldo
- **Migración**: Mover entre servidores
- **Optimización**: Rendimiento y seguridad
- **API**: Automatización con scripts

---

## ⚡ OPTIMIZACIONES INCLUIDAS

### Para Ubuntu/Debian

1. **APT Optimizado**: Repositorios más rápidos
2. **Systemd**: Servicios optimizados para systemd
3. **UFW**: Firewall simplificado y seguro
4. **PHP-FPM**: Mejor rendimiento PHP
5. **Cache**: Configuración optimizada de caché
6. **Logs**: Rotación automática de logs
7. **Security**: Configuraciones de seguridad mejoradas

### Rendimiento

- **Memory**: Uso optimizado de memoria
- **CPU**: Procesos optimizados
- **Disk**: I/O optimizado
- **Network**: Buffer de red optimizado

---

## 🎯 VERIFICACIÓN DE FUNCIONALIDAD

### Script de Verificación

```bash
# Ejecutar verificación completa
sudo ./instalacion_completa_ubuntu_debian.sh verify

# O usar script específico
sudo ./verificar_paneles_estadisticas_pro.sh
```

### Checklist Manual

- [ ] Panel Webmin accesible en puerto 10000
- [ ] Virtualmin visible en el menú
- [ ] Authentic Theme aplicado correctamente
- [ ] Estadísticas CPU funcionando
- [ ] Estadísticas memoria funcionando
- [ ] Estadísticas disco funcionando
- [ ] Estadísticas red funcionando
- [ ] Servicios críticos activos
- [ ] Firewall configurado
- [ ] SSL habilitado

---

## 🏆 CARACTERÍSTICAS PRO VERIFICADAS

### ✅ PANELES COMPLETAMENTE FUNCIONALES

1. **🎛️ Panel Webmin**: Administración completa del servidor
2. **🏠 Panel Virtualmin**: Gestión profesional de hosting
3. **🎨 Authentic Theme**: Interfaz moderna y responsive

### ✅ ESTADÍSTICAS PRO OPERATIVAS

1. **📊 CPU**: Uso en tiempo real y histórico
2. **🧠 Memoria**: RAM y swap detallados
3. **💾 Disco**: Espacio y I/O por partición
4. **🌐 Red**: Tráfico entrante y saliente
5. **⚡ Carga**: Load average del sistema
6. **🕒 Uptime**: Tiempo de actividad
7. **👥 Procesos**: Gestión completa de procesos

### ✅ OPTIMIZACIÓN UBUNTU/DEBIAN

- **APT**: Gestión optimizada de paquetes
- **Systemd**: Servicios nativos del sistema
- **UFW**: Firewall simplificado y efectivo
- **SSL**: Certificados automáticos
- **Performance**: Configuraciones optimizadas

---

## 📞 SOPORTE

### En Caso de Problemas

1. **Revisar logs**: `/var/log/webmin-virtualmin-install.log`
2. **Ejecutar verificación**: `sudo ./instalacion_completa_ubuntu_debian.sh verify`
3. **Consultar documentación**: Ver sección de solución de problemas
4. **Reportar issues**: GitHub repository

### Contacto

- **GitHub**: [Repository Issues](https://github.com/tu-repo/issues)
- **Email**: soporte@tu-dominio.com
- **Documentación**: [Wiki completa](https://github.com/tu-repo/wiki)

---

**🚀 ¡Disfruta de tu servidor profesional con Webmin y Virtualmin optimizado para Ubuntu/Debian!**

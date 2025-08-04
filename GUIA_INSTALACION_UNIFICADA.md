# 🚀 Guía de Instalación Unificada
## Authentic Theme + Virtualmin como UN SOLO SISTEMA

---

## 🎯 ¿Qué vas a obtener?

Un **panel de control único e integrado** que combina:
- ✅ **Virtualmin** (gestión de hosting)
- ✅ **Authentic Theme** (interfaz moderna)
- ✅ **Webmin** (administración del sistema)
- ✅ **Stack LAMP completo** (Apache, MySQL, PHP)

**Resultado**: Un solo panel web con interfaz moderna para gestionar todo tu servidor.

---

## ⚡ Instalación Súper Rápida

### Opción 1: Script Unificado (Recomendado)
```bash
sudo ./instalacion_unificada.sh
```

### Opción 2: Comando Directo
```bash
wget https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh
sudo sh virtualmin-install.sh --bundle LAMP --yes
```

---

## 📋 Requisitos del Sistema

### Sistemas Operativos Soportados:
- ✅ **Ubuntu** 20.04, 22.04, 24.04
- ✅ **Debian** 10, 11, 12
- ✅ **CentOS** 7, 8, 9
- ✅ **Rocky Linux** 8, 9
- ✅ **AlmaLinux** 8, 9

### Recursos Mínimos:
- 🖥️ **RAM**: 1GB (recomendado 2GB+)
- 💾 **Disco**: 10GB libres
- 🌐 **Conexión**: Internet estable
- 🔐 **Acceso**: Root/sudo

---

## 🛠️ Proceso de Instalación Paso a Paso

### Paso 1: Preparar el Sistema
```bash
# Actualizar sistema
sudo apt update && sudo apt upgrade -y  # Ubuntu/Debian
# o
sudo yum update -y  # CentOS/RHEL

# Instalar dependencias básicas
sudo apt install wget curl unzip -y  # Ubuntu/Debian
# o
sudo yum install wget curl unzip -y  # CentOS/RHEL
```

### Paso 2: Ejecutar Instalación Unificada
```bash
# Navegar al directorio
cd "/Users/yunyminaya/Wedmin Y Virtualmin"

# Ejecutar script unificado
sudo ./instalacion_unificada.sh
```

### Paso 3: Esperar la Instalación
- ⏱️ **Tiempo estimado**: 10-30 minutos
- 📦 **Se instala automáticamente**:
  - Webmin (base del sistema)
  - Virtualmin (hosting virtual)
  - Authentic Theme (interfaz)
  - Apache Web Server
  - MySQL/MariaDB
  - PHP (múltiples versiones)
  - Postfix (correo)
  - BIND (DNS)
  - Certificados SSL

---

## 🎨 Características del Sistema Unificado

### Interfaz Única con Authentic Theme:
- 🌓 **Modo oscuro/claro**
- 📱 **Diseño responsive**
- ⚡ **Navegación rápida**
- 🔍 **Búsqueda global**
- 📁 **Gestor de archivos avanzado**
- 💻 **Terminal integrado**
- 🔔 **Notificaciones en tiempo real**

### Funcionalidades de Virtualmin:
- 🌐 **Gestión de dominios**
- 🔒 **Certificados SSL automáticos**
- 📧 **Correo electrónico completo**
- 🗄️ **Bases de datos**
- 👥 **Usuarios y permisos**
- 📊 **Estadísticas y logs**
- 💾 **Backups automáticos**
- 🚀 **Instalador de aplicaciones**

---

## 🔐 Acceso al Panel Unificado

### URL de Acceso:
```
https://tu-servidor:10000
```

### Credenciales:
- **Usuario**: `root`
- **Contraseña**: Tu contraseña de root del servidor

### Puertos que se Abren:
- `10000` - Panel de administración
- `80` - HTTP
- `443` - HTTPS
- `25` - SMTP (correo)
- `53` - DNS

---

## 🎯 Configuración Inicial del Sistema Unificado

### 1. Primer Acceso
1. Abre tu navegador
2. Ve a `https://tu-servidor:10000`
3. Acepta el certificado SSL temporal
4. Inicia sesión con root

### 2. Configuración Inicial de Virtualmin
1. Ve a **"Virtualmin Virtual Servers"**
2. Ejecuta el **"Post-Installation Wizard"**
3. Configura:
   - Servidor de correo
   - Servidor DNS
   - Configuración MySQL
   - Configuración PHP

### 3. Crear tu Primer Dominio
1. En Virtualmin, click **"Create Virtual Server"**
2. Ingresa tu dominio (ej: `midominio.com`)
3. Configura la contraseña del administrador
4. Click **"Create Server"**

### 4. Verificar Authentic Theme
- El tema moderno debería estar activo automáticamente
- Si no, ve a: **Webmin → Webmin Configuration → Webmin Themes**
- Selecciona **"Authentic Theme"**

---

## 🔧 Personalización del Sistema Unificado

### Configurar Authentic Theme:
1. Ve a **"Webmin → Webmin Configuration → Authentic Theme"**
2. Personaliza:
   - Colores y tema
   - Logo personalizado
   - Configuración de navegación
   - Funciones avanzadas

### Configurar Virtualmin:
1. Ve a **"System Settings → Virtualmin Configuration"**
2. Ajusta:
   - Plantillas de servidor
   - Configuración de correo
   - Configuración de DNS
   - Límites y cuotas

---

## 🚨 Solución de Problemas

### No puedo acceder al panel:
```bash
# Verificar que Webmin esté corriendo
sudo systemctl status webmin

# Reiniciar si es necesario
sudo systemctl restart webmin

# Verificar puerto
sudo netstat -tlnp | grep :10000
```

### El tema no se ve bien:
```bash
# Limpiar caché del navegador
# O forzar recarga: Ctrl+F5

# Verificar tema en Webmin
# Webmin → Configuration → Webmin Themes
```

### Virtualmin no aparece:
```bash
# Verificar módulo
sudo /usr/share/webmin/virtual-server/config-system.pl

# Reiniciar Webmin
sudo systemctl restart webmin
```

---

## 📊 Monitoreo del Sistema Unificado

### Dashboard Principal:
- 📈 **Uso de recursos** (CPU, RAM, disco)
- 🌐 **Estado de servicios** (Apache, MySQL, etc.)
- 📧 **Cola de correo**
- 🔒 **Estado SSL**
- 📊 **Estadísticas de tráfico**

### Logs Centralizados:
- 🔍 **Logs de Apache** en tiempo real
- 📧 **Logs de correo**
- 🛡️ **Logs de seguridad**
- 🗄️ **Logs de base de datos**

---

## 🎉 ¡Felicidades!

Ahora tienes un **sistema completamente unificado** que combina:
- La potencia de **Virtualmin** para hosting
- La elegancia de **Authentic Theme** para la interfaz
- La robustez de **Webmin** para administración

**Todo en un solo panel web moderno y fácil de usar.**

---

## 📚 Recursos Adicionales

- 📖 **Documentación Virtualmin**: https://www.virtualmin.com/docs
- 🎨 **Documentación Authentic Theme**: https://github.com/authentic-theme/authentic-theme
- 💬 **Foro de Soporte**: https://forum.virtualmin.com
- 🆘 **Soporte Comercial**: https://www.virtualmin.com/support

---

**¡Tu servidor está listo para alojar sitios web con un panel de control profesional y moderno!** 🚀
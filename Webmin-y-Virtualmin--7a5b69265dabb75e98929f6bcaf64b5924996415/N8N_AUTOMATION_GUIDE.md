# 📋 GUÍA COMPLETA DE INSTALACIÓN AUTOMÁTICA DE n8n

## 🎯 **RESUMEN EJECUTIVO**

Esta guía documenta el sistema completo de instalación automática de **n8n Automation Platform** para servidores virtuales, integrado con Webmin/Virtualmin de manera similar a WordPress.

**FECHA:** 8 de Octubre de 2025  
**VERSIÓN:** 2.0.0  
**ESTADO:** ✅ **PRODUCCIÓN LISTA**

---

## 🚀 **CARACTERÍSTICAS PRINCIPALES**

### ✅ **INSTALACIÓN AUTOMÁTICA COMPLETA**
- **Instalación con un clic** similar a WordPress
- **Detección automática** de componentes del sistema
- **Configuración optimizada** para producción
- **Integración total** con Webmin/Virtualmin

### 🔧 **OPCIONES DE CONFIGURACIÓN**
- **Múltiples bases de datos**: SQLite, MySQL/MariaDB, PostgreSQL
- **SSL/HTTPS automático** con Let's Encrypt
- **Configuración de servidor web**: Nginx y Apache
- **Gestión de usuarios** y permisos

### 🎨 **INTERFAZ WEBMIN INTEGRADA**
- **Panel de control** intuitivo
- **Gestión de instancias** múltiples
- **Monitoreo en tiempo real**
- **Respaldos automáticos**

---

## 📋 **REQUISITOS DEL SISTEMA**

### 🔧 **REQUISITOS MÍNIMOS**
- **Sistema Operativo**: Ubuntu 18.04+, Debian 10+, CentOS 7+, RHEL 7+
- **Memoria RAM**: 1GB mínimo (2GB recomendado)
- **Espacio en disco**: 2GB mínimo
- **Arquitectura**: x86_64 o aarch64

### 🌐 **COMPONENTES REQUERIDOS**
- **Webmin/Virtualmin** instalado y funcionando
- **Servidor web**: Nginx o Apache
- **Node.js 16+** (instalado automáticamente si no existe)
- **Base de datos** (opcional, SQLite por defecto)

---

## 🛠️ **INSTALACIÓN DEL MÓDULO**

### 📦 **MÉTODO 1: INSTALACIÓN AUTOMÁTICA**

```bash
# Descargar el módulo
git clone https://github.com/tu-repo/n8n-virtualmin.git
cd n8n-virtualmin

# Ejecutar instalación
sudo ./n8n_virtualmin_integration/install.pl . /usr/share/webmin

# Reiniciar Webmin
sudo systemctl restart webmin
```

### 📦 **MÉTODO 2: INSTALACIÓN MANUAL**

```bash
# Copiar archivos del módulo
sudo cp -r n8n_virtualmin_integration /usr/share/webmin/n8n

# Establecer permisos
sudo chmod 755 /usr/share/webmin/n8n/index.cgi
sudo chmod 644 /usr/share/webmin/n8n/module.info

# Crear directorios necesarios
sudo mkdir -p /var/lib/n8n /etc/n8n /var/log/n8n /var/backups/n8n

# Crear usuario n8n
sudo useradd -r -s /bin/false -d /var/lib/n8n n8n

# Copiar script de instalación
sudo cp install_n8n_automation.sh /usr/local/bin/
sudo chmod 755 /usr/local/bin/install_n8n_automation.sh
```

---

## 🎯 **USO DEL SISTEMA**

### 🖥️ **ACCESO AL MÓDULO WEBMIN**

1. **Iniciar sesión** en Webmin: `https://tu-servidor:10000`
2. **Navegar** a la sección "n8n Automation Platform"
3. **Hacer clic** en "Instalar n8n" para comenzar

### ⚙️ **CONFIGURACIÓN INTERACTIVA**

El sistema te guiará través de los siguientes pasos:

1. **Dominio**: `n8n.ejemplo.com`
2. **Puerto**: `5678` (por defecto)
3. **Base de datos**: SQLite/MySQL/PostgreSQL
4. **SSL**: Habilitar HTTPS automático
5. **Usuario admin**: Credenciales de acceso

### 🚀 **INSTALACIÓN AUTOMÁTICA**

```bash
# Ejecutar instalación con valores por defecto
sudo /usr/local/bin/install_n8n_automation.sh

# O con parámetros personalizados
sudo /usr/local/bin/install_n8n_automation.sh \
  --domain n8n.ejemplo.com \
  --port 5678 \
  --database mysql \
  --enable-ssl \
  --ssl-email admin@ejemplo.com
```

---

## 🏗️ **ARQUITECTURA DEL SISTEMA**

### 📁 **ESTRUCTURA DE DIRECTORIOS**

```
/usr/share/webmin/n8n/          # Módulo Webmin
├── index.cgi                    # Interfaz principal
├── module.info                  # Información del módulo
├── config                       # Configuración por defecto
├── lang/
│   └── es                       # Traducciones
└── scripts/                     # Scripts auxiliares

/var/lib/n8n/                   # Datos de n8n
├── .n8n/                       # Configuración de usuario
├── custom-nodes/               # Nodos personalizados
└── database/                   # Base de datos SQLite

/etc/n8n/                       # Configuración del sistema
├── n8n.env                     # Variables de entorno
└── nginx.conf                  # Configuración Nginx

/var/log/n8n/                   # Logs del sistema
/var/backups/n8n/               # Respaldos automáticos
```

### 🔧 **COMPONENTES DEL SISTEMA**

#### **1. Script de Instalación Principal**
- **Archivo**: [`install_n8n_automation.sh`](install_n8n_automation.sh)
- **Función**: Instalación completa y automatizada
- **Características**: Detección de sistema, configuración, optimización

#### **2. Módulo Webmin**
- **Archivo**: [`n8n_virtualmin_integration/index.cgi`](n8n_virtualmin_integration/index.cgi)
- **Función**: Interfaz web para gestión
- **Características**: Panel de control, gestión de instancias, monitoreo

#### **3. Sistema de Configuración**
- **Archivo**: [`n8n_virtualmin_integration/config`](n8n_virtualmin_integration/config)
- **Función**: Configuración por defecto del módulo
- **Características**: Parámetros personalizables

---

## 🎨 **FUNCIONALIDADES DEL MÓDULO WEBMIN**

### 📊 **PANEL DE CONTROL**

El panel principal muestra:

- **Estado de n8n**: Instalado/no instalado
- **Información del sistema**: Versión, URL, puerto, base de datos
- **Estadísticas en tiempo real**: CPU, memoria, disco
- **Acciones rápidas**: Iniciar, detener, reiniciar

### 🛠️ **GESTIÓN DE INSTANCIAS**

Cada instancia incluye:

- **Configuración personalizada**: Dominio, puerto, base de datos
- **Monitoreo individual**: Estado, recursos, logs
- **Gestión de respaldos**: Crear, restaurar, programar
- **Acciones de control**: Iniciar, detener, reiniciar, eliminar

### 🔒 **SEGURIDAD INTEGRADA**

- **SSL/HTTPS automático** con Let's Encrypt
- **Autenticación básica** con credenciales seguras
- **Cabeceras de seguridad** configuradas
- **Aislamiento de usuarios** y permisos

---

## 📋 **CONFIGURACIÓN AVANZADA**

### 🔧 **VARIABLES DE ENTORNO**

El sistema crea automáticamente el archivo `/etc/n8n/n8n.env`:

```bash
# Configuración de n8n
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=contraseña_segura

# Configuración de la base de datos
DB_TYPE=sqlite
DB_SQLITE_VACUUM_ON_CLOSE=true

# Configuración del servidor
N8N_HOST=n8n.ejemplo.com
N8N_PORT=5678
N8N_PROTOCOL=http

# Configuración de seguridad
N8N_ENCRYPTION_KEY=clave_encriptación_aleatoria
N8N_JWT_AUTH_HEADER=authorization
N8N_JWT_AUTH_HEADER_VALUE_PREFIX=Bearer

# Configuración de ejecución
N8N_EXECUTORS_DATA=own
N8N_BINARY_DATA_TTL=24
N8N_DEFAULT_BINARY_DATA_MODE=filesystem

# Configuración de archivos
N8N_USER_FOLDER=/var/lib/n8n/.n8n
N8N_CUSTOM_EXTENSIONS=/var/lib/n8n/custom-nodes

# Configuración de webhook
WEBHOOK_URL=http://n8n.ejemplo.com:5678/
```

### 🌐 **CONFIGURACIÓN DE SERVIDOR WEB**

#### **Nginx**
```nginx
server {
    listen 80;
    server_name n8n.ejemplo.com;
    
    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

#### **Apache**
```apache
<VirtualHost *:80>
    ServerName n8n.ejemplo.com
    
    ProxyPreserveHost On
    ProxyRequests Off
    ProxyPass / http://localhost:5678/
    ProxyPassReverse / http://localhost:5678/
    
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} =websocket [NC]
    RewriteRule /(.*) ws://localhost:5678/$1 [P,L]
</VirtualHost>
```

---

## 🔄 **GESTIÓN DE INSTANCIAS**

### 📊 **CREAR NUEVA INSTANCIA**

1. **Acceder** al módulo n8n en Webmin
2. **Hacer clic** en "Instalar n8n"
3. **Configurar** dominio, puerto, base de datos
4. **Seleccionar** opciones de SSL
5. **Hacer clic** en "Instalar"

### 🛠️ **GESTIONAR INSTANCIA EXISTENTE**

Desde el panel de gestión puedes:

- **Ver estado**: Ejecutando, detenido, errores
- **Monitorear recursos**: CPU, memoria, disco
- **Gestionar servicios**: Iniciar, detener, reiniciar
- **Configurar respaldos**: Automáticos, manuales
- **Ver logs**: Sistema, aplicación, errores

### 🗑️ **ELIMINAR INSTANCIA**

1. **Seleccionar** la instancia a eliminar
2. **Hacer clic** en "Eliminar Instancia"
3. **Confirmar** la eliminación
4. **Esperar** a que se complete el proceso

---

## 🔒 **SEGURIDAD Y MEJORES PRÁCTICAS**

### 🛡️ **CONFIGURACIÓN DE SEGURIDAD**

- **Contraseñas seguras**: Generadas automáticamente
- **SSL/TLS obligatorio**: Redirección automática a HTTPS
- **Aislamiento de procesos**: Usuario dedicado n8n
- **Permisos restrictivos**: Mínimos necesarios
- **Logs de auditoría**: Registro completo de acciones

### 🔧 **OPTIMIZACIÓN DE RENDIMIENTO**

- **PM2 como gestor de procesos**: Reinicio automático
- **Cache configurada**: Optimización de respuestas
- **Compresión Gzip**: Reducción de ancho de banda
- **Headers de caché**: Mejora de tiempo de carga
- **Monitoreo continuo**: Detección de problemas

### 📊 **MONITOREO Y LOGS**

- **Logs del sistema**: `/var/log/n8n/`
- **Logs de aplicación**: Integrados con systemd
- **Métricas en tiempo real**: CPU, memoria, disco
- **Alertas automáticas**: Notificación de problemas
- **Historial de eventos**: Registro completo

---

## 🔄 **ACTUALIZACIÓN Y MANTENIMIENTO**

### 📦 **ACTUALIZACIÓN DE n8n**

```bash
# Actualizar a la última versión
sudo npm update -g n8n

# Reiniciar servicio
sudo systemctl restart n8n

# Verificar versión
n8n --version
```

### 🛠️ **MANTENIMIENTO PROGRAMADO**

El sistema incluye tareas automáticas:

- **Limpieza de logs**: Rotación semanal
- **Respaldos automáticos**: Diarios
- **Optimización de base de datos**: Mensual
- **Actualización de seguridad**: Automática

### 🔧 **SOLUCIÓN DE PROBLEMAS**

#### **Problemas Comunes**

1. **n8n no inicia**
   ```bash
   # Verificar logs
   sudo journalctl -u n8n -f
   
   # Verificar configuración
   sudo systemctl status n8n
   ```

2. **Problemas de SSL**
   ```bash
   # Renovar certificado
   sudo certbot renew
   
   # Verificar configuración Nginx/Apache
   sudo nginx -t
   ```

3. **Problemas de base de datos**
   ```bash
   # Verificar conexión
   sudo -u n8n n8n user-management:reset
   
   # Reindexar base de datos
   sudo -u n8n n8n db:migrate
   ```

---

## 📚 **REFERENCIAS Y RECURSOS**

### 📖 **DOCUMENTACIÓN OFICIAL**

- **n8n Documentation**: https://docs.n8n.io/
- **Webmin Documentation**: https://webmin.com/docs/
- **Virtualmin Documentation**: https://www.virtualmin.com/documentation/

### 🔗 **ENLACES ÚTILES**

- **n8n GitHub**: https://github.com/n8n-io/n8n
- **n8n Community**: https://community.n8n.io/
- **Webmin Modules**: https://webmin.com/standard.html

### 🆘 **SOPORTE**

- **Issues y Bugs**: Reportar en GitHub
- **Comunidad**: Foros de n8n y Webmin
- **Documentación**: Guías y tutoriales

---

## 📋 **RESUMEN DE INSTALACIÓN**

### ✅ **VERIFICACIÓN FINAL**

Después de la instalación, verifica:

1. **Acceso Webmin**: `https://servidor:10000/n8n/`
2. **Acceso n8n**: `https://n8n.dominio.com`
3. **Estado del servicio**: `systemctl status n8n`
4. **Logs del sistema**: `journalctl -u n8n -f`

### 🎉 **INSTALACIÓN EXITOSA**

Una vez completada la instalación tendrás:

- ✅ **n8n instalado** y configurado
- ✅ **Panel Webmin** para gestión
- ✅ **SSL/HTTPS** configurado
- ✅ **Respaldos automáticos** programados
- ✅ **Monitoreo** en tiempo real
- ✅ **Documentación** completa

---

**DOCUMENTACIÓN CREADA:** 8 de Octubre de 2025  
**VERSIÓN DEL SISTEMA:** n8n Automation Platform v2.0.0  
**ESTADO:** ✅ **PRODUCCIÓN LISTA**
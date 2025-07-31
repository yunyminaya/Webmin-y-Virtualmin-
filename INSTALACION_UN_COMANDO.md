# 🚀 Instalación de Webmin y Virtualmin con Un Solo Comando

## ⚡ Instalación Rápida

### Opción 1: Comando Directo (Recomendado)

```bash
curl -sSL https://raw.githubusercontent.com/yunyminaya/Wedmin-Y-Virtualmin/main/instalar_webmin_virtualmin.sh | bash
```

### Opción 2: Descarga y Ejecución

```bash
wget -O - https://raw.githubusercontent.com/yunyminaya/Wedmin-Y-Virtualmin/main/instalar_webmin_virtualmin.sh | bash
```

### Opción 3: Instalación Local

```bash
git clone https://github.com/yunyminaya/Wedmin-Y-Virtualmin.git
cd Wedmin-Y-Virtualmin
chmod +x instalacion_completa_automatica.sh
./instalacion_completa_automatica.sh
```

## 🎯 ¿Qué se Instala?

✅ **Webmin 2.111** - Panel de administración web  
✅ **Virtualmin GPL** - Gestión de hosting y dominios  
✅ **MySQL/MariaDB** - Base de datos  
✅ **Apache HTTP Server** - Servidor web  
✅ **PHP** - Lenguaje de programación  
✅ **Certificados SSL** - Seguridad HTTPS  
✅ **Configuración automática** - Todo listo para usar  

## 🖥️ Sistemas Compatibles

| Sistema Operativo | Estado | Notas |
|-------------------|--------|-------|
| 🍎 **macOS** | ✅ Soportado | Requiere Homebrew |
| 🐧 **Ubuntu 18.04+** | ✅ Soportado | Completamente compatible |
| 🐧 **Debian 9+** | ✅ Soportado | Completamente compatible |
| 🎩 **CentOS 7+** | ✅ Soportado | Completamente compatible |
| 🎩 **RHEL 7+** | ✅ Soportado | Completamente compatible |
| 🎩 **Fedora 30+** | ✅ Soportado | Completamente compatible |

## ⏱️ Tiempo de Instalación

- **macOS**: 15-25 minutos
- **Ubuntu/Debian**: 10-20 minutos
- **CentOS/RHEL**: 15-30 minutos

## 🔐 Credenciales por Defecto

```
URL: https://localhost:10000
Usuario: admin
Contraseña: admin123
```

> ⚠️ **IMPORTANTE**: Cambie estas credenciales después del primer acceso

## 📋 Requisitos Previos

### Mínimos
- **RAM**: 1 GB (recomendado 2 GB+)
- **Disco**: 5 GB libres (recomendado 10 GB+)
- **Conexión a Internet**: Requerida para descarga
- **Permisos**: sudo o root

### Automáticamente Instalados
- Git (si no está presente)
- Curl/Wget (si no están presentes)
- Dependencias del sistema

## 🚀 Proceso de Instalación

### Paso 1: Ejecutar Comando
```bash
curl -sSL https://raw.githubusercontent.com/yunyminaya/Wedmin-Y-Virtualmin/main/instalar_webmin_virtualmin.sh | bash
```

### Paso 2: Confirmar Instalación
El script le preguntará si desea continuar:
```
¿Desea continuar con la instalación? (s/N): s
```

### Paso 3: Esperar Completación
El script mostrará el progreso en tiempo real:
```
🚀 Iniciando instalación automática...
[10:30:15] Detectando sistema operativo...
[10:30:16] Instalando dependencias...
[10:32:45] Configurando MySQL...
[10:35:20] Instalando Webmin...
[10:40:10] Configurando Virtualmin...
[10:42:30] ✅ Instalación completada exitosamente!
```

### Paso 4: Acceder al Panel
1. Abra su navegador
2. Vaya a: `https://localhost:10000`
3. Acepte el certificado SSL
4. Inicie sesión con `admin` / `admin123`
5. Complete el asistente de post-instalación

## 🔧 Solución de Problemas

### Error: "Permission denied"
```bash
sudo curl -sSL https://raw.githubusercontent.com/yunyminaya/Wedmin-Y-Virtualmin/main/instalar_webmin_virtualmin.sh | sudo bash
```

### Error: "Command not found"
Instale curl primero:
```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install curl

# CentOS/RHEL
sudo yum install curl

# macOS
brew install curl
```

### Error: "Cannot connect to GitHub"
Use wget como alternativa:
```bash
wget -O - https://raw.githubusercontent.com/yunyminaya/Wedmin-Y-Virtualmin/main/instalar_webmin_virtualmin.sh | bash
```

### Verificación Post-Instalación
Si hay problemas después de la instalación:
```bash
# Descargar script de verificación
curl -sSL https://raw.githubusercontent.com/yunyminaya/Wedmin-Y-Virtualmin/main/verificar_asistente_wizard.sh -o verificar.sh
chmod +x verificar.sh
./verificar.sh
```

## 📊 Monitoreo y Logs

### Ubicaciones de Logs
```bash
# Log de instalación
/tmp/instalacion_webmin_YYYYMMDD_HHMMSS.log

# Logs de Webmin
/var/log/webmin/

# Logs del sistema
/var/log/syslog          # Ubuntu/Debian
/var/log/messages        # CentOS/RHEL
/var/log/system.log      # macOS
```

### Verificar Estado de Servicios
```bash
# Linux
sudo systemctl status webmin mysql apache2

# macOS
brew services list | grep -E "mysql|httpd"
ps aux | grep webmin
```

## 🔄 Actualización

Para actualizar a la última versión:
```bash
curl -sSL https://raw.githubusercontent.com/yunyminaya/Wedmin-Y-Virtualmin/main/instalar_webmin_virtualmin.sh | bash
```

## 🗑️ Desinstalación

```bash
# Descargar script de desinstalación
curl -sSL https://raw.githubusercontent.com/yunyminaya/Wedmin-Y-Virtualmin/main/desinstalar.sh | bash
```

## 📞 Soporte

### Documentación Adicional
- [Guía Completa de Instalación](GUIA_INSTALACION_UNIFICADA.md)
- [Solución de Problemas](SOLUCION_ASISTENTE_POSTINSTALACION.md)
- [Servicios Premium](SERVICIOS_PREMIUM_INCLUIDOS.md)

### Reportar Problemas
- **GitHub Issues**: [Crear Issue](https://github.com/yunyminaya/Wedmin-Y-Virtualmin/issues)
- **Email**: soporte@webmin-virtualmin.com

### Comunidad
- **Discord**: [Unirse al servidor](https://discord.gg/webmin-virtualmin)
- **Telegram**: [@WebminVirtualmin](https://t.me/WebminVirtualmin)

## 🎉 ¡Listo!

Después de ejecutar el comando, tendrá un panel de administración completo funcionando en minutos. ¡Disfrute de su nuevo servidor!

---

**¿Necesita ayuda?** Consulte nuestra [documentación completa](README.md) o [contacte soporte](#-soporte).

**¿Le gusta el proyecto?** ⭐ Deje una estrella en GitHub y compártalo con otros.
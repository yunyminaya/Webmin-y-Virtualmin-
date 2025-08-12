# 🚀 INSTALADOR UNIVERSAL WEBMIN + VIRTUALMIN

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20LTS-orange.svg)](https://ubuntu.com/)
[![Debian](https://img.shields.io/badge/Debian-10%2B-red.svg)](https://debian.org/)
[![Webmin](https://img.shields.io/badge/Webmin-2.111-blue.svg)](https://webmin.com/)
[![Virtualmin](https://img.shields.io/badge/Virtualmin-GPL-green.svg)](https://virtualmin.com/)

## ⚡ INSTALACIÓN CON UN SOLO COMANDO

```bash
curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/master/instalar.sh | sudo bash
```

## 🎯 ¿QUÉ HACE ESTE COMANDO?

1. **Descarga automática** desde GitHub
2. **Verificación del sistema** (Ubuntu/Debian)
3. **Instalación completa** de Webmin + Virtualmin
4. **Configuración automática** de LAMP stack
5. **Activación de SSL** y seguridad
6. **Verificación final** del sistema

## 📦 STACK COMPLETO INCLUIDO

### 🌐 Paneles de Administración

- **Webmin 2.111** - Panel de administración del servidor
- **Virtualmin GPL** - Gestión de hosting y dominios
- **Authentic Theme** - Interfaz moderna y responsiva (48 idiomas)

### 🔧 LAMP Stack

- **Apache 2.4** - Servidor web optimizado
- **MySQL 8.0** - Base de datos robusta
- **PHP 8.1** - Última versión estable
- **phpMyAdmin** - Administración visual de DB

### 📧 Servidor de Correo

- **Postfix** - SMTP server configurado
- **Dovecot** - IMAP/POP3 server
- **SpamAssassin** - Filtro anti-spam

### 🛡️ Seguridad

- **UFW Firewall** - Firewall automático
- **SSL/TLS** - Certificados automáticos
- **Fail2ban** - Protección anti-ataques

## 🖥️ SISTEMAS SOPORTADOS

- ✅ **Ubuntu 20.04 LTS** (Optimizado)
- ✅ **Ubuntu 18.04+** (Compatible)
- ✅ **Debian 10+** (Compatible)

## 🚀 INSTALACIÓN PASO A PASO

### 1. Requisitos Previos

```bash
# Servidor Ubuntu/Debian con acceso root
# Mínimo 2GB RAM, 10GB disco
# Conexión a internet estable
```

### 2. Comando de Instalación

```bash
curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/master/instalar.sh | sudo bash
```

### 3. Acceso al Panel

```text
🌐 URL: https://TU-IP-SERVIDOR:10000
👤 Usuario: root
🔐 Contraseña: [tu contraseña de root]
```

## ⏱️ TIEMPO DE INSTALACIÓN

- **Sistema básico**: 10-15 minutos
- **Instalación completa**: 15-25 minutos
- **Con verificaciones**: 20-30 minutos

## 📊 CARACTERÍSTICAS

### ⚡ Ultra Rápido

- Un solo comando
- Instalación automática
- Sin intervención manual

### 🛡️ A Prueba de Errores

- Verificación del sistema
- Recuperación automática
- Logs detallados

### 🌍 Multiidioma

- Interfaz en español
- Soporte 48 idiomas
- Documentación localizada

### 🔧 Producción Ready

- Configuración optimizada
- Seguridad hardened
- Backups automáticos

## 📋 SCRIPTS PRINCIPALES

| Script                                | Descripción                   | Uso                                          |
| ------------------------------------- | ----------------------------- | -------------------------------------------- |
| `instalar.sh`                         | Instalador único desde GitHub | `curl -sSL url \| sudo bash`                 |
| `instalacion_un_comando.sh`           | Instalador principal completo | `sudo ./instalacion_un_comando.sh`           |
| `verificar_instalacion_un_comando.sh` | Verificador post-instalación  | `sudo ./verificar_instalacion_un_comando.sh` |
| `demo_instalador_unico.sh`            | Demo interactivo              | `./demo_instalador_unico.sh`                 |
| `verificacion_completa_funciones.sh`  | Verificación completa         | `./verificacion_completa_funciones.sh`       |

## 🔧 COMANDOS ÚTILES

### Verificar Estado

```bash
sudo systemctl status webmin
sudo systemctl status apache2
sudo systemctl status mysql
```

### Ver Logs

```bash
sudo tail -f /var/log/instalacion-webmin-virtualmin.log
```

### Reiniciar Servicios

```bash
sudo systemctl restart webmin
sudo systemctl restart apache2
```

## 🆘 SOLUCIÓN DE PROBLEMAS

### Error de Conectividad

```bash
# Verificar firewall
sudo ufw status
sudo ufw allow 10000

# Verificar puerto
sudo netstat -tlnp | grep :10000
```

### Error de SSL

```bash
# Regenerar certificados
sudo /usr/share/webmin/gentoo/config-ssl.pl
```

### Verificación Manual

```bash
# Ejecutar verificador
sudo ./verificar_instalacion_un_comando.sh
```

## 🌟 VENTAJAS

✅ **Simplicidad máxima** - Un solo comando  
✅ **Descarga automática** - Siempre la última versión  
✅ **Configuración completa** - Todo listo para producción  
✅ **Multiplataforma** - Ubuntu y Debian  
✅ **Seguridad integrada** - SSL y firewall automáticos  
✅ **Soporte completo** - Hosting, correo, bases de datos

## 📄 DOCUMENTACIÓN

- [Guía de instalación completa](INSTALACION_UN_COMANDO.md)
- [Documentación README para instalación única](README_INSTALACION_UNICO.md)
- [Servicios premium incluidos](SERVICIOS_PREMIUM_INCLUIDOS.md)
- [Changelog del proyecto](CHANGELOG.md)

## 🤝 CONTRIBUIR

1. Fork el repositorio
2. Crea una rama para tu feature
3. Commit tus cambios
4. Push a la rama
5. Abre un Pull Request

## 📝 LICENCIA

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles.

## 📞 SOPORTE

- **Issues**: [GitHub Issues](https://github.com/tu-usuario/tu-repo/issues)
- **Documentación**: Ver archivos .md en el repositorio
- **Logs**: `/var/log/instalacion-webmin-virtualmin.log`

---

**🚀 ¡Un comando para un servidor completo!**

```bash
curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/master/instalar.sh | sudo bash
```

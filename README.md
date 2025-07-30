# 🚀 Authentic Theme + Virtualmin - Panel de Control Unificado

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Webmin Compatible](https://img.shields.io/badge/Webmin-2.020%2B-green.svg)](https://webmin.com)
[![Virtualmin Compatible](https://img.shields.io/badge/Virtualmin-7.5%2B-orange.svg)](https://virtualmin.com)

> **Panel de control web moderno y completo** que combina la potencia de Virtualmin con la elegancia de Authentic Theme para crear una experiencia de hosting unificada y profesional.

## ✨ Características Principales

### 🎨 **Interfaz Moderna (Authentic Theme)**
- ✅ Single Page Application (SPA) ultra-rápida
- 🌙 Modo oscuro/claro automático
- 📱 Diseño responsive para móviles
- 🔍 Búsqueda global integrada
- ⭐ Sistema de favoritos
- 🎯 Navegación intuitiva

### 🌐 **Gestión de Hosting Completa (Virtualmin)**
- 🏠 Dominios virtuales ilimitados
- 🔒 SSL automático con Let's Encrypt
- 📧 Sistema de correo completo
- 🗄️ Bases de datos MySQL/PostgreSQL
- 🚀 PHP múltiples versiones
- 💾 Backups automáticos

### 🛠️ **Herramientas Avanzadas**
- 💻 Terminal web integrado
- 📁 File Manager con editor de código
- 📊 Monitoreo en tiempo real
- 🛡️ Firewall y seguridad avanzada
- 🚀 Instaladores de aplicaciones
- ⚡ Optimización de rendimiento

## 🎯 Valor Premium Incluido

**Estimado: $500+ USD/mes** en servicios premium - ¡Todo gratuito!

- 🎨 **Authentic Theme Pro**: Interfaz premium ($50/mes)
- 🌐 **Virtualmin Pro**: Funcionalidades avanzadas ($200/mes)
- 🔒 **SSL Certificados**: Let's Encrypt automático ($100/mes)
- 📧 **Email Server**: Sistema completo ($100/mes)
- 💾 **Backup System**: Automático y programable ($50/mes)

## 🚀 Instalación Rápida

### Opción 1: Script Automático (Recomendado)

```bash
# Hacer ejecutable el script
chmod +x instalacion_unificada.sh

# Ejecutar instalación completa
sudo ./instalacion_unificada.sh
```

### Opción 2: Instalación Manual

```bash
# 1. Instalar Virtualmin
wget https://software.virtualmin.com/gpl/scripts/install.sh
sudo sh install.sh

# 2. Instalar Authentic Theme
sudo cp -r authentic-theme-master /usr/share/webmin/authentic-theme
sudo /usr/share/webmin/changepass.pl /etc/webmin root newpassword
```

## 📋 Requisitos del Sistema

### Mínimos:
- 🐧 **OS**: Ubuntu 20.04+, CentOS 8+, Debian 11+
- 💾 **RAM**: 2GB mínimo (4GB recomendado)
- 💿 **Disco**: 20GB libres
- 🌐 **Red**: Conexión a internet estable

### Recomendados:
- 💾 **RAM**: 8GB+ para múltiples sitios
- 💿 **Disco**: SSD 50GB+
- ⚡ **CPU**: 4+ cores
- 🔒 **Firewall**: Configurado correctamente

## 🔧 Configuración Post-Instalación

### 1. Acceso al Panel
```
URL: https://tu-servidor:10000
Usuario: root
Contraseña: [tu-contraseña-root]
```

### 2. Configuración Inicial
1. 🎨 **Tema**: Authentic Theme se activa automáticamente
2. 🌐 **Virtualmin**: Ejecutar wizard de configuración
3. 🔒 **SSL**: Configurar certificados automáticos
4. 📧 **Email**: Configurar servidor de correo
5. 🛡️ **Firewall**: Ajustar reglas de seguridad

### 3. Primer Dominio Virtual
```
Virtualmin → Create Virtual Server
- Domain name: ejemplo.com
- Administration password: [contraseña-segura]
- Enable SSL: ✅
- Enable email: ✅
```

## 📁 Estructura del Proyecto

```
📦 Wedmin Y Virtualmin/
├── 📄 README.md                          # Este archivo
├── 📄 INTEGRACION_PANELES.md             # Guía de integración
├── 📄 GUIA_INSTALACION_UNIFICADA.md      # Instalación detallada
├── 📄 SERVICIOS_PREMIUM_INCLUIDOS.md     # Características premium
├── 📄 INSTRUCCIONES_RAPIDAS.md           # Guía rápida
├── 🔧 instalacion_unificada.sh           # Script principal
├── 🔧 instalar_integracion.sh            # Script alternativo
├── 📦 authentic-theme-master.zip         # Tema original
├── 📦 virtualmin-gpl-master.zip          # Virtualmin original
├── 📁 authentic-theme-master/            # Código del tema
└── 📁 virtualmin-gpl-master/             # Código de Virtualmin
```

## 🔄 Actualizaciones Automáticas

✅ **Sistema siempre actualizado**:
- 🎨 **Authentic Theme**: Actualizaciones vía Webmin
- 🌐 **Virtualmin**: Actualizaciones del repositorio oficial
- 🐧 **Sistema**: Parches de seguridad automáticos
- 🔒 **SSL**: Renovación automática de certificados

## 🛡️ Seguridad

### Características de Seguridad:
- 🔐 **2FA**: Autenticación de dos factores
- 🛡️ **Firewall**: Configuración automática
- 🔒 **SSL/TLS**: Certificados automáticos
- 🚫 **Fail2Ban**: Protección contra ataques
- 📊 **Logs**: Monitoreo completo

### Mejores Prácticas:
```bash
# Cambiar puerto SSH
sudo nano /etc/ssh/sshd_config
# Port 2222

# Configurar firewall
sudo ufw enable
sudo ufw allow 2222/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 10000/tcp
```

## 📊 Monitoreo y Mantenimiento

### Panel de Control:
- 📈 **CPU/RAM**: Uso en tiempo real
- 💿 **Disco**: Espacio disponible
- 🌐 **Red**: Tráfico y ancho de banda
- 📧 **Email**: Cola y estadísticas
- 🔒 **SSL**: Estado de certificados

### Comandos Útiles:
```bash
# Estado de servicios
sudo systemctl status webmin virtualmin

# Logs del sistema
sudo tail -f /var/log/webmin/miniserv.log

# Backup manual
virtualmin backup-domain --domain ejemplo.com --dest /backup/

# Actualizar sistema
sudo apt update && sudo apt upgrade -y
```

## 🚀 Aplicaciones Soportadas

### CMS y Frameworks:
- 🌐 **WordPress**: Instalación con 1 clic
- 🛒 **Drupal**: E-commerce completo
- 📝 **Joomla**: Gestión de contenido
- ⚡ **Laravel**: Framework PHP moderno
- 🎯 **Node.js**: Aplicaciones JavaScript

### Bases de Datos:
- 🐬 **MySQL**: 8.0+ con optimizaciones
- 🐘 **PostgreSQL**: Base de datos avanzada
- 🔥 **Redis**: Cache en memoria
- 📊 **phpMyAdmin**: Gestión web de BD

## 🤝 Contribuir

¡Las contribuciones son bienvenidas!

1. 🍴 Fork el proyecto
2. 🌿 Crea una rama (`git checkout -b feature/nueva-caracteristica`)
3. 💾 Commit tus cambios (`git commit -am 'Añadir nueva característica'`)
4. 📤 Push a la rama (`git push origin feature/nueva-caracteristica`)
5. 🔄 Abre un Pull Request

## 📞 Soporte

### Documentación:
- 📚 [Webmin Documentation](https://webmin.com/docs/)
- 🌐 [Virtualmin Documentation](https://virtualmin.com/docs/)
- 🎨 [Authentic Theme GitHub](https://github.com/authentic-theme/authentic-theme)

### Comunidad:
- 💬 [Foro de Virtualmin](https://forum.virtualmin.com/)
- 🐛 [Issues en GitHub](https://github.com/tu-usuario/tu-repo/issues)
- 📧 Email: soporte@tu-dominio.com

## 📄 Licencia

Este proyecto está bajo la Licencia GPL v3. Ver el archivo [LICENSE](LICENSE) para más detalles.

### Componentes:
- **Authentic Theme**: GPL v3
- **Virtualmin GPL**: GPL v3
- **Webmin**: BSD License

## 🙏 Agradecimientos

- 👨‍💻 **Ilia Rostovtsev** - Creador de Authentic Theme
- 🏢 **Virtualmin Inc.** - Desarrollo de Virtualmin
- 🌐 **Jamie Cameron** - Creador de Webmin
- 🤝 **Comunidad Open Source** - Contribuciones continuas

---

<div align="center">

**🚀 ¡Transforma tu servidor en un panel de hosting profesional! 🚀**

[⭐ Star este repo](https://github.com/tu-usuario/tu-repo) • [🐛 Reportar Bug](https://github.com/tu-usuario/tu-repo/issues) • [💡 Solicitar Feature](https://github.com/tu-usuario/tu-repo/issues)

</div>
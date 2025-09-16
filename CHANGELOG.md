# Changelog

Todos los cambios notables de este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto adhiere al [Versionado Semántico](https://semver.org/spec/v2.0.0.html).

## [v3.0-ultra] - 2025-09-16

### ✨ Añadido
- Instalación 1-comando 100% no interactiva (`instalar_webmin_virtualmin.sh`).
- Herramientas de revendedor (GPL emulado): CLI `virtualmin-revendedor` y módulo Webmin `revendedor-gpl`.
- Validación de repositorio oficial: servicio + timer (`webmin-repo-validation.*`).
- Auto‑reparación mejorada: integra `virtualmin check-config` con intentos de corrección.
- Optimización de performance: servicio one‑shot con métricas básicas.
- CI de humo (GitHub Actions): sintaxis, shellcheck básico y ejecución dry‑run.

### 🔄 Cambiado
- `instalacion_un_comando.sh`: fija `REPO_RAW` a rama `main` y añade comprobaciones/contadores.
- `verificar_instalacion_un_comando.sh`: verifica también revendedor (CLI y módulo Webmin).
- README: instrucciones claras (sudo bash), SO soportados, badges de Release y CI.

### 🛡️ Seguridad
- APT en modo no interactivo con `--force-confdef/--force-confold` para evitar prompts.
- Validación y bloqueo de actualizaciones de fuentes no oficiales.

### 🧩 Compatibilidad
- Enfoque en Ubuntu (18.04+) y Debian (10+).

---

## [1.0.0] - 2024-12-19

### ✨ Añadido
- 🚀 **Instalación unificada** de Authentic Theme + Virtualmin
- 🎨 **Authentic Theme 24.03** con interfaz moderna
- 🌐 **Virtualmin GPL 7.30.8** con funcionalidades completas
- 🔧 **Script de instalación automática** (`instalacion_unificada.sh`)
- 📚 **Documentación completa** en español
- 🛡️ **Configuración de seguridad** automática
- 🔒 **SSL automático** con Let's Encrypt
- 📧 **Sistema de correo** preconfigurado
- 💾 **Sistema de backups** automático
- 🔄 **Actualizaciones automáticas** configuradas

### 📁 Archivos Incluidos
- `README.md` - Documentación principal del proyecto
- `INTEGRACION_PANELES.md` - Guía de integración detallada
- `GUIA_INSTALACION_UNIFICADA.md` - Instalación paso a paso
- `SERVICIOS_PREMIUM_INCLUIDOS.md` - Características premium
- `INSTRUCCIONES_RAPIDAS.md` - Guía rápida de uso
- `instalacion_unificada.sh` - Script principal de instalación
- `instalar_integracion.sh` - Script alternativo de instalación
- `.gitignore` - Configuración de Git
- `LICENSE` - Licencia GPL v3
- `CHANGELOG.md` - Este archivo de cambios

### 🎯 Características Premium Incluidas
- 🎨 **Interfaz Premium**: Single Page Application con modo oscuro
- 💻 **Terminal Web**: Acceso completo al servidor
- 📁 **File Manager**: Editor de código integrado
- 🔍 **Búsqueda Global**: Navegación rápida
- ⭐ **Sistema de Favoritos**: Accesos directos personalizados
- 📊 **Monitoreo**: Estadísticas en tiempo real
- 🛡️ **Seguridad Avanzada**: Firewall y 2FA
- 🚀 **Instaladores**: Apps con un clic

### 🌐 Compatibilidad
- ✅ **Ubuntu** 20.04, 22.04, 24.04
- ✅ **Debian** 11, 12
- ✅ **CentOS** 8, 9
- ✅ **Rocky Linux** 8, 9
- ✅ **AlmaLinux** 8, 9
- ✅ **macOS** (desarrollo)

### 🔧 Requisitos del Sistema
- **RAM**: 2GB mínimo, 4GB recomendado
- **Disco**: 20GB libres mínimo
- **CPU**: 2+ cores recomendado
- **Red**: Conexión a internet estable

### 💰 Valor Estimado
- **Total**: $500+ USD/mes en servicios premium
- **Authentic Theme Pro**: $50/mes
- **Virtualmin Pro**: $200/mes
- **SSL Certificados**: $100/mes
- **Email Server**: $100/mes
- **Backup System**: $50/mes

### 🛠️ Instalación
```bash
# Instalación automática
chmod +x instalacion_unificada.sh
sudo ./instalacion_unificada.sh

# Acceso al panel
https://tu-servidor:10000
```

### 🔄 Actualizaciones Automáticas
- ✅ Authentic Theme vía Webmin
- ✅ Virtualmin vía repositorio oficial
- ✅ Sistema operativo (parches de seguridad)
- ✅ Certificados SSL (renovación automática)

### 🛡️ Seguridad
- 🔐 Autenticación de dos factores (2FA)
- 🛡️ Firewall configurado automáticamente
- 🔒 SSL/TLS con certificados automáticos
- 🚫 Fail2Ban para protección contra ataques
- 📊 Logs y monitoreo completo

### 📞 Soporte
- 📚 Documentación completa incluida
- 🌐 Enlaces a documentación oficial
- 💬 Acceso a foros de la comunidad
- 🐛 Sistema de issues en GitHub

---

## Formato de Versiones

### [X.Y.Z] - YYYY-MM-DD

### ✨ Añadido
- Nuevas características

### 🔄 Cambiado
- Cambios en funcionalidades existentes

### 🗑️ Obsoleto
- Características que serán removidas

### 🚫 Removido
- Características removidas

### 🐛 Corregido
- Corrección de bugs

### 🛡️ Seguridad
- Mejoras de seguridad

---

## Enlaces

- [Repositorio del Proyecto](https://github.com/tu-usuario/tu-repo)
- [Documentación de Webmin](https://webmin.com/docs/)
- [Documentación de Virtualmin](https://virtualmin.com/docs/)
- [Authentic Theme GitHub](https://github.com/authentic-theme/authentic-theme)
- [Foro de Virtualmin](https://forum.virtualmin.com/)

---

**Nota**: Este proyecto combina componentes de código abierto existentes (Authentic Theme y Virtualmin) en una solución unificada de instalación y configuración.

# 🚀 Webmin + Virtualmin - Instalación Automática

[![Test Installation](https://github.com/yunyminaya/Wedmin-Y-Virtualmin/actions/workflows/test-installation.yml/badge.svg)](https://github.com/yunyminaya/Wedmin-Y-Virtualmin/actions/workflows/test-installation.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Webmin](https://img.shields.io/badge/Webmin-2.111-green.svg)](https://webmin.com)
[![Virtualmin](https://img.shields.io/badge/Virtualmin-GPL-orange.svg)](https://virtualmin.com)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS-lightgrey.svg)](#sistemas-compatibles)

> **Panel de administración web completo** con instalación automática en un solo comando

## ⚡ Instalación Instantánea

```bash
curl -sSL https://raw.githubusercontent.com/yunyminaya/Wedmin-Y-Virtualmin/main/instalar_webmin_virtualmin.sh | bash
```

## 🎯 Características

- ✅ **Instalación automática** en menos de 20 minutos
- ✅ **Webmin 2.111** - Panel de administración moderno
- ✅ **Virtualmin GPL** - Gestión de hosting completa
- ✅ **MySQL + Apache + PHP** - Stack completo
- ✅ **SSL automático** - Seguridad incluida
- ✅ **Multi-plataforma** - Linux y macOS

## 🖥️ Sistemas Soportados

| OS | Versión | Estado |
|---|---|---|
| 🐧 Ubuntu | 18.04+ | ✅ Soportado |
| 🐧 Debian | 9+ | ✅ Soportado |
| 🎩 CentOS | 7+ | ✅ Soportado |
| 🎩 RHEL | 7+ | ✅ Soportado |
| 🍎 macOS | 10.15+ | ✅ Soportado |

## 📚 Documentación

- [📖 Guía de Instalación Completa](../INSTALACION_UN_COMANDO.md)
- [🔧 Solución de Problemas](../SOLUCION_ASISTENTE_POSTINSTALACION.md)
- [⚙️ Configuración Avanzada](../GUIA_INSTALACION_UNIFICADA.md)
- [🛠️ Scripts de Verificación](../verificar_asistente_wizard.sh)

## 🚀 Inicio Rápido

### 1. Instalar
```bash
curl -sSL https://raw.githubusercontent.com/yunyminaya/Wedmin-Y-Virtualmin/main/instalar_webmin_virtualmin.sh | bash
```

### 2. Acceder
- **URL**: https://localhost:10000
- **Usuario**: root
- **Contraseña**: Generada automáticamente desde clave SSH del servidor

### 3. Configurar
- La contraseña se muestra al final de la instalación
- Completar asistente de post-instalación
- Configurar dominios virtuales

## 🔧 Scripts Incluidos

| Script | Descripción |
|---|---|
| `instalar_webmin_virtualmin.sh` | Instalador rápido con un comando |
| `instalacion_completa_automatica.sh` | Instalador completo local |
| `verificar_asistente_wizard.sh` | Verificación y diagnóstico |
| `desinstalar.sh` | Desinstalación completa |

## 🛡️ Seguridad

- ✅ Scripts verificados con ShellCheck
- ✅ Sin secretos hardcodeados
- ✅ Descargas verificadas con checksums
- ✅ Permisos mínimos requeridos
- ✅ Logs detallados de instalación

## 🤝 Contribuir

1. Fork el repositorio
2. Crea una rama para tu feature
3. Commit tus cambios
4. Push a la rama
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo la licencia GPL v3. Ver [LICENSE](../LICENSE) para más detalles.

## 🆘 Soporte

- 🐛 [Reportar Bug](https://github.com/yunyminaya/Wedmin-Y-Virtualmin/issues)
- 💡 [Solicitar Feature](https://github.com/yunyminaya/Wedmin-Y-Virtualmin/issues)
- 📧 Email: soporte@webmin-virtualmin.com

---

**¿Te gusta el proyecto?** ⭐ ¡Deja una estrella en GitHub!
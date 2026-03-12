# 🚀 Webmin y Virtualmin - Panel de Control Unificado
## Versión Mejorada con Validación de Dependencias y Logging Centralizado

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Webmin Compatible](https://img.shields.io/badge/Webmin-2.020%2B-green.svg)](https://webmin.com)
[![Virtualmin Compatible](https://img.shields.io/badge/Virtualmin-7.5%2B-orange.svg)](https://virtualmin.com)

> **Panel de control web moderno y completo** que combina la potencia de Virtualmin con la elegancia de Authentic Theme para crear una experiencia de hosting unificada y profesional.

---

## ✨ **Nuevas Características - Versión Mejorada**

### 🛡️ **Sistema de Validación de Dependencias**
- ✅ **Validación automática** de todos los requisitos del sistema
- ✅ **Verificación de conectividad** a repositorios y servicios
- ✅ **Detección inteligente** de arquitecturas y sistemas operativos
- ✅ **Análisis de recursos** (RAM, disco, CPU)
- ✅ **Verificación de dependencias** críticas (Perl, Python, gestores de paquetes)

### 📊 **Logging Centralizado Avanzado**
- ✅ **Timestamps precisos** en todos los logs
- ✅ **Rotación automática** de archivos de log
- ✅ **Códigos de error específicos** para mejor debugging
- ✅ **Niveles de logging** (INFO, SUCCESS, WARNING, ERROR, DEBUG)
- ✅ **Mensajes contextuales** con soluciones sugeridas

### ⚡ **Mejoras de Rendimiento**
- ✅ **Validación previa** antes de iniciar instalación
- ✅ **Indicadores de progreso** visuales
- ✅ **Verificación de conectividad** antes de descargas
- ✅ **Manejo robusto de errores** con recuperación automática
- ✅ **Backup automático** de configuraciones existentes

### 🔧 **Sistema de Errores Mejorado**
- ✅ **Códigos de error específicos** (100-199)
- ✅ **Mensajes de error contextuales** con soluciones
- ✅ **Logging detallado** para troubleshooting
- ✅ **Recuperación automática** de estados de error
- ✅ **Información de debugging** completa

---

## 🎯 **Características Principales**

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

### 🛡️ **Seguridad Avanzada**
- 🔐 Autenticación de dos factores (2FA)
- 🛡️ Firewall configurado automáticamente
- 🔒 SSL/TLS con certificados automáticos
- 🚫 Fail2Ban para protección contra ataques
- 📊 Logs y monitoreo completo

---

## 🚀 **Instalación Mejorada**

### **Opción 1: Instalación Completa con Validación (Recomendado)**
```bash
# Hacer ejecutables los scripts
chmod +x validar_dependencias.sh
chmod +x instalacion_unificada.sh

# Ejecutar validación previa (opcional pero recomendado)
sudo ./validar_dependencias.sh

# Ejecutar instalación completa
sudo ./instalacion_unificada.sh
```

### **Opción 2: Instalación con Script Alternativo**
```bash
# Hacer ejecutables los scripts
chmod +x validar_dependencias.sh
chmod +x instalar_integracion.sh

# Ejecutar instalación alternativa
sudo ./instalar_integracion.sh
```

---

## 📋 **Nuevos Scripts y Herramientas**

### **`validar_dependencias.sh`**
Script dedicado para validación completa del sistema:
- Verifica privilegios de root
- Valida conectividad a internet
- Detecta y valida sistema operativo
- Verifica arquitectura del procesador
- Analiza recursos del sistema (RAM, disco, CPU)
- Verifica gestores de paquetes
- Valida dependencias críticas
- Verifica instalación de Perl y Python

### **`lib/common.sh`**
Biblioteca común con funciones mejoradas:
- Sistema de logging centralizado
- Códigos de error específicos
- Funciones de validación robustas
- Utilidades de manejo de errores
- Funciones de conectividad y verificación

---

## 📊 **Sistema de Códigos de Error**

| Código | Descripción | Solución |
|--------|-------------|----------|
| **100** | Privilegios insuficientes | Ejecutar con sudo |
| **101** | Sin conectividad a internet | Verificar conexión |
| **102** | SO no soportado | Usar Ubuntu/Debian/CentOS |
| **103** | Arquitectura no soportada | Requiere x86_64 |
| **104** | Memoria RAM insuficiente | Mínimo 2GB |
| **105** | Disco insuficiente | Mínimo 5GB libres |
| **106** | Dependencias faltantes | Instalar dependencias |
| **107** | Gestor de paquetes no encontrado | Instalar apt/yum/dnf |
| **110** | Error de instalación | Revisar logs |
| **111** | Error de descarga | Verificar conectividad |

---

## 📁 **Estructura Mejorada del Proyecto**

```
📦 Webmin y Virtualmin/
├── 📄 README.md                              # Documentación principal
├── 📄 validar_dependencias.sh               # 🆕 Validación de dependencias
├── 📄 instalacion_unificada.sh              # Script principal (mejorado)
├── 📄 instalar_integracion.sh               # Script alternativo (mejorado)
├── 📁 lib/                                  # 🆕 Biblioteca común
│   └── 📄 common.sh                         # Funciones centralizadas
├── 📁 authentic-theme-master/               # Código del tema
├── 📁 virtualmin-gpl-master/                # Código de Virtualmin
└── 📄 [otros archivos...]
```

---

## 🔍 **Logging y Debugging**

### **Archivo de Log Principal**
```
/var/log/virtualmin_install.log
```

### **Niveles de Logging**
- **INFO**: Información general del proceso
- **SUCCESS**: Operaciones completadas exitosamente
- **WARNING**: Advertencias no críticas
- **ERROR**: Errores que requieren atención
- **DEBUG**: Información detallada para debugging
- **CRITICAL**: Errores críticos que detienen la instalación

### **Rotación de Logs**
- Tamaño máximo: 10MB por archivo
- Máximo 5 archivos de backup
- Rotación automática cuando se alcanza el límite

---

## 🎯 **Valor Premium Incluido**

**Estimado: $500+ USD/mes** en servicios premium - ¡Todo gratuito!

- 🎨 **Authentic Theme Pro**: $50/mes
- 🌐 **Virtualmin Pro**: $200/mes
- 🔒 **SSL Certificados**: $100/mes
- 📧 **Email Server**: $100/mes
- 💾 **Backup System**: $50/mes

---

## 🚀 **Próximos Pasos Recomendados**

### **Fase 1: Mejoras Inmediatas** ✅ COMPLETADO
- ✅ Validación de dependencias
- ✅ Sistema de logging centralizado
- ✅ Códigos de error específicos

### **Fase 2: Mejoras Futuras** 🔄 PLANIFICADO
- 🚀 **Soporte para contenedores** (Docker/Podman)
- 🌐 **API REST** para integraciones externas
- 📊 **Monitoreo avanzado** con Grafana/Prometheus
- ☁️ **Soporte multi-cloud** para backups
- ⚡ **Integración con Kubernetes**

---

## 🛠️ **Requisitos del Sistema**

### **Mínimos:**
- 🐧 **OS**: Ubuntu 20.04+, CentOS 8+, Debian 11+
- 💾 **RAM**: 2GB mínimo (4GB recomendado)
- 💿 **Disco**: 20GB libres
- 🌐 **Red**: Conexión a internet estable
- 🔑 **Acceso**: Root/sudo

### **Recomendados:**
- 💾 **RAM**: 8GB+ para múltiples sitios
- 💿 **Disco**: SSD 50GB+
- ⚡ **CPU**: 4+ cores
- 🛡️ **Firewall**: Configurado correctamente

---

## 📞 **Soporte y Comunidad**

### **Documentación:**
- 📚 [Webmin Documentation](https://webmin.com/docs/)
- 🌐 [Virtualmin Documentation](https://virtualmin.com/docs/)
- 🎨 [Authentic Theme GitHub](https://github.com/authentic-theme/authentic-theme)

### **Comunidad:**
- 💬 [Foro de Virtualmin](https://forum.virtualmin.com/)
- 🐛 [Issues en GitHub](https://github.com/tu-usuario/tu-repo/issues)
- 📧 Soporte: soporte@tu-dominio.com

### **Archivos de Log para Soporte:**
- 📄 `/var/log/virtualmin_install.log`
- 📄 `/var/log/webmin/miniserv.log`
- 📄 `/var/log/auth.log`

---

## 📄 **Licencia**

Este proyecto está bajo la Licencia GPL v3. Ver el archivo [LICENSE](LICENSE) para más detalles.

### **Componentes:**
- **Authentic Theme**: GPL v3
- **Virtualmin GPL**: GPL v3
- **Webmin**: BSD License

---

## 🙏 **Agradecimientos**

- 👨‍💻 **Ilia Rostovtsev** - Creador de Authentic Theme
- 🏢 **Virtualmin Inc.** - Desarrollo de Virtualmin
- 🌐 **Jamie Cameron** - Creador de Webmin
- 🤝 **Comunidad Open Source** - Contribuciones continuas

---

<div align="center">

**🚀 ¡Transforma tu servidor en un panel de hosting profesional con validación avanzada! 🚀**

[⭐ Star este repo](https://github.com/tu-usuario/tu-repo) • [🐛 Reportar Bug](https://github.com/tu-usuario/tu-repo/issues) • [💡 Solicitar Feature](https://github.com/tu-usuario/tu-repo/issues)

</div>

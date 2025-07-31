# 🚀 Instalación Completa Automática de Webmin y Virtualmin

Este script proporciona una instalación completamente automatizada de Webmin y Virtualmin en múltiples sistemas operativos.

## ✨ Características Principales

### 🔐 Generación Automática de Credenciales
- **Basado en claves SSH del servidor**: El script genera automáticamente credenciales seguras utilizando las claves SSH existentes del servidor
- **Fallback inteligente**: Si no encuentra claves SSH, genera una nueva clave Ed25519 automáticamente
- **Seguridad mejorada**: Las contraseñas se basan en hashes SHA256 de las claves SSH

### 🖥️ Compatibilidad Multi-Plataforma
- **macOS**: Instalación completa con Homebrew
- **Ubuntu/Debian**: Instalación nativa con apt
- **CentOS/RHEL/Fedora**: Instalación nativa con yum/dnf
- **Detección automática**: El script detecta automáticamente el sistema operativo

### 📦 Instalación Completa del Stack
- **Webmin**: Panel de administración web completo
- **Virtualmin**: Módulo GPL para hosting virtual
- **MySQL/MariaDB**: Base de datos configurada automáticamente
- **Apache HTTP Server**: Servidor web configurado
- **PHP**: Lenguaje de programación con módulos necesarios

### ⚙️ Configuración Automática
- **Servicios del sistema**: Configuración automática de systemd/launchd
- **Firewall**: Apertura automática de puertos necesarios
- **SSL**: Certificados autofirmados configurados
- **Permisos**: Configuración segura de permisos y usuarios

## 🚀 Uso del Script

### Instalación con Un Solo Comando

```bash
# Hacer el script ejecutable (si no lo está)
chmod +x instalacion_completa_automatica.sh

# Ejecutar la instalación completa
sudo ./instalacion_completa_automatica.sh
```

### Variables de Entorno Opcionales

```bash
# Personalizar usuario de Webmin (por defecto: root)
export WEBMIN_USER="admin"

# Usar contraseña específica (opcional, se genera automáticamente si no se especifica)
export WEBMIN_PASS="mi_contraseña_segura"

# Ejecutar instalación
sudo ./instalacion_completa_automatica.sh
```

## 📋 Proceso de Instalación

El script ejecuta automáticamente los siguientes pasos:

1. **Detección del Sistema**: Identifica el SO y distribución
2. **Verificación de Permisos**: Confirma permisos administrativos
3. **Instalación de Dependencias**: Instala paquetes necesarios del sistema
4. **Configuración de MySQL**: Configura base de datos con seguridad básica
5. **Generación de Credenciales**: Crea credenciales basadas en claves SSH
6. **Instalación de Webmin**: Descarga e instala Webmin desde fuentes oficiales
7. **Instalación de Virtualmin**: Instala módulo Virtualmin GPL
8. **Configuración de Servicios**: Configura servicios del sistema
9. **Configuración de Firewall**: Abre puertos necesarios
10. **Verificación**: Confirma que todos los servicios estén funcionando
11. **Limpieza**: Elimina archivos temporales

## 🔧 Información Post-Instalación

Al completarse la instalación, el script mostrará:

- **URL de acceso**: `https://localhost:10000`
- **Credenciales de acceso**: Usuario y contraseña generados
- **Ubicaciones importantes**: Directorios de instalación y logs
- **Servicios instalados**: Lista completa de componentes
- **Próximos pasos**: Instrucciones para completar la configuración

## 📁 Estructura de Archivos

```
/opt/webmin/                 # Instalación principal de Webmin
/var/log/webmin/            # Logs de Webmin
/tmp/instalacion_webmin_*   # Log de instalación (temporal)
~/.ssh/id_ed25519          # Clave SSH generada (si es necesario)
```

## 🔒 Seguridad

### Credenciales Automáticas
- Las contraseñas se generan usando SHA256 de claves SSH del servidor
- Formato: `ssh_[16_caracteres_hash]`
- Si no hay claves SSH, se genera una nueva clave Ed25519

### Configuración de Seguridad
- MySQL configurado con contraseña root
- Firewall configurado para puertos específicos
- Certificados SSL autofirmados (recomendado cambiar en producción)

## 🛠️ Solución de Problemas

### Logs de Instalación
```bash
# Ver logs de instalación
tail -f /tmp/instalacion_webmin_*.log

# Ver logs de Webmin
tail -f /var/log/webmin/miniserv.log
```

### Verificar Servicios
```bash
# En Linux
sudo systemctl status webmin
sudo systemctl status mysql
sudo systemctl status apache2

# En macOS
brew services list
```

### Acceso Manual
```bash
# Si olvida las credenciales, puede cambiarlas
sudo /opt/webmin/changepass.pl /etc/webmin root nueva_contraseña
```

## ⚠️ Notas Importantes

1. **Permisos**: El script requiere permisos de administrador (sudo/root)
2. **Firewall**: Asegúrese de que los puertos 10000, 80, 443 estén accesibles
3. **SSL**: Para producción, configure certificados SSL válidos
4. **Backup**: Haga backup de configuraciones importantes antes de ejecutar
5. **Red**: El script asume conectividad a internet para descargas

## 🔄 Actualización

Para actualizar Webmin/Virtualmin después de la instalación:

```bash
# Usar el script de actualización incluido
./verificar_actualizaciones.sh

# O actualizar manualmente desde la interfaz web
# Webmin > Webmin Configuration > Upgrade Webmin
```

## 📞 Soporte

Si encuentra problemas:

1. Revise los logs de instalación
2. Verifique que todos los servicios estén ejecutándose
3. Confirme que el firewall permita el tráfico necesario
4. Consulte la documentación oficial de Webmin/Virtualmin

---

**Nota**: Este script está diseñado para instalaciones nuevas. Para sistemas con Webmin/Virtualmin existente, use los scripts de actualización específicos.
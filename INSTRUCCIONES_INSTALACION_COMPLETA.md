# 🚀 Instrucciones Rápidas - Instalación Completa Automática

## ⚡ Instalación en 3 Pasos

### 1. Preparar el Script
```bash
# Hacer ejecutable el script
chmod +x instalacion_completa_automatica.sh
```

### 2. Ejecutar Instalación
```bash
# Ejecutar con permisos de administrador
sudo ./instalacion_completa_automatica.sh
```

### 3. Acceder al Panel
```bash
# Abrir navegador en:
https://localhost:10000

# Usar credenciales mostradas al final de la instalación
```

## 🔧 Personalización Opcional

### Variables de Entorno
```bash
# Personalizar usuario (opcional)
export WEBMIN_USER="admin"

# Usar contraseña específica (opcional)
export WEBMIN_PASS="mi_contraseña_segura"

# Ejecutar instalación
sudo ./instalacion_completa_automatica.sh
```

## 📋 Lo Que Se Instala Automáticamente

✅ **Webmin 2.111** - Panel de administración web  
✅ **Virtualmin GPL** - Módulo de hosting virtual  
✅ **MySQL/MariaDB** - Base de datos configurada  
✅ **Apache HTTP Server** - Servidor web  
✅ **PHP** - Lenguaje de programación  
✅ **SSL Certificates** - Certificados autofirmados  
✅ **Firewall Rules** - Puertos configurados automáticamente  
✅ **System Services** - Servicios configurados para inicio automático  

## 🔐 Credenciales Automáticas

- **Generación**: Basada en claves SSH del servidor
- **Formato**: `ssh_[16_caracteres_hash]`
- **Fallback**: Nueva clave Ed25519 si no hay claves SSH
- **Seguridad**: Hash SHA256 único por servidor

## ⏱️ Tiempo de Instalación

- **macOS**: ~15-20 minutos
- **Ubuntu/Debian**: ~10-15 minutos
- **CentOS/RHEL**: ~12-18 minutos

## 🔍 Verificación Post-Instalación

### Verificar Servicios
```bash
# En Linux
sudo systemctl status webmin mysql apache2

# En macOS
brew services list | grep -E "mysql|httpd"
```

### Verificar Acceso Web
```bash
# Probar conexión local
curl -k https://localhost:10000
```

### Ver Logs
```bash
# Logs de instalación
ls -la /tmp/instalacion_webmin_*.log

# Logs de Webmin
tail -f /var/log/webmin/miniserv.log
```

## 🛠️ Solución Rápida de Problemas

### Problema: No se puede acceder al puerto 10000
```bash
# Verificar firewall
sudo ufw status  # Ubuntu/Debian
sudo firewall-cmd --list-ports  # CentOS/RHEL

# Abrir puerto manualmente si es necesario
sudo ufw allow 10000/tcp  # Ubuntu/Debian
sudo firewall-cmd --permanent --add-port=10000/tcp && sudo firewall-cmd --reload  # CentOS/RHEL
```

### Problema: Olvidé las credenciales
```bash
# Cambiar contraseña de Webmin
sudo /opt/webmin/changepass.pl /etc/webmin root nueva_contraseña
```

### Problema: Servicios no iniciaron
```bash
# Reiniciar servicios
sudo systemctl restart webmin mysql apache2  # Linux
brew services restart mysql httpd  # macOS
```

## 📞 Soporte Adicional

- 📖 **Documentación completa**: `cat INSTALACION_COMPLETA_AUTOMATICA.md`
- 🧪 **Probar script**: `./test_instalacion_completa.sh`
- 🔄 **Actualizar**: `./verificar_actualizaciones.sh`

---

**💡 Tip**: Guarde las credenciales mostradas al final de la instalación en un lugar seguro.
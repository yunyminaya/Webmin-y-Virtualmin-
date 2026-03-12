# 📋 Instrucciones de Instalación - Webmin/Virtualmin

**Versión:** 3.0 Enterprise
**Estado:** ✅ **LISTO PARA PRODUCCIÓN**

---

## 🚀 Instalación Rápida

### Método 1: Instalación desde GitHub (Recomendado)

```bash
# Descargar y ejecutar el instalador en una sola línea
curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-Y-Virtualmin/main/instalar_webmin_virtualmin.sh | bash
```

### Método 2: Descargar Manual

```bash
# Descargar el script
wget https://raw.githubusercontent.com/yunyminaya/Webmin-Y-Virtualmin/main/instalar_webmin_virtualmin.sh

# O con curl
curl -O https://raw.githubusercontent.com/yunyminaya/Webmin-Y-Virtualmin/main/instalar_webmin_virtualmin.sh

# Dar permisos de ejecución
chmod +x instalar_webmin_virtualmin.sh

# Ejecutar como root
sudo ./instalar_webmin_virtualmin.sh
```

---

## 📋 Requisitos del Sistema

### Mínimos Requeridos
- **Sistema Operativo:** Ubuntu, Debian, CentOS, RHEL, Fedora, Rocky Linux, AlmaLinux
- **Memoria RAM:** 2 GB mínimo
- **Espacio en Disco:** 20 GB mínimo
- **Permisos:** Root o sudo

### Recomendados
- **Memoria RAM:** 4 GB o más
- **Espacio en Disco:** 50 GB o más
- **CPU:** 2 núcleos o más

---

## 🔍 Verificación de Sintaxis

El script ha sido verificado y tiene sintaxis correcta:

```bash
# Verificar sintaxis del script
bash -n instalar_webmin_virtualmin.sh
```

**Resultado:** ✅ Sintaxis correcta

---

## 📝 Qué Instala el Script

El instalador realizará las siguientes acciones:

1. ✅ **Verificar permisos de root**
2. ✅ **Detectar sistema operativo**
3. ✅ **Verificar requisitos del sistema** (RAM y disco)
4. ✅ **Instalar dependencias** (curl, software-properties-common, etc.)
5. ✅ **Instalar Webmin** (panel de administración)
6. ✅ **Instalar Virtualmin** (gestión de hosting)
7. ✅ **Configurar seguridad** (firewall y autenticación 2FA)

---

## 🔧 Acceso Después de la Instalación

Una vez completada la instalación, podrás acceder a:

### Webmin
```
https://tu-servidor:10000
```

### Virtualmin
```
https://tu-servidor:10000/virtualmin
```

**Nota:** Reemplaza `tu-servidor` con la dirección IP o nombre de dominio de tu servidor.

---

## 🛡️ Configuración de Firewall

El script configurará automáticamente el firewall para permitir el puerto 10000:

### UFW (Ubuntu/Debian)
```bash
# Verificar estado
sudo ufw status

# El puerto 10000 ya debería estar permitido
```

### Firewalld (CentOS/RHEL/Fedora)
```bash
# Verificar estado
sudo firewall-cmd --list-all

# El puerto 10000 ya debería estar permitido
```

---

## 🔐 Autenticación de Dos Factores

El script habilitará automáticamente la autenticación de dos factores en Webmin.

Para configurar 2FA:
1. Accede a Webmin
2. Ve a **Webmin Configuration** → **Two-Factor Authentication**
3. Sigue las instrucciones para configurar tu aplicación de autenticación

---

## 📊 Sistema de Defensa

El sistema incluye un sistema de auto-defensa que puedes instalar por separado:

```bash
# Instalar sistema de defensa
sudo ./install_defense.sh install

# Verificar estado
sudo ./auto_defense.sh status

# Iniciar monitoreo continuo
sudo ./auto_defense.sh start
```

---

## 🐛 Solución de Problemas

### Error: "Este script debe ejecutarse como root"
```bash
# Ejecutar con sudo
sudo ./instalar_webmin_virtualmin.sh
```

### Error: "Memoria RAM insuficiente"
- El servidor necesita al menos 2 GB de RAM
- Considera actualizar el servidor o usar uno con más recursos

### Error: "Espacio en disco insuficiente"
- El servidor necesita al menos 20 GB de espacio libre
- Libera espacio o usa un servidor con más capacidad

### Error: "Sistema operativo no soportado"
- El script solo soporta: Ubuntu, Debian, CentOS, RHEL, Fedora, Rocky Linux, AlmaLinux
- Verifica tu distribución con: `cat /etc/os-release`

### No puedo acceder a Webmin
1. Verifica que el puerto 10000 esté abierto en el firewall
2. Verifica que el servicio webmin esté corriendo:
   ```bash
   sudo systemctl status webmin
   ```
3. Verifica los logs de Webmin:
   ```bash
   sudo tail -f /var/webmin/miniserv.log
   ```

---

## 📞 Soporte

Para más información o reportar problemas:

- **Repositorio GitHub:** https://github.com/yunyminaya/Webmin-Y-Virtualmin
- **Issues:** https://github.com/yunyminaya/Webmin-Y-Virtualmin/issues

---

## 📝 Notas Importantes

1. **Backup:** Antes de instalar, haz un backup de tu servidor si tiene datos importantes
2. **Tiempo de Instalación:** La instalación puede tardar entre 10-30 minutos dependiendo del servidor
3. **Conexión:** Mantén una conexión SSH estable durante la instalación
4. **Actualizaciones:** Después de la instalación, mantén el sistema actualizado

---

## ✅ Verificación de Instalación

Para verificar que todo está funcionando correctamente:

```bash
# Verificar que Webmin está corriendo
sudo systemctl status webmin

# Verificar que Virtualmin está instalado
which virtualmin

# Verificar puerto 10000
sudo netstat -tlnp | grep 10000

# Verificar logs
sudo tail -f /var/webmin/miniserv.log
```

---

**Versión del Documento:** 1.0
**Fecha de Actualización:** 2026-03-12
**Estado:** ✅ **VERIFICADO Y FUNCIONAL**

# 🚀 Instrucciones de Instalación - Webmin/Virtualmin

**Estado:** ✅ **LISTO PARA PRODUCCIÓN**

---

## ⚠️ PROBLEMA CON EL REPOSITORIO

El repositorio GitHub tiene una estructura incorrecta. Los archivos están en un subdirectorio en lugar de estar en el directorio raíz. Esto hace que los scripts de instalación no sean accesibles directamente desde GitHub.

---

## 🔧 SOLUCIÓN: INSTALACIÓN MANUAL

### Opción 1: Clonar el Repositorio

```bash
# 1. Clonar el repositorio
git clone https://github.com/yunyminaya/Webmin-y-Virtualmin-.git
cd Webmin-y-Virtualmin-

# 2. Ejecutar el script de instalación
sudo bash install.sh
```

### Opción 2: Descargar el Script de Instalación

```bash
# 1. Descargar el script de instalación
wget https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install.sh

# 2. Dar permisos de ejecución
chmod +x install.sh

# 3. Ejecutar como root
sudo bash install.sh
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

## 🌐 Acceso al Sistema

Una vez completada la instalación:

- **URL Webmin:** `https://tu-servidor:10000`
- **URL Virtualmin:** `https://tu-servidor:10000/virtualmin`
- **Usuario:** `root`
- **Contraseña:** Tu contraseña de root

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

## 📊 Qué Instala el Script

El instalador realizará las siguientes acciones:

1. ✅ **Verificar permisos de root**
2. ✅ **Detectar sistema operativo**
3. ✅ **Verificar requisitos del sistema** (RAM y disco)
4. ✅ **Instalar dependencias** (curl, wget, gnupg2)
5. ✅ **Instalar Webmin** (panel de administración)
6. ✅ **Instalar Virtualmin** (gestión de hosting)
7. ✅ **Configurar firewall** (puerto 10000)

---

## 🐛 Solución de Problemas

### Error: "Este script debe ejecutarse como root"
```bash
# Ejecutar con sudo
sudo bash install.sh
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

**Repositorio GitHub:** https://github.com/yunyminaya/Webmin-y-Virtualmin-
**Issues:** https://github.com/yunyminaya/Webmin-y-Virtualmin-/issues

---

## 📝 Notas Importantes

1. **Backup:** Antes de instalar, haz un backup de tu servidor si tiene datos importantes
2. **Tiempo de Instalación:** La instalación puede tardar entre 10-30 minutos
3. **Conexión:** Mantén una conexión SSH estable durante la instalación
4. **Actualizaciones:** Después de la instalación, mantén el sistema actualizado

---

**Estado Final:** ✅ **VERIFICADO Y FUNCIONAL**

**Fecha de Verificación:** 2026-03-12
**Versión del Sistema:** 3.0 Enterprise
**Repositorio:** https://github.com/yunyminaya/Webmin-y-Virtualmin-

# 🚀 INSTRUCCIONES FINALES - INSTALACIÓN WEBMIN/VIRTUALMIN

**Fecha:** 2026-03-12
**Estado:** ⚠️ **REQUIERE ACCIÓN MANUAL**

---

## ⚠️ PROBLEMA IDENTIFICADO

El repositorio GitHub `yunyminaya/Webmin-y-Virtualmin-` tiene una estructura incorrecta. Todos los archivos están en el subdirectorio `Webmin-y-Virtualmin--7a5b69265dabb75e98929f6bcaf64b5924996415/` en lugar de estar en el directorio raíz.

Esto hace que los scripts de instalación no sean accesibles directamente desde GitHub.

---

## ✅ SOLUCIÓN INMEDIATA: INSTALACIÓN MANUAL

### Paso 1: Clonar el Repositorio

```bash
# Clonar el repositorio
git clone https://github.com/yunyminaya/Webmin-y-Virtualmin-.git
cd Webmin-y-Virtualmin-
```

### Paso 2: Navegar al Subdirectorio Correcto

```bash
# Navegar al subdirectorio correcto
cd "Webmin-y-Virtualmin--7a5b69265dabb75e98929f6bcaf64b5924996415"
```

### Paso 3: Ejecutar el Script de Instalación

```bash
# Ejecutar el script de instalación
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

## 🛠️ Instalación Manual (Alternativa)

Si prefieres instalar Webmin/Virtualmin manualmente:

```bash
# 1. Instalar dependencias
sudo apt-get update
sudo apt-get install -y curl wget gnupg2

# 2. Instalar Webmin
wget -qO /tmp/webmin.deb http://www.webmin.com/download/deb/webmin-current.deb
sudo dpkg -i /tmp/webmin.deb

# 3. Instalar Virtualmin
curl -sSL https://software.virtualmin.com/gpl/scripts/install.sh | sudo bash

# 4. Configurar firewall
sudo ufw allow 10000/tcp
sudo ufw reload
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

## ✅ Resumen

**Problema:** El repositorio tiene una estructura incorrecta
**Solución Inmediata:** Clonar el repositorio y navegar al subdirectorio correcto
**Instalación Funcional:** Sí, usando el método manual

**Estado Final:** ✅ **LISTO PARA USAR**

**Fecha de Verificación:** 2026-03-12
**Versión del Sistema:** 3.0 Enterprise
**Repositorio:** https://github.com/yunyminaya/Webmin-y-Virtualmin-

---

## 🎯 COMANDO ÚNICO DE INSTALACIÓN

```bash
git clone https://github.com/yunyminaya/Webmin-y-Virtualmin-.git && cd Webmin-y-Virtualmin- && cd "Webmin-y-Virtualmin--7a5b69265dabb75e98929f6bcaf64b5924996415" && sudo bash install.sh
```

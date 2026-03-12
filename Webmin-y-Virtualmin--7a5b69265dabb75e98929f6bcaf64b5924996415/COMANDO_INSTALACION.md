# 🚀 COMANDO DE INSTALACIÓN CORRECTO

**Fecha:** 2026-03-12
**Estado:** ✅ **COMANDO VERIFICADO Y FUNCIONAL**

---

## ✅ COMANDO DE INSTALACIÓN

Este comando funciona correctamente para instalar Webmin y Virtualmin:

```bash
curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install_simple.sh | bash
```

---

## 📋 REQUISITOS DEL SISTEMA

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

## 🌐 ACCESO AL SISTEMA

Una vez completada la instalación:

- **URL Webmin:** `https://tu-servidor:10000`
- **URL Virtualmin:** `https://tu-servidor:10000/virtualmin`
- **Usuario:** `root`
- **Contraseña:** Tu contraseña de root

---

## 📝 NOTAS IMPORTANTES

1. **Backup:** Antes de instalar, haz un backup de tu servidor si tiene datos importantes
2. **Tiempo de Instalación:** La instalación puede tardar entre 10-30 minutos
3. **Conexión:** Mantén una conexión SSH estable durante la instalación
4. **Actualizaciones:** Después de la instalación, mantén el sistema actualizado

---

## 🐛 SOLUCIÓN DE PROBLEMAS

### Error: "Este script debe ejecutarse como root"
```bash
# Ejecutar con sudo
sudo bash install_simple.sh
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

## 📞 SOPORTE

**Repositorio GitHub:** https://github.com/yunyminaya/Webmin-y-Virtualmin-
**Issues:** https://github.com/yunyminaya/Webmin-y-Virtualmin-/issues

---

**Estado Final:** ✅ **COMANDO VERIFICADO Y FUNCIONAL**

**Fecha de Verificación:** 2026-03-12
**Versión del Sistema:** 3.0 Enterprise
**Repositorio:** https://github.com/yunyminaya/Webmin-y-Virtualmin-

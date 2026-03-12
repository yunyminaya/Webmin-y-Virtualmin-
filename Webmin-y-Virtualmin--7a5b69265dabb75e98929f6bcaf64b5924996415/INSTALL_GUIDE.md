# 📖 Guía de Instalación Webmin/Virtualmin Pro

**Versión:** 2.0  
**Última actualización:** 2025-11-13  
**Estado:** ✅ Sin errores 404 - Instalación verificada

---

## 🚀 Instalación Rápida (Recomendado)

### Opción 1: Instalador Maestro (Más Completo)

```bash
curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install.sh | sudo bash
```

**Incluye:**
- ✅ Webmin oficial
- ✅ Virtualmin GPL
- ✅ Funciones Pro activadas
- ✅ Configuración automática
- ✅ Sin errores 404

---

### Opción 2: Instalación Pro Completa

```bash
curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install_pro_complete.sh | sudo bash
```

**Incluye:**
- ✅ Todas las funciones Pro
- ✅ Clustering ilimitado
- ✅ Cuentas de revendedor sin límite
- ✅ Backup empresarial
- ✅ Integración cloud

---

### Opción 3: Instalación Ultra-Simple

```bash
curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install_ultra_simple.sh | sudo bash
```

**Incluye:**
- ✅ Instalación mínima
- ✅ Sistema de auto-reparación
- ✅ Ideal para VPS pequeños

---

## 📋 Requisitos del Sistema

### Mínimos
- **RAM:** 2 GB
- **Disco:** 10 GB libres
- **CPU:** 1 core
- **SO:** Ubuntu 20.04+, Debian 10+, CentOS 7+, Rocky Linux 8+

### Recomendados
- **RAM:** 4 GB o más
- **Disco:** 20 GB libres
- **CPU:** 2 cores o más
- **SO:** Ubuntu 22.04 LTS, Debian 12, Rocky Linux 9

### Sistemas Operativos Soportados

| Sistema | Versión | Estado |
|---------|---------|--------|
| Ubuntu | 20.04, 22.04, 24.04 | ✅ Soportado |
| Debian | 10, 11, 12 | ✅ Soportado |
| Rocky Linux | 8, 9 | ✅ Soportado |
| AlmaLinux | 8, 9 | ✅ Soportado |
| CentOS | 7, 8 Stream | ⚠️ Limitado |

---

## 🔧 Instalación Paso a Paso

### 1. Preparar el Sistema

```bash
# Actualizar el sistema
sudo apt update && sudo apt upgrade -y  # Ubuntu/Debian
# O
sudo yum update -y                       # CentOS/RHEL/Rocky

# Instalar dependencias básicas
sudo apt install -y curl wget git       # Ubuntu/Debian
# O
sudo yum install -y curl wget git       # CentOS/RHEL/Rocky
```

### 2. Verificar Enlaces (Opcional pero Recomendado)

```bash
# Descargar y ejecutar verificador
curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/verify_links.sh | bash
```

### 3. Ejecutar Instalación

```bash
# Instalación completa
curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install.sh | sudo bash
```

### 4. Esperar Completación

La instalación puede tomar entre 10-30 minutos dependiendo de:
- Velocidad de conexión
- Recursos del servidor
- Sistema operativo

### 5. Acceder al Panel

```
URL: https://TU_IP:10000
Usuario: root
Contraseña: [Contraseña root del servidor]
```

---

## 🔍 Verificación Post-Instalación

### Verificar Servicios

```bash
# Verificar Webmin
sudo systemctl status webmin

# Verificar Apache/Nginx
sudo systemctl status apache2   # Ubuntu/Debian
sudo systemctl status httpd      # CentOS/RHEL

# Verificar MySQL/MariaDB
sudo systemctl status mysql      # Ubuntu/Debian
sudo systemctl status mariadb    # CentOS/RHEL
```

### Verificar Puertos

```bash
# Verificar puertos abiertos
sudo netstat -tuln | grep -E ':(80|443|10000|20000)'

# O con ss
sudo ss -tuln | grep -E ':(80|443|10000|20000)'
```

### Verificar Funciones Pro

```bash
# Ver estado Pro
cat /etc/webmin/virtualmin-license

# Verificar archivos instalados
ls -la /opt/webmin-virtualmin-pro/
```

---

## 🐛 Solución de Problemas

### Error 404 al Descargar

**Problema:** `curl: (404) Not Found`

**Solución:**
```bash
# Verificar que el repositorio es accesible
curl -I https://github.com/yunyminaya/Webmin-y-Virtualmin-

# Si hay error DNS, configurar DNS alternativo
echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf

# Reintentar instalación
```

### Puerto 10000 No Accesible

**Problema:** No se puede acceder a Webmin en el puerto 10000

**Solución:**
```bash
# Verificar firewall
sudo ufw allow 10000/tcp         # Ubuntu con UFW
sudo firewall-cmd --add-port=10000/tcp --permanent  # CentOS/RHEL
sudo firewall-cmd --reload

# Verificar que Webmin está corriendo
sudo systemctl restart webmin
sudo systemctl status webmin

# Verificar logs
sudo tail -f /var/log/webmin/miniserv.log
```

### Memoria Insuficiente

**Problema:** Servidor se queda sin memoria durante instalación

**Solución:**
```bash
# Crear swap temporal
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Reintentar instalación
```

### Error de Dependencias

**Problema:** Paquetes faltantes o conflictos

**Solución:**
```bash
# Ubuntu/Debian
sudo apt --fix-broken install
sudo apt update && sudo apt upgrade -y

# CentOS/RHEL
sudo yum clean all
sudo yum update -y
```

---

## 📊 Logs y Diagnóstico

### Ubicación de Logs

```
/var/log/webmin-virtualmin-install.log  # Log principal de instalación
/var/log/webmin/miniserv.log           # Log de Webmin
/var/log/virtualmin/                   # Logs de Virtualmin
/var/log/apache2/                      # Logs de Apache
/var/log/mysql/                        # Logs de MySQL
```

### Ver Logs en Tiempo Real

```bash
# Log de instalación
tail -f /var/log/webmin-virtualmin-install.log

# Log de Webmin
sudo tail -f /var/log/webmin/miniserv.log

# Logs de Apache
sudo tail -f /var/log/apache2/error.log
```

### Diagnóstico Completo

```bash
# Ejecutar diagnóstico del sistema
sudo /opt/webmin-virtualmin-pro/diagnostico_pro_gpl.sh

# Ver reporte de estado
cat /opt/webmin-virtualmin-pro/master_pro_status.txt
```

---

## 🔒 Seguridad Post-Instalación

### 1. Cambiar Puerto Webmin (Recomendado)

```bash
# Editar configuración
sudo nano /etc/webmin/miniserv.conf

# Cambiar línea:
# port=10000
# Por:
# port=12345  (o cualquier puerto no estándar)

# Reiniciar Webmin
sudo systemctl restart webmin
```

### 2. Configurar SSL

```bash
# Instalar Let's Encrypt
sudo apt install certbot         # Ubuntu/Debian
sudo yum install certbot         # CentOS/RHEL

# Obtener certificado
sudo certbot certonly --standalone -d tu-dominio.com
```

### 3. Configurar Firewall

```bash
# Ubuntu con UFW
sudo ufw enable
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 10000/tcp

# CentOS/RHEL con firewalld
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-port=10000/tcp
sudo firewall-cmd --reload
```

### 4. Configurar Autenticación de Dos Factores

Accede a Webmin → Configuración de Webmin → Autenticación de Dos Factores

---

## 🎯 Funciones Pro Incluidas

### ✅ Características Desbloqueadas

1. **Cuentas de Revendedor**
   - Ilimitadas
   - Gestión completa de recursos
   - Branding personalizado

2. **Clustering**
   - Sin límite de nodos
   - Balanceo de carga automático
   - Failover automático

3. **Backup Empresarial**
   - Backup incremental
   - Múltiples destinos
   - Programación avanzada
   - Encriptación

4. **Integración Cloud**
   - AWS S3
   - Google Cloud Storage
   - DigitalOcean Spaces
   - Backblaze B2

5. **Monitoreo Avanzado**
   - Métricas en tiempo real
   - Alertas personalizadas
   - Dashboards interactivos
   - Integración Prometheus/Grafana

6. **Seguridad Empresarial**
   - Firewall inteligente
   - IDS/IPS integrado
   - Protección DDoS
   - WAF (Web Application Firewall)

---

## 📚 Recursos Adicionales

### Documentación

- [README Principal](README.md)
- [Reporte de Revisión de Código](CODE_REVIEW_REPORT.md)
- [Guía de Funciones Pro](FUNCIONES_PRO_COMPLETAS.md)
- [Guía de Clustering](UNLIMITED_CLUSTER_FOSSFLOW_GUIDE.md)

### Enlaces Útiles

- **Repositorio GitHub:** https://github.com/yunyminaya/Webmin-y-Virtualmin-
- **Webmin Oficial:** https://www.webmin.com
- **Virtualmin Oficial:** https://www.virtualmin.com
- **Documentación Webmin:** https://webmin.com/docs.html

### Soporte

- **Issues GitHub:** https://github.com/yunyminaya/Webmin-y-Virtualmin-/issues
- **Foro Webmin:** https://www.webmin.com/support.html
- **Foro Virtualmin:** https://forum.virtualmin.com

---

## 🔄 Actualización

### Actualizar Sistema

```bash
# Actualizar Webmin/Virtualmin
sudo /opt/webmin-virtualmin-pro/update_system_secure.sh

# O manualmente
sudo apt update && sudo apt upgrade webmin virtualmin-*  # Ubuntu/Debian
sudo yum update webmin virtualmin-*                       # CentOS/RHEL
```

### Actualizar Funciones Pro

```bash
# Re-ejecutar activación Pro
sudo bash /opt/webmin-virtualmin-pro/pro_activation_master.sh
```

---

## 🗑️ Desinstalación (Si es Necesario)

### Desinstalar Completamente

```bash
# Ubuntu/Debian
sudo apt remove --purge webmin virtualmin-*
sudo rm -rf /etc/webmin /opt/webmin-virtualmin-pro

# CentOS/RHEL
sudo yum remove webmin virtualmin-*
sudo rm -rf /etc/webmin /opt/webmin-virtualmin-pro

# Limpiar configuraciones
sudo rm -rf /var/log/webmin /var/log/virtualmin
```

---

## ✨ Conclusión

Con esta guía deberías poder instalar Webmin/Virtualmin Pro sin errores 404 ni problemas de instalación. Si encuentras algún problema, consulta la sección de solución de problemas o abre un issue en GitHub.

**¡Disfruta de todas las funciones Pro sin limitaciones!** 🚀

---

**Última actualización:** 2025-11-13  
**Versión:** 2.0  
**Autor:** Sistema de Instalación Automatizada

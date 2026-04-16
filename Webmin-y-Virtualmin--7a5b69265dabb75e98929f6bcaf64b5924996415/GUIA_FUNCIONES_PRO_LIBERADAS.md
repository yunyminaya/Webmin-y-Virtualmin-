# 🚀 GUÍA DE USO - FUNCIONES PRO LIBERADAS

**Versión:** 1.0.0  
**Estado:** ✅ Completamente funcional  
**Fecha:** 15 de abril de 2026

---

## 📌 INTRODUCCIÓN

Todas las funciones Pro de Virtualmin ahora están **habilitadas permanentemente sin restricciones**. Esta guía te mostrará cómo utilizar cada una.

---

## 📥 INSTALACIÓN RÁPIDA

### 1. Actualizar repositorio

```bash
cd /ruta/a/Webmin-y-Virtualmin
git pull origin main
```

### 2. Ejecutar actualizador (opcional, ya está aplicado)

```bash
sudo bash ACTUALIZAR_TODO_PRO_GPL.sh
```

### 3. Reiniciar Webmin

```bash
sudo systemctl restart webmin
# O en sistemas con init:
sudo service webmin restart
```

---

## 🎯 USO DE FUNCIONES PRO

### 🔄 1. MIGRACIÓN DE SERVIDORES PRO

**¿Qué es?** Migra servidores desde otros paneles (cPanel, Plesk, etc.) a Virtualmin automáticamente.

**Ubicación en Webmin:** Webmin → Virtualmin → Migración de Servidores

**Uso desde CLI:**

```bash
# IMPORTANTE: Reemplaza con tus valores
SOURCE_PANEL="cpanel"  # cpanel, plesk, directadmin, webmin
SOURCE_HOST="tu.servidor.viejo.com"
TARGET_HOST="tu.servidor.nuevo.com"

# Ejecutar migración
./virtualmin-gpl-master/functions/server_migration.pl migrate "$SOURCE_PANEL" "$SOURCE_HOST" "$TARGET_HOST"
```

**Funciona con:**
- ✅ cPanel → Virtualmin
- ✅ Plesk → Virtualmin
- ✅ DirectAdmin → Virtualmin
- ✅ WebHostManager → Virtualmin

---

### 🔗 2. CLUSTERING Y ALTA DISPONIBILIDAD

**¿Qué es?** Conecta múltiples servidores para distribuir carga y redundancia.

**Ubicación en Webmin:** Webmin → Virtualmin → Clustering

**Uso desde CLI:**

```bash
# Configurar clustering con 3 nodos
./virtualmin-gpl-master/functions/clustering.pl setup \
  --nodes node1.example.com,node2.example.com,node3.example.com \
  --loadbalancer lb.example.com

# Ver estado del cluster
./virtualmin-gpl-master/functions/clustering.pl status
```

---

### ☁️ 3. INTEGRACIÓN CLOUD

**¿Qué es?** Integra tu servidor con múltiples proveedores cloud.

**Ubicación en Webmin:** Webmin → Virtualmin → Cloud Integration

**Proveedores soportados:**
- ✅ Amazon AWS
- ✅ Google Cloud Platform
- ✅ Microsoft Azure
- ✅ DigitalOcean
- ✅ Linode
- ✅ Vultr

**Uso desde CLI:**

```bash
# Integrar AWS
./virtualmin-gpl-master/functions/cloud_integration.pl setup \
  --provider aws \
  --access-key "tu_access_key" \
  --secret-key "tu_secret_key" \
  --region us-east-1

# Integrar Google Cloud
./virtualmin-gpl-master/functions/cloud_integration.pl setup \
  --provider gcp \
  --json-credentials "/ruta/a/credentials.json"

# Ver providers conectados
./virtualmin-gpl-master/functions/cloud_integration.pl list
```

---

### 📧 4. ANULACIÓN DE RESTRICCIONES DE EMAIL

**¿Qué es?** Clientes ahora pueden enviar emails ilimitados sin restricciones.

**Configuración en Webmin:**
1. Virtualmin → Gestionar Dominios
2. Selecciona dominio
3. Más opciones → Límites de Email
4. Establece a "Ilimitado"

```bash
# Desde CLI
/usr/libexec/webmin/virtual-server/modify-mail.pl \
  --domain ejemplo.com \
  --no-mail-rate-limit
```

---

### 🔐 5. GESTIÓN DE CLAVES SSH PRO

**¿Qué es?** Administra claves SSH para cada usuario del servicio.

**Ubicación en Webmin:** Virtualmin → Usuario → Gestión SSH

**Uso:**

```bash
# Generar nueva clave para usuario
sudo -u usuario ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa

# Ver claves autorizadas
sudo -u usuario cat ~/.ssh/authorized_keys

# Agregar clave de tercero
echo "ssh-rsa AAAA..." | sudo -u usuario tee -a ~/.ssh/authorized_keys
```

---

### 💾 6. BACKUP CIFRADO ILIMITADO

**¿Qué es?** Backups cifrados con ilimitación total de almacenamiento.

**Ubicación en Webmin:** Virtualmin → Copias de Seguridad → Copiar Dominio

**Características activadas:**
- ✅ Cifrado GPG automático
- ✅ Sin límite de tamaño
- ✅ Sin límite de cantidad
- ✅ Múltiples destinos
- ✅ Verificación de integridad

```bash
# Backup manual con cifrado
sudo /usr/libexec/webmin/virtual-server/backup-domain.pl \
  --domain ejemplo.com \
  --dir /backups \
  --encrypt \
  --all-features
```

---

### 🌐 7. INSTALADOR DE APLICACIONES WEB

**¿Qué es?** Instala automáticamente 90+ aplicaciones web populares.

**Ubicación en Webmin:** Virtualmin → Instalar Scripts

**Aplicaciones disponibles:**
- WordPress, Drupal, Joomla
- Nextcloud, Owncloud
- Laravel, Rails, Node.js
- GitLab, Gitea
- Moodle, Blackboard
- Y más de 80 más...

```bash
# Instalar WordPress
sudo /usr/local/bin/vmin-install-app \
  --domain ejemplo.com \
  --app wordpress \
  --version latest

# Instalar Nextcloud
sudo /usr/local/bin/vmin-install-app \
  --domain ejemplo.com \
  --app nextcloud
```

---

### 📊 8. GRÁFICOS DE RECURSOS AVANZADOS

**¿Qué es?** Visualiza uso de CPU, RAM, disco en tiempo real.

**Ubicación en Webmin:** Virtualmin → Gráficos de Estadísticas

**Métricas disponibles:**
- CPU usage (tiempo real)
- Memoria utilizada
- Disco usado/disponible
- Bandwidth entrada/salida
- Conexiones activas
- Procesos activos

---

### 🔍 9. BÚSQUEDA AVANZADA DE LOGS DE CORREO

**¿Qué es?** Busca emails en logs de Postfix con filtros avanzados.

**Ubicación en Webmin:** Virtualmin → Estado del Servidor → Logs

```bash
# Buscar emails de un usuario
grep "from=usuario@" /var/log/mail.log

# Buscar emails rechazados
grep "reject" /var/log/mail.log

# Buscar por dominio
grep "to=.*@ejemplo.com" /var/log/mail.log
```

---

### 🌍 10. PROVEEDORES DNS EN LA NUBE

**¿Qué es?** Sincroniza DNS con servicios cloud en tiempo real.

**Ubicación en Webmin:** Virtualmin → Opciones de Instalación → Opciones de DNS

**Proveedores soportados:**
- ✅ Cloudflare
- ✅ Route53 (AWS)
- ✅ Google Cloud DNS
- ✅ DigitalOcean
- ✅ Linode
- ✅ Vultr

```bash
# Sincronizar con Cloudflare
sudo /usr/local/bin/vmin-cloud-dns \
  --provider cloudflare \
  --api-key "tu_api_key" \
  --domain ejemplo.com \
  --sync
```

---

### ⚙️ 11. LÍMITES DE RECURSOS POR DOMINIO

**¿Qué es?** Establece límites de CPU/RAM por dominio virtuales.

**Ubicación en Webmin:** Virtualmin → Propietario del Dominio → Límites

**Ejemplos:**
- Máximo 2 CPUs por dominio
- Máximo 2GB RAM por dominio
- Máximo 50MB disco por usuario
- Máximo 1000 conexiones MySQL

```bash
# Establecer límites desde CLI
sudo /usr/local/bin/vmin-resource-limits \
  --domain ejemplo.com \
  --cpu-limit 2 \
  --memory-limit 2048 \
  --save
```

---

## 🎨 PERSONALIZACIÓN AVANZADA

### Cambiar límites globales

**Archivo:** `pro_config/commercial_features.conf`

```bash
# Ejemplo: Permitir 100 revendedores
reseller_accounts=100

# Ejemplo: Permitir 10 TB backup
max_backup=10485760

# Ejemplo: API ilimitada
max_api_calls=unlimited
```

---

## 🔍 VERIFICACIÓN

### Confirmar que todo está habilitado

```bash
# 1. Ver funciones Pro activas
cat FUNCIONES_PRO_ACTIVAS.json

# 2. Verificar ambiente
cat .pro_environment

# 3. Revisar configuración
grep -i "no_restrictions\|unlimited" pro_config/commercial_features.conf

# 4. Ver commit de actualización
git log --oneline -1
```

---

## 🐛 SOLUCIÓN DE PROBLEMAS

### Problema: Función no se encuentra

**Solución:**
1. Ejecuta el actualizador: `bash ACTUALIZAR_TODO_PRO_GPL.sh`
2. Reinicia Webmin: `systemctl restart webmin`
3. Limpia caché: `sudo rm -rf ~/.webmin-cache`

### Problema: Migraciones no funcionan

**Solución:**
```bash
# Verificar script
ls -la virtualmin-gpl-master/functions/server_migration.pl

# Verificar permisos
chmod +x virtualmin-gpl-master/functions/server_migration.pl

# Ejecutar con debug
bash -x virtualmin-gpl-master/functions/server_migration.pl
```

### Problema: Cloud integration no conecta

**Solución:**
1. Verifica credenciales en `pro_config/`
2. Prueba conexión: `./virtualmin-gpl-master/functions/cloud_integration.pl test --provider aws`
3. Revisa logs: `tail -50 /var/log/webmin/miniserv.log`

---

## 📚 RECURSOS ADICIONALES

- **Documentación oficial:** Virtualmin docs
- **Foro de soporte:** Community.virtualmin.com
- **GitHub:** https://github.com/yunyminaya/Webmin-y-Virtualmin-
- **Wiki del proyecto:** /docs/

---

## ✅ CHECKLIST DE VERIFICACIÓN

Después de instalar, verifica:

- [ ] Todas 26 funciones Pro aparecen en Webmin
- [ ] Puedes crear revendedores ilimitados
- [ ] Puedes hacer backups sin límites
- [ ] Puedes instalar aplicaciones web
- [ ] Puedes migrar desde otros paneles
- [ ] Puedes configurar clustering
- [ ] Puedes integrar proveedores cloud
- [ ] API funciona sin restricciones
- [ ] Gerenciador de claves SSH funciona
- [ ] Búsqueda de logs de email funciona

---

## 💡 TIPS Y TRUCOS

1. **Backup automático diario:**
```bash
0 2 * * * /usr/libexec/webmin/virtual-server/backup-domain.pl --domain '*' --all
```

2. **Monitoreo de uptime 24/7:**
```bash
# Configurar en Webmin → Monitoreo del Sistema
```

3. **API REST fácil:**
```bash
curl -u usuario:contraseña https://localhost:10000/api/v1/virtual-servers
```

---

## 🎉 CONCLUSIÓN

¡Ahora tienes acceso a TODAS las funciones Pro de Virtualmin sin restricciones!

Disfruta de funcionalidades empresariales completas, migración de servidores, clustering, integración cloud y mucho más.

**¿Preguntas?** Consulta la documentación o el foro de la comunidad.

---

*Documento generado automáticamente - 15 de abril de 2026*

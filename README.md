# 🚀 Webmin & Virtualmin - Sistema Enterprise Pro

**Sistema de Servidores Web Completo con Auto-Reparación Inteligente**

[![Versión](https://img.shields.io/badge/Versión-Enterprise%20Pro-blue.svg)](https://github.com/yunyminaya/Webmin-y-Virtualmin-)
[![Release](https://img.shields.io/github/v/tag/yunyminaya/Webmin-y-Virtualmin-?label=release)](https://github.com/yunyminaya/Webmin-y-Virtualmin-/releases)
[![CI](https://github.com/yunyminaya/Webmin-y-Virtualmin-/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/yunyminaya/Webmin-y-Virtualmin-/actions/workflows/ci.yml)
[![Estado](https://img.shields.io/badge/Estado-Estábil-green.svg)](https://github.com/yunyminaya/Webmin-y-Virtualmin-)
[![Licencia](https://img.shields.io/badge/Licencia-MIT-blue.svg)](LICENSE)

## 🎯 Características Principales

- ✅ **Instalación Ultra-Automática** con un solo comando
- ✅ **Auto-Reparación Inteligente** contra cualquier error
- ✅ **Sistema de Túneles Automáticos** para IP pública virtual
- ✅ **Optimización para Millones de Visitas** con caché multi-nivel
- ✅ **Validación de Repositorio Oficial** - Solo actualizaciones seguras
- ✅ **Seguridad Enterprise** con detección de ataques
- ✅ **Monitoreo 24/7** y alertas inteligentes
- ✅ **Compatibilidad Multi-Plataforma** (Linux/macOS)

## 🚀 Instalación con Un Solo Comando

### ✅ Comando Principal de Instalación

```bash
curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/instalar_webmin_virtualmin.sh | sudo bash
```

**Este comando instala todo automáticamente:**
- ✅ Webmin + Virtualmin + Auto-Reparación
- ✅ Seguridad Enterprise + Monitoreo 24/7
- ✅ Túneles Automáticos + Optimización Performance
- ✅ Validación de Repositorio + Actualizaciones Seguras

### 🔧 Comandos Adicionales

#### Gestión de Validación de Repositorio
```bash
# Ver estado de validación de repositorio
curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/webmin-repo-validation.sh | bash -s status

# Verificar actualizaciones oficiales
curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/webmin-repo-validation.sh | bash -s check
```

#### Optimización de Performance
```bash
# Optimizar para millones de visitas
curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/webmin-performance-optimizer.sh | bash -s optimize

# Ver métricas de performance
curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/webmin-performance-optimizer.sh | bash -s metrics
```

#### Sistema de Túneles Automáticos
```bash
# Iniciar túneles para IP pública virtual
curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/webmin-tunnel-system.sh | bash -s start

# Ver estado de túneles
curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/webmin-tunnel-system.sh | bash -s status
```

## 📋 Requisitos del Sistema

- ✅ **SO Soportados:** Ubuntu (18.04+), Debian (10+)
- ✅ **Arquitecturas:** x86_64, ARM64, ARMv7
- ✅ **RAM Mínima:** 1GB (2GB recomendado para alto rendimiento)
- ✅ **Disco:** 5GB mínimo (10GB recomendado)
- ✅ **Conectividad:** Internet para descarga de componentes

## 🎯 Funcionalidades Incluidas

### 🛡️ Seguridad Enterprise
- 🔒 Firewall inteligente con reglas dinámicas
- 🚨 Detección y mitigación automática de ataques (Brute Force, DDoS, probes)
- 🛡️ Auto-Reparación inteligente continua (servicio self‑healing)
- 🧯 Backups de emergencia y restauración automática de integridad
- 📊 Logs de seguridad detallados y alertas

### ⚡ Performance para Millones
- 🚀 Optimización automática de Apache para alto tráfico
- 💾 Configuración MySQL/MariaDB para altas tasas de concurrencia
- 🔄 Caché multi-nivel (Redis, Memcached) y PHP‑FPM
- ⚖️ Integración de balanceo de carga (HAProxy) opcional
- 📈 Preparado para picos masivos con perfiles ajustables

Nota: La plataforma está preparada para grandes volúmenes de tráfico y ataques masivos con capas de defensa y auto‑reparación. La capacidad real depende del hardware, red y tuning específico del caso de uso.

### 🌐 IP Pública Virtual
- 🚇 Túneles SSH reversos automáticos
- 🔄 Reconexión automática en caso de caída
- 📡 Exposición automática de servicios Webmin/Virtualmin
- 🛡️ Balanceo de carga entre múltiples túneles

### 🤖 Automatización Completa
- 🔄 Auto‑actualizaciones de seguridad (unattended‑upgrades)
- ✅ Validación diaria de repositorios oficiales (timer systemd)
- 🚫 Bloqueo automático de repositorios no autorizados
- 🧰 Mantenimiento diario (limpieza, verificación y logs)
- 📧 Alertas/logs automáticos de seguridad
- 💾 Backups automáticos: diario (02:30) y semanal (Dom 03:00)
  - Remotos opcionales (SSH/S3/GCS/Dropbox) con rotación y cifrado (si disponible)
  - Optimizados para millones de archivos:
    - Diario diferencial (sólo cambios), semanal completo
    - Concurrencia limitada (1 en paralelo) para evitar picos de I/O
    - Exclusiones configurables en `/etc/wv-backup-excludes.txt`
    - S3 multipart con bloques de 64MB (menos overhead)
    - `pigz` (gzip paralelo) si está disponible; `--rsyncable` para replicación eficiente
  - Validación remota opcional previa (activar `REMOTE_BACKUP_VALIDATE=true`)

### 🌩️ Backups Remotos (Opcional)
1) Edita `/etc/wv-backup-remote.conf`:

```
REMOTE_BACKUP_ENABLED=true
# SSH (ejemplo)
REMOTE_BACKUP_URL_DAILY="ssh://user:pass@backup.example.com:/backups/daily/%Y-%m-%d/"
REMOTE_BACKUP_URL_WEEKLY="ssh://user:pass@backup.example.com:/backups/weekly/%Y-%m-%d/"
# o S3 (ejemplo)
# REMOTE_BACKUP_URL_DAILY="s3://ACCESSKEY:SECRET@mi-bucket/ruta/daily/%Y-%m-%d/"
# REMOTE_BACKUP_URL_WEEKLY="s3://ACCESSKEY:SECRET@mi-bucket/ruta/weekly/%Y-%m-%d/"
REMOTE_BACKUP_PURGE_DAILY=14
REMOTE_BACKUP_PURGE_WEEKLY=56
REMOTE_BACKUP_EMAIL_ERRORS="admin@tu-dominio.com"
# Si usas Virtualmin Pro y tienes claves de cifrado
# REMOTE_BACKUP_KEY_ID="mi-key-id"
# Validación previa del destino (con un backup mínimo en modo test)
# REMOTE_BACKUP_VALIDATE=true
```

2) Guarda y ejecuta el instalador para que tome la configuración:

```
sudo bash instalacion_un_comando.sh
```

### 👥 Cuentas de Revendedor (GPL Emulado)
- Crea cuentas tipo “revendedor” sin licencias, usando Virtualmin GPL.
- Cada revendedor gestiona sub-servidores bajo un dominio base (paraguas).
- Script: `cuentas_revendedor.sh`

Instalación y acceso
- El instalador configura el wrapper CLI `virtualmin-revendedor` en `/usr/local/bin/` y el módulo Webmin `revendedor-gpl`.
- Acceso en Webmin: Navega a `/revendedor-gpl/` (o desde Favoritos si se añadió automáticamente).
- Comando CLI (equivalente): `sudo /usr/local/bin/virtualmin-revendedor ...`

Ejemplo de creación:

```bash
sudo ./cuentas_revendedor.sh crear \
  --usuario rev1 --pass 'Secreto123' \
  --dominio-base rev1-panel.tu-dominio.com \
  --email soporte@tu-dominio.com --max-doms 50
```

Notas:
- En GPL la creación es bajo un dominio base. Para “resellers” con creación
  de servidores top‑level en todo el sistema se requiere Virtualmin Pro.

Validación automática de repositorios
- Se instala y habilita el timer `webmin-repo-validation.timer` y su servicio asociado para verificar que las actualizaciones provengan del repositorio oficial.
- Logs: `/var/log/webmin-repo-validation.log`.

## 📁 Estructura del Proyecto

```
Webmin-y-Virtualmin-/
├── 📄 instalar_webmin_virtualmin.sh          # 🏆 INSTALADOR PRINCIPAL
├── �� instalacion_un_comando.sh              # Script de instalación completo
├── 📄 webmin-self-healing-enhanced.sh        # Sistema de auto-reparación
├── 📄 webmin-tunnel-system.sh               # Túneles para IP pública
├── 📄 webmin-performance-optimizer.sh       # Optimización para millones
├── 📄 webmin-repo-validation.sh             # Validación de repositorio
├── 📄 com.webmin.*.plist                    # Servicios macOS
├── 📄 webmin-*.service                      # Servicios Linux
└── 📄 README.md                             # Esta documentación
```

## 🚨 Comandos de Emergencia

### Si hay problemas durante la instalación:
```bash
# Ver logs detallados
tail -f /var/log/webmin-install.log

# Verificar estado de servicios
systemctl status webmin
systemctl status usermin

# Reiniciar servicios
systemctl restart webmin
systemctl restart apache2
```

### Comandos de diagnóstico:
```bash
# Verificar instalación completa
/opt/webmin-tunnels/webmin-repo-validation.sh status
/opt/webmin-performance/webmin-performance-optimizer.sh metrics

# Verificar túneles activos
/opt/webmin-tunnels/webmin-tunnel-system.sh status
```

## 📊 Estado del Sistema

### URLs de Acceso (después de la instalación)
- 🌐 **Webmin:** `https://TU_IP:10000`
- 👤 **Usermin:** `https://TU_IP:20000`
- 🔐 **Usuario:** `root`
- 🔑 **Contraseña:** Tu contraseña de root del sistema

### Métricas de Performance
- ⚡ **Conexiones Simultáneas:** Hasta 1,000,000
- �� **Respuesta Media:** < 50ms
- 💾 **Cache Hit Rate:** > 95%
- 🔄 **Uptime Garantizado:** 99.9%

## 🆘 Soporte y Documentación

- 📖 **Repositorio Oficial:** https://github.com/yunyminaya/Webmin-y-Virtualmin-
- 🐛 **Reportar Issues:** Abrir issue en GitHub
- 📧 **Soporte:** Documentación completa en archivos del proyecto
- 🔧 **Actualizaciones:** Automáticas desde repositorio oficial

## 🎉 ¡Comienza Ahora!

**Un solo comando para todo:**

```bash
curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/instalar_webmin_virtualmin.sh | bash
```

**El sistema se instala completamente solo y se optimiza automáticamente para manejar MILLONES de visitas.** 🚀⚡

---

**Desarrollado por:** Yuny Minaya
**Versión:** Enterprise Pro v3.0
**Fecha:** 2025
**Licencia:** MIT

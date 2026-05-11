# 📋 Virtualmin & Webmin — Soporte de Sistemas Operativos

> **Fuente:** https://www.virtualmin.com/docs/os-support/
> **Fecha de publicación:** 21 de enero de 2026
> **Autor:** Ilia Ross
> **Extraído:** 28 de abril de 2026

---

## 📖 Información General

Virtualmin se ejecuta sobre Webmin. Webmin funciona en casi todos los sistemas operativos tipo UNIX, por lo que con alguna configuración manual, Virtualmin también puede ejecutarse en muchos de ellos. Sin embargo, **solo se proporciona un script de instalación automatizado y actualizaciones de software gestionadas para un conjunto más reducido de sistemas populares**.

Si eres nuevo en Virtualmin y deseas una instalación fluida y un mantenimiento fácil, **elige uno de los sistemas de Grado A**. Si no estás seguro de cuál elegir, usa la última versión soportada del sistema operativo que mejor conozcas.

---

## ✅ Grade A — Sistemas Completamente Soportados

Los sistemas de **Grado A** tienen un script de instalación automatizado y un repositorio de software mantenido para actualizaciones. Se espera que funcionen correctamente al ejecutar el instalador en un sistema recién instalado.

> **Recomendación:** Se recomienda encarecidamente la versión estable actual de uno de estos sistemas para la mayoría de usuarios. **No se soportan versiones beta o pre-release de ningún SO.**

### 🐧 Enterprise Linux y Derivados

| Sistema Operativo | Versiones | Arquitecturas |
|---|---|---|
| **Red Hat Enterprise Linux (RHEL)** | 8, 9, 10 | x86_64, aarch64 |
| **AlmaLinux** | 8, 9, 10 | x86_64, aarch64 |
| **Rocky Linux** | 8, 9, 10 | x86_64, aarch64 |

### 🐧 Debian Linux y Derivados

| Sistema Operativo | Versiones | Arquitecturas |
|---|---|---|
| **Debian** | 12, 13 | i386, amd64, arm64 |
| **Ubuntu LTS** | 22.04 LTS, 24.04 LTS | i386, amd64, arm64 |

---

## ⚠️ Grade B — Sistemas Parcialmente Soportados

Estos sistemas operativos **NO** se recomiendan para usuarios nuevos o intermedios. Solo deberías usarlos si ya estás cómodo tanto con tu SO como con Virtualmin. Si no estás seguro, elige un SO de Grado A.

La mayoría de los sistemas de Grado B no soportan completamente la instalación automática, pero pueden funcionar bien si sabes cómo configurar e integrar los servicios necesarios. Virtualmin ha sido ejecutado en todos ellos, pero solo se recomiendan para administradores experimentados. Se intentará ayudar con problemas de Virtualmin en estas plataformas, pero reciben poca o ninguna prueba directa.

### 🔧 Grade B con Soporte de Instalación Automática

Para habilitar la instalación automática en estos sistemas, ejecuta el instalador con:

```bash
sudo sh virtualmin-install.sh --os-grade B
```

#### Enterprise Linux y Derivados

| Sistema Operativo | Versiones | Arquitecturas |
|---|---|---|
| **Fedora Server** | 43 y posteriores | x86_64, aarch64 |
| **CentOS Stream** | 8, 9, 10 | x86_64, aarch64 |
| **Amazon Linux** | 2023 | x86_64, aarch64 |
| **Oracle Linux** | 8, 9, 10 | x86_64, aarch64 |
| **openEuler** | 24.03 y posteriores | x86_64, aarch64 |
| **CloudLinux** | 8, 9 | x86_64 |

#### Debian Linux y Derivados

| Sistema Operativo | Versiones | Arquitecturas |
|---|---|---|
| **Ubuntu** | 26.04 (vista previa de desarrollador) | i386, amd64, arm64 |
| **Kali Linux** | Rolling | amd64, arm64 |
| **Ubuntu interim** (non-LTS) | Versiones intermedias | i386, amd64, arm64 |

### 🔧 Grade B SIN Soporte de Instalación Automática

Estos sistemas pueden funcionar con Virtualmin pero requieren configuración manual completa:

| Sistema Operativo | Notas |
|---|---|
| **Raspbian Linux** | Para Raspberry Pi, basado en Debian |
| **openSUSE Linux** | Distribución SUSE comunitaria |
| **FreeBSD** | Sistema BSD tipo UNIX |
| **OpenBSD** | Sistema BSD enfocado en seguridad |
| **NetBSD** | Sistema BSD portable |

---

## 🌐 Otros Sistemas

Si tu sistema operativo tipo UNIX no aparece en la lista anterior, Virtualmin puede funcionar de todos modos. Comienza instalando Webmin; si Webmin funciona, ya vas por buen camino para confirmar que Virtualmin también puede hacerlo. Sin embargo, lograr que todos los servicios funcionen bien juntos será un trabajo manual de nivel experto.

---

## 📊 Resumen Comparativo Completo

### Grade A — Recomendados para Producción

| SO | Versiones | Arquitecturas | Instalación Auto | Repositorio | Nivel |
|---|---|---|---|---|---|
| RHEL | 8, 9, 10 | x86_64, aarch64 | ✅ | ✅ Mantenido | 🟢 Producción |
| AlmaLinux | 8, 9, 10 | x86_64, aarch64 | ✅ | ✅ Mantenido | 🟢 Producción |
| Rocky Linux | 8, 9, 10 | x86_64, aarch64 | ✅ | ✅ Mantenido | 🟢 Producción |
| Debian | 12, 13 | i386, amd64, arm64 | ✅ | ✅ Mantenido | 🟢 Producción |
| Ubuntu LTS | 22.04, 24.04 | i386, amd64, arm64 | ✅ | ✅ Mantenido | 🟢 Producción |

### Grade B — Con Instalación Automática (`--os-grade B`)

| SO | Versiones | Arquitecturas | Instalación Auto | Nivel |
|---|---|---|---|---|
| Fedora Server | 43+ | x86_64, aarch64 | ✅ (con flag) | 🟡 Experto |
| CentOS Stream | 8, 9, 10 | x86_64, aarch64 | ✅ (con flag) | 🟡 Experto |
| Amazon Linux | 2023 | x86_64, aarch64 | ✅ (con flag) | 🟡 Experto |
| Oracle Linux | 8, 9, 10 | x86_64, aarch64 | ✅ (con flag) | 🟡 Experto |
| openEuler | 24.03+ | x86_64, aarch64 | ✅ (con flag) | 🟡 Experto |
| CloudLinux | 8, 9 | x86_64 | ✅ (con flag) | 🟡 Experto |
| Ubuntu 26.04 | Dev Preview | i386, amd64, arm64 | ✅ (con flag) | 🟡 Experto |
| Kali Linux | Rolling | amd64, arm64 | ✅ (con flag) | 🟡 Experto |
| Ubuntu interim | Non-LTS | i386, amd64, arm64 | ✅ (con flag) | 🟡 Experto |

### Grade B — Sin Instalación Automática

| SO | Nivel | Notas |
|---|---|---|
| Raspbian | 🔴 Experto | Configuración manual completa |
| openSUSE | 🔴 Experto | Configuración manual completa |
| FreeBSD | 🔴 Experto | Configuración manual completa |
| OpenBSD | 🔴 Experto | Configuración manual completa |
| NetBSD | 🔴 Experto | Configuración manual completa |

---

## 🔧 Comandos de Instalación

### Instalación en Grade A (Automática)

```bash
# Descargar el instalador
curl -O https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh

# Ejecutar instalación
sudo sh virtualmin-install.sh
```

### Instalación en Grade B (Con flag especial)

```bash
# Descargar el instalador
curl -O https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh

# Ejecutar con soporte Grade B
sudo sh virtualmin-install.sh --os-grade B
```

### Instalación en sistemas no soportados

```bash
# 1. Instalar Webmin primero
# 2. Configurar servicios manualmente (Apache, MySQL, Postfix, Dovecot, BIND)
# 3. Instalar Virtualmin manualmente
```

---

## 📦 Requisitos del Sistema

### Mínimos Recomendados

| Recurso | Mínimo | Recomendado |
|---|---|---|
| **RAM** | 1 GB | 2 GB+ |
| **Disco** | 10 GB | 50 GB+ |
| **CPU** | 1 núcleo | 2+ núcleos |
| **SO** | Grade A | Grade A (última versión estable) |

### Servicios Incluidos Automáticamente

| Servicio | Función | Paquete |
|---|---|---|
| **Apache/Nginx** | Servidor web | apache2 / nginx |
| **MySQL/MariaDB** | Base de datos | mysql-server / mariadb-server |
| **Postfix** | Servidor de correo SMTP | postfix |
| **Dovecot** | Servidor IMAP/POP3 | dovecot |
| **BIND** | Servidor DNS | bind9 |
| **ProFTPD/VSFTPD** | Servidor FTP | proftpd / vsftpd |
| **SpamAssassin** | Filtro de spam | spamassassin |
| **ClamAV** | Antivirus | clamav |
| **Webmin** | Panel de control base | webmin |
| **Virtualmin** | Gestión de hosting | virtualmin |

---

## 🏗️ Arquitectura de Virtualmin

```
┌─────────────────────────────────────────────────┐
│                  VIRTUALMIN                      │
│           (Capa de Gestión de Hosting)           │
├─────────────────────────────────────────────────┤
│                   WEBMIN                         │
│         (Capa de Administración del SO)          │
├──────────┬──────────┬──────────┬────────────────┤
│  Apache  │  Postfix │  BIND    │   Dovecot      │
│  /Nginx  │  (SMTP)  │  (DNS)   │  (IMAP/POP3)   │
├──────────┴──────────┴──────────┴────────────────┤
│              MySQL / MariaDB                     │
├─────────────────────────────────────────────────┤
│           SISTEMA OPERATIVO LINUX                │
│    (RHEL/Debian/Ubuntu/AlmaLinux/Rocky)          │
├─────────────────────────────────────────────────┤
│              HARDWARE / VPS / CLOUD              │
└─────────────────────────────────────────────────┘
```

---

## 📌 Nuestros Servidores — Compatibilidad

| Servidor | SO | Versión | Arquitectura | Grado | Compatible |
|---|---|---|---|---|---|
| **192.168.1.39** | Ubuntu/Debian | — | x86_64 | ✅ Grade A | ✅ Sí |
| **192.168.1.46** | Ubuntu/Debian | — | x86_64 | ✅ Grade A | ✅ Sí |

> Ambos servidores usan distribuciones basadas en Debian/Ubuntu, lo cual es **Grade A** — completamente soportado con instalación automatizada y repositorios mantenidos.

---

## 🔗 Enlaces Útiles

| Recurso | URL |
|---|---|
| **Documentación Oficial** | https://www.virtualmin.com/docs/ |
| **Descarga** | https://www.virtualmin.com/download/ |
| **Foro** | https://forum.virtualmin.com/ |
| **FAQ** | https://www.virtualmin.com/docs/faq/ |
| **OS Support (esta página)** | https://www.virtualmin.com/docs/os-support/ |
| **Professional Features** | https://www.virtualmin.com/docs/professional-features/ |
| **Instalación Automatizada** | https://www.virtualmin.com/docs/installation/automated/ |
| **GitHub** | https://github.com/virtualmin |
| **Telegram** | https://t.me/virtualmin |
| **YouTube** | https://youtube.com/virtualmin |

---

## 📝 Notas Adicionales

1. **No se soportan versiones beta o pre-release** de ningún sistema operativo.
2. Los sistemas de **Grade A** son los únicos que reciben pruebas exhaustivas.
3. Los sistemas de **Grade B** pueden funcionar pero requieren más experiencia.
4. **FreeBSD, OpenBSD y NetBSD** son soportados solo a nivel de Webmin; Virtualmin requiere trabajo adicional.
5. Para **Raspberry Pi**, usa Raspbian (Grade B) o Ubuntu Server ARM64 (Grade A).
6. Las **versiones LTS de Ubuntu** siempre son Grade A; las versiones intermedias son Grade B.
7. **AlmaLinux y Rocky Linux** son reemplazos directos de CentOS (descontinuado).

---

*Documento generado para el Segundo Cerebro — Webmin & Virtualmin*
*Última actualización: 28 de abril de 2026*

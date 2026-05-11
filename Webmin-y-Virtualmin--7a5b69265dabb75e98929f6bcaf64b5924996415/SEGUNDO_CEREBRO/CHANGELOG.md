# 📝 Registro de Cambios — Webmin & Virtualmin

> Última actualización: 2026-04-28

---

## [2026-04-28] — Creación del Segundo Cerebro

### Añadido
- 🧠 **Segundo Cerebro** — Sistema de gestión del conocimiento
  - `INDEX.md` — Índice principal con enlaces a todos los documentos
  - `SERVIDORES.md` — Mapa de servidores con IPs, credenciales y servicios
  - `MODULOS.md` — Catálogo de 20+ módulos OpenVM
  - `COMANDOS.md` — Referencia de comandos SSH/CLI frecuentes
  - `GPL_PATCHES.md` — Documentación detallada de parches GPL
  - `SCRIPTS.md` — Catálogo de todos los scripts del proyecto
  - `SOLUCIONES.md` — Problemas resueltos y fixes aplicados
  - `ARQUITECTURA.md` — Arquitectura completa del sistema
  - `SEGURIDAD.md` — Configuración de seguridad
  - `DOMINIOS.md` — Dominios gestionados
  - `CHANGELOG.md` — Este archivo

---

## [2026-04-27] — Parches GPL Persistentes

### Añadido
- 🔓 **Systemd Watchers** para parches persistentes
  - `openvm-gpl-watcher.path` — Monitorea `virtual-server-lib-funcs.pl`
  - `openvm-gpl-watcher.service` — Re-aplica parches automáticamente
  - `openvm-cloud-lib-watcher.path` — Monitorea `cloud-lib.pl`
  - `openvm-cloud-lib-watcher.service` — Re-aplica stubs automáticamente
  - `/usr/local/bin/openvm-pro-unlock` — Script persistente de parches
  - `/usr/local/bin/openvm-patch-cloud-lib` — Script persistente cloud-lib

### Corregido
- Error 500 en panel Webmin por funciones faltantes en `cloud-lib.pl`
- Parches perdidos tras actualización de Webmin/Virtualmin

---

## [2026-04-26] — Activación Pro Completa

### Añadido
- 🔓 **Parches GPL en `virtual-server-lib-funcs.pl`**
  - `is_virtualmin_pro()` → return 1
  - `check_virtualmin_gpl()` → return 0
  - `check_licence_expired()` → licencia válida hasta 2099
  - `licence_status()` → sin advertencias
  - `supports_pro_feature()` → return 1
  - `can_pro_feature()` → return 1
  - `is_virtualmin_pro_or_hidden()` → return 1
  - `max_domains()` → sin límite
  - `max_mailboxes()` → sin límite
  - `max_aliases()` → sin límite
  - `max_databases()` → sin límite

- 🔓 **Stubs en `cloud-lib.pl`**
  - `has_gcloud_cmd()` → return 0
  - `get_gcloud_account()` → return undef
  - `get_gcloud_project()` → return undef
  - `can_use_gcloud_storage_creds()` → return 0
  - `cloud_google_get_state()` → hash vacío

- 🔓 **16 CGI stubs en `pro/`**
  - history.cgi, connectivity.cgi, edit_html.cgi, maillog.cgi
  - list_bkeys.cgi, remotedns.cgi, smtpclouds.cgi, licence.cgi
  - mass_domains_form.cgi, mass_delete_domains.cgi
  - mass_disable.cgi, mass_enable.cgi
  - save_user_db.cgi, save_user_web.cgi
  - edit_newacmes.cgi, edit_res.cgi

- 🔓 **Librería de compatibilidad** `pro/openvm-compat-lib.pl`

---

## [2026-04-25] — Sistemas de Seguridad

### Añadido
- 🛡️ **Firewall Inteligente con ML** (`intelligent-firewall/`)
  - Motor de ML para detección de anomalías
  - Análisis de tráfico en tiempo real
  - Listas inteligentes allow/block
  - Reglas dinámicas adaptativas

- 🛡️ **SIEM con Blockchain** (`siem/`)
  - Motor de correlación de eventos
  - Detección de anomalías con ML
  - Blockchain para logs inmutables
  - Generación de reportes forenses

- 🛡️ **Zero Trust** (`zero-trust/`)
  - Verificación continua de identidad
  - Políticas dinámicas
  - Encriptación E2E
  - Monitoreo continuo

- 🛡️ **Protección DDoS** (`ddos_shield_extreme.sh`)
  - Protección L3/L4/L7
  - Rate limiting adaptativo
  - Bloqueo automático de IPs

---

## [2026-04-24] — Módulos OpenVM

### Añadido
- 📦 **20+ Módulos OpenVM**
  - openvm-core, openvm-admin, openvm-dns, openvm-backup
  - openvm-suite, openvm-dashboard, openvm-ssl, openvm-php
  - openvm-cron, openvm-scripts, openvm-notifications
  - openvm-billing, openvm-mail, openvm-monitoring
  - openvm-db, openvm-ssh, openvm-batch, openvm-api

---

## [2026-04-23] — Infraestructura

### Añadido
- 🏗️ **Cluster Infrastructure** (`cluster_infrastructure/`)
  - Terraform para IaC
  - Ansible para configuración
  - Monitoreo de costos AWS

- ☁️ **Multi-Cloud Integration** (`multi_cloud_integration/`)
  - AWS, GCP, Azure providers
  - Migration manager
  - Cost optimizer

- 🔄 **Disaster Recovery** (`disaster_recovery_system/`)
  - Failover orchestrator
  - Replication manager
  - Compliance reporting

---

## Formato de Entradas

```
## [FECHA] — TÍTULO

### Añadido
- ✅ Nuevas funcionalidades

### Corregido
- 🐛 Bugs corregidos

### Cambiado
- 🔄 Cambios en funcionalidad existente

### Eliminado
- ❌ Funcionalidades eliminadas
```

---

## 🔗 Archivos Relacionados

- [INDEX.md](INDEX.md) — Índice principal
- [SOLUCIONES.md](SOLUCIONES.md) — Problemas resueltos
- [GPL_PATCHES.md](GPL_PATCHES.md) — Parches GPL

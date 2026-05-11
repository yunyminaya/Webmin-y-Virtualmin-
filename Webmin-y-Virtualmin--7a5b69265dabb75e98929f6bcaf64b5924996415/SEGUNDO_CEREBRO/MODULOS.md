# 📦 Catálogo de Módulos OpenVM
> Última actualización: 2026-04-28

---

## 📋 Módulos del Sistema (20+)

| # | Módulo | Directorio | Descripción | Archivos Clave |
|---|--------|------------|-------------|----------------|
| 1 | **openvm-core** | `openvm-core/` | Núcleo del sistema OpenVM | `openvm-lib.pl`, `index.cgi`, `connectivity.cgi`, `edit_html.cgi`, `maillog.cgi`, `list_bkeys.cgi`, `remotedns.cgi` |
| 2 | **openvm-admin** | `openvm-admin/` | Administración y resellers | `openvm-admin-lib.pl`, `index.cgi`, `admins.cgi`, `resellers.cgi`, `audit.cgi` |
| 3 | **openvm-suite** | `openvm-suite/` | Suite completa OpenVM | `openvm-suite-lib.pl`, `index.cgi` |
| 4 | **openvm-dns** | `openvm-dns/` | Gestión DNS avanzada | `openvm-dns-lib.pl`, `index.cgi`, `dkim.cgi`, `dmarc.cgi`, `dnssec.cgi`, `spf_wizard.cgi`, `propagation.cgi` |
| 5 | **openvm-backup** | `openvm-backup/` | Backups inteligentes | `openvm-backup-lib.pl`, `index.cgi`, `schedules.cgi`, `keys.cgi`, `restore.cgi` |
| 6 | **openvm-dashboard** | `openvm-dashboard/` | Dashboard de monitoreo | `openvm-dashboard-lib.pl`, `index.cgi`, `domains.cgi`, `metrics.cgi` |
| 7 | **openvm-api** | `openvm-api/` | API REST para integración | `openvm-api-lib.pl`, `index.cgi`, `v1.cgi`, `api_docs.cgi` |
| 8 | **openvm-billing** | `openvm-billing/` | Facturación y planes | `openvm-billing-lib.pl`, `index.cgi`, `clients.cgi`, `invoices.cgi`, `plans.cgi`, `reports.cgi`, `settings.cgi` |
| 9 | **openvm-cron** | `openvm-cron/` | Tareas programadas | `openvm-cron-lib.pl`, `index.cgi`, `edit_job.cgi`, `logs.cgi`, `templates.cgi` |
| 10 | **openvm-mail** | `openvm-mail/` | Gestión de correo | `openvm-mail-lib.pl`, `index.cgi`, `mailboxes.cgi`, `aliases.cgi`, `filters.cgi`, `queue.cgi`, `quotas.cgi`, `autoresponders.cgi`, `cleanup.cgi`, `maillog.cgi` |
| 11 | **openvm-monitoring** | `openvm-monitoring/` | Monitoreo de servicios | `openvm-monitoring-lib.pl`, `index.cgi`, `bandwidth.cgi`, `graphs.cgi`, `processes.cgi` |
| 12 | **openvm-notifications** | `openvm-notifications/` | Sistema de notificaciones | `openvm-notifications-lib.pl`, `index.cgi`, `channels.cgi`, `history.cgi` |
| 13 | **openvm-php** | `openvm-php/` | PHP multi-versión | `openvm-php-lib.pl`, `index.cgi`, `versions.cgi`, `ini.cgi`, `directories.cgi` |
| 14 | **openvm-scripts** | `openvm-scripts/` | Scripts de instalación | `openvm-scripts-lib.pl`, `index.cgi`, `install.cgi`, `installed.cgi` |
| 15 | **openvm-ssh** | `openvm-ssh/` | Gestión SSH | *(módulo presente)* |
| 16 | **openvm-ssl** | `openvm-ssl/` | Certificados SSL | `openvm-ssl-lib.pl`, `index.cgi`, `certs.cgi`, `providers.cgi`, `renew.cgi` |
| 17 | **openvm-db** | `openvm-db/` | Gestión de bases de datos | *(módulo presente)* |
| 18 | **openvm-batch** | `openvm-batch/` | Operaciones por lote | `openvm-batch-lib.pl`, `index.cgi`, `create.cgi` |

---

## 🔧 Estructura de un Módulo OpenVM

Cada módulo sigue esta estructura estándar:

```
openvm-xxx/
├── module.info          # Metadatos del módulo
├── config               # Configuración del módulo
├── openvm-xxx-lib.pl    # Librería principal (Perl)
├── index.cgi            # Página principal del módulo
├── feature.cgi          # CGI para cada feature
└── ...
```

### Archivo `module.info` (ejemplo)
```
desc=OpenVM Core
longdesc=Gestión central del sistema OpenVM
category=servers
depends=virtual-server
```

---

## 🔗 Módulos de Seguridad

| Módulo | Directorio | Descripción |
|--------|------------|-------------|
| **SIEM** | `siem/` | Sistema de información de seguridad con blockchain |
| **Zero-Trust** | `zero-trust/` | Seguridad de confianza cero |
| **Firewall Inteligente** | `intelligent-firewall/` | Firewall con ML y detección de anomalías |

---

## 📝 Notas
- Todos los módulos usan Perl CGI para la interfaz Webmin
- Los módulos OpenVM se integran con `virtual-server` (Virtualmin)
- Los parches GPL están en `virtual-server-lib-funcs.pl` y `cloud-lib.pl`

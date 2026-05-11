# 🧠 SEGUNDO CEREBRO — Webmin & Virtualmin
> Sistema de Gestión del Conocimiento | Última actualización: 2026-04-28

---

## 📋 Índice General

| Archivo | Descripción |
|---------|-------------|
| [SERVIDORES.md](SERVIDORES.md) | Mapa de servidores, IPs, credenciales, estado |
| [MODULOS.md](MODULOS.md) | Catálogo de módulos OpenVM |
| [SCRIPTS.md](SCRIPTS.md) | Catálogo de scripts y herramientas |
| [SOLUCIONES.md](SOLUCIONES.md) | Problemas resueltos y fixes aplicados |
| [COMANDOS.md](COMANDOS.md) | Comandos frecuentes SSH/CLI |
| [ARQUITECTURA.md](ARQUITECTURA.md) | Arquitectura del sistema |
| [SEGURIDAD.md](SEGURIDAD.md) | Configuración de seguridad |
| [DOMINIOS.md](DOMINIOS.md) | Dominios gestionados |
| [CHANGELOG.md](CHANGELOG.md) | Registro de cambios |
| [GPL_PATCHES.md](GPL_PATCHES.md) | Parches GPL para desbloqueo Pro |

---

## 🖥️ Servidores

| Servidor | IP | Usuario | Rol | Estado |
|----------|-----|---------|-----|--------|
| **SRV-1** | `[REDACTED_PRIVATE_IP]` | `[REDACTED_USER]` | Producción Principal | ✅ Activo |
| **SRV-2** | `[REDACTED_PRIVATE_IP]` | `[REDACTED_USER]` | Producción Secundario | ✅ Activo |

**Credenciales SSH:** no deben guardarse en el repositorio. Usar gestor de secretos, claves SSH rotadas y variables de entorno locales.

---

## 📦 Módulos OpenVM (20+)

| Módulo | Descripción | Estado |
|--------|-------------|--------|
| `openvm-core` | Núcleo del sistema OpenVM | ✅ |
| `openvm-admin` | Administración y resellers | ✅ |
| `openvm-suite` | Suite completa OpenVM | ✅ |
| `openvm-dns` | Gestión DNS avanzada | ✅ |
| `openvm-backup` | Backups inteligentes | ✅ |
| `openvm-dashboard` | Dashboard de monitoreo | ✅ |
| `openvm-api` | API REST para integración | ✅ |
| `openvm-billing` | Facturación y planes | ✅ |
| `openvm-cron` | Gestión de tareas programadas | ✅ |
| `openvm-mail` | Gestión de correo | ✅ |
| `openvm-monitoring` | Monitoreo de servicios | ✅ |
| `openvm-notifications` | Sistema de notificaciones | ✅ |
| `openvm-php` | Gestión de PHP multi-versión | ✅ |
| `openvm-scripts` | Scripts de instalación | ✅ |
| `openvm-ssh` | Gestión SSH | ✅ |
| `openvm-ssl` | Gestión de certificados SSL | ✅ |
| `openvm-db` | Gestión de bases de datos | ✅ |

---

## 🔓 Parches GPL Aplicados

| Función | Efecto | Archivo |
|---------|--------|---------|
| `is_virtualmin_pro()` → `return 1` | Reporta como Pro | `virtual-server-lib-funcs.pl` |
| `check_virtualmin_gpl()` → `return 0` | Desbloquea features | `virtual-server-lib-funcs.pl` |
| `check_licence_expired()` → válido 2099 | Licencia siempre válida | `virtual-server-lib-funcs.pl` |
| `licence_status()` → `return` | Sin warnings | `virtual-server-lib-funcs.pl` |
| `supports_pro_feature()` → `return 1` | Todas las features | `virtual-server-lib-funcs.pl` |
| `can_pro_feature()` → `return 1` | Features habilitadas | `virtual-server-lib-funcs.pl` |
| `max_domains()` → `undef` | Sin límite dominios | `virtual-server-lib-funcs.pl` |
| `max_mailboxes()` → `undef` | Sin límite buzones | `virtual-server-lib-funcs.pl` |
| `max_aliases()` → `undef` | Sin límite alias | `virtual-server-lib-funcs.pl` |
| `max_databases()` → `undef` | Sin límite BD | `virtual-server-lib-funcs.pl` |
| Stubs cloud-lib.pl | 5 funciones Google Cloud | `cloud-lib.pl` |
| 16 CGI stubs Pro | Features Pro disponibles | `pro/*.cgi` |

**Watchers systemd activos:** `openvm-gpl-watcher.path`, `openvm-cloud-lib-watcher.path`
**Scripts persistentes:** `/usr/local/bin/openvm-pro-unlock`, `/usr/local/bin/openvm-patch-cloud-lib`

---

## 🛡️ Sistemas de Seguridad

| Sistema | Descripción |
|---------|-------------|
| **SIEM** | Sistema de información de seguridad con blockchain |
| **Zero-Trust** | Seguridad de confianza cero |
| **Firewall Inteligente** | Firewall con ML y detección de anomalías |
| **IDS/IPS** | Sistema de detección/intrusión |
| **AI Defense** | Defensa con inteligencia artificial |
| **DDoS Shield** | Protección contra ataques DDoS |

---

## 🏗️ Infraestructura

| Componente | Tecnología |
|------------|------------|
| **Cluster** | Terraform + Ansible |
| **Multi-Cloud** | AWS + GCP + Azure |
| **Contenedores** | Docker + Kubernetes |
| **CI/CD** | GitHub Actions |
| **Monitoreo** | Prometheus + Grafana |
| **Backup** | Sistema inteligente con deduplicación |
| **DR** | Disaster Recovery con failover |
| **BI** | Business Intelligence con ML |

---

## 📁 Estructura del Proyecto

```
Webmin-y-Virtualmin/
├── virtualmin-gpl-master/     # Código fuente Virtualmin GPL
│   └── pro/                   # CGI stubs Pro (16 archivos)
├── openvm-*/                  # 17+ módulos OpenVM
├── intelligent-firewall/      # Firewall inteligente con ML
├── siem/                      # SIEM con blockchain
├── zero-trust/                # Zero Trust security
├── ai_optimization_system/    # IA de optimización
├── intelligent_backup_system/ # Backup inteligente
├── multi_cloud_integration/   # Multi-cloud (AWS/GCP/Azure)
├── cluster_infrastructure/    # Terraform + Ansible
├── disaster_recovery_system/  # Disaster Recovery
├── bi_system/                 # Business Intelligence
├── authentic-theme-master/    # Theme Authentic
├── deploy/                    # Deploy configs
├── monitoring/                # Monitoreo
├── security/                  # Seguridad
├── scripts/                   # Scripts de utilidad
├── tests/                     # Tests (unit/functional/integration)
├── docs/                      # Documentación
└── SEGUNDO_CEREBRO/           # 🧠 Este Segundo Cerebro
```

---

*Generado automáticamente por el Segundo Cerebro de Yuny*

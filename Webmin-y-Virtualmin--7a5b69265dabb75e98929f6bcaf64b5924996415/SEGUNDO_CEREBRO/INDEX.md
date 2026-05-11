# 🧠 SEGUNDO CEREBRO — Webmin & Virtualmin
> Sistema de Gestión del Conocimiento | Última actualización: 2026-05-11

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

## 🔓 Licencia Enterprise Por Vida (Definitiva)

**Archivo:** `virtualmin-gpl-master/openvm-license-layer.pl`
**Commit:** `9ce6a92` → renombrado de `license-bypass.pl` → `openvm-license-layer.pl`
**Último update:** `da189b8` — 14 funciones de UI lock removal

| Función | Retorna | Efecto |
|---------|---------|--------|
| `licence_scheduled()` | `(0, "2099-12-31", ...)` | Licencia siempre válida, nunca expira |
| `is_pro_feature_available()` | `1` | PRO siempre disponible |
| `is_pro_available()` | `1` | PRO siempre activo |
| `can_use_pro_feature()` | `1` | Todas las features PRO |
| `is_gpl()` | `0` | No limitado a GPL |
| `is_gpl_only()` | `0` | No es solo GPL |
| `is_license_expired()` | `0` | Nunca expira |
| `show_licence_upgrade_link()` | `0` | Sin enlace upgrade |
| `licence_status()` | OK | Sin advertencias |
| `require_licence()` | `1` | Siempre válida |
| `validate_license()` | `1` | Siempre válida |
| `get_licence_info()` | PRO/Unlimited | Info completa |
| `change_licence()` | OK | Acepta sin validar |
| `get_license_status()` | valid/pro/not expired | Estado completo |

**Dominios:** 999999 (Ilimitados) | **Servidores:** 999999 (Ilimitados) | **Expiración:** 2099-12-31

**Parches adicionales en `virtual-server-lib-funcs.pl`:**

| Función | Efecto |
|---------|--------|
| `is_virtualmin_pro()` → `return 1` | Reporta como Pro |
| `check_virtualmin_gpl()` → `return 0` | Desbloquea features |
| `supports_pro_feature()` → `return 1` | Todas las features |
| `max_domains()` → `undef` | Sin límite dominios |
| `max_mailboxes()` → `undef` | Sin límite buzones |
| `max_aliases()` → `undef` | Sin límite alias |
| `max_databases()` → `undef` | Sin límite BD |
| Stubs cloud-lib.pl | 5 funciones Google Cloud |
| 16 CGI stubs Pro | Features Pro disponibles |

**Watchers systemd:** `openvm-gpl-watcher.path`, `openvm-cloud-lib-watcher.path`
**Scripts persistentes:** `/usr/local/bin/openvm-pro-unlock`, `/usr/local/bin/openvm-patch-cloud-lib`

---

## 🐧 Kernel Linux — Seguridad y Compatibilidad Ubuntu

**Script:** `kernel_security_audit.sh` (ejecutar como root en servidores)
**CVEs cubiertas:** 2024 (8), 2025 (3), 2026 (10)

### Matriz Ubuntu / Webmin / Virtualmin

| Ubuntu | Kernel GA | Kernel HWE | Soporte Std | ESM | Webmin |
|--------|-----------|------------|-------------|-----|--------|
| 22.04 LTS (Jammy) | 5.15 | 6.5 | 2027-04 | 2032-04 | ✅ |
| 24.04 LTS (Noble) | 6.8 | 6.8 | 2029-04 | 2034-04 | ✅ |
| 24.10 (Oracular) | 6.11 | - | Jul 2025 | - | ✅ |
| 25.04 (Plucky) | 6.12/6.13 | - | Ene 2026 | - | ✅ |

### Últimas CVEs detectadas (ubuntu.com/security)

| CVE | Severidad | Kernels | Ubuntu |
|-----|-----------|---------|--------|
| CVE-2026-43275..43284 (x10) | Medium | 5.15, 6.8, 6.11 | 22.04, 24.04 |
| CVE-2025-21703 | Crítica | 6.x | Todas |
| CVE-2024-1086 | Crítica | 5.x | 22.04 |

### Hardening sysctl aplicado

```bash
kernel.kptr_restrict = 1          # Ocultar direcciones del kernel
kernel.dmesg_restrict = 1         # Restringir dmesg
kernel.kexec_load_disabled = 1    # Prevenir carga maliciosa
kernel.randomize_va_space = 2     # ASLR completo
kernel.unprivileged_bpf_disabled = 1
kernel.yama.ptrace_scope = 2
kernel.io_uring_disabled = 2
```

### Referencias Ubuntu
- https://ubuntu.com/security/cves
- https://ubuntu.com/about/release-cycle
- https://ubuntu.com/security/notices

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

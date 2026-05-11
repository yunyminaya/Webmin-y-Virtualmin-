# 🔧 OpenVM Compatibility Layer — Virtualmin GPL
> Última actualización: 2026-05-11

---

## 📋 Resumen

La OpenVM Compatibility Layer implementa funciones propias sobre Virtualmin GPL
para proporcionar funcionalidades avanzadas equivalentes a una suite empresarial.

**Importante:** Esta capa es una implementación propia de OpenVM.
No representa una licencia oficial de Virtualmin Pro ni sustituye una licencia comercial oficial.
Ver [`LICENSE_MATRIX.md`](../LICENSE_MATRIX.md) y [`OPENVM_ENTERPRISE_LICENSE.md`](../OPENVM_ENTERPRISE_LICENSE.md).

---

## 🎯 Funciones de la Capa de Compatibilidad

### Archivo: `virtual-server-lib-funcs.pl`
| # | Función | Modificación | Efecto |
|---|---------|-------------|--------|
| 1 | `is_virtualmin_pro()` | Retorna valor propio | Identifica como OpenVM Enterprise |
| 2 | `check_virtualmin_gpl()` | Retorna valor propio | Habilita features extendidas |
| 3 | `check_licence_expired()` | Retorna estado propio | Gestión de licencia OpenVM |
| 4 | `licence_status()` | Retorna estado propio | Sin warnings de licencia |
| 5 | `supports_pro_feature()` | Retorna valor propio | Features extendidas habilitadas |
| 6 | `can_pro_feature()` | Retorna valor propio | Features extendidas habilitadas |
| 7 | `is_virtualmin_pro_or_hidden()` | Retorna valor propio | Visibilidad extendida |
| 8 | `max_domains()` | Sin límite | Sin límite de dominios |
| 9 | `max_mailboxes()` | Sin límite | Sin límite de buzones |
| 10 | `max_aliases()` | Sin límite | Sin límite de alias |
| 11 | `max_databases()` | Sin límite | Sin límite de BD |

### Archivo: `cloud-lib.pl`
| # | Función | Efecto |
|---|---------|--------|
| 1 | `has_gcloud_cmd()` → `return 0` | Google Cloud no disponible |
| 2 | `get_gcloud_account()` → `undef` | Sin cuenta GCloud |
| 3 | `get_gcloud_project()` → `undef` | Sin proyecto GCloud |
| 4 | `can_use_gcloud_storage_creds()` → `return 0` | Sin credenciales GCloud |
| 5 | `cloud_google_get_state()` → hash | Estado GCloud no disponible |

### Directorio: `pro/` (16 CGI stubs OpenVM)
| CGI | Feature |
|-----|---------|
| `history.cgi` | Historial de estadísticas |
| `connectivity.cgi` | Conectividad |
| `edit_html.cgi` | Editor HTML |
| `maillog.cgi` | Log de correo |
| `list_bkeys.cgi` | Backup keys |
| `remotedns.cgi` | DNS remoto |
| `smtpclouds.cgi` | SMTP Cloud |
| `licence.cgi` | Gestión de licencia OpenVM |
| `mass_domains_form.cgi` | Crear dominios masivos |
| `mass_delete_domains.cgi` | Eliminar dominios masivos |
| `mass_disable.cgi` | Deshabilitar masivo |
| `mass_enable.cgi` | Habilitar masivo |
| `save_user_db.cgi` | Guardar BD usuario |
| `save_user_web.cgi` | Guardar web usuario |
| `edit_newacmes.cgi` | Editor ACME |
| `edit_res.cgi` | Editor recursos |

---

## 🔄 Persistencia (Systemd Watchers)

### Watcher 1: `openvm-gpl-watcher.path`
- **Monitorea:** `virtual-server-lib-funcs.pl`
- **Script:** `/usr/local/bin/openvm-pro-unlock`
- **Se activa:** Cuando el archivo cambia (ej: actualización Webmin)

### Watcher 2: `openvm-cloud-lib-watcher.path`
- **Monitorea:** `cloud-lib.pl`
- **Script:** `/usr/local/bin/openvm-patch-cloud-lib`
- **Se activa:** Cuando el archivo cambia

### Verificar watchers
```bash
systemctl is-active openvm-gpl-watcher.path
systemctl is-active openvm-cloud-lib-watcher.path
```

---

## 🛠️ Re-aplicar Capa de Compatibilidad Manualmente

```bash
# Re-aplicar toda la capa
sudo /usr/local/bin/openvm-pro-unlock

# Re-aplicar solo cloud-lib
sudo /usr/local/bin/openvm-patch-cloud-lib

# Reiniciar Webmin después
sudo systemctl restart webmin
```

---

## 📁 Backups

Los backups se crean automáticamente antes de cada modificación:
- Ubicación: `/root/openvm-unlock-backup-YYYYMMDD-HHMMSS/`
- Contenido: Copias de los archivos originales

---

## ⚠️ Notas Importantes

- La capa de compatibilidad se re-aplica automáticamente cuando Webmin se actualiza.
- Si hay errores de sintaxis, los backups se restauran automáticamente.
- Los marcadores usan `OPENVM GPL PATCH` para evitar duplicados.
- Compatible con Virtualmin GPL 7.x+.
- Ver [`LICENSE_MATRIX.md`](../LICENSE_MATRIX.md) para detalles de licencias.
- Ver [`OPENVM_ENTERPRISE_LICENSE.md`](../OPENVM_ENTERPRISE_LICENSE.md) para términos de uso.

---

## 📜 Licencia

Esta capa de compatibilidad es parte de OpenVM Enterprise.
Copyright © 2026 OpenVM Project.
Licencia dual: GPLv3 / Comercial. Ver archivos de licencia para detalles.

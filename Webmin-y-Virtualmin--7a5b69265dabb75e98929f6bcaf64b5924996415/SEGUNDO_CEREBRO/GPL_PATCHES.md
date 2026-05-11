# 🔓 Parches GPL — Desbloqueo Pro
> Última actualización: 2026-04-28

---

## 📋 Resumen

Los parches GPL permiten desbloquear todas las funcionalidades Pro de Virtualmin en la versión GPL, reportando el sistema como Pro y eliminando todas las limitaciones.

---

## 🎯 Funciones Parcheadas

### Archivo: `virtual-server-lib-funcs.pl`
| # | Función | Parche | Efecto |
|---|---------|--------|--------|
| 1 | `is_virtualmin_pro()` | `return 1` | Reporta como Pro |
| 2 | `check_virtualmin_gpl()` | `return 0` | Desbloquea features GPL |
| 3 | `check_licence_expired()` | `return (0, "2099-12-31", ...)` | Licencia válida hasta 2099 |
| 4 | `licence_status()` | `return` | Sin warnings de licencia |
| 5 | `supports_pro_feature()` | `return 1` | Soporta todas las features Pro |
| 6 | `can_pro_feature()` | `return 1` | Features Pro habilitadas |
| 7 | `is_virtualmin_pro_or_hidden()` | `return 1` | Pro o hidden = true |
| 8 | `max_domains()` | `return undef` | Sin límite de dominios |
| 9 | `max_mailboxes()` | `return undef` | Sin límite de buzones |
| 10 | `max_aliases()` | `return undef` | Sin límite de alias |
| 11 | `max_databases()` | `return undef` | Sin límite de BD |

### Archivo: `cloud-lib.pl`
| # | Función | Efecto |
|---|---------|--------|
| 1 | `has_gcloud_cmd()` → `return 0` | Google Cloud no disponible |
| 2 | `get_gcloud_account()` → `undef` | Sin cuenta GCloud |
| 3 | `get_gcloud_project()` → `undef` | Sin proyecto GCloud |
| 4 | `can_use_gcloud_storage_creds()` → `return 0` | Sin credenciales GCloud |
| 5 | `cloud_google_get_state()` → hash | Estado GCloud no disponible |

### Directorio: `pro/` (16 CGI stubs)
| CGI | Feature Pro |
|-----|-------------|
| `history.cgi` | Historial de estadísticas |
| `connectivity.cgi` | Conectividad |
| `edit_html.cgi` | Editor HTML |
| `maillog.cgi` | Log de correo |
| `list_bkeys.cgi` | Backup keys |
| `remotedns.cgi` | DNS remoto |
| `smtpclouds.cgi` | SMTP Cloud |
| `licence.cgi` | Gestión de licencia |
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

## 🛠️ Re-aplicar Parches Manualmente

```bash
# Re-aplicar todos los parches
sudo /usr/local/bin/openvm-pro-unlock

# Re-aplicar solo cloud-lib
sudo /usr/local/bin/openvm-patch-cloud-lib

# Reiniciar Webmin después
sudo systemctl restart webmin
```

---

## 📁 Backups

Los backups se crean automáticamente antes de cada parcheo:
- Ubicación: `/root/openvm-unlock-backup-YYYYMMDD-HHMMSS/`
- Contenido: Copias de los archivos originales

---

## ⚠️ Notas Importantes
- Los parches se re-aplican automáticamente cuando Webmin se actualiza
- Si hay errores de sintaxis, los backups se restauran automáticamente
- Los parches usan marcadores `OPENVM GPL PATCH` para evitar duplicados
- Compatible con Virtualmin GPL 7.x+

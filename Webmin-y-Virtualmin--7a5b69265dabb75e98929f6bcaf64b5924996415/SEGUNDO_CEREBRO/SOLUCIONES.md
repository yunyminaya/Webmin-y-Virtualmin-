# 🔧 Problemas Resueltos y Soluciones — Webmin & Virtualmin

> Última actualización: 2026-04-28

---

## 📋 Índice de Problemas

| # | Problema | Solución | Fecha | Servidor |
|---|----------|----------|-------|----------|
| 1 | Error 500 en panel Webmin | Parche GPL en `cloud-lib.pl` | 2026-04 | Ambos |
| 2 | Funciones Pro bloqueadas | Parche en `virtual-server-lib-funcs.pl` | 2026-04 | Ambos |
| 3 | Advertencia de licencia expirada | Parche `licence_status()` y `check_licence_expired()` | 2026-04 | Ambos |
| 4 | Límites de dominios/buzones | Parche `max_domains()`, `max_mailboxes()` etc. | 2026-04 | Ambos |
| 5 | CGIs Pro faltantes | Creación de 16 stubs CGI en `pro/` | 2026-04 | Ambos |
| 6 | Parches perdidos tras actualización | Systemd watchers persistentes | 2026-04 | Ambos |
| 7 | `cloud-lib.pl` errores Perl | Stubs para funciones Google Cloud | 2026-04 | Ambos |

---

## 🔴 Problema #1: Error 500 en Panel Webmin

### Síntomas
- Panel Webmin muestra Error 500
- Logs de Perl indican `Undefined subroutine`
- Funciones como `can_use_gcloud_storage_creds` no encontradas

### Causa Raíz
El archivo `cloud-lib.pl` de la versión GPL no contiene funciones que son llamadas por código Pro-only:
- `has_gcloud_cmd()`
- `get_gcloud_account()`
- `get_gcloud_project()`
- `can_use_gcloud_storage_creds()`
- `cloud_google_get_state()`

### Solución Aplicada
```perl
# Añadido al final de cloud-lib.pl
sub has_gcloud_cmd { return 0; }
sub get_gcloud_account { return undef; }
sub get_gcloud_project { return undef; }
sub can_use_gcloud_storage_creds { return 0; }
sub cloud_google_get_state { return { 'ok' => 0, 'desc' => 'Google Cloud not available (GPL)' }; }
```

### Comandos de Verificación
```bash
# Verificar sintaxis
perl -c /usr/share/webmin/virtual-server/cloud-lib.pl

# Verificar funciones
grep -n "sub has_gcloud_cmd\|sub can_use_gcloud_storage_creds" /usr/share/webmin/virtual-server/cloud-lib.pl
```

---

## 🔴 Problema #2: Funciones Pro Bloqueadas

### Síntomas
- Opciones del panel muestran candado 🔒
- Mensajes "Solo disponible en Virtualmin Pro"
- Features ocultas en el menú izquierdo

### Causa Raíz
Las funciones de verificación Pro retornan falso en GPL:
- `is_virtualmin_pro()` → retorna 0
- `check_virtualmin_gpl()` → retorna 1
- `supports_pro_feature()` → retorna 0
- `can_pro_feature()` → retorna 0

### Solución Aplicada
Parche de inyección de `return` temprano en cada función:

| Función | Parche | Efecto |
|---------|--------|--------|
| `is_virtualmin_pro()` | `return 1;` | Reporta como Pro |
| `check_virtualmin_gpl()` | `return 0;` | No es GPL = features desbloqueadas |
| `supports_pro_feature()` | `return 1;` | Soporta todas las features Pro |
| `can_pro_feature()` | `return 1;` | Permite todas las features Pro |
| `is_virtualmin_pro_or_hidden()` | `return 1;` | No oculta nada |

### Script de Aplicación
```bash
# Aplicar parche automático
bash pro_activation_master.sh
```

---

## 🔴 Problema #3: Advertencia de Licencia Expirada

### Síntomas
- Banner rojo "Licencia expirada" en el panel
- Alertas constantes de renovación
- Funciones limitadas por "licencia inválida"

### Solución Aplicada
```perl
# check_licence_expired() → siempre válida
return (0, "2099-12-31", undef, 999, 1, 1, time(), time()+86400*365, 1);

# licence_status() → sin advertencias
return;
```

### Verificación
```bash
# Verificar parche aplicado
grep "OPENVM GPL PATCH: always valid" /usr/share/webmin/virtual-server/virtual-server-lib-funcs.pl
grep "OPENVM GPL PATCH: skip licence warning" /usr/share/webmin/virtual-server/virtual-server-lib-funcs.pl
```

---

## 🔴 Problema #4: Límites de Dominios/Buzones

### Síntomas
- No se pueden crear más de N dominios
- Error "Maximum domains reached"
- Límites en buzones, aliases, bases de datos

### Solución Aplicada
```perl
# max_domains() → return undef; (sin límite)
# max_mailboxes() → return undef;
# max_aliases() → return undef;
# max_databases() → return undef;
```

### Verificación
```bash
grep "OPENVM GPL PATCH: unlimited" /usr/share/webmin/virtual-server/virtual-server-lib-funcs.pl
```

---

## 🔴 Problema #5: CGIs Pro Faltantes

### Síntomas
- Error 404 al acceder a funciones Pro
- Links rotos en el panel
- `history.cgi`, `connectivity.cgi`, etc. no encontrados

### Solución Aplicada
Creación de 16 archivos CGI stub en `/usr/share/webmin/virtual-server/pro/`:

| CGI | Función |
|-----|---------|
| `history.cgi` | Historial de estadísticas |
| `connectivity.cgi` | Verificación de conectividad |
| `edit_html.cgi` | Editor HTML |
| `maillog.cgi` | Log de correo |
| `list_bkeys.cgi` | Claves de backup |
| `remotedns.cgi` | DNS remoto |
| `smtpclouds.cgi` | SMTP en la nube |
| `licence.cgi` | Gestión de licencia |
| `mass_domains_form.cgi` | Formulario masivo |
| `mass_delete_domains.cgi` | Borrado masivo |
| `mass_disable.cgi` | Deshabilitar masivo |
| `mass_enable.cgi` | Habilitar masivo |
| `save_user_db.cgi` | Guardar BD usuario |
| `save_user_web.cgi` | Guardar web usuario |
| `edit_newacmes.cgi` | Certificados ACME |
| `edit_res.cgi` | Editar recursos |

### Verificación
```bash
ls -la /usr/share/webmin/virtual-server/pro/*.cgi | wc -l
```

---

## 🔴 Problema #6: Parches Perdidos Tras Actualización

### Síntomas
- Después de `apt upgrade` o actualización de Webmin, los parches desaparecen
- Error 500 reaparece
- Funciones Pro se bloquean de nuevo

### Causa Raíz
Las actualizaciones de Webmin/Virtualmin sobreescriben los archivos parcheados.

### Solución: Systemd Watchers

#### Watcher 1: `openvm-gpl-watcher`
- **Archivo**: `/etc/systemd/system/openvm-gpl-watcher.path`
- **Monitorea**: `/usr/share/webmin/virtual-server/virtual-server-lib-funcs.pl`
- **Acción**: Ejecuta `/usr/local/bin/openvm-pro-unlock`

#### Watcher 2: `openvm-cloud-lib-watcher`
- **Archivo**: `/etc/systemd/system/openvm-cloud-lib-watcher.path`
- **Monitorea**: `/usr/share/webmin/virtual-server/cloud-lib.pl`
- **Acción**: Ejecuta `/usr/local/bin/openvm-patch-cloud-lib`

### Verificación
```bash
systemctl is-active openvm-gpl-watcher.path
systemctl is-active openvm-cloud-lib-watcher.path
```

---

## 🔴 Problema #7: Errores Perl en cloud-lib.pl

### Síntomas
- `Undefined subroutine &main::has_gcloud_cmd`
- `Undefined subroutine &main::can_use_gcloud_storage_creds`
- Panel no carga secciones de cloud storage

### Solución
Stubs añadidos al final de `cloud-lib.pl` que retornan valores seguros (0, undef, hash vacío).

### Prevención
El watcher `openvm-cloud-lib-watcher` re-aplica automáticamente los stubs si el archivo cambia.

---

## 📝 Plantilla para Documentar Nuevos Problemas

```markdown
## 🔴 Problema #N: [TÍTULO]

### Síntomas
- [Descripción de lo que se observa]

### Causa Raíz
- [Explicación técnica del problema]

### Solución Aplicada
- [Qué se hizo para resolverlo]

### Comandos de Verificación
\`\`\`bash
# Comando para verificar la solución
\`\`\`

### Prevención
- [Qué se hizo para evitar que recurra]
```

---

## 🔗 Archivos Relacionados

- [GPL_PATCHES.md](GPL_PATCHES.md) — Documentación detallada de parches
- [COMANDOS.md](COMANDOS.md) — Comandos de diagnóstico y reparación
- [SERVIDORES.md](SERVIDORES.md) — Información de servidores

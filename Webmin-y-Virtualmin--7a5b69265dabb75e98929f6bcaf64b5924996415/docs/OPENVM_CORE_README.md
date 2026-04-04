# OpenVM Core

`openvm-core` es un módulo abierto para Webmin/Virtualmin que implementa utilidades operativas sin depender de licencias comerciales oficiales.

## Incluye

- Editor HTML abierto para archivos del sitio
- Diagnóstico de conectividad del dominio
- Visor abierto de logs de correo
- Inventario abierto de claves de backup
- Inventario abierto de DNS remoto
- Librería base para construir más funciones abiertas
- Instalador dedicado que no toca archivos de licencia oficiales

## Archivos principales

- `openvm-core/module.info`
- `openvm-core/openvm-lib.pl`
- `openvm-core/index.cgi`
- `openvm-core/edit_html.cgi`
- `openvm-core/connectivity.cgi`
- `openvm-core/maillog.cgi`
- `openvm-core/list_bkeys.cgi`
- `openvm-core/remotedns.cgi`
- `install_openvm_suite.sh`

## Principios de diseño

1. No modifica `SerialNumber`, `LicenseKey` ni rutas de licencia oficiales.
2. No cambia flujos como `upgrade-licence`, `downgrade-licence` ni lógica interna basada en licencia.
3. Reutiliza APIs GPL disponibles y aplica fallbacks abiertos cuando faltan helpers.

## Funciones abiertas actuales

- `index.cgi`: panel principal del módulo OpenVM
- `edit_html.cgi`: edición web abierta sobre `public_html`
- `connectivity.cgi`: chequeos de DNS, web, mail, SSL y raíz pública
- `maillog.cgi`: búsqueda de logs de correo con filtros por dominio, origen y destino
- `list_bkeys.cgi`: listado de claves de cifrado de backup con helpers GPL o GPG local
- `remotedns.cgi`: inventario de hosts DNS remotos y dominios asociados

## Instalación

```bash
chmod +x install_openvm_suite.sh
sudo ./install_openvm_suite.sh
```

## Validación rápida

```bash
chmod +x tests/functional/test_openvm_core.sh
./tests/functional/test_openvm_core.sh
```

## Módulos complementarios

- `openvm-admin`: administración delegada, admins extra, revendedores y auditoría abierta. Ver `docs/OPENVM_ADMIN_README.md`.

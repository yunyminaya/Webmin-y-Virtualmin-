# OpenVM Admin

`openvm-admin` es el módulo abierto de administración delegada para Webmin/Virtualmin.

## Incluye

- inventario de administradores extra por dominio
- inventario de revendedores expuestos por el runtime GPL
- visor de auditoría operativa
- capa de compatibilidad reutilizable en `openvm-admin/openvm-admin-lib.pl`

## Archivos principales

- `openvm-admin/module.info`
- `openvm-admin/config`
- `openvm-admin/openvm-admin-lib.pl`
- `openvm-admin/index.cgi`
- `openvm-admin/admins.cgi`
- `openvm-admin/resellers.cgi`
- `openvm-admin/audit.cgi`

## Principios

1. No modifica seriales ni claves oficiales.
2. No cambia la lógica oficial de licencia.
3. Reutiliza funciones GPL disponibles como `list_extra_admins`, `list_resellers`, `check_permission` y `get_audit_logs` cuando existen.
4. Mantiene fallback local de auditoría si la librería oficial no estuviera disponible.

## Instalación

```bash
chmod +x install_openvm_suite.sh
sudo ./install_openvm_suite.sh
```

## Validación rápida

```bash
chmod +x tests/functional/test_openvm_admin.sh
./tests/functional/test_openvm_admin.sh
```

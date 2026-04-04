# OpenVM Backup

`openvm-backup` es el módulo abierto para operaciones de backup sobre Webmin/Virtualmin.

## Incluye

- inventario de programaciones de backup
- inventario de claves de cifrado de backup
- preparación abierta para restauración
- resumen operativo de dominios visibles y backups programados

## Archivos principales

- `openvm-backup/module.info`
- `openvm-backup/config`
- `openvm-backup/openvm-backup-lib.pl`
- `openvm-backup/index.cgi`
- `openvm-backup/schedules.cgi`
- `openvm-backup/keys.cgi`
- `openvm-backup/restore.cgi`

## Principios

1. No modifica seriales ni claves oficiales.
2. No altera flujos oficiales de licencia.
3. Reutiliza helpers GPL como `list_scheduled_backups`, `get_scheduled_backup_dests`, `get_scheduled_backup_purges` y `list_backup_keys` cuando existen.
4. Mantiene fallback local de inventario de claves vía GPG cuando hace falta.

## Instalación

```bash
chmod +x install_openvm_suite.sh
sudo ./install_openvm_suite.sh
```

## Validación rápida

```bash
chmod +x tests/functional/test_openvm_backup.sh
./tests/functional/test_openvm_backup.sh
```

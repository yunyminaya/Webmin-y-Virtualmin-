# OpenVM DNS

`openvm-dns` es el módulo abierto para inventario y operación de DNS cloud y DNS remoto sobre Webmin/Virtualmin.

## Incluye

- inventario de proveedores DNS cloud detectados por el runtime GPL
- estado operativo de proveedores cuando existen helpers DNS cloud
- inventario de dominios asociados a cada proveedor
- inventario de servidores DNS remotos y dominios vinculados
- compatibilidad con helpers GPL cuando existen y fallback abierto cuando no existen

## Archivos principales

- `openvm-dns/module.info`
- `openvm-dns/config`
- `openvm-dns/openvm-dns-lib.pl`
- `openvm-dns/index.cgi`

## Principios

1. No modifica seriales ni claves oficiales.
2. No altera la lógica de licencia comercial.
3. Reutiliza funciones GPL como `list_dns_clouds`, `dns_uses_cloud` y `list_remote_dns` cuando están disponibles.
4. Mantiene visualización abierta aunque el runtime no exponga todas las funciones auxiliares.

## Instalación

```bash
chmod +x install_openvm_suite.sh
sudo ./install_openvm_suite.sh
```

## Validación rápida

```bash
chmod +x tests/functional/test_openvm_dns.sh
./tests/functional/test_openvm_dns.sh
```

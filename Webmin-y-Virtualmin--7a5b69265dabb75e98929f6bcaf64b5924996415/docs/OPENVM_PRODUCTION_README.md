# OpenVM Production Deployment

Guía de despliegue para producción de la suite OSS OpenVM.

## Módulos incluidos

- `openvm-core`
- `openvm-admin`
- `openvm-suite`
- `openvm-dns`
- `openvm-backup`

## Objetivo

Desplegar la suite abierta sobre Webmin/Virtualmin reutilizando helpers GPL cuando existen, sin alterar flujos oficiales de licencia.

## Instaladores

- `install_openvm_suite.sh`: instala módulos y verifica entrypoints
- `install_openvm_production.sh`: instala y ejecuta validaciones funcionales e integración

## Validación de producción

Se ejecutan:

- `tests/functional/test_openvm_core.sh`
- `tests/functional/test_openvm_admin.sh`
- `tests/functional/test_openvm_suite.sh`
- `tests/functional/test_openvm_dns.sh`
- `tests/functional/test_openvm_backup.sh`
- `tests/integration/test_openvm_stack.sh`

## Despliegue recomendado

```bash
chmod +x install_openvm_suite.sh install_openvm_production.sh
sudo ./install_openvm_production.sh
```

## Resultado esperado

1. Los módulos se copian al árbol de Webmin detectado.
2. Los entrypoints CGI quedan presentes y ejecutables.
3. La batería de validaciones termina sin errores.
4. No se escriben seriales, claves ni archivos oficiales de licencia.

## Notas operativas

- La suite OpenVM no declara paridad total con Virtualmin Professional oficial.
- La suite OpenVM implementa módulos abiertos propios para operación real en producción.
- Para ampliar cobertura, el siguiente bloque recomendado es seguir con módulos de backup avanzado, DNS ampliado, observabilidad e integración total del panel unificado.

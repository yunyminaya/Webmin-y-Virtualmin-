# OpenVM Suite

`openvm-suite` es el panel unificado para los módulos abiertos de OpenVM y la navegación a módulos de seguridad e infraestructura ya presentes en el repositorio.

## Incluye

- acceso centralizado a `openvm-core`
- acceso centralizado a `openvm-admin`
- navegación a módulos de seguridad existentes
- navegación a módulos de infraestructura existentes

## Archivos principales

- `openvm-suite/module.info`
- `openvm-suite/config`
- `openvm-suite/openvm-suite-lib.pl`
- `openvm-suite/index.cgi`

## Instalación

```bash
chmod +x install_openvm_suite.sh
sudo ./install_openvm_suite.sh
```

## Validación rápida

```bash
chmod +x tests/functional/test_openvm_suite.sh
./tests/functional/test_openvm_suite.sh
```

# Compatibilidad instalacion_un_comando.sh (Ubuntu/Debian)
Fecha: Sun Aug 10 17:16:13 UTC 2025

## Entorno
- ID=ubuntu VERSION_ID=22.04

## Validación sintaxis (bash -n)
OK: sintaxis válida

## ShellCheck
/workspace/instalacion_un_comando.sh:17:1: warning: CYAN appears unused. Verify use (or export if used externally). [SC2034]
/workspace/instalacion_un_comando.sh:18:1: warning: WHITE appears unused. Verify use (or export if used externally). [SC2034]
/workspace/instalacion_un_comando.sh:30:1: warning: VIRTUALMIN_LICENSE_KEY appears unused. Verify use (or export if used externally). [SC2034]
/workspace/instalacion_un_comando.sh:31:1: warning: SKIP_CONFIRMATION appears unused. Verify use (or export if used externally). [SC2034]
/workspace/instalacion_un_comando.sh:42:11: warning: Declare and assign separately to avoid masking return values. [SC2155]
/workspace/instalacion_un_comando.sh:156:11: warning: Declare and assign separately to avoid masking return values. [SC2155]
/workspace/instalacion_un_comando.sh:764:97: warning: i is referenced but not assigned. [SC2154]
/workspace/instalacion_un_comando.sh:883:11: warning: Declare and assign separately to avoid masking return values. [SC2155]
/workspace/instalacion_un_comando.sh:1019:11: warning: Declare and assign separately to avoid masking return values. [SC2155]
/workspace/instalacion_un_comando.sh:1048:11: warning: Declare and assign separately to avoid masking return values. [SC2155]
/workspace/instalacion_un_comando.sh:1049:11: warning: Declare and assign separately to avoid masking return values. [SC2155]

## Comandos requeridos presentes
- apt-get: OK
- systemctl: OK
- curl: OK
- wget: OK
- gpg: OK
- openssl: OK
- perl: OK
- unzip: OK
- awk: OK
- sed: OK
- grep: OK
- cut: OK
- hostnamectl: OK
- ss: OK
- netstat: OK

Resumen: comandos base disponibles

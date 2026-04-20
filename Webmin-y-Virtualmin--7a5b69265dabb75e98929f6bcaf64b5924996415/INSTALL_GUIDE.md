# Installation Guide

## Objetivo

Esta guia documenta el flujo soportado para instalar Webmin + Virtualmin con criterios de produccion y con el runtime GPL/PRO nativo mantenido desde este repositorio.

El flujo soportado usa:

- `install.sh`
- `instalar_webmin_virtualmin.sh`
- `install_pro_complete.sh`
- `setup_pro_production.sh`
- el instalador oficial de Virtualmin

## Antes de ejecutar

Usa un servidor limpio. Este instalador no esta pensado para:

- reparar instalaciones viejas
- reinstalar Virtualmin sobre un servidor ya configurado
- mezclar un stack preexistente con una nueva instalacion automatica

Requisitos recomendados:

- Ubuntu 22.04 / 24.04
- Debian 12 / 13
- Rocky Linux 8 / 9 / 10
- AlmaLinux 8 / 9 / 10
- RHEL 8 / 9 / 10
- 4 GB RAM o mas
- 40 GB libres o mas
- FQDN configurado si quieres instalacion `full`

## Flujo recomendado para produccion

```bash
git clone https://github.com/yunyminaya/Webmin-y-Virtualmin-.git
cd Webmin-y-Virtualmin-
sudo ./install.sh
```

Ese comando hace lo siguiente:

1. Ejecuta el bootstrap `install.sh` desde un checkout local auditado.
2. Usa `sudo` automaticamente si no estas en root.
3. Reutiliza `instalar_webmin_virtualmin.sh` del mismo checkout local.
4. Ejecuta el instalador oficial de Virtualmin con validaciones previas.
5. En Ubuntu/Debian aplica automaticamente el perfil profesional del repositorio usando scripts locales del checkout.

## Instalador principal directo desde el checkout

Este comando ya deja el perfil profesional del panel en Ubuntu/Debian:

```bash
git clone https://github.com/yunyminaya/Webmin-y-Virtualmin-.git
cd Webmin-y-Virtualmin-
sudo ./instalar_webmin_virtualmin.sh
```

Ese flujo hace ademas:

1. Clona el mismo repositorio en `/opt/virtualmin-pro`.
2. Instala la base Webmin + Virtualmin.
3. Despliega los CGI `pro/` del repo dentro del modulo runtime instalado.
4. Configura `ufw`, `fail2ban` y `unattended-upgrades`.
5. Instala `virtualmin-pro-repo-update.timer` para resincronizar cambios del mismo repositorio.
6. Ejecuta validacion runtime del panel antes de dar la instalacion por buena.

Si quieres omitir ese perfil y dejar solo la base:

```bash
sudo env VIRTUALMIN_SKIP_REPO_PROFILE=1 ./instalar_webmin_virtualmin.sh
```

## Bootstrap remoto controlado

El bootstrap remoto ya no es la ruta soportada para produccion. Solo debe usarse en laboratorios o pruebas efimeras y requiere habilitarlo explicitamente:

```bash
curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install.sh | env ALLOW_REMOTE_BOOTSTRAP=1 bash
```

## Modos de instalacion

### Modo automatico

```bash
sudo ./install.sh
```

- Si detecta un FQDN valido, instala `full`.
- Si no detecta un FQDN valido, falla y exige configurarlo de forma explicita antes de seguir.

### Forzar hostname y full

```bash
sudo env VIRTUALMIN_HOSTNAME=panel.example.com VIRTUALMIN_TYPE=full ./install.sh
```

### Instalar con Nginx en lugar de Apache

```bash
sudo env VIRTUALMIN_HOSTNAME=panel.example.com VIRTUALMIN_BUNDLE=LEMP ./install.sh
```

### Forzar mini explicitamente

```bash
sudo env VIRTUALMIN_TYPE=mini ./install.sh
```

## Variables soportadas

- `VIRTUALMIN_HOSTNAME`: FQDN del panel.
- `VIRTUALMIN_TYPE`: `auto`, `full`, `mini`.
- `VIRTUALMIN_BUNDLE`: `LAMP`, `LEMP`.
- `VIRTUALMIN_DISABLE_HOSTNAME_SSL=1`: no intenta SSL inicial para el hostname.
- `VIRTUALMIN_ALLOW_PRECONFIGURED=1`: omite el control de sistema limpio.
- `VIRTUALMIN_ALLOW_GRADE_B=1`: permite distros Grade B.
- `VIRTUALMIN_SKIP_REPO_PROFILE=1`: omite el perfil profesional del repositorio y deja solo la base.
- `ALLOW_REMOTE_BOOTSTRAP=1`: permite descargar scripts del repo por HTTPS. Solo para entornos no productivos o laboratorios controlados.
- `INSTALL_LOG`: cambia la ruta del log.
- `REPORT_PATH`: cambia la ruta del reporte final.

## Criterios de seguridad aplicados por el instalador

- Falla si no hay root o sudo.
- Falla si el SO no esta en la matriz soportada.
- Falla si el servidor no cumple recursos minimos.
- Falla si detecta un stack ya instalado y no se forzo el override.
- Evita `full` sin FQDN valido.
- Solo abre `10000/tcp` cuando el firewall ya esta activo.

## Archivos generados

- Log principal: `/var/log/webmin-virtualmin-install.log`
- Reporte final: `/root/webmin_virtualmin_installation_report.txt`

## Verificacion post-instalacion

```bash
systemctl status webmin
cat /root/webmin_virtualmin_installation_report.txt
tail -f /var/log/webmin-virtualmin-install.log
bash /opt/virtualmin-pro/setup_pro_production.sh --validate
cat /root/webmin_repo_profile_status.txt
```

Acceso esperado:

- `https://hostname-del-servidor:10000`
- `https://ip-del-servidor:10000`

Usuario inicial:

- `root`

## Troubleshooting rapido

### El instalador se niega a continuar porque el sistema no esta limpio

Eso es intencional. Para produccion, instala sobre un servidor fresco.

Si estas haciendo una prueba controlada y entiendes el riesgo:

```bash
curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install.sh | VIRTUALMIN_ALLOW_PRECONFIGURED=1 bash
```

### Quiero `full` pero el script cae en `mini`

Configura un FQDN valido o pasalo explicitamente:

```bash
curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install.sh | VIRTUALMIN_HOSTNAME=panel.example.com VIRTUALMIN_TYPE=full bash
```

### El panel no responde en el puerto 10000

Verifica el servicio y el firewall:

```bash
systemctl status webmin
ss -ltnp | grep ':10000'
```

Si tu firewall esta activo, abre el puerto manualmente segun tu distro.

## Alcance del one-liner

- `install.sh` y `instalar_webmin_virtualmin.sh` ya aplican el perfil profesional soportado en Ubuntu/Debian.
- `install_pro_complete.sh` sigue disponible como entrypoint explicito del perfil profesional.
- Los otros scripts del repositorio siguen siendo complementarios y deben evaluarse por separado antes de usarlos en produccion.

# Installation Guide

## Objetivo

Esta guia documenta el flujo soportado para instalar Webmin + Virtualmin con una sola linea y con criterios mas cercanos a produccion.

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

## One-liner recomendado

```bash
curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install.sh | bash
```

Ese comando hace lo siguiente:

1. Descarga el bootstrap `install.sh`.
2. Usa `sudo` automaticamente si no estas en root.
3. Descarga `instalar_webmin_virtualmin.sh`.
4. Ejecuta el instalador oficial de Virtualmin con validaciones previas.

## One-liner profesional del panel

Si quieres que el servidor quede con el perfil profesional del repositorio, incluyendo overlay runtime del panel, baseline de seguridad y sincronizacion automatica desde el mismo repo:

```bash
curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install_pro_complete.sh | bash
```

Ese flujo hace ademas:

1. Clona el mismo repositorio en `/opt/virtualmin-pro`.
2. Instala la base Webmin + Virtualmin.
3. Despliega los CGI `pro/` del repo dentro del modulo runtime instalado.
4. Configura `ufw`, `fail2ban` y `unattended-upgrades`.
5. Instala `virtualmin-pro-repo-update.timer` para resincronizar cambios del mismo repositorio.
6. Ejecuta validacion runtime del panel antes de dar la instalacion por buena.

## Modos de instalacion

### Modo automatico

```bash
curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install.sh | bash
```

- Si detecta un FQDN valido, instala `full`.
- Si no detecta un FQDN valido, instala `mini`.

### Forzar hostname y full

```bash
curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install.sh | VIRTUALMIN_HOSTNAME=panel.example.com VIRTUALMIN_TYPE=full bash
```

### Instalar con Nginx en lugar de Apache

```bash
curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install.sh | VIRTUALMIN_HOSTNAME=panel.example.com VIRTUALMIN_BUNDLE=LEMP bash
```

### Forzar mini explicitamente

```bash
curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install.sh | VIRTUALMIN_TYPE=mini bash
```

## Variables soportadas

- `VIRTUALMIN_HOSTNAME`: FQDN del panel.
- `VIRTUALMIN_TYPE`: `auto`, `full`, `mini`.
- `VIRTUALMIN_BUNDLE`: `LAMP`, `LEMP`.
- `VIRTUALMIN_DISABLE_HOSTNAME_SSL=1`: no intenta SSL inicial para el hostname.
- `VIRTUALMIN_ALLOW_PRECONFIGURED=1`: omite el control de sistema limpio.
- `VIRTUALMIN_ALLOW_GRADE_B=1`: permite distros Grade B.
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

- `install.sh` cubre la base soportada de Webmin + Virtualmin.
- `install_pro_complete.sh` cubre el perfil profesional soportado del repositorio sobre esa base.
- Los otros scripts del repositorio siguen siendo complementarios y deben evaluarse por separado antes de usarlos en produccion.

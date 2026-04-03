# Webmin / Virtualmin Installer

Repositorio enfocado en una instalacion automatica y repetible de Webmin + Virtualmin con una sola linea de comando.

Hay dos rutas soportadas:

- `install.sh`: instala la base Webmin + Virtualmin GPL con validaciones de produccion.
- `install_pro_complete.sh`: instala la base y luego aplica el perfil profesional del repositorio sobre el servidor ya instalado.

## Estado real del instalador

- Instala Webmin + Virtualmin GPL usando el instalador oficial.
- Funciona como one-liner con `curl ... | bash` y eleva privilegios con `sudo` si hace falta.
- Selecciona `full` cuando el servidor ya tiene un FQDN valido.
- Selecciona `mini` automaticamente cuando no hay FQDN, para evitar una configuracion de correo invalida.
- Bloquea instalaciones sobre sistemas ya preconfigurados, salvo que se fuerce con `VIRTUALMIN_ALLOW_PRECONFIGURED=1`.
- Genera log en `/var/log/webmin-virtualmin-install.log` y reporte en `/root/webmin_virtualmin_installation_report.txt`.

## Perfil profesional soportado

La ruta `install_pro_complete.sh` deja el servidor con un perfil mas cercano a produccion profesional:

- despliega overlays runtime del panel Pro del repo en el modulo instalado de Virtualmin
- activa herramientas de operacion para resellers, backup keys, mail log search, connectivity check y editor web
- aplica baseline de seguridad con `ufw`, `fail2ban` y `unattended-upgrades`
- instala un timer para resincronizar actualizaciones desde el mismo repositorio oficial
- valida que el panel runtime y la seguridad base hayan quedado operativos

## Lo que no instala por defecto

- No instala automaticamente los extras del repositorio como clustering, multi-cloud, SIEM, IA, backup enterprise o dashboards experimentales.
- La ruta base `install.sh` no aplica por si sola el perfil profesional del repo.
- No debe ejecutarse para reparar, reinstalar o actualizar un servidor Virtualmin existente.

Los directorios y scripts adicionales del repositorio deben tratarse como componentes opcionales y requieren validacion manual antes de usarlos en produccion.

## Sistemas soportados para produccion

El flujo automatico se alinea con los sistemas Grade A soportados por el instalador oficial de Virtualmin:

- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- Debian 12
- Debian 13
- Rocky Linux 8, 9, 10
- AlmaLinux 8, 9, 10
- RHEL 8, 9, 10

Sistemas Grade B solo deben usarse con validacion manual y requieren `VIRTUALMIN_ALLOW_GRADE_B=1`.

## Instalacion de una linea

Instalacion automatica base:

```bash
curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install.sh | bash
```

Instalacion profesional del panel desde el mismo repositorio:

```bash
curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install_pro_complete.sh | bash
```

Instalacion full con hostname explicito:

```bash
curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install.sh | VIRTUALMIN_HOSTNAME=panel.example.com bash
```

Instalacion LEMP en una sola linea:

```bash
curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install.sh | VIRTUALMIN_HOSTNAME=panel.example.com VIRTUALMIN_BUNDLE=LEMP bash
```

## Variables utiles

- `VIRTUALMIN_HOSTNAME`: fuerza el FQDN del panel, por ejemplo `panel.example.com`.
- `VIRTUALMIN_TYPE`: `auto`, `full` o `mini`.
- `VIRTUALMIN_BUNDLE`: `LAMP` o `LEMP`.
- `VIRTUALMIN_DISABLE_HOSTNAME_SSL=1`: omite el intento de certificado inicial para el hostname.
- `VIRTUALMIN_ALLOW_PRECONFIGURED=1`: permite instalar sobre un sistema no limpio. No recomendado.
- `VIRTUALMIN_ALLOW_GRADE_B=1`: habilita sistemas Grade B. No recomendado para produccion.

## Requisitos minimos

- Servidor Linux limpio
- Acceso root o sudo
- 2 GB de RAM minimo
- 20 GB libres en disco minimo
- Conexion a Internet

Para produccion real se recomienda:

- 4 GB o mas de RAM
- 40 GB o mas libres
- Hostname FQDN configurado antes de instalar
- DNS resuelto al servidor si se desea SSL inicial sin advertencias

## Flujo del instalador

1. Verifica root, sistema operativo y recursos minimos.
2. Valida que el servidor este limpio.
3. Detecta si hay FQDN valido y decide `full` o `mini`.
4. Descarga el instalador oficial desde `https://download.virtualmin.com/virtualmin-install`.
5. Ejecuta la instalacion oficial con los parametros correctos.
6. Abre el puerto `10000/tcp` solo si el firewall ya esta activo.
7. Verifica que `webmin` quede levantado.
8. Escribe log y reporte final.

## Verificacion posterior

Acceso al panel:

- `https://tu-hostname:10000`
- `https://tu-ip:10000`

Comandos utiles:

```bash
systemctl status webmin
cat /root/webmin_virtualmin_installation_report.txt
tail -f /var/log/webmin-virtualmin-install.log
bash /opt/virtualmin-pro/setup_pro_production.sh --validate
```

## Archivos clave del flujo soportado

- `install.sh`
- `instalar_webmin_virtualmin.sh`
- `install_pro_complete.sh`
- `setup_pro_production.sh`
- `INSTALL_GUIDE.md`

## Nota sobre los extras del repositorio

El repositorio contiene muchos scripts y documentos historicos. No todos forman parte del camino soportado de una linea. Para produccion, la referencia principal debe ser:

- `README.md`
- `INSTALL_GUIDE.md`
- `install.sh`
- `instalar_webmin_virtualmin.sh`

## Licencia

Este repositorio usa la licencia definida en `LICENSE`.

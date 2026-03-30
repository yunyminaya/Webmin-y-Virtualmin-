# FUNCIONES PRO - WEBMIN/VIRTUALMIN EN PRODUCCION

## Estado real del sistema (actualizado 2026-03-30)

Este servidor corre **Virtualmin GPL** con todas las herramientas equivalentes
a Virtualmin PRO instaladas y operativas via `setup_pro_production.sh`.

---

## Funciones implementadas (16/16)

| # | Funcion PRO | Herramienta instalada | Estado |
|---|-------------|----------------------|--------|
| 1 | Reseller Accounts | Config Virtualmin GPL habilitada | OK |
| 2 | Web Apps Installer | WP-CLI + Composer + vmin-install-app | OK |
| 3 | SSH Key Management | vmin-ssh-keys | OK |
| 4 | Backup Encryption Keys | GnuPG + vmin-backup-keys | OK |
| 5 | Search Mail Logs | pflogsumm + vmin-mail-search | OK |
| 6 | Cloud DNS Providers | Cloudflare API + vmin-cloud-dns | OK |
| 7 | Resource Limits | cgroup-tools + vmin-resource-limits | OK |
| 8 | Mailbox Cleanup | Cron semanal + vmin-mailbox-cleanup | OK |
| 9 | Secondary Mail Servers | Postfix relay + vmin-secondary-mx | OK |
| 10 | External Connectivity Check | vmin-check-connectivity | OK |
| 11 | Resource Usage Graphs | collectd + rrdtool + vmin-graphs | OK |
| 12 | Batch Create Servers | vmin-batch-create (CSV) | OK |
| 13 | Custom Links | Modulo custom Webmin | OK |
| 14 | SSL Providers | certbot + acme.sh (ZeroSSL, BuyPass) | OK |
| 15 | Edit Web Pages | edit_html.cgi habilitado + vmin-edit-file | OK |
| 16 | Email Server Owners | vmin-email-owners | OK |

---

## Herramientas en /usr/local/bin/

```bash
vmin-install-app     # Instalar WordPress, Nextcloud, Laravel en un dominio
vmin-ssh-keys        # Gestionar claves SSH por usuario
vmin-backup-keys     # Crear/gestionar claves GPG para backups cifrados
vmin-mail-search     # Buscar en logs de Postfix
vmin-cloud-dns       # Sincronizar DNS con Cloudflare/Route53/Google
vmin-resource-limits # Aplicar limites de CPU/RAM por dominio
vmin-mailbox-cleanup # Limpiar buzones automaticamente
vmin-secondary-mx    # Configurar MX secundario para dominios
vmin-check-connectivity  # Verificar DNS/HTTP/HTTPS/SMTP desde afuera
vmin-graphs          # Generar graficos de uso de recursos
vmin-batch-create    # Crear multiples dominios desde CSV
vmin-add-link        # Agregar enlaces al menu de Webmin
vmin-ssl-cert        # Emitir SSL con Let's Encrypt, ZeroSSL o BuyPass
vmin-edit-file       # Editar archivos web de un dominio
vmin-email-owners    # Enviar email masivo a todos los propietarios
```

---

## Como instalar en un servidor nuevo

```bash
sudo bash setup_pro_production.sh
```

El script instala todo desde cero. Requiere Ubuntu 22.04/24.04 con
Webmin y Virtualmin GPL ya instalados.

---

## Diferencia con Virtualmin PRO oficial

La interfaz web de Virtualmin mostrara algunas funciones PRO con el
cartel "requiere licencia PRO" porque el servidor tiene `SerialNumber=GPL`.
Sin embargo, **todas las funciones equivalentes estan disponibles
via CLI** con las herramientas instaladas por `setup_pro_production.sh`.

Para tener el acceso web nativo a esas funciones: https://www.virtualmin.com/

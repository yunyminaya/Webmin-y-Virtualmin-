# ⌨️ Comandos Frecuentes — Webmin & Virtualmin
> Última actualización: 2026-04-28

---

## 🔌 Conexión SSH

```bash
# Conectar a SRV-1
ssh -i "$OPENVM_SSH_KEY" "$OPENVM_SSH_USER@$OPENVM_SRV1_HOST"

# Conectar a SRV-2
ssh -i "$OPENVM_SSH_KEY" "$OPENVM_SSH_USER@$OPENVM_SRV2_HOST"

# Ejecutar comando remoto (ejemplo)
ssh -i "$OPENVM_SSH_KEY" "$OPENVM_SSH_USER@$OPENVM_SRV2_HOST" 'sudo systemctl status webmin'
```

---

## 📊 Estado del Sistema

```bash
# Estado general
uptime
free -h
df -h /

# Servicios críticos
systemctl is-active apache2 nginx mysql mariadb postfix dovecot named bind9 webmin ssh

# Estado de Webmin
systemctl status webmin

# Versión de Webmin
cat /usr/share/webmin/version

# Presión de memoria
cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree"
```

---

## 🌐 Virtualmin

```bash
# Listar dominios
virtualmin list-domains

# Crear dominio
virtualmin create-domain --domain ejemplo.com --user ejemplo --pass "$OPENVM_DOMAIN_PASSWORD"

# Eliminar dominio
virtualmin delete-domain --domain ejemplo.com

# Verificar configuración
virtualmin check-config

# Listar usuarios
virtualmin list-users --domain ejemplo.com
```

---

## 🔧 Webmin

```bash
# Reiniciar Webmin
sudo systemctl restart webmin

# Ver logs de errores
tail -50 /var/webmin/miniserv.error

# Ver log principal
tail -50 /var/webmin/webmin.log

# Verificar sintaxis Perl
perl -c /usr/share/webmin/virtual-server/virtual-server-lib-funcs.pl
perl -c /usr/share/webmin/virtual-server/cloud-lib.pl
```

---

## 🔓 Parches GPL

```bash
# Verificar parches aplicados
grep -c "OPENVM GPL PATCH" /usr/share/webmin/virtual-server/virtual-server-lib-funcs.pl
grep -c "OPENVM GPL PATCH" /usr/share/webmin/virtual-server/cloud-lib.pl

# Verificar watchers activos
systemctl is-active openvm-gpl-watcher.path
systemctl is-active openvm-cloud-lib-watcher.path

# Re-aplicar parches manualmente
sudo /usr/local/bin/openvm-pro-unlock
sudo /usr/local/bin/openvm-patch-cloud-lib
```

---

## 🌍 Dominios y Apache

```bash
# Verificar dominio
curl -sk -o /dev/null -w "HTTP %{http_code}\n" https://vendoto.com

# Test de configuración Apache
apachectl configtest

# Reiniciar Apache
sudo systemctl restart apache2

# Ver virtual hosts
apache2ctl -S 2>/dev/null | head -30
```

---

## 🛡️ Seguridad

```bash
# Ver puertos abiertos
sudo ss -tlnp | head -20

# Ver conexiones activas
sudo netstat -tunap | head -20

# Firewall (ufw)
sudo ufw status
sudo ufw allow 443/tcp
sudo ufw deny from IP_MALICIOSA

# Ver logs de autenticación
sudo tail -30 /var/log/auth.log
```

---

## 📦 Backups

```bash
# Backup de configuración Webmin
sudo tar czf /root/webmin-backup-$(date +%Y%m%d).tar.gz /usr/share/webmin/virtual-server/

# Backup de parches
sudo cp /usr/share/webmin/virtual-server/virtual-server-lib-funcs.pl /root/backup-funcs-$(date +%Y%m%d).pl
sudo cp /usr/share/webmin/virtual-server/cloud-lib.pl /root/backup-cloud-$(date +%Y%m%d).pl
```

---

## 🐛 Diagnóstico

```bash
# Errores Perl en Webmin
grep -r "Undefined subroutine\|Can't locate\|syntax error\|Compilation failed" /var/webmin/ 2>/dev/null | tail -30

# Errores recientes
tail -200 /var/webmin/miniserv.error | grep -i "error\|undefined\|failed" | tail -20

# Verificar módulos Perl
find /usr/share/webmin/ -name "*.pl" -exec perl -c {} \; 2>&1 | grep -i "error\|failed" | head -20
```

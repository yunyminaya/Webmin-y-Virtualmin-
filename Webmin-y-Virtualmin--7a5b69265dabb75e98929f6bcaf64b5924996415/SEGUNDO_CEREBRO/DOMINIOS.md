# 🌐 Dominios Gestionados — Webmin & Virtualmin

> Última actualización: 2026-04-28

---

## 📋 Lista de Dominios

### Servidor principal

| Dominio | Tipo | SSL | Estado | Document Root |
|---------|------|-----|--------|---------------|
| vendoto.com | Principal | ✅ Let's Encrypt | Activo | /home/vendoto/public_html |
| *(otros dominios por verificar)* | - | - | - | - |

### Servidor secundario

| Dominio | Tipo | SSL | Estado | Document Root |
|---------|------|-----|--------|---------------|
| *(dominios por verificar)* | - | - | - | - |

---

## 🔍 Comandos de Gestión de Dominios

### Listar Dominios
```bash
# Listar todos los dominios (ejecutar en servidor)
ssh -i "$OPENVM_SSH_KEY" "$OPENVM_SSH_USER@$OPENVM_SRV1_HOST" 'sudo virtualmin list-domains'

# Listar con detalles
ssh -i "$OPENVM_SSH_KEY" "$OPENVM_SSH_USER@$OPENVM_SRV1_HOST" 'sudo virtualmin list-domains --with-status'
```

### Crear Dominio
```bash
# Crear dominio nuevo
ssh -i "$OPENVM_SSH_KEY" "$OPENVM_SSH_USER@$OPENVM_SRV1_HOST" 'sudo virtualmin create-domain --domain nuevo.com --pass "$OPENVM_DOMAIN_PASSWORD" --unix --web --dns --mail'
```

### Eliminar Dominio
```bash
# Eliminar dominio
ssh -i "$OPENVM_SSH_KEY" "$OPENVM_SSH_USER@$OPENVM_SRV1_HOST" 'sudo virtualmin delete-domain --domain dominio.com'
```

### Verificar Dominio
```bash
# Verificar estado HTTP
curl -sk -o /dev/null -w "%{http_code}" https://vendoto.com

# Verificar DNS
dig vendoto.com @"$OPENVM_SRV1_HOST"

# Verificar SSL
echo | openssl s_client -connect vendoto.com:443 -servername vendoto.com 2>/dev/null | openssl x509 -noout -dates
```

---

## 📧 Configuración de Correo por Dominio

### Servicios de Correo
| Servicio | Puerto | Configuración |
|----------|--------|---------------|
| SMTP | 25 / 587 | Postfix con TLS |
| IMAP | 993 | Dovecot con SSL |
| POP3 | 995 | Dovecot con SSL |
| SpamAssassin | - | Filtrado de spam |
| ClamAV | - | Antivirus correo |

### Comandos de Correo
```bash
# Ver cola de correo
ssh -i "$OPENVM_SSH_KEY" "$OPENVM_SSH_USER@$OPENVM_SRV1_HOST" 'sudo mailq'

# Ver logs de correo
ssh -i "$OPENVM_SSH_KEY" "$OPENVM_SSH_USER@$OPENVM_SRV1_HOST" 'sudo tail -50 /var/log/mail.log'

# Ver buzones
ssh -i "$OPENVM_SSH_KEY" "$OPENVM_SSH_USER@$OPENVM_SRV1_HOST" 'sudo ls -la /home/vendoto/Maildir/'
```

---

## 🔒 Certificados SSL por Dominio

### Ubicación de Certificados
```
/etc/letsencrypt/live/
├── vendoto.com/
│   ├── cert.pem
│   ├── chain.pem
│   ├── fullchain.pem
│   └── privkey.pem
└── ...
```

### Renovar Certificado
```bash
# Renovar todos
ssh -i "$OPENVM_SSH_KEY" "$OPENVM_SSH_USER@$OPENVM_SRV1_HOST" 'sudo certbot renew'

# Renovar dominio específico
ssh -i "$OPENVM_SSH_KEY" "$OPENVM_SSH_USER@$OPENVM_SRV1_HOST" 'sudo certbot renew --cert-name vendoto.com'
```

---

## 📊 Estadísticas por Dominio

### Ver Tráfico
```bash
# Tráfico web
ssh -i "$OPENVM_SSH_KEY" "$OPENVM_SSH_USER@$OPENVM_SRV1_HOST" 'sudo cat /home/vendoto/logs/access_log | wc -l'

# Uso de disco
ssh -i "$OPENVM_SSH_KEY" "$OPENVM_SSH_USER@$OPENVM_SRV1_HOST" 'sudo du -sh /home/vendoto/'
```

---

## 🗄️ Bases de Datos por Dominio

### Comandos MySQL
```bash
# Listar bases de datos
ssh -i "$OPENVM_SSH_KEY" "$OPENVM_SSH_USER@$OPENVM_SRV1_HOST" 'sudo mysql -e "SHOW DATABASES;"'

# Ver tablas de una base
ssh -i "$OPENVM_SSH_KEY" "$OPENVM_SSH_USER@$OPENVM_SRV1_HOST" 'sudo mysql -e "USE vendoto; SHOW TABLES;"'
```

---

## 📝 Notas

- Para actualizar la lista de dominios, ejecutar `virtualmin list-domains` en cada servidor
- Los certificados SSL se auto-renuevan cada 60 días
- El backup de dominios se realiza automáticamente vía `auto_backup_system.sh`
- Los logs de cada dominio están en `/home/DOMINIO/logs/`

---

## 🔗 Archivos Relacionados

- [SERVIDORES.md](SERVIDORES.md) — Información de servidores
- [COMANDOS.md](COMANDOS.md) — Comandos frecuentes
- [SEGURIDAD.md](SEGURIDAD.md) — Configuración SSL

# 🖥️ Mapa de Servidores — Webmin & Virtualmin
> Última actualización: 2026-04-28

---

## 📋 Resumen

| ID | Hostname | IP | Rol | SO | Estado |
|----|----------|-----|-----|-----|--------|
| **SRV-1** | *(por verificar)* | `[REDACTED_PRIVATE_IP]` | Producción Principal | Ubuntu/Debian | ✅ Activo |
| **SRV-2** | *(por verificar)* | `[REDACTED_PRIVATE_IP]` | Producción Secundario | Ubuntu/Debian | ✅ Activo |

---

## 🔑 Credenciales de Acceso

### SSH
| Parámetro | Valor |
|-----------|-------|
| **Usuario** | `[REDACTED_USER]` |
| **Contraseña** | `[NO_GUARDAR_EN_GIT]` |
| **Puerto** | `22` |
| **Método recomendado** | SSH key + 2FA, sin password auth |

### Comando de conexión rápida
```bash
# SRV-1
ssh -i "$OPENVM_SSH_KEY" "$OPENVM_SSH_USER@$OPENVM_SRV1_HOST"

# SRV-2
ssh -i "$OPENVM_SSH_KEY" "$OPENVM_SSH_USER@$OPENVM_SRV2_HOST"
```

### Webmin Panel
| Servidor | URL |
|----------|-----|
| SRV-1 | `https://$OPENVM_SRV1_HOST:10000` |
| SRV-2 | `https://$OPENVM_SRV2_HOST:10000` |

---

## 📊 Servicios por Servidor

### SRV-1
| Servicio | Puerto | Estado |
|----------|--------|--------|
| Apache2 | 80/443 | ✅ |
| Nginx (proxy) | - | Verificar |
| MySQL/MariaDB | 3306 | ✅ |
| Postfix (SMTP) | 25/465/587 | ✅ |
| Dovecot (IMAP) | 993/143 | ✅ |
| BIND9 (DNS) | 53 | ✅ |
| Webmin | 10000 | ✅ |
| SSH | 22 | ✅ |

### SRV-2
| Servicio | Puerto | Estado |
|----------|--------|--------|
| Apache2 | 80/443 | ✅ |
| Nginx (proxy) | - | Verificar |
| MySQL/MariaDB | 3306 | ✅ |
| Postfix (SMTP) | 25/465/587 | ✅ |
| Dovecot (IMAP) | 993/143 | ✅ |
| BIND9 (DNS) | 53 | ✅ |
| Webmin | 10000 | ✅ |
| SSH | 22 | ✅ |

---

## 🔧 Rutas Importantes en Servidores

| Ruta | Descripción |
|------|-------------|
| `/usr/share/webmin/` | Instalación de Webmin |
| `/usr/share/webmin/virtual-server/` | Módulo Virtualmin |
| `/usr/share/webmin/virtual-server/pro/` | Features Pro (stubs GPL) |
| `/var/webmin/` | Logs y configuración Webmin |
| `/var/webmin/miniserv.error` | Log de errores Webmin |
| `/etc/apache2/` | Configuración Apache |
| `/etc/postfix/` | Configuración Postfix |
| `/etc/dovecot/` | Configuración Dovecot |
| `/etc/bind/` | Configuración DNS |
| `/usr/local/bin/openvm-pro-unlock` | Script persistente de parches |
| `/usr/local/bin/openvm-patch-cloud-lib` | Script persistente cloud-lib |

---

## 🛡️ Systemd Watchers (Parches Persistentes)

| Servicio | Archivo Monitoreado | Script |
|----------|---------------------|--------|
| `openvm-gpl-watcher.path` | `virtual-server-lib-funcs.pl` | `/usr/local/bin/openvm-pro-unlock` |
| `openvm-cloud-lib-watcher.path` | `cloud-lib.pl` | `/usr/local/bin/openvm-patch-cloud-lib` |

### Verificar estado watchers
```bash
systemctl is-active openvm-gpl-watcher.path
systemctl is-active openvm-cloud-lib-watcher.path
```

---

## 📝 Notas
- Los hosts reales se inyectan por variables de entorno locales o gestor de secretos
- Los parches GPL se re-aplican automáticamente cuando Webmin se actualiza
- Los backups de parches están en `/root/openvm-unlock-backup-*`

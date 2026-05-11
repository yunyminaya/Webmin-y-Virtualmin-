# 🖥️ Mapa de Servidores — Webmin & Virtualmin
> Última actualización: 2026-04-28

---

## 📋 Resumen

| ID | Hostname | IP | Rol | SO | Estado |
|----|----------|-----|-----|-----|--------|
| **SRV-1** | *(por verificar)* | `192.168.1.39` | Producción Principal | Ubuntu/Debian | ✅ Activo |
| **SRV-2** | *(por verificar)* | `192.168.1.46` | Producción Secundario | Ubuntu/Debian | ✅ Activo |

---

## 🔑 Credenciales de Acceso

### SSH
| Parámetro | Valor |
|-----------|-------|
| **Usuario** | `yuny` |
| **Contraseña** | `Ymo55095509` |
| **Puerto** | `22` |
| **Método** | Password Auth |

### Comando de conexión rápida
```bash
# SRV-1 (192.168.1.39)
sshpass -p 'Ymo55095509' ssh -o StrictHostKeyChecking=no yuny@192.168.1.39

# SRV-2 (192.168.1.46)
sshpass -p 'Ymo55095509' ssh -o StrictHostKeyChecking=no yuny@192.168.1.46
```

### Webmin Panel
| Servidor | URL |
|----------|-----|
| SRV-1 | `https://192.168.1.39:10000` |
| SRV-2 | `https://192.168.1.46:10000` |

---

## 📊 Servicios por Servidor

### SRV-1 (192.168.1.39)
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

### SRV-2 (192.168.1.46)
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
- Ambos servidores están en red local (192.168.1.x)
- Los parches GPL se re-aplican automáticamente cuando Webmin se actualiza
- Los backups de parches están en `/root/openvm-unlock-backup-*`

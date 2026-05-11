# 🏗️ Arquitectura del Sistema — Webmin & Virtualmin

> Última actualización: 2026-04-28

---

## 🌐 Vista General de la Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│                    INTERNET / DNS                        │
│                  (CloudFlare / BIND9)                    │
└──────────────────────┬──────────────────────────────────┘
                       │
              ┌────────┴────────┐
              │   Load Balancer │
              │   / Reverse Proxy│
              └────────┬────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
┌───────┴──────┐ ┌────┴─────┐ ┌─────┴──────┐
│  SERVIDOR 1  │ │ FIREWALL │ │ SERVIDOR 2  │
│ 192.168.1.39 │ │    ML    │ │ 192.168.1.46│
│  (Primary)   │ │ + Zero   │ │ (Secondary) │
│              │ │  Trust   │ │              │
│ ┌──────────┐ │ │          │ │ ┌──────────┐ │
│ │ Webmin   │ │ │          │ │ │ Webmin   │ │
│ │ :10000   │ │ │          │ │ │ :10000   │ │
│ ├──────────┤ │ │          │ │ ├──────────┤ │
│ │ Apache   │ │ │          │ │ │ Apache   │ │
│ │ :80/443  │ │ │          │ │ │ :80/443  │ │
│ ├──────────┤ │ │          │ │ ├──────────┤ │
│ │ MySQL    │ │ │          │ │ │ MySQL    │ │
│ │ :3306    │ │ │          │ │ │ :3306    │ │
│ ├──────────┤ │ │          │ │ ├──────────┤ │
│ │ Postfix  │ │ │          │ │ │ Postfix  │ │
│ │ :25/587  │ │ │          │ │ │ :25/587  │ │
│ ├──────────┤ │ │          │ │ ├──────────┤ │
│ │ Dovecot  │ │ │          │ │ │ Dovecot  │ │
│ │ :993/995 │ │ │          │ │ │ :993/995 │ │
│ ├──────────┤ │ │          │ │ ├──────────┤ │
│ │ BIND9    │ │ │          │ │ │ BIND9    │ │
│ │ :53      │ │ │          │ │ │ :53      │ │
│ └──────────┘ │ │          │ │ └──────────┘ │
│              │ │          │ │              │
│ ┌──────────┐ │ │          │ │ ┌──────────┐ │
│ │ OpenVM   │ │ │          │ │ │ OpenVM   │ │
│ │ Modules  │ │ │          │ │ │ Modules  │ │
│ │ (20+)    │ │ │          │ │ │ (20+)    │ │
│ └──────────┘ │ │          │ │ └──────────┘ │
│              │ │          │ │              │
│ ┌──────────┐ │ │          │ │ ┌──────────┐ │
│ │ SIEM +   │ │ │          │ │ │ SIEM +   │ │
│ │ Blockch. │ │ │          │ │ │ Blockch. │ │
│ └──────────┘ │ │          │ │ └──────────┘ │
└──────────────┘ └──────────┘ └──────────────┘
        │                            │
        └────────────┬───────────────┘
                     │
        ┌────────────┴───────────────┐
        │     STORAGE / BACKUP       │
        │  ┌──────┐  ┌───────────┐  │
        │  │ Local │  │ Multi-    │  │
        │  │ Disk  │  │ Cloud     │  │
        │  └──────┘  │ (AWS/GCP/ │  │
        │            │  Azure)    │  │
        │            └───────────┘  │
        └───────────────────────────┘
```

---

## 🧩 Componentes del Sistema

### 1. Capa de Red
| Componente | Tecnología | Puerto | Función |
|------------|-----------|--------|---------|
| DNS | BIND9 | 53 | Resolución de dominios |
| Reverse Proxy | Apache/Nginx | 80/443 | Proxy inverso + SSL |
| Firewall | iptables + ML | - | Filtrado inteligente |
| VPN/Tunnel | SSH Tunnels | 22 | Acceso seguro remoto |

### 2. Capa de Aplicación
| Componente | Tecnología | Puerto | Función |
|------------|-----------|--------|---------|
| Panel Webmin | Perl CGI | 10000 | Administración del servidor |
| Virtualmin | Perl CGI | 10000 | Gestión de hosting |
| OpenVM Modules | Perl CGI | 10000 | Módulos personalizados |
| Authentic Theme | Perl/JS/CSS | 10000 | Interfaz moderna |

### 3. Capa de Datos
| Componente | Tecnología | Puerto | Función |
|------------|-----------|--------|---------|
| Base de Datos | MySQL/MariaDB | 3306 | Datos de dominios y usuarios |
| Email Store | Dovecot | 993/995 | Almacenamiento de correo |
| File System | ext4/xfs | - | Archivos de sitios web |
| Logs | rsyslog | - | Registros del sistema |

### 4. Capa de Seguridad
| Componente | Tecnología | Función |
|------------|-----------|---------|
| SIEM | Bash + Python + Blockchain | Correlación de eventos |
| Zero Trust | Perl | Verificación continua |
| Firewall ML | Python + iptables | Bloqueo inteligente |
| IDS/IPS | Suricata + Custom | Detección de intrusos |
| DDoS Shield | iptables + rate limiting | Protección DDoS |
| SSL/TLS | Let's Encrypt + Custom | Cifrado de comunicaciones |

### 5. Capa de Automatización
| Componente | Tecnología | Función |
|------------|-----------|---------|
| AI Optimizer | Python + ML | Optimización automática |
| Auto Backup | Bash + Python | Backup inteligente |
| Auto Repair | Bash | Auto-reparación |
| Auto Update | Bash | Actualización segura |
| Watchers | systemd | Monitoreo de parches |

### 6. Capa de Infraestructura
| Componente | Tecnología | Función |
|------------|-----------|---------|
| IaC | Terraform | Infraestructura como código |
| Config Management | Ansible | Configuración automatizada |
| Containers | Docker | Contenedores aislados |
| Orchestration | Kubernetes | Orquestación de contenedores |
| CI/CD | GitHub Actions | Integración continua |

---

## 📁 Estructura de Directorios en Servidor

```
/usr/share/webmin/                    # Webmin root
├── virtual-server/                   # Virtualmin module
│   ├── virtual-server-lib.pl         # Librería principal
│   ├── virtual-server-lib-funcs.pl   # Funciones (PATCHED)
│   ├── cloud-lib.pl                  # Cloud functions (PATCHED)
│   ├── module.info                   # Info del módulo
│   ├── pro/                          # Pro features (STUBS)
│   │   ├── openvm-compat-lib.pl      # Librería compat
│   │   ├── history.cgi               # Historial
│   │   ├── connectivity.cgi          # Conectividad
│   │   ├── edit_html.cgi             # Editor HTML
│   │   ├── maillog.cgi               # Log correo
│   │   └── ... (16 CGIs)
│   ├── *.cgi                         # CGI scripts GPL
│   └── *.pl                          # Librerías Perl
├── openvm-core/                      # OpenVM Core
├── openvm-admin/                     # OpenVM Admin
├── openvm-dns/                       # OpenVM DNS
├── openvm-backup/                    # OpenVM Backup
├── openvm-suite/                     # OpenVM Suite
├── openvm-dashboard/                 # OpenVM Dashboard
├── openvm-ssl/                       # OpenVM SSL
├── openvm-php/                       # OpenVM PHP
├── openvm-cron/                      # OpenVM Cron
├── openvm-scripts/                   # OpenVM Scripts
├── openvm-notifications/             # OpenVM Notifications
├── openvm-billing/                   # OpenVM Billing
├── openvm-mail/                      # OpenVM Mail
├── openvm-monitoring/                # OpenVM Monitoring
├── openvm-db/                        # OpenVM Database
├── openvm-ssh/                       # OpenVM SSH
├── openvm-batch/                     # OpenVM Batch
├── openvm-api/                       # OpenVM API
├── intelligent-firewall/             # Firewall Inteligente
├── siem/                             # SIEM System
├── zero-trust/                       # Zero Trust
└── authentic-theme/                  # Authentic Theme

/var/webmin/                          # Webmin datos variables
/var/log/webmin/                      # Logs de Webmin
/etc/webmin/                          # Configuración Webmin
/etc/apache2/                         # Configuración Apache
/etc/mysql/                           # Configuración MySQL
/etc/postfix/                         # Configuración Postfix
/etc/dovecot/                         # Configuración Dovecot
/etc/bind/                            # Configuración BIND9

/usr/local/bin/
├── openvm-pro-unlock                 # Script parche persistente
└── openvm-patch-cloud-lib            # Script parche cloud-lib

/etc/systemd/system/
├── openvm-gpl-watcher.path           # Watcher lib-funcs
├── openvm-gpl-watcher.service        # Servicio re-parche
├── openvm-cloud-lib-watcher.path     # Watcher cloud-lib
└── openvm-cloud-lib-watcher.service  # Servicio re-parche

/home/                                # Dominios virtuales
├── domain1.com/
│   ├── public_html/
│   ├── logs/
│   └── cgi-bin/
└── domain2.com/
    ├── public_html/
    ├── logs/
    └── cgi-bin/

/var/lib/mysql/                       # Bases de datos MySQL
/var/mail/                            # Correo electrónico
/var/spool/postfix/                   # Cola de correo
```

---

## 🔄 Flujo de una Petición HTTP

```
1. Cliente → DNS (resuelve dominio)
2. DNS → IP del servidor
3. Cliente → Apache :443 (SSL)
4. Apache → VirtualHost (mapea dominio → /home/domain/public_html)
5. Si es *.cgi → Perl CGI → Webmin/Virtualmin
6. Si es PHP → PHP-FPM → procesa
7. Si es estático → sirve archivo directamente
8. Apache → Cliente (respuesta)
```

---

## 🔐 Flujo de Autenticación Webmin

```
1. Navegador → https://server:10000/
2. Webmin → Session login (Authentic Theme)
3. Usuario + Password → verificación PAM
4. Si válido → sesión + cookie
5. Cada petición → verificar sesión
6. RBAC → verificar permisos del rol
7. Zero Trust → verificación continua
```

---

## 📊 Flujo del Sistema de Seguridad

```
1. Tráfico entrante → Firewall ML
2. Firewall ML → analizar patrones
3. Si anómalo → bloquear + alertar SIEM
4. SIEM → correlacionar eventos
5. SIEM → registrar en Blockchain (inmutable)
6. Si crítico → alerta + auto-bloqueo
7. Zero Trust → verificar identidad continuamente
8. IDS/IPS → inspeccionar paquetes
```

---

## 🔗 Archivos Relacionados

- [SERVIDORES.md](SERVIDORES.md) — Detalle de servidores
- [MODULOS.md](MODULOS.md) — Catálogo de módulos
- [SEGURIDAD.md](SEGURIDAD.md) — Configuración de seguridad
- [GPL_PATCHES.md](GPL_PATCHES.md) — Parches aplicados

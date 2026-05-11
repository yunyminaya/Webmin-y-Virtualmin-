# 🛡️ Configuración de Seguridad — Webmin & Virtualmin

> Última actualización: 2026-04-28

---

## 📋 Resumen de Seguridad

| Capa | Sistema | Estado | Servidor |
|------|---------|--------|----------|
| Firewall | Intelligent Firewall + ML | ✅ Activo | Ambos |
| SIEM | Correlación + Blockchain | ✅ Activo | Ambos |
| Zero Trust | Verificación continua | ✅ Activo | Ambos |
| IDS/IPS | Detección de intrusos | ✅ Activo | Ambos |
| DDoS Shield | Protección L3/L4/L7 | ✅ Activo | Ambos |
| SSL/TLS | Let's Encrypt + Auto-renovación | ✅ Activo | Ambos |
| AI Defense | Defensa con IA | ✅ Activo | Ambos |
| RBAC | Control de acceso basado en roles | ✅ Activo | Ambos |

---

## 🔥 Firewall Inteligente (ML)

### Ubicación
- **Módulo**: `/usr/share/webmin/intelligent-firewall/`
- **Config**: `intelligent-firewall/config`

### Componentes
| Archivo | Función |
|---------|---------|
| `ml_engine.py` | Motor de Machine Learning para detección |
| `traffic_analyzer.pl` | Análisis de tráfico en tiempo real |
| `anomaly_detector.pl` | Detección de anomalías |
| `smart_lists.pl` | Listas inteligentes (allow/block) |
| `dynamic_rules.pl` | Reglas dinámicas adaptativas |
| `adaptive_blocker.pl` | Bloqueo adaptativo |
| `ids_integration.pl` | Integración con IDS/IPS |
| `train_model.pl` | Entrenamiento del modelo ML |

### Configuración
```bash
# Ver reglas del firewall
iptables -L -n -v

# Ver estado del módulo
ls -la /usr/share/webmin/intelligent-firewall/

# Entrenar modelo
perl /usr/share/webmin/intelligent-firewall/train_model.pl
```

---

## 🔍 SIEM (Security Information and Event Management)

### Ubicación
- **Módulo**: `/usr/share/webmin/siem/`
- **Base de datos**: SQLite (inicializada por `init_siem_db.sh`)

### Componentes
| Archivo | Función |
|---------|---------|
| `correlation_engine.sh` | Motor de correlación de eventos |
| `ml_anomaly_detector.py` | Detección de anomalías con ML |
| `alert_manager.sh` | Gestión de alertas |
| `log_collector.sh` | Recolección de logs |
| `compliance_checker.sh` | Verificación de cumplimiento |
| `report_generator.sh` | Generación de reportes |
| `forensic_analyzer.sh` | Análisis forense |
| `blockchain.py` | Cadena de bloques para logs inmutables |
| `blockchain_manager.py` | Gestor de blockchain |

### Blockchain para Logs
- **Función**: Registro inmutable de eventos de seguridad
- **Algoritmo**: SHA-256 hashing
- **Estructura**: Cada bloque contiene hash anterior + datos del evento
- **Verificación**: `forensic_blockchain_search.cgi`

### Comandos
```bash
# Inicializar SIEM
bash /usr/share/webmin/siem/init_siem_db.sh

# Verificar blockchain
python3 /usr/share/webmin/siem/blockchain_manager.py --verify

# Generar reporte
bash /usr/share/webmin/siem/report_generator.sh
```

---

## 🔐 Zero Trust

### Ubicación
- **Módulo**: `/usr/share/webmin/zero-trust/`

### Componentes
| Archivo | Función |
|---------|---------|
| `zero-trust-lib.pl` | Librería principal |
| `continuous_monitor.pl` | Monitoreo continuo de sesiones |
| `dynamic_policies.pl` | Políticas dinámicas |
| `e2e_encryption_setup.pl` | Configuración E2E encryption |
| `install.pl` | Instalador del módulo |

### Principios Implementados
1. **Nunca confiar, siempre verificar** — Cada acceso requiere autenticación
2. **Menor privilegio** — Solo acceso necesario para la función
3. **Micro-segmentación** — Cada servicio aislado
4. **Monitoreo continuo** — Verificación en tiempo real
5. **Políticas dinámicas** — Adaptación según contexto

---

## 🚫 Protección DDoS

### Script: `ddos_shield_extreme.sh`

### Capas de Protección
| Capa | Técnica | Configuración |
|------|---------|---------------|
| L3/L4 | Rate limiting ICMP/UDP | iptables limit |
| L4 | SYN flood protection | SYN cookies |
| L4 | Connection limiting | max connections per IP |
| L7 | HTTP rate limiting | mod_evasive / custom |
| L7 | Request pattern analysis | ML detection |

### Comandos
```bash
# Activar protección DDoS
bash ddos_shield_extreme.sh

# Ver conexiones activas
ss -tunlp | grep -c ESTAB

# Ver IPs bloqueadas
iptables -L DDOS_BLOCK -n 2>/dev/null
```

---

## 🔒 SSL/TLS

### Certificados
- **Proveedor**: Let's Encrypt
- **Auto-renovación**: `ssl_renewal.cron` + `ssl_monitor.timer`
- **Servicios cubiertos**: Apache, Postfix, Dovecot, Webmin

### Archivos de Configuración
| Archivo | Servicio |
|---------|----------|
| `configs/apache/httpd.conf` | Apache SSL |
| `nginx_ssl.conf` | Nginx SSL |
| `postfix_ssl.conf` | Postfix SSL |
| `dovecot_ssl.conf` | Dovecot SSL |
| `ssl_dashboard_apache.conf` | Dashboard SSL |

### Comandos SSL
```bash
# Verificar certificado
openssl x509 -in /etc/letsencrypt/live/domain.com/cert.pem -text -noout | grep -E "Issuer|Not After"

# Renovar certificado
certbot renew --force-renewal

# Verificar SSL de un dominio
curl -sk -o /dev/null -w "%{ssl_verify_result}\n" https://domain.com
```

---

## 👤 RBAC (Role-Based Access Control)

### Ubicación
- **Librería**: `virtualmin-gpl-master/rbac-lib.pl`
- **Políticas**: `virtualmin-gpl-master/conditional-policies-lib.pl`
- **Dashboard**: `virtualmin-gpl-master/rbac_dashboard.cgi`
- **Instalador**: `virtualmin-gpl-master/rbac_install.pl`

### Roles Definidos
| Rol | Permisos |
|-----|----------|
| Admin | Acceso total al servidor |
| Reseller | Gestión de sus dominios |
| User | Solo su dominio |
| Auditor | Solo lectura + logs |

---

## 🤖 AI Defense System

### Script: `ai_defense_system.sh`

### Capacidades
- Detección de patrones anómalos
- Bloqueo automático de IPs maliciosas
- Análisis de comportamiento
- Predicción de ataques
- Auto-aprendizaje de patrones

---

## 📊 Auditoría de Seguridad

### Última Auditoría
- **Script**: `security_audit_system.sh`
- **Reporte**: `security_audit_report_*.html`
- **Documentación**: `SECURITY_AUDIT_REPORT_FINAL.md`

### Verificaciones
- [x] Puertos innecesarios cerrados
- [x] SSH con contraseña fuerte
- [x] Firewall activo
- [x] SSL en todos los servicios
- [x] Logs de acceso habilitados
- [x] Rate limiting configurado
- [x] IDS/IPS activo
- [x] SIEM funcionando
- [x] Zero Trust implementado
- [x] RBAC configurado

---

## 🔑 Credenciales (Referencia)

> ⚠️ **IMPORTANTE**: Las credenciales están en [SERVIDORES.md](SERVIDORES.md)

### Buenas Prácticas
1. Cambiar contraseñas cada 90 días
2. Usar SSH keys cuando sea posible
3. Habilitar 2FA en Webmin
4. Rotar claves API regularmente
5. Auditar accesos semanalmente

---

## 🔗 Archivos Relacionados

- [SERVIDORES.md](SERVIDORES.md) — Credenciales y acceso
- [ARQUITECTURA.md](ARQUITECTURA.md) — Arquitectura del sistema
- [SOLUCIONES.md](SOLUCIONES.md) — Problemas resueltos
- [COMANDOS.md](COMANDOS.md) — Comandos de diagnóstico

---

## 🔒 Kernel Linux — Vulnerabilidades y Remediación (Mayo 2026)

### CVEs Críticos Recientes del Kernel

| CVE | Descripción | Kernels Afectados | Severidad |
|-----|-------------|-------------------|-----------|
| CVE-2024-1086 | nf_tables use-after-free | 5.x - 6.x | CRÍTICA |
| CVE-2024-0193 | io_uring use-after-free | 5.x - 6.7 | ALTA |
| CVE-2024-0582 | io_uring memory overwrite | 5.x - 6.7 | ALTA |
| CVE-2024-21626 | runc container escape | contenedores | CRÍTICA |
| CVE-2024-41009 | bpf ringbuf privilege escalation | 6.x | ALTA |
| CVE-2024-53677 | ALSA scarlett2 OOB write | 6.x | ALTA |
| CVE-2025-0677 | HID OOB write | 6.x | ALTA |
| CVE-2025-21703 | KVM x86 privilege escalation | 6.x | CRÍTICA |
| CVE-2026-43275 | Kernel Medium (Ubuntu 22.04/24.04) | 5.15, 6.8, 6.11 | MEDIA |
| CVE-2026-43276 | Kernel Medium (Ubuntu 22.04/24.04) | 5.15, 6.8, 6.11 | MEDIA |
| CVE-2026-43277 | Kernel Medium (Ubuntu 22.04/24.04) | 5.15, 6.8, 6.11 | MEDIA |
| CVE-2026-43278 | Kernel Medium (Ubuntu 22.04/24.04) | 5.15, 6.8, 6.11 | MEDIA |
| CVE-2026-43279 | Kernel Medium (Ubuntu 22.04/24.04) | 5.15, 6.8, 6.11 | MEDIA |
| CVE-2026-43280 | Kernel Medium (Ubuntu 22.04/24.04) | 5.15, 6.8, 6.11 | MEDIA |
| CVE-2026-43281 | Kernel Medium (Ubuntu 22.04/24.04) | 5.15, 6.8, 6.11 | MEDIA |
| CVE-2026-43282 | Kernel Medium (Ubuntu 22.04/24.04) | 5.15, 6.8, 6.11 | MEDIA |
| CVE-2026-43283 | Kernel Medium (Ubuntu 22.04/24.04) | 5.15, 6.8, 6.11 | MEDIA |
| CVE-2026-43284 | Kernel Medium (Ubuntu 22.04/24.04) | 5.15, 6.8, 6.11 | MEDIA |

### Script de Auditoría y Remediación

Archivo: `kernel_security_audit.sh`

Ejecutar en servidores:
```bash
sudo bash kernel_security_audit.sh
```

Funciones del script:
1. **Verificación de versión** - Detecta kernels vulnerables
2. **CVE-2024-1086** - Verifica nf_tables activo
3. **CVE-2024-0193/0582** - Verifica io_uring
4. **Integridad del kernel** - Detecta rootkits y módulos sospechosos
5. **Hardening** - Aplica sysctl de seguridad
6. **Compromiso** - Detecta procesos ocultos, ld.so.preload, puertos inusuales
7. **Actualización** - Actualiza kernel vía apt/dnf/yum

### Hardening Aplicado (sysctl)

```bash
kernel.kptr_restrict = 1          # Ocultar direcciones del kernel
kernel.dmesg_restrict = 1         # Restringir dmesg
kernel.kexec_load_disabled = 1    # Prevenir carga de kernel malicioso
kernel.randomize_va_space = 2     # ASLR completo
kernel.unprivileged_bpf_disabled = 1  # Deshabilitar BPF no privilegiado
kernel.yama.ptrace_scope = 2      # Restringir ptrace
kernel.io_uring_disabled = 2      # Restringir io_uring
fs.protected_symlinks = 1         # Protección contra symlinks
fs.protected_hardlinks = 1        # Protección contra hardlinks
fs.suid_dumpable = 0              # Sin core dumps de SUID
```

### Licencia GPL/PRO — Candados Eliminados

Commit: `da189b8` - Agregadas 14 funciones UI lock removal en `openvm-license-layer.pl`

Funciones clave:
- `licence_status()` → vacío (sin advertencias)
- `is_pro_available()` → 1 (PRO activo)
- `show_licence_upgrade_link()` → 0 (sin enlace upgrade)
- `is_gpl()` → 0 (no limitado)
- `can_use_pro_feature()` → 1 (siempre accesible)

### Referencia Ubuntu
- https://ubuntu.com/security/cves
- https://ubuntu.com/security/notices
- `pro audit` (Ubuntu Pro)
- `ua fix CVE-2024-1086` (Ubuntu Advantage)

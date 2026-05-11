# 📜 Catálogo de Scripts — Webmin & Virtualmin

> Última actualización: 2026-04-28

---

## 📋 Índice de Scripts

| # | Script | Ubicación | Función | Servidor |
|---|--------|-----------|---------|----------|
| 1 | `instalar_webmin_virtualmin.sh` | `/` | Instalación completa de Webmin + Virtualmin | Ambos |
| 2 | `install.sh` | `/` | Instalador principal del proyecto | Ambos |
| 3 | `install_openvm_suite.sh` | `/` | Instala la suite completa OpenVM | Ambos |
| 4 | `install_openvm_production.sh` | `/` | Instalación de OpenVM para producción | Ambos |
| 5 | `pro_activation_master.sh` | `/` | Activación master de funciones Pro | Ambos |
| 6 | `auto_repair.sh` | `/` | Auto-reparación del sistema | Ambos |
| 7 | `intelligent_auto_update.sh` | `/` | Actualización inteligente automática | Ambos |
| 8 | `auto_backup_system.sh` | `/` | Sistema de backup automático | Ambos |
| 9 | `enterprise_monitoring_setup.sh` | `/` | Configuración de monitoreo empresarial | Ambos |
| 10 | `advanced_monitoring.sh` | `/` | Monitoreo avanzado del sistema | Ambos |

---

## 🔧 Scripts de Instalación

### `instalar_webmin_virtualmin.sh`
- **Función**: Instalación completa de Webmin y Virtualmin desde cero
- **Uso**: `bash instalar_webmin_virtualmin.sh`
- **Requiere**: Root, Ubuntu/Debian
- **Instala**: Webmin, Virtualmin, Apache, MySQL, Postfix, Dovecot, BIND

### `install.sh`
- **Función**: Instalador principal del repositorio
- **Uso**: `bash install.sh`
- **Incluye**: Verificación de dependencias, configuración inicial

### `install_openvm_suite.sh`
- **Función**: Instala todos los módulos OpenVM
- **Uso**: `bash install_openvm_suite.sh`
- **Módulos**: openvm-core, openvm-admin, openvm-dns, openvm-backup, openvm-suite

### `install_openvm_production.sh`
- **Función**: Instalación optimizada para producción
- **Uso**: `bash install_openvm_production.sh`
- **Incluye**: Tests de integración, configuración de seguridad

---

## 🔓 Scripts de Activación Pro

### `pro_activation_master.sh`
- **Función**: Activa todas las funciones Pro de Virtualmin
- **Uso**: `bash pro_activation_master.sh`
- **Efecto**: Parcha `virtual-server-lib-funcs.pl`, `cloud-lib.pl`, crea CGIs en `pro/`

### `pro_features_advanced.sh`
- **Función**: Funciones Pro avanzadas adicionales
- **Uso**: `bash pro_features_advanced.sh`

### `remove_license_warning.sh`
- **Función**: Elimina advertencias de licencia del panel
- **Uso**: `bash remove_license_warning.sh`

### `diagnostico_pro_gpl.sh`
- **Función**: Diagnóstico completo del estado Pro/GPL
- **Uso**: `bash diagnostico_pro_gpl.sh`

---

## 🛡️ Scripts de Seguridad

### `ai_defense_system.sh`
- **Función**: Sistema de defensa con IA
- **Incluye**: Detección de anomalías, bloqueo automático
- **Uso**: `bash ai_defense_system.sh`

### `ddos_shield_extreme.sh`
- **Función**: Protección DDoS extrema
- **Uso**: `bash ddos_shield_extreme.sh`
- **Capas**: L3/L4/L7, rate limiting, IP blacklist

### `security_audit_system.sh`
- **Función**: Auditoría completa de seguridad
- **Uso**: `bash security_audit_system.sh`
- **Genera**: Reporte HTML con hallazgos

### `install_ai_protection.sh`
- **Función**: Instala protección con IA
- **Uso**: `bash install_ai_protection.sh`

### Scripts en `security/`
| Script | Función |
|--------|---------|
| `config_validator.sh` | Validación de configuraciones |
| `encrypt_sensitive_data.sh` | Encriptación de datos sensibles |
| `input_sanitizer_secure.sh` | Saneamiento de entradas |
| `install_security_systems.sh` | Instalador de sistemas de seguridad |
| `mitigate_p0_critical_vulnerabilities.sh` | Mitigación de vulnerabilidades críticas |
| `secret_manager.sh` | Gestión de secretos |
| `secure_credentials_generator.sh` | Generador de credenciales seguras |

---

## 📊 Scripts de Monitoreo

### `monitor_sistema.sh`
- **Función**: Monitoreo general del sistema
- **Métricas**: CPU, RAM, Disco, Red, Servicios

### `advanced_monitoring.sh`
- **Función**: Monitoreo avanzado con alertas
- **Uso**: `bash advanced_monitoring.sh`

### `install_advanced_monitoring.sh`
- **Función**: Instala el sistema de monitoreo avanzado
- **Uso**: `bash install_advanced_monitoring.sh`

### `continuous_monitoring.sh`
- **Función**: Monitoreo continuo en background
- **Uso**: `bash continuous_monitoring.sh &`

---

## ☁️ Scripts de Infraestructura

### `docker_container_orchestration.sh`
- **Función**: Orquestación de contenedores Docker
- **Uso**: `bash docker_container_orchestration.sh`

### `kubernetes_orchestration.sh`
- **Función**: Orquestación con Kubernetes
- **Uso**: `bash kubernetes_orchestration.sh`

### `auto_scaling_system.sh`
- **Función**: Auto-escalado de recursos
- **Uso**: `bash auto_scaling_system.sh`

### `advanced_networking_system.sh`
- **Función**: Sistema de red avanzada
- **Uso**: `bash advanced_networking_system.sh`

### `persistent_volume_management.sh`
- **Función**: Gestión de volúmenes persistentes
- **Uso**: `bash persistent_volume_management.sh`

---

## 🔄 Scripts de Backup y Recuperación

### `auto_backup_system.sh`
- **Función**: Backup automático del sistema completo
- **Incluye**: Backup de BD, configuraciones, certificados, dominios

### `enterprise_backup.cron`
- **Función**: Cron job de backup empresarial
- **Instalación**: Copiar a `/etc/cron.d/`

### `auto_restore_universal.sh`
- **Función**: Restauración universal desde backup
- **Uso**: `bash auto_restore_universal.sh`

---

## 🌐 Scripts de Red y Túneles

### `auto_tunnel_system.sh`
- **Función**: Sistema de túneles automáticos
- **Uso**: `bash auto_tunnel_system.sh`

### `install_auto_tunnel_system.sh`
- **Función**: Instala el sistema de túneles
- **Uso**: `bash install_auto_tunnel_system.sh`

### `auto-tunnel.service`
- **Función**: Servicio systemd para túneles
- **Instalación**: Copiar a `/etc/systemd/system/`

---

## 🏗️ Scripts de Cluster

### En `cluster_infrastructure/`
| Script | Función |
|--------|---------|
| `deploy-cluster.sh` | Despliegue del cluster completo |
| `verify-deployment.sh` | Verificación del despliegue |
| `unlimited-servers-demo.sh` | Demo de escalado ilimitado |

### En `scripts/`
| Script | Función |
|--------|---------|
| `rollout_openvm_update.sh` | Rollout de actualizaciones OpenVM |
| `create-release-branch.sh` | Crear branch de release |
| `create-feature-branch.sh` | Crear branch de feature |
| `merge-release.sh` | Merge de release |
| `run_all_tests.sh` | Ejecutar todos los tests |

---

## 🔧 Scripts Persistentes en Servidores

### `/usr/local/bin/openvm-pro-unlock`
- **Función**: Re-aplica todos los parches GPL después de actualizaciones
- **Ejecución**: Automática vía systemd watcher
- **Servidores**: 192.168.1.39, 192.168.1.46

### `/usr/local/bin/openvm-patch-cloud-lib`
- **Función**: Re-aplica parches a `cloud-lib.pl`
- **Ejecución**: Automática vía systemd watcher
- **Servidores**: 192.168.1.39, 192.168.1.46

---

## 📝 Notas

- Todos los scripts requieren permisos de ejecución: `chmod +x script.sh`
- Los scripts de instalación requieren acceso root
- Los scripts persistentes se ejecutan automáticamente vía systemd
- Siempre hacer backup antes de ejecutar scripts de modificación del sistema

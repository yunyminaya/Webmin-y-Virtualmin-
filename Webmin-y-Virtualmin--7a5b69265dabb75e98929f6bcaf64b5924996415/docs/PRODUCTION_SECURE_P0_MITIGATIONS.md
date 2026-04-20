# Mitigaciones P0 Críticas - Producción Segura

## Documentación de Implementación de Seguridad P0 Crítica

Este documento describe las mitigaciones P0 críticas implementadas para asegurar el sistema en producción, eliminando vulnerabilidades de seguridad críticas relacionadas con credenciales por defecto, exposición de secretos, y validación de entradas.

---

## Tabla de Contenidos

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Vulnerabilidades P0 Corregidas](#vulnerabilidades-p0-corregidas)
3. [Arquitectura de Seguridad](#arquitectura-de-seguridad)
4. [Implementación](#implementación)
5. [Validación](#validación)
6. [Mantenimiento](#mantenimiento)
7. [Procedimientos de Emergencia](#procedimientos-de-emergencia)

---

## Resumen Ejecutivo

### Problemas Identificados

Se identificaron **vulnerabilidades P0 críticas** en el sistema:

1. **Credenciales por defecto** (`admin/admin123`) en múltiples scripts
2. **Exposición de secretos** en logs y stdout
3. **Falta de sanitización** de entradas a `system()` y `subprocess.run()`
4. **Validación insuficiente** de archivos de entorno
5. **Ausencia de rotación** de credenciales

### Soluciones Implementadas

✅ **Generador de credenciales únicas** por despliegue  
✅ **Sanitizador de entradas** contra inyección de comandos  
✅ **Validación de archivos de entorno** con allowlist  
✅ **Eliminación de credenciales por defecto**  
✅ **Prevención de exposición de secretos** en logs  
✅ **Sistema de rotación automática** de credenciales  
✅ **Permisos seguros** (600, root:root) para archivos sensibles  

---

## Vulnerabilidades P0 Corregidas

### 1. Credenciales por Defecto Eliminadas

#### Archivos Afectados

| Archivo | Líneas | Credenciales | Estado |
|----------|---------|---------------|---------|
| [`scripts/setup_monitoring_system.sh`](../scripts/setup_monitoring_system.sh) | 120, 121, 292, 293, 920, 1080 | `admin/admin123` | ✅ Corregido |
| [`scripts/orchestrate_virtualmin_enterprise.sh`](../scripts/orchestrate_virtualmin_enterprise.sh) | 403, 404 | `admin/admin123` | ✅ Corregido |
| [`monitoring/prometheus_grafana_integration.py`](../monitoring/prometheus_grafana_integration.py) | 71, 72 | `admin/admin123` | ✅ Corregido |

#### Solución Implementada

**Antes:**
```bash
admin_user: "admin"
admin_password: "admin123"
```

**Después:**
```bash
admin_user: "${GRAFANA_ADMIN_USER:-grafana_admin}"
admin_password: "${GRAFANA_ADMIN_PASSWORD}"
```

**Carga de Credenciales:**
```bash
# Cargar credenciales de producción
if [ -f "/etc/webmin/secrets/production.env" ]; then
    set -a
    source /etc/webmin/secrets/production.env
    set +a
fi
```

### 2. Exposición de Secretos en Logs Eliminada

#### Archivo Afectado

| Archivo | Línea | Problema | Estado |
|----------|--------|-----------|---------|
| [`install_n8n_automation.sh`](../install_n8n_automation.sh) | 774 | Impresión de contraseña en stdout | ✅ Corregido |

#### Solución Implementada

**Antes:**
```bash
echo "Contraseña: $(grep N8N_BASIC_AUTH_PASSWORD $HOME_DIR/.n8n.env | cut -d= -f2)"
```

**Después:**
```bash
echo "Contraseña: **** (verificar en archivo de configuración)"
```

### 3. Sanitización de Entradas Implementada

#### Funciones de Sanitización

| Función | Propósito | Validaciones |
|----------|------------|--------------|
| `quotemeta()` | Escapar caracteres especiales de shell | Todos los metacaracteres de shell |
| `sanitize_filename()` | Validar nombres de archivo | Longitud, caracteres peligrosos, path traversal |
| `sanitize_filepath()` | Validar rutas de archivo | Normalización, path traversal, rutas peligrosas |
| `sanitize_username()` | Validar nombres de usuario | Formato, usuarios reservados, caracteres permitidos |
| `sanitize_ip_address()` | Validar direcciones IP | IPv4 e IPv6, rangos válidos |
| `sanitize_port()` | Validar números de puerto | Rango 1-65535, puertos reservados |
| `sanitize_domain()` | Validar nombres de dominio | Longitud, formato, TLD válido |
| `sanitize_url()` | Validar URLs | Protocolo, longitud, patrones XSS |
| `sanitize_command_input()` | Validar entradas de comando | Inyección de comandos, longitud, patrones |

#### Uso Seguro de system() y subprocess.run()

**Antes (VULNERABLE):**
```bash
# ❌ VULNERABLE: Concatenación de strings
system("curl -u $user:$password $url")

# ❌ VULNERABLE: Inyección de comandos
subprocess.run(f"systemctl restart {service}", shell=True)
```

**Después (SEGURO):**
```bash
# ✅ SEGURO: Argumentos en array
safe_execute "/usr/bin/curl" "-u" "$user:$password" "$url"

# ✅ SEGURO: shell=False y lista de argumentos
subprocess.run(["systemctl", "restart", service], shell=False)
```

### 4. Validación de Archivos de Entorno Implementada

#### Especificaciones de Seguridad

| Requisito | Implementación |
|------------|----------------|
| Permisos | 600 (solo lectura/escritura para owner) |
| Owner | root:root |
| Validación de claves | Allowlist de claves permitidas |
| Longitud mínima | 24 caracteres para contraseñas |
| Complejidad | Alfanuméricas + símbolos |
| Entropía | 256 bits |

#### Claves Permitidas (Allowlist)

```bash
GRAFANA_ADMIN_USER
GRAFANA_ADMIN_PASSWORD
PROMETHEUS_ADMIN_USER
PROMETHEUS_ADMIN_PASSWORD
N8N_ADMIN_USER
N8N_ADMIN_PASSWORD
DATABASE_ROOT_PASSWORD
WEBMIN_ROOT_PASSWORD
API_SECRET_KEY
ENCRYPTION_KEY
JWT_SECRET
SESSION_SECRET
```

---

## Arquitectura de Seguridad

### Componentes de Seguridad

```
┌─────────────────────────────────────────────────────────────┐
│                  SISTEMA DE SEGURIDAD P0                  │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│  Generador de  │  │  Sanitizador  │  │  Validador de  │
│  Credenciales  │  │  de Entradas  │  │  Entorno      │
└───────────────┘  └───────────────┘  └───────────────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            │
                            ▼
                    ┌───────────────┐
                    │  Directorio   │
                    │  de Secretos  │
                    │  /etc/webmin/ │
                    │  /secrets/    │
                    └───────────────┘
                            │
                            ▼
                    ┌───────────────┐
                    │  production.  │
                    │  env          │
                    │  (600, root) │
                    └───────────────┘
```

### Flujo de Seguridad

1. **Generación de Credenciales**
   - Ejecutar [`secure_credentials_generator.sh`](../security/secure_credentials_generator.sh)
   - Generar credenciales únicas con alta entropía
   - Almacenar en `/etc/webmin/secrets/production.env`
   - Establecer permisos 600 y owner root:root

2. **Carga de Credenciales**
   - Scripts cargan credenciales desde archivo de entorno
   - Variables de entorno tienen prioridad sobre valores por defecto
   - Validación de permisos antes de leer

3. **Sanitización de Entradas**
   - Todas las entradas de usuario son validadas
   - Uso de `quotemeta()` para escapar caracteres especiales
   - Ejecución segura de comandos con arrays de argumentos

4. **Validación Continua**
   - Verificación periódica de permisos y owner
   - Validación de contenido de archivos de entorno
   - Detección de credenciales por defecto en código

---

## Implementación

### Paso 1: Instalar Scripts de Seguridad

```bash
# Hacer scripts ejecutables
chmod +x security/secure_credentials_generator.sh
chmod +x security/input_sanitizer_secure.sh
chmod +x security/mitigate_p0_critical_vulnerabilities.sh
```

### Paso 2: Ejecutar Mitigaciones P0

```bash
# Ejecutar como root
sudo bash security/mitigate_p0_critical_vulnerabilities.sh
```

Este script:
- ✅ Genera credenciales de producción únicas
- ✅ Corrige archivos con credenciales por defecto
- ✅ Elimina exposición de secretos en logs
- ✅ Agrega sanitización de entradas
- ✅ Valida archivos de entorno
- ✅ Crea directorio de secretos con permisos seguros
- ✅ Genera scripts de verificación

### Paso 3: Verificar Mitigaciones

```bash
# Ejecutar script de verificación
sudo bash security/verify_p0_mitigations.sh
```

### Paso 4: Usar Credenciales en Scripts

```bash
# Cargar credenciales en scripts
source /etc/webmin/secrets/production.env

# Usar variables de entorno
echo "Usuario Grafana: ${GRAFANA_ADMIN_USER}"
# NO imprimir contraseñas
```

---

## Validación

### Verificación Automática

El script [`verify_p0_mitigations.sh`](../security/verify_p0_mitigations.sh) verifica:

- ✅ No hay credenciales `admin/admin123` en scripts
- ✅ No hay exposición de contraseñas en logs
- ✅ Scripts de seguridad existen y son ejecutables
- ✅ Directorio de secretos existe con permisos correctos
- ✅ Archivos de entorno tienen permisos 600 y owner root:root

### Verificación Manual

#### 1. Verificar Credenciales Únicas

```bash
# Verificar que credenciales son únicas
sudo bash security/secure_credentials_generator.sh summary
```

#### 2. Verificar Permisos

```bash
# Verificar permisos de archivo de entorno
ls -la /etc/webmin/secrets/production.env
# Debe mostrar: -rw------- root root

# Verificar permisos de directorio
ls -la /etc/webmin/secrets
# Debe mostrar: drwx------ root root
```

#### 3. Verificar Sanitización

```bash
# Probar sanitizador
sudo bash security/input_sanitizer_secure.sh filename "test.txt"
sudo bash security/input_sanitizer_secure.sh ip "192.168.1.1"
sudo bash security/input_sanitizer_secure.sh port "8080"
```

---

## Mantenimiento

### Rotación de Credenciales

#### Rotación Individual

```bash
# Rotar credencial específica
sudo bash security/secure_credentials_generator.sh rotate GRAFANA_ADMIN_PASSWORD

# Validar después de rotación
sudo bash security/secure_credentials_generator.sh validate
```

#### Rotación Completa

```bash
# Rotar todas las credenciales
sudo bash security/secure_credentials_generator.sh generate
```

### Validación Periódica

#### Verificación Diaria (Cron)

```bash
# Agregar a crontab
0 2 * * * /path/to/security/verify_p0_mitigations.sh >> /var/log/webmin/security_check.log 2>&1
```

#### Verificación Semanal

```bash
# Validar archivos de entorno
sudo bash security/secure_credentials_generator.sh validate

# Verificar permisos
sudo find /etc/webmin/secrets -type f -perm 600
sudo find /etc/webmin/secrets -type d -perm 700
```

### Auditoría de Seguridad

#### Revisión de Logs

```bash
# Revisar logs de seguridad
sudo tail -f /var/log/webmin/secure_credentials.log
sudo tail -f /var/log/webmin/input_sanitizer.log
sudo tail -f /var/log/webmin/p0_mitigation.log
```

#### Detección de Credenciales por Defecto

```bash
# Buscar credenciales por defecto en el código
grep -r "admin/admin123" scripts/ monitoring/ --color=always
grep -r "admin123" scripts/ monitoring/ --color=always
```

---

## Procedimientos de Emergencia

### Compromiso de Credenciales

Si se sospecha que las credenciales han sido comprometidas:

#### 1. Rotación Inmediata

```bash
# Rotar todas las credenciales inmediatamente
sudo bash security/secure_credentials_generator.sh generate

# Reiniciar servicios afectados
sudo systemctl restart grafana
sudo systemctl restart prometheus
sudo systemctl restart n8n
```

#### 2. Auditoría de Accesos

```bash
# Revisar logs de autenticación
sudo journalctl -u grafana --since "1 hour ago"
sudo journalctl -u prometheus --since "1 hour ago"
sudo journalctl -u n8n --since "1 hour ago"

# Revisar logs de webmin
sudo tail -100 /var/webmin/webmin.log
```

#### 3. Revocación de Sesiones

```bash
# Revocar todas las sesiones activas
sudo pkill -u grafana
sudo pkill -u prometheus
sudo pkill -u n8n
```

### Archivo de Entorno Corrupto

Si el archivo de entorno se corrompe:

#### 1. Restaurar desde Backup

```bash
# Listar backups disponibles
ls -la /etc/webmin/secrets/backups/

# Restaurar backup más reciente
sudo cp /etc/webmin/secrets/backups/production.env.backup_YYYYMMDD_HHMMSS \
        /etc/webmin/secrets/production.env

# Establecer permisos correctos
sudo chmod 600 /etc/webmin/secrets/production.env
sudo chown root:root /etc/webmin/secrets/production.env
```

#### 2. Regenerar Credenciales

```bash
# Generar nuevas credenciales
sudo bash security/secure_credentials_generator.sh generate
```

### Permisos Incorrectos

Si los permisos de archivos sensibles son incorrectos:

#### 1. Corregir Permisos

```bash
# Corregir permisos de directorio de secretos
sudo chmod 700 /etc/webmin/secrets
sudo chown root:root /etc/webmin/secrets

# Corregir permisos de archivo de entorno
sudo chmod 600 /etc/webmin/secrets/production.env
sudo chown root:root /etc/webmin/secrets/production.env
```

#### 2. Validar Corrección

```bash
# Verificar permisos
sudo ls -la /etc/webmin/secrets/
```

---

## Scripts de Seguridad

### 1. secure_credentials_generator.sh

**Propósito:** Generar y gestionar credenciales seguras para producción

**Uso:**
```bash
# Generar credenciales
sudo bash security/secure_credentials_generator.sh generate

# Validar archivo de entorno
sudo bash security/secure_credentials_generator.sh validate

# Cargar credencial específica
sudo bash security/secure_credentials_generator.sh load GRAFANA_ADMIN_PASSWORD

# Rotar credencial específica
sudo bash security/secure_credentials_generator.sh rotate GRAFANA_ADMIN_PASSWORD

# Mostrar resumen
sudo bash security/secure_credentials_generator.sh summary
```

**Características:**
- ✅ Contraseñas de mínimo 24 caracteres
- ✅ Alfanuméricas + símbolos
- ✅ Alta entropía (256 bits)
- ✅ Permisos 600 (root:root)
- ✅ Validación de allowlist de claves
- ✅ Backup automático antes de rotación

### 2. input_sanitizer_secure.sh

**Propósito:** Sanitizar entradas para prevenir inyección de comandos

**Uso:**
```bash
# Sanitizar nombre de archivo
sudo bash security/input_sanitizer_secure.sh filename "documento.txt"

# Sanitizar ruta de archivo
sudo bash security/input_sanitizer_secure.sh filepath "/var/log/system.log"

# Sanitizar nombre de usuario
sudo bash security/input_sanitizer_secure.sh username "usuario_ejemplo"

# Sanitizar dirección IP
sudo bash security/input_sanitizer_secure.sh ip "192.168.1.1"

# Sanitizar número de puerto
sudo bash security/input_sanitizer_secure.sh port "8080"

# Sanitizar nombre de dominio
sudo bash security/input_sanitizer_secure.sh domain "example.com"

# Sanitizar URL
sudo bash security/input_sanitizer_secure.sh url "https://example.com"

# Sanitizar entrada de comando
sudo bash security/input_sanitizer_secure.sh command "start" "^(start|stop|restart)$"

# Escapar caracteres especiales
sudo bash security/input_sanitizer_secure.sh quotemeta "texto con espacios"
```

**Características:**
- ✅ Prevención de inyección de comandos
- ✅ Validación de formatos
- ✅ Escapado de caracteres especiales
- ✅ Verificación de longitudes máximas
- ✅ Detección de patrones peligrosos

### 3. mitigate_p0_critical_vulnerabilities.sh

**Propósito:** Corregir vulnerabilidades P0 críticas en producción

**Uso:**
```bash
# Ejecutar mitigaciones
sudo bash security/mitigate_p0_critical_vulnerabilities.sh
```

**Características:**
- ✅ Genera credenciales de producción
- ✅ Corrige archivos con credenciales por defecto
- ✅ Elimina exposición de secretos en logs
- ✅ Agrega sanitización de entradas
- ✅ Valida archivos de entorno
- ✅ Crea directorio de secretos con permisos seguros
- ✅ Genera scripts de verificación

### 4. verify_p0_mitigations.sh

**Propósito:** Verificar que todas las mitigaciones P0 están aplicadas

**Uso:**
```bash
# Verificar mitigaciones
sudo bash security/verify_p0_mitigations.sh
```

**Verificaciones:**
- ✅ No hay credenciales `admin/admin123` en scripts
- ✅ No hay exposición de contraseñas en logs
- ✅ Scripts de seguridad existen y son ejecutables
- ✅ Directorio de secretos existe con permisos correctos
- ✅ Archivos de entorno tienen permisos 600 y owner root:root

---

## Mejores Prácticas

### Desarrollo Seguro

1. **Nunca** incluir credenciales en el código
2. **Siempre** usar variables de entorno para credenciales
3. **Siempre** sanitizar entradas de usuario
4. **Siempre** validar permisos de archivos sensibles
5. **Nunca** imprimir contraseñas en logs o stdout
6. **Siempre** usar arrays de argumentos en lugar de concatenación de strings
7. **Siempre** establecer permisos 600 para archivos de entorno
8. **Siempre** usar owner root:root para archivos de entorno

### Despliegue Seguro

1. Generar credenciales únicas por despliegue
2. Validar archivos de entorno antes de iniciar servicios
3. Verificar permisos de archivos sensibles
4. Rotar credenciales periódicamente
5. Monitorear logs de seguridad
6. Implementar alertas para eventos de seguridad

### Mantenimiento Seguro

1. Rotar credenciales regularmente (cada 90 días)
2. Validar permisos de archivos sensibles diariamente
3. Revisar logs de seguridad semanalmente
4. Actualizar scripts de seguridad regularmente
5. Realizar auditorías de seguridad trimestralmente

---

## Referencias

### Estándares de Seguridad

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE-798: Use of Hard-coded Credentials](https://cwe.mitre.org/data/definitions/798.html)
- [CWE-78: OS Command Injection](https://cwe.mitre.org/data/definitions/78.html)
- [CWE-20: Improper Input Validation](https://cwe.mitre.org/data/definitions/20.html)

### Documentación Relacionada

- [`SECURE_CREDENTIALS_GENERATOR.md`](SECURE_CREDENTIALS_GENERATOR.md)
- [`INPUT_SANITIZER_SECURE.md`](INPUT_SANITIZER_SECURE.md)
- [`PRODUCTION_DEPLOYMENT_GUIDE.md`](PRODUCTION_DEPLOYMENT_GUIDE.md)

---

## Soporte

### Reportar Problemas

Si encuentra vulnerabilidades de seguridad o problemas con las mitigaciones implementadas:

1. Revisar logs de seguridad: `/var/log/webmin/`
2. Ejecutar script de verificación: `security/verify_p0_mitigations.sh`
3. Documentar el problema con evidencia
4. Reportar a través de canales de seguridad oficiales

### Contacto de Seguridad

- **Email de Seguridad:** security@example.com
- **PGP Key:** [disponible en servidor de claves]
- **Política de Divulgación:** [Coordinated Vulnerability Disclosure](https://example.com/security-policy)

---

**Versión:** 1.0.0  
**Fecha:** 2025-01-17  
**Estado:** ✅ Producción Segura

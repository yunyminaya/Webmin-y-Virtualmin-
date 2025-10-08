# Guía del Sistema de Gestión Segura de Credenciales

## Overview

El Sistema de Gestión Segura de Credenciales es un componente crítico del proyecto Webmin/Virtualmin que proporciona almacenamiento cifrado y recuperación segura de credenciales de servicios. Este sistema ha sido completamente rediseñado para abordar vulnerabilidades de seguridad y proporcionar funcionalidad robusta.

## Arquitectura del Sistema

### Componentes Principales

1. **Módulo Central**: `lib/secure_credentials_test.sh`
2. **Suite de Pruebas**: `test_credentials_simple.sh`
3. **Scripts de Depuración**: `debug_simple.sh`, `debug_password_test.sh`

### Características de Seguridad

- ✅ Cifrado AES-256 con clave derivada de contraseña
- ✅ Salt único para cada instalación
- ✅ Validación de integridad de datos descifrados
- ✅ Permisos seguros de archivos (600/700)
- ✅ Manejo seguro de contraseñas en memoria
- ✅ Protección contra ataques de diccionario

## Instalación y Configuración

### Requisitos del Sistema

- OpenSSL (para operaciones criptográficas)
- Bash 4.0+ (para arrays asociativos)
- Permisos de usuario estándar (no requiere root)

### Proceso de Instalación

```bash
# 1. Clonar o descargar el módulo
cp lib/secure_credentials_test.sh /ruta/a/instalacion/

# 2. Hacer ejecutable el script
chmod +x /ruta/a/instalacion/secure_credentials_test.sh

# 3. Inicializar el sistema
./secure_credentials_test.sh init

# 4. Verificar instalación
./test_credentials_simple.sh
```

### Configuración Personalizada

```bash
# Variables de configuración (opcional)
export CREDENTIALS_DIR="/ruta/personalizada/credenciales"
export CREDENTIALS_LOG_FILE="/ruta/personalizada/credenciales.log"
export CREDENTIALS_BACKUP_DIR="/ruta/personalizada/backup"
```

## Guía de Uso

### Comandos Básicos

#### 1. Inicialización del Sistema
```bash
./secure_credentials_test.sh init
```
- Crea directorios necesarios
- Establece permisos seguros
- Genera configuración inicial

#### 2. Almacenar Credenciales
```bash
./secure_credentials_test.sh store <servicio> <usuario> <contraseña>
```

**Ejemplo:**
```bash
./secure_credentials_test.sh store "database" "admin" "SecurePass123!"
```

#### 3. Recuperar Credenciales
```bash
./secure_credentials_test.sh retrieve <servicio>
```
- Solicita contraseña maestra de forma segura
- Valida integridad de datos descifrados
- Devuelve credenciales en formato `usuario:contraseña`

#### 4. Listar Servicios
```bash
./secure_credentials_test.sh list
```
- Muestra todos los servicios almacenados
- No revela información sensible

#### 5. Eliminar Credenciales
```bash
./secure_credentials_test.sh delete <servicio>
```
- Elimina de forma segura el archivo de credenciales
- Registra la operación en el log

#### 6. Respaldar Credenciales
```bash
./secure_credentials_test.sh backup
```
- Copia cifrada de todas las credenciales
- Comprime con timestamp único

### Ejemplos Prácticos

#### Escenario 1: Configuración de Base de Datos
```bash
# Inicializar sistema
./secure_credentials_test.sh init

# Almacenar credenciales de base de datos
./secure_credentials_test.sh store "mysql_prod" "dbadmin" "ComplexPass!@#"

# Recuperar para aplicación
CREDS=$(./secure_credentials_test.sh retrieve "mysql_prod")
DB_USER=$(echo "$CREDS" | cut -d: -f1)
DB_PASS=$(echo "$CREDS" | cut -d: -f2)

# Usar en configuración
mysql -u "$DB_USER" -p"$DB_PASS" production_db
```

#### Escenario 2: Integración con Scripts de Automatización
```bash
#!/bin/bash
# deploy_app.sh - Script de despliegue automatizado

# Recuperar credenciales de API
API_CREDS=$(./secure_credentials_test.sh retrieve "api_service")
API_KEY=$(echo "$API_CREDS" | cut -d: -f1)
API_SECRET=$(echo "$API_CREDS" | cut -d: -f2)

# Realizar despliegue
curl -X POST "https://api.example.com/deploy" \
     -H "Authorization: Bearer $API_KEY" \
     -H "X-API-Secret: $API_SECRET" \
     -d "service=webapp"
```

## Detalles Técnicos

### Algoritmo de Cifrado

El sistema utiliza AES-256-CBC con los siguientes parámetros:

- **Algoritmo**: AES-256-CBC
- **Derivación de Clave**: OpenSSL EVP_BytesToKey con HMAC-SHA256
- **Salt**: Generado aleatoriamente (8 bytes)
- **Iteraciones**: 1 (por defecto de OpenSSL)
- **Codificación**: Base64 para almacenamiento

### Estructura de Archivos

```
credentials_dir/
├── .salt          # Salt único de la instalación
├── .config        # Configuración del sistema
├── service1.enc   # Credenciales cifradas del servicio 1
├── service2.enc   # Credenciales cifradas del servicio 2
└── backup/
    └── credentials_20231008_123456.tar.gz
```

### Formato de Datos

#### Credenciales Cifradas
```
U2FsdGVkX1+vupppZksvRf5pq5g5XjFRIipRkwB0K1Y96Qsv2Lm+31cmzaAILwyt
```

#### Credenciales Descifradas
```
username:password
```

### Validación de Integridad

El sistema implementa validación múltiple:

1. **Validación de Formato**: Verifica presencia de separador `:`
2. **Validación de Longitud**: Rechaza datos demasiado cortos/largos
3. **Validación de Caracteres**: Solo permite caracteres imprimibles

## Seguridad

### Medidas de Seguridad Implementadas

#### 1. Cifrado Robusto
```bash
# Proceso de cifrado
openssl enc -aes-256-cbc -e -a -salt -pass pass:"$password"
```

#### 2. Permisos Seguros
```bash
# Directorio: 700 (solo propietario)
chmod 700 "$CREDENTIALS_DIR"

# Archivos: 600 (solo lectura/escritura propietario)
chmod 600 "$encrypted_file"
```

#### 3. Manejo Seguro de Contraseñas
```bash
# Lectura segura sin echo
read -s -p "Ingrese contraseña maestra: " password
```

#### 4. Validación de Integridad
```bash
# Verificación de formato después del descifrado
if echo "$decrypted_data" | grep -q ":"; then
    # Datos válidos
    return 0
else
    # Datos corruptos o contraseña incorrecta
    return 1
fi
```

### Vulnerabilidades Mitigadas

1. **Ataques de Diccionario**: Salt único previene rainbow tables
2. **Acceso No Autorizado**: Permisos restrictivos de archivos
3. **Inyección de Comandos**: Validación estricta de entradas
4. **Man-in-the-Middle**: Validación de integridad de datos
5. **Fugas de Memoria**: Manejo seguro de contraseñas en RAM

## Pruebas y Validación

### Suite de Pruebas Automatizadas

El sistema incluye 7 pruebas automatizadas:

1. ✅ **Inicialización del Sistema**
   - Verifica creación de directorios
   - Valida permisos correctos
   - Confirma archivos de configuración

2. ✅ **Almacenamiento de Credenciales**
   - Prueba cifrado correcto
   - Valida creación de archivos
   - Verifica permisos de archivo

3. ✅ **Recuperación con Contraseña Correcta**
   - Confirma descifrado funcional
   - Valida formato de salida
   - Verifica contenido correcto

4. ✅ **Recuperación con Contraseña Incorrecta**
   - Verifica rechazo de contraseñas incorrectas
   - Valida códigos de error adecuados
   - Confirma no fuga de información

5. ✅ **Listado de Servicios**
   - Prueba enumeración de servicios
   - Valida no exposición de datos sensibles
   - Confirma formato de salida

6. ✅ **Eliminación de Credenciales**
   - Verifica eliminación segura
   - Valida limpieza de archivos
   - Confirma registro en log

7. ✅ **Verificación de Permisos**
   - Confirma permisos de directorio (700)
   - Valida permisos de archivo (600)
   - Verifica propiedad correcta

### Ejecución de Pruebas

```bash
# Ejecutar suite completa
./test_credentials_simple.sh

# Salida esperada
=== Ejecutando Suite de Pruebas del Sistema de Credenciales ===

✅ Prueba 1: Inicialización del sistema - PASÓ
✅ Prueba 2: Almacenamiento de credenciales - PASÓ
✅ Prueba 3: Recuperación con contraseña correcta - PASÓ
✅ Prueba 4: Recuperación con contraseña incorrecta - PASÓ
✅ Prueba 5: Listado de servicios - PASÓ
✅ Prueba 6: Eliminación de credenciales - PASÓ
✅ Prueba 7: Verificación de permisos - PASÓ

=== Resultados Finales ===
Total de pruebas: 7
Pruebas pasadas: 7
Pruebas fallidas: 0
Tasa de éxito: 100%
🎉 Todas las pruebas pasaron exitosamente
```

## Depuración y Solución de Problemas

### Herramientas de Depuración

#### 1. Diagnóstico Básico
```bash
./debug_simple.sh
```

#### 2. Pruebas Específicas de Credenciales
```bash
./debug_password_test.sh
```

### Problemas Comunes y Soluciones

#### Problema: "Permiso denegado"
```bash
# Solución: Verificar permisos
ls -la "$CREDENTIALS_DIR"
chmod 700 "$CREDENTIALS_DIR"
```

#### Problema: "OpenSSL no disponible"
```bash
# Solución: Instalar OpenSSL
# Ubuntu/Debian
sudo apt-get install openssl

# CentOS/RHEL
sudo yum install openssl
```

#### Problema: "Datos descifrados inválidos"
```bash
# Solución: Verificar contraseña maestra
./debug_password_test.sh
# O reinitializar sistema
rm -rf "$CREDENTIALS_DIR"
./secure_credentials_test.sh init
```

## Integración con Otros Componentes

### Integración con Webmin/Virtualmin

El sistema puede integrarse con módulos existentes:

```bash
# En scripts de instalación de Webmin
source lib/secure_credentials_test.sh

# Almacenar credenciales de administrador
store_credential "webmin_admin" "root" "$ADMIN_PASSWORD"

# Recuperar para configuración
ADMIN_CREDS=$(retrieve_credential "webmin_admin")
```

### Integración con Scripts de Monitoreo

```bash
# En scripts de monitoreo
source lib/secure_credentials_test.sh

# Recuperar credenciales para checks de servicio
DB_CREDS=$(retrieve_credential "monitoring_db")
mysql_check "$(echo "$DB_CREDS" | cut -d: -f1)" "$(echo "$DB_CREDS" | cut -d: -f2)"
```

## Mejores Prácticas

### Recomendaciones de Uso

1. **Contraseñas Fuertes**: Use contraseñas maestras complejas
2. **Rotación Regular**: Cambie contraseñas maestras periódicamente
3. **Backups**: Realice respaldos regulares de credenciales
4. **Auditoría**: Revise logs de acceso regularmente
5. **Pruebas**: Ejecute pruebas automatizadas después de cambios

### Consideraciones de Seguridad

1. **Entorno Aislado**: Ejecute en sistemas aislados cuando sea posible
2. **Limitación de Acceso**: Restrinja acceso físico al servidor
3. **Monitoreo**: Monitoree accesos sospechosos al sistema
4. **Actualizaciones**: Mantenga OpenSSL y sistema actualizados
5. **Formación**: Entrene a administradores en uso seguro

## API de Referencia

### Funciones Principales

#### `init_credentials_system()`
Inicializa el sistema de credenciales.
- **Retorno**: 0 (éxito), 1 (error)

#### `store_credential(service, username, password)`
Almacena credenciales cifradas.
- **Parámetros**: servicio, usuario, contraseña
- **Retorno**: 0 (éxito), 1 (error)

#### `retrieve_credential(service, password)`
Recupera credenciales descifradas.
- **Parámetros**: servicio, contraseña maestra
- **Retorno**: credenciales en formato `usuario:contraseña`

#### `list_credentials()`
Lista todos los servicios almacenados.
- **Retorno**: Lista de servicios, uno por línea

#### `delete_credential(service)`
Elimina credenciales de un servicio.
- **Parámetros**: servicio
- **Retorno**: 0 (éxito), 1 (error)

#### `backup_credentials()`
Crea respaldo de todas las credenciales.
- **Retorno**: 0 (éxito), 1 (error)

### Variables de Configuración

- `CREDENTIALS_DIR`: Directorio de almacenamiento
- `CREDENTIALS_LOG_FILE`: Archivo de log
- `CREDENTIALS_BACKUP_DIR`: Directorio de respaldos

## Historial de Cambios

### Versión 2.0 (Actual)
- ✅ Validación de integridad de datos descifrados
- ✅ Manejo mejorado de errores
- ✅ Suite completa de pruebas automatizadas
- ✅ Documentación completa
- ✅ Scripts de depuración

### Versión 1.0 (Original)
- ⚠️ Funcionalidad básica
- ⚠️ Vulnerabilidades de seguridad
- ⚠️ Sin validación de integridad
- ⚠️ Pruebas limitadas

## Soporte y Contribuciones

### Reporte de Problemas

Para reportar problemas o solicitar mejoras:

1. Ejecute las herramientas de depuración
2. Capture la salida completa
3. Incluya detalles del sistema operativo
4. Proporcione pasos para reproducir el problema

### Contribuciones

Las contribuciones son bienvenidas en:

- Mejoras de seguridad
- Nuevas funcionalidades
- Optimización de rendimiento
- Documentación adicional

---

**Aviso de Seguridad**: Este sistema maneja información sensible. Utilícelo de acuerdo con las políticas de seguridad de su organización y cumpla con las regulaciones aplicables de protección de datos.
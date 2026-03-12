# 📚 FUNCIONES PRINCIPALES DISPONIBLES

## 📋 LIBRERÍA COMÚN - lib/common.sh

### 🔍 Funciones de Logging

| Función | Descripción |
|---------|-------------|
| `log_error "mensaje"` | Muestra mensaje de error en rojo |
| `log_success "mensaje"` | Muestra mensaje de éxito en verde |
| `log_info "mensaje"` | Muestra mensaje informativo en azul |
| `log_warning "mensaje"` | Muestra mensaje de advertencia en amarillo |
| `log_debug "mensaje"` | Muestra mensaje de debug (solo si DEBUG=true) |
| `log_step "mensaje"` | Muestra mensaje de paso en cyan |

### 🛠️ Funciones de Utilidad

| Función | Descripción |
|---------|-------------|
| `command_exists "comando"` | Verifica si un comando existe en el sistema |
| `show_progress actual total "descripción"` | Muestra barra de progreso |
| `show_progress_complete()` | Muestra progreso completado al 100% |
| `get_file_size_mb "archivo"` | Obtiene tamaño de archivo en MB |
| `get_timestamp` | Obtiene timestamp actual |
| `get_system_info` | Obtiene información del sistema |

### 🌐 Funciones de Red

| Función | Descripción |
|---------|-------------|
| `check_url_connectivity "url" [timeout]` | Verifica conectividad a URL |
| `check_network_connectivity` | Verifica conectividad de red |
| `check_port_available puerto` | Verifica si puerto está disponible |
| `get_server_ip` | Obtiene IP del servidor |

### 💾 Funciones de Backup

| Función | Descripción |
|---------|-------------|
| `backup_file "archivo" [sufijo]` | Crea backup de archivo |
| `restore_file "archivo" [sufijo]` | Restaura archivo desde backup |
| `verify_checksum "archivo" "checksum" [algoritmo]` | Verifica checksum de archivo |

### 🔧 Funciones de Sistema

| Función | Descripción |
|---------|-------------|
| `check_root` | Verifica si se ejecuta como root |
| `check_internet` | Verifica conexión a internet |
| `detect_package_manager` | Detecta gestor de paquetes |
| `check_write_permissions "directorio"` | Verifica permisos de escritura |
| `install_packages "paquete1 paquete2..."` | Instala paquetes |
| `ensure_directory "directorio"` | Asegura que directorio existe |
| `service_running "servicio"` | Verifica si servicio está corriendo |

### 🐘 Funciones de Base de Datos

| Función | Descripción |
|---------|-------------|
| `check_mysql_connection [host] [usuario] [password]` | Verifica conexión MySQL |

### 🖥️ Funciones de Validación

| Función | Descripción |
|---------|-------------|
| `validate_args "$@"` | Valida argumentos comunes |
| `handle_error código_error "mensaje"` | Maneja errores con código |
| `show_help` | Muestra ayuda del script |
| `parse_common_args "$@"` | Parsea argumentos comunes |

### 📊 Funciones de Información

| Función | Descripción |
|---------|-------------|
| `show_system_info` | Muestra información del sistema |
| `show_help` | Muestra ayuda |

### 🔍 Funciones de Detección

| Función | Descripción |
|---------|-------------|
| `detect_and_validate_os` | Detecta y valida sistema operativo |
| `detect_package_manager` | Detecta gestor de paquetes |

---

## 🎯 Constantes de Error

| Constante | Valor | Descripción |
|-----------|-------|-------------|
| `ERROR_ROOT_REQUIRED` | 1 | Se requiere root |
| `ERROR_INTERNET_CONNECTION` | 2 | Sin conexión a internet |
| `ERROR_OS_NOT_SUPPORTED` | 3 | OS no soportado |
| `ERROR_ARCHITECTURE_NOT_SUPPORTED` | 4 | Arquitectura no soportada |
| `ERROR_MEMORY_INSUFFICIENT` | 5 | Memoria insuficiente |
| `ERROR_DISK_INSUFFICIENT` | 6 | Disco insuficiente |
| `ERROR_PACKAGE_MANAGER_NOT_FOUND` | 7 | Gestor de paquetes no encontrado |
| `ERROR_DEPENDENCY_MISSING` | 8 | Dependencia faltante |
| `ERROR_PERL_NOT_FOUND` | 9 | Perl no encontrado |
| `ERROR_PYTHON_NOT_FOUND` | 10 | Python no encontrado |
| `ERROR_PHP_NOT_FOUND` | 11 | PHP no encontrado |
| `ERROR_MYSQL_NOT_FOUND` | 12 | MySQL no encontrado |
| `ERROR_APACHE_NOT_FOUND` | 13 | Apache no encontrado |
| `ERROR_FILE_NOT_FOUND` | 14 | Archivo no encontrado |
| `ERROR_PERMISSION_DENIED` | 15 | Permiso denegado |
| `ERROR_INVALID_ARGUMENT` | 16 | Argumento inválido |
| `ERROR_NETWORK_ERROR` | 17 | Error de red |
| `ERROR_TIMEOUT` | 18 | Timeout |
| `ERROR_CHECKSUM_MISMATCH` | 19 | Checksum no coincide |
| `ERROR_BACKUP_FAILED` | 20 | Backup falló |
| `ERROR_RESTORE_FAILED` | 21 | Restauración falló |
| `ERROR_CONFIGURATION_ERROR` | 22 | Error de configuración |
| `ERROR_SERVICE_FAILED` | 23 | Servicio falló |
| `ERROR_SSL_ERROR` | 24 | Error SSL |
| `ERROR_DATABASE_ERROR` | 25 | Error de base de datos |
| `ERROR_API_ERROR` | 26 | Error de API |
| `ERROR_AUTHENTICATION_FAILED` | 27 | Autenticación falló |
| `ERROR_AUTHORIZATION_FAILED` | 28 | Autorización falló |
| `ERROR_VALIDATION_FAILED` | 29 | Validación falló |
| `ERROR_DOWNLOAD_FAILED` | 30 | Descarga falló |
| `ERROR_INSTALLATION_FAILED` | 31 | Instalación falló |
| `ERROR_PHP_VERSION_TOO_OLD` | 32 | Versión PHP muy antigua |
| `ERROR_MYSQL_VERSION_TOO_OLD` | 33 | Versión MySQL muy antigua |
| `ERROR_APACHE_VERSION_TOO_OLD` | 34 | Versión Apache muy antigua |
| `ERROR_SECURITY_VULNERABILITY` | 35 | Vulnerabilidad de seguridad |
| `ERROR_UNKNOWN` | 99 | Error desconocido |

---

## 🎨 Colores ANSI

| Variable | Color |
|-----------|-------|
| `$RED` | Rojo |
| `$GREEN` | Verde |
| `$YELLOW` | Amarillo |
| `$BLUE` | Azul |
| `$PURPLE` | Púrpura |
| `$CYAN` | Cyan |
| `$NC` | Sin color |

---

## 📝 Uso de la Librería

```bash
#!/bin/bash

# Cargar la librería
source lib/common.sh

# Ejemplos de uso
log_info "Iniciando instalación..."

if ! check_root; then
    log_error "Se requiere root para ejecutar este script"
    exit $ERROR_ROOT_REQUIRED
fi

if ! check_internet; then
    log_error "No hay conexión a internet"
    exit $ERROR_INTERNET_CONNECTION
fi

if ! detect_and_validate_os; then
    log_error "Sistema operativo no soportado"
    exit $ERROR_OS_NOT_SUPPORTED
fi

log_success "Todas las validaciones pasaron correctamente"
```

---

## ✅ Estado de Funciones

Todas las funciones principales están:
- ✅ Implementadas
- ✅ Exportadas para uso en otros scripts
- ✅ Documentadas
- ✅ Probadas

---

**Última actualización:** 2026-03-12
**Versión de lib/common.sh:** 3.0 Enterprise

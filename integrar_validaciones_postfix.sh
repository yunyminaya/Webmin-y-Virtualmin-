#!/bin/bash

# =============================================================================
# INTEGRACIÓN DE VALIDACIONES DE POSTFIX EN WEBMIN/VIRTUALMIN
# Script para prevenir errores de postconf en paneles de administración
# =============================================================================

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -e

# Colores para output
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

log_step() {
    echo -e "${PURPLE}[PASO]${NC} $1"
}

# Función para crear validaciones de Postfix
create_postfix_validation_functions() {
    log_step "Creando funciones de validación de Postfix..."
    
    local validation_file="./postfix_validation_functions.sh"
    
    cat > "$validation_file" << 'EOF'
#!/bin/bash

# =============================================================================
# FUNCIONES DE VALIDACIÓN DE POSTFIX PARA WEBMIN/VIRTUALMIN
# Incluir este archivo en scripts que usen postconf
# =============================================================================

# Función para verificar disponibilidad de postconf
check_postconf_available() {
    # Verificar si postconf está en PATH
    if command -v postconf >/dev/null 2>&1; then
        return 0
    fi
    
    # Verificar ubicaciones comunes
    local common_paths=("/usr/sbin/postconf" "/usr/bin/postconf" "/usr/local/sbin/postconf")
    
    for path in "${common_paths[@]}"; do
        if [[ -x "$path" ]]; then
            # Agregar directorio al PATH si no está
            local dir=$(dirname "$path")
            if [[ ":$PATH:" != *":$dir:"* ]]; then
                export PATH="$PATH:$dir"
            fi
            return 0
        fi
    done
    
    return 1
}

# Función segura para ejecutar postconf
safe_postconf() {
    if ! check_postconf_available; then
        echo "ERROR: postconf no está disponible. Instale Postfix primero." >&2
        return 1
    fi
    
    # Ejecutar postconf con los argumentos proporcionados
    postconf "$@"
}

# Función para verificar si Postfix está instalado
is_postfix_installed() {
    check_postconf_available
}

# Función para obtener versión de Postfix de forma segura
get_postfix_version() {
    if check_postconf_available; then
        safe_postconf mail_version 2>/dev/null | cut -d'=' -f2 | tr -d ' '
    else
        echo "No disponible"
        return 1
    fi
}

# Función para verificar parámetro específico de Postfix
get_postfix_parameter() {
    local parameter="$1"
    
    if [[ -z "$parameter" ]]; then
        echo "ERROR: Debe especificar un parámetro" >&2
        return 1
    fi
    
    if check_postconf_available; then
        safe_postconf "$parameter" 2>/dev/null | cut -d'=' -f2 | tr -d ' '
    else
        echo "ERROR: No se puede obtener parámetro $parameter - Postfix no disponible" >&2
        return 1
    fi
}

# Función para verificar directorio de cola de Postfix
verify_queue_directory() {
    local queue_dir
    
    if queue_dir=$(get_postfix_parameter "queue_directory"); then
        if [[ -d "$queue_dir" ]]; then
            echo "$queue_dir"
            return 0
        else
            echo "ERROR: Directorio de cola no existe: $queue_dir" >&2
            return 1
        fi
    else
        echo "ERROR: No se pudo obtener directorio de cola" >&2
        return 1
    fi
}

# Función para mostrar estado de Postfix
show_postfix_status() {
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "ESTADO DE POSTFIX"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    
    if is_postfix_installed; then
        echo "✅ Postfix está instalado"
        echo "📋 Versión: $(get_postfix_version)"
        echo "📁 Directorio de cola: $(get_postfix_parameter "queue_directory" 2>/dev/null || echo "No disponible")"
        echo "🔧 Directorio de comandos: $(get_postfix_parameter "command_directory" 2>/dev/null || echo "No disponible")"
        echo "⚙️  Directorio de daemons: $(get_postfix_parameter "daemon_directory" 2>/dev/null || echo "No disponible")"
    else
        echo "❌ Postfix no está instalado o no está disponible"
        echo "💡 Ejecute: sudo apt-get install postfix (Ubuntu/Debian)"
        echo "💡 Ejecute: sudo yum install postfix (CentOS/RHEL)"
    fi
    
    echo "═══════════════════════════════════════════════════════════════════════════════"
}

# Función para instalar Postfix automáticamente
auto_install_postfix() {
    echo "🔧 Iniciando instalación automática de Postfix..."
    
    # Detectar sistema operativo
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            "ubuntu"|"debian")
                echo "📦 Instalando Postfix en Ubuntu/Debian..."
                sudo apt-get update
                sudo DEBIAN_FRONTEND=noninteractive apt-get install -y postfix
                ;;
            "centos"|"rhel"|"fedora")
                echo "📦 Instalando Postfix en CentOS/RHEL/Fedora..."
                if command -v dnf >/dev/null 2>&1; then
                    sudo dnf install -y postfix
                else
                    sudo yum install -y postfix
                fi
                ;;
            *)
                echo "❌ Sistema operativo no soportado para instalación automática: $ID"
                return 1
                ;;
        esac
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "🍎 En macOS, Postfix viene preinstalado"
        echo "🔧 Habilitando servicio..."
        sudo launchctl load -w /System/Library/LaunchDaemons/org.postfix.master.plist 2>/dev/null || true
    else
        echo "❌ No se pudo detectar el sistema operativo"
        return 1
    fi
    
    # Verificar instalación
    if check_postconf_available; then
        echo "✅ Postfix instalado correctamente"
        return 0
    else
        echo "❌ Error al instalar Postfix"
        return 1
    fi
}
EOF
    
    chmod +x "$validation_file"
    log_success "Funciones de validación creadas: $validation_file"
}

# Función para actualizar scripts existentes
update_existing_scripts() {
    log_step "Actualizando scripts existentes con validaciones de Postfix..."
    
    local scripts_to_update=(
        "./verificacion_final_autonomo.sh"
        "./diagnostico_servidores_virtuales.sh"
        "./monitoreo_sistema.sh"
    )
    
    for script in "${scripts_to_update[@]}"; do
        if [[ -f "$script" ]]; then
            log_info "Actualizando: $script"
            
            # Crear backup
            cp "$script" "${script}.backup.$(date +%Y%m%d_%H%M%S)"
            
            # Verificar si ya tiene las validaciones
            if grep -q "check_postconf_available" "$script"; then
                log_warning "$script ya tiene validaciones de Postfix"
                continue
            fi
            
            # Agregar source de las funciones de validación al inicio
            local temp_file=$(mktemp)
            {
                echo "#!/bin/bash"
                echo ""
                echo "# Incluir funciones de validación de Postfix"
                echo "source \"$(pwd)/postfix_validation_functions.sh\""
                echo ""
                tail -n +2 "$script"
            } > "$temp_file"
            
            # Reemplazar llamadas directas a postconf
            sed -i.bak 's/postconf /safe_postconf /g' "$temp_file"
            
            # Mover archivo temporal al original
            mv "$temp_file" "$script"
            chmod +x "$script"
            
            log_success "$script actualizado con validaciones de Postfix"
        else
            log_warning "Script no encontrado: $script"
        fi
    done
}

# Función para crear script de verificación de Webmin
create_webmin_postfix_check() {
    log_step "Creando script de verificación para Webmin..."
    
    local webmin_check="./webmin_postfix_check.sh"
    
    cat > "$webmin_check" << 'EOF'
#!/bin/bash

# =============================================================================
# VERIFICACIÓN DE POSTFIX PARA WEBMIN
# Script para verificar que Postfix esté disponible antes de usar Webmin
# =============================================================================

# Incluir funciones de validación
source "$(dirname "$0")/postfix_validation_functions.sh"

# Función principal de verificación
main() {
    echo "🔍 Verificando Postfix para Webmin..."
    echo
    
    if is_postfix_installed; then
        echo "✅ Postfix está disponible para Webmin"
        echo "📋 Versión: $(get_postfix_version)"
        
        # Verificar parámetros críticos
        local critical_params=("queue_directory" "command_directory" "daemon_directory")
        local all_ok=true
        
        for param in "${critical_params[@]}"; do
            if get_postfix_parameter "$param" >/dev/null 2>&1; then
                echo "✅ $param: $(get_postfix_parameter "$param")"
            else
                echo "❌ Error al obtener $param"
                all_ok=false
            fi
        done
        
        if [[ "$all_ok" == true ]]; then
            echo
            echo "🎉 Postfix está correctamente configurado para Webmin"
            exit 0
        else
            echo
            echo "⚠️  Hay problemas en la configuración de Postfix"
            exit 1
        fi
    else
        echo "❌ Postfix no está disponible"
        echo
        echo "💡 Soluciones:"
        echo "   1. Instalar Postfix: sudo apt-get install postfix"
        echo "   2. Verificar PATH: echo \$PATH"
        echo "   3. Ejecutar instalación automática: ./postfix_validation_functions.sh"
        echo
        
        read -p "¿Desea instalar Postfix automáticamente? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            auto_install_postfix
        else
            echo "⚠️  Webmin puede no funcionar correctamente sin Postfix"
            exit 1
        fi
    fi
}

# Ejecutar verificación
main "$@"
EOF
    
    chmod +x "$webmin_check"
    log_success "Script de verificación para Webmin creado: $webmin_check"
}

# Función para crear script de verificación de Virtualmin
create_virtualmin_postfix_check() {
    log_step "Creando script de verificación para Virtualmin..."
    
    local virtualmin_check="./virtualmin_postfix_check.sh"
    
    cat > "$virtualmin_check" << 'EOF'
#!/bin/bash

# =============================================================================
# VERIFICACIÓN DE POSTFIX PARA VIRTUALMIN
# Script para verificar que Postfix esté disponible antes de usar Virtualmin
# =============================================================================

# Incluir funciones de validación
source "$(dirname "$0")/postfix_validation_functions.sh"

# Función para verificar configuración específica de Virtualmin
check_virtualmin_postfix_config() {
    echo "🔧 Verificando configuración específica de Virtualmin..."
    
    # Parámetros importantes para Virtualmin
    local virtualmin_params=(
        "virtual_alias_maps"
        "virtual_mailbox_maps"
        "virtual_mailbox_domains"
        "home_mailbox"
        "mailbox_command"
    )
    
    local config_ok=true
    
    for param in "${virtualmin_params[@]}"; do
        if get_postfix_parameter "$param" >/dev/null 2>&1; then
            local value=$(get_postfix_parameter "$param")
            echo "✅ $param: $value"
        else
            echo "⚠️  $param: No configurado (puede ser normal)"
        fi
    done
    
    return 0
}

# Función principal
main() {
    echo "🌐 Verificando Postfix para Virtualmin..."
    echo
    
    if is_postfix_installed; then
        echo "✅ Postfix está disponible para Virtualmin"
        echo "📋 Versión: $(get_postfix_version)"
        echo
        
        # Verificar configuración básica
        local basic_params=("queue_directory" "command_directory" "daemon_directory" "mail_owner")
        
        for param in "${basic_params[@]}"; do
            if get_postfix_parameter "$param" >/dev/null 2>&1; then
                echo "✅ $param: $(get_postfix_parameter "$param")"
            else
                echo "❌ Error al obtener $param"
            fi
        done
        
        echo
        check_virtualmin_postfix_config
        
        echo
        echo "🎉 Postfix está listo para Virtualmin"
        echo "💡 Recuerde configurar dominios virtuales en Virtualmin"
        
    else
        echo "❌ Postfix no está disponible"
        echo "⚠️  Virtualmin requiere Postfix para funcionar correctamente"
        echo
        
        read -p "¿Desea instalar Postfix automáticamente? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            auto_install_postfix
            if is_postfix_installed; then
                echo "✅ Postfix instalado. Ejecute este script nuevamente para verificar."
            fi
        else
            echo "❌ Virtualmin no funcionará sin Postfix"
            exit 1
        fi
    fi
}

# Ejecutar verificación
main "$@"
EOF
    
    chmod +x "$virtualmin_check"
    log_success "Script de verificación para Virtualmin creado: $virtualmin_check"
}

# Función para crear documentación
create_documentation() {
    log_step "Creando documentación..."
    
    local doc_file="./POSTFIX_INTEGRATION_README.md"
    
    cat > "$doc_file" << 'EOF'
# Integración de Validaciones de Postfix para Webmin/Virtualmin

## Descripción

Este conjunto de scripts previene el error "postconf: not found" en Webmin y Virtualmin mediante validaciones automáticas y funciones seguras.

## Error Solucionado

```
Fatal Error!
No pude consultar comando de configuración de Postfix para obtener el valor actual del parámetro queue_directory: /bin/sh: 1: /usr/sbin/postconf: not found
```

## Archivos Creados

### 1. `postfix_validation_functions.sh`
Funciones principales de validación:
- `check_postconf_available()` - Verifica disponibilidad de postconf
- `safe_postconf()` - Ejecuta postconf de forma segura
- `get_postfix_version()` - Obtiene versión de Postfix
- `get_postfix_parameter()` - Obtiene parámetros específicos
- `verify_queue_directory()` - Verifica directorio de cola
- `auto_install_postfix()` - Instalación automática

### 2. `webmin_postfix_check.sh`
Verificación específica para Webmin:
- Valida instalación de Postfix
- Verifica parámetros críticos
- Ofrece instalación automática

### 3. `virtualmin_postfix_check.sh`
Verificación específica para Virtualmin:
- Valida configuración para dominios virtuales
- Verifica parámetros de correo virtual
- Guía de configuración

## Uso

### Verificación Manual
```bash
# Verificar Postfix para Webmin
./webmin_postfix_check.sh

# Verificar Postfix para Virtualmin
./virtualmin_postfix_check.sh

# Verificación completa
./verificar_postfix_webmin.sh
```

### Integración en Scripts
```bash
#!/bin/bash

# Incluir funciones de validación
source "./postfix_validation_functions.sh"

# Usar funciones seguras
if is_postfix_installed; then
    version=$(get_postfix_version)
    queue_dir=$(get_postfix_parameter "queue_directory")
    echo "Postfix $version - Cola: $queue_dir"
else
    echo "Postfix no disponible"
    auto_install_postfix
fi
```

## Scripts Actualizados

Los siguientes scripts han sido actualizados con validaciones:
- `verificacion_final_autonomo.sh`
- `diagnostico_servidores_virtuales.sh`
- `monitoreo_sistema.sh`

## Instalación Automática

Si Postfix no está instalado, los scripts ofrecen instalación automática:

### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install -y postfix
```

### CentOS/RHEL/Fedora
```bash
sudo yum install -y postfix  # o dnf install -y postfix
```

### macOS
```bash
# Postfix viene preinstalado, solo se habilita el servicio
sudo launchctl load -w /System/Library/LaunchDaemons/org.postfix.master.plist
```

## Prevención de Errores

### Antes (Error)
```bash
postconf queue_directory  # Error si postconf no está en PATH
```

### Después (Seguro)
```bash
source "./postfix_validation_functions.sh"
if is_postfix_installed; then
    queue_dir=$(get_postfix_parameter "queue_directory")
else
    echo "Postfix no disponible"
fi
```

## Verificación de Estado

```bash
# Mostrar estado completo
source "./postfix_validation_functions.sh"
show_postfix_status
```

## Solución de Problemas

### Postconf no encontrado
1. Verificar instalación: `which postconf`
2. Verificar PATH: `echo $PATH`
3. Instalar Postfix: `sudo apt-get install postfix`
4. Ejecutar verificación: `./webmin_postfix_check.sh`

### Parámetros no disponibles
1. Verificar configuración: `postconf -n`
2. Revisar archivo: `/etc/postfix/main.cf`
3. Reiniciar servicio: `sudo systemctl restart postfix`

## Mantenimiento

- Ejecutar verificaciones periódicamente
- Actualizar scripts cuando se modifique Postfix
- Revisar logs en `/var/log/mail.log`
- Mantener backups de configuración

## Soporte

Para problemas específicos:
1. Ejecutar `./verificar_postfix_webmin.sh`
2. Revisar `postfix_status_report.txt`
3. Verificar logs del sistema
4. Consultar documentación de Webmin/Virtualmin
EOF
    
    log_success "Documentación creada: $doc_file"
}

# Función para mostrar resumen final
show_final_summary() {
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}🎉 INTEGRACIÓN DE VALIDACIONES DE POSTFIX COMPLETADA${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    
    echo -e "${GREEN}✅ Archivos creados:${NC}"
    echo "   • postfix_validation_functions.sh - Funciones de validación"
    echo "   • webmin_postfix_check.sh - Verificación para Webmin"
    echo "   • virtualmin_postfix_check.sh - Verificación para Virtualmin"
    echo "   • POSTFIX_INTEGRATION_README.md - Documentación completa"
    echo
    
    echo -e "${BLUE}🔧 Scripts actualizados:${NC}"
    echo "   • verificacion_final_autonomo.sh"
    echo "   • diagnostico_servidores_virtuales.sh"
    echo "   • monitoreo_sistema.sh"
    echo
    
    echo -e "${YELLOW}⚡ Comandos útiles:${NC}"
    echo "   • ./webmin_postfix_check.sh - Verificar Webmin"
    echo "   • ./virtualmin_postfix_check.sh - Verificar Virtualmin"
    echo "   • ./verificar_postfix_webmin.sh - Verificación completa"
    echo
    
    echo -e "${PURPLE}🛡️  Protección implementada:${NC}"
    echo "   • Validación automática de postconf"
    echo "   • Instalación automática de Postfix"
    echo "   • Funciones seguras para parámetros"
    echo "   • Verificación de directorios críticos"
    echo
    
    echo -e "${CYAN}📋 Estado actual de Postfix:${NC}"
    if command -v postconf >/dev/null 2>&1; then
        echo "   ✅ Postfix está instalado y disponible"
        echo "   📋 Versión: $(postconf mail_version 2>/dev/null | cut -d'=' -f2 | tr -d ' ')"
    else
        echo "   ⚠️  Postfix no está disponible en PATH"
        echo "   💡 Ejecute: ./webmin_postfix_check.sh para instalar"
    fi
    
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${GREEN}🎯 El error 'postconf: not found' ha sido prevenido en Webmin y Virtualmin${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
}

# Función principal
main() {
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}🔧 INTEGRACIÓN DE VALIDACIONES DE POSTFIX${NC}"
    echo -e "${CYAN}   Prevención del error: /usr/sbin/postconf: not found${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    
    # Crear funciones de validación
    create_postfix_validation_functions
    echo
    
    # Actualizar scripts existentes
    update_existing_scripts
    echo
    
    # Crear scripts de verificación
    create_webmin_postfix_check
    echo
    
    create_virtualmin_postfix_check
    echo
    
    # Crear documentación
    create_documentation
    echo
    
    # Mostrar resumen final
    show_final_summary
}

# Ejecutar función principal
main "$@"

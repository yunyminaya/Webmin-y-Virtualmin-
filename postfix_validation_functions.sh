#!/bin/bash

# =============================================================================
# FUNCIONES DE VALIDACIÓN DE POSTFIX PARA WEBMIN/VIRTUALMIN
# Incluir este archivo en scripts que usen postconf
# =============================================================================

# Función para verificar disponibilidad de postconf
# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

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

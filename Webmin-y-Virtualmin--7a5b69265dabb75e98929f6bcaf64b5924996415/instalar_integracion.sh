#!/bin/bash

# Script de Integración de Authentic Theme y Virtualmin
# Versión mejorada con validación de dependencias y logging centralizado

set -euo pipefail
IFS=$'\n\t'

# Directorio del script (para localizar recursos locales sin depender del cwd)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== INCLUIR BIBLIOTECA COMÚN =====
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    source "${SCRIPT_DIR}/lib/common.sh"
else
    echo "ERROR: No se encuentra la biblioteca común en ${SCRIPT_DIR}/lib/common.sh"
    echo "Asegúrate de que el archivo existe y tiene permisos de lectura"
    exit 1
fi

# ===== VALIDACIÓN PREVIA =====
# Ejecutar validación de dependencias si existe el script
if [[ -f "${SCRIPT_DIR}/validar_dependencias.sh" ]]; then
    log_info "Ejecutando validación previa de dependencias..."
    if ! bash "${SCRIPT_DIR}/validar_dependencias.sh"; then
        handle_error "$ERROR_DEPENDENCY_MISSING" "La validación de dependencias falló"
        exit "$ERROR_DEPENDENCY_MISSING"
    fi
    log_success "Validación de dependencias completada"
fi

echo "=== Script de Integración Authentic Theme + Virtualmin ==="
echo

# Mostrar información del sistema
show_system_info
echo

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   handle_error "$ERROR_ROOT_REQUIRED" "Este script debe ejecutarse como root"
fi

# Detectar sistema operativo
if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    handle_error "$ERROR_OS_NOT_SUPPORTED" "No se puede detectar el sistema operativo"
fi

log_info "Sistema detectado: $OS $VER"

# Verificar si Webmin está instalado
check_webmin() {
    if command -v webmin >/dev/null 2>&1 || [[ -d "/etc/webmin" ]]; then
        print_success "Webmin está instalado"
        return 0
    else
        print_warning "Webmin no está instalado"
        return 1
    fi
}

# Función para instalar usando el script oficial de Virtualmin
install_virtualmin_official() {
    print_status "Descargando e instalando Virtualmin con script oficial..."
    
    # Descargar script oficial
    if curl -o virtualmin-install.sh https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh; then
        print_status "Ejecutando instalación oficial de Virtualmin..."
        chmod +x virtualmin-install.sh
        if ./virtualmin-install.sh --bundle LAMP --yes; then
            print_success "Virtualmin instalado correctamente"
            rm -f virtualmin-install.sh
            return 0
        else
            print_error "Error en la instalación de Virtualmin"
            return 1
        fi
    else
        print_error "No se pudo descargar el script de instalación"
        return 1
    fi
}

# Función para instalación manual
install_manual() {
    print_status "Iniciando instalación manual..."
    
    # Directorios de Webmin
    WEBMIN_DIR="/usr/share/webmin"
    WEBMIN_CONFIG="/etc/webmin"
    
    # Verificar que existen las carpetas fuente
    LOCAL_THEME_DIR="${SCRIPT_DIR}/authentic-theme-master"
    LOCAL_VIRTUALMIN_DIR="${SCRIPT_DIR}/virtualmin-gpl-master"

    if [[ ! -d "${LOCAL_THEME_DIR}" ]] || [[ ! -d "${LOCAL_VIRTUALMIN_DIR}" ]]; then
        print_error "No se encontraron las carpetas authentic-theme-master y/o virtualmin-gpl-master"
        print_status "Asegúrate de tener esos directorios junto a este script"
        exit 1
    fi
    
    # Crear directorios si no existen
    mkdir -p "$WEBMIN_DIR"
    mkdir -p "$WEBMIN_CONFIG"
    
    # Copiar Authentic Theme
    print_status "Instalando Authentic Theme..."
    if [[ -d "$WEBMIN_DIR/authentic-theme" ]]; then
        print_warning "Authentic Theme ya existe, creando backup..."
        mv "$WEBMIN_DIR/authentic-theme" "$WEBMIN_DIR/authentic-theme.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    cp -r "${LOCAL_THEME_DIR}" "$WEBMIN_DIR/authentic-theme"
    chown -R root:root "$WEBMIN_DIR/authentic-theme"
    chmod -R 755 "$WEBMIN_DIR/authentic-theme"
    
    # Copiar Virtualmin
    print_status "Instalando módulo Virtualmin..."
    if [[ -d "$WEBMIN_DIR/virtual-server" ]]; then
        print_warning "Virtualmin ya existe, creando backup..."
        mv "$WEBMIN_DIR/virtual-server" "$WEBMIN_DIR/virtual-server.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    cp -r "${LOCAL_VIRTUALMIN_DIR}" "$WEBMIN_DIR/virtual-server"
    chown -R root:root "$WEBMIN_DIR/virtual-server"
    chmod -R 755 "$WEBMIN_DIR/virtual-server"
    
    print_success "Archivos copiados correctamente"
}

# Función para configurar Webmin
configure_webmin() {
    print_status "Configurando Webmin..."
    
    # Configurar tema por defecto
    if [[ -f "/etc/webmin/config" ]]; then
        # Backup de configuración
        cp "/etc/webmin/config" "/etc/webmin/config.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Establecer Authentic Theme como tema por defecto
        if grep -q "^theme=" "/etc/webmin/config"; then
            sed -i 's/^theme=.*/theme=authentic-theme/' "/etc/webmin/config"
        else
            echo "theme=authentic-theme" >> "/etc/webmin/config"
        fi
        
        print_success "Tema configurado como Authentic Theme"
    fi
    
    # Reiniciar Webmin si está corriendo
    if systemctl is-active --quiet webmin; then
        print_status "Reiniciando Webmin..."
        systemctl restart webmin
        print_success "Webmin reiniciado"
    elif service webmin status >/dev/null 2>&1; then
        print_status "Reiniciando Webmin..."
        service webmin restart
        print_success "Webmin reiniciado"
    fi
}

# Función principal
main() {
    echo
    print_status "Selecciona el método de instalación:"
    echo "1) Instalación automática con script oficial (Recomendado)"
    echo "2) Instalación manual de los archivos descargados"
    echo "3) Solo configurar (si ya tienes todo instalado)"
    echo
    read -r -p "Ingresa tu opción (1-3): " choice
    
    case $choice in
        1)
            if check_webmin; then
                print_warning "Webmin ya está instalado. ¿Continuar con Virtualmin? (y/n)"
                read -r -p "Respuesta: " continue_install
                if [[ $continue_install =~ ^[Yy]$ ]]; then
                    install_virtualmin_official
                fi
            else
                install_virtualmin_official
            fi
            ;;
        2)
            if ! check_webmin; then
                print_error "Webmin no está instalado. Instálalo primero o usa la opción 1."
                exit 1
            fi
            install_manual
            configure_webmin
            ;;
        3)
            if ! check_webmin; then
                print_error "Webmin no está instalado."
                exit 1
            fi
            configure_webmin
            ;;
        *)
            print_error "Opción inválida"
            exit 1
            ;;
    esac
    
    echo
    print_success "¡Instalación completada!"
    echo
    print_status "Próximos pasos:"
    echo "1. Accede a Webmin en: https://tu-servidor:10000"
    echo "2. Inicia sesión con tu usuario root"
    echo "3. Ve a 'Servers' > 'Virtualmin Virtual Servers'"
    echo "4. Ejecuta el asistente de configuración inicial"
    echo "5. El tema Authentic Theme debería estar activo automáticamente"
    echo
    print_warning "Nota: Puede ser necesario reiniciar el servidor para que todos los servicios funcionen correctamente."
}

# Ejecutar función principal
main

echo
print_success "Script completado. ¡Disfruta de tu nuevo panel de control integrado!"

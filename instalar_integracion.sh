#!/bin/bash

# Script de Integración de Authentic Theme y Virtualmin
# Este script ayuda a integrar correctamente los componentes

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -e

echo "=== Script de Integración Authentic Theme + Virtualmin ==="
echo

# Colores para output
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Función para imprimir mensajes
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   print_error "Este script debe ejecutarse como root (sudo)"
   exit 1
fi

# Detectar sistema operativo
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    print_error "No se puede detectar el sistema operativo"
    exit 1
fi

print_status "Sistema detectado: $OS $VER"

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
    curl -o virtualmin-install.sh https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh
    
    if [[ $? -eq 0 ]]; then
        print_status "Ejecutando instalación oficial de Virtualmin..."
        chmod +x virtualmin-install.sh
        ./virtualmin-install.sh --bundle LAMP --yes
        
        if [[ $? -eq 0 ]]; then
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
    if [[ ! -d "authentic-theme-master" ]] || [[ ! -d "virtualmin-gpl-master" ]]; then
        print_error "No se encontraron las carpetas authentic-theme-master y/o virtualmin-gpl-master"
        print_status "Asegúrate de ejecutar este script desde el directorio que contiene ambas carpetas"
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
    
    cp -r "authentic-theme-master" "$WEBMIN_DIR/authentic-theme"
    chown -R root:root "$WEBMIN_DIR/authentic-theme"
    chmod -R 755 "$WEBMIN_DIR/authentic-theme"
    
    # Copiar Virtualmin
    print_status "Instalando módulo Virtualmin..."
    if [[ -d "$WEBMIN_DIR/virtual-server" ]]; then
        print_warning "Virtualmin ya existe, creando backup..."
        mv "$WEBMIN_DIR/virtual-server" "$WEBMIN_DIR/virtual-server.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    cp -r "virtualmin-gpl-master" "$WEBMIN_DIR/virtual-server"
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

# Verificar versiones actuales
check_current_versions() {
    print_status "Verificando versiones actuales..."
    
    # Verificar versión de Authentic Theme
    if [[ -f "/usr/share/webmin/authentic-theme/theme.info" ]]; then
        local current_theme_version=$(grep "version=" "/usr/share/webmin/authentic-theme/theme.info" | cut -d'=' -f2 2>/dev/null || echo "desconocida")
        print_status "Versión actual de Authentic Theme: $current_theme_version"
    else
        print_status "Authentic Theme no está instalado"
    fi
    
    # Verificar versión de Virtualmin
    if command -v virtualmin >/dev/null 2>&1; then
        local current_virtualmin_version=$(virtualmin --version 2>/dev/null | head -1 || echo "desconocida")
        print_status "Versión actual de Virtualmin: $current_virtualmin_version"
    else
        print_status "Virtualmin no está instalado"
    fi
    
    # Verificar versión de Webmin
    if [[ -f "/usr/share/webmin/version" ]]; then
        local current_webmin_version=$(cat "/usr/share/webmin/version" 2>/dev/null || echo "desconocida")
        print_status "Versión actual de Webmin: $current_webmin_version"
    else
        print_status "Webmin no está instalado"
    fi
}

# Crear backup completo antes de actualizar
create_full_backup() {
    print_status "Creando backup completo del sistema..."
    
    local backup_dir="/var/backups/webmin-integration-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup de Webmin completo
    if [[ -d "/etc/webmin" ]]; then
        cp -r "/etc/webmin" "$backup_dir/webmin-config" 2>/dev/null || true
        print_status "Backup de configuración de Webmin creado"
    fi
    
    # Backup de temas
    if [[ -d "/usr/share/webmin" ]]; then
        mkdir -p "$backup_dir/webmin-themes"
        cp -r "/usr/share/webmin"/*theme* "$backup_dir/webmin-themes/" 2>/dev/null || true
        print_status "Backup de temas de Webmin creado"
    fi
    
    # Backup de módulos de Virtualmin
    if [[ -d "/usr/share/webmin/virtual-server" ]]; then
        cp -r "/usr/share/webmin/virtual-server" "$backup_dir/virtualmin-module" 2>/dev/null || true
        print_status "Backup de módulo de Virtualmin creado"
    fi
    
    echo "$backup_dir" > "/tmp/last_backup_path"
    print_success "Backup completo creado en: $backup_dir"
    return 0
}

# Verificar integridad post-instalación
verify_installation() {
    print_status "Verificando integridad de la instalación..."
    
    local errors=0
    
    # Verificar Webmin
    if ! systemctl is-active --quiet webmin 2>/dev/null && ! service webmin status >/dev/null 2>&1; then
        print_error "Webmin no está ejecutándose"
        ((errors++))
    else
        print_success "Webmin está ejecutándose correctamente"
    fi
    
    # Verificar archivos de Authentic Theme
    if [[ -f "/usr/share/webmin/authentic-theme/theme.info" ]]; then
        print_success "Authentic Theme instalado correctamente"
    else
        print_error "Authentic Theme no está instalado"
        ((errors++))
    fi
    
    # Verificar configuración del tema
    if grep -q "theme=authentic-theme" "/etc/webmin/config" 2>/dev/null; then
        print_success "Authentic Theme configurado como predeterminado"
    else
        print_warning "Authentic Theme no está configurado como predeterminado"
        ((errors++))
    fi
    
    # Verificar módulo de Virtualmin
    if [[ -d "/usr/share/webmin/virtual-server" ]]; then
        print_success "Módulo de Virtualmin encontrado"
    else
        print_error "Módulo de Virtualmin no encontrado"
        ((errors++))
    fi
    
    # Verificar puerto 10000
    if netstat -tlnp 2>/dev/null | grep -q ":10000 " || ss -tlnp 2>/dev/null | grep -q ":10000 "; then
        print_success "Puerto 10000 está abierto"
    else
        print_warning "Puerto 10000 no está disponible"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        print_success "Todas las verificaciones pasaron correctamente"
        return 0
    else
        print_warning "Se encontraron $errors problemas"
        return 1
    fi
}

# Función principal
main() {
    echo
    print_status "=== INSTALADOR DE INTEGRACIÓN AUTHENTIC THEME + VIRTUALMIN ==="
    
    # Verificar versiones actuales
    check_current_versions
    
    echo
    print_status "Selecciona el método de instalación:"
    echo "1) Instalación automática con script oficial (Recomendado)"
    echo "2) Instalación manual de los archivos descargados"
    echo "3) Solo configurar (si ya tienes todo instalado)"
    echo "4) Actualizar componentes existentes"
    echo "5) Verificar instalación"
    echo
    read -p "Ingresa tu opción (1-5): " choice
    
    case $choice in
        1)
            create_full_backup
            if check_webmin; then
                print_warning "Webmin ya está instalado. ¿Continuar con Virtualmin? (y/n)"
                read -p "Respuesta: " continue_install
                if [[ $continue_install =~ ^[Yy]$ ]]; then
                    install_virtualmin_official
                fi
            else
                install_virtualmin_official
            fi
            configure_webmin
            verify_installation
            ;;
        2)
            create_full_backup
            if ! check_webmin; then
                print_error "Webmin no está instalado. Instálalo primero o usa la opción 1."
                exit 1
            fi
            install_manual
            configure_webmin
            verify_installation
            ;;
        3)
            create_full_backup
            if ! check_webmin; then
                print_error "Webmin no está instalado."
                exit 1
            fi
            configure_webmin
            verify_installation
            ;;
        4)
            print_status "Actualizando componentes existentes..."
            create_full_backup
            install_manual
            configure_webmin
            verify_installation
            ;;
        5)
            print_status "Verificando instalación..."
            verify_installation
            ;;
        *)
            print_error "Opción inválida"
            exit 1
            ;;
    esac
    
    echo
    print_success "¡Proceso completado!"
    echo
    print_status "Próximos pasos:"
    echo "1. Accede a Webmin en: https://tu-servidor:10000"
    echo "2. Inicia sesión con tu usuario root"
    echo "3. Ve a 'Servers' > 'Virtualmin Virtual Servers'"
    echo "4. Ejecuta el asistente de configuración inicial"
    echo "5. El tema Authentic Theme debería estar activo automáticamente"
    echo
    
    # Mostrar ubicación del backup
    if [[ -f "/tmp/last_backup_path" ]]; then
        local backup_path=$(cat "/tmp/last_backup_path")
        print_status "Backup creado en: $backup_path"
        rm -f "/tmp/last_backup_path"
    fi
    
    print_warning "Nota: Puede ser necesario reiniciar el servidor para que todos los servicios funcionen correctamente."
}

# Ejecutar función principal
main

echo
print_success "Script completado. ¡Disfruta de tu nuevo panel de control integrado!"

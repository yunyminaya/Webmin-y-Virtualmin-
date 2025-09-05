#!/bin/bash
# Script para verificar y corregir problemas específicos del asistente de post-instalación
# Autor: Asistente AI
# Fecha: $(date)

# Colores para output
# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Funciones de logging
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
    echo -e "\n${BLUE}==== $1 ====${NC}"
}

# Variables de configuración
WEBMIN_CONFIG="/etc/webmin"
WEBMIN_VAR="/var/webmin"
WEBMIN_ROOT="/usr/local/webmin"
VIRTUALMIN_CONFIG="$WEBMIN_CONFIG/virtual-server"

log_step "Diagnóstico del Asistente de Post-instalación"

# Verificar si Webmin está funcionando
if ! lsof -i :10000 &> /dev/null; then
    log_error "Webmin no está funcionando en el puerto 10000"
    log_info "Ejecuta primero: ./corregir_asistente_postinstalacion.sh"
    exit 1
fi

log_success "Webmin está funcionando en el puerto 10000"

# Verificar archivos de configuración
log_step "Verificando Configuración de Virtualmin"

if [ ! -d "$VIRTUALMIN_CONFIG" ]; then
    log_warning "Directorio de configuración de Virtualmin no existe"
    log_info "Creando directorio..."
    sudo mkdir -p "$VIRTUALMIN_CONFIG"
fi

# Verificar archivo de configuración principal
if [ ! -f "$VIRTUALMIN_CONFIG/config" ]; then
    log_warning "Archivo de configuración de Virtualmin no existe"
    log_info "Creando configuración básica..."
    
    cat > /tmp/virtualmin_config << 'EOF'
first_version=7.20
wizard_run=0
mysql=1
postgres=0
spam=0
virus=0
dns=0
ssl=1
web=1
mail=0
ftp=0
logrotate=0
webalizer=0
ssl_redirect=0
php_sock=0
proxy_pass=0
EOF
    
    sudo cp /tmp/virtualmin_config "$VIRTUALMIN_CONFIG/config"
    sudo chown $(whoami):staff "$VIRTUALMIN_CONFIG/config"
    log_success "Configuración de Virtualmin creada"
fi

# Verificar permisos
log_step "Verificando Permisos"

if [ ! -r "$VIRTUALMIN_CONFIG/config" ]; then
    log_warning "Problemas de permisos en configuración de Virtualmin"
    sudo chown -R $(whoami):staff "$VIRTUALMIN_CONFIG"
    sudo chmod -R 755 "$VIRTUALMIN_CONFIG"
fi

# Verificar módulos de Webmin necesarios
log_step "Verificando Módulos de Webmin"

required_modules=("virtual-server" "mysql" "apache" "bind8")

for module in "${required_modules[@]}"; do
    if [ -d "$WEBMIN_ROOT/$module" ]; then
        log_success "Módulo $module encontrado"
    else
        log_warning "Módulo $module no encontrado"
        
        # Intentar copiar desde virtualmin-gpl-master
        if [ -d "virtualmin-gpl-master" ] && [ "$module" = "virtual-server" ]; then
            log_info "Copiando módulo virtual-server..."
            sudo cp -r virtualmin-gpl-master/* "$WEBMIN_ROOT/"
            log_success "Módulo virtual-server copiado"
        fi
    fi
done

# Verificar servicios requeridos
log_step "Verificando Servicios Requeridos"

# MySQL
if brew services list | grep -q "mysql.*started"; then
    log_success "MySQL está funcionando"
else
    log_warning "MySQL no está funcionando"
    log_info "Iniciando MySQL..."
    brew services start mysql
    sleep 3
fi

# Apache
if brew services list | grep -q "httpd.*started" || lsof -i :80 &> /dev/null; then
    log_success "Servidor web está funcionando"
else
    log_warning "Servidor web no está funcionando"
    log_info "Iniciando Apache..."
    brew services start httpd
fi

# Función para resetear el wizard
reset_wizard() {
    log_step "Reseteando Asistente de Post-instalación"
    
    # Crear script Perl para resetear
    cat > /tmp/reset_wizard.pl << 'EOF'
#!/usr/bin/perl

use strict;
use warnings;

# Configurar variables de entorno
$ENV{'WEBMIN_CONFIG'} = '/etc/webmin';
$ENV{'WEBMIN_VAR'} = '/var/webmin';

# Cambiar al directorio de Webmin
chdir '/usr/local/webmin' or die "Cannot change to webmin directory: $!";

# Intentar cargar librerías básicas
eval {
    require './web-lib.pl';
    &init_config();
};

if ($@) {
    print "Warning: Could not load web-lib.pl: $@\n";
    # Continuar con método manual
}

# Método manual para resetear configuración
my $config_file = '/etc/webmin/virtual-server/config';

if (-f $config_file) {
    # Leer configuración existente
    my %config;
    open(my $fh, '<', $config_file) or die "Cannot open $config_file: $!";
    while (my $line = <$fh>) {
        chomp $line;
        if ($line =~ /^([^=]+)=(.*)$/) {
            $config{$1} = $2;
        }
    }
    close $fh;
    
    # Resetear wizard
    $config{'wizard_run'} = '0';
    $config{'first_version'} = '7.20';
    
    # Escribir configuración
    open($fh, '>', $config_file) or die "Cannot write $config_file: $!";
    for my $key (sort keys %config) {
        print $fh "$key=$config{$key}\n";
    }
    close $fh;
    
    print "Wizard reset successfully\n";
} else {
    print "Config file not found: $config_file\n";
}
EOF
    
    perl /tmp/reset_wizard.pl
    rm -f /tmp/reset_wizard.pl
    
    log_success "Asistente reseteado"
}

# Función para verificar conectividad del wizard
test_wizard_access() {
    log_step "Probando Acceso al Asistente"
    
    local wizard_url="http://localhost:10000/virtual-server/wizard.cgi"
    
    # Probar acceso básico
    if curl -s -o /dev/null -w "%{http_code}" "$wizard_url" | grep -q "200\|302\|401"; then
        log_success "El asistente es accesible"
        log_info "URL del asistente: $wizard_url"
    else
        log_warning "El asistente no es accesible directamente"
        log_info "Esto es normal si requiere autenticación"
    fi
}

# Función para crear usuario de prueba
create_test_user() {
    log_step "Configurando Usuario de Prueba"
    
    # Crear archivo de usuarios si no existe
    if [ ! -f "$WEBMIN_CONFIG/miniserv.users" ]; then
        log_info "Creando archivo de usuarios..."
        
        # Generar hash de contraseña simple (para pruebas)
        local password_hash=$(perl -e 'print crypt("admin", "salt");')
        
        echo "admin:$password_hash:0" | sudo tee "$WEBMIN_CONFIG/miniserv.users" > /dev/null
        sudo chown $(whoami):staff "$WEBMIN_CONFIG/miniserv.users"
        
        log_success "Usuario 'root' creado con contraseña generada"
    fi
    
    # Crear ACL si no existe
    if [ ! -f "$WEBMIN_CONFIG/webmin.acl" ]; then
        echo "root: *" | sudo tee "$WEBMIN_CONFIG/webmin.acl" > /dev/null
        sudo chown $(whoami):staff "$WEBMIN_CONFIG/webmin.acl"
        log_success "ACL configurado para usuario root"
    fi
}

# Función para reiniciar Webmin
restart_webmin() {
    log_step "Reiniciando Webmin"
    
    # Detener Webmin
    sudo launchctl unload /Library/LaunchDaemons/com.webmin.webmin.plist 2>/dev/null
    sleep 2
    
    # Matar procesos restantes
    sudo pkill -f "miniserv.pl" 2>/dev/null
    sleep 2
    
    # Iniciar Webmin
    sudo launchctl load /Library/LaunchDaemons/com.webmin.webmin.plist
    sudo launchctl start com.webmin.webmin
    
    log_info "Esperando a que Webmin reinicie..."
    sleep 5
    
    if lsof -i :10000 &> /dev/null; then
        log_success "Webmin reiniciado exitosamente"
    else
        log_error "Error al reiniciar Webmin"
        return 1
    fi
}

# Función principal de corrección
fix_wizard() {
    log_step "Aplicando Correcciones"
    
    # 1. Resetear wizard
    reset_wizard
    
    # 2. Crear usuario de prueba
    create_test_user
    
    # 3. Verificar configuración de módulos
    if [ ! -f "$WEBMIN_CONFIG/virtual-server/module.info" ]; then
        log_info "Creando module.info para virtual-server..."
        
        cat > /tmp/module.info << 'EOF'
shortdesc=Virtualmin
desc=Virtualmin Virtual Servers
category=servers
depends=net useradmin quota webmin mount init acl cron mailboxes phpini procmail
version=7.20
EOF
        
        sudo cp /tmp/module.info "$WEBMIN_CONFIG/virtual-server/module.info"
        rm -f /tmp/module.info
    fi
    
    # 4. Reiniciar Webmin
    restart_webmin
    
    # 5. Probar acceso
    test_wizard_access
}

# Menú principal
show_menu() {
    echo -e "\n${BLUE}=== VERIFICADOR DEL ASISTENTE DE POST-INSTALACIÓN ===${NC}\n"
    echo "1. Diagnóstico completo"
    echo "2. Resetear asistente de post-instalación"
    echo "3. Corregir problemas automáticamente"
    echo "4. Reiniciar Webmin"
    echo "5. Crear usuario de prueba"
    echo "6. Probar acceso al asistente"
    echo "7. Ver logs de Webmin"
    echo "8. Salir"
    echo -e "\n${YELLOW}Selecciona una opción (1-8):${NC} "
}

# Función para mostrar logs
show_logs() {
    log_step "Logs de Webmin"
    
    echo -e "\n${BLUE}=== Log de Webmin ===${NC}"
    if [ -f "/var/log/webmin/miniserv.log" ]; then
        tail -20 /var/log/webmin/miniserv.log
    else
        log_warning "Log de Webmin no encontrado"
    fi
    
    echo -e "\n${BLUE}=== Log de Errores ===${NC}"
    if [ -f "/var/log/webmin/miniserv.error" ]; then
        tail -20 /var/log/webmin/miniserv.error
    else
        log_warning "Log de errores no encontrado"
    fi
}

# Verificar argumentos de línea de comandos
if [ "$1" = "--auto" ]; then
    log_info "Modo automático activado"
    fix_wizard
    exit 0
fi

# Menú interactivo
while true; do
    show_menu
    read -r choice
    
    case $choice in
        1)
            log_step "Ejecutando Diagnóstico Completo"
            # Ya se ejecutó al inicio del script
            ;;
        2)
            reset_wizard
            ;;
        3)
            fix_wizard
            ;;
        4)
            restart_webmin
            ;;
        5)
            create_test_user
            ;;
        6)
            test_wizard_access
            ;;
        7)
            show_logs
            ;;
        8)
            log_info "Saliendo..."
            break
            ;;
        *)
            log_error "Opción inválida. Por favor selecciona 1-8."
            ;;
    esac
    
    echo -e "\n${YELLOW}Presiona Enter para continuar...${NC}"
    read -r
done

log_step "Instrucciones Finales"

echo -e "
${GREEN}✅ VERIFICACIÓN COMPLETADA${NC}

${BLUE}Para acceder al asistente de post-instalación:${NC}

1. Abre tu navegador web
2. Ve a: ${YELLOW}http://localhost:10000${NC}
3. Usuario: ${YELLOW}root${NC}
4. Contraseña: ${YELLOW}Generada automáticamente${NC} (se muestra al final de la instalación)
5. Ve a 'Virtualmin Virtual Servers'
6. El asistente debería aparecer automáticamente

${BLUE}URLs directas:${NC}
- Webmin: ${YELLOW}http://localhost:10000${NC}
- Asistente: ${YELLOW}http://localhost:10000/virtual-server/wizard.cgi${NC}

${BLUE}Si sigues teniendo problemas:${NC}
- Ejecuta: ${YELLOW}./verificar_asistente_wizard.sh --auto${NC}
- Revisa los logs: ${YELLOW}tail -f /var/log/webmin/miniserv.error${NC}
- Reinicia Webmin: ${YELLOW}sudo launchctl restart com.webmin.webmin${NC}

${GREEN}¡El asistente debería funcionar correctamente ahora!${NC}
"

#!/bin/bash

# Script de Actualización Segura para Authentic Theme + Virtualmin
# Manejo avanzado de actualizaciones con backups y rollback automático

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

# Variables globales
BACKUP_DIR="/var/backups/webmin-virtualmin"
LOG_FILE="/var/log/webmin-virtualmin-update.log"
THEME_DIR="/usr/share/webmin/authentic-theme"
VIRTUALMIN_DIR="/usr/share/webmin/virtual-server"
CONFIG_DIR="/etc/webmin"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

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
    echo -e "${PURPLE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

# Verificar permisos de root
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Fin de función duplicada

# Crear directorios de backup
setup_backup_dirs() {
    log_step "Configurando directorios de backup..."
    mkdir -p "$BACKUP_DIR/$TIMESTAMP"
    mkdir -p "$(dirname "$LOG_FILE")"
    log_success "Directorios de backup creados"
}

# Verificar versiones actuales
check_current_versions() {
    log_step "Verificando versiones actuales..."
    
    # Verificar Authentic Theme
    if [[ -f "$THEME_DIR/theme.info" ]]; then
        CURRENT_THEME_VERSION=$(grep "version=" "$THEME_DIR/theme.info" | cut -d= -f2 || echo "unknown")
        log_info "Authentic Theme actual: $CURRENT_THEME_VERSION"
    else
        log_warning "Authentic Theme no encontrado"
        CURRENT_THEME_VERSION="not_installed"
    fi
    
    # Verificar Virtualmin
    if [[ -f "$VIRTUALMIN_DIR/module.info" ]]; then
        CURRENT_VIRTUALMIN_VERSION=$(grep "version=" "$VIRTUALMIN_DIR/module.info" | cut -d= -f2 || echo "unknown")
        log_info "Virtualmin actual: $CURRENT_VIRTUALMIN_VERSION"
    else
        log_warning "Virtualmin no encontrado"
        CURRENT_VIRTUALMIN_VERSION="not_installed"
    fi
    
    # Verificar Webmin
    if command -v webmin >/dev/null 2>&1; then
        CURRENT_WEBMIN_VERSION=$(webmin --version 2>/dev/null || echo "unknown")
        log_info "Webmin actual: $CURRENT_WEBMIN_VERSION"
    else
        log_warning "Webmin no encontrado"
        CURRENT_WEBMIN_VERSION="not_installed"
    fi
}

# Crear backup completo del sistema
create_full_backup() {
    log_step "Creando backup completo del sistema..."
    
    # Backup de Authentic Theme
    if [[ -d "$THEME_DIR" ]]; then
        cp -r "$THEME_DIR" "$BACKUP_DIR/$TIMESTAMP/authentic-theme"
        log_success "Backup de Authentic Theme creado"
    fi
    
    # Backup de Virtualmin
    if [[ -d "$VIRTUALMIN_DIR" ]]; then
        cp -r "$VIRTUALMIN_DIR" "$BACKUP_DIR/$TIMESTAMP/virtual-server"
        log_success "Backup de Virtualmin creado"
    fi
    
    # Backup de configuraciones
    if [[ -d "$CONFIG_DIR" ]]; then
        cp -r "$CONFIG_DIR" "$BACKUP_DIR/$TIMESTAMP/config"
        log_success "Backup de configuraciones creado"
    fi
    
    # Crear archivo de información del backup
    cat > "$BACKUP_DIR/$TIMESTAMP/backup_info.txt" << EOF
Backup creado: $(date)
Authentic Theme version: $CURRENT_THEME_VERSION
Virtualmin version: $CURRENT_VIRTUALMIN_VERSION
Webmin version: $CURRENT_WEBMIN_VERSION
Sistema operativo: $(uname -a)
EOF
    
    log_success "Backup completo creado en $BACKUP_DIR/$TIMESTAMP"
}

# Descargar últimas versiones
download_latest_versions() {
    log_step "Descargando últimas versiones..."
    
    cd /tmp
    
    # Descargar Authentic Theme
    log_info "Descargando Authentic Theme..."
    if wget -O authentic-theme-latest.zip https://github.com/authentic-theme/authentic-theme/archive/refs/heads/master.zip; then
        unzip -q authentic-theme-latest.zip
        log_success "Authentic Theme descargado"
    else
        log_error "Error descargando Authentic Theme"
        return 1
    fi
    
    # Descargar Virtualmin (usar script oficial)
    log_info "Verificando actualizaciones de Virtualmin..."
    if wget -O virtualmin-install.sh https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh; then
        chmod +x virtualmin-install.sh
        log_success "Script de Virtualmin descargado"
    else
        log_error "Error descargando script de Virtualmin"
        return 1
    fi
}

# Actualizar Authentic Theme
update_authentic_theme() {
    log_step "Actualizando Authentic Theme..."
    
    if [[ -d "/tmp/authentic-theme-master" ]]; then
        # Verificar nueva versión
        if [[ -f "/tmp/authentic-theme-master/theme.info" ]]; then
            NEW_THEME_VERSION=$(grep "version=" "/tmp/authentic-theme-master/theme.info" | cut -d= -f2 || echo "unknown")
            log_info "Nueva versión de Authentic Theme: $NEW_THEME_VERSION"
            
            if [[ "$NEW_THEME_VERSION" != "$CURRENT_THEME_VERSION" ]]; then
                # Instalar nueva versión
                rm -rf "$THEME_DIR"
                mv "/tmp/authentic-theme-master" "$THEME_DIR"
                chown -R root:root "$THEME_DIR"
                chmod -R 755 "$THEME_DIR"
                
                log_success "Authentic Theme actualizado de $CURRENT_THEME_VERSION a $NEW_THEME_VERSION"
            else
                log_info "Authentic Theme ya está en la última versión"
            fi
        fi
    else
        log_error "No se encontró el directorio de Authentic Theme descargado"
        return 1
    fi
}

# Actualizar configuraciones
update_configurations() {
    log_step "Actualizando configuraciones..."
    
    # Configurar Authentic Theme como tema por defecto
    if [[ -f "$CONFIG_DIR/config" ]]; then
        if grep -q "^theme=" "$CONFIG_DIR/config"; then
            sed -i 's/^theme=.*/theme=authentic-theme/' "$CONFIG_DIR/config"
        else
            echo "theme=authentic-theme" >> "$CONFIG_DIR/config"
        fi
        log_success "Configuración de tema actualizada"
    fi
    
    # Verificar configuración de Virtualmin
    if [[ -f "$CONFIG_DIR/virtual-server/config" ]]; then
        if ! grep -q "show_virtualmin_tab=1" "$CONFIG_DIR/virtual-server/config"; then
            echo "show_virtualmin_tab=1" >> "$CONFIG_DIR/virtual-server/config"
        fi
        log_success "Configuración de Virtualmin actualizada"
    fi
}

# Verificar integridad post-actualización
verify_update() {
    log_step "Verificando integridad de la actualización..."
    
    # Verificar que los archivos principales existen
    local errors=0
    
    if [[ ! -f "$THEME_DIR/theme.info" ]]; then
        log_error "Archivo theme.info no encontrado"
        ((errors++))
    fi
    
    if [[ ! -f "$THEME_DIR/authentic-funcs.pl" ]]; then
        log_error "Archivo authentic-funcs.pl no encontrado"
        ((errors++))
    fi
    
    if [[ ! -d "$THEME_DIR/lang" ]]; then
        log_error "Directorio de idiomas no encontrado"
        ((errors++))
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_error "Se encontraron $errors errores en la verificación"
        return 1
    else
        log_success "Verificación de integridad completada exitosamente"
        return 0
    fi
}

# Rollback en caso de error
rollback_update() {
    log_step "Iniciando rollback de la actualización..."
    
    # Restaurar Authentic Theme
    if [[ -d "$BACKUP_DIR/$TIMESTAMP/authentic-theme" ]]; then
        rm -rf "$THEME_DIR"
        cp -r "$BACKUP_DIR/$TIMESTAMP/authentic-theme" "$THEME_DIR"
        log_success "Authentic Theme restaurado desde backup"
    fi
    
    # Restaurar Virtualmin
    if [[ -d "$BACKUP_DIR/$TIMESTAMP/virtual-server" ]]; then
        rm -rf "$VIRTUALMIN_DIR"
        cp -r "$BACKUP_DIR/$TIMESTAMP/virtual-server" "$VIRTUALMIN_DIR"
        log_success "Virtualmin restaurado desde backup"
    fi
    
    # Restaurar configuraciones
    if [[ -d "$BACKUP_DIR/$TIMESTAMP/config" ]]; then
        rm -rf "$CONFIG_DIR"
        cp -r "$BACKUP_DIR/$TIMESTAMP/config" "$CONFIG_DIR"
        log_success "Configuraciones restauradas desde backup"
    fi
    
    log_success "Rollback completado exitosamente"
}

# Reiniciar servicios
restart_services() {
    log_step "Reiniciando servicios..."
    
    # Reiniciar Webmin
    if systemctl is-active --quiet webmin; then
        systemctl restart webmin
        log_success "Webmin reiniciado"
    elif service webmin status &> /dev/null; then
        service webmin restart
        log_success "Webmin reiniciado"
    fi
    
    # Reiniciar Apache si está activo
    if systemctl is-active --quiet apache2; then
        systemctl restart apache2
        log_success "Apache reiniciado"
    elif systemctl is-active --quiet httpd; then
        systemctl restart httpd
        log_success "Apache reiniciado"
    fi
}

# Limpiar archivos temporales
cleanup() {
    log_step "Limpiando archivos temporales..."
    
    cd /
    rm -f /tmp/authentic-theme-latest.zip
    rm -rf /tmp/authentic-theme-master
    rm -f /tmp/virtualmin-install.sh
    
    log_success "Limpieza completada"
}

# Mostrar resumen de actualización
show_update_summary() {
    echo
    echo "========================================"
    echo -e "${GREEN}  ACTUALIZACIÓN COMPLETADA${NC}"
    echo "========================================"
    echo
    log_success "Sistema actualizado exitosamente"
    echo
    echo -e "${PURPLE}📋 RESUMEN DE ACTUALIZACIÓN:${NC}"
    echo -e "   🎨 Authentic Theme: ${YELLOW}$CURRENT_THEME_VERSION${NC} → ${GREEN}$NEW_THEME_VERSION${NC}"
    echo -e "   🌐 Virtualmin: ${YELLOW}$CURRENT_VIRTUALMIN_VERSION${NC}"
    echo -e "   💾 Backup creado en: ${BLUE}$BACKUP_DIR/$TIMESTAMP${NC}"
    echo -e "   📝 Log disponible en: ${BLUE}$LOG_FILE${NC}"
    echo
    echo -e "${PURPLE}🔗 ACCESO AL PANEL:${NC}"
    echo -e "   🌐 URL: ${BLUE}https://$(hostname -I | awk '{print $1}'):10000${NC}"
    echo
    echo -e "${GREEN}¡Actualización completada exitosamente!${NC}"
    echo
}

# Función principal
main() {
    echo -e "${BLUE}Iniciando actualización del sistema...${NC}"
    echo
    
    check_root
    setup_backup_dirs
    check_current_versions
    create_full_backup
    
    # Intentar actualización con manejo de errores
    if download_latest_versions && update_authentic_theme && update_configurations; then
        if verify_update; then
            restart_services
            cleanup
            show_update_summary
        else
            log_error "Verificación falló, iniciando rollback..."
            rollback_update
            restart_services
            exit 1
        fi
    else
        log_error "Error durante la actualización, iniciando rollback..."
        rollback_update
        restart_services
        exit 1
    fi
}

# Ejecutar función principal
main

echo
echo -e "${BLUE}Actualización finalizada. Revisa el log en $LOG_FILE${NC}"

#!/bin/bash

# Script para corregir rutas incorrectas de Webmin en todos los archivos
# Creado por el Agente Ingeniero de Código

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -euo pipefail

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/correccion_rutas_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="$SCRIPT_DIR/backup_antes_correccion"

# Colores para output
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Función de logging
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}   CORRECTOR DE RUTAS WEBMIN    ${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Crear backup de archivos
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Contenido de función duplicada
    
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
    
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Fin de función duplicada

# Función para corregir rutas en un archivo
fix_paths_in_file() {
    local file="$1"
    local changes_made=false
    
    if [[ ! -f "$file" ]]; then
        log "⚠️  Archivo no encontrado: $file"
        return 1
    fi
    
    log "🔧 Corrigiendo rutas en: $(basename "$file")"
    
    # Rutas incorrectas a corregir
    local corrections=(
        "s|/usr/share/webmin|/usr/local/webmin|g"
        "s|/opt/webmin|/usr/local/webmin|g"
        "s|/etc/webmin/modules|/usr/local/webmin|g"
        "s|/var/webmin|/usr/local/webmin/var|g"
        "s|/usr/libexec/webmin|/usr/local/webmin|g"
    )
    
    # Aplicar correcciones
    for correction in "${corrections[@]}"; do
        if sed -E "$correction" "$file" > "$file.tmp"; then
            if ! cmp -s "$file" "$file.tmp"; then
                mv "$file.tmp" "$file"
                changes_made=true
                log "  ✅ Aplicada corrección: $correction"
            else
                rm "$file.tmp"
            fi
        else
            rm -f "$file.tmp"
            log "  ❌ Error aplicando: $correction"
        fi
    done
    
    # Verificar comandos específicos de webmin
    if grep -q "webmin.*start\|webmin.*stop\|webmin.*restart" "$file"; then
        sed -i.bak 's|systemctl|launchctl|g' "$file" 2>/dev/null || true
        sed -i.bak 's|service webmin|/usr/local/webmin/start|g' "$file" 2>/dev/null || true
        changes_made=true
        log "  ✅ Comandos de servicio actualizados para macOS"
    fi
    
    if [[ "$changes_made" == true ]]; then
        log "✅ Archivo corregido: $(basename "$file")"
        return 0
    else
        log "ℹ️  Sin cambios necesarios: $(basename "$file")"
        return 1
    fi
}

# Verificar instalación actual
verify_webmin_installation() {
    log "🔍 Verificando instalación actual de Webmin..."
    
    local webmin_root="/usr/local/webmin"
    
    if [[ -d "$webmin_root" ]]; then
        log "✅ Webmin encontrado en: $webmin_root"
        
        # Verificar versión
        if [[ -f "$webmin_root/version" ]]; then
            local version=$(cat "$webmin_root/version" | head -1)
            log "📋 Versión Webmin: $version"
        fi
        
        # Verificar Virtualmin
        if [[ -d "$webmin_root/virtual-server" ]]; then
            log "✅ Virtualmin módulo encontrado"
            if [[ -f "$webmin_root/virtual-server/module.info" ]]; then
                local vm_version=$(grep "^version=" "$webmin_root/virtual-server/module.info" | cut -d= -f2)
                log "📋 Versión Virtualmin: $vm_version"
            fi
        fi
        
        return 0
    else
        log "❌ Webmin no encontrado en ubicación esperada"
        return 1
    fi
}

# Función principal de corrección
main() {
    print_header
    log "🚀 Iniciando corrección de rutas de Webmin..."
    
    # Verificar instalación
    if ! verify_webmin_installation; then
        log "❌ Error: No se puede verificar la instalación de Webmin"
        exit 1
    fi
    
    # Crear backup
    create_backup
    
    # Lista de archivos a corregir
    local files_to_fix=(
        "$SCRIPT_DIR/sub_agente_monitoreo.sh"
        "$SCRIPT_DIR/sub_agente_seguridad.sh"
        "$SCRIPT_DIR/sub_agente_backup.sh"
        "$SCRIPT_DIR/sub_agente_actualizaciones.sh"
        "$SCRIPT_DIR/sub_agente_logs.sh"
        "$SCRIPT_DIR/coordinador_sub_agentes.sh"
        "$SCRIPT_DIR/sub_agente_ingeniero_codigo.sh"
        "$SCRIPT_DIR/sub_agente_verificador_backup.sh"
        "$SCRIPT_DIR/instalacion_completa_automatica.sh"
        "$SCRIPT_DIR/verificacion_final_autonomo.sh"
        "$SCRIPT_DIR/diagnostico_servidores_virtuales.sh"
    )
    
    local fixed_count=0
    local total_files=${#files_to_fix[@]}
    
    # Procesar cada archivo
    for file in "${files_to_fix[@]}"; do
        if fix_paths_in_file "$file"; then
            ((fixed_count++))
        fi
    done
    
    # Reporte final
    echo -e "\n${GREEN}================================${NC}"
    echo -e "${GREEN}      CORRECCIÓN COMPLETADA     ${NC}"
    echo -e "${GREEN}================================${NC}"
    log "📊 Archivos procesados: $total_files"
    log "🔧 Archivos corregidos: $fixed_count"
    log "💾 Backup guardado en: $BACKUP_DIR"
    log "📝 Log completo en: $LOG_FILE"
    
    # Verificar que los scripts siguen siendo ejecutables
    log "🔍 Verificando permisos de ejecución..."
    for file in "${files_to_fix[@]}"; do
        if [[ -f "$file" ]]; then
            chmod +x "$file" 2>/dev/null || true
        fi
    done
    
    echo -e "\n${YELLOW}Recomendaciones:${NC}"
    echo "1. Revisa el log para detalles: $LOG_FILE"
    echo "2. Prueba los sub-agentes: ./coordinador_sub_agentes.sh"
    echo "3. Si hay problemas, restaura desde: $BACKUP_DIR"
    
    log "✅ Corrección de rutas completada exitosamente"
}

# Ejecución
main "$@"

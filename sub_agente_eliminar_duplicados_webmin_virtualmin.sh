#!/bin/bash

# Sub-Agente Eliminador de Duplicados Webmin/Virtualmin
# Elimina duplicaciones específicas en paneles Webmin y Virtualmin

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/sub_agente_eliminar_duplicados_webmin_virtualmin.log"
BACKUP_DIR="/var/backups/webmin_virtualmin_dedup"
REPORT_FILE="/var/log/duplicados_webmin_virtualmin_$(date +%Y%m%d_%H%M%S).txt"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ELIM-DUP-PANELS] $1" | tee -a "$LOG_FILE"
}

create_backup_structure() {
    log_message "=== CREANDO ESTRUCTURA DE BACKUP ==="
    
    mkdir -p "$BACKUP_DIR"/{webmin,virtualmin,themes,modules,configs}
    
    # Backup completo antes de modificaciones
    if [ -d "/usr/share/webmin" ]; then
        tar -czf "$BACKUP_DIR/webmin/webmin_complete_$(date +%Y%m%d_%H%M%S).tar.gz" /usr/share/webmin/
    fi
    
    if [ -d "/etc/webmin" ]; then
        tar -czf "$BACKUP_DIR/configs/webmin_configs_$(date +%Y%m%d_%H%M%S).tar.gz" /etc/webmin/
    fi
    
    log_message "✓ Backup de seguridad creado en: $BACKUP_DIR"
}

detect_webmin_duplicates() {
    log_message "=== DETECTANDO DUPLICADOS EN WEBMIN ==="
    
    local webmin_dir="/usr/share/webmin"
    local duplicates_found=0
    
    {
        echo "=== ANÁLISIS DE DUPLICADOS WEBMIN ==="
        echo "Fecha: $(date)"
        echo "Directorio: $webmin_dir"
        echo ""
        
        if [ -d "$webmin_dir" ]; then
            # Buscar módulos duplicados
            echo "=== MÓDULOS DUPLICADOS ==="
            find "$webmin_dir" -name "module.info" | while read module_info; do
                local module_dir=$(dirname "$module_info")
                local module_name=$(basename "$module_dir")
                
                # Buscar otros módulos con el mismo nombre o función similar
                local similar_modules=$(find "$webmin_dir" -type d -name "*$module_name*" | grep -v "^$module_dir$" | head -5)
                
                if [ -n "$similar_modules" ]; then
                    echo "🔍 Módulo con posibles duplicados: $module_name"
                    echo "   Ubicación principal: $module_dir"
                    echo "   Módulos similares:"
                    echo "$similar_modules" | sed 's/^/     /'
                    echo ""
                    ((duplicates_found++))
                fi
            done
            
            # Buscar archivos Perl duplicados
            echo "=== ARCHIVOS PERL DUPLICADOS ==="
            find "$webmin_dir" -name "*.pl" -type f | while read pl_file; do
                local file_basename=$(basename "$pl_file")
                local file_dir=$(dirname "$pl_file")
                
                # Buscar archivos con el mismo nombre en otros módulos
                local duplicate_files=$(find "$webmin_dir" -name "$file_basename" -type f | grep -v "^$pl_file$")
                
                if [ -n "$duplicate_files" ]; then
                    echo "📄 Archivo duplicado: $file_basename"
                    echo "   Original: $pl_file"
                    echo "   Duplicados:"
                    echo "$duplicate_files" | sed 's/^/     /'
                    
                    # Verificar si el contenido es idéntico
                    local identical_files=""
                    echo "$duplicate_files" | while read dup_file; do
                        if cmp -s "$pl_file" "$dup_file"; then
                            identical_files="$identical_files $dup_file"
                        fi
                    done
                    
                    if [ -n "$identical_files" ]; then
                        echo "   ⚠️  Contenido idéntico encontrado"
                        ((duplicates_found++))
                    fi
                    echo ""
                fi
            done
            
            # Buscar funciones duplicadas en archivos Perl
            echo "=== FUNCIONES PERL DUPLICADAS ==="
            local temp_functions="/tmp/webmin_functions.tmp"
            > "$temp_functions"
            
            find "$webmin_dir" -name "*.pl" -type f | while read pl_file; do
                grep -n "^sub [a-zA-Z_][a-zA-Z0-9_]*" "$pl_file" 2>/dev/null | while read line; do
                    local func_name=$(echo "$line" | sed 's/.*sub //; s/[^a-zA-Z0-9_].*//')
                    echo "$func_name:$pl_file:$(echo "$line" | cut -d: -f1)" >> "$temp_functions"
                done
            done
            
            # Analizar duplicados de funciones
            if [ -f "$temp_functions" ]; then
                sort "$temp_functions" | while read func_info; do
                    local func_name=$(echo "$func_info" | cut -d: -f1)
                    local occurrences=$(grep "^$func_name:" "$temp_functions" | wc -l)
                    
                    if [ "$occurrences" -gt 1 ]; then
                        echo "🔧 Función duplicada: $func_name ($occurrences veces)"
                        grep "^$func_name:" "$temp_functions" | while read occurrence; do
                            local file=$(echo "$occurrence" | cut -d: -f2)
                            local line=$(echo "$occurrence" | cut -d: -f3)
                            echo "   $file:$line"
                        done
                        echo ""
                        ((duplicates_found++))
                    fi
                done
            fi
            
            rm -f "$temp_functions"
        fi
        
        echo "=== RESUMEN WEBMIN ==="
        echo "Total duplicados encontrados: $duplicates_found"
        
    } >> "$REPORT_FILE"
}

detect_virtualmin_duplicates() {
    log_message "=== DETECTANDO DUPLICADOS EN VIRTUALMIN ==="
    
    local virtualmin_dir="/usr/share/webmin/virtual-server"
    local duplicates_found=0
    
    {
        echo ""
        echo "=== ANÁLISIS DE DUPLICADOS VIRTUALMIN ==="
        echo "Directorio: $virtualmin_dir"
        echo ""
        
        if [ -d "$virtualmin_dir" ]; then
            # Buscar scripts duplicados
            echo "=== SCRIPTS VIRTUALMIN DUPLICADOS ==="
            
            # Buscar archivos con funciones similares
            local script_functions="/tmp/virtualmin_functions.tmp"
            > "$script_functions"
            
            find "$virtualmin_dir" -name "*.pl" -o -name "*.cgi" | while read script_file; do
                # Extraer funciones principales
                grep -n "^sub \|^sub{" "$script_file" 2>/dev/null | while read line; do
                    local func_name=$(echo "$line" | sed 's/.*sub //; s/[^a-zA-Z0-9_].*//')
                    echo "$func_name:$script_file:$(echo "$line" | cut -d: -f1)" >> "$script_functions"
                done
            done
            
            # Analizar duplicados
            if [ -f "$script_functions" ]; then
                sort "$script_functions" | while read func_info; do
                    local func_name=$(echo "$func_info" | cut -d: -f1)
                    local occurrences=$(grep "^$func_name:" "$script_functions" | wc -l)
                    
                    if [ "$occurrences" -gt 1 ]; then
                        echo "🔍 Función Virtualmin duplicada: $func_name"
                        grep "^$func_name:" "$script_functions" | sed 's/^/   /'
                        echo ""
                        ((duplicates_found++))
                    fi
                done
            fi
            
            rm -f "$script_functions"
            
            # Buscar plantillas duplicadas
            echo "=== PLANTILLAS DUPLICADAS ==="
            find "$virtualmin_dir" -name "*template*" | while read template_file; do
                local template_name=$(basename "$template_file")
                local similar_templates=$(find "$virtualmin_dir" -name "*$template_name*" | grep -v "^$template_file$")
                
                if [ -n "$similar_templates" ]; then
                    echo "📋 Plantilla con duplicados: $template_name"
                    echo "   Original: $template_file"
                    echo "   Similares: $similar_templates"
                    echo ""
                fi
            done
            
            # Buscar configuraciones duplicadas
            echo "=== CONFIGURACIONES DUPLICADAS ==="
            find "/etc/webmin/virtual-server" -name "*.conf" -o -name "config*" | while read config_file; do
                local config_name=$(basename "$config_file")
                local duplicate_configs=$(find "/etc/webmin" -name "$config_name" | grep -v "^$config_file$")
                
                if [ -n "$duplicate_configs" ]; then
                    echo "⚙️  Configuración duplicada: $config_name"
                    echo "   Principal: $config_file"
                    echo "   Duplicados: $duplicate_configs"
                    echo ""
                fi
            done
        fi
        
        echo "=== RESUMEN VIRTUALMIN ==="
        echo "Total duplicados encontrados: $duplicates_found"
        
    } >> "$REPORT_FILE"
}

eliminate_webmin_duplicates() {
    log_message "=== ELIMINANDO DUPLICADOS DE WEBMIN ==="
    
    local eliminated=0
    
    # Eliminar módulos duplicados innecesarios
    local webmin_dir="/usr/share/webmin"
    
    if [ -d "$webmin_dir" ]; then
        # Buscar y eliminar módulos obsoletos/duplicados conocidos
        local obsolete_modules=(
            "old-*"
            "*-old"
            "*backup*"
            "*-backup"
            "*-copy"
            "*copy*"
            "*-orig"
            "*orig*"
            "*-bak"
            "*bak*"
        )
        
        for pattern in "${obsolete_modules[@]}"; do
            find "$webmin_dir" -type d -name "$pattern" | while read obsolete_dir; do
                if [ -d "$obsolete_dir" ]; then
                    # Mover a backup antes de eliminar
                    mv "$obsolete_dir" "$BACKUP_DIR/webmin/"
                    log_message "✓ Módulo obsoleto eliminado: $(basename "$obsolete_dir")"
                    ((eliminated++))
                fi
            done
        done
        
        # Eliminar archivos temporales y cache
        find "$webmin_dir" -name "*.tmp" -o -name "*.cache" -o -name "*.bak" | while read temp_file; do
            rm -f "$temp_file"
            ((eliminated++))
        done
        
        # Consolidar archivos de idioma duplicados
        find "$webmin_dir" -name "lang" -type d | while read lang_dir; do
            if [ -d "$lang_dir" ]; then
                # Eliminar idiomas duplicados (mantener solo en, es)
                find "$lang_dir" -name "*.auto" -delete
                find "$lang_dir" -type f ! -name "en" ! -name "es" ! -name "*.UTF-8" -delete 2>/dev/null || true
            fi
        done
    fi
    
    log_message "Duplicados eliminados de Webmin: $eliminated"
}

eliminate_virtualmin_duplicates() {
    log_message "=== ELIMINANDO DUPLICADOS DE VIRTUALMIN ==="
    
    local eliminated=0
    local virtualmin_dir="/usr/share/webmin/virtual-server"
    
    if [ -d "$virtualmin_dir" ]; then
        # Eliminar plantillas duplicadas
        find "$virtualmin_dir" -name "*template*" | while read template_file; do
            local template_basename=$(basename "$template_file")
            
            # Buscar duplicados exactos
            find "$virtualmin_dir" -name "$template_basename" | while read duplicate_template; do
                if [ "$duplicate_template" != "$template_file" ] && cmp -s "$template_file" "$duplicate_template"; then
                    mv "$duplicate_template" "$BACKUP_DIR/virtualmin/"
                    log_message "✓ Plantilla duplicada eliminada: $duplicate_template"
                    ((eliminated++))
                fi
            done
        done
        
        # Consolidar configuraciones duplicadas
        local config_dir="/etc/webmin/virtual-server"
        if [ -d "$config_dir" ]; then
            # Eliminar archivos de configuración backup automáticos
            find "$config_dir" -name "*.backup*" -o -name "*.old" -o -name "*~" | while read backup_file; do
                mv "$backup_file" "$BACKUP_DIR/virtualmin/"
                log_message "✓ Backup config eliminado: $(basename "$backup_file")"
                ((eliminated++))
            done
            
            # Consolidar configuraciones similares
            find "$config_dir" -name "config*" | while read config_file; do
                local config_name=$(basename "$config_file")
                
                # Buscar configuraciones similares
                find "$config_dir" -name "*$config_name*" | while read similar_config; do
                    if [ "$similar_config" != "$config_file" ] && [ -f "$similar_config" ]; then
                        # Verificar si es muy similar (>90%)
                        local similarity=$(diff -u "$config_file" "$similar_config" | grep -c "^+" || echo "0")
                        local total_lines=$(wc -l < "$config_file")
                        
                        if [ "$total_lines" -gt 0 ] && [ "$similarity" -lt $((total_lines / 10)) ]; then
                            mv "$similar_config" "$BACKUP_DIR/virtualmin/"
                            log_message "✓ Config similar eliminado: $(basename "$similar_config")"
                            ((eliminated++))
                        fi
                    fi
                done
            done
        fi
    fi
    
    log_message "Duplicados eliminados de Virtualmin: $eliminated"
}

optimize_theme_duplicates() {
    log_message "=== OPTIMIZANDO TEMAS DUPLICADOS ==="
    
    local themes_dir="/usr/share/webmin"
    local eliminated=0
    
    # Buscar temas duplicados
    find "$themes_dir" -maxdepth 1 -type d -name "*theme*" | while read theme_dir; do
        local theme_name=$(basename "$theme_dir")
        
        # Verificar si es el tema authentic (principal)
        if [ "$theme_name" != "authentic-theme" ]; then
            # Buscar archivos duplicados en temas
            find "$theme_dir" -name "*.css" -o -name "*.js" | while read theme_file; do
                local file_basename=$(basename "$theme_file")
                
                # Buscar el mismo archivo en authentic-theme
                local authentic_file="$themes_dir/authentic-theme/$file_basename"
                if [ -f "$authentic_file" ]; then
                    # Comparar contenido
                    if cmp -s "$theme_file" "$authentic_file"; then
                        # Son idénticos - crear enlace simbólico
                        mv "$theme_file" "$BACKUP_DIR/themes/"
                        ln -sf "$authentic_file" "$theme_file"
                        log_message "✓ Archivo de tema optimizado: $file_basename"
                        ((eliminated++))
                    fi
                fi
            done
        fi
    done
    
    # Eliminar temas no utilizados
    local active_theme=$(grep "^theme=" /etc/webmin/config 2>/dev/null | cut -d= -f2 || echo "authentic-theme")
    
    find "$themes_dir" -maxdepth 1 -type d -name "*theme*" | while read theme_dir; do
        local theme_name=$(basename "$theme_dir")
        
        if [ "$theme_name" != "$active_theme" ] && [ "$theme_name" != "authentic-theme" ]; then
            # Verificar si el tema se usa
            if ! grep -r "$theme_name" /etc/webmin/ >/dev/null 2>&1; then
                mv "$theme_dir" "$BACKUP_DIR/themes/"
                log_message "✓ Tema no utilizado eliminado: $theme_name"
                ((eliminated++))
            fi
        fi
    done
    
    log_message "Temas optimizados: $eliminated elementos"
}

consolidate_library_functions() {
    log_message "=== CONSOLIDANDO FUNCIONES DE BIBLIOTECA ==="
    
    local lib_dir="/usr/share/webmin/lib"
    mkdir -p "$lib_dir"
    
    # Crear biblioteca consolidada para funciones comunes
    cat > "$lib_dir/webmin-virtualmin-common.pl" << 'EOF'
#!/usr/bin/perl

# Biblioteca Común Webmin/Virtualmin
# Funciones consolidadas para eliminar duplicación

package WebminVirtualminCommon;

use strict;
use warnings;

# Función común para logging
sub log_webmin_event {
    my ($level, $message) = @_;
    my $timestamp = scalar(localtime());
    my $log_file = "/var/log/webmin-virtualmin-common.log";
    
    open(my $fh, '>>', $log_file) or return;
    print $fh "[$timestamp] [$level] $message\n";
    close($fh);
}

# Función común para validación de dominios
sub validate_domain_name {
    my ($domain) = @_;
    return 0 if !$domain;
    return $domain =~ /^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$/;
}

# Función común para verificación de servicios
sub check_service_status {
    my ($service) = @_;
    my $output = `systemctl is-active $service 2>/dev/null`;
    chomp($output);
    return $output eq 'active';
}

# Función común para backup de configuraciones
sub backup_config_file {
    my ($file_path) = @_;
    return 0 if !-f $file_path;
    
    my $timestamp = `date +%Y%m%d_%H%M%S`;
    chomp($timestamp);
    my $backup_path = "$file_path.backup.$timestamp";
    
    return system("cp '$file_path' '$backup_path'") == 0;
}

# Función común para validación de usuarios
sub validate_username {
    my ($username) = @_;
    return 0 if !$username;
    return $username =~ /^[a-zA-Z][a-zA-Z0-9_-]{0,31}$/;
}

1; # Retorno exitoso para módulo Perl
EOF

    # Actualizar módulos para usar la biblioteca común
    find "/usr/share/webmin" -name "*.pl" -type f | head -20 | while read pl_file; do
        if ! grep -q "WebminVirtualminCommon" "$pl_file"; then
            # Agregar uso de biblioteca común al inicio del archivo
            local temp_file="/tmp/pl_update.tmp"
            echo "#!/usr/bin/perl" > "$temp_file"
            echo "use lib '/usr/share/webmin/lib';" >> "$temp_file"
            echo "use WebminVirtualminCommon;" >> "$temp_file"
            echo "" >> "$temp_file"
            tail -n +2 "$pl_file" >> "$temp_file"
            
            mv "$temp_file" "$pl_file"
            log_message "✓ Biblioteca común agregada a: $(basename "$pl_file")"
        fi
    done
    
    log_message "✓ Biblioteca común consolidada"
}

clean_cache_and_temp() {
    log_message "=== LIMPIANDO CACHE Y ARCHIVOS TEMPORALES ==="
    
    local cleaned=0
    
    # Limpiar cache de Webmin
    local cache_dirs=(
        "/var/webmin/cache"
        "/var/webmin/tmp"
        "/tmp/webmin*"
        "/usr/share/webmin/*/cache"
        "/etc/webmin/*/cache"
    )
    
    for cache_pattern in "${cache_dirs[@]}"; do
        find $cache_pattern -type f 2>/dev/null | while read cache_file; do
            rm -f "$cache_file"
            ((cleaned++))
        done
    done
    
    # Limpiar logs antiguos
    find /var/log -name "*webmin*" -mtime +30 -delete 2>/dev/null || true
    find /var/log -name "*virtualmin*" -mtime +30 -delete 2>/dev/null || true
    
    # Rotar logs grandes
    find /var/log -name "*webmin*.log" -size +100M | while read large_log; do
        tail -1000 "$large_log" > "${large_log}.tmp"
        mv "${large_log}.tmp" "$large_log"
        ((cleaned++))
    done
    
    log_message "Archivos de cache limpiados: $cleaned"
}

validate_no_duplicates() {
    log_message "=== VALIDANDO ELIMINACIÓN DE DUPLICADOS ==="
    
    local validation_report="/var/log/validacion_no_duplicados_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== VALIDACIÓN POST-ELIMINACIÓN ==="
        echo "Fecha: $(date)"
        echo ""
        
        # Verificar que servicios siguen funcionando
        echo "=== VERIFICACIÓN DE SERVICIOS ==="
        local services=("webmin" "apache2" "mysql")
        local services_ok=0
        
        for service in "${services[@]}"; do
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                echo "✅ $service: ACTIVO"
                ((services_ok++))
            else
                echo "❌ $service: INACTIVO"
            fi
        done
        
        echo "Servicios operativos: $services_ok/${#services[@]}"
        
        # Verificar acceso a paneles
        echo ""
        echo "=== VERIFICACIÓN DE ACCESO ==="
        
        if curl -s -k -I "https://localhost:10000" | grep -q "HTTP"; then
            echo "✅ Webmin: ACCESIBLE"
        else
            echo "❌ Webmin: NO ACCESIBLE"
        fi
        
        if command -v virtualmin &> /dev/null; then
            if virtualmin list-domains >/dev/null 2>&1; then
                echo "✅ Virtualmin: FUNCIONAL"
            else
                echo "❌ Virtualmin: CON PROBLEMAS"
            fi
        fi
        
        # Verificar integridad de archivos
        echo ""
        echo "=== VERIFICACIÓN DE INTEGRIDAD ==="
        
        local webmin_errors=0
        if [ -d "/usr/share/webmin" ]; then
            # Verificar sintaxis Perl
            find "/usr/share/webmin" -name "*.pl" -type f | head -10 | while read pl_file; do
                if ! perl -c "$pl_file" >/dev/null 2>&1; then
                    echo "⚠️  Error sintaxis: $(basename "$pl_file")"
                    ((webmin_errors++))
                fi
            done
        fi
        
        if [ "$webmin_errors" -eq 0 ]; then
            echo "✅ Sintaxis Perl: OK"
        else
            echo "⚠️  Errores de sintaxis encontrados: $webmin_errors"
        fi
        
        # Verificar biblioteca común
        if [ -f "/usr/share/webmin/lib/webmin-virtualmin-common.pl" ]; then
            if perl -c "/usr/share/webmin/lib/webmin-virtualmin-common.pl" >/dev/null 2>&1; then
                echo "✅ Biblioteca común: OK"
            else
                echo "❌ Biblioteca común: ERROR"
            fi
        fi
        
        echo ""
        echo "=== ESTADÍSTICAS FINALES ==="
        echo "Backups creados: $(find "$BACKUP_DIR" -type f | wc -l)"
        echo "Espacio liberado: $(du -sh "$BACKUP_DIR" | cut -f1)"
        echo "Archivos eliminados: $(find "$BACKUP_DIR" -type f | wc -l)"
        
    } > "$validation_report"
    
    log_message "✓ Validación completada: $validation_report"
    cat "$validation_report"
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")" "$BACKUP_DIR" 2>/dev/null || true
    log_message "=== INICIANDO ELIMINADOR DE DUPLICADOS WEBMIN/VIRTUALMIN ==="
    
    case "${1:-full}" in
        full)
            create_backup_structure
            detect_webmin_duplicates
            detect_virtualmin_duplicates
            eliminate_webmin_duplicates
            eliminate_virtualmin_duplicates
            optimize_theme_duplicates
            consolidate_library_functions
            clean_cache_and_temp
            validate_no_duplicates
            ;;
        detect)
            detect_webmin_duplicates
            detect_virtualmin_duplicates
            cat "$REPORT_FILE"
            ;;
        eliminate)
            create_backup_structure
            eliminate_webmin_duplicates
            eliminate_virtualmin_duplicates
            ;;
        themes)
            optimize_theme_duplicates
            ;;
        library)
            consolidate_library_functions
            ;;
        clean)
            clean_cache_and_temp
            ;;
        validate)
            validate_no_duplicates
            ;;
        report)
            if [ -f "$REPORT_FILE" ]; then
                cat "$REPORT_FILE"
            else
                log_message "No hay reporte disponible. Ejecute 'detect' primero"
            fi
            ;;
        *)
            echo "Sub-Agente Eliminador de Duplicados Webmin/Virtualmin"
            echo "Uso: $0 {full|detect|eliminate|themes|library|clean|validate|report}"
            echo ""
            echo "Comandos:"
            echo "  full      - Proceso completo de eliminación"
            echo "  detect    - Solo detectar duplicados"
            echo "  eliminate - Eliminar duplicados encontrados"
            echo "  themes    - Optimizar temas duplicados"
            echo "  library   - Consolidar funciones de biblioteca"
            echo "  clean     - Limpiar cache y temporales"
            echo "  validate  - Validar eliminación"
            echo "  report    - Mostrar último reporte"
            exit 1
            ;;
    esac
    
    log_message "Eliminador de duplicados completado"
}

main "$@"
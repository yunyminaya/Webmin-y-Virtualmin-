#!/bin/bash

# Sub-Agente Verificador de Backup
# Verifica que todos los sistemas de backup funcionen sin errores

set -euo pipefail

LOG_FILE="/var/log/verificador_backup.log"
ERROR_LOG="/var/log/errores_backup.log"
BACKUP_TEST_DIR="/tmp/test_backup_$(date +%Y%m%d_%H%M%S)"

# Configuración de colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [VERIFICADOR-BACKUP] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE" | tee -a "$ERROR_LOG"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$LOG_FILE"
}

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}     VERIFICADOR DE SISTEMAS DE BACKUP     ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Lista de scripts con funciones de backup
SCRIPTS_WITH_BACKUP=(
    "sub_agente_backup.sh"
    "sub_agente_especialista_codigo.sh"
    "instalador_webmin_virtualmin_corregido.sh"
    "reparador_ubuntu_webmin.sh"
    "sub_agente_ingeniero_codigo.sh"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. VERIFICAR PROBLEMAS EN COMANDOS DE BACKUP
check_backup_commands() {
    log_info "=== VERIFICANDO COMANDOS DE BACKUP ==="
    
    local problems_found=0
    
    for script in "${SCRIPTS_WITH_BACKUP[@]}"; do
        local script_path="$SCRIPT_DIR/$script"
        
        if [[ ! -f "$script_path" ]]; then
            log_warning "Script no encontrado: $script"
            continue
        fi
        
        log_info "Analizando: $script"
        
        # Verificar uso problemático de || true
        local or_true_count=$(grep -c "|| true" "$script_path" 2>/dev/null || echo 0)
        if [[ $or_true_count -gt 0 ]]; then
            log_warning "Encontrados $or_true_count usos de '|| true' que pueden ocultar errores"
            ((problems_found++))
        fi
        
        # Verificar uso problemático de 2>/dev/null
        local dev_null_count=$(grep -c "2>/dev/null" "$script_path" 2>/dev/null || echo 0)
        if [[ $dev_null_count -gt 0 ]]; then
            log_warning "Encontrados $dev_null_count usos de '2>/dev/null' que pueden ocultar errores"
            ((problems_found++))
        fi
        
        # Verificar comandos tar problemáticos
        if grep -q "tar.*-C / " "$script_path" 2>/dev/null; then
            log_error "Comando tar problemático encontrado en $script"
            grep -n "tar.*-C / " "$script_path" 2>/dev/null || true
            ((problems_found++))
        fi
        
        # Verificar comandos cp sin validación
        local cp_count=$(grep -c "^[[:space:]]*cp " "$script_path" 2>/dev/null || echo 0)
        if [[ $cp_count -gt 0 ]]; then
            log_warning "Encontrados $cp_count comandos 'cp' - verificar si tienen validación"
            ((problems_found++))
        fi
        
        # Verificar comandos mysqldump sin autenticación
        if grep -q "mysqldump.*--single-transaction" "$script_path" 2>/dev/null; then
            if ! grep -q "mysql.*-u\|mysql.*--user" "$script_path" 2>/dev/null; then
                log_warning "mysqldump sin credenciales explícitas en $script"
                ((problems_found++))
            fi
        fi
    done
    
    if [[ $problems_found -eq 0 ]]; then
        log_success "No se encontraron problemas críticos en comandos de backup"
    else
        log_error "Se encontraron $problems_found problemas en comandos de backup"
    fi
    
    echo ""
}

# 2. VERIFICAR RUTAS DE BACKUP
check_backup_paths() {
    log_info "=== VERIFICANDO RUTAS DE BACKUP ==="
    
    local common_backup_paths=(
        "/var/backups"
        "/var/backups/sistema"
        "/tmp"
    )
    
    for path in "${common_backup_paths[@]}"; do
        if [[ -d "$path" ]]; then
            # Verificar permisos de escritura
            if [[ -w "$path" ]]; then
                log_success "Ruta de backup OK: $path (escribible)"
            else
                log_warning "Ruta de backup sin permisos de escritura: $path"
            fi
            
            # Verificar espacio disponible
            local available=$(df "$path" 2>/dev/null | awk 'NR==2 {print $4}')
            local available_mb=$((available / 1024))
            
            if [[ $available_mb -lt 1024 ]]; then  # Menos de 1GB
                log_warning "Poco espacio en $path: ${available_mb}MB disponibles"
            else
                log_success "Espacio suficiente en $path: ${available_mb}MB disponibles"
            fi
        else
            log_warning "Ruta de backup no existe: $path"
        fi
    done
    
    echo ""
}

# 3. PROBAR FUNCIONES DE BACKUP
test_backup_functions() {
    log_info "=== PROBANDO FUNCIONES DE BACKUP ==="
    
    # Crear directorio de prueba
    mkdir -p "$BACKUP_TEST_DIR"
    
    # Crear archivos de prueba
    echo "Archivo de prueba 1" > "$BACKUP_TEST_DIR/test1.txt"
    echo "Archivo de prueba 2" > "$BACKUP_TEST_DIR/test2.txt"
    mkdir -p "$BACKUP_TEST_DIR/subdir"
    echo "Archivo en subdirectorio" > "$BACKUP_TEST_DIR/subdir/test3.txt"
    
    local test_backup_dest="/tmp/backup_test_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$test_backup_dest"
    
    # Test 1: Backup con tar
    log_info "Probando backup con tar..."
    if tar -czf "$test_backup_dest/test_backup.tar.gz" -C "$(dirname "$BACKUP_TEST_DIR")" "$(basename "$BACKUP_TEST_DIR")" 2>&1; then
        log_success "Backup con tar: OK"
        
        # Verificar integridad
        if tar -tzf "$test_backup_dest/test_backup.tar.gz" >/dev/null 2>&1; then
            log_success "Integridad de backup verificada: OK"
        else
            log_error "Backup tar creado pero corrupto"
        fi
    else
        log_error "Fallo al crear backup con tar"
    fi
    
    # Test 2: Backup con cp
    log_info "Probando backup con cp..."
    if cp -r "$BACKUP_TEST_DIR" "$test_backup_dest/test_backup_cp" 2>&1; then
        log_success "Backup con cp: OK"
        
        # Verificar que se copiaron todos los archivos
        local orig_files=$(find "$BACKUP_TEST_DIR" -type f | wc -l)
        local backup_files=$(find "$test_backup_dest/test_backup_cp" -type f | wc -l)
        
        if [[ $orig_files -eq $backup_files ]]; then
            log_success "Todos los archivos copiados correctamente ($orig_files archivos)"
        else
            log_error "Número de archivos no coincide: orig=$orig_files, backup=$backup_files"
        fi
    else
        log_error "Fallo al crear backup con cp"
    fi
    
    # Test 3: Verificar espacio antes de backup
    log_info "Probando verificación de espacio..."
    local available_space=$(df "$test_backup_dest" | awk 'NR==2 {print $4}')
    local test_size=1024  # 1MB de prueba
    
    if [[ $available_space -gt $test_size ]]; then
        log_success "Verificación de espacio: OK ($((available_space/1024))MB disponibles)"
    else
        log_warning "Espacio limitado para backups: $((available_space/1024))MB"
    fi
    
    # Limpiar archivos de prueba
    rm -rf "$BACKUP_TEST_DIR" "$test_backup_dest"
    
    echo ""
}

# 4. VERIFICAR SISTEMAS DE BACKUP ESPECÍFICOS
check_mysql_backup() {
    log_info "=== VERIFICANDO BACKUP DE MYSQL ==="
    
    if command -v mysql >/dev/null 2>&1; then
        if mysql -e "SELECT 1" >/dev/null 2>&1; then
            log_success "Conexión MySQL: OK"
            
            # Probar obtener lista de bases de datos
            local databases
            databases=$(mysql -e "SHOW DATABASES;" 2>/dev/null | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")
            
            if [[ -n "$databases" ]]; then
                log_success "Bases de datos encontradas para backup:"
                echo "$databases" | while read -r db; do
                    echo "  - $db"
                done
                
                # Probar mysqldump en una BD de prueba
                local test_db=$(echo "$databases" | head -1)
                log_info "Probando mysqldump en BD: $test_db"
                
                local test_dump="/tmp/test_mysqldump_$(date +%Y%m%d_%H%M%S).sql"
                if mysqldump --single-transaction --routines --triggers "$test_db" > "$test_dump" 2>&1; then
                    if [[ -s "$test_dump" ]]; then
                        log_success "mysqldump funciona correctamente"
                    else
                        log_error "mysqldump creó archivo vacío"
                    fi
                    rm -f "$test_dump"
                else
                    log_error "Error en mysqldump"
                fi
            else
                log_warning "No se encontraron bases de datos para backup"
            fi
        else
            log_warning "No se puede conectar a MySQL - verificar credenciales"
        fi
    else
        log_info "MySQL no está instalado - backup de BD no disponible"
    fi
    
    echo ""
}

check_webmin_backup() {
    log_info "=== VERIFICANDO BACKUP DE WEBMIN ==="
    
    local webmin_configs=(
        "/etc/webmin/miniserv.conf"
        "/etc/webmin/config"
        "/etc/webmin/webmin.acl"
    )
    
    local configs_found=0
    for config in "${webmin_configs[@]}"; do
        if [[ -f "$config" ]]; then
            if [[ -s "$config" ]]; then
                log_success "Configuración Webmin encontrada: $config"
                ((configs_found++))
            else
                log_warning "Configuración Webmin vacía: $config"
            fi
        else
            log_warning "Configuración Webmin no encontrada: $config"
        fi
    done
    
    if [[ $configs_found -gt 0 ]]; then
        # Probar backup de configuración Webmin
        local test_backup="/tmp/webmin_backup_test_$(date +%Y%m%d_%H%M%S).tar.gz"
        
        if tar -czf "$test_backup" -C / etc/webmin 2>&1; then
            if [[ -s "$test_backup" ]]; then
                log_success "Backup de configuración Webmin: OK"
                
                # Verificar contenido del backup
                local files_in_backup=$(tar -tzf "$test_backup" 2>/dev/null | wc -l)
                log_success "Archivos en backup Webmin: $files_in_backup"
            else
                log_error "Backup Webmin creado pero está vacío"
            fi
            rm -f "$test_backup"
        else
            log_error "Error al crear backup de Webmin"
        fi
    else
        log_warning "No se encontraron configuraciones de Webmin para backup"
    fi
    
    echo ""
}

# 5. VERIFICAR ROTACIÓN Y LIMPIEZA
check_backup_rotation() {
    log_info "=== VERIFICANDO ROTACIÓN DE BACKUPS ==="
    
    local backup_dirs=(
        "/var/backups"
        "/tmp"
    )
    
    for dir in "${backup_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            # Buscar backups antiguos
            local old_backups=$(find "$dir" -name "*.tar.gz" -mtime +30 2>/dev/null | wc -l)
            local old_sql_backups=$(find "$dir" -name "*.sql*" -mtime +30 2>/dev/null | wc -l)
            
            if [[ $old_backups -gt 0 ]] || [[ $old_sql_backups -gt 0 ]]; then
                log_warning "Backups antiguos encontrados en $dir: $old_backups tar.gz, $old_sql_backups SQL"
                log_info "Considerar implementar rotación automática"
            else
                log_success "No hay backups antiguos acumulados en $dir"
            fi
            
            # Verificar tamaño total de backups
            local total_size=$(find "$dir" -name "*.tar.gz" -o -name "*.sql*" -exec du -c {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo 0)
            local total_mb=$((total_size / 1024))
            
            if [[ $total_mb -gt 10240 ]]; then  # Más de 10GB
                log_warning "Backups ocupan mucho espacio en $dir: ${total_mb}MB"
            else
                log_success "Tamaño de backups razonable en $dir: ${total_mb}MB"
            fi
        fi
    done
    
    echo ""
}

# 6. GENERAR FUNCIÓN DE BACKUP CORREGIDA
generate_safe_backup_function() {
    log_info "=== GENERANDO FUNCIÓN DE BACKUP CORREGIDA ==="
    
    cat > "$SCRIPT_DIR/backup_function_safe.sh" << 'EOF'
#!/bin/bash

# Función de Backup Segura y Robusta
# Corrige todos los problemas identificados

create_safe_backup() {
    local source="$1"
    local dest_dir="$2" 
    local backup_name="$3"
    local verify_integrity="${4:-true}"
    
    # Validaciones de entrada
    if [[ -z "$source" || -z "$dest_dir" || -z "$backup_name" ]]; then
        echo "ERROR: Faltan parámetros requeridos"
        echo "Uso: create_safe_backup <source> <dest_dir> <backup_name> [verify_integrity]"
        return 1
    fi
    
    # Verificar que el origen existe
    if [[ ! -e "$source" ]]; then
        echo "ERROR: Ruta origen no existe: $source"
        return 1
    fi
    
    # Crear directorio destino si no existe
    if ! mkdir -p "$dest_dir" 2>/dev/null; then
        echo "ERROR: No se pudo crear directorio destino: $dest_dir"
        return 1
    fi
    
    # Verificar permisos de escritura
    if [[ ! -w "$dest_dir" ]]; then
        echo "ERROR: Sin permisos de escritura en: $dest_dir"
        return 1
    fi
    
    # Estimar tamaño del backup
    local source_size=0
    if [[ -d "$source" ]]; then
        source_size=$(du -s "$source" 2>/dev/null | awk '{print $1}' || echo 0)
    else
        source_size=$(stat -f%z "$source" 2>/dev/null || stat -c%s "$source" 2>/dev/null || echo 0)
        source_size=$((source_size / 1024))  # Convertir a KB
    fi
    
    # Verificar espacio disponible (con margen del 50%)
    local available_space=$(df "$dest_dir" | awk 'NR==2 {print $4}')
    local required_space=$((source_size * 15 / 10))  # +50% margen
    
    if [[ $available_space -lt $required_space ]]; then
        echo "ERROR: Espacio insuficiente"
        echo "Requerido: ${required_space}KB (${source_size}KB + 50% margen)"
        echo "Disponible: ${available_space}KB"
        return 1
    fi
    
    # Preparar archivos de backup
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$dest_dir/${backup_name}_${timestamp}.tar.gz"
    local temp_backup="${backup_file}.tmp"
    local lock_file="${backup_file}.lock"
    
    # Verificar si hay otro backup en progreso
    if [[ -f "$lock_file" ]]; then
        echo "ERROR: Otro backup está en progreso (archivo lock existe)"
        return 1
    fi
    
    # Crear lock
    echo "$$|$(date)|$(whoami)" > "$lock_file"
    
    # Función de limpieza
    cleanup_backup() {
        rm -f "$temp_backup" "$lock_file"
    }
    
    # Configurar trap para limpieza automática
    trap cleanup_backup EXIT INT TERM
    
    echo "Iniciando backup: $source -> $backup_file"
    
    # Crear backup según el tipo de origen
    local backup_success=false
    
    if [[ -d "$source" ]]; then
        # Backup de directorio con tar
        if tar -czf "$temp_backup" -C "$(dirname "$source")" "$(basename "$source")" 2>&1; then
            backup_success=true
        else
            echo "ERROR: Falló el comando tar"
            cleanup_backup
            return 1
        fi
    else
        # Backup de archivo individual
        if cp "$source" "$temp_backup" 2>&1; then
            backup_success=true
        else
            echo "ERROR: Falló el comando cp"
            cleanup_backup
            return 1
        fi
    fi
    
    # Verificar que el backup temporal se creó correctamente
    if [[ "$backup_success" == "true" && -s "$temp_backup" ]]; then
        # Mover archivo temporal al definitivo
        if mv "$temp_backup" "$backup_file"; then
            echo "Backup creado exitosamente: $backup_file"
            
            # Verificar integridad si se solicita
            if [[ "$verify_integrity" == "true" && -f "$backup_file" ]]; then
                echo "Verificando integridad del backup..."
                
                if [[ "$backup_file" == *.tar.gz ]]; then
                    if tar -tzf "$backup_file" >/dev/null 2>&1; then
                        echo "Integridad verificada: OK"
                    else
                        echo "ERROR: Backup corrupto, eliminando archivo"
                        rm -f "$backup_file"
                        cleanup_backup
                        return 1
                    fi
                fi
            fi
            
            # Registrar backup exitoso
            local backup_size=$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file" 2>/dev/null || echo 0)
            echo "$(date '+%Y-%m-%d %H:%M:%S')|$source|$backup_file|$backup_size|SUCCESS" >> "$dest_dir/backup_registry.log"
            
            echo "Backup completado exitosamente"
            echo "Archivo: $backup_file"
            echo "Tamaño: $((backup_size / 1024))KB"
            
            cleanup_backup
            return 0
        else
            echo "ERROR: No se pudo mover archivo temporal a definitivo"
            cleanup_backup
            return 1
        fi
    else
        echo "ERROR: Backup temporal vacío o no se creó"
        cleanup_backup
        return 1
    fi
}

# Función para verificar espacio antes de múltiples backups
check_total_backup_space() {
    local dest_dir="$1"
    local estimated_total_size="$2"  # En KB
    
    local available_space=$(df "$dest_dir" | awk 'NR==2 {print $4}')
    local required_space=$((estimated_total_size * 2))  # 100% margen para múltiples backups
    
    if [[ $available_space -lt $required_space ]]; then
        echo "ERROR: Espacio insuficiente para serie de backups"
        echo "Requerido: ${required_space}KB"
        echo "Disponible: ${available_space}KB"
        return 1
    fi
    
    echo "Espacio verificado para backups: $((available_space / 1024))MB disponibles"
    return 0
}

# Función para limpiar backups antiguos
cleanup_old_backups() {
    local backup_dir="$1"
    local retention_days="${2:-30}"
    
    if [[ ! -d "$backup_dir" ]]; then
        echo "ERROR: Directorio de backup no existe: $backup_dir"
        return 1
    fi
    
    echo "Limpiando backups anteriores a $retention_days días en $backup_dir"
    
    # Buscar y eliminar backups antiguos
    local deleted_count=0
    while IFS= read -r -d '' file; do
        echo "Eliminando backup antiguo: $(basename "$file")"
        rm -f "$file"
        ((deleted_count++))
    done < <(find "$backup_dir" -name "*.tar.gz" -type f -mtime +"$retention_days" -print0 2>/dev/null)
    
    while IFS= read -r -d '' file; do
        echo "Eliminando backup SQL antiguo: $(basename "$file")"
        rm -f "$file"
        ((deleted_count++))
    done < <(find "$backup_dir" -name "*.sql*" -type f -mtime +"$retention_days" -print0 2>/dev/null)
    
    echo "Backups antiguos eliminados: $deleted_count archivos"
    
    # Actualizar registro
    if [[ $deleted_count -gt 0 ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S')|CLEANUP|$backup_dir|$deleted_count files|SUCCESS" >> "$backup_dir/backup_registry.log"
    fi
    
    return 0
}

echo "Funciones de backup seguras cargadas correctamente"
echo "Funciones disponibles:"
echo "  - create_safe_backup <source> <dest_dir> <name> [verify]"
echo "  - check_total_backup_space <dest_dir> <estimated_size_kb>"
echo "  - cleanup_old_backups <backup_dir> [retention_days]"
EOF

    chmod +x "$SCRIPT_DIR/backup_function_safe.sh"
    log_success "Función de backup corregida creada: backup_function_safe.sh"
    
    echo ""
}

# 7. GENERAR REPORTE FINAL
generate_backup_verification_report() {
    log_info "=== GENERANDO REPORTE DE VERIFICACIÓN ==="
    
    local report_file="/var/log/reporte_verificacion_backup_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== REPORTE DE VERIFICACIÓN DE SISTEMAS DE BACKUP ==="
        echo "Fecha: $(date)"
        echo "Servidor: $(hostname)"
        echo "Verificador: Sub-Agente Verificador de Backup"
        echo ""
        
        echo "=== SCRIPTS ANALIZADOS ==="
        for script in "${SCRIPTS_WITH_BACKUP[@]}"; do
            if [[ -f "$SCRIPT_DIR/$script" ]]; then
                echo "✓ $script"
            else
                echo "✗ $script (no encontrado)"
            fi
        done
        
        echo ""
        echo "=== PROBLEMAS IDENTIFICADOS ==="
        if [[ -s "$ERROR_LOG" ]]; then
            echo "Ver errores detallados en: $ERROR_LOG"
            echo ""
            echo "Últimos errores encontrados:"
            tail -10 "$ERROR_LOG"
        else
            echo "No se encontraron errores críticos"
        fi
        
        echo ""
        echo "=== RECOMENDACIONES ==="
        echo "1. Usar la función create_safe_backup() corregida"
        echo "2. Eliminar usos de '|| true' y '2>/dev/null' en backups"
        echo "3. Implementar verificación de espacio antes de backups"
        echo "4. Agregar validación de integridad post-backup"
        echo "5. Implementar sistema de rotación automática"
        echo "6. Configurar alertas para fallos de backup"
        echo ""
        
        echo "=== ARCHIVOS CREADOS ==="
        echo "• backup_function_safe.sh - Funciones de backup corregidas"
        echo "• $ERROR_LOG - Log de errores encontrados"
        echo "• $LOG_FILE - Log completo de verificación"
        echo ""
        
        echo "=== PRÓXIMOS PASOS ==="
        echo "1. Revisar errores en $ERROR_LOG"
        echo "2. Implementar funciones corregidas de backup_function_safe.sh"
        echo "3. Probar backups con las nuevas funciones"
        echo "4. Configurar monitoreo de backups"
        echo "5. Programar verificaciones regulares"
        echo ""
        
        echo "Verificación completada: $(date '+%Y-%m-%d %H:%M:%S')"
        
    } > "$report_file"
    
    log_success "Reporte de verificación generado: $report_file"
    echo ""
}

# FUNCIÓN PRINCIPAL
main() {
    log_message "=== INICIANDO VERIFICACIÓN DE SISTEMAS DE BACKUP ==="
    
    check_backup_commands
    check_backup_paths  
    test_backup_functions
    check_mysql_backup
    check_webmin_backup
    check_backup_rotation
    generate_safe_backup_function
    generate_backup_verification_report
    
    log_success "Verificación de backup completada"
    
    if [[ -s "$ERROR_LOG" ]]; then
        echo ""
        echo -e "${RED}⚠️  SE ENCONTRARON PROBLEMAS EN LOS SISTEMAS DE BACKUP${NC}"
        echo "Ver detalles en: $ERROR_LOG"
        echo "Función corregida disponible en: backup_function_safe.sh"
    else
        echo ""
        echo -e "${GREEN}✅ SISTEMAS DE BACKUP VERIFICADOS CORRECTAMENTE${NC}"
    fi
}

case "${1:-}" in
    commands)
        check_backup_commands
        ;;
    paths)
        check_backup_paths
        ;;
    test)
        test_backup_functions
        ;;
    mysql)
        check_mysql_backup
        ;;
    webmin)
        check_webmin_backup
        ;;
    rotation)
        check_backup_rotation
        ;;
    generate)
        generate_safe_backup_function
        ;;
    *)
        main
        ;;
esac
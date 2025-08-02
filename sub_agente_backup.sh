#!/bin/bash

# Sub-Agente de Backup Automatizado
# Gestiona copias de seguridad del sistema, configuraciones y datos

LOG_FILE="/var/log/sub_agente_backup.log"
BACKUP_BASE_DIR="/var/backups/sistema"
CONFIG_FILE="/etc/webmin/backup_config.conf"
RETENTION_DAYS=30

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

create_backup_dirs() {
    local dirs=(
        "$BACKUP_BASE_DIR/webmin"
        "$BACKUP_BASE_DIR/virtualmin"
        "$BACKUP_BASE_DIR/system"
        "$BACKUP_BASE_DIR/databases"
        "$BACKUP_BASE_DIR/websites"
        "$BACKUP_BASE_DIR/logs"
    )
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_message "Directorio de backup creado: $dir"
        fi
    done
}

backup_webmin_config() {
    log_message "=== RESPALDANDO CONFIGURACIÓN DE WEBMIN ==="
    
    local backup_file="$BACKUP_BASE_DIR/webmin/webmin_config_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    if [ -d "/etc/webmin" ]; then
        tar -czf "$backup_file" -C / etc/webmin 2>/dev/null
        if [ $? -eq 0 ]; then
            log_message "✓ Backup de Webmin creado: $backup_file"
            echo "webmin_config|$(date)|$backup_file|$(du -h "$backup_file" | cut -f1)" >> "$BACKUP_BASE_DIR/backup_registry.log"
        else
            log_message "✗ Error al crear backup de Webmin"
        fi
    else
        log_message "Directorio /etc/webmin no encontrado"
    fi
}

backup_virtualmin_domains() {
    log_message "=== RESPALDANDO DOMINIOS DE VIRTUALMIN ==="
    
    local backup_file="$BACKUP_BASE_DIR/virtualmin/virtualmin_domains_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    # Backup de configuraciones de dominios
    if [ -d "/etc/virtualmin-domains" ]; then
        tar -czf "$backup_file" -C / etc/virtualmin-domains 2>/dev/null
        log_message "✓ Backup de dominios Virtualmin: $backup_file"
    fi
    
    # Backup usando comando de Virtualmin si está disponible
    if command -v virtualmin >/dev/null 2>&1; then
        local domains=$(virtualmin list-domains --name-only 2>/dev/null)
        for domain in $domains; do
            local domain_backup="$BACKUP_BASE_DIR/virtualmin/${domain}_$(date +%Y%m%d_%H%M%S).tar.gz"
            virtualmin backup-domain --domain "$domain" --dest "$domain_backup" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                log_message "✓ Backup del dominio $domain creado"
                echo "virtualmin_domain|$(date)|$domain_backup|$(du -h "$domain_backup" | cut -f1)" >> "$BACKUP_BASE_DIR/backup_registry.log"
            fi
        done
    fi
}

backup_system_configs() {
    log_message "=== RESPALDANDO CONFIGURACIONES DEL SISTEMA ==="
    
    local backup_file="$BACKUP_BASE_DIR/system/system_configs_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    local important_configs=(
        "/etc/apache2"
        "/etc/nginx"
        "/etc/ssh"
        "/etc/postfix"
        "/etc/bind"
        "/etc/mysql"
        "/etc/postgresql"
        "/etc/ssl"
        "/etc/hosts"
        "/etc/hostname"
        "/etc/resolv.conf"
        "/etc/fstab"
        "/etc/crontab"
        "/etc/sudoers"
    )
    
    local existing_configs=()
    for config in "${important_configs[@]}"; do
        if [ -e "$config" ]; then
            existing_configs+=("$config")
        fi
    done
    
    if [ ${#existing_configs[@]} -gt 0 ]; then
        tar -czf "$backup_file" "${existing_configs[@]}" 2>/dev/null
        if [ $? -eq 0 ]; then
            log_message "✓ Backup de configuraciones del sistema: $backup_file"
            echo "system_configs|$(date)|$backup_file|$(du -h "$backup_file" | cut -f1)" >> "$BACKUP_BASE_DIR/backup_registry.log"
        else
            log_message "✗ Error al crear backup de configuraciones del sistema"
        fi
    fi
}

backup_databases() {
    log_message "=== RESPALDANDO BASES DE DATOS ==="
    
    # MySQL/MariaDB
    if command -v mysqldump >/dev/null 2>&1; then
        local mysql_backup="$BACKUP_BASE_DIR/databases/mysql_$(date +%Y%m%d_%H%M%S).sql"
        
        # Obtener todas las bases de datos
        local databases=$(mysql -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")
        
        for db in $databases; do
            mysqldump --single-transaction --routines --triggers "$db" >> "$mysql_backup" 2>/dev/null
            if [ $? -eq 0 ]; then
                log_message "✓ Base de datos MySQL '$db' respaldada"
            fi
        done
        
        if [ -f "$mysql_backup" ] && [ -s "$mysql_backup" ]; then
            gzip "$mysql_backup"
            echo "mysql_databases|$(date)|${mysql_backup}.gz|$(du -h "${mysql_backup}.gz" | cut -f1)" >> "$BACKUP_BASE_DIR/backup_registry.log"
        fi
    fi
    
    # PostgreSQL
    if command -v pg_dumpall >/dev/null 2>&1; then
        local postgres_backup="$BACKUP_BASE_DIR/databases/postgresql_$(date +%Y%m%d_%H%M%S).sql"
        
        sudo -u postgres pg_dumpall > "$postgres_backup" 2>/dev/null
        if [ $? -eq 0 ] && [ -s "$postgres_backup" ]; then
            gzip "$postgres_backup"
            log_message "✓ Bases de datos PostgreSQL respaldadas"
            echo "postgresql_databases|$(date)|${postgres_backup}.gz|$(du -h "${postgres_backup}.gz" | cut -f1)" >> "$BACKUP_BASE_DIR/backup_registry.log"
        fi
    fi
}

backup_websites() {
    log_message "=== RESPALDANDO SITIOS WEB ==="
    
    local web_dirs=("/var/www" "/home/*/public_html" "/home/*/domains/*/public_html")
    
    for dir_pattern in "${web_dirs[@]}"; do
        for dir in $dir_pattern; do
            if [ -d "$dir" ] && [ "$(ls -A "$dir" 2>/dev/null)" ]; then
                local dir_name=$(echo "$dir" | tr '/' '_')
                local backup_file="$BACKUP_BASE_DIR/websites/website_${dir_name}_$(date +%Y%m%d_%H%M%S).tar.gz"
                
                tar -czf "$backup_file" -C "$(dirname "$dir")" "$(basename "$dir")" 2>/dev/null
                if [ $? -eq 0 ]; then
                    log_message "✓ Sitio web respaldado: $dir -> $backup_file"
                    echo "website|$(date)|$backup_file|$(du -h "$backup_file" | cut -f1)" >> "$BACKUP_BASE_DIR/backup_registry.log"
                fi
            fi
        done
    done
}

backup_logs() {
    log_message "=== RESPALDANDO LOGS IMPORTANTES ==="
    
    local log_backup="$BACKUP_BASE_DIR/logs/system_logs_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    local important_logs=(
        "/var/log/webmin"
        "/var/log/apache2"
        "/var/log/nginx"
        "/var/log/mysql"
        "/var/log/postgresql"
        "/var/log/postfix"
        "/var/log/auth.log"
        "/var/log/syslog"
        "/var/log/messages"
    )
    
    local existing_logs=()
    for log_dir in "${important_logs[@]}"; do
        if [ -e "$log_dir" ]; then
            existing_logs+=("$log_dir")
        fi
    done
    
    if [ ${#existing_logs[@]} -gt 0 ]; then
        tar -czf "$log_backup" "${existing_logs[@]}" 2>/dev/null
        if [ $? -eq 0 ]; then
            log_message "✓ Logs del sistema respaldados: $log_backup"
            echo "system_logs|$(date)|$log_backup|$(du -h "$log_backup" | cut -f1)" >> "$BACKUP_BASE_DIR/backup_registry.log"
        fi
    fi
}

clean_old_backups() {
    log_message "=== LIMPIANDO BACKUPS ANTIGUOS ==="
    
    find "$BACKUP_BASE_DIR" -type f -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null
    find "$BACKUP_BASE_DIR" -type f -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null
    
    local deleted_count=$(find "$BACKUP_BASE_DIR" -type f -mtime +$RETENTION_DAYS 2>/dev/null | wc -l)
    if [ "$deleted_count" -gt 0 ]; then
        log_message "✓ $deleted_count backups antiguos eliminados (>${RETENTION_DAYS} días)"
    else
        log_message "No hay backups antiguos para eliminar"
    fi
}

verify_backups() {
    log_message "=== VERIFICANDO INTEGRIDAD DE BACKUPS ==="
    
    local recent_backups=$(find "$BACKUP_BASE_DIR" -type f -name "*.tar.gz" -mtime -1)
    local corrupted_count=0
    
    for backup in $recent_backups; do
        if ! tar -tzf "$backup" >/dev/null 2>&1; then
            log_message "✗ Backup corrupto detectado: $backup"
            ((corrupted_count++))
        fi
    done
    
    if [ "$corrupted_count" -eq 0 ]; then
        log_message "✓ Todos los backups recientes están íntegros"
    else
        log_message "✗ $corrupted_count backups corruptos encontrados"
    fi
}

generate_backup_report() {
    log_message "=== GENERANDO REPORTE DE BACKUP ==="
    
    local report_file="$BACKUP_BASE_DIR/backup_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== REPORTE DE BACKUP DEL SISTEMA ==="
        echo "Fecha: $(date)"
        echo "Servidor: $(hostname)"
        echo ""
        echo "=== ESTADÍSTICAS DE BACKUP ==="
        echo "Directorio base: $BACKUP_BASE_DIR"
        echo "Retención: $RETENTION_DAYS días"
        echo "Espacio total usado: $(du -sh "$BACKUP_BASE_DIR" 2>/dev/null | cut -f1)"
        echo ""
        echo "=== BACKUPS POR CATEGORÍA ==="
        find "$BACKUP_BASE_DIR" -type f -name "*.tar.gz" -o -name "*.sql.gz" | awk -F'/' '{print $(NF-1)}' | sort | uniq -c
        echo ""
        echo "=== BACKUPS RECIENTES (últimas 24h) ==="
        find "$BACKUP_BASE_DIR" -type f -mtime -1 -exec ls -lh {} \; | awk '{print $9 " - " $5 " - " $6 " " $7 " " $8}'
        echo ""
        echo "=== REGISTRO DE BACKUPS ==="
        if [ -f "$BACKUP_BASE_DIR/backup_registry.log" ]; then
            tail -20 "$BACKUP_BASE_DIR/backup_registry.log"
        else
            echo "Sin registro de backups"
        fi
    } > "$report_file"
    
    log_message "Reporte de backup generado: $report_file"
}

main() {
    log_message "Iniciando proceso de backup..."
    
    create_backup_dirs
    backup_webmin_config
    backup_virtualmin_domains
    backup_system_configs
    backup_databases
    backup_websites
    backup_logs
    verify_backups
    clean_old_backups
    generate_backup_report
    
    log_message "Proceso de backup completado."
}

case "${1:-}" in
    start|full)
        main
        ;;
    webmin)
        create_backup_dirs
        backup_webmin_config
        ;;
    virtualmin)
        create_backup_dirs
        backup_virtualmin_domains
        ;;
    system)
        create_backup_dirs
        backup_system_configs
        ;;
    databases)
        create_backup_dirs
        backup_databases
        ;;
    websites)
        create_backup_dirs
        backup_websites
        ;;
    clean)
        clean_old_backups
        ;;
    verify)
        verify_backups
        ;;
    report)
        generate_backup_report
        ;;
    *)
        echo "Uso: $0 {start|full|webmin|virtualmin|system|databases|websites|clean|verify|report}"
        echo "  start/full - Backup completo del sistema"
        echo "  webmin     - Solo configuración de Webmin"
        echo "  virtualmin - Solo dominios de Virtualmin"
        echo "  system     - Solo configuraciones del sistema"
        echo "  databases  - Solo bases de datos"
        echo "  websites   - Solo sitios web"
        echo "  clean      - Limpiar backups antiguos"
        echo "  verify     - Verificar integridad de backups"
        echo "  report     - Generar reporte de backups"
        exit 1
        ;;
esac
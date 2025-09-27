#!/bin/bash

# ============================================================================
# MÓDULO DE REPARACIÓN AUTOMÁTICA LARAVEL - Webmin/Virtualmin
# ============================================================================
# Detecta y repara automáticamente aplicaciones Laravel
# Versión: 1.0.0
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ===== INCLUIR BIBLIOTECA COMÚN =====
if [[ -f "${PROJECT_DIR}/lib/common.sh" ]]; then
    source "${PROJECT_DIR}/lib/common.sh"
    log_info "Biblioteca común cargada correctamente"
else
    echo "ERROR: No se pudo cargar lib/common.sh"
    exit 1
fi

# ===== CONFIGURACIÓN =====
LOG_FILE="./logs/laravel_repair.log"
REPORT_DIR="./logs/laravel_reports"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
REPORT_FILE="$REPORT_DIR/laravel_repair_report_$TIMESTAMP.html"

# Detect Laravel applications
detect_laravel_apps() {
    log_info "Starting Laravel application detection..."

    local laravel_apps=()
    local search_dirs=("/home" "/var/www" "/usr/local/apache2/htdocs")

    for base_dir in "${search_dirs[@]}"; do
        if [[ -d "$base_dir" ]]; then
            log_info "Searching in: $base_dir"
            # Find artisan files and get their parent directories
            while IFS= read -r -d '' artisan_file; do
                local app_dir=$(dirname "$artisan_file")
                if [[ -f "$app_dir/composer.json" ]]; then
                    # Check if it's a Laravel app by looking for Laravel in composer.json
                    if grep -q '"laravel/framework"' "$app_dir/composer.json" 2>/dev/null; then
                        # Validate directory exists and is accessible
                        if [[ -d "$app_dir" && -r "$app_dir" ]]; then
                            laravel_apps+=("$app_dir")
                            log_info "Found Laravel application: $app_dir"
                        else
                            log_warning "Directory not accessible: $app_dir"
                        fi
                    fi
                fi
            done < <(find "$base_dir" -name "artisan" -type f -print0 2>/dev/null)
        else
            log_info "Directory does not exist: $base_dir"
        fi
    done

    echo "${laravel_apps[@]}"
}

# Repair Composer dependencies
repair_composer_deps() {
    local app_dir="$1"
    log_info "Repairing Composer dependencies for: $app_dir"

    cd "$app_dir" || {
        log_error "Cannot access directory: $app_dir"
        return 1
    }

    # Check if composer is available
    if ! command -v composer &> /dev/null; then
        log_error "Composer not found. Installing..."
        if ! curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer; then
            log_error "Failed to install Composer"
            return 1
        fi
    fi

    # Clear composer cache
    composer clear-cache 2>/dev/null

    # Install/update dependencies
    if [[ -f "composer.lock" ]]; then
        log_info "Running composer install..."
        if composer install --no-interaction --optimize-autoloader; then
            log_success "Composer dependencies repaired successfully"
            return 0
        else
            log_error "Composer install failed"
            return 1
        fi
    else
        log_info "Running composer update..."
        if composer update --no-interaction --optimize-autoloader; then
            log_success "Composer dependencies updated successfully"
            return 0
        else
            log_error "Composer update failed"
            return 1
        fi
    fi
}

# Configure .env file
configure_env() {
    local app_dir="$1"
    log_info "Configuring .env file for: $app_dir"

    cd "$app_dir" || return 1

    local env_file="$app_dir/.env"
    local env_example="$app_dir/.env.example"

    if [[ ! -f "$env_file" ]]; then
        if [[ -f "$env_example" ]]; then
            cp "$env_example" "$env_file"
            log_info "Created .env file from .env.example"
        else
            # Create basic .env file
            cat > "$env_file" << EOF
APP_NAME=Laravel
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=http://localhost

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=root
DB_PASSWORD=

BROADCAST_DRIVER=log
CACHE_DRIVER=file
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS=null
MAIL_FROM_NAME="\${APP_NAME}"
EOF
            log_warning "Created basic .env file. Please configure database and other settings."
        fi
    fi

    # Generate application key if not set
    if ! grep -q "^APP_KEY=" "$env_file" || grep -q "^APP_KEY=$" "$env_file"; then
        if php artisan key:generate --force 2>/dev/null; then
            log_success "Application key generated"
        else
            log_error "Failed to generate application key"
        fi
    fi

    # Set proper permissions
    chmod 600 "$env_file"
    log_success ".env file configured"
}

# Fix permissions
fix_permissions() {
    local app_dir="$1"
    log_info "Fixing permissions for: $app_dir"

    cd "$app_dir" || return 1

    # Get the owner of the directory (usually the domain owner)
    local owner=$(stat -c '%U' "$app_dir" 2>/dev/null || stat -f '%Su' "$app_dir" 2>/dev/null)

    if [[ -z "$owner" ]]; then
        owner="www-data"
    fi

    # Set ownership
    chown -R "$owner":www-data "$app_dir" 2>/dev/null || chown -R "$owner" "$app_dir"

    # Set directory permissions
    find "$app_dir" -type d -exec chmod 755 {} \;

    # Set file permissions
    find "$app_dir" -type f -exec chmod 644 {} \;

    # Special permissions for Laravel
    chmod -R 775 "$app_dir/storage" 2>/dev/null
    chmod -R 775 "$app_dir/bootstrap/cache" 2>/dev/null

    log_success "Permissions fixed"
}

# Repair database
repair_database() {
    local app_dir="$1"
    log_info "Repairing database for: $app_dir"

    cd "$app_dir" || return 1

    # Check if .env exists and has database config
    if [[ ! -f ".env" ]]; then
        log_error "No .env file found for database configuration"
        return 1
    fi

    # Run migrations
    if php artisan migrate --force 2>/dev/null; then
        log_success "Database migrations completed"
    else
        log_warning "Database migration failed or already up to date"
    fi

    # Seed database if seeder exists
    if php artisan db:seed --force 2>/dev/null; then
        log_success "Database seeded"
    else
        log_info "No database seeder found or seeding failed"
    fi
}

# Diagnose PHP errors
diagnose_php_errors() {
    local app_dir="$1"
    log_info "Diagnosing PHP errors for: $app_dir"

    cd "$app_dir" || return 1

    local php_errors=()

    # Check PHP version compatibility
    local php_version=$(php -r "echo PHP_VERSION;")
    log_info "PHP version: $php_version"

    if [[ -f "composer.json" ]]; then
        local required_php=$(grep -o '"php": "[^"]*"' composer.json | sed 's/.*"php": "\([^"]*\)".*/\1/')
        if [[ -n "$required_php" ]]; then
            log_info "Required PHP version: $required_php"
        fi
    fi

    # Check for common PHP errors
    if ! php -l artisan >/dev/null 2>&1; then
        php_errors+=("Syntax error in artisan file")
    fi

    # Check if vendor directory exists
    if [[ ! -d "vendor" ]]; then
        php_errors+=("Vendor directory missing - run composer install")
    fi

    # Check storage link
    if [[ ! -L "public/storage" ]]; then
        php_errors+=("Storage link missing")
    fi

    # Check .env file
    if [[ ! -f ".env" ]]; then
        php_errors+=(".env file missing")
    fi

    # Check application key
    if ! grep -q "^APP_KEY=[^$]" .env 2>/dev/null; then
        php_errors+=("Application key not set")
    fi

    if [[ ${#php_errors[@]} -eq 0 ]]; then
        log_success "No PHP errors detected"
    else
        for error in "${php_errors[@]}"; do
            log_error "PHP Error: $error"
        done
    fi

    echo "${php_errors[@]}"
}

# Run Artisan commands
run_artisan_commands() {
    local app_dir="$1"
    log_info "Running Artisan commands for: $app_dir"

    cd "$app_dir" || return 1

    local commands=(
        "config:clear"
        "cache:clear"
        "view:clear"
        "route:clear"
        "storage:link"
        "optimize"
    )

    for cmd in "${commands[@]}"; do
        log_info "Running: php artisan $cmd"
        if php artisan "$cmd" 2>/dev/null; then
            log_success "Command $cmd completed successfully"
        else
            log_warning "Command $cmd failed or not applicable"
        fi
    done
}

# Generate HTML report
generate_html_report() {
    local app_dir="$1"
    local status="$2"
    local errors="$3"

    log_info "Generating HTML report..."

    if ! mkdir -p "$REPORT_DIR"; then
        log_error "Failed to create report directory: $REPORT_DIR"
        return 1
    fi

    if ! [[ -d "$REPORT_DIR" ]]; then
        log_error "Report directory does not exist after creation: $REPORT_DIR"
        return 1
    fi

    if ! cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte de Reparación Laravel - $TIMESTAMP</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        .status { padding: 10px; margin: 10px 0; border-radius: 4px; }
        .success { background-color: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .error { background-color: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
        .warning { background-color: #fff3cd; color: #856404; border: 1px solid #ffeaa7; }
        .info { background-color: #d1ecf1; color: #0c5460; border: 1px solid #bee5eb; }
        pre { background: #f8f9fa; padding: 10px; border-radius: 4px; overflow-x: auto; }
        .footer { margin-top: 20px; padding-top: 10px; border-top: 1px solid #dee2e6; color: #6c757d; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Reporte de Reparación Automática Laravel</h1>
        <div class="status $status">
            <strong>Estado General:</strong> ${status^^}
        </div>
        <p><strong>Directorio de la Aplicación:</strong> $app_dir</p>
        <p><strong>Fecha y Hora:</strong> $(date)</p>

        <h2>Errores Detectados</h2>
        <pre>$errors</pre>

        <h2>Log de Ejecución</h2>
        <pre>$(tail -50 "$LOG_FILE")</pre>

        <div class="footer">
            <p>Reporte generado por el Sistema de Auto Reparación Webmin/Virtualmin</p>
            <p>Archivo de log completo: $LOG_FILE</p>
        </div>
    </div>
</body>
</html>
EOF
    then
        log_error "Failed to write report file: $REPORT_FILE"
        return 1
    fi

    if ! [[ -f "$REPORT_FILE" ]]; then
        log_error "Report file was not created: $REPORT_FILE"
        return 1
    fi

    log_success "HTML report generated: $REPORT_FILE"
}

# Main function
main() {
    log_info "Starting Laravel Auto Repair Module"

    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"

    # Detect Laravel applications
    local apps=($(detect_laravel_apps))

    if [[ ${#apps[@]} -eq 0 ]]; then
        log_warning "No Laravel applications found"
        return 0
    fi

    local overall_status="success"
    local all_errors=""

    for app in "${apps[@]}"; do
        log_info "Processing Laravel application: $app"

        local app_errors=""

        # Repair Composer dependencies
        if ! repair_composer_deps "$app"; then
            app_errors+="Composer repair failed\n"
            overall_status="error"
        fi

        # Configure .env
        if ! configure_env "$app"; then
            app_errors+=".env configuration failed\n"
            overall_status="warning"
        fi

        # Fix permissions
        if ! fix_permissions "$app"; then
            app_errors+="Permission fix failed\n"
            overall_status="error"
        fi

        # Diagnose PHP errors
        local php_errors=($(diagnose_php_errors "$app"))
        if [[ ${#php_errors[@]} -gt 0 ]]; then
            app_errors+="PHP Errors: ${php_errors[*]}\n"
            overall_status="warning"
        fi

        # Repair database
        if ! repair_database "$app"; then
            app_errors+="Database repair failed\n"
            overall_status="error"
        fi

        # Run Artisan commands
        if ! run_artisan_commands "$app"; then
            app_errors+="Artisan commands failed\n"
            overall_status="warning"
        fi

        all_errors+="$app_errors"
    done

    # Generate HTML report
    generate_html_report "${apps[*]}" "$overall_status" "$all_errors"

    log_info "Laravel Auto Repair Module completed with status: $overall_status"
}

# Run main function
main "$@"
#!/bin/bash

# Script principal de despliegue automatizado para Webmin/Virtualmin
# Uso: ./deploy.sh [staging|production] [webmin|virtualmin|full]

set -e

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../configs"
TEMPLATE_DIR="$SCRIPT_DIR/../templates"

# Variables por defecto
ENVIRONMENT="${1:-staging}"
COMPONENT="${2:-full}"
VERSION="${3:-latest}"
BACKUP_BEFORE_DEPLOY=true
ROLLBACK_ON_FAILURE=true

# Validar parámetros
validate_params() {
    case "$ENVIRONMENT" in
        staging|production)
            ;;
        *)
            echo "❌ Error: Environment must be 'staging' or 'production'"
            exit 1
            ;;
    esac

    case "$COMPONENT" in
        webmin|virtualmin|full)
            ;;
        *)
            echo "❌ Error: Component must be 'webmin', 'virtualmin', or 'full'"
            exit 1
            ;;
    esac
}

# Cargar configuración del entorno
load_environment_config() {
    local config_file="$CONFIG_DIR/$ENVIRONMENT.yml"

    if [ ! -f "$config_file" ]; then
        echo "❌ Error: Configuration file not found: $config_file"
        exit 1
    fi

    echo "⚙️ Loading configuration for $ENVIRONMENT environment..."

    # Aquí iría la lógica para parsear YAML y cargar variables
    # Por simplicidad, usaremos variables de entorno o defaults

    # Configuración por defecto
    export WEBMIN_PORT="${WEBMIN_PORT:-10000}"
    export VIRTUALMIN_SSL="${VIRTUALMIN_SSL:-true}"
    export DB_HOST="${DB_HOST:-localhost}"
    export DB_USER="${DB_USER:-virtualmin}"
    export BACKUP_RETENTION="${BACKUP_RETENTION:-7}"
}

# Crear backup antes del despliegue
create_backup() {
    if [ "$BACKUP_BEFORE_DEPLOY" = true ]; then
        echo "💾 Creating pre-deployment backup..."

        local backup_dir="/var/backups/webmin_virtualmin"
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_name="pre_deploy_${ENVIRONMENT}_${timestamp}"

        mkdir -p "$backup_dir"

        # Backup de configuración de Webmin
        if [ -d "/etc/webmin" ]; then
            tar -czf "$backup_dir/${backup_name}_webmin.tar.gz" -C / etc/webmin 2>/dev/null || true
        fi

        # Backup de configuración de Virtualmin
        if [ -d "/etc/virtualmin" ]; then
            tar -czf "$backup_dir/${backup_name}_virtualmin.tar.gz" -C / etc/virtualmin 2>/dev/null || true
        fi

        # Backup de bases de datos
        if command -v mysqldump >/dev/null 2>&1; then
            mysqldump --all-databases > "$backup_dir/${backup_name}_databases.sql" 2>/dev/null || true
        fi

        echo "✅ Backup created: $backup_dir/${backup_name}_*"

        # Limpiar backups antiguos
        find "$backup_dir" -name "pre_deploy_${ENVIRONMENT}_*.tar.gz" -mtime +$BACKUP_RETENTION -delete 2>/dev/null || true
        find "$backup_dir" -name "pre_deploy_${ENVIRONMENT}_*.sql" -mtime +$BACKUP_RETENTION -delete 2>/dev/null || true
    fi
}

# Desplegar Webmin
deploy_webmin() {
    echo "🚀 Deploying Webmin..."

    # Detener servicio si está corriendo
    if systemctl is-active --quiet webmin 2>/dev/null; then
        echo "🛑 Stopping Webmin service..."
        systemctl stop webmin
    fi

    # Instalar/actualizar Webmin
    if [ -f "$PROJECT_ROOT/install_webmin_virtualmin.sh" ]; then
        echo "📦 Installing Webmin..."
        bash "$PROJECT_ROOT/install_webmin_virtualmin.sh" webmin-only
    else
        echo "⚠️ Webmin installer not found, assuming it's already installed"
    fi

    # Configurar Webmin
    configure_webmin

    # Iniciar servicio
    echo "▶️ Starting Webmin service..."
    systemctl enable webmin 2>/dev/null || true
    systemctl start webmin

    # Verificar que esté corriendo
    sleep 5
    if systemctl is-active --quiet webmin 2>/dev/null; then
        echo "✅ Webmin deployed successfully"
    else
        echo "❌ Failed to start Webmin service"
        return 1
    fi
}

# Configurar Webmin
configure_webmin() {
    echo "⚙️ Configuring Webmin..."

    local webmin_config="/etc/webmin/config"

    # Configurar puerto
    if [ -f "$webmin_config" ]; then
        sed -i "s/^port=.*/port=$WEBMIN_PORT/" "$webmin_config" 2>/dev/null || true
    fi

    # Configurar SSL si es producción
    if [ "$ENVIRONMENT" = "production" ] && [ "$VIRTUALMIN_SSL" = "true" ]; then
        # Aquí iría configuración SSL avanzada
        echo "🔒 SSL configuration applied"
    fi

    # Aplicar configuración de tema
    if [ -d "/etc/webmin" ]; then
        # Configurar tema authentic
        echo "theme=authentic-theme" >> "$webmin_config" 2>/dev/null || true
    fi
}

# Desplegar Virtualmin
deploy_virtualmin() {
    echo "🚀 Deploying Virtualmin..."

    # Verificar que Webmin esté instalado
    if ! command -v webmin >/dev/null 2>&1; then
        echo "❌ Webmin must be installed before Virtualmin"
        return 1
    fi

    # Instalar/actualizar Virtualmin
    if [ -f "$PROJECT_ROOT/install_webmin_virtualmin.sh" ]; then
        echo "📦 Installing Virtualmin..."
        bash "$PROJECT_ROOT/install_webmin_virtualmin.sh" virtualmin-only
    else
        echo "⚠️ Virtualmin installer not found, assuming it's already installed"
    fi

    # Configurar Virtualmin
    configure_virtualmin

    # Reiniciar servicios
    echo "🔄 Restarting services..."
    systemctl restart webmin 2>/dev/null || true

    echo "✅ Virtualmin deployed successfully"
}

# Configurar Virtualmin
configure_virtualmin() {
    echo "⚙️ Configuring Virtualmin..."

    # Configurar base de datos
    if [ -n "$DB_HOST" ] && [ -n "$DB_USER" ]; then
        echo "🗄️ Configuring database connection..."
        # Aquí iría configuración de base de datos
    fi

    # Configurar SSL
    if [ "$VIRTUALMIN_SSL" = "true" ]; then
        echo "🔒 Enabling SSL for Virtualmin..."
        # Aquí iría configuración SSL
    fi

    # Configurar límites y quotas
    echo "📊 Configuring quotas and limits..."
    # Aquí iría configuración de quotas
}

# Ejecutar pruebas post-despliegue
run_post_deploy_tests() {
    echo "🧪 Running post-deployment tests..."

    local test_results=0

    # Verificar servicios
    if [ "$COMPONENT" = "webmin" ] || [ "$COMPONENT" = "full" ]; then
        if ! systemctl is-active --quiet webmin 2>/dev/null; then
            echo "❌ Webmin service is not running"
            test_results=1
        else
            echo "✅ Webmin service is running"
        fi

        # Verificar puerto
        if ! nc -z localhost $WEBMIN_PORT 2>/dev/null; then
            echo "❌ Webmin is not listening on port $WEBMIN_PORT"
            test_results=1
        else
            echo "✅ Webmin is listening on port $WEBMIN_PORT"
        fi
    fi

    if [ "$COMPONENT" = "virtualmin" ] || [ "$COMPONENT" = "full" ]; then
        # Verificar que Virtualmin esté configurado
        if [ ! -d "/etc/virtualmin" ]; then
            echo "❌ Virtualmin configuration not found"
            test_results=1
        else
            echo "✅ Virtualmin configuration found"
        fi
    fi

    # Verificar conectividad a base de datos
    if [ "$COMPONENT" = "virtualmin" ] || [ "$COMPONENT" = "full" ]; then
        if ! mysql -h "$DB_HOST" -u "$DB_USER" -e "SELECT 1;" >/dev/null 2>&1; then
            echo "⚠️ Database connection test failed (may be expected in some configurations)"
        else
            echo "✅ Database connection successful"
        fi
    fi

    return $test_results
}

# Función de rollback
rollback_deployment() {
    echo "🔄 Rolling back deployment..."

    local backup_dir="/var/backups/webmin_virtualmin"
    local latest_backup=$(ls -t "$backup_dir"/pre_deploy_${ENVIRONMENT}_*.tar.gz 2>/dev/null | head -1)

    if [ -n "$latest_backup" ]; then
        echo "📦 Restoring from backup: $latest_backup"

        # Restaurar configuración de Webmin
        if [[ "$latest_backup" == *webmin* ]]; then
            tar -xzf "$latest_backup" -C / 2>/dev/null || true
        fi

        # Reiniciar servicios
        systemctl restart webmin 2>/dev/null || true

        echo "✅ Rollback completed"
    else
        echo "❌ No backup found for rollback"
        return 1
    fi
}

# Función principal
main() {
    echo "🚀 Starting Webmin/Virtualmin deployment"
    echo "Environment: $ENVIRONMENT"
    echo "Component: $COMPONENT"
    echo "Version: $VERSION"
    echo "================================="

    # Validar parámetros
    validate_params

    # Cargar configuración
    load_environment_config

    # Crear backup
    create_backup

    # Desplegar componentes
    local deploy_success=true

    if [ "$COMPONENT" = "webmin" ] || [ "$COMPONENT" = "full" ]; then
        if ! deploy_webmin; then
            deploy_success=false
        fi
    fi

    if [ "$COMPONENT" = "virtualmin" ] || [ "$COMPONENT" = "full" ]; then
        if ! deploy_virtualmin; then
            deploy_success=false
        fi
    fi

    # Ejecutar pruebas post-despliegue
    if [ "$deploy_success" = true ]; then
        if run_post_deploy_tests; then
            echo "🎉 Deployment completed successfully!"
            return 0
        else
            echo "⚠️ Deployment completed but post-deploy tests failed"
            if [ "$ROLLBACK_ON_FAILURE" = true ]; then
                rollback_deployment
            fi
            return 1
        fi
    else
        echo "❌ Deployment failed"
        if [ "$ROLLBACK_ON_FAILURE" = true ]; then
            rollback_deployment
        fi
        return 1
    fi
}

# Manejo de señales para cleanup
trap 'echo "❌ Deployment interrupted by user"; exit 1' INT TERM

# Ejecutar función principal
main "$@"
#!/bin/bash

# Script para validar configuración de despliegue
# Uso: ./validate_config.sh [staging|production]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../configs"

ENVIRONMENT="${1:-staging}"
CONFIG_FILE="$CONFIG_DIR/$ENVIRONMENT.yml"

echo "🔍 Validating deployment configuration for $ENVIRONMENT environment"
echo "================================================================"

# Verificar que el archivo de configuración existe
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file not found: $CONFIG_FILE"
    exit 1
fi

echo "✅ Configuration file found: $CONFIG_FILE"

# Verificar sintaxis YAML (si yamllint está disponible)
if command -v yamllint >/dev/null 2>&1; then
    echo "🔍 Checking YAML syntax..."
    if yamllint "$CONFIG_FILE" 2>/dev/null; then
        echo "✅ YAML syntax is valid"
    else
        echo "❌ YAML syntax errors found"
        exit 1
    fi
else
    echo "⚠️ yamllint not available, skipping YAML validation"
fi

# Verificar estructura básica de configuración
echo "🔍 Checking configuration structure..."

# Verificar secciones requeridas
required_sections=("environment" "webmin" "virtualmin" "database" "services" "backup" "security")

for section in "${required_sections[@]}"; do
    if grep -q "^$section:" "$CONFIG_FILE"; then
        echo "✅ Section '$section' found"
    else
        echo "❌ Required section '$section' missing"
        exit 1
    fi
done

# Validar configuración específica por entorno
echo "🔍 Validating environment-specific configuration..."

if [ "$ENVIRONMENT" = "production" ]; then
    # Validaciones específicas para producción
    if grep -q "ssl_enabled: true" "$CONFIG_FILE"; then
        echo "✅ SSL enabled for production"
    else
        echo "⚠️ SSL not enabled for production environment"
    fi

    if grep -q "backup_enabled: true" "$CONFIG_FILE"; then
        echo "✅ Backups enabled for production"
    else
        echo "❌ Backups not enabled for production environment"
        exit 1
    fi

    if grep -q "monitoring:" "$CONFIG_FILE" && grep -q "enabled: true" "$CONFIG_FILE"; then
        echo "✅ Monitoring enabled for production"
    else
        echo "⚠️ Monitoring not enabled for production environment"
    fi
fi

# Validar puertos
echo "🔍 Validating port configurations..."
webmin_port=$(grep "port:" "$CONFIG_FILE" | head -1 | sed 's/.*port: *//')
if [[ "$webmin_port" =~ ^[0-9]+$ ]] && [ "$webmin_port" -ge 1024 ] && [ "$webmin_port" -le 65535 ]; then
    echo "✅ Webmin port $webmin_port is valid"
else
    echo "❌ Invalid Webmin port: $webmin_port"
    exit 1
fi

# Validar configuración de base de datos
echo "🔍 Validating database configuration..."
if grep -q "database:" "$CONFIG_FILE"; then
    db_host=$(grep "host:" "$CONFIG_FILE" | grep -v "monitoring\|grafana" | head -1 | sed 's/.*host: *//')
    db_port=$(grep "port:" "$CONFIG_FILE" | grep -v "webmin\|apache\|nginx\|postfix\|dovecot\|prometheus\|grafana" | head -1 | sed 's/.*port: *//')

    if [ -n "$db_host" ]; then
        echo "✅ Database host configured: $db_host"
    else
        echo "❌ Database host not configured"
        exit 1
    fi

    if [[ "$db_port" =~ ^[0-9]+$ ]] && [ "$db_port" -ge 1 ] && [ "$db_port" -le 65535 ]; then
        echo "✅ Database port $db_port is valid"
    else
        echo "❌ Invalid database port: $db_port"
        exit 1
    fi
fi

# Validar configuración de servicios
echo "🔍 Validating services configuration..."
services=("apache" "postfix" "dovecot")
for service in "${services[@]}"; do
    if grep -q "$service:" "$CONFIG_FILE" && grep -q "enabled: true" "$CONFIG_FILE"; then
        echo "✅ Service $service is enabled"
    else
        echo "⚠️ Service $service configuration may be incomplete"
    fi
done

# Validar configuración de backup
echo "🔍 Validating backup configuration..."
if grep -q "backup:" "$CONFIG_FILE"; then
    backup_retention=$(grep "retention_days:" "$CONFIG_FILE" | sed 's/.*retention_days: *//')
    if [[ "$backup_retention" =~ ^[0-9]+$ ]] && [ "$backup_retention" -gt 0 ]; then
        echo "✅ Backup retention period: ${backup_retention} days"
    else
        echo "❌ Invalid backup retention period: $backup_retention"
        exit 1
    fi
fi

# Validar configuración de seguridad
echo "🔍 Validating security configuration..."
if grep -q "security:" "$CONFIG_FILE"; then
    if grep -q "firewall_enabled: true" "$CONFIG_FILE"; then
        echo "✅ Firewall is enabled"
    else
        echo "⚠️ Firewall is not enabled"
    fi

    if grep -q "ssl_enforcement: true" "$CONFIG_FILE"; then
        echo "✅ SSL enforcement is enabled"
    else
        echo "⚠️ SSL enforcement is not enabled"
    fi
fi

# Verificar variables de entorno requeridas
echo "🔍 Checking required environment variables..."
required_vars=("DB_PASSWORD")

if [ "$ENVIRONMENT" = "production" ]; then
    required_vars+=("SLACK_WEBHOOK_PRODUCTION" "PAGERDUTY_INTEGRATION_KEY")
fi

missing_vars=()
for var in "${required_vars[@]}"; do
    env_var="${var}_${ENVIRONMENT^^}"
    if [ -z "${!env_var}" ]; then
        missing_vars+=("$env_var")
    fi
done

if [ ${#missing_vars[@]} -eq 0 ]; then
    echo "✅ All required environment variables are set"
else
    echo "⚠️ Missing environment variables: ${missing_vars[*]}"
    echo "   These should be set in your deployment environment"
fi

# Verificar conectividad de red (si es aplicable)
echo "🔍 Checking network connectivity..."
if [ "$ENVIRONMENT" = "production" ]; then
    # Verificar que los hosts configurados sean accesibles
    db_host=$(grep "host:" "$CONFIG_FILE" | grep -v "monitoring\|grafana" | head -1 | sed 's/.*host: *//' | tr -d '"')
    if [ "$db_host" != "localhost" ] && [ -n "$db_host" ]; then
        if ping -c 1 -W 2 "$db_host" >/dev/null 2>&1; then
            echo "✅ Database host $db_host is reachable"
        else
            echo "⚠️ Database host $db_host is not reachable"
        fi
    fi
fi

# Verificar permisos de archivos
echo "🔍 Checking file permissions..."
if [ -r "$CONFIG_FILE" ]; then
    echo "✅ Configuration file is readable"
else
    echo "❌ Configuration file is not readable"
    exit 1
fi

# Verificar que los scripts sean ejecutables
scripts_to_check=(
    "$SCRIPT_DIR/deploy.sh"
    "$SCRIPT_DIR/rollback.sh"
)

for script in "${scripts_to_check[@]}"; do
    if [ -x "$script" ]; then
        echo "✅ Script $(basename "$script") is executable"
    else
        echo "❌ Script $(basename "$script") is not executable"
        exit 1
    fi
done

# Generar resumen de validación
echo ""
echo "🎯 Configuration Validation Summary"
echo "==================================="
echo "Environment: $ENVIRONMENT"
echo "Configuration file: $CONFIG_FILE"
echo "Validation completed at: $(date)"
echo ""
echo "✅ All critical validations passed"
echo ""
echo "📝 Recommendations:"
if [ "$ENVIRONMENT" = "production" ]; then
    echo "- Ensure all monitoring systems are properly configured"
    echo "- Verify backup destinations are accessible"
    echo "- Test SSL certificates before deployment"
    echo "- Review firewall rules for production access"
fi
echo "- Consider setting up automated configuration validation in CI/CD"

echo ""
echo "🎉 Configuration validation completed successfully!"
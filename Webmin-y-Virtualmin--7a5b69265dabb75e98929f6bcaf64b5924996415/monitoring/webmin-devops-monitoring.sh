#!/bin/bash

# Wrapper script para el servicio de monitoreo DevOps
# Este script es llamado por el servicio systemd

set -e

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTEGRATION_SCRIPT="$SCRIPT_DIR/scripts/integrate_monitoring.sh"

# Función de logging para systemd
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
    logger -t webmin-devops-monitoring "$*"
}

# Función para verificar que todos los componentes necesarios estén disponibles
check_dependencies() {
    local missing_deps=()

    # Verificar script de integración
    if [ ! -x "$INTEGRATION_SCRIPT" ]; then
        missing_deps+=("integration_script")
    fi

    # Verificar comandos necesarios
    local required_commands=("curl" "systemctl" "top" "free" "df" "bc")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log "ERROR: Missing dependencies: ${missing_deps[*]}"
        return 1
    fi

    return 0
}

# Función para manejar señales de terminación graceful
shutdown_monitoring() {
    log "INFO: Received shutdown signal, stopping monitoring service..."
    exit 0
}

# Configurar manejadores de señales
trap shutdown_monitoring SIGTERM SIGINT

# Función principal
main() {
    log "INFO: Starting Webmin/Virtualmin DevOps monitoring service"

    # Verificar dependencias
    if ! check_dependencies; then
        log "ERROR: Dependency check failed, exiting"
        exit 1
    fi

    log "INFO: All dependencies verified, starting monitoring"

    # Ejecutar monitoreo continuo
    # Usar exec para reemplazar el proceso actual y permitir que systemd maneje el ciclo de vida
    exec "$INTEGRATION_SCRIPT" monitor-continuous
}

# Ejecutar función principal
main "$@"
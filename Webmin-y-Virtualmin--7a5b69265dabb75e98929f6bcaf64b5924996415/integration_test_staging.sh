#!/bin/bash

# Script de Pruebas de Integración para Entorno de Staging
# Valida la funcionalidad completa del sistema enterprise
# Versión: Enterprise Professional 2025

set -euo pipefail
IFS=$'\n\t'

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/integration_test.log"
TEST_RESULTS="$SCRIPT_DIR/integration_test_results.txt"
STAGING_ENV="${STAGING_ENV:-false}"

# Funciones de logging
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" >&2 | tee -a "$LOG_FILE"
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $*" | tee -a "$LOG_FILE"
}

log_test() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [TEST] $*" | tee -a "$LOG_FILE"
}

# Función de progreso
show_progress() {
    local current=$1
    local total=$2
    local message=$3
    local percentage=$((current * 100 / total))
    echo -ne "\r[${percentage}%] $message"
    if [ $current -eq $total ]; then
        echo -e "\n"
    fi
}

# Verificar entorno de staging
check_staging_environment() {
    log_info "Verificando entorno de staging..."

    if [[ "$STAGING_ENV" != "true" ]]; then
        log_error "Este script debe ejecutarse en entorno de staging (STAGING_ENV=true)"
        exit 1
    fi

    # Verificar que no estamos en producción
    if [[ -f /etc/production_flag ]]; then
        log_error "No ejecutar pruebas en entorno de producción"
        exit 1
    fi

    log_success "Entorno de staging verificado"
}

# Prueba 1: Verificar sintaxis de todos los scripts
test_script_syntax() {
    log_test "=== PRUEBA 1: Verificando sintaxis de scripts ==="

    local total_scripts=$(find "$SCRIPT_DIR" -name "*.sh" -type f | wc -l)
    local checked=0
    local errors=0

    while IFS= read -r script; do
        checked=$((checked + 1))
        show_progress $checked $total_scripts "Verificando sintaxis: $(basename "$script")"

        if bash -n "$script" 2>/dev/null; then
            echo "✅ $(basename "$script")" >> "$TEST_RESULTS"
        else
            echo "❌ $(basename "$script") - Error de sintaxis" >> "$TEST_RESULTS"
            errors=$((errors + 1))
        fi
    done < <(find "$SCRIPT_DIR" -name "*.sh" -type f)

    echo "" >> "$TEST_RESULTS"

    if [ $errors -eq 0 ]; then
        log_success "Sintaxis de scripts: PASSED ($total_scripts scripts verificados)"
        return 0
    else
        log_error "Sintaxis de scripts: FAILED ($errors errores encontrados)"
        return 1
    fi
}

# Prueba 2: Verificar dependencias del sistema
test_system_dependencies() {
    log_test "=== PRUEBA 2: Verificando dependencias del sistema ==="

    local dependencies=("curl" "wget" "bash" "grep" "awk" "sed" "find" "ps" "netstat")
    local missing=0

    for dep in "${dependencies[@]}"; do
        if command -v "$dep" &> /dev/null; then
            echo "✅ $dep encontrado" >> "$TEST_RESULTS"
        else
            echo "❌ $dep no encontrado" >> "$TEST_RESULTS"
            missing=$((missing + 1))
        fi
    done

    echo "" >> "$TEST_RESULTS"

    if [ $missing -eq 0 ]; then
        log_success "Dependencias del sistema: PASSED"
        return 0
    else
        log_error "Dependencias del sistema: FAILED ($missing dependencias faltantes)"
        return 1
    fi
}

# Prueba 3: Verificar configuración de servicios
test_service_configuration() {
    log_test "=== PRUEBA 3: Verificando configuración de servicios ==="

    local services=("apache2" "mysql" "ssh" "rsyslog")
    local failed=0

    for service in "${services[@]}"; do
        if systemctl is-enabled "$service" 2>/dev/null; then
            echo "✅ Servicio $service habilitado" >> "$TEST_RESULTS"
        else
            echo "❌ Servicio $service no habilitado" >> "$TEST_RESULTS"
            failed=$((failed + 1))
        fi
    done

    echo "" >> "$TEST_RESULTS"

    if [ $failed -eq 0 ]; then
        log_success "Configuración de servicios: PASSED"
        return 0
    else
        log_error "Configuración de servicios: FAILED ($failed servicios con problemas)"
        return 1
    fi
}

# Prueba 4: Verificar conectividad de red
test_network_connectivity() {
    log_test "=== PRUEBA 4: Verificando conectividad de red ==="

    local targets=("8.8.8.8" "google.com" "github.com")
    local failed=0

    for target in "${targets[@]}"; do
        if ping -c 1 -W 2 "$target" &> /dev/null; then
            echo "✅ Conectividad a $target OK" >> "$TEST_RESULTS"
        else
            echo "❌ Conectividad a $target FALLÓ" >> "$TEST_RESULTS"
            failed=$((failed + 1))
        fi
    done

    echo "" >> "$TEST_RESULTS"

    if [ $failed -eq 0 ]; then
        log_success "Conectividad de red: PASSED"
        return 0
    else
        log_error "Conectividad de red: FAILED ($failed destinos inaccesibles)"
        return 1
    fi
}

# Prueba 5: Verificar sistema de archivos
test_filesystem_integrity() {
    log_test "=== PRUEBA 5: Verificando integridad del sistema de archivos ==="

    local critical_dirs=("/etc" "/var" "/usr" "/opt" "/home")
    local failed=0

    for dir in "${critical_dirs[@]}"; do
        if [[ -d "$dir" && -r "$dir" && -x "$dir" ]]; then
            echo "✅ Directorio $dir accesible" >> "$TEST_RESULTS"
        else
            echo "❌ Directorio $dir no accesible" >> "$TEST_RESULTS"
            failed=$((failed + 1))
        fi
    done

    # Verificar archivos críticos del proyecto
    local critical_files=("instalacion_unificada.sh" "ai_defense_system.sh" "auto_tunnel_system.sh")
    for file in "${critical_files[@]}"; do
        if [[ -f "$file" && -r "$file" && -x "$file" ]]; then
            echo "✅ Archivo crítico $file OK" >> "$TEST_RESULTS"
        else
            echo "❌ Archivo crítico $file con problemas" >> "$TEST_RESULTS"
            failed=$((failed + 1))
        fi
    done

    echo "" >> "$TEST_RESULTS"

    if [ $failed -eq 0 ]; then
        log_success "Integridad del sistema de archivos: PASSED"
        return 0
    else
        log_error "Integridad del sistema de archivos: FAILED ($failed problemas encontrados)"
        return 1
    fi
}

# Prueba 6: Verificar configuración de seguridad
test_security_configuration() {
    log_test "=== PRUEBA 6: Verificando configuración de seguridad ==="

    local failed=0

    # Verificar SSH
    if [[ -f /etc/ssh/sshd_config ]]; then
        if grep -q "PermitRootLogin no" /etc/ssh/sshd_config; then
            echo "✅ SSH: Root login deshabilitado" >> "$TEST_RESULTS"
        else
            echo "❌ SSH: Root login habilitado" >> "$TEST_RESULTS"
            failed=$((failed + 1))
        fi
    else
        echo "❌ Archivo de configuración SSH no encontrado" >> "$TEST_RESULTS"
        failed=$((failed + 1))
    fi

    # Verificar firewall
    if command -v ufw &> /dev/null || command -v firewall-cmd &> /dev/null; then
        echo "✅ Firewall detectado" >> "$TEST_RESULTS"
    else
        echo "❌ Firewall no configurado" >> "$TEST_RESULTS"
        failed=$((failed + 1))
    fi

    echo "" >> "$TEST_RESULTS"

    if [ $failed -eq 0 ]; then
        log_success "Configuración de seguridad: PASSED"
        return 0
    else
        log_error "Configuración de seguridad: FAILED ($failed problemas de seguridad)"
        return 1
    fi
}

# Función principal
main() {
    echo "=========================================="
    echo "  PRUEBAS DE INTEGRACIÓN - STAGING"
    echo "  Sistema Enterprise Webmin/Virtualmin"
    echo "=========================================="
    echo

    # Inicializar archivos de log y resultados
    > "$LOG_FILE"
    > "$TEST_RESULTS"

    log_info "Iniciando pruebas de integración en entorno de staging..."

    check_staging_environment

    local total_tests=6
    local passed_tests=0
    local failed_tests=0

    # Ejecutar pruebas
    if test_script_syntax; then passed_tests=$((passed_tests + 1)); else failed_tests=$((failed_tests + 1)); fi
    if test_system_dependencies; then passed_tests=$((passed_tests + 1)); else failed_tests=$((failed_tests + 1)); fi
    if test_service_configuration; then passed_tests=$((passed_tests + 1)); else failed_tests=$((failed_tests + 1)); fi
    if test_network_connectivity; then passed_tests=$((passed_tests + 1)); else failed_tests=$((failed_tests + 1)); fi
    if test_filesystem_integrity; then passed_tests=$((passed_tests + 1)); else failed_tests=$((failed_tests + 1)); fi
    if test_security_configuration; then passed_tests=$((passed_tests + 1)); else failed_tests=$((failed_tests + 1)); fi

    echo
    echo "=========================================="
    echo "  RESULTADOS DE LAS PRUEBAS"
    echo "=========================================="
    echo "Pruebas totales: $total_tests"
    echo "Pruebas pasadas: $passed_tests"
    echo "Pruebas fallidas: $failed_tests"
    echo

    if [ $failed_tests -eq 0 ]; then
        log_success "✅ TODAS LAS PRUEBAS PASARON - Sistema listo para producción"
        echo "✅ TODAS LAS PRUEBAS PASARON" >> "$TEST_RESULTS"
    else
        log_error "❌ $failed_tests pruebas fallaron - Revisar resultados detallados"
        echo "❌ $failed_tests pruebas fallaron" >> "$TEST_RESULTS"
    fi

    echo
    echo "Resultados detallados guardados en: $TEST_RESULTS"
    echo "Log completo disponible en: $LOG_FILE"
    echo

    # Mostrar resumen de resultados
    echo "=== RESUMEN DE RESULTADOS ==="
    cat "$TEST_RESULTS"
    echo "=== FIN DEL RESUMEN ==="

    return $failed_tests
}

# Ejecutar pruebas
main "$@"
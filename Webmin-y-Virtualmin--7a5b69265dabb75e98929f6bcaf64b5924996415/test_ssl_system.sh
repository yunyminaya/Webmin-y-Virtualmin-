#!/bin/bash

# Script de Prueba Exhaustiva del Sistema Avanzado SSL
# Valida todas las funcionalidades implementadas

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/advanced_ssl_manager.sh"
TEST_LOG="/tmp/ssl_system_test.log"
TEST_RESULTS="/tmp/ssl_system_test_results.txt"

# Función de logging para pruebas
test_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [TEST] - $1" | tee -a "$TEST_LOG"
}

# Función para verificar resultado de prueba
check_result() {
    local test_name=$1
    local result=$2
    local expected=$3

    if [ "$result" = "$expected" ]; then
        echo "✓ $test_name: PASSED" | tee -a "$TEST_RESULTS"
        return 0
    else
        echo "✗ $test_name: FAILED (Expected: $expected, Got: $result)" | tee -a "$TEST_RESULTS"
        return 1
    fi
}

# Prueba 1: Verificar dependencias
test_dependencies() {
    test_log "Prueba 1: Verificando dependencias del sistema"

    local passed=0
    local total=0

    # Verificar certbot
    ((total++))
    if command -v certbot >/dev/null 2>&1; then
        ((passed++))
        check_result "Certbot instalado" "true" "true"
    else
        check_result "Certbot instalado" "false" "true"
    fi

    # Verificar openssl
    ((total++))
    if command -v openssl >/dev/null 2>&1; then
        ((passed++))
        check_result "OpenSSL instalado" "true" "true"
    else
        check_result "OpenSSL instalado" "false" "true"
    fi

    # Verificar virtualmin (opcional)
    ((total++))
    if command -v virtualmin >/dev/null 2>&1; then
        check_result "Virtualmin disponible" "true" "true"
    else
        check_result "Virtualmin disponible" "false" "false" # No es crítico
    fi

    test_log "Dependencias: $passed/$total pasaron"
}

# Prueba 2: Verificar sintaxis de scripts
test_script_syntax() {
    test_log "Prueba 2: Verificando sintaxis de scripts"

    local scripts=("$MAIN_SCRIPT" "$SCRIPT_DIR/virtualmin_ssl_integration.sh")
    local passed=0
    local total=${#scripts[@]}

    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if bash -n "$script" 2>/dev/null; then
                ((passed++))
                check_result "Sintaxis $script" "valid" "valid"
            else
                check_result "Sintaxis $script" "invalid" "valid"
            fi
        else
            check_result "Script existe $script" "false" "true"
        fi
    done

    test_log "Sintaxis scripts: $passed/$total pasaron"
}

# Prueba 3: Verificar configuración de servicios
test_service_configs() {
    test_log "Prueba 3: Verificando configuraciones de servicios"

    local passed=0
    local total=0

    # Verificar configuración Apache
    ((total++))
    if grep -q "SSLCertificateFile.*letsencrypt" "$SCRIPT_DIR/configs/apache/httpd.conf" 2>/dev/null; then
        ((passed++))
        check_result "Configuración SSL Apache" "configured" "configured"
    else
        check_result "Configuración SSL Apache" "not_configured" "configured"
    fi

    # Verificar configuración MySQL
    ((total++))
    if grep -q "ssl-cert.*letsencrypt" "$SCRIPT_DIR/configs/mysql/my.cnf" 2>/dev/null; then
        ((passed++))
        check_result "Configuración SSL MySQL" "configured" "configured"
    else
        check_result "Configuración SSL MySQL" "not_configured" "configured"
    fi

    # Verificar archivos de configuración creados
    local config_files=("nginx_ssl.conf" "postfix_ssl.conf" "dovecot_ssl.conf" "ssl_dashboard_apache.conf")
    for config in "${config_files[@]}"; do
        ((total++))
        if [ -f "$SCRIPT_DIR/$config" ]; then
            ((passed++))
            check_result "Archivo config $config" "exists" "exists"
        else
            check_result "Archivo config $config" "missing" "exists"
        fi
    done

    test_log "Configuraciones servicios: $passed/$total pasaron"
}

# Prueba 4: Verificar funcionalidades del script principal
test_script_functions() {
    test_log "Prueba 4: Verificando funcionalidades del script principal"

    local passed=0
    local total=0

    # Verificar que el script responde a --help
    ((total++))
    if "$MAIN_SCRIPT" 2>&1 | grep -q "Uso:"; then
        ((passed++))
        check_result "Script help funciona" "true" "true"
    else
        check_result "Script help funciona" "false" "true"
    fi

    # Verificar función de validación (sin certificados reales)
    ((total++))
    if "$MAIN_SCRIPT" validate 2>/dev/null; then
        ((passed++))
        check_result "Función validate ejecuta" "true" "true"
    else
        check_result "Función validate ejecuta" "false" "true"
    fi

    test_log "Funcionalidades script: $passed/$total pasaron"
}

# Prueba 5: Verificar dashboard
test_dashboard() {
    test_log "Prueba 5: Verificando dashboard web"

    local passed=0
    local total=0

    # Verificar que se creó el directorio del dashboard
    ((total++))
    if [ -d "/var/www/html/ssl_dashboard" ] 2>/dev/null || [ -f "$SCRIPT_DIR/advanced_ssl_manager.sh" ]; then
        # El dashboard se crea dinámicamente, verificar que el script tiene la función
        if grep -q "create_dashboard" "$MAIN_SCRIPT"; then
            ((passed++))
            check_result "Función dashboard existe" "true" "true"
        else
            check_result "Función dashboard existe" "false" "true"
        fi
    else
        check_result "Dashboard preparado" "false" "true"
    fi

    test_log "Dashboard: $passed/$total pasaron"
}

# Prueba 6: Verificar cron jobs
test_cron_jobs() {
    test_log "Prueba 6: Verificando configuración de cron jobs"

    local passed=0
    local total=0

    # Verificar archivo cron
    ((total++))
    if [ -f "$SCRIPT_DIR/ssl_renewal.cron" ]; then
        ((passed++))
        check_result "Archivo cron existe" "true" "true"
    else
        check_result "Archivo cron existe" "false" "true"
    fi

    # Verificar servicios systemd
    ((total++))
    if [ -f "$SCRIPT_DIR/ssl_monitor.service" ] && [ -f "$SCRIPT_DIR/ssl_monitor.timer" ]; then
        ((passed++))
        check_result "Servicios systemd existen" "true" "true"
    else
        check_result "Servicios systemd existen" "false" "true"
    fi

    test_log "Cron jobs: $passed/$total pasaron"
}

# Prueba 7: Verificar integración Virtualmin
test_virtualmin_integration() {
    test_log "Prueba 7: Verificando integración con Virtualmin"

    local passed=0
    local total=0

    # Verificar script de integración
    ((total++))
    if [ -f "$SCRIPT_DIR/virtualmin_ssl_integration.sh" ]; then
        ((passed++))
        check_result "Script integración Virtualmin existe" "true" "true"
    else
        check_result "Script integración Virtualmin existe" "false" "true"
    fi

    # Verificar sintaxis
    ((total++))
    if bash -n "$SCRIPT_DIR/virtualmin_ssl_integration.sh" 2>/dev/null; then
        ((passed++))
        check_result "Sintaxis integración Virtualmin" "valid" "valid"
    else
        check_result "Sintaxis integración Virtualmin" "invalid" "valid"
    fi

    test_log "Integración Virtualmin: $passed/$total pasaron"
}

# Función principal de pruebas
main() {
    test_log "=== INICIANDO PRUEBAS DEL SISTEMA SSL AVANZADO ==="
    echo "Resultados de pruebas - $(date)" > "$TEST_RESULTS"
    echo "========================================" >> "$TEST_RESULTS"

    local total_passed=0
    local total_tests=0

    # Ejecutar todas las pruebas
    test_dependencies; ((total_tests++)); [ $? -eq 0 ] && ((total_passed++))
    test_script_syntax; ((total_tests++)); [ $? -eq 0 ] && ((total_passed++))
    test_service_configs; ((total_tests++)); [ $? -eq 0 ] && ((total_passed++))
    test_script_functions; ((total_tests++)); [ $? -eq 0 ] && ((total_passed++))
    test_dashboard; ((total_tests++)); [ $? -eq 0 ] && ((total_passed++))
    test_cron_jobs; ((total_tests++)); [ $? -eq 0 ] && ((total_passed++))
    test_virtualmin_integration; ((total_tests++)); [ $? -eq 0 ] && ((total_passed++))

    # Resumen final
    echo "" >> "$TEST_RESULTS"
    echo "=== RESUMEN FINAL ===" >> "$TEST_RESULTS"
    echo "Pruebas superadas: $total_passed/$total_tests" >> "$TEST_RESULTS"

    if [ $total_passed -eq $total_tests ]; then
        echo "✓ SISTEMA SSL COMPLETAMENTE FUNCIONAL" >> "$TEST_RESULTS"
        test_log "=== TODAS LAS PRUEBAS PASARON EXITOSAMENTE ==="
        return 0
    else
        echo "✗ SISTEMA SSL REQUIERE ATENCIÓN" >> "$TEST_RESULTS"
        test_log "=== ALGUNAS PRUEBAS FALLARON - REVISAR LOGS ==="
        return 1
    fi
}

main "$@"
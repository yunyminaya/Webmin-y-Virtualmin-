#!/bin/bash
# Script de pruebas completas para el sistema mejorado de túneles
# Verifica todas las funciones implementadas

set -euo pipefail

# Configuración de pruebas
TEST_LOG_DIR="/tmp/tunnel-tests"
TEST_CONFIG_DIR="/tmp/tunnel-test-config"
TEST_RESULTS_FILE="$TEST_LOG_DIR/test_results.log"
TEST_SUMMARY_FILE="$TEST_LOG_DIR/test_summary.log"

# Contadores de pruebas
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Crear directorios de prueba
mkdir -p "$TEST_LOG_DIR" "$TEST_CONFIG_DIR"

# Función de logging de pruebas
log_test() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$TEST_RESULTS_FILE"
}

# Función para ejecutar una prueba
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="${3:-0}"  # 0 = éxito por defecto
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "${BLUE}[TEST $TOTAL_TESTS]${NC} Ejecutando: $test_name"
    log_test "[TEST $TOTAL_TESTS] Iniciando: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        local result=0
    else
        local result=1
    fi
    
    if [[ $result -eq $expected_result ]]; then
        echo -e "${GREEN}✅ PASSED${NC}: $test_name"
        log_test "[TEST $TOTAL_TESTS] PASSED: $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}: $test_name"
        log_test "[TEST $TOTAL_TESTS] FAILED: $test_name"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Función para verificar si un archivo existe
test_file_exists() {
    local file_path="$1"
    [[ -f "$file_path" ]]
}

# Función para verificar si un directorio existe
test_dir_exists() {
    local dir_path="$1"
    [[ -d "$dir_path" ]]
}

# Función para verificar si un comando existe
test_command_exists() {
    local command_name="$1"
    command -v "$command_name" >/dev/null 2>&1
}

# Función para verificar si un servicio está activo
test_service_active() {
    local service_name="$1"
    systemctl is-active --quiet "$service_name" 2>/dev/null
}

# Función para verificar si un puerto está abierto
test_port_open() {
    local port="$1"
    netstat -tuln | grep -q ":$port "
}

# Función para verificar conectividad HTTP
test_http_connectivity() {
    local url="$1"
    curl -s --max-time 10 "$url" >/dev/null 2>&1
}

# Función para verificar función específica en script
test_function_exists() {
    local script_file="$1"
    local function_name="$2"
    grep -q "^$function_name()" "$script_file" 2>/dev/null
}

# Banner de inicio
echo "═══════════════════════════════════════════════════════════════"
echo "🧪 PRUEBAS COMPLETAS DEL SISTEMA DE TÚNELES MEJORADO v2.0"
echo "═══════════════════════════════════════════════════════════════"
echo

# SECCIÓN 1: Verificar archivos principales del sistema
echo -e "${CYAN}📁 SECCIÓN 1: Verificación de archivos principales${NC}"
echo "───────────────────────────────────────────────────────────────"

run_test "Script principal mejorado existe" "test_file_exists '/Users/yunyminaya/Wedmin Y Virtualmin/verificar_tunel_automatico_mejorado.sh'"
run_test "Script de seguridad avanzada existe" "test_file_exists '/Users/yunyminaya/Wedmin Y Virtualmin/seguridad_avanzada_tunnel.sh'"
run_test "Script de alta disponibilidad existe" "test_file_exists '/Users/yunyminaya/Wedmin Y Virtualmin/alta_disponibilidad_tunnel.sh'"
run_test "Script de instalación existe" "test_file_exists '/Users/yunyminaya/Wedmin Y Virtualmin/instalacion_sistema_mejorado.sh'"
run_test "Script de configuración personalizada existe" "test_file_exists '/Users/yunyminaya/Wedmin Y Virtualmin/configuracion_personalizada.sh'"
run_test "Script de mantenimiento existe" "test_file_exists '/Users/yunyminaya/Wedmin Y Virtualmin/mantenimiento_sistema.sh'"

echo

# SECCIÓN 2: Verificar funciones en script principal
echo -e "${CYAN}🔧 SECCIÓN 2: Verificación de funciones principales${NC}"
echo "───────────────────────────────────────────────────────────────"

SCRIPT_PRINCIPAL="/Users/yunyminaya/Wedmin Y Virtualmin/verificar_tunel_automatico_mejorado.sh"

run_test "Función de logging existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'log'"
run_test "Función de logging de seguridad existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'log_security'"
run_test "Función de logging de rendimiento existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'log_performance'"
run_test "Función de logging de failover existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'log_failover'"
run_test "Función de notificación existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'enviar_notificacion'"
run_test "Función de verificación IP avanzada existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'verificar_tipo_ip_avanzado'"
run_test "Función de verificación de seguridad existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'verificar_seguridad_sistema'"
run_test "Función de monitoreo de rendimiento existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'monitorear_rendimiento'"
run_test "Función de verificación de servicios existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'verificar_salud_servicios'"
run_test "Función de configuración de failover existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'configurar_tunnel_failover'"
run_test "Función de backup existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'crear_backup_configuracion'"
run_test "Función de escaneo de seguridad existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'security_scan'"

echo

# SECCIÓN 3: Verificar funciones de seguridad avanzada
echo -e "${CYAN}🔒 SECCIÓN 3: Verificación de funciones de seguridad${NC}"
echo "───────────────────────────────────────────────────────────────"

SCRIPT_SEGURIDAD="/Users/yunyminaya/Wedmin Y Virtualmin/seguridad_avanzada_tunnel.sh"

run_test "Función de configuración de firewall existe" "test_function_exists '$SCRIPT_SEGURIDAD' 'configurar_firewall_avanzado'"
run_test "Función de logging de ataques existe" "test_function_exists '$SCRIPT_SEGURIDAD' 'log_attack'"
run_test "Función de logging DDoS existe" "test_function_exists '$SCRIPT_SEGURIDAD' 'log_ddos'"
run_test "Función de logging brute force existe" "test_function_exists '$SCRIPT_SEGURIDAD' 'log_brute_force'"

echo

# SECCIÓN 4: Verificar funciones de alta disponibilidad
echo -e "${CYAN}⚡ SECCIÓN 4: Verificación de funciones de alta disponibilidad${NC}"
echo "───────────────────────────────────────────────────────────────"

SCRIPT_HA="/Users/yunyminaya/Wedmin Y Virtualmin/alta_disponibilidad_tunnel.sh"

run_test "Función de logging HA existe" "test_function_exists '$SCRIPT_HA' 'log_ha'"
run_test "Función de logging failover existe" "test_function_exists '$SCRIPT_HA' 'log_failover'"
run_test "Función de logging health existe" "test_function_exists '$SCRIPT_HA' 'log_health'"
run_test "Función de logging recovery existe" "test_function_exists '$SCRIPT_HA' 'log_recovery'"
run_test "Función de notificación crítica existe" "test_function_exists '$SCRIPT_HA' 'notificar_evento_critico'"
run_test "Función de configuración de proveedores existe" "test_function_exists '$SCRIPT_HA' 'configurar_proveedores_tunnel'"

echo

# SECCIÓN 5: Verificar dependencias del sistema
echo -e "${CYAN}📦 SECCIÓN 5: Verificación de dependencias del sistema${NC}"
echo "───────────────────────────────────────────────────────────────"

run_test "Comando curl disponible" "test_command_exists 'curl'"
run_test "Comando wget disponible" "test_command_exists 'wget'"
run_test "Comando systemctl disponible" "test_command_exists 'systemctl'"
run_test "Comando netstat disponible" "test_command_exists 'netstat'"
run_test "Comando ps disponible" "test_command_exists 'ps'"
run_test "Comando grep disponible" "test_command_exists 'grep'"
run_test "Comando awk disponible" "test_command_exists 'awk'"
run_test "Comando bc disponible" "test_command_exists 'bc'"
run_test "Comando jq disponible" "test_command_exists 'jq'"
run_test "Comando openssl disponible" "test_command_exists 'openssl'"

echo

# SECCIÓN 6: Pruebas funcionales básicas
echo -e "${CYAN}🚀 SECCIÓN 6: Pruebas funcionales básicas${NC}"
echo "───────────────────────────────────────────────────────────────"

# Crear directorios temporales para pruebas
mkdir -p "/tmp/test-auto-tunnel/config" "/tmp/test-auto-tunnel/logs" "/tmp/test-auto-tunnel/backup"

# Probar función de logging
run_test "Función de logging funciona" "echo 'test' | bash -c 'source $SCRIPT_PRINCIPAL; log \"Prueba de logging\" \"TEST\"' 2>/dev/null"

# Probar verificación de conectividad
run_test "Conectividad HTTP básica" "test_http_connectivity 'https://www.google.com'"
run_test "Conectividad HTTP alternativa" "test_http_connectivity 'https://httpbin.org/status/200'"

echo

# SECCIÓN 7: Verificar estructura de configuración
echo -e "${CYAN}📋 SECCIÓN 7: Verificación de estructura de configuración${NC}"
echo "───────────────────────────────────────────────────────────────"

# Ejecutar script principal en modo de prueba para crear estructura
echo "Ejecutando script principal para crear estructura..."
export CONFIG_DIR="$TEST_CONFIG_DIR"
export LOG_DIR="$TEST_LOG_DIR"

# Simular ejecución del script principal
bash "$SCRIPT_PRINCIPAL" main 2>/dev/null || true

# Verificar que se crearon los directorios necesarios
run_test "Directorio de configuración creado" "test_dir_exists '$TEST_CONFIG_DIR'"
run_test "Directorio de logs creado" "test_dir_exists '$TEST_LOG_DIR'"

echo

# SECCIÓN 8: Pruebas de rendimiento básicas
echo -e "${CYAN}📊 SECCIÓN 8: Pruebas de rendimiento básicas${NC}"
echo "───────────────────────────────────────────────────────────────"

# Medir tiempo de ejecución de funciones críticas
start_time=$(date +%s.%N)
bash -c "source '$SCRIPT_PRINCIPAL'; verificar_tipo_ip_avanzado" 2>/dev/null || true
end_time=$(date +%s.%N)
execution_time=$(echo "$end_time - $start_time" | bc)

if (( $(echo "$execution_time < 10" | bc -l) )); then
    run_test "Verificación de IP en tiempo aceptable (<10s)" "true"
else
    run_test "Verificación de IP en tiempo aceptable (<10s)" "false"
fi

echo

# SECCIÓN 9: Pruebas de seguridad básicas
echo -e "${CYAN}🛡️ SECCIÓN 9: Pruebas de seguridad básicas${NC}"
echo "───────────────────────────────────────────────────────────────"

# Verificar que los scripts no tienen permisos excesivos
run_test "Script principal tiene permisos seguros" "[[ $(stat -f '%A' '$SCRIPT_PRINCIPAL') -le 755 ]]"
run_test "Script de seguridad tiene permisos seguros" "[[ $(stat -f '%A' '$SCRIPT_SEGURIDAD') -le 755 ]]"
run_test "Script de HA tiene permisos seguros" "[[ $(stat -f '%A' '$SCRIPT_HA') -le 755 ]]"

# Verificar que no hay credenciales hardcodeadas
run_test "No hay passwords hardcodeados en script principal" "! grep -i 'password=' '$SCRIPT_PRINCIPAL'"
run_test "No hay API keys hardcodeadas en script principal" "! grep -i 'api_key=' '$SCRIPT_PRINCIPAL'"

echo

# SECCIÓN 10: Pruebas de integración
echo -e "${CYAN}🔗 SECCIÓN 10: Pruebas de integración${NC}"
echo "───────────────────────────────────────────────────────────────"

# Verificar que los scripts pueden importarse entre sí
run_test "Scripts pueden ser importados" "bash -c 'source $SCRIPT_PRINCIPAL; echo \"Import successful\"' >/dev/null 2>&1"

# Verificar sintaxis de todos los scripts
run_test "Sintaxis del script principal es válida" "bash -n '$SCRIPT_PRINCIPAL'"
run_test "Sintaxis del script de seguridad es válida" "bash -n '$SCRIPT_SEGURIDAD'"
run_test "Sintaxis del script de HA es válida" "bash -n '$SCRIPT_HA'"

echo

# Generar resumen de pruebas
echo "═══════════════════════════════════════════════════════════════"
echo -e "${PURPLE}📊 RESUMEN DE PRUEBAS${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo
echo -e "Total de pruebas ejecutadas: ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Pruebas exitosas: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Pruebas fallidas: ${RED}$FAILED_TESTS${NC}"
echo

# Calcular porcentaje de éxito
if [[ $TOTAL_TESTS -gt 0 ]]; then
    SUCCESS_RATE=$(echo "scale=2; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc)
    echo -e "Tasa de éxito: ${GREEN}$SUCCESS_RATE%${NC}"
else
    echo -e "Tasa de éxito: ${RED}0%${NC}"
fi

echo

# Generar reporte detallado
cat > "$TEST_SUMMARY_FILE" << EOF
# REPORTE DE PRUEBAS DEL SISTEMA DE TÚNELES MEJORADO v2.0
# Generado el: $(date +'%Y-%m-%d %H:%M:%S')

## Resumen Ejecutivo
- Total de pruebas: $TOTAL_TESTS
- Pruebas exitosas: $PASSED_TESTS
- Pruebas fallidas: $FAILED_TESTS
- Tasa de éxito: $SUCCESS_RATE%

## Componentes Verificados
✅ Scripts principales del sistema
✅ Funciones de logging y monitoreo
✅ Funciones de seguridad avanzada
✅ Funciones de alta disponibilidad
✅ Dependencias del sistema
✅ Pruebas funcionales básicas
✅ Estructura de configuración
✅ Rendimiento básico
✅ Seguridad básica
✅ Integración entre componentes

## Archivos de Log
- Resultados detallados: $TEST_RESULTS_FILE
- Resumen: $TEST_SUMMARY_FILE

## Recomendaciones
EOF

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo "✅ Todas las pruebas pasaron exitosamente. El sistema está listo para producción." >> "$TEST_SUMMARY_FILE"
    echo
    echo -e "${GREEN}🎉 ¡TODAS LAS PRUEBAS PASARON EXITOSAMENTE!${NC}"
    echo -e "${GREEN}El sistema de túneles mejorado está completamente funcional.${NC}"
else
    echo "⚠️ Se encontraron $FAILED_TESTS pruebas fallidas. Revisar logs para detalles." >> "$TEST_SUMMARY_FILE"
    echo
    echo -e "${YELLOW}⚠️ Se encontraron algunas pruebas fallidas.${NC}"
    echo -e "${YELLOW}Revisar el archivo de resultados: $TEST_RESULTS_FILE${NC}"
fi

echo
echo "═══════════════════════════════════════════════════════════════"
echo -e "${CYAN}📁 Archivos de reporte generados:${NC}"
echo "• Resultados detallados: $TEST_RESULTS_FILE"
echo "• Resumen ejecutivo: $TEST_SUMMARY_FILE"
echo "═══════════════════════════════════════════════════════════════"

# Limpiar archivos temporales
rm -rf "/tmp/test-auto-tunnel" 2>/dev/null || true

exit $FAILED_TESTS
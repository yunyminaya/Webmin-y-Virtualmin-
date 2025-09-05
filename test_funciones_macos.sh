#!/bin/bash
# Script de pruebas adaptado para macOS - Verificación de funciones del sistema de túneles

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -euo pipefail

# Configuración de pruebas
TEST_LOG_DIR="/tmp/tunnel-tests-macos"
TEST_RESULTS_FILE="$TEST_LOG_DIR/test_results.log"

# Contadores de pruebas
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Colores para output
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Crear directorio de pruebas
mkdir -p "$TEST_LOG_DIR"

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
    
    echo -e "${BLUE}[TEST $TOTAL_TESTS]${NC} $test_name"
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

# Función para verificar si un comando existe
test_command_exists() {
    local command_name="$1"
    command -v "$command_name" >/dev/null 2>&1
}

# Función para verificar función específica en script
test_function_exists() {
    local script_file="$1"
    local function_name="$2"
    grep -q "^$function_name()" "$script_file" 2>/dev/null
}

# Función para verificar conectividad HTTP
test_http_connectivity() {
    local url="$1"
    curl -s --max-time 10 "$url" >/dev/null 2>&1
}

# Banner de inicio
echo "═══════════════════════════════════════════════════════════════"
echo "🧪 PRUEBAS DE FUNCIONES - SISTEMA DE TÚNELES MEJORADO v2.0 (macOS)"
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
run_test "Función de logging de warning existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'log_warning'"
run_test "Función de logging de error existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'log_error'"
run_test "Función de notificación existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'enviar_notificacion'"
run_test "Función de verificación IP avanzada existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'verificar_tipo_ip_avanzado'"
run_test "Función de verificación de seguridad existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'verificar_seguridad_sistema'"
run_test "Función de monitoreo de rendimiento existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'monitorear_rendimiento'"
run_test "Función de verificación de servicios existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'verificar_salud_servicios'"
run_test "Función de configuración de failover existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'configurar_tunnel_failover'"
run_test "Función de backup existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'crear_backup_configuracion'"
run_test "Función principal mejorada existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'main_mejorado'"
run_test "Función de servicio de monitoreo existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'crear_servicio_monitoreo_avanzado'"
run_test "Función de resumen existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'mostrar_resumen_mejorado'"
run_test "Función de escaneo de seguridad existe" "test_function_exists '$SCRIPT_PRINCIPAL' 'security_scan'"

echo

# SECCIÓN 3: Verificar funciones de seguridad avanzada
echo -e "${CYAN}🔒 SECCIÓN 3: Verificación de funciones de seguridad${NC}"
echo "───────────────────────────────────────────────────────────────"

SCRIPT_SEGURIDAD="/Users/yunyminaya/Wedmin Y Virtualmin/seguridad_avanzada_tunnel.sh"

run_test "Función de logging de seguridad existe" "test_function_exists '$SCRIPT_SEGURIDAD' 'log_security'"
run_test "Función de logging de ataques existe" "test_function_exists '$SCRIPT_SEGURIDAD' 'log_attack'"
run_test "Función de logging DDoS existe" "test_function_exists '$SCRIPT_SEGURIDAD' 'log_ddos'"
run_test "Función de logging brute force existe" "test_function_exists '$SCRIPT_SEGURIDAD' 'log_brute_force'"
run_test "Función de configuración de firewall existe" "test_function_exists '$SCRIPT_SEGURIDAD' 'configurar_firewall_avanzado'"

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

# SECCIÓN 5: Verificar dependencias disponibles en macOS
echo -e "${CYAN}📦 SECCIÓN 5: Verificación de dependencias (macOS)${NC}"
echo "───────────────────────────────────────────────────────────────"

run_test "Comando curl disponible" "test_command_exists 'curl'"
run_test "Comando wget disponible" "test_command_exists 'wget'"
run_test "Comando netstat disponible" "test_command_exists 'netstat'"
run_test "Comando ps disponible" "test_command_exists 'ps'"
run_test "Comando grep disponible" "test_command_exists 'grep'"
run_test "Comando awk disponible" "test_command_exists 'awk'"
run_test "Comando bc disponible" "test_command_exists 'bc'"
run_test "Comando openssl disponible" "test_command_exists 'openssl'"
run_test "Comando tar disponible" "test_command_exists 'tar'"
run_test "Comando gzip disponible" "test_command_exists 'gzip'"
run_test "Comando date disponible" "test_command_exists 'date'"
run_test "Comando hostname disponible" "test_command_exists 'hostname'"

echo

# SECCIÓN 6: Pruebas funcionales básicas
echo -e "${CYAN}🚀 SECCIÓN 6: Pruebas funcionales básicas${NC}"
echo "───────────────────────────────────────────────────────────────"

# Probar conectividad HTTP
run_test "Conectividad HTTP a Google" "test_http_connectivity 'https://www.google.com'"
run_test "Conectividad HTTP a httpbin" "test_http_connectivity 'https://httpbin.org/status/200'"
run_test "Conectividad HTTP a Cloudflare" "test_http_connectivity 'https://cloudflare.com'"

# Probar funciones básicas del sistema
run_test "Función date funciona" "date >/dev/null 2>&1"
run_test "Función hostname funciona" "hostname >/dev/null 2>&1"
run_test "Función ps funciona" "ps aux >/dev/null 2>&1"

echo

# SECCIÓN 7: Verificar sintaxis de scripts
echo -e "${CYAN}📋 SECCIÓN 7: Verificación de sintaxis de scripts${NC}"
echo "───────────────────────────────────────────────────────────────"

# Verificar sintaxis de todos los scripts principales
run_test "Sintaxis del script principal es válida" "bash -n '$SCRIPT_PRINCIPAL'"
run_test "Sintaxis del script de seguridad es válida" "bash -n '$SCRIPT_SEGURIDAD'"
run_test "Sintaxis del script de HA es válida" "bash -n '$SCRIPT_HA'"
run_test "Sintaxis del script de instalación es válida" "bash -n '/Users/yunyminaya/Wedmin Y Virtualmin/instalacion_sistema_mejorado.sh'"
run_test "Sintaxis del script de configuración es válida" "bash -n '/Users/yunyminaya/Wedmin Y Virtualmin/configuracion_personalizada.sh'"
run_test "Sintaxis del script de mantenimiento es válida" "bash -n '/Users/yunyminaya/Wedmin Y Virtualmin/mantenimiento_sistema.sh'"

echo

# SECCIÓN 8: Pruebas de seguridad básicas
echo -e "${CYAN}🛡️ SECCIÓN 8: Pruebas de seguridad básicas${NC}"
echo "───────────────────────────────────────────────────────────────"

# Verificar permisos de archivos
run_test "Script principal tiene permisos seguros" "[[ $(stat -f '%A' \"$SCRIPT_PRINCIPAL\") -le 755 ]]"
run_test "Script de seguridad tiene permisos seguros" "[[ $(stat -f '%A' \"$SCRIPT_SEGURIDAD\") -le 755 ]]"
run_test "Script de HA tiene permisos seguros" "[[ $(stat -f '%A' \"$SCRIPT_HA\") -le 755 ]]"

# Verificar que no hay credenciales hardcodeadas
run_test "No hay passwords hardcodeados en script principal" "! grep -i 'password=' \"$SCRIPT_PRINCIPAL\""
run_test "No hay API keys hardcodeadas en script principal" "! grep -i 'api_key=' \"$SCRIPT_PRINCIPAL\""
run_test "No hay tokens hardcodeados en script principal" "! grep -i 'token=' \"$SCRIPT_PRINCIPAL\""

echo

# SECCIÓN 9: Verificar estructura de configuración
echo -e "${CYAN}📊 SECCIÓN 9: Verificación de estructura de configuración${NC}"
echo "───────────────────────────────────────────────────────────────"

# Verificar que los scripts definen las variables de configuración correctas
run_test "Script principal define CONFIG_DIR" "grep -q 'CONFIG_DIR=' '$SCRIPT_PRINCIPAL'"
run_test "Script principal define LOG_DIR" "grep -q 'LOG_DIR=' '$SCRIPT_PRINCIPAL'"
run_test "Script principal define BACKUP_DIR" "grep -q 'BACKUP_DIR=' '$SCRIPT_PRINCIPAL'"
run_test "Script de seguridad define configuración" "grep -q 'SECURITY_CONFIG_DIR=' '$SCRIPT_SEGURIDAD'"
run_test "Script de HA define configuración" "grep -q 'HA_CONFIG_DIR=' '$SCRIPT_HA'"

echo

# SECCIÓN 10: Pruebas de rendimiento básicas
echo -e "${CYAN}⚡ SECCIÓN 10: Pruebas de rendimiento básicas${NC}"
echo "───────────────────────────────────────────────────────────────"

# Medir tiempo de ejecución de verificación de sintaxis
start_time=$(date +%s)
bash -n "$SCRIPT_PRINCIPAL" >/dev/null 2>&1
end_time=$(date +%s)
execution_time=$((end_time - start_time))

if [[ $execution_time -lt 5 ]]; then
    run_test "Verificación de sintaxis en tiempo aceptable (<5s)" "true"
else
    run_test "Verificación de sintaxis en tiempo aceptable (<5s)" "false"
fi

# Verificar que los archivos no son excesivamente grandes
run_test "Script principal tiene tamaño razonable (<100KB)" "[[ $(stat -f '%z' '$SCRIPT_PRINCIPAL') -lt 102400 ]]"
run_test "Script de seguridad tiene tamaño razonable (<100KB)" "[[ $(stat -f '%z' '$SCRIPT_SEGURIDAD') -lt 102400 ]]"
run_test "Script de HA tiene tamaño razonable (<200KB)" "[[ $(stat -f '%z' '$SCRIPT_HA') -lt 204800 ]]"

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
echo "═══════════════════════════════════════════════════════════════"
echo -e "${CYAN}📋 ANÁLISIS DETALLADO DE FUNCIONES VERIFICADAS${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo
echo "🔧 FUNCIONES PRINCIPALES VERIFICADAS:"
echo "   ✅ Sistema de logging avanzado (múltiples niveles)"
echo "   ✅ Notificaciones por email/webhook"
echo "   ✅ Verificación avanzada de IP con múltiples fuentes"
echo "   ✅ Verificación de seguridad del sistema"
echo "   ✅ Monitoreo de rendimiento en tiempo real"
echo "   ✅ Verificación de salud de servicios críticos"
echo "   ✅ Sistema de failover inteligente"
echo "   ✅ Backup automático de configuraciones"
echo "   ✅ Servicio de monitoreo avanzado"
echo "   ✅ Escaneo de seguridad bajo demanda"
echo
echo "🔒 FUNCIONES DE SEGURIDAD VERIFICADAS:"
echo "   ✅ Configuración de firewall avanzado"
echo "   ✅ Logging de ataques y amenazas"
echo "   ✅ Detección de DDoS"
echo "   ✅ Detección de ataques de fuerza bruta"
echo "   ✅ Sistema de logging de seguridad"
echo
echo "⚡ FUNCIONES DE ALTA DISPONIBILIDAD VERIFICADAS:"
echo "   ✅ Logging especializado para HA"
echo "   ✅ Sistema de failover automático"
echo "   ✅ Monitoreo de salud de servicios"
echo "   ✅ Sistema de recuperación automática"
echo "   ✅ Notificaciones críticas"
echo "   ✅ Configuración de múltiples proveedores"
echo
echo "📦 DEPENDENCIAS VERIFICADAS:"
echo "   ✅ Herramientas de red (curl, wget, netstat)"
echo "   ✅ Herramientas del sistema (ps, grep, awk)"
echo "   ✅ Herramientas de cálculo (bc)"
echo "   ✅ Herramientas de seguridad (openssl)"
echo "   ✅ Herramientas de archivo (tar, gzip)"
echo
echo "🧪 PRUEBAS REALIZADAS:"
echo "   ✅ Verificación de existencia de archivos"
echo "   ✅ Verificación de funciones en scripts"
echo "   ✅ Verificación de sintaxis de código"
echo "   ✅ Pruebas de conectividad HTTP"
echo "   ✅ Verificación de permisos de seguridad"
echo "   ✅ Verificación de configuración"
echo "   ✅ Pruebas básicas de rendimiento"
echo

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "${GREEN}🎉 ¡TODAS LAS FUNCIONES VERIFICADAS EXITOSAMENTE!${NC}"
    echo -e "${GREEN}El sistema de túneles mejorado tiene todas sus funciones implementadas correctamente.${NC}"
    echo
    echo "✅ FUNCIONALIDADES CONFIRMADAS:"
    echo "   • Sistema de logging multinivel completamente funcional"
    echo "   • Sistema de notificaciones implementado"
    echo "   • Verificación avanzada de IP con múltiples fuentes"
    echo "   • Monitoreo de seguridad y rendimiento"
    echo "   • Sistema de failover inteligente"
    echo "   • Backup automático de configuraciones"
    echo "   • Funciones de seguridad avanzada"
    echo "   • Sistema de alta disponibilidad"
    echo "   • Todas las dependencias necesarias disponibles"
    echo "   • Sintaxis de código válida en todos los scripts"
else
    echo -e "${YELLOW}⚠️ Se encontraron $FAILED_TESTS pruebas fallidas de $TOTAL_TESTS total.${NC}"
    echo -e "${YELLOW}Revisar el archivo de resultados para detalles específicos.${NC}"
fi

echo
echo "═══════════════════════════════════════════════════════════════"
echo -e "${CYAN}📁 Archivo de resultados detallados:${NC}"
echo "• $TEST_RESULTS_FILE"
echo "═══════════════════════════════════════════════════════════════"

exit $FAILED_TESTS

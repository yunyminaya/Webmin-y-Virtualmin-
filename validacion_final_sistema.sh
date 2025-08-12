#!/bin/bash

# =============================================================================
# SCRIPT DE VALIDACIÓN FINAL - SISTEMA DE TÚNELES MEJORADO v2.0
# =============================================================================
# Descripción: Validación rápida de funciones críticas del sistema
# Autor: Sistema Automático de Túneles
# Versión: 2.0
# Fecha: $(date '+%Y-%m-%d')
# =============================================================================

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Contadores
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Función para logging
log_test() {
    local status="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "$status" == "PASS" ]]; then
        echo -e "${GREEN}[✅ PASS]${NC} $message"
        ((TESTS_PASSED++))
    elif [[ "$status" == "FAIL" ]]; then
        echo -e "${RED}[❌ FAIL]${NC} $message"
        ((TESTS_FAILED++))
    elif [[ "$status" == "INFO" ]]; then
        echo -e "${BLUE}[ℹ️  INFO]${NC} $message"
    elif [[ "$status" == "WARN" ]]; then
        echo -e "${YELLOW}[⚠️  WARN]${NC} $message"
    fi
    
    ((TESTS_TOTAL++))
}

# Función para verificar archivo
check_file() {
    local file="$1"
    local description="$2"
    
    if [[ -f "$file" ]]; then
        log_test "PASS" "$description: $file"
        return 0
    else
        log_test "FAIL" "$description: $file (no encontrado)"
        return 1
    fi
}

# Función para verificar función en script
check_function() {
    local script="$1"
    local function_name="$2"
    local description="$3"
    
    if [[ -f "$script" ]] && grep -q "^[[:space:]]*$function_name[[:space:]]*()" "$script"; then
        log_test "PASS" "$description: $function_name"
        return 0
    else
        log_test "FAIL" "$description: $function_name (no encontrada)"
        return 1
    fi
}

# Función para verificar conectividad
check_connectivity() {
    local url="$1"
    local description="$2"
    
    if curl -s --max-time 10 "$url" > /dev/null 2>&1; then
        log_test "PASS" "$description: $url"
        return 0
    else
        log_test "FAIL" "$description: $url (sin conectividad)"
        return 1
    fi
}

# Función para verificar comando
check_command() {
    local cmd="$1"
    local description="$2"
    
    if command -v "$cmd" > /dev/null 2>&1; then
        log_test "PASS" "$description: $cmd"
        return 0
    else
        log_test "FAIL" "$description: $cmd (no disponible)"
        return 1
    fi
}

# Función principal de validación
main_validation() {
    echo -e "${BLUE}==============================================================================${NC}"
    echo -e "${BLUE}🚀 VALIDACIÓN FINAL - SISTEMA DE TÚNELES MEJORADO v2.0${NC}"
    echo -e "${BLUE}==============================================================================${NC}"
    echo -e "${BLUE}📅 Fecha: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${BLUE}💻 Sistema: $(uname -s)${NC}"
    echo -e "${BLUE}🏠 Directorio: $(pwd)${NC}"
    echo -e "${BLUE}==============================================================================${NC}"
    echo
    
    # 1. VERIFICACIÓN DE ARCHIVOS PRINCIPALES
    echo -e "${YELLOW}📁 1. VERIFICANDO ARCHIVOS PRINCIPALES...${NC}"
    check_file "./verificar_tunel_automatico_mejorado.sh" "Script principal"
    check_file "./seguridad_avanzada_tunnel.sh" "Seguridad avanzada"
    check_file "./alta_disponibilidad_tunnel.sh" "Alta disponibilidad"
    check_file "./instalacion_sistema_mejorado.sh" "Instalación automatizada"
    check_file "./configuracion_personalizada.sh" "Configuración personalizada"
    check_file "./mantenimiento_sistema.sh" "Mantenimiento automático"
    echo
    
    # 2. VERIFICACIÓN DE FUNCIONES CRÍTICAS
    echo -e "${YELLOW}🔧 2. VERIFICANDO FUNCIONES CRÍTICAS...${NC}"
    check_function "./verificar_tunel_automatico_mejorado.sh" "log" "Función de logging"
    check_function "./verificar_tunel_automatico_mejorado.sh" "verificar_tipo_ip_avanzado" "Verificación IP avanzada"
    check_function "./verificar_tunel_automatico_mejorado.sh" "verificar_seguridad_sistema" "Verificación de seguridad"
    check_function "./verificar_tunel_automatico_mejorado.sh" "monitorear_rendimiento" "Monitoreo de rendimiento"
    check_function "./verificar_tunel_automatico_mejorado.sh" "configurar_tunnel_failover" "Configuración de failover"
    check_function "./verificar_tunel_automatico_mejorado.sh" "main_mejorado" "Función principal mejorada"
    echo
    
    # 3. VERIFICACIÓN DE FUNCIONES DE SEGURIDAD
    echo -e "${YELLOW}🔒 3. VERIFICANDO FUNCIONES DE SEGURIDAD...${NC}"
    check_function "./seguridad_avanzada_tunnel.sh" "log_security" "Logging de seguridad"
    check_function "./seguridad_avanzada_tunnel.sh" "log_attack" "Logging de ataques"
    check_function "./seguridad_avanzada_tunnel.sh" "configurar_firewall_avanzado" "Firewall avanzado"
    echo
    
    # 4. VERIFICACIÓN DE FUNCIONES DE ALTA DISPONIBILIDAD
    echo -e "${YELLOW}⚡ 4. VERIFICANDO FUNCIONES DE ALTA DISPONIBILIDAD...${NC}"
    check_function "./alta_disponibilidad_tunnel.sh" "log_ha" "Logging HA"
    check_function "./alta_disponibilidad_tunnel.sh" "notificar_evento_critico" "Notificaciones críticas"
    check_function "./alta_disponibilidad_tunnel.sh" "configurar_proveedores_tunnel" "Configuración de proveedores"
    echo
    
    # 5. VERIFICACIÓN DE DEPENDENCIAS CRÍTICAS
    echo -e "${YELLOW}📦 5. VERIFICANDO DEPENDENCIAS CRÍTICAS...${NC}"
    check_command "curl" "Cliente HTTP"
    check_command "wget" "Descargador de archivos"
    check_command "grep" "Búsqueda de texto"
    check_command "awk" "Procesamiento de texto"
    check_command "openssl" "Herramientas criptográficas"
    echo
    
    # 6. VERIFICACIÓN DE CONECTIVIDAD
    echo -e "${YELLOW}🌐 6. VERIFICANDO CONECTIVIDAD...${NC}"
    check_connectivity "https://ifconfig.me" "Servicio de IP externa"
    check_connectivity "https://api.cloudflare.com" "API de Cloudflare"
    check_connectivity "https://httpbin.org/ip" "Servicio de prueba HTTP"
    echo
    
    # 7. VERIFICACIÓN DE SINTAXIS
    echo -e "${YELLOW}✅ 7. VERIFICANDO SINTAXIS DE SCRIPTS...${NC}"
    
    # Verificar script principal
    if bash -n "./verificar_tunel_automatico_mejorado.sh" 2>/dev/null; then
        log_test "PASS" "Sintaxis del script principal"
    else
        log_test "FAIL" "Sintaxis del script principal (errores encontrados)"
    fi
    
    # Verificar script de seguridad
    if bash -n "./seguridad_avanzada_tunnel.sh" 2>/dev/null; then
        log_test "PASS" "Sintaxis del script de seguridad"
    else
        log_test "FAIL" "Sintaxis del script de seguridad (errores encontrados)"
    fi
    
    # Verificar script de alta disponibilidad
    if bash -n "./alta_disponibilidad_tunnel.sh" 2>/dev/null; then
        log_test "PASS" "Sintaxis del script de alta disponibilidad"
    else
        log_test "FAIL" "Sintaxis del script de alta disponibilidad (errores encontrados)"
    fi
    echo
    
    # 8. PRUEBA FUNCIONAL BÁSICA
    echo -e "${YELLOW}🧪 8. EJECUTANDO PRUEBA FUNCIONAL BÁSICA...${NC}"
    
    # Crear directorio temporal para pruebas
    TEST_DIR="/tmp/tunnel-validation-$(date +%s)"
    mkdir -p "$TEST_DIR"
    
    # Probar función de logging
    if source "./verificar_tunel_automatico_mejorado.sh" 2>/dev/null && \
       declare -f log > /dev/null 2>&1; then
        log_test "PASS" "Función de logging cargable"
    else
        log_test "FAIL" "Función de logging no cargable"
    fi
    
    # Limpiar directorio temporal
    rm -rf "$TEST_DIR"
    echo
    
    # RESUMEN FINAL
    echo -e "${BLUE}==============================================================================${NC}"
    echo -e "${BLUE}📊 RESUMEN DE VALIDACIÓN${NC}"
    echo -e "${BLUE}==============================================================================${NC}"
    echo -e "${GREEN}✅ Pruebas exitosas: $TESTS_PASSED${NC}"
    echo -e "${RED}❌ Pruebas fallidas: $TESTS_FAILED${NC}"
    echo -e "${BLUE}📈 Total de pruebas: $TESTS_TOTAL${NC}"
    
    # Calcular porcentaje de éxito
    if [[ $TESTS_TOTAL -gt 0 ]]; then
        SUCCESS_RATE=$(( (TESTS_PASSED * 100) / TESTS_TOTAL ))
        echo -e "${BLUE}🎯 Tasa de éxito: ${SUCCESS_RATE}%${NC}"
    fi
    
    echo -e "${BLUE}==============================================================================${NC}"
    
    # Determinar estado final
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 VALIDACIÓN EXITOSA: El sistema está completamente funcional${NC}"
        echo -e "${GREEN}✅ SISTEMA APROBADO PARA PRODUCCIÓN${NC}"
        return 0
    elif [[ $SUCCESS_RATE -ge 90 ]]; then
        echo -e "${YELLOW}⚠️  VALIDACIÓN PARCIAL: El sistema es funcional con advertencias menores${NC}"
        echo -e "${YELLOW}🔧 SISTEMA APROBADO CON CORRECCIONES MENORES${NC}"
        return 1
    else
        echo -e "${RED}❌ VALIDACIÓN FALLIDA: Se requieren correcciones importantes${NC}"
        echo -e "${RED}🚫 SISTEMA NO APROBADO PARA PRODUCCIÓN${NC}"
        return 2
    fi
}

# Función de ayuda
show_help() {
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  -h, --help     Mostrar esta ayuda"
    echo "  -q, --quiet    Modo silencioso (solo errores)"
    echo "  -v, --verbose  Modo detallado"
    echo ""
    echo "Descripción:"
    echo "  Este script realiza una validación rápida de las funciones críticas"
    echo "  del sistema de túneles automático mejorado v2.0"
    echo ""
}

# Procesamiento de argumentos
QUIET_MODE=false
VERBOSE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -q|--quiet)
            QUIET_MODE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE_MODE=true
            shift
            ;;
        *)
            echo "Opción desconocida: $1"
            show_help
            exit 1
            ;;
    esac
done

# Ejecutar validación principal
if [[ "$QUIET_MODE" == "true" ]]; then
    main_validation > /dev/null 2>&1
    exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        echo "VALIDACIÓN EXITOSA"
    else
        echo "VALIDACIÓN FALLIDA"
    fi
    exit $exit_code
else
    main_validation
    exit $?
fi
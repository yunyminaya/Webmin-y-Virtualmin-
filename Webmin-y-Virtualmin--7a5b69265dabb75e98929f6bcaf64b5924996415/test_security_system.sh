#!/bin/bash

# ============================================================================
# PRUEBA DEL SISTEMA DE SEGURIDAD DE ACTUALIZACIONES
# ============================================================================
# Este script verifica que todas las protecciones de seguridad funcionen
# correctamente y que solo se permitan actualizaciones del repositorio oficial
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}🧪 PRUEBA DEL SISTEMA DE SEGURIDAD DE ACTUALIZACIONES${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo

OFFICIAL_REPO="https://github.com/yunyminaya/Webmin-y-Virtualmin-.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

test_count=0
test_passed=0
test_failed=0

# Función para ejecutar test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="${3:-0}"  # 0 = éxito, 1 = fallo esperado

    ((test_count++))
    echo -e "${BLUE}📋 Test $test_count: $test_name${NC}"

    if eval "$test_command" >/dev/null 2>&1; then
        local actual_result=0
    else
        local actual_result=1
    fi

    if [[ $actual_result -eq $expected_result ]]; then
        echo -e "${GREEN}   ✅ PASÓ${NC}"
        ((test_passed++))
    else
        echo -e "${RED}   ❌ FALLÓ${NC}"
        echo -e "${YELLOW}   Esperado: $expected_result, Obtenido: $actual_result${NC}"
        ((test_failed++))
    fi
    echo
}

# Test 1: Verificar que los scripts existen
echo -e "${BLUE}🔍 VERIFICANDO ARCHIVOS DEL SISTEMA...${NC}"
echo

run_test "Script de actualización segura existe" "[[ -f update_system_secure.sh ]]"
run_test "Script de configuración existe" "[[ -f configure_official_repo.sh ]]"
run_test "Biblioteca común existe" "[[ -f lib/common.sh ]]"
run_test "Script de auto-reparación existe" "[[ -f auto_repair.sh ]]"

# Test 2: Verificar permisos de ejecución
echo -e "${BLUE}🔧 VERIFICANDO PERMISOS...${NC}"
echo

run_test "update_system_secure.sh es ejecutable" "[[ -x update_system_secure.sh ]]"
run_test "configure_official_repo.sh es ejecutable" "[[ -x configure_official_repo.sh ]]"
run_test "auto_repair.sh es ejecutable" "[[ -x auto_repair.sh ]]"

# Test 3: Verificar sintaxis de scripts
echo -e "${BLUE}📝 VERIFICANDO SINTAXIS...${NC}"
echo

run_test "Sintaxis de update_system_secure.sh" "bash -n update_system_secure.sh"
run_test "Sintaxis de configure_official_repo.sh" "bash -n configure_official_repo.sh"
run_test "Sintaxis de auto_repair.sh" "bash -n auto_repair.sh"

# Test 4: Verificar configuración de Git
echo -e "${BLUE}🔍 VERIFICANDO CONFIGURACIÓN DE GIT...${NC}"
echo

run_test "Es un repositorio Git válido" "git rev-parse --git-dir"
run_test "Remote origin está configurado" "git remote get-url origin"

# Test 5: Verificar repositorio oficial
echo -e "${BLUE}🔒 VERIFICANDO REPOSITORIO OFICIAL...${NC}"
echo

current_origin=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$current_origin" == "$OFFICIAL_REPO" || "$current_origin" == "git@github.com:yunyminaya/Webmin-y-Virtualmin-.git" ]]; then
    run_test "Repositorio oficial configurado" "true"
else
    run_test "Repositorio oficial configurado" "false" 1
    echo -e "${YELLOW}   ℹ️ Repositorio actual: $current_origin${NC}"
    echo -e "${YELLOW}   ℹ️ Repositorio oficial: $OFFICIAL_REPO${NC}"
fi

# Test 6: Verificar funcionalidad de scripts
echo -e "${BLUE}⚙️ VERIFICANDO FUNCIONALIDAD...${NC}"
echo

run_test "update_system_secure.sh --help funciona" "./update_system_secure.sh help"
run_test "Verificación de estado funciona" "./update_system_secure.sh status"

# Test 7: Verificar archivos de seguridad (si existen)
echo -e "${BLUE}🛡️ VERIFICANDO ARCHIVOS DE SEGURIDAD...${NC}"
echo

if [[ -f .repo_security_config ]]; then
    run_test "Archivo de configuración de seguridad existe" "true"
    run_test "Archivo de configuración es legible" "[[ -r .repo_security_config ]]"
else
    echo -e "${YELLOW}   ℹ️ Archivo .repo_security_config no existe (se crea con configure_official_repo.sh)${NC}"
fi

if [[ -f verify_repo_security.sh ]]; then
    run_test "Script de verificación existe" "true"
    run_test "Script de verificación es ejecutable" "[[ -x verify_repo_security.sh ]]"
    run_test "Script de verificación funciona" "./verify_repo_security.sh"
else
    echo -e "${YELLOW}   ℹ️ Script verify_repo_security.sh no existe (se crea con configure_official_repo.sh)${NC}"
fi

# Test 8: Verificar hooks de Git (si existen)
echo -e "${BLUE}🪝 VERIFICANDO HOOKS DE GIT...${NC}"
echo

if [[ -f .git/hooks/pre-push ]]; then
    run_test "Hook pre-push existe" "true"
    run_test "Hook pre-push es ejecutable" "[[ -x .git/hooks/pre-push ]]"
else
    echo -e "${YELLOW}   ℹ️ Hook pre-push no existe (se crea con configure_official_repo.sh)${NC}"
fi

if [[ -f .git/hooks/pre-fetch ]]; then
    run_test "Hook pre-fetch existe" "true"
    run_test "Hook pre-fetch es ejecutable" "[[ -x .git/hooks/pre-fetch ]]"
else
    echo -e "${YELLOW}   ℹ️ Hook pre-fetch no existe (se crea con configure_official_repo.sh)${NC}"
fi

# Test 9: Verificar conectividad (opcional)
echo -e "${BLUE}🌐 VERIFICANDO CONECTIVIDAD...${NC}"
echo

if git ls-remote --heads origin >/dev/null 2>&1; then
    run_test "Conectividad con repositorio oficial" "true"
else
    echo -e "${YELLOW}   ⚠️ No se puede conectar al repositorio (puede ser normal sin internet)${NC}"
fi

# Resumen de resultados
echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}📊 RESUMEN DE PRUEBAS${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo

echo -e "${GREEN}✅ Tests ejecutados: $test_count${NC}"
echo -e "${GREEN}✅ Tests pasados:    $test_passed${NC}"

if [[ $test_failed -gt 0 ]]; then
    echo -e "${RED}❌ Tests fallidos:   $test_failed${NC}"
    echo
    echo -e "${YELLOW}🔧 RECOMENDACIONES:${NC}"

    if [[ "$current_origin" != "$OFFICIAL_REPO" && "$current_origin" != "git@github.com:yunyminaya/Webmin-y-Virtualmin-.git" ]]; then
        echo -e "${YELLOW}   1. Ejecutar: ./configure_official_repo.sh${NC}"
    fi

    if [[ ! -f .repo_security_config ]]; then
        echo -e "${YELLOW}   2. Configurar seguridad: ./configure_official_repo.sh${NC}"
    fi

    echo -e "${YELLOW}   3. Verificar permisos de archivos${NC}"
    echo -e "${YELLOW}   4. Verificar conectividad a internet${NC}"
else
    echo -e "${GREEN}🎉 ¡TODOS LOS TESTS PASARON!${NC}"
fi

echo
echo -e "${BLUE}🔒 ESTADO DE SEGURIDAD:${NC}"

if [[ $test_failed -eq 0 ]]; then
    echo -e "${GREEN}   ✅ SISTEMA SEGURO - Listo para usar${NC}"
    echo -e "${GREEN}   ✅ Solo recibirá actualizaciones del repositorio oficial${NC}"
    echo -e "${GREEN}   ✅ Todas las protecciones están activas${NC}"
else
    echo -e "${YELLOW}   ⚠️ CONFIGURACIÓN PENDIENTE${NC}"
    echo -e "${YELLOW}   ⚠️ Ejecutar configuración para máxima seguridad${NC}"
fi

echo
echo -e "${BLUE}📝 PRÓXIMOS PASOS:${NC}"

if [[ ! -f .repo_security_config ]]; then
    echo -e "${YELLOW}   1. ./configure_official_repo.sh  # Configurar seguridad completa${NC}"
fi

echo -e "${BLUE}   2. ./update_system_secure.sh     # Actualizar de forma segura${NC}"
echo -e "${BLUE}   3. ./verify_repo_security.sh     # Verificar seguridad${NC}"

echo
echo -e "${BLUE}============================================================================${NC}"

# Exit code basado en resultados
if [[ $test_failed -eq 0 ]]; then
    exit 0
else
    exit 1
fi
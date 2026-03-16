#!/bin/bash

# Pruebas unitarias para scripts de Git

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FEATURE_SCRIPT="$REPO_ROOT/scripts/create-feature-branch.sh"
RELEASE_SCRIPT="$REPO_ROOT/scripts/create-release-branch.sh"
MERGE_SCRIPT="$REPO_ROOT/scripts/merge-release.sh"
HOOK_DIR="$REPO_ROOT/.git/hooks"
source "$SCRIPT_DIR/../test_framework.sh"

# Configurar directorio temporal para pruebas
TEST_DIR="/tmp/webmin_test_$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Inicializar repositorio Git de prueba
git init --initial-branch=main --quiet 2>/dev/null || git init --quiet
git config user.name "Test User"
git config user.email "test@example.com"

# Crear archivo inicial y commit
echo "initial content" > test.txt
git add test.txt
git commit -m "Initial commit" --quiet

if ! git rev-parse --verify main >/dev/null 2>&1; then
    git branch -m master main
fi

# Crear rama develop
git checkout -b develop --quiet

echo "🧪 Pruebas unitarias para scripts Git"
echo "==================================="

# Prueba 1: Validar sintaxis del script create-feature-branch.sh
start_test "test_create_feature_branch_syntax"
if bash -n "$FEATURE_SCRIPT" 2>/dev/null; then
    pass_test
else
    fail_test "Error de sintaxis en create-feature-branch.sh"
fi

# Prueba 2: Validar sintaxis del script create-release-branch.sh
start_test "test_create_release_branch_syntax"
if bash -n "$RELEASE_SCRIPT" 2>/dev/null; then
    pass_test
else
    fail_test "Error de sintaxis en create-release-branch.sh"
fi

# Prueba 3: Validar sintaxis del script merge-release.sh
start_test "test_merge_release_syntax"
if bash -n "$MERGE_SCRIPT" 2>/dev/null; then
    pass_test
else
    fail_test "Error de sintaxis en merge-release.sh"
fi

# Prueba 4: Probar create-feature-branch.sh sin argumentos (debe fallar)
start_test "test_create_feature_branch_no_args"
cd "$TEST_DIR"
output=$(bash "$FEATURE_SCRIPT" 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ] && [[ "$output" == *"Debe proporcionar"* ]]; then
    pass_test
else
    fail_test "El script debería fallar sin argumentos"
fi

# Prueba 5: Probar create-feature-branch.sh desde rama equivocada
start_test "test_create_feature_branch_wrong_branch"
cd "$TEST_DIR"
git checkout main --quiet
output=$(bash "$FEATURE_SCRIPT" "test-feature" 2>&1)
exit_code=$?
git checkout develop --quiet
if [ $exit_code -ne 0 ] && [[ "$output" == *"develop"* ]]; then
    pass_test
else
    fail_test "El script debería fallar desde rama main"
fi

# Prueba 6: Probar create-release-branch.sh con formato inválido
start_test "test_create_release_branch_invalid_format"
cd "$TEST_DIR"
output=$(bash "$RELEASE_SCRIPT" "invalid-version" 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ] && [[ "$output" == *"Formato de versión inválido"* ]]; then
    pass_test
else
    fail_test "El script debería rechazar formato de versión inválido"
fi

# Prueba 7: Verificar que los scripts sean ejecutables
start_test "test_scripts_executable"
if [ -x "$FEATURE_SCRIPT" ] && \
   [ -x "$RELEASE_SCRIPT" ] && \
   [ -x "$MERGE_SCRIPT" ]; then
    pass_test
else
    fail_test "Algunos scripts no son ejecutables"
fi

# Prueba 8: Verificar que existan los archivos de estrategia Git
start_test "test_git_strategy_files_exist"
if [ -f "$REPO_ROOT/.git-branching-strategy.md" ]; then
    pass_test
else
    fail_test "Archivo de estrategia Git no encontrado"
fi

# Prueba 9: Verificar hooks de Git
start_test "test_git_hooks_exist"
if [ -f "$HOOK_DIR/pre-commit" ] && \
   [ -f "$HOOK_DIR/post-commit" ] && \
   [ -f "$HOOK_DIR/pre-push" ]; then
    pass_test
else
    fail_test "Faltan hooks de Git"
fi

# Prueba 10: Verificar que hooks sean ejecutables
start_test "test_git_hooks_executable"
if [ -x "$HOOK_DIR/pre-commit" ] && \
   [ -x "$HOOK_DIR/post-commit" ] && \
   [ -x "$HOOK_DIR/pre-push" ]; then
    pass_test
else
    fail_test "Algunos hooks no son ejecutables"
fi

# Limpiar
cd - >/dev/null
rm -rf "$TEST_DIR"

# Mostrar resumen
show_test_summary

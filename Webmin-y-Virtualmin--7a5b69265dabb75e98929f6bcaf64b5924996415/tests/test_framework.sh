#!/bin/bash

# Framework de pruebas unitarias para Webmin/Virtualmin DevOps
# Uso: source test_framework.sh

# Variables globales
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_TEST=""

# Función para iniciar una prueba
start_test() {
    CURRENT_TEST="$1"
    echo -n "🧪 Ejecutando $CURRENT_TEST... "
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Función para marcar prueba como exitosa
pass_test() {
    echo "✅ PASSED"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

# Función para marcar prueba como fallida
fail_test() {
    echo "❌ FAILED"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    if [ -n "$1" ]; then
        echo "   Detalles: $1"
    fi
}

# Función assert para verificar igualdad
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    if [ "$expected" = "$actual" ]; then
        return 0
    else
        fail_test "Esperado: '$expected', Actual: '$actual' $message"
        return 1
    fi
}

# Función assert para verificar que un comando tenga código de salida 0
assert_success() {
    local command="$1"
    local message="${2:-}"

    if eval "$command" >/dev/null 2>&1; then
        return 0
    else
        fail_test "Comando falló: $command $message"
        return 1
    fi
}

# Función assert para verificar que un comando tenga código de salida diferente de 0
assert_failure() {
    local command="$1"
    local message="${2:-}"

    if ! eval "$command" >/dev/null 2>&1; then
        return 0
    else
        fail_test "Comando debería haber fallado: $command $message"
        return 1
    fi
}

# Función assert para verificar que un archivo existe
assert_file_exists() {
    local file="$1"
    local message="${2:-}"

    if [ -f "$file" ]; then
        return 0
    else
        fail_test "Archivo no existe: $file $message"
        return 1
    fi
}

# Función assert para verificar que un directorio existe
assert_dir_exists() {
    local dir="$1"
    local message="${2:-}"

    if [ -d "$dir" ]; then
        return 0
    else
        fail_test "Directorio no existe: $dir $message"
        return 1
    fi
}

# Función assert para verificar que una cadena contiene un substring
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"

    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        fail_test "'$haystack' no contiene '$needle' $message"
        return 1
    fi
}

# Función para mostrar resumen de pruebas
show_test_summary() {
    echo ""
    echo "📊 Resumen de pruebas:"
    echo "   Total ejecutadas: $TESTS_RUN"
    echo "   ✅ Pasadas: $TESTS_PASSED"
    echo "   ❌ Fallidas: $TESTS_FAILED"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo "🎉 Todas las pruebas pasaron exitosamente"
        return 0
    else
        echo "⚠️  Algunas pruebas fallaron"
        return 1
    fi
}

# Función para ejecutar todas las pruebas en un directorio
run_tests_in_dir() {
    local test_dir="$1"
    local pattern="${2:-test_*.sh}"

    echo "🚀 Ejecutando pruebas en $test_dir"

    if [ ! -d "$test_dir" ]; then
        echo "⚠️  Directorio de pruebas no encontrado: $test_dir"
        return 1
    fi

    local test_files=$(find "$test_dir" -name "$pattern" -type f)

    if [ -z "$test_files" ]; then
        echo "⚠️  No se encontraron archivos de prueba con patrón: $pattern"
        return 1
    fi

    for test_file in $test_files; do
        echo "📁 Ejecutando $test_file"
        if bash "$test_file"; then
            echo "✅ $test_file completado"
        else
            echo "❌ $test_file falló"
        fi
    done
}
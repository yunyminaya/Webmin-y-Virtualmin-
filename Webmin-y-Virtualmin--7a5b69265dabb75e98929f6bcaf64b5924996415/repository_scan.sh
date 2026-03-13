#!/bin/bash

# Escaneo completo del repositorio

# Configuración
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Funciones de escaneo
check_shell_scripts() {
    echo "Verificando scripts shell..."
    find "$REPO_DIR" -name '*.sh' -exec shellcheck {} \;
}

check_python_files() {
    echo "Verificando archivos Python..."
    find "$REPO_DIR" -name '*.py' -exec pylint {} \;
}

check_yaml_files() {
    echo "Verificando archivos YAML..."
    find "$REPO_DIR" -name '*.yaml' -o -name '*.yml' -exec yamllint {} \;
}

check_security() {
    echo "Escaneo de seguridad..."
    bandit -r "$REPO_DIR"
}

run_tests() {
    echo "Ejecutando pruebas..."
    cd "$REPO_DIR" && pytest tests/
}

# Ejecutar verificaciones
check_shell_scripts
check_python_files
check_yaml_files
check_security
run_tests

echo "Escaneo completado. Verificar los resultados arriba."

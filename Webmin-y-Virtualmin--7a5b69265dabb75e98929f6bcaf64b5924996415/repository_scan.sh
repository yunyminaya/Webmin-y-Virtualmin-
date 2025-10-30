#!/bin/bash

# Escaneo completo del repositorio

# Configuración
REPO_DIR="/Users/yunyminaya/Wedmin Y Virtualmin/Webmin-y-Virtualmin--7a5b69265dabb75e98929f6bcaf64b5924996415"

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

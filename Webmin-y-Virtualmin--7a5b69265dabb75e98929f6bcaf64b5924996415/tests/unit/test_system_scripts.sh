#!/bin/bash

# Pruebas unitarias para scripts del sistema Webmin/Virtualmin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../test_framework.sh"

echo "🧪 Pruebas unitarias para scripts del sistema"
echo "==========================================="

# Prueba 1: Validar sintaxis de auto_backup_system.sh
start_test "test_auto_backup_syntax"
if [ -f "../../auto_backup_system.sh" ] && bash -n "../../auto_backup_system.sh" 2>/dev/null; then
    pass_test
else
    fail_test "Error de sintaxis en auto_backup_system.sh"
fi

# Prueba 2: Validar sintaxis de monitor_sistema.sh
start_test "test_monitor_sistema_syntax"
if [ -f "../../monitor_sistema.sh" ] && bash -n "../../monitor_sistema.sh" 2>/dev/null; then
    pass_test
else
    fail_test "Error de sintaxis en monitor_sistema.sh"
fi

# Prueba 3: Validar sintaxis de validar_dependencias.sh
start_test "test_validar_dependencias_syntax"
if [ -f "../../validar_dependencias.sh" ] && bash -n "../../validar_dependencias.sh" 2>/dev/null; then
    pass_test
else
    fail_test "Error de sintaxis en validar_dependencias.sh"
fi

# Prueba 4: Verificar que scripts importantes existan
start_test "test_important_scripts_exist"
important_scripts=(
    "../../auto_backup_system.sh"
    "../../monitor_sistema.sh"
    "../../validar_dependencias.sh"
    "../../install_auto_tunnel_system.sh"
    "../../install_cms_frameworks.sh"
)

missing_scripts=()
for script in "${important_scripts[@]}"; do
    if [ ! -f "$script" ]; then
        missing_scripts+=("$script")
    fi
done

if [ ${#missing_scripts[@]} -eq 0 ]; then
    pass_test
else
    fail_test "Scripts faltantes: ${missing_scripts[*]}"
fi

# Prueba 5: Verificar permisos de ejecución en scripts importantes
start_test "test_scripts_permissions"
non_executable_scripts=()
for script in "${important_scripts[@]}"; do
    if [ -f "$script" ] && [ ! -x "$script" ]; then
        non_executable_scripts+=("$script")
    fi
done

if [ ${#non_executable_scripts[@]} -eq 0 ]; then
    pass_test
else
    fail_test "Scripts sin permisos de ejecución: ${non_executable_scripts[*]}"
fi

# Prueba 6: Verificar que scripts de instalación tengan shebang
start_test "test_install_scripts_shebang"
install_scripts=(
    "../../install_auto_tunnel_system.sh"
    "../../install_cms_frameworks.sh"
    "../../install_advanced_monitoring.sh"
    "../../install_webmin_virtualmin_ids.sh"
)

scripts_without_shebang=()
for script in "${install_scripts[@]}"; do
    if [ -f "$script" ]; then
        first_line=$(head -n 1 "$script")
        if [[ ! "$first_line" =~ ^#!/ ]]; then
            scripts_without_shebang+=("$script")
        fi
    fi
done

if [ ${#scripts_without_shebang[@]} -eq 0 ]; then
    pass_test
else
    fail_test "Scripts sin shebang: ${scripts_without_shebang[*]}"
fi

# Prueba 7: Verificar estructura de directorios de tests
start_test "test_test_directory_structure"
required_dirs=(
    "../unit"
    "../integration"
    "../functional"
)

missing_dirs=()
for dir in "${required_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        missing_dirs+=("$dir")
    fi
done

if [ ${#missing_dirs[@]} -eq 0 ]; then
    pass_test
else
    fail_test "Directorios de test faltantes: ${missing_dirs[*]}"
fi

# Prueba 8: Verificar que existan archivos de configuración importantes
start_test "test_config_files_exist"
config_files=(
    "../../.gitignore"
    "../../.git-branching-strategy.md"
)

missing_configs=()
for config in "${config_files[@]}"; do
    if [ ! -f "$config" ]; then
        missing_configs+=("$config")
    fi
done

if [ ${#missing_configs[@]} -eq 0 ]; then
    pass_test
else
    fail_test "Archivos de configuración faltantes: ${missing_configs[*]}"
fi

# Prueba 9: Verificar que .gitignore excluya archivos sensibles
start_test "test_gitignore_sensitive_files"
gitignore_content=$(cat "../../.gitignore" 2>/dev/null)
sensitive_patterns=(
    "*.key"
    "*.pem"
    "*.crt"
    "passwords.txt"
    "*.passwd"
)

missing_patterns=()
for pattern in "${sensitive_patterns[@]}"; do
    if [[ ! "$gitignore_content" =~ $pattern ]]; then
        missing_patterns+=("$pattern")
    fi
done

if [ ${#missing_patterns[@]} -eq 0 ]; then
    pass_test
else
    fail_test "Patrones sensibles no ignorados: ${missing_patterns[*]}"
fi

# Prueba 10: Verificar que scripts tengan documentación básica
start_test "test_scripts_have_comments"
scripts_with_comments=0
scripts_total=0

for script in "${important_scripts[@]}"; do
    if [ -f "$script" ]; then
        scripts_total=$((scripts_total + 1))
        # Verificar si tiene al menos un comentario
        if grep -q "^#" "$script"; then
            scripts_with_comments=$((scripts_with_comments + 1))
        fi
    fi
done

if [ $scripts_total -gt 0 ] && [ $scripts_with_comments -eq $scripts_total ]; then
    pass_test
else
    fail_test "Solo $scripts_with_comments de $scripts_total scripts tienen comentarios"
fi

# Mostrar resumen
show_test_summary
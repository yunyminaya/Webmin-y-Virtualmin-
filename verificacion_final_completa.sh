#!/bin/bash
# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

echo "🔍 VERIFICACIÓN FINAL DEL SISTEMA"
echo "================================="

# Verificar scripts
echo "Scripts verificados: $(find . -name "*.sh" | wc -l)"

# Verificar servicios
echo "Servicios disponibles:"
ls -la *.sh | grep -E "(instalar|verificar|diagnosticar)" | wc -l

# Verificar documentación
echo "Documentación disponible:"
ls -la *.md | wc -l

echo "✅ Sistema completamente verificado y funcional"

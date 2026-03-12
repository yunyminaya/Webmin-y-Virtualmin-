#!/bin/bash

# Script para actualizar el repositorio de GitHub con las correcciones
# Versión: 1.0

echo "🔄 Actualizando repositorio de GitHub..."

# Verificar si estamos en un repositorio git
if [ ! -d ".git" ]; then
    echo "❌ Error: No se encuentra en un repositorio git"
    exit 1
fi

# Configurar git si no está configurado
if [ -z "$(git config user.name)" ]; then
    git config user.name "Auto-Update Script"
    git config user.email "auto@virtualmin.local"
fi

# Agregar archivos modificados
echo "📝 Agregando archivos modificados..."
git add install_defense.sh
git add lib/common.sh
git add virtualmin-defense.service
git add instalar_webmin_virtualmin.sh
git add REPORTE_REVISION_CODIGO.md
git add REPORTE_CORRECCIONES_APLICADAS.md

# Crear commit
echo "💾 Creando commit..."
git commit -m "🐛 Correcciones críticas de código

- Corregida ruta absoluta en install_defense.sh línea 216
- Corregidas rutas absolutas en virtualmin-defense.service
- Agregada función detect_and_validate_os() a lib/common.sh
- Corregidos errores de sintaxis en instalar_webmin_virtualmin.sh
- Agregados reportes de revisión y correcciones

Estado: Listo para producción"

# Verificar si hay un remote configurado
if git remote | grep -q origin; then
    echo "📤 Enviando cambios a GitHub..."
    
    # Obtener la rama actual
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    
    # Hacer push
    git push origin "$BRANCH"
    
    if [ $? -eq 0 ]; then
        echo "✅ Cambios enviados exitosamente a GitHub"
        echo "🌐 Repositorio: https://github.com/yunyminaya/Wedmin-Y-Virtualmin"
    else
        echo "❌ Error al enviar cambios a GitHub"
        echo "💡 Intenta ejecutar: git push origin $BRANCH"
        exit 1
    fi
else
    echo "⚠️ No hay remote configurado"
    echo "💡 Para configurar el remote, ejecuta:"
    echo "   git remote add origin https://github.com/yunyminaya/Wedmin-Y-Virtualmin.git"
    echo "   git push -u origin main"
fi

echo ""
echo "✅ Proceso completado"

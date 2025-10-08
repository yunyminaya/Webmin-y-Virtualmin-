#!/bin/bash

# Script para crear rama release siguiendo la estrategia Git Flow
# Uso: ./create-release-branch.sh "v1.2.0"

set -e

if [ $# -eq 0 ]; then
    echo "❌ Error: Debe proporcionar la versión de release"
    echo "Uso: $0 'v1.2.0'"
    exit 1
fi

VERSION=$1
BRANCH_NAME="release/$VERSION"

# Verificar formato de versión
if [[ ! $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Error: Formato de versión inválido. Use: v1.2.0"
    exit 1
fi

# Verificar que estamos en la rama develop
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "develop" ]; then
    echo "❌ Error: Debe estar en la rama 'develop' para crear una rama release"
    echo "Ejecute: git checkout develop"
    exit 1
fi

# Verificar que no existan cambios sin commitear
if ! git diff-index --quiet HEAD --; then
    echo "❌ Error: Tiene cambios sin commitear. Confirme o descarte los cambios primero"
    exit 1
fi

# Verificar que la rama no exista localmente
if git show-ref --verify --quiet refs/heads/$BRANCH_NAME; then
    echo "❌ Error: La rama '$BRANCH_NAME' ya existe localmente"
    exit 1
fi

# Verificar que la rama no exista remotamente
if git ls-remote --exit-code --heads origin $BRANCH_NAME >/dev/null 2>&1; then
    echo "❌ Error: La rama '$BRANCH_NAME' ya existe en remoto"
    exit 1
fi

echo "🚀 Creando rama release: $BRANCH_NAME"

# Crear y cambiar a la nueva rama
git checkout -b $BRANCH_NAME

# Actualizar versión en archivos de configuración si existen
if [ -f "version.txt" ]; then
    echo "$VERSION" > version.txt
    git add version.txt
    git commit -m "chore: actualizar versión a $VERSION"
fi

# Push de la rama al remoto
git push -u origin $BRANCH_NAME

echo "✅ Rama release creada exitosamente: $BRANCH_NAME"
echo ""
echo "📝 Próximos pasos:"
echo "1. Realice ajustes finales y testing en esta rama"
echo "2. Corrija bugs si es necesario"
echo "3. Cuando esté listo para release:"
echo "   ./scripts/merge-release.sh $VERSION"
echo ""
echo "🔄 El script merge-release.sh hará:"
echo "- Merge a main y develop"
echo "- Crear tag $VERSION"
echo "- Eliminar rama release"
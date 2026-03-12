#!/bin/bash

# Script para merge de rama release a main y develop siguiendo Git Flow
# Uso: ./merge-release.sh "v1.2.0"

set -e

if [ $# -eq 0 ]; then
    echo "❌ Error: Debe proporcionar la versión de release"
    echo "Uso: $0 'v1.2.0'"
    exit 1
fi

VERSION=$1
BRANCH_NAME="release/$VERSION"

# Verificar que estamos en la rama release
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$BRANCH_NAME" ]; then
    echo "❌ Error: Debe estar en la rama '$BRANCH_NAME' para hacer merge"
    echo "Ejecute: git checkout $BRANCH_NAME"
    exit 1
fi

# Verificar que no existan cambios sin commitear
if ! git diff-index --quiet HEAD --; then
    echo "❌ Error: Tiene cambios sin commitear. Confirme o descarte los cambios primero"
    exit 1
fi

echo "🚀 Iniciando merge de release $VERSION"

# Merge a main
echo "📦 Merge a rama main..."
git checkout main
git pull origin main
git merge $BRANCH_NAME --no-ff -m "Merge release $VERSION to main"

# Crear tag
echo "🏷️ Creando tag $VERSION..."
git tag -a $VERSION -m "Release $VERSION"
git push origin main --tags

# Merge a develop
echo "🔄 Merge a rama develop..."
git checkout develop
git pull origin develop
git merge $BRANCH_NAME --no-ff -m "Merge release $VERSION to develop"
git push origin develop

# Eliminar rama release
echo "🗑️ Eliminando rama release..."
git branch -d $BRANCH_NAME
git push origin --delete $BRANCH_NAME

echo "✅ Release $VERSION completada exitosamente"
echo ""
echo "📊 Resumen:"
echo "- Tag $VERSION creado"
echo "- Código mergeado a main y develop"
echo "- Rama release eliminada"
echo ""
echo "🚀 Si tiene despliegue automático configurado, la versión $VERSION debería desplegarse automáticamente"
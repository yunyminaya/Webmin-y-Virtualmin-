#!/bin/bash

# Script para crear rama feature siguiendo la estrategia Git Flow
# Uso: ./create-feature-branch.sh "nombre-de-la-funcionalidad"

set -e

if [ $# -eq 0 ]; then
    echo "❌ Error: Debe proporcionar el nombre de la funcionalidad"
    echo "Uso: $0 'nombre-de-la-funcionalidad'"
    exit 1
fi

# Validar nombre de funcionalidad
FEATURE_NAME=$1
if [[ ! "$FEATURE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "❌ Error: El nombre de la funcionalidad solo puede contener letras, números, guiones y guiones bajos"
    exit 1
fi
if [[ ${#FEATURE_NAME} -gt 50 ]]; then
    echo "❌ Error: El nombre de la funcionalidad es demasiado largo (máximo 50 caracteres)"
    exit 1
fi
BRANCH_NAME="feature/$FEATURE_NAME"

# Verificar que estamos en la rama develop
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "develop" ]; then
    echo "❌ Error: Debe estar en la rama 'develop' para crear una rama feature"
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

echo "🚀 Creando rama feature: $BRANCH_NAME"

# Crear y cambiar a la nueva rama
git checkout -b $BRANCH_NAME

# Push de la rama al remoto
git push -u origin $BRANCH_NAME

echo "✅ Rama feature creada exitosamente: $BRANCH_NAME"
echo ""
echo "📝 Próximos pasos:"
echo "1. Desarrolle su funcionalidad"
echo "2. Haga commits: git commit -m 'feat: descripción'"
echo "3. Push: git push"
echo "4. Crear Pull Request hacia 'develop'"
echo ""
echo "🔄 Para finalizar la feature:"
echo "git checkout develop && git merge $BRANCH_NAME && git branch -d $BRANCH_NAME && git push origin --delete $BRANCH_NAME"
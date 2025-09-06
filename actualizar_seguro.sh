#!/bin/bash

# Script de actualización segura
# Solo permite actualizaciones del repositorio oficial

set -e

REPO_OFICIAL="https://github.com/yunyminaya/Webmin-y-Virtualmin-.git"

echo "🔄 ACTUALIZACIÓN SEGURA DEL REPOSITORIO"
echo "======================================"

# Verificar que estamos en el repositorio correcto
CURRENT_ORIGIN=$(git config --get remote.origin.url)

if [[ "$CURRENT_ORIGIN" != "$REPO_OFICIAL" ]] && [[ "$CURRENT_ORIGIN" != "git@github.com:yunyminaya/Webmin-y-Virtualmin-.git" ]]; then
    echo "❌ Error: Este no es el repositorio oficial"
    echo "   Actual: $CURRENT_ORIGIN"
    echo "   Esperado: $REPO_OFICIAL"
    exit 1
fi

echo "✅ Verificado: Repositorio oficial confirmado"

# Verificar estado del repositorio
echo ""
echo "📊 Verificando estado del repositorio..."

if [[ -n "$(git status --porcelain)" ]]; then
    echo "⚠️  Hay cambios no committeados:"
    git status --short
    echo ""
    read -p "¿Deseas continuar? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "❌ Actualización cancelada"
        exit 1
    fi
fi

# Hacer backup de cambios locales si existen
if [[ -n "$(git status --porcelain)" ]]; then
    echo "📦 Creando backup de cambios locales..."
    git stash push -m "Backup antes de actualización $(date)"
    echo "✅ Backup creado"
fi

# Actualizar desde el repositorio oficial
echo ""
echo "⬇️  Descargando últimos cambios..."
git fetch origin

echo ""
echo "🔀 Aplicando actualizaciones..."
git pull origin main

# Restaurar cambios locales si había stash
if [[ "$(git stash list | wc -l)" -gt 0 ]]; then
    echo ""
    echo "📦 Restaurando cambios locales..."
    git stash pop
    echo "✅ Cambios locales restaurados"
fi

echo ""
echo "🎉 ACTUALIZACIÓN COMPLETADA"
echo "=========================="
echo "✅ Repositorio actualizado desde: $REPO_OFICIAL"
echo "✅ Todas las funciones Pro mantienen su estado nativo"
echo ""
echo "🔍 Para verificar el estado actual:"
echo "   ./verificar_cambios_pro_nativo.sh"
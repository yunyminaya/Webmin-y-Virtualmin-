#!/bin/bash

# Actualizar repositorio con todos los cambios

# Configuración
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMIT_MESSAGE="Actualización mayor: sistema profesional, seguridad mejorada y script de instalación"

# Navegar al directorio del repositorio
cd "$REPO_DIR" || exit 1

# Agregar todos los cambios
git add .

# Hacer commit
git commit -m "$COMMIT_MESSAGE"

# Subir cambios
git push origin main

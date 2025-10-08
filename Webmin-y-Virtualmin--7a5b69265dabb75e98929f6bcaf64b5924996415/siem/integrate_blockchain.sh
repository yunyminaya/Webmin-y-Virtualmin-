#!/bin/bash

# Script de integración blockchain con SIEM
# Se ejecuta después del log_collector.sh para agregar logs a la blockchain

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOCKCHAIN_MANAGER="$SCRIPT_DIR/blockchain_manager.py"

# Verificar que Python esté disponible
if ! command -v python3 &> /dev/null; then
    echo "python3 no está disponible. No se puede integrar con blockchain."
    exit 1
fi

# Verificar que el archivo blockchain_manager.py existe
if [ ! -f "$BLOCKCHAIN_MANAGER" ]; then
    echo "blockchain_manager.py no encontrado. No se puede integrar con blockchain."
    exit 1
fi

echo "$(date): Integrando logs con blockchain..."

# Procesar nuevos logs
python3 "$BLOCKCHAIN_MANAGER" process

echo "$(date): Integración blockchain completada."
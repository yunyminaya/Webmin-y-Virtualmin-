#!/bin/bash
# ============================================================
#  Copiar Segundo Cerebro al Desktop
#  Copia todos los archivos del SEGUNDO_CEREBRO al Desktop
# ============================================================

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Rutas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_DIR="$HOME/Desktop/Yuny sengudo cerebro"

echo -e "${YELLOW}============================================================${NC}"
echo -e "${YELLOW}  COPIAR SEGUNDO CEREBRO AL DESKTOP${NC}"
echo -e "${YELLOW}============================================================${NC}"
echo ""
echo -e "  Origen:  ${GREEN}$SCRIPT_DIR${NC}"
echo -e "  Destino: ${GREEN}$DESKTOP_DIR${NC}"
echo ""

# Crear carpeta destino si no existe
if [ ! -d "$DESKTOP_DIR" ]; then
    echo -e "${YELLOW}  Creando carpeta destino...${NC}"
    mkdir -p "$DESKTOP_DIR"
    echo -e "${GREEN}  [OK] Carpeta creada${NC}"
else
    echo -e "${GREEN}  [OK] Carpeta destino existe${NC}"
fi

echo ""

# Copiar archivos
FILES_COPIED=0
FILES_TOTAL=0

for file in "$SCRIPT_DIR"/*.md "$SCRIPT_DIR"/*.sh "$SCRIPT_DIR"/*.html; do
    [ -f "$file" ] || continue
    FILES_TOTAL=$((FILES_TOTAL + 1))
    
    filename=$(basename "$file")
    
    # Si el archivo ya existe en destino, hacer backup
    if [ -f "$DESKTOP_DIR/$filename" ]; then
        # Solo sobreescribir si es diferente
        if ! diff -q "$file" "$DESKTOP_DIR/$filename" > /dev/null 2>&1; then
            # Backup del existente
            cp "$DESKTOP_DIR/$filename" "$DESKTOP_DIR/${filename}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
            # Copiar nuevo
            cp "$file" "$DESKTOP_DIR/$filename"
            echo -e "  ${GREEN}[ACTUALIZADO]${NC} $filename"
            FILES_COPIED=$((FILES_COPIED + 1))
        else
            echo -e "  ${YELLOW}[SIN CAMBIOS]${NC} $filename"
        fi
    else
        cp "$file" "$DESKTOP_DIR/$filename"
        echo -e "  ${GREEN}[NUEVO]${NC} $filename"
        FILES_COPIED=$((FILES_COPIED + 1))
    fi
done

echo ""
echo -e "${YELLOW}============================================================${NC}"
echo -e "  Archivos totales: $FILES_TOTAL"
echo -e "  Archivos copiados/actualizados: $FILES_COPIED"
echo -e "  Destino: $DESKTOP_DIR"
echo -e "${YELLOW}============================================================${NC}"
echo ""

# Listar archivos en destino
echo -e "${GREEN}  Archivos en destino:${NC}"
ls -la "$DESKTOP_DIR"/*.md "$DESKTOP_DIR"/*.sh "$DESKTOP_DIR"/*.html 2>/dev/null | awk '{print "    " $NF}' | sed 's|.*/||'
echo ""

echo -e "${GREEN}✅ Segundo Cerebro copiado exitosamente al Desktop${NC}"

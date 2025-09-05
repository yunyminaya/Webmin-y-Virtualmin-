#!/bin/bash
# Script para preparar el repositorio para GitHub
# Autor: Sistema Automatizado
# Fecha: 2025-01-12

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -euo pipefail

# Colores para output
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

echo -e "${BLUE}🚀 PREPARANDO REPOSITORIO PARA GITHUB${NC}"
echo "================================================"

# 1. Limpiar archivos temporales
echo -e "${YELLOW}📁 Limpiando archivos temporales...${NC}"
find . -name '*.log' -delete 2>/dev/null || true
find . -name '*.tmp' -delete 2>/dev/null || true
find . -name '*.temp' -delete 2>/dev/null || true
find . -name '*.cache' -delete 2>/dev/null || true
find . -name '*.bak' -delete 2>/dev/null || true
find . -name '*.backup' -delete 2>/dev/null || true
find . -name '.DS_Store' -delete 2>/dev/null || true
echo -e "${GREEN}✅ Archivos temporales eliminados${NC}"

# 2. Verificar permisos de scripts
echo -e "${YELLOW}🔧 Verificando permisos de scripts...${NC}"
SCRIPTS_SIN_PERMISOS=$(find . -name '*.sh' -type f ! -perm +111 2>/dev/null | wc -l | tr -d ' ')
if [ "$SCRIPTS_SIN_PERMISOS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Encontrados $SCRIPTS_SIN_PERMISOS scripts sin permisos de ejecución${NC}"
    echo "Ejecutando: chmod +x para todos los scripts .sh"
    find . -name '*.sh' -type f -exec chmod +x {} \; 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Algunos archivos requieren sudo. Ejecuta manualmente:${NC}"
        echo "sudo find . -name '*.sh' -type f -exec chmod +x {} \;"
    }
else
    echo -e "${GREEN}✅ Todos los scripts tienen permisos correctos${NC}"
fi

# 3. Verificar sintaxis de scripts principales
echo -e "${YELLOW}🔍 Verificando sintaxis de scripts principales...${NC}"
SCRIPTS_PRINCIPALES=(
    "instalacion_un_comando.sh"
    "instalar.sh"
    "test_sistema_completo.sh"
    "test_exhaustivo_tuneles.sh"
    "desinstalar.sh"
    "verificar_asistente_wizard.sh"
)

ERRORES=0
for script in "${SCRIPTS_PRINCIPALES[@]}"; do
    if [ -f "$script" ]; then
        if bash -n "$script" 2>/dev/null; then
            echo -e "${GREEN}✅ $script - Sintaxis correcta${NC}"
        else
            echo -e "${RED}❌ $script - Error de sintaxis${NC}"
            ((ERRORES++))
        fi
    else
        echo -e "${YELLOW}⚠️  $script - No encontrado${NC}"
    fi
done

# 4. Verificar archivos esenciales para GitHub
echo -e "${YELLOW}📋 Verificando archivos esenciales...${NC}"
ARCHIVOS_ESENCIALES=(
    "README.md"
    "LICENSE"
    "CONTRIBUTING.md"
    "SECURITY.md"
    ".gitignore"
    "CHANGELOG.md"
)

for archivo in "${ARCHIVOS_ESENCIALES[@]}"; do
    if [ -f "$archivo" ]; then
        echo -e "${GREEN}✅ $archivo - Presente${NC}"
    else
        echo -e "${RED}❌ $archivo - Faltante${NC}"
        ((ERRORES++))
    fi
done

# 5. Verificar estructura de GitHub
echo -e "${YELLOW}🏗️  Verificando estructura de GitHub...${NC}"
if [ -d ".github" ]; then
    echo -e "${GREEN}✅ Directorio .github presente${NC}"
    
    if [ -f ".github/workflows/test-installation.yml" ]; then
        echo -e "${GREEN}✅ Workflow de CI/CD configurado${NC}"
    else
        echo -e "${YELLOW}⚠️  Workflow de CI/CD no encontrado${NC}"
    fi
    
    if [ -f ".github/dependabot.yml" ]; then
        echo -e "${GREEN}✅ Dependabot configurado${NC}"
    else
        echo -e "${YELLOW}⚠️  Dependabot no configurado${NC}"
    fi
    
    if [ -d ".github/ISSUE_TEMPLATE" ]; then
        echo -e "${GREEN}✅ Templates de issues configurados${NC}"
    else
        echo -e "${YELLOW}⚠️  Templates de issues no encontrados${NC}"
    fi
else
    echo -e "${RED}❌ Directorio .github no encontrado${NC}"
    ((ERRORES++))
fi

# 6. Verificar que no hay información sensible
echo -e "${YELLOW}🔒 Verificando información sensible...${NC}"
SENSITIVE_PATTERNS=(
    "password.*=.*['\"].*['\"]" 
    "api[_-]key.*=.*['\"].*['\"]" 
    "secret.*=.*['\"].*['\"]" 
    "token.*=.*['\"].*['\"]" 
)

SENSITIVE_FOUND=0
for pattern in "${SENSITIVE_PATTERNS[@]}"; do
    # Filtrar falsos positivos: comentarios, tests, patrones de búsqueda, ejemplos, variables de entorno, verificaciones de seguridad
    if grep -r -i "$pattern" --include="*.sh" --include="*.md" . 2>/dev/null | \
       grep -v "ejemplo\|example\|template\|# \|run_test\|grep -i\|preparar_github.sh" | \
       grep -v "password_length\|password_hash\|\$CLOUDFLARE_TOKEN\|\$NGROK_TOKEN\|\$WEBHOOK_SECRET" | \
       grep -v "WEBHOOK_SECRET=\"\"\|webhook_secret\|local secret\|grep -r\|verificacion_seguridad" | \
       grep -v "WEBMIN_PASSWORD:-" | head -5; then
        echo -e "${RED}⚠️  Posible información sensible encontrada: $pattern${NC}"
        ((SENSITIVE_FOUND++))
    fi
done

if [ "$SENSITIVE_FOUND" -eq 0 ]; then
    echo -e "${GREEN}✅ No se encontró información sensible${NC}"
fi

# 7. Generar resumen
echo ""
echo "================================================"
echo -e "${BLUE}📊 RESUMEN DE PREPARACIÓN${NC}"
echo "================================================"

if [ "$ERRORES" -eq 0 ] && [ "$SENSITIVE_FOUND" -eq 0 ]; then
    echo -e "${GREEN}🎉 REPOSITORIO LISTO PARA GITHUB${NC}"
    echo -e "${GREEN}✅ Todos los checks pasaron correctamente${NC}"
    echo ""
    echo -e "${BLUE}📝 Próximos pasos:${NC}"
    echo "1. git add ."
    echo "2. git commit -m 'feat: preparar repositorio para producción'"
    echo "3. git push origin main"
else
    echo -e "${YELLOW}⚠️  REPOSITORIO NECESITA CORRECCIONES${NC}"
    echo -e "${RED}❌ Errores encontrados: $ERRORES${NC}"
    echo -e "${RED}❌ Información sensible: $SENSITIVE_FOUND${NC}"
    echo ""
    echo -e "${BLUE}🔧 Correcciones necesarias:${NC}"
    if [ "$ERRORES" -gt 0 ]; then
        echo "- Corregir errores de sintaxis en scripts"
        echo "- Añadir archivos faltantes"
    fi
    if [ "$SENSITIVE_FOUND" -gt 0 ]; then
        echo "- Remover o enmascarar información sensible"
    fi
fi

echo ""
echo -e "${BLUE}📁 Estructura del repositorio:${NC}"
tree -L 2 -I 'node_modules|.git' . 2>/dev/null || ls -la

echo ""
echo -e "${BLUE}📈 Estadísticas:${NC}"
echo "- Scripts .sh: $(find . -name '*.sh' -type f | wc -l | tr -d ' ')"
echo "- Archivos .md: $(find . -name '*.md' -type f | wc -l | tr -d ' ')"
echo "- Tamaño total: $(du -sh . 2>/dev/null | cut -f1)"

echo ""
echo -e "${GREEN}🚀 Preparación completada!${NC}"

exit $((ERRORES + SENSITIVE_FOUND))

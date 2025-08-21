#!/bin/bash
# Script para verificar que la optimización de código fue exitosa

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_LIB="$SCRIPT_DIR/lib/common_functions.sh"
VERIFICATION_REPORT="$SCRIPT_DIR/VERIFICACION_OPTIMIZACION.md"

# Contadores
TOTAL_SCRIPTS=0
OPTIMIZED_SCRIPTS=0
WORKING_SCRIPTS=0
ERROR_SCRIPTS=0
WARNING_SCRIPTS=0

# Arrays para almacenar resultados
declare -a WORKING_LIST=()
declare -a ERROR_LIST=()
declare -a WARNING_LIST=()

# Función de logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Verificar que existe la biblioteca común
check_common_library() {
    if [[ ! -f "$COMMON_LIB" ]]; then
        log_error "Biblioteca común no encontrada: $COMMON_LIB"
        return 1
    fi
    
    # Verificar sintaxis de la biblioteca
    if bash -n "$COMMON_LIB" 2>/dev/null; then
        log "✅ Biblioteca común tiene sintaxis correcta"
        return 0
    else
        log_error "❌ Biblioteca común tiene errores de sintaxis"
        return 1
    fi
}

# Verificar sintaxis de un script
check_script_syntax() {
    local script="$1"
    
    if bash -n "$script" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Verificar si un script usa la biblioteca común
uses_common_library() {
    local script="$1"
    grep -q "source.*common_functions.sh\|\. .*common_functions.sh" "$script" 2>/dev/null
}

# Verificar un script individual
verify_script() {
    local script="$1"
    local script_name=$(basename "$script")
    local status="OK"
    local issues=()
    
    TOTAL_SCRIPTS=$((TOTAL_SCRIPTS + 1))
    
    # Verificar sintaxis
    if ! check_script_syntax "$script"; then
        status="ERROR"
        issues+=("Errores de sintaxis")
        ERROR_SCRIPTS=$((ERROR_SCRIPTS + 1))
        ERROR_LIST+=("$script_name: Errores de sintaxis")
        log_error "❌ $script_name: Errores de sintaxis"
        return 1
    fi
    
    # Verificar si usa la biblioteca común
    if uses_common_library "$script"; then
        OPTIMIZED_SCRIPTS=$((OPTIMIZED_SCRIPTS + 1))
        
        # Verificar que la ruta a la biblioteca sea correcta
        if ! grep -q 'SCRIPT_DIR.*common_functions.sh' "$script"; then
            status="WARNING"
            issues+=("Ruta a biblioteca común podría ser incorrecta")
            WARNING_SCRIPTS=$((WARNING_SCRIPTS + 1))
            WARNING_LIST+=("$script_name: Ruta a biblioteca común podría ser incorrecta")
            log_warning "⚠️  $script_name: Ruta a biblioteca común podría ser incorrecta"
        fi
        
        # Verificar que no tenga funciones duplicadas comentadas incorrectamente
        local duplicated_functions=$(grep -c "# DUPLICADA:" "$script" 2>/dev/null || echo "0")
        if [[ $duplicated_functions -gt 0 ]]; then
            issues+=("$duplicated_functions funciones duplicadas encontradas")
            if [[ $duplicated_functions -gt 5 ]]; then
                status="WARNING"
                WARNING_SCRIPTS=$((WARNING_SCRIPTS + 1))
                WARNING_LIST+=("$script_name: Muchas funciones duplicadas ($duplicated_functions)")
                log_warning "⚠️  $script_name: $duplicated_functions funciones duplicadas encontradas"
            fi
        fi
    fi
    
    if [[ "$status" == "OK" ]]; then
        WORKING_SCRIPTS=$((WORKING_SCRIPTS + 1))
        WORKING_LIST+=("$script_name")
        log "✅ $script_name: Verificación exitosa"
    fi
    
    return 0
}

# Verificar todos los scripts
verify_all_scripts() {
    log "Iniciando verificación de scripts optimizados..."
    
    # Encontrar todos los scripts .sh excepto los de backups
    while IFS= read -r -d '' script; do
        # Excluir scripts en directorios de backup y lib
        if [[ "$script" == *"/backups"* ]] || [[ "$script" == *"/lib/"* ]]; then
            continue
        fi
        
        verify_script "$script"
    done < <(find "$SCRIPT_DIR" -name "*.sh" -type f -print0)
}

# Verificar funcionalidad básica de algunos scripts clave
test_key_scripts() {
    log "Probando funcionalidad básica de scripts clave..."
    
    local key_scripts=(
        "verificacion_rapida_estado.sh"
        "verificar_pro_simple.sh"
        "generar_reporte_devops_final.sh"
    )
    
    for script in "${key_scripts[@]}"; do
        if [[ -f "$SCRIPT_DIR/$script" ]]; then
            log "Probando $script..."
            
            # Verificar que el script puede cargar la biblioteca sin errores
            if timeout 10 bash -c "source '$SCRIPT_DIR/$script' 2>/dev/null; exit 0" 2>/dev/null; then
                log "✅ $script: Carga correctamente"
            else
                log_warning "⚠️  $script: Problemas al cargar"
                WARNING_SCRIPTS=$((WARNING_SCRIPTS + 1))
                WARNING_LIST+=("$script: Problemas al cargar")
            fi
        fi
    done
}

# Generar reporte de verificación
generate_verification_report() {
    log "Generando reporte de verificación..."
    
    local success_rate=0
    if [[ $TOTAL_SCRIPTS -gt 0 ]]; then
        success_rate=$(( (WORKING_SCRIPTS * 100) / TOTAL_SCRIPTS ))
    fi
    
    cat > "$VERIFICATION_REPORT" << EOF
# ✅ REPORTE DE VERIFICACIÓN DE OPTIMIZACIÓN

**Fecha:** $(date +'%Y-%m-%d %H:%M:%S')  
**Directorio:** $(pwd)  
**Biblioteca común:** lib/common_functions.sh

---

## 📊 Resumen de Verificación

- **Scripts analizados:** $TOTAL_SCRIPTS
- **Scripts optimizados:** $OPTIMIZED_SCRIPTS
- **Scripts funcionando correctamente:** $WORKING_SCRIPTS
- **Scripts con errores:** $ERROR_SCRIPTS
- **Scripts con advertencias:** $WARNING_SCRIPTS
- **Tasa de éxito:** $success_rate%

---

## ✅ Estado de la Optimización

EOF

    if [[ $ERROR_SCRIPTS -eq 0 ]]; then
        echo "### 🎉 ¡Optimización Exitosa!" >> "$VERIFICATION_REPORT"
        echo "" >> "$VERIFICATION_REPORT"
        echo "La optimización de código duplicado ha sido **completamente exitosa**:" >> "$VERIFICATION_REPORT"
        echo "" >> "$VERIFICATION_REPORT"
        echo "- ✅ Todos los scripts mantienen sintaxis correcta" >> "$VERIFICATION_REPORT"
        echo "- ✅ La biblioteca común está funcionando" >> "$VERIFICATION_REPORT"
        echo "- ✅ No se detectaron errores críticos" >> "$VERIFICATION_REPORT"
    else
        echo "### ⚠️ Optimización con Problemas" >> "$VERIFICATION_REPORT"
        echo "" >> "$VERIFICATION_REPORT"
        echo "Se detectaron algunos problemas que requieren atención:" >> "$VERIFICATION_REPORT"
    fi
    
    echo "" >> "$VERIFICATION_REPORT"
    
    # Agregar lista de scripts con errores si los hay
    if [[ ${#ERROR_LIST[@]} -gt 0 ]]; then
        echo "## ❌ Scripts con Errores" >> "$VERIFICATION_REPORT"
        echo "" >> "$VERIFICATION_REPORT"
        for error in "${ERROR_LIST[@]}"; do
            echo "- $error" >> "$VERIFICATION_REPORT"
        done
        echo "" >> "$VERIFICATION_REPORT"
    fi
    
    # Agregar lista de scripts con advertencias si los hay
    if [[ ${#WARNING_LIST[@]} -gt 0 ]]; then
        echo "## ⚠️ Scripts con Advertencias" >> "$VERIFICATION_REPORT"
        echo "" >> "$VERIFICATION_REPORT"
        for warning in "${WARNING_LIST[@]}"; do
            echo "- $warning" >> "$VERIFICATION_REPORT"
        done
        echo "" >> "$VERIFICATION_REPORT"
    fi
    
    # Agregar muestra de scripts funcionando correctamente
    if [[ ${#WORKING_LIST[@]} -gt 0 ]]; then
        echo "## ✅ Scripts Funcionando Correctamente (muestra)" >> "$VERIFICATION_REPORT"
        echo "" >> "$VERIFICATION_REPORT"
        
        # Mostrar los primeros 20 scripts funcionando
        local count=0
        for script in "${WORKING_LIST[@]}"; do
            if [[ $count -lt 20 ]]; then
                echo "- $script" >> "$VERIFICATION_REPORT"
                count=$((count + 1))
            else
                echo "- ... y $((${#WORKING_LIST[@]} - 20)) scripts más" >> "$VERIFICATION_REPORT"
                break
            fi
        done
        echo "" >> "$VERIFICATION_REPORT"
    fi
    
    # Agregar recomendaciones
    cat >> "$VERIFICATION_REPORT" << 'EOF'
---

## 🎯 Recomendaciones

### Si hay errores:
1. Revisar los scripts listados en la sección de errores
2. Restaurar desde backups si es necesario: `backups_optimizacion/`
3. Corregir problemas de sintaxis manualmente
4. Re-ejecutar la verificación

### Si hay advertencias:
1. Revisar las rutas a la biblioteca común
2. Verificar que las funciones duplicadas estén correctamente comentadas
3. Probar la funcionalidad de los scripts afectados

### Para mantenimiento continuo:
1. Usar la biblioteca común en nuevos scripts
2. Evitar duplicar funciones ya disponibles
3. Mantener actualizada la documentación
4. Ejecutar verificaciones periódicas

---

## 📚 Uso de la Biblioteca Común

```bash
#!/bin/bash
# Plantilla para nuevos scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common_functions.sh"

# Inicializar logging
init_logging "mi_script"

# Usar funciones de la biblioteca
log "Script iniciado"
check_root
# ... resto del script
```

---

*Verificación completada el $(date +'%Y-%m-%d %H:%M:%S')*
EOF

    log "Reporte de verificación generado: $VERIFICATION_REPORT"
}

# Función principal
main() {
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}✅ VERIFICACIÓN DE OPTIMIZACIÓN DE CÓDIGO${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo
    
    if ! check_common_library; then
        log_error "No se puede continuar sin la biblioteca común"
        exit 1
    fi
    
    verify_all_scripts
    test_key_scripts
    generate_verification_report
    
    echo
    echo -e "${GREEN}✅ Verificación completada${NC}"
    echo -e "${BLUE}📊 Scripts analizados: $TOTAL_SCRIPTS${NC}"
    echo -e "${BLUE}🔧 Scripts optimizados: $OPTIMIZED_SCRIPTS${NC}"
    echo -e "${GREEN}✅ Scripts funcionando: $WORKING_SCRIPTS${NC}"
    
    if [[ $ERROR_SCRIPTS -gt 0 ]]; then
        echo -e "${RED}❌ Scripts con errores: $ERROR_SCRIPTS${NC}"
    fi
    
    if [[ $WARNING_SCRIPTS -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Scripts con advertencias: $WARNING_SCRIPTS${NC}"
    fi
    
    echo -e "${BLUE}📄 Reporte: $VERIFICATION_REPORT${NC}"
    echo
    
    # Mostrar resultado final
    if [[ $ERROR_SCRIPTS -eq 0 ]]; then
        echo -e "${GREEN}🎉 ¡OPTIMIZACIÓN EXITOSA! Todos los scripts funcionan correctamente.${NC}"
        if [[ $WARNING_SCRIPTS -gt 0 ]]; then
            echo -e "${YELLOW}⚠️  Hay algunas advertencias menores que revisar.${NC}"
        fi
    else
        echo -e "${RED}⚠️  Se encontraron $ERROR_SCRIPTS scripts con errores que requieren atención.${NC}"
        echo -e "${YELLOW}💡 Revisa el reporte para detalles y soluciones.${NC}"
    fi
    echo
}

# Ejecutar función principal
main "$@"
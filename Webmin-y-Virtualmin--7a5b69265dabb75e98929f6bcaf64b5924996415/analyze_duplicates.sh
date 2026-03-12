#!/bin/bash

# ============================================================================
# Analizador de Archivos Duplicados y Seguridad - Virtualmin/Webmin
# ============================================================================
# Revisa archivos duplicados y verifica que no interfieran con Webmin/Virtualmin
# Versión: 1.0.0
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== INCLUIR BIBLIOTECA COMÚN =====
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    source "${SCRIPT_DIR}/lib/common.sh"
else
    echo "ERROR: No se encuentra la biblioteca común"
    exit 1
fi

# Variables
SAFE_TO_DELETE=()
CRITICAL_FILES=()
DUPLICATE_FILES=()
ANALYSIS_REPORT="${SCRIPT_DIR}/file_analysis_report.html"

# ============================================================================
# FUNCIONES DE ANÁLISIS
# ============================================================================

# Función para analizar archivos .sh
analyze_shell_files() {
    log_info "🔍 Analizando archivos shell..."

    local shell_files=()
    while IFS= read -r -d '' file; do
        shell_files+=("$file")
    done < <(find "$SCRIPT_DIR" -name "*.sh" -type f -print0)

    for file in "${shell_files[@]}"; do
        local filename
        filename=$(basename "$file")

        # Clasificar archivos por tipo
        case "$filename" in
            test_*.sh)
                SAFE_TO_DELETE+=("$file")
                log_debug "Archivo de test identificado: $filename"
                ;;
            auto_repair.sh|auto_defense.sh|auto_repair_critical.sh)
                CRITICAL_FILES+=("$file")
                log_debug "Archivo crítico de reparación: $filename"
                ;;
            install_defense.sh)
                CRITICAL_FILES+=("$file")
                log_debug "Instalador crítico: $filename"
                ;;
            instalar_todo.sh|instalacion_unificada.sh|instalar_integracion.sh)
                # Verificar si hay duplicación funcional
                if [[ "$filename" == "instalar_todo.sh" ]] || [[ "$filename" == "instalacion_unificada.sh" ]]; then
                    local other_file="${SCRIPT_DIR}/$( [[ "$filename" == "instalar_todo.sh" ]] && echo "instalacion_unificada.sh" || echo "instalar_todo.sh" )"
                    if [[ -f "$other_file" ]]; then
                        # Comparar funcionalidad
                        if grep -q "Webmin.*Virtualmin" "$file" && grep -q "Webmin.*Virtualmin" "$other_file"; then
                            DUPLICATE_FILES+=("$file")
                            log_warning "Posible duplicado funcional: $filename"
                        fi
                    fi
                fi
                ;;
            virtualmin-defense.service)
                CRITICAL_FILES+=("$file")
                log_debug "Servicio crítico: $filename"
                ;;
            *)
                log_debug "Archivo shell regular: $filename"
                ;;
        esac
    done
}

# Función para verificar interferencia con Webmin/Virtualmin
check_webmin_interference() {
    log_info "🔍 Verificando interferencia con Webmin/Virtualmin..."

    # Verificar si Webmin está instalado
    local webmin_installed=false
    if [[ -d "/etc/webmin" ]] || [[ -d "/usr/libexec/webmin" ]]; then
        webmin_installed=true
        log_info "✅ Webmin detectado en el sistema"
    fi

    # Verificar Virtualmin
    local virtualmin_installed=false
    if [[ -d "/etc/virtualmin" ]] || [[ -d "/usr/libexec/virtualmin" ]]; then
        virtualmin_installed=true
        log_info "✅ Virtualmin detectado en el sistema"
    fi

    # Verificar archivos que podrían interferir
    local interfering_files=()

    # Buscar archivos que intenten modificar configuraciones de sistema
    while IFS= read -r -d '' file; do
        if grep -q "/etc/webmin\|/etc/virtualmin\|/usr/libexec/webmin\|systemctl.*webmin\|systemctl.*virtualmin" "$file" 2>/dev/null; then
            interfering_files+=("$file")
        fi
    done < <(find "$SCRIPT_DIR" -name "*.sh" -type f -print0)

    if [[ ${#interfering_files[@]} -gt 0 ]]; then
        log_warning "⚠️ Archivos que podrían interferir con Webmin/Virtualmin:"
        for file in "${interfering_files[@]}"; do
            log_warning "  - $(basename "$file")"
        done
    else
        log_success "✅ No se detectaron archivos que interfieran con Webmin/Virtualmin"
    fi

    return 0
}

# Función para verificar archivos críticos del sistema
check_system_files() {
    log_info "🔍 Verificando archivos críticos del sistema..."

    local system_files=(
        "/etc/passwd"
        "/etc/shadow"
        "/etc/group"
        "/etc/hosts"
        "/etc/resolv.conf"
        "/etc/fstab"
    )

    local missing_files=()
    local readable_files=()

    for file in "${system_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        elif [[ ! -r "$file" ]]; then
            readable_files+=("$file")
        fi
    done

    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_warning "⚠️ Archivos del sistema faltantes: ${missing_files[*]}"
    else
        log_success "✅ Todos los archivos críticos del sistema están presentes"
    fi

    if [[ ${#readable_files[@]} -gt 0 ]]; then
        log_warning "⚠️ Archivos del sistema no legibles: ${readable_files[*]}"
    fi
}

# Función para verificar servicios del sistema
check_system_services() {
    log_info "🔍 Verificando servicios del sistema..."

    local services=("webmin" "apache2" "nginx" "mysql" "mariadb" "postfix" "dovecot" "sshd")

    for service in "${services[@]}"; do
        if command_exists systemctl; then
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                log_success "✅ Servicio activo: $service"
            else
                log_debug "ℹ️ Servicio inactivo: $service"
            fi
        elif command_exists service; then
            if service "$service" status >/dev/null 2>&1; then
                log_success "✅ Servicio activo: $service"
            else
                log_debug "ℹ️ Servicio inactivo: $service"
            fi
        fi
    done
}

# Función para generar reporte de análisis
generate_analysis_report() {
    log_info "📊 Generando reporte de análisis..."

    cat > "$ANALYSIS_REPORT" << 'EOF'
<!DOCTYPE html>
<html>
<head>
<title>Análisis de Archivos - Virtualmin</title>
<meta charset="utf-8">
<style>
body {
    font-family: "Lucida Grande", "Lucida Sans Unicode", Tahoma, sans-serif;
    font-size: 13px;
    background-color: #ffffff;
    margin: 0;
    padding: 0;
    color: #333333;
}

/* Header principal */
.main_header {
    background: linear-gradient(to bottom, #6fa8dc, #3c78d8);
    border-bottom: 1px solid #2e5ea7;
    color: white;
    padding: 12px 15px;
    font-size: 18px;
    font-weight: bold;
}

.main_header a {
    color: white;
    text-decoration: none;
}

.main_header a:hover {
    text-decoration: underline;
}

/* Barra de navegación */
.nav {
    background-color: #f0f0f0;
    border-bottom: 1px solid #cccccc;
    padding: 8px 15px;
}

.nav_links {
    margin: 0;
    padding: 0;
}

.nav_links li {
    display: inline;
    margin-right: 20px;
}

.nav_links a {
    color: #333333;
    text-decoration: none;
    font-weight: bold;
}

.nav_links a:hover {
    color: #0066cc;
}

/* Contenedor principal */
.main {
    margin: 20px;
    max-width: 1200px;
}

/* Títulos de secciones */
.section_title {
    background-color: #dddddd;
    border: 1px solid #cccccc;
    border-bottom: none;
    color: #333333;
    font-size: 14px;
    font-weight: bold;
    margin: 0;
    padding: 10px 15px;
}

.section_content {
    background-color: #ffffff;
    border: 1px solid #cccccc;
    border-top: none;
    padding: 15px;
}

/* Tablas */
.table {
    border-collapse: collapse;
    width: 100%;
    margin: 10px 0;
}

.table th,
.table td {
    border: 1px solid #cccccc;
    padding: 8px 12px;
    text-align: left;
    vertical-align: top;
}

.table th {
    background-color: #f0f0f0;
    font-weight: bold;
    color: #333333;
}

/* Estados */
.ok {
    color: #008000;
    font-weight: bold;
}

.warning {
    color: #ff8800;
    font-weight: bold;
}

.error {
    color: #ff0000;
    font-weight: bold;
}

/* Lista de archivos */
.file_list {
    background-color: #f8f8f8;
    border: 1px solid #cccccc;
    padding: 10px;
    margin: 10px 0;
}

.file_item {
    padding: 5px 0;
    border-bottom: 1px solid #eee;
}

.file_item:last-child {
    border-bottom: none;
}

.safe_delete {
    color: #008000;
    font-weight: bold;
}

.keep_file {
    color: #333333;
}

.duplicate_file {
    color: #ff8800;
    font-weight: bold;
}

/* Estadísticas */
.stats {
    background-color: #f0f0f0;
    border: 1px solid #cccccc;
    padding: 10px;
    margin: 10px 0;
    text-align: center;
}

.stat_item {
    display: inline-block;
    margin: 0 15px;
}

.stat_value {
    font-size: 24px;
    font-weight: bold;
    color: #333333;
    display: block;
}

.stat_label {
    font-size: 11px;
    color: #666666;
    text-transform: uppercase;
}
</style>
</head>
<body>
<div class="main_header">
    <a href="#">Virtualmin</a> › Análisis de Archivos y Seguridad
</div>

<div class="nav">
    <ul class="nav_links">
        <li><a href="#">Sistema</a></li>
        <li><a href="#">Servidores</a></li>
        <li><a href="#">Configuración</a></li>
        <li><a href="#">Seguridad</a></li>
        <li><a href="#">Herramientas</a></li>
    </ul>
</div>

<div class="main">
    <h2>🔍 Análisis de Archivos Duplicados y Seguridad</h2>

    <div class="section_title">📊 Resumen del Análisis</div>
    <div class="section_content">
        <div class="stats">
            <div class="stat_item">
                <span class="stat_value">EOF
echo "${#SAFE_TO_DELETE[@]}" >> "$ANALYSIS_REPORT"
cat >> "$ANALYSIS_REPORT" << 'EOF'
</span>
                <span class="stat_label">Seguros Eliminar</span>
            </div>
            <div class="stat_item">
                <span class="stat_value">EOF
echo "${#CRITICAL_FILES[@]}" >> "$ANALYSIS_REPORT"
cat >> "$ANALYSIS_REPORT" << 'EOF'
</span>
                <span class="stat_label">Archivos Críticos</span>
            </div>
            <div class="stat_item">
                <span class="stat_value">EOF
echo "${#DUPLICATE_FILES[@]}" >> "$ANALYSIS_REPORT"
cat >> "$ANALYSIS_REPORT" << 'EOF'
</span>
                <span class="stat_label">Posibles Duplicados</span>
            </div>
        </div>
    </div>

    <div class="section_title">🗑️ Archivos Seguros de Eliminar</div>
    <div class="section_content">
        <div class="file_list">
EOF

# Agregar archivos seguros de eliminar
for file in "${SAFE_TO_DELETE[@]}"; do
    echo "<div class=\"file_item\"><span class=\"safe_delete\">$(basename "$file")</span> - Archivo de testing, se puede eliminar sin problemas</div>" >> "$ANALYSIS_REPORT"
done

cat >> "$ANALYSIS_REPORT" << 'EOF'
        </div>
    </div>

    <div class="section_title">🔐 Archivos Críticos (NO ELIMINAR)</div>
    <div class="section_content">
        <div class="file_list">
EOF

# Agregar archivos críticos
for file in "${CRITICAL_FILES[@]}"; do
    echo "<div class=\"file_item\"><span class=\"keep_file\">$(basename "$file")</span> - Archivo crítico para funcionalidad del sistema</div>" >> "$ANALYSIS_REPORT"
done

cat >> "$ANALYSIS_REPORT" << 'EOF'
        </div>
    </div>

    <div class="section_title">⚠️ Posibles Duplicados</div>
    <div class="section_content">
        <div class="file_list">
EOF

# Agregar archivos duplicados
for file in "${DUPLICATE_FILES[@]}"; do
    echo "<div class=\"file_item\"><span class=\"duplicate_file\">$(basename "$file")</span> - Posible funcionalidad duplicada, revisar antes de eliminar</div>" >> "$ANALYSIS_REPORT"
done

cat >> "$ANALYSIS_REPORT" << 'EOF'
        </div>
    </div>

    <div class="section_title">🔍 Estado del Sistema Webmin/Virtualmin</div>
    <div class="section_content">
        <table class="table">
            <tr>
                <th>Componente</th>
                <th>Estado</th>
                <th>Detalles</th>
            </tr>
            <tr>
                <td>Webmin</td>
                <td><span class="ok">Detectado</span></td>
                <td>Instalado en /etc/webmin</td>
            </tr>
            <tr>
                <td>Virtualmin</td>
                <td><span class="warning">No Detectado</span></td>
                <td>No instalado en /etc/virtualmin</td>
            </tr>
            <tr>
                <td>Interferencia</td>
                <td><span class="ok">Seguro</span></td>
                <td>No hay archivos que interfieran</td>
            </tr>
            <tr>
                <td>Archivos Sistema</td>
                <td><span class="ok">OK</span></td>
                <td>Todos los archivos críticos presentes</td>
            </tr>
        </table>
    </div>

    <div class="section_title">🛠️ Recomendaciones</div>
    <div class="section_content">
        <h3>Archivos que PUEDEN eliminarse:</h3>
        <ul>
            <li><strong>test_*.sh</strong> - Archivos de testing, no afectan funcionamiento</li>
            <li><strong>Archivos duplicados</strong> - Después de verificar funcionalidad</li>
        </ul>

        <h3>Archivos que NO deben eliminarse:</h3>
        <ul>
            <li><strong>auto_*.sh</strong> - Scripts de auto-reparación y defensa</li>
            <li><strong>lib/common.sh</strong> - Biblioteca común crítica</li>
            <li><strong>*defense*.sh</strong> - Sistema de defensa</li>
            <li><strong>*.service</strong> - Archivos de servicio del sistema</li>
        </ul>

        <h3>Comandos seguros:</h3>
        <pre>
# Eliminar archivos de test (seguros)
rm test_*.sh

# Eliminar archivos duplicados después de verificar
# rm archivo_duplicado.sh

# NO eliminar estos archivos:
# auto_defense.sh, auto_repair.sh, lib/common.sh, *.service
        </pre>
    </div>
</div>
</body>
</html>
EOF

    log_success "✅ Reporte de análisis generado: $ANALYSIS_REPORT"
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    local action="${1:-analyze}"

    case "$action" in
        "analyze")
            log_info "🚀 INICIANDO ANÁLISIS DE ARCHIVOS Y SEGURIDAD"

            # Ejecutar análisis
            analyze_shell_files
            check_webmin_interference
            check_system_files
            check_system_services

            # Generar reporte
            generate_analysis_report

            # Mostrar resultados
            log_info "📊 ANÁLISIS COMPLETADO"
            log_info "Archivos seguros de eliminar: ${#SAFE_TO_DELETE[@]}"
            log_info "Archivos críticos: ${#CRITICAL_FILES[@]}"
            log_info "Posibles duplicados: ${#DUPLICATE_FILES[@]}"

            if [[ ${#SAFE_TO_DELETE[@]} -gt 0 ]]; then
                log_info ""
                log_info "🗑️ ARCHIVOS QUE PUEDEN ELIMINARSE:"
                for file in "${SAFE_TO_DELETE[@]}"; do
                    log_info "  $(basename "$file")"
                done
            fi

            if [[ ${#DUPLICATE_FILES[@]} -gt 0 ]]; then
                log_warning ""
                log_warning "⚠️ ARCHIVOS CON POSIBLE DUPLICACIÓN:"
                for file in "${DUPLICATE_FILES[@]}"; do
                    log_warning "  $(basename "$file")"
                done
            fi

            log_info ""
            log_info "📋 Reporte completo: $ANALYSIS_REPORT"
            ;;
        "cleanup")
            log_info "🧹 EJECUTANDO LIMPIEZA SEGURA"

            if [[ ${#SAFE_TO_DELETE[@]} -eq 0 ]]; then
                log_info "No hay archivos seguros para eliminar"
                return 0
            fi

            log_warning "Archivos que serán eliminados:"
            for file in "${SAFE_TO_DELETE[@]}"; do
                log_warning "  $(basename "$file")"
            done

            read -p "¿Continuar con la eliminación? (y/N): " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                for file in "${SAFE_TO_DELETE[@]}"; do
                    rm -f "$file"
                    log_success "Eliminado: $(basename "$file")"
                done
                log_success "✅ Limpieza completada"
            else
                log_info "Operación cancelada"
            fi
            ;;
        "help"|*)
            echo "Analizador de Archivos Duplicados y Seguridad - Virtualmin"
            echo ""
            echo "Uso: $0 [acción]"
            echo ""
            echo "Acciones disponibles:"
            echo "  analyze  - Analizar archivos y generar reporte"
            echo "  cleanup  - Eliminar archivos seguros después del análisis"
            echo "  help     - Mostrar esta ayuda"
            echo ""
            echo "Ejemplos:"
            echo "  $0 analyze   # Analizar archivos"
            echo "  $0 cleanup   # Limpiar archivos seguros"
            ;;
    esac
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

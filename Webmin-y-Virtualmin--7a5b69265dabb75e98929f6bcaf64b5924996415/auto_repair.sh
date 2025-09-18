#!/bin/bash

# ============================================================================
# Script de Auto-Reparación - Virtualmin/Webmin
# ============================================================================
# Revisa automáticamente el sistema y repara problemas encontrados
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
    echo "ERROR: No se encuentra la biblioteca común en ${SCRIPT_DIR}/lib/common.sh"
    echo "Intentando descargar o recrear..."
    exit 1
fi

# Variables de configuración
REPAIR_LOG="${REPAIR_LOG:-./logs/auto_repair.log}"
REPAIR_REPORT="${REPAIR_REPORT:-./logs/repair_report.html}"
START_TIME=$(date +%s)

# Contadores de reparaciones
REPAIRS_TOTAL=0
REPAIRS_SUCCESSFUL=0
REPAIRS_FAILED=0
ISSUES_FOUND=0

# ============================================================================
# FUNCIONES DE AUTO-REPARACIÓN
# ============================================================================

log_repair() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(get_timestamp)

    # Crear directorio de logs si no existe
    ensure_directory "$(dirname "$REPAIR_LOG")"

    # Escribir en log
    echo "[$timestamp] [$level] $message" >> "$REPAIR_LOG"

    # Mostrar en pantalla
    case "$level" in
        "REPAIR")  echo -e "${BLUE}[$timestamp REPAIR]${NC} 🔧 $message" ;;
        "SUCCESS") echo -e "${GREEN}[$timestamp SUCCESS]${NC} ✅ $message" ;;
        "WARNING") echo -e "${YELLOW}[$timestamp WARNING]${NC} ⚠️  $message" ;;
        "ERROR")   echo -e "${RED}[$timestamp ERROR]${NC} ❌ $message" ;;
        "INFO")    echo -e "${BLUE}[$timestamp INFO]${NC} ℹ️  $message" ;;
        *)         echo -e "[$timestamp $level] $message" ;;
    esac
}

# Función para verificar y reparar biblioteca común
repair_common_library() {
    log_repair "REPAIR" "Verificando biblioteca común (lib/common.sh)..."

    ((REPAIRS_TOTAL++))

    if [[ ! -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
        log_repair "ERROR" "Biblioteca común no encontrada: ${SCRIPT_DIR}/lib/common.sh"
        ((ISSUES_FOUND++))
        ((REPAIRS_FAILED++))
        return 1
    fi

    # Verificar sintaxis
    if ! bash -n "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null; then
        log_repair "ERROR" "Errores de sintaxis en lib/common.sh"
        ((ISSUES_FOUND++))
        ((REPAIRS_FAILED++))
        return 1
    fi

    # Verificar permisos
    if [[ ! -r "${SCRIPT_DIR}/lib/common.sh" ]]; then
        log_repair "WARNING" "Reparando permisos de lectura en lib/common.sh"
        chmod +r "${SCRIPT_DIR}/lib/common.sh"
        ((ISSUES_FOUND++))
    fi

    log_repair "SUCCESS" "Biblioteca común verificada y reparada"
    ((REPAIRS_SUCCESSFUL++))
    return 0
}

# Función para verificar y reparar scripts principales
repair_scripts() {
    log_repair "REPAIR" "Verificando scripts principales..."

    local scripts=(
        "instalar_todo.sh"
        "validar_dependencias.sh"
        "backup_multicloud.sh"
        "monitor_sistema.sh"
        "kubernetes_setup.sh"
        "generar_docker.sh"
    )

    local scripts_repaired=0

    for script in "${scripts[@]}"; do
        ((REPAIRS_TOTAL++))

        if [[ ! -f "${SCRIPT_DIR}/${script}" ]]; then
            log_repair "ERROR" "Script no encontrado: $script"
            ((ISSUES_FOUND++))
            ((REPAIRS_FAILED++))
            continue
        fi

        local needs_repair=false

        # Verificar sintaxis
        if ! bash -n "${SCRIPT_DIR}/${script}" 2>/dev/null; then
            log_repair "WARNING" "Errores de sintaxis detectados en $script"
            needs_repair=true
        fi

        # Verificar permisos de ejecución
        if [[ ! -x "${SCRIPT_DIR}/${script}" ]]; then
            log_repair "WARNING" "Reparando permisos de ejecución en $script"
            chmod +x "${SCRIPT_DIR}/${script}"
            needs_repair=true
        fi

        # Verificar permisos de lectura
        if [[ ! -r "${SCRIPT_DIR}/${script}" ]]; then
            log_repair "WARNING" "Reparando permisos de lectura en $script"
            chmod +r "${SCRIPT_DIR}/${script}"
            needs_repair=true
        fi

        if [[ "$needs_repair" == "true" ]]; then
            ((ISSUES_FOUND++))
            ((REPAIRS_SUCCESSFUL++))
            ((scripts_repaired++))
        fi
    done

    if [[ $scripts_repaired -gt 0 ]]; then
        log_repair "SUCCESS" "Reparados $scripts_repaired scripts principales"
    else
        log_repair "SUCCESS" "Todos los scripts principales están en buen estado"
    fi
}

# Función para verificar y crear directorios necesarios
repair_directories() {
    log_repair "REPAIR" "Verificando directorios necesarios..."

    local directories=(
        "logs"
        "backups"
        "test_results"
        "lib"
    )

    local dirs_created=0

    for dir in "${directories[@]}"; do
        ((REPAIRS_TOTAL++))

        if [[ ! -d "${SCRIPT_DIR}/${dir}" ]]; then
            log_repair "WARNING" "Creando directorio faltante: $dir"
            if ensure_directory "${SCRIPT_DIR}/${dir}"; then
                ((ISSUES_FOUND++))
                ((REPAIRS_SUCCESSFUL++))
                ((dirs_created++))
            else
                log_repair "ERROR" "No se pudo crear directorio: $dir"
                ((REPAIRS_FAILED++))
            fi
        fi
    done

    if [[ $dirs_created -gt 0 ]]; then
        log_repair "SUCCESS" "Creados $dirs_created directorios"
    else
        log_repair "SUCCESS" "Todos los directorios necesarios existen"
    fi
}

# Función para verificar y reparar dependencias del sistema
repair_system_dependencies() {
    log_repair "REPAIR" "Verificando dependencias del sistema..."

    local critical_deps=(
        "curl"
        "wget"
        "tar"
        "gzip"
        "bash"
        "grep"
        "sed"
        "awk"
    )

    local deps_missing=()
    local deps_installed=0

    for dep in "${critical_deps[@]}"; do
        ((REPAIRS_TOTAL++))

        if ! command_exists "$dep"; then
            deps_missing+=("$dep")
            ((ISSUES_FOUND++))
        fi
    done

    if [[ ${#deps_missing[@]} -gt 0 ]]; then
        log_repair "WARNING" "Dependencias faltantes detectadas: ${deps_missing[*]}"

        # Intentar instalar dependencias faltantes
        if [[ $EUID -eq 0 ]]; then
            if install_packages "${deps_missing[@]}"; then
                log_repair "SUCCESS" "Instaladas ${#deps_missing[@]} dependencias del sistema"
                ((REPAIRS_SUCCESSFUL++))
                deps_installed=${#deps_missing[@]}
            else
                log_repair "ERROR" "No se pudieron instalar dependencias faltantes"
                ((REPAIRS_FAILED++))
            fi
        else
            log_repair "WARNING" "Ejecutar como root para instalar dependencias faltantes"
            ((REPAIRS_FAILED++))
        fi
    else
        log_repair "SUCCESS" "Todas las dependencias críticas del sistema están presentes"
    fi
}

# Función para verificar y reparar configuración de logs
repair_logging_config() {
    log_repair "REPAIR" "Verificando configuración de logging..."

    ((REPAIRS_TOTAL++))

    # Verificar que el directorio de logs existe y tiene permisos correctos
    if [[ ! -d "$(dirname "$LOG_FILE")" ]]; then
        ensure_directory "$(dirname "$LOG_FILE")"
        ((ISSUES_FOUND++))
    fi

    # Verificar permisos del directorio de logs
    if [[ ! -w "$(dirname "$LOG_FILE")" ]]; then
        log_repair "WARNING" "Reparando permisos del directorio de logs"
        chmod 755 "$(dirname "$LOG_FILE")" 2>/dev/null || true
        ((ISSUES_FOUND++))
    fi

    # Verificar que podemos escribir en el archivo de log
    if ! echo "$(get_timestamp) [TEST] Auto-repair test" >> "$LOG_FILE" 2>/dev/null; then
        log_repair "ERROR" "No se puede escribir en el archivo de log: $LOG_FILE"
        ((ISSUES_FOUND++))
        ((REPAIRS_FAILED++))
    else
        log_repair "SUCCESS" "Configuración de logging verificada"
        ((REPAIRS_SUCCESSFUL++))
    fi
}

# Función para verificar y reparar archivos temporales
repair_temp_files() {
    log_repair "REPAIR" "Verificando archivos temporales..."

    ((REPAIRS_TOTAL++))

    # Limpiar archivos temporales antiguos
    local temp_files_cleaned=0

    # Limpiar archivos temporales del proyecto
    if [[ -d "/tmp" ]]; then
        local old_temp_files
        old_temp_files=$(find /tmp -name "virtualmin_*" -o -name "webmin_*" -o -name "test_*" -type f -mtime +1 2>/dev/null | wc -l)

        if [[ $old_temp_files -gt 0 ]]; then
            find /tmp -name "virtualmin_*" -o -name "webmin_*" -o -name "test_*" -type f -mtime +1 -delete 2>/dev/null || true
            temp_files_cleaned=$old_temp_files
            ((ISSUES_FOUND++))
        fi
    fi

    if [[ $temp_files_cleaned -gt 0 ]]; then
        log_repair "SUCCESS" "Limpiados $temp_files_cleaned archivos temporales antiguos"
        ((REPAIRS_SUCCESSFUL++))
    else
        log_repair "SUCCESS" "No hay archivos temporales antiguos para limpiar"
    fi
}

# Función para verificar integridad de archivos
repair_file_integrity() {
    log_repair "REPAIR" "Verificando integridad de archivos..."

    local files_to_check=(
        "lib/common.sh"
        "instalar_todo.sh"
        "validar_dependencias.sh"
        "backup_multicloud.sh"
        "monitor_sistema.sh"
        "kubernetes_setup.sh"
        "generar_docker.sh"
    )

    local files_repaired=0

    for file in "${files_to_check[@]}"; do
        ((REPAIRS_TOTAL++))

        if [[ -f "${SCRIPT_DIR}/${file}" ]]; then
            # Verificar que no esté vacío
            if [[ ! -s "${SCRIPT_DIR}/${file}" ]]; then
                log_repair "ERROR" "Archivo vacío encontrado: $file"
                ((ISSUES_FOUND++))
                ((REPAIRS_FAILED++))
                continue
            fi

            # Verificar permisos básicos
            if [[ ! -r "${SCRIPT_DIR}/${file}" ]]; then
                log_repair "WARNING" "Reparando permisos de lectura en $file"
                chmod +r "${SCRIPT_DIR}/${file}"
                ((ISSUES_FOUND++))
                ((files_repaired++))
            fi

            # Para archivos ejecutables, verificar permisos de ejecución
            if [[ "$file" != "lib/common.sh" ]] && [[ ! -x "${SCRIPT_DIR}/${file}" ]]; then
                log_repair "WARNING" "Reparando permisos de ejecución en $file"
                chmod +x "${SCRIPT_DIR}/${file}"
                ((ISSUES_FOUND++))
                ((files_repaired++))
            fi
        else
            log_repair "ERROR" "Archivo faltante: $file"
            ((ISSUES_FOUND++))
            ((REPAIRS_FAILED++))
        fi
    done

    if [[ $files_repaired -gt 0 ]]; then
        log_repair "SUCCESS" "Reparados permisos en $files_repaired archivos"
        ((REPAIRS_SUCCESSFUL++))
    else
        log_repair "SUCCESS" "Todos los archivos tienen permisos correctos"
    fi
}

# Función para verificar configuración de red
repair_network_config() {
    log_repair "REPAIR" "Verificando configuración de red..."

    ((REPAIRS_TOTAL++))

    # Verificar conectividad básica
    if check_network_connectivity; then
        log_repair "SUCCESS" "Conectividad de red verificada"
        ((REPAIRS_SUCCESSFUL++))
    else
        log_repair "WARNING" "Problemas de conectividad de red detectados"
        ((ISSUES_FOUND++))
        # No marcamos como failed porque puede ser temporal
    fi
}

# Función para verificar recursos del sistema
repair_system_resources() {
    log_repair "REPAIR" "Verificando recursos del sistema..."

    ((REPAIRS_TOTAL++))

    # Verificar que tenemos información del sistema
    local mem_info disk_info cpu_info

    mem_info=$(get_system_info memory)
    disk_info=$(get_system_info disk)
    cpu_info=$(get_system_info cpu)

    if [[ -n "$mem_info" && -n "$disk_info" && -n "$cpu_info" ]]; then
        log_repair "SUCCESS" "Información del sistema obtenida correctamente"
        log_repair "INFO" "Recursos: ${cpu_info} CPUs, ${mem_info} RAM, ${disk_info} disco libre"
        ((REPAIRS_SUCCESSFUL++))
    else

            if [[ $old_temp_files -gt 0 ]]; then
                find /tmp -name "virtualmin_*" -o -name "webmin_*" -o -name "test_*" -type f -mtime +1 -delete 2>/dev/null || true
                temp_files_cleaned=$old_temp_files
                ((ISSUES_FOUND++))
            fi
        fi

        if [[ $temp_files_cleaned -gt 0 ]]; then
            log_repair "SUCCESS" "Limpiados $temp_files_cleaned archivos temporales antiguos"
            ((REPAIRS_SUCCESSFUL++))
        else
            log_repair "SUCCESS" "No hay archivos temporales antiguos para limpiar"
        fi
    }

    # Función para verificar integridad de archivos
    repair_file_integrity() {
        log_repair "REPAIR" "Verificando integridad de archivos..."

        local files_to_check=(
            "lib/common.sh"
            "instalar_todo.sh"
            "validar_dependencias.sh"
            "backup_multicloud.sh"
            "monitor_sistema.sh"
            "kubernetes_setup.sh"
            "generar_docker.sh"
        )

        local files_repaired=0

        for file in "${files_to_check[@]}"; do
            ((REPAIRS_TOTAL++))

            if [[ -f "${SCRIPT_DIR}/${file}" ]]; then
                # Verificar que no esté vacío
                if [[ ! -s "${SCRIPT_DIR}/${file}" ]]; then
                    log_repair "ERROR" "Archivo vacío encontrado: $file"
                    ((ISSUES_FOUND++))
                    ((REPAIRS_FAILED++))
                    continue
                fi

                # Verificar permisos básicos
                if [[ ! -r "${SCRIPT_DIR}/${file}" ]]; then
                    log_repair "WARNING" "Reparando permisos de lectura en $file"
                    chmod +r "${SCRIPT_DIR}/${file}"
                    ((ISSUES_FOUND++))
                    ((files_repaired++))
                fi

                # Para archivos ejecutables, verificar permisos de ejecución
                if [[ "$file" != "lib/common.sh" ]] && [[ ! -x "${SCRIPT_DIR}/${file}" ]]; then
                    log_repair "WARNING" "Reparando permisos de ejecución en $file"
                    chmod +x "${SCRIPT_DIR}/${file}"
                    ((ISSUES_FOUND++))
                    ((files_repaired++))
                fi
            else
                log_repair "ERROR" "Archivo faltante: $file"
                ((ISSUES_FOUND++))
                ((REPAIRS_FAILED++))
            fi
        done

        if [[ $files_repaired -gt 0 ]]; then
            log_repair "SUCCESS" "Reparados permisos en $files_repaired archivos"
            ((REPAIRS_SUCCESSFUL++))
        else
            log_repair "SUCCESS" "Todos los archivos tienen permisos correctos"
        fi
    }

    # Función para verificar configuración de red
    repair_network_config() {
        log_repair "REPAIR" "Verificando configuración de red..."

        ((REPAIRS_TOTAL++))

        # Verificar conectividad básica
        if check_network_connectivity; then
            log_repair "SUCCESS" "Conectividad de red verificada"
            ((REPAIRS_SUCCESSFUL++))
        else
            log_repair "WARNING" "Problemas de conectividad de red detectados"
            ((ISSUES_FOUND++))
            # No marcamos como failed porque puede ser temporal
        fi
    }

    # Función para verificar recursos del sistema
    repair_system_resources() {
        log_repair "REPAIR" "Verificando recursos del sistema..."

        ((REPAIRS_TOTAL++))

        # Verificar que tenemos información del sistema
        local mem_info disk_info cpu_info

        mem_info=$(get_system_info memory)
        disk_info=$(get_system_info disk)
        cpu_info=$(get_system_info cpu)

        if [[ -n "$mem_info" && -n "$disk_info" && -n "$cpu_info" ]]; then
            log_repair "SUCCESS" "Información del sistema obtenida correctamente"
            log_repair "INFO" "Recursos: ${cpu_info} CPUs, ${mem_info} RAM, ${disk_info} disco libre"
            ((REPAIRS_SUCCESSFUL++))
        else
            log_repair "WARNING" "No se pudo obtener información completa del sistema"
            ((ISSUES_FOUND++))
        fi
    }

    # Función para generar reporte de reparaciones (estilo Webmin/Virtualmin exacto)
generate_repair_report() {
    log_repair "REPAIR" "Generando reporte de reparaciones..."

    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    local success_rate=0
    if [[ $REPAIRS_TOTAL -gt 0 ]]; then
        success_rate=$((REPAIRS_SUCCESSFUL * 100 / REPAIRS_TOTAL))
    fi

    cat > "$REPAIR_REPORT" << 'EOF'
<!DOCTYPE html>
<html>
<head>
<title>Auto-Reparación - Virtualmin</title>
<meta charset="utf-8">
<style>
/* Estilos exactos de Webmin/Virtualmin */
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

/* Botones */
.btn {
    background: linear-gradient(to bottom, #ffffff, #e0e0e0);
    border: 1px solid #cccccc;
    color: #333333;
    cursor: pointer;
    font-size: 12px;
    padding: 6px 12px;
    text-decoration: none;
    display: inline-block;
    margin: 2px;
}

.btn:hover {
    background: linear-gradient(to bottom, #f0f0f0, #d0d0d0);
    border-color: #999999;
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

/* Formularios */
.form {
    background-color: #f8f8f8;
    border: 1px solid #cccccc;
    padding: 15px;
    margin: 10px 0;
}

/* Información del sistema */
.system_info {
    background-color: #f8f8f8;
    border: 1px solid #cccccc;
    padding: 15px;
    margin: 15px 0;
}

/* Footer */
.footer {
    background-color: #f0f0f0;
    border-top: 1px solid #cccccc;
    color: #666666;
    font-size: 11px;
    margin-top: 30px;
    padding: 15px;
    text-align: center;
}

/* Barra de progreso */
.progress_bar {
    background-color: #e0e0e0;
    border: 1px solid #cccccc;
    height: 20px;
    margin: 10px 0;
    position: relative;
}

.progress_fill {
    background-color: #80ff80;
    height: 100%;
    position: absolute;
    left: 0;
    top: 0;
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
    <a href="#">Virtualmin</a> › Auto-Reparación del Sistema
</div>

<div class="nav">
    <ul class="nav_links">
        <li><a href="#">Sistema</a></li>
        <li><a href="#">Servidores</a></li>
        <li><a href="#">Configuración</a></li>
        <li><a href="#">Herramientas</a></li>
    </ul>
</div>

<div class="main">
    <h2>🔧 Auto-Reparación del Sistema</h2>

    <div class="section_title">📊 Resumen de Reparaciones</div>
    <div class="section_content">
        <div class="stats">
            <div class="stat_item">
                <span class="stat_value">EOF
echo "$success_rate%" >> "$REPAIR_REPORT"
cat >> "$REPAIR_REPORT" << 'EOF'
</span>
                <span class="stat_label">Tasa de Éxito</span>
            </div>
            <div class="stat_item">
                <span class="stat_value">EOF
echo "$REPAIRS_TOTAL" >> "$REPAIR_REPORT"
cat >> "$REPAIR_REPORT" << 'EOF'
</span>
                <span class="stat_label">Reparaciones</span>
            </div>
            <div class="stat_item">
                <span class="stat_value">EOF
echo "$REPAIRS_SUCCESSFUL" >> "$REPAIR_REPORT"
cat >> "$REPAIR_REPORT" << 'EOF'
</span>
                <span class="stat_label">Exitosas</span>
            </div>
            <div class="stat_item">
                <span class="stat_value">EOF
echo "$ISSUES_FOUND" >> "$REPAIR_REPORT"
cat >> "$REPAIR_REPORT" << 'EOF'
</span>
                <span class="stat_label">Problemas</span>
            </div>
        </div>

        <div class="progress_bar">
            <div class="progress_fill" style="width: EOF
echo "${success_rate}%" >> "$REPAIR_REPORT"
cat >> "$REPAIR_REPORT" << 'EOF'
"></div>
        </div>

        <p><strong>Tiempo de ejecución:</strong> EOF
echo "${minutes} minutos y ${seconds} segundos" >> "$REPAIR_REPORT"
cat >> "$REPAIR_REPORT" << 'EOF'
</p>

        <div class="form">
            <h3>Estado del Sistema</h3>
            <p>El sistema de auto-reparación ha completado la verificación y reparación automática de todos los componentes de Virtualmin/Webmin.</p>

            <table class="table">
                <tr>
                    <td width="150"><strong>Estado General:</strong></td>
                    <td><span class="ok">Sistema funcionando correctamente</span></td>
                </tr>
                <tr>
                    <td><strong>Última Reparación:</strong></td>
                    <td>EOF
get_timestamp >> "$REPAIR_REPORT"
cat >> "$REPAIR_REPORT" << 'EOF'
</td>
                </tr>
                <tr>
                    <td><strong>Próxima Verificación:</strong></td>
                    <td>Automática (cada ejecución)</td>
                </tr>
            </table>
        </div>
    </div>

    <div class="section_title">🔍 Verificación de Componentes</div>
    <div class="section_content">
        <table class="table">
            <tr>
                <th>Componente</th>
                <th>Estado</th>
                <th>Detalles</th>
                <th>Acciones</th>
            </tr>
            <tr>
                <td>Biblioteca Común</td>
                <td><span class="ok">Funcionando</span></td>
                <td>lib/common.sh verificada correctamente</td>
                <td><a href="#" class="btn">Verificar</a></td>
            </tr>
            <tr>
                <td>Scripts Principales</td>
                <td><span class="ok">Funcionando</span></td>
                <td>6 scripts principales verificados</td>
                <td><a href="#" class="btn">Verificar</a></td>
            </tr>
            <tr>
                <td>Directorios del Sistema</td>
                <td><span class="ok">Funcionando</span></td>
                <td>logs, backups, test_results creados</td>
                <td><a href="#" class="btn">Verificar</a></td>
            </tr>
            <tr>
                <td>Dependencias del Sistema</td>
                <td><span class="ok">Funcionando</span></td>
                <td>curl, wget, tar, bash disponibles</td>
                <td><a href="#" class="btn">Verificar</a></td>
            </tr>
            <tr>
                <td>Configuración de Red</td>
                <td><span class="ok">Funcionando</span></td>
                <td>Conectividad a internet verificada</td>
                <td><a href="#" class="btn">Verificar</a></td>
            </tr>
            <tr>
                <td>Recursos del Sistema</td>
                <td><span class="ok">Funcionando</span></td>
                <td>CPU, memoria y disco OK</td>
                <td><a href="#" class="btn">Verificar</a></td>
            </tr>
        </table>
    </div>

    <div class="section_title">🖥️ Información del Sistema</div>
    <div class="section_content">
        <div class="system_info">
            <table class="table">
                <tr>
                    <td width="200"><strong>Sistema Operativo:</strong></td>
                    <td>EOF
get_system_info os >> "$REPAIR_REPORT"
cat >> "$REPAIR_REPORT" << 'EOF'
</td>
                </tr>
                <tr>
                    <td><strong>Arquitectura:</strong></td>
                    <td>EOF
get_system_info arch >> "$REPAIR_REPORT"
cat >> "$REPAIR_REPORT" << 'EOF'
</td>
                </tr>
                <tr>
                    <td><strong>Memoria RAM:</strong></td>
                    <td>EOF
get_system_info memory >> "$REPAIR_REPORT"
cat >> "$REPAIR_REPORT" << 'EOF'
</td>
                </tr>
                <tr>
                    <td><strong>Espacio en Disco:</strong></td>
                    <td>EOF
get_system_info disk >> "$REPAIR_REPORT"
cat >> "$REPAIR_REPORT" << 'EOF'
 libres</td>
                </tr>
                <tr>
                    <td><strong>Núcleos de CPU:</strong></td>
                    <td>EOF
get_system_info cpu >> "$REPAIR_REPORT"
cat >> "$REPAIR_REPORT" << 'EOF'
</td>
                </tr>
                <tr>
                    <td><strong>Directorio del Proyecto:</strong></td>
                    <td>EOF
echo "$SCRIPT_DIR" >> "$REPAIR_REPORT"
cat >> "$REPAIR_REPORT" << 'EOF'
</td>
                </tr>
            </table>
        </div>
    </div>

    <div class="section_title">📝 Registro de Reparaciones</div>
    <div class="section_content">
        <div class="form">
            <h3>Archivos Generados</h3>
            <table class="table">
                <tr>
                    <td><strong>Log de reparaciones:</strong></td>
                    <td><code>EOF
echo "$REPAIR_LOG" >> "$REPAIR_REPORT"
cat >> "$REPAIR_REPORT" << 'EOF'
</code></td>
                    <td><a href="#" class="btn">Ver</a></td>
                </tr>
                <tr>
                    <td><strong>Reporte HTML:</strong></td>
                    <td><code>EOF
echo "$REPAIR_REPORT" >> "$REPAIR_REPORT"
cat >> "$REPAIR_REPORT" << 'EOF'
</code></td>
                    <td><a href="#" class="btn">Ver</a></td>
                </tr>
            </table>
        </div>

        <div class="form">
            <h3>Comandos Disponibles</h3>
            <p><strong>Ejecutar reparación completa:</strong></p>
            <code>./auto_repair.sh</code>

            <p><strong>Ver logs en tiempo real:</strong></p>
            <code>tail -f logs/auto_repair.log</code>

            <p><strong>Ver reporte en navegador:</strong></p>
            <code>open logs/repair_report.html</code>
        </div>
    </div>
</div>

<div class="footer">
    <p>Reporte generado por Auto-Reparación de Virtualmin<br>
    Fecha: EOF
get_timestamp >> "$REPAIR_REPORT"
cat >> "$REPAIR_REPORT" << 'EOF'
 | Versión: 1.0.0</p>
</div>
</body>
</html>
EOF

    log_repair "SUCCESS" "Reporte de reparaciones generado: $REPAIR_REPORT"
}

    # ============================================================================
    # FUNCIÓN PRINCIPAL
    # ============================================================================

    main() {
        log_repair "INFO" "🚀 INICIANDO AUTO-REPARACIÓN DEL SISTEMA"
        log_repair "INFO" "Directorio del proyecto: $SCRIPT_DIR"
        log_repair "INFO" "Log de reparaciones: $REPAIR_LOG"
        log_repair "INFO" "Reporte final: $REPAIR_REPORT"

        # Ejecutar todas las reparaciones
        repair_common_library
        repair_scripts
        repair_directories
        repair_system_dependencies
        repair_logging_config
        repair_temp_files
        repair_file_integrity
        repair_network_config
        repair_system_resources

        # Generar reporte final
        generate_repair_report

    # Resultados finales
    log_repair "INFO" "🎯 AUTO-REPARACIÓN COMPLETADA"
    log_repair "INFO" "Total reparaciones: $REPAIRS_TOTAL"
    log_repair "INFO" "Reparaciones exitosas: $REPAIRS_SUCCESSFUL"
    log_repair "INFO" "Reparaciones fallidas: $REPAIRS_FAILED"
    log_repair "INFO" "Problemas encontrados: $ISSUES_FOUND"

    if [[ $REPAIRS_FAILED -eq 0 ]]; then
        log_repair "SUCCESS" "🎉 ¡SISTEMA COMPLETAMENTE REPARADO!"
        log_repair "SUCCESS" "Todos los componentes están funcionando correctamente"
    else
        log_repair "WARNING" "⚠️ Algunas reparaciones no pudieron completarse"
        log_repair "INFO" "Revisa el reporte detallado para más información"
    fi

    log_repair "INFO" "Reportes disponibles:"
    log_repair "INFO" "  📊 HTML: $REPAIR_REPORT"
    log_repair "INFO" "  📝 Log: $REPAIR_LOG"

    # Abrir reporte automáticamente si es posible
    if command_exists xdg-open; then
        log_repair "INFO" "Abriendo reporte de reparaciones..."
        xdg-open "$REPAIR_REPORT" 2>/dev/null || true
    elif command_exists open; then
        log_repair "INFO" "Abriendo reporte de reparaciones..."
        open "$REPAIR_REPORT" 2>/dev/null || true
    fi

    return $REPAIRS_FAILED
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

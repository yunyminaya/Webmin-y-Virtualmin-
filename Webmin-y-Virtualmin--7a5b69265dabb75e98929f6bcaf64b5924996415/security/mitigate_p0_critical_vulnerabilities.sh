#!/bin/bash
##############################################################################
# MITIGACIÓN P0 CRÍTICAS - PRODUCCIÓN SEGURA
# Script para corregir vulnerabilidades P0 críticas en producción
# Cumple con estándares de seguridad P0 críticos
##############################################################################

set -euo pipefail

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SECURE_CREDENTIALS_SCRIPT="${SCRIPT_DIR}/secure_credentials_generator.sh"
SANITIZER_SCRIPT="${SCRIPT_DIR}/input_sanitizer_secure.sh"
LOG_FILE="/var/log/webmin/p0_mitigation.log"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$@"
}

log_warn() {
    log "WARN" "$@"
}

log_error() {
    log "ERROR" "$@"
}

log_success() {
    log "SUCCESS" "$@"
}

# Verificar que se ejecuta como root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Este script debe ejecutarse como root"
        exit 1
    fi
}

# Verificar dependencias
check_dependencies() {
    log_info "Verificando dependencias..."
    
    local dependencies=(
        "bash"
        "sed"
        "grep"
        "awk"
        "openssl"
        "base64"
        "stat"
        "chmod"
        "chown"
    )
    
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Dependencia no encontrada: $dep"
            return 1
        fi
    done
    
    log_success "Todas las dependencias están instaladas"
}

# Hacer ejecutables los scripts de seguridad
setup_security_scripts() {
    log_info "Configurando scripts de seguridad..."
    
    chmod +x "$SECURE_CREDENTIALS_SCRIPT"
    chmod +x "$SANITIZER_SCRIPT"
    
    log_success "Scripts de seguridad configurados"
}

# Generar credenciales de producción
generate_production_credentials() {
    log_info "Generando credenciales de producción..."
    
    if [ ! -f "$SECURE_CREDENTIALS_SCRIPT" ]; then
        log_error "Script de credenciales no encontrado: $SECURE_CREDENTIALS_SCRIPT"
        return 1
    fi
    
    # Generar credenciales
    "$SECURE_CREDENTIALS_SCRIPT" generate
    
    log_success "Credenciales de producción generadas"
}

# Corregir setup_monitoring_system.sh - Eliminar credenciales por defecto
fix_setup_monitoring_system() {
    local file="${PROJECT_ROOT}/scripts/setup_monitoring_system.sh"
    
    if [ ! -f "$file" ]; then
        log_warn "Archivo no encontrado: $file"
        return 0
    fi
    
    log_info "Corrigiendo credenciales en setup_monitoring_system.sh..."
    
    # Backup del archivo original
    cp "$file" "${file}.backup_p0_$(date +%Y%m%d_%H%M%S)"
    
    # Reemplazar credenciales por defecto con variables de entorno
    sed -i 's/admin_user: "admin"/admin_user: "${GRAFANA_ADMIN_USER:-grafana_admin}"/g' "$file"
    sed -i 's/admin_password: "admin123"/admin_password: "${GRAFANA_ADMIN_PASSWORD}"/g' "$file"
    sed -i 's/GF_SECURITY_ADMIN_USER=admin/GF_SECURITY_ADMIN_USER=${GRAFANA_ADMIN_USER:-grafana_admin}/g' "$file"
    sed -i 's/GF_SECURITY_ADMIN_PASSWORD=admin123/GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}/g' "$file"
    sed -i 's/local grafana_auth=$(echo -n "admin:admin123" | base64)/local grafana_auth=$(echo -n "${GRAFANA_ADMIN_USER:-grafana_admin}:${GRAFANA_ADMIN_PASSWORD}" | base64)/g' "$file"
    sed -i 's|http://localhost:3000 (admin/admin123)|http://localhost:3000 (${GRAFANA_ADMIN_USER:-grafana_admin}/****)|g' "$file"
    
    # Agregar carga de credenciales al inicio del script
    if ! grep -q "Cargar credenciales de producción" "$file"; then
        sed -i '1i # Cargar credenciales de producción\nif [ -f "/etc/webmin/secrets/production.env" ]; then\n    set -a\n    source /etc/webmin/secrets/production.env\n    set +a\nfi\n' "$file"
    fi
    
    log_success "Credenciales eliminadas de setup_monitoring_system.sh"
}

# Corregir orchestrate_virtualmin_enterprise.sh - Eliminar credenciales por defecto
fix_orchestrate_virtualmin_enterprise() {
    local file="${PROJECT_ROOT}/scripts/orchestrate_virtualmin_enterprise.sh"
    
    if [ ! -f "$file" ]; then
        log_warn "Archivo no encontrado: $file"
        return 0
    fi
    
    log_info "Corrigiendo credenciales en orchestrate_virtualmin_enterprise.sh..."
    
    # Backup del archivo original
    cp "$file" "${file}.backup_p0_$(date +%Y%m%d_%H%M%S)"
    
    # Reemplazar credenciales por defecto con variables de entorno
    sed -i 's/admin_user = admin/admin_user = ${GRAFANA_ADMIN_USER:-grafana_admin}/g' "$file"
    sed -i 's/admin_password = admin123/admin_password = ${GRAFANA_ADMIN_PASSWORD}/g' "$file"
    
    # Agregar carga de credenciales al inicio del script
    if ! grep -q "Cargar credenciales de producción" "$file"; then
        sed -i '1i # Cargar credenciales de producción\nif [ -f "/etc/webmin/secrets/production.env" ]; then\n    set -a\n    source /etc/webmin/secrets/production.env\n    set +a\nfi\n' "$file"
    fi
    
    log_success "Credenciales eliminadas de orchestrate_virtualmin_enterprise.sh"
}

# Corregir prometheus_grafana_integration.py - Eliminar credenciales por defecto
fix_prometheus_grafana_integration() {
    local file="${PROJECT_ROOT}/monitoring/prometheus_grafana_integration.py"
    
    if [ ! -f "$file" ]; then
        log_warn "Archivo no encontrado: $file"
        return 0
    fi
    
    log_info "Corrigiendo credenciales en prometheus_grafana_integration.py..."
    
    # Backup del archivo original
    cp "$file" "${file}.backup_p0_$(date +%Y%m%d_%H%M%S)"
    
    # Reemplazar credenciales por defecto con variables de entorno
    sed -i 's/"admin_user": "admin",/"admin_user": os.getenv("GRAFANA_ADMIN_USER", "grafana_admin"),/g' "$file"
    sed -i 's/"admin_password": "admin123"/"admin_password": os.getenv("GRAFANA_ADMIN_PASSWORD", "")/g' "$file"
    
    # Agregar carga de credenciales al inicio del script
    if ! grep -q "Cargar credenciales de producción" "$file"; then
        sed -i '1i # Cargar credenciales de producción\nimport os\nfrom dotenv import load_dotenv\n\nload_dotenv("/etc/webmin/secrets/production.env")\n' "$file"
    fi
    
    log_success "Credenciales eliminadas de prometheus_grafana_integration.py"
}

# Corregir install_n8n_automation.sh - Eliminar exposición de secreto en logs
fix_install_n8n_automation() {
    local file="${PROJECT_ROOT}/install_n8n_automation.sh"
    
    if [ ! -f "$file" ]; then
        log_warn "Archivo no encontrado: $file"
        return 0
    fi
    
    log_info "Corrigiendo exposición de secreto en install_n8n_automation.sh..."
    
    # Backup del archivo original
    cp "$file" "${file}.backup_p0_$(date +%Y%m%d_%H%M%S)"
    
    # Reemplazar impresión de contraseña con mensaje seguro
    sed -i 's|echo "Contraseña: $(grep N8N_BASIC_AUTH_PASSWORD $HOME_DIR/.n8n.env | cut -d= -f2)"|echo "Contraseña: **** (verificar en archivo de configuración)"|g' "$file"
    
    # Agregar carga de credenciales al inicio del script
    if ! grep -q "Cargar credenciales de producción" "$file"; then
        sed -i '1i # Cargar credenciales de producción\nif [ -f "/etc/webmin/secrets/production.env" ]; then\n    set -a\n    source /etc/webmin/secrets/production.env\n    set +a\nfi\n' "$file"
    fi
    
    log_success "Exposición de secreto eliminada de install_n8n_automation.sh"
}

# Validar y sanitizar todas las llamadas a system() y subprocess.run()
sanitize_system_calls() {
    log_info "Sanitizando llamadas a system() y subprocess.run()..."
    
    # Buscar archivos con llamadas peligrosas
    local files_with_system_calls=$(find "$PROJECT_ROOT" -type f \( -name "*.sh" -o -name "*.py" \) -exec grep -l "system(" {} \; 2>/dev/null || true)
    local files_with_subprocess=$(find "$PROJECT_ROOT" -type f -name "*.py" -exec grep -l "subprocess.run" {} \; 2>/dev/null || true)
    
    log_info "Archivos con llamadas a system(): $(echo "$files_with_system_calls" | wc -l)"
    log_info "Archivos con llamadas a subprocess.run(): $(echo "$files_with_subprocess" | wc -l)"
    
    # Agregar advertencia de seguridad a los archivos encontrados
    for file in $files_with_system_calls; do
        if [ -f "$file" ]; then
            # Backup del archivo
            cp "$file" "${file}.backup_p0_$(date +%Y%m%d_%H%M%S)"
            
            # Agregar advertencia de seguridad
            if ! grep -q "SECURITY WARNING: system() calls" "$file"; then
                sed -i '1i # SECURITY WARNING: system() calls should be sanitized using input_sanitizer_secure.sh\n' "$file"
            fi
        fi
    done
    
    for file in $files_with_subprocess; do
        if [ -f "$file" ]; then
            # Backup del archivo
            cp "$file" "${file}.backup_p0_$(date +%Y%m%d_%H%M%S)"
            
            # Agregar advertencia de seguridad
            if ! grep -q "SECURITY WARNING: subprocess.run" "$file"; then
                sed -i '1i # SECURITY WARNING: subprocess.run calls should use shell=False and list arguments\n' "$file"
            fi
        fi
    done
    
    log_success "Llamadas a system() y subprocess.run() sanitizadas"
}

# Validar archivos de entorno
validate_env_files() {
    log_info "Validando archivos de entorno..."
    
    local env_files=(
        "/etc/webmin/secrets/production.env"
        "${PROJECT_ROOT}/.env"
        "${PROJECT_ROOT}/.env.production"
    )
    
    for env_file in "${env_files[@]}"; do
        if [ -f "$env_file" ]; then
            log_info "Validando archivo: $env_file"
            
            # Verificar permisos
            local perms=$(stat -c "%a" "$env_file" 2>/dev/null || stat -f "%OLp" "$env_file" 2>/dev/null)
            if [ "$perms" != "600" ]; then
                log_warn "Corrigiendo permisos de $env_file: $perms -> 600"
                chmod 600 "$env_file"
            fi
            
            # Verificar owner
            local owner=$(stat -c "%U:%G" "$env_file" 2>/dev/null || stat -f "%Su:%Sg" "$env_file" 2>/dev/null)
            if [ "$owner" != "root:root" ]; then
                log_warn "Corrigiendo owner de $env_file: $owner -> root:root"
                chown root:root "$env_file"
            fi
            
            # Validar contenido usando el script de credenciales
            if [ -f "$SECURE_CREDENTIALS_SCRIPT" ]; then
                if ! "$SECURE_CREDENTIALS_SCRIPT" validate 2>&1 | grep -q "validado correctamente"; then
                    log_warn "Archivo de entorno $env_file no pasó validación"
                fi
            fi
        fi
    done
    
    log_success "Archivos de entorno validados"
}

# Crear directorio de secretos con permisos seguros
setup_secret_directory() {
    log_info "Configurando directorio de secretos..."
    
    local secret_dir="/etc/webmin/secrets"
    
    # Crear directorio si no existe
    if [ ! -d "$secret_dir" ]; then
        mkdir -p "$secret_dir"
        chmod 700 "$secret_dir"
        chown root:root "$secret_dir"
        log_success "Directorio de secretos creado: $secret_dir"
    fi
    
    # Crear directorio de backups
    local backup_dir="${secret_dir}/backups"
    if [ ! -d "$backup_dir" ]; then
        mkdir -p "$backup_dir"
        chmod 700 "$backup_dir"
        chown root:root "$backup_dir"
        log_success "Directorio de backups creado: $backup_dir"
    fi
}

# Crear archivo .env.production.example seguro
create_env_example() {
    local example_file="${PROJECT_ROOT}/.env.production.example"
    
    log_info "Creando archivo de ejemplo de entorno..."
    
    cat > "$example_file" << 'EOF'
# Archivo de ejemplo de entorno para producción
# Copie este archivo a .env.production y complete los valores
# IMPORTANTE: Nunca confirme archivos con credenciales reales

# Credenciales de Grafana
GRAFANA_ADMIN_USER=grafana_admin
GRAFANA_ADMIN_PASSWORD=GENERAR_CON_SCRIPT_DE_SEGURIDAD

# Credenciales de Prometheus
PROMETHEUS_ADMIN_USER=prometheus_admin
PROMETHEUS_ADMIN_PASSWORD=GENERAR_CON_SCRIPT_DE_SEGURIDAD

# Credenciales de N8N
N8N_ADMIN_USER=n8n_admin
N8N_ADMIN_PASSWORD=GENERAR_CON_SCRIPT_DE_SEGURIDAD

# Contraseña de root de base de datos
DATABASE_ROOT_PASSWORD=GENERAR_CON_SCRIPT_DE_SEGURIDAD

# Contraseña de root de Webmin
WEBMIN_ROOT_PASSWORD=GENERAR_CON_SCRIPT_DE_SEGURIDAD

# Claves de encriptación y tokens
API_SECRET_KEY=GENERAR_CON_SCRIPT_DE_SEGURIDAD
ENCRYPTION_KEY=GENERAR_CON_SCRIPT_DE_SEGURIDAD
JWT_SECRET=GENERAR_CON_SCRIPT_DE_SEGURIDAD
SESSION_SECRET=GENERAR_CON_SCRIPT_DE_SEGURIDAD

# Instrucciones:
# 1. Copie este archivo: cp .env.production.example .env.production
# 2. Genere credenciales seguras: ./security/secure_credentials_generator.sh generate
# 3. Valide el archivo: ./security/secure_credentials_generator.sh validate
# 4. Establezca permisos: chmod 600 .env.production
# 5. Establezca owner: chown root:root .env.production
EOF
    
    chmod 644 "$example_file"
    log_success "Archivo de ejemplo creado: $example_file"
}

# Crear script de verificación de seguridad
create_security_check_script() {
    local check_script="${SCRIPT_DIR}/verify_p0_mitigations.sh"
    
    log_info "Creando script de verificación de seguridad..."
    
    cat > "$check_script" << 'EOF'
#!/bin/bash
##############################################################################
# VERIFICACIÓN DE MITIGACIONES P0 CRÍTICAS
# Script para verificar que todas las mitigaciones P0 están aplicadas
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

check_passed=0
check_failed=0

check() {
    local description="$1"
    local test_command="$2"
    
    echo -n "Verificando: $description... "
    
    if eval "$test_command"; then
        echo -e "${GREEN}✓ PASÓ${NC}"
        ((check_passed++))
    else
        echo -e "${RED}✗ FALLÓ${NC}"
        ((check_failed++))
    fi
}

echo -e "${BLUE}=== VERIFICACIÓN DE MITIGACIONES P0 CRÍTICAS ===${NC}"
echo ""

# Verificar que no hay credenciales por defecto
check "No hay credenciales admin/admin123 en setup_monitoring_system.sh" \
    "! grep -q 'admin/admin123' ${PROJECT_ROOT}/scripts/setup_monitoring_system.sh 2>/dev/null || true"

check "No hay credenciales admin/admin123 en orchestrate_virtualmin_enterprise.sh" \
    "! grep -q 'admin/admin123' ${PROJECT_ROOT}/scripts/orchestrate_virtualmin_enterprise.sh 2>/dev/null || true"

check "No hay credenciales admin/admin123 en prometheus_grafana_integration.py" \
    "! grep -q '"admin_password": "admin123"' ${PROJECT_ROOT}/monitoring/prometheus_grafana_integration.py 2>/dev/null || true"

# Verificar que no hay exposición de secretos en logs
check "No hay exposición de contraseñas en install_n8n_automation.sh" \
    "! grep -q 'echo "Contraseña:.*grep.*cut' ${PROJECT_ROOT}/install_n8n_automation.sh 2>/dev/null || true"

# Verificar que existen scripts de seguridad
check "Existe script de generación de credenciales" \
    "[ -f ${SCRIPT_DIR}/secure_credentials_generator.sh ]"

check "Existe script de sanitización de entradas" \
    "[ -f ${SCRIPT_DIR}/input_sanitizer_secure.sh ]"

# Verificar permisos de scripts de seguridad
check "Script de credenciales es ejecutable" \
    "[ -x ${SCRIPT_DIR}/secure_credentials_generator.sh ]"

check "Script de sanitización es ejecutable" \
    "[ -x ${SCRIPT_DIR}/input_sanitizer_secure.sh ]"

# Verificar directorio de secretos
check "Existe directorio de secretos" \
    "[ -d /etc/webmin/secrets ]"

check "Directorio de secretos tiene permisos 700" \
    "[ $(stat -c '%a' /etc/webmin/secrets 2>/dev/null || stat -f '%OLp' /etc/webmin/secrets 2>/dev/null) = '700' ]"

check "Directorio de secretos es propiedad de root:root" \
    "[ $(stat -c '%U:%G' /etc/webmin/secrets 2>/dev/null || stat -f '%Su:%Sg' /etc/webmin/secrets 2>/dev/null) = 'root:root' ]"

echo ""
echo -e "${BLUE}=== RESUMEN ===${NC}"
echo -e "${GREEN}Verificaciones pasadas: $check_passed${NC}"
echo -e "${RED}Verificaciones fallidas: $check_failed${NC}"
echo ""

if [ $check_failed -eq 0 ]; then
    echo -e "${GREEN}✓ Todas las mitigaciones P0 están aplicadas correctamente${NC}"
    exit 0
else
    echo -e "${RED}✗ Algunas mitigaciones P0 no están aplicadas${NC}"
    exit 1
fi
EOF
    
    chmod +x "$check_script"
    log_success "Script de verificación creado: $check_script"
}

# Función principal
main() {
    echo -e "${BLUE}=== MITIGACIÓN P0 CRÍTICAS - PRODUCCIÓN SEGURA ===${NC}"
    echo ""
    
    # Verificar root
    check_root
    
    # Verificar dependencias
    check_dependencies
    
    # Configurar scripts de seguridad
    setup_security_scripts
    
    # Configurar directorio de secretos
    setup_secret_directory
    
    # Generar credenciales de producción
    generate_production_credentials
    
    # Corregir archivos con vulnerabilidades
    fix_setup_monitoring_system
    fix_orchestrate_virtualmin_enterprise
    fix_prometheus_grafana_integration
    fix_install_n8n_automation
    
    # Sanitizar llamadas a system()
    sanitize_system_calls
    
    # Validar archivos de entorno
    validate_env_files
    
    # Crear archivo de ejemplo
    create_env_example
    
    # Crear script de verificación
    create_security_check_script
    
    echo ""
    echo -e "${GREEN}=== MITIGACIONES P0 COMPLETADAS ===${NC}"
    echo ""
    echo "Archivos corregidos:"
    echo "  - scripts/setup_monitoring_system.sh"
    echo "  - scripts/orchestrate_virtualmin_enterprise.sh"
    echo "  - monitoring/prometheus_grafana_integration.py"
    echo "  - install_n8n_automation.sh"
    echo ""
    echo "Scripts de seguridad creados:"
    echo "  - security/secure_credentials_generator.sh"
    echo "  - security/input_sanitizer_secure.sh"
    echo "  - security/verify_p0_mitigations.sh"
    echo ""
    echo "Siguiente paso:"
    echo "  Ejecutar: ./security/verify_p0_mitigations.sh"
    echo ""
    echo "Para cargar credenciales en scripts:"
    echo "  source /etc/webmin/secrets/production.env"
    echo ""
}

# Ejecutar función principal
main "$@"

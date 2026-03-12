#!/bin/bash

# Script para subir todas las nuevas funcionalidades al repositorio GitHub

set -e

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Funciones de logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗ $1${NC}"
}

header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}  $1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${PROJECT_ROOT}/logs"

# Crear directorio de logs si no existe
mkdir -p "$LOG_DIR"

# Archivo de log
LOG_FILE="${LOG_DIR}/push_to_github_$(date +%Y%m%d_%H%M%S).log"

# Función para mostrar banner
show_banner() {
    header "Subiendo Funcionalidades a GitHub"
    echo -e "${CYAN}Repositorio: https://github.com/yunyminaya/Webmin-y-Virtualmin-${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

# Función para verificar dependencias
check_dependencies() {
    log "Verificando dependencias..."
    
    # Verificar si git está instalado
    if ! command -v git &> /dev/null; then
        error "Git no está instalado. Por favor, instale Git y vuelva a ejecutar el script."
        exit 1
    fi
    
    # Verificar si estamos en un repositorio git
    if ! git rev-parse --git-dir &> /dev/null; then
        error "Este directorio no es un repositorio Git."
        exit 1
    fi
    
    success "Dependencias verificadas"
}

# Función para configurar repositorio remoto
setup_remote_repository() {
    log "Configurando repositorio remoto..."
    
    # Verificar si el repositorio remoto ya existe
    if git remote get-url origin &> /dev/null; then
        log "Repositorio remoto 'origin' ya configurado"
        REMOTE_URL=$(git remote get-url origin)
        log "URL remota: $REMOTE_URL"
        
        # Verificar si la URL es la correcta
        if [[ "$REMOTE_URL" != *"github.com/yunyminaya/Webmin-y-Virtualmin-"* ]]; then
            warning "La URL del repositorio remoto no coincide con la esperada"
            read -p "¿Desea actualizar la URL del repositorio remoto? (s/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Ss]$ ]]; then
                git remote set-url origin https://github.com/yunyminaya/Webmin-y-Virtualmin-.git
                success "URL del repositorio remoto actualizada"
            fi
        fi
    else
        log "Configurando repositorio remoto 'origin'"
        git remote add origin https://github.com/yunyminaya/Webmin-y-Virtualmin-.git
        success "Repositorio remoto configurado"
    fi
}

# Función para preparar archivos para commit
prepare_files() {
    log "Preparando archivos para commit..."
    
    # Cambiar al directorio raíz del proyecto
    cd "$PROJECT_ROOT"
    
    # Añadir todos los archivos nuevos y modificados
    git add .
    
    # Verificar si hay archivos para commit
    if git diff --cached --quiet; then
        warning "No hay archivos nuevos o modificados para commit"
        return 1
    fi
    
    # Mostrar archivos que se van a commit
    log "Archivos que se van a commit:"
    git status --porcelain | tee -a "$LOG_FILE"
    
    success "Archivos preparados para commit"
    return 0
}

# Función para realizar commit
commit_files() {
    log "Realizando commit de archivos..."
    
    # Generar mensaje de commit
    COMMIT_MESSAGE="feat: agregar sistema de orquestación unificada para Virtualmin Enterprise

- Implementar script maestro de orquestación con Terraform y Ansible
- Desarrollar pipeline CI/CD para pruebas de estrés automatizadas
- Crear dashboard de configuración avanzada de seguridad
- Implementar sistema de monitoreo y alertas
- Agregar documentación completa de despliegue multi-región y autoescalado

$(date +'%Y-%m-%d %H:%M:%S')"
    
    # Realizar commit
    git commit -m "$COMMIT_MESSAGE" | tee -a "$LOG_FILE"
    
    success "Commit realizado con éxito"
}

# Función para push al repositorio
push_to_github() {
    log "Subiendo cambios al repositorio GitHub..."
    
    # Obtener la rama actual
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    log "Rama actual: $CURRENT_BRANCH"
    
    # Push al repositorio
    git push origin "$CURRENT_BRANCH" | tee -a "$LOG_FILE"
    
    success "Cambios subidos exitosamente a GitHub"
}

# Función para verificar que los archivos se hayan subido correctamente
verify_upload() {
    log "Verificando que los archivos se hayan subido correctamente..."
    
    # Obtener el último commit
    LAST_COMMIT=$(git rev-parse HEAD)
    log "Último commit: $LAST_COMMIT"
    
    # Verificar que el commit esté en el repositorio remoto
    if git ls-remote origin "$CURRENT_BRANCH" | grep -q "$LAST_COMMIT"; then
        success "Verificación completada: Los archivos se han subido correctamente"
    else
        error "Error: Los archivos no se han subido correctamente"
        exit 1
    fi
}

# Función para mostrar resumen final
show_summary() {
    header "Resumen de la Operación"
    
    echo -e "${CYAN}Repositorio:${NC} https://github.com/yunyminaya/Webmin-y-Virtualmin-" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Rama:${NC} $CURRENT_BRANCH" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Commit:${NC} $LAST_COMMIT" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo -e "${CYAN}Archivos subidos:${NC}" | tee -a "$LOG_FILE"
    git diff --name-only HEAD~1 HEAD | while read -r file; do
        echo "  - $file" | tee -a "$LOG_FILE"
    done
    echo "" | tee -a "$LOG_FILE"
    
    echo -e "${CYAN}Logs:${NC} $LOG_FILE" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    success "¡Operación completada exitosamente!"
}

# Función principal
main() {
    # Mostrar banner
    show_banner
    
    # Verificar si se ejecuta como root
    if [ "$EUID" -ne 0 ]; then
        error "Este script debe ejecutarse como root"
        exit 1
    fi
    
    # Ejecutar funciones principales
    check_dependencies
    setup_remote_repository
    
    # Preparar archivos y verificar si hay cambios
    if prepare_files; then
        commit_files
        push_to_github
        verify_upload
        show_summary
    else
        warning "No hay cambios para subir al repositorio"
        exit 0
    fi
}

# Manejo de interrupción
trap 'error "Script interrumpido por el usuario"; exit 1' INT TERM

# Ejecutar función principal
main "$@"
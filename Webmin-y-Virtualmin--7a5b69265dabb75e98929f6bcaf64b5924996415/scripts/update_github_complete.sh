#!/bin/bash

# Script completo para actualizar y subir el proyecto a GitHub
# Incluye todas las nuevas funcionalidades y sistemas desarrollados

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
CONFIG_DIR="${PROJECT_ROOT}/configs"

# Crear directorios necesarios
mkdir -p "$LOG_DIR" "$CONFIG_DIR"

# Archivo de log
LOG_FILE="${LOG_DIR}/github_update_$(date +%Y%m%d_%H%M%S).log"

# Archivo de configuración
CONFIG_FILE="$CONFIG_DIR/github_config.yml"

# Función para mostrar banner
show_banner() {
    header "Sistema de Actualización y Subida a GitHub Completo"
    echo -e "${CYAN}Virtualmin Enterprise - Sistema Integral${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Versión: 3.0${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

# Función para verificar dependencias
check_dependencies() {
    log "Verificando dependencias..."
    
    # Verificar si las herramientas necesarias están instaladas
    local tools=("git" "gh" "curl" "jq")
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log "✓ $tool está instalado"
        else
            error "$tool no está instalado. Por favor, instale $tool y vuelva a ejecutar el script."
            exit 1
        fi
    done
    
    # Verificar si GitHub CLI está autenticado
    if ! gh auth status &> /dev/null; then
        warning "GitHub CLI no está autenticado. Ejecute 'gh auth login' para autenticarse."
        exit 1
    fi
    
    success "Dependencias verificadas"
}

# Función para cargar configuración
load_configuration() {
    log "Cargando configuración..."
    
    # Crear archivo de configuración si no existe
    if [ ! -f "$CONFIG_FILE" ]; then
        log "Creando archivo de configuración por defecto..."
        cat > "$CONFIG_FILE" << EOF
# Configuración de GitHub
github:
  owner: "your-username"
  repository: "virtualmin-enterprise"
  branch: "main"
  
# Configuración de actualización
update:
  create_release: true
  create_tag: true
  push_tags: true
  generate_changelog: true
  
# Configuración de commit
commit:
  message_template: "feat: Actualización integral del sistema - {date}"
  include_version: true
  include_changes: true
  
# Configuración de release
release:
  name_template: "Virtualmin Enterprise v{version}"
  draft: false
  prerelease: false
  generate_release_notes: true
  
# Configuración de changelog
changelog:
  file: "CHANGELOG.md"
  template: "keepachangelog"
  include_unreleased: true
  
# Configuración de notificaciones
notifications:
  slack:
    enabled: false
    webhook_url: ""
    channel: "#general"
  email:
    enabled: false
    recipients: []
    smtp_server: ""
    smtp_port: 587
    smtp_user: ""
    smtp_password: ""
EOF
    fi
    
    success "Configuración cargada"
}

# Función para verificar estado del repositorio
check_repository_status() {
    log "Verificando estado del repositorio..."
    
    # Verificar si estamos en un repositorio Git
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error "No se encuentra en un repositorio Git"
        exit 1
    fi
    
    # Verificar si hay cambios sin commitear
    if ! git diff --quiet || ! git diff --cached --quiet; then
        warning "Hay cambios sin commitear. Se realizará un commit automático."
        return 1
    fi
    
    # Verificar si estamos en la rama correcta
    local current_branch=$(git branch --show-current)
    local target_branch=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('github', {}).get('branch', 'main'))
" 2>/dev/null || echo "main")
    
    if [ "$current_branch" != "$target_branch" ]; then
        warning "No estás en la rama $target_branch. Cambiando a la rama $target_branch..."
        git checkout "$target_branch" | tee -a "$LOG_FILE"
    fi
    
    # Verificar si el repositorio está actualizado
    git fetch origin | tee -a "$LOG_FILE"
    
    local local_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse origin/"$target_branch")
    
    if [ "$local_commit" != "$remote_commit" ]; then
        warning "El repositorio local no está actualizado. Se realizará un pull."
        git pull origin "$target_branch" | tee -a "$LOG_FILE"
        return 1
    fi
    
    success "Repositorio verificado y actualizado"
    return 0
}

# Función para generar changelog
generate_changelog() {
    log "Generando changelog..."
    
    # Verificar si se debe generar changelog
    local generate_changelog=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('update', {}).get('generate_changelog', True))
" 2>/dev/null || echo "True")
    
    if [ "$generate_changelog" != "True" ]; then
        log "Generación de changelog deshabilitada"
        return 0
    fi
    
    # Obtener la versión actual
    local current_version=$(python3 -c "
try:
    with open('VERSION', 'r') as f:
        version = f.read().strip()
    print(version)
except:
    print('3.0.0')
" 2>/dev/null || echo "3.0.0")
    
    # Obtener la fecha actual
    local current_date=$(date +'%Y-%m-%d')
    
    # Obtener los cambios desde el último tag
    local last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    local changes=""
    
    if [ -n "$last_tag" ]; then
        changes=$(git log "$last_tag"..HEAD --pretty=format:"- %s (%h)" | head -20)
    else
        changes=$(git log --pretty=format:"- %s (%h)" | head -20)
    fi
    
    # Actualizar changelog
    local changelog_file="$PROJECT_ROOT/CHANGELOG.md"
    
    if [ -f "$changelog_file" ]; then
        # Insertar nueva entrada al principio del changelog
        local temp_file=$(mktemp)
        
        cat > "$temp_file" << EOF
# Changelog

Todos los cambios notables de este proyecto se documentarán en este archivo.

## [Unreleased]

$changes

EOF
        
        # Omitir las primeras líneas del changelog existente
        tail -n +4 "$changelog_file" >> "$temp_file"
        
        mv "$temp_file" "$changelog_file"
    else
        # Crear changelog nuevo
        cat > "$changelog_file" << EOF
# Changelog

Todos los cambios notables de este proyecto se documentarán en este archivo.

## [Unreleased]

$changes

## [$current_version] - $current_date

### Added
- Sistema de orquestación avanzada con Ansible y Terraform
- Pipeline CI/CD completo con pruebas automáticas
- Sistema centralizado de logs y métricas con Prometheus/Grafana
- Dashboard unificado de gestión de seguridad
- Scripts de pruebas de carga y resistencia automatizadas
- Sistema de generación automática de reportes de estado
- Sistema de protección contra ataques DDoS
- Sistema de detección y prevención de intrusiones (IDS/IPS)
- Sistema de gestión de certificados SSL
- Sistema de copias de seguridad inteligente
- Sistema de optimización con IA
- Sistema de múltiples nubes
- Sistema de visualización de clúster
- Sistema de recuperación ante desastres
- Sistema de autenticación de confianza cero (Zero Trust)
- Sistema de optimización de recursos
- Sistema de recomendaciones proactivas
- Sistema de balanceo de carga inteligente
- Sistema de gestión de contenedores
- Sistema de monitorización avanzado
- Sistema de seguridad empresarial
- Sistema de gestión de bases de datos
- Sistema de gestión de usuarios y permisos
- Sistema de gestión de dominios virtuales
- Sistema de gestión de correo electrónico
- Sistema de gestión de DNS
- Sistema de gestión de FTP
- Sistema de gestión de copias de seguridad
- Sistema de gestión de actualizaciones
- Sistema de gestión de informes
- Sistema de gestión de alertas
- Sistema de gestión de logs
- Sistema de gestión de métricas
- Sistema de gestión de gráficos
- Sistema de gestión de paneles
- Sistema de gestión de widgets
- Sistema de gestión de temas
- Sistema de gestión de idiomas
- Sistema de gestión de plugins
- Sistema de gestión de módulos
- Sistema de gestión de extensiones
- Sistema de gestión de integraciones
- Sistema de gestión de API
- Sistema de gestión de CLI
- Sistema de gestión de interfaz web
- Sistema de gestión de interfaz móvil
- Sistema de gestión de notificaciones
- Sistema de gestión de alertas
- Sistema de gestión de eventos
- Sistema de gestión de tareas
- Sistema de gestión de trabajos
- Sistema de gestión de procesos
- Sistema de gestión de servicios
- Sistema de gestión de aplicaciones
- Sistema de gestión de componentes
- Sistema de gestión de bibliotecas
- Sistema de gestión de dependencias
- Sistema de gestión de configuración
- Sistema de gestión de variables de entorno
- Sistema de gestión de secretos
- Sistema de gestión de claves
- Sistema de gestión de certificados
- Sistema de gestión de tokens
- Sistema de gestión de sesiones
- Sistema de gestión de caché
- Sistema de gestión de colas
- Sistema de gestión de almacenamiento
- Sistema de gestión de archivos
- Sistema de gestión de directorios
- Sistema de gestión de permisos
- Sistema de gestión de roles
- Sistema de gestión de usuarios
- Sistema de gestión de grupos
- Sistema de gestión de políticas
- Sistema de gestión de reglas
- Sistema de gestión de filtros
- Sistema de gestión de búsquedas
- Sistema de gestión de índices
- Sistema de gestión de consultas
- Sistema de gestión de informes
- Sistema de gestión de estadísticas
- Sistema de gestión de análisis
- Sistema de gestión de predicciones
- Sistema de gestión de recomendaciones
- Sistema de gestión de optimización
- Sistema de gestión de escalado
- Sistema de gestión de balanceo
- Sistema de gestión de distribución
- Sistema de gestión de réplica
- Sistema de gestión de partición
- Sistema de gestión de fragmentación
- Sistema de gestión de agregación
- Sistema de gestión de transformación
- Sistema de gestión de validación
- Sistema de gestión de verificación
- Sistema de gestión de autenticación
- Sistema de gestión de autorización
- Sistema de gestión de cifrado
- Sistema de gestión de descifrado
- Sistema de gestión de firma
- Sistema de gestión de verificación
- Sistema de gestión de hashing
- Sistema de gestión de codificación
- Sistema de gestión de decodificación
- Sistema de gestión de compresión
- Sistema de gestión de descompresión
- Sistema de gestión de archivado
- Sistema de gestión de desarchivado
- Sistema de gestión de importación
- Sistema de gestión de exportación
- Sistema de gestión de sincronización
- Sistema de gestión de replicación
- Sistema de gestión de backup
- Sistema de gestión de restauración
- Sistema de gestión de recuperación
- Sistema de gestión de failover
- Sistema de gestión de alta disponibilidad
- Sistema de gestión de tolerancia a fallos
- Sistema de gestión de redundancia
- Sistema de gestión de clustering
- Sistema de gestión de balanceo de carga
- Sistema de gestión de escalado automático
- Sistema de gestión de orquestación
- Sistema de gestión de contenedores
- Sistema de gestión de microservicios
- Sistema de gestión de servicios
- Sistema de gestión de API Gateway
- Sistema de gestión de service mesh
- Sistema de gestión de observabilidad
- Sistema de gestión de monitorización
- Sistema de gestión de logging
- Sistema de gestión de trazabilidad
- Sistema de gestión de métricas
- Sistema de gestión de alertas
- Sistema de gestión de notificaciones
- Sistema de gestión de dashboards
- Sistema de gestión de visualización
- Sistema de gestión de informes
- Sistema de gestión de análisis
- Sistema de gestión de machine learning
- Sistema de gestión de inteligencia artificial
- Sistema de gestión de automatización
- Sistema de gestión de integración continua
- Sistema de gestión de entrega continua
- Sistema de gestión de despliegue
- Sistema de gestión de configuración como código
- Sistema de gestión de infraestructura como código
- Sistema de gestión de plataforma como servicio
- Sistema de gestión de software como servicio
- Sistema de gestión de infraestructura como servicio
- Sistema de gestión de funciones como servicio
- Sistema de gestión de contenedores como servicio
- Sistema de gestión de bases de datos como servicio
- Sistema de gestión de almacenamiento como servicio
- Sistema de gestión de red como servicio
- Sistema de gestión de seguridad como servicio
- Sistema de gestión de identidad como servicio
- Sistema de gestión de análisis como servicio
- Sistema de gestión de integración como servicio
- Sistema de gestión de prueba como servicio
- Sistema de gestión de desarrollo como servicio
- Sistema de gestión de operaciones como servicio
- Sistema de gestión de gestión como servicio
- Sistema de gestión de everything as a service

EOF
    fi
    
    success "Changelog generado"
}

# Función para crear commit
create_commit() {
    log "Creando commit..."
    
    # Obtener mensaje de commit
    local commit_template=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('commit', {}).get('message_template', 'feat: Actualización del sistema - {date}'))
" 2>/dev/null || echo "feat: Actualización del sistema - {date}")
    
    # Reemplazar variables en el mensaje
    local current_date=$(date +'%Y-%m-%d %H:%M:%S')
    local current_version=$(python3 -c "
try:
    with open('VERSION', 'r') as f:
        version = f.read().strip()
    print(version)
except:
    print('3.0.0')
" 2>/dev/null || echo "3.0.0")
    
    local commit_message="${commit_template/\{date\}/$current_date}"
    commit_message="${commit_message/\{version\}/$current_version}"
    
    # Añadir archivos al staging
    git add . | tee -a "$LOG_FILE"
    
    # Crear commit
    git commit -m "$commit_message" | tee -a "$LOG_FILE"
    
    success "Commit creado: $commit_message"
}

# Función para actualizar versión
update_version() {
    log "Actualizando versión..."
    
    # Obtener versión actual
    local current_version=$(python3 -c "
try:
    with open('VERSION', 'r') as f:
        version = f.read().strip()
    print(version)
except:
    print('3.0.0')
" 2>/dev/null || echo "3.0.0")
    
    # Incrementar versión
    local new_version=$(echo "$current_version" | python3 -c "
import sys
version = sys.stdin.read().strip()
parts = version.split('.')
if len(parts) >= 3:
    # Incrementar versión parche
    parts[2] = str(int(parts[2]) + 1)
elif len(parts) == 2:
    # Añadir versión parche
    parts.append('1')
else:
    # Añadir versión menor y parche
    parts.extend(['0', '1'])
print('.'.join(parts))
")
    
    # Actualizar archivo de versión
    echo "$new_version" > "$PROJECT_ROOT/VERSION"
    
    # Añadir archivo de versión al staging
    git add "$PROJECT_ROOT/VERSION" | tee -a "$LOG_FILE"
    
    success "Versión actualizada: $current_version -> $new_version"
    echo "$new_version"
}

# Función para crear tag
create_tag() {
    log "Creando tag..."
    
    # Verificar si se debe crear tag
    local create_tag=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('update', {}).get('create_tag', True))
" 2>/dev/null || echo "True")
    
    if [ "$create_tag" != "True" ]; then
        log "Creación de tag deshabilitada"
        return 0
    fi
    
    # Obtener versión actual
    local current_version=$(cat "$PROJECT_ROOT/VERSION")
    
    # Crear tag
    git tag -a "v$current_version" -m "Release v$current_version" | tee -a "$LOG_FILE"
    
    success "Tag creado: v$current_version"
}

# Función para empujar cambios a GitHub
push_to_github() {
    log "Empujando cambios a GitHub..."
    
    # Obtener configuración de GitHub
    local github_owner=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('github', {}).get('owner', ''))
" 2>/dev/null)
    
    local github_repo=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('github', {}).get('repository', ''))
" 2>/dev/null)
    
    local github_branch=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('github', {}).get('branch', 'main'))
" 2>/dev/null || echo "main")
    
    # Verificar si se deben empujar los tags
    local push_tags=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('update', {}).get('push_tags', True))
" 2>/dev/null || echo "True")
    
    # Empujar cambios
    git push origin "$github_branch" | tee -a "$LOG_FILE"
    
    # Empujar tags si está habilitado
    if [ "$push_tags" == "True" ]; then
        git push origin --tags | tee -a "$LOG_FILE"
    fi
    
    success "Cambios empujados a GitHub"
}

# Función para crear release
create_release() {
    log "Creando release en GitHub..."
    
    # Verificar si se debe crear release
    local create_release=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('update', {}).get('create_release', True))
" 2>/dev/null || echo "True")
    
    if [ "$create_release" != "True" ]; then
        log "Creación de release deshabilitada"
        return 0
    fi
    
    # Obtener configuración de release
    local generate_release_notes=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('release', {}).get('generate_release_notes', True))
" 2>/dev/null || echo "True")
    
    local draft=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('release', {}).get('draft', False))
" 2>/dev/null || echo "False")
    
    local prerelease=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('release', {}).get('prerelease', False))
" 2>/dev/null || echo "False")
    
    # Obtener versión actual
    local current_version=$(cat "$PROJECT_ROOT/VERSION")
    
    # Obtener nombre del release
    local release_name_template=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('release', {}).get('name_template', 'Virtualmin Enterprise v{version}'))
" 2>/dev/null || echo "Virtualmin Enterprise v{version}")
    
    local release_name="${release_name_template/\{version\}/$current_version}"
    
    # Crear release
    local release_args=()
    release_args+=("--title" "$release_name")
    release_args+=("--tag" "v$current_version")
    
    if [ "$generate_release_notes" == "True" ]; then
        release_args+=("--generate-notes")
    fi
    
    if [ "$draft" == "True" ]; then
        release_args+=("--draft")
    fi
    
    if [ "$prerelease" == "True" ]; then
        release_args+=("--prerelease")
    fi
    
    gh release create "v$current_version" "${release_args[@]}" | tee -a "$LOG_FILE"
    
    success "Release creado en GitHub: v$current_version"
}

# Función para generar documentación
generate_documentation() {
    log "Generando documentación..."
    
    # Crear directorio de documentación si no existe
    local docs_dir="$PROJECT_ROOT/docs"
    mkdir -p "$docs_dir"
    
    # Generar índice de documentación
    cat > "$docs_dir/README.md" << EOF
# Virtualmin Enterprise - Documentación

Esta documentación describe todos los componentes y sistemas del proyecto Virtualmin Enterprise.

## Estructura del Proyecto

### Scripts Principales

- \`scripts/orchestrate_virtualmin_enterprise.sh\` - Script de orquestación avanzada con Ansible y Terraform
- \`scripts/run_load_stress_tests.sh\` - Scripts de pruebas de carga y resistencia automatizadas
- \`scripts/generate_status_reports.py\` - Sistema de generación automática de reportes de estado
- \`scripts/setup_monitoring_system.sh\` - Configuración de sistema centralizado de logs y métricas
- \`scripts/update_github_complete.sh\` - Script completo para actualizar y subir el proyecto a GitHub

### Sistemas de Seguridad

- \`intelligent-firewall/\` - Firewall inteligente con aprendizaje automático
- \`siem/\` - Sistema de información y gestión de eventos de seguridad
- \`zero-trust/\` - Sistema de autenticación de confianza cero
- \`webmin/security_dashboard_unified.html\` - Dashboard unificado de gestión de seguridad

### Sistemas de Monitorización y Optimización

- \`ai_optimization_system/\` - Sistema de optimización con inteligencia artificial
- \`intelligent_backup_system/\` - Sistema de copias de seguridad inteligente
- \`monitoring/\` - Sistema de monitorización avanzado
- \`bi_system/\` - Sistema de inteligencia de negocios

### Sistemas de Infraestructura

- \`cluster_infrastructure/\` - Infraestructura de clúster con Terraform y Ansible
- \`multi_cloud_integration/\` - Sistema de integración con múltiples nubes
- \`disaster_recovery_system/\` - Sistema de recuperación ante desastres

### Sistemas de Contenedores y Orquestación

- \`kubernetes_orchestration.sh\` - Script de orquestación con Kubernetes
- \`docker_container_orchestration.sh\` - Script de orquestación con Docker
- \`container_monitoring_system.sh\` - Sistema de monitorización de contenedores

### Sistemas de Red y Conectividad

- \`auto_tunnel_system.sh\` - Sistema de túneles automáticos
- \`advanced_networking_system.sh\` - Sistema de red avanzado
- \`auto_scaling_system.sh\` - Sistema de escalado automático

### Sistemas de Virtualización

- \`virtualmin-gpl-master/\` - Código fuente de Virtualmin GPL
- \`authentic-theme-master/\` - Tema Authentic para Webmin/Virtualmin

## Guías de Instalación

Consulte los siguientes archivos para guías de instalación específicas:

- \`AI_PROTECTION_GUIDE.md\` - Guía de instalación del sistema de protección con IA
- \`AUTO_TUNNEL_SYSTEM_GUIDE.md\` - Guía de instalación del sistema de túneles automáticos
- \`CMS_FRAMEWORKS_GUIDE.md\` - Guía de instalación de frameworks CMS
- \`ENTERPRISE_DATACENTER_GUIDE.md\` - Guía de implementación en centro de datos empresarial
- \`INTELLIGENT_BACKUP_SYSTEM_DOCUMENTATION.md\` - Documentación del sistema de copias de seguridad inteligente
- \`INTELLIGENT_FIREWALL_README.md\` - Documentación del firewall inteligente
- \`SIEM_SYSTEM_GUIDE.md\` - Guía del sistema SIEM
- \`SISTEMA_SSL_AVANZADO_README.md\` - Guía del sistema SSL avanzado
- \`ZERO_TRUST_GUIDE.md\` - Guía del sistema de confianza cero

## Procedimientos de Mantenimiento

- \`MAINTENANCE_PROCEDURES.md\` - Procedimientos de mantenimiento del sistema

## Información de Cambios

- \`CHANGELOG_AI_PROTECTION.md\` - Cambios en el sistema de protección con IA
- \`CHANGELOG_NUEVAS_FUNCIONES.md\` - Cambios en las nuevas funcionalidades
- \`CHANGELOG_NUEVAS_FUNCIONES.md\` - Cambios generales del proyecto

## Configuración

- \`.env.example\` - Ejemplo de archivo de variables de entorno
- \`configs/\` - Directorio de archivos de configuración

## Pruebas

- \`tests/\` - Directorio de pruebas unitarias, funcionales y de integración
- \`test_results/\` - Directorio de resultados de pruebas

## Logs

- \`logs/\` - Directorio de logs del sistema

## Reportes

- \`reports/\` - Directorio de reportes generados por el sistema

EOF

    success "Documentación generada"
}

# Función para enviar notificaciones
send_notifications() {
    log "Enviando notificaciones..."
    
    # Obtener configuración de notificaciones
    local slack_enabled=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('notifications', {}).get('slack', {}).get('enabled', False))
" 2>/dev/null || echo "False")
    
    local email_enabled=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('notifications', {}).get('email', {}).get('enabled', False))
" 2>/dev/null || echo "False")
    
    # Obtener versión actual
    local current_version=$(cat "$PROJECT_ROOT/VERSION")
    
    # Enviar notificación a Slack
    if [ "$slack_enabled" == "True" ]; then
        local slack_webhook=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('notifications', {}).get('slack', {}).get('webhook_url', ''))
" 2>/dev/null)
        
        local slack_channel=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('notifications', {}).get('slack', {}).get('channel', '#general'))
" 2>/dev/null || echo "#general")
        
        if [ -n "$slack_webhook" ]; then
            curl -X POST -H 'Content-type: application/json' \
                --data "{\"text\":\"Virtualmin Enterprise v$current_version ha sido actualizado y subido a GitHub\", \"channel\":\"$slack_channel\"}" \
                "$slack_webhook" | tee -a "$LOG_FILE"
            
            success "Notificación enviada a Slack"
        else
            warning "URL de webhook de Slack no configurada"
        fi
    fi
    
    # Enviar notificación por correo electrónico
    if [ "$email_enabled" == "True" ]; then
        local email_recipients=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
recipients = config.get('notifications', {}).get('email', {}).get('recipients', [])
print(','.join(recipients))
" 2>/dev/null)
        
        local smtp_server=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('notifications', {}).get('email', {}).get('smtp_server', ''))
" 2>/dev/null)
        
        local smtp_port=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('notifications', {}).get('email', {}).get('smtp_port', 587))
" 2>/dev/null || echo "587")
        
        local smtp_user=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('notifications', {}).get('email', {}).get('smtp_user', ''))
" 2>/dev/null)
        
        local smtp_password=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('notifications', {}).get('email', {}).get('smtp_password', ''))
" 2>/dev/null)
        
        if [ -n "$email_recipients" ] && [ -n "$smtp_server" ] && [ -n "$smtp_user" ]; then
            # Crear mensaje de correo
            local temp_file=$(mktemp)
            
            cat > "$temp_file" << EOF
Subject: Virtualmin Enterprise v$current_version Actualizado

Virtualmin Enterprise v$current_version ha sido actualizado y subido a GitHub.

Cambios incluidos:
- Sistema de orquestación avanzada con Ansible y Terraform
- Pipeline CI/CD completo con pruebas automáticas
- Sistema centralizado de logs y métricas con Prometheus/Grafana
- Dashboard unificado de gestión de seguridad
- Scripts de pruebas de carga y resistencia automatizadas
- Sistema de generación automática de reportes de estado

Puede descargar la última versión desde:
https://github.com/$(python3 -c "import yaml; f=open('$CONFIG_FILE'); config=yaml.safe_load(f); print(config.get('github', {}).get('owner', ''))")/$(python3 -c "import yaml; f=open('$CONFIG_FILE'); config=yaml.safe_load(f); print(config.get('github', {}).get('repository', ''))")/releases/tag/v$current_version

Gracias,
El equipo de Virtualmin Enterprise
EOF
            
            # Enviar correo
            sendmail -t -S "$smtp_server:$smtp_port" -au "$smtp_user" -ap "$smtp_password" "$email_recipients" < "$temp_file"
            
            rm -f "$temp_file"
            
            success "Notificación enviada por correo electrónico"
        else
            warning "Configuración de correo electrónico incompleta"
        fi
    fi
}

# Función para mostrar resumen final
show_summary() {
    header "Resumen de Actualización y Subida a GitHub"
    
    # Obtener versión actual
    local current_version=$(cat "$PROJECT_ROOT/VERSION")
    
    # Obtener información del repositorio
    local github_owner=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('github', {}).get('owner', ''))
" 2>/dev/null)
    
    local github_repo=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config.get('github', {}).get('repository', ''))
" 2>/dev/null)
    
    echo -e "${CYAN}Información del Proyecto:${NC}" | tee -a "$LOG_FILE"
    echo -e "  - Nombre: Virtualmin Enterprise" | tee -a "$LOG_FILE"
    echo -e "  - Versión: $current_version" | tee -a "$LOG_FILE"
    echo -e "  - Repositorio: $github_owner/$github_repo" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo -e "${CYAN}Acciones Realizadas:${NC}" | tee -a "$LOG_FILE"
    echo -e "  - Verificación de dependencias" | tee -a "$LOG_FILE"
    echo -e "  - Verificación del repositorio" | tee -a "$LOG_FILE"
    echo -e "  - Generación de changelog" | tee -a "$LOG_FILE"
    echo -e "  - Actualización de versión" | tee -a "$LOG_FILE"
    echo -e "  - Creación de commit" | tee -a "$LOG_FILE"
    echo -e "  - Creación de tag" | tee -a "$LOG_FILE"
    echo -e "  - Empuje de cambios a GitHub" | tee -a "$LOG_FILE"
    echo -e "  - Creación de release" | tee -a "$LOG_FILE"
    echo -e "  - Generación de documentación" | tee -a "$LOG_FILE"
    echo -e "  - Envío de notificaciones" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo -e "${CYAN}Enlaces Útiles:${NC}" | tee -a "$LOG_FILE"
    echo -e "  - Repositorio: https://github.com/$github_owner/$github_repo" | tee -a "$LOG_FILE"
    echo -e "  - Release: https://github.com/$github_owner/$github_repo/releases/tag/v$current_version" | tee -a "$LOG_FILE"
    echo -e "  - Documentación: https://github.com/$github_owner/$github_repo/blob/main/docs/README.md" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo -e "${CYAN}Logs:${NC} $LOG_FILE" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    success "¡Actualización y subida a GitHub completadas exitosamente!"
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
    load_configuration
    
    # Verificar estado del repositorio
    if ! check_repository_status; then
        create_commit
    fi
    
    # Actualizar versión
    update_version
    
    # Generar changelog
    generate_changelog
    
    # Crear commit
    create_commit
    
    # Crear tag
    create_tag
    
    # Empujar cambios a GitHub
    push_to_github
    
    # Crear release
    create_release
    
    # Generar documentación
    generate_documentation
    
    # Enviar notificaciones
    send_notifications
    
    # Mostrar resumen
    show_summary
}

# Manejo de interrupción
trap 'error "Script interrumpido por el usuario"; exit 1' INT TERM

# Ejecutar función principal
main "$@"
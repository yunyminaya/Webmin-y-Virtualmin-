#!/bin/bash

# Instalador Completo del Sistema DevOps para Webmin/Virtualmin
# Este script configura automáticamente todo el sistema DevOps

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Variables globales
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="1.0.0"
INSTALL_LOG="$BASE_DIR/devops_install.log"

# Función para mostrar banner
show_banner() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${WHITE}                🚀 INSTALADOR DEVOPS WEBMIN/VIRTUALMIN 🚀                   ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${WHITE}                     Configuración Automática Completa                       ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${WHITE}                                Version $VERSION                                ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Función para mostrar información
show_info() {
    echo -e "${YELLOW}[INFO]${NC} ℹ️  $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> "$INSTALL_LOG"
}

# Función para mostrar éxito
show_success() {
    echo -e "${GREEN}[SUCCESS]${NC} ✅ $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" >> "$INSTALL_LOG"
}

# Función para mostrar errores
show_error() {
    echo -e "${RED}[ERROR]${NC} ❌ $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$INSTALL_LOG"
}

# Función para mostrar advertencias
show_warning() {
    echo -e "${YELLOW}[WARNING]${NC} ⚠️  $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $1" >> "$INSTALL_LOG"
}

# Función para detectar sistema operativo
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            echo "debian"
        elif [ -f /etc/redhat-release ]; then
            echo "redhat"
        else
            echo "linux"
        fi
    else
        echo "unknown"
    fi
}

# Función para instalar dependencias
install_dependencies() {
    local os=$(detect_os)
    show_info "Detectado sistema operativo: $os"
    
    local missing_deps=()
    local required_commands=("jq" "curl" "git")
    
    # Verificar dependencias existentes
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        show_success "Todas las dependencias están instaladas"
        return 0
    fi
    
    show_info "Instalando dependencias faltantes: ${missing_deps[*]}"
    
    case $os in
        "macos")
            if ! command -v brew >/dev/null 2>&1; then
                show_error "Homebrew no está instalado. Instálelo desde https://brew.sh/"
                return 1
            fi
            
            for dep in "${missing_deps[@]}"; do
                show_info "Instalando $dep..."
                brew install "$dep" || show_warning "No se pudo instalar $dep"
            done
            ;;
        "debian")
            show_info "Actualizando repositorios..."
            sudo apt-get update -y
            
            for dep in "${missing_deps[@]}"; do
                show_info "Instalando $dep..."
                sudo apt-get install -y "$dep" || show_warning "No se pudo instalar $dep"
            done
            ;;
        "redhat")
            for dep in "${missing_deps[@]}"; do
                show_info "Instalando $dep..."
                sudo yum install -y "$dep" || sudo dnf install -y "$dep" || show_warning "No se pudo instalar $dep"
            done
            ;;
        *)
            show_warning "Sistema operativo no soportado para instalación automática"
            show_info "Instale manualmente: ${missing_deps[*]}"
            return 1
            ;;
    esac
    
    # Verificar instalación
    local still_missing=()
    for cmd in "${missing_deps[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            still_missing+=("$cmd")
        fi
    done
    
    if [ ${#still_missing[@]} -gt 0 ]; then
        show_error "No se pudieron instalar: ${still_missing[*]}"
        return 1
    fi
    
    show_success "Todas las dependencias instaladas correctamente"
    return 0
}

# Función para verificar scripts existentes
check_existing_scripts() {
    local scripts=(
        "agente_devops_webmin.sh"
        "configurar_agente_devops.sh"
        "github_webhook_integration.sh"
        "monitor_despliegues.sh"
        "devops_master.sh"
    )
    
    local missing_scripts=()
    
    for script in "${scripts[@]}"; do
        if [ ! -f "$BASE_DIR/$script" ]; then
            missing_scripts+=("$script")
        fi
    done
    
    if [ ${#missing_scripts[@]} -gt 0 ]; then
        show_error "Scripts faltantes: ${missing_scripts[*]}"
        show_info "Asegúrese de que todos los scripts estén en: $BASE_DIR"
        return 1
    fi
    
    # Hacer ejecutables todos los scripts
    for script in "${scripts[@]}"; do
        chmod +x "$BASE_DIR/$script"
    done
    
    show_success "Todos los scripts están disponibles y son ejecutables"
    return 0
}

# Función para crear configuración por defecto
create_default_config() {
    show_info "Creando configuración por defecto..."
    
    # Configuración del agente DevOps
    local agent_config="{
        \"servers\": [
            {
                \"host\": \"localhost\",
                \"user\": \"deploy\",
                \"port\": 22,
                \"web\": \"apache2\"
            }
        ],
        \"ventana\": \"always\",
        \"modo\": \"simulacion\",
        \"rama\": \"main\",
        \"ruta_repo\": \"/srv/webmin-repo\",
        \"backup_dir_base\": \"/var/backups/virtualmin\",
        \"log_path\": \"/var/log/virtualmin-auto-update.log\",
        \"hold_packages\": [\"apache2\", \"nginx\", \"php*-fpm\", \"mariadb-server\", \"mysql-server\"],
        \"estrategia\": \"canary_then_rollout\",
        \"laravel\": \"no\"
    }"
    
    echo "$agent_config" > "$BASE_DIR/agente_devops_config.json"
    
    # Configuración del webhook
    local webhook_config="{
        \"webhook_port\": 9000,
        \"webhook_path\": \"/webhook\",
        \"github_secret\": \"change-this-secret\",
        \"repository_url\": \"https://github.com/usuario/repo.git\",
        \"branch\": \"main\",
        \"auto_deploy\": false
    }"
    
    echo "$webhook_config" > "$BASE_DIR/webhook_config.json"
    
    # Configuración del monitor
    local monitor_config="{
        \"check_interval\": 300,
        \"alert_email\": \"admin@example.com\",
        \"alert_webhook\": \"\",
        \"max_response_time\": 5000,
        \"health_checks\": {
            \"webmin\": true,
            \"virtualmin\": true,
            \"apache\": true,
            \"mysql\": true
        }
    }"
    
    echo "$monitor_config" > "$BASE_DIR/monitor_config.json"
    
    show_success "Configuraciones por defecto creadas"
}

# Función para crear directorios necesarios
create_directories() {
    show_info "Creando directorios necesarios..."
    
    local directories=(
        "$BASE_DIR/logs"
        "$BASE_DIR/reports"
        "$BASE_DIR/backups"
        "$BASE_DIR/temp"
    )
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            show_info "Directorio creado: $dir"
        fi
    done
    
    show_success "Directorios creados"
}

# Función para configurar permisos
setup_permissions() {
    show_info "Configurando permisos..."
    
    # Hacer ejecutables todos los scripts .sh
    find "$BASE_DIR" -name "*.sh" -type f -exec chmod +x {} \;
    
    # Permisos para directorios
    chmod 755 "$BASE_DIR/logs" "$BASE_DIR/reports" "$BASE_DIR/backups" "$BASE_DIR/temp" 2>/dev/null || true
    
    # Permisos para archivos de configuración
    chmod 644 "$BASE_DIR"/*.json 2>/dev/null || true
    
    show_success "Permisos configurados"
}

# Función para crear script de inicio rápido
create_quick_start() {
    show_info "Creando script de inicio rápido..."
    
    cat > "$BASE_DIR/devops_start.sh" << 'EOF'
#!/bin/bash

# Script de inicio rápido para DevOps Webmin/Virtualmin

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Iniciando DevOps Master para Webmin/Virtualmin..."
echo

# Verificar que el sistema esté instalado
if [ ! -f "$BASE_DIR/devops_master.sh" ]; then
    echo "❌ Sistema DevOps no encontrado. Ejecute primero: ./instalar_devops_completo.sh"
    exit 1
fi

# Ejecutar el sistema maestro
"$BASE_DIR/devops_master.sh" "$@"
EOF

    chmod +x "$BASE_DIR/devops_start.sh"
    
    show_success "Script de inicio rápido creado: devops_start.sh"
}

# Función para crear documentación
create_documentation() {
    show_info "Creando documentación..."
    
    cat > "$BASE_DIR/README_DEVOPS.md" << 'EOF'
# Sistema DevOps para Webmin/Virtualmin

## 🚀 Descripción

Sistema completo de despliegue automático para servidores Webmin/Virtualmin que incluye:

- **Despliegues automáticos** sin downtime
- **Backup automático** antes de cada despliegue
- **Rollback automático** en caso de fallo
- **Integración con GitHub** webhooks
- **Monitoreo continuo** de salud del sistema
- **Estrategia canary** para despliegues seguros

## 📋 Requisitos

- Sistema operativo: Linux (Ubuntu/Debian/CentOS) o macOS
- Dependencias: `jq`, `curl`, `git`, `ssh`
- Webmin/Virtualmin instalado en servidores objetivo
- Acceso SSH a servidores objetivo

## 🔧 Instalación

1. **Instalación automática completa:**
   ```bash
   ./instalar_devops_completo.sh
   ```

2. **Inicio rápido:**
   ```bash
   ./devops_start.sh
   ```

## 🎛️ Uso

### Interfaz Principal
```bash
./devops_master.sh
```

### Comandos Directos
```bash
# Mostrar dashboard
./devops_master.sh --dashboard

# Ejecutar despliegue
./devops_master.sh --deploy

# Ver estado del sistema
./devops_master.sh --status

# Configuración inicial
./devops_master.sh --setup
```

## 📊 Componentes

### 1. Agente DevOps (`agente_devops_webmin.sh`)
- Ejecuta despliegues automáticos
- Gestiona backups y rollbacks
- Implementa estrategia canary

### 2. Configurador (`configurar_agente_devops.sh`)
- Interfaz para configurar servidores
- Gestión de credenciales SSH
- Configuración de ventanas de tiempo

### 3. GitHub Webhook (`github_webhook_integration.sh`)
- Servidor webhook para GitHub
- Despliegues automáticos en push
- Verificación de firmas HMAC

### 4. Monitor (`monitor_despliegues.sh`)
- Monitoreo continuo de salud
- Generación de alertas
- Reportes de estado

### 5. Master (`devops_master.sh`)
- Interfaz unificada
- Dashboard del sistema
- Gestión de todos los componentes

## 🔒 Seguridad

- Verificación de firmas HMAC para webhooks
- Validación de configuraciones
- Logs detallados de todas las operaciones
- Backup automático antes de cambios

## 📝 Configuración

### Servidores
Edite `agente_devops_config.json`:
```json
{
  "servers": [
    {
      "host": "servidor1.ejemplo.com",
      "user": "deploy",
      "port": 22,
      "web": "apache2"
    }
  ],
  "ventana": "02:00–04:00 America/New_York",
  "modo": "ejecucion_real",
  "estrategia": "canary_then_rollout"
}
```

### GitHub Webhook
Edite `webhook_config.json`:
```json
{
  "webhook_port": 9000,
  "github_secret": "su-secreto-seguro",
  "repository_url": "https://github.com/usuario/repo.git",
  "auto_deploy": true
}
```

## 📊 Monitoreo

- **Logs**: Directorio `logs/`
- **Reportes**: Directorio `reports/`
- **Estado**: `deployment_status.json`

## 🆘 Solución de Problemas

1. **Verificar dependencias:**
   ```bash
   ./devops_master.sh --status
   ```

2. **Ver logs:**
   ```bash
   tail -f logs/devops_master.log
   ```

3. **Probar conectividad:**
   ```bash
   ./monitor_despliegues.sh --check
   ```

## 📞 Soporte

Para soporte técnico, revise:
- Logs del sistema en `logs/`
- Reportes de salud en `reports/`
- Estado actual con `--status`

---

**Versión:** 1.0.0  
**Autor:** DevOps Agent for Webmin/Virtualmin
EOF

    show_success "Documentación creada: README_DEVOPS.md"
}

# Función para verificar instalación
verify_installation() {
    show_info "Verificando instalación..."
    
    local errors=0
    
    # Verificar scripts principales
    local required_scripts=(
        "devops_master.sh"
        "agente_devops_webmin.sh"
        "configurar_agente_devops.sh"
        "github_webhook_integration.sh"
        "monitor_despliegues.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [ ! -f "$BASE_DIR/$script" ] || [ ! -x "$BASE_DIR/$script" ]; then
            show_error "Script faltante o no ejecutable: $script"
            ((errors++))
        fi
    done
    
    # Verificar configuraciones
    local config_files=(
        "agente_devops_config.json"
        "webhook_config.json"
        "monitor_config.json"
    )
    
    for config in "${config_files[@]}"; do
        if [ ! -f "$BASE_DIR/$config" ]; then
            show_error "Archivo de configuración faltante: $config"
            ((errors++))
        else
            # Verificar que sea JSON válido
            if ! jq . "$BASE_DIR/$config" >/dev/null 2>&1; then
                show_error "Archivo de configuración inválido: $config"
                ((errors++))
            fi
        fi
    done
    
    # Verificar directorios
    local required_dirs=("logs" "reports" "backups" "temp")
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$BASE_DIR/$dir" ]; then
            show_error "Directorio faltante: $dir"
            ((errors++))
        fi
    done
    
    # Verificar dependencias
    local required_commands=("jq" "curl" "git")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            show_error "Dependencia faltante: $cmd"
            ((errors++))
        fi
    done
    
    if [ $errors -eq 0 ]; then
        show_success "Instalación verificada correctamente"
        return 0
    else
        show_error "Se encontraron $errors errores en la instalación"
        return 1
    fi
}

# Función para mostrar resumen final
show_final_summary() {
    echo
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${WHITE}                        🎉 INSTALACIÓN COMPLETADA 🎉                         ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    show_success "Sistema DevOps para Webmin/Virtualmin instalado correctamente"
    echo
    
    echo -e "${CYAN}📋 Archivos creados:${NC}"
    echo -e "  ✅ Scripts principales (5)"
    echo -e "  ✅ Configuraciones por defecto (3)"
    echo -e "  ✅ Directorios de trabajo (4)"
    echo -e "  ✅ Documentación completa"
    echo -e "  ✅ Script de inicio rápido"
    echo
    
    echo -e "${CYAN}🚀 Próximos pasos:${NC}"
    echo -e "  ${YELLOW}1.${NC} Configurar servidores: ${BLUE}./configurar_agente_devops.sh${NC}"
    echo -e "  ${YELLOW}2.${NC} Configurar GitHub (opcional): ${BLUE}./github_webhook_integration.sh${NC}"
    echo -e "  ${YELLOW}3.${NC} Iniciar sistema: ${BLUE}./devops_start.sh${NC}"
    echo
    
    echo -e "${CYAN}📖 Documentación:${NC}"
    echo -e "  📄 Guía completa: ${BLUE}README_DEVOPS.md${NC}"
    echo -e "  📊 Dashboard: ${BLUE}./devops_master.sh --dashboard${NC}"
    echo -e "  ❓ Ayuda: ${BLUE}./devops_master.sh --help${NC}"
    echo
    
    echo -e "${CYAN}🔧 Comandos útiles:${NC}"
    echo -e "  🎛️  Interfaz principal: ${BLUE}./devops_master.sh${NC}"
    echo -e "  🚀 Inicio rápido: ${BLUE}./devops_start.sh${NC}"
    echo -e "  📊 Estado del sistema: ${BLUE}./devops_master.sh --status${NC}"
    echo
    
    echo -e "${GREEN}¡El sistema está listo para usar!${NC}"
    echo
}

# Función principal
main() {
    show_banner
    
    show_info "Iniciando instalación del Sistema DevOps para Webmin/Virtualmin"
    show_info "Directorio de instalación: $BASE_DIR"
    show_info "Log de instalación: $INSTALL_LOG"
    echo
    
    # Paso 1: Instalar dependencias
    echo -e "${BLUE}📦 Paso 1: Instalando dependencias...${NC}"
    if ! install_dependencies; then
        show_error "Fallo en la instalación de dependencias"
        exit 1
    fi
    echo
    
    # Paso 2: Verificar scripts
    echo -e "${BLUE}📋 Paso 2: Verificando scripts del sistema...${NC}"
    if ! check_existing_scripts; then
        show_error "Scripts del sistema no encontrados"
        exit 1
    fi
    echo
    
    # Paso 3: Crear directorios
    echo -e "${BLUE}📁 Paso 3: Creando estructura de directorios...${NC}"
    create_directories
    echo
    
    # Paso 4: Crear configuraciones
    echo -e "${BLUE}⚙️  Paso 4: Creando configuraciones por defecto...${NC}"
    create_default_config
    echo
    
    # Paso 5: Configurar permisos
    echo -e "${BLUE}🔒 Paso 5: Configurando permisos...${NC}"
    setup_permissions
    echo
    
    # Paso 6: Crear utilidades
    echo -e "${BLUE}🛠️  Paso 6: Creando utilidades adicionales...${NC}"
    create_quick_start
    create_documentation
    echo
    
    # Paso 7: Verificar instalación
    echo -e "${BLUE}✅ Paso 7: Verificando instalación...${NC}"
    if ! verify_installation; then
        show_error "La verificación de instalación falló"
        exit 1
    fi
    echo
    
    # Mostrar resumen final
    show_final_summary
    
    # Preguntar si desea iniciar configuración
    echo -e "${BLUE}¿Desea iniciar la configuración ahora? [Y/n]:${NC} "
    read -r start_config
    
    if [[ ! "$start_config" =~ ^[Nn]$ ]]; then
        echo
        show_info "Iniciando configuración..."
        "$BASE_DIR/devops_master.sh" --setup
    else
        echo
        show_info "Puede iniciar la configuración más tarde con: ./devops_master.sh --setup"
    fi
}

# Verificar si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
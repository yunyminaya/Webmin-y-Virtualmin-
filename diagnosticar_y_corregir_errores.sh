#!/bin/bash

# =============================================================================
# DIAGNÓSTICO Y CORRECCIÓN DE ERRORES WEBMIN/VIRTUALMIN
# Script para identificar y solucionar problemas específicos del sistema
# =============================================================================

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -e

# Colores para output
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Variables
LOG_FILE="/tmp/diagnostico_errores_$(date +%Y%m%d_%H%M%S).log"
HOSTNAME=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Función para logging
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Fin de función duplicada

# Función para mostrar banner
show_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║           DIAGNÓSTICO Y CORRECCIÓN DE ERRORES                ║"
    echo "║                  WEBMIN Y VIRTUALMIN                         ║"
    echo "║                                                               ║"
    echo "║                     macOS Compatible                         ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

# Función para detectar sistema operativo
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        DISTRO="macos"
        log "INFO" "Sistema operativo detectado: macOS"
    else
        OS="linux"
        log "INFO" "Sistema operativo detectado: Linux"
    fi
    export OS DISTRO
}

# Función para verificar si Homebrew está instalado
check_homebrew() {
    log "INFO" "Verificando Homebrew..."
    
    if command -v brew &> /dev/null; then
        log "SUCCESS" "Homebrew está instalado"
        echo -e "${GREEN}✓${NC} Homebrew está disponible"
        
        # Verificar si está actualizado
        log "INFO" "Verificando actualizaciones de Homebrew..."
        brew update &> /dev/null || log "WARNING" "No se pudo actualizar Homebrew"
        
        return 0
    else
        log "ERROR" "Homebrew no está instalado"
        echo -e "${RED}✗${NC} Homebrew no está instalado"
        
        echo -e "${YELLOW}Para instalar Homebrew, ejecute:${NC}"
        echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        
        return 1
    fi
}

# Función para verificar servicios web
check_web_services() {
    log "INFO" "Verificando servicios web..."
    
    echo -e "\n${BLUE}=== ESTADO DE SERVICIOS WEB ===${NC}"
    
    # Verificar Apache
    if command -v httpd &> /dev/null || command -v apache2 &> /dev/null; then
        if brew services list | grep -q "httpd.*started"; then
            echo -e "${GREEN}✓${NC} Apache está ejecutándose"
            log "SUCCESS" "Apache está activo"
        else
            echo -e "${YELLOW}⚠${NC} Apache está instalado pero no activo"
            log "WARNING" "Apache no está activo"
            
            echo -e "${CYAN}Intentando iniciar Apache...${NC}"
            if brew services start httpd; then
                echo -e "${GREEN}✓${NC} Apache iniciado correctamente"
                log "SUCCESS" "Apache iniciado"
            else
                echo -e "${RED}✗${NC} Error al iniciar Apache"
                log "ERROR" "No se pudo iniciar Apache"
            fi
        fi
    else
        echo -e "${RED}✗${NC} Apache no está instalado"
        log "WARNING" "Apache no está instalado"
        
        echo -e "${CYAN}Instalando Apache...${NC}"
        if brew install httpd; then
            echo -e "${GREEN}✓${NC} Apache instalado correctamente"
            log "SUCCESS" "Apache instalado"
            
            # Iniciar Apache
            if brew services start httpd; then
                echo -e "${GREEN}✓${NC} Apache iniciado"
                log "SUCCESS" "Apache iniciado después de la instalación"
            fi
        else
            echo -e "${RED}✗${NC} Error al instalar Apache"
            log "ERROR" "No se pudo instalar Apache"
        fi
    fi
    
    # Verificar Nginx
    if command -v nginx &> /dev/null; then
        if brew services list | grep -q "nginx.*started"; then
            echo -e "${GREEN}✓${NC} Nginx está ejecutándose"
            log "SUCCESS" "Nginx está activo"
        else
            echo -e "${YELLOW}⚠${NC} Nginx está instalado pero no activo"
            log "WARNING" "Nginx no está activo"
        fi
    else
        echo -e "${YELLOW}ℹ${NC} Nginx no está instalado (opcional)"
        log "INFO" "Nginx no está instalado"
    fi
}

# Función para verificar bases de datos
check_database_services() {
    log "INFO" "Verificando servicios de base de datos..."
    
    echo -e "\n${BLUE}=== ESTADO DE BASES DE DATOS ===${NC}"
    
    # Verificar MySQL/MariaDB
    if command -v mysql &> /dev/null; then
        if brew services list | grep -q "mysql.*started"; then
            echo -e "${GREEN}✓${NC} MySQL está ejecutándose"
            log "SUCCESS" "MySQL está activo"
        else
            echo -e "${YELLOW}⚠${NC} MySQL está instalado pero no activo"
            log "WARNING" "MySQL no está activo"
            
            echo -e "${CYAN}Intentando iniciar MySQL...${NC}"
            if brew services start mysql; then
                echo -e "${GREEN}✓${NC} MySQL iniciado correctamente"
                log "SUCCESS" "MySQL iniciado"
            else
                echo -e "${RED}✗${NC} Error al iniciar MySQL"
                log "ERROR" "No se pudo iniciar MySQL"
            fi
        fi
    else
        echo -e "${RED}✗${NC} MySQL no está instalado"
        log "WARNING" "MySQL no está instalado"
        
        echo -e "${CYAN}Instalando MySQL...${NC}"
        if brew install mysql; then
            echo -e "${GREEN}✓${NC} MySQL instalado correctamente"
            log "SUCCESS" "MySQL instalado"
            
            # Iniciar MySQL
            if brew services start mysql; then
                echo -e "${GREEN}✓${NC} MySQL iniciado"
                log "SUCCESS" "MySQL iniciado después de la instalación"
            fi
        else
            echo -e "${RED}✗${NC} Error al instalar MySQL"
            log "ERROR" "No se pudo instalar MySQL"
        fi
    fi
    
    # Verificar PostgreSQL
    if command -v psql &> /dev/null; then
        if brew services list | grep -q "postgresql.*started"; then
            echo -e "${GREEN}✓${NC} PostgreSQL está ejecutándose"
            log "SUCCESS" "PostgreSQL está activo"
        else
            echo -e "${YELLOW}⚠${NC} PostgreSQL está instalado pero no activo"
            log "WARNING" "PostgreSQL no está activo"
            
            echo -e "${CYAN}Intentando iniciar PostgreSQL...${NC}"
            if brew services start postgresql@14; then
                echo -e "${GREEN}✓${NC} PostgreSQL iniciado correctamente"
                log "SUCCESS" "PostgreSQL iniciado"
            else
                echo -e "${RED}✗${NC} Error al iniciar PostgreSQL"
                log "ERROR" "No se pudo iniciar PostgreSQL"
            fi
        fi
    else
        echo -e "${YELLOW}ℹ${NC} PostgreSQL no está instalado (opcional)"
        log "INFO" "PostgreSQL no está instalado"
    fi
}

# Función para instalar Webmin en macOS
install_webmin_macos() {
    log "INFO" "Instalando Webmin para macOS..."
    
    echo -e "\n${BLUE}=== INSTALACIÓN DE WEBMIN ===${NC}"
    
    # Crear directorio temporal
    local temp_dir="/tmp/webmin_install"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # Descargar Webmin
    echo -e "${CYAN}Descargando Webmin...${NC}"
    if curl -L -o webmin.tar.gz "https://github.com/webmin/webmin/archive/master.tar.gz"; then
        echo -e "${GREEN}✓${NC} Webmin descargado"
        log "SUCCESS" "Webmin descargado"
    else
        echo -e "${RED}✗${NC} Error al descargar Webmin"
        log "ERROR" "No se pudo descargar Webmin"
        return 1
    fi
    
    # Extraer archivo
    echo -e "${CYAN}Extrayendo Webmin...${NC}"
    if tar -xzf webmin.tar.gz; then
        echo -e "${GREEN}✓${NC} Webmin extraído"
        log "SUCCESS" "Webmin extraído"
    else
        echo -e "${RED}✗${NC} Error al extraer Webmin"
        log "ERROR" "No se pudo extraer Webmin"
        return 1
    fi
    
    # Mover a directorio de instalación
    local webmin_dir="/usr/local/webmin"
    echo -e "${CYAN}Instalando Webmin en $webmin_dir...${NC}"
    
    if sudo mkdir -p "$webmin_dir" && sudo cp -r webmin-master/* "$webmin_dir/"; then
        echo -e "${GREEN}✓${NC} Webmin instalado en $webmin_dir"
        log "SUCCESS" "Webmin instalado"
    else
        echo -e "${RED}✗${NC} Error al instalar Webmin (requiere sudo)"
        log "ERROR" "No se pudo instalar Webmin"
        return 1
    fi
    
    # Configurar Webmin
    echo -e "${CYAN}Configurando Webmin...${NC}"
    cd "$webmin_dir"
    
    if sudo ./setup.sh; then
        echo -e "${GREEN}✓${NC} Webmin configurado correctamente"
        log "SUCCESS" "Webmin configurado"
    else
        echo -e "${RED}✗${NC} Error al configurar Webmin"
        log "ERROR" "No se pudo configurar Webmin"
        return 1
    fi
    
    # Limpiar archivos temporales
    rm -rf "$temp_dir"
    
    echo -e "${GREEN}✓${NC} Webmin instalado correctamente"
    echo -e "${CYAN}Acceda a Webmin en: https://localhost:10000${NC}"
    
    return 0
}

# Función para verificar puertos
check_ports() {
    log "INFO" "Verificando puertos importantes..."
    
    echo -e "\n${BLUE}=== ESTADO DE PUERTOS ===${NC}"
    
    local ports=("80:HTTP" "443:HTTPS" "3306:MySQL" "5432:PostgreSQL" "10000:Webmin")
    
    for port_info in "${ports[@]}"; do
        local port=$(echo "$port_info" | cut -d: -f1)
        local service=$(echo "$port_info" | cut -d: -f2)
        
        if lsof -i :"$port" &> /dev/null; then
            echo -e "${GREEN}✓${NC} Puerto $port ($service) está en uso"
            log "SUCCESS" "Puerto $port está activo"
        else
            echo -e "${YELLOW}⚠${NC} Puerto $port ($service) está libre"
            log "INFO" "Puerto $port está libre"
        fi
    done
}

# Función para generar reporte de errores
generate_error_report() {
    log "INFO" "Generando reporte de errores..."
    
    local report_file="/tmp/reporte_errores_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
# REPORTE DE DIAGNÓSTICO DE ERRORES
# Generado: $DATE
# Hostname: $HOSTNAME
# Sistema: $OS

## PROBLEMAS IDENTIFICADOS

EOF
    
    # Verificar si Webmin está instalado
    if ! command -v webmin &> /dev/null && [ ! -d "/usr/local/webmin" ]; then
        echo "- Webmin no está instalado" >> "$report_file"
    fi
    
    # Verificar si Virtualmin está instalado
    if ! command -v virtualmin &> /dev/null; then
        echo "- Virtualmin no está instalado" >> "$report_file"
    fi
    
    # Verificar servicios web
    if ! brew services list | grep -q "httpd.*started"; then
        echo "- Apache no está ejecutándose" >> "$report_file"
    fi
    
    # Verificar base de datos
    if ! brew services list | grep -q "mysql.*started"; then
        echo "- MySQL no está ejecutándose" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## RECOMENDACIONES

1. Instalar Homebrew si no está disponible
2. Instalar y configurar servicios web (Apache)
3. Instalar y configurar base de datos (MySQL)
4. Instalar Webmin manualmente para macOS
5. Configurar Virtualmin después de Webmin

## COMANDOS SUGERIDOS

# Instalar Homebrew
/bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Instalar servicios
brew install httpd mysql
brew services start httpd
brew services start mysql

# Ejecutar este script para instalar Webmin
./diagnosticar_y_corregir_errores.sh --install-webmin

EOF
    
    echo -e "${GREEN}✓${NC} Reporte generado: $report_file"
    log "SUCCESS" "Reporte generado en $report_file"
    
    # Mostrar reporte
    echo -e "\n${BLUE}=== REPORTE DE ERRORES ===${NC}"
    cat "$report_file"
}

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  -h, --help              Muestra esta ayuda"
    echo "  -d, --diagnose          Solo diagnostica problemas"
    echo "  -f, --fix               Diagnostica y corrige problemas"
    echo "  -w, --install-webmin    Instala Webmin para macOS"
    echo "  -r, --report            Genera reporte de errores"
    echo ""
    echo "Ejemplos:"
    echo "  $0 --diagnose          Solo diagnostica"
    echo "  $0 --fix               Diagnostica y corrige"
    echo "  $0 --install-webmin    Instala Webmin"
    echo ""
}

# Función principal
main() {
    local action="diagnose"
    
    # Procesar argumentos
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--diagnose)
                action="diagnose"
                ;;
            -f|--fix)
                action="fix"
                ;;
            -w|--install-webmin)
                action="install-webmin"
                ;;
            -r|--report)
                action="report"
                ;;
            *)
                echo "Opción desconocida: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
    
    # Mostrar banner
    show_banner
    
    # Detectar sistema operativo
    detect_os
    
    # Verificar Homebrew
    check_homebrew
    
    case "$action" in
        "diagnose")
            log "INFO" "Iniciando diagnóstico..."
            check_web_services
            check_database_services
            check_ports
            ;;
        "fix")
            log "INFO" "Iniciando diagnóstico y corrección..."
            check_web_services
            check_database_services
            check_ports
            ;;
        "install-webmin")
            log "INFO" "Instalando Webmin..."
            install_webmin_macos
            ;;
        "report")
            log "INFO" "Generando reporte..."
            generate_error_report
            ;;
    esac
    
    echo -e "\n${GREEN}=== DIAGNÓSTICO COMPLETADO ===${NC}"
    echo "Log guardado en: $LOG_FILE"
    
    if [ "$action" != "report" ]; then
        echo -e "\n${CYAN}Para generar un reporte completo, ejecute:${NC}"
        echo "  $0 --report"
    fi
}

# Ejecutar función principal
main "$@"

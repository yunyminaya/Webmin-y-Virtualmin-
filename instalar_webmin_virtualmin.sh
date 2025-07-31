#!/bin/bash

# =============================================================================
# INSTALADOR RÁPIDO DE WEBMIN Y VIRTUALMIN
# Un solo comando para instalar todo el panel completo
# Uso: curl -sSL https://raw.githubusercontent.com/tu-repo/instalador.sh | bash
# =============================================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
REPO_URL="https://github.com/yunyminaya/Wedmin-Y-Virtualmin.git"
INSTALL_DIR="/tmp/webmin_virtualmin_install"
SCRIPT_NAME="instalacion_completa_automatica.sh"

echo "═══════════════════════════════════════════════════════════════════════════════"
echo -e "${GREEN}🚀 INSTALADOR RÁPIDO DE WEBMIN Y VIRTUALMIN${NC}"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo

# Función para logging
log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Verificar si git está instalado
if ! command -v git >/dev/null 2>&1; then
    log_error "Git no está instalado. Instalando..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew >/dev/null 2>&1; then
            brew install git
        else
            log_error "Homebrew no está instalado. Por favor instale git manualmente."
            exit 1
        fi
    elif command -v apt-get >/dev/null 2>&1; then
        # Ubuntu/Debian
        sudo apt-get update && sudo apt-get install -y git
    elif command -v yum >/dev/null 2>&1; then
        # CentOS/RHEL
        sudo yum install -y git
    elif command -v dnf >/dev/null 2>&1; then
        # Fedora
        sudo dnf install -y git
    else
        log_error "No se pudo instalar git automáticamente. Por favor instálelo manualmente."
        exit 1
    fi
fi

# Limpiar directorio anterior si existe
if [[ -d "$INSTALL_DIR" ]]; then
    log "Limpiando instalación anterior..."
    rm -rf "$INSTALL_DIR"
fi

# Crear directorio temporal
log "Creando directorio temporal..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Clonar repositorio
log "Descargando archivos de instalación..."
if git clone "$REPO_URL" .; then
    log "✅ Repositorio descargado correctamente"
else
    log_error "❌ Error al descargar el repositorio"
    log_info "Intentando descarga alternativa..."
    
    # Método alternativo usando curl
    if command -v curl >/dev/null 2>&1; then
        curl -sSL "https://github.com/yunyminaya/Wedmin-Y-Virtualmin/archive/main.zip" -o repo.zip
        if command -v unzip >/dev/null 2>&1; then
            unzip -q repo.zip
            mv Wedmin-Y-Virtualmin-main/* .
            rm -rf Wedmin-Y-Virtualmin-main repo.zip
        else
            log_error "unzip no está disponible. Instalando..."
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # En macOS unzip viene preinstalado
                unzip -q repo.zip
            elif command -v apt-get >/dev/null 2>&1; then
                sudo apt-get install -y unzip
                unzip -q repo.zip
            else
                log_error "No se pudo extraer el archivo. Por favor instale unzip."
                exit 1
            fi
        fi
    else
        log_error "No se pudo descargar el repositorio. Verifique su conexión a internet."
        exit 1
    fi
fi

# Verificar que el script principal existe
if [[ ! -f "$SCRIPT_NAME" ]]; then
    log_error "❌ Script de instalación no encontrado: $SCRIPT_NAME"
    log_info "Archivos disponibles:"
    ls -la
    exit 1
fi

# Hacer ejecutable el script
chmod +x "$SCRIPT_NAME"

# Mostrar información antes de ejecutar
echo
log_info "📋 INFORMACIÓN DE LA INSTALACIÓN:"
echo "   • Se instalará Webmin y Virtualmin completo"
echo "   • Se configurarán MySQL, Apache y PHP"
echo "   • Se creará un usuario admin con contraseña temporal"
echo "   • El proceso puede tomar 10-30 minutos dependiendo de su sistema"
echo

# Preguntar confirmación
read -p "¿Desea continuar con la instalación? (s/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
    log "Instalación cancelada por el usuario"
    exit 0
fi

echo
log "🚀 Iniciando instalación automática..."
echo

# Ejecutar script principal
if bash "$SCRIPT_NAME"; then
    echo
    log "✅ ¡Instalación completada exitosamente!"
    echo
    echo -e "${GREEN}🎉 WEBMIN Y VIRTUALMIN ESTÁN LISTOS${NC}"
    echo
    echo -e "${BLUE}📱 ACCESO RÁPIDO:${NC}"
    echo "   🌐 URL: https://localhost:10000"
    echo "   👤 Usuario: admin"
    echo "   🔑 Contraseña: admin123"
    echo
    echo -e "${YELLOW}⚠️  IMPORTANTE:${NC}"
    echo "   • Cambie la contraseña después del primer acceso"
    echo "   • Complete el asistente de post-instalación"
    echo "   • Configure SSL para producción"
    echo
else
    log_error "❌ Error durante la instalación"
    echo
    echo -e "${YELLOW}🔧 SOLUCIÓN DE PROBLEMAS:${NC}"
    echo "   • Verifique los logs en /tmp/instalacion_webmin_*.log"
    echo "   • Ejecute el script de verificación: ./verificar_asistente_wizard.sh"
    echo "   • Consulte la documentación en SOLUCION_ASISTENTE_POSTINSTALACION.md"
    echo
    exit 1
fi

# Limpiar archivos temporales
log "Limpiando archivos temporales..."
cd /
rm -rf "$INSTALL_DIR"

echo
echo "═══════════════════════════════════════════════════════════════════════════════"
echo -e "${GREEN}✨ INSTALACIÓN COMPLETADA - ¡DISFRUTE DE SU NUEVO PANEL!${NC}"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo
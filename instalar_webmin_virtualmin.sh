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
WEBMIN_USER="root"

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

# Función para generar credenciales basadas en SSH
generate_ssh_credentials() {
    log_info "🔐 Generando credenciales desde clave SSH del servidor..."
    
    # Buscar claves SSH existentes
    local ssh_key_found=false
    local ssh_key_path=""
    
    # Buscar en directorio del usuario actual
    for key_type in id_rsa id_ed25519 id_ecdsa id_dsa; do
        if [[ -f "$HOME/.ssh/$key_type" ]]; then
            ssh_key_path="$HOME/.ssh/$key_type"
            ssh_key_found=true
            log_info "✅ Clave SSH encontrada: $ssh_key_path"
            break
        fi
    done
    
    # Si no se encuentra en el usuario, buscar claves del sistema (solo si tenemos permisos)
    if [[ "$ssh_key_found" == false ]]; then
        for key_type in ssh_host_rsa_key ssh_host_ed25519_key ssh_host_ecdsa_key ssh_host_dsa_key; do
            if [[ -f "/etc/ssh/$key_type" ]] && [[ -r "/etc/ssh/$key_type" ]]; then
                ssh_key_path="/etc/ssh/$key_type"
                ssh_key_found=true
                log_info "✅ Clave SSH del sistema encontrada: $ssh_key_path"
                break
            fi
        done
    fi
    
    # Si no hay claves SSH, generar una nueva
    if [[ "$ssh_key_found" == false ]]; then
        log_info "⚠️  No se encontraron claves SSH existentes"
        log_info "🔧 Generando nueva clave SSH Ed25519..."
        
        mkdir -p "$HOME/.ssh"
        ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519_webmin" -N "" -C "webmin-auto-generated" >/dev/null 2>&1
        ssh_key_path="$HOME/.ssh/id_ed25519_webmin"
        
        log_info "✅ Nueva clave SSH generada: $ssh_key_path"
    fi
    
    # Generar hash SHA256 de la clave para usar como contraseña
    WEBMIN_PASS=$(sha256sum "$ssh_key_path" | cut -d' ' -f1 | head -c 16)
    
    log_info "🔑 Credenciales generadas exitosamente"
    log_info "👤 Usuario: $WEBMIN_USER"
    log_info "🔐 Contraseña generada desde: $(basename "$ssh_key_path")"
    
    # Exportar variables para el script principal
    export WEBMIN_USER
    export WEBMIN_PASS
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
echo "   • Se creará un usuario root con contraseña desde clave SSH"
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

# Generar credenciales SSH antes de ejecutar
generate_ssh_credentials

# Ejecutar script principal
if bash "$SCRIPT_NAME"; then
    echo
    log "✅ ¡Instalación completada exitosamente!"
    echo
    echo -e "${GREEN}🎉 WEBMIN Y VIRTUALMIN ESTÁN LISTOS${NC}"
    echo
    echo -e "${BLUE}📱 ACCESO RÁPIDO:${NC}"
    echo "   🌐 URL: https://localhost:10000"
    echo "   👤 Usuario: $WEBMIN_USER"
    echo "   🔑 Contraseña: $WEBMIN_PASS (desde clave SSH)"
    echo
    echo -e "${YELLOW}⚠️  IMPORTANTE:${NC}"
    echo "   • La contraseña se generó desde la clave SSH del servidor"
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
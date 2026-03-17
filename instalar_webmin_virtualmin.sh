#!/bin/bash

# Instalador unificado para Webmin/Virtualmin
# Versión: 3.0 Enterprise

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para verificar root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}Re-ejecutando instalador con sudo...${NC}"

        if command -v sudo >/dev/null 2>&1; then
            curl -fsSL "https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/instalar_webmin_virtualmin.sh" | sudo bash
            exit $?
        fi

        echo -e "${RED}Error: Este script debe ejecutarse como root (sudo no disponible)${NC}" >&2
        exit 1
    fi
}

# Función para verificar sistema operativo
check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        echo -e "${RED}Error: No se pudo determinar el sistema operativo${NC}"
        exit 1
    fi
}

# Función para verificar requisitos del sistema
check_system_requirements() {
    # Verificar memoria RAM (mínimo 2GB, recomendado 4GB)
    local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_gb=$((mem_kb / 1024 / 1024))

    if [ "$mem_gb" -lt 2 ]; then
        echo -e "${RED}Error: Memoria RAM insuficiente (${mem_gb}GB). Mínimo requerido: 2GB${NC}"
        exit 1
    elif [ "$mem_gb" -lt 4 ]; then
        echo -e "${YELLOW}Advertencia: Memoria RAM limitada (${mem_gb}GB). Se recomiendan 4GB o más${NC}"
    fi

    # Verificar espacio en disco (mínimo 20GB, recomendado 50GB)
    local disk_kb=$(df -k / | tail -1 | awk '{print $4}')
    local disk_gb=$((disk_kb / 1024 / 1024))

    if [ "$disk_gb" -lt 20 ]; then
        echo -e "${RED}Error: Espacio en disco insuficiente (${disk_gb}GB). Mínimo requerido: 20GB${NC}"
        exit 1
    elif [ "$disk_gb" -lt 50 ]; then
        echo -e "${YELLOW}Advertencia: Espacio en disco limitado (${disk_gb}GB). Se recomiendan 50GB o más${NC}"
    fi
}

# Función para instalar dependencias
install_dependencies() {
    echo -e "${GREEN}Instalando dependencias...${NC}"
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y curl software-properties-common apt-transport-https
            ;;
        centos|rhel|fedora)
            if command -v dnf >/dev/null; then
                dnf install -y curl epel-release
            else
                yum install -y curl epel-release
            fi
            ;;
        *)
            echo -e "${RED}Error: Sistema operativo no soportado: $OS${NC}"
            exit 1
            ;;
    esac
}

# Función para instalar Webmin
install_webmin() {
    echo -e "${GREEN}Instalando Webmin...${NC}"
    
    case $OS in
        ubuntu|debian)
            curl -o /etc/apt/trusted.gpg.d/webmin.gpg https://download.webmin.com/jcameron-key.asc
            echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
            apt-get update
            apt-get install -y webmin
            ;;
        centos|rhel|fedora)
            curl -o /etc/yum.repos.d/webmin.repo https://download.webmin.com/download/yum/webmin.repo
            if command -v dnf >/dev/null; then
                dnf install -y webmin
            else
                yum install -y webmin
            fi
            ;;
    esac
    
    # Iniciar Webmin automáticamente después de la instalación
    echo -e "${GREEN}Iniciando Webmin...${NC}"
    if command -v systemctl >/dev/null; then
        systemctl start webmin
        systemctl enable webmin
        sleep 2
        
        # Verificar que Webmin esté corriendo
        if systemctl is-active --quiet webmin; then
            echo -e "${GREEN}✅ Webmin iniciado y habilitado correctamente${NC}"
        else
            echo -e "${YELLOW}⚠️  Webmin no pudo iniciarse automáticamente${NC}"
            echo -e "${YELLOW}   Ejecute: systemctl start webmin${NC}"
        fi
    else
        service webmin start
        echo -e "${GREEN}✅ Webmin iniciado${NC}"
    fi
}

# Función para instalar Virtualmin
install_virtualmin() {
    echo -e "${GREEN}Instalando Virtualmin...${NC}"
    curl -sSL https://raw.githubusercontent.com/virtualmin/virtualmin-installer/master/install.sh | bash
    
    # Iniciar Virtualmin automáticamente después de la instalación
    echo -e "${GREEN}Iniciando Virtualmin...${NC}"
    if command -v systemctl >/dev/null; then
        systemctl restart webmin 2>/dev/null || systemctl start webmin
        sleep 3
        
        # Verificar que Virtualmin esté corriendo
        if systemctl is-active --quiet webmin; then
            echo -e "${GREEN}✅ Virtualmin iniciado correctamente${NC}"
        else
            echo -e "${YELLOW}⚠️  Virtualmin no pudo iniciarse automáticamente${NC}"
            echo -e "${YELLOW}   Ejecute: systemctl restart webmin${NC}"
        fi
    else
        service webmin restart 2>/dev/null || service webmin start
        echo -e "${GREEN}✅ Virtualmin iniciado${NC}"
    fi
}

# Función para configurar seguridad
configure_security() {
    echo -e "${GREEN}Configurando seguridad...${NC}"

    # Habilitar firewall
    if command -v ufw >/dev/null; then
        ufw allow 10000/tcp
        ufw reload
    elif command -v firewall-cmd >/dev/null; then
        firewall-cmd --permanent --add-port=10000/tcp
        firewall-cmd --reload
    fi

    # Configurar autenticación de dos factores
    if [ -f /etc/webmin/miniserv.conf ]; then
        echo "twofactor=1" >> /etc/webmin/miniserv.conf
        if command -v systemctl >/dev/null; then
            systemctl restart webmin
        else
            service webmin restart
        fi
    fi
}

# Función para instalar túnel automático (modo autónomo)
install_auto_tunnel() {
    local enable_auto_tunnel="${ENABLE_AUTO_TUNNEL:-true}"

    if [[ "$enable_auto_tunnel" != "true" ]]; then
        echo -e "${YELLOW}Túnel automático deshabilitado por configuración (ENABLE_AUTO_TUNNEL=false)${NC}"
        return 0
    fi

    echo -e "${GREEN}Instalando sistema de túnel automático...${NC}"

    local tunnel_installer_url="https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install_auto_tunnel_system.sh"
    local tunnel_installer_tmp="/tmp/install_auto_tunnel_system.sh"

    if ! curl -fsSL "$tunnel_installer_url" -o "$tunnel_installer_tmp"; then
        echo -e "${YELLOW}Advertencia: No se pudo descargar el instalador de túnel automático${NC}"
        return 0
    fi

    chmod +x "$tunnel_installer_tmp"

    if ! bash "$tunnel_installer_tmp" auto; then
        echo -e "${YELLOW}Advertencia: La instalación del túnel automático falló, continuando instalación principal${NC}"
        return 0
    fi

    echo -e "${GREEN}Túnel automático instalado y configurado${NC}"
}

# Función principal
main() {
    check_root
    check_os
    check_system_requirements
    install_dependencies
    install_webmin
    install_virtualmin
    configure_security
    install_auto_tunnel

    # Determinar IP de acceso del servidor (priorizar IP real sobre hostname)
    local server_ip=""
    server_ip=$(hostname -I 2>/dev/null | awk '{print $1}')

    if [[ -z "$server_ip" ]]; then
        server_ip=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}')
    fi

    if [[ -z "$server_ip" ]]; then
        server_ip=$(hostname -f 2>/dev/null || hostname)
    fi
    
    echo -e "${GREEN}Instalación completada con éxito!${NC}"
    echo -e "Accede a la interfaz en: https://${server_ip}:10000"
    echo -e "Estado túnel automático: systemctl status auto-tunnel"
}

# Ejecutar función principal
main

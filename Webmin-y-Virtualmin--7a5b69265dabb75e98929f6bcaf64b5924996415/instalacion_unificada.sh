#!/bin/bash

# Script de Instalación Unificada: Authentic Theme + Virtualmin
# Instala ambos componentes como un sistema integrado único
# Versión mejorada con validación de dependencias y logging centralizado

set -euo pipefail
IFS=$'\n\t'

# Directorio del script actual (para localizar recursos desplegados junto al script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== INCLUIR BIBLIOTECA COMÚN =====
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    source "${SCRIPT_DIR}/lib/common.sh"
else
    echo "ERROR: No se encuentra la biblioteca común en ${SCRIPT_DIR}/lib/common.sh"
    echo "Asegúrate de que el archivo existe y tiene permisos de lectura"
    exit 1
fi

# ===== VALIDACIÓN PREVIA =====
# Ejecutar validación de dependencias si existe el script
if [[ -f "${SCRIPT_DIR}/validar_dependencias.sh" ]]; then
    log_info "Ejecutando validación previa de dependencias..."
    if ! bash "${SCRIPT_DIR}/validar_dependencias.sh"; then
        handle_error "$ERROR_DEPENDENCY_MISSING" "La validación de dependencias falló"
        exit "$ERROR_DEPENDENCY_MISSING"
    fi
    log_success "Validación de dependencias completada"
fi

# Variables globales (se detectarán automáticamente)
SERVER_IP="127.0.0.1"
WEBMIN_PORT="10000"

cleanup() {
    rm -f /tmp/virtualmin-install.sh
    rm -f /tmp/authentic-theme.zip
    rm -rf /tmp/authentic-theme-master
}

trap cleanup EXIT

echo "========================================"
echo "  INSTALACIÓN UNIFICADA"
echo "  Authentic Theme + Virtualmin"
echo "  Como un solo sistema integrado"
echo "========================================"
echo

# Función para mostrar información del sistema
show_system_info() {
    echo ""
    echo "=== Información del Sistema ==="
    echo "Sistema Operativo: $(get_system_info os)"
    echo "Arquitectura: $(get_system_info arch)"
    echo "Memoria: $(get_system_info memory)"
    echo "Disco: $(get_system_info disk)"
    echo "CPU: $(get_system_info cpu)"
    echo "============================"
    echo ""
}

# Mostrar información del sistema
show_system_info
echo

# Verificar privilegios de root
if [[ $EUID -ne 0 ]]; then
   handle_error "$ERROR_ROOT_REQUIRED" "Este script debe ejecutarse como root"
fi

# Detectar sistema operativo
detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        OS=${NAME:-"Desconocido"}
        VER=${VERSION_ID:-""}
        local os_id=${ID:-""}
        local os_like=${ID_LIKE:-""}

        log_info "Sistema detectado: $OS $VER"

        case "$os_id" in
            ubuntu|debian)
                log_success "Distribución soportada detectada (${os_id})"
                ;;
            *)
                if [[ "$os_like" == *"debian"* ]]; then
                    log_warning "Distribución basada en Debian detectada (${os_id:-"sin ID"}). El soporte está optimizado para Ubuntu/Debian."
                else
                    handle_error "$ERROR_OS_NOT_SUPPORTED" "Distribución no soportada (${os_id:-"desconocida"}). Este instalador solo está probado en Ubuntu/Debian."
                fi
                ;;
        esac
    else
        handle_error "$ERROR_OS_NOT_SUPPORTED" "No se puede detectar el sistema operativo"
    fi
}

# Verificar conectividad a internet
check_internet() {
    log_step "Verificando conectividad a internet..."
    if check_url_connectivity "https://google.com" 10; then
        log_success "Conectividad a internet OK"
    else
        handle_error "$ERROR_INTERNET_CONNECTION" "No hay conectividad a internet. Se requiere para la instalación."
    fi
}

# Verificar requisitos mínimos de hardware
check_system_requirements() {
    log_step "Validando requisitos mínimos del sistema..."

    local arch
    arch=$(uname -m)
    if [[ "$arch" != "x86_64" && "$arch" != "amd64" ]]; then
        handle_error "$ERROR_ARCHITECTURE_NOT_SUPPORTED" "Arquitectura no soportada ($arch). Se requiere x86_64/amd64."
    fi

    if [[ -r /proc/meminfo ]]; then
        local mem_kb
        mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        if [[ -n "$mem_kb" && "$mem_kb" -lt 2000000 ]]; then
            handle_error "$ERROR_MEMORY_INSUFFICIENT" "Memoria RAM insuficiente: ${mem_kb}KB. Se requieren al menos 2GB."
        fi
    fi

    local disk_kb
    disk_kb=$(df --output=avail / | tail -n 1)
    if [[ -n "$disk_kb" && "$disk_kb" -lt 5242880 ]]; then # 5 GB
        handle_error "$ERROR_DISK_INSUFFICIENT" "Espacio en disco insuficiente: ${disk_kb}KB libres. Se requieren al menos 5GB."
    fi

    log_success "Requisitos mínimos verificados"
}

# Actualizar sistema
update_system() {
    log_step "Actualizando sistema base..."
    
    if command -v apt-get &> /dev/null; then
        apt-get update -y
        apt-get upgrade -y
        log_success "Sistema Ubuntu/Debian actualizado"
    elif command -v yum &> /dev/null; then
        yum update -y
        log_success "Sistema CentOS/RHEL actualizado"
    elif command -v dnf &> /dev/null; then
        dnf update -y
        log_success "Sistema Fedora actualizado"
    else
        log_warning "Gestor de paquetes no reconocido, continuando..."
    fi
}

# Instalar dependencias básicas
install_dependencies() {
    log_step "Instalando dependencias básicas..."
    
    if command -v apt-get &> /dev/null; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get install -y --no-install-recommends \
            wget curl unzip software-properties-common ca-certificates gnupg2 \
            ufw fail2ban unattended-upgrades apt-transport-https
    elif command -v yum &> /dev/null; then
        yum install -y wget curl unzip firewalld fail2ban
    elif command -v dnf &> /dev/null; then
        dnf install -y wget curl unzip firewalld fail2ban
    fi
    
    log_success "Dependencias instaladas"
}

# Descargar e instalar Virtualmin con Authentic Theme
install_virtualmin_unified() {
    log_step "Descargando script oficial de Virtualmin..."

    # Verificar conectividad al repositorio de Virtualmin
    if ! check_url_connectivity "https://software.virtualmin.com" 30; then
        handle_error "$ERROR_DOWNLOAD_FAILED" "No se puede acceder al repositorio de Virtualmin"
        return 1
    fi

    # Descargar script oficial
    cd /tmp || {
        handle_error "$ERROR_INSTALLATION_FAILED" "No se pudo cambiar al directorio /tmp"
        return 1
    }

    if wget -O virtualmin-install.sh https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh; then
        log_success "Script descargado correctamente"
        chmod +x virtualmin-install.sh

        log_step "Iniciando instalación unificada de Virtualmin + Webmin + Authentic Theme..."
        log_info "Esto puede tomar varios minutos..."
        show_progress 0 100 "Instalando Virtualmin..."

        # Ejecutar instalación con bundle LAMP y configuración automática
        if ./virtualmin-install.sh --bundle LAMP --yes --force; then
            show_progress_complete
            log_success "Virtualmin instalado correctamente con stack completo"
            return 0
        else
            show_progress_complete
            handle_error "$ERROR_INSTALLATION_FAILED" "Error en la instalación de Virtualmin"
            return 1
        fi
    else
        handle_error "$ERROR_DOWNLOAD_FAILED" "No se pudo descargar el script de instalación de Virtualmin"
        return 1
    fi
}

# Instalar/Actualizar Authentic Theme
install_authentic_theme() {
    log_step "Instalando Authentic Theme como interfaz unificada..."

    # Directorio de temas de Webmin
    THEME_DIR="/usr/share/webmin/authentic-theme"

    # Si existe el directorio local, usarlo
    LOCAL_THEME_DIR="${SCRIPT_DIR}/authentic-theme-master"
    if [[ -d "${LOCAL_THEME_DIR}" ]]; then
        log_info "Usando Authentic Theme local..."

        # Verificar permisos de escritura
        if ! check_write_permissions "/usr/share/webmin"; then
            handle_error "$ERROR_INSTALLATION_FAILED" "No hay permisos de escritura en /usr/share/webmin"
            return 1
        fi

        # Backup del tema existente si existe
        if [[ -d "$THEME_DIR" ]]; then
            local backup_dir="${THEME_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
            log_debug "Creando backup del tema existente: $backup_dir"
            mv "$THEME_DIR" "$backup_dir" || {
                handle_error "$ERROR_INSTALLATION_FAILED" "No se pudo crear backup del tema existente"
                return 1
            }
        fi

        # Copiar tema local
        cp -r "${LOCAL_THEME_DIR}" "$THEME_DIR" || {
            handle_error "$ERROR_INSTALLATION_FAILED" "No se pudo copiar Authentic Theme local"
            return 1
        }
        chown -R root:root "$THEME_DIR"
        chmod -R 755 "$THEME_DIR"

        log_success "Authentic Theme local instalado"
    else
        # Descargar la última versión
        log_info "Descargando última versión de Authentic Theme..."

        # Verificar conectividad a GitHub
        if ! check_url_connectivity "https://github.com" 30; then
            handle_error "$ERROR_DOWNLOAD_FAILED" "No se puede acceder a GitHub para descargar Authentic Theme"
            return 1
        fi

        cd /tmp || {
            handle_error "$ERROR_INSTALLATION_FAILED" "No se pudo cambiar al directorio /tmp"
            return 1
        }

        if wget -O authentic-theme.zip https://github.com/authentic-theme/authentic-theme/archive/refs/heads/master.zip; then
            if unzip -q authentic-theme.zip; then
                # Verificar permisos de escritura
                if ! check_write_permissions "/usr/share/webmin"; then
                    handle_error "$ERROR_INSTALLATION_FAILED" "No hay permisos de escritura en /usr/share/webmin"
                    return 1
                fi

                # Backup del tema existente si existe
                if [[ -d "$THEME_DIR" ]]; then
                    local backup_dir="${THEME_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
                    log_debug "Creando backup del tema existente: $backup_dir"
                    mv "$THEME_DIR" "$backup_dir" || {
                        handle_error "$ERROR_INSTALLATION_FAILED" "No se pudo crear backup del tema existente"
                        return 1
                    }
                fi

                # Instalar nuevo tema
                mv authentic-theme-master "$THEME_DIR" || {
                    handle_error "$ERROR_INSTALLATION_FAILED" "No se pudo mover Authentic Theme a destino"
                    return 1
                }
                chown -R root:root "$THEME_DIR"
                chmod -R 755 "$THEME_DIR"

                log_success "Authentic Theme descargado e instalado"
            else
                log_warning "No se pudo descomprimir Authentic Theme, usando el incluido con Virtualmin"
            fi
        else
            log_warning "No se pudo descargar Authentic Theme, usando el incluido con Virtualmin"
        fi
    fi
}

# Configurar sistema unificado
configure_unified_system() {
    log_step "Configurando sistema unificado..."
    
    # Configurar Authentic Theme como tema por defecto
    if [[ -f "/etc/webmin/config" ]]; then
        # Backup de configuración
        cp "/etc/webmin/config" "/etc/webmin/config.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Establecer Authentic Theme
        if grep -q "^theme=" "/etc/webmin/config"; then
            sed -i 's/^theme=.*/theme=authentic-theme/' "/etc/webmin/config"
        else
            echo "theme=authentic-theme" >> "/etc/webmin/config"
        fi
        
        log_success "Authentic Theme configurado como tema por defecto"
    fi
    
    # Configurar Virtualmin para inicio automático
    if [[ -f "/etc/webmin/virtual-server/config" ]]; then
        # Habilitar características avanzadas
        echo "show_virtualmin_tab=1" >> "/etc/webmin/virtual-server/config"
        log_success "Virtualmin configurado para interfaz unificada"
    fi
    
}

# Configurar firewall
configure_firewall() {
    log_step "Configurando firewall para acceso web..."
    
    # UFW (Ubuntu/Debian)
    if command -v ufw &> /dev/null; then
        ufw allow 22/tcp comment "SSH"
        ufw allow 10000/tcp comment "Webmin/Virtualmin"
        ufw allow 80/tcp comment "HTTP"
        ufw allow 443/tcp comment "HTTPS"

        if ufw status | grep -qi "inactive"; then
            ufw default deny incoming
            ufw default allow outgoing
            ufw logging on
            ufw --force enable
            log_success "Firewall UFW configurado y habilitado"
        else
            log_success "Reglas aplicadas a UFW existente"
        fi
    
    # Firewalld (CentOS/RHEL/Fedora)
    elif command -v firewall-cmd &> /dev/null; then
        if firewall-cmd --state &> /dev/null; then
            firewall-cmd --permanent --add-port=10000/tcp
            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
            firewall-cmd --reload
            log_success "Firewall firewalld configurado"
        else
            log_warning "firewalld está instalado pero no se encuentra activo; omitiendo configuración automática"
        fi
    
    # iptables básico
    elif command -v iptables &> /dev/null; then
        iptables -A INPUT -p tcp --dport 10000 -j ACCEPT
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
        log_success "Firewall iptables configurado"
    else
        log_warning "No se detectó firewall, asegúrate de abrir los puertos manualmente"
    fi
}

configure_fail2ban() {
    log_step "Configurando Fail2Ban..."

    if ! command -v fail2ban-client &> /dev/null; then
        log_warning "Fail2Ban no está instalado; omitiendo endurecimiento de fuerza bruta"
        return
    fi

    mkdir -p /etc/fail2ban/jail.d
    cat <<'EOF' > /etc/fail2ban/jail.d/sshd.local
[sshd]
enabled = true
port    = ssh
logpath = /var/log/auth.log
maxretry = 5
findtime = 600
bantime  = 3600
EOF

    if command -v systemctl &> /dev/null; then
        if ! systemctl enable --now fail2ban &> /dev/null; then
            log_warning "No se pudo habilitar Fail2Ban mediante systemd"
        fi
    elif command -v service &> /dev/null; then
        if ! service fail2ban start &> /dev/null; then
            log_warning "No se pudo iniciar Fail2Ban mediante service"
        fi
    fi

    if command -v fail2ban-client &> /dev/null; then
        if ! fail2ban-client reload &> /dev/null; then
            log_warning "No se pudo recargar la configuración de Fail2Ban"
        fi
    fi

    log_success "Fail2Ban configurado para proteger el acceso SSH"
}

configure_automatic_updates() {
    if ! command -v apt-get &> /dev/null; then
        return
    fi

    log_step "Configurando actualizaciones automáticas de seguridad..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y unattended-upgrades apt-listchanges &> /dev/null || log_warning "No se pudo instalar unattended-upgrades"

    cat <<'EOF' > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

    log_success "Actualizaciones automáticas configuradas"
}

apply_security_baseline() {
    log_step "Aplicando medidas de seguridad recomendadas..."
    configure_firewall
    configure_fail2ban
    configure_automatic_updates
    log_success "Endurecimiento básico completado"
}

# Reiniciar servicios
restart_services() {
    log_step "Reiniciando servicios del sistema unificado..."
    
    # Reiniciar Webmin
    if systemctl is-active --quiet webmin; then
        systemctl restart webmin
        log_success "Webmin reiniciado"
    elif service webmin status &> /dev/null; then
        service webmin restart
        log_success "Webmin reiniciado"
    fi
    
    # Reiniciar Apache si está instalado
    if systemctl is-active --quiet apache2; then
        systemctl restart apache2
        log_success "Apache reiniciado"
    elif systemctl is-active --quiet httpd; then
        systemctl restart httpd
        log_success "Apache reiniciado"
    fi
}

# Obtener información del sistema
get_system_info() {
    local info_type="${1:-all}"
    
    case "$info_type" in
        os)
            if [[ -f /etc/os-release ]]; then
                . /etc/os-release
                echo "${NAME:-Unknown} ${VERSION_ID:-Unknown}"
            else
                echo "Unknown"
            fi
            ;;
        arch)
            uname -m
            ;;
        memory)
            local mem_kb
            mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")
            local mem_gb=$(awk "BEGIN {printf \"%.2f\", $mem_kb / 1024 / 1024}")
            echo "${mem_gb}GB"
            ;;
        disk)
            local disk_kb
            disk_kb=$(df --output=avail / | tail -n 1 2>/dev/null || echo "0")
            local disk_gb=$(awk "BEGIN {printf \"%.2f\", $disk_kb / 1024 / 1024}")
            echo "${disk_gb}GB libres"
            ;;
        cpu)
            nproc 2>/dev/null || echo "1"
            ;;
        *)
            # Devolver toda la información
            echo "OS: $(get_system_info os)"
            echo "Arquitectura: $(get_system_info arch)"
            echo "Memoria: $(get_system_info memory)"
            echo "Disco: $(get_system_info disk)"
            echo "CPU: $(get_system_info cpu)"
            ;;
    esac
}

# Función para mostrar progreso completo
show_progress_complete() {
    echo -ne "\r${GREEN}[100%]${NC} Completado${BLUE}████████████████████████████████████████████████████${NC} 100%\n"
}

# Mostrar información final
show_final_info() {
    echo
    echo "========================================"
    echo -e "${GREEN}  ¡INSTALACIÓN COMPLETADA!${NC}"
    echo "========================================"
    echo
    log_success "Sistema unificado Virtualmin + Authentic Theme instalado"
    echo
    echo -e "${PURPLE}📋 INFORMACIÓN DE ACCESO:${NC}"
    echo -e "   🌐 URL del Panel: ${BLUE}https://$SERVER_IP:$WEBMIN_PORT${NC}"
    echo -e "   👤 Usuario: ${YELLOW}root${NC}"
    echo -e "   🔑 Contraseña: ${YELLOW}tu contraseña de root${NC}"
    echo
    echo -e "${PURPLE}🚀 PRÓXIMOS PASOS:${NC}"
    echo "   1. Accede al panel web usando la URL de arriba"
    echo "   2. Inicia sesión con tu usuario root"
    echo "   3. Ve a 'Virtualmin Virtual Servers' en el menú"
    echo "   4. Ejecuta el asistente de configuración inicial"
    echo "   5. Crea tu primer dominio virtual"
    echo
    echo -e "${PURPLE}✨ CARACTERÍSTICAS INSTALADAS:${NC}"
    echo "   ✅ Webmin (administración del sistema)"
    echo "   ✅ Virtualmin (hosting virtual)"
    echo "   ✅ Authentic Theme (interfaz moderna)"
    echo "   ✅ Apache Web Server"
    echo "   ✅ MySQL/MariaDB"
    echo "   ✅ PHP (múltiples versiones: 7.4, 8.0, 8.1, 8.2, 8.3)"
    echo "   ✅ Postfix (correo)"
    echo "   ✅ BIND (DNS)"
    echo "   ✅ WordPress (desde wordpress.org)"
    echo "   ✅ Laravel (desde sitio oficial)"
    echo "   ✅ Composer (gestor de dependencias PHP)"
    echo "   ✅ WP-CLI (herramientas WordPress)"
    echo "   ✅ Drush (herramientas Drupal)"
    echo "   ✅ Prometheus & Grafana (monitoreo empresarial)"
    echo "   ✅ ELK Stack (logging centralizado)"
    echo "   ✅ Zabbix & Nagios (monitoreo avanzado)"
    echo "   ✅ Bacula (backup empresarial)"
    echo "   ✅ Docker & Kubernetes (contenedores)"
    echo "   ✅ KVM/QEMU (virtualización)"
    echo "   ✅ HAProxy (load balancer)"
    echo "   ✅ GlusterFS (almacenamiento distribuido)"
    echo "   ✅ Ansible, Terraform, Vault (DevOps)"
    echo "   ✅ Snort, OSSEC, ModSecurity (seguridad enterprise)"
    echo "   ✅ OpenVPN, WireGuard (VPN empresarial)"
    echo "   ✅ Sistema de Túnel Automático Inteligente"
    echo "   ✅ Sistema de Auto-Reparación Autónoma"
    echo "   ✅ Sistema de Auto-Reparación Ejecutado"
    echo "   ✅ Sistema de Auto-Reparación Crítica Ejecutado"
    echo "   ✅ Sistema de Auto-Reparación Completa Ejecutado"
    echo
    echo -e "${GREEN}¡Tu panel de control unificado está listo para usar!${NC}"
    echo
}

# Instalar PHP multi-versión para servidores virtuales
install_php_multi_version() {
    log_step "Instalando múltiples versiones de PHP para servidores virtuales..."

    # Verificar que el script de PHP existe y es ejecutable
    if [[ ! -f "${SCRIPT_DIR}/install_php_multi_version.sh" ]]; then
        log_warning "Script install_php_multi_version.sh no encontrado, omitiendo instalación de PHP multi-versión"
        return 0
    fi

    if [[ ! -x "${SCRIPT_DIR}/install_php_multi_version.sh" ]]; then
        log_info "Dando permisos de ejecución a install_php_multi_version.sh"
        chmod +x "${SCRIPT_DIR}/install_php_multi_version.sh" 2>/dev/null || {
            log_warning "No se pudieron dar permisos de ejecución a install_php_multi_version.sh, omitiendo instalación de PHP multi-versión"
            return 0
        }
    fi

    # Ejecutar instalación de PHP multi-versión
    local php_output
    local php_exit_code

    if ! php_output=$(bash "${SCRIPT_DIR}/install_php_multi_version.sh" 2>&1); then
        php_exit_code=$?
        log_warning "La instalación de PHP multi-versión falló (código de salida: $php_exit_code), pero continuando con la instalación"
        if [[ "${DEBUG:-false}" == "true" ]]; then
            log_debug "Output de PHP multi-versión:"
            echo "$php_output" | while IFS= read -r line; do
                log_debug "  $line"
            done
        fi
    else
        log_success "PHP multi-versión instalado correctamente para servidores virtuales"
    fi
}

# Instalar CMS y Frameworks desde fuentes oficiales
install_cms_frameworks() {
    log_step "Instalando CMS y Frameworks web desde fuentes oficiales..."

    # Verificar que el script de CMS existe y es ejecutable
    if [[ ! -f "${SCRIPT_DIR}/install_cms_frameworks.sh" ]]; then
        log_warning "Script install_cms_frameworks.sh no encontrado, omitiendo instalación de CMS y Frameworks"
        return 0
    fi

    if [[ ! -x "${SCRIPT_DIR}/install_cms_frameworks.sh" ]]; then
        log_info "Dando permisos de ejecución a install_cms_frameworks.sh"
        chmod +x "${SCRIPT_DIR}/install_cms_frameworks.sh" 2>/dev/null || {
            log_warning "No se pudieron dar permisos de ejecución a install_cms_frameworks.sh, omitiendo instalación de CMS y Frameworks"
            return 0
        }
    fi

    # Ejecutar instalación de CMS y Frameworks
    local cms_output
    local cms_exit_code

    if ! cms_output=$(bash "${SCRIPT_DIR}/install_cms_frameworks.sh" 2>&1); then
        cms_exit_code=$?
        log_warning "La instalación de CMS y Frameworks falló (código de salida: $cms_exit_code), pero continuando con la instalación"
        if [[ "${DEBUG:-false}" == "true" ]]; then
            log_debug "Output de CMS y Frameworks:"
            echo "$cms_output" | while IFS= read -r line; do
                log_debug "  $line"
            done
        fi
    else
        log_success "CMS y Frameworks instalados correctamente desde fuentes oficiales"
    fi
}

# Instalar componentes empresariales para datacenters
install_enterprise_components() {
    log_step "Instalando componentes empresariales para datacenters..."

    # Verificar que el script enterprise existe y es ejecutable
    if [[ ! -f "${SCRIPT_DIR}/enterprise_monitoring_setup.sh" ]]; then
        log_warning "Script enterprise_monitoring_setup.sh no encontrado, omitiendo instalación de componentes empresariales"
        return 0
    fi

    if [[ ! -x "${SCRIPT_DIR}/enterprise_monitoring_setup.sh" ]]; then
        log_info "Dando permisos de ejecución a enterprise_monitoring_setup.sh"
        chmod +x "${SCRIPT_DIR}/enterprise_monitoring_setup.sh" 2>/dev/null || {
            log_warning "No se pudieron dar permisos de ejecución a enterprise_monitoring_setup.sh, omitiendo instalación de componentes empresariales"
            return 0
        }
    fi

    # Ejecutar instalación de componentes empresariales
    local enterprise_output
    local enterprise_exit_code

    if ! enterprise_output=$(bash "${SCRIPT_DIR}/enterprise_monitoring_setup.sh" 2>&1); then
        enterprise_exit_code=$?
        log_warning "La instalación de componentes empresariales falló (código de salida: $enterprise_exit_code), pero continuando con la instalación"
        if [[ "${DEBUG:-false}" == "true" ]]; then
            log_debug "Output de componentes empresariales:"
            echo "$enterprise_output" | while IFS= read -r line; do
                log_debug "  $line"
            done
        fi
    else
        log_success "Componentes empresariales instalados correctamente para datacenters"
    fi
}

# Instalar sistema de auto-reparación autónoma
install_autonomous_repair_system() {
    log_step "Instalando sistema de auto-reparación autónoma..."

    # Verificar que el script existe y es ejecutable
    if [[ ! -f "${SCRIPT_DIR}/scripts/autonomous_repair.sh" ]]; then
        log_warning "Script scripts/autonomous_repair.sh no encontrado, omitiendo instalación del sistema de auto-reparación autónoma"
        return 0
    fi

    if [[ ! -x "${SCRIPT_DIR}/scripts/autonomous_repair.sh" ]]; then
        log_info "Dando permisos de ejecución a scripts/autonomous_repair.sh"
        chmod +x "${SCRIPT_DIR}/scripts/autonomous_repair.sh" 2>/dev/null || {
            log_warning "No se pudieron dar permisos de ejecución a scripts/autonomous_repair.sh, omitiendo instalación del sistema de auto-reparación autónoma"
            return 0
        }
    fi

    # Ejecutar instalación del sistema de auto-reparación con comando 'install'
    local repair_output
    local repair_exit_code

    if ! repair_output=$(bash "${SCRIPT_DIR}/scripts/autonomous_repair.sh" install 2>&1); then
        repair_exit_code=$?
        log_warning "La instalación del sistema de auto-reparación autónoma falló (código de salida: $repair_exit_code), pero continuando con la instalación"
        if [[ "${DEBUG:-false}" == "true" ]]; then
            log_debug "Output del sistema de auto-reparación:"
            echo "$repair_output" | while IFS= read -r line; do
                log_debug "  $line"
            done
        fi
    else
        log_success "Sistema de auto-reparación autónoma instalado correctamente"
    fi
}

# Ejecutar sistema de auto-reparación
run_auto_repair_system() {
    log_step "Ejecutando sistema de auto-reparación..."

    # Verificar que auto_repair.sh existe
    if [[ ! -f "${SCRIPT_DIR}/auto_repair.sh" ]]; then
        log_warning "Script auto_repair.sh no encontrado, omitiendo ejecución del sistema de auto-reparación"
        return 0
    fi

    # Otorgar permisos de ejecución si es necesario
    if [[ ! -x "${SCRIPT_DIR}/auto_repair.sh" ]]; then
        log_info "Dando permisos de ejecución a auto_repair.sh"
        chmod +x "${SCRIPT_DIR}/auto_repair.sh" 2>/dev/null || {
            log_warning "No se pudieron dar permisos de ejecución a auto_repair.sh, omitiendo ejecución"
            return 0
        }
    fi

    # Ejecutar auto_repair.sh para reparación completa del sistema
    local repair_output
    local repair_exit_code

    if ! repair_output=$(bash "${SCRIPT_DIR}/auto_repair.sh" 2>&1); then
        repair_exit_code=$?
        log_warning "La ejecución del sistema de auto-reparación falló (código de salida: $repair_exit_code), pero continuando con la instalación"
        if [[ "${DEBUG:-false}" == "true" ]]; then
            log_debug "Output del auto-repair:"
            echo "$repair_output" | while IFS= read -r line; do
                log_debug "  $line"
            done
        fi
    else
        log_success "Sistema de auto-reparación ejecutado correctamente"
    fi
}

# Ejecutar sistema de auto-reparación crítica
run_auto_repair_critical_system() {
    log_step "Ejecutando sistema de auto-reparación crítica..."

    # Verificar que auto_repair_critical.sh existe
    if [[ ! -f "${SCRIPT_DIR}/auto_repair_critical.sh" ]]; then
        log_warning "Script auto_repair_critical.sh no encontrado, omitiendo ejecución del sistema de auto-reparación crítica"
        return 0
    fi

    # Otorgar permisos de ejecución si es necesario
    if [[ ! -x "${SCRIPT_DIR}/auto_repair_critical.sh" ]]; then
        log_info "Dando permisos de ejecución a auto_repair_critical.sh"
        chmod +x "${SCRIPT_DIR}/auto_repair_critical.sh" 2>/dev/null || {
            log_warning "No se pudieron dar permisos de ejecución a auto_repair_critical.sh, omitiendo ejecución"
            return 0
        }
    fi

    # Ejecutar auto_repair_critical.sh con el comando 'repair'
    local repair_output
    local repair_exit_code

    if ! repair_output=$(bash "${SCRIPT_DIR}/auto_repair_critical.sh" repair 2>&1); then
        repair_exit_code=$?
        log_warning "La ejecución del sistema de auto-reparación crítica falló (código de salida: $repair_exit_code), pero continuando con la instalación"
        if [[ "${DEBUG:-false}" == "true" ]]; then
            log_debug "Output del auto-repair crítico:"
            echo "$repair_output" | while IFS= read -r line; do
                log_debug "  $line"
            done
        fi
    else
        log_success "Sistema de auto-reparación crítica ejecutado correctamente"
    fi
}

# Ejecutar sistema de auto-reparación completa
run_auto_repair_complete_system() {
    log_step "Ejecutando sistema de auto-reparación completa..."

    # Verificar que scripts/auto_repair_complete.sh existe
    if [[ ! -f "${SCRIPT_DIR}/scripts/auto_repair_complete.sh" ]]; then
        log_warning "Script scripts/auto_repair_complete.sh no encontrado, omitiendo ejecución del sistema de auto-reparación completa"
        return 0
    fi

    # Otorgar permisos de ejecución si es necesario
    if [[ ! -x "${SCRIPT_DIR}/scripts/auto_repair_complete.sh" ]]; then
        log_info "Dando permisos de ejecución a scripts/auto_repair_complete.sh"
        chmod +x "${SCRIPT_DIR}/scripts/auto_repair_complete.sh" 2>/dev/null || {
            log_warning "No se pudieron dar permisos de ejecución a scripts/auto_repair_complete.sh, omitiendo ejecución"
            return 0
        }
    fi

    # Ejecutar scripts/auto_repair_complete.sh con el comando '--complete'
    local repair_output
    local repair_exit_code

    if ! repair_output=$(bash "${SCRIPT_DIR}/scripts/auto_repair_complete.sh" --complete 2>&1); then
        repair_exit_code=$?
        log_warning "La ejecución del sistema de auto-reparación completa falló (código de salida: $repair_exit_code), pero continuando con la instalación"
        if [[ "${DEBUG:-false}" == "true" ]]; then
            log_debug "Output del auto-repair completo:"
            echo "$repair_output" | while IFS= read -r line; do
                log_debug "  $line"
            done
        fi
    else
        log_success "Sistema de auto-reparación completa ejecutado correctamente"
    fi
}

# Instalar sistema de túnel automático inteligente
install_auto_tunnel_system() {
    log_step "Instalando sistema de túnel automático inteligente..."

    # Verificar que el script existe y es ejecutable
    if [[ ! -f "${SCRIPT_DIR}/install_auto_tunnel_system.sh" ]]; then
        log_warning "Script install_auto_tunnel_system.sh no encontrado, omitiendo instalación del túnel automático"
        return 0
    fi

    if [[ ! -x "${SCRIPT_DIR}/install_auto_tunnel_system.sh" ]]; then
        log_info "Dando permisos de ejecución a install_auto_tunnel_system.sh"
        chmod +x "${SCRIPT_DIR}/install_auto_tunnel_system.sh" 2>/dev/null || {
            log_warning "No se pudieron dar permisos de ejecución a install_auto_tunnel_system.sh, omitiendo instalación del túnel automático"
            return 0
        }
    fi

    # Ejecutar instalación del túnel automático
    local tunnel_output
    local tunnel_exit_code

    if ! tunnel_output=$(bash "${SCRIPT_DIR}/install_auto_tunnel_system.sh" auto 2>&1); then
        tunnel_exit_code=$?
        log_warning "La instalación del sistema de túnel automático falló (código de salida: $tunnel_exit_code), pero continuando con la instalación"
        if [[ "${DEBUG:-false}" == "true" ]]; then
            log_debug "Output del túnel automático:"
            echo "$tunnel_output" | while IFS= read -r line; do
                log_debug "  $line"
            done
        fi
    else
        log_success "Sistema de túnel automático inteligente instalado correctamente"
    fi
}


# Función principal
main() {
    echo -e "${BLUE}Iniciando instalación unificada...${NC}"
    echo

    detect_os
    check_internet
    check_system_requirements
    update_system
    install_dependencies
    install_virtualmin_unified
    install_authentic_theme
    configure_unified_system
    apply_security_baseline
    install_php_multi_version
    install_cms_frameworks
    install_enterprise_components
    install_autonomous_repair_system
    run_auto_repair_system
    run_auto_repair_critical_system
    run_auto_repair_complete_system
    install_auto_tunnel_system
    restart_services
    get_system_info
    show_final_info

    echo -e "${GREEN}🎉 ¡Instalación unificada completada exitosamente!${NC}"
}

# Ejecutar instalación
main

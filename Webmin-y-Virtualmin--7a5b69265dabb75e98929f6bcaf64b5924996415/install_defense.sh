#!/bin/bash

# ============================================================================
# Instalador del Sistema de Auto-Defensa - Virtualmin/Webmin
# ============================================================================
# Instala y configura el sistema de auto-defensa completo
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
    echo "ERROR: No se encuentra la biblioteca común"
    exit 1
fi

# Variables de configuración
INSTALL_LOG="${INSTALL_LOG:-./logs/defense_install.log}"
BACKUP_DIR="${BACKUP_DIR:-./backups/pre_defense}"

# ============================================================================
# FUNCIONES DE INSTALACIÓN
# ============================================================================

# Función para verificar prerrequisitos
check_prerequisites() {
    log_install "🔍 Verificando prerrequisitos del sistema..."

    # Verificar que somos root
    if [[ $EUID -ne 0 ]]; then
        log_install "❌ Se requieren permisos de root para instalar el sistema de defensa"
        return 1
    fi

    # Verificar sistema operativo compatible
    if ! detect_and_validate_os; then
        log_install "❌ Sistema operativo no compatible"
        return 1
    fi

    # Verificar dependencias críticas
    local missing_deps=()

    if ! command_exists curl; then missing_deps+=("curl"); fi
    if ! command_exists netstat; then missing_deps+=("net-tools"); fi
    if ! command_exists pgrep; then missing_deps+=("procps"); fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_install "⚠️ Instalando dependencias faltantes: ${missing_deps[*]}"
        if ! install_packages "${missing_deps[@]}"; then
            log_install "❌ Error instalando dependencias"
            return 1
        fi
    fi

    log_install "✅ Prerrequisitos verificados correctamente"
    return 0
}

# Función para crear directorios necesarios
create_directories() {
    log_install "📁 Creando directorios necesarios..."

    local directories=(
        "logs"
        "backups"
        "backups/virtualmin_auto"
        "test_results"
        "defense_backups"
    )

    for dir in "${directories[@]}"; do
        if [[ ! -d "${SCRIPT_DIR}/${dir}" ]]; then
            ensure_directory "${SCRIPT_DIR}/${dir}"
            log_install "✅ Directorio creado: ${dir}"
        else
            log_install "ℹ️ Directorio ya existe: ${dir}"
        fi
    done
}

# Función para dar permisos de ejecución
set_permissions() {
    log_install "🔐 Configurando permisos de ejecución..."

    local scripts=(
        "auto_defense.sh"
        "auto_repair.sh"
        "auto_repair_critical.sh"
        "test_master.sh"
        "test_multi_distro.sh"
        "test_unit_functions.sh"
    )

    for script in "${scripts[@]}"; do
        if [[ -f "${SCRIPT_DIR}/${script}" ]]; then
            chmod +x "${SCRIPT_DIR}/${script}"
            log_install "✅ Permisos configurados: ${script}"
        else
            log_install "⚠️ Script no encontrado: ${script}"
        fi
    done
}

# Función para crear backup de configuraciones existentes
create_backup() {
    log_install "💾 Creando backup de configuraciones existentes..."

    ensure_directory "$BACKUP_DIR"

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/pre_defense_backup_${timestamp}.tar.gz"

    # Archivos y directorios a respaldar
    local backup_items=(
        "logs/"
        "backups/"
        "lib/common.sh"
    )

    local items_to_backup=()

    for item in "${backup_items[@]}"; do
        if [[ -e "${SCRIPT_DIR}/${item}" ]]; then
            items_to_backup+=("${SCRIPT_DIR}/${item}")
        fi
    done

    if [[ ${#items_to_backup[@]} -gt 0 ]]; then
        tar -czf "$backup_file" -C "$SCRIPT_DIR" "${items_to_backup[@]}" 2>/dev/null
        log_install "✅ Backup creado: $backup_file"
    else
        log_install "ℹ️ No hay elementos para respaldar"
    fi
}

# Función para instalar servicio systemd
install_service() {
    log_install "🔧 Instalando servicio systemd..."

    local service_file="/etc/systemd/system/virtualmin-defense.service"

    # Generar archivo de servicio dinámicamente con rutas correctas
    cat > "$service_file" << EOF
[Unit]
Description=Sistema de Auto-Defensa Virtualmin
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/bin/bash ${SCRIPT_DIR}/auto_defense.sh start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=virtualmin-defense

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ReadWritePaths=${SCRIPT_DIR}/logs ${SCRIPT_DIR}/backups

# Environment
Environment=DEFENSE_ACTIVE=true
Environment=MONITOR_INTERVAL=300

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$service_file"

    # Recargar systemd
    systemctl daemon-reload

    # Habilitar el servicio para que inicie automáticamente
    systemctl enable virtualmin-defense.service

    log_install "✅ Servicio instalado y habilitado"
}

# Función para configurar firewall básico
configure_firewall() {
    log_install "🔥 Configurando firewall básico..."

    if command_exists ufw; then
        log_install "Configurando UFW..."

        # Backup de configuración actual
        ufw status > "${SCRIPT_DIR}/logs/ufw_backup_$(date +%Y%m%d_%H%M%S).txt" 2>/dev/null || true

        # Configuración básica
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow ssh
        ufw allow 80
        ufw allow 443
        ufw allow 10000
        ufw --force enable

        log_install "✅ UFW configurado correctamente"

    elif command_exists firewall-cmd; then
        log_install "Configurando Firewalld..."

        # Configuración básica
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --permanent --add-port=10000/tcp
        firewall-cmd --reload

        log_install "✅ Firewalld configurado correctamente"

    else
        log_install "⚠️ No se detectó firewall gestionable (ufw/firewalld)"
        log_install "ℹ️ Considere instalar y configurar un firewall manualmente"
    fi
}

# Función para configurar logrotate
configure_logrotate() {
    log_install "📝 Configurando rotación de logs..."

    local logrotate_config="/etc/logrotate.d/virtualmin-defense"

    cat > "$logrotate_config" << EOF
${SCRIPT_DIR}/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        # Reiniciar servicio si es necesario
        systemctl reload virtualmin-defense.service || true
    endscript
}
EOF

    chmod 644 "$logrotate_config"
    log_install "✅ Configuración de logrotate creada"
}

# Función para crear script de desinstalación
create_uninstall_script() {
    log_install "📋 Creando script de desinstalación..."

    cat > "${SCRIPT_DIR}/uninstall_defense.sh" << 'EOF'
#!/bin/bash

# Script de Desinstalación del Sistema de Auto-Defensa
# Versión: 1.0.0

set -euo pipefail

echo "🗑️ Desinstalando Sistema de Auto-Defensa de Virtualmin..."

# Detener y deshabilitar servicio
if command_exists systemctl; then
    echo "Deteniendo servicio..."
    systemctl stop virtualmin-defense.service 2>/dev/null || true
    systemctl disable virtualmin-defense.service 2>/dev/null || true

    echo "Eliminando archivo de servicio..."
    rm -f /etc/systemd/system/virtualmin-defense.service
    systemctl daemon-reload
fi

# Eliminar archivos del sistema de defensa
echo "Eliminando archivos del sistema..."
rm -f auto_defense.sh
rm -f auto_repair.sh
rm -f auto_repair_critical.sh
rm -f virtualmin-defense.service
rm -f defense_dashboard.html
rm -rf logs/
rm -rf backups/virtualmin_auto/

# Eliminar configuración de logrotate
echo "Eliminando configuración de logrotate..."
rm -f /etc/logrotate.d/virtualmin-defense

echo "✅ Sistema de Auto-Defensa desinstalado completamente"
echo ""
echo "Nota: Los backups creados durante la operación del sistema"
echo "se conservan en el directorio 'backups/' por seguridad."
EOF

    chmod +x "${SCRIPT_DIR}/uninstall_defense.sh"
    log_install "✅ Script de desinstalación creado"
}

# Función para probar la instalación
test_installation() {
    log_install "🧪 Probando instalación..."

    # Verificar que los scripts sean ejecutables
    local scripts=("auto_defense.sh" "auto_repair.sh" "auto_repair_critical.sh")

    for script in "${scripts[@]}"; do
        if [[ ! -x "${SCRIPT_DIR}/${script}" ]]; then
            log_install "❌ Script no ejecutable: $script"
            return 1
        fi
    done

    # Verificar que el servicio se pueda iniciar
    if command_exists systemctl; then
        if ! systemctl status virtualmin-defense.service >/dev/null 2>&1; then
            log_install "⚠️ Servicio no está activo (esto es normal en instalación inicial)"
        else
            log_install "✅ Servicio activo y funcionando"
        fi
    fi

    # Probar comando de verificación
    if "${SCRIPT_DIR}/auto_defense.sh" status >/dev/null 2>&1; then
        log_install "✅ Comando de estado funciona correctamente"
    else
        log_install "❌ Error en comando de estado"
        return 1
    fi

    log_install "✅ Pruebas de instalación completadas exitosamente"
}

# ============================================================================
# FUNCIONES DE LOGGING
# ============================================================================

log_install() {
    local message="$1"
    local timestamp
    timestamp=$(get_timestamp)

    ensure_directory "$(dirname "$INSTALL_LOG")"

    echo "[$timestamp] INSTALL: $message" >> "$INSTALL_LOG"
    echo -e "${BLUE}[$timestamp INSTALL]${NC} $message"
}

# ============================================================================
# FUNCIÓN PRINCIPAL DE INSTALACIÓN
# ============================================================================

main() {
    local action="${1:-install}"

    case "$action" in
        "install")
            log_install "🚀 INICIANDO INSTALACIÓN DEL SISTEMA DE AUTO-DEFENSA"

            # Verificar prerrequisitos
            if ! check_prerequisites; then
                log_install "❌ Instalación cancelada - prerrequisitos no cumplidos"
                exit 1
            fi

            # Crear backup
            create_backup

            # Crear directorios
            create_directories

            # Configurar permisos
            set_permissions

            # Configurar firewall
            configure_firewall

            # Configurar logrotate
            configure_logrotate

            # Instalar servicio
            install_service

            # Crear script de desinstalación
            create_uninstall_script

            # Probar instalación
            if test_installation; then
                log_install "🎉 INSTALACIÓN COMPLETADA EXITOSAMENTE"
                log_install ""
                log_install "📋 COMANDOS DISPONIBLES:"
                log_install "  ./auto_defense.sh status     - Ver estado del sistema"
                log_install "  ./auto_defense.sh start      - Iniciar monitoreo continuo"
                log_install "  ./auto_defense.sh dashboard  - Ver dashboard de control"
                log_install "  ./auto_defense.sh defense    - Activar defensa manual"
                log_install "  ./uninstall_defense.sh       - Desinstalar el sistema"
                log_install ""
                log_install "🌐 DASHBOARD WEB: ./defense_dashboard.html"
                log_install "📊 LOGS: ./logs/auto_defense.log"
                log_install ""
                log_install "✅ El sistema se activará automáticamente al reiniciar"
            else
                log_install "❌ Error en las pruebas de instalación"
                exit 1
            fi
            ;;
        "uninstall")
            log_install "🗑️ DESINSTALANDO SISTEMA DE AUTO-DEFENSA"
            if [[ -f "${SCRIPT_DIR}/uninstall_defense.sh" ]]; then
                bash "${SCRIPT_DIR}/uninstall_defense.sh"
            else
                log_install "❌ Script de desinstalación no encontrado"
                exit 1
            fi
            ;;
        "status")
            log_install "📊 ESTADO DE LA INSTALACIÓN"
            if [[ -f "/etc/systemd/system/virtualmin-defense.service" ]]; then
                log_install "✅ Servicio systemd instalado"
            else
                log_install "❌ Servicio systemd no instalado"
            fi

            if [[ -f "${SCRIPT_DIR}/auto_defense.sh" ]] && [[ -x "${SCRIPT_DIR}/auto_defense.sh" ]]; then
                log_install "✅ Script principal ejecutable"
            else
                log_install "❌ Script principal no ejecutable"
            fi

            if [[ -d "${SCRIPT_DIR}/logs" ]]; then
                log_install "✅ Directorios de logs creados"
            else
                log_install "❌ Directorios de logs no creados"
            fi
            ;;
        "help"|*)
            echo "Instalador del Sistema de Auto-Defensa - Virtualmin"
            echo ""
            echo "Uso: $0 [acción]"
            echo ""
            echo "Acciones disponibles:"
            echo "  install   - Instalar el sistema completo de auto-defensa"
            echo "  uninstall - Desinstalar el sistema de auto-defensa"
            echo "  status    - Verificar estado de la instalación"
            echo "  help      - Mostrar esta ayuda"
            echo ""
            echo "Características que instala:"
            echo "  🛡️ Sistema de detección automática de ataques"
            echo "  🔧 Reparación automática de servidores virtuales"
            echo "  📊 Dashboard web con controles manuales"
            echo "  🔄 Servicio systemd para monitoreo continuo"
            echo "  🔥 Configuración automática de firewall"
            echo "  📝 Sistema de logs y rotación automática"
            echo ""
            echo "Ejemplos:"
            echo "  $0 install    # Instalar sistema completo"
            echo "  $0 status     # Verificar instalación"
            echo "  $0 uninstall  # Desinstalar sistema"
            ;;
    esac
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

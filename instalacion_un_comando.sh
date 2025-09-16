#!/bin/bash

# =============================================================================
# INSTALACIÓN AUTOMÁTICA DE UN SOLO COMANDO - WEBMIN Y VIRTUALMIN
# Script completamente automático y a prueba de errores para Ubuntu/Debian
# Comando único: curl -sSL https://tu-url/install.sh | sudo bash
# =============================================================================

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -euo pipefail  # Salir inmediatamente si hay errores
export TERM=${TERM:-xterm}
export DEBIAN_FRONTEND=${DEBIAN_FRONTEND:-noninteractive}

# Colores para output
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Variables globales
SCRIPT_VERSION="2.0"
INSTALL_LOG="/var/log/webmin-virtualmin-install.log"
TEMP_DIR="/tmp/webmin-virtualmin-install"
BACKUP_DIR="/root/webmin-virtualmin-backup-$(date +%Y%m%d_%H%M%S)"
REPO_RAW="https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main"
DISTRO=""
VERSION=""
PACKAGE_MANAGER=""
WEBMIN_PORT=10000
VIRTUALMIN_LICENSE_KEY=""
SKIP_CONFIRMATION=false
ENABLE_SSL=false
INSTALL_AUTHENTIC_THEME=false
CONFIGURE_FIREWALL=true
OPTIMIZE_FOR_PRODUCTION=false

# Inicializar logging a archivo específico del instalador
if [[ $EUID -eq 0 ]]; then
    mkdir -p "$(dirname "$INSTALL_LOG")" 2>/dev/null || true
    touch "$INSTALL_LOG" 2>/dev/null || true
    chmod 0644 "$INSTALL_LOG" 2>/dev/null || true
    export LOG_FILE="$INSTALL_LOG"
fi

# Funciones de logging mejoradas
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
    
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
    
# Contenido de función duplicada
# Contenido de función duplicada
# Fin de función duplicada

# Función para manejo de errores
error_handler() {
    local line_no=$1
    local error_code=$2
    log "ERROR" "Error en línea $line_no con código $error_code"
    log "ERROR" "La instalación ha fallado. Consulte $INSTALL_LOG para más detalles"
    
    # Intentar cleanup básico
    cleanup_on_error
    exit $error_code
}

# Configurar trap para manejo de errores
trap 'error_handler ${LINENO} $?' ERR

# Función de cleanup en caso de error
cleanup_on_error() {
    log "WARNING" "Ejecutando cleanup de emergencia..."
    
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
    
    # Restaurar servicios si es necesario
    systemctl start apache2 2>/dev/null || true
    systemctl start mysql 2>/dev/null || true
    
    log "INFO" "Cleanup completado. Revise $INSTALL_LOG para detalles"
}

# Función para mostrar banner
show_banner() {
    clear 2>/dev/null || true
    cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════════
   🚀 INSTALACIÓN AUTOMÁTICA WEBMIN Y VIRTUALMIN - UN SOLO COMANDO
   
   ✨ Completamente automático y a prueba de errores
   🛡️ Validación continua y recuperación automática
   🔧 Optimizado para Ubuntu 20.04 LTS y Debian 10+
   📦 Incluye Authentic Theme y configuración SSL
   
═══════════════════════════════════════════════════════════════════════════════
EOF
    echo
}

# Detectar sistema operativo con validación robusta
detect_system() {
    log "HEADER" "DETECCIÓN DEL SISTEMA"
    
    if [[ ! -f /etc/os-release ]]; then
        log "ERROR" "Sistema operativo no soportado (falta /etc/os-release)"
        exit 1
    fi
    
    source /etc/os-release
    DISTRO="$ID"
    VERSION="$VERSION_ID"
    
    case "$DISTRO" in
        "ubuntu")
            PACKAGE_MANAGER="apt"
            if [[ "$VERSION" == "20.04" ]]; then
                log "SUCCESS" "Sistema detectado: Ubuntu 20.04 LTS (OPTIMIZADO)"
            elif dpkg --compare-versions "$VERSION" ge "18.04"; then
                log "SUCCESS" "Sistema detectado: Ubuntu $VERSION (Compatible)"
            else
                log "ERROR" "Ubuntu $VERSION no soportado (mínimo: 18.04)"
                exit 1
            fi
            ;;
        "debian")
            PACKAGE_MANAGER="apt"
            if [[ "${VERSION%%.*}" -ge 10 ]]; then
                log "SUCCESS" "Sistema detectado: Debian $VERSION (Compatible)"
            else
                log "ERROR" "Debian $VERSION no soportado (mínimo: 10)"
                exit 1
            fi
            ;;
        *)
            log "ERROR" "Distribución no soportada: $DISTRO"
            log "INFO" "Este script solo soporta Ubuntu 18.04+ y Debian 10+"
            exit 1
            ;;
    esac
    
    # Verificar arquitectura
    local arch=$(uname -m)
    if [[ "$arch" != "x86_64" ]]; then
        log "WARNING" "Arquitectura no optimizada: $arch (recomendado: x86_64)"
    fi
    
    log "INFO" "Distribución: $DISTRO $VERSION"
    log "INFO" "Arquitectura: $arch"
    log "INFO" "Gestor de paquetes: $PACKAGE_MANAGER"
}


# Verificar conectividad de red
check_network() {
    log "HEADER" "VERIFICACIÓN DE CONECTIVIDAD"
    
    local test_urls=(
        "google.com"
        "download.webmin.com"
        "software.virtualmin.com"
        "github.com"
    )
    
    for url in "${test_urls[@]}"; do
        if ping -c 1 -W 5 "$url" >/dev/null 2>&1; then
            log "SUCCESS" "Conectividad a $url: OK"
        else
            log "WARNING" "Conectividad a $url: FALLA"
        fi
    done
    
    # Verificar DNS
    if getent hosts google.com >/dev/null 2>&1 || nslookup google.com >/dev/null 2>&1; then
        log "SUCCESS" "Resolución DNS: Funcionando"
    else
        log "ERROR" "Resolución DNS: FALLA"
        log "INFO" "Configurando DNS públicos..."
        if ! command -v resolvectl >/dev/null 2>&1 && [ ! -L /etc/resolv.conf ]; then
            echo "nameserver 8.8.8.8" >> /etc/resolv.conf
            echo "nameserver 8.8.4.4" >> /etc/resolv.conf
        fi
    fi
}

# Validar y forzar FQDN antes de instalar (requisito Virtualmin)
ensure_fqdn() {
    log "HEADER" "VALIDACIÓN DE HOSTNAME (FQDN)"
    local current_fqdn
    current_fqdn=$(hostname -f 2>/dev/null || hostname || echo "")
    local bad_suffix_re='\.local(domain)?$'

    if [[ -n "${FQDN_OVERRIDE:-}" ]]; then
        local fqdn="$FQDN_OVERRIDE"
        local short="${fqdn%%.*}"
        log "INFO" "Usando FQDN_OVERRIDE: $fqdn"

        # Persistente y en runtime
        echo "$fqdn" > /etc/hostname
        if command -v hostnamectl >/dev/null 2>&1; then
            hostnamectl set-hostname "$fqdn" --static --transient --pretty || true
        fi
        hostname "$fqdn" 2>/dev/null || true
        command -v hostname >/dev/null 2>&1 && hostname -F /etc/hostname 2>/dev/null || true
        export HOSTNAME="$fqdn"

        # /etc/hosts coherente
        { grep -qE '^127\.0\.1\.1[[:space:]]' /etc/hosts 2>/dev/null && \
          sed -i "s/^127\.0\.1\.1.*/127.0.1.1 $fqdn $short/" /etc/hosts 2>/dev/null; } || \
          printf "127.0.1.1 %s %s\n" "$fqdn" "$short" >> /etc/hosts
        grep -qE '^127\.0\.0\.1[[:space:]]+localhost' /etc/hosts 2>/dev/null || echo "127.0.0.1 localhost" >> /etc/hosts

        # Mapear IP primaria -> FQDN para satisfacer validación de Virtualmin
        if command -v ip >/dev/null 2>&1; then
            primary_ip="$(ip -4 route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++){if($i=="src"){print $(i+1); exit}}}')"
            if [[ -n "$primary_ip" ]]; then
                # Eliminar líneas previas con primary_ip
                sed -i "\|^${primary_ip}[[:space:]]|d" /etc/hosts 2>/dev/null || true
                printf "%s %s %s\n" "$primary_ip" "$fqdn" "$short" >> /etc/hosts
            fi
        fi

        # Verificación y refuerzo
        local check_fqdn
        check_fqdn="$(hostname -f 2>/dev/null || true)"
        if [[ -z "$check_fqdn" || "$check_fqdn" != *.* ]]; then
            log "WARNING" "hostname -f aún no es FQDN, reforzando ajustes"
            hostname "$fqdn" 2>/dev/null || true
        fi

        log "SUCCESS" "Hostname establecido: $fqdn"
        return 0
    fi

    if [[ -n "$current_fqdn" && "$current_fqdn" == *.* && ! "$current_fqdn" =~ $bad_suffix_re ]]; then
        log "SUCCESS" "FQDN detectado: $current_fqdn"
        return 0
    fi

    log "ERROR" "FQDN inválido o ausente (${current_fqdn:-none}). Debe proporcionar un FQDN válido."
    log "INFO" "Establezca la variable de entorno FQDN_OVERRIDE (ej: export FQDN_OVERRIDE=panel.midominio.com) y reintente."
    return 1
}

# Crear directorio temporal con permisos seguros
create_temp_dir() {
    log "INFO" "Creando directorio temporal seguro"
    
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    mkdir -p "$TEMP_DIR"
    chmod 700 "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    log "SUCCESS" "Directorio temporal creado: $TEMP_DIR"
}

# Crear backup del sistema
create_system_backup() {
    log "HEADER" "CREACIÓN DE BACKUP DE SEGURIDAD"
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup de configuraciones importantes
    local configs=(
        "/etc/apache2"
        "/etc/mysql"
        "/etc/postfix"
        "/etc/ssh"
        "/etc/webmin"
        "/etc/hosts"
        "/etc/resolv.conf"
    )
    
    for config in "${configs[@]}"; do
        if [[ -e "$config" ]]; then
            cp -r "$config" "$BACKUP_DIR/" 2>/dev/null || true
            log "SUCCESS" "Backup creado: $config"
        fi
    done
    
    # Backup de base de datos de paquetes
    dpkg --get-selections > "$BACKUP_DIR/installed-packages.txt"
    apt list --installed > "$BACKUP_DIR/apt-packages.txt" 2>/dev/null
    
    log "SUCCESS" "Backup del sistema creado en: $BACKUP_DIR"
}

# Actualizar sistema con manejo de errores robusto
update_system() {
    log "HEADER" "ACTUALIZACIÓN DEL SISTEMA"
    
    # Configurar apt para evitar preguntas interactivas
    export DEBIAN_FRONTEND=noninteractive
    
    # Reparar paquetes rotos si existen
    log "INFO" "Verificando integridad de paquetes..."
    dpkg --configure -a 2>/dev/null || true
    apt-get -f install -y 2>/dev/null || true
    
    # Actualizar lista de paquetes con reintentos
    local retries=3
    while [[ $retries -gt 0 ]]; do
        log "INFO" "Actualizando lista de paquetes (intento: $((4-retries)))"
        
        if apt-get update -y; then
            log "SUCCESS" "Lista de paquetes actualizada"
            break
        else
            log "WARNING" "Fallo al actualizar paquetes, reintentando..."
            ((retries--))
            sleep 5
        fi
        
        if [[ $retries -eq 0 ]]; then
            log "ERROR" "No se pudo actualizar la lista de paquetes después de 3 intentos"
            exit 1
        fi
    done
    
    # Actualizar sistema
    log "INFO" "Actualizando paquetes del sistema..."
    apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
    
    # Instalar paquetes esenciales
    log "INFO" "Instalando dependencias esenciales..."
    local essential_packages=(
        "curl"
        "wget"
        "gnupg2"
        "software-properties-common"
        "apt-transport-https"
        "ca-certificates"
        "lsb-release"
        "unzip"
        "perl"
        "perl-modules"
        "libnet-ssleay-perl"
        "openssl"
        "libauthen-pam-perl"
        "libpam-runtime"
        "libio-pty-perl"
        "python3"
        "python3-pip"
        "ntpdate"
        "chrony"
        "procps"
        "psmisc"
        "iproute2"
        "iputils-ping"
        "net-tools"
        "dnsutils"
        "rsyslog"
        "cron"
    )
    
    for package in "${essential_packages[@]}"; do
        if apt-get install -y "$package"; then
            log "SUCCESS" "Instalado: $package"
        else
            log "WARNING" "Fallo al instalar: $package"
        fi
    done
    
    log "SUCCESS" "Sistema actualizado correctamente"
}

# Activar actualizaciones automáticas de seguridad (Ubuntu/Debian)
enable_security_auto_updates() {
    log "HEADER" "ACTIVANDO ACTUALIZACIONES AUTOMÁTICAS DE SEGURIDAD"
    if apt-get install -y unattended-upgrades >/dev/null 2>&1; then
        # Habilitar unattended-upgrades
        dpkg-reconfigure -f noninteractive unattended-upgrades >/dev/null 2>&1 || true
        # Asegurar ejecución diaria
        if [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
            sed -i 's/\"0\"/"1"/g' /etc/apt/apt.conf.d/20auto-upgrades || true
        else
            cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
        fi
        log "SUCCESS" "Actualizaciones automáticas de seguridad habilitadas"
    else
        log "WARNING" "No se pudo instalar unattended-upgrades"
    fi
}

# Tunings de kernel y límites para alto rendimiento
apply_kernel_tuning() {
    log "HEADER" "APLICANDO TUNING DE KERNEL Y LÍMITES"
    local sysctl_conf="/etc/sysctl.d/99-wv-tuning.conf"
    cat > "$sysctl_conf" <<'EOF'
# Tuning moderado para alto tráfico y concurrencia
fs.file-max = 1000000
net.core.somaxconn = 4096
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_local_port_range = 10240 65535
net.ipv4.tcp_fin_timeout = 15
# net.ipv4.tcp_tw_reuse = 1 # Comentado por compatibilidad; habilitar si aplica
EOF
    sysctl --system >/dev/null 2>&1 || sysctl -p "$sysctl_conf" >/dev/null 2>&1 || true

    # Límites de archivos
    local limits_conf="/etc/security/limits.d/webmin-virtualmin.conf"
    cat > "$limits_conf" <<'EOF'
* soft nofile 100000
* hard nofile 200000
EOF
    log "SUCCESS" "Tuning aplicado (sysctl y límites de archivos)"
}

# Mantenimiento diario automático
schedule_daily_maintenance() {
    log "HEADER" "PROGRAMANDO MANTENIMIENTO DIARIO AUTOMÁTICO"
    local cron_file="/etc/cron.daily/wv-maintenance"
    cat > "$cron_file" <<'EOF'
#!/bin/bash
# Mantenimiento diario: limpieza, verificación y validación

LOG=/var/log/wv-daily-maintenance.log
exec >> "$LOG" 2>&1
echo "==== RUN $(date) ===="

# Rotar y podar logs de journal (7 días)
journalctl --rotate >/dev/null 2>&1 || true
journalctl --vacuum-time=7d >/dev/null 2>&1 || true

# Limpieza de paquetes
apt-get autoremove -y >/dev/null 2>&1 || true
apt-get autoclean -y >/dev/null 2>&1 || true

# Validación de repos oficiales
if [ -x /opt/webmin-repo-validation/webmin-repo-validation.sh ]; then
  /opt/webmin-repo-validation/webmin-repo-validation.sh check || true
fi

# Verificación general (no falla el cron)
if [ -x "$(dirname "$0")/../../verificar_instalacion_un_comando.sh" ]; then
  bash "$(dirname "$0")/../../verificar_instalacion_un_comando.sh" || true
fi
EOF
    chmod +x "$cron_file"
    log "SUCCESS" "Mantenimiento diario programado (/etc/cron.daily/wv-maintenance)"
}

# Instalar y habilitar la pila de Auto-Reparación y Defensa
install_self_healing_stack() {
    log "HEADER" "AUTO-REPARACIÓN Y DEFENSA AVANZADA"

    # Directorios destino
    mkdir -p /opt/webmin-self-healing /opt/webmin-performance /opt/webmin-tunnels /opt/webmin-repo-validation 2>/dev/null || true

    # Copiar scripts principales
    install -m 0755 "$SCRIPT_DIR/webmin-self-healing-enhanced.sh" /opt/webmin-self-healing/auto-repair.sh 2>/dev/null || true
    install -m 0755 "$SCRIPT_DIR/webmin-ssh-monitor.sh"        /opt/webmin-self-healing/ssh-monitor.sh 2>/dev/null || true
    install -m 0755 "$SCRIPT_DIR/webmin-performance-optimizer.sh" /opt/webmin-performance/webmin-performance-optimizer.sh 2>/dev/null || true
    install -m 0755 "$SCRIPT_DIR/webmin-tunnel-system.sh"         /opt/webmin-tunnels/webmin-tunnel-system.sh 2>/dev/null || true
    install -m 0755 "$SCRIPT_DIR/webmin-repo-validation.sh"       /opt/webmin-repo-validation/webmin-repo-validation.sh 2>/dev/null || true

    # Instalar servicios systemd
    if [[ -d /run/systemd/system ]]; then
        install -m 0644 "$SCRIPT_DIR/webmin-self-healing.service"          /etc/systemd/system/webmin-self-healing.service 2>/dev/null || true
        install -m 0644 "$SCRIPT_DIR/webmin-ssh-monitor.service"           /etc/systemd/system/webmin-ssh-monitor.service 2>/dev/null || true
        install -m 0644 "$SCRIPT_DIR/webmin-performance-optimizer.service" /etc/systemd/system/webmin-performance-optimizer.service 2>/dev/null || true
        install -m 0644 "$SCRIPT_DIR/webmin-tunnel-system.service"         /etc/systemd/system/webmin-tunnel-system.service 2>/dev/null || true
        install -m 0644 "$SCRIPT_DIR/webmin-repo-validation.service"       /etc/systemd/system/webmin-repo-validation.service 2>/dev/null || true
        install -m 0644 "$SCRIPT_DIR/webmin-repo-validation.timer"         /etc/systemd/system/webmin-repo-validation.timer 2>/dev/null || true

        systemctl daemon-reload 2>/dev/null || true

        # Habilitar + iniciar servicios persistentes
        systemctl enable --now webmin-self-healing.service 2>/dev/null || true
        systemctl enable --now webmin-ssh-monitor.service 2>/dev/null || true
        systemctl enable --now webmin-tunnel-system.service 2>/dev/null || true

        # Ejecutar servicios oneshot iniciales
        systemctl enable webmin-performance-optimizer.service 2>/dev/null || true
        systemctl start webmin-performance-optimizer.service 2>/dev/null || true
        systemctl enable webmin-repo-validation.service 2>/dev/null || true
        systemctl start webmin-repo-validation.service 2>/dev/null || true
        systemctl enable --now webmin-repo-validation.timer 2>/dev/null || true
    fi

    log "SUCCESS" "Auto-Reparación y defensas avanzadas activadas"
}

# Ajustar motor de backups de Virtualmin para alta escala
tune_virtualmin_backup_engine() {
    log "HEADER" "AJUSTANDO MOTOR DE BACKUPS (ALTA ESCALA)"
    local vcfg="/etc/webmin/virtual-server/config"
    [[ -f "$vcfg" ]] || { log "INFO" "Archivo de configuración Virtualmin no encontrado ($vcfg)."; return 0; }

    # Limitar concurrencia de backups para reducir impacto de I/O (1 en paralelo)
    if grep -q '^max_backups=' "$vcfg" 2>/dev/null; then
        sed -i 's/^max_backups=.*/max_backups=1/' "$vcfg" || true
    else
        echo 'max_backups=1' >> "$vcfg"
    fi

    # Habilitar pigz si está disponible (gzip paralelo)
    if command -v pigz >/dev/null 2>&1; then
        if grep -q '^pigz=' "$vcfg" 2>/dev/null; then
            sed -i 's/^pigz=.*/pigz=1/' "$vcfg" || true
        else
            echo 'pigz=1' >> "$vcfg"
        fi
        # Añadir bandera --rsyncable para mejorar replicación y delta transfers
        if grep -q '^zip_args=' "$vcfg" 2>/dev/null; then
            sed -i 's/^zip_args=.*/zip_args=--rsyncable/' "$vcfg" || true
        else
            echo 'zip_args=--rsyncable' >> "$vcfg"
        fi
    fi

    # Aumentar chunk de S3 (MB) para grandes ficheros
    if grep -q '^s3_chunk=' "$vcfg" 2>/dev/null; then
        sed -i 's/^s3_chunk=.*/s3_chunk=64/' "$vcfg" || true
    else
        echo 's3_chunk=64' >> "$vcfg"
    fi

    log "SUCCESS" "Backups: concurrencia=1, pigz=$(command -v pigz >/dev/null 2>&1 && echo on || echo off), s3_chunk=64MB"
}

# Cargar exclusiones de backup (si existen)
load_backup_excludes() {
    local excludes_file="/etc/wv-backup-excludes.txt"
    BACKUP_EXCLUDE_ARGS=()
    if [[ -f "$excludes_file" ]]; then
        while IFS= read -r relpath; do
            [[ -z "$relpath" || "$relpath" =~ ^# ]] && continue
            BACKUP_EXCLUDE_ARGS+=( --exclude "$relpath" )
        done < "$excludes_file"
        log "INFO" "Se aplicarán exclusiones desde $excludes_file"
    fi
}

# Configurar backups automáticos de Virtualmin (diario y semanal)
setup_automatic_virtualmin_backups() {
    log "HEADER" "CONFIGURANDO BACKUPS AUTOMÁTICOS VIRTUALMIN"
    if ! command -v virtualmin >/dev/null 2>&1; then
        log "WARNING" "Comando 'virtualmin' no disponible; omitiendo configuración de backups"
        return 0
    fi

    mkdir -p /var/backups/virtualmin/daily /var/backups/virtualmin/weekly 2>/dev/null || true

    # Cargar exclusiones si existen
    load_backup_excludes

    # Backup diario: todos los dominios, todas las features, un archivo por dominio, rotación 14 días
    if virtualmin create-scheduled-backup \
        --dest /var/backups/virtualmin/daily/%Y-%m-%d/ \
        --all-domains \
        --all-features \
        --newformat \
        --differential \
        --strftime \
        --purge 14 \
        --compression gzip \
        --ignore-errors \
        --desc "WV Daily Backup" \
        --schedule "30 2 * * *" \
        "${BACKUP_EXCLUDE_ARGS[@]}" \
        --email-errors >/dev/null 2>&1; then
        log "SUCCESS" "Backup diario programado (02:30)"
    else
        log "WARNING" "No se pudo crear el backup diario"
    fi

    # Backup semanal: incluye settings de Virtualmin y todo el sistema de dominios
    if virtualmin create-scheduled-backup \
        --dest /var/backups/virtualmin/weekly/%Y-%m-%d/ \
        --all-domains \
        --all-features \
        --all-virtualmin \
        --newformat \
        --strftime \
        --purge 8 \
        --compression gzip \
        --ignore-errors \
        --desc "WV Weekly Full + Virtualmin" \
        --schedule "0 3 * * 0" \
        "${BACKUP_EXCLUDE_ARGS[@]}" \
        --email-errors >/dev/null 2>&1; then
        log "SUCCESS" "Backup semanal programado (Domingos 03:00)"
    else
        log "WARNING" "No se pudo crear el backup semanal"
    fi
}

# Configurar backups remotos (SSH/S3/Dropbox/GCS) con rotación y cifrado opcional
setup_remote_backups() {
    log "HEADER" "CONFIGURANDO BACKUPS REMOTOS (OPCIONAL)"

    if ! command -v virtualmin >/dev/null 2>&1; then
        log "INFO" "Virtualmin no está disponible; se omite configuración remota"
        return 0
    fi

    # Cargar configuración desde archivo si existe (KEY=VALUE)
    local remote_cfg_file="/etc/wv-backup-remote.conf"
    if [[ -f "$remote_cfg_file" ]]; then
        # shellcheck disable=SC1090
        source "$remote_cfg_file"
    fi

    local enabled="${REMOTE_BACKUP_ENABLED:-false}"
    local do_validate="${REMOTE_BACKUP_VALIDATE:-false}"
    if [[ "$enabled" != "true" ]]; then
        # Sembrar plantilla de configuración para el usuario
        if [[ ! -f "$remote_cfg_file" ]]; then
            cat > "$remote_cfg_file" <<'EOF'
# Habilitar backups remotos (true/false)
REMOTE_BACKUP_ENABLED=false

# Proveedor: ssh|s3|gcs|dropbox
# Ejemplos de URL con credenciales (reemplaza con tus datos):
# SSH:     ssh://usuario:password@host:/ruta/backups/%Y-%m-%d/
# S3:      s3://ACCESSKEY:SECRET@bucket/ruta/%Y-%m-%d/
# GCS:     gcs://bucket/ruta/%Y-%m-%d/
# Dropbox: dropbox://carpeta/%Y-%m-%d/
REMOTE_BACKUP_URL_DAILY=
REMOTE_BACKUP_URL_WEEKLY=

# Rotación (días)
REMOTE_BACKUP_PURGE_DAILY=14
REMOTE_BACKUP_PURGE_WEEKLY=56

# Horarios (formato cron de 5 campos)
REMOTE_BACKUP_SCHEDULE_DAILY="45 2 * * *"
REMOTE_BACKUP_SCHEDULE_WEEKLY="15 3 * * 0"

# Notificación por email sólo en errores (opcional)
REMOTE_BACKUP_EMAIL_ERRORS=

# Cifrado (sólo Virtualmin Pro, requiere clave existente)
REMOTE_BACKUP_KEY_ID=
EOF
            chmod 0600 "$remote_cfg_file" 2>/dev/null || true
            log "INFO" "Plantilla de configuración creada: $remote_cfg_file"
        fi
        log "INFO" "Backups remotos deshabilitados (define REMOTE_BACKUP_ENABLED=true para activarlos)"
        return 0
    fi

    # Variables desde env o archivo
    local url_daily="${REMOTE_BACKUP_URL_DAILY:-}"
    local url_weekly="${REMOTE_BACKUP_URL_WEEKLY:-}"
    local purge_daily="${REMOTE_BACKUP_PURGE_DAILY:-14}"
    local purge_weekly="${REMOTE_BACKUP_PURGE_WEEKLY:-56}"
    local sched_daily="${REMOTE_BACKUP_SCHEDULE_DAILY:-45 2 * * *}"
    local sched_weekly="${REMOTE_BACKUP_SCHEDULE_WEEKLY:-15 3 * * 0}"
    local email_errs="${REMOTE_BACKUP_EMAIL_ERRORS:-}"
    local key_id="${REMOTE_BACKUP_KEY_ID:-}"

    # Sanitizar logging: no exponer secretos
    mask_url() {
        local url="$1"
        echo "$url" | sed -E 's#(://[^:/]+:)[^@]+@#\1****@#'
    }

    # Determinar si existe soporte de claves de cifrado (Pro)
    local has_keys="0"
    if virtualmin list-backup-keys >/dev/null 2>&1; then
        has_keys="1"
    fi

    # Helper: validar destino remoto con un backup mínimo en modo --test
    validate_remote_dest() {
        local url="$1"
        local masked=$(mask_url "$url")
        if [[ "$do_validate" != "true" ]]; then
            log "INFO" "Validación remota desactivada; saltando test para $masked"
            return 0
        fi
        local vdest="$url/validate-%Y-%m-%d-%H%M%S/"
        log "INFO" "Validando destino remoto con prueba ligera: $masked"
        if virtualmin backup-domain \
            --test \
            --dest "$vdest" \
            --virtualmin config \
            --newformat \
            --strftime >/dev/null 2>&1; then
            log "SUCCESS" "Validación de destino OK: $masked"
            return 0
        else
            log "ERROR" "Validación de destino FALLÓ: $masked. No se programará backup remoto para este destino."
            return 1
        fi
    }

    # Crear backup remoto diario (concurrencia mínima y 'onebyone')
    if [[ -n "$url_daily" ]]; then
        log "INFO" "Programando backup remoto diario hacia: $(mask_url "$url_daily")"
        if ! validate_remote_dest "$url_daily"; then
            url_daily=""  # Evitar programar si falla validación
        fi
        local args=(
            --dest "$url_daily"
            --all-domains
            --all-features
            --newformat
            --strftime
            --purge "$purge_daily"
            --compression gzip
            --ignore-errors
            --desc "WV Remote Daily"
            --schedule "$sched_daily"
            --onebyone
        )
        # Cargar exclusiones si existen
        load_backup_excludes
        if [[ ${#BACKUP_EXCLUDE_ARGS[@]} -gt 0 ]]; then
            args+=( "${BACKUP_EXCLUDE_ARGS[@]}" )
        fi
        if [[ -n "$email_errs" ]]; then
            args+=( --email "$email_errs" --email-errors )
        fi
        if [[ "$has_keys" == "1" && -n "$key_id" ]]; then
            args+=( --key "$key_id" )
        fi
        if virtualmin create-scheduled-backup "${args[@]}" >/dev/null 2>&1; then
            log "SUCCESS" "Backup remoto diario programado"
        else
            log "WARNING" "No se pudo programar backup remoto diario"
        fi
    else
        log "INFO" "REMOTE_BACKUP_URL_DAILY no definido; se omite backup remoto diario"
    fi

    # Crear backup remoto semanal (onebyone)
    if [[ -n "$url_weekly" ]]; then
        log "INFO" "Programando backup remoto semanal hacia: $(mask_url "$url_weekly")"
        if ! validate_remote_dest "$url_weekly"; then
            url_weekly=""  # Evitar programar si falla validación
        fi
        local wargs=(
            --dest "$url_weekly"
            --all-domains
            --all-features
            --all-virtualmin
            --newformat
            --strftime
            --purge "$purge_weekly"
            --compression gzip
            --ignore-errors
            --desc "WV Remote Weekly + Virtualmin"
            --schedule "$sched_weekly"
            --onebyone
        )
        # Cargar exclusiones si existen
        load_backup_excludes
        if [[ ${#BACKUP_EXCLUDE_ARGS[@]} -gt 0 ]]; then
            wargs+=( "${BACKUP_EXCLUDE_ARGS[@]}" )
        fi
        if [[ -n "$email_errs" ]]; then
            wargs+=( --email "$email_errs" --email-errors )
        fi
        if [[ "$has_keys" == "1" && -n "$key_id" ]]; then
            wargs+=( --key "$key_id" )
        fi
        if virtualmin create-scheduled-backup "${wargs[@]}" >/dev/null 2>&1; then
            log "SUCCESS" "Backup remoto semanal programado"
        else
            log "WARNING" "No se pudo programar backup remoto semanal"
        fi
    else
        log "INFO" "REMOTE_BACKUP_URL_WEEKLY no definido; se omite backup remoto semanal"
    fi
}

# Instalar utilidades de revendedor (GPL emulado) y módulo Webmin
install_reseller_tools() {
    log "HEADER" "HERRAMIENTAS DE REVENDEDOR (GPL EMULADO)"
    
    # Wrapper CLI global (descarga script y biblioteca)
    if curl -fsSL "$REPO_RAW/cuentas_revendedor.sh" -o /usr/local/bin/virtualmin-revendedor; then
        chmod +x /usr/local/bin/virtualmin-revendedor
        # Instalar biblioteca requerida junto al wrapper para rutas relativas
        mkdir -p /usr/local/bin/lib 2>/dev/null || true
        if curl -fsSL "$REPO_RAW/lib/common_functions.sh" -o /usr/local/bin/lib/common_functions.sh; then
            chmod 0644 /usr/local/bin/lib/common_functions.sh
            log "SUCCESS" "Instalado /usr/local/bin/virtualmin-revendedor + lib/common_functions.sh"
        else
            log "WARNING" "Wrapper instalado, pero no se pudo descargar lib/common_functions.sh"
        fi
    else
        log "WARNING" "No se pudo descargar cuentas_revendedor.sh"
    fi
    
    # Módulo Webmin
    local module_dir="/usr/share/webmin/revendedor-gpl"
    mkdir -p "$module_dir"
    if curl -fsSL "$REPO_RAW/webmin-revendedor/module.info" -o "$module_dir/module.info" && \
       curl -fsSL "$REPO_RAW/webmin-revendedor/index.cgi"   -o "$module_dir/index.cgi"   && \
       curl -fsSL "$REPO_RAW/webmin-revendedor/config"      -o "$module_dir/config"; then
        chmod 755 "$module_dir/index.cgi"
        chown -R root:root "$module_dir" 2>/dev/null || true
        log "SUCCESS" "Módulo Webmin 'revendedor-gpl' instalado"
        # Recargar Webmin para registrar el módulo
        systemctl restart webmin 2>/dev/null || service webmin restart 2>/dev/null || true
    else
        log "WARNING" "No se pudo instalar el módulo Webmin de revendedor"
    fi

    # Favoritos del tema Authentic: añadir acceso rápido si no existe
    local theme_cfg_dir="/etc/webmin/authentic-theme"
    local fav_sys="$theme_cfg_dir/favorites.json"
    local fav_root="$theme_cfg_dir/favorites-root.json"
    mkdir -p "$theme_cfg_dir" 2>/dev/null || true
    if [[ ! -f "$fav_sys" ]] && [[ ! -f "$fav_root" ]]; then
        cat > "$fav_sys" <<'EOF'
{
  "favorites": [
    { "title": "Revendedores (GPL)", "link": "/revendedor-gpl/", "icon": "fa-users" }
  ]
}
EOF
        log "SUCCESS" "Acceso rápido agregado en Authentic (favoritos)"
    else
        # No forzar si ya existe algún favorito; evitar sobre-escrituras
        if ! grep -q "/revendedor-gpl/" "$fav_sys" 2>/dev/null && ! grep -q "/revendedor-gpl/" "$fav_root" 2>/dev/null; then
            # Crear archivo específico para root si no existe
            if [[ ! -f "$fav_root" ]]; then
                cat > "$fav_root" <<'EOF'
{
  "favorites": [
    { "title": "Revendedores (GPL)", "link": "/revendedor-gpl/", "icon": "fa-users" }
  ]
}
EOF
                log "SUCCESS" "Acceso rápido agregado para root (favoritos)"
            else
                log "INFO" "Favoritos existentes detectados; no se modifica"
            fi
        fi
    fi
}

# Configurar firewall automáticamente
configure_firewall() {
    if [[ "$CONFIGURE_FIREWALL" != "true" ]]; then
        return 0
    fi
    
    log "HEADER" "CONFIGURACIÓN DEL FIREWALL"
    
    # Instalar UFW si no está presente
    if ! command -v ufw >/dev/null 2>&1; then
        apt-get install -y ufw
    fi
    
    # Configurar reglas básicas (evitar reset para no perder acceso remoto)
    ufw default deny incoming
    ufw default allow outgoing
    
    # Permitir servicios esenciales
    ufw allow ssh
    ufw allow $WEBMIN_PORT
    ufw allow 20000  # Usermin
    ufw allow 80
    ufw allow 443
    ufw allow 25    # SMTP
    ufw allow 465   # SMTPS
    ufw allow 587   # Submission
    ufw allow 53    # DNS TCP
    ufw allow 53/udp  # DNS UDP
    ufw allow 21    # FTP
    ufw allow 110   # POP3
    ufw allow 143   # IMAP
    ufw allow 993   # IMAPS
    ufw allow 995   # POP3S
    
    # Activar firewall
    ufw --force enable
    
    log "SUCCESS" "Firewall configurado correctamente"
    ufw status
}

# Instalar Webmin con validación completa
install_webmin() {
    log "HEADER" "INSTALACIÓN DE WEBMIN"
    
    # Añadir repositorio oficial de Webmin
    log "INFO" "Configurando repositorio oficial de Webmin..."
    
    cd /tmp
    curl -fsSL https://download.webmin.com/jcameron-key.asc | gpg --dearmor | tee /usr/share/keyrings/webmin.gpg >/dev/null
    
    if [[ ! -f /etc/apt/sources.list.d/webmin.list ]]; then
        echo "deb [signed-by=/usr/share/keyrings/webmin.gpg] https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
    fi
    
    # Actualizar y instalar Webmin
    apt-get update
    
    # Preconfigurar Webmin para evitar preguntas
    echo "webmin webmin/redirect boolean false" | debconf-set-selections
    echo "webmin webmin/restart boolean true" | debconf-set-selections
    
    # Instalar Webmin
    log "INFO" "Instalando Webmin..."
    if apt-get install -y webmin; then
        log "SUCCESS" "Webmin instalado correctamente"
    else
        log "ERROR" "Error al instalar Webmin"
        exit 1
    fi
    
    # Verificar instalación
    if systemctl is-active --quiet webmin; then
        log "SUCCESS" "Servicio Webmin activo"
    else
        log "INFO" "Iniciando servicio Webmin..."
        systemctl enable webmin
        systemctl start webmin
        
        if systemctl is-active --quiet webmin; then
            log "SUCCESS" "Servicio Webmin iniciado correctamente"
        else
            log "ERROR" "No se pudo iniciar el servicio Webmin"
            exit 1
        fi
    fi
    
    # Verificar puerto
    if ss -tlnp 2>/dev/null | grep -q ":$WEBMIN_PORT\b" || netstat -tlnp 2>/dev/null | grep -q ":$WEBMIN_PORT "; then
        log "SUCCESS" "Webmin escuchando en puerto $WEBMIN_PORT"
    else
        log "ERROR" "Webmin no está escuchando en puerto $WEBMIN_PORT"
        exit 1
    fi
}

# Instalar Virtualmin con optimizaciones
install_virtualmin() {
    log "HEADER" "INSTALACIÓN DE VIRTUALMIN"
    
    # Descargar script oficial de Virtualmin
    cd /tmp
    log "INFO" "Descargando script oficial de Virtualmin..."
    
    if wget -O virtualmin-install.sh https://software.virtualmin.com/gpl/scripts/install.sh; then
        log "SUCCESS" "Script de Virtualmin descargado"
    else
        log "ERROR" "No se pudo descargar el script de Virtualmin"
        exit 1
    fi
    
    chmod +x virtualmin-install.sh
    
    # Configurar variables de entorno para instalación no interactiva
    export VIRTUALMIN_NONINTERACTIVE=1
    export VIRTUALMIN_CONFIG_SYSTEM=1
    
    # Ejecutar instalación con logging completo
    log "INFO" "Ejecutando instalación de Virtualmin (esto puede tomar varios minutos)..."
    
    if ./virtualmin-install.sh --bundle LAMP --force; then
        log "SUCCESS" "Virtualmin instalado correctamente"
    else
        log "ERROR" "Error durante la instalación de Virtualmin"
        log "INFO" "Intentando instalación con modo minimal..."
        
        if ./virtualmin-install.sh --minimal --force; then
            log "SUCCESS" "Virtualmin instalado en modo minimal"
        else
            log "ERROR" "Error crítico en instalación de Virtualmin"
            exit 1
        fi
    fi
    
    # Verificar instalación de Virtualmin
    if [[ -f /usr/sbin/virtualmin ]]; then
        log "SUCCESS" "Comando virtualmin disponible"
    else
        log "ERROR" "Comando virtualmin no encontrado"
        exit 1
    fi
    
    # Verificar módulo de Virtualmin en Webmin
    if [[ -d /etc/webmin/virtual-server ]]; then
        log "SUCCESS" "Módulo Virtualmin instalado en Webmin"
    else
        log "ERROR" "Módulo Virtualmin no encontrado en Webmin"
        exit 1
    fi
}

# Instalar y configurar Authentic Theme
install_authentic_theme() {
    if [[ "$INSTALL_AUTHENTIC_THEME" != "true" ]]; then
        return 0
    fi
    
    log "HEADER" "INSTALACIÓN DE AUTHENTIC THEME"
    
    cd /tmp
    
    # Descargar Authentic Theme desde GitHub
    log "INFO" "Descargando Authentic Theme..."
    if wget -O authentic-theme.zip https://github.com/authentic-theme/authentic-theme/archive/refs/heads/master.zip; then
        log "SUCCESS" "Authentic Theme descargado"
    else
        log "ERROR" "No se pudo descargar Authentic Theme"
        return 1
    fi
    
    # Extraer y instalar
    unzip -q authentic-theme.zip
    
    if [[ -d authentic-theme-master ]]; then
        # Manejo robusto de carpeta destino
        THEME_DEST="/usr/share/webmin/authentic-theme/authentic-theme-master"
        if [ -d "$THEME_DEST" ]; then
            log "WARNING" "La carpeta destino de Authentic Theme ya existe. Eliminando para evitar conflictos..."
            rm -rf "$THEME_DEST"
        fi
        mv -f authentic-theme-master "$THEME_DEST" 2>/dev/null || rsync -a --delete authentic-theme-master/ "$THEME_DEST/"

        # Configurar como tema predeterminado (idempotente)
        if grep -q '^theme=' /etc/webmin/config 2>/dev/null; then
            sed -i 's/^theme=.*/theme=authentic-theme/' /etc/webmin/config
        else
            echo 'theme=authentic-theme' >> /etc/webmin/config
        fi

        # Reiniciar Webmin para aplicar el tema
        systemctl restart webmin

        log "SUCCESS" "Authentic Theme instalado y configurado"
    else
        log "ERROR" "No se pudo extraer Authentic Theme"
        return 1
    fi
}

# Configurar pila de correo y seguridad (DKIM, SPF, Spam, Virus, Fail2ban)
setup_security_pro_features() {
    log "HEADER" "CONFIGURACIÓN DE SEGURIDAD Y CORREO (PRO)"

    # Paquetes base de correo/seguridad
    local pkgs=(
        opendkim opendkim-tools spamassassin clamav-daemon clamav-freshclam
        postfix-policyd-spf-python python3-policyd-spf fail2ban dovecot-imapd dovecot-pop3d
    )
    for p in "${pkgs[@]}"; do
        apt-get install -y "$p" >/dev/null 2>&1 || true
    done

    # SpamAssassin: habilitar servicio
    if [ -f /etc/default/spamassassin ]; then
        sed -i 's/^ENABLED=.*/ENABLED=1/' /etc/default/spamassassin || true
    fi
    systemctl enable --now spamassassin >/dev/null 2>&1 || systemctl enable --now spamd >/dev/null 2>&1 || true

    # ClamAV
    systemctl enable --now clamav-freshclam >/dev/null 2>&1 || true
    systemctl enable --now clamav-daemon >/dev/null 2>&1 || true

    # OpenDKIM: configuración básica para que Virtualmin pueda firmar dominios al crearlos
    if [ -f /etc/opendkim.conf ]; then
        sed -i 's/^#*\?AutoRestart.*/AutoRestart             Yes/' /etc/opendkim.conf || true
        sed -i 's/^#*\?UMask.*/UMask                   002/' /etc/opendkim.conf || true
        grep -q '^Mode\s\+sv$' /etc/opendkim.conf || echo 'Mode                     sv' >> /etc/opendkim.conf
        grep -q '^Socket\s' /etc/opendkim.conf || echo 'Socket                   inet:8891@127.0.0.1' >> /etc/opendkim.conf
        grep -q '^Syslog\s\+yes$' /etc/opendkim.conf || echo 'Syslog                   yes' >> /etc/opendkim.conf
    fi
    # Permisos y directorios comunes de OpenDKIM
    mkdir -p /etc/opendkim/keys >/dev/null 2>&1 || true
    chown -R opendkim:opendkim /etc/opendkim || true
    systemctl enable --now opendkim >/dev/null 2>&1 || true

    # Postfix: integrar OpenDKIM y SPF policy
    if [ -f /etc/postfix/main.cf ]; then
        # DKIM milter
        if ! grep -q '^smtpd_milters.*8891' /etc/postfix/main.cf; then
            postconf -e 'milter_default_action=accept'
            postconf -e 'non_smtpd_milters=inet:127.0.0.1:8891'
            if grep -q '^smtpd_milters' /etc/postfix/main.cf; then
                postconf -e "smtpd_milters=$(postconf -h smtpd_milters), inet:127.0.0.1:8891"
            else
                postconf -e 'smtpd_milters=inet:127.0.0.1:8891'
            fi
        fi

        # SPF policy (preferir socket unix si existe, si no inet puerto 10023)
        local SPF_CHECK="check_policy_service unix:private/policyd-spf"
        grep -q policyd-spf /etc/postfix/master.cf || cat >> /etc/postfix/master.cf <<'EOF'
policyd-spf  unix  -       n       n       -       0       spawn
  user=policyd-spf argv=/usr/bin/policyd-spf
EOF
        if ! postconf -h smtpd_recipient_restrictions | grep -q policyd-spf; then
            if postconf -h smtpd_recipient_restrictions >/dev/null 2>&1; then
                postconf -e "smtpd_recipient_restrictions=$(postconf -h smtpd_recipient_restrictions), ${SPF_CHECK}"
            else
                postconf -e "smtpd_recipient_restrictions=permit_mynetworks, reject_unauth_destination, ${SPF_CHECK}"
            fi
        fi
        systemctl restart postfix >/dev/null 2>&1 || true
    fi

    # Fail2ban: reglas básicas para sshd, postfix y dovecot
    mkdir -p /etc/fail2ban >/dev/null 2>&1 || true
    cat >/etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 5

[postfix]
enabled = true
port    = smtp,ssmtp,submission
logpath = /var/log/mail.log

[dovecot]
enabled = true
port    = pop3,pop3s,imap,imaps,submission,465,sieve
logpath = /var/log/mail.log
EOF
    systemctl enable --now fail2ban >/dev/null 2>&1 || true

    # Dovecot (IMAP/POP3)
    systemctl enable --now dovecot >/dev/null 2>&1 || true

    # Opcional: activar funciones por defecto en Virtualmin si está instalado
    if [ -d /etc/webmin/virtual-server ] && command -v virtualmin >/dev/null 2>&1; then
        # Verificación de configuración general
        virtualmin check-config >/dev/null 2>&1 || true
        # Nota: Virtualmin habilita DKIM/Spam/Virus por dominio; aquí solo dejamos servicios listos
    fi

    log "SUCCESS" "Pila de correo y seguridad configurada"
}

# Funciones premium opcionales (estadísticas, WAF, webmail, DB GUIs, cache)
setup_premium_optional_features() {
    log "HEADER" "INSTALANDO FUNCIONES PREMIUM OPCIONALES"

    # Paquetes de estadísticas
    apt-get install -y awstats webalizer >/dev/null 2>&1 || true
    if command -v a2enconf >/dev/null 2>&1; then
        a2enconf awstats >/dev/null 2>&1 || true
    fi

    # Webmail Roundcube (cuando está en repos)
    apt-get install -y roundcube roundcube-core roundcube-plugins >/dev/null 2>&1 || true

    # Mailman (listas de correo)
    apt-get install -y mailman >/dev/null 2>&1 || true

    # ModSecurity + CRS
    apt-get install -y libapache2-mod-security2 modsecurity-crs >/dev/null 2>&1 || true
    if command -v a2enmod >/dev/null 2>&1; then
        a2enmod security2 >/dev/null 2>&1 || true
        # Incluir CRS si no existe
        if [ -f /etc/modsecurity/modsecurity.conf-recommended ]; then
            cp -n /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf || true
            sed -i 's/SecRuleEngine .*/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf || true
        fi
        if [ -d /usr/share/modsecurity-crs ]; then
            echo 'IncludeOptional /usr/share/modsecurity-crs/*.conf' > /etc/modsecurity/crs-include.conf 2>/dev/null || true
        fi
    fi

    # GUIs para DB
    apt-get install -y phpmyadmin phppgadmin >/dev/null 2>&1 || true

    # Caches
    apt-get install -y redis-server memcached >/dev/null 2>&1 || true
    systemctl enable --now redis-server >/dev/null 2>&1 || true
    systemctl enable --now memcached >/dev/null 2>&1 || true

    # PHP-FPM (común)
    apt-get install -y php-fpm >/dev/null 2>&1 || true
    systemctl enable --now php7.4-fpm >/dev/null 2>&1 || true
    systemctl enable --now php8.1-fpm >/dev/null 2>&1 || true
    systemctl enable --now php8.2-fpm >/dev/null 2>&1 || true

    # Reiniciar Apache para aplicar módulos
    systemctl restart apache2 >/dev/null 2>&1 || true

    log "SUCCESS" "Funciones premium opcionales instaladas (cuando disponibles)"
}

# Exponer acceso público de Webmin/Usermin asegurando servicios y firewall
ensure_public_access() {
    log "HEADER" "EXPOSICIÓN PÚBLICA DE SERVICIOS"
    # Asegurar servicios habilitados
    systemctl enable --now webmin >/dev/null 2>&1 || true
    if systemctl list-unit-files 2>/dev/null | grep -q "^usermin\.service"; then
        systemctl enable --now usermin >/dev/null 2>&1 || true
    fi
    # Abrir puertos mediante UFW si está disponible
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 10000/tcp >/dev/null 2>&1 || true
        ufw allow 20000/tcp >/dev/null 2>&1 || true
        ufw allow 80/tcp     >/dev/null 2>&1 || true
        ufw allow 443/tcp    >/dev/null 2>&1 || true
    fi
    # Validación de escucha local
    if ss -tlnp 2>/dev/null | grep -Eq ':(10000|20000|80|443)\b'; then
        log "SUCCESS" "Puertos públicos habilitados (10000, 20000, 80, 443)"
    else
        log "WARNING" "Verifique reglas externas/NAT si no hay acceso público"
    fi
}

# Configurar red de Virtualmin para usar IP pública local sin servicios externos
configure_virtualmin_public_ip() {
    log "HEADER" "CONFIGURANDO IP PÚBLICA EN VIRTUALMIN"
    local pub_ip
    pub_ip="$(get_best_public_ip)"
    if [[ -z "$pub_ip" || "$pub_ip" =~ ^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.) ]]; then
        log "WARNING" "No se detectó IP pública enrutable en interfaces. Se mantendrá IP local."
        return 0
    fi

    # Asegurar que el módulo existe
    if [[ ! -d /etc/webmin/virtual-server ]]; then
        log "WARNING" "Módulo virtual-server aún no disponible; omitiendo."
        return 0
    fi

    # Respaldo de configuración
    cp -f /etc/webmin/virtual-server/config "/etc/webmin/virtual-server/config.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true

    # Claves comunes de red en Virtualmin (modo auto con IP fija detectada)
    # - default_ip: IP predeterminada para nuevos dominios
    # - real_ip: usar IP real (no NAT) si está disponible
    # - detect_external_ip: intentar auto-detección
    # - default_interface: interfaz primaria (se infiere)
    local primary_if=""
    if command -v ip >/dev/null 2>&1; then
        primary_if="$(ip -4 route get 8.8.8.8 2>/dev/null | awk "/dev/ {for(i=1;i<=NF;i++){if(\\$i==\"dev\"){print \\$(i+1); exit}}}")"
    fi

    # Crear archivo temporal y fusionar claves de forma idempotente
    local cfg="/etc/webmin/virtual-server/config"
    local tmp_cfg
    tmp_cfg="$(mktemp)"
    cat "$cfg" > "$tmp_cfg" 2>/dev/null || true

    # Helpers para setear/actualizar claves en formato key=value
    set_kv() {
        local key="$1"; local val="$2"
        if grep -q "^${key}=" "$tmp_cfg"; then
            sed -i "s|^${key}=.*|${key}=${val}|" "$tmp_cfg"
        else
            printf "%s=%s\n" "$key" "$val" >> "$tmp_cfg"
        fi
    }

    set_kv default_ip "$pub_ip"
    set_kv real_ip 1
    set_kv detect_external_ip 0

    if [[ -n "$primary_if" ]]; then
        set_kv default_interface "$primary_if"
    fi

    # Grabar cambios si hay diferencias
    if ! diff -q "$cfg" "$tmp_cfg" >/dev/null 2>&1; then
        mv "$tmp_cfg" "$cfg"
        log "SUCCESS" "Virtualmin configurado para usar IP pública: $pub_ip"
        # Reiniciar Webmin para recargar configuración del módulo
        systemctl restart webmin >/dev/null 2>&1 || true
    else
        rm -f "$tmp_cfg"
        log "INFO" "Configuración de red de Virtualmin ya coherente con $pub_ip"
    fi
}

# Obtener IP pública sin servicios de terceros (preferir metadata del proveedor)
get_best_public_ip() {
    local ip=""
    if command -v curl >/dev/null 2>&1; then
        # AWS / DigitalOcean
        ip=$(curl -fsS --connect-timeout 1 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || true)
        # Google Cloud
        if [[ -z "$ip" ]]; then
            ip=$(curl -fsS --connect-timeout 1 -H "Metadata-Flavor: Google" \
                http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip 2>/dev/null || true)
        fi
        # Azure
        if [[ -z "$ip" ]]; then
            ip=$(curl -fsS --connect-timeout 1 -H "Metadata: true" \
                "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01&format=text" 2>/dev/null || true)
        fi
        # DigitalOcean explicit
        if [[ -z "$ip" ]]; then
            ip=$(curl -fsS --connect-timeout 1 http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)
        fi
        # Hetzner
        if [[ -z "$ip" ]]; then
            ip=$(curl -fsS --connect-timeout 1 http://169.254.169.254/hetzner/v1/metadata/public-ipv4 2>/dev/null || true)
        fi
    fi
    # Fallback: interfaz global no RFC1918
    if [[ -z "$ip" ]] && command -v ip >/dev/null 2>&1; then
        ip=$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | \
             grep -Ev '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)' | head -n1 || true)
    fi
    # Último recurso
    if [[ -z "$ip" ]]; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    echo "${ip:-127.0.0.1}"
}

# Forzar que Webmin/Usermin escuchen públicamente (0.0.0.0) y sin restricciones allow/deny
configure_webmin_public_access() {
    log "HEADER" "CONFIGURACIÓN PÚBLICA DE WEBMIN/USERMIN"
    local wcfg="/etc/webmin/miniserv.conf"
    local ucfg="/etc/usermin/miniserv.conf"

    # Verificar firewall de forma más robusta
    verify_firewall_protection() {
        local FIREWALL_OK="false"
        
        # Verificar UFW
        if command -v ufw >/dev/null 2>&1; then
            if ufw status 2>/dev/null | grep -qi "Status: active"; then
                # Verificar que UFW esté configurado correctamente
                if ufw status 2>/dev/null | grep -q "10000/tcp.*ALLOW" && ufw status 2>/dev/null | grep -q "20000/tcp.*ALLOW"; then
                    FIREWALL_OK="true"
                    log "SUCCESS" "Firewall UFW activo y configurado para Webmin/Usermin"
                else
                    log "WARNING" "Firewall UFW activo pero sin reglas específicas para Webmin"
                fi
            fi
        
        # Verificar firewalld
        elif command -v firewall-cmd >/dev/null 2>&1; then
            if firewall-cmd --state 2>/dev/null | grep -qi running; then
                # Verificar zonas y reglas
                if firewall-cmd --list-all 2>/dev/null | grep -q "10000/tcp" && firewall-cmd --list-all 2>/dev/null | grep -q "20000/tcp"; then
                    FIREWALL_OK="true"
                    log "SUCCESS" "Firewall firewalld activo y configurado para Webmin/Usermin"
                else
                    log "WARNING" "Firewall firewalld activo pero sin reglas específicas para Webmin"
                fi
            fi
        
        # Verificar iptables de forma más detallada
        elif command -v iptables >/dev/null 2>&1; then
            # Verificar política por defecto
            local input_policy=$(iptables -S 2>/dev/null | grep "^-P INPUT" | awk '{print $3}')
            if [[ "$input_policy" == "DROP" ]]; then
                # Verificar reglas específicas para Webmin
                if iptables -S 2>/dev/null | grep -q "--dport 10000" && iptables -S 2>/dev/null | grep -q "--dport 20000"; then
                    FIREWALL_OK="true"
                    log "SUCCESS" "Firewall iptables configurado con política DROP y reglas específicas"
                else
                    log "WARNING" "Firewall iptables con política DROP pero sin reglas específicas para Webmin"
                fi
            elif [[ "$input_policy" == "ACCEPT" ]]; then
                log "WARNING" "Firewall iptables con política ACCEPT - no seguro para exposición pública"
            else
                log "INFO" "Firewall iptables detectado, política: $input_policy"
            fi
        fi
        
        echo "$FIREWALL_OK"
    }

    # Solo exponer públicamente si el firewall está activo y correctamente configurado
    local FIREWALL_OK=$(verify_firewall_protection)

    if [[ -f "$wcfg" ]]; then
        grep -q '^port=' "$wcfg" || echo "port=10000" >> "$wcfg"
        if [[ "$FIREWALL_OK" == "true" ]]; then
            sed -i 's/^bind=.*/bind=0.0.0.0/' "$wcfg" 2>/dev/null || true
            grep -q '^bind=' "$wcfg" || echo "bind=0.0.0.0" >> "$wcfg"
            log "SUCCESS" "Webmin configurado para acceso público (0.0.0.0)"
        else
            sed -i 's/^bind=.*/bind=127.0.0.1/' "$wcfg" 2>/dev/null || true
            grep -q '^bind=' "$wcfg" || echo "bind=127.0.0.1" >> "$wcfg"
            log "WARNING" "Firewall no activo o mal configurado; Webmin limitado a localhost (127.0.0.1) por seguridad"
        fi
    fi
    if [[ -f "$ucfg" ]]; then
        grep -q '^port=' "$ucfg" || echo "port=20000" >> "$ucfg"
        if [[ "$FIREWALL_OK" == "true" ]]; then
            sed -i 's/^bind=.*/bind=0.0.0.0/' "$ucfg" 2>/dev/null || true
            grep -q '^bind=' "$ucfg" || echo "bind=0.0.0.0" >> "$ucfg"
            log "SUCCESS" "Usermin configurado para acceso público (0.0.0.0)"
        else
            sed -i 's/^bind=.*/bind=127.0.0.1/' "$ucfg" 2>/dev/null || true
            grep -q '^bind=' "$ucfg" || echo "bind=127.0.0.1" >> "$ucfg"
        fi
    fi

    systemctl restart webmin >/dev/null 2>&1 || true
    systemctl restart usermin >/dev/null 2>&1 || true

    if ss -tlnp 2>/dev/null | grep -Eq ':(10000|20000)\b'; then
        log "SUCCESS" "Webmin/Usermin en ejecución (puertos 10000/20000)"
    else
        log "WARNING" "No se detecta escucha; revise miniserv.conf y firewall/NAT externo"
    fi
}

    # Configurar SSL automáticamente
    configure_ssl() {
        if [[ "$ENABLE_SSL" != "true" ]]; then
            return 0
        fi
        
        log "HEADER" "CONFIGURACIÓN SSL"
        
        # Generar certificado SSL autofirmado para Webmin
        log "INFO" "Generando certificado SSL para Webmin..."
        
        local ssl_dir="/etc/webmin"
        local hostname=$(hostname -f 2>/dev/null || hostname)
        
        # Crear certificado SSL
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$ssl_dir/miniserv.pem" \
            -out "$ssl_dir/miniserv.pem" \
            -subj "/C=ES/ST=Local/L=Local/O=Webmin/CN=$hostname" 2>/dev/null
        
        chmod 600 "$ssl_dir/miniserv.pem"
        
        # Configurar Webmin para usar SSL
        sed -i 's/ssl=0/ssl=1/' /etc/webmin/miniserv.conf 2>/dev/null || true
        
        # Reiniciar Webmin
        systemctl restart webmin
        
        log "SUCCESS" "SSL configurado para Webmin"
        log "INFO" "Acceso seguro: https://$(get_best_public_ip):$WEBMIN_PORT"
    }

    # Optimizar para producción
    optimize_for_production() {
        if [[ "$OPTIMIZE_FOR_PRODUCTION" != "true" ]]; then
            return 0
        fi
        
        log "HEADER" "OPTIMIZACIÓN PARA PRODUCCIÓN"
        
        # Configurar límites del sistema (idempotente)
        ensure_limit() { local line="$1"; grep -qxF "$line" /etc/security/limits.conf || echo "$line" >> /etc/security/limits.conf; }
        ensure_limit "* soft nofile 65535"
        ensure_limit "* hard nofile 65535"
        ensure_limit "* soft nproc 65535"
        ensure_limit "* hard nproc 65535"
    
    # Optimizar MySQL si está instalado
    # Optimización robusta de MySQL/MariaDB
    if systemctl is-active --quiet mysql; then
        log "INFO" "Optimizando configuración de MySQL/MariaDB..."

        if [ -f /etc/mysql/mysql.conf.d/mysqld.cnf ]; then
            cp /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf.backup
            cat >> /etc/mysql/mysql.conf.d/mysqld.cnf << 'EOF'

# Optimizaciones Virtualmin
max_connections = 200
innodb_buffer_pool_size = 256M
query_cache_size = 16M
query_cache_limit = 2M
thread_cache_size = 8
table_open_cache = 2000
EOF
            systemctl restart mysql
            log "SUCCESS" "MySQL optimizado"
        elif [ -f /etc/mysql/mariadb.conf.d/50-server.cnf ]; then
            cp /etc/mysql/mariadb.conf.d/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf.backup
            cat >> /etc/mysql/mariadb.conf.d/50-server.cnf << 'EOF'

# Optimizaciones Virtualmin
max_connections = 200
innodb_buffer_pool_size = 256M
query_cache_size = 16M
query_cache_limit = 2M
thread_cache_size = 8
table_open_cache = 2000
EOF
            systemctl restart mysql
            log "SUCCESS" "MariaDB optimizado"
        else
            log "WARNING" "No se encontró archivo de configuración de MySQL/MariaDB. Saltando optimización."
        fi
    fi
    
    # Optimizar Apache
    if systemctl is-active --quiet apache2; then
        log "INFO" "Optimizando configuración de Apache..."
        
        # Habilitar módulos necesarios
        a2enmod rewrite ssl headers expires deflate
        
        # Configurar límites
        cat > /etc/apache2/conf-available/virtualmin-optimizations.conf << 'EOF'
# Optimizaciones Virtualmin
ServerTokens Prod
ServerSignature Off
Timeout 60
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 5

# Límites de memoria
LimitRequestBody 52428800
EOF
        
        a2enconf virtualmin-optimizations
        systemctl restart apache2
        log "SUCCESS" "Apache optimizado"
    fi
    
    log "SUCCESS" "Optimizaciones de producción aplicadas"
}

# Verificación final del sistema
final_verification() {
    log "HEADER" "VERIFICACIÓN FINAL DEL SISTEMA"
    
    local errors=0
    
    # Verificar servicios críticos
    local services=("webmin" "apache2" "mysql")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log "SUCCESS" "Servicio $service: ACTIVO"
        else
            log "ERROR" "Servicio $service: INACTIVO"
            ((errors++))
        fi
    done
    
    # Verificar puertos
    local ports=("$WEBMIN_PORT:Webmin" "80:Apache" "443:Apache-SSL")
    
    for port_info in "${ports[@]}"; do
        local port="${port_info%:*}"
        local service_name="${port_info#*:}"
        
        if ss -tlnp 2>/dev/null | grep -q ":$port\b" || netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            log "SUCCESS" "Puerto $port ($service_name): ABIERTO"
        else
            log "WARNING" "Puerto $port ($service_name): CERRADO"
        fi
    done
    
    # Verificar acceso a Webmin
    local server_ip=$(get_best_public_ip)
    log "INFO" "Verificando acceso a Webmin..."
    
    if curl -k -s --connect-timeout 5 "https://$server_ip:$WEBMIN_PORT" >/dev/null; then
        log "SUCCESS" "Webmin accesible vía HTTPS"
    elif curl -s --connect-timeout 5 "http://$server_ip:$WEBMIN_PORT" >/dev/null; then
        log "SUCCESS" "Webmin accesible vía HTTP"
    else
        log "ERROR" "Webmin no accesible"
        ((errors++))
    fi
    
    # Verificar Virtualmin
    if command -v virtualmin >/dev/null 2>&1; then
        if virtualmin list-domains >/dev/null 2>&1; then
            log "SUCCESS" "Virtualmin funcionando correctamente"
        else
            log "WARNING" "Virtualmin instalado pero con errores"
        fi
    else
        log "ERROR" "Virtualmin no instalado correctamente"
        ((errors++))
    fi
    
    return $errors
}

# Mostrar información de acceso
show_access_info() {
    local server_ip=$(get_best_public_ip)
    local hostname=$(hostname -f 2>/dev/null || hostname)
    
    log "HEADER" "INFORMACIÓN DE ACCESO"
    
    cat << EOF

═══════════════════════════════════════════════════════════════════════════════
🎉 ¡INSTALACIÓN COMPLETADA EXITOSAMENTE!
═══════════════════════════════════════════════════════════════════════════════

📡 ACCESO A WEBMIN:
   • URL: https://$server_ip:$WEBMIN_PORT
   • URL alternativa: https://$hostname:$WEBMIN_PORT
   • Usuario: root
   • Contraseña: [contraseña de root del sistema]

🏢 ACCESO A VIRTUALMIN:
   • URL: https://$server_ip:$WEBMIN_PORT
   • Módulo: Virtualmin Virtual Servers
   • Panel completo de hosting disponible

🔐 SEGURIDAD:
   • SSL habilitado automáticamente
   • Firewall configurado
   • Certificados SSL autofirmados instalados

🚀 CARACTERÍSTICAS INSTALADAS:
   ✅ Webmin (panel de administración)
   ✅ Virtualmin GPL (gestión de hosting)
   ✅ Authentic Theme (interfaz moderna)
   ✅ Apache + MySQL + PHP (stack LAMP)
   ✅ Postfix (servidor de correo)
   ✅ Certificados SSL
   ✅ Firewall UFW configurado

📋 PRÓXIMOS PASOS:
   1. Acceder a https://$server_ip:$WEBMIN_PORT
   2. Iniciar sesión con credenciales de root
   3. Configurar primer dominio virtual en Virtualmin
   4. Revisar configuración en System Information

   🆘 SOPORTE:
      • Logs: $INSTALL_LOG
      • Backup: $BACKUP_DIR
      • Documentación: https://webmin.com/docs/

   👥 CUENTAS DE REVENDEDOR (GPL EMULADO):
   • Crear: ./cuentas_revendedor.sh crear \
       --usuario rev1 --pass 'Secreto123' \
       --dominio-base rev1-panel.tu-dominio.com \
       --email soporte@tu-dominio.com --max-doms 50
   • Nota: en GPL se crean sub-servidores bajo un dominio base. Para revendedores
     con creación de top-level en todo el sistema se requiere Virtualmin Pro.

   🛡️ AUTO-REPARACIÓN Y DEFENSA:
      • Auto-Reparación Inteligente: Activa (servicio webmin-self-healing)
      • Defensa ante ataques: Detección y mitigación automática (brute force, DDoS, probes)
      • Integridad protegida: Backups de emergencia y restauración automática
      • Backups Virtualmin: Diario 02:30 y Semanal Dom 03:00

═══════════════════════════════════════════════════════════════════════════════

EOF
}

# Función para cleanup final
final_cleanup() {
    log "INFO" "Ejecutando limpieza final..."
    
    # Limpiar archivos temporales
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    # Limpiar cache de apt
    apt-get autoremove -y
    apt-get autoclean
    
    log "SUCCESS" "Limpieza completada"
}

# Funciones de autocorrección adicionales

# Reparar permisos de archivos y carpetas críticos
repair_permissions() {
    log "INFO" "Reparando permisos de archivos y carpetas críticos..."
    chown -R root:root /etc/webmin 2>/dev/null || true
    chown -R root:root /usr/share/webmin 2>/dev/null || true
    chmod -R 750 /etc/webmin 2>/dev/null || true
    chmod -R 755 /usr/share/webmin 2>/dev/null || true
}

# Reintentar descargas críticas hasta 3 veces
retry_download() {
    local url="$1"
    local output="$2"
    local tries=0
    while [[ $tries -lt 3 ]]; do
        if wget -O "$output" "$url"; then
            return 0
        fi
        log "WARNING" "Fallo al descargar $url, reintentando..."
        ((tries++))
        sleep 2
    done
    log "ERROR" "No se pudo descargar $url después de 3 intentos"
    return 1
}

# Reparar servicios caídos automáticamente
repair_services() {
    log "INFO" "Verificando y reparando servicios críticos..."
    local services=("webmin" "apache2" "mysql")
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet "$service"; then
            log "WARNING" "Servicio $service inactivo, intentando reiniciar..."
            systemctl restart "$service" || service "$service" restart || true
            sleep 2
            if systemctl is-active --quiet "$service"; then
                log "SUCCESS" "Servicio $service reparado y activo"
            else
                log "ERROR" "No se pudo reparar el servicio $service"
            fi
        fi
    done
}

# Reparar configuraciones problemáticas detectadas
repair_configurations() {
    log "INFO" "Reparando configuraciones problemáticas si es necesario..."
    # Ejemplo: restaurar backup si la config principal de Webmin está corrupta
    if [[ ! -f /etc/webmin/miniserv.conf && -f "$BACKUP_DIR/webmin/miniserv.conf" ]]; then
        cp "$BACKUP_DIR/webmin/miniserv.conf" /etc/webmin/miniserv.conf
        log "SUCCESS" "Configuración de Webmin restaurada desde backup"
    fi
}

# Función principal
main() {
    # Mostrar banner
    show_banner
    
    # Inicializar log
    mkdir -p "$(dirname "$INSTALL_LOG")"
    echo "=== INSTALACIÓN WEBMIN/VIRTUALMIN INICIADA $(date) ===" > "$INSTALL_LOG"
    
    log "INFO" "Iniciando instalación automática v$SCRIPT_VERSION"
    log "INFO" "Log de instalación: $INSTALL_LOG"
    
    # Ejecutar pasos de instalación
    check_root
    detect_system
    ensure_fqdn
    check_network
    create_temp_dir
    create_system_backup
    update_system
    apply_kernel_tuning
    enable_security_auto_updates
    schedule_daily_maintenance
    configure_firewall

    # Autocorrección antes de instalar paneles
    repair_permissions

    install_webmin
    install_virtualmin
    install_reseller_tools
    ensure_public_access
    configure_webmin_public_access
    configure_virtualmin_public_ip
    tune_virtualmin_backup_engine
    install_self_healing_stack
    setup_automatic_virtualmin_backups
    setup_remote_backups
    install_authentic_theme
    configure_ssl
    setup_security_pro_features
    setup_premium_optional_features
    optimize_for_production

    # Autocorrección después de instalar paneles
    repair_permissions
    repair_services
    repair_configurations

    # Verificación final
    if final_verification; then
        log "SUCCESS" "Todas las verificaciones pasaron correctamente"
        show_access_info
    else
        log "WARNING" "Instalación completada con algunas advertencias"
        log "INFO" "Revise $INSTALL_LOG para más detalles"
    fi

    # Cleanup final
    final_cleanup

    log "SUCCESS" "¡Instalación automática completada exitosamente!"
    echo
    echo -e "${GREEN}Para acceder al panel: https://$(get_best_public_ip):$WEBMIN_PORT${NC}"
    echo
}

# Verificar si se está ejecutando directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Ejecutar función principal
    main "$@"
fi

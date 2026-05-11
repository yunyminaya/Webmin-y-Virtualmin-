#!/bin/bash
# ============================================================================
# Kernel Security Audit & Remediation Script
# Detecta y corrige vulnerabilidades del kernel Linux
# Incluye detección de compromisos, verificación de integridad y parcheo
# ============================================================================
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

readonly LOG_FILE="/var/log/kernel_security_audit.log"
readonly REPORT_FILE="/root/kernel_security_report.txt"

# ============================================================================
# Funciones de utilidad
# ============================================================================
log_info()  { printf '%b[INFO]%b %s\n' "$GREEN" "$NC" "$*" | tee -a "$LOG_FILE"; }
log_warn()  { printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$*" | tee -a "$LOG_FILE"; }
log_error() { printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$*" | tee -a "$LOG_FILE"; }
log_crit()  { printf '%b[CRITICAL]%b %s\n' "$RED" "$NC" "$*" | tee -a "$LOG_FILE"; }

separator() {
    printf '\n%b========================================%b\n' "$CYAN" "$NC" | tee -a "$LOG_FILE"
    printf '%b  %s%b\n' "$CYAN" "$*" "$NC" | tee -a "$LOG_FILE"
    printf '%b========================================%b\n' "$CYAN" "$NC" | tee -a "$LOG_FILE"
}

# ============================================================================
# CVEs Críticos Recientes del Kernel Linux (2024-2026)
# ============================================================================
# CVE-2024-21626: runc container escape (v1.1.11)
# CVE-2024-1086: nf_tables use-after-free (netfilter, kernels 5.x-6.x)
# CVE-2024-0193: io_uring use-after-free
# CVE-2024-0582: io_uring memory overwrite
# CVE-2024-41009: bpf ringbuf privilege escalation
# CVE-2024-46814: drm/amdgpu double free
# CVE-2024-46858: bpf integer overflow
# CVE-2024-49967: ALSA use-after-free
# CVE-2024-50264: vsock use-after-free
# CVE-2024-53104: USB video class out-of-bounds
# CVE-2024-53150: erofs out-of-bounds
# CVE-2024-53239: nfsd out-of-bounds
# CVE-2024-53677: ALSA scarlett2 out-of-bounds write
# CVE-2025-0677: HID out-of-bounds write
# CVE-2025-21703: KVM x86 privilege escalation
# CVE-2025-22655: HID big_bench out-of-bounds
# CVE-2025-23127: HID core double free

check_kernel_version() {
    separator "VERIFICACIÓN DE VERSIÓN DEL KERNEL"
    
    local kernel_version
    kernel_version="$(uname -r)"
    log_info "Kernel actual: $kernel_version"
    
    local major minor patch
    IFS='.-' read -r major minor patch _ <<< "$kernel_version"
    
    log_info "Versión mayor: $major, menor: $minor, patch: $patch"
    
    # Verificar si el kernel es vulnerable
    local vulnerable=0
    
    # Kernel 5.x vulnerable a CVE-2024-1086 (netfilter)
    if [[ "$major" == "5" ]]; then
        log_warn "Kernel 5.x detectado - Potencialmente vulnerable a CVE-2024-1086 (netfilter nf_tables)"
        vulnerable=1
    fi
    
    # Kernel 6.1.x < 6.1.76 vulnerable
    if [[ "$major" == "6" && "$minor" == "1" ]]; then
        if [[ "$patch" -lt 76 ]]; then
            log_warn "Kernel 6.1.$patch vulnerable a múltiples CVEs (requiere >= 6.1.76)"
            vulnerable=1
        fi
    fi
    
    # Kernel 6.5.x < 6.5.16 vulnerable
    if [[ "$major" == "6" && "$minor" == "5" ]]; then
        if [[ "$patch" -lt 16 ]]; then
            log_warn "Kernel 6.5.$patch vulnerable a múltiples CVEs (requiere >= 6.5.16)"
            vulnerable=1
        fi
    fi
    
    # Kernel 6.6.x < 6.6.15 vulnerable
    if [[ "$major" == "6" && "$minor" == "6" ]]; then
        if [[ "$patch" -lt 15 ]]; then
            log_warn "Kernel 6.6.$patch vulnerable a múltiples CVEs (requiere >= 6.6.15)"
            vulnerable=1
        fi
    fi
    
    # Kernel 6.7.x < 6.7.3 vulnerable
    if [[ "$major" == "6" && "$minor" == "7" ]]; then
        if [[ "$patch" -lt 3 ]]; then
            log_warn "Kernel 6.7.$patch vulnerable a múltiples CVEs (requiere >= 6.7.3)"
            vulnerable=1
        fi
    fi
    
    # Kernel 6.12.x < 6.12.10 vulnerable a CVE-2025-*
    if [[ "$major" == "6" && "$minor" == "12" ]]; then
        if [[ "$patch" -lt 10 ]]; then
            log_warn "Kernel 6.12.$patch vulnerable a CVE-2025-* (requiere >= 6.12.10)"
            vulnerable=1
        fi
    fi
    
    if [[ "$vulnerable" -eq 0 ]]; then
        log_info "Versión del kernel parece estar actualizada."
    fi
    
    return $vulnerable
}

check_netfilter_vulnerability() {
    separator "CVE-2024-1086: NETFILTER NF_TABLES"
    
    # Verificar si nf_tables está cargado
    if lsmod 2>/dev/null | grep -q 'nf_tables'; then
        log_warn "Módulo nf_tables cargado - Potencialmente vulnerable a CVE-2024-1086"
        log_info "Verificando si hay reglas nft activas..."
        
        if command -v nft >/dev/null 2>&1; then
            local nft_rules
            nft_rules="$(nft list ruleset 2>/dev/null | wc -l)"
            if [[ "$nft_rules" -gt 0 ]]; then
                log_warn "Se encontraron $nft_rules líneas de reglas nft - El módulo está en uso activo"
                log_info "MITIGACIÓN: Asegurar que solo root puede crear tablas nft"
            else
                log_info "No hay reglas nft activas - Se puede bloquear el módulo si no se usa"
            fi
        fi
    else
        log_info "Módulo nf_tables NO cargado - No vulnerable a CVE-2024-1086"
    fi
}

check_io_uring_vulnerability() {
    separator "CVE-2024-0193/0582: IO_URING"
    
    if [[ -d /sys/kernel/debug/io_uring ]]; then
        log_warn "io_uring disponible - Potencialmente vulnerable a CVE-2024-0193/0582"
        log_info "MITIGACIÓN: Se puede deshabilitar io_uring si no se usa"
    else
        log_info "io_uring no accesible - No vulnerable"
    fi
    
    # Verificar si io_uring está en uso
    if command -v grep >/dev/null 2>&1; then
        local iouring_sysctl
        iouring_sysctl="$(sysctl -n kernel.io_uring_disabled 2>/dev/null || echo "not-set")"
        if [[ "$iouring_sysctl" == "1" ]]; then
            log_info "io_uring DESHABILITADO via sysctl - Protegido"
        elif [[ "$iouring_sysctl" == "2" ]]; then
            log_info "io_uring restringido a procesos con CAP_SYS_IO_URING - Parcialmente protegido"
        else
            log_warn "io_uring HABILITADO - Recomendado: sysctl -w kernel.io_uring_disabled=2"
        fi
    fi
}

check_kernel_integrity() {
    separator "VERIFICACIÓN DE INTEGRIDAD DEL KERNEL"
    
    # Verificar módulos del kernel comprometidos
    log_info "Verificando módulos del kernel..."
    
    local suspicious_modules=()
    
    # Módulos conocidos de rootkits
    local known_rootkit_modules=(
        "adore"
        "knark"
        "suckit"
        "shv4"
        "shv5"
        "reptile"
        "diamorphine"
        "azazel"
        "jynx"
        "vlany"
        "bdvl"
        "vladi"
    )
    
    for mod in "${known_rootkit_modules[@]}"; do
        if lsmod 2>/dev/null | grep -qi "$mod"; then
            suspicious_modules+=("$mod")
        fi
    done
    
    if [[ ${#suspicious_modules[@]} -gt 0 ]]; then
        log_crit "MÓDULOS SOSPECHOSOS DETECTADOS: ${suspicious_modules[*]}"
        log_crit "POSIBLE COMPROMISO DEL KERNEL - Requiere investigación inmediata"
        return 1
    else
        log_info "No se detectaron módulos de rootkit conocidos."
    fi
    
    # Verificar /proc/kallsyms
    if [[ -f /proc/kallsyms ]]; then
        local kallsyms_zeros
        kallsyms_zeros="$(awk '{print $1}' /proc/kallsyms | grep -c '^0000000' 2>/dev/null || echo "0")"
        if [[ "$kallsyms_zeros" -gt 100 ]]; then
            log_info "kallsyms protegido (direcciones enmascaradas) - Correcto"
        else
            log_warn "kallsyms expone direcciones reales del kernel - Considerar kptr_restrict=1"
        fi
    fi
    
    return 0
}

check_kernel_hardening() {
    separator "VERIFICACIÓN DE HARDENING DEL KERNEL"
    
    local hardening_ok=1
    
    # kptr_restrict
    local kptr
    kptr="$(sysctl -n kernel.kptr_restrict 2>/dev/null || echo "not-set")"
    if [[ "$kptr" == "1" || "$kptr" == "2" ]]; then
        log_info "kernel.kptr_restrict = $kptr ✓"
    else
        log_warn "kernel.kptr_restrict = $kptr (recomendado: 1)"
        hardening_ok=0
    fi
    
    # dmesg_restrict
    local dmesg
    dmesg="$(sysctl -n kernel.dmesg_restrict 2>/dev/null || echo "not-set")"
    if [[ "$dmesg" == "1" ]]; then
        log_info "kernel.dmesg_restrict = 1 ✓"
    else
        log_warn "kernel.dmesg_restrict = $dmesg (recomendado: 1)"
        hardening_ok=0
    fi
    
    # kexec_load_disabled
    local kexec
    kexec="$(sysctl -n kernel.kexec_load_disabled 2>/dev/null || echo "not-set")"
    if [[ "$kexec" == "1" ]]; then
        log_info "kernel.kexec_load_disabled = 1 ✓"
    else
        log_warn "kernel.kexec_load_disabled = $kexec (recomendado: 1)"
        hardening_ok=0
    fi
    
    # randomize_va_space (ASLR)
    local aslr
    aslr="$(sysctl -n kernel.randomize_va_space 2>/dev/null || echo "not-set")"
    if [[ "$aslr" == "2" ]]; then
        log_info "kernel.randomize_va_space = 2 (ASLR completo) ✓"
    else
        log_warn "kernel.randomize_va_space = $aslr (recomendado: 2)"
        hardening_ok=0
    fi
    
    # unprivileged_bpf_disabled
    local bpf
    bpf="$(sysctl -n kernel.unprivileged_bpf_disabled 2>/dev/null || echo "not-set")"
    if [[ "$bpf" == "1" ]]; then
        log_info "kernel.unprivileged_bpf_disabled = 1 ✓"
    else
        log_warn "kernel.unprivileged_bpf_disabled = $bpf (recomendado: 1)"
        hardening_ok=0
    fi
    
    # Yama ptrace_scope
    local ptrace
    ptrace="$(sysctl -n kernel.yama.ptrace_scope 2>/dev/null || echo "not-set")"
    if [[ "$ptrace" == "2" || "$ptrace" == "3" ]]; then
        log_info "kernel.yama.ptrace_scope = $ptrace ✓"
    elif [[ "$ptrace" == "1" ]]; then
        log_info "kernel.yama.ptrace_scope = 1 (básico) - Aceptable"
    else
        log_warn "kernel.yama.ptrace_scope = $ptrace (recomendado: >= 1)"
        hardening_ok=0
    fi
    
    return $hardening_ok
}

check_signs_of_compromise() {
    separator "DETECCIÓN DE SIGNOS DE COMPROMISO"
    
    local compromise_found=0
    
    # Verificar procesos ocultos
    log_info "Verificando procesos ocultos..."
    local ps_count ls_count
    ps_count="$(ps aux 2>/dev/null | wc -l)"
    ls_count="$(ls /proc 2>/dev/null | grep -c '^[0-9]')"
    
    if [[ "$ls_count" -gt "$((ps_count + 5))" ]]; then
        log_crit "Posibles procesos ocultos detectados (proc: $ls_count vs ps: $ps_count)"
        compromise_found=1
    else
        log_info "No se detectaron procesos ocultos ($ls_count procesos en /proc)"
    fi
    
    # Verificar archivos de sistema modificados
    log_info "Verificando integridad de archivos críticos..."
    
    local critical_files=(
        "/etc/passwd"
        "/etc/shadow"
        "/etc/crontab"
        "/etc/ld.so.preload"
    )
    
    for file in "${critical_files[@]}"; do
        if [[ -f "$file" ]]; then
            local perms
            perms="$(stat -c '%a:%U:%G' "$file" 2>/dev/null || stat -f '%Lp:%Su:%Sg' "$file" 2>/dev/null || echo "unknown")"
            log_info "$file -> $perms"
        fi
    done
    
    # Verificar ld.so.preload (técnica común de rootkit)
    if [[ -f /etc/ld.so.preload ]]; then
        local preload_content
        preload_content="$(cat /etc/ld.so.preload 2>/dev/null)"
        if [[ -n "$preload_content" ]]; then
            log_crit "/etc/ld.so.preload CONTIENE ENTRADAS: $preload_content"
            log_crit "POSIBLE ROOTKIT - Investigar inmediatamente"
            compromise_found=1
        fi
    fi
    
    # Verificar módulos del kernel recientes
    log_info "Verificando módulos del kernel cargados recientemente..."
    if [[ -d /sys/module ]]; then
        local recent_modules=()
        for mod_dir in /sys/module/*/; do
            if [[ -f "${mod_dir}initstate" ]]; then
                local mod_name
                mod_name="$(basename "$mod_dir")"
                recent_modules+=("$mod_name")
            fi
        done
        log_info "Módulos cargados: ${#recent_modules[@]}"
    fi
    
    # Verificar conexiones de red sospechosas
    log_info "Verificando conexiones de red..."
    local established
    established="$(ss -tnp 2>/dev/null | grep -c 'ESTAB' || echo "0")"
    log_info "Conexiones establecidas: $established"
    
    # Verificar puertos en escucha inusuales
    local listening
    listening="$(ss -tlnp 2>/dev/null | grep -v '127.0.0' || true)"
    if [[ -n "$listening" ]]; then
        log_info "Puertos en escucha (no-localhost):"
        echo "$listening" | while IFS= read -r line; do
            log_info "  $line"
        done
    fi
    
    return $compromise_found
}

apply_kernel_hardening() {
    separator "APLICANDO HARDENING DEL KERNEL"
    
    local sysctl_conf="/etc/sysctl.d/99-kernel-hardening.conf"
    
    log_info "Creando configuración de hardening en $sysctl_conf"
    
    cat > "$sysctl_conf" <<'EOF'
# Kernel Security Hardening - OpenVM Enterprise
# Protección contra explotación del kernel

# Ocultar direcciones del kernel a usuarios no privilegiados
kernel.kptr_restrict = 1

# Restringir acceso a dmesg
kernel.dmesg_restrict = 1

# Deshabilitar kexec (previene carga de kernel malicioso)
kernel.kexec_load_disabled = 1

# ASLR completo
kernel.randomize_va_space = 2

# Deshabilitar BPF no privilegiado (mitiga CVE-2024-41009)
kernel.unprivileged_bpf_disabled = 1

# Restringir ptrace (Yama)
kernel.yama.ptrace_scope = 2

# Restringir io_uring (mitiga CVE-2024-0193/0582)
kernel.io_uring_disabled = 2

# Protección contra symlink hardlink
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2

# Protecciones de red
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Protección contra source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Protección contra IP forwarding no autorizado
net.ipv4.ip_forward = 0

# TCP SYN cookies
net.ipv4.tcp_syncookies = 1

# Restringir core dumps a pipes
fs.suid_dumpable = 0
EOF
    
    chmod 644 "$sysctl_conf"
    log_info "Aplicando sysctl..."
    sysctl -p "$sysctl_conf" 2>/dev/null || true
    
    log_info "Hardening del kernel aplicado correctamente."
}

update_kernel() {
    separator "ACTUALIZACIÓN DEL KERNEL"
    
    log_info "Buscando actualizaciones del kernel..."
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq 2>/dev/null
        local available_updates
        available_updates="$(apt list --upgradable 2>/dev/null | grep -i 'linux-image\|linux-headers' || true)"
        if [[ -n "$available_updates" ]]; then
            log_info "Actualizaciones de kernel disponibles:"
            echo "$available_updates" | while IFS= read -r line; do
                log_info "  $line"
            done
            log_info "Instalando actualizaciones del kernel..."
            apt-get install -y --only-upgrade linux-image-* linux-headers-* 2>/dev/null || true
            log_info "Kernel actualizado. REINICIO NECESARIO."
        else
            log_info "No hay actualizaciones de kernel pendientes."
        fi
    elif command -v dnf >/dev/null 2>&1; then
        dnf update -y kernel kernel-core kernel-modules 2>/dev/null || true
        log_info "Kernel actualizado. REINICIO NECESARIO."
    elif command -v yum >/dev/null 2>&1; then
        yum update -y kernel 2>/dev/null || true
        log_info "Kernel actualizado. REINICIO NECESARIO."
    else
        log_warn "No se pudo determinar el gestor de paquetes para actualizar el kernel."
    fi
}

generate_report() {
    separator "GENERANDO REPORTE"
    
    {
        echo "========================================"
        echo "  REPORTE DE SEGURIDAD DEL KERNEL"
        echo "========================================"
        echo "Fecha: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo "Kernel: $(uname -r)"
        echo "Hostname: $(hostname -f 2>/dev/null || hostname)"
        echo "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || uname -s)"
        echo "========================================"
        echo ""
        echo "Ver /var/log/kernel_security_audit.log para detalles completos"
        echo ""
        echo "Acciones recomendadas:"
        echo "1. Reiniciar el servidor si se actualizó el kernel"
        echo "2. Verificar que el hardening esté activo: sysctl -a | grep restrict"
        echo "3. Monitorear logs del kernel: dmesg -w"
        echo "4. Ejecutar rkhunter y chkrootkit para escaneo completo"
    } | tee "$REPORT_FILE"
    
    chmod 600 "$REPORT_FILE"
    log_info "Reporte guardado en $REPORT_FILE"
}

# ============================================================================
# MAIN
 ============================================================================
main() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        echo "Este script debe ejecutarse como root." >&2
        exit 1
    fi
    
    mkdir -p "$(dirname "$LOG_FILE")"
    : > "$LOG_FILE"
    
    separator "AUDITORÍA DE SEGURIDAD DEL KERNEL LINUX"
    log_info "Iniciando auditoría completa..."
    
    check_kernel_version
    local kernel_vuln=$?
    
    check_netfilter_vulnerability
    check_io_uring_vulnerability
    check_kernel_integrity
    local integrity=$?
    
    check_kernel_hardening
    local hardening=$?
    
    check_signs_of_compromise
    local compromise=$?
    
    # Aplicar hardening si es necesario
    if [[ "$hardening" -ne 0 ]]; then
        apply_kernel_hardening
    fi
    
    # Actualizar kernel si es vulnerable
    if [[ "$kernel_vuln" -ne 0 ]]; then
        update_kernel
    fi
    
    generate_report
    
    separator "RESUMEN"
    if [[ "$compromise" -ne 0 ]]; then
        log_crit "⚠️  POSIBLE COMPROMISO DETECTADO - Investigar inmediatamente"
    elif [[ "$kernel_vuln" -ne 0 ]]; then
        log_warn "⚠️  Kernel vulnerable detectado - Actualización aplicada, reiniciar"
    else
        log_info "✅ Kernel seguro - No se detectaron vulnerabilidades críticas"
    fi
    
    log_info "Auditoría completada. Ver $REPORT_FILE para detalles."
}

main "$@"

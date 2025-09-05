#!/bin/bash
# Orquestador de Verificación PRO (Webmin + Virtualmin)
# Ejecuta verificaciones clave y devuelve exit != 0 si hay problemas.
# Uso:
#   ./orquestador_verificacion_pro.sh [--strict]

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh" >&2
    exit 1
fi

set -euo pipefail

STRICT=0
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
  esac
done

init_logging "orquestador_verificacion_pro"
show_header "VERIFICACIÓN PRO - WEBMIN/VIRTUALMIN" "Orquestador de salud de servicios"

overall_errors=0

step() { log_step "$1" "$2"; }

# 1) Verificación base con el verificador
step 1 "Ejecutando verificador de servicios base"
if [[ -x "$SCRIPT_DIR/verificador_servicios.sh" ]]; then
    if ! "$SCRIPT_DIR/verificador_servicios.sh" ${STRICT:+--strict}; then
        log_warning "Verificador base reportó incidencias"
        overall_errors=$((overall_errors + 1))
    else
        log_success "Verificador base OK"
    fi
else
    log_error "verificador_servicios.sh no encontrado o no ejecutable"
    overall_errors=$((overall_errors + 1))
fi

# 2) Webmin/Virtualmin: servicio, puerto y SSL
step 2 "Comprobando Webmin/Virtualmin"
if systemctl list-unit-files 2>/dev/null | grep -q '^webmin\.service'; then
    systemctl is-active --quiet webmin 2>/dev/null && log_success "Webmin activo" || { log_warning "Webmin inactivo"; overall_errors=$((overall_errors + 1)); }
else
    log_warning "Servicio webmin no instalado"
    overall_errors=$((overall_errors + 1))
fi

if ss -tuln 2>/dev/null | grep -q ':10000 ' || netstat -tuln 2>/dev/null | grep -q ':10000 '; then
    log_success "Puerto 10000 escuchando"
else
    log_warning "Puerto 10000 no está escuchando"
    overall_errors=$((overall_errors + 1))
fi

if [[ -f /etc/webmin/miniserv.conf ]]; then
    if grep -q '^ssl=1' /etc/webmin/miniserv.conf; then
        log_success "Webmin SSL habilitado"
    else
        log_warning "Webmin SSL deshabilitado (ssl=0)"
        overall_errors=$((overall_errors + 1))
    fi
else
    log_warning "miniserv.conf no encontrado"
    overall_errors=$((overall_errors + 1))
fi

# 3) Fail2ban: instalado y jail webmin (si aplica)
step 3 "Comprobando Fail2ban"
if command -v fail2ban-client >/dev/null 2>&1; then
    if fail2ban-client status >/dev/null 2>&1; then
        jails=$(fail2ban-client status 2>/dev/null | awk -F': ' '/Jail list:/ {print $2}')
        echo "$jails" | grep -qw webmin && log_success "Jail fail2ban 'webmin' activo" || log_info "Jail 'webmin' no presente (opcional)"
    else
        log_warning "Fail2ban instalado pero sin estado"
        overall_errors=$((overall_errors + 1))
    fi
else
    log_info "Fail2ban no instalado (opcional)"
fi

# 4) Firewall (UFW/Firewalld)
step 4 "Comprobando Firewall"
if command -v ufw >/dev/null 2>&1; then
    ufw status | sed 's/^/  /'
elif command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --state 2>/dev/null | grep -q running && log_success "firewalld activo" || log_info "firewalld inactivo"
else
    log_info "Firewall no detectado (opcional)"
fi

# 5) HAProxy (si instalado)
step 5 "Comprobando HAProxy (si existe)"
if command -v haproxy >/dev/null 2>&1; then
    systemctl is-active --quiet haproxy 2>/dev/null && log_success "HAProxy activo" || log_info "HAProxy instalado pero inactivo"
else
    log_info "HAProxy no instalado"
fi

# 6) Servicio de túnel nativo (si existe)
step 6 "Comprobando servicio túnel nativo"
if systemctl list-unit-files 2>/dev/null | grep -q '^tunel-nativo\.service'; then
    systemctl is-active --quiet tunel-nativo 2>/dev/null && log_success "tunel-nativo activo" || { log_warning "tunel-nativo inactivo"; overall_errors=$((overall_errors + 1)); }
else
    log_info "Servicio tunel-nativo no instalado"
fi

# Resumen final
echo
show_header "RESUMEN PRO" "Errores detectados: $overall_errors"
if [[ $overall_errors -eq 0 ]]; then
    log_success "Todos los servicios PRO están operativos"
    exit 0
else
    if [[ $STRICT -eq 1 ]]; then
        log_error "Incidencias detectadas en servicios PRO"
        exit 1
    fi
    log_warning "Incidencias detectadas (modo no estricto)"
    exit 0
fi
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

#!/bin/bash

# =============================================================================
# AUDITOR DE COBERTURA DE FUNCIONES PROFESSIONAL DE VIRTUALMIN
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_DIR="${SCRIPT_DIR}/virtualmin-gpl-master"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TOTAL=0
INTEGRATED=0
PARTIAL=0
MISSING=0

print_header() {
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${BLUE}🔎 AUDITORÍA DE COBERTURA: VIRTUALMIN PROFESSIONAL FEATURES${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo "Origen oficial: https://www.virtualmin.com/docs/professional-features/"
    echo "Repositorio local: ${SCRIPT_DIR}"
    echo
}

have_file() {
    local file
    for file in "$@"; do
        if [[ -f "${VM_DIR}/${file}" ]]; then
            return 0
        fi
    done
    return 1
}

repo_has() {
    local pattern="$1"
    grep -R -q -i -E "$pattern" "${VM_DIR}" 2>/dev/null
}

report_feature() {
    local name="$1"
    local status="$2"
    local evidence="$3"
    local note="${4:-}"

    ((TOTAL+=1))
    case "$status" in
        INTEGRADO)
            ((INTEGRATED+=1))
            echo -e "${GREEN}✅ ${name}: ${status}${NC}"
            ;;
        PARCIAL)
            ((PARTIAL+=1))
            echo -e "${YELLOW}⚠️  ${name}: ${status}${NC}"
            ;;
        *)
            ((MISSING+=1))
            echo -e "${RED}❌ ${name}: SIN_EVIDENCIA${NC}"
            ;;
    esac

    [[ -n "$evidence" ]] && echo "   Evidencia: $evidence"
    [[ -n "$note" ]] && echo "   Nota: $note"
    echo
}

require_vm_dir() {
    if [[ ! -d "$VM_DIR" ]]; then
        echo -e "${RED}❌ No existe el directorio ${VM_DIR}${NC}"
        exit 1
    fi
}

audit_features() {
    if have_file "functional-test.pl" "commands-lib.pl" && repo_has 'create-reseller\.pl|modify-reseller\.pl|list-resellers\.pl|delete-reseller\.pl'; then
        report_feature "Reseller accounts" "INTEGRADO" "CLI, backend y pruebas de revendedores presentes"
    else
        report_feature "Reseller accounts" "SIN_EVIDENCIA" ""
    fi

    if have_file "newreseller.cgi" "reseller_email.cgi" "edit_newreseller.cgi"; then
        report_feature "New reseller email" "INTEGRADO" "Página real para edición del correo de nuevo revendedor"
    elif repo_has 'newreseller_title|reseller_email\.html|New reseller email'; then
        report_feature "New reseller email" "PARCIAL" "Hay textos/ayuda/referencias, pero no se encontró CGI funcional dedicado" "Falta página real de edición"
    else
        report_feature "New reseller email" "SIN_EVIDENCIA" ""
    fi

    if repo_has 'authorized_keys|Update SSH key if given|get_ssh_key_identifier'; then
        report_feature "Manage SSH public keys" "INTEGRADO" "Manejo de authorized_keys y actualización de claves SSH en backend"
    else
        report_feature "Manage SSH public keys" "SIN_EVIDENCIA" ""
    fi

    if repo_has 'list_extra_db_users|create_databases_user|db_only'; then
        report_feature "Manage extra database users" "INTEGRADO" "Usuarios extra de base de datos soportados en backend y creación de usuarios"
    else
        report_feature "Manage extra database users" "SIN_EVIDENCIA" ""
    fi

    if repo_has 'list_extra_web_users|save_user_web\.cgi|webserver users'; then
        report_feature "Manage extra webserver users" "INTEGRADO" "Usuarios web adicionales presentes en backend y formularios Pro"
    else
        report_feature "Manage extra webserver users" "SIN_EVIDENCIA" ""
    fi

    if repo_has 'script installer|Install Scripts|save_scriptlatest|edit_newscripts'; then
        report_feature "Manage web apps" "INTEGRADO" "Instaladores de scripts/aplicaciones web presentes"
    else
        report_feature "Manage web apps" "SIN_EVIDENCIA" ""
    fi

    if have_file "bwgraph.cgi" && repo_has 'history\.cgi|bwgraph'; then
        report_feature "Resource usage graphs" "INTEGRADO" "Gráficas de uso/histórico presentes"
    else
        report_feature "Resource usage graphs" "SIN_EVIDENCIA" ""
    fi

    if repo_has 'jailkit|edit_newchroot|get_domain_jailkit'; then
        report_feature "Environment limitations" "INTEGRADO" "Aislamiento tipo Jailkit/chroot presente"
    else
        report_feature "Environment limitations" "SIN_EVIDENCIA" ""
    fi

    if repo_has 'limits\.conf|edit_res\.cgi|resource limits|bandwidth limits'; then
        report_feature "Resource limits" "INTEGRADO" "Límites de recursos presentes en backend/UI"
    else
        report_feature "Resource limits" "SIN_EVIDENCIA" ""
    fi

    if have_file "pro/edit_html.cgi" "edit_html.cgi"; then
        report_feature "Edit web pages" "INTEGRADO" "Página de edición HTML presente"
    elif repo_has 'pro/edit_html\.cgi|can_edit_html|edit_htmldesc'; then
        report_feature "Edit web pages" "PARCIAL" "Hay botón/referencias y permiso, pero falta el CGI real de edición HTML" "virtualmin-gpl-master/pro está ausente"
    else
        report_feature "Edit web pages" "SIN_EVIDENCIA" ""
    fi

    if have_file "pro/connectivity.cgi" "edit_connect.cgi"; then
        report_feature "External connectivity check" "INTEGRADO" "Página de comprobación de conectividad presente"
    elif repo_has 'check_domain_connectivity|Connectivity check failed|pro/connectivity\.cgi'; then
        report_feature "External connectivity check" "PARCIAL" "Existe lógica de comprobación y enlace UI, pero no la página CGI final" "Falta connectivity.cgi"
    else
        report_feature "External connectivity check" "SIN_EVIDENCIA" ""
    fi

    if have_file "pro/maillog.cgi" "maillog.cgi"; then
        report_feature "Search mail logs" "INTEGRADO" "Página CGI de búsqueda de logs de correo presente"
    elif have_file "maillog.pl" && repo_has 'pro/maillog\.cgi'; then
        report_feature "Search mail logs" "PARCIAL" "Existe parser/lógica de logs, pero falta la página CGI final esperada por la UI" "Falta maillog.cgi"
    else
        report_feature "Search mail logs" "SIN_EVIDENCIA" ""
    fi

    if have_file "dnsclouds.cgi" "edit_dnscloud.cgi"; then
        report_feature "Cloud DNS providers" "INTEGRADO" "Gestión DNS cloud presente"
    else
        report_feature "Cloud DNS providers" "SIN_EVIDENCIA" ""
    fi

    if have_file "edit_mail.cgi" && repo_has 'list_smtp_clouds|smtpcloud_'; then
        report_feature "Cloud mail delivery providers" "INTEGRADO" "Soporte SMTP cloud presente en UI y backend"
    else
        report_feature "Cloud mail delivery providers" "SIN_EVIDENCIA" ""
    fi

    if have_file "notify.cgi" "edit_newnotify.cgi"; then
        report_feature "Email server owners" "INTEGRADO" "Notificación a propietarios presente"
    else
        report_feature "Email server owners" "SIN_EVIDENCIA" ""
    fi

    if have_file "edit_newretention.cgi" "save_newretention.cgi"; then
        report_feature "Mailbox cleanup" "INTEGRADO" "Política de limpieza/retención de buzones presente"
    else
        report_feature "Mailbox cleanup" "SIN_EVIDENCIA" ""
    fi

    if have_file "edit_newlinks.cgi" "edit_link.cgi"; then
        report_feature "Custom links" "INTEGRADO" "Gestión de enlaces personalizados presente"
    else
        report_feature "Custom links" "SIN_EVIDENCIA" ""
    fi

    if have_file "remotedns.cgi"; then
        report_feature "Remote DNS servers" "INTEGRADO" "Página de servidores DNS remotos presente"
    elif repo_has 'remotedns_title|remote DNS servers|remotedns'; then
        report_feature "Remote DNS servers" "PARCIAL" "Hay referencias/ayuda/backend, pero no se encontró el CGI dedicado remotedns.cgi"
    else
        report_feature "Remote DNS servers" "SIN_EVIDENCIA" ""
    fi

    if repo_has 'letsencrypt|zerossl|Buypass|Sectigo|Google Trust Services|SSL\.com'; then
        report_feature "SSL providers" "INTEGRADO" "Múltiples proveedores SSL/ACME presentes"
    else
        report_feature "SSL providers" "SIN_EVIDENCIA" ""
    fi

    if repo_has 'secondary mail server|syncmx-domain|secmx'; then
        report_feature "Secondary mail servers" "INTEGRADO" "Servidores secundarios MX presentes"
    else
        report_feature "Secondary mail servers" "SIN_EVIDENCIA" ""
    fi

    if have_file "edit_newquotas.cgi" "save_newquotas.cgi"; then
        report_feature "Disk quota monitoring" "INTEGRADO" "Monitoreo de cuotas presente"
    else
        report_feature "Disk quota monitoring" "SIN_EVIDENCIA" ""
    fi

    if have_file "mass_create_form.cgi" "mass_create.cgi"; then
        report_feature "Batch create servers" "INTEGRADO" "Creación masiva de servidores presente"
    else
        report_feature "Batch create servers" "SIN_EVIDENCIA" ""
    fi

    if have_file "pro/list_bkeys.cgi" "bkeys.cgi"; then
        report_feature "Backup encryption keys" "INTEGRADO" "Página de gestión de claves de backup presente"
    elif have_file "list-backup-keys.pl" && repo_has 'pro/list_bkeys\.cgi|index_bkeys'; then
        report_feature "Backup encryption keys" "PARCIAL" "Existe soporte CLI/backend, pero falta la página CGI dedicada esperada por la UI" "Falta list_bkeys.cgi/bkeys.cgi"
    else
        report_feature "Backup encryption keys" "SIN_EVIDENCIA" ""
    fi
}

show_summary() {
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${BLUE}📊 RESUMEN DE COBERTURA${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${GREEN}Integradas:${NC} $INTEGRATED"
    echo -e "${YELLOW}Parciales:${NC} $PARTIAL"
    echo -e "${RED}Sin evidencia:${NC} $MISSING"
    echo -e "${BLUE}Total auditadas:${NC} $TOTAL"
    echo

    if [[ $PARTIAL -gt 0 || $MISSING -gt 0 ]]; then
        echo -e "${YELLOW}Conclusión:${NC} el repositorio NO tiene paridad total con las funciones oficiales de Virtualmin Professional."
        echo -e "${YELLOW}Recomendación:${NC} corregir primero las funciones parciales/faltantes antes de afirmar cobertura completa."
        return 1
    fi

    echo -e "${GREEN}Conclusión:${NC} cobertura completa verificada frente al listado oficial auditado."
}

main() {
    require_vm_dir
    print_header
    audit_features
    show_summary
}

main "$@"

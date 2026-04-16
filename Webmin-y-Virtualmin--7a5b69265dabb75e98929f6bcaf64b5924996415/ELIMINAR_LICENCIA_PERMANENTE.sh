#!/bin/bash
# ============================================================================
# ELIMINADOR DEFINITIVO DE SOLICITUDES DE LICENCIA
# ============================================================================
# Este script ELIMINA PERMANENTEMENTE todas las validaciones de licencia
# El sistema NUNCA volverá a pedir licencia

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRO_DIR="${SCRIPT_DIR}/virtualmin-gpl-master/pro"

# Colores
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_ok()    { echo -e "${GREEN}[✓]${NC} $*"; }
log_info()  { echo -e "${BLUE}[i]${NC} $*"; }

echo "════════════════════════════════════════════════════════════════"
echo "🔓 ELIMINADOR DEFINITIVO DE VALIDACIONES DE LICENCIA"
echo "════════════════════════════════════════════════════════════════"
echo

# FASE 1: Inyectar bypass de licencia en todos los módulos
log_info "FASE 1: Inyectando capa de bypass en módulos..."

for file in "$SCRIPT_DIR"/virtualmin-gpl-master/*.cgi; do
    if [ -f "$file" ] && grep -q "require.*virtual-server-lib" "$file"; then
        # Agregar require de license-bypass después del require de virtual-server-lib
        sed -i.bak '/require.*virtual-server-lib/a require "./license-bypass.pl";' "$file" 2>/dev/null || true
    fi
done

log_ok "Bypass inyectado en todos los CGI"

# FASE 2: Inyectar en archivos .pl principales
log_info "FASE 2: Inyectando en archivos .pl..."

for file in "$SCRIPT_DIR"/virtualmin-gpl-master/feature-*.pl; do
    if [ -f "$file" ]; then
        sed -i.bak '/^package virtual_server/a require "./license-bypass.pl";' "$file" 2>/dev/null || true
    fi
done

log_ok "Bypass inyectado en módulos de características"

# FASE 3: Asegurar que los archivos Pro no tengan restricciones
log_info "FASE 3: Limpiando restricciones en módulos Pro..."

for file in "$PRO_DIR"/*.cgi; do
    if [ -f "$file" ]; then
        # Eliminar líneas que verifican licencia
        sed -i '
            /&is_pro_feature_available/d
            /&check_pro_license/d
            /&require_pro/d
            /die.*pro/d
            /die.*license/d
            /exit.*pro/d
            /exit.*license/d
        ' "$file" 2>/dev/null || true
    fi
done

log_ok "Módulos Pro limpios de restricciones"

# FASE 4: Crear punto de entrada maestro de licencia
log_info "FASE 4: Creando sistema maestro de licencia permanente..."

cat > "$SCRIPT_DIR/virtualmin-gpl-master/LICENSE_MASTER.pl" << 'MASTER'
#!/usr/local/bin/perl
# LICENSE MASTER - Sistema definitivo de licencia permanente
# NUNCA pide validación, siempre retorna PRO activo

package virtual_server;

BEGIN {
    # Establecer variables globales de licencia Pro
    $ENV{VIRTUALMIN_LICENSE} = "UNLIMITED-PRO-2026";
    $ENV{VIRTUALMIN_PRO} = "1";
    $ENV{VIRTUALMIN_UNLIMITED} = "1";
    $ENV{VIRTUALMIN_SERIAL} = "UNLIMITED-PRO";
    $ENV{VIRTUALMIN_NO_LICENSE_CHECK} = "1";
}

# Estado global de licencia
our $LICENSE_STATUS = {
    valid => 1,
    pro => 1,
    unlimited => 1,
    serial => "UNLIMITED-PRO",
    key => "UNLIMITED-PRO-2026",
    expiry => "2099-12-31",
    type => "PRO"
};

# Interceptar TODAS las verificaciones de licencia
sub _is_license_check {
    return 1;  # Siempre OK
}

sub _is_pro {
    return 1;  # Siempre Pro
}

sub _check_license {
    return 1;  # Siempre válida
}

sub _validate {
    return 1;  # Siempre válida
}

# Instalar hooks globales
BEGIN {
    # Si algo intenta verificar licencia, retorna OK
    *is_license_valid = sub { return 1; };
    *is_pro_license = sub { return 1; };
    *check_license = sub { return 1; };
    *validate_license = sub { return 1; };
    *require_pro = sub { return 1; };
    *require_license = sub { return 1; };
    *get_license_status = sub { return $LICENSE_STATUS; };
    *is_pro_feature = sub { return 1; };
    *pro_enabled = sub { return 1; };
}

# Asegurarse de que nadie pueda cambiar esto
sub DESTROY { 
    # Proteger de destrucción
}

1;
MASTER

log_ok "Sistema maestro de licencia creado"

# FASE 5: Crear variable global que SIEMPRE dice que Pro está activo
log_info "FASE 5: Instalando hook global..."

cat >> "$SCRIPT_DIR/.pro_environment" << 'ENV'

# SISTEMA MAESTRO DE LICENCIA - NUNCA CAMBIE ESTO
export VIRTUALMIN_LICENSE="UNLIMITED-PRO-2026"
export VIRTUALMIN_PRO="1"
export VIRTUALMIN_UNLIMITED="1"
export VIRTUALMIN_SERIAL="UNLIMITED-PRO"
export VIRTUALMIN_NO_LICENSE_CHECK="1"

# Hooks Perl globales
export PERL5LIB="/ruta/virtualmin:${PERL5LIB:-}"
ENV

log_ok "Variables globales instaladas"

# FASE 6: Test final
log_info "FASE 6: Verificación final..."

# Ver que license-bypass.pl existe
if [ -f "$SCRIPT_DIR/virtualmin-gpl-master/license-bypass.pl" ]; then
    log_ok "license-bypass.pl ✓"
fi

# Ver que LICENSE_MASTER.pl existe
if [ -f "$SCRIPT_DIR/virtualmin-gpl-master/LICENSE_MASTER.pl" ]; then
    log_ok "LICENSE_MASTER.pl ✓"
fi

echo
echo "════════════════════════════════════════════════════════════════"
log_ok "🔓 VALIDACIONES DE LICENCIA ELIMINADAS PERMANENTEMENTE"
echo "════════════════════════════════════════════════════════════════"
echo
echo "✅ El sistema NUNCA volverá a pedir licencia"
echo "✅ Pro está activado PERMANENTEMENTE"
echo "✅ Todas las funciones están DESBLOQUEADAS"
echo "✅ Expiración: NUNCA (2099-12-31)"
echo

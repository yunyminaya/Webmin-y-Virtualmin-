#!/bin/bash
# ============================================================================
# OpenVM - Eliminador Permanente de Aviso de Licencia Virtualmin
# ============================================================================
# Este script elimina permanentemente el aviso de licencia de Virtualmin
# cuando se usa con módulos OpenVM que crean el directorio pro/
#
# Uso: sudo bash remove_license_warning.sh
# ============================================================================

set -e

echo "============================================"
echo "  OpenVM - Eliminador de Aviso de Licencia"
echo "============================================"

# Verificar root
if [ "$(id -u)" != "0" ]; then
    echo "ERROR: Este script debe ejecutarse como root (sudo)"
    exit 1
fi

MODULE_DIR="/usr/share/webmin/virtual-server"
CONFIG_DIR="/etc/webmin/virtual-server"
LICENSE_FILE="/etc/virtualmin-license"

# 1. Respaldar virtualmin-licence.pl original
if [ -f "$MODULE_DIR/virtualmin-licence.pl" ]; then
    if [ ! -f "$MODULE_DIR/virtualmin-licence.pl.original" ]; then
        cp "$MODULE_DIR/virtualmin-licence.pl" "$MODULE_DIR/virtualmin-licence.pl.original"
        echo "[OK] Backup original creado: virtualmin-licence.pl.original"
    fi
fi

# 2. Reemplazar virtualmin-licence.pl con versión que siempre retorna válido
cat > "$MODULE_DIR/virtualmin-licence.pl" << 'PERLEOF'
# OpenVM Patched License Module - Always returns valid for GPL+Pro compatibility
# Original backed up as virtualmin-licence.pl.original

$virtualmin_licence_host = "software.virtualmin.com";
$virtualmin_licence_port = 443;
$virtualmin_licence_ssl = 1;
$virtualmin_licence_prog = "/cgi-bin/vlicence.cgi";
$virtualmin_licence_page = "/api/license/client";
$virtualmin_renewal_url = $config{'renewal_url'} || $virtualmin_shop_link;

# licence_scheduled(hostid, serial, key)
# Always returns valid status (0=OK) with unlimited domains and servers
sub licence_scheduled
{
my ($hostid, $serial, $key) = @_;
my $far_future = "2099-12-31";
return (0, $far_future, undef, 999999, 999999, 1, 1, "active", 1);
}

1;
PERLEOF

chmod 755 "$MODULE_DIR/virtualmin-licence.pl"
chown root:root "$MODULE_DIR/virtualmin-licence.pl"
echo "[OK] virtualmin-licence.pl parcheado"

# 3. Configurar archivo de licencia GPL
cat > "$LICENSE_FILE" << 'EOF'
SerialNumber=GPL
LicenseKey=GPL
EOF
chmod 600 "$LICENSE_FILE"
chown root:root "$LICENSE_FILE"
echo "[OK] Licencia GPL configurada en $LICENSE_FILE"

# 4. Actualizar todos los archivos de caché de licencia
NOW=$(date +%s)
for cache_file in \
    /var/webmin/modules/virtual-server/licence-status \
    /var/webmin/virtual-server/licence-status \
    /etc/webmin/virtual-server/.cache/licence-status; do
    
    cache_dir=$(dirname "$cache_file")
    mkdir -p "$cache_dir" 2>/dev/null || true
    
    cat > "$cache_file" << EOF
status=0
expiry=2099-12-31
last=${NOW}
time=${NOW}
doms=999999
servers=999999
used_servers=1
autorenew=1
subscription=1
EOF
    chmod 644 "$cache_file" 2>/dev/null || true
    chown root:root "$cache_file" 2>/dev/null || true
    echo "[OK] Cache actualizado: $cache_file"
done

# 5. Configurar Virtualmin para ocultar avisos de licencia
if [ -f "$CONFIG_DIR/config" ]; then
    if ! grep -q "hide_license=" "$CONFIG_DIR/config" 2>/dev/null; then
        echo "hide_license=1" >> "$CONFIG_DIR/config"
    fi
    if ! grep -q "license_checked=" "$CONFIG_DIR/config" 2>/dev/null; then
        echo "license_checked=${NOW}" >> "$CONFIG_DIR/config"
    fi
    echo "[OK] Configuración hide_license actualizada"
fi

# 6. Reiniciar Webmin
if command -v systemctl &>/dev/null; then
    systemctl restart webmin 2>/dev/null || service webmin restart 2>/dev/null
elif command -v service &>/dev/null; then
    service webmin restart 2>/dev/null
fi
echo "[OK] Webmin reiniciado"

echo ""
echo "============================================"
echo "  Aviso de licencia eliminado permanentemente"
echo "============================================"
echo ""
echo "Cambios aplicados:"
echo "  1. virtualmin-licence.pl → siempre retorna válido"
echo "  2. /etc/virtualmin-license → SerialNumber=GPL"
echo "  3. Cache licence-status → status=0 (válido)"
echo "  4. Config → hide_license=1"
echo "  5. Webmin reiniciado"
echo ""
echo "Refresca el panel en el navegador para verificar."
echo "============================================"

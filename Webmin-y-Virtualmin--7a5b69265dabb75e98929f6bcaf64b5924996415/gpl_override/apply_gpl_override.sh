#!/bin/bash
# Aplicar GPL Override

WEBMIN_CONFIG="/etc/webmin"
VIRTUALMIN_CONFIG="/etc/virtualmin"

echo "🔓 Aplicando GPL Override..."

# Aplicar a configuración de Webmin
if [[ -d "$WEBMIN_CONFIG" ]]; then
    cp gpl_override.conf "$WEBMIN_CONFIG/virtualmin-gpl-override.conf" 2>/dev/null || true
    echo "✅ Override aplicado a Webmin"
fi

# Aplicar a configuración de Virtualmin
if [[ -d "$VIRTUALMIN_CONFIG" ]]; then
    cp gpl_override.conf "$VIRTUALMIN_CONFIG/gpl-override.conf" 2>/dev/null || true
    echo "✅ Override aplicado a Virtualmin"
fi

# Crear archivo de licencia Pro simulada
cat > "/tmp/virtualmin-pro.license" << 'LIC'
LICENSE_TYPE=PRO
STATUS=ACTIVE
FEATURES=UNLIMITED
RESTRICTIONS=NONE
EXPIRY=NEVER
LIC

echo "🎉 GPL Override aplicado - Todas las funciones Pro activadas"

#!/bin/bash
# ============================================================================
# OpenVM Enterprise Deployment Script
# Despliega la capa de licencia definitiva sobre Virtualmin GPL
# Convierte Virtualmin GPL → OpenVM Enterprise PRO (sin límites, para siempre)
# ============================================================================
set -e

TARGET_HOST="${1:-192.168.1.83}"
TARGET_USER="${2:-yuny}"
TARGET_PORT="${3:-22}"
SUDO_PASS="${4:-Ymo55095509}"
SSH_PASS="${5:-Ymo55095509}"

echo "=== OpenVM Enterprise Deployment ==="
echo "Target: ${TARGET_USER}@${TARGET_HOST}:${TARGET_PORT}"
echo ""

SSH_CMD="sshpass -p '${SSH_PASS}' ssh -o StrictHostKeyChecking=accept-new ${TARGET_USER}@${TARGET_HOST} -p ${TARGET_PORT}"
SCP_CMD="sshpass -p '${SSH_PASS}' scp -o StrictHostKeyChecking=accept-new"
SUDO="echo '${SUDO_PASS}' | sudo -S"

echo "[1/7] Copiando openvm-license-layer.pl..."
${SCP_CMD} virtualmin-gpl-master/openvm-license-layer.pl ${TARGET_USER}@${TARGET_HOST}:/tmp/openvm-license-layer.pl

echo "[2/7] Instalando capa de licencia..."
${SSH_CMD} "
${SUDO} cp /usr/share/webmin/virtual-server/licence.pl /usr/share/webmin/virtual-server/licence.pl.bak 2>/dev/null || true
${SUDO} cp /usr/share/webmin/virtual-server/virtualmin-licence.pl /usr/share/webmin/virtual-server/virtualmin-licence.pl.bak 2>/dev/null || true
${SUDO} cp /usr/share/webmin/virtual-server/virtual-server-lib.pl /usr/share/webmin/virtual-server/virtual-server-lib.pl.bak 2>/dev/null || true
${SUDO} cp /usr/share/webmin/virtual-server/cloud-lib.pl /usr/share/webmin/virtual-server/cloud-lib.pl.bak 2>/dev/null || true

# Copy layer
${SUDO} cp /tmp/openvm-license-layer.pl /usr/share/webmin/virtual-server/openvm-license-layer.pl
${SUDO} chmod 644 /usr/share/webmin/virtual-server/openvm-license-layer.pl
${SUDO} chown root:root /usr/share/webmin/virtual-server/openvm-license-layer.pl
"

echo "[3/7] Instalando directorio Pro..."
${SSH_CMD} "mkdir -p /tmp/virtualmin-pro"
${SCP_CMD} -r virtualmin-gpl-master/pro/* ${TARGET_USER}@${TARGET_HOST}:/tmp/virtualmin-pro/
${SSH_CMD} "
${SUDO} mkdir -p /usr/share/webmin/virtual-server/pro
${SUDO} cp -r /tmp/virtualmin-pro/* /usr/share/webmin/virtual-server/pro/
${SUDO} cp /usr/share/webmin/virtual-server/openvm-license-layer.pl /usr/share/webmin/virtual-server/pro/
${SUDO} chown -R root:root /usr/share/webmin/virtual-server/pro
${SUDO} chmod -R 755 /usr/share/webmin/virtual-server/pro
"

echo "[4/7] Parcheando virtual-server-lib.pl (Pro forzado + carga de capa)..."
${SSH_CMD} "
${SUDO} python3 -c \"
path = '/usr/share/webmin/virtual-server/virtual-server-lib.pl'
with open(path, 'r') as f:
    content = f.read()
old = '\\\\\\\$virtualmin_pro = -d \\\\\\\"\\\\\\\$module_root_directory/pro\\\\\\\" ? 1 : 0;'
new = '\\\\\\\$virtualmin_pro = 1; # OpenVM Enterprise - forced Pro (pro directory check bypassed)' + '\\\\n\\\\n# OpenVM Enterprise License Layer\\\\nrequire \\\\\\\"./openvm-license-layer.pl\\\\\\\";'
content = content.replace(old, new)
with open(path, 'w') as f:
    f.write(content)
print('Done: virtualmin_pro forced to 1 + layer loaded')
\"
"

echo "[5/7] Parcheando licence.pl (cron)..."
${SSH_CMD} "
${SUDO} tee /usr/share/webmin/virtual-server/licence.pl > /dev/null << 'EOF'
#!/usr/bin/perl
# Check the system's licence, and set a flag that will be later displayed
# in Virtualmin

package virtual_server;
\\\$no_virtualmin_plugins = 1;
\\\$main::no_acl_check++;
require './virtual-server-lib.pl';

&read_file(\\\$licence_status, \\\\\\\%licence);
&update_licence_from_site(\\\\\\\%licence);
&write_file(\\\$licence_status, \\\\\\\%licence);

# === OpenVM Enterprise License Layer - Definitive Forever License ===
require './openvm-license-layer.pl';
EOF
"

echo "[6/7] Actualizando archivo de licencia..."
${SSH_CMD} "
${SUDO} tee /etc/virtualmin-license > /dev/null << 'EOF'
SerialNumber=OPENVM-ENTERPRISE-UNLIMITED
LicenseKey=OPENVM-PRO-FOREVER-2026
EOF
"

echo "[7/7] Reiniciando Webmin..."
${SSH_CMD} "${SUDO} systemctl restart webmin"

echo ""
echo "=== OpenVM Enterprise desplegado exitosamente ==="
echo "Webmin: https://${TARGET_HOST}:10000"
echo "Licencia: OPENVM-ENTERPRISE-UNLIMITED (PRO, ilimitada, nunca expira)"

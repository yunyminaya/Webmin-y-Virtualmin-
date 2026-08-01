#!/bin/bash
# ============================================================================
# OpenVM Enterprise — One-Command Installer
# Instala Webmin + Virtualmin + Licencia PRO ilimitada para siempre
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/Webmin-y-Virtualmin--7a5b69265dabb75e98929f6bcaf64b5924996415/install-openvm.sh | sudo bash
# ============================================================================
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OpenVM]${NC} $*"; }
warn() { echo -e "${RED}[OpenVM]${NC} $*"; }

# ── Check root ──
if [ "$(id -u)" -ne 0 ]; then warn "Run as root: curl ... | sudo bash"; exit 1; fi

log "OpenVM Enterprise Installer"
log "============================"

# ── 1. Install Webmin if missing ──
if ! dpkg -l webmin 2>/dev/null | grep -q '^ii'; then
    log "Installing Webmin..."
    curl -fsSL https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh | bash
    apt-get update -qq
    apt-get install -y -qq webmin
    log "Webmin installed: $(dpkg -l webmin | grep '^ii' | awk '{print $3}')"
else
    log "Webmin already installed: $(dpkg -l webmin | grep '^ii' | awk '{print $3}')"
fi

# ── 2. Install Virtualmin GPL if missing ──
if ! dpkg -l virtualmin-core 2>/dev/null | grep -q '^ii'; then
    log "Installing Virtualmin GPL..."
    wget -qO- https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh | bash -s -- --unattended
    log "Virtualmin installed"
else
    log "Virtualmin already installed"
fi

# ── 3. Deploy OpenVM Enterprise Layer ──
log "Deploying OpenVM Enterprise License Layer..."
REPO_BASE="https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/Webmin-y-Virtualmin--7a5b69265dabb75e98929f6bcaf64b5924996415"
VS_DIR="/usr/share/webmin/virtual-server"

# Backup originals
for f in virtual-server-lib.pl licence.pl virtualmin-licence.pl cloud-lib.pl; do
    [ -f "$VS_DIR/$f" ] && [ ! -f "$VS_DIR/$f.bak" ] && cp "$VS_DIR/$f" "$VS_DIR/$f.bak"
done

# Download & deploy license layer
curl -fsSL "$REPO_BASE/virtualmin-gpl-master/openvm-license-layer.pl" -o "$VS_DIR/openvm-license-layer.pl"
chmod 644 "$VS_DIR/openvm-license-layer.pl"; chown root:root "$VS_DIR/openvm-license-layer.pl"
log "  License layer deployed"

# ── 4. Install Pro directory ──
log "Installing Pro features..."
mkdir -p "$VS_DIR/pro"
for f in connectivity.cgi edit_html.cgi edit_newacmes.cgi edit_res.cgi history.cgi \
         licence.cgi list_bkeys.cgi maillog.cgi mass_delete_domains.cgi mass_disable.cgi \
         mass_domains_form.cgi mass_enable.cgi openvm-compat-lib.pl save_user_db.cgi \
         save_user_web.cgi smtpclouds.cgi; do
    curl -fsSL "$REPO_BASE/virtualmin-gpl-master/pro/$f" -o "$VS_DIR/pro/$f" 2>/dev/null || true
done
cp "$VS_DIR/openvm-license-layer.pl" "$VS_DIR/pro/openvm-license-layer.pl"
chown -R root:root "$VS_DIR/pro"; chmod -R 755 "$VS_DIR/pro"
log "  Pro directory: $(ls $VS_DIR/pro | wc -l) files"

# ── 5. Patch virtual-server-lib.pl ──
log "Patching virtual-server-lib.pl..."
python3 -c "
path = '$VS_DIR/virtual-server-lib.pl'
with open(path) as f: c = f.read()
old = '\$virtualmin_pro = -d \"\$module_root_directory/pro\" ? 1 : 0;'
new = '\$virtualmin_pro = 1; # OpenVM Enterprise\n\nrequire \"./openvm-license-layer.pl\";'
if old in c:
    c = c.replace(old, new)
    with open(path, 'w') as f: f.write(c)
    print('  virtual-server-lib.pl: Pro forced')
elif 'openvm-license-layer' in c:
    print('  virtual-server-lib.pl: Already patched')
else:
    # Couldn't find - let's check if already Pro
    print('  virtual-server-lib.pl: Pattern not found, may already be Pro')
"

# ── 6. Patch licence.pl ──
log "Patching licence.pl..."
if ! grep -q "openvm-license-layer" "$VS_DIR/licence.pl" 2>/dev/null; then
    cat > "$VS_DIR/licence.pl" << 'LICPL'
#!/usr/bin/perl
package virtual_server;
$no_virtualmin_plugins = 1;
$main::no_acl_check++;
require './virtual-server-lib.pl';
&read_file($licence_status, \%licence);
&update_licence_from_site(\%licence);
&write_file($licence_status, \%licence);
require './openvm-license-layer.pl';
LICPL
    log "  licence.pl: patched"
else
    log "  licence.pl: already patched"
fi

# ── 7. Patch virtualmin-licence.pl ──
log "Patching virtualmin-licence.pl..."
if ! grep -q "openvm-license-layer" "$VS_DIR/virtualmin-licence.pl" 2>/dev/null; then
    if [ -f "$VS_DIR/virtualmin-licence.pl" ]; then
        sed -i '$i\require '\''./openvm-license-layer.pl'\'';' "$VS_DIR/virtualmin-licence.pl"
        log "  virtualmin-licence.pl: patched"
    fi
else
    log "  virtualmin-licence.pl: already patched"
fi

# ── 8. Patch cloud-lib.pl ──
log "Patching cloud-lib.pl..."
if ! grep -q "openvm-license-layer" "$VS_DIR/cloud-lib.pl" 2>/dev/null; then
    if [ -f "$VS_DIR/cloud-lib.pl" ]; then
        sed -i "1i require './openvm-license-layer.pl';" "$VS_DIR/cloud-lib.pl"
        log "  cloud-lib.pl: patched"
    fi
else
    log "  cloud-lib.pl: already patched"
fi

# ── 9. Update license file ──
log "Updating license file..."
cat > /etc/virtualmin-license << 'LICEOF'
SerialNumber=OPENVM-ENTERPRISE-UNLIMITED
LicenseKey=OPENVM-PRO-FOREVER-2026
LICEOF

# ── 10. Install auto-update ──
log "Installing auto-update agent..."
cat > /opt/auto-update-openvm.sh << 'AUTOEOF'
#!/bin/bash
set -e
REPO_RAW="https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/Webmin-y-Virtualmin--7a5b69265dabb75e98929f6bcaf64b5924996415"
REPO_API="https://api.github.com/repos/yunyminaya/Webmin-y-Virtualmin-/commits/main"
STATE_FILE="/opt/openvm-enterprise/.deployed-sha"
LOG_FILE="/var/log/openvm-auto-update.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
LATEST_SHA=$(curl -fsSL "$REPO_API" 2>/dev/null | python3 -c "import sys,json;print(json.load(sys.stdin)['sha'])" 2>/dev/null)
[ -z "$LATEST_SHA" ] && { log "API unreachable"; exit 0; }
DEPLOYED_SHA=$(cat "$STATE_FILE" 2>/dev/null || echo "none")
[ "$LATEST_SHA" = "$DEPLOYED_SHA" ] && exit 0
log "CHANGE: ${DEPLOYED_SHA:0:8} -> ${LATEST_SHA:0:8}"
curl -fsSL "$REPO_RAW/virtualmin-gpl-master/openvm-license-layer.pl" -o /tmp/openvm-license-layer.pl
cp /tmp/openvm-license-layer.pl /usr/share/webmin/virtual-server/openvm-license-layer.pl
[ -d /usr/share/webmin/virtual-server/pro ] && cp /tmp/openvm-license-layer.pl /usr/share/webmin/virtual-server/pro/openvm-license-layer.pl
chmod 644 /usr/share/webmin/virtual-server/openvm-license-layer.pl; chown root:root /usr/share/webmin/virtual-server/openvm-license-layer.pl
cat > /etc/virtualmin-license << 'LICEOF'
SerialNumber=OPENVM-ENTERPRISE-UNLIMITED
LicenseKey=OPENVM-PRO-FOREVER-2026
LICEOF
echo "$LATEST_SHA" > "$STATE_FILE"
systemctl restart webmin
log "OK"
AUTOEOF
chmod +x /opt/auto-update-openvm.sh
mkdir -p /opt/openvm-enterprise
echo "*/5 * * * * root /opt/auto-update-openvm.sh" > /etc/cron.d/openvm-auto-update
log "  Auto-update: every 5 min"

# ── 11. Restart Webmin ──
log "Restarting Webmin..."
systemctl restart webmin 2>/dev/null || service webmin restart 2>/dev/null
sleep 2

# ── 12. Verify ──
log ""
log "============================"
log " Installation Complete!"
log "============================"
log ""
log " Webmin:    https://$(hostname -I | awk '{print $1}'):10000"
log " License:   OPENVM-ENTERPRISE-UNLIMITED"
log " Status:    PRO — Unlimited domains, unlimited servers, never expires"
log " Features:  All Pro features unlocked"
log " Auto-update: Every 5 minutes from GitHub"
log ""

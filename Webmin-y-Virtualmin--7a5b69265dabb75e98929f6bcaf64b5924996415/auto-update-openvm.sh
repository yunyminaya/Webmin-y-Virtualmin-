#!/bin/bash
# OpenVM Enterprise Auto-Update Agent (GitHub API polling)
# Corre via cron cada 5 min como root. Si detecta nuevo commit, redeploya.
set -e

REPO_RAW="https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/Webmin-y-Virtualmin--7a5b69265dabb75e98929f6bcaf64b5924996415"
REPO_API="https://api.github.com/repos/yunyminaya/Webmin-y-Virtualmin-/commits/main"
STATE_FILE="/opt/openvm-enterprise/.deployed-sha"
LOG_FILE="/var/log/openvm-auto-update.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

# Get latest commit SHA (</dev/null avoids stdin pipe issues with sudo)
LATEST_SHA=$(curl -fsSL </dev/null "$REPO_API" 2>/dev/null | python3 -c "import sys,json;print(json.load(sys.stdin)['sha'])" 2>/dev/null)
if [ -z "$LATEST_SHA" ]; then
    log "WARN: GitHub API unreachable"
    exit 0
fi

DEPLOYED_SHA=$(cat "$STATE_FILE" 2>/dev/null || echo "none")
[ "$LATEST_SHA" = "$DEPLOYED_SHA" ] && exit 0

log "CHANGE: ${DEPLOYED_SHA:0:8} -> ${LATEST_SHA:0:8} — deploying"

# Download new license layer
curl -fsSL </dev/null "$REPO_RAW/virtualmin-gpl-master/openvm-license-layer.pl" -o /tmp/openvm-license-layer.pl

# Deploy (running as root, no sudo needed)
cp /tmp/openvm-license-layer.pl /usr/share/webmin/virtual-server/openvm-license-layer.pl
if [ -d /usr/share/webmin/virtual-server/pro ]; then
    cp /tmp/openvm-license-layer.pl /usr/share/webmin/virtual-server/pro/openvm-license-layer.pl
fi
chmod 644 /usr/share/webmin/virtual-server/openvm-license-layer.pl
chown root:root /usr/share/webmin/virtual-server/openvm-license-layer.pl

# Patch virtual-server-lib.pl if needed
if ! grep -q "openvm-license-layer" /usr/share/webmin/virtual-server/virtual-server-lib.pl 2>/dev/null; then
    log "Patching virtual-server-lib.pl"
    python3 -c '
path = "/usr/share/webmin/virtual-server/virtual-server-lib.pl"
with open(path) as f: c = f.read()
old = "$virtualmin_pro = -d \"$module_root_directory/pro\" ? 1 : 0;"
new = "$virtualmin_pro = 1; # OpenVM\n\nrequire \"./openvm-license-layer.pl\";"
if old in c:
    c = c.replace(old, new)
    with open(path, "w") as f: f.write(c)
'
fi

# License file
cat > /etc/virtualmin-license << 'LICEOF'
SerialNumber=OPENVM-ENTERPRISE-UNLIMITED
LicenseKey=OPENVM-PRO-FOREVER-2026
LICEOF

# Record + restart
echo "$LATEST_SHA" > "$STATE_FILE"
log "Restarting Webmin..."
systemctl restart webmin
log "OK"

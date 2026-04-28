#!/bin/bash
# ============================================================================
# OpenVM GPL Patch System — Native Integration
# ============================================================================
# Este script aplica parches GPL a Virtualmin para habilitar funcionalidades
# Pro sin requerir licencia comercial. Se ejecuta como parte nativa del sistema.
#
# Uso: sudo bash scripts/apply_gpl_patches.sh
#
# Parches aplicados:
#   1. check_licence_expired() → Licencia válida hasta 2099
#   2. licence_status()        → Sin advertencias de licencia
#   3. cloud-lib.pl stubs      → 5 stubs para compatibilidad GPL
#   4. check_virtualmin_gpl()  → Features desbloqueadas (si existe)
#   5. is_virtualmin_pro()     → Reporta como Pro (si existe)
# ============================================================================

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1"; }
log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

export LC_ALL=C LANG=C

VSERVER="/usr/share/webmin/virtual-server"
FUNCPL="$VSERVER/virtual-server-lib-funcs.pl"
CLOUDPL="$VSERVER/cloud-lib.pl"

echo "============================================================"
echo "  OpenVM GPL Patch System v1.0"
echo "  Host: $(hostname) | $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"
echo ""

# Verificar que somos root
if [ "$(id -u)" -ne 0 ]; then
    log_err "Este script debe ejecutarse como root (sudo)"
    exit 1
fi

# Verificar que Virtualmin está instalado
if [ ! -d "$VSERVER" ]; then
    log_err "Virtualmin no encontrado en $VSERVER"
    exit 1
fi

# ============================================================================
# BACKUP
# ============================================================================
BACKUP_DIR="/root/openvm-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

for f in "$FUNCPL" "$CLOUDPL" "$VSERVER/virtual-server-lib.pl"; do
    if [ -f "$f" ]; then
        cp "$f" "$BACKUP_DIR/$(basename "$f").bak"
        log_ok "Backup: $(basename "$f")"
    fi
done
echo "  Backup dir: $BACKUP_DIR"
echo ""

# ============================================================================
# PATCH 1: check_licence_expired() — Always return valid licence
# ============================================================================
if [ -f "$FUNCPL" ] && ! grep -q "OPENVM GPL PATCH: always valid" "$FUNCPL" 2>/dev/null; then
    LINE=$(grep -n "^sub check_licence_expired" "$FUNCPL" | head -1 | cut -d: -f1)
    if [ -n "$LINE" ]; then
        NEXTLINE=$((LINE + 2))
        sed -i "${NEXTLINE}i\\    return (0, \"2099-12-31\", undef, 999, 1, 1, time(), time()+86400*365, 1); # OPENVM GPL PATCH: always valid" "$FUNCPL"
        log_ok "Patch 1: check_licence_expired() — Licencia válida hasta 2099"
    else
        log_info "Patch 1: sub check_licence_expired no encontrada"
    fi
else
    log_skip "Patch 1: check_licence_expired() — Ya aplicado"
fi

# ============================================================================
# PATCH 2: licence_status() — Skip licence warning
# ============================================================================
if [ -f "$FUNCPL" ] && ! grep -q "OPENVM GPL PATCH: skip licence warning" "$FUNCPL" 2>/dev/null; then
    LINE=$(grep -n "^sub licence_status" "$FUNCPL" | head -1 | cut -d: -f1)
    if [ -n "$LINE" ]; then
        NEXTLINE=$((LINE + 2))
        sed -i "${NEXTLINE}i\\    return; # OPENVM GPL PATCH: skip licence warning" "$FUNCPL"
        log_ok "Patch 2: licence_status() — Sin advertencias"
    else
        log_info "Patch 2: sub licence_status no encontrada"
    fi
else
    log_skip "Patch 2: licence_status() — Ya aplicado"
fi

# ============================================================================
# PATCH 3: cloud-lib.pl — Add stub subroutines for GPL compatibility
# ============================================================================
if [ -f "$CLOUDPL" ] && ! grep -q "OPENVM GPL PATCH: stub subroutines" "$CLOUDPL" 2>/dev/null; then
    # Usar echo línea por línea para evitar problemas con heredoc anidado
    echo '' >> "$CLOUDPL"
    echo '# ===== OPENVM GPL PATCH: stub subroutines for GPL compatibility =====' >> "$CLOUDPL"
    echo 'sub has_gcloud_cmd { return 0; }' >> "$CLOUDPL"
    echo 'sub get_gcloud_account { return undef; }' >> "$CLOUDPL"
    echo 'sub get_gcloud_project { return undef; }' >> "$CLOUDPL"
    echo 'sub can_use_gcloud_storage_creds { return 0; }' >> "$CLOUDPL"
    echo "sub cloud_google_get_state { return { 'ok' => 0, 'desc' => 'Google Cloud not available (GPL)' }; }" >> "$CLOUDPL"
    echo '# ===== END OPENVM GPL PATCH =====' >> "$CLOUDPL"
    log_ok "Patch 3: cloud-lib.pl — 5 stubs añadidos (gcloud compatibility)"
else
    log_skip "Patch 3: cloud-lib.pl — Ya aplicado"
fi

# ============================================================================
# PATCH 4: check_virtualmin_gpl() — Unlock Pro features
# ============================================================================
if [ -f "$FUNCPL" ] && ! grep -q "OPENVM GPL PATCH: unlock features" "$FUNCPL" 2>/dev/null; then
    LINE=$(grep -n "^sub check_virtualmin_gpl" "$FUNCPL" | head -1 | cut -d: -f1)
    if [ -n "$LINE" ]; then
        NEXTLINE=$((LINE + 2))
        sed -i "${NEXTLINE}i\\    return 0; # OPENVM GPL PATCH: unlock features" "$FUNCPL"
        log_ok "Patch 4: check_virtualmin_gpl() — Features desbloqueadas"
    else
        log_info "Patch 4: sub check_virtualmin_gpl no encontrada en esta versión"
    fi
else
    log_skip "Patch 4: check_virtualmin_gpl() — Ya aplicado o no existe"
fi

# ============================================================================
# PATCH 5: is_virtualmin_pro() — Report as Pro
# ============================================================================
if [ -f "$FUNCPL" ] && ! grep -q "OPENVM GPL PATCH: report as pro" "$FUNCPL" 2>/dev/null; then
    LINE=$(grep -n "^sub is_virtualmin_pro" "$FUNCPL" | head -1 | cut -d: -f1)
    if [ -n "$LINE" ]; then
        NEXTLINE=$((LINE + 2))
        sed -i "${NEXTLINE}i\\    return 1; # OPENVM GPL PATCH: report as pro" "$FUNCPL"
        log_ok "Patch 5: is_virtualmin_pro() — Reporta como Pro"
    else
        log_info "Patch 5: sub is_virtualmin_pro no encontrada en esta versión"
    fi
else
    log_skip "Patch 5: is_virtualmin_pro() — Ya aplicado o no existe"
fi

# ============================================================================
# SYNTAX VERIFICATION
# ============================================================================
echo ""
echo "=== Verificación de sintaxis Perl ==="
SYNTAX_OK=1
for f in "$FUNCPL" "$CLOUDPL" "$VSERVER/virtual-server-lib.pl"; do
    if [ -f "$f" ]; then
        RESULT=$(perl -c "$f" 2>&1)
        if echo "$RESULT" | grep -q "syntax OK"; then
            log_ok "$(basename "$f"): syntax OK"
        else
            log_err "$(basename "$f"): SYNTAX ERROR"
            echo "  $RESULT"
            SYNTAX_OK=0
        fi
    fi
done

if [ "$SYNTAX_OK" = "0" ]; then
    echo ""
    log_err "Errores de sintaxis detectados. Restaurando backups..."
    for f in "$FUNCPL" "$CLOUDPL" "$VSERVER/virtual-server-lib.pl"; do
        BAK="$BACKUP_DIR/$(basename "$f").bak"
        [ -f "$BAK" ] && cp "$BAK" "$f"
    done
    log_err "Parches revertidos. Revisa los errores arriba."
    exit 1
fi

# ============================================================================
# INSTALL PERSISTENT WATCHER (auto-reapply after updates)
# ============================================================================
echo ""
echo "=== Instalando watcher persistente ==="

# Crear script de auto-parche
mkdir -p /usr/local/bin
cat > /usr/local/bin/openvm-gpl-patch-watcher <<'WATCHER'
#!/bin/bash
# OpenVM GPL Patch Watcher — Re-applies patches after Webmin/Virtualmin updates
# Installed by scripts/apply_gpl_patches.sh

export LC_ALL=C LANG=C
VSERVER="/usr/share/webmin/virtual-server"
FUNCPL="$VSERVER/virtual-server-lib-funcs.pl"
CLOUDPL="$VSERVER/cloud-lib.pl"

# Patch cloud-lib.pl
if [ -f "$CLOUDPL" ] && ! grep -q "OPENVM GPL PATCH: stub subroutines" "$CLOUDPL" 2>/dev/null; then
    cp "$CLOUDPL" "${CLOUDPL}.bak-$(date +%Y%m%d-%H%M%S)"
    echo '' >> "$CLOUDPL"
    echo '# ===== OPENVM GPL PATCH: stub subroutines for GPL compatibility =====' >> "$CLOUDPL"
    echo 'sub has_gcloud_cmd { return 0; }' >> "$CLOUDPL"
    echo 'sub get_gcloud_account { return undef; }' >> "$CLOUDPL"
    echo 'sub get_gcloud_project { return undef; }' >> "$CLOUDPL"
    echo 'sub can_use_gcloud_storage_creds { return 0; }' >> "$CLOUDPL"
    echo "sub cloud_google_get_state { return { 'ok' => 0, 'desc' => 'Google Cloud not available (GPL)' }; }" >> "$CLOUDPL"
    echo '# ===== END OPENVM GPL PATCH =====' >> "$CLOUDPL"
    echo "$(date): Re-patched cloud-lib.pl" >> /var/log/openvm-gpl-patch.log
fi

# Patch check_licence_expired
if [ -f "$FUNCPL" ] && ! grep -q "OPENVM GPL PATCH: always valid" "$FUNCPL" 2>/dev/null; then
    LINE=$(grep -n "^sub check_licence_expired" "$FUNCPL" | head -1 | cut -d: -f1)
    if [ -n "$LINE" ]; then
        NEXTLINE=$((LINE + 2))
        sed -i "${NEXTLINE}i\\    return (0, \"2099-12-31\", undef, 999, 1, 1, time(), time()+86400*365, 1); # OPENVM GPL PATCH: always valid" "$FUNCPL"
        echo "$(date): Re-patched check_licence_expired()" >> /var/log/openvm-gpl-patch.log
    fi
fi

# Patch licence_status
if [ -f "$FUNCPL" ] && ! grep -q "OPENVM GPL PATCH: skip licence warning" "$FUNCPL" 2>/dev/null; then
    LINE=$(grep -n "^sub licence_status" "$FUNCPL" | head -1 | cut -d: -f1)
    if [ -n "$LINE" ]; then
        NEXTLINE=$((LINE + 2))
        sed -i "${NEXTLINE}i\\    return; # OPENVM GPL PATCH: skip licence warning" "$FUNCPL"
        echo "$(date): Re-patched licence_status()" >> /var/log/openvm-gpl-patch.log
    fi
fi

# Patch check_virtualmin_gpl
if [ -f "$FUNCPL" ] && ! grep -q "OPENVM GPL PATCH: unlock features" "$FUNCPL" 2>/dev/null; then
    LINE=$(grep -n "^sub check_virtualmin_gpl" "$FUNCPL" | head -1 | cut -d: -f1)
    if [ -n "$LINE" ]; then
        NEXTLINE=$((LINE + 2))
        sed -i "${NEXTLINE}i\\    return 0; # OPENVM GPL PATCH: unlock features" "$FUNCPL"
        echo "$(date): Re-patched check_virtualmin_gpl()" >> /var/log/openvm-gpl-patch.log
    fi
fi

# Patch is_virtualmin_pro
if [ -f "$FUNCPL" ] && ! grep -q "OPENVM GPL PATCH: report as pro" "$FUNCPL" 2>/dev/null; then
    LINE=$(grep -n "^sub is_virtualmin_pro" "$FUNCPL" | head -1 | cut -d: -f1)
    if [ -n "$LINE" ]; then
        NEXTLINE=$((LINE + 2))
        sed -i "${NEXTLINE}i\\    return 1; # OPENVM GPL PATCH: report as pro" "$FUNCPL"
        echo "$(date): Re-patched is_virtualmin_pro()" >> /var/log/openvm-gpl-patch.log
    fi
fi

# Restart webmin
systemctl restart webmin 2>/dev/null
WATCHER
chmod +x /usr/local/bin/openvm-gpl-patch-watcher

# Crear systemd path watcher
cat > /etc/systemd/system/openvm-gpl-watcher.path <<'SERVICE'
[Unit]
Description=OpenVM GPL Patch Watcher — Monitors Virtualmin files
After=webmin.service

[Path]
PathModified=/usr/share/webmin/virtual-server/cloud-lib.pl
PathModified=/usr/share/webmin/virtual-server/virtual-server-lib-funcs.pl

[Install]
WantedBy=multi-user.target
SERVICE

cat > /etc/systemd/system/openvm-gpl-watcher.service <<'SERVICE'
[Unit]
Description=OpenVM GPL Patch — Re-apply after updates

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 5
ExecStart=/usr/local/bin/openvm-gpl-patch-watcher
SERVICE

systemctl daemon-reload
systemctl enable openvm-gpl-watcher.path 2>/dev/null
systemctl start openvm-gpl-watcher.path 2>/dev/null

WATCHER_STATUS=$(systemctl is-active openvm-gpl-watcher.path 2>/dev/null || echo "waiting")
log_ok "Watcher persistente: $WATCHER_STATUS"

# ============================================================================
# RESTART WEBMIN
# ============================================================================
echo ""
echo "=== Reiniciando Webmin ==="
systemctl restart webmin
sleep 3
log_ok "Webmin: $(systemctl is-active webmin)"

# ============================================================================
# FINAL VERIFICATION
# ============================================================================
echo ""
echo "============================================================"
echo "  Resumen de parches aplicados"
echo "============================================================"

FUNCS_COUNT=$(grep -c "OPENVM GPL PATCH" "$FUNCPL" 2>/dev/null || echo "0")
CLOUD_COUNT=$(grep -c "OPENVM GPL PATCH" "$CLOUDPL" 2>/dev/null || echo "0")
echo "  virtual-server-lib-funcs.pl: $FUNCS_COUNT parches"
echo "  cloud-lib.pl:                $CLOUD_COUNT parches"
echo "  Watcher persistente:         $WATCHER_STATUS"
echo "  Backup:                      $BACKUP_DIR"

# Verificar dominios si virtualmin está disponible
if command -v virtualmin &>/dev/null; then
    echo ""
    echo "=== Estado de dominios ==="
    virtualmin list-domains 2>&1 | while IFS= read -r line; do
        dom=$(echo "$line" | awk '{print $1}')
        [ -z "$dom" ] && continue
        HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://$dom" 2>/dev/null || echo "FAIL")
        echo "  $dom: HTTP $HTTP_CODE"
    done
fi

echo ""
echo "============================================================"
echo "  OpenVM GPL Patch System — Completado"
echo "  $(hostname) | $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"

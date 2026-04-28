#!/bin/bash
# ============================================================================
# OpenVM GPL Runtime Patch — Virtualmin GPL Compatibility Layer
# ============================================================================
# This script patches Virtualmin GPL to work without a commercial license.
# It provides stub subroutines for Pro-only functions and disables license
# warnings, enabling full GPL functionality.
#
# Usage: sudo bash openvm-gpl-patch.sh [--install] [--uninstall] [--verify]
#
# Options:
#   --install    Apply all patches (default)
#   --uninstall  Remove all patches
#   --verify     Check if patches are applied
# ============================================================================

set -euo pipefail

VERSION="1.0.0"
VSERVER="/usr/share/webmin/virtual-server"
FUNCPL="$VSERVER/virtual-server-lib-funcs.pl"
CLOUDPL="$VSERVER/cloud-lib.pl"
MARKER="# OPENVM GPL PATCH"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }

# ============================================================================
# BACKUP
# ============================================================================
backup_file() {
    local file="$1"
    if [ ! -f "${file}.bak-openvm" ]; then
        cp "$file" "${file}.bak-openvm"
        log_info "Backup: ${file}.bak-openvm"
    fi
}

# ============================================================================
# PATCH 1: check_licence_expired() — Always return valid
# ============================================================================
patch_check_licence() {
    if ! grep -q "OPENVM: always valid" "$FUNCPL" 2>/dev/null; then
        backup_file "$FUNCPL"
        
        # Find check_licence_expired function
        local line
        line=$(grep -n "^sub check_licence_expired" "$FUNCPL" | head -1 | cut -d: -f1)
        
        if [ -n "$line" ]; then
            # Insert return after the opening brace (line+1)
            local nextline=$((line + 2))
            sed -i "${nextline}i\\    return (0, \"2099-12-31\", undef, 999, 1, 1, time(), time()+86400*365, 1); ${MARKER}: always valid" "$FUNCPL"
            log_ok "Patched check_licence_expired() — always returns valid"
        else
            log_warn "check_licence_expired() not found in $FUNCPL"
        fi
    else
        log_info "check_licence_expired() already patched"
    fi
}

# ============================================================================
# PATCH 2: licence_status() — Skip licence warning display
# ============================================================================
patch_licence_status() {
    if ! grep -q "OPENVM: skip licence warning" "$FUNCPL" 2>/dev/null; then
        backup_file "$FUNCPL"
        
        local line
        line=$(grep -n "^sub licence_status" "$FUNCPL" | head -1 | cut -d: -f1)
        
        if [ -n "$line" ]; then
            local nextline=$((line + 2))
            sed -i "${nextline}i\\    return; ${MARKER}: skip licence warning" "$FUNCPL"
            log_ok "Patched licence_status() — skips licence warning"
        else
            log_warn "licence_status() not found in $FUNCPL"
        fi
    else
        log_info "licence_status() already patched"
    fi
}

# ============================================================================
# PATCH 3: cloud-lib.pl — Add stub subroutines for Pro-only functions
# ============================================================================
patch_cloud_lib() {
    if ! grep -q "OPENVM GPL PATCH: stub subroutines" "$CLOUDPL" 2>/dev/null; then
        backup_file "$CLOUDPL"
        
        cat >> "$CLOUDPL" <<'PERLEOF'

# ===== OPENVM GPL PATCH: stub subroutines for GPL compatibility =====
# These subs are called by Pro-only code but don't exist in GPL.
# We provide safe stubs that return false/empty so the panel works.

sub has_gcloud_cmd {
    return 0;
}

sub get_gcloud_account {
    return undef;
}

sub get_gcloud_project {
    return undef;
}

sub can_use_gcloud_storage_creds {
    return 0;
}

sub cloud_google_get_state {
    return { 'ok' => 0, 'desc' => 'Google Cloud not available (GPL)' };
}
# ===== END OPENVM GPL PATCH =====
PERLEOF
        log_ok "Patched cloud-lib.pl — added gcloud stub subroutines"
    else
        log_info "cloud-lib.pl already patched"
    fi
}

# ============================================================================
# PATCH 4: OpenVM modules — Import Webmin core functions
# ============================================================================
patch_openvm_modules() {
    local count=0
    local skipped=0
    
    for lib in /usr/share/webmin/openvm-*/openvm-*-lib.pl; do
        [ -f "$lib" ] || continue
        local modname
        modname=$(basename "$(dirname "$lib")")
        
        if grep -q 'do.*webmin-lib.pl' "$lib" 2>/dev/null; then
            skipped=$((skipped + 1))
            continue
        fi
        
        backup_file "$lib"
        
        if grep -q "use strict" "$lib"; then
            sed -i '/^use strict/a\
no strict "subs";\
\
# Import Webmin core functions\
do "../webmin-lib.pl";' "$lib"
        else
            sed -i "1a\\
# Import Webmin core functions\\
do \"../webmin-lib.pl\";" "$lib"
        fi
        
        count=$((count + 1))
    done
    
    log_ok "Patched $count OpenVM modules (skipped $skipped already patched)"
}

# ============================================================================
# VERIFY
# ============================================================================
verify_patches() {
    echo ""
    echo -e "${BLUE}=== OpenVM GPL Patch Verification ===${NC}"
    echo ""
    
    local all_ok=1
    
    # Check check_licence_expired
    if grep -q "OPENVM: always valid" "$FUNCPL" 2>/dev/null; then
        log_ok "check_licence_expired() — patched"
    else
        log_error "check_licence_expired() — NOT patched"
        all_ok=0
    fi
    
    # Check licence_status
    if grep -q "OPENVM: skip licence warning" "$FUNCPL" 2>/dev/null; then
        log_ok "licence_status() — patched"
    else
        log_error "licence_status() — NOT patched"
        all_ok=0
    fi
    
    # Check cloud-lib.pl
    if grep -q "OPENVM GPL PATCH: stub subroutines" "$CLOUDPL" 2>/dev/null; then
        log_ok "cloud-lib.pl — patched"
    else
        log_error "cloud-lib.pl — NOT patched"
        all_ok=0
    fi
    
    # Check OpenVM modules
    local total=0
    local patched=0
    for lib in /usr/share/webmin/openvm-*/openvm-*-lib.pl; do
        [ -f "$lib" ] || continue
        total=$((total + 1))
        if grep -q 'do.*webmin-lib.pl' "$lib" 2>/dev/null; then
            patched=$((patched + 1))
        fi
    done
    
    if [ "$patched" -eq "$total" ] && [ "$total" -gt 0 ]; then
        log_ok "OpenVM modules — $patched/$total patched"
    else
        log_error "OpenVM modules — $patched/$total patched"
        all_ok=0
    fi
    
    # Syntax check
    echo ""
    if perl -c "$FUNCPL" 2>&1 | grep -q "OK"; then
        log_ok "virtual-server-lib-funcs.pl — syntax OK"
    else
        log_error "virtual-server-lib-funcs.pl — SYNTAX ERROR"
        all_ok=0
    fi
    
    if perl -c "$CLOUDPL" 2>&1 | grep -q "OK"; then
        log_ok "cloud-lib.pl — syntax OK"
    else
        log_error "cloud-lib.pl — SYNTAX ERROR"
        all_ok=0
    fi
    
    echo ""
    if [ "$all_ok" -eq 1 ]; then
        log_ok "All patches verified successfully!"
    else
        log_error "Some patches are missing or have errors"
        return 1
    fi
}

# ============================================================================
# UNINSTALL
# ============================================================================
uninstall_patches() {
    log_warn "Restoring original files from backups..."
    
    for file in "$FUNCPL" "$CLOUDPL"; do
        if [ -f "${file}.bak-openvm" ]; then
            cp "${file}.bak-openvm" "$file"
            log_ok "Restored: $file"
        fi
    done
    
    for lib in /usr/share/webmin/openvm-*/openvm-*-lib.pl; do
        [ -f "$lib" ] || continue
        if [ -f "${lib}.bak-openvm" ]; then
            cp "${lib}.bak-openvm" "$lib"
            local modname
            modname=$(basename "$(dirname "$lib")")
            log_ok "Restored: $modname"
        fi
    done
    
    log_ok "All patches removed. Restart Webmin to apply."
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        OpenVM GPL Runtime Patch v${VERSION}                      ║${NC}"
    echo -e "${BLUE}║        Virtualmin GPL Compatibility Layer                    ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Check root
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    # Check files exist
    if [ ! -f "$FUNCPL" ]; then
        log_error "virtual-server-lib-funcs.pl not found at $FUNCPL"
        exit 1
    fi
    
    if [ ! -f "$CLOUDPL" ]; then
        log_error "cloud-lib.pl not found at $CLOUDPL"
        exit 1
    fi
    
    local action="${1:---install}"
    
    case "$action" in
        --install)
            log_info "Applying OpenVM GPL patches..."
            echo ""
            patch_check_licence
            patch_licence_status
            patch_cloud_lib
            patch_openvm_modules
            echo ""
            log_info "Restarting Webmin..."
            systemctl restart webmin 2>/dev/null || true
            sleep 2
            echo ""
            verify_patches
            echo ""
            log_ok "Done! Webmin status: $(systemctl is-active webmin 2>/dev/null || echo 'unknown')"
            ;;
        --uninstall)
            uninstall_patches
            systemctl restart webmin 2>/dev/null || true
            ;;
        --verify)
            verify_patches
            ;;
        *)
            echo "Usage: $0 [--install] [--uninstall] [--verify]"
            exit 1
            ;;
    esac
}

main "$@"

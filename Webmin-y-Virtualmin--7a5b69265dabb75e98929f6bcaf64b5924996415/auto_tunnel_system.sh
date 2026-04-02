#!/bin/bash
set -euo pipefail

echo "[SECURITY] auto_tunnel_system.sh has been disabled." >&2
echo "[SECURITY] Public/reverse tunnel automation is not allowed in this secure build." >&2
exit 1

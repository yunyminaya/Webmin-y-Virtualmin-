#!/bin/bash
set -euo pipefail

echo "[SECURITY] auto_ip_tunnel.sh has been disabled." >&2
echo "[SECURITY] Hard-coded remote tunnel hosts are not allowed in this secure build." >&2
exit 1

#!/usr/bin/env bash
set -Eeuo pipefail

# Escaneo local de secretos para Webmin/Virtualmin/OpenVM.
# No reemplaza una herramienta dedicada como gitleaks, pero bloquea patrones críticos comunes.

PATTERN='(Ymo[0-9]+|sshpass -p|BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|api[_-]?key[[:space:]]*=|token[[:space:]]*=|password[[:space:]]*=|contraseña|passwd[[:space:]]*=)'

grep -RInE \
  --exclude-dir=.git \
  --exclude-dir=node_modules \
  --exclude-dir=vendor \
  --exclude-dir=.venv \
  --exclude='*.png' \
  --exclude='*.jpg' \
  --exclude='*.jpeg' \
  --exclude='*.gif' \
  --exclude='*.webp' \
  "$PATTERN" . || true

#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INVENTORY_FILE="${PROJECT_ROOT}/cluster_infrastructure/ansible/inventory.ini"
REMOTE_PROJECT_DIR="${REMOTE_PROJECT_DIR:-/opt/virtualmin-pro}"
REMOTE_BRANCH="${REMOTE_BRANCH:-main}"
SSH_PORT="${SSH_PORT:-22}"
SSH_USER_OVERRIDE="${SSH_USER_OVERRIDE:-}"
SSH_OPTS_DEFAULT='-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
SSH_OPTS="${SSH_OPTS:-${SSH_OPTS_DEFAULT}}"
RUN_VALIDATE="${RUN_VALIDATE:-1}"
SYNC_RUNTIME="${SYNC_RUNTIME:-1}"
AUTO_YES="${AUTO_YES:-0}"

usage() {
    cat <<'EOF'
Uso:
  bash scripts/rollout_openvm_update.sh --hosts "host1 host2"
  bash scripts/rollout_openvm_update.sh --inventory cluster_infrastructure/ansible/inventory.ini

Opciones:
  --hosts "h1 h2"        Lista de hosts separados por espacios
  --inventory <ruta>     Inventario INI estilo Ansible
  --remote-dir <ruta>    Ruta remota del proyecto (default: /opt/virtualmin-pro)
  --branch <rama>        Rama git a desplegar (default: main)
  --user <usuario>       Usuario SSH remoto
  --port <puerto>        Puerto SSH (default: 22)
  --no-validate          No ejecutar validación post-update
  --no-sync-runtime      No resincronizar runtime del panel
  --yes                  Ejecutar sin confirmaciones interactivas
EOF
}

log() {
    printf '[rollout-openvm] %s\n' "$1"
}

fail() {
    printf '[rollout-openvm][ERROR] %s\n' "$1" >&2
    exit 1
}

confirm() {
    local prompt="$1"
    if [[ "$AUTO_YES" == "1" ]]; then
        log "$prompt -> yes (auto)"
        return 0
    fi
    read -r -p "$prompt [y/N]: " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

parse_inventory_hosts() {
    local inventory="$1"
    [[ -f "$inventory" ]] || fail "No existe inventario: $inventory"
    awk '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*$/ { next }
        /^\[/ { next }
        /ansible_/ { print $1; next }
        /^[A-Za-z0-9._-]+([[:space:]]+.*)?$/ { print $1 }
    ' "$inventory" | awk '!seen[$0]++'
}

build_remote_command() {
    local remote_dir="$1"
    local branch="$2"
    local cmd="set -euo pipefail; cd '$remote_dir'; git fetch origin; git checkout '$branch'; git pull origin '$branch';"

    if [[ "$SYNC_RUNTIME" == "1" ]]; then
        cmd+=" bash ./setup_pro_production.sh --sync-runtime;"
    fi

    if [[ "$RUN_VALIDATE" == "1" ]]; then
        cmd+=" bash ./setup_pro_production.sh --validate;"
    fi

    printf '%s\n' "$cmd"
}

rollout_host() {
    local host="$1"
    local ssh_user="$2"
    local remote_dir="$3"
    local branch="$4"
    local remote_cmd
    local ssh_target="$host"

    [[ -n "$ssh_user" ]] && ssh_target="${ssh_user}@${host}"
    remote_cmd="$(build_remote_command "$remote_dir" "$branch")"

    log "Actualizando ${ssh_target}:${remote_dir}"
    ssh -p "$SSH_PORT" ${SSH_OPTS} "$ssh_target" "$remote_cmd"
    log "Servidor actualizado correctamente: $ssh_target"
}

main() {
    local -a hosts=()
    local inventory="$INVENTORY_FILE"
    local remote_dir="$REMOTE_PROJECT_DIR"
    local branch="$REMOTE_BRANCH"
    local ssh_user="$SSH_USER_OVERRIDE"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --hosts)
                shift
                read -r -a hosts <<< "${1:-}"
                ;;
            --inventory)
                shift
                inventory="${1:-}"
                ;;
            --remote-dir)
                shift
                remote_dir="${1:-}"
                ;;
            --branch)
                shift
                branch="${1:-}"
                ;;
            --user)
                shift
                ssh_user="${1:-}"
                ;;
            --port)
                shift
                SSH_PORT="${1:-22}"
                ;;
            --no-validate)
                RUN_VALIDATE=0
                ;;
            --no-sync-runtime)
                SYNC_RUNTIME=0
                ;;
            --yes)
                AUTO_YES=1
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                fail "Opción no válida: $1"
                ;;
        esac
        shift || true
    done

    if [[ ${#hosts[@]} -eq 0 ]]; then
        mapfile -t hosts < <(parse_inventory_hosts "$inventory")
    fi

    [[ ${#hosts[@]} -gt 0 ]] || fail "No se encontraron hosts para actualizar"

    log "Hosts objetivo: ${hosts[*]}"
    log "Ruta remota: $remote_dir"
    log "Rama: $branch"
    log "Sync runtime: $SYNC_RUNTIME"
    log "Validate: $RUN_VALIDATE"

    confirm "¿Aplicar actualización centralizada en todos los hosts listados?" || {
        log "Despliegue cancelado"
        exit 0
    }

    local host
    for host in "${hosts[@]}"; do
        rollout_host "$host" "$ssh_user" "$remote_dir" "$branch"
    done

    log "Rollout completado en todos los servidores objetivo"
}

main "$@"

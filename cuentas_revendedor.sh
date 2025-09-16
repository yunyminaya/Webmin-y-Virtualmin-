#!/bin/bash

# =============================================================================
# CUENTAS DE REVENDEDOR (EMULADAS GPL) PARA VIRTUALMIN
# - Implementa cuentas tipo “revendedor” usando Virtualmin GPL (sin licencias)
# - Crea un dominio “paraguas” + admin extra con permisos y límites de creación
# - Opcionalmente actualiza límites/características y lista/elimina admins
# =============================================================================

set -euo pipefail

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/lib/common_functions.sh"
else
  echo "❌ Error: No se encontró lib/common_functions.sh" >&2
  exit 1
fi

init_logging "cuentas_revendedor"

# ===============================
# Utilidades
# ===============================

require_root() {
  check_root || show_error "Este comando requiere sudo/root" 2
}

require_virtualmin() {
  if ! command -v virtualmin >/dev/null 2>&1; then
    show_error "No se encontró el comando 'virtualmin'. Instala/ejecuta primero la instalación completa." 3
  fi
}

exists_domain() {
  local dom="$1"
  if virtualmin list-domains --name-only 2>/dev/null | grep -Fxq "$dom"; then
    return 0
  fi
  return 1
}

exists_admin_in_domain() {
  local dom="$1"; shift
  local admin="$1"
  if virtualmin list-admins --domain "$dom" --name-only 2>/dev/null | grep -Fxq "$admin"; then
    return 0
  fi
  return 1
}

# ===============================
# Crear revendedor (emulado GPL)
# ===============================

cmd_crear() {
  require_root
  require_virtualmin

  local usuario=""
  local pass=""
  local dominio_base=""
  local email=""
  local desc="Cuenta de revendedor"
  local max_doms="20"            # sub-servidores totales
  local max_realdoms="20"        # sub-servidores reales
  local max_mailboxes="200"
  local max_dbs="50"
  local max_aliases="200"
  local allow_features=(web dns mail webmin mysql postgres ssl logrotate)
  local edit_caps=(domain users aliases dbs scripts mail backup sched restore ssl phpver phpmode admins records spf redirect forward sharedips catchall allowedhosts passwd disable delete)

  while [[ ${1:-} ]]; do
    case "$1" in
      --usuario) usuario="$2"; shift 2;;
      --pass) pass="$2"; shift 2;;
      --dominio-base) dominio_base="$2"; shift 2;;
      --email) email="$2"; shift 2;;
      --desc) desc="$2"; shift 2;;
      --max-doms) max_doms="$2"; shift 2;;
      --max-realdoms) max_realdoms="$2"; shift 2;;
      --max-mailboxes) max_mailboxes="$2"; shift 2;;
      --max-dbs) max_dbs="$2"; shift 2;;
      --max-aliases) max_aliases="$2"; shift 2;;
      --allow) IFS=' ' read -r -a allow_features <<< "$2"; shift 2;;
      --caps|--capabilities) IFS=' ' read -r -a edit_caps <<< "$2"; shift 2;;
      --help) mostrar_ayuda_crear; return 0;;
      *) show_error "Parámetro desconocido: $1" 2;;
    esac
  done

  [[ -n "$usuario" && -n "$pass" && -n "$dominio_base" ]] || {
    mostrar_ayuda_crear
    show_error "Faltan parámetros obligatorios (--usuario, --pass, --dominio-base)" 2
  }

  log "HEADER" "CREACIÓN DE REVENDEDOR (EMULADO GPL)"
  log "INFO" "Usuario: $usuario | Dominio base: $dominio_base"

  # 1) Crear dominio paraguas si no existe
  if exists_domain "$dominio_base"; then
    log "SUCCESS" "Dominio base ya existe: $dominio_base"
  else
    log "INFO" "Creando dominio base $dominio_base"
    virtualmin create-domain \
      --domain "$dominio_base" \
      --pass "$pass" \
      --desc "$desc ($usuario)" \
      --unix --dir --webmin --web --dns --mail --default-features --limits-from-plan || {
        show_error "Fallo creando el dominio base $dominio_base" 10
      }
    log "SUCCESS" "Dominio base creado: $dominio_base"
  fi

  # 2) Crear admin extra con permisos de creación y módulos
  if exists_admin_in_domain "$dominio_base" "$usuario"; then
    log "WARNING" "El admin $usuario ya existe en $dominio_base; actualizando límites/capacidades"
  else
    log "INFO" "Creando administrador extra ($usuario)"
    virtualmin create-admin \
      --domain "$dominio_base" \
      --name "$usuario" \
      --pass "$pass" \
      --desc "$desc" \
      ${email:+--email "$email"} \
      --can-create --can-rename --can-features --can-modules || {
        show_error "Fallo creando el admin $usuario en $dominio_base" 11
      }
  fi

  # 3) Establecer límites del propietario (cuotas y capacidades)
  log "INFO" "Aplicando límites al propietario del dominio base"
  local ml_args=(
    --domain "$dominio_base"
    --max-doms "$max_doms"
    --max-realdoms "$max_realdoms"
    --max-mailboxes "$max_mailboxes"
    --max-dbs "$max_dbs"
    --max-aliases "$max_aliases"
  )
  # Permitir características
  for f in "${allow_features[@]}"; do
    ml_args+=( --allow "$f" )
  done
  # Habilitar capacidades de edición
  for c in "${edit_caps[@]}"; do
    ml_args+=( --can-edit "$c" )
  done
  virtualmin modify-limits "${ml_args[@]}" || {
    show_error "Fallo configurando límites/capacidades para $dominio_base" 12
  }
  log "SUCCESS" "Límites aplicados al propietario de $dominio_base"

  # 4) Resumen de acceso
  echo
  log "HEADER" "REVENDEDOR LISTO"
  log "INFO" "URL Webmin: https://$(hostname -I | awk '{print $1}'):10000"
  log "INFO" "Usuario: $usuario"
  log "INFO" "Dominio base (crear sub-servidores): $dominio_base"
  echo
}

mostrar_ayuda_crear() {
  cat <<'EOF'
Uso: cuentas_revendedor.sh crear --usuario USR --pass PASS --dominio-base DOM [opciones]

Opciones:
  --email EMAIL              Correo de contacto del revendedor
  --desc TEXTO               Descripción (por defecto: "Cuenta de revendedor")
  --max-doms N               Máximo sub-servidores totales (def: 20)
  --max-realdoms N           Máximo sub-servidores reales (def: 20)
  --max-mailboxes N|UNLIMITED Máximo buzones (def: 200)
  --max-dbs N|UNLIMITED      Máximo bases de datos (def: 50)
  --max-aliases N|UNLIMITED  Máximo alias de correo (def: 200)
  --allow "f1 f2 ..."        Lista de features a permitir (def: web dns mail webmin mysql postgres ssl logrotate)
  --caps  "c1 c2 ..."        Capacidades de edición (def: conjunto amplio compatible GPL)

Notas:
  - Esta implementación emula revendedores en Virtualmin GPL: el usuario administra
    y crea sub-servidores bajo un dominio base (paraguas). Para “resellers” reales
    (crear top-level en todo el sistema) se requiere Virtualmin Professional.
EOF
}

# ===============================
# Listar / Eliminar / Limitar
# ===============================

cmd_listar() {
  require_root; require_virtualmin
  local dominio_base=""
  while [[ ${1:-} ]]; do
    case "$1" in
      --dominio-base) dominio_base="$2"; shift 2;;
      --help) cat <<'EOF'; return 0;;
Uso: cuentas_revendedor.sh listar --dominio-base DOM
  Muestra los administradores extra (revendedor y otros) del dominio paraguas.
EOF
      *) show_error "Parámetro desconocido: $1" 2;;
    esac
  done
  [[ -n "$dominio_base" ]] || show_error "Falta --dominio-base" 2
  virtualmin list-admins --domain "$dominio_base" || true
}

cmd_eliminar() {
  require_root; require_virtualmin
  local dominio_base="" usuario=""
  while [[ ${1:-} ]]; do
    case "$1" in
      --dominio-base) dominio_base="$2"; shift 2;;
      --usuario) usuario="$2"; shift 2;;
      --help) cat <<'EOF'; return 0;;
Uso: cuentas_revendedor.sh eliminar --dominio-base DOM --usuario USR
  Elimina el administrador extra USR del dominio paraguas DOM.
EOF
      *) show_error "Parámetro desconocido: $1" 2;;
    esac
  done
  [[ -n "$dominio_base" && -n "$usuario" ]] || show_error "Faltan --dominio-base y/o --usuario" 2
  virtualmin delete-admin --domain "$dominio_base" --name "$usuario"
  log "SUCCESS" "Admin $usuario eliminado del dominio $dominio_base"
}

cmd_limites() {
  require_root; require_virtualmin
  local dominio_base=""
  local args=( )
  while [[ ${1:-} ]]; do
    case "$1" in
      --dominio-base) dominio_base="$2"; shift 2;;
      --max-doms|--max-realdoms|--max-mailboxes|--max-dbs|--max-aliases)
        args+=( "$1" "$2" ); shift 2;;
      --allow|--disallow)
        args+=( "$1" "$2" ); shift 2;;
      --can-edit|--cannot-edit)
        args+=( "$1" "$2" ); shift 2;;
      --help) cat <<'EOF'; return 0;;
Uso: cuentas_revendedor.sh limites --dominio-base DOM [opciones]
  Actualiza límites/capacidades del propietario del dominio paraguas.

Opciones:
  --max-doms N | --max-realdoms N | --max-mailboxes N|UNLIMITED
  --max-dbs N | --max-aliases N
  --allow "feat" | --disallow "feat"
  --can-edit cap | --cannot-edit cap
EOF
      *) show_error "Parámetro desconocido: $1" 2;;
    esac
  done
  [[ -n "$dominio_base" ]] || show_error "Falta --dominio-base" 2
  [[ ${#args[@]} -gt 0 ]] || show_error "No se especificaron cambios de límites" 2
  virtualmin modify-limits --domain "$dominio_base" "${args[@]}"
  log "SUCCESS" "Límites actualizados en $dominio_base"
}

cmd_ayuda() {
  cat <<'EOF'
Uso general: cuentas_revendedor.sh <comando> [opciones]

Comandos:
  crear    Crea una cuenta de revendedor (emulada GPL)
  listar   Lista administradores extra del dominio base
  eliminar Elimina un admin extra del dominio base
  limites  Ajusta límites/capacidades del propietario del dominio base

Ejemplos:
  cuentas_revendedor.sh crear \
    --usuario acme --pass 'Secreto123' \
    --dominio-base acme-panel.example.com \
    --email soporte@acme.com --max-doms 50 --max-dbs 100

  cuentas_revendedor.sh listar --dominio-base acme-panel.example.com

  cuentas_revendedor.sh limites --dominio-base acme-panel.example.com \
    --max-doms 100 --can-edit backup --allow web
EOF
}

# ===============================
# Dispatch principal
# ===============================

subcmd="${1:-ayuda}"; shift || true
case "$subcmd" in
  crear)   cmd_crear "$@" ;;
  listar)  cmd_listar "$@" ;;
  eliminar)cmd_eliminar "$@" ;;
  limites) cmd_limites "$@" ;;
  ayuda|-h|--help) cmd_ayuda ;;
  *) log "ERROR" "Comando desconocido: $subcmd"; cmd_ayuda; exit 1;;
esac

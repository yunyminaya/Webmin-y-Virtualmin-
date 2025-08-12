#!/bin/bash
# Verificación Total Automatizada (Webmin/Virtualmin)
# - Ejecuta verificación profunda y orquestador PRO
# - Falla (exit != 0) si cualquier verificación detecta errores
# Uso:
#   sudo bash verificacion_total_automatizada.sh
#   sudo bash verificacion_total_automatizada.sh --auto-fetch   # descarga scripts si faltan

set -Eeuo pipefail
IFS=$'\n\t'

# Colores / Log
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; NC='\033[0m'
log(){ local L="$1"; shift; case "$L" in
  INFO) echo -e "${BLUE}[INFO]${NC} $*";;
  OK)   echo -e "${GREEN}[OK]${NC} $*";;
  WARN) echo -e "${YELLOW}[WARN]${NC} $*";;
  ERR)  echo -e "${RED}[ERR]${NC} $*";;
  HDR)  echo -e "\n${PURPLE}=== $* ===${NC}";;
esac; }

require_root(){
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log ERR "Se requieren privilegios de root. Usa: sudo $0"
    exit 1
  fi
}

have_cmd(){ command -v "$1" >/dev/null 2>&1; }

RAW_URL="https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/master"
AUTO_FETCH=0
for a in "$@"; do
  case "$a" in
    --auto-fetch) AUTO_FETCH=1 ;;
  esac
done

fetch_if_missing(){
  local local_path="$1"; local remote_name="$2"
  if [[ -f "$local_path" ]]; then
    chmod +x "$local_path" || true
    return 0
  fi
  if [[ "$AUTO_FETCH" -eq 1 ]]; then
    log INFO "Descargando ${remote_name} ..."
    curl -fsSL "${RAW_URL}/${remote_name}" -o "$local_path"
    chmod +x "$local_path" || true
  else
    log WARN "Falta ${local_path}. Ejecute con --auto-fetch para descargar automáticamente."
  fi
}

last_report(){
  ls -t $1 2>/dev/null | head -1 || true
}

main(){
  require_root
  mkdir -p reportes 2>/dev/null || true

  # Asegurar presencia de scripts
  fetch_if_missing "./verificacion_profunda_paneles.sh" "verificacion_profunda_paneles.sh"
  fetch_if_missing "./orquestador_verificacion_pro.sh" "orquestador_verificacion_pro.sh"

  if [[ ! -x ./verificacion_profunda_paneles.sh || ! -x ./orquestador_verificacion_pro.sh ]]; then
    log ERR "No se encontraron los scripts necesarios. Ejecute con --auto-fetch o colóquelos en el directorio actual."
    exit 2
  fi

  log HDR "EJECUTANDO VERIFICACIÓN PROFUNDA"
  set +e
  ./verificacion_profunda_paneles.sh
  rc1=$?
  RP1="$(last_report 'reportes/reporte_profundo_paneles_*.md')"

  log HDR "EJECUTANDO ORQUESTADOR PRO"
  ./orquestador_verificacion_pro.sh
  rc2=$?
  RP2="$(last_report 'reportes/reporte_verificacion_pro_*.md')"
  set -e

  log HDR "RESUMEN"
  [[ -n "$RP1" ]] && log OK "Reporte profundo: $RP1" || log WARN "Reporte profundo no localizado"
  [[ -n "$RP2" ]] && log OK "Reporte orquestador: $RP2" || log WARN "Reporte orquestador no localizado"

  if [[ $rc1 -eq 0 && $rc2 -eq 0 ]]; then
    log OK "Todas las verificaciones finalizaron SIN ERRORES"
    exit 0
  else
    log ERR "Se detectaron errores (rc profundo=$rc1, rc orquestador=$rc2). Revise los reportes."
    exit 1
  fi
}

main "$@"

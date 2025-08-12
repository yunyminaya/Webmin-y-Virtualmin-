#!/usr/bin/env bash
# Eliminación SEGURA de duplicados en el repo para Webmin/Virtualmin (compatible con bash 3.x)
# Uso:
#   bash limpiar_duplicados_seguro.sh                 # Solo reporte (dry-run)
#   bash limpiar_duplicados_seguro.sh --apply         # Elimina duplicados (mantiene 1 copia)
#   bash limpiar_duplicados_seguro.sh --quarantine    # Mueve duplicados a cuarentena en vez de borrar
#   bash limpiar_duplicados_seguro.sh --include-vendor# Incluye vendor (NO recomendado)
#
# Reglas:
# - Mantener la PRIMERA mejor copia por grupo de hash (ruta más corta; si empata, mtime más antiguo)
# - EXCLUYE por defecto: authentic-theme-master/, virtualmin-gpl-master/, reportes/, .git/
# - No requiere sudo. No usa arreglos asociativos (portátil en macOS bash 3.2)

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log(){ local L="$1"; shift; echo -e "${L}[$(date '+%F %T')] $*${NC}"; }
ok(){ log "${GREEN}" "$*"; }
info(){ log "${BLUE}" "$*"; }
warn(){ log "${YELLOW}" "$*"; }
err(){ log "${RED}" "$*"; }

APPLY="false"
QUARANTINE="false"
INCLUDE_VENDOR="false"

for a in "${@:-}"; do
  case "$a" in
    --apply) APPLY="true" ;;
    --quarantine) QUARANTINE="true"; APPLY="true" ;;
    --include-vendor) INCLUDE_VENDOR="true" ;;
    *) warn "Opción desconocida: $a" ;;
  esac
done

# Exclusiones por defecto (para no romper vendor)
EXCLUDE_DIRS=(
  "./.git"
  "./reportes"
  "./authentic-theme-master"
  "./virtualmin-gpl-master"
)

is_excluded() {
  local f="$1"
  if [[ "$INCLUDE_VENDOR" == "true" ]]; then
    # Solo respeta .git y reportes
    for d in "./.git" "./reportes"; do
      [[ "$f" == "$d"* ]] && return 0
    done
    return 1
  else
    local d
    for d in "${EXCLUDE_DIRS[@]}"; do
      [[ "$f" == "$d"* ]] && return 0
    done
    return 1
  fi
}

# Portabilidad mínima para stat size/mtime
get_size() {
  local f="$1"
  if stat -c %s "$f" >/dev/null 2>&1; then
    stat -c %s "$f"
  else
    stat -f %z "$f"
  fi
}
get_mtime() {
  local f="$1"
  if stat -c %Y "$f" >/dev/null 2>&1; then
    stat -c %Y "$f"
  else
    stat -f %m "$f"
  fi
}
get_hash() {
  local f="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  else
    # Fallback a md5 si no hay SHA-256 (menos ideal, pero funcional para deduplicación local)
    if command -v md5 >/dev/null 2>&1; then
      md5 -q "$f"
    else
      err "No se encontró shasum/sha256sum/md5 para calcular hash"
      exit 2
    fi
  fi
}

TS="$(date +%Y%m%d_%H%M%S)"
mkdir -p reportes 2>/dev/null || true
REPORT="reportes/duplicados_reporte_${TS}.md"
APPLY_SCRIPT="reportes/aplicar_borrado_duplicados_${TS}.sh"
QUAR_DIR="reportes/cuarentena_duplicados_${TS}"
CANDIDATES="$(mktemp -t dupcand.XXXXXX)"
SORTED="$(mktemp -t dupsort.XXXXXX)"
GROUPS_TMP="$(mktemp -t dupgrp.XXXXXX)"

# Tipos a revisar (código y configuraciones)
MAP_EXT=(
  "*.sh" "*.conf" "*.cfg" "*.pl" "*.pm" "*.cgi" "*.service" "*.inc" "*.template"
  "*.txt" "*.md"
)

# Limitar tamaño (5MB) para evitar binarios pesados
MAX_BYTES=$((5*1024*1024))

echo "# 🧹 Reporte de Duplicados (seguro) - ${TS}" > "$REPORT"
echo "" >> "$REPORT"
echo "#!/usr/bin/env bash" > "$APPLY_SCRIPT"
echo "set -euo pipefail" >> "$APPLY_SCRIPT"
echo >> "$APPLY_SCRIPT"

collect_files() {
  info "Recolectando candidatos..."
  local cmd=(find . -type f \( )
  local i
  for i in "${!MAP_EXT[@]}"; do
    if [[ $i -gt 0 ]]; then cmd+=(-o); fi
    cmd+=(-name "${MAP_EXT[$i]}")
  done
  cmd+=( \) -print0 )

  "${cmd[@]}" | while IFS= read -r -d '' f; do
    [[ -f "$f" ]] || continue
    if is_excluded "$f"; then
      continue
    fi
    local sz; sz="$(get_size "$f" 2>/dev/null || echo 0)"
    if [[ "$sz" -gt "$MAX_BYTES" ]]; then
      continue
    fi
    local h; h="$(get_hash "$f")"
    local m; m="$(get_mtime "$f" 2>/dev/null || echo 0)"
    # hash \t mtime \t path
    printf "%s\t%s\t%s\n" "$h" "$m" "$f" >> "$CANDIDATES"
  done
}

process_groups() {
  sort -t $'\t' -k1,1 "$CANDIDATES" > "$SORTED" || true

  # AWK: agrupa por hash, elige keeper por (len(path) asc, mtime asc), emite líneas: HASH\t<hash>, KEEP\t<path>, DUP\t<path>
  awk -F $'\t' '
  function flush_group(    i,best,bestlen,bestm) {
    if (cnt <= 1) { cnt=0; return }
    best=1; bestlen=length(p[1]); bestm=m[1]
    for (i=2; i<=cnt; i++) {
      if (length(p[i]) < bestlen || (length(p[i])==bestlen && m[i] < bestm)) { best=i; bestlen=length(p[i]); bestm=m[i] }
    }
    print "HASH\t" prev
    print "KEEP\t" p[best]
    for (i=1; i<=cnt; i++) {
      if (i!=best) print "DUP\t" p[i]
    }
    cnt=0
  }
  {
    if (NR==1) { prev=$1; cnt=0 }
    if ($1!=prev) { flush_group(); prev=$1 }
    cnt++; h[cnt]=$1; m[cnt]=$2; p[cnt]=$3
  }
  END { flush_group() }
  ' "$SORTED" > "$GROUPS_TMP" || true
}

write_report_and_actions() {
  local sets=0
  local current_hash=""
  while IFS=$'\t' read -r tag value; do
    case "$tag" in
      HASH)
        sets=$((sets+1))
        current_hash="$value"
        {
          echo ""
          echo "## Hash: \`$current_hash\`"
        } >> "$REPORT"
        ;;
      KEEP)
        echo "- Mantener: \`$value\`" >> "$REPORT"
        ;;
      DUP)
        echo "  - Duplicado: \`$value\`" >> "$REPORT"
        if [[ "$APPLY" == "true" ]]; then
          if [[ "$QUARANTINE" == "true" ]]; then
            echo "mkdir -p \"$QUAR_DIR\"" >> "$APPLY_SCRIPT"
            rel="${value#./}"
            echo "mkdir -p \"${QUAR_DIR}/\$(dirname \"$rel\")\"" >> "$APPLY_SCRIPT"
            echo "mv -f -- \"$value\" \"${QUAR_DIR}/$rel\"" >> "$APPLY_SCRIPT"
          else
            echo "rm -f -- \"$value\"" >> "$APPLY_SCRIPT"
          fi
        fi
        ;;
    esac
  done < "$GROUPS_TMP"

  {
    echo ""
    echo "# Resumen"
    echo "- Conjuntos de duplicados: ${sets}"
    if [[ "$APPLY" == "true" ]]; then
      if [[ "$QUARANTINE" == "true" ]]; then
        echo "- Modo: Aplicar (cuarentena)"
      else
        echo "- Modo: Aplicar (borrado)"
      fi
    else
      echo "- Modo: Dry-run (sin cambios)"
    fi
    echo ""
  } >> "$REPORT"

  if [[ "$APPLY" == "true" ]]; then
    chmod +x "$APPLY_SCRIPT" || true
    ok "Acciones preparadas en: $APPLY_SCRIPT"
    info "Para ejecutar ahora mismo:"
    echo "  bash \"$APPLY_SCRIPT\""
    {
      echo "### Script de aplicación"
      echo ""
      echo "Archivo generado: \`$APPLY_SCRIPT\`"
      echo ""
      echo "Ejecute:"
      echo ""
      echo "\`\`\`bash"
      echo "bash \"$APPLY_SCRIPT\""
      echo "\`\`\`"
    } >> "$REPORT"
  else
    {
      echo "### Modo dry-run"
      echo ""
      echo "No se aplicaron cambios. Para eliminar duplicados ejecute:"
      echo ""
      echo "\`\`\`bash"
      echo "bash limpiar_duplicados_seguro.sh --apply"
      echo "\`\`\`"
      echo ""
      echo "Para cuarentena en lugar de borrado:"
      echo ""
      echo "\`\`\`bash"
      echo "bash limpiar_duplicados_seguro.sh --quarantine"
      echo "\`\`\`"
    } >> "$REPORT"
  fi
}

cleanup() {
  rm -f "$CANDIDATES" "$SORTED" "$GROUPS_TMP" 2>/dev/null || true
}

main() {
  info "Analizando duplicados (excluyendo vendor por defecto)..."
  collect_files
  process_groups
  write_report_and_actions
  cleanup
  ok "Reporte generado: $REPORT"
}

main "$@"

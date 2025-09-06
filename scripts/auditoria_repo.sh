#!/usr/bin/env bash
# Auditoría estática de scripts del repositorio (portátil para macOS/Linux)
set -euo pipefail
IFS=$'\n\t'

ts="$(date +%Y%m%d_%H%M%S)"
default_out="reportes/revision_codigo_${ts}.md"
out="${OUT_FILE:-$default_out}"
mkdir -p reportes

# Helpers de salida (formato markdown compatible con markdownlint)
append() { printf "%s\n" "$*" >> "$out"; }
# Asegurar línea en blanco antes y después de bloques de código y especificar lenguaje
code_start() { printf '\n```text\n' >> "$out"; }
code_end() { printf '```\n\n' >> "$out"; }

# Encabezado
: > "$out"
append "# Revisión completa del código"
append ""
append "Fecha: $(date)"
append ""

# Resumen
total="$(find . -type f -name "*.sh" | wc -l | tr -d ' ')"
append "## Resumen"
append ""
append "- Scripts .sh: ${total}"
append ""

# Scripts sin shebang
append "## Scripts sin shebang (línea 1)"
append ""
code_start
while IFS= read -r -d '' f; do
  first="$(head -n1 "$f" 2>/dev/null || true)"
  if [[ "${first:-}" != \#\!* ]]; then
    printf "%s\n" "$f" >> "$out"
  fi
done < <(find . -type f -name "*.sh" -print0)
code_end
append ""

# Scripts sin modo estricto
append "## Scripts sin modo estricto (set -euo pipefail)"
append ""
code_start
while IFS= read -r -d '' f; do
  if ! grep -Eq 'set[[:space:]]+-E?euo[[:space:]]+pipefail' "$f"; then
    printf "%s\n" "$f" >> "$out"
  fi
done < <(find . -type f -name "*.sh" -print0)
code_end
append ""

# Errores de sintaxis (bash -n)
append "## Errores de sintaxis (bash -n)"
append ""
code_start
while IFS= read -r -d '' f; do
  if ! bash -n "$f" 2>/dev/null; then
    printf "%s\n" "$f" >> "$out"
  fi
done < <(find . -type f -name "*.sh" -print0)
code_end
append ""

# Uso de sudo
append "## Uso de sudo dentro de scripts"
append ""
code_start
find . -type f -name "*.sh" -exec grep -nH -E '(^|[^[:alnum:]_])sudo([[:space:]]|$)' {} + >> "$out" 2>/dev/null || true
code_end
append ""

# Uso de eval
append "## Uso de eval"
append ""
code_start
find . -type f -name "*.sh" -exec grep -nH -E '(^|[^[:alnum:]_])eval([[:space:]]|\()' {} + >> "$out" 2>/dev/null || true
code_end
append ""

# Uso de rm -rf
append "## Uso de rm -rf"
append ""
code_start
find . -type f -name "*.sh" -exec grep -nH -E '(^|[^[:alnum:]_])rm[[:space:]]+-rf([[:space:]]|$)' {} + >> "$out" 2>/dev/null || true
code_end
append ""

# Uso de systemctl
append "## Uso de systemctl"
append ""
code_start
find . -type f -name "*.sh" -exec grep -nH -E '(^|[^[:alnum:]_])systemctl([[:space:]]|$)' {} + >> "$out" 2>/dev/null || true
code_end
append ""

# Recomendaciones
append "## Recomendaciones rápidas"
append ""
append "- Añadir set -euo pipefail e IFS seguro en scripts listados arriba."
append "- Agregar require_root cuando se escriba en /etc, /var o se use systemctl."
append "- Evitar sudo dentro de scripts que ya requieren root."
append "- Revisar usos de eval y rm -rf."

# Ruta del reporte
printf "%s\n" "$out"

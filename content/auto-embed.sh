#!/usr/bin/env bash
# auto-embed.sh
# Para cada archivo maestro (dif.md, myc.md, etc.), busca todos los .md
# cuyo nombre empiece con ese código + al menos un carácter más,
# y reescribe la sección de embeds en el maestro.

set -euo pipefail

VAULT="${1:-$HOME/my-notes}"
CODIGOS=("dif" "myc" "fdg" "pye" "fex")

MARKER_START="<!-- auto-embed:start -->"
MARKER_END="<!-- auto-embed:end -->"

for CODIGO in "${CODIGOS[@]}"; do
  MAESTRO="$VAULT/${CODIGO}.md"

  # Si el maestro no existe, créalo vacío
  if [[ ! -f "$MAESTRO" ]]; then
    echo "# ${CODIGO}" > "$MAESTRO"
    echo "" >> "$MAESTRO"
    echo "$MARKER_START" >> "$MAESTRO"
    echo "$MARKER_END" >> "$MAESTRO"
    echo "[auto-embed] Creado maestro: ${CODIGO}.md"
  fi

  # Buscar hijos: archivos que empiecen con el código + algo más
  mapfile -t HIJOS < <(
    find "$VAULT" -maxdepth 1 -name "${CODIGO}?*.md" -not -name "${CODIGO}.md" \
      | sort \
      | xargs -I{} basename {} .md
  )

  # Construir bloque de embeds
  BLOQUE=""
  for HIJO in "${HIJOS[@]}"; do
    BLOQUE+="[[${HIJO}]]"$'\n\n'
  done
  BLOQUE="${BLOQUE%$'\n\n'}"  # quitar último salto doble

  # Reemplazar la sección entre markers en el maestro
  # Usamos python3 para manipulación segura de texto multilínea
  python3 - "$MAESTRO" "$MARKER_START" "$MARKER_END" "$BLOQUE" << 'PYEOF'
import sys

path, start_marker, end_marker, bloque = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

with open(path, "r", encoding="utf-8") as f:
    contenido = f.read()

# Si no existen los markers, agregarlos al final
if start_marker not in contenido:
    contenido = contenido.rstrip("\n") + "\n\n" + start_marker + "\n" + end_marker + "\n"

# Reemplazar entre markers
antes  = contenido.split(start_marker)[0]
despues = contenido.split(end_marker)[1]

nuevo = antes + start_marker + "\n"
if bloque.strip():
    nuevo += "\n" + bloque + "\n\n"
nuevo += end_marker + despues

with open(path, "w", encoding="utf-8") as f:
    f.write(nuevo)
PYEOF

  echo "[auto-embed] ${CODIGO}.md → ${#HIJOS[@]} hijo(s) embebido(s): ${HIJOS[*]:-ninguno}"
done

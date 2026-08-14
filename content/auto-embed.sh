#!/usr/bin/env bash
# auto-embed.sh
# Para cada maestro (dif.md, myc.md, etc.), agrega wikilinks [[hijo]]
# solo si no están ya presentes. Detección case-insensitive.

set -euo pipefail

VAULT="${1:-$HOME/my-notes}"
CODIGOS=("dif" "myc" "fdg" "pye" "fex")

for CODIGO in "${CODIGOS[@]}"; do
  MAESTRO="$VAULT/${CODIGO}.md"

  # Si el maestro no existe, créalo
  if [[ ! -f "$MAESTRO" ]]; then
    echo "# ${CODIGO}" > "$MAESTRO"
    echo "[auto-embed] Creado maestro: ${CODIGO}.md"
  fi

  # Leer contenido del maestro en minúsculas para comparar
  CONTENIDO_LOWER=$(tr '[:upper:]' '[:lower:]' < "$MAESTRO")

  # Buscar hijos: archivos que empiecen con el código + algo más
  mapfile -t HIJOS < <(
    find "$VAULT" -maxdepth 1 -name "${CODIGO}?*.md" -not -name "${CODIGO}.md" \
      | sort \
      | xargs -I{} basename {} .md
  )

  AGREGADOS=0
  for HIJO in "${HIJOS[@]}"; do
    HIJO_LOWER=$(echo "$HIJO" | tr '[:upper:]' '[:lower:]')
    # Solo agregar si el wikilink no existe ya (case-insensitive)
    if ! echo "$CONTENIDO_LOWER" | grep -qF "[[${HIJO_LOWER}]]"; then
      echo "" >> "$MAESTRO"
      echo "[[${HIJO}]]" >> "$MAESTRO"
      (( AGREGADOS++ ))
    fi
  done

  echo "[auto-embed] ${CODIGO}.md → ${#HIJOS[@]} hijo(s) total, ${AGREGADOS} nuevo(s) agregado(s)"
done

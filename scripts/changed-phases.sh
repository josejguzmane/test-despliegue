#!/usr/bin/env bash
# =============================================================================
# Imprime, como array JSON, las fases afectadas por los cambios respecto a BASE.
#
#   ./scripts/changed-phases.sh origin/main
#
# Regla: si cambia algo compartido (modulos, tfvars de entorno, politicas,
# workflows) se planifican TODAS las fases, porque cualquiera puede verse
# afectada. Si solo cambian archivos dentro de una fase, se planifica esa.
# El orden de salida siempre respeta el orden numerico de las fases.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="${1:-origin/main}"

all_phases() {
  find "$ROOT/infra/phases" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
}

to_json() {
  local first=1
  printf '['
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    [[ $first -eq 0 ]] && printf ','
    printf '"%s"' "$p"
    first=0
  done
  printf ']'
}

if ! git rev-parse --verify "$BASE" >/dev/null 2>&1; then
  echo "base '$BASE' no encontrada; se planifican todas las fases" >&2
  all_phases | to_json
  exit 0
fi

changed="$(git diff --name-only "$BASE"...HEAD 2>/dev/null || git diff --name-only "$BASE")"

if [[ -z "$changed" ]]; then
  printf '[]'
  exit 0
fi

if grep -qE '^(infra/modules/|infra/envs/|infra/shared/|policy/|scripts/|\.github/(workflows|actions)/)' <<<"$changed"; then
  echo "cambio compartido detectado: se planifican todas las fases" >&2
  all_phases | to_json
  exit 0
fi

grep -oE '^infra/phases/[^/]+' <<<"$changed" \
  | cut -d/ -f3 \
  | sort -u \
  | to_json

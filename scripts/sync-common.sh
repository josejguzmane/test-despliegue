#!/usr/bin/env bash
# Copia infra/shared/variables.common.tf a cada fase.
# Con --check no escribe: solo verifica y falla si hay deriva (uso en CI).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/infra/shared/variables.common.tf"
CHECK=0
[[ "${1:-}" == "--check" ]] && CHECK=1

rc=0
for phase_dir in "$ROOT"/infra/phases/*/; do
  dst="$phase_dir/variables.common.tf"
  if [[ $CHECK -eq 1 ]]; then
    if ! diff -q "$SRC" "$dst" >/dev/null 2>&1; then
      echo "::error file=${dst#"$ROOT/"}::desincronizado con infra/shared/variables.common.tf (corre 'make sync-common')"
      rc=1
    fi
  else
    cp "$SRC" "$dst"
    echo "sync -> ${dst#"$ROOT/"}"
  fi
done
exit $rc

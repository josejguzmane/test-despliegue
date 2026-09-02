#!/usr/bin/env bash
# Busca definiciones built-in de Azure Policy por texto en el display name.
# Uso: ./scripts/find-policy.sh "public ip"
set -euo pipefail
[[ $# -ge 1 ]] || { echo "uso: $0 <texto>" >&2; exit 2; }
az policy definition list \
  --query "[?policyType=='BuiltIn' && contains(to_string(displayName), '$1')].{displayName:displayName, name:name, mode:mode}" \
  -o table

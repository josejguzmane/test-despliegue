#!/usr/bin/env bash
# =============================================================================
# Envoltorio local de Terraform por fase y entorno. Hace exactamente lo mismo
# que el workflow de CI, para que "en mi maquina" y "en el pipeline" no diverjan.
#
#   ./scripts/tf.sh 10-network-hub dev plan
#   ./scripts/tf.sh 10-network-hub dev apply
#   ./scripts/tf.sh 30-data prod output -json
#
# Requiere estas variables de entorno (o un archivo .env en la raiz):
#   ARM_SUBSCRIPTION_ID, TFSTATE_RESOURCE_GROUP, TFSTATE_STORAGE_ACCOUNT,
#   TFSTATE_CONTAINER
# La autenticacion se toma de 'az login'.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/.env" ]] && { set -a; . "$ROOT/.env"; set +a; }

PHASE="${1:-}"; ENV="${2:-}"; shift 2 || true
CMD=("$@")

if [[ -z "$PHASE" || -z "$ENV" || ${#CMD[@]} -eq 0 ]]; then
  echo "uso: $0 <fase> <dev|qa|prod> <comando de terraform...>" >&2
  echo "fases disponibles:" >&2
  ls -1 "$ROOT/infra/phases" | sed 's/^/  /' >&2
  exit 2
fi

PHASE_DIR="$ROOT/infra/phases/$PHASE"
[[ -d "$PHASE_DIR" ]] || { echo "fase desconocida: $PHASE" >&2; exit 2; }

for v in ARM_SUBSCRIPTION_ID TFSTATE_RESOURCE_GROUP TFSTATE_STORAGE_ACCOUNT TFSTATE_CONTAINER; do
  [[ -n "${!v:-}" ]] || { echo "falta la variable de entorno $v" >&2; exit 2; }
done

# Las tres tfstate_* llegan como variables de Terraform porque los data sources
# terraform_remote_state las necesitan, no solo el backend.
export TF_VAR_tfstate_resource_group_name="$TFSTATE_RESOURCE_GROUP"
export TF_VAR_tfstate_storage_account_name="$TFSTATE_STORAGE_ACCOUNT"
export TF_VAR_tfstate_container_name="$TFSTATE_CONTAINER"
export ARM_STORAGE_USE_AZUREAD=true

VAR_FILES=(-var-file="$ROOT/infra/envs/$ENV.tfvars")
[[ -f "$PHASE_DIR/tfvars/$ENV.tfvars" ]] && VAR_FILES+=(-var-file="$PHASE_DIR/tfvars/$ENV.tfvars")

cd "$PHASE_DIR"

if [[ ! -d .terraform ]] || [[ "${TF_REINIT:-0}" == "1" ]]; then
  terraform init -input=false -reconfigure \
    -backend-config="resource_group_name=$TFSTATE_RESOURCE_GROUP" \
    -backend-config="storage_account_name=$TFSTATE_STORAGE_ACCOUNT" \
    -backend-config="container_name=$TFSTATE_CONTAINER" \
    -backend-config="key=$PHASE/$ENV.tfstate" \
    -backend-config="subscription_id=$ARM_SUBSCRIPTION_ID" \
    -backend-config="use_azuread_auth=true"
fi

case "${CMD[0]}" in
  plan|apply|destroy|refresh|import)
    exec terraform "${CMD[@]}" "${VAR_FILES[@]}"
    ;;
  *)
    # output, show, state, providers, fmt, validate... no aceptan -var-file
    exec terraform "${CMD[@]}"
    ;;
esac

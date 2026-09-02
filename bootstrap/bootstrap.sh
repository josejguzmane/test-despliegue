#!/usr/bin/env bash
# =============================================================================
# Bootstrap del despliegue. Equivalente de bootstrap.ps1 para Linux/macOS y
# Azure Cloud Shell. Idempotente.
#
#   ./bootstrap/bootstrap.sh -s <subscription-id> -r <owner/repo> [-p itsm] [-l eastus2]
# =============================================================================
set -euo pipefail

PREFIX="itsm"
LOCATION="eastus2"
ENVIRONMENTS=("dev" "prod")
SUBSCRIPTION_ID=""
GITHUB_REPO=""
DRY_RUN=0

usage() { sed -n '2,10p' "$0"; exit 2; }

while getopts ":s:r:p:l:nh" opt; do
  case $opt in
    s) SUBSCRIPTION_ID="$OPTARG" ;;
    r) GITHUB_REPO="$OPTARG" ;;
    p) PREFIX="$OPTARG" ;;
    l) LOCATION="$OPTARG" ;;
    n) DRY_RUN=1 ;;
    *) usage ;;
  esac
done

[[ -n "$SUBSCRIPTION_ID" && -n "$GITHUB_REPO" ]] || usage
[[ "$GITHUB_REPO" =~ ^[^/]+/[^/]+$ ]] || { echo "GitHubRepo debe ser owner/repo" >&2; exit 2; }
command -v az >/dev/null || { echo "Azure CLI no encontrado." >&2; exit 1; }

step() { printf '\n==> %s\n' "$1"; }
info() { printf '    %s\n' "$1"; }
ok()   { printf '    OK  %s\n' "$1"; }
run()  { if [[ $DRY_RUN -eq 1 ]]; then info "[dry-run] $*"; else "$@" >/dev/null; fi; }

step "Verificando sesion de Azure"
az account show >/dev/null 2>&1 || { echo "Corre 'az login' primero." >&2; exit 1; }
az account set --subscription "$SUBSCRIPTION_ID"
TENANT_ID="$(az account show --query tenantId -o tsv)"
ok "suscripcion $SUBSCRIPTION_ID / tenant $TENANT_ID"

step "Registrando resource providers"
PROVIDERS=(Microsoft.Storage Microsoft.Network Microsoft.ContainerService
  Microsoft.ContainerRegistry Microsoft.KeyVault Microsoft.DBforPostgreSQL
  Microsoft.Cache Microsoft.ServiceBus Microsoft.Search Microsoft.OperationalInsights
  Microsoft.Insights Microsoft.Monitor Microsoft.Dashboard Microsoft.Cdn
  Microsoft.ApiManagement Microsoft.Security Microsoft.SecurityInsights
  Microsoft.PolicyInsights Microsoft.ManagedIdentity Microsoft.Relay
  Microsoft.EventGrid Microsoft.Authorization Microsoft.Resources)
for rp in "${PROVIDERS[@]}"; do
  state="$(az provider show --namespace "$rp" --query registrationState -o tsv 2>/dev/null || echo NotFound)"
  if [[ "$state" != "Registered" ]]; then
    info "registrando $rp ($state)"
    run az provider register --namespace "$rp" --wait
  fi
done
ok "${#PROVIDERS[@]} providers verificados"

step "Creando backend de Terraform state"
STATE_RG="rg-${PREFIX}-tfstate-${LOCATION}"
SUFFIX="$(printf '%s|%s' "$SUBSCRIPTION_ID" "$GITHUB_REPO" | sha256sum | cut -c1-8)"
STATE_SA="st${PREFIX}tfstate${SUFFIX}"
STATE_CONTAINER="tfstate"
[[ ${#STATE_SA} -le 24 ]] || { echo "Nombre de storage account muy largo: $STATE_SA" >&2; exit 1; }
info "rg=$STATE_RG sa=$STATE_SA container=$STATE_CONTAINER"

run az group create --name "$STATE_RG" --location "$LOCATION" \
  --tags managedBy=bootstrap "workload=$PREFIX" purpose=tfstate
run az storage account create --name "$STATE_SA" --resource-group "$STATE_RG" \
  --location "$LOCATION" --sku Standard_ZRS --kind StorageV2 \
  --min-tls-version TLS1_2 --allow-blob-public-access false \
  --allow-shared-key-access false --https-only true \
  --tags managedBy=bootstrap "workload=$PREFIX" purpose=tfstate
run az storage account blob-service-properties update \
  --account-name "$STATE_SA" --resource-group "$STATE_RG" \
  --enable-versioning true --enable-delete-retention true --delete-retention-days 30 \
  --enable-container-delete-retention true --container-delete-retention-days 30
run az storage container create --name "$STATE_CONTAINER" --account-name "$STATE_SA" --auth-mode login
ok "backend listo"

STATE_SA_ID="$(az storage account show --name "$STATE_SA" --resource-group "$STATE_RG" --query id -o tsv 2>/dev/null || echo '')"
SUB_SCOPE="/subscriptions/${SUBSCRIPTION_ID}"
STATE_SCOPE="${STATE_SA_ID}/blobServices/default/containers/${STATE_CONTAINER}"

ensure_app() {
  local display_name="$1" app_id
  app_id="$(az ad app list --display-name "$display_name" --query '[0].appId' -o tsv 2>/dev/null || true)"
  if [[ -z "$app_id" || "$app_id" == "None" ]]; then
    info "creando app registration $display_name" >&2
    if [[ $DRY_RUN -eq 1 ]]; then echo "<pendiente>"; return; fi
    app_id="$(az ad app create --display-name "$display_name" --query appId -o tsv)"
  fi
  local sp_id
  sp_id="$(az ad sp list --filter "appId eq '$app_id'" --query '[0].id' -o tsv 2>/dev/null || true)"
  if [[ -z "$sp_id" || "$sp_id" == "None" ]] && [[ $DRY_RUN -eq 0 ]]; then
    az ad sp create --id "$app_id" >/dev/null
  fi
  echo "$app_id"
}

ensure_fic() {
  local app_id="$1" name="$2" subject="$3"
  if [[ $DRY_RUN -eq 1 ]]; then info "fic $name -> $subject"; return; fi
  local existing
  existing="$(az ad app federated-credential list --id "$app_id" --query "[?name=='$name'].name" -o tsv 2>/dev/null || true)"
  [[ -n "$existing" ]] && { info "fic $name ya existe"; return; }
  az ad app federated-credential create --id "$app_id" --parameters "$(cat <<JSON
{
  "name": "$name",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "$subject",
  "description": "GitHub Actions OIDC para $GITHUB_REPO",
  "audiences": ["api://AzureADTokenExchange"]
}
JSON
)" >/dev/null
  ok "fic $name -> $subject"
}

ensure_role() {
  local app_id="$1" role="$2" scope="$3"
  if [[ $DRY_RUN -eq 1 ]]; then info "role $role en $scope"; return; fi
  local object_id already
  object_id="$(az ad sp list --filter "appId eq '$app_id'" --query '[0].id' -o tsv)"
  already="$(az role assignment list --assignee "$object_id" --role "$role" --scope "$scope" --query '[0].id' -o tsv 2>/dev/null || true)"
  [[ -n "$already" ]] && { info "role $role ya asignado"; return; }
  az role assignment create --assignee-object-id "$object_id" \
    --assignee-principal-type ServicePrincipal --role "$role" --scope "$scope" >/dev/null
  ok "role $role en $scope"
}

step "Creando identidades OIDC (sin secretos de cliente)"

# Identidad de plan: solo lectura. Corre en pull requests, sobre codigo aun no revisado.
PLAN_APP_ID="$(ensure_app "gh-${PREFIX}-plan")"
ensure_fic "$PLAN_APP_ID" "gh-pull-request" "repo:${GITHUB_REPO}:pull_request"
ensure_fic "$PLAN_APP_ID" "gh-main" "repo:${GITHUB_REPO}:ref:refs/heads/main"
ensure_role "$PLAN_APP_ID" "Reader" "$SUB_SCOPE"
# Terraform toma un lease del blob para bloquear el state, incluso en plan.
ensure_role "$PLAN_APP_ID" "Storage Blob Data Contributor" "$STATE_SCOPE"

declare -A APPLY_IDS
for env in "${ENVIRONMENTS[@]}"; do
  app_id="$(ensure_app "gh-${PREFIX}-apply-${env}")"
  ensure_fic "$app_id" "gh-env-${env}" "repo:${GITHUB_REPO}:environment:${env}"
  ensure_role "$app_id" "Contributor" "$SUB_SCOPE"
  ensure_role "$app_id" "User Access Administrator" "$SUB_SCOPE"
  ensure_role "$app_id" "Resource Policy Contributor" "$SUB_SCOPE"
  ensure_role "$app_id" "Storage Blob Data Contributor" "$STATE_SCOPE"
  APPLY_IDS[$env]="$app_id"
done

step "Configuracion para GitHub"
OUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/outputs"
mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/github-config.md"
{
  echo "# Configuracion de GitHub generada por bootstrap.sh"
  echo
  echo "Repositorio: \`$GITHUB_REPO\`"
  echo
  echo "## Variables a nivel repositorio"
  echo
  echo "| Nombre | Valor |"
  echo "|---|---|"
  echo "| \`AZURE_TENANT_ID\` | \`$TENANT_ID\` |"
  echo "| \`AZURE_SUBSCRIPTION_ID\` | \`$SUBSCRIPTION_ID\` |"
  echo "| \`AZURE_CLIENT_ID\` | \`$PLAN_APP_ID\` |"
  echo "| \`TFSTATE_RESOURCE_GROUP\` | \`$STATE_RG\` |"
  echo "| \`TFSTATE_STORAGE_ACCOUNT\` | \`$STATE_SA\` |"
  echo "| \`TFSTATE_CONTAINER\` | \`$STATE_CONTAINER\` |"
  echo
  echo "## Variables por environment"
  echo
  for env in "${ENVIRONMENTS[@]}"; do
    echo "### \`$env\`"
    echo
    echo "| Nombre | Valor |"
    echo "|---|---|"
    echo "| \`AZURE_CLIENT_ID\` | \`${APPLY_IDS[$env]}\` |"
    echo
  done
  echo "Marca **Required reviewers** en el environment \`prod\`."
} | tee "$OUT_FILE"
ok "guardado en $OUT_FILE"

step "Bootstrap completo"

<#
.SYNOPSIS
  Bootstrap del despliegue: crea el backend de state de Terraform y las
  identidades OIDC que usa GitHub Actions. Es idempotente.

.DESCRIPTION
  Este script es el unico paso que NO esta en Terraform, por el problema del
  huevo y la gallina: Terraform necesita un backend remoto que todavia no
  existe, y GitHub Actions necesita una identidad federada para poder correr.

  Crea:
    - Resource group + storage account + contenedor para el state remoto,
      con acceso solo por Entra ID (shared keys deshabilitadas), versionado y
      soft delete.
    - Tres aplicaciones de Entra ID con federacion OIDC contra este repositorio:
        gh-<prefix>-plan        Reader     -> corre terraform plan en los PR
        gh-<prefix>-apply-dev   Contributor-> aplica en dev
        gh-<prefix>-apply-prod  Contributor-> aplica en prod
      Ningun secreto de cliente: solo federacion (seccion 9 del diseno).

.PARAMETER SubscriptionId
  Suscripcion de Azure destino.

.PARAMETER GitHubRepo
  Repositorio en formato owner/repo.

.EXAMPLE
  ./bootstrap/bootstrap.ps1 -SubscriptionId 00000000-... -GitHubRepo contoso/itsm-azure
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$SubscriptionId,
  [Parameter(Mandatory = $true)][string]$GitHubRepo,
  [string]$Prefix = "itsm",
  [string]$Location = "eastus2",
  [string[]]$Environments = @("dev", "prod"),
  [switch]$WhatIfOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-Step { param([string]$Message) Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Write-Info { param([string]$Message) Write-Host "    $Message" -ForegroundColor DarkGray }
function Write-Ok   { param([string]$Message) Write-Host "    OK  $Message" -ForegroundColor Green }

if ($GitHubRepo -notmatch '^[^/]+/[^/]+$') {
  throw "GitHubRepo debe tener el formato owner/repo. Recibido: $GitHubRepo"
}

# --- 0. Precondiciones -------------------------------------------------------
Write-Step "Verificando prerequisitos"
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
  throw "Azure CLI no encontrado. Instala az y vuelve a correr."
}

$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) { throw "No hay sesion de Azure CLI. Corre 'az login' primero." }

az account set --subscription $SubscriptionId | Out-Null
$account = az account show | ConvertFrom-Json
$TenantId = $account.tenantId
Write-Ok "Suscripcion: $($account.name) ($SubscriptionId)"
Write-Ok "Tenant:      $TenantId"

if ($WhatIfOnly) {
  Write-Host "`n-WhatIfOnly activo: no se creara nada." -ForegroundColor Yellow
}

# --- 1. Resource providers ---------------------------------------------------
# El provider de Terraform corre con resource_provider_registrations = "none"
# para que la identidad de plan (Reader) no falle intentando registrar. Por eso
# el registro se hace aqui, una sola vez.
Write-Step "Registrando resource providers"
$providers = @(
  "Microsoft.Storage", "Microsoft.Network", "Microsoft.ContainerService",
  "Microsoft.ContainerRegistry", "Microsoft.KeyVault", "Microsoft.DBforPostgreSQL",
  "Microsoft.Cache", "Microsoft.ServiceBus", "Microsoft.Search",
  "Microsoft.OperationalInsights", "Microsoft.Insights", "Microsoft.Monitor",
  "Microsoft.Dashboard", "Microsoft.Cdn", "Microsoft.ApiManagement",
  "Microsoft.Security", "Microsoft.SecurityInsights", "Microsoft.PolicyInsights",
  "Microsoft.ManagedIdentity", "Microsoft.Relay", "Microsoft.EventGrid",
  "Microsoft.Authorization", "Microsoft.Resources"
)
foreach ($rp in $providers) {
  $state = (az provider show --namespace $rp --query registrationState -o tsv 2>$null)
  if ($state -ne "Registered") {
    Write-Info "registrando $rp (estado actual: $state)"
    if (-not $WhatIfOnly) { az provider register --namespace $rp --wait | Out-Null }
  }
}
Write-Ok "$($providers.Count) providers verificados"

# --- 2. Backend de state -----------------------------------------------------
Write-Step "Creando backend de Terraform state"

$stateRg = "rg-$Prefix-tfstate-$Location"
# Sufijo deterministico a partir de suscripcion + repo: reejecutar el script
# devuelve siempre el mismo nombre de storage account.
$hashInput = "$SubscriptionId|$GitHubRepo"
$sha = [System.Security.Cryptography.SHA256]::Create()
$hashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hashInput))
$suffix = ([System.BitConverter]::ToString($hashBytes) -replace '-', '').ToLower().Substring(0, 8)
$stateSa = "st$($Prefix)tfstate$suffix"
$stateContainer = "tfstate"

if ($stateSa.Length -gt 24) { throw "El nombre de storage account excede 24 caracteres: $stateSa. Usa un -Prefix mas corto." }

Write-Info "resource group : $stateRg"
Write-Info "storage account: $stateSa"
Write-Info "contenedor     : $stateContainer"

if (-not $WhatIfOnly) {
  az group create --name $stateRg --location $Location `
    --tags managedBy=bootstrap workload=$Prefix purpose=tfstate | Out-Null

  az storage account create `
    --name $stateSa --resource-group $stateRg --location $Location `
    --sku Standard_ZRS --kind StorageV2 `
    --min-tls-version TLS1_2 `
    --allow-blob-public-access false `
    --allow-shared-key-access false `
    --https-only true `
    --public-network-access Enabled `
    --tags managedBy=bootstrap workload=$Prefix purpose=tfstate | Out-Null

  # Versionado + soft delete: red de seguridad ante un state corrupto o un
  # apply desafortunado. Es lo mas barato que se puede comprar.
  az storage account blob-service-properties update `
    --account-name $stateSa --resource-group $stateRg `
    --enable-versioning true `
    --enable-delete-retention true --delete-retention-days 30 `
    --enable-container-delete-retention true --container-delete-retention-days 30 | Out-Null

  # El contenedor se crea con auth de Entra ID porque las shared keys estan
  # deshabilitadas por diseno.
  az storage container create `
    --name $stateContainer --account-name $stateSa --auth-mode login | Out-Null

  Write-Ok "backend listo"
}

$stateSaId = az storage account show --name $stateSa --resource-group $stateRg --query id -o tsv 2>$null

# --- 3. Identidades federadas para GitHub Actions ----------------------------
Write-Step "Creando identidades OIDC (sin secretos de cliente)"

function Ensure-App {
  param([string]$DisplayName)

  $appId = az ad app list --display-name $DisplayName --query "[0].appId" -o tsv 2>$null
  if ([string]::IsNullOrWhiteSpace($appId)) {
    Write-Info "creando app registration $DisplayName"
    if ($WhatIfOnly) { return "<pendiente>" }
    $appId = az ad app create --display-name $DisplayName --query appId -o tsv
  } else {
    Write-Info "app registration $DisplayName ya existe"
  }

  $spId = az ad sp list --filter "appId eq '$appId'" --query "[0].id" -o tsv 2>$null
  if ([string]::IsNullOrWhiteSpace($spId)) {
    if (-not $WhatIfOnly) { az ad sp create --id $appId | Out-Null }
  }
  return $appId
}

function Ensure-FederatedCredential {
  param([string]$AppId, [string]$Name, [string]$Subject)

  if ($WhatIfOnly) { Write-Info "federated credential $Name -> $Subject"; return }

  $existing = az ad app federated-credential list --id $AppId --query "[?name=='$Name'].name" -o tsv 2>$null
  if (-not [string]::IsNullOrWhiteSpace($existing)) {
    Write-Info "federated credential $Name ya existe"
    return
  }

  $payload = @{
    name        = $Name
    issuer      = "https://token.actions.githubusercontent.com"
    subject     = $Subject
    description = "GitHub Actions OIDC para $GitHubRepo"
    audiences   = @("api://AzureADTokenExchange")
  } | ConvertTo-Json -Compress

  $tmp = New-TemporaryFile
  # Sin BOM: az no parsea el JSON si lo lleva.
  [System.IO.File]::WriteAllText($tmp.FullName, $payload, (New-Object System.Text.UTF8Encoding($false)))
  az ad app federated-credential create --id $AppId --parameters "@$($tmp.FullName)" | Out-Null
  Remove-Item $tmp.FullName -Force
  Write-Ok "federated credential $Name -> $Subject"
}

function Ensure-RoleAssignment {
  param([string]$AppId, [string]$Role, [string]$Scope)

  if ($WhatIfOnly) { Write-Info "role $Role en $Scope"; return }

  $objectId = az ad sp list --filter "appId eq '$AppId'" --query "[0].id" -o tsv
  $already = az role assignment list --assignee $objectId --role $Role --scope $Scope --query "[0].id" -o tsv 2>$null
  if (-not [string]::IsNullOrWhiteSpace($already)) {
    Write-Info "role $Role ya asignado"
    return
  }
  az role assignment create `
    --assignee-object-id $objectId --assignee-principal-type ServicePrincipal `
    --role $Role --scope $Scope | Out-Null
  Write-Ok "role $Role en $Scope"
}

$subScope = "/subscriptions/$SubscriptionId"
$stateScope = if ($stateSaId) { "$stateSaId/blobServices/default/containers/$stateContainer" } else { "<pendiente>" }
$results = @{}

# 3a. Identidad de PLAN: solo lectura sobre la suscripcion. Es la que corre en
#     los pull requests, donde el codigo todavia no ha sido revisado.
$planApp = "gh-$Prefix-plan"
$planAppId = Ensure-App -DisplayName $planApp
Ensure-FederatedCredential -AppId $planAppId -Name "gh-pull-request" -Subject "repo:$($GitHubRepo):pull_request"
Ensure-FederatedCredential -AppId $planAppId -Name "gh-main" -Subject "repo:$($GitHubRepo):ref:refs/heads/main"
Ensure-RoleAssignment -AppId $planAppId -Role "Reader" -Scope $subScope
# Escribir en el contenedor es necesario aunque solo se planifique: Terraform
# toma un lease sobre el blob de state para bloquearlo.
Ensure-RoleAssignment -AppId $planAppId -Role "Storage Blob Data Contributor" -Scope $stateScope
$results["plan"] = $planAppId

# 3b. Identidad de APPLY por entorno. La federacion apunta al environment de
#     GitHub, de modo que el token solo se emite cuando el job pasa por la
#     puerta de aprobacion de ese environment.
foreach ($env in $Environments) {
  $applyApp = "gh-$Prefix-apply-$env"
  $applyAppId = Ensure-App -DisplayName $applyApp
  Ensure-FederatedCredential -AppId $applyAppId -Name "gh-env-$env" -Subject "repo:$($GitHubRepo):environment:$env"

  Ensure-RoleAssignment -AppId $applyAppId -Role "Contributor" -Scope $subScope
  # Necesario para crear role assignments (Workload Identity, AcrPull, etc.).
  Ensure-RoleAssignment -AppId $applyAppId -Role "User Access Administrator" -Scope $subScope
  # Contributor no puede escribir en Microsoft.Authorization: la fase 70 lo necesita.
  Ensure-RoleAssignment -AppId $applyAppId -Role "Resource Policy Contributor" -Scope $subScope
  Ensure-RoleAssignment -AppId $applyAppId -Role "Storage Blob Data Contributor" -Scope $stateScope

  $results[$env] = $applyAppId
}

# --- 4. Salida ---------------------------------------------------------------
Write-Step "Configuracion para GitHub"

$outDir = Join-Path $PSScriptRoot "outputs"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$outFile = Join-Path $outDir "github-config.md"

$lines = @()
$lines += "# Configuracion de GitHub generada por bootstrap.ps1"
$lines += ""
$lines += "Repositorio: ``$GitHubRepo``"
$lines += ""
$lines += "## Variables a nivel repositorio (Settings > Secrets and variables > Actions > Variables)"
$lines += ""
$lines += "| Nombre | Valor |"
$lines += "|---|---|"
$lines += "| ``AZURE_TENANT_ID`` | ``$TenantId`` |"
$lines += "| ``AZURE_SUBSCRIPTION_ID`` | ``$SubscriptionId`` |"
$lines += "| ``AZURE_CLIENT_ID`` | ``$($results['plan'])`` |"
$lines += "| ``TFSTATE_RESOURCE_GROUP`` | ``$stateRg`` |"
$lines += "| ``TFSTATE_STORAGE_ACCOUNT`` | ``$stateSa`` |"
$lines += "| ``TFSTATE_CONTAINER`` | ``$stateContainer`` |"
$lines += ""
$lines += "``AZURE_CLIENT_ID`` a nivel repositorio es la identidad de solo lectura que corre los ``plan`` de los pull requests."
$lines += ""
$lines += "## Variables por environment (Settings > Environments)"
$lines += ""
foreach ($env in $Environments) {
  $lines += "### ``$env``"
  $lines += ""
  $lines += "| Nombre | Valor |"
  $lines += "|---|---|"
  $lines += "| ``AZURE_CLIENT_ID`` | ``$($results[$env])`` |"
  $lines += ""
}
$lines += "La variable del environment sobrescribe la del repositorio: los jobs de apply reciben la identidad con permisos de escritura solo despues de pasar la aprobacion del environment."
$lines += ""
$lines += "Recuerda marcar **Required reviewers** en el environment ``prod``."

$content = $lines -join "`n"
Set-Content -Path $outFile -Value $content -Encoding utf8
Write-Host $content
Write-Ok "guardado en $outFile"

if (Get-Command gh -ErrorAction SilentlyContinue) {
  Write-Host "`nPara aplicarlo automaticamente con gh CLI:" -ForegroundColor Yellow
  Write-Host "  gh variable set AZURE_TENANT_ID --repo $GitHubRepo --body $TenantId"
  Write-Host "  gh variable set AZURE_SUBSCRIPTION_ID --repo $GitHubRepo --body $SubscriptionId"
  Write-Host "  gh variable set AZURE_CLIENT_ID --repo $GitHubRepo --body $($results['plan'])"
  Write-Host "  gh variable set TFSTATE_RESOURCE_GROUP --repo $GitHubRepo --body $stateRg"
  Write-Host "  gh variable set TFSTATE_STORAGE_ACCOUNT --repo $GitHubRepo --body $stateSa"
  Write-Host "  gh variable set TFSTATE_CONTAINER --repo $GitHubRepo --body $stateContainer"
  foreach ($env in $Environments) {
    Write-Host "  gh variable set AZURE_CLIENT_ID --repo $GitHubRepo --env $env --body $($results[$env])"
  }
}

Write-Step "Bootstrap completo"

<#
.SYNOPSIS
  Envoltorio local de Terraform por fase y entorno (equivalente de tf.sh).

.EXAMPLE
  ./scripts/tf.ps1 10-network-hub dev plan
  ./scripts/tf.ps1 30-data prod output -Extra @("-json")
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)][string]$Phase,
  [Parameter(Mandatory = $true, Position = 1)][ValidateSet("dev", "qa", "prod")][string]$Environment,
  [Parameter(Mandatory = $true, Position = 2)][string]$Command,
  [string[]]$Extra = @(),
  [switch]$ReInit
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

# Carga .env si existe (KEY=VALUE por linea).
$envFile = Join-Path $root ".env"
if (Test-Path $envFile) {
  Get-Content $envFile | Where-Object { $_ -match '^\s*[^#].*=' } | ForEach-Object {
    $name, $value = $_ -split '=', 2
    Set-Item -Path "env:$($name.Trim())" -Value $value.Trim()
  }
}

$phaseDir = Join-Path $root "infra/phases/$Phase"
if (-not (Test-Path $phaseDir)) {
  Write-Host "Fase desconocida: $Phase" -ForegroundColor Red
  Get-ChildItem (Join-Path $root "infra/phases") -Directory | ForEach-Object { Write-Host "  $($_.Name)" }
  exit 2
}

foreach ($v in @("ARM_SUBSCRIPTION_ID", "TFSTATE_RESOURCE_GROUP", "TFSTATE_STORAGE_ACCOUNT", "TFSTATE_CONTAINER")) {
  if (-not (Test-Path "env:$v")) { throw "Falta la variable de entorno $v" }
}

# Los data sources terraform_remote_state las necesitan como variables, no solo
# el backend.
$env:TF_VAR_tfstate_resource_group_name = $env:TFSTATE_RESOURCE_GROUP
$env:TF_VAR_tfstate_storage_account_name = $env:TFSTATE_STORAGE_ACCOUNT
$env:TF_VAR_tfstate_container_name = $env:TFSTATE_CONTAINER
$env:ARM_STORAGE_USE_AZUREAD = "true"

$varFiles = @("-var-file=$root/infra/envs/$Environment.tfvars")
$phaseVars = Join-Path $phaseDir "tfvars/$Environment.tfvars"
if (Test-Path $phaseVars) { $varFiles += "-var-file=$phaseVars" }

Push-Location $phaseDir
try {
  if ($ReInit -or -not (Test-Path ".terraform")) {
    terraform init -input=false -reconfigure `
      "-backend-config=resource_group_name=$($env:TFSTATE_RESOURCE_GROUP)" `
      "-backend-config=storage_account_name=$($env:TFSTATE_STORAGE_ACCOUNT)" `
      "-backend-config=container_name=$($env:TFSTATE_CONTAINER)" `
      "-backend-config=key=$Phase/$Environment.tfstate" `
      "-backend-config=subscription_id=$($env:ARM_SUBSCRIPTION_ID)" `
      "-backend-config=use_azuread_auth=true"
    if ($LASTEXITCODE -ne 0) { throw "terraform init fallo" }
  }

  $needsVarFiles = @("plan", "apply", "destroy", "refresh", "import")
  if ($needsVarFiles -contains $Command) {
    terraform $Command @varFiles @Extra
  } else {
    terraform $Command @Extra
  }
  exit $LASTEXITCODE
} finally {
  Pop-Location
}

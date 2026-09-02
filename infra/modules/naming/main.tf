locals {
  # Abreviaturas de region. Si la region no esta en el mapa se usa un fallback
  # deterministico para no romper el plan al cambiar de region.
  location_short_map = {
    eastus         = "eus"
    eastus2        = "eus2"
    centralus      = "cus"
    southcentralus = "scus"
    westus2        = "wus2"
    westus3        = "wus3"
    mexicocentral  = "mxc"
    brazilsouth    = "brs"
    northeurope    = "neu"
    westeurope     = "weu"
    spaincentral   = "spc"
  }

  location_short = try(
    local.location_short_map[var.location],
    substr(replace(lower(var.location), "/[^a-z0-9]/", ""), 0, 6)
  )

  # itsm-hub-dev-eus2
  base = "${var.prefix}-${var.component}-${var.environment}-${local.location_short}"

  # itsmhubdeveus2 -> para recursos sin guiones (storage, acr, kv)
  compact = replace(local.base, "-", "")

  tags = merge(
    {
      workload    = var.prefix
      component   = var.component
      environment = var.environment
      costCenter  = var.cost_center
      owner       = var.owner
      phase       = var.phase
      managedBy   = "terraform"
    },
    var.extra_tags
  )
}

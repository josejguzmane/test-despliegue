# Todas arrancan en enforce = false: primero se mide el impacto sobre el
# inventario existente, despues se pasa a bloqueo. Verifica cada display_name
# con ./scripts/find-policy.sh antes de descomentar.
policy_assignments = {
  # no-public-ip = {
  #   display_name     = "Not allowed resource types"
  #   scope_components = ["spoke", "data", "aks"]
  #   parameters       = { listOfResourceTypesNotAllowed = ["Microsoft.Network/publicIPAddresses"] }
  #   enforce          = false
  # }
  # require-costcenter = {
  #   display_name     = "Require a tag on resources"
  #   scope_components = ["hub", "spoke", "data", "aks", "edge", "obs", "sec"]
  #   parameters       = { tagName = "costCenter" }
  #   enforce          = false
  # }
  # storage-private-only = {
  #   display_name     = "Storage accounts should restrict network access"
  #   scope_components = ["data"]
  #   enforce          = false
  # }
}

enable_defender_plans = false
enable_sentinel       = false

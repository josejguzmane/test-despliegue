# Zonas privadas de la seccion 3.6. privatelink.<region>.azmk8s.io debe
# coincidir con la region del cluster AKS de la fase 40.
private_dns_zones = [
  "privatelink.postgres.database.azure.com",
  "privatelink.redis.cache.windows.net",
  "privatelink.servicebus.windows.net",
  "privatelink.blob.core.windows.net",
  "privatelink.vaultcore.azure.net",
  "privatelink.azurecr.io",
  "privatelink.search.windows.net",
  "privatelink.eastus2.azmk8s.io",
  "privatelink.azurefd.net",
]

enable_postgresql  = false
enable_redis       = false
enable_service_bus = false
enable_storage     = false
enable_key_vault   = false
enable_acr         = false
enable_ai_search   = false

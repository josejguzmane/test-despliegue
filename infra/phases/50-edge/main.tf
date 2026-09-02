# =============================================================================
# FASE 50 - BORDE PUBLICO
# =============================================================================
# Unico punto de entrada desde Internet (seccion 3.3):
#
#   Navegador -> Front Door Premium (TLS, DDoS, WAF, cache)
#             -> Private Link Service (trafico privado, no Internet)
#             -> ILB interno del ingress controller
#             -> pods
#
# Consecuencia de diseno: el spoke no tiene ni una sola IP publica y no existe
# ruta desde Internet al cluster que no atraviese el WAF.
#
# El Private Link Service depende del ILB que crea el ingress controller dentro
# del cluster, asi que esta fase se aplica despues de que la fase 40 exista y
# el ingress este desplegado por GitOps.
# =============================================================================

locals {
  phase = "50-edge"
}

module "naming" {
  source = "../../modules/naming"

  prefix      = var.prefix
  environment = var.environment
  location    = var.location
  component   = "edge"
  cost_center = var.cost_center
  owner       = var.owner
  phase       = local.phase
  extra_tags  = var.extra_tags
}

# -----------------------------------------------------------------------------
# TODO fase 50:
#
#   [ ] azurerm_cdn_frontdoor_profile (SKU Premium_AzureFrontDoor)
#   [ ] azurerm_cdn_frontdoor_firewall_policy
#         mode = var.waf_mode
#         managed rules: Microsoft_DefaultRuleSet 2.1 + Microsoft_BotManagerRuleSet
#         custom rules: rate limiting por IP segun var.rate_limit_rules
#                       (100 req/min en /api/*, 5 req/min en /api/auth/register)
#         geo-filtrado si el servicio es de alcance nacional
#   [ ] azurerm_cdn_frontdoor_security_policy que asocia el WAF al dominio
#   [ ] azurerm_cdn_frontdoor_custom_domain para var.public_hostname, con
#       certificado gestionado o referenciado desde Key Vault
#   [ ] azurerm_cdn_frontdoor_origin_group con health probes y session affinity
#   [ ] azurerm_cdn_frontdoor_origin con private_link apuntando al PLS
#   [ ] azurerm_cdn_frontdoor_route con https_redirect_enabled y cache de
#       estaticos, forwarding_protocol = HttpsOnly
#   [ ] azurerm_private_link_service publicando el ILB interno del ingress
#       (frontend_ip_configuration del ILB creado por el Service de Kubernetes)
#   [ ] Aprobacion de la conexion private link del origen de Front Door
#   [ ] azurerm_api_management en modo interno sobre snet-apim
#   [ ] azurerm_monitor_diagnostic_setting de Front Door y WAF hacia LAW
#       (FrontDoorAccessLog, FrontDoorWebApplicationFirewallLog)
#
# Alternativa evaluada en el diseno: Application Gateway v2 con WAF como
# segundo nivel regional. Se descarto por exigir IP publica; si aparece el
# requisito de mTLS de cliente, se agrega un AGW interno entre el PLS y el
# ingress.
# -----------------------------------------------------------------------------

resource "terraform_data" "unimplemented_guard" {
  # Siempre presente: la guarda vive en la precondition, no en el count,
  # porque Terraform exige que la condicion referencie algo real.
  input = local.phase

  lifecycle {
    precondition {
      condition     = !(var.enable_front_door || var.enable_apim)
      error_message = "enable_front_door / enable_apim estan activos pero los recursos aun no estan implementados. Implementa los TODO de main.tf antes de encender los flags."
    }
  }
}

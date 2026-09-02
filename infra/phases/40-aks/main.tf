# =============================================================================
# FASE 40 - PLATAFORMA DE CONTENEDORES (AKS)
# =============================================================================
# Cluster privado, zonal, con Azure CNI Overlay + Cilium, Workload Identity y
# egreso forzado por UDR hacia el firewall del hub (seccion 5).
#
# Lo unico sin costo que se crea aqui son las identidades administradas: se
# declaran desde ya porque las fases y los equipos de aplicacion las referencian
# (federacion OIDC de Workload ID, seccion 4.3).
# =============================================================================

locals {
  phase = "40-aks"

  # Una identidad por microservicio, con permisos minimos. Los service accounts
  # del cluster se federan contra estas identidades: cero secretos en el cluster.
  workload_identities = {
    "ticket-api"       = "itsm-core"
    "workflow-engine"  = "itsm-core"
    "cmdb-api"         = "itsm-core"
    "catalog-api"      = "itsm-core"
    "kb-api"           = "itsm-knowledge"
    "search-indexer"   = "itsm-knowledge"
    "notification-svc" = "itsm-integration"
    "webhook-ingress"  = "itsm-integration"
    "file-svc"         = "itsm-files"
    "bff-gateway"      = "itsm-edge"
  }
}

module "naming" {
  source = "../../modules/naming"

  prefix      = var.prefix
  environment = var.environment
  location    = var.location
  component   = "aks"
  cost_center = var.cost_center
  owner       = var.owner
  phase       = local.phase
  extra_tags  = var.extra_tags
}

# Identidad del plano de control del cluster. Se crea aparte del cluster para
# poder asignarle Network Contributor sobre las subredes antes del primer apply
# y evitar la carrera clasica de permisos.
resource "azurerm_user_assigned_identity" "cluster" {
  name                = "id-${module.naming.base}-cluster"
  resource_group_name = local.aks_rg
  location            = var.location
  tags                = module.naming.tags
}

resource "azurerm_user_assigned_identity" "kubelet" {
  name                = "id-${module.naming.base}-kubelet"
  resource_group_name = local.aks_rg
  location            = var.location
  tags                = module.naming.tags
}

# Identidades de carga de trabajo (seccion 4.3). Sin federacion todavia: el
# federated credential necesita el issuer OIDC del cluster, que no existe hasta
# que enable_cluster sea true.
resource "azurerm_user_assigned_identity" "workload" {
  for_each = local.workload_identities

  name                = "id-${var.prefix}-${each.key}-${var.environment}"
  resource_group_name = local.aks_rg
  location            = var.location
  tags                = merge(module.naming.tags, { namespace = each.value, service = each.key })
}

# -----------------------------------------------------------------------------
# TODO fase 40:
#
#   [ ] azurerm_kubernetes_cluster "aks"
#         sku_tier                  = "Standard"
#         private_cluster_enabled   = true
#         private_dns_zone_id       = zona privatelink.<region>.azmk8s.io de la fase 30
#         oidc_issuer_enabled       = true
#         workload_identity_enabled = true
#         azure_policy_enabled      = true
#         image_cleaner_enabled     = true
#         network_profile: network_plugin=azure, network_plugin_mode=overlay,
#                          network_data_plane=cilium, network_policy=cilium,
#                          outbound_type=userDefinedRouting,
#                          pod_cidr/service_cidr/dns_service_ip de las variables
#         azure_active_directory_role_based_access_control:
#                          azure_rbac_enabled = true, admin_group_object_ids
#         automatic_upgrade_channel = "stable" + maintenance_window nocturna
#         node_os_upgrade_channel   = "NodeImage"
#         default_node_pool: system, D4s_v5, zonas 1/2/3, only_critical_addons_taint
#
#   [ ] azurerm_kubernetes_cluster_node_pool: apps (3-15), workers (Spot 0-20,
#       taint scalesetpriority=spot), memory (E8s_v5 0-4, taint workload=memory)
#   [ ] Addons gestionados: Managed Prometheus, Container Insights, Istio,
#       KEDA, Defender, Secrets Store CSI Driver con rotacion
#   [ ] azurerm_role_assignment: Network Contributor de la identidad del cluster
#       sobre snet-aks-system / snet-aks-user; AcrPull del kubelet sobre el ACR
#   [ ] azurerm_federated_identity_credential por cada identidad de workload,
#       con subject system:serviceaccount:<namespace>:sa-<servicio>
#   [ ] azurerm_role_assignment de minimo privilegio por servicio: ticket-api
#       lee un solo Key Vault y escribe en una sola cola; file-svc es el unico
#       con Storage Blob Data Contributor sobre el contenedor de adjuntos
#   [ ] Flux (GitOps) via azurerm_kubernetes_flux_configuration apuntando al
#       repositorio de manifiestos
#   [ ] azurerm_monitor_diagnostic_setting con las categorias de auditoria de
#       Kubernetes hacia LAW
# -----------------------------------------------------------------------------

resource "terraform_data" "unimplemented_guard" {
  # Siempre presente: la guarda vive en la precondition, no en el count,
  # porque Terraform exige que la condicion referencie algo real.
  input = local.phase

  lifecycle {
    precondition {
      condition     = !var.enable_cluster
      error_message = "enable_cluster esta activo pero el recurso azurerm_kubernetes_cluster aun no esta implementado. Implementa los TODO de main.tf antes de encender el flag."
    }
  }
}

# Chequeos de coherencia del direccionamiento, para que un error de CIDR falle
# en plan y no a mitad de la creacion del cluster.
resource "terraform_data" "cidr_checks" {
  lifecycle {
    precondition {
      condition     = cidrhost(var.service_cidr, 0) != null && can(cidrnetmask(var.service_cidr))
      error_message = "service_cidr no es un CIDR valido."
    }
    precondition {
      condition     = can(cidrnetmask(var.pod_cidr))
      error_message = "pod_cidr no es un CIDR valido."
    }
    precondition {
      condition     = can(regex("^[0-9.]+$", var.dns_service_ip))
      error_message = "dns_service_ip debe ser una IPv4 dentro de service_cidr."
    }
  }
}

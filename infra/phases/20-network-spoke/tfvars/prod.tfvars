# Direccionamiento de la seccion 3.2 del diseno.
spoke_address_space = ["10.10.0.0/16"]

spoke_subnets = {
  ingress     = "10.10.1.0/24"
  apim        = "10.10.2.0/24"
  aks_system  = "10.10.4.0/22"
  aks_user    = "10.10.8.0/21"
  privatelink = "10.10.16.0/24"
}

enable_peering      = true
use_remote_gateways = false

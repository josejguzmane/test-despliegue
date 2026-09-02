spoke_address_space = ["10.20.0.0/16"]

spoke_subnets = {
  ingress     = "10.20.1.0/24"
  apim        = "10.20.2.0/24"
  aks_system  = "10.20.4.0/22"
  aks_user    = "10.20.8.0/21"
  privatelink = "10.20.16.0/24"
}

enable_peering      = true
use_remote_gateways = false

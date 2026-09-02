# Direccionamiento de la seccion 3.2 del diseno.
hub_address_space = ["10.0.0.0/22"]

hub_subnets = {
  firewall            = "10.0.0.0/26"
  firewall_management = "10.0.0.64/26"
  bastion             = "10.0.0.128/26"
  gateway             = "10.0.0.192/27"
  dns_inbound         = "10.0.1.0/28"
  dns_outbound        = "10.0.1.16/28"
  mgmt                = "10.0.2.0/24"
}

enable_firewall     = false
enable_bastion      = false
enable_dns_resolver = false

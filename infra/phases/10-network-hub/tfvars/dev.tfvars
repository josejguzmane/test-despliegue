# Hub dev: mismo esquema que prod a menor escala, en un /22 distinto para poder
# emparejar ambos entornos con on-premises sin solapamiento.
hub_address_space = ["10.1.0.0/22"]

hub_subnets = {
  firewall            = "10.1.0.0/26"
  firewall_management = "10.1.0.64/26"
  bastion             = "10.1.0.128/26"
  gateway             = "10.1.0.192/27"
  dns_inbound         = "10.1.1.0/28"
  dns_outbound        = "10.1.1.16/28"
  mgmt                = "10.1.2.0/24"
}

enable_firewall     = false
enable_bastion      = false
enable_dns_resolver = false

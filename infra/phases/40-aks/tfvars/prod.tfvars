# Espacios de la seccion 3.2: overlay de pods y services fuera de la VNet.
pod_cidr       = "172.16.0.0/16"
service_cidr   = "172.20.0.0/16"
dns_service_ip = "172.20.0.10"

kubernetes_version = null
enable_cluster     = false

# Rellenar con los object IDs de los grupos de Entra ID elegibles via PIM.
admin_group_object_ids = []

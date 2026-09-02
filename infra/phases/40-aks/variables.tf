variable "enable_cluster" {
  description = "Crea el cluster AKS. COSTO ALTO: 3 nodos D4s_v5 de sistema mas los pools de aplicacion (~600 USD/mes de piso) mas 73 USD/mes del tier Standard del plano de control."
  type        = bool
  default     = false
}

variable "kubernetes_version" {
  description = "Version de Kubernetes. Dejar en null para tomar la default de la region y no pelear con el upgrade channel."
  type        = string
  default     = null
}

variable "pod_cidr" {
  description = "Espacio superpuesto de pods para Azure CNI Overlay. No consume IPs de la VNet (seccion 3.2)."
  type        = string
}

variable "service_cidr" {
  description = "Rango de Services de Kubernetes."
  type        = string
}

variable "dns_service_ip" {
  description = "IP de kube-dns dentro de service_cidr."
  type        = string
}

variable "admin_group_object_ids" {
  description = "Object IDs de los grupos de Entra ID con rol de administrador del cluster. Se activan via PIM, no son permanentes (seccion 4.4)."
  type        = list(string)
  default     = []
}

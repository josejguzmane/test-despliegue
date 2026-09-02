variable "policy_assignments" {
  description = <<-EOT
    Asignaciones de Azure Policy (seccion 4.4). Clave = nombre corto de la
    asignacion. Se resuelve la definicion por display_name para no fijar GUIDs
    que pueden variar entre nubes; verifica el nombre exacto con:
      ./scripts/find-policy.sh "parte del nombre"

    - display_name      : display name exacto de la definicion built-in
    - scope_components  : componentes de la fase 00 sobre los que aplica
                          (hub, spoke, data, aks, edge, obs, sec)
    - parameters        : parametros de la definicion, como mapa
    - enforce           : true = Default (bloquea), false = DoNotEnforce (solo reporta)
  EOT
  type = map(object({
    display_name     = string
    scope_components = list(string)
    parameters       = optional(map(any), {})
    enforce          = optional(bool, false)
  }))
  default = {}
}

variable "enable_defender_plans" {
  description = "Activa los planes de Microsoft Defender for Cloud. COSTO ALTO y por consumo (Containers ~7 USD/vCore/mes, Databases, Storage, Key Vault)."
  type        = bool
  default     = false
}

variable "enable_sentinel" {
  description = "Habilita Microsoft Sentinel sobre el workspace. COSTO ALTO, por GB analizado."
  type        = bool
  default     = false
}

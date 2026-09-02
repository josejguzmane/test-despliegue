alert_emails = ["dev-itsm@contoso.com"]

enable_grafana            = false
enable_managed_prometheus = false

# SLOs de la seccion 8.
slo_targets = {
  portal_availability = {
    objective   = 99.9
    window_days = 30
    description = "Disponibilidad del portal"
  }
  ticket_create_p95 = {
    objective   = 800
    window_days = 30
    description = "Latencia p95 de creacion de ticket en ms"
  }
  api_p99 = {
    objective   = 2000
    window_days = 30
    description = "Latencia p99 de API en ms"
  }
  error_rate_5xx = {
    objective   = 0.1
    window_days = 30
    description = "Tasa de error 5xx en porcentaje"
  }
}

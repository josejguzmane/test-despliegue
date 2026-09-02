public_hostname = "portal-dev.contoso.com"
waf_mode        = "Detection"

enable_front_door = false
enable_apim       = false

# Limites de la seccion 3.3.
rate_limit_rules = {
  api = {
    path_prefix = "/api/"
    limit       = 100
    window_min  = 1
  }
  register = {
    path_prefix = "/api/auth/register"
    limit       = 5
    window_min  = 1
  }
}

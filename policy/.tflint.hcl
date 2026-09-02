# Configuracion de tflint. Se pasa con --config=policy/.tflint.hcl.
# Inicializar plugins con: tflint --init --config=policy/.tflint.hcl

config {
  format = "compact"
  # Los modulos locales se analizan por separado, no via llamada.
  call_module_type = "local"
  force            = false
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "azurerm" {
  enabled = true
  version = "0.28.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# Convenciones del repositorio.
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

# Los modulos se referencian por ruta local, no por registry con version.
rule "terraform_module_pinned_source" {
  enabled = false
}

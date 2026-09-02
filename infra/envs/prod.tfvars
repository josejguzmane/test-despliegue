# Valores comunes a todas las fases del entorno productivo.
# Los tres tfstate_* NO van aqui: los inyecta CI como TF_VAR_* porque el nombre
# de la storage account se genera en el bootstrap.
prefix      = "itsm"
environment = "prod"
location    = "eastus2"
cost_center = "CC-ITSM-PROD"
owner       = "plataforma-itsm"

extra_tags = {
  dataClassification = "confidential"
  criticality        = "tier-1"
  compliance         = "audit-2y"
}

# Plataforma ITSM en Azure — infraestructura

Despliegue por fases con Terraform y GitHub Actions de la arquitectura descrita
en [`docs/arquitectura-itsm-azure.md`](docs/arquitectura-itsm-azure.md):
plataforma ITSM multi-tenant, portal publico, backend en AKS privado, red
cerrada por diseno.

Este repositorio contiene el **andamiaje de CI/CD**: el pipeline completo,
funcional y ejercitable de punta a punta, con las fases de Terraform creadas y
los recursos de costo cero ya implementados. Los servicios caros estan
declarados como `TODO` explicitos y protegidos por feature flags.

## Estado actual

| Implementado | Pendiente (marcado como `TODO` en cada fase) |
|---|---|
| Backend de state con bloqueo, versionado y soft delete | Azure Firewall Premium, Bastion, DNS Private Resolver |
| Autenticacion OIDC sin secretos, con identidad de lectura separada de la de escritura | PostgreSQL Flexible, Redis, Service Bus, Blob, AI Search, Key Vault, ACR |
| 8 fases con orden de dependencias codificado | Cluster AKS, node pools, addons, federacion de Workload Identity |
| Plan automatico en PR, comentado y actualizado en sitio | Front Door Premium, WAF, Private Link Service, APIM |
| Apply por fases con puerta de aprobacion por entorno | Managed Prometheus, Grafana, alertas de burn rate |
| Deteccion diaria de deriva con apertura de incidencia | Defender for Cloud, Sentinel, reglas analiticas |
| Politicas propias en OPA, tflint y checkov en cada PR | Asignaciones de Azure Policy en modo deny |
| Resource groups, VNets hub y spoke, peering, zonas DNS privadas, identidades administradas | |

Aplicar el andamiaje completo en dev y prod no tiene costo fijo: ningun recurso
creado cobra por hora.

## Arranque rapido

```bash
az login
./bootstrap/bootstrap.ps1 -SubscriptionId <id> -GitHubRepo <owner>/<repo>
```

Despues carga en GitHub las variables que deja en
`bootstrap/outputs/github-config.md`, crea los environments `dev` y `prod`, y
abre un PR. El detalle esta en el [runbook](docs/runbook.md).

## Estructura

```
bootstrap/          Script idempotente: backend de state + identidades OIDC
infra/
  envs/             Valores comunes por entorno (prefijo, region, etiquetas)
  shared/           variables.common.tf, la fuente unica que se propaga
  modules/          naming, resource-group, virtual-network, private-dns-zone
  phases/           Las 8 fases, cada una con su state independiente
policy/
  .tflint.hcl       Reglas de estilo y de azurerm
  .checkov.yaml     Analisis de seguridad sobre el plan
  opa/              Politicas propias en Rego: etiquetas, red, datos, secretos
scripts/            tf.sh / tf.ps1, deteccion de fases, sincronizacion
.github/workflows/  Workflows de validacion y workflow reutilizable
docs/               Arquitectura, fases y runbook
```

## Workflows de validacion

| Workflow | Disparo | Que hace |
|---|---|---|
| **TF plan (PR)** | pull request | Detecta fases afectadas, planifica contra dev con identidad de solo lectura, comenta el plan |
| **TF validation (main)** | push a `main`, manual | Valida las 8 fases en dev y prod sin aplicar los planes |
| **TF validar fase individual** | manual | Valida y planifica una sola fase |
| **TF validar entorno** | manual | Valida y planifica todas las fases de un entorno |
| **TF deteccion de deriva** | diario 07:00 UTC | Planifica todo; si algo cambio en Azure, abre incidencia |
| **Pipeline validation** | pull request, push a `main`, manual | Valida sintaxis, bloquea comandos de despliegue y comprueba Terraform sin backend |

Los workflows de Terraform delegan en `_terraform-phase.yml`, que es el unico
sitio donde Terraform genera planes en CI. Usa una identidad de solo lectura,
no bloquea el state remoto y no contiene rutas de apply o destroy.

## Decisiones que conviene conocer

**Identidad de solo lectura en CI.** Todos los planes corren con una app de
Entra ID que solo tiene `Reader`. Ningun workflow selecciona environments con
credenciales de escritura, y una comprobacion estatica rechaza comandos de
despliegue antes de ejecutar las validaciones.

**Ni un secreto.** Federacion OIDC en el pipeline, Workload Identity en el
cluster, shared keys deshabilitadas en la storage account del state. No hay
ningun `client_secret` que rotar ni que filtrar.

**Un state por fase.** Ocho states pequenos planifican en segundos y solo se
planifica lo que cambio. Las dependencias se leen con `terraform_remote_state`,
nunca copiando valores a mano.

**Las politicas se evaluan sobre el plan, no despues.** conftest corre reglas
propias en Rego contra el JSON del plan: etiquetas obligatorias, prohibicion de
IPs publicas fuera del hub, servicios de datos sin acceso publico de red, y
deteccion de secretos. Lo que Azure Policy denegaria en produccion, aqui falla
en el pull request.

**La seguridad tambien se valida.** La fase 70 incluye las politicas en modo
deny en el plan, y conftest y checkov deben aprobarlo sin aplicar recursos.

## Alcance

Cubre infraestructura. Quedan fuera, por diseno: manifiestos de Kubernetes
(repositorio aparte reconciliado por Flux), codigo y build de los microservicios,
configuracion de Entra External ID, y migraciones de base de datos.

## Documentacion

- [Arquitectura completa](docs/arquitectura-itsm-azure.md)
- [Fases, dependencias y costos](docs/fases.md)
- [Runbook operativo](docs/runbook.md)

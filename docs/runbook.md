# Runbook

## Puesta en marcha desde cero

### 1. Bootstrap (una sola vez, desde tu maquina)

Crea el backend de state y las identidades OIDC. Es lo unico que no esta en
Terraform, porque Terraform necesita un backend que todavia no existe y GitHub
Actions necesita una identidad federada para poder correr.

```powershell
az login
./bootstrap/bootstrap.ps1 -SubscriptionId <id> -GitHubRepo <owner>/<repo>
```

En Linux, macOS o Cloud Shell:

```bash
./bootstrap/bootstrap.sh -s <id> -r <owner>/<repo>
```

Requiere ser **Owner** de la suscripcion y poder crear app registrations en el
tenant (rol Application Developer como minimo).

Con `-WhatIfOnly` (PowerShell) o `-n` (bash) muestra lo que haria sin crear nada.

Deja el resultado en `bootstrap/outputs/github-config.md`.

### 2. Configurar GitHub

Copia los valores de `bootstrap/outputs/github-config.md`:

**Settings > Secrets and variables > Actions > Variables** (nivel repositorio):

| Variable | Contenido |
|---|---|
| `AZURE_TENANT_ID` | tenant |
| `AZURE_SUBSCRIPTION_ID` | suscripcion |
| `AZURE_CLIENT_ID` | app de **solo lectura** (`gh-itsm-plan`) |
| `TFSTATE_RESOURCE_GROUP` | rg del state |
| `TFSTATE_STORAGE_ACCOUNT` | storage account del state |
| `TFSTATE_CONTAINER` | `tfstate` |

Los workflows no seleccionan GitHub environments ni usan identidades con
permisos de escritura. Todos los planes usan exclusivamente el
`AZURE_CLIENT_ID` de solo lectura configurado en el repositorio.

### 3. Primera validacion

Abre un PR con cualquier cambio en `infra/`. El workflow **TF plan (PR)** detecta
las fases afectadas, planifica cada una contra dev y comenta el resultado.

Al mezclar a `main`, **TF validation (main)** valida las 8 fases en dev y prod.
Los planes usan la identidad de solo lectura y nunca se aplican.

## Trabajo local

```bash
cat > .env <<'ENV'
ARM_SUBSCRIPTION_ID=...
TFSTATE_RESOURCE_GROUP=rg-itsm-tfstate-eastus2
TFSTATE_STORAGE_ACCOUNT=stitsmtfstate...
TFSTATE_CONTAINER=tfstate
ENV

az login
make check                                  # fmt, validate, tflint, sync
./scripts/tf.sh 10-network-hub dev plan
```

En Windows:

```powershell
./scripts/tf.ps1 10-network-hub dev plan
```

`.env` esta en `.gitignore`. No contiene secretos: la autenticacion sale de
`az login`.

## Operaciones frecuentes

### Validar una sola fase

Actions > **TF validar fase individual** > Run workflow. Elige fase y entorno.
Ejecuta todas las comprobaciones y genera un plan que no se aplica.

### Encender un servicio de costo alto

1. Implementa los `TODO` del `main.tf` de la fase.
2. Cambia el `enable_*` correspondiente en `infra/phases/<fase>/tfvars/<env>.tfvars`.
3. Abre PR y revisa el plan con atencion al costo.

Si enciendes el flag sin implementar el recurso, el plan falla con un mensaje
explicito. Es deliberado.

### El plan quiere destruir algo que no esperabas

Para. Revisa si cambio un nombre: casi todos los recursos de Azure se reemplazan
al renombrarse. Si el cambio de nombre es intencional, dilo en el PR. Si no lo
es, revierte el nombre.

### El state quedo bloqueado

Un job cancelado a mitad de un apply puede dejar el lease del blob tomado.

```bash
./scripts/tf.sh <fase> <env> force-unlock <lock-id>
```

El ID aparece en el mensaje de error. No lo hagas si hay un apply corriendo de
verdad: comprueba primero en Actions.

### Deriva detectada

El workflow diario **TF deteccion de deriva** planifica todo con la identidad de
solo lectura y abre una incidencia si algo cambio. Dos salidas posibles:

- El cambio en Azure es legitimo: incorporalo al codigo.
- No lo es: reaplica la fase y vuelve a la realidad descrita en el repositorio.

### Recuperar un state corrupto

La storage account tiene versionado y soft delete de 30 dias.

```bash
az storage blob list --account-name <sa> --container-name tfstate \
  --include v --auth-mode login -o table
az storage blob copy start --account-name <sa> --destination-container tfstate \
  --destination-blob "<fase>/<env>.tfstate" \
  --source-uri "<url-de-la-version>" --auth-mode login
```

## Destruir un entorno

La destruccion desde GitHub Actions esta deshabilitada. **TF validar entorno**
solo comprueba todas las fases y genera planes de lectura; no ejecuta destroy.

## Que no cubre este repositorio

El andamiaje llega hasta la infraestructura. Fuera de alcance, por diseno:

- **Manifiestos de Kubernetes**: van en un repositorio aparte que reconcilia Flux
  (seccion 9 del diseno). Terraform crea el cluster; Flux lo llena.
- **Codigo de los microservicios** y sus pipelines de build, firma y SBOM.
- **Configuracion de Entra External ID**: user flows, branding y atributos de
  extension se gestionan por separado.
- **Migraciones de base de datos**: corren como Job de Kubernetes previo al
  rollout, con estrategia expand/contract.

# Atajos para trabajo local. En Windows usa scripts/tf.ps1 directamente.
SHELL := /bin/bash
PHASES := $(notdir $(wildcard infra/phases/*))
ENV ?= dev
PHASE ?= 00-foundation

.PHONY: help
help: ## Muestra esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

.PHONY: phases
phases: ## Lista las fases disponibles
	@printf '%s\n' $(PHASES)

.PHONY: sync-common
sync-common: ## Propaga infra/shared/variables.common.tf a todas las fases
	@./scripts/sync-common.sh

.PHONY: check-common
check-common: ## Verifica que ninguna copia de variables.common.tf quedo desincronizada
	@./scripts/sync-common.sh --check

.PHONY: fmt
fmt: ## Formatea todo el Terraform del repositorio
	@terraform fmt -recursive infra

.PHONY: fmt-check
fmt-check: ## Falla si algo no esta formateado
	@terraform fmt -check -recursive -diff infra

.PHONY: validate
validate: ## terraform validate en todas las fases (sin backend)
	@for p in $(PHASES); do \
	  echo "== $$p"; \
	  terraform -chdir=infra/phases/$$p init -backend=false -input=false -no-color >/dev/null || exit 1; \
	  terraform -chdir=infra/phases/$$p validate -no-color || exit 1; \
	done

.PHONY: lint
lint: ## tflint sobre todas las fases
	@tflint --init --config="$$PWD/policy/.tflint.hcl"
	@for p in $(PHASES); do \
	  echo "== $$p"; \
	  tflint --config="$$PWD/policy/.tflint.hcl" --chdir=infra/phases/$$p --format compact || exit 1; \
	done

.PHONY: plan
plan: ## terraform plan de una fase: make plan PHASE=10-network-hub ENV=dev
	@./scripts/tf.sh $(PHASE) $(ENV) plan

.PHONY: apply
apply: ## terraform apply de una fase
	@./scripts/tf.sh $(PHASE) $(ENV) apply

.PHONY: output
output: ## Outputs de una fase
	@./scripts/tf.sh $(PHASE) $(ENV) output

.PHONY: check
check: check-common fmt-check validate lint ## Todo lo que corre CI antes del plan

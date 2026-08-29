# ==============================================================================
# Homelab Terraform & Kubernetes Infrastructure Automation Makefile
# ==============================================================================
# Provides standard developer workflows, multi-stage lifecycle commands,
# verification tooling, and quality gates for contributors.
# ==============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Paths
STAGE1_DIR := terraform/environments/01-nested-sandbox
STAGE2_DIR := terraform/environments/02-k8s-cluster
STAGE3_DIR := terraform/environments/03-k8s-bootstrap
SCRIPTS_DIR := scripts

# Colors
BLUE   := \033[36m
GREEN  := \033[32m
YELLOW := \033[33m
RESET  := \033[0m

##@ 📖 Help & Documentation

.PHONY: help
help: ## Display this interactive help menu
	@echo -e "$(BLUE)==============================================================================$(RESET)"
	@echo -e "$(BLUE)     Homelab Terraform & Kubernetes Infrastructure Workflow Targets           $(RESET)"
	@echo -e "$(BLUE)==============================================================================$(RESET)"
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""

##@ 🏗️ Stage 1: Nested Sandbox Hypervisor (01-nested-sandbox)

.PHONY: stage1-init
stage1-init: ## Initialize Terraform/OpenTofu providers for Stage 1
	@echo -e "$(GREEN)===> Initializing Stage 1 Nested Sandbox workspace...$(RESET)"
	terraform -chdir=$(STAGE1_DIR) init

.PHONY: stage1-plan
stage1-plan: ## Generate and review execution plan for Stage 1
	@echo -e "$(GREEN)===> Planning Stage 1 Nested Sandbox infrastructure...$(RESET)"
	terraform -chdir=$(STAGE1_DIR) plan

.PHONY: stage1-apply
stage1-apply: ## Provision Stage 1 Nested Sandbox VM hypervisor
	@echo -e "$(GREEN)===> Applying Stage 1 Nested Sandbox infrastructure...$(RESET)"
	terraform -chdir=$(STAGE1_DIR) apply

.PHONY: stage1-destroy
stage1-destroy: ## Destroy Stage 1 Nested Sandbox infrastructure
	@echo -e "$(YELLOW)===> Destroying Stage 1 Nested Sandbox infrastructure...$(RESET)"
	terraform -chdir=$(STAGE1_DIR) destroy

##@ 🚀 Stage 2: Downstream K8s Cluster & NAT VPC (02-k8s-cluster)

.PHONY: stage2-init
stage2-init: ## Initialize Terraform/OpenTofu providers for Stage 2
	@echo -e "$(GREEN)===> Initializing Stage 2 Kubernetes Cluster workspace...$(RESET)"
	terraform -chdir=$(STAGE2_DIR) init

.PHONY: stage2-plan
stage2-plan: ## Generate and review execution plan for Stage 2
	@echo -e "$(GREEN)===> Planning Stage 2 Kubernetes Cluster infrastructure...$(RESET)"
	terraform -chdir=$(STAGE2_DIR) plan

.PHONY: stage2-apply
stage2-apply: ## Provision Stage 2 K8s VMs, host keys, and ingress workload
	@echo -e "$(GREEN)===> Applying Stage 2 Kubernetes Cluster infrastructure...$(RESET)"
	terraform -chdir=$(STAGE2_DIR) apply

.PHONY: stage2-destroy
stage2-destroy: ## Destroy Stage 2 Kubernetes Cluster infrastructure
	@echo -e "$(YELLOW)===> Destroying Stage 2 Kubernetes Cluster infrastructure...$(RESET)"
	terraform -chdir=$(STAGE2_DIR) destroy

##@ ⚙️ Stage 3: Automated K3s Distribution Bootstrap (03-k8s-bootstrap)

.PHONY: stage3-init
stage3-init: ## Initialize Terraform/OpenTofu providers for Stage 3
	@echo -e "$(GREEN)===> Initializing Stage 3 K3s Bootstrap workspace...$(RESET)"
	terraform -chdir=$(STAGE3_DIR) init

.PHONY: stage3-plan
stage3-plan: ## Generate and review execution plan for Stage 3
	@echo -e "$(GREEN)===> Planning Stage 3 K3s Bootstrap infrastructure...$(RESET)"
	terraform -chdir=$(STAGE3_DIR) plan

.PHONY: stage3-apply
stage3-apply: ## Bootstrap K3s cluster, join workers, and extract kubeconfig
	@echo -e "$(GREEN)===> Applying Stage 3 K3s Bootstrap infrastructure...$(RESET)"
	terraform -chdir=$(STAGE3_DIR) apply

.PHONY: stage3-destroy
stage3-destroy: ## Reset K3s cluster state across control plane and workers
	@echo -e "$(YELLOW)===> Destroying Stage 3 K3s Bootstrap state...$(RESET)"
	terraform -chdir=$(STAGE3_DIR) destroy

##@ 🔍 Automated Verification & Auditing

.PHONY: verify-stage1
verify-stage1: ## Run non-destructive read-only audit of hypervisor host (ADR 004)
	@echo -e "$(GREEN)===> Auditing Stage 1 Hypervisor host prerequisites...$(RESET)"
	@if [ -f "$(SCRIPTS_DIR)/bootstrap-host.sh" ]; then \
		./$(SCRIPTS_DIR)/bootstrap-host.sh --check; \
	fi

.PHONY: verify-stage2
verify-stage2: ## Run automated health, SSH, and ingress checks on Stage 2 (ADRs 006, 007, 008)
	@echo -e "$(GREEN)===> Verifying Stage 2 Kubernetes Cluster infrastructure...$(RESET)"
	python3 $(SCRIPTS_DIR)/verify_stage2.py --check

.PHONY: verify-stage3
verify-stage3: ## Run automated validation checks on Stage 3 K3s bootstrap (ADR 009)
	@echo -e "$(GREEN)===> Verifying Stage 3 Kubernetes Distribution Bootstrap...$(RESET)"
	python3 $(SCRIPTS_DIR)/verify_stage3.py

##@ 🧹 Code Quality, Linting & Formatting

.PHONY: lint
lint: ## Run all pre-commit quality gates, gitleaks, and terraform validate
	@echo -e "$(GREEN)===> Running pre-commit hooks and validation suite...$(RESET)"
	pre-commit run --all-files

.PHONY: fmt
fmt: ## Automatically format all Terraform and HCL files
	@echo -e "$(GREEN)===> Formatting Terraform manifests...$(RESET)"
	terraform fmt -recursive

.PHONY: docs
docs: ## Generate and update Terraform documentation tables
	@echo -e "$(GREEN)===> Generating Terraform documentation tables...$(RESET)"
	pre-commit run terraform-docs-stage1 --all-files || true
	pre-commit run terraform-docs-stage2 --all-files || true
	pre-commit run terraform-docs-stage3 --all-files || true

.PHONY: clean
clean: ## Clean up temporary files, pycache, and ephemeral artifacts
	@echo -e "$(YELLOW)===> Cleaning temporary and build artifacts...$(RESET)"
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	find . -type f -name ".terraform.tfstate.lock.info" -delete 2>/dev/null || true
	@echo -e "$(GREEN)Clean complete.$(RESET)"

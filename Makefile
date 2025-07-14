# Talos Proxmox Homelab Makefile
# Provides convenient commands for cluster management

.PHONY: help init plan apply destroy status clean setup-azure setup-keyvault list-keyvault-secrets

# Default target
.DEFAULT_GOAL := help

# Configuration
TERRAFORM_DIR := terraform
OUTPUT_DIR := $(TERRAFORM_DIR)/output
KUBECONFIG_FILE := $(OUTPUT_DIR)/kube-config.yaml
TALOSCONFIG_FILE := $(OUTPUT_DIR)/talos-config.yaml

# Colors for output
BLUE := \033[34m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
NC := \033[0m

define log_info
	@echo "$(BLUE)[INFO]$(NC) $(1)"
endef

define log_success
	@echo "$(GREEN)[SUCCESS]$(NC) $(1)"
endef

define log_warning
	@echo "$(YELLOW)[WARNING]$(NC) $(1)"
endef

define log_error
	@echo "$(RED)[ERROR]$(NC) $(1)"
endef

help: ## Display this help message
	@echo "🏠 Talos Proxmox Homelab Management"
	@echo "=================================="
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "🚀 Quick Start:"
	@echo "  make setup-azure    # Setup Azure backend"
	@echo "  make deploy         # Deploy entire cluster"
	@echo "  make status         # Check cluster health"

setup-azure: ## Setup Azure backend for Terraform state
	$(call log_info,"Setting up Azure backend...")
	@az group create --name homelab-state-rg --location eastus --output none || true
	@az storage account create --name homelabstatestg --resource-group homelab-state-rg --location eastus --sku Standard_LRS --output none || true
	@az storage container create --name tfstate --account-name homelabstatestg --auth-mode login --output none || true
	$(call log_success,"Azure backend configured")

setup-keyvault: ## Setup Azure Key Vault configuration
	$(call log_info,"Setting up Azure Key Vault configuration...")
	@TENANT_ID=$$(az account show --query tenantId -o tsv); \
	OBJECT_ID=$$(az ad signed-in-user show --query id -o tsv); \
	echo "Azure Tenant ID: $$TENANT_ID"; \
	echo "Azure Object ID: $$OBJECT_ID"; \
	echo "Add these to your terraform.tfvars file:"; \
	echo ""; \
	echo "azure = {"; \
	echo "  tenant_id = \"$$TENANT_ID\""; \
	echo "  object_id = \"$$OBJECT_ID\""; \
	echo "  location  = \"East US\""; \
	echo "}"; \
	echo ""; \
	echo "enable_keyvault = true"
	$(call log_success,"Key Vault configuration ready")

list-keyvault-secrets: ## List secrets in Azure Key Vault
	$(call log_info,"Listing Azure Key Vault secrets...")
	@VAULT_NAME=$$(cd $(TERRAFORM_DIR) && terraform output -raw keyvault_info 2>/dev/null | jq -r '.vault_name' 2>/dev/null); \
	if [ "$$VAULT_NAME" != "null" ] && [ -n "$$VAULT_NAME" ]; then \
		az keyvault secret list --vault-name "$$VAULT_NAME" --query "[].name" -o table; \
	else \
		echo "Key Vault not found or not deployed"; \
	fi

init: ## Initialize Terraform
	$(call log_info,"Initializing Terraform...")
	@cd $(TERRAFORM_DIR) && terraform init
	$(call log_success,"Terraform initialized")

validate: init ## Validate Terraform configuration
	$(call log_info,"Validating Terraform configuration...")
	@cd $(TERRAFORM_DIR) && terraform validate
	$(call log_success,"Configuration is valid")

plan: validate ## Plan Terraform deployment
	$(call log_info,"Planning infrastructure deployment...")
	@cd $(TERRAFORM_DIR) && terraform plan -out=tfplan
	$(call log_success,"Plan generated successfully")

apply: ## Apply Terraform configuration
	$(call log_info,"Applying infrastructure deployment...")
	@cd $(TERRAFORM_DIR) && terraform apply -auto-approve
	$(call log_success,"Infrastructure deployed")

deploy: setup-azure setup-keyvault apply configure-access wait-ready verify ## Full deployment pipeline
	$(call log_success,"🎉 Complete deployment finished!")

configure-access: ## Configure kubectl and talosctl access
	$(call log_info,"Configuring cluster access...")
	@mkdir -p $(OUTPUT_DIR)
	@if [ -f "$(KUBECONFIG_FILE)" ]; then \
		export KUBECONFIG="$(PWD)/$(KUBECONFIG_FILE)"; \
		echo "export KUBECONFIG=\"$(PWD)/$(KUBECONFIG_FILE)\"" >> ~/.bashrc; \
	fi
	@if [ -f "$(TALOSCONFIG_FILE)" ]; then \
		export TALOSCONFIG="$(PWD)/$(TALOSCONFIG_FILE)"; \
		echo "export TALOSCONFIG=\"$(PWD)/$(TALOSCONFIG_FILE)\"" >> ~/.bashrc; \
	fi
	$(call log_success,"Cluster access configured")

wait-ready: ## Wait for cluster to be ready
	$(call log_info,"Waiting for cluster to be ready...")
	@export KUBECONFIG="$(PWD)/$(KUBECONFIG_FILE)" && \
	for i in {1..60}; do \
		if kubectl get nodes >/dev/null 2>&1; then \
			ready_nodes=$$(kubectl get nodes --no-headers | grep " Ready " | wc -l); \
			total_nodes=$$(kubectl get nodes --no-headers | wc -l); \
			if [ "$$ready_nodes" -eq "$$total_nodes" ] && [ "$$total_nodes" -gt 0 ]; then \
				echo "$(GREEN)[SUCCESS]$(NC) All nodes ready ($$ready_nodes/$$total_nodes)"; \
				break; \
			else \
				echo "$(BLUE)[INFO]$(NC) Nodes ready: $$ready_nodes/$$total_nodes"; \
			fi; \
		else \
			echo "$(BLUE)[INFO]$(NC) Waiting for Kubernetes API... (attempt $$i/60)"; \
		fi; \
		sleep 10; \
	done

verify: ## Verify cluster health
	$(call log_info,"Verifying cluster health...")
	@export KUBECONFIG="$(PWD)/$(KUBECONFIG_FILE)" && \
	export TALOSCONFIG="$(PWD)/$(TALOSCONFIG_FILE)" && \
	echo "$(BLUE)Kubernetes Nodes:$(NC)" && \
	kubectl get nodes && \
	echo "" && \
	echo "$(BLUE)System Pods:$(NC)" && \
	kubectl get pods -n kube-system && \
	echo "" && \
	echo "$(BLUE)Talos Health:$(NC)" && \
	talosctl health || true && \
	echo "" && \
	echo "$(BLUE)Cilium Status:$(NC)" && \
	cilium status || true

status: ## Show comprehensive cluster status
	$(call log_info,"Gathering cluster status...")
	@export KUBECONFIG="$(PWD)/$(KUBECONFIG_FILE)" && \
	export TALOSCONFIG="$(PWD)/$(TALOSCONFIG_FILE)" && \
	echo "🏠 $(GREEN)Homelab Cluster Status$(NC)" && \
	echo "=========================" && \
	echo "" && \
	echo "$(BLUE)📋 Cluster Info:$(NC)" && \
	echo "Endpoint: $$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || echo 'Not available')" && \
	echo "Nodes: $$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo '0') total, $$(kubectl get nodes --no-headers 2>/dev/null | grep ' Ready ' | wc -l || echo '0') ready" && \
	echo "" && \
	echo "$(BLUE)🖥️  Nodes:$(NC)" && \
	kubectl get nodes -o wide 2>/dev/null || echo "Cluster not accessible" && \
	echo "" && \
	echo "$(BLUE)🚀 System Pods:$(NC)" && \
	kubectl get pods -n kube-system 2>/dev/null || echo "Cluster not accessible" && \
	echo "" && \
	echo "$(BLUE)🌐 Network (Cilium):$(NC)" && \
	cilium status 2>/dev/null || echo "Cilium not accessible" && \
	echo "" && \
	echo "$(BLUE)📊 Talos Health:$(NC)" && \
	talosctl health 2>/dev/null || echo "Talos not accessible"

logs: ## Show recent logs from key components
	$(call log_info,"Fetching recent logs...")
	@export KUBECONFIG="$(PWD)/$(KUBECONFIG_FILE)" && \
	echo "$(BLUE)Cilium Operator Logs:$(NC)" && \
	kubectl logs -n kube-system -l name=cilium-operator --tail=10 || true && \
	echo "" && \
	echo "$(BLUE)CoreDNS Logs:$(NC)" && \
	kubectl logs -n kube-system -l k8s-app=kube-dns --tail=10 || true

shell: configure-access ## Open shell with cluster access configured
	$(call log_info,"Opening shell with cluster access...")
	@export KUBECONFIG="$(PWD)/$(KUBECONFIG_FILE)" && \
	export TALOSCONFIG="$(PWD)/$(TALOSCONFIG_FILE)" && \
	bash

upgrade: ## Upgrade Talos cluster (apply with latest versions)
	$(call log_info,"Upgrading cluster...")
	@cd $(TERRAFORM_DIR) && terraform apply -auto-approve
	$(call log_success,"Cluster upgrade completed")

scale-up: ## Add worker node (interactive)
	$(call log_info,"Scaling up cluster...")
	@echo "$(YELLOW)Edit terraform/main.tf to add new worker nodes, then run 'make apply'$(NC)"

destroy: ## Destroy infrastructure (with confirmation)
	$(call log_warning,"⚠️  This will destroy ALL infrastructure!")
	@read -p "Are you sure? Type 'yes' to confirm: " confirm && \
	if [ "$$confirm" = "yes" ]; then \
		cd $(TERRAFORM_DIR) && terraform destroy; \
		$(call log_success,"Infrastructure destroyed"); \
	else \
		echo "$(BLUE)Destruction cancelled$(NC)"; \
	fi

clean: ## Clean up temporary files
	$(call log_info,"Cleaning up temporary files...")
	@cd $(TERRAFORM_DIR) && rm -f tfplan terraform.tfstate.backup .terraform.lock.hcl
	@rm -f $(OUTPUT_DIR)/*.yaml 2>/dev/null || true
	$(call log_success,"Cleanup completed")

reset: destroy clean ## Complete reset (destroy + clean)
	$(call log_success,"Complete reset finished")

dev: ## Setup development environment
	$(call log_info,"Setting up development environment...")
	@code .
	$(call log_info,"Open in DevContainer when prompted")

docs: ## Open documentation
	$(call log_info,"Opening documentation...")
	@echo "📖 Documentation available:"
	@echo "  README-TALOS.md - Complete deployment guide"
	@echo "  terraform/ - Infrastructure code"
	@echo "  kubernetes/ - Application manifests"

# Emergency commands
emergency-kubeconfig: ## Emergency kubeconfig retrieval
	$(call log_info,"Retrieving emergency kubeconfig...")
	@export TALOSCONFIG="$(PWD)/$(TALOSCONFIG_FILE)" && \
	talosctl kubeconfig . --force && \
	$(call log_success,"Kubeconfig retrieved to ./kubeconfig")

emergency-reset-talos: ## Emergency Talos node reset
	$(call log_warning,"⚠️  Emergency Talos reset - USE WITH CAUTION!")
	@export TALOSCONFIG="$(PWD)/$(TALOSCONFIG_FILE)" && \
	read -p "Enter node IP to reset: " node_ip && \
	talosctl reset --nodes $$node_ip --graceful=false

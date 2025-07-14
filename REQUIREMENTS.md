# Talos/Proxmox/Kubernetes Homelab Requirements

## Core Requirements

• Refactor and automate a Talos/Proxmox/Kubernetes homelab deployment using Terraform (no Ansible)
• All secrets/state managed in Azure Key Vault and Storage Account
• Use the official Talos and Proxmox Terraform providers (siderolabs/terraform-provider-talos, bpg/terraform-provider-proxmox)
• Automate initial root password collection to create a Terraform user, API key, and SSH key, then use those for all subsequent runs
• Use Talos Image Factory (https://factory.talos.dev/) for VM templates
• DevContainer must include all required tools (Terraform, Talos, Flux, kubectl, etc.) and work reliably (only one config)
• Cilium for networking https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/ and cli install in devcontainer
• Proxmox network: .10 (Proxmox), .1 (worker), .11 (master), .2-.9 (more workers), .12-.15 (more masters)
• Ceph must be installed and used for Talos ephemeral storage
• Flux cli installed in devcontainer and must be bootstrapped and used to deploy a sample app and cluster platform tools (Istio, Bind9, Cert Manager, security tools, etc.) 
• Directory structure and automation should follow best practices and referenced guides (especially https://blog.stonegarden.dev/articles/2024/08/talos-proxmox-tofu/)
• Remove all files/scripts/configs that do not serve these requirements. Only keep REQUIREMENTS.md and README.md for documentation
• All automation must be testable and actually work (no echo-only scripts)
• I have fast hosts domain hosting for andisoft.co.uk
• I have a udm pro, we should configure dns on there for proxmox, our nodes and any dns bindings like home.andisoft.co.uk for home assistant and internal dns for proxmox.andisoft.co.uk and anything else we need a binding for.
• You should provide instructions and document network configuration I need to apply to the udmpro (which runs on 192.168.1.254)
• You should provide instructions for any DNS A record or similar changes I need to make on fast hosts

## Reference Implementation
Primary reference: https://blog.stonegarden.dev/articles/2024/08/talos-proxmox-tofu/

## Platform tool for kubernetes installed via flux
- Istio
- Cert Manager
- Hashicore vault
- Bind9 or external-dns https://github.com/kubernetes-sigs/external-dns

## Key workload running in AKS installed by flux
- Home Assistant

## Success Criteria
- Single command deployment from clean state
- Fully automated Proxmox → Talos → Kubernetes → Platform Tools → Apps pipeline
- All state and secrets properly managed in Azure
- Ceph storage functional and integrated
- Flux GitOps operational with sample application deployed
- DevContainer reliably provides all required tools
- Only essential files remain (REQUIREMENTS.md, README.md, working configs)
- All tools are configured and home assistant is accessible on home.andisoft.co.uk
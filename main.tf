# Create GitHub App for Flux authentication (only if git_repository is provided)
module "github_app" {
  source = "./modules/github_app"
  count  = var.git_repository != "" && var.github_token != "" ? 1 : 0

  app_name        = var.github_app_name
  repository_name = "proxmox-iac"  # This repository
}

module "proxmox_talos" {
  source = "./modules/proxmox_talos"

  proxmox_node_name = var.proxmox_node_name
  proxmox_admin_endpoint = var.proxmox_admin_endpoint
  proxmox_username = var.proxmox_username
  proxmox_password = var.proxmox_password
  proxmox_insecure = var.proxmox_insecure

  proxmox_vms_default_gateway = var.proxmox_vms_default_gateway
  proxmox_vms_talos = var.proxmox_vms_talos

  # https://factory.talos.dev/
  # For this setup we need system extensions for Proxmox and storage
  # Updated schematic with Talos v1.10.5 including:
  #     systemExtensions:
  #         officialExtensions:
  #             - siderolabs/iscsi-tools
  #             - siderolabs/qemu-guest-agent  
  #             - siderolabs/util-linux-tools
  talos_disk_image_schematic_id = "88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b"
  talos_version = "v1.10.5"

  talos_cluster_name = "k8s-homelab"
  talos_remove_cni = true  # Remove default CNI so we can install Flannel via Terraform
}

# Install Flannel CNI via Terraform for full automation and idempotency
module "flannel" {
  source = "./modules/flannel"
  
  # Now we can use depends_on since provider configurations are at root level
  depends_on = [
    time_sleep.wait_for_cluster,
    local_file.kubeconfig
  ]
}

# Flux GitOps - Bootstrap only, everything else managed by Flux
module "flux" {
  source = "./modules/flux"

  kube_host = module.proxmox_talos.kube_client_config.host
  kube_cluster_ca_certificate = module.proxmox_talos.kube_client_config.ca_certificate
  kube_client_key = module.proxmox_talos.kube_client_config.client_key
  kube_client_certificate = module.proxmox_talos.kube_client_config.client_certificate

  flux_version = "2.4.0"
  git_repository = var.git_repository
  git_branch = var.git_branch
  flux_path = var.flux_path

  # GitHub App credentials (automatically created by Terraform)
  github_app_id = length(module.github_app) > 0 ? module.github_app[0].app_id : var.github_app_id
  github_app_installation_id = length(module.github_app) > 0 ? module.github_app[0].installation_id : var.github_app_installation_id
  github_app_private_key = length(module.github_app) > 0 ? module.github_app[0].private_key_pem : var.github_app_private_key

  depends_on = [
    time_sleep.wait_for_cluster,
    local_file.kubeconfig,
    module.flannel,
    module.github_app
  ]
}

# Save kubeconfig and talosconfig files automatically
# These files are recreated on each apply with fresh certificates
resource "local_file" "kubeconfig" {
  content  = module.proxmox_talos.kube_config
  filename = "${path.root}/kubeconfig.yaml"
  
  # Ensure the file is updated when cluster config changes
  depends_on = [module.proxmox_talos]
}

resource "local_file" "talosconfig" {
  content  = module.proxmox_talos.talos_config
  filename = "${path.root}/talosconfig.yaml"
  
  # Ensure the file is updated when cluster config changes  
  depends_on = [module.proxmox_talos]
}

# Add a delay to allow cluster to fully boot and API server to become ready
resource "time_sleep" "wait_for_cluster" {
  depends_on = [
    local_file.kubeconfig,
    module.proxmox_talos
  ]
  
  create_duration = "3m"  # Wait 3 minutes for cluster to be ready
}

# NOTE: MetalLB and Longhorn moved to Flux management
# This follows the pattern: Terraform for prerequisites, Flux for platform services
# Create these in your GitOps repository under kubernetes/infrastructure/

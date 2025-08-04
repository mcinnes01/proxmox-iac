output "kube_config" {
  value = module.proxmox_talos.kube_config
  sensitive = true
  description = "Kubernetes configuration for cluster access"
}

output "talos_config" {
  value = module.proxmox_talos.talos_config
  sensitive = true
  description = "Talos configuration for cluster management"
}

output "kube_client_config" {
  value = module.proxmox_talos.kube_client_config
  sensitive = true
  description = "Kubernetes client configuration"
}

output "cluster_endpoints" {
  value = {
    kubernetes_api = module.proxmox_talos.kube_client_config.host
    talos_endpoints = var.proxmox_vms_talos
  }
  description = "Cluster connection endpoints"
}

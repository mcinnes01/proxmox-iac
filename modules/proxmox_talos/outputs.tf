output "talos_config" {
  value = data.talos_client_configuration.this.talos_config
  sensitive = true
  description = "Talos configuration for cluster management"
}

output "kube_config" {
  value = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive = true
  description = "Kubernetes configuration for cluster access"
}

output "kube_client_config" { 
  value = talos_cluster_kubeconfig.kubeconfig.kubernetes_client_configuration  
  sensitive = true
  description = "Kubernetes client configuration"
}

output "cluster_endpoints" {
  value = {
    control_plane_ips = local.controller_vm_ips
    worker_ips = local.worker_vm_ips
    cluster_endpoint = "https://${local.controller_vm_ips[0]}:6443"
  }
  description = "Cluster endpoint information"
}

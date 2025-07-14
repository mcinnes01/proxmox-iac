# Output the generated configuration files to local files
resource "local_file" "machine_configs" {
  for_each        = module.talos.machine_config
  content         = each.value.machine_configuration
  filename        = "output/talos-machine-config-${each.key}.yaml"
  file_permission = "0600"
}

resource "local_file" "talos_config" {
  content         = module.talos.client_configuration.talos_config
  filename        = "output/talos-config.yaml"
  file_permission = "0600"
}

resource "local_file" "kube_config" {
  content         = module.talos.kube_config.kubeconfig_raw
  filename        = "output/kube-config.yaml"
  file_permission = "0600"
}

# Outputs for external access
output "kube_config" {
  description = "Kubernetes configuration for cluster access"
  value       = module.talos.kube_config.kubeconfig_raw
  sensitive   = true
}

output "talos_config" {
  description = "Talos configuration for cluster management"
  value       = module.talos.client_configuration.talos_config
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = module.talos.kube_config.kubernetes_client_configuration.host
}

output "node_ips" {
  description = "IP addresses of all cluster nodes"
  value = {
    control_plane = [for k, v in module.talos.machine_config : k if contains(["controlplane"], split("-", k)[1])]
    workers       = [for k, v in module.talos.machine_config : k if contains(["worker"], split("-", k)[1])]
  }
}

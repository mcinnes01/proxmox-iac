output "client_configuration" {
  description = "Talos client configuration for talosctl"
  value       = data.talos_client_configuration.this
  sensitive   = true
}

output "kube_config" {
  description = "Kubernetes cluster configuration"
  value       = data.talos_cluster_kubeconfig.this
  sensitive   = true
}

output "machine_config" {
  description = "Talos machine configurations for all nodes"
  value       = data.talos_machine_configuration.this
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = var.cluster.endpoint
}

output "node_ips" {
  description = "Node IP addresses by type"
  value = {
    control_plane = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"]
    workers       = [for k, v in var.nodes : v.ip if v.machine_type == "worker"]
  }
}

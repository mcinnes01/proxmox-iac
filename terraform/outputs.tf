# Output configuration files for cluster access
resource "local_file" "talos_config" {
  content  = data.talos_client_configuration.cluster_client_config.talos_config
  filename = "${path.module}/output/talos-config.yaml"
  
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/output && chmod 600 ${path.module}/output/talos-config.yaml"
  }
}

resource "local_file" "kube_config" {
  content  = talos_cluster_kubeconfig.cluster_kubeconfig.kubeconfig_raw
  filename = "${path.module}/output/kube-config.yaml"
  
  provisioner "local-exec" {
    command = "chmod 600 ${path.module}/output/kube-config.yaml"
  }
}

# Save machine configurations for reference
resource "local_file" "control_plane_config" {
  for_each = var.control_plane_nodes
  content  = data.talos_machine_configuration.control_plane.machine_configuration
  filename = "${path.module}/output/machine-config-${each.key}.yaml"
}

resource "local_file" "worker_config" {
  for_each = var.worker_nodes
  content  = data.talos_machine_configuration.worker[each.key].machine_configuration
  filename = "${path.module}/output/machine-config-${each.key}.yaml"
}

# Output cluster information
output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = "https://${var.cluster_endpoint}:6443"
}

output "talos_config_path" {
  description = "Path to talos configuration file"
  value       = local_file.talos_config.filename
}

output "kube_config_path" {
  description = "Path to kubernetes configuration file"
  value       = local_file.kube_config.filename
}

output "node_ips" {
  description = "IP addresses of cluster nodes"
  value = {
    control_plane = [for k, v in var.control_plane_nodes : v.ip_address]
    workers       = [for k, v in var.worker_nodes : v.ip_address]
  }
}

output "cluster_info" {
  description = "Cluster connection information"
  value = {
    cluster_name     = var.cluster_name
    cluster_endpoint = var.cluster_endpoint
    node_count = {
      control_plane = length(var.control_plane_nodes)
      workers       = length(var.worker_nodes)
    }
  }
}

output "dns_records_needed" {
  description = "DNS records that need to be configured"
  value = {
    internal_dns = merge(
      {
        "proxmox.${var.internal_domain}" = "192.168.1.10"
      },
      {
        for k, v in var.control_plane_nodes : "${k}.${var.internal_domain}" => v.ip_address
      }
    )
    external_dns = {
      "home.${var.domain_name}" = var.worker_nodes["talos-worker-01"].ip_address
    }
  }
}

output "next_steps" {
  description = "Next steps after infrastructure deployment"
  value = [
    "1. Configure DNS records as shown in 'dns_records_needed' output",
    "2. Export cluster configs: export KUBECONFIG=${local_file.kube_config.filename}",
    "3. Export Talos config: export TALOSCONFIG=${local_file.talos_config.filename}",
    "4. Verify cluster: kubectl get nodes",
    "5. Bootstrap Flux: flux bootstrap github --owner=mcinnes01 --repository=proxmox-iac --branch=main --path=./kubernetes"
  ]
}

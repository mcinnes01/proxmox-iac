# Generate machine secrets for the cluster
resource "talos_machine_secrets" "this" {
  talos_version = var.cluster.talos_version
}

# Generate client configuration for talosctl
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster.name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [for k, v in var.nodes : v.ip]
  endpoints            = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"]
}

# Generate machine configurations for each node
data "talos_machine_configuration" "this" {
  for_each         = var.nodes
  cluster_name     = var.cluster.name
  cluster_endpoint = "https://${var.cluster.endpoint}:6443"
  talos_version    = var.cluster.talos_version
  machine_type     = each.value.machine_type
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  
  config_patches = each.value.machine_type == "controlplane" ? [
    templatefile("${path.module}/machine-config/control-plane.yaml.tftpl", {
      hostname       = each.key
      node_name      = each.value.host_node
      cluster_name   = var.cluster.proxmox_cluster
      cilium_values  = var.cilium.values
      cilium_install = var.cilium.install
    })
  ] : [
    templatefile("${path.module}/machine-config/worker.yaml.tftpl", {
      hostname     = each.key
      node_name    = each.value.host_node
      cluster_name = var.cluster.proxmox_cluster
    })
  ]
}

# Apply machine configuration to each node
resource "talos_machine_configuration_apply" "this" {
  depends_on = [proxmox_virtual_environment_vm.this]
  for_each                    = var.nodes
  node                        = each.value.ip
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
  
  lifecycle {
    # Re-run config apply if VM changes
    replace_triggered_by = [proxmox_virtual_environment_vm.this[each.key]]
  }
}

# Bootstrap the cluster (only run on first control plane node)
resource "talos_machine_bootstrap" "this" {
  node                 = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"][0]
  endpoint             = var.cluster.endpoint
  client_configuration = talos_machine_secrets.this.client_configuration
}

# Wait for cluster to be healthy
data "talos_cluster_health" "this" {
  depends_on = [
    talos_machine_configuration_apply.this,
    talos_machine_bootstrap.this
  ]
  client_configuration = data.talos_client_configuration.this.client_configuration
  control_plane_nodes  = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"]
  worker_nodes         = [for k, v in var.nodes : v.ip if v.machine_type == "worker"]
  endpoints            = data.talos_client_configuration.this.endpoints
  timeouts = {
    read = "10m"
  }
}

# Get cluster kubeconfig
data "talos_cluster_kubeconfig" "this" {
  depends_on = [
    talos_machine_bootstrap.this,
    data.talos_cluster_health.this
  ]
  node                 = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"][0]
  endpoint             = var.cluster.endpoint
  client_configuration = talos_machine_secrets.this.client_configuration
  timeouts = {
    read = "1m"
  }
}

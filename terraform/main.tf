# Generate Talos image URLs using Image Factory
module "talos_image_factory" {
  source = "github.com/jhulndev/terraform-talos-image-factory"

  # Specify exact Talos version
  talos_version_spec = {
    number = var.talos_version
  }

  # Add the qemu agent extension so you can access the VM IP
  find_extensions = ["qemu-guest-agent"]

  # Use `nocloud` so that cloud-init can be used
  platform = "nocloud"
}

# Download Talos Linux image to Proxmox using Image Factory URL
resource "proxmox_virtual_environment_download_file" "talos_image" {
  content_type = "iso"
  datastore_id = "local"  # Use local for ISO files
  file_name    = "talos-${var.talos_version}.img"
  node_name    = var.proxmox_node
  url          = module.talos_image_factory.urls.disk_image
  
  # This seems to be safe to use for the disk_image urls even if it doesn't
  # have the .zst extension.
  decompression_algorithm = "zst"
  
  # The filesize will change because it is decompressed, causing a replacement
  # if this isn't set to false.
  overwrite        = false
  overwrite_unmanaged = false
  upload_timeout   = 1800
  verify          = true
}

# Generate machine secrets for cluster
resource "talos_machine_secrets" "cluster_secrets" {}

# Generate machine configurations
data "talos_machine_configuration" "control_plane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.cluster_endpoint}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.cluster_secrets.machine_secrets
  
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/vda"
          image = "factory.talos.dev/installer/${module.talos_image_factory.schematic.id}:${var.talos_version}"
        }
        network = {
          hostname = "talos-cp-01"
          interfaces = [{
            interface = "eth0"
            dhcp      = false
            addresses = ["${var.control_plane_nodes["talos-cp-01"].ip_address}/24"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = var.network_gateway
            }]
          }]
          nameservers = [var.nameserver]
        }
        time = {
          servers = ["pool.ntp.org"]
        }
      }
      cluster = {
        allowSchedulingOnControlPlanes = false
        network = {
          cni = {
            name = "none"  # We'll install Cilium manually
          }
        }
      }
    })
  ]
}

data "talos_machine_configuration" "worker" {
  for_each         = var.worker_nodes
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.cluster_endpoint}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.cluster_secrets.machine_secrets
  
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/vda"
          image = "factory.talos.dev/installer/${module.talos_image_factory.schematic.id}:${var.talos_version}"
        }
        network = {
          hostname = each.key
          interfaces = [{
            interface = "eth0"
            dhcp      = false
            addresses = ["${each.value.ip_address}/24"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = var.network_gateway
            }]
          }]
          nameservers = [var.nameserver]
        }
        time = {
          servers = ["pool.ntp.org"]
        }
      }
    })
  ]
}

# Create control plane VMs
resource "proxmox_virtual_environment_vm" "control_plane" {
  for_each    = var.control_plane_nodes
  name        = each.key
  description = "Talos control plane node"
  node_name   = var.proxmox_node
  vm_id       = each.value.vm_id
  
  agent {
    enabled = true
  }
  
  cpu {
    cores = each.value.cpu_cores
    type  = "x86-64-v2-AES"
  }
  
  memory {
    dedicated = each.value.memory_mb
  }
  
  network_device {
    bridge      = "vmbr0"
    mac_address = each.value.mac_address
  }
  
  disk {
    datastore_id = var.vm_datastore
    file_id      = proxmox_virtual_environment_download_file.talos_image.id
    interface    = "virtio0"
    size         = each.value.disk_size_gb
  }
  
  initialization {
    user_data_file_id = proxmox_virtual_environment_file.control_plane_userdata[each.key].id
  }
  
  operating_system {
    type = "l26"
  }
  
  serial_device {}
  
  startup {
    order      = 1
    up_delay   = 30
    down_delay = 30
  }
}

# Create worker VMs
resource "proxmox_virtual_environment_vm" "worker" {
  for_each    = var.worker_nodes
  name        = each.key
  description = "Talos worker node"
  node_name   = var.proxmox_node
  vm_id       = each.value.vm_id
  
  agent {
    enabled = true
  }
  
  cpu {
    cores = each.value.cpu_cores
    type  = "x86-64-v2-AES"
  }
  
  memory {
    dedicated = each.value.memory_mb
  }
  
  network_device {
    bridge      = "vmbr0"
    mac_address = each.value.mac_address
  }
  
  disk {
    datastore_id = var.vm_datastore
    file_id      = proxmox_virtual_environment_download_file.talos_image.id
    interface    = "virtio0"
    size         = each.value.disk_size_gb
  }
  
  initialization {
    user_data_file_id = proxmox_virtual_environment_file.worker_userdata[each.key].id
  }
  
  operating_system {
    type = "l26"
  }
  
  serial_device {}
  
  startup {
    order      = 2
    up_delay   = 30
    down_delay = 30
  }
}

# Upload machine configurations as cloud-init userdata
resource "proxmox_virtual_environment_file" "control_plane_userdata" {
  for_each     = var.control_plane_nodes
  content_type = "snippets"
  datastore_id = "local"  # Use local for snippets
  node_name    = var.proxmox_node
  
  source_raw {
    data      = data.talos_machine_configuration.control_plane.machine_configuration
    file_name = "${each.key}-userdata.yaml"
  }
}

resource "proxmox_virtual_environment_file" "worker_userdata" {
  for_each     = var.worker_nodes
  content_type = "snippets"
  datastore_id = "local"  # Use local for snippets
  node_name    = var.proxmox_node
  
  source_raw {
    data      = data.talos_machine_configuration.worker[each.key].machine_configuration
    file_name = "${each.key}-userdata.yaml"
  }
}

# Bootstrap Talos cluster
resource "talos_machine_bootstrap" "cluster_bootstrap" {
  depends_on = [
    proxmox_virtual_environment_vm.control_plane
  ]
  client_configuration = talos_machine_secrets.cluster_secrets.client_configuration
  node                = var.cluster_endpoint
}

# Generate cluster configuration
resource "talos_cluster_kubeconfig" "cluster_kubeconfig" {
  depends_on = [
    talos_machine_bootstrap.cluster_bootstrap
  ]
  client_configuration = talos_machine_secrets.cluster_secrets.client_configuration
  node                = var.cluster_endpoint
}

# Generate client configuration for talosctl
data "talos_client_configuration" "cluster_client_config" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster_secrets.client_configuration
  endpoints            = [for node in var.control_plane_nodes : node.ip_address]
}

# Create Cilium installation manifest
locals {
  cilium_install_manifest = yamlencode({
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "cilium-install"
      namespace = "kube-system"
    }
    data = {
      "values.yaml" = file("${path.module}/../kubernetes/cilium/values.yaml")
    }
  })
}

# Apply Cilium via Talos inline manifests
resource "talos_machine_configuration_apply" "control_plane" {
  depends_on = [talos_machine_bootstrap.cluster_bootstrap]
  
  client_configuration        = talos_machine_secrets.cluster_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane.machine_configuration
  node                       = var.cluster_endpoint
  config_patches = [
    yamlencode({
      cluster = {
        inlineManifests = [
          {
            name     = "cilium-install"
            contents = local.cilium_install_manifest
          }
        ]
      }
    })
  ]
}

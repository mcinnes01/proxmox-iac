terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.74.1"
    }
    talos = {
      source = "siderolabs/talos"
      version = "0.7.1"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_admin_endpoint
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = var.proxmox_insecure
}

locals {
  controller_vm_ips = [
    for key, node in var.proxmox_vms_talos : replace(node.ip, "/24", "")
    if node.controller == true
  ]
  worker_vm_ips = [
    for key, node in var.proxmox_vms_talos : replace(node.ip, "/24", "")
    if node.controller != true
  ]

  talos_machine_config_patches = var.talos_remove_cni ? [
    yamlencode({
      cluster = {
        network = {
          cni = {
            name = "none"
          }
        }
      }
    })
  ] : []
}

resource "proxmox_virtual_environment_download_file" "talos_nocloud_image" {
  content_type            = "iso"
  datastore_id            = "local"
  node_name               = var.proxmox_node_name

  file_name               = "talos-${var.talos_version}-nocloud-amd64.iso"
  url                     = "https://factory.talos.dev/image/${var.talos_disk_image_schematic_id}/${var.talos_version}/nocloud-amd64.raw.zst"
  decompression_algorithm = "zst"
  overwrite               = true
  verify                  = false
  upload_timeout          = 1800
}

resource "proxmox_virtual_environment_vm" "talos" {
  for_each        = var.proxmox_vms_talos

  on_boot         = true
  stop_on_destroy = true
  vm_id           = each.value.id
  name            = "${var.talos_cluster_name}-${each.key}"
  node_name       = var.proxmox_node_name
  tags            = sort(["terraform", var.talos_cluster_name])
  bios            = "ovmf"
  machine         = "q35"
  scsi_hardware   = "virtio-scsi-single"
  
  operating_system {
    type = "l26"
  }
  
  cpu {
    type  = "host"
    cores = each.value.cpu_cores
  }
  
  memory {
    dedicated = each.value.memory_mb
  }
  
  network_device {
    bridge = "vmbr0"
  }
  
  efi_disk {
    datastore_id = "storage2"  # Use your new storage
    file_format  = "raw"
    type         = "4m"
  }
  
  disk {
    datastore_id = "storage2"  # Use your new storage
    interface    = "scsi0"
    iothread     = true
    ssd          = true
    discard      = "on"
    size         = each.value.controller == true ? 50 : 40  # Larger disks for controllers
    file_format  = "raw"
    file_id      = proxmox_virtual_environment_download_file.talos_nocloud_image.id
  }
  
  agent {
    enabled = true
    trim    = true
  }
  
  # Increased timeouts for homelab environment
  timeout_create    = 1800  # 30 minutes for VM creation
  timeout_start_vm  = 600   # 10 minutes for VM startup
  timeout_shutdown_vm = 300 # 5 minutes for shutdown
  timeout_stop_vm   = 300   # 5 minutes for stop
  
  initialization {
    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = var.proxmox_vms_default_gateway
      }
    }
  }
}

resource "talos_machine_secrets" "this" {}

data "talos_client_configuration" "this" {
  cluster_name         = var.talos_cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = local.controller_vm_ips
}

data "talos_machine_configuration" "controller" {
  cluster_name     = var.talos_cluster_name
  cluster_endpoint = "https://${local.controller_vm_ips[0]}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  examples         = false
  docs             = false
  config_patches   = local.talos_machine_config_patches
}

data "talos_machine_configuration" "worker" {
  cluster_name     = var.talos_cluster_name
  cluster_endpoint = "https://${local.controller_vm_ips[0]}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  examples         = false
  docs             = false
  config_patches   = local.talos_machine_config_patches
}

resource "talos_machine_configuration_apply" "controller" {
  depends_on                  = [ proxmox_virtual_environment_vm.talos ]
  for_each                    = toset(local.controller_vm_ips)

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controller.machine_configuration
  node                        = each.value
}

resource "talos_machine_configuration_apply" "worker" {
  depends_on                  = [ proxmox_virtual_environment_vm.talos ]
  for_each                    = toset(local.worker_vm_ips)

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = each.value
}

resource "talos_machine_bootstrap" "this" {
  depends_on           = [
    talos_machine_configuration_apply.controller,
    talos_machine_configuration_apply.worker
  ]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.controller_vm_ips[0]
}

# Note: Commented out health check as it blocks destroy operations
# For production use, consider a null_resource with local-exec for health validation
# data "talos_cluster_health" "this" {
#   depends_on = [ talos_machine_bootstrap.this ]
#
#   client_configuration = data.talos_client_configuration.this.client_configuration
#   control_plane_nodes  = local.controller_vm_ips
#   worker_nodes         = local.worker_vm_ips
#   endpoints            = data.talos_client_configuration.this.endpoints
#   timeouts = {
#     read = "30m"  # Increased timeout for homelab environment - fresh cluster needs more time to initialize
#   }
# }

resource "talos_cluster_kubeconfig" "kubeconfig" {
  # depends_on           = [ data.talos_cluster_health.this ]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.controller_vm_ips[0]
}

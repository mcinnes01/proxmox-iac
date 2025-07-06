resource "macaddress" "k3s-masters" {
  count = var.master_nodes_count
}

resource "random_password" "k3s-server-token" {
  length           = 32
  special          = false
  override_special = "_%@"
}

resource "proxmox_virtual_environment_vm" "k3s-master" {
  depends_on = [proxmox_virtual_environment_vm.k3s-support]

  count     = var.master_nodes_count
  name      = "${var.cluster_name}-master-${count.index}"
  node_name = var.proxmox_node

  # Clone from template
  clone {
    vm_id = proxmox_virtual_environment_vm.ubuntu_template.vm_id
    full  = true
  }

  # Basic VM configuration
  cpu {
    cores = var.master_node_settings.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.master_node_settings.memory
  }

  # Network configuration
  network_device {
    bridge      = var.master_node_settings.network_bridge
    mac_address = upper(macaddress.k3s-masters[count.index].address)
  }

  # Disk configuration
  disk {
    datastore_id = var.master_node_settings.storage_id
    interface    = "scsi0"
    size         = tonumber(trimspace(trimsuffix(var.master_node_settings.disk_size, "G")))
    file_format  = "raw"
  }

  # Cloud-init configuration
  initialization {
    user_account {
      username = var.master_node_settings.user
      password = random_password.k3s-server-token.result
    }

    ip_config {
      ipv4 {
        address = "${cidrhost(var.control_plane_subnet, count.index + 3)}/${tonumber(split("/", var.lan_subnet)[1])}"
        gateway = var.network_gateway
      }
    }

    dns {
      servers = [var.nameserver]
    }
  }

  # VM settings
  operating_system {
    type = "l26"
  }

  # QEMU Guest Agent
  agent {
    enabled = true
  }

  # Boot configuration
  boot_order = ["scsi0"]

  # SCSI hardware
  scsi_hardware = "virtio-scsi-pci"

  # Start VM on boot
  started = true
}

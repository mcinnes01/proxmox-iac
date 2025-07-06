locals {
  support_node_settings = merge(
    {
      cores          = 2
      sockets        = 1
      memory         = 4096
      storage_type   = "scsi"
      storage_id     = "local-lvm"
      disk_size      = "20G"
      user           = "support"
      network_tag    = -1
      db_name        = "k3s"
      db_user        = "k3s"
      network_bridge = "vmbr0"
    },
    var.support_node_settings
  )

  support_node_ip        = "192.168.1.2"
}

# Simple Ubuntu template approach - modify this later to use proper cloud image download
# For now, this creates a basic template that can be used for cloning
resource "proxmox_virtual_environment_vm" "ubuntu_template" {
  name      = var.node_template
  node_name = var.proxmox_node
  vm_id     = 9000
  
  bios     = "seabios"
  machine  = "q35"
  started  = false  # Don't boot the VM
  template = true   # Turn the VM into a template
  
  agent {
    enabled = true
  }
  
  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }
  
  memory {
    dedicated = 2048
    floating  = 2048
  }
  
  # Create basic disk for the template
  disk {
    datastore_id = local.support_node_settings.storage_id
    interface    = "scsi0"
    size         = 8
    file_format  = "raw"
  }
  
  network_device {
    bridge = local.support_node_settings.network_bridge
  }
  
  operating_system {
    type = "l26"
  }
  
  scsi_hardware = "virtio-scsi-pci"
}

resource "macaddress" "k3s-support" {
}

resource "random_password" "support-db-password" {
  length           = 32
  special          = true
  override_special = "_%@"
}

resource "random_password" "k3s-master-db-password" {
  length           = 32
  special          = true
  override_special = "_%@"
}

resource "proxmox_virtual_environment_vm" "k3s-support" {
  depends_on = [proxmox_virtual_environment_vm.ubuntu_template]
  
  name      = join("-", [var.cluster_name, "support"])
  node_name = var.proxmox_node
  
  # Clone from template
  clone {
    vm_id = proxmox_virtual_environment_vm.ubuntu_template.vm_id
    full  = true
  }
  
  # Basic VM configuration
  cpu {
    cores = local.support_node_settings.cores
    type  = "x86-64-v2-AES"
  }
  
  memory {
    dedicated = local.support_node_settings.memory
  }
  
  # Network configuration
  network_device {
    bridge      = local.support_node_settings.network_bridge
    mac_address = upper(macaddress.k3s-support.address)
  }
  
  # Disk configuration
  disk {
    datastore_id = local.support_node_settings.storage_id
    interface    = "scsi0"
    size         = tonumber(trimspace(trimsuffix(local.support_node_settings.disk_size, "G")))
    file_format  = "raw"
  }
  
  # Cloud-init configuration
  initialization {
    user_account {
      username = local.support_node_settings.user
      password = random_password.support-db-password.result
    }
    
    ip_config {
      ipv4 {
        address = "${local.support_node_ip}/${tonumber(split("/", var.lan_subnet)[1])}"
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
  
  # Commented out provisioners to troubleshoot plugin crash
  # connection {
  #   type = "ssh"
  #   user = local.support_node_settings.user
  #   host = local.support_node_ip
  # }

  # provisioner "file" {
  #   destination = "/tmp/install.sh"
  #   content = templatefile("${path.module}/scripts/install-support-apps.sh.tftpl", {
  #     root_password = random_password.support-db-password.result
  #     k3s_database  = local.support_node_settings.db_name
  #     k3s_user      = local.support_node_settings.db_user
  #     k3s_password  = random_password.k3s-master-db-password.result
  #     http_proxy    = var.http_proxy
  #   })
  # }

  # provisioner "remote-exec" {
  #   inline = [
  #     "chmod u+x /tmp/install.sh",
  #     "/tmp/install.sh",
  #     "rm -r /tmp/install.sh",
  #   ]
  # }
}

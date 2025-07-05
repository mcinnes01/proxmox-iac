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

  lan_subnet_cidr_bitnum = tonumber(split("/", var.lan_subnet)[1])
  support_node_ip        = cidrhost(var.control_plane_subnet, 0)
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

resource "proxmox_vm_qemu" "k3s-support" {
  target_node = var.proxmox_node
  name        = join("-", [var.cluster_name, "support"])

  clone = var.node_template

  pool = var.proxmox_resource_pool

  cores   = local.support_node_settings.cores
  sockets = local.support_node_settings.sockets
  memory  = local.support_node_settings.memory

  agent = 1

  disk {
    type    = local.support_node_settings.storage_type
    storage = local.support_node_settings.storage_id
    size    = local.support_node_settings.disk_size
  }

  network {
    bridge    = local.support_node_settings.network_bridge
    firewall  = true
    link_down = false
    macaddr   = upper(macaddress.k3s-support.address)
    model     = "virtio"
    queues    = 0
    rate      = 0
    tag       = local.support_node_settings.network_tag
  }

  lifecycle {
    ignore_changes = [
      ciuser,
      sshkeys,
      disk,
      network
    ]
  }

  os_type = "cloud-init"

  ciuser = local.support_node_settings.user

  ipconfig0 = "ip=${local.support_node_ip}/${local.lan_subnet_cidr_bitnum},gw=${var.network_gateway}"

  nameserver = var.nameserver

  connection {
    type = "ssh"
    user = local.support_node_settings.user
    host = local.support_node_ip
  }

  provisioner "file" {
    destination = "/tmp/install.sh"
    content = templatefile("${path.module}/scripts/install-support-apps.sh.tftpl", {
      root_password = random_password.support-db-password.result
      k3s_database  = local.support_node_settings.db_name
      k3s_user      = local.support_node_settings.db_user
      k3s_password  = random_password.k3s-master-db-password.result
      http_proxy    = var.http_proxy
    })
  }

  provisioner "remote-exec" {
    inline = [
      "chmod u+x /tmp/install.sh",
      "/tmp/install.sh",
      "rm -r /tmp/install.sh",
    ]
  }
}

# Azure Key Vault for Secrets Management
module "azure_keyvault" {
  count  = var.enable_keyvault ? 1 : 0
  source = "./azure-keyvault"

  tenant_id           = var.azure.tenant_id
  object_id           = var.azure.object_id
  location            = var.azure.location
  resource_group_name = "homelab-keyvault-rg"
  key_vault_name      = "homelab-secrets-kv"
  secrets             = var.keyvault_secrets

  tags = {
    Environment = "homelab"
    Purpose     = "talos-cluster-secrets"
    ManagedBy   = "terraform"
  }
}

module "talos" {
  source = "./talos"

  providers = {
    proxmox = proxmox
  }

  image = {
    version   = "v1.10.5"
    schematic = file("${path.module}/talos/image/schematic.yaml")
  }

  cilium = {
    install = file("${path.module}/talos/inline-manifests/cilium-install.yaml")
    values  = file("${path.module}/../kubernetes/cilium/values.yaml")
  }

  cluster = {
    name            = "homelab"
    endpoint        = "192.168.1.2"
    gateway         = "192.168.1.254"
    talos_version   = "v1.10"
    proxmox_cluster = "homelab"
  }

  nodes = {
    "talos-cp-01" = {
      host_node     = "pve"
      machine_type  = "controlplane"
      ip            = "192.168.1.2"
      mac_address   = "BC:24:11:2E:C8:00"
      vm_id         = 800
      cpu           = 4
      ram_dedicated = 8192
    }
    "talos-worker-01" = {
      host_node     = "pve"
      machine_type  = "worker"
      ip            = "192.168.1.3"
      mac_address   = "BC:24:11:2E:C8:01"
      vm_id         = 810
      cpu           = 4
      ram_dedicated = 8192
    }
  }
}

# Optional: Sealed Secrets Bootstrap (commented out - enable if you have certificates)
# module "sealed_secrets" {
#   depends_on = [module.talos]
#   source     = "./bootstrap/sealed-secrets"
#
#   providers = {
#     kubernetes = kubernetes
#   }
#
#   cert = {
#     cert = file("${path.module}/bootstrap/sealed-secrets/certificate/sealed-secrets.cert")
#     key  = file("${path.module}/bootstrap/sealed-secrets/certificate/sealed-secrets.key")
#   }
# }

# Optional: Proxmox CSI Plugin (commented out - enable if needed)
# module "proxmox_csi_plugin" {
#   depends_on = [module.talos]
#   source     = "./bootstrap/proxmox-csi-plugin"
#
#   providers = {
#     proxmox    = proxmox
#     kubernetes = kubernetes
#   }
#
#   proxmox = var.proxmox
# }

# Optional: Volume Management (commented out - enable if needed)
# module "volumes" {
#   depends_on = [module.proxmox_csi_plugin]
#   source     = "./bootstrap/volumes"
#
#   providers = {
#     restapi    = restapi
#     kubernetes = kubernetes
#   }
#
#   proxmox_api = var.proxmox
#
#   volumes = {
#     pv-test = {
#       node = "pve"
#       size = "4G"
#     }
#   }
# }

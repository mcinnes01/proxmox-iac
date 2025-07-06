terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.79.0"
    }

    macaddress = {
      source  = "ivoronin/macaddress"
      version = "0.3.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }

    external = {
      source  = "hashicorp/external"
      version = "~> 2.2"
    }
  }
}

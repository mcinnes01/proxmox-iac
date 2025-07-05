terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = ">= 2.9.14"
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

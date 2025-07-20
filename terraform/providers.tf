terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.7.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token_secret != "" ? "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}" : null
  username  = var.proxmox_username != "" ? var.proxmox_username : null
  password  = var.proxmox_password != "" ? var.proxmox_password : null
  insecure  = var.proxmox_insecure
  ssh {
    agent    = true
    username = "root"
  }
}

provider "talos" {}

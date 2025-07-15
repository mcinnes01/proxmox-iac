terraform {
  required_version = ">= 1.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.7.0"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.66.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "1.20.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.4.5"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.6"
    }
  }

  # Local Backend for State Management
  backend "local" {
    path = "terraform.tfstate"
  }
}

# Proxmox Provider Configuration
provider "proxmox" {
  endpoint = var.proxmox.endpoint
  insecure = var.proxmox.insecure

  # For API token authentication
  username = var.proxmox.username
  api_token = var.proxmox.api_token
}

# Kubernetes Provider Configuration (will be configured by Talos module output)
provider "kubernetes" {
  host                   = try(module.talos.kube_config.kubernetes_client_configuration.host, "")
  client_certificate     = try(base64decode(module.talos.kube_config.kubernetes_client_configuration.client_certificate), "")
  client_key             = try(base64decode(module.talos.kube_config.kubernetes_client_configuration.client_key), "")
  cluster_ca_certificate = try(base64decode(module.talos.kube_config.kubernetes_client_configuration.ca_certificate), "")
}

# REST API Provider for Proxmox API calls
provider "restapi" {
  uri                  = var.proxmox.endpoint
  insecure             = var.proxmox.insecure
  write_returns_object = true

  headers = {
    "Content-Type"  = "application/json"
    "Authorization" = "PVEAPIToken=${var.proxmox.api_token}"
  }
}

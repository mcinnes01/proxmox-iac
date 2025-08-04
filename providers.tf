terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.4.5"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.16.1"
    }
    flux = {
      source  = "fluxcd/flux"
      version = "1.4.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
  required_version = ">= 1.0"
}

# Configure kubernetes provider to connect to the cluster
provider "kubernetes" {
  config_path = "${path.root}/kubeconfig.yaml"
}

provider "kubectl" {
  config_path = "${path.root}/kubeconfig.yaml"
}

provider "helm" {
  kubernetes {
    config_path = "${path.root}/kubeconfig.yaml"
  }
}

# GitHub provider for creating GitHub App
provider "github" {
  token = var.github_token
}

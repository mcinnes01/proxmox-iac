terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.16.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = var.kube_host
    cluster_ca_certificate = base64decode(var.kube_cluster_ca_certificate)
    client_key             = base64decode(var.kube_client_key)
    client_certificate     = base64decode(var.kube_client_certificate)
  }
}

provider "kubernetes" {
  host                   = var.kube_host
  cluster_ca_certificate = base64decode(var.kube_cluster_ca_certificate)
  client_key             = base64decode(var.kube_client_key)
  client_certificate     = base64decode(var.kube_client_certificate)
}

provider "kubectl" {
  load_config_file       = false
  host                   = var.kube_host
  cluster_ca_certificate = base64decode(var.kube_cluster_ca_certificate)
  client_key             = base64decode(var.kube_client_key)
  client_certificate     = base64decode(var.kube_client_certificate)
}

# Only create Flux resources if git_repository is provided
resource "kubernetes_namespace" "flux-system" {
  count = var.git_repository != "" ? 1 : 0
  
  metadata {
    name = "flux-system"
  }
}

resource "helm_release" "flux" {
  count = var.git_repository != "" ? 1 : 0
  depends_on = [ kubernetes_namespace.flux-system ]
  
  name       = "flux2"
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2"
  namespace  = "flux-system"
  version    = var.flux_version

  set {
    name  = "runtime.enabled"
    value = "true"
  }

  set {
    name  = "prometheus.podMonitor.enabled"
    value = "false"
  }
}

# GitRepository resource for Flux
resource "kubectl_manifest" "git_repository" {
  count = var.git_repository != "" ? 1 : 0
  depends_on = [ helm_release.flux ]

  yaml_body = yamlencode({
    apiVersion = "source.toolkit.fluxcd.io/v1"
    kind       = "GitRepository"
    metadata = {
      name      = "homelab-gitops"
      namespace = "flux-system"
    }
    spec = {
      interval = "1m"
      ref = {
        branch = var.git_branch
      }
      url = var.git_repository
    }
  })
}

# Kustomization resource for Flux
resource "kubectl_manifest" "kustomization" {
  count = var.git_repository != "" ? 1 : 0
  depends_on = [ kubectl_manifest.git_repository ]

  yaml_body = yamlencode({
    apiVersion = "kustomize.toolkit.fluxcd.io/v1"
    kind       = "Kustomization"
    metadata = {
      name      = "homelab-apps"
      namespace = "flux-system"
    }
    spec = {
      interval = "10m"
      sourceRef = {
        kind = "GitRepository"
        name = "homelab-gitops"
      }
      path = "./kubernetes/apps"
      prune = true
      wait = true
      timeout = "5m"
    }
  })
}
